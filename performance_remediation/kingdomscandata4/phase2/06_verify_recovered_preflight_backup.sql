/*
KingdomScanData4 Phase 2 representative recovery verification.

Run only after 05_restore_preflight_backup_to_recovery.sql creates the exact
separately named recovery database. This verifies the original pre-migration
schema and the in-progress preflight receipt captured inside the restored
backup. The source receipt becomes PASS only after BACKUP DATABASE,
RESTORE VERIFYONLY, and the backup metadata checks complete, so the backup
correctly contains the earlier STARTED / BackupVerified = 0 state.

Edit only the confirmation values in a local execution copy.
*/
USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY];
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ConfirmRecoveryDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY';
DECLARE @ConfirmSourceDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK';
DECLARE @ConfirmRunId uniqueidentifier =
    '00000000-0000-0000-0000-000000000000';
DECLARE @ExecuteVerification bit = 0;
DECLARE @StartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @Sql nvarchar(max);

IF @ExecuteVerification <> 1
    THROW 51720, 'Recovery verification is disabled. Set @ExecuteVerification = 1 only in a reviewed local execution copy.', 1;

IF DB_NAME() <> @ConfirmRecoveryDatabase
   OR @ConfirmRecoveryDatabase <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY'
    THROW 51721, 'Recovery verification requires the exact separately named recovery database.', 1;

IF DB_NAME() IN
   (
       N'ROK_TRACKER',
       N'ROK_TRACKER_BACKUP_TEST_KS4',
       N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE',
       N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK'
   )
    THROW 51722, 'Recovery verification refuses every protected production, source, snapshot, and benchmark database.', 1;

IF @ConfirmRunId = '00000000-0000-0000-0000-000000000000'
    THROW 51723, 'Set @ConfirmRunId to the exact restored preflight run ID.', 1;

IF OBJECT_ID(N'dbo.KS4_Phase2_PreflightState', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KS4_Phase2_ColumnInventory', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KS4_Phase2_IndexInventory', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KS4_Phase2_StatisticInventory', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KS4_Phase2_PermissionInventory', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KS4_Phase2_ModuleInventory', N'U') IS NULL
    THROW 51724, 'The restored preflight receipt or inventory tables are incomplete.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NOT NULL
    THROW 51725, 'A forward or rollback table artifact exists in the recovered preflight backup.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.KS4_Phase2_PreflightState
    WHERE RunId = @ConfirmRunId
      AND DatabaseName = @ConfirmSourceDatabase
      AND BackupVerified = 0
      AND Status = 'STARTED'
      AND CompletedAtUtc IS NULL
      AND BackupPath IS NULL
      AND Ks4Rows IS NULL
      AND Ks5Rows IS NULL
      AND StagingRows IS NULL
      AND BaselineKs4Digest IS NULL
      AND BaselineKs5Digest IS NULL
      AND BaselineStagingDigest IS NULL
      AND MigrationStartedAtUtc IS NULL
      AND MigrationCompletedAtUtc IS NULL
      AND VerifiedAtUtc IS NULL
      AND RollbackCompletedAtUtc IS NULL
      AND FinalizedAtUtc IS NULL
)
    THROW 51726, 'The exact in-progress preflight receipt was not restored.', 1;

/*
These are the exact values from the finalized PASS receipt that
05_restore_preflight_backup_to_recovery.sql validates in the source database
before restoring this earlier point-in-time image.
*/
DECLARE @ExpectedKs4Rows bigint = 394506;
DECLARE @ExpectedKs5Rows bigint = 394526;
DECLARE @ExpectedStagingRows bigint = 0;
DECLARE @ExpectedKs4MaxScan int = 1020;
DECLARE @ExpectedKs5MaxScan int = 1020;
DECLARE @BaselineKs4Digest varbinary(32) =
    0x2E0FE9F846FA4C29D6900C81DE3A04637F8CA23A9C01DE8CD8E958222EE94D1A;
DECLARE @BaselineKs5Digest varbinary(32) =
    0x1AB01D4C73BA72EC7EFB5B04755EED0FF214EBD686CA0A9EAB590B5441FCABB1;
