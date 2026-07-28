/*
Prove that an unknown digest fails closed without a transaction leak or file
operation. This does not create a receipt or call xp_cmdshell.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 52000, 'Phase 3 archive rehearsal refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52001, 'Phase 3 archive rehearsal is connected to the wrong database.', 1;

DECLARE @ObservedErrorNumber int;
DECLARE @ObservedErrorMessage nvarchar(2048);

BEGIN TRY
    EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
        @FileDigest =
            0x0000000000000000000000000000000000000000000000000000000000000000;
END TRY
BEGIN CATCH
    SELECT
        @ObservedErrorNumber = ERROR_NUMBER(),
        @ObservedErrorMessage = ERROR_MESSAGE();
END CATCH;

IF @ObservedErrorNumber <> 51842
    THROW 52002, 'Phase 3 archive rehearsal did not return the expected unknown-receipt error.', 1;

IF XACT_STATE() <> 0 OR @@TRANCOUNT <> 0
    THROW 52003, 'Phase 3 archive rehearsal leaked a transaction.', 1;

SELECT
    N'phase3_archive_negative_path' AS EvidenceSection,
    @ObservedErrorNumber AS ErrorNumber,
    @ObservedErrorMessage AS ErrorMessage,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt)
        AS ReceiptRows,
    XACT_STATE() AS FinalXactState,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
