/*
Purpose:
    Pre-restart verification for the Phase 2 shadow migration.

Safety:
    - Refuses production only when the forward receipt did not record production approval.
    - Requires the application/import/admin entry points to remain stopped.
    - Does not drop or rename tables.
    - Marks the run verified only after exact digest, schema, index, statistic,
      permission, module, DBCC, and critical read-smoke checks pass.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;

DECLARE @ScriptRevision varchar(20) = '20260725.1';
DECLARE @RunId uniqueidentifier;
DECLARE @ProductionApproved bit;
DECLARE @ExpectedKs4Rows bigint;
DECLARE @ExpectedKs5Rows bigint;
DECLARE @ExpectedStagingRows bigint;
DECLARE @ExpectedKs4MaxScan int;
DECLARE @ExpectedKs5MaxScan int;
DECLARE @ForwardKs4Digest varbinary(32);
DECLARE @ForwardKs5Digest varbinary(32);
DECLARE @ForwardStagingDigest varbinary(32);
DECLARE @MigrationStartedAtUtc datetime2(7);
DECLARE @StartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @StepStartedAtUtc datetime2(7);
DECLARE @StepFinishedAtUtc datetime2(7);
DECLARE @Sql nvarchar(max);

IF OBJECT_ID(N'dbo.KS4_Phase2_PreflightState', N'U') IS NULL
    THROW 51580, 'Phase 2 migration state is absent.', 1;

SELECT TOP (1)
    @RunId = RunId,
    @ProductionApproved = ProductionApproved,
    @ExpectedKs4Rows = Ks4Rows,
    @ExpectedKs5Rows = Ks5Rows,
    @ExpectedStagingRows = StagingRows,
    @ExpectedKs4MaxScan = Ks4MaxScan,
    @ExpectedKs5MaxScan = Ks5MaxScan,
    @ForwardKs4Digest = ForwardKs4Digest,
    @ForwardKs5Digest = ForwardKs5Digest,
    @ForwardStagingDigest = ForwardStagingDigest,
    @MigrationStartedAtUtc = MigrationStartedAtUtc
FROM dbo.KS4_Phase2_PreflightState
WHERE DatabaseName = DB_NAME()
  AND ServerName = @@SERVERNAME
  AND Status IN ('FORWARD_PASS', 'VERIFIED')
  AND MigrationCompletedAtUtc IS NOT NULL
  AND RollbackCompletedAtUtc IS NULL
  AND FinalizedAtUtc IS NULL
ORDER BY MigrationCompletedAtUtc DESC;

IF @RunId IS NULL
    THROW 51581, 'No eligible forward PASS receipt exists for this database.', 1;

IF DB_NAME() = N'ROK_TRACKER' AND @ProductionApproved <> 1
    THROW 51582, 'The run did not record separate production approval.', 1;

IF @@TRANCOUNT <> 0
    THROW 51583, 'Run verification with no existing user transaction.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NULL
    THROW 51584, 'Canonical or retained rollback tables are incomplete.', 1;

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
    THROW 51585, 'Conflicting user sessions are connected; keep all entry points stopped.', 1;

DECLARE @ExpectedFinalTypes table
(
    ObjectName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    TypeName sysname NOT NULL,
    MaxLength smallint NOT NULL,
    IsNullable bit NOT NULL,
    PRIMARY KEY (ObjectName, ColumnName)
);

INSERT @ExpectedFinalTypes
    (ObjectName, ColumnName, TypeName, MaxLength, IsNullable)
VALUES
    (N'KingdomScanData4', N'PowerRank', N'int', 4, 0),
    (N'KingdomScanData4', N'GovernorName', N'nvarchar', 400, 1),
    (N'KingdomScanData4', N'GovernorID', N'bigint', 8, 0),
    (N'KingdomScanData4', N'Alliance', N'nvarchar', 200, 1),
    (N'KingdomScanData4', N'Power', N'bigint', 8, 0),
    (N'KingdomScanData4', N'KillPoints', N'bigint', 8, 0),
    (N'KingdomScanData4', N'Deads', N'bigint', 8, 0),
    (N'KingdomScanData4', N'T1_Kills', N'bigint', 8, 0),
    (N'KingdomScanData4', N'T2_Kills', N'bigint', 8, 0),
    (N'KingdomScanData4', N'T3_Kills', N'bigint', 8, 0),
    (N'KingdomScanData4', N'T4_Kills', N'bigint', 8, 0),
    (N'KingdomScanData4', N'T5_Kills', N'bigint', 8, 0),
    (N'KingdomScanData4', N'T4&T5_KILLS', N'bigint', 8, 1),
    (N'KingdomScanData4', N'TOTAL_KILLS', N'bigint', 8, 1),
    (N'KingdomScanData4', N'RSS_Gathered', N'bigint', 8, 1),
    (N'KingdomScanData4', N'RSSAssistance', N'bigint', 8, 0),
    (N'KingdomScanData4', N'Helps', N'bigint', 8, 0),
    (N'KingdomScanData4', N'SCANORDER', N'int', 4, 0),
    (N'KingdomScanData5', N'PowerRank', N'int', 4, 0),
    (N'KingdomScanData5', N'GovernorName', N'nvarchar', 400, 1),
    (N'KingdomScanData5', N'GovernorID', N'bigint', 8, 0),
    (N'KingdomScanData5', N'Alliance', N'nvarchar', 200, 1),
    (N'KingdomScanData5', N'Power', N'bigint', 8, 0),
    (N'KingdomScanData5', N'KillPoints', N'bigint', 8, 0),
    (N'KingdomScanData5', N'Deads', N'bigint', 8, 0),
    (N'KingdomScanData5', N'T1_Kills', N'bigint', 8, 0),
    (N'KingdomScanData5', N'T2_Kills', N'bigint', 8, 0),
    (N'KingdomScanData5', N'T3_Kills', N'bigint', 8, 0),
    (N'KingdomScanData5', N'T4_Kills', N'bigint', 8, 0),
    (N'KingdomScanData5', N'T5_Kills', N'bigint', 8, 0),
    (N'KingdomScanData5', N'T4&T5_KILLS', N'bigint', 8, 1),
    (N'KingdomScanData5', N'TOTAL_KILLS', N'bigint', 8, 1),
    (N'KingdomScanData5', N'RSS_Gathered', N'bigint', 8, 1),
    (N'KingdomScanData5', N'RSSAssistance', N'bigint', 8, 0),
    (N'KingdomScanData5', N'Helps', N'bigint', 8, 0),
    (N'KingdomScanData5', N'SCANORDER', N'int', 4, 1),
    (N'IMPORT_STAGING', N'Name', N'nvarchar', 400, 1),
    (N'IMPORT_STAGING', N'Governor ID', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'Alliance', N'nvarchar', 200, 1),
    (N'IMPORT_STAGING', N'Power', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'Total Kill Points', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'Dead Troops', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'T1-Kills', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'T2-Kills', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'T3-Kills', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'T4-Kills', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'T5-Kills', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'Kills (T4+)', N'bigint', 8, 1),
    (N'IMPORT_STAGING', N'KILLS', N'bigint', 8, 1),
    (N'IMPORT_STAGING', N'RSS Gathered', N'bigint', 8, 1),
    (N'IMPORT_STAGING', N'RSS Assistance', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'Alliance Helps', N'bigint', 8, 0),
    (N'IMPORT_STAGING', N'SCANORDER', N'int', 4, 1),
    (N'IMPORT_STAGING', N'Updated_on', N'nvarchar', 400, 1);

IF EXISTS
(
    SELECT 1
    FROM @ExpectedFinalTypes AS expected
    LEFT JOIN sys.columns AS column_info
      ON column_info.object_id = OBJECT_ID(N'dbo.' + expected.ObjectName)
     AND column_info.name COLLATE DATABASE_DEFAULT =
         expected.ColumnName COLLATE DATABASE_DEFAULT
    LEFT JOIN sys.types AS type_info
      ON type_info.user_type_id = column_info.user_type_id
    WHERE column_info.column_id IS NULL
       OR type_info.name COLLATE DATABASE_DEFAULT <>
          expected.TypeName COLLATE DATABASE_DEFAULT
       OR column_info.max_length <> expected.MaxLength
       OR column_info.is_nullable <> expected.IsNullable
)
    THROW 51586, 'Final type or nullability assertion failed.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.computed_columns
    WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
      AND name COLLATE DATABASE_DEFAULT = N'AsOfDate' COLLATE DATABASE_DEFAULT
      AND is_persisted = 1
      AND definition COLLATE DATABASE_DEFAULT =
          N'(CONVERT([date],[ScanDate]))' COLLATE DATABASE_DEFAULT
)
   OR COLUMNPROPERTY(OBJECT_ID(N'dbo.KingdomScanData5'), N'SCAN_UNO', 'IsIdentity') <> 1
   OR NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.KingdomScanData4')
      AND definition COLLATE DATABASE_DEFAULT =
          N'(NEXT VALUE FOR [dbo].[KS4_UNO_SEQ])' COLLATE DATABASE_DEFAULT
)
    THROW 51587, 'Computed, identity, or sequence-default assertion failed.', 1;

DECLARE @ExpectedOrder table
(
    ObjectName sysname NOT NULL PRIMARY KEY,
    ColumnOrder nvarchar(max) NOT NULL
);
INSERT @ExpectedOrder (ObjectName, ColumnOrder)
SELECT ObjectName,
       STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(ColumnName)), N'|')
           WITHIN GROUP (ORDER BY ColumnId)
FROM dbo.KS4_Phase2_ColumnInventory
WHERE RunId = @RunId
GROUP BY ObjectName;

IF EXISTS
(
    SELECT 1
    FROM @ExpectedOrder AS expected
    CROSS APPLY
    (
        SELECT STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(column_info.name)), N'|')
            WITHIN GROUP (ORDER BY column_info.column_id) AS ActualOrder
        FROM sys.columns AS column_info
        WHERE column_info.object_id = OBJECT_ID(N'dbo.' + expected.ObjectName)
    ) AS actual
    WHERE actual.ActualOrder COLLATE DATABASE_DEFAULT <>
          expected.ColumnOrder COLLATE DATABASE_DEFAULT
)
    THROW 51588, 'Final column order differs from the captured source order.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @ExpectedKs4Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @ExpectedKs5Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.IMPORT_STAGING) <> @ExpectedStagingRows
   OR (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4) <> @ExpectedKs4MaxScan
   OR (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData5) <> @ExpectedKs5MaxScan
    THROW 51589, 'Final rows or scan range differs from preflight.', 1;

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
(
    ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
    IsDisabled, HasFilter, FilterDefinition, KeyColumns, IncludeColumns
)
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
           ISNULL(KeyColumns, N''), ISNULL(IncludeColumns, N'')
    FROM dbo.KS4_Phase2_IndexInventory
    WHERE RunId = @RunId
    EXCEPT
    SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
           IsDisabled, HasFilter, ISNULL(FilterDefinition, N''),
           ISNULL(KeyColumns, N''), ISNULL(IncludeColumns, N'')
    FROM @ActualIndexes
)
   OR EXISTS
(
    SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
           IsDisabled, HasFilter, ISNULL(FilterDefinition, N''),
           ISNULL(KeyColumns, N''), ISNULL(IncludeColumns, N'')
    FROM @ActualIndexes
    EXCEPT
    SELECT ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
           IsDisabled, HasFilter, ISNULL(FilterDefinition, N''),
           ISNULL(KeyColumns, N''), ISNULL(IncludeColumns, N'')
    FROM dbo.KS4_Phase2_IndexInventory
    WHERE RunId = @RunId
)
    THROW 51590, 'Final index metadata differs from the exact captured three-table contract.', 1;

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
          OR actual.user_created <> 1
          OR actual.no_recompute <> expected.NoRecompute
          OR actual.has_filter <> expected.HasFilter
          OR ISNULL(actual.filter_definition, N'') COLLATE DATABASE_DEFAULT <>
              ISNULL(expected.FilterDefinition, N'') COLLATE DATABASE_DEFAULT
          OR actual_columns.ColumnList COLLATE DATABASE_DEFAULT <>
             expected.StatisticColumns COLLATE DATABASE_DEFAULT
      )
)
    THROW 51592, 'Standalone statistic preservation assertion failed.', 1;

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
    THROW 51591, 'Final explicit permission inventory differs from the captured contract.', 1;

IF (SELECT COUNT(*) FROM @ActualPermissions) <> 1
   OR NOT EXISTS
(
    SELECT 1
    FROM @ActualPermissions
    WHERE ObjectName = N'KingdomScanData4'
      AND ColumnId = 0
      AND StateCode = 'G'
      AND PermissionName = N'SELECT'
      AND PrincipalName = N'ImportProcUser'
)
    THROW 51593, 'Final explicit permission contract is not the approved one-grant shape.', 1;

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
    (N'KS4', N'KingdomScanData4', @ForwardKs4Digest),
    (N'KS5', N'KingdomScanData5', @ForwardKs5Digest),
    (N'STAGING', N'IMPORT_STAGING', @ForwardStagingDigest);

DECLARE
    @LogicalName sysname,
    @PhysicalName sysname,
    @ExpectedDigest varbinary(32),
    @Projection nvarchar(max),
    @CanonicalRows nvarchar(max),
    @Digest varbinary(32),
    @DigestRows bigint;

SET @StepStartedAtUtc = SYSUTCDATETIME();

DECLARE digest_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT LogicalName, PhysicalName, ExpectedDigest
FROM @DigestWork ORDER BY LogicalName;

OPEN digest_cursor;
FETCH NEXT FROM digest_cursor
INTO @LogicalName, @PhysicalName, @ExpectedDigest;

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
        THROW 51594, 'A final normalized SHA-256 digest differs from the forward receipt.', 1;

    INSERT @Digests VALUES (@LogicalName, @DigestRows, @Digest);

    FETCH NEXT FROM digest_cursor
    INTO @LogicalName, @PhysicalName, @ExpectedDigest;
END;

CLOSE digest_cursor;
DEALLOCATE digest_cursor;

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase2_MigrationReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'VERIFY', N'canonical_normalized_digests',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     @ExpectedKs4Rows + @ExpectedKs5Rows + @ExpectedStagingRows,
     N'All canonical rows and normalized SHA-256 digests match the forward receipt.');

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
      )
)
    THROW 51595, 'A module definition changed or failed refresh verification.', 1;

SET @StepStartedAtUtc = SYSUTCDATETIME();
DBCC CHECKTABLE (N'dbo.KingdomScanData4') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.KingdomScanData5') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.IMPORT_STAGING') WITH NO_INFOMSGS;
SET @StepFinishedAtUtc = SYSUTCDATETIME();

INSERT dbo.KS4_Phase2_MigrationReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'VERIFY', N'dbcc_checktable',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     @ExpectedKs4Rows + @ExpectedKs5Rows + @ExpectedStagingRows,
     N'DBCC CHECKTABLE passed for all three canonical tables.');

DECLARE
    @LatestStatsRows bigint,
    @DailyExportRows bigint,
    @GlobalLatestRows bigint;

SELECT @LatestStatsRows = COUNT_BIG(*) FROM dbo.v_PlayerLatestStats;
SELECT @DailyExportRows = COUNT_BIG(*) FROM dbo.vDaily_PlayerExport;
SELECT @GlobalLatestRows = COUNT_BIG(*) FROM dbo.vw_Governor_KVK_Summary_GlobalLatest;

IF @ExpectedKs4Rows = 394506
   AND (@LatestStatsRows <> 2371
        OR @DailyExportRows <> 223386
        OR @GlobalLatestRows <> 411)
    THROW 51596, 'Representative critical read-smoke row counts changed.', 1;

UPDATE dbo.KS4_Phase2_PreflightState
SET VerifiedAtUtc = SYSUTCDATETIME(),
    Status = 'VERIFIED'
WHERE RunId = @RunId;

SELECT
    N'phase2_verify_completion' AS EvidenceSection,
    @ScriptRevision AS ScriptRevision,
    @RunId AS RunId,
    DB_NAME() AS DatabaseName,
    @StartedAtUtc AS StartedAtUtc,
    SYSUTCDATETIME() AS CompletedAtUtc,
    @ExpectedKs4Rows AS Ks4Rows,
    @ExpectedKs5Rows AS Ks5Rows,
    @ExpectedStagingRows AS StagingRows,
    @LatestStatsRows AS LatestStatsRows,
    @DailyExportRows AS DailyExportRows,
    @GlobalLatestRows AS GlobalLatestRows,
    N'PASS' AS VerifyStatus;

SELECT
    N'phase2_verify_digest' AS EvidenceSection,
    LogicalName,
    [RowCount],
    CONVERT(char(64), Digest, 2) AS NormalizedDigestSha256
FROM @Digests
ORDER BY LogicalName;

SELECT
    N'phase2_verify_query_store_error' AS EvidenceSection,
    query_info.query_id,
    plan_info.plan_id,
    runtime_stats.execution_type_desc,
    runtime_stats.count_executions,
    runtime_stats.last_execution_time
FROM sys.query_store_runtime_stats AS runtime_stats
JOIN sys.query_store_plan AS plan_info
  ON plan_info.plan_id = runtime_stats.plan_id
JOIN sys.query_store_query AS query_info
  ON query_info.query_id = plan_info.query_id
WHERE runtime_stats.last_execution_time >= @MigrationStartedAtUtc
  AND runtime_stats.execution_type <> 0
ORDER BY runtime_stats.last_execution_time;

SELECT
    N'phase2_verify_resources' AS EvidenceSection,
    CONVERT(decimal(19, 2), log_usage.total_log_size_in_bytes / 1048576.0)
        AS TotalLogMb,
    CONVERT(decimal(19, 2), log_usage.used_log_space_in_bytes / 1048576.0)
        AS UsedLogMb,
    CONVERT(decimal(19, 2),
        (SELECT SUM(allocated_extent_page_count) * 8.0 / 1024.0
         FROM tempdb.sys.dm_db_file_space_usage)) AS TempdbAllocatedMb,
    CONVERT(decimal(19, 2),
        (SELECT SUM(CASE WHEN type = 0
                    THEN size - FILEPROPERTY(name, 'SpaceUsed') ELSE 0 END)
                    * 8.0 / 1024.0
         FROM sys.database_files)) AS DataFreeInsideMb
FROM sys.dm_db_log_space_usage AS log_usage;
