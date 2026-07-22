/*
Phase 8.1 leadership performance evidence harness.

Read-only and intentionally non-automatic:
- In the same private SSMS session, create #Phase81GovernorCases with four approved rows before
  running this tracked script. Never put real Governor IDs in this repository file.
- Run from SSMS/Azure Data Studio in an approved measurement window.
- Enable Include Actual Execution Plan before execution.
- For a single save containing every heterogeneous result set, select SSMS Results to File
  (Ctrl+Shift+F) before execution and save as restricted .rpt or .txt evidence. CSV export saves
  only one selected result grid and cannot preserve the six different procedure result schemas.
- Save raw .sqlplan, Messages, Results and client elapsed time only below the ignored private
  reports/phase81_private directory. Treat them as restricted leadership data.
- Never commit or share raw plans/Results. Before sharing a summary, remove Governor IDs, names,
  row values, location/shield data, and plan ParameterCompiledValue/ParameterRuntimeValue fields.
- Do not clear the plan cache or buffer pool.
- Do not run this script concurrently or use it as a load test.

Case selection:
- recent_dense: present in the latest scan with dense activity
- long_tenure: substantial 720-day scan history
- sparse: missing scans/source observations
- high_history: high alias/alliance history and three finalized KVKs where possible

Private session-table shape (create and populate in an untracked query tab on the same connection):
CREATE TABLE #Phase81GovernorCases
(
    CaseName nvarchar(32) NOT NULL PRIMARY KEY,
    GovernorID bigint NOT NULL
);
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @EffectiveNowUtc datetime2(0) = SYSUTCDATETIME();
DECLARE @MeasurementStartedUtc datetime2(0) = @EffectiveNowUtc;
DECLARE @Cases table
(
    CaseName nvarchar(32) NOT NULL PRIMARY KEY,
    GovernorID bigint NOT NULL
);

IF OBJECT_ID(N'tempdb..#Phase81GovernorCases') IS NULL
    THROW 51980, 'Create private #Phase81GovernorCases input before running this harness.', 1;

INSERT INTO @Cases (CaseName, GovernorID)
SELECT CaseName, GovernorID
FROM #Phase81GovernorCases;

IF (SELECT COUNT(*) FROM @Cases) <> 4
   OR EXISTS (SELECT 1 FROM @Cases WHERE GovernorID IS NULL OR GovernorID <= 0)
   OR (SELECT COUNT(DISTINCT GovernorID) FROM @Cases) <> 4
   OR EXISTS
      (
          SELECT 1 FROM @Cases
          WHERE CaseName NOT IN (N'recent_dense', N'long_tenure', N'sparse', N'high_history')
      )
    THROW 51982, 'Use the four named cases with four distinct positive Governor IDs.', 1;

/* Table and index shape. Usage counters are since the last SQL Server restart. */
SELECT @MeasurementStartedUtc AS MeasurementStartedUtc,
       sql_info.sqlserver_start_time AS SqlServerStartTime
FROM sys.dm_os_sys_info AS sql_info;

SELECT OBJECT_SCHEMA_NAME(indexes.object_id) AS SchemaName,
       OBJECT_NAME(indexes.object_id) AS TableName,
       indexes.index_id,
       indexes.name AS IndexName,
       indexes.type_desc,
       indexes.is_unique,
       indexes.is_primary_key,
       indexes.is_disabled,
       indexes.has_filter,
       indexes.filter_definition,
       columns.key_ordinal,
       columns.index_column_id,
       table_columns.name AS ColumnName,
       column_types.name AS ColumnType,
       table_columns.max_length AS ColumnMaxBytes,
       table_columns.is_nullable AS ColumnIsNullable,
       columns.is_included_column,
       index_storage.TotalRowCount AS TableRowCount,
       CONVERT(decimal(18,2), index_storage.ReservedPages * 8.0 / 1024.0) AS ReservedMb,
       CONVERT(decimal(18,2), index_storage.UsedPages * 8.0 / 1024.0) AS UsedMb,
       usage.user_seeks,
       usage.user_scans,
       usage.user_lookups,
       usage.user_updates,
       COALESCE(usage.user_seeks, 0) + COALESCE(usage.user_scans, 0)
           + COALESCE(usage.user_lookups, 0) AS TotalReads,
       CASE WHEN COALESCE(usage.user_updates, 0) = 0 THEN NULL
            ELSE CONVERT(decimal(18,2),
                 (COALESCE(usage.user_seeks, 0) + COALESCE(usage.user_scans, 0)
                  + COALESCE(usage.user_lookups, 0)) * 1.0
                 / usage.user_updates) END AS ReadsPerWrite,
       usage.last_user_seek,
       usage.last_user_scan,
       usage.last_user_lookup
