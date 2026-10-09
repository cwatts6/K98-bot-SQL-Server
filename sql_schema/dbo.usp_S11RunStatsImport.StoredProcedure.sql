SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE OR ALTER PROCEDURE dbo.usp_S11RunStatsImport
    @PreparationID uniqueidentifier,
    @CompletedFileName nvarchar(260),
    @param1 float = NULL,
    @param2 nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 51960, 'S11 import requires an unowned transaction.', 1;
    DECLARE @Entered bit=0;
    DECLARE @LockResult int, @Resource nvarchar(255) = N'S11:stats-import:' + LOWER(CONVERT(nvarchar(36),@PreparationID));
    EXEC @LockResult = sys.sp_getapplock @Resource=@Resource, @LockMode='Exclusive', @LockOwner='Session', @LockTimeout=0;
    IF @LockResult < 0 THROW 51960, 'Exact import execution is already active.', 1;
    BEGIN TRY
        -- A prepared receipt is single-use. It cannot rerun a failed/committed import.
        UPDATE e SET State='running', UpdatedUTC=SYSUTCDATETIME(), Version=Version+1
        FROM dbo.StatsImportExecution e
        JOIN dbo.ExportPreparation p ON p.PreparationID=e.PreparationID
        WHERE e.PreparationID=@PreparationID AND e.CompletedFileName=@CompletedFileName
          AND e.State='prepared' AND p.State='writing' AND p.ConsumerKind='scan_data'
          AND p.OwnerID=e.OwnerID AND p.Fence=e.Fence AND p.JobID IS NULL AND p.SpoolKey IS NULL
          AND EXISTS (SELECT 1 FROM dbo.ExportResource r WHERE r.ResourceKey='sql_snapshot:legacy_outputs'
            AND r.ActivePreparationID=p.PreparationID AND r.OwnerID=p.OwnerID AND r.Fence=p.Fence
            AND r.ActiveJobID IS NULL AND r.ActiveOutputOperationID IS NULL AND r.BlockedReason IS NULL);
        IF @@ROWCOUNT <> 1 THROW 51960, 'Exact prepared import ownership required; no replay.', 1;
        SET @Entered=1;
        EXEC dbo.UPDATE_ALL2 @param1=@param1, @param2=@param2,
            @CompletedFileName=@CompletedFileName, @ExportPreparationID=@PreparationID;
        IF NOT EXISTS (SELECT 1 FROM dbo.StatsImportExecution WHERE PreparationID=@PreparationID AND State='completed')
            THROW 51960, 'Import returned without its exact completion receipt.', 1;
        EXEC sys.sp_releaseapplock @Resource=@Resource, @LockOwner='Session';
    END TRY
    BEGIN CATCH
        -- Attention/disconnection may bypass CATCH: the nonterminal receipt then stays
        -- unresolved. A terminal receipt and the execution lock are both required.
        IF XACT_STATE() <> 0 ROLLBACK;
        UPDATE dbo.StatsImportExecution
        SET State=CASE State WHEN 'running' THEN 'rolled_back' WHEN 'import_committed' THEN 'partial' ELSE State END,
            ErrorNumber=ERROR_NUMBER(), ErrorProcedure=ERROR_PROCEDURE(), ErrorLine=ERROR_LINE(),
            UpdatedUTC=SYSUTCDATETIME(), Version=Version+1
        WHERE @Entered=1 AND PreparationID=@PreparationID AND State IN ('running','import_committed','completed');
        EXEC sys.sp_releaseapplock @Resource=@Resource, @LockOwner='Session';
        THROW;
    END CATCH;
END;
