/*
Purpose:
    Read-only ownership and parameter evidence for the retained
    KingdomScanData4 Query Store shortlist.

Run:
    - Run in the database whose Query Store contains the query_id/plan_id
      values captured by 03_collect_query_store_baseline.sql.
    - Results to File, preserving the complete .rpt.
    - Do not run in tempdb or master.

Safety:
    - No data, schema, Query Store, plan, or cache changes.
    - Fails if any retained query/plan pair is absent.

Revision: 20260725.2
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @CollectorRevision nvarchar(32) = N'20260725.2';
DECLARE @CollectedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @SinceUtc datetimeoffset(7) = DATEADD(DAY, -30, SYSUTCDATETIME());

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    THROW 51070,
        'Run 07_collect_query_store_owner_parameter_map.sql in the captured application database.',
        1;
END;

IF ISNULL(HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'VIEW DATABASE STATE'), 0) <> 1
   AND IS_SRVROLEMEMBER(N'sysadmin') <> 1
BEGIN
    THROW 51071,
        'VIEW DATABASE STATE or sysadmin is required to read the Query Store ownership receipt.',
        1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_query_store_options AS options
    WHERE options.actual_state_desc IN (N'READ_ONLY', N'READ_WRITE')
)
BEGIN
    THROW 51072, 'Query Store is not readable in the current database.', 1;
END;

CREATE TABLE #Target
(
    QueryId bigint NOT NULL,
    PlanId bigint NOT NULL,
    ExpectedOwner nvarchar(776) COLLATE DATABASE_DEFAULT NOT NULL,
    RepresentativeScenario nvarchar(2000) COLLATE DATABASE_DEFAULT NOT NULL,
    RequiredAfterBaseline nvarchar(2000) COLLATE DATABASE_DEFAULT NOT NULL,
    CONSTRAINT PK_Target PRIMARY KEY (QueryId, PlanId)
);

DECLARE @CommittedImportScenario nvarchar(2000) =
    N'UPDATE_ALL2 @param1=NULL, @param2=NULL; fixture SHA-256 '
    + N'AC7FF4794067617738318594AA96ADD32069FB43C1C81943BD3A46C9A317BB26; '
    + N'fresh seed KS4 394506/scan 1020 and KS5 394526/scan 1020; '
    + N'expect 411 rows in each target, scan 1021, no duplicates and digest '
    + N'D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463.';
DECLARE @CommittedImportAfter nvarchar(2000) =
    N'Restore the same seed before each run; rerun committed-import ordinal 0 '
    + N'plus measured ordinals 1-5 and exact row/scan/value/digest reconciliation.';
DECLARE @LeadershipReviewScenario nvarchar(2000) =
    N'EXEC dbo.usp_GetLeadershipPlayerReview @GovernorID=2441482, '
    + N'@PeriodDays=90, @NowUtc=''2026-07-23T09:55:00''; high-activity '
    + N'governor with 1019 observations on the retained restored copy.';
DECLARE @LeadershipReviewAfter nvarchar(2000) =
    N'Rerun the pinned high-activity leadership-review scenario with one warm-up '
    + N'and five measured executions; reconcile every result set, row count, '
    + N'column contract and deterministic digest.';
DECLARE @AccountsScenario nvarchar(2000) =
    N'player_self_service.accounts_dal.fetch_latest_accounts_scan_rows for ordered IDs '
    + N'(2352446,154112523,2441482,228689487,583354): sparse, median, '
    + N'high-activity, absent and additional existing governor.';
DECLARE @AccountsAfter nvarchar(2000) =
    N'Rerun the five-ID accounts DAL smoke/materialization with one warm-up and '
    + N'five measured executions; preserve requested-ID ordering and reconcile '
    + N'rows, nulls, types and deterministic digest.';

INSERT INTO #Target
(
    QueryId,
    PlanId,
    ExpectedOwner,
    RepresentativeScenario,
    RequiredAfterBaseline
)
VALUES
    (125393, 15558, N'dbo.UPDATE_ALL2',
        @CommittedImportScenario, @CommittedImportAfter),
    (49472, 4949, N'dbo.CREATE_THE_AVERAGES',
        @CommittedImportScenario, @CommittedImportAfter),
    (144113, 16877, N'dbo.usp_GetLeadershipPlayerReview',
        @LeadershipReviewScenario, @LeadershipReviewAfter),
    (52300, 8473, N'dbo.UPDATE_ALL2',
        @CommittedImportScenario, @CommittedImportAfter),
    (143117, 16603, N'dbo.usp_UpsertGovernorNameHistoryForScan',
        @CommittedImportScenario, @CommittedImportAfter),
    (125576, 15435, N'dbo.GOVERNOR_NAMES_PROC',
        @CommittedImportScenario, @CommittedImportAfter),
    (143234, 16658, N'dbo.usp_GetLeadershipPlayerReview',
        @LeadershipReviewScenario, @LeadershipReviewAfter),
    (143319, 16735, N'dbo.usp_GetLeadershipPlayerReview',
        @LeadershipReviewScenario, @LeadershipReviewAfter),
    (143049, 16547, N'dbo.usp_GetLeadershipPlayerReview',
        @LeadershipReviewScenario, @LeadershipReviewAfter),
    (23307, 12884, N'dbo.GOVERNOR_NAMES_PROC',
        @CommittedImportScenario, @CommittedImportAfter),
    (67494, 10394, N'dbo.SUMMARY_PROC',
        @CommittedImportScenario, @CommittedImportAfter),
    (140333, 16354,
        N'ad hoc: player_self_service/accounts_dal.py:fetch_latest_accounts_scan_rows',
        @AccountsScenario, @AccountsAfter);

SELECT
    N'query_store_owner_map_context' AS EvidenceSection,
    @CollectorRevision AS CollectorRevision,
    DB_NAME() AS DatabaseName,
    SUSER_SNAME() AS CollectorLogin,
    IS_SRVROLEMEMBER(N'sysadmin') AS IsSysadmin,
    HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'VIEW DATABASE STATE')
        AS HasViewDatabaseState,
    options.actual_state_desc AS QueryStoreActualState,
    options.desired_state_desc AS QueryStoreDesiredState,
    options.query_capture_mode_desc AS QueryCaptureMode,
    (SELECT COUNT_BIG(*) FROM #Target) AS RequiredPairCount,
    @SinceUtc AS RuntimeWindowStartUtc,
    @CollectedAtUtc AS CollectedAtUtc
FROM sys.database_query_store_options AS options;

SELECT
    N'query_store_owner_map_missing' AS EvidenceSection,
    target.QueryId,
    target.PlanId,
    target.ExpectedOwner
FROM #Target AS target
LEFT JOIN sys.query_store_query AS query_store_query
  ON query_store_query.query_id = target.QueryId
LEFT JOIN sys.query_store_plan AS query_store_plan
  ON query_store_plan.query_id = target.QueryId
 AND query_store_plan.plan_id = target.PlanId
WHERE query_store_query.query_id IS NULL
   OR query_store_plan.plan_id IS NULL
ORDER BY target.QueryId, target.PlanId;

IF EXISTS
(
    SELECT 1
    FROM #Target AS target
    LEFT JOIN sys.query_store_query AS query_store_query
      ON query_store_query.query_id = target.QueryId
    LEFT JOIN sys.query_store_plan AS query_store_plan
      ON query_store_plan.query_id = target.QueryId
     AND query_store_plan.plan_id = target.PlanId
    WHERE query_store_query.query_id IS NULL
       OR query_store_plan.plan_id IS NULL
)
BEGIN
    THROW 51073,
        'One or more retained query_id/plan_id pairs are absent; run against the captured Query Store database.',
        1;
END;

;WITH Runtime AS
(
    SELECT
        runtime_stats.plan_id,
        SUM(CONVERT(bigint, runtime_stats.count_executions)) AS ExecutionCount,
        CONVERT
        (
            decimal(19, 3),
            SUM
            (
                CONVERT(float, runtime_stats.avg_duration)
                * runtime_stats.count_executions
            )
            / NULLIF(SUM(runtime_stats.count_executions), 0)
            / 1000.0
        ) AS WeightedAvgDurationMs,
        CONVERT
        (
            decimal(19, 3),
            SUM
            (
                CONVERT(float, runtime_stats.avg_cpu_time)
                * runtime_stats.count_executions
            )
            / NULLIF(SUM(runtime_stats.count_executions), 0)
            / 1000.0
        ) AS WeightedAvgCpuMs,
        CONVERT
        (
            decimal(19, 3),
            SUM
            (
                CONVERT(float, runtime_stats.avg_logical_io_reads)
                * runtime_stats.count_executions
            )
            / NULLIF(SUM(runtime_stats.count_executions), 0)
        ) AS WeightedAvgLogicalReads,
        CONVERT
        (
            decimal(19, 3),
            SUM
            (
                CONVERT(float, runtime_stats.avg_logical_io_writes)
                * runtime_stats.count_executions
            )
            / NULLIF(SUM(runtime_stats.count_executions), 0)
        ) AS WeightedAvgLogicalWrites,
        MAX(runtime_stats.last_execution_time) AS LastExecutionTime
    FROM sys.query_store_runtime_stats AS runtime_stats
    INNER JOIN sys.query_store_runtime_stats_interval AS interval
      ON interval.runtime_stats_interval_id =
         runtime_stats.runtime_stats_interval_id
    WHERE interval.end_time >= @SinceUtc
      AND runtime_stats.execution_type_desc = N'Regular'
    GROUP BY runtime_stats.plan_id
),
OwnerMap AS
(
    SELECT
        target.QueryId,
        target.PlanId,
        target.ExpectedOwner,
        target.RepresentativeScenario,
        target.RequiredAfterBaseline,
        query_store_query.object_id AS QueryStoreObjectId,
        CASE
            WHEN query_store_query.object_id = 0 THEN N'<ad hoc>'
            ELSE
                QUOTENAME
                (
                    OBJECT_SCHEMA_NAME(query_store_query.object_id)
                )
                + N'.'
                + QUOTENAME(OBJECT_NAME(query_store_query.object_id))
        END AS QueryStoreOwner,
        objects.type_desc AS OwnerType,
        query_store_query.query_parameterization_type_desc
            AS ParameterizationType,
        query_store_query.count_compiles AS CountCompiles,
        query_store_query.last_compile_start_time AS LastCompileStartTime,
        query_store_plan.is_forced_plan AS IsForcedPlan,
        query_store_plan.force_failure_count AS ForceFailureCount,
        query_store_plan.last_force_failure_reason_desc
            AS LastForceFailureReason,
        query_store_plan.compatibility_level AS PlanCompatibilityLevel,
        query_store_text.query_sql_text AS QuerySqlText,
        query_store_plan.query_plan AS QueryPlanText,
        runtime.ExecutionCount,
        runtime.WeightedAvgDurationMs,
        runtime.WeightedAvgCpuMs,
        runtime.WeightedAvgLogicalReads,
        runtime.WeightedAvgLogicalWrites,
        runtime.LastExecutionTime
    FROM #Target AS target
    INNER JOIN sys.query_store_query AS query_store_query
      ON query_store_query.query_id = target.QueryId
    INNER JOIN sys.query_store_query_text AS query_store_text
      ON query_store_text.query_text_id = query_store_query.query_text_id
    INNER JOIN sys.query_store_plan AS query_store_plan
      ON query_store_plan.query_id = target.QueryId
     AND query_store_plan.plan_id = target.PlanId
    LEFT JOIN sys.objects AS objects
      ON objects.object_id = query_store_query.object_id
    LEFT JOIN Runtime AS runtime
      ON runtime.plan_id = target.PlanId
)
SELECT
    N'query_store_owner_parameter_map' AS EvidenceSection,
    owner_map.QueryId,
    owner_map.PlanId,
    owner_map.ExpectedOwner,
    owner_map.QueryStoreObjectId,
    owner_map.QueryStoreOwner,
    owner_map.OwnerType,
    CASE
        WHEN owner_map.QueryStoreObjectId = 0
         AND owner_map.ExpectedOwner LIKE N'ad hoc:%'
            THEN N'MATCH_STATIC_AD_HOC'
        WHEN
            REPLACE(REPLACE(owner_map.QueryStoreOwner, N'[', N''), N']', N'')
            = owner_map.ExpectedOwner
            THEN N'MATCH_QUERY_STORE_OBJECT'
        ELSE N'MISMATCH_REVIEW_REQUIRED'
    END AS OwnerMatchStatus,
    owner_map.ParameterizationType,
    owner_map.CountCompiles,
    owner_map.LastCompileStartTime,
    owner_map.IsForcedPlan,
    owner_map.ForceFailureCount,
    owner_map.LastForceFailureReason,
    owner_map.PlanCompatibilityLevel,
    owner_map.ExecutionCount AS RuntimeExecutionCount30d,
    owner_map.WeightedAvgDurationMs AS RuntimeAvgDurationMs30d,
    owner_map.WeightedAvgCpuMs AS RuntimeAvgCpuMs30d,
    owner_map.WeightedAvgLogicalReads AS RuntimeAvgLogicalReads30d,
    owner_map.WeightedAvgLogicalWrites AS RuntimeAvgLogicalWrites30d,
    owner_map.LastExecutionTime,
    LEN(owner_map.QuerySqlText) AS QueryTextCharacterCount,
    CONVERT
    (
        varchar(64),
        HASHBYTES
        (
            N'SHA2_256',
            CONVERT(varbinary(max), owner_map.QuerySqlText)
        ),
        2
    ) AS QueryTextSha256,
    LEFT(owner_map.QuerySqlText, 4000) AS QueryTextPrefix,
    owner_map.RepresentativeScenario,
    owner_map.RequiredAfterBaseline
FROM OwnerMap AS owner_map
ORDER BY owner_map.QueryId, owner_map.PlanId;

;WITH PlanXml AS
(
    SELECT
        target.QueryId,
        target.PlanId,
        TRY_CONVERT(xml, query_store_plan.query_plan) AS ShowPlan
    FROM #Target AS target
    INNER JOIN sys.query_store_plan AS query_store_plan
      ON query_store_plan.query_id = target.QueryId
     AND query_store_plan.plan_id = target.PlanId
)
SELECT
    N'query_store_compiled_parameter_evidence' AS EvidenceSection,
    plan_xml.QueryId,
    plan_xml.PlanId,
    parameter_node.value(N'string((@Column)[1])', N'nvarchar(256)')
        AS ParameterName,
    parameter_node.value(N'string((@ParameterDataType)[1])', N'nvarchar(256)')
        AS ParameterDataType,
    NULLIF
    (
        parameter_node.value
        (
            N'string((@ParameterCompiledValue)[1])',
            N'nvarchar(4000)'
        ),
        N''
    ) AS ParameterCompiledValue,
    NULLIF
    (
        parameter_node.value
        (
            N'string((@ParameterRuntimeValue)[1])',
            N'nvarchar(4000)'
        ),
        N''
    ) AS ParameterRuntimeValue
FROM PlanXml AS plan_xml
CROSS APPLY plan_xml.ShowPlan.nodes
(
    N'//*[local-name()="ParameterList"]/*[local-name()="ColumnReference"]'
) AS parameter_nodes(parameter_node)
ORDER BY plan_xml.QueryId, plan_xml.PlanId, ParameterName;

;WITH Owners AS
(
    SELECT DISTINCT query_store_query.object_id
    FROM #Target AS target
    INNER JOIN sys.query_store_query AS query_store_query
      ON query_store_query.query_id = target.QueryId
    WHERE query_store_query.object_id > 0
)
SELECT
    N'query_store_owner_module_receipt' AS EvidenceSection,
    owners.object_id AS ObjectId,
    QUOTENAME(OBJECT_SCHEMA_NAME(owners.object_id))
        + N'.' + QUOTENAME(OBJECT_NAME(owners.object_id)) AS ObjectName,
    objects.type_desc AS ObjectType,
    sql_modules.uses_ansi_nulls AS UsesAnsiNulls,
    sql_modules.uses_quoted_identifier AS UsesQuotedIdentifier,
    sql_modules.is_schema_bound AS IsSchemaBound,
    LEN(sql_modules.definition) AS DefinitionCharacterCount,
    CONVERT
    (
        varchar(64),
        HASHBYTES
        (
            N'SHA2_256',
            CONVERT(varbinary(max), sql_modules.definition)
        ),
        2
    ) AS DefinitionSha256
FROM Owners AS owners
INNER JOIN sys.objects AS objects
  ON objects.object_id = owners.object_id
LEFT JOIN sys.sql_modules AS sql_modules
  ON sql_modules.object_id = owners.object_id
ORDER BY ObjectName;

SELECT
    N'query_store_owner_map_completion' AS EvidenceSection,
    @CollectorRevision AS CollectorRevision,
    COUNT_BIG(*) AS RequiredPairCount,
    SUM
    (
        CASE
            WHEN query_store_query.object_id = 0
             AND target.ExpectedOwner LIKE N'ad hoc:%'
                THEN 1
            WHEN
                REPLACE
                (
                    REPLACE
                    (
                        QUOTENAME
                        (
                            OBJECT_SCHEMA_NAME(query_store_query.object_id)
                        )
                        + N'.'
                        + QUOTENAME(OBJECT_NAME(query_store_query.object_id)),
                        N'[',
                        N''
                    ),
                    N']',
                    N''
                ) = target.ExpectedOwner
                THEN 1
            ELSE 0
        END
    ) AS MatchedOwnerCount,
    @CollectedAtUtc AS CollectedAtUtc
FROM #Target AS target
INNER JOIN sys.query_store_query AS query_store_query
  ON query_store_query.query_id = target.QueryId;
