SET NOCOUNT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4];

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @ActiveFixture nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\stats.csv';
DECLARE @RunId uniqueidentifier;
DECLARE @StartAtUtc datetime2(7);
DECLARE @BeforeKs4Rows bigint;
DECLARE @BeforeKs5Rows bigint;
DECLARE @BeforeKs4Scan bigint;
DECLARE @BeforeKs5Scan bigint;
DECLARE @AfterKs4Rows bigint;
DECLARE @AfterKs5Rows bigint;
DECLARE @AfterKs4Scan bigint;
DECLARE @AfterKs5Scan bigint;
DECLARE @Ks4RowsInNewScan bigint;
DECLARE @Ks5RowsInNewScan bigint;
DECLARE @ImportStagingRows bigint;
DECLARE @FixtureStillPresent int = 0;
DECLARE @ResultCount int;
DECLARE @SuccessCount int;
DECLARE @FailureCount int;
DECLARE @LeakedTransactionCount int;
DECLARE @CleanupRecorderAnomalyCount int;
DECLARE @StartSpreadMilliseconds bigint;
DECLARE @LosingErrorNumber int;
DECLARE @LosingErrorMessage nvarchar(4000);

IF DB_NAME() <> @ExpectedDatabase
BEGIN
    THROW 51095,
        'Refusing to collect concurrency outside the guarded rehearsal database.',
        1;
END;

SELECT
    @RunId = RunId,
    @StartAtUtc = StartAtUtc,
    @BeforeKs4Rows = BeforeKs4Rows,
    @BeforeKs5Rows = BeforeKs5Rows,
    @BeforeKs4Scan = BeforeKs4Scan,
    @BeforeKs5Scan = BeforeKs5Scan
FROM dbo.K98_UpdateAll2ConcurrencyControl
WHERE ControlId = 1;

IF @RunId IS NULL
BEGIN
    THROW 51095,
        'Concurrency preparation evidence was not found.',
        1;
END;

SELECT
    @ResultCount = COUNT(*),
    @SuccessCount = SUM(
        CASE WHEN ErrorNumber IS NULL THEN 1 ELSE 0 END
    ),
    @FailureCount = SUM(
        CASE WHEN ErrorNumber IS NOT NULL THEN 1 ELSE 0 END
    ),
    @LeakedTransactionCount = SUM(
        CASE
            WHEN TransactionCountAfterCall <> 0
              OR XactStateAfterCall <> 0
            THEN 1
            ELSE 0
        END
    ),
    @CleanupRecorderAnomalyCount = SUM(
        CASE
            WHEN TransactionCountAfterCall = 0
             AND XactStateAfterCall = 0
             AND TransactionCountAfterCleanup <> 0
            THEN 1
            ELSE 0
        END
    ),
    @StartSpreadMilliseconds = DATEDIFF_BIG(
        millisecond,
        MIN(StartedAtUtc),
        MAX(StartedAtUtc)
    )
FROM dbo.K98_UpdateAll2ConcurrencyResult
WHERE RunId = @RunId;

IF @ResultCount <> 2
BEGIN
    THROW 51095,
        'Both concurrency sessions have not recorded a result.',
        1;
END;

SELECT TOP (1)
    @LosingErrorNumber = ErrorNumber,
    @LosingErrorMessage = ErrorMessage
FROM dbo.K98_UpdateAll2ConcurrencyResult
WHERE RunId = @RunId
  AND ErrorNumber IS NOT NULL
ORDER BY SessionLabel;

SELECT
    @AfterKs4Rows = COUNT_BIG(*),
    @AfterKs4Scan = MAX(SCANORDER)
FROM dbo.KingdomScanData4;

SELECT
    @AfterKs5Rows = COUNT_BIG(*),
    @AfterKs5Scan = MAX(SCANORDER)
FROM dbo.KingdomScanData5;

SELECT @Ks4RowsInNewScan = COUNT_BIG(*)
FROM dbo.KingdomScanData4
WHERE SCANORDER = @AfterKs4Scan;

SELECT @Ks5RowsInNewScan = COUNT_BIG(*)
FROM dbo.KingdomScanData5
WHERE SCANORDER = @AfterKs5Scan;

