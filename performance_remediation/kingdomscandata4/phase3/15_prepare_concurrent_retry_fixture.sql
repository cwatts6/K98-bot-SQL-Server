USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52130, 'Concurrency retry fixture preparation is restricted to the named representative database.', 1;

DECLARE
    @FixturePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test\fixtures\valid_representative.csv',
    @ActivePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv',
    @FixtureExists int = 0,
    @ActiveExists int = 0,
    @ReceiptCount bigint,
    @FileDigest binary(32),
    @Command nvarchar(4000);

EXEC master.dbo.xp_fileexist @FixturePath, @FixtureExists OUTPUT;
EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;

SELECT @ReceiptCount = COUNT_BIG(*)
FROM dbo.KS4_ImportFileReceipt;

IF ISNULL(@FixtureExists, 0) <> 1
    THROW 52131, 'The representative fixture is missing.', 1;

IF ISNULL(@ActiveExists, 0) <> 0
    THROW 52132, 'The isolated Phase 3 active stats.csv already exists.', 1;

IF @ReceiptCount <> 2
    THROW 52133, 'Expected exactly two receipts before the clean concurrency retry.', 1;

SET @Command =
    N'cmd /d /c copy /b /y "'
    + REPLACE(@FixturePath, N'"', N'""')
    + N'" "'
    + REPLACE(@ActivePath, N'"', N'""')
    + N'"';
EXEC master.dbo.xp_cmdshell @Command, NO_OUTPUT;

SET @Command =
    N'cmd /d /c echo.>>"'
    + REPLACE(@ActivePath, N'"', N'""')
    + N'"';
EXEC master.dbo.xp_cmdshell @Command, NO_OUTPUT;

EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;

IF ISNULL(@ActiveExists, 0) <> 1
    THROW 52134, 'The concurrency retry fixture was not staged.', 1;

SELECT @FileDigest = HASHBYTES('SHA2_256', BulkColumn)
FROM OPENROWSET(
    BULK N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv',
    SINGLE_BLOB
) AS SourceFile;

IF @FileDigest IS NULL
    THROW 52135, 'The concurrency retry fixture digest could not be calculated.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.KS4_ImportFileReceipt
    WHERE FileDigest = @FileDigest
)
    THROW 52136, 'The concurrency retry fixture digest is not new.', 1;

SELECT
    N'phase3_concurrency_retry_fixture' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @FixturePath AS FixturePath,
    @ActivePath AS ActivePath,
    CONVERT(char(64), @FileDigest, 2) AS FileDigestSha256,
    @ReceiptCount AS BaselineReceiptRows,
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) AS BaselineKS4Rows,
    (SELECT MAX(ScanOrder) FROM dbo.KingdomScanData4) AS BaselineKS4MaxScan,
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) AS BaselineKS5Rows,
    (SELECT MAX(ScanOrder) FROM dbo.KingdomScanData5) AS BaselineKS5MaxScan,
    @ActiveExists AS ActiveFileExists,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
