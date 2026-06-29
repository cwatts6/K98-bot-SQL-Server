SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_ImportAudit_CompleteBatch]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_ImportAudit_CompleteBatch] AS'
END
ALTER PROCEDURE [dbo].[usp_ImportAudit_CompleteBatch]
    @ImportAuditBatchId bigint,
    @Status nvarchar(32) = N'completed',
    @RowsInSource int = NULL,
    @RowsStaged int = NULL,
    @RowsWritten int = NULL,
    @RowsSkipped int = NULL,
    @ExternalBatchTable nvarchar(256) = NULL,
    @ExternalBatchId nvarchar(128) = NULL,
    @DetailsJson nvarchar(max) = NULL,
    @CompletedAtUtc datetime2(3) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Status NOT IN (
        N'queued', N'started', N'staged', N'converted', N'procedure_started',
        N'downstream_rebuild_started', N'completed', N'failed', N'skipped',
        N'duplicate', N'cancelled', N'rolled_back'
    )
        THROW 51022, 'Status is not valid for ImportAuditBatch.', 1;

    IF @DetailsJson IS NOT NULL AND ISJSON(@DetailsJson) <> 1
        THROW 51020, 'DetailsJson must be valid JSON.', 1;

    UPDATE dbo.ImportAuditBatch
    SET Status = @Status,
        CompletedAtUtc = COALESCE(@CompletedAtUtc, SYSUTCDATETIME()),
        RowsInSource = COALESCE(@RowsInSource, RowsInSource),
        RowsStaged = COALESCE(@RowsStaged, RowsStaged),
        RowsWritten = COALESCE(@RowsWritten, RowsWritten),
        RowsSkipped = COALESCE(@RowsSkipped, RowsSkipped),
        ExternalBatchTable = COALESCE(@ExternalBatchTable, ExternalBatchTable),
        ExternalBatchId = COALESCE(@ExternalBatchId, ExternalBatchId),
        DetailsJson = COALESCE(@DetailsJson, DetailsJson),
        UpdatedAtUtc = SYSUTCDATETIME()
    WHERE ImportAuditBatchId = @ImportAuditBatchId;

    IF @@ROWCOUNT = 0
        THROW 51021, 'ImportAuditBatchId was not found.', 1;

    SELECT @ImportAuditBatchId AS ImportAuditBatchId;
END