DECLARE @BaselineStagingDigest varbinary(32) =
    0x5EE9173B1B564E61AFD2359A897C180B5EA83875A91A28537DF4202AAD4B3AA7;

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
    SELECT ObjectName, ColumnId, ColumnName, TypeName, MaxLength, [Precision],
           Scale, CollationName, IsNullable, IsIdentity, IdentitySeed,
           IdentityIncrement, IsComputed, IsPersisted, ComputedDefinition,
           DefaultName, DefaultDefinition
    FROM dbo.KS4_Phase2_ColumnInventory
    WHERE RunId = @ConfirmRunId
    EXCEPT
    SELECT ObjectName, ColumnId, ColumnName, TypeName, MaxLength, [Precision],
           Scale, CollationName, IsNullable, IsIdentity, IdentitySeed,
           IdentityIncrement, IsComputed, IsPersisted, ComputedDefinition,
           DefaultName, DefaultDefinition
    FROM @ActualColumns
)
   OR EXISTS
(
    SELECT ObjectName, ColumnId, ColumnName, TypeName, MaxLength, [Precision],
           Scale, CollationName, IsNullable, IsIdentity, IdentitySeed,
           IdentityIncrement, IsComputed, IsPersisted, ComputedDefinition,
           DefaultName, DefaultDefinition
    FROM @ActualColumns
    EXCEPT
    SELECT ObjectName, ColumnId, ColumnName, TypeName, MaxLength, [Precision],
           Scale, CollationName, IsNullable, IsIdentity, IdentitySeed,
           IdentityIncrement, IsComputed, IsPersisted, ComputedDefinition,
           DefaultName, DefaultDefinition
    FROM dbo.KS4_Phase2_ColumnInventory
    WHERE RunId = @ConfirmRunId
)
    THROW 51728, 'Recovered original column metadata differs from the preflight inventory.', 1;

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
    KeyColumns nvarchar(max) NOT NULL,
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
    SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey, IsDisabled,
           HasFilter, FilterDefinition, KeyColumns, IncludeColumns
    FROM dbo.KS4_Phase2_IndexInventory
    WHERE RunId = @ConfirmRunId
    EXCEPT
    SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey, IsDisabled,
           HasFilter, FilterDefinition, KeyColumns, IncludeColumns
    FROM @ActualIndexes
)
   OR EXISTS
(
    SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey, IsDisabled,
           HasFilter, FilterDefinition, KeyColumns, IncludeColumns
    FROM @ActualIndexes
    EXCEPT
    SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey, IsDisabled,
           HasFilter, FilterDefinition, KeyColumns, IncludeColumns
    FROM dbo.KS4_Phase2_IndexInventory
    WHERE RunId = @ConfirmRunId
)
   OR (SELECT COUNT(*) FROM @ActualIndexes WHERE ObjectName = N'KingdomScanData4') <> 10
   OR (SELECT COUNT(*) FROM @ActualIndexes WHERE ObjectName = N'KingdomScanData5') <> 1
   OR EXISTS (SELECT 1 FROM @ActualIndexes WHERE ObjectName = N'IMPORT_STAGING')
    THROW 51729, 'Recovered original index metadata differs from the exact preflight inventory.', 1;

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
           NoRecompute, HasFilter, FilterDefinition, StatisticColumns
    FROM dbo.KS4_Phase2_StatisticInventory
    WHERE RunId = @ConfirmRunId
    EXCEPT
    SELECT ObjectName, StatisticName, IsAutoCreated, IsUserCreated,
           NoRecompute, HasFilter, FilterDefinition, StatisticColumns
    FROM @ActualStatistics
)
   OR EXISTS
(
    SELECT ObjectName, StatisticName, IsAutoCreated, IsUserCreated,
           NoRecompute, HasFilter, FilterDefinition, StatisticColumns
    FROM @ActualStatistics
    EXCEPT
    SELECT ObjectName, StatisticName, IsAutoCreated, IsUserCreated,
           NoRecompute, HasFilter, FilterDefinition, StatisticColumns
    FROM dbo.KS4_Phase2_StatisticInventory
    WHERE RunId = @ConfirmRunId
)
    THROW 51730, 'Recovered original standalone-statistic metadata differs from the preflight inventory.', 1;

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
    FROM dbo.KS4_Phase2_PermissionInventory
    WHERE RunId = @ConfirmRunId
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
    WHERE RunId = @ConfirmRunId
)
   OR (SELECT COUNT(*) FROM @ActualPermissions) <> 1
   OR NOT EXISTS
