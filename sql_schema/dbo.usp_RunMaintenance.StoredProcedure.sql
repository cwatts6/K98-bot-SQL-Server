SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_RunMaintenance @Kind varchar(24)
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    -- The actual worker owns both guards; no journal-session/age lease can
    -- outlive it or admit another worker while this one still executes.
    IF @@TRANCOUNT<>0 THROW 51962, 'Maintenance requires its own autocommit session.', 1;
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork WHERE Kind=@Kind)
        THROW 51962, 'Unknown maintenance kind.', 1;
    DECLARE @r int, @released int, @claim uniqueidentifier=NEWID(),
            @generation bigint, @state varchar(12), @log decimal(9,4),
            @resource nvarchar(255)=N'K98:post-import-stats:v1',
            @snapshot bit=0, @owned bit=0;
    BEGIN TRY
        EXEC @r=sys.sp_getapplock @Resource=@resource,
            @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
        IF @r<0 RETURN;
        SET @owned=1;
        -- A free exact session guard proves physical absence, not outcome.
        UPDATE dbo.MaintenanceWork SET State='unknown'
          WHERE Kind=@Kind AND State='running';
        SELECT @generation=DueGeneration,@state=State
          FROM dbo.MaintenanceWork WHERE Kind=@Kind;
        IF @state='pending'
        BEGIN
            EXEC @r=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',
                @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
            IF @r>=0
            BEGIN
                SET @snapshot=1;
                -- Preserve the existing log headroom gate. Missing evidence
                -- defers optional work; it never creates business replay authority.
                SELECT @log=used_log_space_in_percent FROM sys.dm_db_log_space_usage;
                IF @log IS NOT NULL AND @log<70
                BEGIN
                    UPDATE dbo.MaintenanceWork SET State='running',ClaimID=@claim,
                        ClaimedGeneration=@generation,StartedUTC=SYSUTCDATETIME()
                      WHERE Kind=@Kind AND State='pending';
                    -- Fixed dispatch only. Later D3 slices add their real children.
                    IF @Kind='post_import' EXEC dbo.usp_MaintenancePostImport;
                    ELSE THROW 51963, 'Maintenance child is not installed.', 1;
                    UPDATE dbo.MaintenanceWork SET CompletedGeneration=@generation,
                        CompletedUTC=SYSUTCDATETIME(),LastErrorNumber=NULL,
                        State=CASE WHEN DueGeneration=@generation THEN 'complete' ELSE 'pending' END
                      WHERE Kind=@Kind AND ClaimID=@claim AND State='running'
                        AND ClaimedGeneration=@generation;
                    IF @@ROWCOUNT<>1 THROW 51964, 'Maintenance claim changed.', 1;
                END;
            END;
        END;
        IF @snapshot=1
        BEGIN
            EXEC @released=sys.sp_releaseapplock @Resource=N'k98-legacy-output-snapshot',@LockOwner='Session';
            IF @released<0 THROW 51965, 'Maintenance snapshot release not acknowledged.', 1;
            SET @snapshot=0;
        END;
        EXEC @released=sys.sp_releaseapplock @Resource=@resource,@LockOwner='Session';
        IF @released<0 THROW 51965, 'Maintenance release not acknowledged.', 1;
        SET @owned=0;
    END TRY
    BEGIN CATCH
        DECLARE @error int=ERROR_NUMBER();
        -- Keep the first failure separate from current state. Transport loss can
        -- prevent this update: running then remains unknown until inspected.
        BEGIN TRY
            UPDATE dbo.MaintenanceWork SET State='failed',LastErrorNumber=@error,
                FirstErrorNumber=COALESCE(FirstErrorNumber,@error),
                FirstErrorUTC=COALESCE(FirstErrorUTC,SYSUTCDATETIME())
              WHERE Kind=@Kind AND ClaimID=@claim AND State='running';
        END TRY
        BEGIN CATCH
            -- Failed evidence persistence leaves the original running claim.
            -- Preserve the child error below; never manufacture completion.
        END CATCH;
        -- The caller must explicitly acknowledge session release before returning
        -- this connection to an ODBC pool; close alone may retain these guards.
        -- Do not mask the original SQL failure with an attempted second release.
        THROW;
    END CATCH;
END;
