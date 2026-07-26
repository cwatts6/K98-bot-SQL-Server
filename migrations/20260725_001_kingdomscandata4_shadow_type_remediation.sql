/*
MigrationId: 20260725_001_kingdomscandata4_shadow_type_remediation
Purpose: Replace IMPORT_STAGING, KingdomScanData5, and KingdomScanData4 with drift-guarded typed shadow copies
Author: cwatts
CreatedUtc: 2026-07-25
RequiresBackup: Yes
RiskLevel: High
Rollback: Included
RollbackScript: migrations/rollback/20260725_001_kingdomscandata4_shadow_type_remediation_rollback.sql
TransactionMode: None
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: Current rows in all three source tables; representative seed 789032 rows
PreValidationQuery: Run performance_remediation/kingdomscandata4/phase2/01_preflight.sql and require a current PASS receipt
PostValidationQuery: Run performance_remediation/kingdomscandata4/phase2/02_verify.sql before application restart
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety plan:
    - Requires a verified copy-only backup and an unexpired exact metadata receipt.
    - Requires bot/import/admin SQL entry points stopped and no conflicting sessions.
    - Acquires K98:KingdomScanData4:Migration exclusively for the whole operation.
    - Copies each source table once into an exact typed shadow.
    - Reconciles normalized SHA-256 row digests before the metadata swap.
    - Retains the original tables as *_Phase2_Old for pre-restart rollback.
    - Does not drop source data. After any post-cutover write, use forward fix or
      the backup/log recovery branch, never the metadata-swap rollback.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;

DECLARE @ScriptRevision varchar(20) = '20260725.1';
DECLARE @ProductionDatabase sysname = N'ROK_TRACKER';
DECLARE @RunId uniqueidentifier;
DECLARE @PreflightDatabase sysname;
DECLARE @PreflightServer sysname;
DECLARE @ProductionApproved bit;
DECLARE @ExpectedKs4Rows bigint;
DECLARE @ExpectedKs5Rows bigint;
DECLARE @ExpectedStagingRows bigint;
DECLARE @ExpectedKs4MaxScan int;
DECLARE @ExpectedKs5MaxScan int;
DECLARE @OverallStartedAtUtc datetime2(7);
DECLARE @OverallFinishedAtUtc datetime2(7);
DECLARE @StepStartedAtUtc datetime2(7);
DECLARE @StepFinishedAtUtc datetime2(7);
DECLARE @RowsCopied bigint;
DECLARE @Sql nvarchar(max);
DECLARE @ExpectedKs5PrimaryKeyName sysname;
DECLARE @ExpectedKs5PrimaryKeyObjectName nvarchar(517);
DECLARE @ApplicationLockResult int;
DECLARE @ApplicationLockAcquired bit = 0;
DECLARE
    @StartDataFileSizeMb decimal(19, 2),
    @StartDataFreeInsideMb decimal(19, 2),
    @StartLogSizeMb decimal(19, 2),
    @StartUsedLogMb decimal(19, 2),
    @StartTempdbAllocatedMb decimal(19, 2),
    @StartVolumeFreeMb decimal(19, 2),
    @EndDataFileSizeMb decimal(19, 2),
    @EndDataFreeInsideMb decimal(19, 2),
    @EndLogSizeMb decimal(19, 2),
    @EndUsedLogMb decimal(19, 2),
    @EndTempdbAllocatedMb decimal(19, 2),
    @EndVolumeFreeMb decimal(19, 2);

IF OBJECT_ID(N'dbo.KS4_Phase2_PreflightState', N'U') IS NULL
    THROW 51540, 'Phase 2 preflight state is absent; run the approved preflight first.', 1;

SELECT TOP (1)
    @RunId = RunId,
    @PreflightDatabase = DatabaseName,
    @PreflightServer = ServerName,
    @ProductionApproved = ProductionApproved,
    @ExpectedKs4Rows = Ks4Rows,
    @ExpectedKs5Rows = Ks5Rows,
    @ExpectedStagingRows = StagingRows,
    @ExpectedKs4MaxScan = Ks4MaxScan,
    @ExpectedKs5MaxScan = Ks5MaxScan
FROM dbo.KS4_Phase2_PreflightState
WHERE Status = 'PASS'
  AND BackupVerified = 1
  AND ExpiresAtUtc >= SYSUTCDATETIME()
  AND MigrationStartedAtUtc IS NULL
ORDER BY CompletedAtUtc DESC;

IF @RunId IS NULL
    THROW 51541, 'No unexpired, unconsumed PASS preflight receipt exists.', 1;

IF DB_NAME() <> @PreflightDatabase OR @@SERVERNAME <> @PreflightServer
    THROW 51542, 'The preflight database/server identity does not match this session.', 1;

IF DB_NAME() = @ProductionDatabase AND @ProductionApproved <> 1
    THROW 51543, 'The preflight did not record separate production approval.', 1;

SELECT @ExpectedKs5PrimaryKeyName = IndexName
FROM dbo.KS4_Phase2_IndexInventory
WHERE RunId = @RunId
  AND ObjectName = N'KingdomScanData5'
  AND IsPrimaryKey = 1;
SET @ExpectedKs5PrimaryKeyObjectName =
    N'dbo.' + QUOTENAME(@ExpectedKs5PrimaryKeyName);

IF @ExpectedKs5PrimaryKeyName IS NULL
   OR
   (
       SELECT COUNT(*)
       FROM dbo.KS4_Phase2_IndexInventory
       WHERE RunId = @RunId
         AND ObjectName = N'KingdomScanData5'
         AND IsPrimaryKey = 1
   ) <> 1
   OR @ExpectedKs5PrimaryKeyName IN
      (N'PK_KingdomScanData5_Phase2_New', N'PK_KingdomScanData5_Phase2_Old')
   OR OBJECT_ID(N'dbo.PK_KingdomScanData5_Phase2_Old', N'PK') IS NOT NULL
    THROW 51561, 'The captured KingdomScanData5 primary-key name is not cutover-safe.', 1;

IF DB_NAME() <> @ProductionDatabase
   AND DB_NAME() NOT LIKE N'ROK[_]TRACKER[_]BACKUP[_]TEST[_]KS4%'
    THROW 51544, 'Safety stop: target is not an approved KS4 database.', 1;

IF @@TRANCOUNT <> 0
    THROW 51545, 'Run the migration with no existing user transaction.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE source_database_id = DB_ID()
       OR (database_id = DB_ID() AND source_database_id IS NOT NULL)
)
    THROW 51546, 'A database snapshot is associated with the target.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NOT NULL
    THROW 51547, 'Prior Phase 2 table artifacts exist.', 1;

EXEC @ApplicationLockResult = sys.sp_getapplock
    @Resource = N'K98:KingdomScanData4:Migration',
    @LockMode = N'Exclusive',
    @LockOwner = N'Session',
    @LockTimeout = 0,
    @DbPrincipal = N'public';

IF @ApplicationLockResult < 0
    THROW 51548, 'Could not acquire the Phase 2 migration application lock.', 1;

SET @ApplicationLockAcquired = 1;

BEGIN TRY
    IF EXISTS
    (
        SELECT 1
        FROM sys.dm_exec_sessions AS session_info
        LEFT JOIN sys.dm_exec_requests AS request_info
          ON request_info.session_id = session_info.session_id
        WHERE session_info.is_user_process = 1
          AND session_info.session_id <> @@SPID
          AND COALESCE(request_info.database_id, session_info.database_id) = DB_ID()
          AND NOT
          (
              session_info.program_name LIKE N'Microsoft SQL Server Management Studio%IntelliSense%'
              AND request_info.session_id IS NULL
              AND session_info.open_transaction_count = 0
              AND session_info.status = N'sleeping'
          )
    )
        THROW 51549, 'Conflicting user sessions are connected.', 1;

    IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @ExpectedKs4Rows
       OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @ExpectedKs5Rows
       OR (SELECT COUNT_BIG(*) FROM dbo.IMPORT_STAGING) <> @ExpectedStagingRows
       OR (SELECT MAX(TRY_CONVERT(int, SCANORDER)) FROM dbo.KingdomScanData4)
            <> @ExpectedKs4MaxScan
       OR (SELECT MAX(TRY_CONVERT(int, SCANORDER)) FROM dbo.KingdomScanData5)
            <> @ExpectedKs5MaxScan
        THROW 51550, 'Rows or scan allocation changed after preflight.', 1;

    IF
    (
        SELECT COUNT(*)
        FROM dbo.KS4_Phase2_ColumnInventory AS expected
        JOIN sys.columns AS actual
          ON actual.object_id = OBJECT_ID(N'dbo.' + expected.ObjectName)
         AND actual.column_id = expected.ColumnId
         AND actual.name COLLATE DATABASE_DEFAULT =
             expected.ColumnName COLLATE DATABASE_DEFAULT
        JOIN sys.types AS actual_type
          ON actual_type.user_type_id = actual.user_type_id
        LEFT JOIN sys.identity_columns AS actual_identity
          ON actual_identity.object_id = actual.object_id
         AND actual_identity.column_id = actual.column_id
        LEFT JOIN sys.computed_columns AS actual_computed
          ON actual_computed.object_id = actual.object_id
         AND actual_computed.column_id = actual.column_id
        LEFT JOIN sys.default_constraints AS actual_default
          ON actual_default.object_id = actual.default_object_id
        WHERE expected.RunId = @RunId
          AND actual_type.name COLLATE DATABASE_DEFAULT =
              expected.TypeName COLLATE DATABASE_DEFAULT
          AND actual.max_length = expected.MaxLength
          AND actual.precision = expected.[Precision]
          AND actual.scale = expected.Scale
          AND ISNULL(actual.collation_name, N'') COLLATE DATABASE_DEFAULT =
              ISNULL(expected.CollationName, N'') COLLATE DATABASE_DEFAULT
          AND actual.is_nullable = expected.IsNullable
          AND actual.is_identity = expected.IsIdentity
          AND actual.is_computed = expected.IsComputed
          AND ISNULL(actual_computed.is_persisted, 0) =
              ISNULL(expected.IsPersisted, 0)
          AND ISNULL(actual_computed.definition, N'') COLLATE DATABASE_DEFAULT =
              ISNULL(expected.ComputedDefinition, N'') COLLATE DATABASE_DEFAULT
          AND ISNULL(actual_default.name, N'') COLLATE DATABASE_DEFAULT =
              ISNULL(expected.DefaultName, N'') COLLATE DATABASE_DEFAULT
          AND ISNULL(actual_default.definition, N'') COLLATE DATABASE_DEFAULT =
              ISNULL(expected.DefaultDefinition, N'') COLLATE DATABASE_DEFAULT
    ) <>
    (
        SELECT COUNT(*)
        FROM dbo.KS4_Phase2_ColumnInventory
        WHERE RunId = @RunId
    )
        THROW 51551, 'Column metadata changed after preflight.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_IndexInventory AS expected
        LEFT JOIN sys.indexes AS actual
          ON actual.object_id = OBJECT_ID(N'dbo.' + expected.ObjectName)
         AND actual.name COLLATE DATABASE_DEFAULT =
             expected.IndexName COLLATE DATABASE_DEFAULT
        OUTER APPLY
        (
            SELECT STRING_AGG(
                CONVERT(nvarchar(max),
                    QUOTENAME(column_info.name)
                    + CASE WHEN index_column.is_descending_key = 1
                           THEN N' DESC' ELSE N' ASC' END),
                N',') WITHIN GROUP (ORDER BY index_column.key_ordinal)
                AS ColumnList
            FROM sys.index_columns AS index_column
            JOIN sys.columns AS column_info
              ON column_info.object_id = index_column.object_id
             AND column_info.column_id = index_column.column_id
            WHERE index_column.object_id = actual.object_id
              AND index_column.index_id = actual.index_id
              AND index_column.key_ordinal > 0
        ) AS actual_keys
        OUTER APPLY
        (
            SELECT STRING_AGG(
                CONVERT(nvarchar(max), QUOTENAME(column_info.name)),
                N',') WITHIN GROUP (ORDER BY index_column.index_column_id)
                AS ColumnList
            FROM sys.index_columns AS index_column
            JOIN sys.columns AS column_info
              ON column_info.object_id = index_column.object_id
             AND column_info.column_id = index_column.column_id
            WHERE index_column.object_id = actual.object_id
              AND index_column.index_id = actual.index_id
              AND index_column.is_included_column = 1
        ) AS actual_includes
        WHERE expected.RunId = @RunId
          AND
          (
              actual.index_id IS NULL
              OR actual.type_desc COLLATE DATABASE_DEFAULT <>
                 expected.TypeDesc COLLATE DATABASE_DEFAULT
              OR actual.is_unique <> expected.IsUnique
              OR actual.is_primary_key <> expected.IsPrimaryKey
              OR actual.is_disabled <> expected.IsDisabled
              OR actual.has_filter <> expected.HasFilter
              OR ISNULL(actual.filter_definition, N'') COLLATE DATABASE_DEFAULT <>
                  ISNULL(expected.FilterDefinition, N'') COLLATE DATABASE_DEFAULT
              OR actual_keys.ColumnList COLLATE DATABASE_DEFAULT <>
                 expected.KeyColumns COLLATE DATABASE_DEFAULT
              OR ISNULL(actual_includes.ColumnList, N'') COLLATE DATABASE_DEFAULT <>
                  ISNULL(expected.IncludeColumns, N'') COLLATE DATABASE_DEFAULT
          )
    )
        THROW 51552, 'Index metadata changed after preflight.', 1;

    DECLARE @ActualPermissions table
    (
        ObjectName sysname NOT NULL,
        PrincipalName sysname NOT NULL,
        StateCode char(1) NOT NULL,
        PermissionName sysname NOT NULL,
        ColumnId int NOT NULL,
        PRIMARY KEY (ObjectName, PrincipalName, PermissionName, ColumnId)
    );

    INSERT @ActualPermissions
        (ObjectName, PrincipalName, StateCode, PermissionName, ColumnId)
    SELECT
        OBJECT_NAME(permission_info.major_id),
        principal_info.name,
        permission_info.state,
        permission_info.permission_name,
        permission_info.minor_id
    FROM sys.database_permissions AS permission_info
    JOIN sys.database_principals AS principal_info
      ON principal_info.principal_id = permission_info.grantee_principal_id
    WHERE permission_info.class = 1
      AND permission_info.major_id IN
      (
          OBJECT_ID(N'dbo.KingdomScanData4'),
          OBJECT_ID(N'dbo.KingdomScanData5'),
          OBJECT_ID(N'dbo.IMPORT_STAGING')
      );

    IF EXISTS
    (
        SELECT ObjectName, PrincipalName, StateCode, PermissionName, ColumnId
        FROM dbo.KS4_Phase2_PermissionInventory
        WHERE RunId = @RunId
        EXCEPT
        SELECT ObjectName, PrincipalName, StateCode, PermissionName, ColumnId
        FROM @ActualPermissions
    )
       OR EXISTS
    (
        SELECT ObjectName, PrincipalName, StateCode, PermissionName, ColumnId
        FROM @ActualPermissions
        EXCEPT
        SELECT ObjectName, PrincipalName, StateCode, PermissionName, ColumnId
        FROM dbo.KS4_Phase2_PermissionInventory
        WHERE RunId = @RunId
    )
        THROW 51553, 'Permission metadata changed after preflight.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_ModuleInventory AS expected
        LEFT JOIN sys.sql_modules AS actual
          ON actual.object_id =
             OBJECT_ID(QUOTENAME(expected.SchemaName) + N'.' + QUOTENAME(expected.ObjectName))
        WHERE expected.RunId = @RunId
          AND
          (
              actual.object_id IS NULL
              OR HASHBYTES('SHA2_256', CONVERT(varbinary(max), actual.definition))
                    <> expected.DefinitionHash
              OR actual.uses_ansi_nulls <> expected.UsesAnsiNulls
              OR actual.uses_quoted_identifier <> expected.UsesQuotedIdentifier
          )
    )
        THROW 51554, 'A dependent module changed after preflight.', 1;

    IF
    (
        SELECT COUNT(*)
        FROM dbo.KS4_Phase2_StatisticInventory
        WHERE RunId = @RunId
    ) <>
    (
        SELECT COUNT(*)
        FROM sys.stats AS actual
        LEFT JOIN sys.indexes AS index_info
          ON index_info.object_id = actual.object_id
         AND index_info.index_id = actual.stats_id
        WHERE actual.object_id IN
        (
            OBJECT_ID(N'dbo.KingdomScanData4'),
            OBJECT_ID(N'dbo.KingdomScanData5'),
            OBJECT_ID(N'dbo.IMPORT_STAGING')
        )
          AND index_info.index_id IS NULL
    )
       OR EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_StatisticInventory AS expected
        LEFT JOIN sys.stats AS actual
          ON actual.object_id = OBJECT_ID(N'dbo.' + expected.ObjectName)
         AND actual.name COLLATE DATABASE_DEFAULT =
             expected.StatisticName COLLATE DATABASE_DEFAULT
        OUTER APPLY
        (
            SELECT STRING_AGG(
                CONVERT(nvarchar(max), QUOTENAME(column_info.name)),
                N',') WITHIN GROUP (ORDER BY stat_column.stats_column_id)
                AS ColumnList
            FROM sys.stats_columns AS stat_column
            JOIN sys.columns AS column_info
              ON column_info.object_id = stat_column.object_id
             AND column_info.column_id = stat_column.column_id
            WHERE stat_column.object_id = actual.object_id
              AND stat_column.stats_id = actual.stats_id
        ) AS actual_columns
        WHERE expected.RunId = @RunId
          AND
          (
              actual.stats_id IS NULL
              OR actual.auto_created <> expected.IsAutoCreated
              OR actual.user_created <> expected.IsUserCreated
              OR actual.no_recompute <> expected.NoRecompute
              OR actual.has_filter <> expected.HasFilter
              OR ISNULL(actual.filter_definition, N'') COLLATE DATABASE_DEFAULT <>
                  ISNULL(expected.FilterDefinition, N'') COLLATE DATABASE_DEFAULT
              OR actual_columns.ColumnList COLLATE DATABASE_DEFAULT <>
                 expected.StatisticColumns COLLATE DATABASE_DEFAULT
          )
    )
        THROW 51555, 'Standalone statistics changed after preflight.', 1;

    UPDATE dbo.KS4_Phase2_PreflightState
    SET MigrationStartedAtUtc = SYSUTCDATETIME(),
        Status = 'MIGRATING'
    WHERE RunId = @RunId;

    SELECT
        @StartDataFileSizeMb =
            SUM(CASE WHEN type = 0 THEN size ELSE 0 END) * 8.0 / 1024.0,
        @StartDataFreeInsideMb =
            SUM(CASE WHEN type = 0
                     THEN size - FILEPROPERTY(name, 'SpaceUsed') ELSE 0 END)
            * 8.0 / 1024.0,
        @StartLogSizeMb =
            SUM(CASE WHEN type = 1 THEN size ELSE 0 END) * 8.0 / 1024.0
    FROM sys.database_files;
    SELECT @StartUsedLogMb = used_log_space_in_bytes / 1048576.0
    FROM sys.dm_db_log_space_usage;
    SELECT @StartTempdbAllocatedMb =
        SUM(allocated_extent_page_count) * 8.0 / 1024.0
    FROM tempdb.sys.dm_db_file_space_usage;
    SELECT TOP (1) @StartVolumeFreeMb = volume.available_bytes / 1048576.0
    FROM sys.database_files AS file_info
    CROSS APPLY sys.dm_os_volume_stats(DB_ID(), file_info.file_id) AS volume
    WHERE file_info.type = 0
    ORDER BY file_info.file_id;

    SET @OverallStartedAtUtc = SYSUTCDATETIME();

    DECLARE @BigintMap table
    (
        LogicalName sysname NOT NULL,
        ColumnName sysname NOT NULL,
        PRIMARY KEY (LogicalName, ColumnName)
    );
    DECLARE @IntMap table
    (
        LogicalName sysname NOT NULL,
        ColumnName sysname NOT NULL,
        PRIMARY KEY (LogicalName, ColumnName)
    );
    DECLARE @StringMap table
    (
        LogicalName sysname NOT NULL,
        ColumnName sysname NOT NULL,
        TargetLength int NOT NULL,
        TrimRight bit NOT NULL,
        PRIMARY KEY (LogicalName, ColumnName)
    );

    INSERT @BigintMap (LogicalName, ColumnName)
    VALUES
        (N'KS4', N'GovernorID'), (N'KS4', N'Power'),
        (N'KS4', N'KillPoints'), (N'KS4', N'Deads'),
        (N'KS4', N'T1_Kills'), (N'KS4', N'T2_Kills'),
        (N'KS4', N'T3_Kills'), (N'KS4', N'T4_Kills'),
        (N'KS4', N'T5_Kills'), (N'KS4', N'T4&T5_KILLS'),
        (N'KS4', N'TOTAL_KILLS'), (N'KS4', N'RSS_Gathered'),
        (N'KS4', N'RSSAssistance'), (N'KS4', N'Helps'),
        (N'KS5', N'GovernorID'), (N'KS5', N'Power'),
        (N'KS5', N'KillPoints'), (N'KS5', N'Deads'),
        (N'KS5', N'T1_Kills'), (N'KS5', N'T2_Kills'),
        (N'KS5', N'T3_Kills'), (N'KS5', N'T4_Kills'),
        (N'KS5', N'T5_Kills'), (N'KS5', N'T4&T5_KILLS'),
        (N'KS5', N'TOTAL_KILLS'), (N'KS5', N'RSS_Gathered'),
        (N'KS5', N'RSSAssistance'), (N'KS5', N'Helps'),
        (N'STAGING', N'Governor ID'), (N'STAGING', N'Power'),
        (N'STAGING', N'Total Kill Points'), (N'STAGING', N'Dead Troops'),
        (N'STAGING', N'T1-Kills'), (N'STAGING', N'T2-Kills'),
        (N'STAGING', N'T3-Kills'), (N'STAGING', N'T4-Kills'),
        (N'STAGING', N'T5-Kills'), (N'STAGING', N'Kills (T4+)'),
        (N'STAGING', N'KILLS'), (N'STAGING', N'RSS Gathered'),
        (N'STAGING', N'RSS Assistance'), (N'STAGING', N'Alliance Helps');

    INSERT @IntMap (LogicalName, ColumnName)
    VALUES
        (N'KS4', N'PowerRank'), (N'KS4', N'SCANORDER'),
        (N'KS5', N'PowerRank'), (N'KS5', N'SCANORDER'),
        (N'STAGING', N'SCANORDER');

    INSERT @StringMap (LogicalName, ColumnName, TargetLength, TrimRight)
    VALUES
        (N'KS4', N'GovernorName', 200, 1),
        (N'KS4', N'Alliance', 100, 1),
        (N'KS5', N'GovernorName', 200, 1),
        (N'KS5', N'Alliance', 100, 1),
        (N'STAGING', N'Name', 200, 1),
        (N'STAGING', N'Alliance', 100, 1),
        (N'STAGING', N'Updated_on', 200, 0);

    SET @StepStartedAtUtc = SYSUTCDATETIME();

    CREATE TABLE dbo.KingdomScanData4_Phase2_New
    (
        PowerRank int NOT NULL,
        GovernorName nvarchar(200) COLLATE Latin1_General_CI_AS NULL,
        GovernorID bigint NOT NULL,
        Alliance nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
        Power bigint NOT NULL,
        KillPoints bigint NOT NULL,
        Deads bigint NOT NULL,
        T1_Kills bigint NOT NULL,
        T2_Kills bigint NOT NULL,
        T3_Kills bigint NOT NULL,
        T4_Kills bigint NOT NULL,
        T5_Kills bigint NOT NULL,
        [T4&T5_KILLS] bigint NULL,
        TOTAL_KILLS bigint NULL,
        RSS_Gathered bigint NULL,
        RSSAssistance bigint NOT NULL,
        Helps bigint NOT NULL,
        ScanDate datetime NOT NULL,
        SCANORDER int NOT NULL,
        SCAN_UNO int NOT NULL
            CONSTRAINT DF_KS4_Phase2_New_SCAN_UNO
            DEFAULT (NEXT VALUE FOR dbo.KS4_UNO_SEQ),
        [Troops Power] float NULL,
        [City Hall] float NULL,
        [Tech Power] float NULL,
        [Building Power] float NULL,
        [Commander Power] float NULL,
        AsOfDate AS (CONVERT(date, ScanDate)) PERSISTED,
        HealedTroops bigint NULL,
        RangedPoints bigint NULL,
        Civilization nvarchar(100) COLLATE Latin1_General_CI_AS NULL,
        KvKPlayed int NULL,
        MostKvKKill bigint NULL,
        MostKvKDead bigint NULL,
        MostKvKHeal bigint NULL,
        Acclaim bigint NULL,
        HighestAcclaim bigint NULL,
        AOOJoined bigint NULL,
        AOOWon int NULL,
        AOOAvgKill bigint NULL,
        AOOAvgDead bigint NULL,
        AOOAvgHeal bigint NULL,
        AutarchTimes int NULL,
        Conduct decimal(5, 2) NULL
    );

    SELECT TOP (0) *
    INTO dbo.KingdomScanData5_Phase2_New
    FROM dbo.KingdomScanData5;

    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN PowerRank int NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN GovernorName nvarchar(200) COLLATE Latin1_General_CI_AS NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN GovernorID bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN Alliance nvarchar(100) COLLATE Latin1_General_CI_AS NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN Power bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN KillPoints bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN Deads bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T1_Kills bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T2_Kills bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T3_Kills bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T4_Kills bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T5_Kills bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN [T4&T5_KILLS] bigint NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN TOTAL_KILLS bigint NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN RSS_Gathered bigint NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN RSSAssistance bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN Helps bigint NOT NULL;
    ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN SCANORDER int NULL;

    SELECT TOP (0) *
    INTO dbo.IMPORT_STAGING_Phase2_New
    FROM dbo.IMPORT_STAGING;

    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN Name nvarchar(200) COLLATE Latin1_General_CI_AS NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [Governor ID] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN Alliance nvarchar(100) COLLATE Latin1_General_CI_AS NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN Power bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [Total Kill Points] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [Dead Troops] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [T1-Kills] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [T2-Kills] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [T3-Kills] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [T4-Kills] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [T5-Kills] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [Kills (T4+)] bigint NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN KILLS bigint NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [RSS Gathered] bigint NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [RSS Assistance] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN [Alliance Helps] bigint NOT NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN SCANORDER int NULL;
    ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN Updated_on nvarchar(200) COLLATE Latin1_General_CI_AS NULL;

    IF COLUMNPROPERTY(OBJECT_ID(N'dbo.KingdomScanData5_Phase2_New'), N'SCAN_UNO', 'IsIdentity') <> 1
        THROW 51556, 'KingdomScanData5 shadow lost identity semantics.', 1;

    SET @StepFinishedAtUtc = SYSUTCDATETIME();
    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'FORWARD', N'create_empty_typed_shadows',
         @StepStartedAtUtc, @StepFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
         0, N'Exact column order/nullability retained; AsOfDate remains persisted.');

    DECLARE @CopyWork table
    (
        LogicalName sysname NOT NULL PRIMARY KEY,
        SourceName sysname NOT NULL,
        TargetName sysname NOT NULL,
        HasIdentity bit NOT NULL,
        StepName nvarchar(128) NOT NULL,
        SortOrder tinyint NOT NULL
    );
    INSERT @CopyWork
    VALUES
        (N'STAGING', N'IMPORT_STAGING', N'IMPORT_STAGING_Phase2_New', 0, N'copy_import_staging', 1),
        (N'KS5', N'KingdomScanData5', N'KingdomScanData5_Phase2_New', 1, N'copy_kingdomscandata5', 2),
        (N'KS4', N'KingdomScanData4', N'KingdomScanData4_Phase2_New', 0, N'copy_kingdomscandata4', 3);

    DECLARE
        @LogicalName sysname,
        @SourceName sysname,
        @TargetName sysname,
        @HasIdentity bit,
        @CopyStepName nvarchar(128),
        @InsertColumns nvarchar(max),
        @CopyProjection nvarchar(max);

    DECLARE copy_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT LogicalName, SourceName, TargetName, HasIdentity, StepName
    FROM @CopyWork ORDER BY SortOrder;

    OPEN copy_cursor;
    FETCH NEXT FROM copy_cursor
    INTO @LogicalName, @SourceName, @TargetName, @HasIdentity, @CopyStepName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @StepStartedAtUtc = SYSUTCDATETIME();

        SELECT
            @InsertColumns = STRING_AGG(
                CONVERT(nvarchar(max), QUOTENAME(column_info.name)), N',')
                WITHIN GROUP (ORDER BY column_info.column_id),
            @CopyProjection = STRING_AGG(
                CONVERT(nvarchar(max),
                    CASE
                        WHEN bigint_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(bigint, source.' + QUOTENAME(column_info.name) + N')'
                        WHEN int_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(int, source.' + QUOTENAME(column_info.name) + N')'
                        WHEN string_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(nvarchar('
                                 + CONVERT(nvarchar(10), string_map.TargetLength)
                                 + N'), '
                                 + CASE WHEN string_map.TrimRight = 1
                                        THEN N'RTRIM(source.' + QUOTENAME(column_info.name) + N')'
                                        ELSE N'source.' + QUOTENAME(column_info.name) END
                                 + N') COLLATE Latin1_General_CI_AS'
                        ELSE N'source.' + QUOTENAME(column_info.name)
                    END),
                N',') WITHIN GROUP (ORDER BY column_info.column_id)
        FROM sys.columns AS column_info
        LEFT JOIN @BigintMap AS bigint_map
          ON bigint_map.LogicalName = @LogicalName
         AND bigint_map.ColumnName = column_info.name
        LEFT JOIN @IntMap AS int_map
          ON int_map.LogicalName = @LogicalName
         AND int_map.ColumnName = column_info.name
        LEFT JOIN @StringMap AS string_map
          ON string_map.LogicalName = @LogicalName
         AND string_map.ColumnName = column_info.name
        WHERE column_info.object_id = OBJECT_ID(N'dbo.' + @SourceName)
          AND column_info.is_computed = 0;

        SET @Sql =
            CASE WHEN @HasIdentity = 1
                 THEN N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@TargetName) + N' ON;'
                 ELSE N'' END
            + N' INSERT dbo.' + QUOTENAME(@TargetName)
            + N' (' + @InsertColumns + N') SELECT ' + @CopyProjection
            + N' FROM dbo.' + QUOTENAME(@SourceName) + N' AS source;'
            + N' SET @Copied = @@ROWCOUNT;'
            + CASE WHEN @HasIdentity = 1
                   THEN N' SET IDENTITY_INSERT dbo.' + QUOTENAME(@TargetName) + N' OFF;'
                   ELSE N'' END;

        EXEC sys.sp_executesql
            @Sql, N'@Copied bigint OUTPUT', @Copied = @RowsCopied OUTPUT;

        SET @StepFinishedAtUtc = SYSUTCDATETIME();
        INSERT dbo.KS4_Phase2_MigrationReceipt
            (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
             DurationMs, RowsAffected, Notes)
        VALUES
            (@RunId, 'FORWARD', @CopyStepName,
             @StepStartedAtUtc, @StepFinishedAtUtc,
             DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
             @RowsCopied, N'One explicit checked normalization pass.');

        FETCH NEXT FROM copy_cursor
        INTO @LogicalName, @SourceName, @TargetName, @HasIdentity, @CopyStepName;
    END;

    CLOSE copy_cursor;
    DEALLOCATE copy_cursor;

    DECLARE @Ks5MaxIdentity bigint =
        (SELECT MAX(SCAN_UNO) FROM dbo.KingdomScanData5_Phase2_New);
    SET @Sql =
        N'DBCC CHECKIDENT (N''dbo.KingdomScanData5_Phase2_New'', RESEED, '
        + CONVERT(nvarchar(30), @Ks5MaxIdentity) + N') WITH NO_INFOMSGS;';
    EXEC sys.sp_executesql @Sql;

    SET @StepStartedAtUtc = SYSUTCDATETIME();

    ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ADD CONSTRAINT PK_KingdomScanData5_Phase2_New
        PRIMARY KEY CLUSTERED (SCAN_UNO ASC)
        WITH
        (
            PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF,
            IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
            ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
        );

    CREATE CLUSTERED INDEX CIX_KS4_ScanOrder_Governor
    ON dbo.KingdomScanData4_Phase2_New (SCANORDER ASC, GovernorID ASC)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_KS4_AsOf_Governor
    ON dbo.KingdomScanData4_Phase2_New (AsOfDate ASC, GovernorID ASC)
    INCLUDE
        (TOTAL_KILLS, KillPoints, Deads, Helps, RSS_Gathered,
         RSSAssistance, Power, GovernorName)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_KS4_Governor_ScanDate
    ON dbo.KingdomScanData4_Phase2_New (GovernorID ASC, ScanDate ASC)
    INCLUDE (Power, KillPoints, [T4&T5_KILLS], Deads, GovernorName)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_KSD4_Governor_ScanOrder
    ON dbo.KingdomScanData4_Phase2_New
        (GovernorID ASC, SCANORDER DESC, AsOfDate DESC, ScanDate DESC)
    INCLUDE (GovernorName, Alliance)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_KSD4_Gov_ScanOrder
    ON dbo.KingdomScanData4_Phase2_New (GovernorID ASC, SCANORDER ASC)
    INCLUDE (PowerRank, ScanDate)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_kingdomscandata4_ScanOrder_DESC
    ON dbo.KingdomScanData4_Phase2_New (SCANORDER DESC)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_KS4_Governor_ScanDate_ScanOrder
    ON dbo.KingdomScanData4_Phase2_New
        (GovernorID ASC, ScanDate ASC, SCANORDER ASC)
    INCLUDE (Deads, GovernorName, PowerRank)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_KingdomScanData4_GovernorID_ScanOrder_Covering
    ON dbo.KingdomScanData4_Phase2_New (GovernorID ASC, SCANORDER ASC)
    INCLUDE
        (ScanDate, GovernorName, PowerRank, Power, T5_Kills, T4_Kills,
         [T4&T5_KILLS], HealedTroops, Deads, RangedPoints, KillPoints)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_KingdomScanData4_ScanOrder_GovernorID
    ON dbo.KingdomScanData4_Phase2_New (SCANORDER ASC, GovernorID ASC)
    INCLUDE (ScanDate, GovernorName, PowerRank, Deads, HealedTroops)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    CREATE NONCLUSTERED INDEX IX_KingdomScanData4_GovernorID_ScanOrder
    ON dbo.KingdomScanData4_Phase2_New (GovernorID ASC, SCANORDER ASC)
    INCLUDE (ScanDate, GovernorName, PowerRank, Deads, HealedTroops)
    WITH
    (
        PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF,
        DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

    DECLARE
        @StatisticObject sysname,
        @StatisticTarget sysname,
        @StatisticName sysname,
        @StatisticColumns nvarchar(max),
        @StatisticFilter nvarchar(max),
        @StatisticNoRecompute bit;

    DECLARE statistic_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        inventory.ObjectName,
        CASE inventory.ObjectName
            WHEN N'KingdomScanData4' THEN N'KingdomScanData4_Phase2_New'
            WHEN N'KingdomScanData5' THEN N'KingdomScanData5_Phase2_New'
            ELSE N'IMPORT_STAGING_Phase2_New'
        END,
        inventory.StatisticName,
        inventory.StatisticColumns,
        inventory.FilterDefinition,
        inventory.NoRecompute
    FROM dbo.KS4_Phase2_StatisticInventory AS inventory
    WHERE inventory.RunId = @RunId
    ORDER BY inventory.ObjectName, inventory.StatisticName;

    OPEN statistic_cursor;
    FETCH NEXT FROM statistic_cursor
    INTO @StatisticObject, @StatisticTarget, @StatisticName,
         @StatisticColumns, @StatisticFilter, @StatisticNoRecompute;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql =
            N'CREATE STATISTICS ' + QUOTENAME(@StatisticName)
            + N' ON dbo.' + QUOTENAME(@StatisticTarget)
            + N' (' + @StatisticColumns + N')'
            + CASE WHEN @StatisticFilter IS NOT NULL
                   THEN N' WHERE ' + @StatisticFilter ELSE N'' END
            + N' WITH FULLSCAN'
            + CASE WHEN @StatisticNoRecompute = 1
                   THEN N', NORECOMPUTE' ELSE N'' END
            + N';';
        EXEC sys.sp_executesql @Sql;

        FETCH NEXT FROM statistic_cursor
        INTO @StatisticObject, @StatisticTarget, @StatisticName,
             @StatisticColumns, @StatisticFilter, @StatisticNoRecompute;
    END;

    CLOSE statistic_cursor;
    DEALLOCATE statistic_cursor;

    UPDATE STATISTICS dbo.KingdomScanData4_Phase2_New WITH FULLSCAN;
    UPDATE STATISTICS dbo.KingdomScanData5_Phase2_New WITH FULLSCAN;
    UPDATE STATISTICS dbo.IMPORT_STAGING_Phase2_New WITH FULLSCAN;

    GRANT SELECT ON OBJECT::dbo.KingdomScanData4_Phase2_New TO ImportProcUser;

    SET @StepFinishedAtUtc = SYSUTCDATETIME();
    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'FORWARD', N'build_indexes_statistics_permissions',
         @StepStartedAtUtc, @StepFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
         @ExpectedKs4Rows + @ExpectedKs5Rows,
         N'Ten KS4 indexes, KS5 PK, every captured standalone statistic and KS4 SELECT permission recreated.');

    DECLARE @DigestWork table
    (
        LogicalName sysname NOT NULL,
        PhysicalName sysname NOT NULL,
        DigestKind varchar(10) NOT NULL,
        PRIMARY KEY (LogicalName, DigestKind)
    );
    DECLARE @Digests table
    (
        LogicalName sysname NOT NULL,
        DigestKind varchar(10) NOT NULL,
        [RowCount] bigint NOT NULL,
        Digest varbinary(32) NOT NULL,
        PRIMARY KEY (LogicalName, DigestKind)
    );

    INSERT @DigestWork
    VALUES
        (N'KS4', N'KingdomScanData4', 'BASELINE'),
        (N'KS5', N'KingdomScanData5', 'BASELINE'),
        (N'STAGING', N'IMPORT_STAGING', 'BASELINE'),
        (N'KS4', N'KingdomScanData4_Phase2_New', 'SHADOW'),
        (N'KS5', N'KingdomScanData5_Phase2_New', 'SHADOW'),
        (N'STAGING', N'IMPORT_STAGING_Phase2_New', 'SHADOW');

    DECLARE
        @PhysicalName sysname,
        @DigestKind varchar(10),
        @Projection nvarchar(max),
        @CanonicalRows nvarchar(max),
        @Digest varbinary(32),
        @DigestRows bigint;

    SET @StepStartedAtUtc = SYSUTCDATETIME();
    BEGIN TRANSACTION;

    /*
    Runtime writers do not yet share the migration application lock. Hold
    exclusive table locks from the final source digest through metadata
    cutover so a short-lived writer cannot commit into a retained original
    after it was reconciled.
    */
    DECLARE @LockWitness bigint;
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData5 WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData4 WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING_Phase2_New WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData5_Phase2_New WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData4_Phase2_New WITH (TABLOCKX, HOLDLOCK);

    DECLARE digest_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT LogicalName, PhysicalName, DigestKind
    FROM @DigestWork
    ORDER BY LogicalName, DigestKind;

    OPEN digest_cursor;
    FETCH NEXT FROM digest_cursor INTO @LogicalName, @PhysicalName, @DigestKind;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @Projection =
            STRING_AGG(
                CONVERT(nvarchar(max),
                    CASE
                        WHEN bigint_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(bigint, source.' + QUOTENAME(column_info.name)
                                 + N') AS ' + QUOTENAME(column_info.name)
                        WHEN int_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(int, source.' + QUOTENAME(column_info.name)
                                 + N') AS ' + QUOTENAME(column_info.name)
                        WHEN string_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(nvarchar('
                                 + CONVERT(nvarchar(10), string_map.TargetLength)
                                 + N'), '
                                 + CASE WHEN string_map.TrimRight = 1
                                        THEN N'RTRIM(source.' + QUOTENAME(column_info.name) + N')'
                                        ELSE N'source.' + QUOTENAME(column_info.name) END
                                 + N') COLLATE Latin1_General_CI_AS AS '
                                 + QUOTENAME(column_info.name)
                        WHEN @LogicalName = N'KS4' AND column_info.name = N'AsOfDate'
                            THEN N'CONVERT(date, source.[ScanDate]) AS [AsOfDate]'
                        ELSE N'source.' + QUOTENAME(column_info.name)
                             + N' AS ' + QUOTENAME(column_info.name)
                    END),
                N',') WITHIN GROUP (ORDER BY column_info.column_id)
        FROM sys.columns AS column_info
        LEFT JOIN @BigintMap AS bigint_map
          ON bigint_map.LogicalName = @LogicalName
         AND bigint_map.ColumnName = column_info.name
        LEFT JOIN @IntMap AS int_map
          ON int_map.LogicalName = @LogicalName
         AND int_map.ColumnName = column_info.name
        LEFT JOIN @StringMap AS string_map
          ON string_map.LogicalName = @LogicalName
         AND string_map.ColumnName = column_info.name
        WHERE column_info.object_id = OBJECT_ID(N'dbo.' + @PhysicalName);

        SET @Sql = N'
            SELECT @Rows = COUNT_BIG(*) FROM dbo.' + QUOTENAME(@PhysicalName) + N';
            SELECT @Canonical =
            (
                SELECT row_hashes.RowDigest
                FROM
                (
                    SELECT CONVERT(char(64),
                        HASHBYTES(''SHA2_256'',
                            (SELECT ' + @Projection + N'
                             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER,
                                 INCLUDE_NULL_VALUES)), 2) AS RowDigest
                    FROM dbo.' + QUOTENAME(@PhysicalName) + N' AS source
                ) AS row_hashes
                ORDER BY row_hashes.RowDigest
                FOR JSON PATH
            );
            SET @OutputDigest =
                HASHBYTES(''SHA2_256'', COALESCE(@Canonical, N''[]''));';

        EXEC sys.sp_executesql
            @Sql,
            N'@Rows bigint OUTPUT, @Canonical nvarchar(max) OUTPUT,
              @OutputDigest varbinary(32) OUTPUT',
            @Rows = @DigestRows OUTPUT,
            @Canonical = @CanonicalRows OUTPUT,
            @OutputDigest = @Digest OUTPUT;

        INSERT @Digests (LogicalName, DigestKind, [RowCount], Digest)
        VALUES (@LogicalName, @DigestKind, @DigestRows, @Digest);

        FETCH NEXT FROM digest_cursor INTO @LogicalName, @PhysicalName, @DigestKind;
    END;

    CLOSE digest_cursor;
    DEALLOCATE digest_cursor;

    IF EXISTS
    (
        SELECT 1
        FROM @Digests AS baseline
        JOIN @Digests AS shadow_copy
          ON shadow_copy.LogicalName = baseline.LogicalName
         AND shadow_copy.DigestKind = 'SHADOW'
        WHERE baseline.DigestKind = 'BASELINE'
          AND (baseline.[RowCount] <> shadow_copy.[RowCount]
               OR baseline.Digest <> shadow_copy.Digest)
    )
        THROW 51557, 'Shadow row count or normalized SHA-256 digest mismatch.', 1;

    UPDATE dbo.KS4_Phase2_PreflightState
    SET BaselineKs4Digest =
            (SELECT Digest FROM @Digests WHERE LogicalName = N'KS4' AND DigestKind = 'BASELINE'),
        BaselineKs5Digest =
            (SELECT Digest FROM @Digests WHERE LogicalName = N'KS5' AND DigestKind = 'BASELINE'),
        BaselineStagingDigest =
            (SELECT Digest FROM @Digests WHERE LogicalName = N'STAGING' AND DigestKind = 'BASELINE'),
        ForwardKs4Digest =
            (SELECT Digest FROM @Digests WHERE LogicalName = N'KS4' AND DigestKind = 'SHADOW'),
        ForwardKs5Digest =
            (SELECT Digest FROM @Digests WHERE LogicalName = N'KS5' AND DigestKind = 'SHADOW'),
        ForwardStagingDigest =
            (SELECT Digest FROM @Digests WHERE LogicalName = N'STAGING' AND DigestKind = 'SHADOW')
    WHERE RunId = @RunId;

    SET @StepFinishedAtUtc = SYSUTCDATETIME();
    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'FORWARD', N'verify_normalized_digests',
         @StepStartedAtUtc, @StepFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
         @ExpectedKs4Rows + @ExpectedKs5Rows + @ExpectedStagingRows,
         N'Baseline and shadow rows and normalized SHA-256 digests match exactly.');

    IF EXISTS
    (
        SELECT 1
        FROM sys.dm_exec_sessions AS session_info
        LEFT JOIN sys.dm_exec_requests AS request_info
          ON request_info.session_id = session_info.session_id
        WHERE session_info.is_user_process = 1
          AND session_info.session_id <> @@SPID
          AND COALESCE(request_info.database_id, session_info.database_id) = DB_ID()
          AND NOT
          (
              session_info.program_name LIKE N'Microsoft SQL Server Management Studio%IntelliSense%'
              AND request_info.session_id IS NULL
              AND session_info.open_transaction_count = 0
              AND session_info.status = N'sleeping'
          )
    )
        THROW 51558, 'A conflicting user session connected before cutover.', 1;

    /*
    Re-read permissions inside the locked cutover transaction. The earlier
    receipt comparison rejects ordinary drift; this final bidirectional
    comparison also rejects a short-lived permission change that commits
    after the first check and disconnects before the session gate.
    */
    DELETE FROM @ActualPermissions;

    INSERT @ActualPermissions
        (ObjectName, PrincipalName, StateCode, PermissionName, ColumnId)
    SELECT
        OBJECT_NAME(permission_info.major_id),
        principal_info.name,
        permission_info.state,
        permission_info.permission_name,
        permission_info.minor_id
    FROM sys.database_permissions AS permission_info
    JOIN sys.database_principals AS principal_info
      ON principal_info.principal_id = permission_info.grantee_principal_id
    WHERE permission_info.class = 1
      AND permission_info.major_id IN
      (
          OBJECT_ID(N'dbo.KingdomScanData4'),
          OBJECT_ID(N'dbo.KingdomScanData5'),
          OBJECT_ID(N'dbo.IMPORT_STAGING')
      );

    IF EXISTS
    (
        SELECT ObjectName, PrincipalName, StateCode, PermissionName, ColumnId
        FROM dbo.KS4_Phase2_PermissionInventory
        WHERE RunId = @RunId
        EXCEPT
        SELECT ObjectName, PrincipalName, StateCode, PermissionName, ColumnId
        FROM @ActualPermissions
    )
       OR EXISTS
    (
        SELECT ObjectName, PrincipalName, StateCode, PermissionName, ColumnId
        FROM @ActualPermissions
        EXCEPT
        SELECT ObjectName, PrincipalName, StateCode, PermissionName, ColumnId
        FROM dbo.KS4_Phase2_PermissionInventory
        WHERE RunId = @RunId
    )
        THROW 51560, 'Permission metadata changed inside the cutover window.', 1;

    EXEC sys.sp_rename N'dbo.IMPORT_STAGING', N'IMPORT_STAGING_Phase2_Old', N'OBJECT';
    EXEC sys.sp_rename N'dbo.IMPORT_STAGING_Phase2_New', N'IMPORT_STAGING', N'OBJECT';
    EXEC sys.sp_rename N'dbo.KingdomScanData5', N'KingdomScanData5_Phase2_Old', N'OBJECT';
    EXEC sys.sp_rename N'dbo.KingdomScanData5_Phase2_New', N'KingdomScanData5', N'OBJECT';
    EXEC sys.sp_rename N'dbo.KingdomScanData4', N'KingdomScanData4_Phase2_Old', N'OBJECT';
    EXEC sys.sp_rename N'dbo.KingdomScanData4_Phase2_New', N'KingdomScanData4', N'OBJECT';
    EXEC sys.sp_rename
        @ExpectedKs5PrimaryKeyObjectName,
        N'PK_KingdomScanData5_Phase2_Old',
        N'OBJECT';
    EXEC sys.sp_rename
        N'dbo.PK_KingdomScanData5_Phase2_New',
        @ExpectedKs5PrimaryKeyName,
        N'OBJECT';

    DECLARE
        @ModuleSchema sysname,
        @ModuleName sysname,
        @ModuleType char(2),
        @QualifiedModule nvarchar(517);

    DECLARE module_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT SchemaName, ObjectName, ObjectType
    FROM dbo.KS4_Phase2_ModuleInventory
    WHERE RunId = @RunId
    ORDER BY CASE WHEN ObjectType = 'V' THEN 1 ELSE 2 END,
             SchemaName, ObjectName;

    OPEN module_cursor;
    FETCH NEXT FROM module_cursor INTO @ModuleSchema, @ModuleName, @ModuleType;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @QualifiedModule = QUOTENAME(@ModuleSchema) + N'.' + QUOTENAME(@ModuleName);
        IF @ModuleType = 'V'
            EXEC sys.sp_refreshview @QualifiedModule;
        ELSE
            EXEC sys.sp_refreshsqlmodule @QualifiedModule;

        FETCH NEXT FROM module_cursor INTO @ModuleSchema, @ModuleName, @ModuleType;
    END;

    CLOSE module_cursor;
    DEALLOCATE module_cursor;

    IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @ExpectedKs4Rows
       OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @ExpectedKs5Rows
       OR (SELECT COUNT_BIG(*) FROM dbo.IMPORT_STAGING) <> @ExpectedStagingRows
        THROW 51559, 'Canonical row counts changed during cutover.', 1;

    UPDATE dbo.KS4_Phase2_PreflightState
    SET MigrationCompletedAtUtc = SYSUTCDATETIME(),
        Status = 'FORWARD_PASS'
    WHERE RunId = @RunId;

    COMMIT TRANSACTION;
    SET @StepFinishedAtUtc = SYSUTCDATETIME();

    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'FORWARD', N'transactional_cutover_and_module_refresh',
         @StepStartedAtUtc, @StepFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
         52, N'Three metadata swaps; 13 views refreshed before 39 procedures.');

    SET @OverallFinishedAtUtc = SYSUTCDATETIME();
    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'FORWARD', N'total_forward_outage',
         @OverallStartedAtUtc, @OverallFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @OverallStartedAtUtc, @OverallFinishedAtUtc) / 1000.0,
        @ExpectedKs4Rows + @ExpectedKs5Rows + @ExpectedStagingRows,
        N'Application/import/admin entry points must remain stopped through verification.');

    SELECT
        @EndDataFileSizeMb =
            SUM(CASE WHEN type = 0 THEN size ELSE 0 END) * 8.0 / 1024.0,
        @EndDataFreeInsideMb =
            SUM(CASE WHEN type = 0
                     THEN size - FILEPROPERTY(name, 'SpaceUsed') ELSE 0 END)
            * 8.0 / 1024.0,
        @EndLogSizeMb =
            SUM(CASE WHEN type = 1 THEN size ELSE 0 END) * 8.0 / 1024.0
    FROM sys.database_files;
    SELECT @EndUsedLogMb = used_log_space_in_bytes / 1048576.0
    FROM sys.dm_db_log_space_usage;
    SELECT @EndTempdbAllocatedMb =
        SUM(allocated_extent_page_count) * 8.0 / 1024.0
    FROM tempdb.sys.dm_db_file_space_usage;
    SELECT TOP (1) @EndVolumeFreeMb = volume.available_bytes / 1048576.0
    FROM sys.database_files AS file_info
    CROSS APPLY sys.dm_os_volume_stats(DB_ID(), file_info.file_id) AS volume
    WHERE file_info.type = 0
    ORDER BY file_info.file_id;

    EXEC sys.sp_releaseapplock
        @Resource = N'K98:KingdomScanData4:Migration',
        @LockOwner = N'Session',
        @DbPrincipal = N'public';
    SET @ApplicationLockAcquired = 0;

    SELECT
        N'phase2_forward_completion' AS EvidenceSection,
        @ScriptRevision AS ScriptRevision,
        @RunId AS RunId,
        DB_NAME() AS DatabaseName,
        @OverallStartedAtUtc AS StartedAtUtc,
        @OverallFinishedAtUtc AS FinishedAtUtc,
        DATEDIFF_BIG(microsecond, @OverallStartedAtUtc, @OverallFinishedAtUtc) / 1000.0
            AS TotalOutageMs,
        @ExpectedKs4Rows AS Ks4Rows,
        @ExpectedKs5Rows AS Ks5Rows,
        @ExpectedStagingRows AS StagingRows,
        10 AS RetainedKs4Indexes,
        (SELECT COUNT(*) FROM dbo.KS4_Phase2_StatisticInventory WHERE RunId = @RunId)
            AS RecreatedStandaloneStatistics,
        @StartDataFileSizeMb AS StartDataFileSizeMb,
        @EndDataFileSizeMb AS EndDataFileSizeMb,
        @StartDataFreeInsideMb AS StartDataFreeInsideMb,
        @EndDataFreeInsideMb AS EndDataFreeInsideMb,
        @StartLogSizeMb AS StartLogSizeMb,
        @EndLogSizeMb AS EndLogSizeMb,
        @StartUsedLogMb AS StartUsedLogMb,
        @EndUsedLogMb AS EndUsedLogMb,
        @StartTempdbAllocatedMb AS StartTempdbAllocatedMb,
        @EndTempdbAllocatedMb AS EndTempdbAllocatedMb,
        @StartVolumeFreeMb AS StartVolumeFreeMb,
        @EndVolumeFreeMb AS EndVolumeFreeMb,
        N'PASS' AS ForwardStatus;

    SELECT
        N'phase2_forward_digest' AS EvidenceSection,
        LogicalName,
        DigestKind,
        [RowCount],
        CONVERT(char(64), Digest, 2) AS NormalizedDigestSha256
    FROM @Digests
    ORDER BY LogicalName, DigestKind;

    SELECT
        N'phase2_forward_step' AS EvidenceSection,
        Direction, StepName, StartedAtUtc, FinishedAtUtc,
        DurationMs, RowsAffected, Notes
    FROM dbo.KS4_Phase2_MigrationReceipt
    WHERE RunId = @RunId
    ORDER BY ReceiptId;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NOT NULL
       AND OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NULL
    BEGIN
        DROP TABLE IF EXISTS dbo.KingdomScanData4_Phase2_New;
        DROP TABLE IF EXISTS dbo.KingdomScanData5_Phase2_New;
        DROP TABLE IF EXISTS dbo.IMPORT_STAGING_Phase2_New;
    END;

    UPDATE dbo.KS4_Phase2_PreflightState
    SET Status =
            CASE WHEN OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NOT NULL
                 THEN 'FORWARD_PASS' ELSE 'MIGRATION_FAILED' END,
        FailureMessage = ERROR_MESSAGE()
    WHERE RunId = @RunId;

    IF @ApplicationLockAcquired = 1
    BEGIN
        EXEC sys.sp_releaseapplock
            @Resource = N'K98:KingdomScanData4:Migration',
            @LockOwner = N'Session',
            @DbPrincipal = N'public';
    END;
    THROW;
END CATCH;