FROM sys.indexes AS indexes
JOIN sys.index_columns AS columns
  ON columns.object_id = indexes.object_id
 AND columns.index_id = indexes.index_id
JOIN sys.columns AS table_columns
  ON table_columns.object_id = columns.object_id
 AND table_columns.column_id = columns.column_id
JOIN sys.types AS column_types
  ON column_types.user_type_id = table_columns.user_type_id
LEFT JOIN
(
    SELECT object_id, index_id,
           SUM(row_count) AS TotalRowCount,
           SUM(reserved_page_count) AS ReservedPages,
           SUM(used_page_count) AS UsedPages
    FROM sys.dm_db_partition_stats
    GROUP BY object_id, index_id
) AS index_storage
  ON index_storage.object_id = indexes.object_id
 AND index_storage.index_id = indexes.index_id
LEFT JOIN sys.dm_db_index_usage_stats AS usage
  ON usage.database_id = DB_ID()
 AND usage.object_id = indexes.object_id
 AND usage.index_id = indexes.index_id
WHERE indexes.object_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.AllianceActivitySnapshotHeader'),
    OBJECT_ID(N'dbo.AllianceActivitySnapshotRow'),
    OBJECT_ID(N'dbo.RallyDailySnapshotHeader'),
    OBJECT_ID(N'dbo.cur_RallyDaily'),
    OBJECT_ID(N'dbo.GovernorNameHistory'),
    OBJECT_ID(N'dbo.KVK_Details'),
    OBJECT_ID(N'dbo.KVK_History')
)
ORDER BY TableName, indexes.index_id, columns.is_included_column, columns.key_ordinal,
         columns.index_column_id;

/* Statistics age and sampled-row evidence. */
SELECT OBJECT_SCHEMA_NAME(stats.object_id) AS SchemaName,
       OBJECT_NAME(stats.object_id) AS TableName,
       stats.name AS StatisticsName,
       properties.last_updated,
       properties.rows,
       properties.rows_sampled,
       properties.steps,
       properties.modification_counter,
       CASE WHEN properties.rows > 0
            THEN CONVERT(decimal(9,2), properties.rows_sampled * 100.0 / properties.rows)
            ELSE NULL END AS SamplePercent
FROM sys.stats AS stats
CROSS APPLY sys.dm_db_stats_properties(stats.object_id, stats.stats_id) AS properties
WHERE stats.object_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.AllianceActivitySnapshotHeader'),
    OBJECT_ID(N'dbo.AllianceActivitySnapshotRow'),
    OBJECT_ID(N'dbo.RallyDailySnapshotHeader'),
    OBJECT_ID(N'dbo.cur_RallyDaily')
)
ORDER BY TableName, StatisticsName;

