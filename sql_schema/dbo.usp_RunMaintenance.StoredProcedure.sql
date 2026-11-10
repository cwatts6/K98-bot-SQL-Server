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
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2 THROW 51962, 'Maintenance requires its own autocommit session.', 1;
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork WHERE Kind=@Kind)
        THROW 51962, 'Unknown maintenance kind.', 1;
    DECLARE @r int, @released int, @claim uniqueidentifier=NEWID(),
            @generation bigint, @ks4due bigint, @ks4done bigint, @includeKS4 bit, @state varchar(12), @log decimal(9,4),
            @resource nvarchar(255)=N'K98:post-import-stats:v1',
            @snapshot bit=0, @schema bit=0, @delta bit=0, @player bit=0, @owned bit=0,
            @cfgrows bigint,@cfgcompleted bigint,@cfgbatch int,@cfgscan int,
            @cfglarge bigint,@cfglargedone bigint,@pendingRows bigint,@largeDue bit,@kvkDone bit=1,
            @dashdue bigint,@dashdone bigint,@sumdue bigint,@sumdone bigint,@dashboard bit,@summary bit;
    BEGIN TRY
        EXEC @r=sys.sp_getapplock @Resource=@resource,
            @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
        IF @r<0 RETURN;
        SET @owned=1;
        -- A free exact session guard proves physical absence, not outcome.
        IF @Kind='kvk_output'
            UPDATE dbo.MaintenanceKvkWork SET State='unknown' WHERE State='running';
        UPDATE dbo.MaintenanceWork SET State='unknown'
          WHERE Kind=@Kind AND State='running';
        SELECT @generation=DueGeneration,@state=State,@ks4due=KS4DueGeneration,@ks4done=KS4CompletedGeneration,
            @dashdue=DashboardDueGeneration,@dashdone=DashboardCompletedGeneration,
            @sumdue=SummaryDueGeneration,@sumdone=SummaryCompletedGeneration
          FROM dbo.MaintenanceWork WHERE Kind=@Kind;
        IF @state='pending'
        BEGIN
            EXEC @r=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',
                @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
            IF @r>=0
            BEGIN
                SET @snapshot=1;
                EXEC @r=sys.sp_getapplock @Resource=N'K98:TargetPublication:DeltaPreprocessing',
                    @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
                IF @r>=0 SET @delta=1;
                IF @delta=1
                BEGIN
                    EXEC @r=sys.sp_getapplock @Resource=N'K98:StatsForUpload:Publish',
                        @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
                    IF @r>=0 SET @player=1;
                END;
                IF @player=1
                BEGIN
                    EXEC @r=sys.sp_getapplock @Resource=N'K98:maintenance-schema:v1',
                        @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
                    IF @r>=0 SET @schema=1;
                END;
                -- Preserve the existing log headroom gate. Missing evidence
                -- defers optional work; it never creates business replay authority.
                SELECT @log=used_log_space_in_percent FROM sys.dm_db_log_space_usage;
                IF @delta=1 AND @schema=1 AND @log IS NOT NULL AND @log<70
                BEGIN
                    IF @Kind='configuration'
                    BEGIN
                        SELECT @generation=DueGeneration FROM dbo.MaintenanceWork WHERE Kind=@Kind;
                        SELECT @cfgrows=DueRows,@cfgcompleted=CompletedRows,@cfgbatch=LastBatchRows,
                            @cfgscan=LastScan,@cfglarge=LargeBatchGeneration,@cfglargedone=CompletedLargeBatchGeneration
                          FROM dbo.MaintenanceConfigurationWork WHERE ID=1;
                        IF @cfgrows IS NULL THROW 51962,'Configuration summary missing.',1;
                        SET @pendingRows=@cfgrows-@cfgcompleted;
                        IF @pendingRows<=0 OR @cfgbatch>@pendingRows THROW 51962,'Configuration maintenance summary does not match pending work.',1;
                        SET @largeDue=CASE WHEN @cfglarge>@cfglargedone THEN 1 ELSE 0 END;
                    END;
                    UPDATE dbo.MaintenanceWork SET State='running',ClaimID=@claim,
                        ClaimedGeneration=@generation,StartedUTC=SYSUTCDATETIME()
                      WHERE Kind=@Kind AND State='pending';
                    -- Fixed dispatch only. Later D3 slices add their real children.
                    SET @includeKS4=CASE WHEN @ks4due>@ks4done THEN 1 ELSE 0 END;
                    IF @Kind='import' EXEC dbo.usp_MaintenanceImport @IncludeKS4=@includeKS4;
                    ELSE IF @Kind='configuration' EXEC dbo.usp_MaintenanceConfiguration
                        @RowsProcessed=@pendingRows,@LastBatchRows=@cfgbatch,@NewMaxScan=@cfgscan,
                        @LargeBatchDue=@largeDue,@Generation=@generation;
                    ELSE IF @Kind='player_report' EXEC dbo.usp_MaintenancePlayerReport;
                    ELSE IF @Kind='kvk_output' EXEC dbo.usp_MaintenanceKvkOutput
                        @Generation=@generation,@ClaimID=@claim,@AllDone=@kvkDone OUTPUT;
                    ELSE IF @Kind='final_stats'
                    BEGIN
                        SET @dashboard=CASE WHEN @dashdue>@dashdone THEN 1 ELSE 0 END;
                        SET @summary=CASE WHEN @sumdue>@sumdone THEN 1 ELSE 0 END;
                        EXEC dbo.usp_MaintenanceFinalStats @Dashboard=@dashboard,@Summary=@summary,
                            @Generation=@generation,@ClaimID=@claim;
                    END;
                    ELSE IF @Kind='post_import'  EXEC dbo.usp_MaintenancePostImport;
                    ELSE THROW 51963, 'Maintenance child is not installed.', 1;
                    IF @Kind='configuration'
                    BEGIN
                        BEGIN TRANSACTION;
                        UPDATE dbo.MaintenanceConfigurationWork SET CompletedRows=@cfgrows,
                            CompletedLargeBatchGeneration=@cfglarge WHERE ID=1;
                        IF @@ROWCOUNT<>1 THROW 51964,'Configuration summary changed.',1;
                    END;
                    UPDATE dbo.MaintenanceWork SET CompletedGeneration=CASE WHEN @kvkDone=1 THEN @generation ELSE CompletedGeneration END,
                        KS4CompletedGeneration=@ks4due,
                        DashboardCompletedGeneration=@dashdue,SummaryCompletedGeneration=@sumdue,
                        CompletedUTC=SYSUTCDATETIME(),LastErrorNumber=NULL,
                        State=CASE WHEN DueGeneration=@generation AND @kvkDone=1 THEN 'complete' ELSE 'pending' END
                      WHERE Kind=@Kind AND ClaimID=@claim AND State='running'
                        AND ClaimedGeneration=@generation;
                    IF @@ROWCOUNT<>1 THROW 51964, 'Maintenance claim changed.', 1;
                    IF @Kind='configuration' COMMIT TRANSACTION;
                END;
            END;
        END;
        IF @schema=1
        BEGIN
            EXEC @released=sys.sp_releaseapplock @Resource=N'K98:maintenance-schema:v1',@LockOwner='Session';
            IF @released<0 THROW 51965,'Maintenance schema release not acknowledged.',1;
            SET @schema=0;
        END;
        IF @player=1
        BEGIN
            EXEC @released=sys.sp_releaseapplock @Resource=N'K98:StatsForUpload:Publish',@LockOwner='Session';
            IF @released<0 THROW 51965,'Maintenance player publication release not acknowledged.',1;
            SET @player=0;
        END;
        IF @delta=1
        BEGIN
            EXEC @released=sys.sp_releaseapplock @Resource=N'K98:TargetPublication:DeltaPreprocessing',@LockOwner='Session';
            IF @released<0 THROW 51965,'Maintenance delta release not acknowledged.',1;
            SET @delta=0;
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
        BEGIN TRY
            IF XACT_STATE()<>0 ROLLBACK; -- only the worker-owned short acknowledgement transaction
        END TRY
        BEGIN CATCH
            -- Preserve the first child/acknowledgement failure. The caller must
            -- still establish physical rollback/release before returning a pool handle.
        END CATCH;
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
