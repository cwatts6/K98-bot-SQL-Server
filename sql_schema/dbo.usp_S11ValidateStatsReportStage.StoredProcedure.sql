SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE OR ALTER PROCEDURE dbo.usp_S11ValidateStatsReportStage
    @PreparationID uniqueidentifier,
    @CompletedFileName nvarchar(260)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>1 OR XACT_STATE()<>1
        THROW 51961, 'One owned reporting transaction required.', 1;
    DECLARE @LockResult int;
    EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK @LockTimeout=0,@LockResult=@LockResult OUTPUT;
    IF @LockResult<0 THROW 51961, 'Scan writer is active; reporting remains held.', 1;
    -- The non-coordinated legacy entry point still uses these same business
    -- calculations. It has no durable continuation and cannot adopt one.
    IF @PreparationID IS NULL RETURN;
    DECLARE @Resource nvarchar(255)=N'S11:stats-import:'+LOWER(CONVERT(nvarchar(36),@PreparationID));
    IF COALESCE(APPLOCK_MODE(N'public',@Resource,N'Session'),N'NoLock')<>N'Exclusive'
       OR COALESCE(APPLOCK_MODE(N'public',N'k98-legacy-output-snapshot',N'Session'),N'NoLock')<>N'Exclusive'
        THROW 51961, 'Both independent producer session guards are required.', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.StatsImportExecution e WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.StatsImportReportContinuation c WITH (UPDLOCK,HOLDLOCK) ON c.PreparationID=e.PreparationID
        JOIN dbo.ExportPreparation p WITH (UPDLOCK,HOLDLOCK) ON p.PreparationID=e.PreparationID
        JOIN dbo.ExportResource r WITH (UPDLOCK,HOLDLOCK) ON r.ActivePreparationID=p.PreparationID
        JOIN dbo.KS4_ImportFileClaim f WITH (HOLDLOCK) ON f.CompletedFileName COLLATE Latin1_General_100_BIN2=e.CompletedFileName
        WHERE e.PreparationID=@PreparationID AND e.CompletedFileName=@CompletedFileName
          AND e.Resolution IS NULL AND e.State IN ('import_committed','partial','completed')
          AND e.ScanOrder=c.ScanOrder AND c.ContractVersion=1
          AND (e.State<>'completed' OR c.CompletedStage=3)
          AND (c.CompletedStage<>3 OR e.State='completed')
          AND p.ConsumerKind='scan_data' AND p.State IN ('writing','committed','uncertain')
          AND p.OwnerID=e.OwnerID AND p.Fence=e.Fence
          AND p.JobID IS NULL AND p.SpoolKey IS NULL AND p.GenerationJson IS NULL
          AND r.ResourceKey='sql_snapshot:legacy_outputs' AND r.OwnerID=p.OwnerID AND r.Fence=p.Fence
          AND r.ActiveJobID IS NULL AND r.ActiveOutputOperationID IS NULL
          AND f.FileDigest=c.InputDigest AND f.ClaimStatus IN ('imported','archived')
          AND c.LatestScanOrder=(SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4 WITH (HOLDLOCK))
          AND c.ConfigurationJson=(SELECT KVKVersion,ConfigKey,ConfigValue,LastUpdated
              FROM dbo.ProcConfig WITH (HOLDLOCK) ORDER BY KVKVersion,ConfigKey
              FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE Latin1_General_100_BIN2
          AND NOT EXISTS (SELECT 1 FROM dbo.ExportResource other WITH (HOLDLOCK)
              WHERE other.ActivePreparationID=p.PreparationID AND other.ResourceKey<>'sql_snapshot:legacy_outputs')
    ) THROW 51961, 'Exact committed input, unchanged configuration and retained ownership required.', 1;
END;
