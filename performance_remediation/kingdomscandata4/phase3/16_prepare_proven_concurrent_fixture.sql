USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52140, 'Proven concurrency fixture preparation is restricted to the named representative database.', 1;

DECLARE
    @FixturePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test\fixtures\valid_boundary_unicode_optional_blanks.csv',
    @ActivePath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv',
    @RejectedPath nvarchar(4000) = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\concurrency_retry_rejected_appended_blank.csv',
    @FixtureExists int = 0,
    @ActiveExists int = 0,
    @RejectedExists int = 0,
    @ReceiptCount bigint,
    @ReleasedDigest binary(32),
    @StagedDigest binary(32),
    @Command nvarchar(4000);

EXEC master.dbo.xp_fileexist @FixturePath, @FixtureExists OUTPUT;
EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;
EXEC master.dbo.xp_fileexist @RejectedPath, @RejectedExists OUTPUT;

SELECT @ReceiptCount = COUNT_BIG(*)
FROM dbo.KS4_ImportFileReceipt;

SELECT @ReleasedDigest = FileDigest
FROM dbo.KS4_ImportFileReceipt
WHERE ScanOrder = 1022
  AND ArchiveStatus = N'archived';

IF ISNULL(@FixtureExists, 0) <> 1
    THROW 52141, 'The previously accepted concurrency fixture is missing.', 1;

IF ISNULL(@ActiveExists, 0) <> 1
    THROW 52142, 'The rejected synthetic fixture is not present for preservation.', 1;

IF ISNULL(@RejectedExists, 0) <> 0
    THROW 52143, 'The rejected synthetic evidence target already exists.', 1;

IF @ReceiptCount <> 2 OR @ReleasedDigest IS NULL
    THROW 52144, 'Expected the two prior receipts including archived scan 1022.', 1;

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

SELECT @StagedDigest = HASHBYTES('SHA2_256', BulkColumn)
FROM OPENROWSET(
    BULK N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv',
    SINGLE_BLOB
) AS SourceFile;

IF @StagedDigest IS NULL OR @StagedDigest <> @ReleasedDigest
    THROW 52145, 'The staged fixture does not match the previously accepted digest.', 1;

BEGIN TRANSACTION;

DELETE FROM dbo.KS4_ImportFileReceipt
WHERE ScanOrder = 1022
  AND FileDigest = @ReleasedDigest
  AND ArchiveStatus = N'archived';

IF @@ROWCOUNT <> 1
BEGIN
    ROLLBACK TRANSACTION;
    THROW 52146, 'The prior rehearsal receipt could not be released exactly once.', 1;
END;

COMMIT TRANSACTION;

IF EXISTS (
    SELECT 1
    FROM dbo.KS4_ImportFileReceipt
    WHERE FileDigest = @StagedDigest
)
    THROW 52147, 'The accepted fixture digest remains receipted after controlled rehearsal cleanup.', 1;

SET @ActiveExists = 0;
SET @RejectedExists = 0;
EXEC master.dbo.xp_fileexist @ActivePath, @ActiveExists OUTPUT;
EXEC master.dbo.xp_fileexist @RejectedPath, @RejectedExists OUTPUT;

IF ISNULL(@ActiveExists, 0) <> 1 OR ISNULL(@RejectedExists, 0) <> 1
    THROW 52148, 'Proven concurrency fixture preparation did not reach the required file state.', 1;

SELECT
    N'phase3_proven_concurrency_fixture' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @FixturePath AS FixturePath,
    @ActivePath AS ActivePath,
    @RejectedPath AS PreservedRejectedSyntheticPath,
    CONVERT(char(64), @StagedDigest, 2) AS FileDigestSha256,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS BaselineReceiptRows,
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) AS BaselineKS4Rows,
    (SELECT MAX(ScanOrder) FROM dbo.KingdomScanData4) AS BaselineKS4MaxScan,
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) AS BaselineKS5Rows,
    (SELECT MAX(ScanOrder) FROM dbo.KingdomScanData5) AS BaselineKS5MaxScan,
    @ActiveExists AS ActiveFileExists,
    @RejectedExists AS PreservedRejectedFileExists,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
