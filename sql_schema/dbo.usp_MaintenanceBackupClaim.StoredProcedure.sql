SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceBackupClaim @ClaimID uniqueidentifier
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON; SET LOCK_TIMEOUT 0;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2 OR @ClaimID IS NULL
        THROW 51962,'Backup claim requires dedicated autocommit ownership.',1;
    IF COALESCE(APPLOCK_MODE('public','K98:post-import-stats:v1','Session'),'NoLock')<>'NoLock'
        THROW 51962,'Backup claim cannot adopt pre-existing ownership.',1;
    DECLARE @r int;
    EXEC @r=sys.sp_getapplock @Resource='K98:post-import-stats:v1',
        @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
    IF @r<0
    BEGIN
        SELECT CAST('busy' AS varchar(12)) State,DueGeneration,RequestedGeneration,ClaimedGeneration,ClaimID
          FROM dbo.MaintenanceBackupWork WHERE ID=1;
        RETURN;
    END;
    -- Guard is held on this session until the caller acknowledges cleanup.
    -- Committed summary demand is sufficient. Backup relief must not wait for
    -- statistics/CHECKPOINT, whose separate log-headroom gate can defer upkeep.
    DECLARE @summary bigint;
    SELECT @summary=SummaryDueGeneration FROM dbo.MaintenanceWork WHERE Kind='final_stats';
    IF OBJECT_ID('dbo.LogBackupTriggerQueue','U') IS NOT NULL AND @summary>0
        UPDATE dbo.MaintenanceBackupWork SET DueGeneration=@summary,DueUTC=SYSUTCDATETIME(),
            State=CASE WHEN State='requested' THEN 'pending' ELSE State END
          WHERE ID=1 AND DueGeneration<@summary;
    UPDATE dbo.MaintenanceBackupWork SET State='unknown',
        FirstFailure=COALESCE(FirstFailure,'owner_absent'),
        FirstFailureUTC=COALESCE(FirstFailureUTC,SYSUTCDATETIME()),LastFailure='owner_absent'
      WHERE ID=1 AND State='running';
    UPDATE dbo.MaintenanceBackupWork SET State='running',ClaimID=@ClaimID,
        ClaimedGeneration=DueGeneration,StartedUTC=SYSUTCDATETIME()
      WHERE ID=1 AND State='pending' AND DueGeneration>RequestedGeneration
        AND DueGeneration<=@summary;
    SELECT State,DueGeneration,RequestedGeneration,ClaimedGeneration,ClaimID
      FROM dbo.MaintenanceBackupWork WHERE ID=1;
END;
