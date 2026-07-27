USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52090, 'Concurrency fixture preparation is restricted to the named representative database.', 1;

DECLARE
    @FixturePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test\fixtures\valid_boundary_unicode_optional_blanks.csv',
    @ActivePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv',
    @RejectedPath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\duplicate_replay_rejected_valid_representative.csv',
    @FixtureExists int = 0,
    @ActiveExists int = 0,
    @RejectedExists int = 0,
    @ReceiptCount bigint,
    @Command nvarchar(4000);

EXEC master.dbo.xp_fileexist @FixturePath, @FixtureExists OUTPUT;
EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;
EXEC master.dbo.xp_fileexist @RejectedPath, @RejectedExists OUTPUT;

SELECT @ReceiptCount = COUNT_BIG(*)
FROM dbo.KS4_ImportFileReceipt;

IF ISNULL(@FixtureExists, 0) <> 1
    THROW 52091, 'The second valid representative fixture is missing.', 1;

IF ISNULL(@ActiveExists, 0) <> 1
    THROW 52092, 'The rejected duplicate fixture is not present for preservation.', 1;

IF ISNULL(@RejectedExists, 0) <> 0
    THROW 52093, 'The rejected duplicate evidence target already exists.', 1;

IF @ReceiptCount <> 1
    THROW 52094, 'Expected exactly one receipt before the concurrent entry-point rehearsal.', 1;

SET @Command =
    N'cmd /d /c move /y "'
    + REPLACE(@ActivePath, N'"', N'""')
    + N'" "'
    + REPLACE(@RejectedPath, N'"', N'""')
    + N'"';
EXEC master.dbo.xp_cmdshell @Command, NO_OUTPUT;

SET @Command =
    N'cmd /d /c copy /b /y "'
    + REPLACE(@FixturePath, N'"', N'""')
    + N'" "'
    + REPLACE(@ActivePath, N'"', N'""')
    + N'"';
EXEC master.dbo.xp_cmdshell @Command, NO_OUTPUT;

SET @ActiveExists = 0;
SET @RejectedExists = 0;
EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;
EXEC master.dbo.xp_fileexist @RejectedPath, @RejectedExists OUTPUT;

IF ISNULL(@ActiveExists, 0) <> 1 OR ISNULL(@RejectedExists, 0) <> 1
    THROW 52095, 'Concurrency fixture preparation did not reach the required file state.', 1;

SELECT
    N'phase3_concurrency_fixture' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @FixturePath AS FixturePath,
    @ActivePath AS ActivePath,
    @RejectedPath AS PreservedRejectedDuplicatePath,
    @ReceiptCount AS BaselineReceiptRows,
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) AS BaselineKS4Rows,
    (SELECT MAX(ScanOrder) FROM dbo.KingdomScanData4) AS BaselineKS4MaxScan,
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) AS BaselineKS5Rows,
    (SELECT MAX(ScanOrder) FROM dbo.KingdomScanData5) AS BaselineKS5MaxScan,
    @ActiveExists AS ActiveFileExists,
    @RejectedExists AS PreservedRejectedFileExists,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
