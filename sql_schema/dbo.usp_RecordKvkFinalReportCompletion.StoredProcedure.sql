SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_RecordKvkFinalReportCompletion]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_RecordKvkFinalReportCompletion] AS' 
END
ALTER PROCEDURE [dbo].[usp_RecordKvkFinalReportCompletion]
	@KVKNo [int],
	@FinalScanOrder [int],
	@FinalizationBasis [nvarchar](24) = N'LIVE_OUTPUT',
	@FinalDataAtUtc [datetime2](0) = NULL
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

