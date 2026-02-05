SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_QS_PerfPack]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_QS_PerfPack] AS' 
END
ALTER PROCEDURE [dbo].[sp_QS_PerfPack]
	@LookbackDays [int] = 3,
	@TopN [int] = 25,
	@PersistSnapshot [bit] = 0,
	@Notes [nvarchar](4000) = NULL,
	@SingleResultset [bit] = 0,
	@SqlTextMaxLen [int] = 4000
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    -- Basic parameter guardrails
    IF @LookbackDays < 1 SET @LookbackDays = 1;
    IF @TopN < 1 SET @TopN = 1;
    IF @SqlTextMaxLen IS NULL OR @SqlTextMaxLen < 0 SET @SqlTextMaxLen = 0;

    DECLARE @StartTimeUtc datetime2(0) = DATEADD(DAY, -@LookbackDays, SYSUTCDATETIME());
    DECLARE @RunId bigint = NULL;

    -------------------------------------------------------------------------
    -- Optional snapshot header
    -------------------------------------------------------------------------
    IF @PersistSnapshot = 1
    BEGIN
        INSERT INTO dbo.QS_PerfPack_Run(LookbackDays, Notes)
        VALUES (@LookbackDays, @Notes);

        SET @RunId = SCOPE_IDENTITY();
    END;

    -------------------------------------------------------------------------
    -- Resultset 1: Query Store configuration (always returned first)
    -------------------------------------------------------------------------
    SELECT
        actual_state_desc,
        desired_state_desc,
        current_storage_size_mb,
        max_storage_size_mb,
        interval_length_minutes,
        stale_query_threshold_days,
        wait_stats_capture_mode_desc
    FROM sys.database_query_store_options;

    -------------------------------------------------------------------------
    -- Materialise common lookback aggregations so we can reuse across sections
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#Agg') IS NOT NULL DROP TABLE #Agg;
    IF OBJECT_ID('tempdb..#Texts') IS NOT NULL DROP TABLE #Texts;
    IF OBJECT_ID('tempdb..#WaitAgg') IS NOT NULL DROP TABLE #WaitAgg;
    IF OBJECT_ID('tempdb..#Regressions') IS NOT NULL DROP TABLE #Regressions;
    IF OBJECT_ID('tempdb..#Report') IS NOT NULL DROP TABLE #Report;

    -- Runtime aggregation over lookback window
    SELECT
        qsq.query_id,
        COUNT(DISTINCT qsp.plan_id) AS plan_count,
        SUM(rs.count_executions) AS executions,

        -- totals (duration/cpu are in microseconds; reads are counts)
        SUM(CONVERT(bigint, rs.count_executions) * CONVERT(bigint, rs.avg_duration))           AS total_duration_us,
        SUM(CONVERT(bigint, rs.count_executions) * CONVERT(bigint, rs.avg_cpu_time))           AS total_cpu_us,
        SUM(CONVERT(bigint, rs.count_executions) * CONVERT(bigint, rs.avg_logical_io_reads))   AS total_logical_reads,

        -- weighted avgs
        CAST(SUM(CONVERT(bigint, rs.count_executions) * CONVERT(bigint, rs.avg_duration))
             / NULLIF(SUM(rs.count_executions),0) AS bigint) AS avg_duration_us,
        CAST(SUM(CONVERT(bigint, rs.count_executions) * CONVERT(bigint, rs.avg_cpu_time))
             / NULLIF(SUM(rs.count_executions),0) AS bigint) AS avg_cpu_us,
        CAST(SUM(CONVERT(bigint, rs.count_executions) * CONVERT(bigint, rs.avg_logical_io_reads))
             / NULLIF(SUM(rs.count_executions),0) AS bigint) AS avg_logical_reads
    INTO #Agg
    FROM sys.query_store_runtime_stats rs
    JOIN sys.query_store_runtime_stats_interval rsi
        ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
    JOIN sys.query_store_plan qsp
        ON qsp.plan_id = rs.plan_id
    JOIN sys.query_store_query qsq
        ON qsq.query_id = qsp.query_id
    WHERE rsi.start_time >= @StartTimeUtc
    GROUP BY qsq.query_id;

    CREATE UNIQUE CLUSTERED INDEX CX_Agg ON #Agg(query_id);

    -- Text + hash + truncation
    SELECT
        qsq.query_id,
        qst.query_sql_text,
        CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), qst.query_sql_text)), 2) AS query_text_hash,
        CASE
            WHEN @SqlTextMaxLen = 0 THEN CAST(NULL AS nvarchar(max))
            WHEN LEN(qst.query_sql_text) <= @SqlTextMaxLen THEN qst.query_sql_text
            ELSE LEFT(qst.query_sql_text, @SqlTextMaxLen) + N' …(truncated)'
        END AS query_sql_text_trunc
    INTO #Texts
    FROM sys.query_store_query qsq
    JOIN sys.query_store_query_text qst
        ON qst.query_text_id = qsq.query_text_id;

    CREATE UNIQUE CLUSTERED INDEX CX_Texts ON #Texts(query_id);

    -- Waits aggregation (lookback window)
    SELECT
        qsp.query_id,
        ws.wait_category_desc,
        SUM(CONVERT(bigint, ws.total_query_wait_time_ms)) AS total_wait_time_ms
    INTO #WaitAgg
    FROM sys.query_store_wait_stats ws
    JOIN sys.query_store_plan qsp
        ON qsp.plan_id = ws.plan_id
    JOIN sys.query_store_runtime_stats_interval rsi
        ON rsi.runtime_stats_interval_id = ws.runtime_stats_interval_id
    WHERE rsi.start_time >= @StartTimeUtc
    GROUP BY qsp.query_id, ws.wait_category_desc;

    CREATE INDEX IX_WaitAgg_Query ON #WaitAgg(query_id);

    -------------------------------------------------------------------------
    -- Single unified resultset support (collects rows into #Report)
    -------------------------------------------------------------------------
    CREATE TABLE #Report (
        report_section           varchar(40)   NOT NULL,
        metric                   varchar(30)   NULL,

        query_id                 bigint        NULL,
        plan_count               int           NULL,
        executions               bigint        NULL,

        avg_duration_us          bigint        NULL,
        avg_cpu_us               bigint        NULL,
        avg_logical_reads        bigint        NULL,

        total_duration_us        bigint        NULL,
        total_cpu_us             bigint        NULL,
        total_logical_reads      bigint        NULL,

        wait_category_desc       nvarchar(60)  NULL,
        total_wait_time_ms       bigint        NULL,
        avg_wait_time_ms         bigint        NULL,

        baseline_execs           bigint        NULL,
        recent_execs             bigint        NULL,
        baseline_avg_duration_us bigint        NULL,
        recent_avg_duration_us   bigint        NULL,
        delta_avg_duration_us    bigint        NULL,
        pct_change_avg_duration  decimal(10,2) NULL,

        query_text_hash          varchar(64)   NULL,
        query_sql_text_trunc     nvarchar(max) NULL
    );

    -------------------------------------------------------------------------
    -- Resultset 2: Top by avg duration
    -------------------------------------------------------------------------
    IF @SingleResultset = 0
    BEGIN
        SELECT TOP (@TopN)
            'TOP_BY_AVG_DURATION' AS report_section,
            a.query_id,
            a.plan_count,
            a.executions,
            a.avg_duration_us,
            a.avg_cpu_us,
            a.avg_logical_reads,
            a.total_duration_us,
            a.total_cpu_us,
            a.total_logical_reads,
            t.query_sql_text
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_duration_us DESC;
    END
    ELSE
    BEGIN
        INSERT INTO #Report
        (
            report_section, metric,
            query_id, plan_count, executions,
            avg_duration_us, avg_cpu_us, avg_logical_reads,
            total_duration_us, total_cpu_us, total_logical_reads,
            query_text_hash, query_sql_text_trunc
        )
        SELECT TOP (@TopN)
            'TOP_BY_AVG_DURATION', 'DURATION',
            a.query_id, a.plan_count, a.executions,
            a.avg_duration_us, a.avg_cpu_us, a.avg_logical_reads,
            a.total_duration_us, a.total_cpu_us, a.total_logical_reads,
            t.query_text_hash, t.query_sql_text_trunc
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_duration_us DESC;
    END;

    IF @PersistSnapshot = 1
    BEGIN
        INSERT INTO dbo.QS_PerfPack_TopQueries
        (RunId, Metric, query_id, plan_count, executions, avg_duration_us, avg_cpu_us, avg_logical_reads,
         total_duration_us, total_cpu_us, total_logical_reads, query_sql_text)
        SELECT TOP (@TopN)
            @RunId, 'DURATION', a.query_id, a.plan_count, a.executions,
            a.avg_duration_us, a.avg_cpu_us, a.avg_logical_reads,
            a.total_duration_us, a.total_cpu_us, a.total_logical_reads,
            t.query_sql_text
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_duration_us DESC;
    END;

    -------------------------------------------------------------------------
    -- Resultset 3: Top by avg CPU
    -------------------------------------------------------------------------
    IF @SingleResultset = 0
    BEGIN
        SELECT TOP (@TopN)
            'TOP_BY_AVG_CPU' AS report_section,
            a.query_id,
            a.plan_count,
            a.executions,
            a.avg_cpu_us,
            a.avg_duration_us,
            a.avg_logical_reads,
            a.total_cpu_us,
            a.total_duration_us,
            a.total_logical_reads,
            t.query_sql_text
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_cpu_us DESC;
    END
    ELSE
    BEGIN
        INSERT INTO #Report
        (
            report_section, metric,
            query_id, plan_count, executions,
            avg_duration_us, avg_cpu_us, avg_logical_reads,
            total_duration_us, total_cpu_us, total_logical_reads,
            query_text_hash, query_sql_text_trunc
        )
        SELECT TOP (@TopN)
            'TOP_BY_AVG_CPU', 'CPU',
            a.query_id, a.plan_count, a.executions,
            a.avg_duration_us, a.avg_cpu_us, a.avg_logical_reads,
            a.total_duration_us, a.total_cpu_us, a.total_logical_reads,
            t.query_text_hash, t.query_sql_text_trunc
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_cpu_us DESC;
    END;

    IF @PersistSnapshot = 1
    BEGIN
        INSERT INTO dbo.QS_PerfPack_TopQueries
        (RunId, Metric, query_id, plan_count, executions, avg_duration_us, avg_cpu_us, avg_logical_reads,
         total_duration_us, total_cpu_us, total_logical_reads, query_sql_text)
        SELECT TOP (@TopN)
            @RunId, 'CPU', a.query_id, a.plan_count, a.executions,
            a.avg_duration_us, a.avg_cpu_us, a.avg_logical_reads,
            a.total_duration_us, a.total_cpu_us, a.total_logical_reads,
            t.query_sql_text
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_cpu_us DESC;
    END;

    -------------------------------------------------------------------------
    -- Resultset 4: Top by avg logical reads
    -------------------------------------------------------------------------
    IF @SingleResultset = 0
    BEGIN
        SELECT TOP (@TopN)
            'TOP_BY_AVG_READS' AS report_section,
            a.query_id,
            a.plan_count,
            a.executions,
            a.avg_logical_reads,
            a.avg_duration_us,
            a.avg_cpu_us,
            a.total_logical_reads,
            a.total_duration_us,
            a.total_cpu_us,
            t.query_sql_text
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_logical_reads DESC;
    END
    ELSE
    BEGIN
        INSERT INTO #Report
        (
            report_section, metric,
            query_id, plan_count, executions,
            avg_duration_us, avg_cpu_us, avg_logical_reads,
            total_duration_us, total_cpu_us, total_logical_reads,
            query_text_hash, query_sql_text_trunc
        )
        SELECT TOP (@TopN)
            'TOP_BY_AVG_READS', 'READS',
            a.query_id, a.plan_count, a.executions,
            a.avg_duration_us, a.avg_cpu_us, a.avg_logical_reads,
            a.total_duration_us, a.total_cpu_us, a.total_logical_reads,
            t.query_text_hash, t.query_sql_text_trunc
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_logical_reads DESC;
    END;

    IF @PersistSnapshot = 1
    BEGIN
        INSERT INTO dbo.QS_PerfPack_TopQueries
        (RunId, Metric, query_id, plan_count, executions, avg_duration_us, avg_cpu_us, avg_logical_reads,
         total_duration_us, total_cpu_us, total_logical_reads, query_sql_text)
        SELECT TOP (@TopN)
            @RunId, 'READS', a.query_id, a.plan_count, a.executions,
            a.avg_duration_us, a.avg_cpu_us, a.avg_logical_reads,
            a.total_duration_us, a.total_cpu_us, a.total_logical_reads,
            t.query_sql_text
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        ORDER BY a.avg_logical_reads DESC;
    END;

    -------------------------------------------------------------------------
    -- Resultset 5: Top waits by query
    -------------------------------------------------------------------------
    IF @SingleResultset = 0
    BEGIN
        SELECT TOP (@TopN)
            'TOP_WAITS_BY_QUERY' AS report_section,
            w.query_id,
            w.wait_category_desc,
            w.total_wait_time_ms,
            CAST(w.total_wait_time_ms / NULLIF(a.executions, 0) AS bigint) AS avg_wait_time_ms,
            a.executions,
            t.query_sql_text
        FROM #WaitAgg w
        JOIN #Agg a
            ON a.query_id = w.query_id
        JOIN #Texts t
            ON t.query_id = w.query_id
        ORDER BY w.total_wait_time_ms DESC;
    END
    ELSE
    BEGIN
        INSERT INTO #Report
        (
            report_section, metric,
            query_id, executions,
            wait_category_desc, total_wait_time_ms, avg_wait_time_ms,
            query_text_hash, query_sql_text_trunc
        )
        SELECT TOP (@TopN)
            'TOP_WAITS_BY_QUERY', 'WAITS',
            w.query_id, a.executions,
            w.wait_category_desc,
            w.total_wait_time_ms,
            CAST(w.total_wait_time_ms / NULLIF(a.executions, 0) AS bigint) AS avg_wait_time_ms,
            t.query_text_hash,
            t.query_sql_text_trunc
        FROM #WaitAgg w
        JOIN #Agg a
            ON a.query_id = w.query_id
        JOIN #Texts t
            ON t.query_id = w.query_id
        ORDER BY w.total_wait_time_ms DESC;
    END;

    IF @PersistSnapshot = 1
    BEGIN
        INSERT INTO dbo.QS_PerfPack_Waits
        (RunId, query_id, wait_category_desc, total_wait_time_ms, avg_wait_time_ms, executions, query_sql_text)
        SELECT TOP (@TopN)
            @RunId,
            w.query_id,
            w.wait_category_desc,
            w.total_wait_time_ms,
            CAST(w.total_wait_time_ms / NULLIF(a.executions, 0) AS bigint) AS avg_wait_time_ms,
            a.executions,
            t.query_sql_text
        FROM #WaitAgg w
        JOIN #Agg a
            ON a.query_id = w.query_id
        JOIN #Texts t
            ON t.query_id = w.query_id
        ORDER BY w.total_wait_time_ms DESC;
    END;

    -------------------------------------------------------------------------
    -- Resultset 6: Recent regressions (duration) - version safe
    -- (CTE is used only for the SELECT INTO #Regressions statement)
    -------------------------------------------------------------------------
    DECLARE @RecentStartUtc   datetime2(0) = @StartTimeUtc;
    DECLARE @RecentEndUtc     datetime2(0) = SYSUTCDATETIME();
    DECLARE @BaselineStartUtc datetime2(0) = DATEADD(DAY, -@LookbackDays * 2, SYSUTCDATETIME());
    DECLARE @BaselineEndUtc   datetime2(0) = DATEADD(DAY, -@LookbackDays, SYSUTCDATETIME());

    ;WITH RS AS (
        SELECT
            qsp.query_id,
            CASE
                WHEN rsi.start_time >= @RecentStartUtc   AND rsi.start_time < @RecentEndUtc   THEN 'RECENT'
                WHEN rsi.start_time >= @BaselineStartUtc AND rsi.start_time < @BaselineEndUtc THEN 'BASELINE'
                ELSE NULL
            END AS period,
            SUM(rs.count_executions) AS execs,
            CAST(SUM(CONVERT(bigint, rs.count_executions) * CONVERT(bigint, rs.avg_duration))
                 / NULLIF(SUM(rs.count_executions),0) AS bigint) AS avg_duration_us
        FROM sys.query_store_runtime_stats rs
        JOIN sys.query_store_runtime_stats_interval rsi
            ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
        JOIN sys.query_store_plan qsp
            ON qsp.plan_id = rs.plan_id
        WHERE (rsi.start_time >= @BaselineStartUtc AND rsi.start_time < @RecentEndUtc)
        GROUP BY qsp.query_id,
            CASE
                WHEN rsi.start_time >= @RecentStartUtc   AND rsi.start_time < @RecentEndUtc   THEN 'RECENT'
                WHEN rsi.start_time >= @BaselineStartUtc AND rsi.start_time < @BaselineEndUtc THEN 'BASELINE'
                ELSE NULL
            END
    ),
    Pivoted AS (
        SELECT
            query_id,
            MAX(CASE WHEN period = 'BASELINE' THEN execs END) AS baseline_execs,
            MAX(CASE WHEN period = 'BASELINE' THEN avg_duration_us END) AS baseline_avg_duration_us,
            MAX(CASE WHEN period = 'RECENT' THEN execs END) AS recent_execs,
            MAX(CASE WHEN period = 'RECENT' THEN avg_duration_us END) AS recent_avg_duration_us
        FROM RS
        WHERE period IS NOT NULL
        GROUP BY query_id
    )
    SELECT TOP (@TopN)
        p.query_id,
        p.baseline_execs,
        p.recent_execs,
        p.baseline_avg_duration_us,
        p.recent_avg_duration_us,
        CAST((p.recent_avg_duration_us - p.baseline_avg_duration_us) AS bigint) AS delta_avg_duration_us,
        CAST(
            (100.0 * (p.recent_avg_duration_us - p.baseline_avg_duration_us))
            / NULLIF(p.baseline_avg_duration_us, 0) AS decimal(10,2)
        ) AS pct_change_avg_duration
    INTO #Regressions
    FROM Pivoted p
    WHERE p.baseline_execs IS NOT NULL
      AND p.recent_execs IS NOT NULL
      AND p.baseline_execs >= 2
      AND p.recent_execs >= 2
      AND p.baseline_avg_duration_us > 0
      AND p.recent_avg_duration_us > p.baseline_avg_duration_us
      AND ( (p.recent_avg_duration_us - p.baseline_avg_duration_us) >= 250000 ) -- >= 250ms
    ORDER BY pct_change_avg_duration DESC, delta_avg_duration_us DESC;

    IF @SingleResultset = 0
    BEGIN
        SELECT
            'RECENT_REGRESSIONS' AS report_section,
            r.query_id,
            r.baseline_execs,
            r.recent_execs,
            r.baseline_avg_duration_us,
            r.recent_avg_duration_us,
            r.delta_avg_duration_us,
            r.pct_change_avg_duration,
            t.query_sql_text
        FROM #Regressions r
        JOIN #Texts t
            ON t.query_id = r.query_id
        ORDER BY r.pct_change_avg_duration DESC, r.delta_avg_duration_us DESC;
    END
    ELSE
    BEGIN
        INSERT INTO #Report
        (
            report_section, metric,
            query_id,
            baseline_execs, recent_execs,
            baseline_avg_duration_us, recent_avg_duration_us,
            delta_avg_duration_us, pct_change_avg_duration,
            query_text_hash, query_sql_text_trunc
        )
        SELECT
            'RECENT_REGRESSIONS', 'REGRESSION',
            r.query_id,
            r.baseline_execs, r.recent_execs,
            r.baseline_avg_duration_us, r.recent_avg_duration_us,
            r.delta_avg_duration_us, r.pct_change_avg_duration,
            t.query_text_hash,
            t.query_sql_text_trunc
        FROM #Regressions r
        JOIN #Texts t
            ON t.query_id = r.query_id
        ORDER BY r.pct_change_avg_duration DESC, r.delta_avg_duration_us DESC;
    END;

    -------------------------------------------------------------------------
    -- Resultset 7: Multi-plan queries (parameter sensitivity suspects)
    -------------------------------------------------------------------------
    IF @SingleResultset = 0
    BEGIN
        SELECT TOP (@TopN)
            'MULTI_PLAN_QUERIES' AS report_section,
            a.query_id,
            a.plan_count,
            a.executions,
            a.avg_duration_us,
            a.avg_cpu_us,
            a.avg_logical_reads,
            t.query_sql_text
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        WHERE a.plan_count >= 5
        ORDER BY a.plan_count DESC, a.avg_duration_us DESC;
    END
    ELSE
    BEGIN
        INSERT INTO #Report
        (
            report_section, metric,
            query_id, plan_count, executions,
            avg_duration_us, avg_cpu_us, avg_logical_reads,
            query_text_hash, query_sql_text_trunc
        )
        SELECT TOP (@TopN)
            'MULTI_PLAN_QUERIES', 'MULTIPLAN',
            a.query_id, a.plan_count, a.executions,
            a.avg_duration_us, a.avg_cpu_us, a.avg_logical_reads,
            t.query_text_hash, t.query_sql_text_trunc
        FROM #Agg a
        JOIN #Texts t ON t.query_id = a.query_id
        WHERE a.plan_count >= 5
        ORDER BY a.plan_count DESC, a.avg_duration_us DESC;
    END;

    -------------------------------------------------------------------------
    -- Final output: single unified dataset (if enabled)
    -------------------------------------------------------------------------
    IF @SingleResultset = 1
    BEGIN
        SELECT
            report_section,
            metric,
            query_id,
            plan_count,
            executions,
            avg_duration_us,
            avg_cpu_us,
            avg_logical_reads,
            total_duration_us,
            total_cpu_us,
            total_logical_reads,
            wait_category_desc,
            total_wait_time_ms,
            avg_wait_time_ms,
            baseline_execs,
            recent_execs,
            baseline_avg_duration_us,
            recent_avg_duration_us,
            delta_avg_duration_us,
            pct_change_avg_duration,
            query_text_hash,
            query_sql_text_trunc
        FROM #Report
        ORDER BY
            CASE report_section
                WHEN 'RECENT_REGRESSIONS' THEN 1
                WHEN 'TOP_BY_AVG_DURATION' THEN 2
                WHEN 'TOP_BY_AVG_CPU' THEN 3
                WHEN 'TOP_BY_AVG_READS' THEN 4
                WHEN 'TOP_WAITS_BY_QUERY' THEN 5
                WHEN 'MULTI_PLAN_QUERIES' THEN 6
                ELSE 99
            END,
            COALESCE(pct_change_avg_duration, 0) DESC,
            COALESCE(total_wait_time_ms, 0) DESC,
            COALESCE(avg_duration_us, 0) DESC,
            COALESCE(avg_cpu_us, 0) DESC,
            COALESCE(avg_logical_reads, 0) DESC;
    END
END;

