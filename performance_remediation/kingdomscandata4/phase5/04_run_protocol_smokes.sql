/*
Phase 5.0 immutable-file SQL consumer smokes.

Prerequisites:
  1. Apply the Phase 5.0 migration to an isolated representative database.
  2. Run 03_apply_test_path_override.sql.
  3. Stage valid_minimal.csv under the first two ready names, then stage
     valid_recovery.csv under the third name with
     Initialize-Phase5RehearsalFile.ps1:
       stats_00000000000000000000000000000001.ready.csv
       stats_00000000000000000000000000000002.ready.csv
       stats_00000000000000000000000000000003.ready.csv
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 52400, 'Phase 5.0 protocol smoke refuses production ROK_TRACKER.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
       NOT LIKE N'%downloads_test_phase5_rehearsal%'
    THROW 52401, 'Apply the Phase 5.0 isolated test-path override first.', 1;

DECLARE @FirstName nvarchar(260) =
    N'stats_00000000000000000000000000000001.ready.csv';
DECLARE @DuplicateName nvarchar(260) =
    N'stats_00000000000000000000000000000002.ready.csv';
DECLARE @RecoveryName nvarchar(260) =
    N'stats_00000000000000000000000000000003.ready.csv';
DECLARE @Digest binary(32);
DECLARE @ArchivePath nvarchar(4000);
DECLARE @ReturnCode int;
DECLARE @BeforeReceiptCount bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt);

EXEC @ReturnCode = dbo.IMPORT_STAGING_PROC
    @CompletedFileName = @FirstName,
    @ImportFileDigest = @Digest OUTPUT,
    @ArchivePath = @ArchivePath OUTPUT;

IF @ReturnCode <> 0 OR @Digest IS NULL
BEGIN
    DECLARE @NormalImportError nvarchar(2048) =
        CONCAT(
            N'Phase 5.0 normal immutable import failed. ',
            COALESCE(
                (
                    SELECT LastError
                    FROM dbo.KS4_ImportFileClaim
                    WHERE CompletedFileName = @FirstName
                ),
                N'The import core did not persist an error.'
            )
        );
    THROW 52402, @NormalImportError, 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim AS claim
    JOIN dbo.KS4_ImportFileReceipt AS receipt
      ON receipt.FileDigest = claim.FileDigest
     AND receipt.SourcePath = claim.ClaimedPath
     AND receipt.ArchivePath = claim.ArchivePath
    WHERE claim.CompletedFileName = @FirstName
      AND claim.ClaimStatus = N'archived'
      AND receipt.ArchiveStatus = N'archived'
)
    THROW 52403, 'Phase 5.0 normal import did not bind claim, receipt and archive.', 1;

BEGIN TRY
    EXEC dbo.IMPORT_STAGING_PROC
        @CompletedFileName = @DuplicateName,
        @ImportFileDigest = @Digest OUTPUT,
        @ArchivePath = @ArchivePath OUTPUT;

    THROW 52404, 'Phase 5.0 duplicate bytes unexpectedly allocated another import.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 51803
        THROW;
END CATCH;

IF (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> @BeforeReceiptCount + 1
    THROW 52405, 'Phase 5.0 duplicate retry changed the receipt count.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim
    WHERE CompletedFileName = @DuplicateName
      AND ClaimStatus = N'duplicate_archived'
)
    THROW 52406, 'Phase 5.0 duplicate retry did not archive deterministically.', 1;

DECLARE @RecoveryArchivePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase5_rehearsal\Import_Archive\'
    + @RecoveryName;
DECLARE @RecoveryClaimedPath nvarchar(4000);
DECLARE @CreateConflictCommand nvarchar(4000) =
    N'CMD /D /C TYPE NUL > "' + @RecoveryArchivePath + N'"';
DECLARE @DeleteConflictCommand nvarchar(4000) =
    N'CMD /D /C DEL /F /Q "' + @RecoveryArchivePath + N'"';
DECLARE @CommandResult int;

SET @Digest = NULL;
SET @ArchivePath = NULL;

EXEC dbo.CLAIM_KS4_IMPORT_FILE
    @CompletedFileName = @RecoveryName,
    @FileDigest = @Digest OUTPUT,
    @ClaimedPath = @RecoveryClaimedPath OUTPUT,
    @ArchivePath = @ArchivePath OUTPUT;

EXEC @CommandResult = master.dbo.xp_cmdshell
    @CreateConflictCommand,
    NO_OUTPUT;

IF ISNULL(@CommandResult, 1) <> 0
    THROW 52407, 'Phase 5.0 recovery smoke could not create its isolated archive conflict.', 1;

EXEC @ReturnCode = dbo.IMPORT_STAGING_PROC_CORE
    @CompletedFileName = @RecoveryName,
    @ImportFileDigest = @Digest OUTPUT,
    @ArchivePath = @ArchivePath OUTPUT;

IF @ReturnCode <> 1
    THROW 52408, 'Phase 5.0 recovery smoke did not expose the controlled archive failure.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim
    WHERE CompletedFileName = @RecoveryName
      AND ClaimStatus = N'imported'
)
    THROW 52409, 'Phase 5.0 controlled archive failure lost the committed claim.', 1;

EXEC @CommandResult = master.dbo.xp_cmdshell
    @DeleteConflictCommand,
    NO_OUTPUT;

IF ISNULL(@CommandResult, 1) <> 0
    THROW 52410, 'Phase 5.0 recovery smoke could not remove its isolated archive conflict.', 1;

EXEC @ReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
    @CompletedFileName = @RecoveryName;

IF @ReturnCode <> 0
   OR NOT EXISTS
      (
          SELECT 1
          FROM dbo.KS4_ImportFileClaim
          WHERE CompletedFileName = @RecoveryName
            AND ClaimStatus = N'archived'
      )
    THROW 52411, 'Phase 5.0 archive reconciliation did not converge.', 1;

SELECT
    N'phase5_protocol_smokes' AS EvidenceSection,
    N'PASS' AS SmokeStatus,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileClaim) AS ClaimRows,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS ReceiptRows,
    @FirstName AS NormalIdentity,
    @DuplicateName AS DuplicateIdentity,
    @RecoveryName AS RecoveryIdentity;
