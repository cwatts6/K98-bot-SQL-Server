USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52070, 'Duplicate replay fixture preparation is restricted to the named representative database.', 1;

DECLARE
    @FixturePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test\fixtures\valid_representative.csv',
    @ActivePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv',
    @FixtureExists int = 0,
    @ActiveExists int = 0,
    @ReceiptCount bigint,
    @Command nvarchar(4000);

EXEC master.dbo.xp_fileexist @FixturePath, @FixtureExists OUTPUT;
EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;

SELECT @ReceiptCount = COUNT_BIG(*)
FROM dbo.KS4_ImportFileReceipt
WHERE ArchiveStatus = N'archived';

IF ISNULL(@FixtureExists, 0) <> 1
    THROW 52071, 'The immutable representative fixture is missing.', 1;

IF ISNULL(@ActiveExists, 0) <> 0
    THROW 52072, 'The isolated Phase 3 active stats.csv already exists.', 1;

IF @ReceiptCount <> 1
    THROW 52073, 'Expected exactly one archived Phase 3 receipt before duplicate replay.', 1;

SET @Command =
    N'cmd /d /c copy /b /y "'
    + REPLACE(@FixturePath, N'"', N'""')
    + N'" "'
    + REPLACE(@ActivePath, N'"', N'""')
    + N'"';

EXEC master.dbo.xp_cmdshell @Command, NO_OUTPUT;

SET @ActiveExists = 0;
EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;

IF ISNULL(@ActiveExists, 0) <> 1
    THROW 52074, 'The duplicate replay fixture was not staged.', 1;

SELECT
    N'phase3_duplicate_fixture' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @FixturePath AS FixturePath,
    @ActivePath AS ActivePath,
    @ReceiptCount AS ArchivedReceiptCount,
    @ActiveExists AS ActiveFileExists,
    XACT_STATE() AS FinalXactState,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
