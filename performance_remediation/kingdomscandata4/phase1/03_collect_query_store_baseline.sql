/*
Purpose: Read-only Query Store baseline for statements that reference KingdomScanData4.
Safety: No cache clearing, plan forcing, procedure execution, or data/schema changes.
Default window: last 30 days.
*/

SET NOCOUNT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF DB_NAME() <> N'ROK_TRACKER'
BEGIN
    THROW 51000, 'Run this collector only in the ROK_TRACKER database.', 1;
END;

DECLARE @SinceUtc datetime2(0) = DATEADD(day, -30, SYSUTCDATETIME());

SELECT
    N'query_store_collection_context' AS EvidenceSection,
    @SinceUtc AS SinceUtc,
    SYSUTCDATETIME() AS CollectedAtUtc,
    actual_state_desc AS ActualState,
    desired_state_desc AS DesiredState,
    readonly_reason AS ReadonlyReason,
    current_storage_size_mb AS CurrentStorageSizeMb,
    max_storage_size_mb AS MaxStorageSizeMb,
    query_capture_mode_desc AS QueryCaptureMode
FROM sys.database_query_store_options;

IF EXISTS (
    SELECT 1
    FROM sys.database_query_store_options
    WHERE actual_state_desc IN (N'READ_WRITE', N'READ_ONLY')
)
BEGIN
    ;WITH Runtime AS (
        SELECT
            q.query_id,
            p.plan_id,
            qt.query_sql_text,
            SUM(CONVERT(bigint, rs.count_executions)) AS ExecutionCount,
            SUM(rs.avg_duration * rs.count_executions)
                / NULLIF(SUM(CONVERT(float, rs.count_executions)), 0) AS WeightedAvgDurationUs,
            MAX(rs.max_duration) AS MaxDurationUs,
            SUM(rs.avg_cpu_time * rs.count_executions)
                / NULLIF(SUM(CONVERT(float, rs.count_executions)), 0) AS WeightedAvgCpuUs,
            MAX(rs.max_cpu_time) AS MaxCpuUs,
            SUM(rs.avg_logical_io_reads * rs.count_executions)
                / NULLIF(SUM(CONVERT(float, rs.count_executions)), 0) AS WeightedAvgLogicalReads,
            MAX(rs.max_logical_io_reads) AS MaxLogicalReads,
            SUM(rs.avg_logical_io_writes * rs.count_executions)
                / NULLIF(SUM(CONVERT(float, rs.count_executions)), 0) AS WeightedAvgLogicalWrites,
            MAX(rs.max_logical_io_writes) AS MaxLogicalWrites,
            SUM(rs.avg_physical_io_reads * rs.count_executions)
                / NULLIF(SUM(CONVERT(float, rs.count_executions)), 0) AS WeightedAvgPhysicalReads,
            MAX(rs.max_query_max_used_memory) AS MaxQueryMemory8KbPages,
            MIN(rsi.start_time) AS FirstIntervalStart,
            MAX(rsi.end_time) AS LastIntervalEnd,
            MAX(rs.last_execution_time) AS LastExecutionTime
        FROM sys.query_store_query_text AS qt
        JOIN sys.query_store_query AS q
          ON q.query_text_id = qt.query_text_id
        JOIN sys.query_store_plan AS p
          ON p.query_id = q.query_id
        JOIN sys.query_store_runtime_stats AS rs
          ON rs.plan_id = p.plan_id
        JOIN sys.query_store_runtime_stats_interval AS rsi
          ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
        WHERE rsi.end_time >= @SinceUtc
          AND qt.query_sql_text LIKE N'%KingdomScanData4%'
        GROUP BY q.query_id, p.plan_id, qt.query_sql_text
    )
    SELECT TOP (200)
        N'query_store_top_by_total_logical_reads' AS EvidenceSection,
        query_id AS QueryId,
        plan_id AS PlanId,
        ExecutionCount,
        CAST(WeightedAvgDurationUs / 1000.0 AS decimal(19, 3)) AS WeightedAvgDurationMs,
        CAST(MaxDurationUs / 1000.0 AS decimal(19, 3)) AS MaxDurationMs,
        CAST(WeightedAvgCpuUs / 1000.0 AS decimal(19, 3)) AS WeightedAvgCpuMs,
        CAST(MaxCpuUs / 1000.0 AS decimal(19, 3)) AS MaxCpuMs,
        CAST(WeightedAvgLogicalReads AS decimal(19, 3)) AS WeightedAvgLogicalReads,
        MaxLogicalReads,
        CAST(WeightedAvgLogicalWrites AS decimal(19, 3)) AS WeightedAvgLogicalWrites,
        MaxLogicalWrites,
        CAST(WeightedAvgPhysicalReads AS decimal(19, 3)) AS WeightedAvgPhysicalReads,
        MaxQueryMemory8KbPages,
        FirstIntervalStart,
        LastIntervalEnd,
        LastExecutionTime,
        query_sql_text AS QuerySqlText
    FROM Runtime
    ORDER BY WeightedAvgLogicalReads * ExecutionCount DESC, QueryId, PlanId;

    SELECT
        N'query_store_plans' AS EvidenceSection,
        q.query_id AS QueryId,
        p.plan_id AS PlanId,
        p.is_forced_plan AS IsForcedPlan,
        p.force_failure_count AS ForceFailureCount,
        p.last_force_failure_reason_desc AS LastForceFailureReason,
        p.compatibility_level AS CompatibilityLevel,
        p.engine_version AS EngineVersion,
        p.query_plan AS QueryPlan
    FROM sys.query_store_query_text AS qt
    JOIN sys.query_store_query AS q
      ON q.query_text_id = qt.query_text_id
    JOIN sys.query_store_plan AS p
      ON p.query_id = q.query_id
    WHERE qt.query_sql_text LIKE N'%KingdomScanData4%'
    ORDER BY q.query_id, p.plan_id;
END;
ELSE
BEGIN
    SELECT
        N'query_store_unavailable' AS EvidenceSection,
        N'Query Store is not readable. Supply a plan-cache export and representative actual plans.' AS RequiredAction;
END;
