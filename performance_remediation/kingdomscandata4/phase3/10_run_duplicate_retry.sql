USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52080, 'Duplicate replay rehearsal is restricted to the named representative database.', 1;

DECLARE
    @ActivePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv',
    @ActiveExistsBefore int = 0,
    @ActiveExistsAfter int = 0,
    @BeforeKS4Rows bigint,
    @AfterKS4Rows bigint,
    @BeforeKS5Rows bigint,
    @AfterKS5Rows bigint,
    @BeforeKS4MaxScan int,
    @AfterKS4MaxScan int,
    @BeforeKS5MaxScan int,
    @AfterKS5MaxScan int,
    @BeforeReceiptRows bigint,
    @AfterReceiptRows bigint,
    @BeforeStagingRows bigint,
    @AfterStagingRows bigint,
    @CaughtErrorNumber int = NULL,
    @CaughtErrorMessage nvarchar(4000) = NULL;

EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExistsBefore OUTPUT;

SELECT
    @BeforeKS4Rows = COUNT_BIG(*),
    @BeforeKS4MaxScan = MAX(ScanOrder)
FROM dbo.KingdomScanData4;

SELECT
    @BeforeKS5Rows = COUNT_BIG(*),
    @BeforeKS5MaxScan = MAX(ScanOrder)
FROM dbo.KingdomScanData5;

SELECT @BeforeReceiptRows = COUNT_BIG(*)
FROM dbo.KS4_ImportFileReceipt;

SELECT @BeforeStagingRows = COUNT_BIG(*)
FROM dbo.IMPORT_STAGING;

IF ISNULL(@ActiveExistsBefore, 0) <> 1
    THROW 52081, 'The duplicate stats.csv fixture is not staged.', 1;

BEGIN TRY
    EXEC dbo.UPDATE_ALL2;
END TRY
BEGIN CATCH
    SELECT
        @CaughtErrorNumber = ERROR_NUMBER(),
        @CaughtErrorMessage = ERROR_MESSAGE();
END CATCH;

EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExistsAfter OUTPUT;

SELECT
    @AfterKS4Rows = COUNT_BIG(*),
    @AfterKS4MaxScan = MAX(ScanOrder)
FROM dbo.KingdomScanData4;

SELECT
    @AfterKS5Rows = COUNT_BIG(*),
    @AfterKS5MaxScan = MAX(ScanOrder)
FROM dbo.KingdomScanData5;

SELECT @AfterReceiptRows = COUNT_BIG(*)
FROM dbo.KS4_ImportFileReceipt;

SELECT @AfterStagingRows = COUNT_BIG(*)
FROM dbo.IMPORT_STAGING;

IF @CaughtErrorNumber IS NULL
    THROW 52082, 'Duplicate replay unexpectedly succeeded.', 1;

IF @CaughtErrorMessage NOT LIKE N'%IMPORT_STAGING_PROC failed (rc=1)%'
    THROW 52083, 'Duplicate replay returned an unexpected error.', 1;

IF @BeforeKS4Rows <> @AfterKS4Rows
    OR ISNULL(@BeforeKS4MaxScan, -1) <> ISNULL(@AfterKS4MaxScan, -1)
    OR @BeforeKS5Rows <> @AfterKS5Rows
    OR ISNULL(@BeforeKS5MaxScan, -1) <> ISNULL(@AfterKS5MaxScan, -1)
    OR @BeforeReceiptRows <> @AfterReceiptRows
    OR @BeforeStagingRows <> @AfterStagingRows
    THROW 52084, 'Duplicate replay changed protected database state.', 1;

IF ISNULL(@ActiveExistsAfter, 0) <> 1
    THROW 52085, 'Duplicate replay moved or removed the active fixture.', 1;

IF @@TRANCOUNT <> 0
    THROW 52086, 'Duplicate replay leaked a transaction.', 1;

SELECT
    N'phase3_duplicate_retry' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @CaughtErrorNumber AS CaughtErrorNumber,
    @CaughtErrorMessage AS CaughtErrorMessage,
    @BeforeKS4Rows AS KS4Rows,
    @BeforeKS4MaxScan AS KS4MaxScan,
    @BeforeKS5Rows AS KS5Rows,
    @BeforeKS5MaxScan AS KS5MaxScan,
    @BeforeReceiptRows AS ReceiptRows,
    @BeforeStagingRows AS StagingRows,
    @ActiveExistsAfter AS ActiveFileStillExists,
    XACT_STATE() AS FinalXactState,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