(
    SELECT 1
    FROM @ActualPermissions
    WHERE ObjectName = N'KingdomScanData4'
      AND PrincipalName = N'ImportProcUser'
      AND StateCode = 'G'
      AND PermissionName = N'SELECT'
      AND ColumnId = 0
)
    THROW 51731, 'Recovered original permission metadata differs from the exact one-grant preflight inventory.', 1;

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
    LogicalName sysname NOT NULL PRIMARY KEY,
    PhysicalName sysname NOT NULL,
    ExpectedRows bigint NOT NULL,
    ExpectedDigest varbinary(32) NOT NULL
);
DECLARE @Digests table
(
    LogicalName sysname NOT NULL PRIMARY KEY,
    [RowCount] bigint NOT NULL,
    Digest varbinary(32) NOT NULL
);

INSERT @DigestWork
VALUES
    (N'KS4', N'KingdomScanData4', @ExpectedKs4Rows, @BaselineKs4Digest),
    (N'KS5', N'KingdomScanData5', @ExpectedKs5Rows, @BaselineKs5Digest),
    (N'STAGING', N'IMPORT_STAGING', @ExpectedStagingRows, @BaselineStagingDigest);

DECLARE
    @LogicalName sysname,
    @PhysicalName sysname,
    @ExpectedRows bigint,
    @ExpectedDigest varbinary(32),
    @Projection nvarchar(max),
    @CanonicalRows nvarchar(max),
    @Digest varbinary(32),
    @DigestRows bigint;

DECLARE digest_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT LogicalName, PhysicalName, ExpectedRows, ExpectedDigest
FROM @DigestWork
ORDER BY LogicalName;

OPEN digest_cursor;
FETCH NEXT FROM digest_cursor
INTO @LogicalName, @PhysicalName, @ExpectedRows, @ExpectedDigest;

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

    IF @DigestRows <> @ExpectedRows OR @Digest <> @ExpectedDigest
        THROW 51732, 'A recovered row count or normalized SHA-256 digest differs from the preflight receipt.', 1;

    INSERT @Digests VALUES (@LogicalName, @DigestRows, @Digest);

    FETCH NEXT FROM digest_cursor
    INTO @LogicalName, @PhysicalName, @ExpectedRows, @ExpectedDigest;
END;

CLOSE digest_cursor;
DEALLOCATE digest_cursor;

IF (SELECT MAX(TRY_CONVERT(int, SCANORDER)) FROM dbo.KingdomScanData4) <> @ExpectedKs4MaxScan
   OR (SELECT MAX(TRY_CONVERT(int, SCANORDER)) FROM dbo.KingdomScanData5) <> @ExpectedKs5MaxScan
    THROW 51733, 'Recovered maximum scan values differ from the preflight receipt.', 1;

DECLARE
    @ModuleSchema sysname,
    @ModuleName sysname,
    @ModuleType char(2),
    @QualifiedModule nvarchar(517);

IF (SELECT COUNT(*) FROM dbo.KS4_Phase2_ModuleInventory
    WHERE RunId = @ConfirmRunId) <> 52
    THROW 51734, 'The recovered preflight module inventory does not contain exactly 52 modules.', 1;

DECLARE module_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT SchemaName, ObjectName, ObjectType
FROM dbo.KS4_Phase2_ModuleInventory
WHERE RunId = @ConfirmRunId
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

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_Phase2_ModuleInventory AS expected
    LEFT JOIN sys.sql_modules AS actual
      ON actual.object_id =
         OBJECT_ID(QUOTENAME(expected.SchemaName) + N'.' + QUOTENAME(expected.ObjectName))
    WHERE expected.RunId = @ConfirmRunId
      AND
      (
          actual.object_id IS NULL
          OR HASHBYTES('SHA2_256', CONVERT(varbinary(max), actual.definition))
                <> expected.DefinitionHash
          OR actual.uses_ansi_nulls <> expected.UsesAnsiNulls
          OR actual.uses_quoted_identifier <> expected.UsesQuotedIdentifier
      )
)
    THROW 51735, 'A recovered dependent module changed or failed refresh verification.', 1;

DBCC CHECKDB WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.KingdomScanData4') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.KingdomScanData5') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.IMPORT_STAGING') WITH NO_INFOMSGS;

DECLARE
    @LatestStatsRows bigint,
    @DailyExportRows bigint,
    @GlobalLatestRows bigint;

