SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_ImportAudit_StartBatch]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_ImportAudit_StartBatch] AS' 
END
ALTER PROCEDURE [dbo].[usp_ImportAudit_StartBatch]
	@ImportKind [nvarchar](64),
	@SourceType [nvarchar](64) = NULL,
	@SourceFilename [nvarchar](260) = NULL,
	@SourceFileHashSha256 [char](64) = NULL,
	@SourceMessageId [bigint] = NULL,
	@SourceChannelId [bigint] = NULL,
	@ActorDiscordId [bigint] = NULL,
	@QueueName [nvarchar](128) = NULL,
	@QueueChannelId [bigint] = NULL,
	@ExternalBatchTable [nvarchar](256) = NULL,
	@ExternalBatchId [nvarchar](128) = NULL,
	@Status [nvarchar](32) = N'started',
	@RowsInSource [int] = NULL,
	@DetailsJson [nvarchar](max) = NULL,
	@CorrelationId [uniqueidentifier] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ImportKind IS NULL OR LTRIM(RTRIM(@ImportKind)) = N''
        THROW 51000, 'ImportKind is required.', 1;

    IF @Status NOT IN (
        N'queued', N'started', N'staged', N'converted', N'procedure_started',
        N'downstream_rebuild_started', N'completed', N'failed', N'skipped',
        N'duplicate', N'cancelled', N'rolled_back'
    )
        THROW 51002, 'Status is not valid for ImportAuditBatch.', 1;

    IF @DetailsJson IS NOT NULL AND ISJSON(@DetailsJson) <> 1
        THROW 51001, 'DetailsJson must be valid JSON.', 1;

    SET @CorrelationId = COALESCE(@CorrelationId, NEWID());

    INSERT INTO dbo.ImportAuditBatch
    (
        CorrelationId, ImportKind, SourceType, SourceFilename, SourceFileHashSha256,
        SourceMessageId, SourceChannelId, ActorDiscordId, QueueName, QueueChannelId,
        ExternalBatchTable, ExternalBatchId, Status, RowsInSource, DetailsJson,
        StartedAtUtc, CreatedAtUtc, UpdatedAtUtc
    )
    VALUES
    (
        @CorrelationId, @ImportKind, @SourceType, @SourceFilename, @SourceFileHashSha256,
        @SourceMessageId, @SourceChannelId, @ActorDiscordId, @QueueName, @QueueChannelId,
        @ExternalBatchTable, @ExternalBatchId, @Status, @RowsInSource, @DetailsJson,
        SYSUTCDATETIME(), SYSUTCDATETIME(), SYSUTCDATETIME()
    );

    SELECT
        CAST(SCOPE_IDENTITY() AS bigint) AS ImportAuditBatchId,
        @CorrelationId AS CorrelationId;
END;

