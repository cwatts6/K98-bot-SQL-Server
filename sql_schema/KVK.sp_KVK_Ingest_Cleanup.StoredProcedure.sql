SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[sp_KVK_Ingest_Cleanup]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [KVK].[sp_KVK_Ingest_Cleanup] AS' 
END
ALTER PROCEDURE [KVK].[sp_KVK_Ingest_Cleanup]
	@StageRetentionHours [int] = 24,
	@DiagnosticRetentionDays [int] = 90,
	@NegativeRetentionDays [int] = 365,
	@DryRun [bit] = 1,
	@NowUTC [datetime2](0) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @StageRetentionHours IS NULL OR @StageRetentionHours < 1
        THROW 51010, 'Stage retention must be at least 1 hour.', 1;
    IF @DiagnosticRetentionDays IS NULL OR @DiagnosticRetentionDays < 1
        THROW 51011, 'Diagnostic retention must be at least 1 day.', 1;
    IF @NegativeRetentionDays IS NULL OR @NegativeRetentionDays < 1
        THROW 51012, 'Negative diagnostic retention must be at least 1 day.', 1;

    DECLARE @EffectiveNow datetime2(0) = COALESCE(@NowUTC, SYSUTCDATETIME());
    DECLARE @StageCutoff datetime2(0) = DATEADD(hour, -@StageRetentionHours, @EffectiveNow);
    DECLARE @DiagnosticCutoff datetime2(0) = DATEADD(day, -@DiagnosticRetentionDays, @EffectiveNow);
    DECLARE @NegativeCutoff datetime2(0) = DATEADD(day, -@NegativeRetentionDays, @EffectiveNow);

    DECLARE @StageRows int = (
        SELECT COUNT(*)
        FROM KVK.KVK_AllPlayers_Stage WITH (READCOMMITTEDLOCK)
        WHERE staged_at_utc < @StageCutoff
    );
    DECLARE @DiagnosticRows int = (
        SELECT COUNT(*)
        FROM KVK.KVK_Ingest_Diagnostics WITH (READCOMMITTEDLOCK)
        WHERE CreatedUTC < @DiagnosticCutoff
    );
    DECLARE @NegativeRows int = (
        SELECT COUNT(*)
        FROM KVK.KVK_Ingest_Negatives WITH (READCOMMITTEDLOCK)
        WHERE recorded_at_utc < @NegativeCutoff
    );

    IF @DryRun = 0
    BEGIN
        BEGIN TRANSACTION;

        DELETE FROM KVK.KVK_AllPlayers_Stage
        WHERE staged_at_utc < @StageCutoff;
        SET @StageRows = @@ROWCOUNT;

        DELETE FROM KVK.KVK_Ingest_Diagnostics
        WHERE CreatedUTC < @DiagnosticCutoff;
        SET @DiagnosticRows = @@ROWCOUNT;

        DELETE FROM KVK.KVK_Ingest_Negatives
        WHERE recorded_at_utc < @NegativeCutoff;
        SET @NegativeRows = @@ROWCOUNT;

        INSERT INTO KVK.KVK_Ingest_Diagnostics
        (
            DiagnosticStatus, DiagnosticType, ErrorText, ContextJson
        )
        VALUES
        (
            'cleanup',
            N'retention_cleanup',
            N'KVK ingest retention cleanup completed.',
            CONCAT(
                N'{"stage_retention_hours":', @StageRetentionHours,
                N',"diagnostic_retention_days":', @DiagnosticRetentionDays,
                N',"negative_retention_days":', @NegativeRetentionDays,
                N',"stage_rows_deleted":', @StageRows,
                N',"diagnostic_rows_deleted":', @DiagnosticRows,
                N',"negative_rows_deleted":', @NegativeRows,
                N'}'
            )
        );

        COMMIT TRANSACTION;
    END

    SELECT
        CAST(@DryRun AS bit) AS DryRun,
        @StageCutoff AS StageCutoffUTC,
        @DiagnosticCutoff AS DiagnosticCutoffUTC,
        @NegativeCutoff AS NegativeCutoffUTC,
        @StageRows AS StaleStageRows,
        @DiagnosticRows AS StaleDiagnosticRows,
        @NegativeRows AS StaleNegativeRows;
END