/* Lock/latch evidence for the existing indexes. */
SELECT OBJECT_NAME(operational.object_id) AS TableName,
       indexes.name AS IndexName,
       SUM(operational.range_scan_count) AS RangeScans,
       SUM(operational.singleton_lookup_count) AS SingletonLookups,
       SUM(operational.row_lock_wait_count) AS RowLockWaits,
       SUM(operational.row_lock_wait_in_ms) AS RowLockWaitMs,
       SUM(operational.page_lock_wait_count) AS PageLockWaits,
       SUM(operational.page_lock_wait_in_ms) AS PageLockWaitMs,
       SUM(operational.page_latch_wait_count) AS PageLatchWaits,
       SUM(operational.page_latch_wait_in_ms) AS PageLatchWaitMs
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) AS operational
JOIN sys.indexes AS indexes
  ON indexes.object_id = operational.object_id
 AND indexes.index_id = operational.index_id
WHERE operational.object_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.AllianceActivitySnapshotHeader'),
    OBJECT_ID(N'dbo.AllianceActivitySnapshotRow'),
    OBJECT_ID(N'dbo.RallyDailySnapshotHeader'),
    OBJECT_ID(N'dbo.cur_RallyDaily')
)
GROUP BY operational.object_id, indexes.name
ORDER BY TableName, IndexName;

/*
Cached procedure history is captured before and after. Deltas are valid only when the cached-plan
set remains identical; a recompile deliberately produces NULL deltas rather than false evidence.
*/
DECLARE @ProcedureStatsBefore table
(
    object_id int NOT NULL PRIMARY KEY,
    PlanCount int NOT NULL,
    EarliestCachedTime datetime NOT NULL,
    LatestCachedTime datetime NOT NULL,
    LastExecutionTime datetime NULL,
    ExecutionCount bigint NOT NULL,
    TotalWorkerTime bigint NOT NULL,
    TotalElapsedTime bigint NOT NULL,
    TotalLogicalReads bigint NOT NULL,
    TotalPhysicalReads bigint NOT NULL,
    TotalLogicalWrites bigint NOT NULL
);

INSERT INTO @ProcedureStatsBefore
    (object_id, PlanCount, EarliestCachedTime, LatestCachedTime, LastExecutionTime,
     ExecutionCount, TotalWorkerTime, TotalElapsedTime, TotalLogicalReads,
     TotalPhysicalReads, TotalLogicalWrites)
SELECT procedure_stats.object_id,
       COUNT(*) AS PlanCount,
       MIN(procedure_stats.cached_time),
       MAX(procedure_stats.cached_time),
       MAX(procedure_stats.last_execution_time),
       SUM(procedure_stats.execution_count),
       SUM(procedure_stats.total_worker_time),
       SUM(procedure_stats.total_elapsed_time),
       SUM(procedure_stats.total_logical_reads),
       SUM(procedure_stats.total_physical_reads),
       SUM(procedure_stats.total_logical_writes)
FROM sys.dm_exec_procedure_stats AS procedure_stats
WHERE procedure_stats.database_id = DB_ID()
  AND procedure_stats.object_id IN
  (
      OBJECT_ID(N'dbo.usp_GetLeadershipPlayerReview'),
      OBJECT_ID(N'dbo.usp_GetLeadershipPlayerLastActive'),
      OBJECT_ID(N'dbo.usp_GetLeadershipPlayerKvkHistory'),
      OBJECT_ID(N'dbo.usp_GetLeadershipPlayerIdentityHistory')
  )
GROUP BY procedure_stats.object_id;

SELECT N'BEFORE_HARNESS' AS CapturePoint,
       OBJECT_NAME(before_stats.object_id) AS ProcedureName,
       before_stats.*
FROM @ProcedureStatsBefore AS before_stats
ORDER BY ProcedureName;

/* Query Store history is metadata-only here: do not select query text or plan XML. */
SELECT desired_state_desc, actual_state_desc, readonly_reason,
       current_storage_size_mb, max_storage_size_mb,
       query_capture_mode_desc, interval_length_minutes
FROM sys.database_query_store_options;

