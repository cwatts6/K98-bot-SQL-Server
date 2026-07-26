/*
RollbackForMigrationId: 20260725_001_kingdomscandata4_shadow_type_remediation
Purpose: Restore the retained pre-Phase-2 tables by guarded metadata swap before any post-cutover write
Author: cwatts
CreatedUtc: 2026-07-25
RiskLevel: High
DataLossRisk: None only when the no-post-cutover-write digest guard passes
RollbackType: Full
RequiresBackup: Yes
PreRollbackValidation: Current canonical digests must match forward digests and retained originals must match baseline digests
PostRollbackValidation: Original metadata, rows, digests, indexes, permission, modules, and DBCC CHECKTABLE must pass
RelatedSQLPR:
*/

/*
This rollback is forbidden after application/import restart or any post-cutover
write. In that state use the forward-fix or backup/log recovery branch in
performance_remediation/kingdomscandata4/phase2/04_recovery_runbook.md.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;

DECLARE @ScriptRevision varchar(20) = '20260726.2';
DECLARE @RunId uniqueidentifier;
DECLARE @ProductionApproved bit;
DECLARE @ExpectedKs4Rows bigint;
DECLARE @ExpectedKs5Rows bigint;
DECLARE @ExpectedStagingRows bigint;
DECLARE @BaselineKs4Digest varbinary(32);
DECLARE @BaselineKs5Digest varbinary(32);
DECLARE @BaselineStagingDigest varbinary(32);
DECLARE @ForwardKs4Digest varbinary(32);
DECLARE @ForwardKs5Digest varbinary(32);
DECLARE @ForwardStagingDigest varbinary(32);
DECLARE @OverallStartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @StepStartedAtUtc datetime2(7);
DECLARE @StepFinishedAtUtc datetime2(7);
DECLARE @Sql nvarchar(max);
DECLARE @ExpectedKs5PrimaryKeyName sysname;
DECLARE @ExpectedKs5PrimaryKeyObjectName nvarchar(517);
DECLARE @ApplicationLockResult int;
DECLARE @ApplicationLockAcquired bit = 0;
DECLARE @CutoverCommitted bit = 0;
DECLARE @MigrationHistoryRowsReset int = 0;
DECLARE
    @StartDataFileSizeMb decimal(19, 2),
    @StartUsedLogMb decimal(19, 2),
    @StartTempdbAllocatedMb decimal(19, 2),
    @StartVolumeFreeMb decimal(19, 2),
    @EndDataFileSizeMb decimal(19, 2),
    @EndUsedLogMb decimal(19, 2),
    @EndTempdbAllocatedMb decimal(19, 2),
    @EndVolumeFreeMb decimal(19, 2);

IF OBJECT_ID(N'dbo.KS4_Phase2_PreflightState', N'U') IS NULL
    THROW 51620, 'Phase 2 migration state is absent.', 1;

SELECT TOP (1)
    @RunId = RunId,
    @ProductionApproved = ProductionApproved,
    @ExpectedKs4Rows = Ks4Rows,
    @ExpectedKs5Rows = Ks5Rows,
    @ExpectedStagingRows = StagingRows,
    @BaselineKs4Digest = BaselineKs4Digest,
    @BaselineKs5Digest = BaselineKs5Digest,
    @BaselineStagingDigest = BaselineStagingDigest,
    @ForwardKs4Digest = ForwardKs4Digest,
    @ForwardKs5Digest = ForwardKs5Digest,
    @ForwardStagingDigest = ForwardStagingDigest
FROM dbo.KS4_Phase2_PreflightState
WHERE DatabaseName = DB_NAME()
  AND ServerName = @@SERVERNAME
  AND Status IN ('FORWARD_PASS', 'VERIFIED')
  AND MigrationCompletedAtUtc IS NOT NULL
  AND RollbackCompletedAtUtc IS NULL
  AND FinalizedAtUtc IS NULL
ORDER BY MigrationCompletedAtUtc DESC;

IF @RunId IS NULL
    THROW 51621, 'No eligible unfinalized forward run exists.', 1;

IF DB_NAME() = N'ROK_TRACKER' AND @ProductionApproved <> 1
    THROW 51622, 'The run did not record separate production approval.', 1;

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
      (N'PK_KingdomScanData5_Phase2_Old', N'PK_KingdomScanData5_Phase2_Failed')
   OR OBJECT_ID(N'dbo.PK_KingdomScanData5_Phase2_Old', N'PK') IS NULL
   OR OBJECT_ID(N'dbo.PK_KingdomScanData5_Phase2_Failed', N'PK') IS NOT NULL
    THROW 51632, 'The captured KingdomScanData5 primary-key names are not rollback-safe.', 1;

IF @@TRANCOUNT <> 0
    THROW 51623, 'Run rollback with no existing user transaction.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Failed', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Failed', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Failed', N'U') IS NOT NULL
    THROW 51624, 'Canonical, retained-original, or failed-copy object state is not rollback-safe.', 1;

EXEC @ApplicationLockResult = sys.sp_getapplock
    @Resource = N'K98:KingdomScanData4:Migration',
    @LockMode = N'Exclusive',
    @LockOwner = N'Session',
    @LockTimeout = 0,
    @DbPrincipal = N'public';

IF @ApplicationLockResult < 0
    THROW 51625, 'Could not acquire the Phase 2 migration application lock.', 1;
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
        THROW 51626, 'Conflicting user sessions are connected.', 1;

    SELECT @StartDataFileSizeMb =
        SUM(CASE WHEN type = 0 THEN size ELSE 0 END) * 8.0 / 1024.0
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

    INSERT @BigintMap
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

    INSERT @IntMap
    VALUES
        (N'KS4', N'PowerRank'), (N'KS4', N'SCANORDER'),
        (N'KS5', N'PowerRank'), (N'KS5', N'SCANORDER'),
        (N'STAGING', N'SCANORDER');

    INSERT @StringMap
    VALUES
        (N'KS4', N'GovernorName', 200, 1),
        (N'KS4', N'Alliance', 100, 1),
        (N'KS5', N'GovernorName', 200, 1),
        (N'KS5', N'Alliance', 100, 1),
        (N'STAGING', N'Name', 200, 1),
        (N'STAGING', N'Alliance', 100, 1),
        (N'STAGING', N'Updated_on', 200, 0);

    DECLARE @DigestWork table
    (
        LogicalName sysname NOT NULL,
        PhysicalName sysname NOT NULL,
        DigestKind varchar(12) NOT NULL,
        ExpectedDigest varbinary(32) NOT NULL,
        PRIMARY KEY (LogicalName, DigestKind)
    );
    DECLARE @Digests table
    (
        LogicalName sysname NOT NULL,
        DigestKind varchar(12) NOT NULL,
        [RowCount] bigint NOT NULL,
        Digest varbinary(32) NOT NULL,
        PRIMARY KEY (LogicalName, DigestKind)
    );

    INSERT @DigestWork
    VALUES
        (N'KS4', N'KingdomScanData4', 'CURRENT', @ForwardKs4Digest),
        (N'KS5', N'KingdomScanData5', 'CURRENT', @ForwardKs5Digest),
        (N'STAGING', N'IMPORT_STAGING', 'CURRENT', @ForwardStagingDigest),
        (N'KS4', N'KingdomScanData4_Phase2_Old', 'RETAINED', @BaselineKs4Digest),
        (N'KS5', N'KingdomScanData5_Phase2_Old', 'RETAINED', @BaselineKs5Digest),
        (N'STAGING', N'IMPORT_STAGING_Phase2_Old', 'RETAINED', @BaselineStagingDigest);

    DECLARE
        @LogicalName sysname,
        @PhysicalName sysname,
        @DigestKind varchar(12),
        @ExpectedDigest varbinary(32),
        @Projection nvarchar(max),
        @CanonicalRows nvarchar(max),
        @Digest varbinary(32),
        @DigestRows bigint;

    SET @StepStartedAtUtc = SYSUTCDATETIME();
    BEGIN TRANSACTION;

    /*
    Runtime writers do not yet share the migration application lock. Hold
    exclusive locks on both the canonical and retained tables from digest
    verification through the metadata swap.
    */
    DECLARE @LockWitness bigint;
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData5 WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData4 WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING_Phase2_Old WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData5_Phase2_Old WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData4_Phase2_Old WITH (TABLOCKX, HOLDLOCK);

    DECLARE digest_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT LogicalName, PhysicalName, DigestKind, ExpectedDigest
    FROM @DigestWork ORDER BY LogicalName, DigestKind;

    OPEN digest_cursor;
    FETCH NEXT FROM digest_cursor
    INTO @LogicalName, @PhysicalName, @DigestKind, @ExpectedDigest;

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

        IF @Digest <> @ExpectedDigest
            THROW 51627, 'Rollback digest guard failed; post-cutover write or retained-original drift detected.', 1;

        INSERT @Digests VALUES
            (@LogicalName, @DigestKind, @DigestRows, @Digest);

        FETCH NEXT FROM digest_cursor
        INTO @LogicalName, @PhysicalName, @DigestKind, @ExpectedDigest;
    END;

    CLOSE digest_cursor;
    DEALLOCATE digest_cursor;

    SET @StepFinishedAtUtc = SYSUTCDATETIME();
    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'ROLLBACK', N'pre_rollback_digest_guard',
         @StepStartedAtUtc, @StepFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
         2 * (@ExpectedKs4Rows + @ExpectedKs5Rows + @ExpectedStagingRows),
         N'Current matches forward and retained originals match baseline; no post-cutover write.');

    SET @StepStartedAtUtc = SYSUTCDATETIME();

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
        THROW 51628, 'A conflicting user session connected before rollback swap.', 1;

    EXEC sys.sp_rename N'dbo.IMPORT_STAGING', N'IMPORT_STAGING_Phase2_Failed', N'OBJECT';
    EXEC sys.sp_rename N'dbo.IMPORT_STAGING_Phase2_Old', N'IMPORT_STAGING', N'OBJECT';
    EXEC sys.sp_rename N'dbo.KingdomScanData5', N'KingdomScanData5_Phase2_Failed', N'OBJECT';
    EXEC sys.sp_rename N'dbo.KingdomScanData5_Phase2_Old', N'KingdomScanData5', N'OBJECT';
    EXEC sys.sp_rename N'dbo.KingdomScanData4', N'KingdomScanData4_Phase2_Failed', N'OBJECT';
    EXEC sys.sp_rename N'dbo.KingdomScanData4_Phase2_Old', N'KingdomScanData4', N'OBJECT';
    EXEC sys.sp_rename
        @ExpectedKs5PrimaryKeyObjectName,
        N'PK_KingdomScanData5_Phase2_Failed',
        N'OBJECT';
    EXEC sys.sp_rename
        N'dbo.PK_KingdomScanData5_Phase2_Old',
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

    DECLARE @ActualColumns table
    (
        ObjectName sysname NOT NULL,
        ColumnId int NOT NULL,
        ColumnName sysname NOT NULL,
        TypeName sysname NOT NULL,
        MaxLength smallint NOT NULL,
        [Precision] tinyint NOT NULL,
        Scale tinyint NOT NULL,
        CollationName sysname NULL,
        IsNullable bit NOT NULL,
        IsIdentity bit NOT NULL,
        IdentitySeed sql_variant NULL,
        IdentityIncrement sql_variant NULL,
        IsComputed bit NOT NULL,
        IsPersisted bit NULL,
        ComputedDefinition nvarchar(max) NULL,
        DefaultName sysname NULL,
        DefaultDefinition nvarchar(max) NULL,
        PRIMARY KEY (ObjectName, ColumnId)
    );

    INSERT @ActualColumns
    SELECT
        OBJECT_NAME(column_info.object_id),
        column_info.column_id,
        column_info.name,
        type_info.name,
        column_info.max_length,
        column_info.precision,
        column_info.scale,
        column_info.collation_name,
        column_info.is_nullable,
        column_info.is_identity,
        identity_info.seed_value,
        identity_info.increment_value,
        column_info.is_computed,
        computed_info.is_persisted,
        computed_info.definition,
        default_info.name,
        default_info.definition
    FROM sys.columns AS column_info
    JOIN sys.types AS type_info
      ON type_info.user_type_id = column_info.user_type_id
    LEFT JOIN sys.identity_columns AS identity_info
      ON identity_info.object_id = column_info.object_id
     AND identity_info.column_id = column_info.column_id
    LEFT JOIN sys.computed_columns AS computed_info
      ON computed_info.object_id = column_info.object_id
     AND computed_info.column_id = column_info.column_id
    LEFT JOIN sys.default_constraints AS default_info
      ON default_info.object_id = column_info.default_object_id
    WHERE column_info.object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    );

    IF EXISTS
    (
        SELECT ObjectName, ColumnId, ColumnName, TypeName, MaxLength,
               [Precision], Scale, ISNULL(CollationName, N''), IsNullable,
               IsIdentity, IdentitySeed, IdentityIncrement, IsComputed,
               ISNULL(IsPersisted, 0), ISNULL(ComputedDefinition, N''),
               ISNULL(DefaultName, N''), ISNULL(DefaultDefinition, N'')
        FROM dbo.KS4_Phase2_ColumnInventory WHERE RunId = @RunId
        EXCEPT
        SELECT ObjectName, ColumnId, ColumnName, TypeName, MaxLength,
               [Precision], Scale, ISNULL(CollationName, N''), IsNullable,
               IsIdentity, IdentitySeed, IdentityIncrement, IsComputed,
               ISNULL(IsPersisted, 0), ISNULL(ComputedDefinition, N''),
               ISNULL(DefaultName, N''), ISNULL(DefaultDefinition, N'')
        FROM @ActualColumns
    )
       OR EXISTS
    (
        SELECT ObjectName, ColumnId, ColumnName, TypeName, MaxLength,
               [Precision], Scale, ISNULL(CollationName, N''), IsNullable,
               IsIdentity, IdentitySeed, IdentityIncrement, IsComputed,
               ISNULL(IsPersisted, 0), ISNULL(ComputedDefinition, N''),
               ISNULL(DefaultName, N''), ISNULL(DefaultDefinition, N'')
        FROM @ActualColumns
        EXCEPT
        SELECT ObjectName, ColumnId, ColumnName, TypeName, MaxLength,
               [Precision], Scale, ISNULL(CollationName, N''), IsNullable,
               IsIdentity, IdentitySeed, IdentityIncrement, IsComputed,
               ISNULL(IsPersisted, 0), ISNULL(ComputedDefinition, N''),
               ISNULL(DefaultName, N''), ISNULL(DefaultDefinition, N'')
        FROM dbo.KS4_Phase2_ColumnInventory WHERE RunId = @RunId
    )
        THROW 51629, 'Post-rollback column metadata differs from the captured contract.', 1;

    DECLARE @ActualIndexes table
    (
        ObjectName sysname NOT NULL,
        IndexName sysname NOT NULL,
        TypeDesc nvarchar(60) NOT NULL,
        IsUnique bit NOT NULL,
        IsPrimaryKey bit NOT NULL,
        IsDisabled bit NOT NULL,
        HasFilter bit NOT NULL,
        FilterDefinition nvarchar(max) NULL,
        KeyColumns nvarchar(max) NULL,
        IncludeColumns nvarchar(max) NULL,
        PRIMARY KEY (ObjectName, IndexName)
    );

    INSERT @ActualIndexes
    SELECT
        OBJECT_NAME(index_info.object_id),
        index_info.name,
        index_info.type_desc,
        index_info.is_unique,
        index_info.is_primary_key,
        index_info.is_disabled,
        index_info.has_filter,
        index_info.filter_definition,
        key_columns.ColumnList,
        include_columns.ColumnList
    FROM sys.indexes AS index_info
    CROSS APPLY
    (
        SELECT STRING_AGG(
            CONVERT(nvarchar(max),
                QUOTENAME(column_info.name)
                + CASE WHEN index_column.is_descending_key = 1
                       THEN N' DESC' ELSE N' ASC' END),
            N',') WITHIN GROUP (ORDER BY index_column.key_ordinal) AS ColumnList
        FROM sys.index_columns AS index_column
        JOIN sys.columns AS column_info
          ON column_info.object_id = index_column.object_id
         AND column_info.column_id = index_column.column_id
        WHERE index_column.object_id = index_info.object_id
          AND index_column.index_id = index_info.index_id
          AND index_column.key_ordinal > 0
    ) AS key_columns
    OUTER APPLY
    (
        SELECT STRING_AGG(
            CONVERT(nvarchar(max), QUOTENAME(column_info.name)),
            N',') WITHIN GROUP (ORDER BY index_column.index_column_id) AS ColumnList
        FROM sys.index_columns AS index_column
        JOIN sys.columns AS column_info
          ON column_info.object_id = index_column.object_id
         AND column_info.column_id = index_column.column_id
        WHERE index_column.object_id = index_info.object_id
          AND index_column.index_id = index_info.index_id
          AND index_column.is_included_column = 1
    ) AS include_columns
    WHERE index_info.object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
      AND index_info.index_id > 0;

    IF EXISTS
    (
        SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
               IsDisabled, HasFilter, ISNULL(FilterDefinition, N''),
               KeyColumns, ISNULL(IncludeColumns, N'')
        FROM dbo.KS4_Phase2_IndexInventory WHERE RunId = @RunId
        EXCEPT
        SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
               IsDisabled, HasFilter, ISNULL(FilterDefinition, N''),
               KeyColumns, ISNULL(IncludeColumns, N'')
        FROM @ActualIndexes
    )
       OR EXISTS
    (
        SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
               IsDisabled, HasFilter, ISNULL(FilterDefinition, N''),
               KeyColumns, ISNULL(IncludeColumns, N'')
        FROM @ActualIndexes
        EXCEPT
        SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
               IsDisabled, HasFilter, ISNULL(FilterDefinition, N''),
               KeyColumns, ISNULL(IncludeColumns, N'')
        FROM dbo.KS4_Phase2_IndexInventory WHERE RunId = @RunId
    )
        THROW 51630, 'Post-rollback indexes differ from the captured contract.', 1;

    DECLARE @ActualStatistics table
    (
        ObjectName sysname NOT NULL,
        StatisticName sysname NOT NULL,
        IsAutoCreated bit NOT NULL,
        IsUserCreated bit NOT NULL,
        NoRecompute bit NOT NULL,
        HasFilter bit NOT NULL,
        FilterDefinition nvarchar(max) NULL,
        StatisticColumns nvarchar(max) NOT NULL,
        PRIMARY KEY (ObjectName, StatisticName)
    );

    INSERT @ActualStatistics
    SELECT
        OBJECT_NAME(stat_info.object_id),
        stat_info.name,
        stat_info.auto_created,
        stat_info.user_created,
        stat_info.no_recompute,
        stat_info.has_filter,
        stat_info.filter_definition,
        stat_columns.ColumnList
    FROM sys.stats AS stat_info
    CROSS APPLY
    (
        SELECT STRING_AGG(
            CONVERT(nvarchar(max), QUOTENAME(column_info.name)),
            N',') WITHIN GROUP (ORDER BY stat_column.stats_column_id) AS ColumnList
        FROM sys.stats_columns AS stat_column
        JOIN sys.columns AS column_info
          ON column_info.object_id = stat_column.object_id
         AND column_info.column_id = stat_column.column_id
        WHERE stat_column.object_id = stat_info.object_id
          AND stat_column.stats_id = stat_info.stats_id
    ) AS stat_columns
    LEFT JOIN sys.indexes AS index_info
      ON index_info.object_id = stat_info.object_id
     AND index_info.index_id = stat_info.stats_id
    WHERE stat_info.object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
      AND index_info.index_id IS NULL;

    IF EXISTS
    (
        SELECT ObjectName, StatisticName, IsAutoCreated, IsUserCreated,
               NoRecompute, HasFilter, ISNULL(FilterDefinition, N''),
               StatisticColumns
        FROM dbo.KS4_Phase2_StatisticInventory WHERE RunId = @RunId
        EXCEPT
        SELECT ObjectName, StatisticName, IsAutoCreated, IsUserCreated,
               NoRecompute, HasFilter, ISNULL(FilterDefinition, N''),
               StatisticColumns
        FROM @ActualStatistics
    )
       OR EXISTS
    (
        SELECT ObjectName, StatisticName, IsAutoCreated, IsUserCreated,
               NoRecompute, HasFilter, ISNULL(FilterDefinition, N''),
               StatisticColumns
        FROM @ActualStatistics
        EXCEPT
        SELECT ObjectName, StatisticName, IsAutoCreated, IsUserCreated,
               NoRecompute, HasFilter, ISNULL(FilterDefinition, N''),
               StatisticColumns
        FROM dbo.KS4_Phase2_StatisticInventory WHERE RunId = @RunId
    )
        THROW 51631, 'Post-rollback standalone statistics differ from the captured contract.', 1;

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
        FROM dbo.KS4_Phase2_PermissionInventory WHERE RunId = @RunId
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
        FROM dbo.KS4_Phase2_PermissionInventory WHERE RunId = @RunId
    )
        THROW 51632, 'Post-rollback permissions differ from the captured contract.', 1;

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
        THROW 51633, 'Post-rollback module metadata differs from the captured contract.', 1;

    /*
    Deploy-SqlMigration.ps1 records the forward script as Applied before an
    operator can choose the pre-restart rollback. Reset only this exact
    migration to Pending inside the same transaction as the metadata swap so
    a successful early rollback remains auditable and retryable. Direct/manual
    rehearsals without SchemaMigrationHistory deliberately produce zero rows.
    */
    IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NOT NULL
    BEGIN
        UPDATE dbo.SchemaMigrationHistory WITH (UPDLOCK, HOLDLOCK)
        SET Status = N'Pending',
            ErrorMessage = CONCAT(
                N'Pre-restart Phase 2 rollback completed for run ',
                CONVERT(nvarchar(36), @RunId),
                N'; a new preflight is required before retry.'
            )
        WHERE MigrationId =
              N'20260725_001_kingdomscandata4_shadow_type_remediation'
          AND Status = N'Applied';

        SET @MigrationHistoryRowsReset = @@ROWCOUNT;
    END;

    COMMIT TRANSACTION;
    SET @CutoverCommitted = 1;
    SET @StepFinishedAtUtc = SYSUTCDATETIME();

    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'ROLLBACK', N'transactional_rollback_and_module_refresh',
         @StepStartedAtUtc, @StepFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
         52, N'Original tables restored; migrated copies retained as *_Phase2_Failed.');

    DBCC CHECKTABLE (N'dbo.KingdomScanData4') WITH NO_INFOMSGS;
    DBCC CHECKTABLE (N'dbo.KingdomScanData5') WITH NO_INFOMSGS;
    DBCC CHECKTABLE (N'dbo.IMPORT_STAGING') WITH NO_INFOMSGS;

    IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @ExpectedKs4Rows
       OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @ExpectedKs5Rows
       OR (SELECT COUNT_BIG(*) FROM dbo.IMPORT_STAGING) <> @ExpectedStagingRows
       OR (SELECT COUNT(*) FROM sys.indexes
           WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
             AND index_id > 0) <> 10
       OR NOT EXISTS
    (
        SELECT 1
        FROM sys.database_permissions AS permission_info
        JOIN sys.database_principals AS principal_info
          ON principal_info.principal_id = permission_info.grantee_principal_id
        WHERE permission_info.major_id = OBJECT_ID(N'dbo.KingdomScanData4')
          AND principal_info.name = N'ImportProcUser'
          AND permission_info.permission_name = N'SELECT'
          AND permission_info.state = 'G'
    )
        THROW 51634, 'Post-rollback rows, indexes, or permission verification failed.', 1;

    UPDATE dbo.KS4_Phase2_PreflightState
    SET RollbackCompletedAtUtc = SYSUTCDATETIME(),
        Status = 'ROLLBACK_PASS'
    WHERE RunId = @RunId;

    EXEC sys.sp_releaseapplock
        @Resource = N'K98:KingdomScanData4:Migration',
        @LockOwner = N'Session',
        @DbPrincipal = N'public';
    SET @ApplicationLockAcquired = 0;

    DECLARE @OverallFinishedAtUtc datetime2(7) = SYSUTCDATETIME();

    SELECT @EndDataFileSizeMb =
        SUM(CASE WHEN type = 0 THEN size ELSE 0 END) * 8.0 / 1024.0
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

    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'ROLLBACK', N'total_rollback_outage',
         @OverallStartedAtUtc, @OverallFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @OverallStartedAtUtc, @OverallFinishedAtUtc) / 1000.0,
         @ExpectedKs4Rows + @ExpectedKs5Rows + @ExpectedStagingRows,
         CONCAT(
             N'Production-usable metadata-swap rollback; no database snapshot used. ',
             N'SchemaMigrationHistory rows reset to Pending: ',
             @MigrationHistoryRowsReset,
             N'.'
         ));

    SELECT
        N'phase2_rollback_completion' AS EvidenceSection,
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
        @StartDataFileSizeMb AS StartDataFileSizeMb,
        @EndDataFileSizeMb AS EndDataFileSizeMb,
        @StartUsedLogMb AS StartUsedLogMb,
        @EndUsedLogMb AS EndUsedLogMb,
        @StartTempdbAllocatedMb AS StartTempdbAllocatedMb,
        @EndTempdbAllocatedMb AS EndTempdbAllocatedMb,
        @StartVolumeFreeMb AS StartVolumeFreeMb,
        @EndVolumeFreeMb AS EndVolumeFreeMb,
        @MigrationHistoryRowsReset AS MigrationHistoryRowsReset,
        N'PASS' AS RollbackStatus;

    SELECT
        N'phase2_rollback_digest' AS EvidenceSection,
        LogicalName,
        DigestKind,
        [RowCount],
        CONVERT(char(64), Digest, 2) AS NormalizedDigestSha256
    FROM @Digests
    ORDER BY LogicalName, DigestKind;

    SELECT
        N'phase2_rollback_step' AS EvidenceSection,
        Direction, StepName, StartedAtUtc, FinishedAtUtc,
        DurationMs, RowsAffected, Notes
    FROM dbo.KS4_Phase2_MigrationReceipt
    WHERE RunId = @RunId AND Direction = 'ROLLBACK'
    ORDER BY ReceiptId;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    IF @ApplicationLockAcquired = 1
    BEGIN
        EXEC sys.sp_releaseapplock
            @Resource = N'K98:KingdomScanData4:Migration',
            @LockOwner = N'Session',
            @DbPrincipal = N'public';
    END;
    IF @CutoverCommitted = 1
    BEGIN
        UPDATE dbo.KS4_Phase2_PreflightState
        SET Status = 'ROLLBACK_FAILED',
            FailureMessage = ERROR_MESSAGE()
        WHERE RunId = @RunId
          AND RollbackCompletedAtUtc IS NULL;
    END
    ELSE
    BEGIN
        UPDATE dbo.KS4_Phase2_PreflightState
        SET FailureMessage =
            CONCAT(N'Rollback refused before cutover: ', ERROR_MESSAGE())
        WHERE RunId = @RunId
          AND RollbackCompletedAtUtc IS NULL;
    END;
    THROW;
END CATCH;
