/*
Purpose:
    Prove that source-absent/archive-present recovery verifies the destination
    digest before advancing a receipt, and remains idempotent for matching bytes.

Safety:
    - Refuses production and any database except the isolated Phase 3 rehearsal.
    - Requires the test-path override and an absent active stats.csv.
    - Uses two dedicated archive file names and receipt scan orders.
    - Removes only the files and rows created by this script.
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 52200, 'Phase 3 archive reconciliation verification refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52201, 'Phase 3 archive reconciliation verification is connected to the wrong database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52202, 'Phase 3 archive reconciliation verification requires no existing transaction.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       NOT LIKE N'%downloads_test_phase3_rehearsal%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P'))
       NOT LIKE N'%downloads_test_phase3_rehearsal%'
    THROW 52203, 'Apply the Phase 3 test-path override before archive reconciliation verification.', 1;

DECLARE @SourcePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv';
DECLARE @WrongArchivePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\Import_Archive\Stats_20990101_000000_Scan_2147483000.csv';
DECLARE @RightArchivePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\Import_Archive\Stats_20990101_000001_Scan_2147483001.csv';
DECLARE @WrongFixturePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\fixtures\valid_representative.csv';
DECLARE @RightFixturePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\fixtures\valid_boundary_unicode_optional_blanks.csv';
DECLARE @SourceExists int = 0;
DECLARE @WrongArchiveExists int = 0;
DECLARE @RightArchiveExists int = 0;
DECLARE @WrongFixtureExists int = 0;
DECLARE @RightFixtureExists int = 0;
DECLARE @WrongReceiptDigest binary(32) =
    HASHBYTES(N'SHA2_256', 0x0102030405060708);
DECLARE @RightReceiptDigest binary(32);
DECLARE @WrongObservedError int = NULL;
DECLARE @WrongObservedMessage nvarchar(2048) = NULL;
DECLARE @QuotedPathError int = NULL;
DECLARE @QuotedPathDigest binary(32);
DECLARE @RightReturnCode int = NULL;
DECLARE @Command nvarchar(4000);
DECLARE @CommandResult int;

EXEC master.dbo.xp_fileexist @SourcePath, @SourceExists OUTPUT;
EXEC master.dbo.xp_fileexist @WrongArchivePath, @WrongArchiveExists OUTPUT;
EXEC master.dbo.xp_fileexist @RightArchivePath, @RightArchiveExists OUTPUT;
EXEC master.dbo.xp_fileexist @WrongFixturePath, @WrongFixtureExists OUTPUT;
EXEC master.dbo.xp_fileexist @RightFixturePath, @RightFixtureExists OUTPUT;

IF ISNULL(@SourceExists, 0) = 1
    THROW 52204, 'The isolated active stats.csv must be absent before reconciliation verification.', 1;

IF ISNULL(@WrongArchiveExists, 0) = 1
   OR ISNULL(@RightArchiveExists, 0) = 1
    THROW 52205, 'A dedicated archive reconciliation probe file already exists.', 1;

IF ISNULL(@WrongFixtureExists, 0) <> 1
   OR ISNULL(@RightFixtureExists, 0) <> 1
    THROW 52206, 'A required archive reconciliation fixture is missing.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileReceipt
    WHERE ScanOrder IN (2147483000, 2147483001)
       OR FileDigest = @WrongReceiptDigest
)
    THROW 52207, 'A dedicated archive reconciliation probe receipt already exists.', 1;

BEGIN TRY
    BEGIN TRY
        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath =
                N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\Import_Archive\Stats_"quote_probe.csv',
            @FileDigest = @QuotedPathDigest OUTPUT;
    END TRY
    BEGIN CATCH
        SET @QuotedPathError = ERROR_NUMBER();
    END CATCH;

    IF @QuotedPathError <> 51872
        THROW 52218, 'The archive hash helper did not reject an embedded double quote before command construction.', 1;

    SET @Command =
        N'cmd /d /c copy /b /y "'
        + REPLACE(@WrongFixturePath, N'"', N'""')
        + N'" "'
        + REPLACE(@WrongArchivePath, N'"', N'""')
        + N'"';
    EXEC @CommandResult = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
    IF ISNULL(@CommandResult, 1) <> 0
        THROW 52208, 'Could not create the wrong-digest archive probe file.', 1;

    SET @Command =
        N'cmd /d /c copy /b /y "'
        + REPLACE(@RightFixturePath, N'"', N'""')
        + N'" "'
        + REPLACE(@RightArchivePath, N'"', N'""')
        + N'"';
    EXEC @CommandResult = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
    IF ISNULL(@CommandResult, 1) <> 0
        THROW 52209, 'Could not create the matching-digest archive probe file.', 1;

    SELECT @RightReceiptDigest = HASHBYTES(N'SHA2_256', BulkColumn)
    FROM OPENROWSET(
        BULK N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\Import_Archive\Stats_20990101_000001_Scan_2147483001.csv',
        SINGLE_BLOB
    ) AS archive_file;

    IF @RightReceiptDigest IS NULL
        THROW 52210, 'Could not hash the matching archive probe file.', 1;

    INSERT dbo.KS4_ImportFileReceipt
    (
        FileDigest,
        SourcePath,
        ArchivePath,
        ScanOrder,
        ScanDate,
        [RowCount],
        DatabaseCommittedAtUtc,
        ArchiveStatus,
        ArchivedAtUtc,
        LastArchiveError
    )
    VALUES
        (
            @WrongReceiptDigest,
            @SourcePath,
            @WrongArchivePath,
            2147483000,
            NULL,
            1,
            SYSUTCDATETIME(),
            N'pending',
            NULL,
            NULL
        ),
        (
            @RightReceiptDigest,
            @SourcePath,
            @RightArchivePath,
            2147483001,
            NULL,
            1,
            SYSUTCDATETIME(),
            N'pending',
            NULL,
            NULL
        );

    BEGIN TRY
        EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
            @FileDigest = @WrongReceiptDigest;
    END TRY
    BEGIN CATCH
        SELECT
            @WrongObservedError = ERROR_NUMBER(),
            @WrongObservedMessage = ERROR_MESSAGE();
    END CATCH;

    IF @WrongObservedError <> 51850
    BEGIN
        SELECT
            @WrongObservedError AS WrongObservedError,
            @WrongObservedMessage AS WrongObservedMessage;
        THROW 52211, 'Wrong archive bytes did not produce the expected reconciliation digest error.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KS4_ImportFileReceipt
        WHERE FileDigest = @WrongReceiptDigest
          AND ArchiveStatus = N'pending'
          AND ArchivedAtUtc IS NULL
          AND LastArchiveError LIKE N'%digest differs%'
    )
        THROW 52212, 'Wrong archive bytes advanced or failed to record the pending receipt error.', 1;

    EXEC @RightReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
        @FileDigest = @RightReceiptDigest;

    IF @RightReturnCode <> 0
        THROW 52213, 'Matching archive bytes did not reconcile successfully.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KS4_ImportFileReceipt
        WHERE FileDigest = @RightReceiptDigest
          AND ArchiveStatus = N'archived'
          AND ArchivedAtUtc IS NOT NULL
          AND LastArchiveError IS NULL
    )
        THROW 52214, 'Matching archive bytes did not advance the receipt exactly once.', 1;

    DELETE FROM dbo.KS4_ImportFileReceipt
    WHERE FileDigest IN (@WrongReceiptDigest, @RightReceiptDigest)
      AND ScanOrder IN (2147483000, 2147483001);

    IF @@ROWCOUNT <> 2
        THROW 52215, 'Archive reconciliation probe receipt cleanup was incomplete.', 1;

    SET @Command =
        N'cmd /d /c del /q "'
        + REPLACE(@WrongArchivePath, N'"', N'""')
        + N'" "'
        + REPLACE(@RightArchivePath, N'"', N'""')
        + N'"';
    EXEC @CommandResult = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
    IF ISNULL(@CommandResult, 1) <> 0
        THROW 52216, 'Archive reconciliation probe file cleanup was incomplete.', 1;

    EXEC master.dbo.xp_fileexist @WrongArchivePath, @WrongArchiveExists OUTPUT;
    EXEC master.dbo.xp_fileexist @RightArchivePath, @RightArchiveExists OUTPUT;

    IF ISNULL(@WrongArchiveExists, 0) = 1
       OR ISNULL(@RightArchiveExists, 0) = 1
        THROW 52217, 'Archive reconciliation probe files remain after cleanup.', 1;

    SELECT
        N'phase3_archive_reconciliation_digest' AS EvidenceSection,
        @WrongObservedError AS WrongDigestError,
        @WrongObservedMessage AS WrongDigestMessage,
        @QuotedPathError AS QuotedPathError,
        @RightReturnCode AS MatchingDigestReturnCode,
        @WrongArchiveExists AS WrongProbeExistsAfterCleanup,
        @RightArchiveExists AS RightProbeExistsAfterCleanup,
        XACT_STATE() AS FinalXactState,
        @@TRANCOUNT AS FinalTranCount,
        N'PASS' AS VerificationStatus;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DELETE FROM dbo.KS4_ImportFileReceipt
    WHERE FileDigest IN (@WrongReceiptDigest, @RightReceiptDigest)
      AND ScanOrder IN (2147483000, 2147483001);

    SET @Command =
        N'cmd /d /c del /q "'
        + REPLACE(@WrongArchivePath, N'"', N'""')
        + N'" "'
        + REPLACE(@RightArchivePath, N'"', N'""')
        + N'"';

    BEGIN TRY
        EXEC master.dbo.xp_cmdshell @Command, NO_OUTPUT;
    END TRY
    BEGIN CATCH
        -- Preserve the original verification failure.
    END CATCH;

    THROW;
END CATCH;
