/*
Purpose:
    Controlled, repeatable before/after performance baseline for the
    dbo.KingdomScanData4 remediation.

Safety:
    - Refuses to run in the production database named ROK_TRACKER.
    - Requires the current database to match @ExpectedTestDatabase.
    - Never clears procedure, buffer, or Query Store caches.
    - Read workloads materialize complete results into local temporary tables.
    - SUMMARY_PROC, selected component procedures, and Refresh_PlayerScanMeta
      run inside an outer transaction and are rolled back after every run.
    - Full-history summary benchmarks are independently opt-in because each
      suite can run for tens of minutes on the representative restored copy.
    - UPDATE_ALL2 is a separate committed end-to-end benchmark. It is disabled
      unless @UpdateAll2RunOrdinal and @ConfirmDurableUpdateAll2Database are
      explicitly set. Run each ordinal against a freshly restored copy.

Run protocol:
    1. Restore the same representative backup for every before/after series.
    2. Leave @MeasuredRunCount at 5: run 0 is warm-up; runs 1-5 are measured.
    3. Run the normal rollback-isolated suite once with
       @RunStandardSuite = 1. Full-history SUMMARY_PROC and standalone
       component benchmarks are skipped unless their explicit flags are set.
       The completed pre-remediation .rpt already supplies those heavy-path
       baselines. Enable the flags only for a deliberate comparable rerun.
    4. For UPDATE_ALL2, restore a fresh copy and run this script six times:
         @UpdateAll2RunOrdinal = 0  -- warm-up
         @UpdateAll2RunOrdinal = 1 through 5
       Set @ConfirmDurableUpdateAll2Database to the exact test database name.
       Set @ConfirmIsolatedUpdateAll2Fixture = 1 only after the restored
       database's IMPORT_STAGING_PROC points to a disposable test CSV and test
       archive path. The script rejects the repository's live hard-coded path.
       Set @RunStandardSuite = 0 so only UPDATE_ALL2 runs on each fresh copy.
    5. Save Results to File as an .rpt. UPDATE_ALL2 returns its own two audit
       result sets before this script's normalized result sets.

Interpretation:
    - Reads is the current-request DMV physical-read counter.
    - LogicalReads, Writes, and CpuMs are current-request counter deltas.
    - Log usage is for the current test database.
    - tempdb usage is instance-wide and can be affected by concurrent sessions;
      run on an otherwise quiet instance.
    - SHA-256 comparison digests are deterministic and order-independent for
      view materializations. Procedure digests use explicit stable ordering.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 30000;

/* Operator settings. */
DECLARE @ExpectedTestDatabase sysname = N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @CommittedUpdateAll2Database sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK';
DECLARE @MeasuredRunCount tinyint = 5;
DECLARE @RunStandardSuite bit = 1;
DECLARE @RunRollbackIsolatedWriters bit = 1;
DECLARE @RunFullHistorySummaryEndToEnd bit = 0;
DECLARE @RunFullHistorySummaryComponents bit = 0;
DECLARE @EmitProgressMessages bit = 1;

/*
NULL disables the committed UPDATE_ALL2 benchmark.
Use 0 for its warm-up or 1-5 for a measured run, once per fresh restore.
*/
DECLARE @UpdateAll2RunOrdinal tinyint = NULL;
DECLARE @ConfirmDurableUpdateAll2Database sysname = NULL;
DECLARE @ConfirmIsolatedUpdateAll2Fixture bit = 0;
DECLARE @ExpectedUpdateAll2PreKs4Rows bigint = 394506;
DECLARE @ExpectedUpdateAll2PreKs5Rows bigint = 394526;
DECLARE @ExpectedUpdateAll2PreMaxScan bigint = 1020;
DECLARE @ExpectedUpdateAll2ImportedRows bigint = 411;
DECLARE @CommittedImportHarnessRevision nvarchar(32) = N'20260724.3';
DECLARE @RequiredCurrentDatabase sysname =
    CASE
        WHEN @UpdateAll2RunOrdinal IS NULL
            THEN @ExpectedTestDatabase
        ELSE @CommittedUpdateAll2Database
    END;

/* Immutable safety checks. */
IF DB_NAME() = N'ROK_TRACKER'
BEGIN
    THROW 51040,
        'Safety stop: 04_run_controlled_baseline.sql refuses to run in production ROK_TRACKER.',
        1;
END;

IF DB_NAME() <> @RequiredCurrentDatabase
BEGIN
    DECLARE @WrongDatabaseMessage nvarchar(2048) =
        CONCAT(
            N'Safety stop: connected database is ',
            QUOTENAME(DB_NAME()),
            N', but this run requires ',
            QUOTENAME(@RequiredCurrentDatabase),
            N'.'
        );
    THROW 51041, @WrongDatabaseMessage, 1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51042,
        'Safety stop: run the benchmark with no existing user transaction.',
        1;
END;

IF @MeasuredRunCount <> 5
BEGIN
    THROW 51043,
        'This controlled baseline requires exactly five measured runs.',
        1;
END;

IF @UpdateAll2RunOrdinal IS NOT NULL
   AND @UpdateAll2RunOrdinal NOT BETWEEN 0 AND 5
BEGIN
    THROW 51044,
        '@UpdateAll2RunOrdinal must be NULL, warm-up 0, or measured run 1 through 5.',
        1;
END;

IF @UpdateAll2RunOrdinal IS NOT NULL
   AND ISNULL(@ConfirmDurableUpdateAll2Database, N'') <> DB_NAME()
BEGIN
    THROW 51045,
        'UPDATE_ALL2 requires @ConfirmDurableUpdateAll2Database to equal the current test database.',
        1;
END;

IF @UpdateAll2RunOrdinal IS NOT NULL
   AND @ConfirmIsolatedUpdateAll2Fixture <> 1
BEGIN
    THROW 51048,
        'UPDATE_ALL2 requires explicit confirmation of an isolated disposable CSV fixture.',
        1;
END;

IF @UpdateAll2RunOrdinal IS NOT NULL
   AND
   (
       @RunStandardSuite <> 0
       OR @RunRollbackIsolatedWriters <> 0
       OR @RunFullHistorySummaryEndToEnd <> 0
       OR @RunFullHistorySummaryComponents <> 0
   )
BEGIN
    THROW 51046,
        'UPDATE_ALL2 ordinals must run alone: disable the standard and rollback-isolated suites.',
        1;
END;

IF @UpdateAll2RunOrdinal IS NOT NULL
   AND EXISTS
   (
       SELECT 1
       FROM sys.databases
       WHERE source_database_id = DB_ID()
   )
BEGIN
    THROW 51047,
        'UPDATE_ALL2 performance safety stop: a database snapshot still references this restored copy.',
        1;
END;

IF @UpdateAll2RunOrdinal IS NOT NULL
   AND
   (
       OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P') IS NULL
       OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'))
            LIKE N'%C:\discord_file_downloader\downloads\stats.csv%'
       OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'))
            NOT LIKE N'%C:\discord_file_downloader\downloads_test\stats.csv%'
   )
BEGIN
    THROW 51049,
        'UPDATE_ALL2 safety stop: IMPORT_STAGING_PROC is missing or still references the live stats.csv path.',
        1;
END;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
BEGIN
    THROW 51050,
        'Required table dbo.KingdomScanData4 is missing from the test database.',
        1;
END;

/*
Allow an operator to rerun the harness in the same SSMS session after a
compile/runtime failure. These names are owned exclusively by this script.
*/
DROP TABLE IF EXISTS #BenchmarkResults;
DROP TABLE IF EXISTS #DateStats;
DROP TABLE IF EXISTS #GovernorStats;
DROP TABLE IF EXISTS #MaterializedView;
DROP TABLE IF EXISTS #ProcedureResult;
DROP TABLE IF EXISTS #ScanStats;
DROP TABLE IF EXISTS #Workloads;

DECLARE @BenchmarkRunId uniqueidentifier = NEWID();
DECLARE @CollectedAtUtc datetime2(7) = SYSUTCDATETIME();

/* Automatically select reproducible representative values. */
CREATE TABLE #GovernorStats
(
    GovernorID bigint NOT NULL PRIMARY KEY,
    ObservationCount bigint NOT NULL,
    DistinctScanCount bigint NOT NULL,
    FirstAsOfDate date NULL,
    LastAsOfDate date NULL
);

INSERT #GovernorStats
(
    GovernorID,
    ObservationCount,
    DistinctScanCount,
    FirstAsOfDate,
    LastAsOfDate
)
SELECT
    TRY_CONVERT(bigint, source.GovernorID),
    COUNT_BIG(*),
    COUNT_BIG(DISTINCT TRY_CONVERT(bigint, source.SCANORDER)),
    MIN(source.AsOfDate),
    MAX(source.AsOfDate)
FROM dbo.KingdomScanData4 AS source
WHERE TRY_CONVERT(bigint, source.GovernorID) IS NOT NULL
  AND TRY_CONVERT(bigint, source.GovernorID) > 0
GROUP BY TRY_CONVERT(bigint, source.GovernorID);

