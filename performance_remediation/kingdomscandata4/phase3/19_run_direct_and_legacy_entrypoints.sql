/*
Purpose:
    Prove two standalone IMPORT_STAGING_PROC allocations, the legacy
    FIX_IMPORT_STAGING allocator, and the legacy UPDATE_ALL writer.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52220, 'Direct/legacy rehearsal is restricted to the Phase 3 database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52221, 'Direct/legacy rehearsal requires no open transaction.', 1;

DECLARE @ActivePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv';
DECLARE @GeneratedRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\generated\';
DECLARE @Command nvarchar(4000);
DECLARE @ExitCode int;
DECLARE @ImportReturnCode int;
DECLARE @Digest binary(32);
DECLARE @ArchivePath nvarchar(4000);
DECLARE @BeforeKs4Rows bigint;
DECLARE @BeforeKs5Rows bigint;
DECLARE @BeforeReceipts bigint;
DECLARE @BeforeReceiptScan int;
DECLARE @AllocatedScan int;
DECLARE @SourceExists int;
DECLARE @ArchiveExists int;

/* Standalone direct import 1. */
SELECT
    @BeforeKs4Rows = COUNT_BIG(*)
FROM dbo.KingdomScanData4;
SELECT
    @BeforeKs5Rows = COUNT_BIG(*)
FROM dbo.KingdomScanData5;
SELECT
    @BeforeReceipts = COUNT_BIG(*),
    @BeforeReceiptScan = MAX(ScanOrder)
FROM dbo.KS4_ImportFileReceipt;

SET @Command =
    N'CMD /D /C COPY /B /Y "' + @GeneratedRoot
    + N'direct_one.csv" "' + @ActivePath + N'"';
EXEC @ExitCode = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
IF @ExitCode <> 0
    THROW 52222, 'Could not stage direct fixture one.', 1;

SET @Digest = NULL;
SET @ArchivePath = NULL;
EXEC @ImportReturnCode = dbo.IMPORT_STAGING_PROC
    @ImportFileDigest = @Digest OUTPUT,
    @ArchivePath = @ArchivePath OUTPUT;

SET @AllocatedScan =
    (SELECT ScanOrder FROM dbo.KS4_ImportFileReceipt WHERE FileDigest = @Digest);
SET @SourceExists = 0;
SET @ArchiveExists = 0;
EXEC master.dbo.xp_fileexist @ActivePath, @SourceExists OUTPUT;
EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

IF @ImportReturnCode <> 0
   OR @AllocatedScan IS NULL
   OR @AllocatedScan <= ISNULL(@BeforeReceiptScan, 0)
   OR (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> @BeforeReceipts + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @BeforeKs4Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @BeforeKs5Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.IMPORT_STAGING WHERE SCANORDER = @AllocatedScan) <> 411
   OR (SELECT COUNT(DISTINCT [Governor ID]) FROM dbo.IMPORT_STAGING WHERE SCANORDER = @AllocatedScan) <> 411
   OR @SourceExists <> 0
   OR @ArchiveExists <> 1
   OR @@TRANCOUNT <> 0
BEGIN
    THROW 52223, 'Standalone direct import one did not satisfy its receipt/staging contract.', 1;
END;

SELECT
    N'direct_import_one' AS Scenario,
    N'PASS' AS ScenarioResult,
    @AllocatedScan AS AllocatedScanOrder,
    411 AS StagedRows,
    @SourceExists AS SourceExists,
    @ArchiveExists AS ArchiveExists,
    @@TRANCOUNT AS FinalTranCount;

/* Standalone direct import 2 proves allocation above receipt-only history. */
SET @BeforeReceipts = (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt);
SET @BeforeReceiptScan = (SELECT MAX(ScanOrder) FROM dbo.KS4_ImportFileReceipt);
SET @Command =
    N'CMD /D /C COPY /B /Y "' + @GeneratedRoot
    + N'direct_two.csv" "' + @ActivePath + N'"';
EXEC @ExitCode = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
IF @ExitCode <> 0
    THROW 52224, 'Could not stage direct fixture two.', 1;

SET @Digest = NULL;
SET @ArchivePath = NULL;
EXEC @ImportReturnCode = dbo.IMPORT_STAGING_PROC
    @ImportFileDigest = @Digest OUTPUT,
    @ArchivePath = @ArchivePath OUTPUT;

SET @AllocatedScan =
    (SELECT ScanOrder FROM dbo.KS4_ImportFileReceipt WHERE FileDigest = @Digest);
SET @SourceExists = 0;
SET @ArchiveExists = 0;
EXEC master.dbo.xp_fileexist @ActivePath, @SourceExists OUTPUT;
EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

