/*
Purpose:
    Prove invalid required-numeric rejection and a corrected retry through the
    authoritative UPDATE_ALL2 path without changing the representative shape.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52210, 'Invalid/corrected retry rehearsal is restricted to the Phase 3 database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52211, 'Invalid/corrected retry rehearsal requires no open transaction.', 1;

DECLARE @ActivePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv';
DECLARE @InvalidPath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\fixtures\invalid_required_numeric.csv';
DECLARE @CorrectedPath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\generated\corrected_boundary.csv';
DECLARE @Command nvarchar(4000);
DECLARE @ExitCode int;
DECLARE @BeforeKs4Rows bigint = (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4);
DECLARE @BeforeKs5Rows bigint = (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5);
DECLARE @BeforeKs4Scan bigint = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4);
DECLARE @BeforeKs5Scan bigint = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData5);
DECLARE @BeforeReceipts bigint = (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt);
DECLARE @InvalidErrorNumber int;
DECLARE @InvalidErrorMessage nvarchar(4000);
DECLARE @InvalidTranCount int;
DECLARE @InvalidSourceExists int = 0;

SET @Command =
    N'CMD /D /C COPY /B /Y "' + @InvalidPath + N'" "' + @ActivePath + N'"';
EXEC @ExitCode = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
IF @ExitCode <> 0
    THROW 52212, 'Could not stage the invalid required-numeric fixture.', 1;

BEGIN TRY
    EXEC dbo.UPDATE_ALL2;
END TRY
BEGIN CATCH
    SET @InvalidErrorNumber = ERROR_NUMBER();
    SET @InvalidErrorMessage = ERROR_MESSAGE();
END CATCH;

SET @InvalidTranCount = @@TRANCOUNT;
IF @@TRANCOUNT <> 0
    ROLLBACK TRANSACTION;

EXEC master.dbo.xp_fileexist @ActivePath, @InvalidSourceExists OUTPUT;

IF @InvalidErrorNumber IS NULL
   OR @InvalidErrorMessage NOT LIKE N'%IMPORT_STAGING_PROC failed (rc=1)%'
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @BeforeKs4Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @BeforeKs5Rows
   OR (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4) <> @BeforeKs4Scan
   OR (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData5) <> @BeforeKs5Scan
   OR (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> @BeforeReceipts
   OR @InvalidSourceExists <> 1
   OR @InvalidTranCount <> 0
BEGIN
    THROW 52213, 'Invalid required-numeric rehearsal did not fail closed.', 1;
END;

SELECT
    N'invalid_required_numeric' AS Scenario,
    N'PASS_EXPECTED_REJECTION' AS ScenarioResult,
    @InvalidErrorNumber AS ErrorNumber,
    @InvalidErrorMessage AS ErrorMessage,
    @BeforeKs4Scan AS UnchangedKs4Scan,
    @BeforeKs5Scan AS UnchangedKs5Scan,
    @BeforeReceipts AS UnchangedReceiptRows,
    @InvalidSourceExists AS SourceRetained,
    @InvalidTranCount AS FinalTranCount;

SET @Command =
    N'CMD /D /C COPY /B /Y "' + @CorrectedPath + N'" "' + @ActivePath + N'"';
EXEC @ExitCode = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
IF @ExitCode <> 0
    THROW 52214, 'Could not stage the corrected retry fixture.', 1;

DECLARE @CorrectedBeforeKs4Rows bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4);
DECLARE @CorrectedBeforeKs5Rows bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5);
DECLARE @CorrectedBeforeReceipts bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt);
DECLARE @CorrectedStartedAt datetime2(7) = SYSUTCDATETIME();

EXEC dbo.UPDATE_ALL2;

DECLARE @CorrectedScan int =
    (SELECT MAX(ScanOrder) FROM dbo.KS4_ImportFileReceipt);
DECLARE @ArchivePath nvarchar(4000) =
    (
        SELECT ArchivePath
        FROM dbo.KS4_ImportFileReceipt
        WHERE ScanOrder = @CorrectedScan
    );
DECLARE @CorrectedSourceExists int = 0;
DECLARE @CorrectedArchiveExists int = 0;

EXEC master.dbo.xp_fileexist @ActivePath, @CorrectedSourceExists OUTPUT;
EXEC master.dbo.xp_fileexist @ArchivePath, @CorrectedArchiveExists OUTPUT;

IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @CorrectedBeforeKs4Rows + 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @CorrectedBeforeKs5Rows + 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> @CorrectedBeforeReceipts + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4 WHERE SCANORDER = @CorrectedScan) <> 411
   OR (SELECT COUNT(DISTINCT GovernorID) FROM dbo.KingdomScanData4 WHERE SCANORDER = @CorrectedScan) <> 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5 WHERE SCANORDER = @CorrectedScan) <> 411
   OR (SELECT COUNT(DISTINCT GovernorID) FROM dbo.KingdomScanData5 WHERE SCANORDER = @CorrectedScan) <> 411
   OR @CorrectedSourceExists <> 0
   OR @CorrectedArchiveExists <> 1
   OR @@TRANCOUNT <> 0
BEGIN
    THROW 52215, 'Corrected retry did not commit the exact import contract.', 1;
END;

SELECT
    N'corrected_retry_representative_shape' AS Scenario,
    N'PASS' AS ScenarioResult,
    @CorrectedScan AS ImportedScanOrder,
    411 AS ExpectedRows,
    @CorrectedSourceExists AS SourceExists,
    @CorrectedArchiveExists AS ArchiveExists,
    @@TRANCOUNT AS FinalTranCount,
    DATEDIFF_BIG(millisecond, @CorrectedStartedAt, SYSUTCDATETIME())
        AS ElapsedMilliseconds;
