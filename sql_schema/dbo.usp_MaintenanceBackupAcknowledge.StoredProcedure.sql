SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceBackupAcknowledge
    @ClaimID uniqueidentifier, @Generation bigint, @Outcome varchar(12), @Failure varchar(32)=NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2 OR
        COALESCE(APPLOCK_MODE('public','K98:post-import-stats:v1','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Exact backup session owner required.',1;
    IF @Outcome NOT IN ('requested','failed','unknown') OR @Outcome IS NULL
        THROW 51962,'Unsupported backup outcome.',1;
    UPDATE dbo.MaintenanceBackupWork SET
        RequestedGeneration=CASE WHEN @Outcome='requested' THEN @Generation ELSE RequestedGeneration END,
        RequestedUTC=CASE WHEN @Outcome='requested' THEN SYSUTCDATETIME() ELSE RequestedUTC END,
        State=CASE WHEN @Outcome='requested' AND DueGeneration>@Generation THEN 'pending' ELSE @Outcome END,
        FirstFailure=CASE WHEN @Outcome<>'requested' THEN COALESCE(FirstFailure,@Failure,'dispatch_unknown') ELSE FirstFailure END,
        FirstFailureUTC=CASE WHEN @Outcome<>'requested' THEN COALESCE(FirstFailureUTC,SYSUTCDATETIME()) ELSE FirstFailureUTC END,
        LastFailure=CASE WHEN @Outcome<>'requested' THEN COALESCE(@Failure,'dispatch_unknown') END
      WHERE ID=1 AND State='running' AND ClaimID=@ClaimID AND ClaimedGeneration=@Generation;
    IF @@ROWCOUNT<>1 THROW 51964,'Backup claim changed; retain original outcome.',1;
    SELECT State,DueGeneration,RequestedGeneration,ClaimedGeneration,ClaimID
      FROM dbo.MaintenanceBackupWork WHERE ID=1;
END;