IF @ImportReturnCode <> 0
   OR @AllocatedScan <> @BeforeReceiptScan + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> @BeforeReceipts + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.IMPORT_STAGING WHERE SCANORDER = @AllocatedScan) <> 411
   OR (SELECT COUNT(DISTINCT [Governor ID]) FROM dbo.IMPORT_STAGING WHERE SCANORDER = @AllocatedScan) <> 411
   OR @SourceExists <> 0
   OR @ArchiveExists <> 1
   OR @@TRANCOUNT <> 0
BEGIN
    THROW 52225, 'Standalone direct import two did not allocate above receipt-only history.', 1;
END;

SELECT
    N'direct_import_two_receipt_maximum' AS Scenario,
    N'PASS' AS ScenarioResult,
    @BeforeReceiptScan AS PriorReceiptScanOrder,
    @AllocatedScan AS AllocatedScanOrder,
    411 AS StagedRows,
    @@TRANCOUNT AS FinalTranCount;

/* Legacy staging repair must also allocate above the receipt ledger. */
SET @BeforeReceiptScan = (SELECT MAX(ScanOrder) FROM dbo.KS4_ImportFileReceipt);
SET @BeforeReceipts = (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt);
SET @BeforeKs4Rows = (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4);
SET @BeforeKs5Rows = (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5);

EXEC dbo.FIX_IMPORT_STAGING;

SET @AllocatedScan = (SELECT MAX(SCANORDER) FROM dbo.IMPORT_STAGING);

IF @AllocatedScan <> @BeforeReceiptScan + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.IMPORT_STAGING WHERE SCANORDER = @AllocatedScan) <> 411
   OR (SELECT COUNT(DISTINCT [Governor ID]) FROM dbo.IMPORT_STAGING WHERE SCANORDER = @AllocatedScan) <> 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> @BeforeReceipts
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @BeforeKs4Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @BeforeKs5Rows
   OR @@TRANCOUNT <> 0
BEGIN
    THROW 52226, 'FIX_IMPORT_STAGING did not allocate above all durable scan owners.', 1;
END;

SELECT
    N'legacy_fix_import_staging' AS Scenario,
    N'PASS' AS ScenarioResult,
    @BeforeReceiptScan AS PriorReceiptScanOrder,
    @AllocatedScan AS RepairedStagingScanOrder,
    411 AS StagedRows,
    @@TRANCOUNT AS FinalTranCount;

/* Legacy full writer. */
SET @BeforeReceipts = (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt);
SET @BeforeReceiptScan = (SELECT MAX(ScanOrder) FROM dbo.KS4_ImportFileReceipt);
SET @BeforeKs4Rows = (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4);
SET @BeforeKs5Rows = (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5);
SET @Command =
    N'CMD /D /C COPY /B /Y "' + @GeneratedRoot
    + N'legacy_update_all.csv" "' + @ActivePath + N'"';
EXEC @ExitCode = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
IF @ExitCode <> 0
    THROW 52227, 'Could not stage the legacy UPDATE_ALL fixture.', 1;

EXEC dbo.UPDATE_ALL;

SET @AllocatedScan = (SELECT MAX(ScanOrder) FROM dbo.KS4_ImportFileReceipt);
SET @ArchivePath =
    (SELECT ArchivePath FROM dbo.KS4_ImportFileReceipt WHERE ScanOrder = @AllocatedScan);
SET @SourceExists = 0;
SET @ArchiveExists = 0;
EXEC master.dbo.xp_fileexist @ActivePath, @SourceExists OUTPUT;
EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

IF @AllocatedScan <> @BeforeReceiptScan + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> @BeforeReceipts + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @BeforeKs4Rows + 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @BeforeKs5Rows + 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4 WHERE SCANORDER = @AllocatedScan) <> 411
   OR (SELECT COUNT(DISTINCT GovernorID) FROM dbo.KingdomScanData4 WHERE SCANORDER = @AllocatedScan) <> 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5 WHERE SCANORDER = @AllocatedScan) <> 411
   OR (SELECT COUNT(DISTINCT GovernorID) FROM dbo.KingdomScanData5 WHERE SCANORDER = @AllocatedScan) <> 411
   OR @SourceExists <> 0
   OR @ArchiveExists <> 1
   OR @@TRANCOUNT <> 0
BEGIN
    THROW 52228, 'Legacy UPDATE_ALL did not satisfy its durable import contract.', 1;
END;

SELECT
    N'legacy_update_all' AS Scenario,
    N'PASS' AS ScenarioResult,
    @AllocatedScan AS ImportedScanOrder,
    411 AS Ks4Rows,
    411 AS Ks5Rows,
    @SourceExists AS SourceExists,
    @ArchiveExists AS ArchiveExists,
    @@TRANCOUNT AS FinalTranCount;