SELECT OBJECT_NAME(query_store_query.object_id) AS ProcedureName,
       query_store_plan.plan_id,
       MIN(runtime_interval.start_time) AS FirstIntervalUtc,
       MAX(runtime_interval.end_time) AS LastIntervalUtc,
       SUM(runtime_stats.count_executions) AS ExecutionCount,
       CONVERT(decimal(18,2),
           SUM(runtime_stats.avg_duration * runtime_stats.count_executions)
           / NULLIF(SUM(runtime_stats.count_executions), 0)) AS WeightedAvgDurationUs,
       MAX(runtime_stats.max_duration) AS MaxDurationUs,
       MAX(runtime_stats.stdev_duration) AS MaxIntervalStdevDurationUs,
       CONVERT(decimal(18,2),
           SUM(runtime_stats.avg_cpu_time * runtime_stats.count_executions)
           / NULLIF(SUM(runtime_stats.count_executions), 0)) AS WeightedAvgCpuUs,
       CONVERT(decimal(18,2),
           SUM(runtime_stats.avg_logical_io_reads * runtime_stats.count_executions)
           / NULLIF(SUM(runtime_stats.count_executions), 0)) AS WeightedAvgLogicalReads
FROM sys.query_store_query AS query_store_query
JOIN sys.query_store_plan AS query_store_plan
  ON query_store_plan.query_id = query_store_query.query_id
JOIN sys.query_store_runtime_stats AS runtime_stats
  ON runtime_stats.plan_id = query_store_plan.plan_id
JOIN sys.query_store_runtime_stats_interval AS runtime_interval
  ON runtime_interval.runtime_stats_interval_id = runtime_stats.runtime_stats_interval_id
WHERE query_store_query.object_id IN
(
    OBJECT_ID(N'dbo.usp_GetLeadershipPlayerReview'),
    OBJECT_ID(N'dbo.usp_GetLeadershipPlayerLastActive'),
    OBJECT_ID(N'dbo.usp_GetLeadershipPlayerKvkHistory'),
    OBJECT_ID(N'dbo.usp_GetLeadershipPlayerIdentityHistory')
)
  AND runtime_interval.end_time >= DATEADD(DAY, -7, SYSUTCDATETIME())
GROUP BY query_store_query.object_id, query_store_plan.plan_id
ORDER BY ProcedureName, query_store_plan.plan_id;

DECLARE @CaseName nvarchar(32);
DECLARE @GovernorID bigint;
DECLARE @GovernorIDs dbo.IntList;

DECLARE case_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CaseName, GovernorID FROM @Cases ORDER BY CaseName;
OPEN case_cursor;
FETCH NEXT FROM case_cursor INTO @CaseName, @GovernorID;

