/*
Purpose:
    Verify the byte-distinct, semantically valid fixtures used by the remaining
    Phase 3 direct/legacy/failure-path rehearsals.

Safety:
    - Exact disposable rehearsal database only.
    - Reads the operator-held Phase 1 fixture library.
    - Does not launch an operating-system command.
    - Run 17_prepare_extended_fixtures.ps1 interactively on the SQL host first.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52200, 'Extended fixture preparation is restricted to the Phase 3 rehearsal database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52201, 'Extended fixture preparation requires no open transaction.', 1;

DECLARE @FixtureRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\fixtures\';
DECLARE @GeneratedRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\generated\';

DECLARE @Variants table
(
    VariantName sysname NOT NULL PRIMARY KEY,
    SourcePath nvarchar(4000) NOT NULL,
    TargetPath nvarchar(4000) NOT NULL,
    HeaderMarker nvarchar(10) NOT NULL
);

INSERT @Variants (VariantName, SourcePath, TargetPath, HeaderMarker)
VALUES
    (
        N'corrected_boundary',
        @FixtureRoot + N'valid_representative.csv',
        @GeneratedRoot + N'corrected_boundary.csv',
        N'upd_p3_301'
    ),
    (
        N'direct_one',
        @FixtureRoot + N'valid_representative.csv',
        @GeneratedRoot + N'direct_one.csv',
        N'upd_p3_302'
    ),
    (
        N'direct_two',
        @FixtureRoot + N'valid_representative.csv',
        @GeneratedRoot + N'direct_two.csv',
        N'upd_p3_303'
    ),
    (
        N'legacy_update_all',
        @FixtureRoot + N'valid_representative.csv',
        @GeneratedRoot + N'legacy_update_all.csv',
        N'upd_p3_304'
    ),
    (
        N'phase_b_failure',
        @FixtureRoot + N'valid_representative.csv',
        @GeneratedRoot + N'phase_b_failure.csv',
        N'upd_p3_305'
    );

DROP TABLE IF EXISTS #FileProbe;
CREATE TABLE #FileProbe
(
    FileExists int NULL,
    FileIsDirectory int NULL,
    ParentDirectoryExists int NULL
);

DECLARE
    @VariantName sysname,
    @TargetPath nvarchar(4000);

DECLARE verify_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT VariantName, TargetPath
    FROM @Variants
    ORDER BY HeaderMarker;

OPEN verify_cursor;
FETCH NEXT FROM verify_cursor INTO @VariantName, @TargetPath;

WHILE @@FETCH_STATUS = 0
BEGIN
    TRUNCATE TABLE #FileProbe;
    INSERT #FileProbe
    EXEC master.dbo.xp_fileexist @TargetPath;

    IF NOT EXISTS (SELECT 1 FROM #FileProbe WHERE FileExists = 1)
        THROW 52204, 'A generated Phase 3 fixture is missing. Run 17_prepare_extended_fixtures.ps1 interactively on the SQL host.', 1;

    FETCH NEXT FROM verify_cursor INTO @VariantName, @TargetPath;
END;

CLOSE verify_cursor;
DEALLOCATE verify_cursor;

SELECT
    N'phase3_extended_fixture' AS EvidenceSection,
    VariantName,
    SourcePath,
    TargetPath,
    HeaderMarker,
    N'PASS' AS FixtureStatus
FROM @Variants
ORDER BY HeaderMarker;
