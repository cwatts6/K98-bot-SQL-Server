/*
Purpose: Read-only Phase 1 inventory for dbo.KingdomScanData4.
Safety: No data or schema changes. No cache clearing. No procedure execution.
Target: ROK_TRACKER on the exact instance intended for remediation.
*/

SET NOCOUNT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF DB_NAME() <> N'ROK_TRACKER'
BEGIN
    THROW 51000, 'Run this collector only in the ROK_TRACKER database.', 1;
END;

DECLARE @TableObjectId int = OBJECT_ID(N'dbo.KingdomScanData4', N'U');

IF @TableObjectId IS NULL
BEGIN
    THROW 51001, 'dbo.KingdomScanData4 does not exist in the target database.', 1;
END;

SELECT
    N'target_environment' AS EvidenceSection,
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    ORIGINAL_LOGIN() AS OriginalLogin,
    CAST(SERVERPROPERTY(N'ProductVersion') AS nvarchar(128)) AS ProductVersion,
    CAST(SERVERPROPERTY(N'ProductLevel') AS nvarchar(128)) AS ProductLevel,
    CAST(SERVERPROPERTY(N'Edition') AS nvarchar(128)) AS Edition,
    CAST(SERVERPROPERTY(N'EngineEdition') AS int) AS EngineEdition,
    CAST(SERVERPROPERTY(N'IsHadrEnabled') AS int) AS IsHadrEnabled,
    d.compatibility_level AS CompatibilityLevel,
    d.collation_name AS DatabaseCollation,
    d.recovery_model_desc AS RecoveryModel,
    d.is_query_store_on AS IsQueryStoreOn,
    d.is_cdc_enabled AS IsCdcEnabled,
    d.snapshot_isolation_state_desc AS SnapshotIsolationState,
    d.is_read_committed_snapshot_on AS IsReadCommittedSnapshotOn,
    d.log_reuse_wait_desc AS LogReuseWait,
    d.create_date AS DatabaseCreateDate,
    (SELECT create_date FROM sys.databases WHERE name = N'tempdb') AS ApproximateInstanceStartTime
FROM sys.databases AS d
WHERE d.database_id = DB_ID();

SELECT
    N'query_store_options' AS EvidenceSection,
    actual_state_desc,
    desired_state_desc,
    readonly_reason,
    current_storage_size_mb,
    max_storage_size_mb,
    query_capture_mode_desc,
    size_based_cleanup_mode_desc,
    stale_query_threshold_days,
    wait_stats_capture_mode_desc
FROM sys.database_query_store_options;

SELECT
    N'table_properties' AS EvidenceSection,
    s.name AS SchemaName,
    t.name AS TableName,
    t.temporal_type_desc AS TemporalType,
    t.is_replicated AS IsReplicated,
    t.is_merge_published AS IsMergePublished,
    t.is_tracked_by_cdc AS IsTrackedByCdc,
    t.lock_escalation_desc AS LockEscalation,
    SUM(CASE WHEN p.index_id IN (0, 1) THEN p.rows ELSE 0 END) AS ApproximateRowCount,
    CAST(SUM(a.total_pages) * 8.0 / 1024.0 AS decimal(19, 2)) AS TotalSizeMb,
    CAST(SUM(a.used_pages) * 8.0 / 1024.0 AS decimal(19, 2)) AS UsedSizeMb,
    MIN(p.data_compression_desc) AS Compression,
    COUNT(DISTINCT p.data_compression_desc) AS CompressionKinds
FROM sys.tables AS t
JOIN sys.schemas AS s
  ON s.schema_id = t.schema_id
JOIN sys.partitions AS p
  ON p.object_id = t.object_id
JOIN sys.allocation_units AS a
  ON a.container_id = CASE WHEN a.type IN (1, 3) THEN p.hobt_id ELSE p.partition_id END
WHERE t.object_id = @TableObjectId
GROUP BY
    s.name,
    t.name,
    t.temporal_type_desc,
    t.is_replicated,
    t.is_merge_published,
    t.is_tracked_by_cdc,
    t.lock_escalation_desc;

SELECT
    N'columns' AS EvidenceSection,
    c.column_id AS ColumnOrdinal,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLengthBytes,
    c.precision AS [Precision],
    c.scale AS Scale,
    c.is_nullable AS IsNullable,
    c.collation_name AS CollationName,
    c.is_identity AS IsIdentity,
    c.is_computed AS IsComputed,
    cc.is_persisted AS IsPersisted,
    cc.definition AS ComputedDefinition,
    dc.name AS DefaultConstraintName,
    dc.definition AS DefaultDefinition
