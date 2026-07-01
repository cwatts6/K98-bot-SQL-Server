SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_ImportAudit_RecordPhase]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_ImportAudit_RecordPhase] AS'
END
ALTER PROCEDURE [dbo].[usp_ImportAudit_RecordPhase]
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
    DECLARE @EffectiveStartedAtUtc datetime2(3) =
        COALESCE(@StartedAtUtc, @CompletedAtUtc, SYSUTCDATETIME());
    DECLARE @EffectiveCompletedAtUtc datetime2(3) =
        CASE
            WHEN @CompletedAtUtc IS NOT NULL
                 AND @CompletedAtUtc < @EffectiveStartedAtUtc
                THEN @EffectiveStartedAtUtc
            ELSE @CompletedAtUtc
        END;

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
            @EffectiveStartedAtUtc, @EffectiveCompletedAtUtc,
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
END
