/*
Purpose:
    Prove that a controlled UPDATE_ALL2 Phase-B failure leaves Phase A durable,
    archives the accepted source, records the error, restores the real
    downstream procedure, and leaks no transaction.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52230, 'Controlled Phase-B rehearsal is restricted to the Phase 3 database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52231, 'Controlled Phase-B rehearsal requires no open transaction.', 1;

DECLARE @ActivePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\stats.csv';
DECLARE @FixturePath nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\generated\phase_b_failure.csv';
DECLARE @Command nvarchar(4000) =
    N'CMD /D /C COPY /B /Y "' + @FixturePath + N'" "' + @ActivePath + N'"';
DECLARE @ExitCode int;
DECLARE @OriginalDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.CREATE_THE_AVERAGES', N'P'));
DECLARE @RestoreDefinition nvarchar(max);
DECLARE @DefinitionStart int;
DECLARE @LeadingDefinition nvarchar(80);
DECLARE @StubInstalled bit = 0;
DECLARE @ObservedErrorNumber int;
DECLARE @ObservedErrorMessage nvarchar(4000);
DECLARE @BeforeKs4Rows bigint = (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4);
DECLARE @BeforeKs5Rows bigint = (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5);
DECLARE @BeforeReceiptRows bigint = (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt);
DECLARE @BeforeReceiptScan int = (SELECT MAX(ScanOrder) FROM dbo.KS4_ImportFileReceipt);
DECLARE @StartedAtLocal datetime2(7) = SYSDATETIME();
DECLARE @StartedAtUtc datetime2(7) = SYSUTCDATETIME();

IF @OriginalDefinition IS NULL
    THROW 52232, 'CREATE_THE_AVERAGES is unavailable for the controlled failure rehearsal.', 1;

EXEC @ExitCode = master.dbo.xp_cmdshell @Command, NO_OUTPUT;
IF @ExitCode <> 0
    THROW 52233, 'Could not stage the controlled Phase-B fixture.', 1;

SET @RestoreDefinition = @OriginalDefinition;
SET @DefinitionStart = 1;
WHILE @DefinitionStart <= LEN(@RestoreDefinition)
  AND UNICODE(SUBSTRING(@RestoreDefinition, @DefinitionStart, 1))
      IN (9, 10, 13, 32, 65279)
BEGIN
    SET @DefinitionStart += 1;
END;

SET @LeadingDefinition =
    UPPER(SUBSTRING(@RestoreDefinition, @DefinitionStart, 80));
SET @LeadingDefinition =
    REPLACE(REPLACE(REPLACE(@LeadingDefinition, NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ');
WHILE CHARINDEX(N'  ', @LeadingDefinition) > 0
    SET @LeadingDefinition = REPLACE(@LeadingDefinition, N'  ', N' ');

IF LEFT(@LeadingDefinition, LEN(N'CREATE PROCEDURE')) = N'CREATE PROCEDURE'
BEGIN
    SET @RestoreDefinition =
        STUFF(@RestoreDefinition, @DefinitionStart, LEN(N'CREATE'), N'ALTER');
END;
ELSE IF LEFT(@LeadingDefinition, LEN(N'CREATE OR ALTER PROCEDURE'))
             <> N'CREATE OR ALTER PROCEDURE'
        AND LEFT(@LeadingDefinition, LEN(N'ALTER PROCEDURE'))
             <> N'ALTER PROCEDURE'
BEGIN
    THROW 52234, 'CREATE_THE_AVERAGES has an unsupported module header.', 1;
END;

BEGIN TRY
    EXEC sys.sp_executesql N'
ALTER PROCEDURE dbo.CREATE_THE_AVERAGES
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    -- K98_UPDATE_ALL2_PHASE_B_FAILURE
    THROW 51091, ''Controlled UPDATE_ALL2 Phase-B rehearsal failure.'', 1;
END;';
    SET @StubInstalled = 1;

    BEGIN TRY
        EXEC dbo.UPDATE_ALL2;
    END TRY
    BEGIN CATCH
        SET @ObservedErrorNumber = ERROR_NUMBER();
        SET @ObservedErrorMessage = ERROR_MESSAGE();
    END CATCH;

    IF @@TRANCOUNT <> 0
        ROLLBACK TRANSACTION;

    EXEC sys.sp_executesql @RestoreDefinition;
    SET @StubInstalled = 0;
END TRY
BEGIN CATCH
    DECLARE @HarnessErrorNumber int = ERROR_NUMBER();
    DECLARE @HarnessErrorMessage nvarchar(4000) = ERROR_MESSAGE();

    IF @@TRANCOUNT <> 0
        ROLLBACK TRANSACTION;

    IF @StubInstalled = 1
    BEGIN
        BEGIN TRY
            EXEC sys.sp_executesql @RestoreDefinition;
            SET @StubInstalled = 0;
        END TRY
        BEGIN CATCH
            DECLARE @RestoreError nvarchar(2048) =
                CONCAT(
                    N'Controlled Phase-B harness failed and could not restore CREATE_THE_AVERAGES: ',
                    ERROR_MESSAGE()
                );
            THROW 52235, @RestoreError, 1;
        END CATCH;
    END;

    DECLARE @HarnessError nvarchar(2048) =
        CONCAT(
            N'Controlled Phase-B harness failed before validation (',
            @HarnessErrorNumber,
            N'): ',
            @HarnessErrorMessage
        );
    THROW 52236, @HarnessError, 1;
END CATCH;

DECLARE @CommittedScan int = (SELECT MAX(ScanOrder) FROM dbo.KS4_ImportFileReceipt);
DECLARE @ArchivePath nvarchar(4000) =
    (SELECT ArchivePath FROM dbo.KS4_ImportFileReceipt WHERE ScanOrder = @CommittedScan);
DECLARE @SourceExists int = 0;
DECLARE @ArchiveExists int = 0;
DECLARE @ErrorAuditMatched bit =
    CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.ErrorAudit
        WHERE ErrorTime >= @StartedAtLocal
          AND ErrorNumber = 51091
          AND ErrorMessage = N'Controlled UPDATE_ALL2 Phase-B rehearsal failure.'
          AND AdditionalInfo LIKE N'%CurrentPhase=update_all2_create_averages%'
    )
    THEN 1 ELSE 0 END;

EXEC master.dbo.xp_fileexist @ActivePath, @SourceExists OUTPUT;
EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

IF @ObservedErrorNumber <> 51091
   OR @ObservedErrorMessage <> N'Controlled UPDATE_ALL2 Phase-B rehearsal failure.'
   OR @CommittedScan <> @BeforeReceiptScan + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> @BeforeReceiptRows + 1
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @BeforeKs4Rows + 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @BeforeKs5Rows + 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4 WHERE SCANORDER = @CommittedScan) <> 411
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5 WHERE SCANORDER = @CommittedScan) <> 411
   OR @SourceExists <> 0
   OR @ArchiveExists <> 1
   OR @ErrorAuditMatched <> 1
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.CREATE_THE_AVERAGES', N'P'))
        LIKE N'%K98_UPDATE_ALL2_PHASE_B_FAILURE%'
   OR @@TRANCOUNT <> 0
BEGIN
    THROW 52237, 'Controlled Phase-B failure did not preserve the exact durable/retry contract.', 1;
END;

SELECT
    N'controlled_phase_b_failure' AS Scenario,
    N'PASS_EXPECTED_PHASE_B_FAILURE' AS ScenarioResult,
    @ObservedErrorNumber AS ErrorNumber,
    @ObservedErrorMessage AS ErrorMessage,
    @CommittedScan AS DurableScanOrder,
    411 AS Ks4Rows,
    411 AS Ks5Rows,
    @SourceExists AS SourceExists,
    @ArchiveExists AS ArchiveExists,
    @ErrorAuditMatched AS ErrorAuditMatched,
    @@TRANCOUNT AS FinalTranCount,
    DATEDIFF_BIG(millisecond, @StartedAtUtc, SYSUTCDATETIME())
        AS ElapsedMilliseconds;