FROM sys.columns AS c
JOIN sys.types AS ty
  ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.computed_columns AS cc
  ON cc.object_id = c.object_id
 AND cc.column_id = c.column_id
LEFT JOIN sys.default_constraints AS dc
  ON dc.object_id = c.default_object_id
WHERE c.object_id = @TableObjectId
ORDER BY c.column_id;

SELECT
    N'constraints' AS EvidenceSection,
    o.type_desc AS ConstraintType,
    o.name AS ConstraintName,
    OBJECT_DEFINITION(o.object_id) AS ConstraintDefinition
FROM sys.objects AS o
WHERE o.parent_object_id = @TableObjectId
  AND o.type IN (N'C', N'D', N'F', N'PK', N'UQ')
ORDER BY o.type_desc, o.name;

;WITH KeyColumns AS (
    SELECT
        ic.object_id,
        ic.index_id,
        STRING_AGG(
            CONVERT(nvarchar(max), QUOTENAME(c.name))
                + CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N' ASC' END,
            N', '
        ) WITHIN GROUP (ORDER BY ic.key_ordinal) AS KeyColumns
    FROM sys.index_columns AS ic
    JOIN sys.columns AS c
      ON c.object_id = ic.object_id
     AND c.column_id = ic.column_id
    WHERE ic.object_id = @TableObjectId
      AND ic.is_included_column = 0
    GROUP BY ic.object_id, ic.index_id
),
IncludedColumns AS (
    SELECT
        ic.object_id,
        ic.index_id,
        STRING_AGG(
            CONVERT(nvarchar(max), QUOTENAME(c.name)),
            N', '
        ) WITHIN GROUP (ORDER BY ic.index_column_id) AS IncludedColumns
    FROM sys.index_columns AS ic
    JOIN sys.columns AS c
      ON c.object_id = ic.object_id
     AND c.column_id = ic.column_id
    WHERE ic.object_id = @TableObjectId
      AND ic.is_included_column = 1
    GROUP BY ic.object_id, ic.index_id
)
SELECT
    N'indexes_and_usage' AS EvidenceSection,
    i.index_id AS IndexId,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    kc.KeyColumns,
    inc.IncludedColumns,
    i.is_unique AS IsUnique,
    i.is_primary_key AS IsPrimaryKey,
    i.has_filter AS HasFilter,
    i.filter_definition AS FilterDefinition,
    i.fill_factor AS [FillFactor],
    i.is_disabled AS IsDisabled,
    COALESCE(us.user_seeks, 0) AS UserSeeksSinceRestart,
    COALESCE(us.user_scans, 0) AS UserScansSinceRestart,
    COALESCE(us.user_lookups, 0) AS UserLookupsSinceRestart,
    COALESCE(us.user_updates, 0) AS UserUpdatesSinceRestart,
    us.last_user_seek AS LastUserSeek,
    us.last_user_scan AS LastUserScan,
    us.last_user_lookup AS LastUserLookup,
    us.last_user_update AS LastUserUpdate
FROM sys.indexes AS i
LEFT JOIN KeyColumns AS kc
  ON kc.object_id = i.object_id
 AND kc.index_id = i.index_id
LEFT JOIN IncludedColumns AS inc
  ON inc.object_id = i.object_id
 AND inc.index_id = i.index_id
LEFT JOIN sys.dm_db_index_usage_stats AS us
  ON us.database_id = DB_ID()
 AND us.object_id = i.object_id
 AND us.index_id = i.index_id
WHERE i.object_id = @TableObjectId
  AND i.index_id > 0
  AND i.is_hypothetical = 0
ORDER BY i.index_id;

SELECT
    N'statistics' AS EvidenceSection,
    st.stats_id AS StatisticsId,
    st.name AS StatisticsName,
    st.auto_created AS IsAutoCreated,
    st.user_created AS IsUserCreated,
    st.no_recompute AS NoRecompute,
    sp.last_updated AS LastUpdated,
    sp.rows AS SampledObjectRows,
    sp.rows_sampled AS RowsSampled,
    sp.steps AS HistogramSteps,
    sp.modification_counter AS ModificationCounter,
    STUFF((
        SELECT N', ' + QUOTENAME(c.name)
        FROM sys.stats_columns AS sc
        JOIN sys.columns AS c
          ON c.object_id = sc.object_id
         AND c.column_id = sc.column_id
        WHERE sc.object_id = st.object_id
          AND sc.stats_id = st.stats_id
        ORDER BY sc.stats_column_id
        FOR XML PATH(N''), TYPE
    ).value(N'.', N'nvarchar(max)'), 1, 2, N'') AS StatisticsColumns