WHILE @@FETCH_STATUS = 0
BEGIN
    RAISERROR(N'PHASE81 case=%s pass=first_sql_execution period=30', 0, 1,
              @CaseName) WITH NOWAIT;
    EXEC dbo.usp_GetLeadershipPlayerReview
         @GovernorID = @GovernorID, @PeriodDays = 30, @NowUtc = @EffectiveNowUtc;

    RAISERROR(N'PHASE81 case=%s pass=repeat_sql_execution period=30', 0, 1,
              @CaseName) WITH NOWAIT;
    EXEC dbo.usp_GetLeadershipPlayerReview
         @GovernorID = @GovernorID, @PeriodDays = 30, @NowUtc = @EffectiveNowUtc;

    RAISERROR(N'PHASE81 case=%s pass=first_sql_execution period=90', 0, 1,
              @CaseName) WITH NOWAIT;
    EXEC dbo.usp_GetLeadershipPlayerReview
         @GovernorID = @GovernorID, @PeriodDays = 90, @NowUtc = @EffectiveNowUtc;

    RAISERROR(N'PHASE81 case=%s pass=first_sql_execution period=180', 0, 1,
              @CaseName) WITH NOWAIT;
    EXEC dbo.usp_GetLeadershipPlayerReview
         @GovernorID = @GovernorID, @PeriodDays = 180, @NowUtc = @EffectiveNowUtc;

    RAISERROR(N'PHASE81 case=%s pass=first_sql_execution period=360', 0, 1,
              @CaseName) WITH NOWAIT;
    EXEC dbo.usp_GetLeadershipPlayerReview
         @GovernorID = @GovernorID, @PeriodDays = 360, @NowUtc = @EffectiveNowUtc;

    RAISERROR(N'PHASE81 case=%s contract=last_active', 0, 1,
              @CaseName) WITH NOWAIT;
    EXEC dbo.usp_GetLeadershipPlayerLastActive
         @GovernorID = @GovernorID, @HistoryDays = 720, @NowUtc = @EffectiveNowUtc;

    RAISERROR(N'PHASE81 case=%s contract=kvk_history', 0, 1,
              @CaseName) WITH NOWAIT;
    EXEC dbo.usp_GetLeadershipPlayerKvkHistory
         @GovernorID = @GovernorID, @CandidateLimit = 20;

    DELETE FROM @GovernorIDs;
    INSERT INTO @GovernorIDs (ID) VALUES (@GovernorID);
    RAISERROR(N'PHASE81 case=%s contract=identity_history', 0, 1,
              @CaseName) WITH NOWAIT;
    EXEC dbo.usp_GetLeadershipPlayerIdentityHistory
         @GovernorIDs = @GovernorIDs, @HistoryDays = 720;

    FETCH NEXT FROM case_cursor INTO @CaseName, @GovernorID;
END;

CLOSE case_cursor;
DEALLOCATE case_cursor;

WITH ProcedureStatsAfter AS
(
    SELECT procedure_stats.object_id,
           COUNT(*) AS PlanCount,
           MIN(procedure_stats.cached_time) AS EarliestCachedTime,
           MAX(procedure_stats.cached_time) AS LatestCachedTime,
           MAX(procedure_stats.last_execution_time) AS LastExecutionTime,
           SUM(procedure_stats.execution_count) AS ExecutionCount,
           SUM(procedure_stats.total_worker_time) AS TotalWorkerTime,
           SUM(procedure_stats.total_elapsed_time) AS TotalElapsedTime,
           SUM(procedure_stats.total_logical_reads) AS TotalLogicalReads,
           SUM(procedure_stats.total_physical_reads) AS TotalPhysicalReads,
           SUM(procedure_stats.total_logical_writes) AS TotalLogicalWrites
    FROM sys.dm_exec_procedure_stats AS procedure_stats
    WHERE procedure_stats.database_id = DB_ID()
      AND procedure_stats.object_id IN
      (
          OBJECT_ID(N'dbo.usp_GetLeadershipPlayerReview'),
          OBJECT_ID(N'dbo.usp_GetLeadershipPlayerLastActive'),
          OBJECT_ID(N'dbo.usp_GetLeadershipPlayerKvkHistory'),
          OBJECT_ID(N'dbo.usp_GetLeadershipPlayerIdentityHistory')
      )
    GROUP BY procedure_stats.object_id
)
SELECT N'AFTER_HARNESS' AS CapturePoint,
       OBJECT_NAME(after_stats.object_id) AS ProcedureName,
       after_stats.PlanCount,
       after_stats.EarliestCachedTime,
       after_stats.LatestCachedTime,
       after_stats.LastExecutionTime,
       after_stats.ExecutionCount,
       after_stats.TotalWorkerTime,
       after_stats.TotalElapsedTime,
       after_stats.TotalLogicalReads,
       after_stats.TotalPhysicalReads,
       after_stats.TotalLogicalWrites,
       CASE WHEN before_stats.PlanCount = after_stats.PlanCount
                  AND before_stats.EarliestCachedTime = after_stats.EarliestCachedTime
                  AND before_stats.LatestCachedTime = after_stats.LatestCachedTime
            THEN CONVERT(bit, 1) ELSE CONVERT(bit, 0) END AS PlanBaselineComparable,
       CASE WHEN before_stats.PlanCount = after_stats.PlanCount
                  AND before_stats.EarliestCachedTime = after_stats.EarliestCachedTime
                  AND before_stats.LatestCachedTime = after_stats.LatestCachedTime
            THEN after_stats.ExecutionCount - before_stats.ExecutionCount END
           AS HarnessExecutionCount,
       CASE WHEN before_stats.PlanCount = after_stats.PlanCount
                  AND before_stats.EarliestCachedTime = after_stats.EarliestCachedTime
                  AND before_stats.LatestCachedTime = after_stats.LatestCachedTime
            THEN after_stats.TotalWorkerTime - before_stats.TotalWorkerTime END
           AS HarnessWorkerTime,
       CASE WHEN before_stats.PlanCount = after_stats.PlanCount
                  AND before_stats.EarliestCachedTime = after_stats.EarliestCachedTime
                  AND before_stats.LatestCachedTime = after_stats.LatestCachedTime
            THEN after_stats.TotalElapsedTime - before_stats.TotalElapsedTime END
           AS HarnessElapsedTime,
       CASE WHEN before_stats.PlanCount = after_stats.PlanCount
                  AND before_stats.EarliestCachedTime = after_stats.EarliestCachedTime
                  AND before_stats.LatestCachedTime = after_stats.LatestCachedTime
            THEN after_stats.TotalLogicalReads - before_stats.TotalLogicalReads END
           AS HarnessLogicalReads,
       CASE WHEN before_stats.PlanCount = after_stats.PlanCount
                  AND before_stats.EarliestCachedTime = after_stats.EarliestCachedTime
                  AND before_stats.LatestCachedTime = after_stats.LatestCachedTime
            THEN after_stats.TotalPhysicalReads - before_stats.TotalPhysicalReads END
           AS HarnessPhysicalReads,
       CASE WHEN before_stats.PlanCount = after_stats.PlanCount
                  AND before_stats.EarliestCachedTime = after_stats.EarliestCachedTime
                  AND before_stats.LatestCachedTime = after_stats.LatestCachedTime
            THEN after_stats.TotalLogicalWrites - before_stats.TotalLogicalWrites END
           AS HarnessLogicalWrites