SELECT @LatestStatsRows = COUNT_BIG(*) FROM dbo.v_PlayerLatestStats;
SELECT @DailyExportRows = COUNT_BIG(*) FROM dbo.vDaily_PlayerExport;
SELECT @GlobalLatestRows = COUNT_BIG(*) FROM dbo.vw_Governor_KVK_Summary_GlobalLatest;

IF @LatestStatsRows <> 2371
   OR @DailyExportRows <> 223386
   OR @GlobalLatestRows <> 411
    THROW 51736, 'Recovered critical read-only view row counts changed.', 1;

DECLARE @HighActivityGovernorID bigint =
(
    SELECT TOP (1) CONVERT(bigint, GovernorID)
    FROM dbo.KingdomScanData4
    GROUP BY CONVERT(bigint, GovernorID)
    ORDER BY COUNT_BIG(*) DESC, CONVERT(bigint, GovernorID)
);

CREATE TABLE #GovernorExists
(
    GovernorID bigint NOT NULL,
    ExistsInDatabase bit NOT NULL
);

INSERT #GovernorExists
EXEC dbo.usp_LeadershipPlayerGovernorExists
    @GovernorID = @HighActivityGovernorID;

IF (SELECT COUNT(*) FROM #GovernorExists) <> 1
   OR NOT EXISTS
(
    SELECT 1
    FROM #GovernorExists
    WHERE GovernorID = @HighActivityGovernorID
      AND ExistsInDatabase = 1
)
    THROW 51737, 'Recovered leadership governor lookup smoke failed.', 1;

CREATE TABLE #LeadershipDirectory
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

INSERT #LeadershipDirectory
EXEC dbo.usp_GetLeadershipPlayerLookupDirectory
    @HistoryDays = 720;

IF (SELECT COUNT(*) FROM #LeadershipDirectory) <> 1639
    THROW 51738, 'Recovered 720-day leadership directory row count changed.', 1;

SELECT
    N'phase2_recovery_verify_completion' AS EvidenceSection,
    @ConfirmRunId AS RunId,
    @ConfirmSourceDatabase AS BackupSourceDatabase,
    DB_NAME() AS RecoveryDatabase,
    @StartedAtUtc AS StartedAtUtc,
    SYSUTCDATETIME() AS CompletedAtUtc,
    DATEDIFF_BIG(millisecond, @StartedAtUtc, SYSUTCDATETIME()) AS DurationMs,
    @ExpectedKs4Rows AS Ks4Rows,
    @ExpectedKs5Rows AS Ks5Rows,
    @ExpectedStagingRows AS StagingRows,
    @ExpectedKs4MaxScan AS Ks4MaxScan,
    @ExpectedKs5MaxScan AS Ks5MaxScan,
    (SELECT COUNT(*) FROM @ActualIndexes WHERE ObjectName = N'KingdomScanData4') AS Ks4IndexCount,
    (SELECT COUNT(*) FROM @ActualIndexes WHERE ObjectName = N'KingdomScanData5') AS Ks5IndexCount,
    (SELECT COUNT(*) FROM @ActualStatistics) AS StandaloneStatisticCount,
    (SELECT COUNT(*) FROM @ActualPermissions) AS ExplicitPermissionCount,
    (SELECT COUNT(*) FROM dbo.KS4_Phase2_ModuleInventory WHERE RunId = @ConfirmRunId) AS RefreshedModuleCount,
    @LatestStatsRows AS LatestStatsRows,
    @DailyExportRows AS DailyExportRows,
    @GlobalLatestRows AS GlobalLatestRows,
    (SELECT COUNT(*) FROM #LeadershipDirectory) AS LeadershipDirectoryRows,
    N'None; application, import, scheduler, and administrative write entry points remained stopped throughout the controlled rehearsal.'
        AS WritesLostOrReplayed,
    N'PASS' AS RecoveryVerifyStatus;

SELECT
    N'phase2_recovery_verify_digest' AS EvidenceSection,
    LogicalName,
    [RowCount],
    CONVERT(char(64), Digest, 2) AS NormalizedDigestSha256
FROM @Digests
ORDER BY LogicalName;

SELECT
    N'phase2_recovery_verify_permission' AS EvidenceSection,
    ObjectName,
    PrincipalName,
    StateCode,
    PermissionName,
    ColumnId
FROM @ActualPermissions
ORDER BY ObjectName, PrincipalName, PermissionName, ColumnId;