SELECT @ImportStagingRows = COUNT_BIG(*)
FROM dbo.IMPORT_STAGING;

EXEC master.dbo.xp_fileexist
    @ActiveFixture,
    @FixtureStillPresent OUTPUT;

SELECT
    RunId,
    SessionLabel,
    SessionId,
    StartedAtUtc,
    CompletedAtUtc,
    ElapsedMilliseconds,
    ErrorNumber,
    ErrorMessage,
    TransactionCountAfterCall,
    XactStateAfterCall,
    TransactionCountAfterCleanup AS RecordedCleanupCount,
    CASE
        WHEN TransactionCountAfterCall = 0
         AND XactStateAfterCall = 0
        THEN N'CLEAN'
        ELSE N'LEAK'
    END AS PostCallTransactionState,
    CASE
        WHEN TransactionCountAfterCall = 0
         AND XactStateAfterCall = 0
         AND TransactionCountAfterCleanup <> 0
        THEN N'RUNNER_RECORDED_INSIDE_RESULT_INSERT'
        ELSE NULL
    END AS RecorderLimitation
FROM dbo.K98_UpdateAll2ConcurrencyResult
WHERE RunId = @RunId
ORDER BY SessionLabel;

SELECT
    N'concurrent_update_all2' AS Scenario,
    CASE
        WHEN @ResultCount = 2
         AND @SuccessCount = 1
         AND @FailureCount = 1
         AND @AfterKs4Rows - @BeforeKs4Rows = 411
         AND @AfterKs5Rows - @BeforeKs5Rows = 411
         AND @AfterKs4Scan = @BeforeKs4Scan + 1
         AND @AfterKs5Scan = @BeforeKs5Scan + 1
         AND @AfterKs4Scan = @AfterKs5Scan
         AND @Ks4RowsInNewScan = 411
         AND @Ks5RowsInNewScan = 411
         AND @FixtureStillPresent = 0
         AND @ImportStagingRows = 0
         AND @LeakedTransactionCount = 0
        THEN CASE
            WHEN @CleanupRecorderAnomalyCount = 0
            THEN N'PASS_SINGLE_WINNER_NO_DUPLICATE_IMPORT'
            ELSE N'PASS_WITH_CLEANUP_RECORDER_LIMITATION'
        END
        ELSE N'FAIL_CONCURRENCY_UNSAFE_OR_INCOMPLETE'
    END AS ScenarioResult,
    @RunId AS RunId,
    @StartAtUtc AS CoordinatedStartAtUtc,
    @StartSpreadMilliseconds AS StartSpreadMilliseconds,
    @SuccessCount AS SuccessfulSessions,
    @FailureCount AS FailedSessions,
    @LosingErrorNumber AS LosingErrorNumber,
    @LosingErrorMessage AS LosingErrorMessage,
    @BeforeKs4Rows AS BeforeKs4Rows,
    @AfterKs4Rows AS AfterKs4Rows,
    @BeforeKs5Rows AS BeforeKs5Rows,
    @AfterKs5Rows AS AfterKs5Rows,
    @BeforeKs4Scan AS BeforeKs4Scan,
    @AfterKs4Scan AS AfterKs4Scan,
    @BeforeKs5Scan AS BeforeKs5Scan,
    @AfterKs5Scan AS AfterKs5Scan,
    @Ks4RowsInNewScan AS Ks4RowsInNewScan,
    @Ks5RowsInNewScan AS Ks5RowsInNewScan,
    @FixtureStillPresent AS FixtureStillPresent,
    @ImportStagingRows AS ImportStagingRows,
    @LeakedTransactionCount AS LeakedTransactionSessions,
    @CleanupRecorderAnomalyCount AS CleanupRecorderAnomalySessions,
    CASE
        WHEN @CleanupRecorderAnomalyCount > 0
        THEN N'The original runner evaluated @@TRANCOUNT inside its result INSERT. TransactionCountAfterCall, XactStateAfterCall, and the session final outputs were clean.'
        ELSE NULL
    END AS RecorderLimitation,
    @@TRANCOUNT AS CollectorTransactionCount;
