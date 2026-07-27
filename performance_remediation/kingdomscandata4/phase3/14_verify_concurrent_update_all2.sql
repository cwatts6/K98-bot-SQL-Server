USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52120, 'Concurrency verification is restricted to the named representative database.', 1;

DECLARE
    @ActivePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv',
    @ActiveExists int = 0,
    @ArchiveExists int = 0,
    @ReceiptRows bigint,
    @ImportedScanOrder int,
    @ImportedRowCount int,
    @ArchivePath nvarchar(4000),
    @ArchiveStatus nvarchar(20),
    @KS4RowsForScan bigint,
    @KS4GovernorsForScan bigint,
    @KS5RowsForScan bigint,
    @KS5GovernorsForScan bigint;

SELECT
    @ReceiptRows = COUNT_BIG(*),
    @ImportedScanOrder = MAX(ScanOrder)
FROM dbo.KS4_ImportFileReceipt;

SELECT
    @ImportedRowCount = [RowCount],
    @ArchivePath = ArchivePath,
    @ArchiveStatus = ArchiveStatus
FROM dbo.KS4_ImportFileReceipt
WHERE ScanOrder = @ImportedScanOrder;

SELECT
    @KS4RowsForScan = COUNT_BIG(*),
    @KS4GovernorsForScan = COUNT_BIG(DISTINCT GovernorID)
FROM dbo.KingdomScanData4
WHERE ScanOrder = @ImportedScanOrder;

SELECT
    @KS5RowsForScan = COUNT_BIG(*),
    @KS5GovernorsForScan = COUNT_BIG(DISTINCT GovernorID)
FROM dbo.KingdomScanData5
WHERE ScanOrder = @ImportedScanOrder;

EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;
EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

IF @ReceiptRows <> 2 OR @ImportedScanOrder <> 1022
    THROW 52121, 'Concurrent UPDATE_ALL2 rehearsal did not create exactly one new receipt and scan.', 1;

IF @KS4RowsForScan <> @ImportedRowCount
    OR @KS4GovernorsForScan <> @ImportedRowCount
    OR @KS5RowsForScan <> @ImportedRowCount
    OR @KS5GovernorsForScan <> @ImportedRowCount
    THROW 52122, 'Concurrent UPDATE_ALL2 winner produced inconsistent per-governor rows.', 1;

IF @ArchiveStatus <> N'archived'
    OR ISNULL(@ActiveExists, 0) <> 0
    OR ISNULL(@ArchiveExists, 0) <> 1
    THROW 52123, 'Concurrent UPDATE_ALL2 winner has inconsistent source/archive disposition.', 1;

IF @@TRANCOUNT <> 0
    THROW 52124, 'Concurrency verification leaked a transaction.', 1;

SELECT
    N'phase3_concurrent_update_all2_verify' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @ReceiptRows AS ReceiptRows,
    @ImportedScanOrder AS ImportedScanOrder,
    @ImportedRowCount AS ImportedRowCount,
    @KS4RowsForScan AS KS4RowsForScan,
    @KS4GovernorsForScan AS KS4DistinctGovernors,
    @KS5RowsForScan AS KS5RowsForScan,
    @KS5GovernorsForScan AS KS5DistinctGovernors,
    @ArchiveStatus AS ArchiveStatus,
    @ActiveExists AS ActiveFileExists,
    @ArchiveExists AS ArchiveFileExists,
    @ArchivePath AS ArchivePath,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
