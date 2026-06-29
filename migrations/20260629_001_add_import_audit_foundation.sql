/*
MigrationId: 20260629_001_add_import_audit_foundation
Purpose: Add generic durable import audit batch and phase tracking
Author: cwatts
CreatedUtc: 2026-06-29
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.ImportAuditBatch') AS BatchTable, OBJECT_ID(N'dbo.ImportAuditPhase') AS PhaseTable;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.ImportAuditBatch') AS BatchTable, OBJECT_ID(N'dbo.ImportAuditPhase') AS PhaseTable, OBJECT_ID(N'dbo.usp_ImportAudit_StartBatch') AS StartProc, OBJECT_ID(N'dbo.usp_ImportAudit_RecordPhase') AS PhaseProc, OBJECT_ID(N'dbo.usp_ImportAudit_CompleteBatch') AS CompleteProc, OBJECT_ID(N'dbo.usp_ImportAudit_FailBatch') AS FailProc;
RelatedBotPR:
RelatedSQLPR:
RollbackNotes:
- Disable bot-side audit calls first if bot code has been deployed.
- Drop dbo.usp_ImportAudit_FailBatch, dbo.usp_ImportAudit_CompleteBatch, dbo.usp_ImportAudit_RecordPhase, dbo.usp_ImportAudit_StartBatch, dbo.ImportAuditPhase, and dbo.ImportAuditBatch only after confirming no operator needs the captured audit history.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.ImportAuditBatch', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ImportAuditBatch
    (
        ImportAuditBatchId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_ImportAuditBatch PRIMARY KEY CLUSTERED,
        CorrelationId uniqueidentifier NOT NULL
            CONSTRAINT DF_ImportAuditBatch_CorrelationId DEFAULT NEWID(),
        ImportKind nvarchar(64) COLLATE Latin1_General_CI_AS NOT NULL,
        SourceType nvarchar(64) COLLATE Latin1_General_CI_AS NULL,
        SourceFilename nvarchar(260) COLLATE Latin1_General_CI_AS NULL,
        SourceFileHashSha256 char(64) COLLATE Latin1_General_CI_AS NULL,
        SourceMessageId bigint NULL,
        SourceChannelId bigint NULL,
        ActorDiscordId bigint NULL,
        QueueName nvarchar(128) COLLATE Latin1_General_CI_AS NULL,
        QueueChannelId bigint NULL,
        ExternalBatchTable nvarchar(256) COLLATE Latin1_General_CI_AS NULL,
        ExternalBatchId nvarchar(128) COLLATE Latin1_General_CI_AS NULL,
        Status nvarchar(32) COLLATE Latin1_General_CI_AS NOT NULL,
        StartedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_ImportAuditBatch_StartedAtUtc DEFAULT SYSUTCDATETIME(),
        CompletedAtUtc datetime2(3) NULL,
        RowsInSource int NULL,
        RowsStaged int NULL,
        RowsWritten int NULL,
        RowsSkipped int NULL,
        ErrorType nvarchar(128) COLLATE Latin1_General_CI_AS NULL,
        ErrorText nvarchar(2000) COLLATE Latin1_General_CI_AS NULL,
        DetailsJson nvarchar(max) COLLATE Latin1_General_CI_AS NULL,
        CreatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_ImportAuditBatch_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        UpdatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_ImportAuditBatch_UpdatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_ImportAuditBatch_CorrelationId UNIQUE NONCLUSTERED (CorrelationId),
        CONSTRAINT CK_ImportAuditBatch_Status CHECK (
            Status IN (
                N'queued', N'started', N'staged', N'converted', N'procedure_started',
                N'downstream_rebuild_started', N'completed', N'failed', N'skipped',
                N'duplicate', N'cancelled', N'rolled_back'
            )
        ),
        CONSTRAINT CK_ImportAuditBatch_DetailsJson CHECK (
            DetailsJson IS NULL OR ISJSON(DetailsJson) = 1
        )
    );
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ImportAuditBatch')
      AND name = N'IX_ImportAuditBatch_KindStatusStarted'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_ImportAuditBatch_KindStatusStarted
    ON dbo.ImportAuditBatch (ImportKind, Status, StartedAtUtc DESC)
    INCLUDE (SourceFilename, ExternalBatchTable, ExternalBatchId, RowsWritten);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ImportAuditBatch')
      AND name = N'IX_ImportAuditBatch_ExternalBatch'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_ImportAuditBatch_ExternalBatch
    ON dbo.ImportAuditBatch (ExternalBatchTable, ExternalBatchId, StartedAtUtc DESC)
    WHERE ExternalBatchTable IS NOT NULL AND ExternalBatchId IS NOT NULL;
END;
GO

IF OBJECT_ID(N'dbo.ImportAuditPhase', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ImportAuditPhase
    (
        ImportAuditPhaseId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_ImportAuditPhase PRIMARY KEY CLUSTERED,
        ImportAuditBatchId bigint NOT NULL,
        PhaseName nvarchar(64) COLLATE Latin1_General_CI_AS NOT NULL,
        PhaseStatus nvarchar(32) COLLATE Latin1_General_CI_AS NOT NULL,
        StartedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_ImportAuditPhase_StartedAtUtc DEFAULT SYSUTCDATETIME(),
        CompletedAtUtc datetime2(3) NULL,
        RowsIn int NULL,
        RowsOut int NULL,
        DurationMs int NULL,
        ErrorType nvarchar(128) COLLATE Latin1_General_CI_AS NULL,
        ErrorText nvarchar(2000) COLLATE Latin1_General_CI_AS NULL,
        DetailsJson nvarchar(max) COLLATE Latin1_General_CI_AS NULL,
        CreatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_ImportAuditPhase_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_ImportAuditPhase_Batch FOREIGN KEY (ImportAuditBatchId)
            REFERENCES dbo.ImportAuditBatch (ImportAuditBatchId),
        CONSTRAINT CK_ImportAuditPhase_Status CHECK (
            PhaseStatus IN (
                N'started', N'completed', N'failed', N'skipped',
                N'duplicate', N'cancelled', N'rolled_back'
            )
        ),
        CONSTRAINT CK_ImportAuditPhase_DetailsJson CHECK (
            DetailsJson IS NULL OR ISJSON(DetailsJson) = 1
        )
    );
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ImportAuditPhase')
      AND name = N'IX_ImportAuditPhase_BatchPhase'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_ImportAuditPhase_BatchPhase
    ON dbo.ImportAuditPhase (ImportAuditBatchId, StartedAtUtc, ImportAuditPhaseId)
    INCLUDE (PhaseName, PhaseStatus, RowsIn, RowsOut, DurationMs);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ImportAudit_StartBatch
    @ImportKind nvarchar(64),
    @SourceType nvarchar(64) = NULL,
    @SourceFilename nvarchar(260) = NULL,
    @SourceFileHashSha256 char(64) = NULL,
    @SourceMessageId bigint = NULL,
    @SourceChannelId bigint = NULL,
    @ActorDiscordId bigint = NULL,
    @QueueName nvarchar(128) = NULL,
    @QueueChannelId bigint = NULL,
    @ExternalBatchTable nvarchar(256) = NULL,
    @ExternalBatchId nvarchar(128) = NULL,
    @Status nvarchar(32) = N'started',
    @RowsInSource int = NULL,
    @DetailsJson nvarchar(max) = NULL,
    @CorrelationId uniqueidentifier = NULL
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
GO

CREATE OR ALTER PROCEDURE dbo.usp_ImportAudit_RecordPhase
    @ImportAuditBatchId bigint,
    @PhaseName nvarchar(64),
    @PhaseStatus nvarchar(32),
    @StartedAtUtc datetime2(3) = NULL,
    @CompletedAtUtc datetime2(3) = NULL,
    @RowsIn int = NULL,
    @RowsOut int = NULL,
    @DurationMs int = NULL,
    @ErrorType nvarchar(128) = NULL,
    @ErrorText nvarchar(2000) = NULL,
    @DetailsJson nvarchar(max) = NULL,
    @SetBatchStatus nvarchar(32) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ImportAuditPhaseId bigint;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.ImportAuditBatch
        WHERE ImportAuditBatchId = @ImportAuditBatchId
    )
        THROW 51010, 'ImportAuditBatchId was not found.', 1;

    IF @PhaseName IS NULL OR LTRIM(RTRIM(@PhaseName)) = N''
        THROW 51011, 'PhaseName is required.', 1;

    IF @PhaseStatus NOT IN (
        N'started', N'completed', N'failed', N'skipped',
        N'duplicate', N'cancelled', N'rolled_back'
    )
        THROW 51013, 'PhaseStatus is not valid for ImportAuditPhase.', 1;

    IF @SetBatchStatus IS NOT NULL
       AND @SetBatchStatus NOT IN (
            N'queued', N'started', N'staged', N'converted', N'procedure_started',
            N'downstream_rebuild_started', N'completed', N'failed', N'skipped',
            N'duplicate', N'cancelled', N'rolled_back'
       )
        THROW 51014, 'SetBatchStatus is not valid for ImportAuditBatch.', 1;

    IF @DetailsJson IS NOT NULL AND ISJSON(@DetailsJson) <> 1
        THROW 51012, 'DetailsJson must be valid JSON.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.ImportAuditPhase
        (
            ImportAuditBatchId, PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc,
            RowsIn, RowsOut, DurationMs, ErrorType, ErrorText, DetailsJson, CreatedAtUtc
        )
        VALUES
        (
            @ImportAuditBatchId, @PhaseName, @PhaseStatus,
            COALESCE(@StartedAtUtc, SYSUTCDATETIME()), @CompletedAtUtc,
            @RowsIn, @RowsOut, @DurationMs, @ErrorType, @ErrorText, @DetailsJson,
            SYSUTCDATETIME()
        );

        SET @ImportAuditPhaseId = CAST(SCOPE_IDENTITY() AS bigint);

        UPDATE dbo.ImportAuditBatch
        SET Status = COALESCE(@SetBatchStatus, Status),
            UpdatedAtUtc = SYSUTCDATETIME()
        WHERE ImportAuditBatchId = @ImportAuditBatchId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT @ImportAuditPhaseId AS ImportAuditPhaseId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ImportAudit_CompleteBatch
    @ImportAuditBatchId bigint,
    @Status nvarchar(32) = N'completed',
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
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ImportAudit_FailBatch
    @ImportAuditBatchId bigint,
    @Status nvarchar(32) = N'failed',
    @ErrorType nvarchar(128) = NULL,
    @ErrorText nvarchar(2000) = NULL,
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
        THROW 51032, 'Status is not valid for ImportAuditBatch.', 1;

    IF @DetailsJson IS NOT NULL AND ISJSON(@DetailsJson) <> 1
        THROW 51030, 'DetailsJson must be valid JSON.', 1;

    UPDATE dbo.ImportAuditBatch
    SET Status = @Status,
        CompletedAtUtc = COALESCE(@CompletedAtUtc, SYSUTCDATETIME()),
        RowsStaged = COALESCE(@RowsStaged, RowsStaged),
        RowsWritten = COALESCE(@RowsWritten, RowsWritten),
        RowsSkipped = COALESCE(@RowsSkipped, RowsSkipped),
        ExternalBatchTable = COALESCE(@ExternalBatchTable, ExternalBatchTable),
        ExternalBatchId = COALESCE(@ExternalBatchId, ExternalBatchId),
        ErrorType = @ErrorType,
        ErrorText = @ErrorText,
        DetailsJson = COALESCE(@DetailsJson, DetailsJson),
        UpdatedAtUtc = SYSUTCDATETIME()
    WHERE ImportAuditBatchId = @ImportAuditBatchId;

    IF @@ROWCOUNT = 0
        THROW 51031, 'ImportAuditBatchId was not found.', 1;

    SELECT @ImportAuditBatchId AS ImportAuditBatchId;
END;
GO