FROM ProcedureStatsAfter AS after_stats
LEFT JOIN @ProcedureStatsBefore AS before_stats
  ON before_stats.object_id = after_stats.object_id
ORDER BY ProcedureName;

/*
Missing-index DMVs are workload hints, not recommendations. Retain a row only after its
actual plan operator, logical-read reduction, write cost, overlap and concurrency impact
are demonstrated against the same representative matrix.
*/
SELECT OBJECT_NAME(details.object_id) AS TableName,
       groups.index_group_handle,
       group_stats.user_seeks,
       group_stats.user_scans,
       group_stats.unique_compiles,
       group_stats.last_user_seek,
       group_stats.avg_total_user_cost,
       group_stats.avg_user_impact,
       details.equality_columns,
       details.inequality_columns,
       details.included_columns
FROM sys.dm_db_missing_index_group_stats AS group_stats
JOIN sys.dm_db_missing_index_groups AS groups
  ON groups.index_group_handle = group_stats.group_handle
JOIN sys.dm_db_missing_index_details AS details
  ON details.index_handle = groups.index_handle
WHERE details.database_id = DB_ID()
  AND details.object_id IN
  (
      OBJECT_ID(N'dbo.KingdomScanData4'),
      OBJECT_ID(N'dbo.AllianceActivitySnapshotHeader'),
      OBJECT_ID(N'dbo.AllianceActivitySnapshotRow'),
      OBJECT_ID(N'dbo.RallyDailySnapshotHeader'),
      OBJECT_ID(N'dbo.cur_RallyDaily')
  )
ORDER BY group_stats.avg_total_user_cost * group_stats.avg_user_impact
         * (group_stats.user_seeks + group_stats.user_scans) DESC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
