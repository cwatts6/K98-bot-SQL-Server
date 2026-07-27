/*
Purpose:
    Create the dedicated Phase 3 rehearsal directories and stage the retained
    representative fixture without deleting or overwriting prior evidence.

Safety:
    - Refuses production and any database other than the exact representative.
    - Uses fixed, reviewed filesystem paths.
    - Refuses an existing active file or any existing Phase 3 archive entry.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 52030, 'Phase 3 fixture preparation refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52031, 'Phase 3 fixture preparation is connected to the wrong database.', 1;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
    THROW 52032, 'Phase 3 fixture preparation requires a sysadmin session.', 1;

IF @@TRANCOUNT <> 0
    THROW 52033, 'Phase 3 fixture preparation requires no existing transaction.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.configurations
    WHERE [name] = N'xp_cmdshell'
      AND value_in_use = 1
)
BEGIN
    THROW 52034,
        'xp_cmdshell is not enabled; do not enable it solely for this rehearsal.',
        1;
END;

DECLARE @FixturePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\fixtures\valid_representative.csv';
DECLARE @TestRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal';
DECLARE @ArchiveRoot nvarchar(4000) =
    @TestRoot + N'\Import_Archive';
DECLARE @ActivePath nvarchar(4000) =
    @TestRoot + N'\stats.csv';
DECLARE @FixtureExists int = 0;
DECLARE @ActiveExists int = 0;
DECLARE @CommandExitCode int;

EXEC master.dbo.xp_fileexist
    @FixturePath,
    @FixtureExists OUTPUT;

IF ISNULL(@FixtureExists, 0) <> 1
    THROW 52035, 'The retained representative fixture does not exist.', 1;

EXEC master.dbo.xp_fileexist
    @ActivePath,
    @ActiveExists OUTPUT;

IF ISNULL(@ActiveExists, 0) = 1
    THROW 52036, 'The Phase 3 active stats.csv already exists; no file was overwritten.', 1;

EXEC @CommandExitCode = master.dbo.xp_cmdshell
    N'CMD /D /C IF NOT EXIST "C:\discord_file_downloader\downloads_test_phase3_rehearsal" MKDIR "C:\discord_file_downloader\downloads_test_phase3_rehearsal"',
    NO_OUTPUT;

IF ISNULL(@CommandExitCode, 1) <> 0
    THROW 52037, 'Could not create the Phase 3 rehearsal root.', 1;

EXEC @CommandExitCode = master.dbo.xp_cmdshell
    N'CMD /D /C IF NOT EXIST "C:\discord_file_downloader\downloads_test_phase3_rehearsal\Import_Archive" MKDIR "C:\discord_file_downloader\downloads_test_phase3_rehearsal\Import_Archive"',
    NO_OUTPUT;

IF ISNULL(@CommandExitCode, 1) <> 0
    THROW 52038, 'Could not create the Phase 3 rehearsal archive root.', 1;

CREATE TABLE #ArchiveEntries
(
    subdirectory nvarchar(512) NULL,
    depth int NULL,
    [file] bit NULL
);

INSERT #ArchiveEntries
EXEC master.sys.xp_dirtree @ArchiveRoot, 1, 1;

IF EXISTS (SELECT 1 FROM #ArchiveEntries)
BEGIN
    SELECT *
    FROM #ArchiveEntries;

    THROW 52039,
        'The Phase 3 archive root contains retained evidence; no fixture was staged.',
        1;
END;

EXEC @CommandExitCode = master.dbo.xp_cmdshell
    N'CMD /D /C COPY /B "C:\discord_file_downloader\downloads_test\fixtures\valid_representative.csv" "C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv"',
    NO_OUTPUT;

IF ISNULL(@CommandExitCode, 1) <> 0
    THROW 52040, 'Could not stage the Phase 3 representative fixture.', 1;

SET @ActiveExists = 0;
EXEC master.dbo.xp_fileexist
    @ActivePath,
    @ActiveExists OUTPUT;

IF ISNULL(@ActiveExists, 0) <> 1
    THROW 52041, 'The staged Phase 3 fixture could not be verified.', 1;

SELECT
    N'phase3_fixture_preparation' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @FixturePath AS FixtureSource,
    @ActivePath AS ActiveFixture,
    @ArchiveRoot AS EmptyArchiveRoot,
    CONVERT(bit, @ActiveExists) AS ActiveFixtureExists,
    N'PASS' AS PreparationStatus;
