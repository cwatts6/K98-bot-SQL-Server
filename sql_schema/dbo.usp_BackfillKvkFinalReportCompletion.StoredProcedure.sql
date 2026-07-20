SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
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
END