FROM sys.stats AS st
OUTER APPLY sys.dm_db_stats_properties(st.object_id, st.stats_id) AS sp
WHERE st.object_id = @TableObjectId
ORDER BY st.stats_id;

SELECT
    N'sql_expression_dependencies' AS EvidenceSection,
    OBJECT_SCHEMA_NAME(d.referencing_id) AS ReferencingSchema,
    OBJECT_NAME(d.referencing_id) AS ReferencingObject,
    o.type_desc AS ReferencingType,
    d.referenced_server_name AS ReferencedServer,
    d.referenced_database_name AS ReferencedDatabase,
    d.referenced_schema_name AS ReferencedSchema,
    d.referenced_entity_name AS ReferencedEntity,
    d.is_schema_bound_reference AS IsSchemaBoundReference,
    d.is_ambiguous AS IsAmbiguous
FROM sys.sql_expression_dependencies AS d
LEFT JOIN sys.objects AS o
  ON o.object_id = d.referencing_id
WHERE d.referenced_id = @TableObjectId
   OR (
       d.referenced_entity_name = N'KingdomScanData4'
       AND COALESCE(d.referenced_database_name, DB_NAME()) = DB_NAME()
   )
ORDER BY ReferencingSchema, ReferencingObject;

SELECT
    N'module_text_search' AS EvidenceSection,
    s.name AS SchemaName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType,
    o.modify_date AS ModifyDate,
    CONVERT(varchar(64), HASHBYTES(N'SHA2_256', CONVERT(varbinary(max), m.definition)), 2) AS DefinitionSha256,
    CASE WHEN d.referencing_id IS NULL THEN 0 ELSE 1 END AS FoundByDependencyMetadata
FROM sys.sql_modules AS m
JOIN sys.objects AS o
  ON o.object_id = m.object_id
JOIN sys.schemas AS s
  ON s.schema_id = o.schema_id
LEFT JOIN (
    SELECT DISTINCT referencing_id
    FROM sys.sql_expression_dependencies
    WHERE referenced_id = @TableObjectId
       OR referenced_entity_name = N'KingdomScanData4'
) AS d
  ON d.referencing_id = o.object_id
WHERE m.definition LIKE N'%KingdomScanData4%'
ORDER BY s.name, o.name;

SELECT
    N'synonyms' AS EvidenceSection,
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS SynonymName,
    base_object_name AS BaseObjectName
FROM sys.synonyms
WHERE base_object_name LIKE N'%KingdomScanData4%';

SELECT
    N'triggers' AS EvidenceSection,
    OBJECT_SCHEMA_NAME(o.object_id) AS SchemaName,
    o.name AS TriggerName,
    o.is_disabled AS IsDisabled,
    OBJECT_SCHEMA_NAME(o.parent_id) AS ParentSchema,
    OBJECT_NAME(o.parent_id) AS ParentObject,
    CONVERT(varchar(64), HASHBYTES(N'SHA2_256', CONVERT(varbinary(max), m.definition)), 2) AS DefinitionSha256
FROM sys.triggers AS o
LEFT JOIN sys.sql_modules AS m
  ON m.object_id = o.object_id
WHERE o.parent_id = @TableObjectId
   OR m.definition LIKE N'%KingdomScanData4%';

BEGIN TRY
    SELECT
        N'sql_agent_job_steps' AS EvidenceSection,
        j.name AS JobName,
        js.step_id AS StepId,
        js.step_name AS StepName,
        js.subsystem AS Subsystem,
        js.database_name AS DatabaseName,
        js.command AS CommandText,
        j.enabled AS JobEnabled
    FROM msdb.dbo.sysjobs AS j
    JOIN msdb.dbo.sysjobsteps AS js
      ON js.job_id = j.job_id
    WHERE js.command LIKE N'%KingdomScanData4%'
       OR js.command LIKE N'%UPDATE_ALL2%'
       OR js.command LIKE N'%IMPORT_STAGING_PROC%'
    ORDER BY j.name, js.step_id;
END TRY
BEGIN CATCH
    SELECT
        N'sql_agent_job_steps_unavailable' AS EvidenceSection,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