IF NOT EXISTS (SELECT 1 FROM #GovernorStats)
BEGIN
    THROW 51051,
        'No positive, bigint-convertible GovernorID values are available for benchmark selection.',
        1;
END;

DECLARE
    @SparseGovernorID bigint,
    @MedianGovernorID bigint,
    @HighActivityGovernorID bigint,
    @AbsentGovernorID bigint;

SELECT TOP (1)
    @SparseGovernorID = GovernorID
FROM #GovernorStats
ORDER BY ObservationCount, GovernorID;

;WITH RankedGovernors AS
(
    SELECT
        GovernorID,
        ROW_NUMBER() OVER (ORDER BY ObservationCount, GovernorID) AS RowNumber,
        COUNT_BIG(*) OVER () AS GovernorCount
    FROM #GovernorStats
)
SELECT
    @MedianGovernorID = GovernorID
FROM RankedGovernors
WHERE RowNumber = (GovernorCount + 1) / 2;

SELECT TOP (1)
    @HighActivityGovernorID = GovernorID
FROM #GovernorStats
ORDER BY ObservationCount DESC, GovernorID;

SELECT
    @AbsentGovernorID =
        CASE
            WHEN MAX(GovernorID) < 9223372036854775807
                THEN MAX(GovernorID) + 1
            ELSE 1
        END
FROM #GovernorStats;

WHILE EXISTS
(
    SELECT 1
    FROM #GovernorStats
    WHERE GovernorID = @AbsentGovernorID
)
BEGIN
    SET @AbsentGovernorID -= 1;
END;

CREATE TABLE #ScanStats
(
    ScanOrder bigint NOT NULL PRIMARY KEY,
    ObservationCount bigint NOT NULL,
    ScanAsOfDate date NULL
);

INSERT #ScanStats (ScanOrder, ObservationCount, ScanAsOfDate)
SELECT
    TRY_CONVERT(bigint, source.SCANORDER),
    COUNT_BIG(*),
    MAX(source.AsOfDate)
FROM dbo.KingdomScanData4 AS source
WHERE TRY_CONVERT(bigint, source.SCANORDER) IS NOT NULL
GROUP BY TRY_CONVERT(bigint, source.SCANORDER);

DECLARE
    @EarliestScanOrder bigint,
    @HistoricalScanOrder bigint,
    @LatestScanOrder bigint;

SELECT @EarliestScanOrder = MIN(ScanOrder),
       @LatestScanOrder = MAX(ScanOrder)
FROM #ScanStats;

;WITH RankedScans AS
(
    SELECT
        ScanOrder,
        ROW_NUMBER() OVER (ORDER BY ScanOrder) AS RowNumber,
        COUNT_BIG(*) OVER () AS ScanCount
    FROM #ScanStats
)
SELECT
    @HistoricalScanOrder = ScanOrder
FROM RankedScans
WHERE RowNumber = (ScanCount + 1) / 2;

CREATE TABLE #DateStats
(
    AsOfDate date NOT NULL PRIMARY KEY,
    ObservationCount bigint NOT NULL
);

INSERT #DateStats (AsOfDate, ObservationCount)
SELECT source.AsOfDate, COUNT_BIG(*)
FROM dbo.KingdomScanData4 AS source
WHERE source.AsOfDate IS NOT NULL
GROUP BY source.AsOfDate;

DECLARE
    @EarliestAsOfDate date,
    @HistoricalAsOfDate date,
    @LatestAsOfDate date,
    @BenchmarkNowUtc datetime2(0);

SELECT @EarliestAsOfDate = MIN(AsOfDate),
       @LatestAsOfDate = MAX(AsOfDate)
FROM #DateStats;

;WITH RankedDates AS
(
    SELECT
        AsOfDate,
        ROW_NUMBER() OVER (ORDER BY AsOfDate) AS RowNumber,
        COUNT_BIG(*) OVER () AS DateCount
    FROM #DateStats
)
SELECT
    @HistoricalAsOfDate = AsOfDate
FROM RankedDates
WHERE RowNumber = (DateCount + 1) / 2;

SELECT
    @BenchmarkNowUtc = MAX(TRY_CONVERT(datetime2(0), source.ScanDate))
FROM dbo.KingdomScanData4 AS source;

IF @BenchmarkNowUtc IS NULL
    SET @BenchmarkNowUtc = CONVERT(datetime2(0), @LatestAsOfDate);

/*
The dynamic execution surface is a static allowlist authored below. Object
identifiers are validated against metadata and quoted with QUOTENAME. Data
parameters are passed through sp_executesql rather than concatenated.
*/
CREATE TABLE #Workloads
(
    WorkloadId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    WorkloadCategory nvarchar(40) NOT NULL,
    WorkloadName sysname NOT NULL,
    Scenario nvarchar(80) NOT NULL,
    IsWriteCapable bit NOT NULL,
    RequiredObjectName nvarchar(517) NOT NULL,
    RequiredObjectType varchar(2) NOT NULL,
    CommandSql nvarchar(max) NOT NULL,
    Notes nvarchar(1000) NULL
);

DECLARE @CaptureEndMetricsSql nvarchar(max) = N'
SELECT
    @FinishedAtUtc = SYSUTCDATETIME(),
    @CpuEnd = CONVERT(bigint, request_state.cpu_time),
    @PhysicalReadsEnd = CONVERT(bigint, request_state.reads),
    @LogicalReadsEnd = CONVERT(bigint, request_state.logical_reads),
    @WritesEnd = CONVERT(bigint, request_state.writes)
FROM sys.dm_exec_requests AS request_state
WHERE request_state.session_id = @@SPID
  AND request_state.request_id = CURRENT_REQUEST_ID();

SELECT
    @LogUsedEndBytes =
        CONVERT(decimal(38,0), log_state.used_log_space_in_bytes)
FROM sys.dm_db_log_space_usage AS log_state;

SELECT
    @TempdbUsedEndBytes =
        SUM(
            CONVERT(
                decimal(38,0),
                file_state.total_page_count
                    - file_state.unallocated_extent_page_count
            ) * 8192
        )
FROM tempdb.sys.dm_db_file_space_usage AS file_state;
';

/* Core views: complete materialization, then order-independent row hashing. */
DECLARE @Views TABLE
(
    SequenceNo int NOT NULL PRIMARY KEY,
    ViewName sysname NOT NULL,
    Scenario nvarchar(80) NOT NULL
);

INSERT @Views (SequenceNo, ViewName, Scenario)
VALUES
    (10, N'v_PlayerLatestStats', N'complete_view'),
    (20, N'vDaily_PlayerExport', N'complete_view'),
    (30, N'vDaily_Helps', N'complete_view'),
    (40, N'vDaily_RSSAssisted', N'complete_view'),
    (50, N'vDaily_RSSGathered', N'complete_view'),
    (60, N'vWTD_Helps', N'complete_view'),
    (70, N'vWTD_RSSAssisted', N'complete_view'),
    (80, N'vWTD_RSSGathered', N'complete_view'),
    (90, N'vw_Governor_KVK_Summary_GlobalLatest', N'complete_view');

DECLARE
    @ViewName sysname,
    @ViewScenario nvarchar(80),
    @QualifiedViewName nvarchar(517),
    @ViewCommand nvarchar(max);

DECLARE ViewCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ViewName, Scenario
    FROM @Views
    ORDER BY SequenceNo;

OPEN ViewCursor;
FETCH NEXT FROM ViewCursor INTO @ViewName, @ViewScenario;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @QualifiedViewName =
        QUOTENAME(N'dbo') + N'.' + QUOTENAME(@ViewName);

    SET @ViewCommand =
        N'SELECT materialized.*' + NCHAR(13) + NCHAR(10)
        + N'INTO #MaterializedView' + NCHAR(13) + NCHAR(10)
        + N'FROM ' + @QualifiedViewName + N' AS materialized;'
        + NCHAR(13) + NCHAR(10)
        + @CaptureEndMetricsSql
        + N'
SELECT @RowCount = COUNT_BIG(*) FROM #MaterializedView;

DECLARE @CanonicalRows nvarchar(max);
SELECT @CanonicalRows =
(
    SELECT row_hashes.RowDigest
    FROM
    (
        SELECT
            CONVERT(
                char(64),
                HASHBYTES(
                    ''SHA2_256'',
                    (
                        SELECT materialized.*
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                    )
                ),
                2
            ) AS RowDigest
        FROM #MaterializedView AS materialized
    ) AS row_hashes
    ORDER BY row_hashes.RowDigest
    FOR JSON PATH
);

SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
';

    INSERT #Workloads
    (
        WorkloadCategory,
        WorkloadName,
        Scenario,
        IsWriteCapable,
        RequiredObjectName,
        RequiredObjectType,
        CommandSql,
        Notes
    )
    VALUES
    (
        N'view',
        @ViewName,
        @ViewScenario,
        0,
        N'dbo.' + @ViewName,
        N'V',
        @ViewCommand,
        N'All view columns are materialized. Digest is SHA-256 over sorted SHA-256 row digests.'
    );

    FETCH NEXT FROM ViewCursor INTO @ViewName, @ViewScenario;
END;

CLOSE ViewCursor;
DEALLOCATE ViewCursor;

/* Bot-facing single-result lookup procedures. */
INSERT #Workloads
(
    WorkloadCategory,
    WorkloadName,
    Scenario,
    IsWriteCapable,
    RequiredObjectName,
    RequiredObjectType,
    CommandSql,
    Notes
)
VALUES
(
    N'bot_lookup',
    N'usp_LeadershipPlayerGovernorExists',
    N'high_activity_existing',
    0,
    N'dbo.usp_LeadershipPlayerGovernorExists',
    N'P',
    N'
CREATE TABLE #ProcedureResult
(
    GovernorID bigint NOT NULL,
    ExistsInDatabase bit NOT NULL
);

INSERT #ProcedureResult
EXEC dbo.usp_LeadershipPlayerGovernorExists
    @GovernorID = @HighActivityGovernorID;
'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM #ProcedureResult;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT result.*
    FROM #ProcedureResult AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Existing governor lookup selected from the highest observation count.'
),
(
    N'bot_lookup',
    N'usp_LeadershipPlayerGovernorExists',
    N'absent_governor',
    0,
    N'dbo.usp_LeadershipPlayerGovernorExists',
    N'P',
    N'
CREATE TABLE #ProcedureResult
(
    GovernorID bigint NOT NULL,
    ExistsInDatabase bit NOT NULL
);

INSERT #ProcedureResult
EXEC dbo.usp_LeadershipPlayerGovernorExists
    @GovernorID = @AbsentGovernorID;
'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM #ProcedureResult;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT result.*
    FROM #ProcedureResult AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Negative lookup uses an automatically selected non-existent positive bigint.'
),
(
    N'bot_lookup',
    N'usp_GetLeadershipPlayerLookupDirectory',
    N'720_day_directory',
    0,
    N'dbo.usp_GetLeadershipPlayerLookupDirectory',
    N'P',
    N'
CREATE TABLE #ProcedureResult
(
    GovernorID bigint NOT NULL,
    GovernorName nvarchar(100) NULL,
    GovernorNameKey nvarchar(100) NULL,
    FirstSeen datetime2(0) NULL,
    LastSeen datetime2(0) NULL,
    SeenScanCount int NULL,
    CurrentGovernorName nvarchar(100) NULL,
    CurrentAlliance nvarchar(100) NULL,
    LastGovernorScanAtUtc datetime2(0) NULL,
    PresentInLatestCompleteScan bit NULL,
    IsCurrentName bit NULL
);

INSERT #ProcedureResult
EXEC dbo.usp_GetLeadershipPlayerLookupDirectory
    @HistoryDays = 720;
'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM #ProcedureResult;
DECLARE @CanonicalRows nvarchar(max);
SELECT @CanonicalRows =
(
    SELECT row_hashes.RowDigest
    FROM
    (
        SELECT
            CONVERT(
                char(64),
                HASHBYTES(
                    ''SHA2_256'',
                    (
                        SELECT result.*
                        FOR JSON PATH,
                            WITHOUT_ARRAY_WRAPPER,
                            INCLUDE_NULL_VALUES
                    )
                ),
                2
            ) AS RowDigest
        FROM #ProcedureResult AS result
    ) AS row_hashes
    ORDER BY row_hashes.RowDigest
    FOR JSON PATH
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Full leadership lookup directory with its supported maximum history window.'
),
(
    N'bot_lookup',
    N'usp_GetLeadershipPlayerLastActive',
    N'high_activity_720_day',
    0,
    N'dbo.usp_GetLeadershipPlayerLastActive',
    N'P',
    N'
CREATE TABLE #ProcedureResult
(
    GovernorID bigint NOT NULL,
    EffectiveUtcDate date NULL,
    HistoryStartDate date NULL,
    HistoryEndDate date NULL,
    LastActiveDate date NULL,
    ActivityState nvarchar(16) NULL,
    QualifyingSourceCode nvarchar(32) NULL,
    QualifyingScanOrder bigint NULL,
    ComparedCompleteScanCount int NULL,
    HistoryDays smallint NULL
);

INSERT #ProcedureResult
EXEC dbo.usp_GetLeadershipPlayerLastActive
    @GovernorID = @HighActivityGovernorID,
    @HistoryDays = 720,
    @NowUtc = @BenchmarkNowUtc;
'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM #ProcedureResult;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT result.*
    FROM #ProcedureResult AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'NowUtc is pinned to the latest restored scan timestamp for deterministic output.'
);

/* Rollback-isolated write-capable procedures. */
INSERT #Workloads
(
    WorkloadCategory,
    WorkloadName,
    Scenario,
    IsWriteCapable,
    RequiredObjectName,
    RequiredObjectType,
    CommandSql,
    Notes
)
VALUES
(
    N'summary',
    N'SUMMARY_PROC',
    N'end_to_end_all_components',
    1,
    N'dbo.SUMMARY_PROC',
    N'P',
    N'EXEC dbo.SUMMARY_PROC;'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM dbo.SUMMARY_CHANGE_EXPORT;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT result.*
    FROM dbo.SUMMARY_CHANGE_EXPORT AS result
    ORDER BY result.GOVERNORID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Runs all eight component summary procedures and digests SUMMARY_CHANGE_EXPORT. '
    + N'Checkpoint rows are reset before timing inside the rollback-isolated transaction.'
),
(
    N'summary_component',
    N'DEADSSUMMARY_PROC',
    N'component_cost',
    1,
    N'dbo.DEADSSUMMARY_PROC',
    N'P',
    N'EXEC dbo.DEADSSUMMARY_PROC;'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM dbo.DEADSSUMMARY;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT result.*
    FROM dbo.DEADSSUMMARY AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Selected representative component for death-delta calculations. '
    + N'Its checkpoint row is reset before timing inside the rollback-isolated transaction.'
),
(
    N'summary_component',
    N'POWERSUMMARY_PROC',
    N'component_cost',
    1,
    N'dbo.POWERSUMMARY_PROC',
    N'P',
    N'EXEC dbo.POWERSUMMARY_PROC;'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM dbo.POWERSUMMARY;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT result.*
    FROM dbo.POWERSUMMARY AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Selected representative component for power calculations. '
    + N'Its checkpoint row is reset before timing inside the rollback-isolated transaction.'
),
(
    N'summary_component',
    N'HEALEDSUMMARY_PROC',
    N'component_cost',
    1,
    N'dbo.HEALEDSUMMARY_PROC',
    N'P',
    N'EXEC dbo.HEALEDSUMMARY_PROC;'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM dbo.HEALEDSUMMARY;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT result.*
    FROM dbo.HEALEDSUMMARY AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Selected representative component for healed-troop calculations. '
    + N'Its checkpoint row is reset before timing inside the rollback-isolated transaction.'
),
(
    N'summary_component',
    N'RANGEDSUMMARY_PROC',
    N'component_cost',
    1,
    N'dbo.RANGEDSUMMARY_PROC',
    N'P',
    N'EXEC dbo.RANGEDSUMMARY_PROC;'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM dbo.RANGEDSUMMARY;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT result.*
    FROM dbo.RANGEDSUMMARY AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Selected representative component for ranged-point calculations. '
    + N'Its checkpoint row is reset before timing inside the rollback-isolated transaction.'
),
(
    N'player_scan_meta',
    N'Refresh_PlayerScanMeta',
    N'full_rebuild',
    1,
    N'dbo.Refresh_PlayerScanMeta',
    N'P',
    N'
EXEC dbo.Refresh_PlayerScanMeta
    @FullRebuild = 1,
    @MinScanOrder = NULL,
    @FromScanDate = NULL,
    @BatchSize = NULL,
    @StartingGovernorID = NULL;
'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM dbo.PlayerScanMeta;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT
        result.GovernorID,
        result.FirstScanDate,
        result.LastScanDate,
        result.FirstScanOrder,
        result.LastScanOrder,
        result.OfflineDaysOver30
    FROM dbo.PlayerScanMeta AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Excludes volatile LastRefreshedUTC from the stable digest.'
),
(
    N'player_scan_meta',
    N'Refresh_PlayerScanMeta',
    N'incremental_from_historical_scan',
    1,
    N'dbo.Refresh_PlayerScanMeta',
    N'P',
    N'
DECLARE @HistoricalScanOrderFloat float =
    CONVERT(float, @HistoricalScanOrder);

EXEC dbo.Refresh_PlayerScanMeta
    @FullRebuild = 0,
    @MinScanOrder = @HistoricalScanOrderFloat,
    @FromScanDate = NULL,
    @BatchSize = NULL,
    @StartingGovernorID = NULL;
'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM dbo.PlayerScanMeta;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT
        result.GovernorID,
        result.FirstScanDate,
        result.LastScanDate,
        result.FirstScanOrder,
        result.LastScanOrder,
        result.OfflineDaysOver30
    FROM dbo.PlayerScanMeta AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Historical scan order is selected automatically from the median distinct scan.'
),
(
    N'player_scan_meta',
    N'Refresh_PlayerScanMeta',
    N'no_op_after_latest_scan',
    1,
    N'dbo.Refresh_PlayerScanMeta',
    N'P',
    N'
DECLARE @NoOpMinScanOrder float =
    CONVERT(float, @LatestScanOrder + 1);

EXEC dbo.Refresh_PlayerScanMeta
    @FullRebuild = 0,
    @MinScanOrder = @NoOpMinScanOrder,
    @FromScanDate = NULL,
    @BatchSize = NULL,
    @StartingGovernorID = NULL;
'
    + @CaptureEndMetricsSql
    + N'
SELECT @RowCount = COUNT_BIG(*) FROM dbo.PlayerScanMeta;
DECLARE @CanonicalRows nvarchar(max) =
(
    SELECT
        result.GovernorID,
        result.FirstScanDate,
        result.LastScanDate,
        result.FirstScanOrder,
        result.LastScanOrder,
        result.OfflineDaysOver30
    FROM dbo.PlayerScanMeta AS result
    ORDER BY result.GovernorID
    FOR JSON PATH, INCLUDE_NULL_VALUES
);
SET @ResultDigest =
    HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
',
    N'Uses one more than the latest scan order to exercise the no-change path.'
);

CREATE TABLE #BenchmarkResults
(
    BenchmarkRunId uniqueidentifier NOT NULL,
    WorkloadCategory nvarchar(40) NOT NULL,
    WorkloadName sysname NOT NULL,
    Scenario nvarchar(80) NOT NULL,
    RunKind nvarchar(16) NOT NULL,
    RunNumber tinyint NULL,
    IsWriteCapable bit NOT NULL,
    TransactionMode nvarchar(32) NOT NULL,
    StartedAtUtc datetime2(7) NULL,
    FinishedAtUtc datetime2(7) NULL,
    DurationMs decimal(19,3) NULL,
    CpuMs bigint NULL,
    LogicalReads bigint NULL,
    PhysicalReads bigint NULL,
    Writes bigint NULL,
    ResultRowCount bigint NULL,
    ResultDigestSha256 char(64) NULL,
    LogUsedBeforeMB decimal(19,3) NULL,
    LogUsedAfterMB decimal(19,3) NULL,
    LogUsedDeltaMB decimal(19,3) NULL,
    TempdbUsedBeforeMB decimal(19,3) NULL,
    TempdbUsedAfterMB decimal(19,3) NULL,
    TempdbUsedDeltaMB decimal(19,3) NULL,
    Status nvarchar(16) NOT NULL,
    ErrorNumber int NULL,
    ErrorMessage nvarchar(2048) NULL,
    Notes nvarchar(1000) NULL
);

DECLARE
    @WorkloadId int,
    @WorkloadCategory nvarchar(40),
    @WorkloadName sysname,
    @Scenario nvarchar(80),
    @IsWriteCapable bit,
    @RequiredObjectName nvarchar(517),
    @RequiredObjectType varchar(2),
    @CommandSql nvarchar(max),
    @WorkloadNotes nvarchar(1000);

DECLARE WorkloadCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        WorkloadId,
        WorkloadCategory,
        WorkloadName,
        Scenario,
        IsWriteCapable,
        RequiredObjectName,
        RequiredObjectType,
        CommandSql,
        Notes
    FROM #Workloads
    ORDER BY WorkloadId;

OPEN WorkloadCursor;
FETCH NEXT FROM WorkloadCursor
INTO
    @WorkloadId,
    @WorkloadCategory,
    @WorkloadName,
    @Scenario,
    @IsWriteCapable,
    @RequiredObjectName,
    @RequiredObjectType,
    @CommandSql,
    @WorkloadNotes;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @RunStandardSuite = 0
    BEGIN
        INSERT #BenchmarkResults
        (
            BenchmarkRunId,
            WorkloadCategory,
            WorkloadName,
            Scenario,
            RunKind,
            RunNumber,
            IsWriteCapable,
            TransactionMode,
            Status,
            Notes
        )
        VALUES
        (
            @BenchmarkRunId,
            @WorkloadCategory,
            @WorkloadName,
            @Scenario,
            N'configuration',
            NULL,
            @IsWriteCapable,
            CASE WHEN @IsWriteCapable = 1
                 THEN N'rollback_isolated'
                 ELSE N'read_only'
            END,
            N'SKIPPED',
            N'@RunStandardSuite is disabled for an UPDATE_ALL2-only invocation.'
        );
    END;
    ELSE IF OBJECT_ID(@RequiredObjectName, @RequiredObjectType) IS NULL
    BEGIN
        INSERT #BenchmarkResults
        (
            BenchmarkRunId,
            WorkloadCategory,
            WorkloadName,
            Scenario,
            RunKind,
            RunNumber,
            IsWriteCapable,
            TransactionMode,
            Status,
            Notes
        )
        VALUES
        (
            @BenchmarkRunId,
            @WorkloadCategory,
            @WorkloadName,
            @Scenario,
            N'configuration',
            NULL,
            @IsWriteCapable,
            CASE WHEN @IsWriteCapable = 1
                 THEN N'rollback_isolated'
                 ELSE N'read_only'
            END,
            N'SKIPPED',
            CONCAT(N'Required object is missing: ', @RequiredObjectName, N'.')
        );
    END;
    ELSE IF
    (
        @WorkloadCategory = N'summary'
        AND @RunFullHistorySummaryEndToEnd = 0
    )
    OR
    (
        @WorkloadCategory = N'summary_component'
        AND @RunFullHistorySummaryComponents = 0
    )
    BEGIN
        INSERT #BenchmarkResults
        (
            BenchmarkRunId,
            WorkloadCategory,
            WorkloadName,
            Scenario,
            RunKind,
            RunNumber,
            IsWriteCapable,
            TransactionMode,
            Status,
            Notes
        )
        VALUES
        (
            @BenchmarkRunId,
            @WorkloadCategory,
            @WorkloadName,
            @Scenario,
            N'configuration',
            NULL,
            @IsWriteCapable,
            N'rollback_isolated',
            N'SKIPPED',
            CASE
                WHEN @WorkloadCategory = N'summary'
                    THEN N'Full-history SUMMARY_PROC benchmark is opt-in; set @RunFullHistorySummaryEndToEnd = 1 for a deliberate comparable run.'
                ELSE N'Full-history standalone component benchmarks are opt-in; set @RunFullHistorySummaryComponents = 1 for a deliberate comparable run.'
            END
        );
    END;
    ELSE IF @IsWriteCapable = 1
            AND @RunRollbackIsolatedWriters = 0
    BEGIN
        INSERT #BenchmarkResults
        (
            BenchmarkRunId,
            WorkloadCategory,
            WorkloadName,
            Scenario,
            RunKind,
            RunNumber,
            IsWriteCapable,
            TransactionMode,
            Status,
            Notes
        )
        VALUES
        (
            @BenchmarkRunId,
            @WorkloadCategory,
            @WorkloadName,
            @Scenario,
            N'configuration',
            NULL,
            1,
            N'rollback_isolated',
            N'SKIPPED',
            N'@RunRollbackIsolatedWriters is disabled.'
        );
    END;
    ELSE
    BEGIN
        DECLARE @RunNumber tinyint = 0;

        WHILE @RunNumber <= @MeasuredRunCount
        BEGIN
            DECLARE
                @StartedAtUtc datetime2(7),
                @FinishedAtUtc datetime2(7),
                @CpuStart bigint,
                @CpuEnd bigint,
                @PhysicalReadsStart bigint,
                @PhysicalReadsEnd bigint,
                @LogicalReadsStart bigint,
                @LogicalReadsEnd bigint,
                @WritesStart bigint,
                @WritesEnd bigint,
                @LogUsedStartBytes decimal(38,0),
                @LogUsedEndBytes decimal(38,0),
                @TempdbUsedStartBytes decimal(38,0),
                @TempdbUsedEndBytes decimal(38,0),
                @ResultRowCount bigint,
                @ResultDigest varbinary(32),
                @Status nvarchar(16) = N'SUCCEEDED',
                @ErrorNumber int = NULL,
                @ErrorMessage nvarchar(2048) = NULL;

            IF @EmitProgressMessages = 1
            BEGIN
                DECLARE @ProgressStartMessage nvarchar(2047) =
                    CONCAT(
                        N'Benchmark starting: ',
                        @WorkloadCategory,
                        N' / ',
                        @WorkloadName,
                        N' / ',
                        @Scenario,
                        N' / ',
                        CASE WHEN @RunNumber = 0
                            THEN N'warmup'
                            ELSE CONCAT(N'measured ', @RunNumber, N' of ', @MeasuredRunCount)
                        END
                    );

                RAISERROR(N'%s', 0, 1, @ProgressStartMessage) WITH NOWAIT;
            END;

            BEGIN TRY
                IF @IsWriteCapable = 1
                    BEGIN TRANSACTION;

                /*
                Force the summary benchmarks to process the full restored data
                set. The preparation is excluded from the timed counters, and
                the enclosing transaction is rolled back after each execution.
                */
                IF @WorkloadCategory = N'summary'
                BEGIN
                    DELETE FROM dbo.SUMMARY_PROC_STATE
                    WHERE MetricName IN
                    (
                        N'Deads',
                        N'Power',
                        N'T4T5Kills',
                        N'T4Kills',
                        N'T5Kills',
                        N'KillPoints',
                        N'HealedTroops',
                        N'RangedPoints',
                        N'SummaryExport'
                    );
                END;
                ELSE IF @WorkloadCategory = N'summary_component'
                BEGIN
                    DELETE FROM dbo.SUMMARY_PROC_STATE
                    WHERE MetricName =
                        CASE @WorkloadName
                            WHEN N'DEADSSUMMARY_PROC' THEN N'Deads'
                            WHEN N'POWERSUMMARY_PROC' THEN N'Power'
                            WHEN N'HEALEDSUMMARY_PROC' THEN N'HealedTroops'
                            WHEN N'RANGEDSUMMARY_PROC' THEN N'RangedPoints'
                        END;
                END;

            SELECT
                @StartedAtUtc = SYSUTCDATETIME(),
                @CpuStart = CONVERT(bigint, request_state.cpu_time),
                @PhysicalReadsStart = CONVERT(bigint, request_state.reads),
                @LogicalReadsStart = CONVERT(bigint, request_state.logical_reads),
                @WritesStart = CONVERT(bigint, request_state.writes)
            FROM sys.dm_exec_requests AS request_state
            WHERE request_state.session_id = @@SPID
              AND request_state.request_id = CURRENT_REQUEST_ID();

            SELECT
                @LogUsedStartBytes =
                    CONVERT(decimal(38,0), log_state.used_log_space_in_bytes)
            FROM sys.dm_db_log_space_usage AS log_state;

            SELECT
                @TempdbUsedStartBytes =
                    SUM(
                        CONVERT(
                            decimal(38,0),
                            file_state.total_page_count
                                - file_state.unallocated_extent_page_count
                        ) * 8192
                    )
            FROM tempdb.sys.dm_db_file_space_usage AS file_state;

                EXEC sys.sp_executesql
                    @CommandSql,
                    N'@HighActivityGovernorID bigint,
                      @AbsentGovernorID bigint,
                      @LatestScanOrder bigint,
                      @HistoricalScanOrder bigint,
                      @BenchmarkNowUtc datetime2(0),
                      @FinishedAtUtc datetime2(7) OUTPUT,
                      @CpuEnd bigint OUTPUT,
                      @PhysicalReadsEnd bigint OUTPUT,
                      @LogicalReadsEnd bigint OUTPUT,
                      @WritesEnd bigint OUTPUT,
                      @LogUsedEndBytes decimal(38,0) OUTPUT,
                      @TempdbUsedEndBytes decimal(38,0) OUTPUT,
                      @RowCount bigint OUTPUT,
                      @ResultDigest varbinary(32) OUTPUT',
                    @HighActivityGovernorID = @HighActivityGovernorID,
                    @AbsentGovernorID = @AbsentGovernorID,
                    @LatestScanOrder = @LatestScanOrder,
                    @HistoricalScanOrder = @HistoricalScanOrder,
                    @BenchmarkNowUtc = @BenchmarkNowUtc,
                    @FinishedAtUtc = @FinishedAtUtc OUTPUT,
                    @CpuEnd = @CpuEnd OUTPUT,
                    @PhysicalReadsEnd = @PhysicalReadsEnd OUTPUT,
                    @LogicalReadsEnd = @LogicalReadsEnd OUTPUT,
                    @WritesEnd = @WritesEnd OUTPUT,
                    @LogUsedEndBytes = @LogUsedEndBytes OUTPUT,
                    @TempdbUsedEndBytes = @TempdbUsedEndBytes OUTPUT,
                    @RowCount = @ResultRowCount OUTPUT,
                    @ResultDigest = @ResultDigest OUTPUT;

                IF @IsWriteCapable = 1 AND XACT_STATE() <> 0
                    ROLLBACK TRANSACTION;
            END TRY
            BEGIN CATCH
                SET @Status = N'FAILED';
                SET @ErrorNumber = ERROR_NUMBER();
                SET @ErrorMessage = ERROR_MESSAGE();

                SELECT
                    @FinishedAtUtc = SYSUTCDATETIME(),
                    @CpuEnd = CONVERT(bigint, request_state.cpu_time),
                    @PhysicalReadsEnd = CONVERT(bigint, request_state.reads),
                    @LogicalReadsEnd = CONVERT(bigint, request_state.logical_reads),
                    @WritesEnd = CONVERT(bigint, request_state.writes)
                FROM sys.dm_exec_requests AS request_state
                WHERE request_state.session_id = @@SPID
                  AND request_state.request_id = CURRENT_REQUEST_ID();

                SELECT
                    @LogUsedEndBytes =
                        CONVERT(decimal(38,0), log_state.used_log_space_in_bytes)
                FROM sys.dm_db_log_space_usage AS log_state;

                SELECT
                    @TempdbUsedEndBytes =
                        SUM(
                            CONVERT(
                                decimal(38,0),
                                file_state.total_page_count
                                    - file_state.unallocated_extent_page_count
                            ) * 8192
                        )
                FROM tempdb.sys.dm_db_file_space_usage AS file_state;

                IF XACT_STATE() <> 0
                    ROLLBACK TRANSACTION;
            END CATCH;

            INSERT #BenchmarkResults
            (
                BenchmarkRunId,
                WorkloadCategory,
                WorkloadName,
                Scenario,
                RunKind,
                RunNumber,
                IsWriteCapable,
                TransactionMode,
                StartedAtUtc,
                FinishedAtUtc,
                DurationMs,
                CpuMs,
                LogicalReads,
                PhysicalReads,
                Writes,
                ResultRowCount,
                ResultDigestSha256,
                LogUsedBeforeMB,
                LogUsedAfterMB,
                LogUsedDeltaMB,
                TempdbUsedBeforeMB,
                TempdbUsedAfterMB,
                TempdbUsedDeltaMB,
                Status,
                ErrorNumber,
                ErrorMessage,
                Notes
            )
            VALUES
            (
                @BenchmarkRunId,
                @WorkloadCategory,
                @WorkloadName,
                @Scenario,
                CASE WHEN @RunNumber = 0
                     THEN N'warmup'
                     ELSE N'measured'
                END,
                @RunNumber,
                @IsWriteCapable,
                CASE WHEN @IsWriteCapable = 1
                     THEN N'rollback_isolated'
                     ELSE N'read_only'
                END,
                @StartedAtUtc,
                @FinishedAtUtc,
                CONVERT(
                    decimal(19,3),
                    DATEDIFF_BIG(microsecond, @StartedAtUtc, @FinishedAtUtc)
                        / 1000.0
                ),
                @CpuEnd - @CpuStart,
                @LogicalReadsEnd - @LogicalReadsStart,
                @PhysicalReadsEnd - @PhysicalReadsStart,
                @WritesEnd - @WritesStart,
                @ResultRowCount,
                CONVERT(char(64), @ResultDigest, 2),
                CONVERT(decimal(19,3), @LogUsedStartBytes / 1048576.0),
                CONVERT(decimal(19,3), @LogUsedEndBytes / 1048576.0),
                CONVERT(
                    decimal(19,3),
                    (@LogUsedEndBytes - @LogUsedStartBytes) / 1048576.0
                ),
                CONVERT(decimal(19,3), @TempdbUsedStartBytes / 1048576.0),
                CONVERT(decimal(19,3), @TempdbUsedEndBytes / 1048576.0),
                CONVERT(
                    decimal(19,3),
                    (@TempdbUsedEndBytes - @TempdbUsedStartBytes) / 1048576.0
                ),
                @Status,
                @ErrorNumber,
                @ErrorMessage,
                @WorkloadNotes
            );

            IF @EmitProgressMessages = 1
            BEGIN
                DECLARE @ProgressEndMessage nvarchar(2047) =
                    CONCAT(
                        N'Benchmark finished: ',
                        @WorkloadCategory,
                        N' / ',
                        @WorkloadName,
                        N' / ',
                        @Scenario,
                        N' / status ',
                        @Status,
                        N' / elapsed ',
                        CONVERT(
                            decimal(19,3),
                            DATEDIFF_BIG(
                                microsecond,
                                @StartedAtUtc,
                                @FinishedAtUtc
                            ) / 1000.0
                        ),
                        N' ms'
                    );

                RAISERROR(N'%s', 0, 1, @ProgressEndMessage) WITH NOWAIT;
            END;

            SET @RunNumber += 1;
        END;
    END;

    FETCH NEXT FROM WorkloadCursor
    INTO
        @WorkloadId,
        @WorkloadCategory,
        @WorkloadName,
        @Scenario,
        @IsWriteCapable,
        @RequiredObjectName,
        @RequiredObjectType,
        @CommandSql,
        @WorkloadNotes;
END;

CLOSE WorkloadCursor;
DEALLOCATE WorkloadCursor;

/*
Committed UPDATE_ALL2 benchmark.
This is intentionally not wrapped in an outer transaction: UPDATE_ALL2's own
commit/checkpoint boundaries are part of the workload being measured.
*/
IF @UpdateAll2RunOrdinal IS NULL
BEGIN
    INSERT #BenchmarkResults
    (
        BenchmarkRunId,
        WorkloadCategory,
        WorkloadName,
        Scenario,
        RunKind,
        RunNumber,
        IsWriteCapable,
        TransactionMode,
        Status,
        Notes
    )
    VALUES
    (
        @BenchmarkRunId,
        N'import_end_to_end',
        N'UPDATE_ALL2',
        N'committed_fresh_restore',
        N'configuration',
        NULL,
        1,
        N'committed',
        N'SKIPPED',
        N'Set @UpdateAll2RunOrdinal and confirm the exact database to run one committed ordinal.'
    );
END;
ELSE IF OBJECT_ID(N'dbo.UPDATE_ALL2', N'P') IS NULL
BEGIN
    INSERT #BenchmarkResults
    (
        BenchmarkRunId,
        WorkloadCategory,
        WorkloadName,
        Scenario,
        RunKind,
        RunNumber,
        IsWriteCapable,
        TransactionMode,
        Status,
        Notes
    )
    VALUES
    (
        @BenchmarkRunId,
        N'import_end_to_end',
        N'UPDATE_ALL2',
        N'committed_fresh_restore',
        CASE WHEN @UpdateAll2RunOrdinal = 0
             THEN N'warmup'
             ELSE N'measured'
        END,
        @UpdateAll2RunOrdinal,
        1,
        N'committed',
        N'SKIPPED',
        N'Required procedure dbo.UPDATE_ALL2 is missing.'
    );
END;
ELSE
BEGIN
    DECLARE
        @UpdateStartedAtUtc datetime2(7),
        @UpdateFinishedAtUtc datetime2(7),
        @UpdateCpuStart bigint,
        @UpdateCpuEnd bigint,
        @UpdatePhysicalReadsStart bigint,
        @UpdatePhysicalReadsEnd bigint,
        @UpdateLogicalReadsStart bigint,
        @UpdateLogicalReadsEnd bigint,
        @UpdateWritesStart bigint,
        @UpdateWritesEnd bigint,
        @UpdateLogStartBytes decimal(38,0),
        @UpdateLogEndBytes decimal(38,0),
        @UpdateTempdbStartBytes decimal(38,0),
        @UpdateTempdbEndBytes decimal(38,0),
        @UpdateLogFileStartBytes decimal(38,0),
        @UpdateLogFileEndBytes decimal(38,0),
        @UpdateLogSinceBackupStartMB decimal(38,3),
        @UpdateLogSinceBackupEndMB decimal(38,3),
        @UpdateLockWaitStartMs bigint,
        @UpdateLockWaitEndMs bigint,
        @UpdateLockWaitStartCount bigint,
        @UpdateLockWaitEndCount bigint,
        @UpdatePreKs4Rows bigint,
        @UpdatePostKs4Rows bigint,
        @UpdatePreKs5Rows bigint,
        @UpdatePostKs5Rows bigint,
        @UpdatePreKs4MaxScan bigint,
        @UpdatePostKs4MaxScan bigint,
        @UpdatePreKs5MaxScan bigint,
        @UpdatePostKs5MaxScan bigint,
        @UpdatePostKs4LatestScanRows bigint,
        @UpdatePostKs5LatestScanRows bigint,
        @UpdatePostKs4LatestDistinctGovernors bigint,
        @UpdatePostKs5LatestDistinctGovernors bigint,
        @UpdatePostKs4LatestDuplicateRows bigint,
        @UpdatePostKs5LatestDuplicateRows bigint,
        @UpdatePostKs4LatestScanUnoMin int,
        @UpdatePostKs4LatestScanUnoMax int,
        @UpdatePostKs4LatestDistinctScanUno bigint,
        @UpdateRawStagingRows bigint,
        @UpdateTypedCsvStagingRows bigint,
        @UpdateCanonicalStagingRows bigint,
        @UpdateRowsPerSecond decimal(19,3),
        @UpdateRowCount bigint,
        @UpdateDigest varbinary(32),
        @UpdateStatus nvarchar(16) = N'SUCCEEDED',
        @UpdateErrorNumber int = NULL,
        @UpdateErrorMessage nvarchar(2048) = NULL;

    SELECT
        @UpdatePreKs4Rows = COUNT_BIG(*),
        @UpdatePreKs4MaxScan = MAX(TRY_CONVERT(bigint, SCANORDER))
    FROM dbo.KingdomScanData4;

    SELECT
        @UpdatePreKs5Rows = COUNT_BIG(*),
        @UpdatePreKs5MaxScan = MAX(TRY_CONVERT(bigint, SCANORDER))
    FROM dbo.KingdomScanData5;

    IF @UpdatePreKs4Rows <> @ExpectedUpdateAll2PreKs4Rows
       OR @UpdatePreKs5Rows <> @ExpectedUpdateAll2PreKs5Rows
       OR @UpdatePreKs4MaxScan <> @ExpectedUpdateAll2PreMaxScan
       OR @UpdatePreKs5MaxScan <> @ExpectedUpdateAll2PreMaxScan
    BEGIN
        DECLARE @UnexpectedRestoreStateMessage nvarchar(2048) =
            CONCAT(
                N'Fresh-restore drift: KS4 rows/scan=',
                @UpdatePreKs4Rows,
                N'/',
                @UpdatePreKs4MaxScan,
                N'; KS5 rows/scan=',
                @UpdatePreKs5Rows,
                N'/',
                @UpdatePreKs5MaxScan,
                N'.'
            );
        THROW 51052, @UnexpectedRestoreStateMessage, 1;
    END;

    DECLARE @ActiveFixtureExists int = 0;
    EXEC master.dbo.xp_fileexist
        N'C:\discord_file_downloader\downloads_test\stats.csv',
        @ActiveFixtureExists OUTPUT;

    IF @ActiveFixtureExists <> 1
    BEGIN
        THROW 51053,
            'The isolated representative stats.csv is not visible to SQL Server.',
            1;
    END;

    SELECT
        @UpdateStartedAtUtc = SYSUTCDATETIME(),
        @UpdateCpuStart = CONVERT(bigint, request_state.cpu_time),
        @UpdatePhysicalReadsStart = CONVERT(bigint, request_state.reads),
        @UpdateLogicalReadsStart = CONVERT(bigint, request_state.logical_reads),
        @UpdateWritesStart = CONVERT(bigint, request_state.writes)
    FROM sys.dm_exec_requests AS request_state
    WHERE request_state.session_id = @@SPID
      AND request_state.request_id = CURRENT_REQUEST_ID();

    SELECT
        @UpdateLogStartBytes =
            CONVERT(decimal(38,0), log_state.used_log_space_in_bytes)
    FROM sys.dm_db_log_space_usage AS log_state;

    SELECT
        @UpdateTempdbStartBytes =
            SUM(
                CONVERT(
                    decimal(38,0),
                    file_state.total_page_count
                        - file_state.unallocated_extent_page_count
                ) * 8192
            )
    FROM tempdb.sys.dm_db_file_space_usage AS file_state;

    SELECT
        @UpdateLogFileStartBytes =
            SUM(CONVERT(decimal(38,0), size) * 8192)
    FROM sys.database_files
    WHERE type_desc = N'LOG';

    SELECT
        @UpdateLogSinceBackupStartMB =
            CONVERT(decimal(38,3), log_since_last_log_backup_mb)
    FROM sys.dm_db_log_stats(DB_ID());

    SELECT
        @UpdateLockWaitStartMs = COALESCE(SUM(wait_time_ms), 0),
        @UpdateLockWaitStartCount = COALESCE(SUM(waiting_tasks_count), 0)
    FROM sys.dm_exec_session_wait_stats
    WHERE session_id = @@SPID
      AND wait_type LIKE N'LCK_M_%';

    BEGIN TRY
        /*
        UPDATE_ALL2 returns two audit result sets. They are intentionally
        retained in the .rpt before the normalized benchmark rows.
        */
        EXEC dbo.UPDATE_ALL2
            @param1 = NULL,
            @param2 = NULL;

        SELECT
            @UpdateFinishedAtUtc = SYSUTCDATETIME(),
            @UpdateCpuEnd = CONVERT(bigint, request_state.cpu_time),
            @UpdatePhysicalReadsEnd = CONVERT(bigint, request_state.reads),
            @UpdateLogicalReadsEnd = CONVERT(bigint, request_state.logical_reads),
            @UpdateWritesEnd = CONVERT(bigint, request_state.writes)
        FROM sys.dm_exec_requests AS request_state
        WHERE request_state.session_id = @@SPID
          AND request_state.request_id = CURRENT_REQUEST_ID();

        SELECT
            @UpdateLogEndBytes =
                CONVERT(decimal(38,0), log_state.used_log_space_in_bytes)
        FROM sys.dm_db_log_space_usage AS log_state;

        SELECT
            @UpdateTempdbEndBytes =
                SUM(
                    CONVERT(
                        decimal(38,0),
                        file_state.total_page_count
                            - file_state.unallocated_extent_page_count
                    ) * 8192
                )
        FROM tempdb.sys.dm_db_file_space_usage AS file_state;

    END TRY
    BEGIN CATCH
        SET @UpdateStatus = N'FAILED';
        SET @UpdateErrorNumber = ERROR_NUMBER();
        SET @UpdateErrorMessage = ERROR_MESSAGE();

        SELECT
            @UpdateFinishedAtUtc = SYSUTCDATETIME(),
            @UpdateCpuEnd = CONVERT(bigint, request_state.cpu_time),
            @UpdatePhysicalReadsEnd = CONVERT(bigint, request_state.reads),
            @UpdateLogicalReadsEnd = CONVERT(bigint, request_state.logical_reads),
            @UpdateWritesEnd = CONVERT(bigint, request_state.writes)
        FROM sys.dm_exec_requests AS request_state
        WHERE request_state.session_id = @@SPID
          AND request_state.request_id = CURRENT_REQUEST_ID();

        SELECT
            @UpdateLogEndBytes =
                CONVERT(decimal(38,0), log_state.used_log_space_in_bytes)
        FROM sys.dm_db_log_space_usage AS log_state;

        SELECT
            @UpdateTempdbEndBytes =
                SUM(
                    CONVERT(
                        decimal(38,0),
                        file_state.total_page_count
                            - file_state.unallocated_extent_page_count
                    ) * 8192
                )
        FROM tempdb.sys.dm_db_file_space_usage AS file_state;
    END CATCH;

    SELECT
        @UpdateLogFileEndBytes =
            SUM(CONVERT(decimal(38,0), size) * 8192)
    FROM sys.database_files
    WHERE type_desc = N'LOG';

    SELECT
        @UpdateLogSinceBackupEndMB =
            CONVERT(decimal(38,3), log_since_last_log_backup_mb)
    FROM sys.dm_db_log_stats(DB_ID());

    SELECT
        @UpdateLockWaitEndMs = COALESCE(SUM(wait_time_ms), 0),
        @UpdateLockWaitEndCount = COALESCE(SUM(waiting_tasks_count), 0)
    FROM sys.dm_exec_session_wait_stats
    WHERE session_id = @@SPID
      AND wait_type LIKE N'LCK_M_%';

    SELECT
        @UpdatePostKs4Rows = COUNT_BIG(*),
        @UpdatePostKs4MaxScan = MAX(TRY_CONVERT(bigint, SCANORDER))
    FROM dbo.KingdomScanData4;

    SELECT
        @UpdatePostKs5Rows = COUNT_BIG(*),
        @UpdatePostKs5MaxScan = MAX(TRY_CONVERT(bigint, SCANORDER))
    FROM dbo.KingdomScanData5;

    SELECT
        @UpdatePostKs4LatestScanRows = COUNT_BIG(*),
        @UpdatePostKs4LatestDistinctGovernors =
            COUNT_BIG(DISTINCT TRY_CONVERT(bigint, GovernorID)),
        @UpdatePostKs4LatestScanUnoMin = MIN(SCAN_UNO),
        @UpdatePostKs4LatestScanUnoMax = MAX(SCAN_UNO),
        @UpdatePostKs4LatestDistinctScanUno =
            COUNT_BIG(DISTINCT SCAN_UNO)
    FROM dbo.KingdomScanData4
    WHERE TRY_CONVERT(bigint, SCANORDER) = @UpdatePostKs4MaxScan;

    SELECT
        @UpdatePostKs5LatestScanRows = COUNT_BIG(*),
        @UpdatePostKs5LatestDistinctGovernors =
            COUNT_BIG(DISTINCT TRY_CONVERT(bigint, GovernorID))
    FROM dbo.KingdomScanData5
    WHERE TRY_CONVERT(bigint, SCANORDER) = @UpdatePostKs5MaxScan;

    SELECT
        @UpdatePostKs4LatestDuplicateRows =
            COALESCE(SUM(duplicate_group.[RowCount] - 1), 0)
    FROM
    (
        SELECT COUNT_BIG(*) AS [RowCount]
        FROM dbo.KingdomScanData4
        WHERE TRY_CONVERT(bigint, SCANORDER) = @UpdatePostKs4MaxScan
        GROUP BY TRY_CONVERT(bigint, GovernorID)
        HAVING COUNT_BIG(*) > 1
    ) AS duplicate_group;

    SELECT
        @UpdatePostKs5LatestDuplicateRows =
            COALESCE(SUM(duplicate_group.[RowCount] - 1), 0)
    FROM
    (
        SELECT COUNT_BIG(*) AS [RowCount]
        FROM dbo.KingdomScanData5
        WHERE TRY_CONVERT(bigint, SCANORDER) = @UpdatePostKs5MaxScan
        GROUP BY TRY_CONVERT(bigint, GovernorID)
        HAVING COUNT_BIG(*) > 1
    ) AS duplicate_group;

    SELECT @UpdateRawStagingRows = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING_CSV_RAW;

    SELECT @UpdateTypedCsvStagingRows = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING_CSV;

    SELECT @UpdateCanonicalStagingRows = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING;

    SET @UpdateRowCount = @UpdatePostKs4Rows;

    IF @UpdateFinishedAtUtc > @UpdateStartedAtUtc
    BEGIN
        SET @UpdateRowsPerSecond =
            CONVERT(
                decimal(19,3),
                (@UpdatePostKs4Rows - @UpdatePreKs4Rows)
                    / NULLIF(
                        DATEDIFF_BIG(
                            millisecond,
                            @UpdateStartedAtUtc,
                            @UpdateFinishedAtUtc
                        ) / 1000.0,
                        0
                    )
            );
    END;

    DECLARE @CanonicalKingdomScanData4Rows nvarchar(max);
    SELECT @CanonicalKingdomScanData4Rows =
    (
        SELECT row_hashes.RowDigest
        FROM
        (
            SELECT
                CONVERT(
                    char(64),
                    HASHBYTES(
                        'SHA2_256',
                        (
                            SELECT
                                source.PowerRank,
                                source.GovernorName,
                                source.GovernorID,
                                source.Alliance,
                                source.[Power],
                                source.KillPoints,
                                source.Deads,
                                source.T1_Kills,
                                source.T2_Kills,
                                source.T3_Kills,
                                source.T4_Kills,
                                source.T5_Kills,
                                source.[T4&T5_KILLS],
                                source.TOTAL_KILLS,
                                source.RSS_Gathered,
                                source.RSSAssistance,
                                source.Helps,
                                source.ScanDate,
                                source.SCANORDER,
                                source.[Troops Power],
                                source.[City Hall],
                                source.[Tech Power],
                                source.[Building Power],
                                source.[Commander Power],
                                source.AsOfDate,
                                source.HealedTroops,
                                source.RangedPoints,
                                source.Civilization,
                                source.KvKPlayed,
                                source.MostKvKKill,
                                source.MostKvKDead,
                                source.MostKvKHeal,
                                source.Acclaim,
                                source.HighestAcclaim,
                                source.AOOJoined,
                                source.AOOWon,
                                source.AOOAvgKill,
                                source.AOOAvgDead,
                                source.AOOAvgHeal,
                                source.Conduct,
                                source.AutarchTimes
                            FOR JSON PATH,
                                WITHOUT_ARRAY_WRAPPER,
                                INCLUDE_NULL_VALUES
                        )
                    ),
                    2
                ) AS RowDigest
            FROM dbo.KingdomScanData4 AS source
        ) AS row_hashes
        ORDER BY row_hashes.RowDigest
        FOR JSON PATH
    );

    SET @UpdateDigest =
        HASHBYTES(
            'SHA2_256',
            COALESCE(@CanonicalKingdomScanData4Rows, N'[]')
        );

    IF @UpdateStatus = N'SUCCEEDED'
       AND
       (
           @UpdatePostKs4Rows - @UpdatePreKs4Rows
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdatePostKs5Rows - @UpdatePreKs5Rows
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdatePostKs4MaxScan <> @UpdatePreKs4MaxScan + 1
           OR @UpdatePostKs5MaxScan <> @UpdatePreKs5MaxScan + 1
           OR @UpdatePostKs4LatestScanRows
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdatePostKs5LatestScanRows
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdatePostKs4LatestDistinctGovernors
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdatePostKs5LatestDistinctGovernors
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdatePostKs4LatestDuplicateRows <> 0
           OR @UpdatePostKs5LatestDuplicateRows <> 0
           OR @UpdatePostKs4LatestDistinctScanUno
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdateRawStagingRows
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdateTypedCsvStagingRows
                <> @ExpectedUpdateAll2ImportedRows
           OR @UpdateCanonicalStagingRows <> 0
       )
    BEGIN
        SET @UpdateStatus = N'FAILED';
        SET @UpdateErrorNumber = 51054;
        SET @UpdateErrorMessage =
            N'UPDATE_ALL2 completed but the exact row/scan/duplicate/staging-boundary receipt failed.';
    END;

    INSERT #BenchmarkResults
    (
        BenchmarkRunId,
        WorkloadCategory,
        WorkloadName,
        Scenario,
        RunKind,
        RunNumber,
        IsWriteCapable,
        TransactionMode,
        StartedAtUtc,
        FinishedAtUtc,
        DurationMs,
        CpuMs,
        LogicalReads,
        PhysicalReads,
        Writes,
        ResultRowCount,
        ResultDigestSha256,
        LogUsedBeforeMB,
        LogUsedAfterMB,
        LogUsedDeltaMB,
        TempdbUsedBeforeMB,
        TempdbUsedAfterMB,
        TempdbUsedDeltaMB,
        Status,
        ErrorNumber,
        ErrorMessage,
        Notes
    )
    VALUES
    (
        @BenchmarkRunId,
        N'import_end_to_end',
        N'UPDATE_ALL2',
        N'committed_fresh_restore',
        CASE WHEN @UpdateAll2RunOrdinal = 0
             THEN N'warmup'
             ELSE N'measured'
        END,
        @UpdateAll2RunOrdinal,
        1,
        N'committed',
        @UpdateStartedAtUtc,
        @UpdateFinishedAtUtc,
        CONVERT(
            decimal(19,3),
            DATEDIFF_BIG(
                microsecond,
                @UpdateStartedAtUtc,
                @UpdateFinishedAtUtc
            ) / 1000.0
        ),
        @UpdateCpuEnd - @UpdateCpuStart,
        @UpdateLogicalReadsEnd - @UpdateLogicalReadsStart,
        @UpdatePhysicalReadsEnd - @UpdatePhysicalReadsStart,
        @UpdateWritesEnd - @UpdateWritesStart,
        @UpdateRowCount,
        CONVERT(char(64), @UpdateDigest, 2),
        CONVERT(decimal(19,3), @UpdateLogStartBytes / 1048576.0),
        CONVERT(decimal(19,3), @UpdateLogEndBytes / 1048576.0),
        CONVERT(
            decimal(19,3),
            (@UpdateLogEndBytes - @UpdateLogStartBytes) / 1048576.0
        ),
        CONVERT(decimal(19,3), @UpdateTempdbStartBytes / 1048576.0),
        CONVERT(decimal(19,3), @UpdateTempdbEndBytes / 1048576.0),
        CONVERT(
            decimal(19,3),
            (@UpdateTempdbEndBytes - @UpdateTempdbStartBytes) / 1048576.0
        ),
        @UpdateStatus,
        @UpdateErrorNumber,
        @UpdateErrorMessage,
        N'Committed run. Restore the same backup before the next UPDATE_ALL2 ordinal.'
    );

    SELECT
        N'committed_import_receipt' AS EvidenceSection,
        @BenchmarkRunId AS BenchmarkRunId,
        @CommittedImportHarnessRevision AS HarnessRevision,
        @UpdateAll2RunOrdinal AS RunOrdinal,
        @UpdateStatus AS Status,
        @UpdateErrorNumber AS ErrorNumber,
        @UpdateErrorMessage AS ErrorMessage,
        @UpdatePreKs4Rows AS Ks4RowsBefore,
        @UpdatePostKs4Rows AS Ks4RowsAfter,
        @UpdatePostKs4Rows - @UpdatePreKs4Rows AS Ks4RowsAdded,
        @UpdatePreKs5Rows AS Ks5RowsBefore,
        @UpdatePostKs5Rows AS Ks5RowsAfter,
        @UpdatePostKs5Rows - @UpdatePreKs5Rows AS Ks5RowsAdded,
        @UpdatePreKs4MaxScan AS Ks4MaxScanBefore,
        @UpdatePostKs4MaxScan AS Ks4MaxScanAfter,
        @UpdatePreKs5MaxScan AS Ks5MaxScanBefore,
        @UpdatePostKs5MaxScan AS Ks5MaxScanAfter,
        @UpdatePostKs4LatestScanRows AS Ks4FinalScanRows,
        @UpdatePostKs5LatestScanRows AS Ks5FinalScanRows,
        @UpdatePostKs4LatestDistinctGovernors
            AS Ks4FinalScanDistinctGovernors,
        @UpdatePostKs5LatestDistinctGovernors
            AS Ks5FinalScanDistinctGovernors,
        @UpdatePostKs4LatestDuplicateRows AS Ks4FinalScanDuplicateRows,
        @UpdatePostKs5LatestDuplicateRows AS Ks5FinalScanDuplicateRows,
        @UpdatePostKs4LatestScanUnoMin AS Ks4FinalScanUnoMin,
        @UpdatePostKs4LatestScanUnoMax AS Ks4FinalScanUnoMax,
        @UpdatePostKs4LatestDistinctScanUno
            AS Ks4FinalScanDistinctScanUno,
        @UpdateRawStagingRows AS RawStagingRowsAfter,
        @UpdateTypedCsvStagingRows AS TypedCsvStagingRowsAfter,
        @UpdateCanonicalStagingRows AS CanonicalStagingRowsAfter,
        @UpdateRowsPerSecond AS RowsPerSecond,
        @UpdateLockWaitEndMs - @UpdateLockWaitStartMs AS LockWaitMs,
        @UpdateLockWaitEndCount - @UpdateLockWaitStartCount
            AS LockWaitCount,
        CONVERT(
            bit,
            CASE WHEN @UpdateErrorNumber = 1205 THEN 1 ELSE 0 END
        ) AS DeadlockVictim,
        CONVERT(
            decimal(19,3),
            @UpdateLogFileStartBytes / 1048576.0
        ) AS LogFileSizeBeforeMB,
        CONVERT(
            decimal(19,3),
            @UpdateLogFileEndBytes / 1048576.0
        ) AS LogFileSizeAfterMB,
        CONVERT(
            decimal(19,3),
            (@UpdateLogFileEndBytes - @UpdateLogFileStartBytes) / 1048576.0
        ) AS LogFileGrowthMB,
        @UpdateLogSinceBackupStartMB AS LogSinceBackupBeforeMB,
        @UpdateLogSinceBackupEndMB AS LogSinceBackupAfterMB,
        @UpdateLogSinceBackupEndMB - @UpdateLogSinceBackupStartMB
            AS LogGeneratedDeltaMB,
        CONVERT(
            decimal(19,3),
            (@UpdateTempdbEndBytes - @UpdateTempdbStartBytes) / 1048576.0
        ) AS TempdbUsedDeltaMB,
        CONVERT(char(64), @UpdateDigest, 2)
            AS Ks4MaterialDigestExcludingScanUnoSha256;
END;

/* Normalized evidence result sets. */
SELECT
    N'benchmark_configuration' AS EvidenceSection,
    @BenchmarkRunId AS BenchmarkRunId,
    @CollectedAtUtc AS CollectedAtUtc,
    CONVERT(sysname, SERVERPROPERTY(N'ServerName')) AS ServerName,
    DB_NAME() AS DatabaseName,
    @RequiredCurrentDatabase AS ExpectedTestDatabase,
    @MeasuredRunCount AS MeasuredRunCount,
    CONVERT(tinyint, 1) AS WarmupRunCount,
    @RunStandardSuite AS RunStandardSuite,
    @RunRollbackIsolatedWriters AS RunRollbackIsolatedWriters,
    @RunFullHistorySummaryEndToEnd AS RunFullHistorySummaryEndToEnd,
    @RunFullHistorySummaryComponents AS RunFullHistorySummaryComponents,
    @EmitProgressMessages AS EmitProgressMessages,
    @UpdateAll2RunOrdinal AS UpdateAll2RunOrdinal,
    @ConfirmIsolatedUpdateAll2Fixture AS ConfirmIsolatedUpdateAll2Fixture,
    @CommittedImportHarnessRevision AS CommittedImportHarnessRevision,
    CONVERT(bit, 0) AS CacheCleared,
    CONVERT(nvarchar(60), SERVERPROPERTY(N'ProductVersion'))
        AS SqlServerProductVersion,
    compatibility_level AS CompatibilityLevel,
    recovery_model_desc AS RecoveryModel,
    snapshot_isolation_state_desc AS SnapshotIsolationState,
    is_read_committed_snapshot_on AS IsReadCommittedSnapshotOn
FROM sys.databases
WHERE database_id = DB_ID();

SELECT
    N'representative_parameters' AS EvidenceSection,
    @BenchmarkRunId AS BenchmarkRunId,
    @SparseGovernorID AS SparseGovernorID,
    sparse_stats.ObservationCount AS SparseGovernorObservationCount,
    @MedianGovernorID AS MedianGovernorID,
    median_stats.ObservationCount AS MedianGovernorObservationCount,
    @HighActivityGovernorID AS HighActivityGovernorID,
    high_stats.ObservationCount AS HighActivityGovernorObservationCount,
    @AbsentGovernorID AS AbsentGovernorID,
    @EarliestScanOrder AS EarliestScanOrder,
    @HistoricalScanOrder AS HistoricalScanOrder,
    @LatestScanOrder AS LatestScanOrder,
    @EarliestAsOfDate AS EarliestAsOfDate,
    @HistoricalAsOfDate AS HistoricalAsOfDate,
    @LatestAsOfDate AS LatestAsOfDate,
    @BenchmarkNowUtc AS BenchmarkNowUtc
FROM #GovernorStats AS sparse_stats
JOIN #GovernorStats AS median_stats
  ON median_stats.GovernorID = @MedianGovernorID
JOIN #GovernorStats AS high_stats
  ON high_stats.GovernorID = @HighActivityGovernorID
WHERE sparse_stats.GovernorID = @SparseGovernorID;

SELECT
    N'benchmark_result' AS EvidenceSection,
    BenchmarkRunId,
    WorkloadCategory,
    WorkloadName,
    Scenario,
    RunKind,
    RunNumber,
    IsWriteCapable,
    TransactionMode,
    StartedAtUtc,
    FinishedAtUtc,
    DurationMs,
    CpuMs,
    LogicalReads,
    PhysicalReads,
    Writes,
    ResultRowCount,
    ResultDigestSha256,
    LogUsedBeforeMB,
    LogUsedAfterMB,
    LogUsedDeltaMB,
    TempdbUsedBeforeMB,
    TempdbUsedAfterMB,
    TempdbUsedDeltaMB,
    Status,
    ErrorNumber,
    ErrorMessage,
    Notes
FROM #BenchmarkResults
ORDER BY
    WorkloadCategory,
    WorkloadName,
    Scenario,
    CASE RunKind
        WHEN N'warmup' THEN 0
        WHEN N'measured' THEN 1
        ELSE 2
    END,
    RunNumber;

;WITH SuccessfulMeasured AS
(
    SELECT *
    FROM #BenchmarkResults
    WHERE RunKind = N'measured'
      AND Status = N'SUCCEEDED'
),
MeasuredAggregates AS
(
    SELECT
        WorkloadCategory,
        WorkloadName,
        Scenario,
        COUNT(*) AS SuccessfulMeasuredRuns,
        CONVERT(decimal(19,3), AVG(DurationMs)) AS AverageDurationMs,
        CONVERT(
            decimal(38,3),
            AVG(CONVERT(decimal(38,3), LogicalReads))
        ) AS AverageLogicalReads,
        CONVERT(
            decimal(38,3),
            AVG(CONVERT(decimal(38,3), PhysicalReads))
        ) AS AveragePhysicalReads,
        CONVERT(
            decimal(38,3),
            AVG(CONVERT(decimal(38,3), Writes))
        ) AS AverageWrites,
        MIN(ResultRowCount) AS MinimumResultRowCount,
        MAX(ResultRowCount) AS MaximumResultRowCount,
        COUNT(DISTINCT ResultDigestSha256) AS DistinctResultDigests
    FROM SuccessfulMeasured
    GROUP BY WorkloadCategory, WorkloadName, Scenario
),
MeasuredPercentiles AS
(
    SELECT DISTINCT
        WorkloadCategory,
        WorkloadName,
        Scenario,
        CONVERT(
            decimal(19,3),
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DurationMs)
            OVER (PARTITION BY WorkloadCategory, WorkloadName, Scenario)
        ) AS MedianDurationMs,
        CONVERT(
            decimal(19,3),
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CpuMs)
            OVER (PARTITION BY WorkloadCategory, WorkloadName, Scenario)
        ) AS MedianCpuMs
    FROM SuccessfulMeasured
)
SELECT
    N'benchmark_summary' AS EvidenceSection,
    @BenchmarkRunId AS BenchmarkRunId,
    aggregate_stats.WorkloadCategory,
    aggregate_stats.WorkloadName,
    aggregate_stats.Scenario,
    aggregate_stats.SuccessfulMeasuredRuns,
    percentile_stats.MedianDurationMs,
    aggregate_stats.AverageDurationMs,
    percentile_stats.MedianCpuMs,
    aggregate_stats.AverageLogicalReads,
    aggregate_stats.AveragePhysicalReads,
    aggregate_stats.AverageWrites,
    aggregate_stats.MinimumResultRowCount,
    aggregate_stats.MaximumResultRowCount,
    aggregate_stats.DistinctResultDigests,
    CASE
        WHEN aggregate_stats.SuccessfulMeasuredRuns <> @MeasuredRunCount
            THEN N'INCOMPLETE'
        WHEN aggregate_stats.MinimumResultRowCount
             <> aggregate_stats.MaximumResultRowCount
            THEN N'ROW_COUNT_VARIANCE'
        WHEN aggregate_stats.DistinctResultDigests <> 1
            THEN N'DIGEST_VARIANCE'
        ELSE N'STABLE'
    END AS StabilityStatus
FROM MeasuredAggregates AS aggregate_stats
JOIN MeasuredPercentiles AS percentile_stats
  ON percentile_stats.WorkloadCategory = aggregate_stats.WorkloadCategory
 AND percentile_stats.WorkloadName = aggregate_stats.WorkloadName
 AND percentile_stats.Scenario = aggregate_stats.Scenario
ORDER BY
    aggregate_stats.WorkloadCategory,
    aggregate_stats.WorkloadName,
    aggregate_stats.Scenario;

SELECT
    N'benchmark_issue' AS EvidenceSection,
    BenchmarkRunId,
    WorkloadCategory,
    WorkloadName,
    Scenario,
    RunKind,
    RunNumber,
    Status,
    ErrorNumber,
    ErrorMessage,
    Notes
FROM #BenchmarkResults
WHERE Status <> N'SUCCEEDED'
ORDER BY WorkloadCategory, WorkloadName, Scenario, RunNumber;
