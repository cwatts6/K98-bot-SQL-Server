SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4];

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @ExpectedSnapshot sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
DECLARE @ActiveFixture nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\stats.csv';
DECLARE @ExpectedRows bigint = 411;
DECLARE @ExpectedErrorNumber int = 51091;
DECLARE @StartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @StartedAtLocal datetime2(7) = SYSDATETIME();
DECLARE @BeforeKs4Rows bigint;
DECLARE @AfterKs4Rows bigint;
DECLARE @BeforeKs5Rows bigint;
DECLARE @AfterKs5Rows bigint;
DECLARE @BeforeKs4Scan bigint;
DECLARE @AfterKs4Scan bigint;
DECLARE @BeforeKs5Scan bigint;
DECLARE @AfterKs5Scan bigint;
DECLARE @FixturePresentBefore int = 0;
DECLARE @FixtureStillPresent int = 0;
DECLARE @ObservedErrorNumber int = NULL;
DECLARE @ObservedErrorMessage nvarchar(4000) = NULL;
DECLARE @TransactionCountAfterCall int = NULL;
DECLARE @ErrorAuditMatched bit = 0;

IF DB_NAME() <> @ExpectedDatabase
BEGIN
    THROW 51092,
        'Refusing to run the Phase-B failure test outside the guarded rehearsal database.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51092,
        'The Phase-B failure test requires a session with no open transaction.',
        1;
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.databases AS snapshot_db
    INNER JOIN sys.databases AS source_db
        ON source_db.database_id = snapshot_db.source_database_id
    WHERE snapshot_db.name = @ExpectedSnapshot
      AND snapshot_db.state_desc = N'ONLINE'
      AND source_db.name = @ExpectedDatabase
)
BEGIN
    THROW 51092,
        'The guarded pristine snapshot is not online for this rehearsal database.',
        1;
END;

IF COALESCE(
    OBJECT_DEFINITION(
        OBJECT_ID(N'dbo.CREATE_THE_AVERAGES', N'P')
    ),
    N''
) NOT LIKE N'%K98_UPDATE_ALL2_PHASE_B_FAILURE%'
BEGIN
    THROW 51092,
        'The controlled Phase-B failure is not installed.',
        1;
END;

EXEC master.dbo.xp_fileexist
    @ActiveFixture,
    @FixturePresentBefore OUTPUT;

IF @FixturePresentBefore <> 1
BEGIN
    THROW 51092,
        'The representative fixture is not present at the guarded test path.',
        1;
END;

SELECT
    @BeforeKs4Rows = COUNT_BIG(*),
    @BeforeKs4Scan = MAX(SCANORDER)
FROM dbo.KingdomScanData4;

SELECT
    @BeforeKs5Rows = COUNT_BIG(*),
    @BeforeKs5Scan = MAX(SCANORDER)
FROM dbo.KingdomScanData5;

BEGIN TRY
    EXEC dbo.UPDATE_ALL2;
END TRY
BEGIN CATCH
    SET @ObservedErrorNumber = ERROR_NUMBER();
    SET @ObservedErrorMessage = ERROR_MESSAGE();
END CATCH;

SET @TransactionCountAfterCall = @@TRANCOUNT;

IF @@TRANCOUNT <> 0
BEGIN
    ROLLBACK TRANSACTION;
END;

SELECT
    @AfterKs4Rows = COUNT_BIG(*),
    @AfterKs4Scan = MAX(SCANORDER)
FROM dbo.KingdomScanData4;

SELECT
    @AfterKs5Rows = COUNT_BIG(*),
    @AfterKs5Scan = MAX(SCANORDER)
FROM dbo.KingdomScanData5;

EXEC master.dbo.xp_fileexist
    @ActiveFixture,
    @FixtureStillPresent OUTPUT;

IF EXISTS (
    SELECT 1
    FROM dbo.ErrorAudit
    WHERE ErrorTime >= @StartedAtLocal
      AND ErrorNumber = @ExpectedErrorNumber
      AND ErrorMessage =
          N'Controlled UPDATE_ALL2 Phase-B rehearsal failure.'
      AND AdditionalInfo LIKE
          N'%CurrentPhase=update_all2_create_averages%'
)
BEGIN
    SET @ErrorAuditMatched = 1;
END;

SELECT
    N'controlled_phase_b_failure' AS Scenario,
    CASE
        WHEN @ObservedErrorNumber = @ExpectedErrorNumber
         AND @AfterKs4Rows - @BeforeKs4Rows = @ExpectedRows
         AND @AfterKs5Rows - @BeforeKs5Rows = @ExpectedRows
         AND @AfterKs4Scan = @BeforeKs4Scan + 1
         AND @AfterKs5Scan = @BeforeKs5Scan + 1
         AND @AfterKs4Scan = @AfterKs5Scan
         AND @FixtureStillPresent = 0
         AND @TransactionCountAfterCall = 0
         AND @ErrorAuditMatched = 1
        THEN N'PASS_EXPECTED_PHASE_B_FAILURE'
        ELSE N'FAIL'
    END AS ScenarioResult,
    @ObservedErrorNumber AS ErrorNumber,
    @ObservedErrorMessage AS ErrorMessage,
    @BeforeKs4Rows AS BeforeKs4Rows,
    @AfterKs4Rows AS AfterKs4Rows,
    @BeforeKs5Rows AS BeforeKs5Rows,
    @AfterKs5Rows AS AfterKs5Rows,
    @BeforeKs4Scan AS BeforeKs4Scan,
    @AfterKs4Scan AS AfterKs4Scan,
    @BeforeKs5Scan AS BeforeKs5Scan,
    @AfterKs5Scan AS AfterKs5Scan,
    @FixtureStillPresent AS FixtureStillPresent,
    @TransactionCountAfterCall AS TransactionCount,
    @ErrorAuditMatched AS ErrorAuditMatched,
    DATEDIFF_BIG(
        millisecond,
        @StartedAtUtc,
        SYSUTCDATETIME()
    ) AS ElapsedMilliseconds;
