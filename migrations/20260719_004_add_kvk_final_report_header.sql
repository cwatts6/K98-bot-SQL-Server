/*
MigrationId: 20260719_004_add_kvk_final_report_header
Purpose: Record successful KVK final-output rebuild timestamps without duplicating KVK state logic
Author: cwatts
CreatedUtc: 2026-07-19
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A during deployment; one header row per successful future KVK output rebuild
PreValidationQuery: SELECT OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK', N'P') AS OutputProcedure, OBJECT_ID(N'dbo.v_EXCEL_FOR_KVK_All', N'V') AS OutputView;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.KVKFinalReportHeader', N'U') AS HeaderTable, OBJECT_ID(N'dbo.usp_RecordKvkFinalReportCompletion', N'P') AS Recorder, OBJECT_ID(N'dbo.usp_BackfillKvkFinalReportCompletion', N'P') AS BackfillProcedure, OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK')) AS OutputDefinition;
RelatedBotPR:
RelatedSQLPR:

Notes:
- OUTPUT_COMPLETE proves the reporting output rebuilt; it does not declare the KVK ended.
- The existing Python kvk_state resolver remains the completion authority.
- Historical completion rows are not inferred by this migration.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.KVKFinalReportHeader', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.KVKFinalReportHeader
    (
        KVK_NO int NOT NULL,
        FinalDataAtUtc datetime2(0) NOT NULL,
        FinalScanOrder int NOT NULL,
        OutputRowCount int NOT NULL,
        Revision int NOT NULL,
        State nvarchar(24) NOT NULL,
        FinalizationBasis nvarchar(24) NOT NULL,
        CONSTRAINT PK_KVKFinalReportHeader PRIMARY KEY CLUSTERED (KVK_NO),
        CONSTRAINT CK_KVKFinalReportHeader_Values CHECK
            (KVK_NO > 0 AND FinalScanOrder > 0 AND OutputRowCount > 0 AND Revision > 0),
        CONSTRAINT CK_KVKFinalReportHeader_State CHECK
            (State IN (N'OUTPUT_COMPLETE')),
        CONSTRAINT CK_KVKFinalReportHeader_Basis CHECK
            (FinalizationBasis IN (N'LIVE_OUTPUT', N'AUDIT_BACKFILL', N'INFERRED_BACKFILL'))
    );
END;
GO

IF OBJECT_ID(N'dbo.CK_KVKFinalReportHeader_Values', N'C') IS NOT NULL
    ALTER TABLE dbo.KVKFinalReportHeader
        DROP CONSTRAINT CK_KVKFinalReportHeader_Values;
GO

ALTER TABLE dbo.KVKFinalReportHeader WITH CHECK
    ADD CONSTRAINT CK_KVKFinalReportHeader_Values CHECK
        (KVK_NO > 0 AND FinalScanOrder > 0 AND OutputRowCount > 0 AND Revision > 0);
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordKvkFinalReportCompletion
    @KVKNo int,
    @FinalScanOrder int,
    @FinalizationBasis nvarchar(24) = N'LIVE_OUTPUT',
    @FinalDataAtUtc datetime2(0) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @KVKNo <= 0 OR @FinalScanOrder <= 0
        THROW 51301, 'KVK output completion requires positive KVK and scan values.', 1;
    IF @FinalizationBasis NOT IN (N'LIVE_OUTPUT', N'AUDIT_BACKFILL', N'INFERRED_BACKFILL')
        THROW 51302, 'KVK output completion received an invalid basis.', 1;

    DECLARE @OwnsTransaction bit = 0;
    DECLARE @OutputRowCount int;
    DECLARE @ExistingRevision int;

    IF @@TRANCOUNT = 0
    BEGIN
        SET @OwnsTransaction = 1;
        BEGIN TRANSACTION;
    END;

    BEGIN TRY
        SELECT @OutputRowCount = COUNT(*)
        FROM dbo.v_EXCEL_FOR_KVK_All
        WHERE KVK_NO = @KVKNo;

        IF @OutputRowCount <= 0
            THROW 51310, 'KVK output completion requires at least one final output row.', 1;

        SELECT @ExistingRevision = Revision
        FROM dbo.KVKFinalReportHeader WITH (UPDLOCK, HOLDLOCK)
        WHERE KVK_NO = @KVKNo;

        IF @ExistingRevision IS NULL
            INSERT INTO dbo.KVKFinalReportHeader
                (KVK_NO, FinalDataAtUtc, FinalScanOrder, OutputRowCount,
                 Revision, State, FinalizationBasis)
            VALUES
                (@KVKNo, COALESCE(@FinalDataAtUtc, SYSUTCDATETIME()), @FinalScanOrder,
                 @OutputRowCount, 1, N'OUTPUT_COMPLETE', @FinalizationBasis);
        ELSE
            UPDATE dbo.KVKFinalReportHeader
            SET FinalDataAtUtc = COALESCE(@FinalDataAtUtc, SYSUTCDATETIME()),
                FinalScanOrder = @FinalScanOrder,
                OutputRowCount = @OutputRowCount,
                Revision = @ExistingRevision + 1,
                State = N'OUTPUT_COMPLETE',
                FinalizationBasis = @FinalizationBasis
            WHERE KVK_NO = @KVKNo;

        IF @OwnsTransaction = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @OwnsTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_BackfillKvkFinalReportCompletion
    @KVKNo int,
    @FinalScanOrder int,
    @FinalDataAtUtc datetime2(0),
    @FinalizationBasis nvarchar(24) = N'AUDIT_BACKFILL'
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @KVKNo <= 0 OR @FinalScanOrder <= 0 OR @FinalDataAtUtc IS NULL
        THROW 51305, 'KVK completion backfill requires explicit positive KVK/scan values and an evidence timestamp.', 1;
    IF @FinalizationBasis NOT IN (N'AUDIT_BACKFILL', N'INFERRED_BACKFILL')
        THROW 51306, 'KVK completion backfill basis must be AUDIT_BACKFILL or INFERRED_BACKFILL.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.KVK_Details WHERE KVK_NO = @KVKNo)
        THROW 51307, 'KVK completion backfill could not find KVK details.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE TRY_CONVERT(int, SCANORDER) = @FinalScanOrder
    )
        THROW 51308, 'KVK completion backfill could not find the final scan order.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.v_EXCEL_FOR_KVK_All
        WHERE TRY_CONVERT(int, KVK_NO) = @KVKNo
    )
        THROW 51309, 'KVK completion backfill requires existing final output rows.', 1;

    EXEC dbo.usp_RecordKvkFinalReportCompletion
         @KVKNo = @KVKNo,
         @FinalScanOrder = @FinalScanOrder,
         @FinalizationBasis = @FinalizationBasis,
         @FinalDataAtUtc = @FinalDataAtUtc;

    SELECT KVK_NO, FinalDataAtUtc, FinalScanOrder, OutputRowCount,
           Revision, State, FinalizationBasis
    FROM dbo.KVKFinalReportHeader
    WHERE KVK_NO = @KVKNo;
END;
GO

DECLARE @OutputDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK', N'P'));
DECLARE @RefreshMarker nvarchar(300) =
    N'    EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;';
DECLARE @CompletionCall nvarchar(500) =
    @RefreshMarker + NCHAR(13) + NCHAR(10)
    + N'    EXEC dbo.usp_RecordKvkFinalReportCompletion'
    + N' @KVKNo = @KVK, @FinalScanOrder = @LatestScanToUse, @FinalizationBasis = N''LIVE_OUTPUT'';';
DECLARE @ScanCapMarker nvarchar(300) =
    N'    IF @Scan > @MaxAvailableScan SET @Scan = @MaxAvailableScan;';
DECLARE @ScanEvidenceGuard nvarchar(1000) =
    @ScanCapMarker + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10)
    + N'    IF NOT EXISTS' + NCHAR(13) + NCHAR(10)
    + N'    (' + NCHAR(13) + NCHAR(10)
    + N'        SELECT 1' + NCHAR(13) + NCHAR(10)
    + N'        FROM dbo.KingdomScanData4' + NCHAR(13) + NCHAR(10)
    + N'        WHERE ScanOrder = @Scan' + NCHAR(13) + NCHAR(10)
    + N'    )' + NCHAR(13) + NCHAR(10)
    + N'    BEGIN' + NCHAR(13) + NCHAR(10)
    + N'        RAISERROR(''sp_ExcelOutput_ByKVK: Requested final ScanOrder=%d has no source rows.'', 16, 1, @Scan);' + NCHAR(13) + NCHAR(10)
    + N'        RETURN;' + NCHAR(13) + NCHAR(10)
    + N'    END';
DECLARE @TransactionMarker nvarchar(100) =
    N'    BEGIN TRY';
DECLARE @LatestScanEvidenceGuard nvarchar(1200) =
    N'    IF NOT EXISTS' + NCHAR(13) + NCHAR(10)
    + N'    (' + NCHAR(13) + NCHAR(10)
    + N'        SELECT 1' + NCHAR(13) + NCHAR(10)
    + N'        FROM dbo.KingdomScanData4' + NCHAR(13) + NCHAR(10)
    + N'        WHERE ScanOrder = @LatestScanToUse' + NCHAR(13) + NCHAR(10)
    + N'    )' + NCHAR(13) + NCHAR(10)
    + N'    BEGIN' + NCHAR(13) + NCHAR(10)
    + N'        RAISERROR(''sp_ExcelOutput_ByKVK: Resolved final ScanOrder=%d has no source rows.'', 16, 1, @LatestScanToUse);' + NCHAR(13) + NCHAR(10)
    + N'        RETURN;' + NCHAR(13) + NCHAR(10)
    + N'    END' + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10)
    + @TransactionMarker;
DECLARE @DefinitionChanged bit = 0;

IF @OutputDefinition IS NULL
    THROW 51303, 'sp_ExcelOutput_ByKVK was not found for completion-hook deployment.', 1;

IF CHARINDEX(N'Requested final ScanOrder=%d has no source rows.', @OutputDefinition) = 0
BEGIN
    IF CHARINDEX(@ScanCapMarker, @OutputDefinition) = 0
        THROW 51311, 'sp_ExcelOutput_ByKVK scan-evidence marker was not found.', 1;
    SET @OutputDefinition = REPLACE(@OutputDefinition, @ScanCapMarker, @ScanEvidenceGuard);
    SET @DefinitionChanged = 1;
END;

IF CHARINDEX(N'Resolved final ScanOrder=%d has no source rows.', @OutputDefinition) = 0
BEGIN
    IF CHARINDEX(@TransactionMarker, @OutputDefinition) = 0
        THROW 51312, 'sp_ExcelOutput_ByKVK resolved-scan evidence marker was not found.', 1;
    SET @OutputDefinition = REPLACE(
        @OutputDefinition,
        @TransactionMarker,
        @LatestScanEvidenceGuard
    );
    SET @DefinitionChanged = 1;
END;

IF CHARINDEX(N'usp_RecordKvkFinalReportCompletion', @OutputDefinition) = 0
BEGIN
    IF CHARINDEX(@RefreshMarker, @OutputDefinition) = 0
        THROW 51304, 'sp_ExcelOutput_ByKVK completion-hook marker was not found.', 1;
    SET @OutputDefinition = REPLACE(@OutputDefinition, @RefreshMarker, @CompletionCall);
    SET @DefinitionChanged = 1;
END;

IF @DefinitionChanged = 1
BEGIN
    -- OBJECT_DEFINITION preserves the module's original CREATE/ALTER header.
    -- A CREATE header must be changed before replaying an existing procedure.
    DECLARE @CreateProcedurePosition int =
        CHARINDEX(N'CREATE PROCEDURE', UPPER(@OutputDefinition));
    DECLARE @CreateProcPosition int =
        CHARINDEX(N'CREATE PROC', UPPER(@OutputDefinition));

    IF @CreateProcedurePosition BETWEEN 1 AND 64
        SET @OutputDefinition = STUFF(
            @OutputDefinition,
            @CreateProcedurePosition,
            LEN(N'CREATE PROCEDURE'),
            N'ALTER PROCEDURE'
        );
    ELSE IF @CreateProcPosition BETWEEN 1 AND 64
        SET @OutputDefinition = STUFF(
            @OutputDefinition, @CreateProcPosition, LEN(N'CREATE PROC'), N'ALTER PROC'
        );

    EXEC sys.sp_executesql @OutputDefinition;
END;
GO
