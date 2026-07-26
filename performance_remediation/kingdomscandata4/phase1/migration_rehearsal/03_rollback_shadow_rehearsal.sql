/*
Purpose:
    Timed Phase 1 rollback rehearsal for the selected shadow-copy method.

Safety:
    - Refuses production and every database except the dedicated benchmark copy.
    - Requires a completed matching forward rehearsal.
    - Requires the application/import stopped, no conflicting user sessions,
      and no data drift since forward cutover. Sleeping, zero-transaction SSMS
      IntelliSense metadata sessions are non-conflicting and ignored.
    - Restores the retained original tables through a transactional metadata
      swap and module refresh. It never uses a database snapshot.

This is the production-usable early rollback path: verification must finish
before application/import restart. A rollback after new writes requires the
separate backup/restore recovery branch in the final runbook.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;

DECLARE @ScriptRevision varchar(20) = '20260725.2';
DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK';
DECLARE @ExpectedKs4Rows bigint = 394506;
DECLARE @ExpectedKs5Rows bigint = 394526;
DECLARE @ExpectedMaxScan int = 1020;
DECLARE @RunId uniqueidentifier;
DECLARE @OverallStartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @OverallFinishedAtUtc datetime2(7);
DECLARE @StepStartedAtUtc datetime2(7);
DECLARE @StepFinishedAtUtc datetime2(7);

IF DB_NAME() <> @ExpectedDatabase OR DB_NAME() = N'ROK_TRACKER'
    THROW 51460,
        'Safety stop: connect to the exact benchmark database, never production.',
        1;

IF @@TRANCOUNT <> 0
    THROW 51461, 'Run the rollback rehearsal with no existing transaction.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE source_database_id = DB_ID()
       OR database_id = DB_ID() AND source_database_id IS NOT NULL
)
    THROW 51462, 'A database snapshot is associated with the benchmark target.', 1;

IF OBJECT_ID(N'dbo.KS4_Phase1_MigrationRehearsalState', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KS4_Phase1_MigrationRehearsalReceipt', N'U') IS NULL
    THROW 51463, 'Forward rehearsal state/receipt tables are absent.', 1;

IF (SELECT COUNT(*) FROM dbo.KS4_Phase1_MigrationRehearsalState
    WHERE ForwardComplete = 1 AND RollbackComplete = 0) <> 1
    THROW 51464, 'Exactly one completed, unrolled-back forward run is required.', 1;

SELECT @RunId = RunId
FROM dbo.KS4_Phase1_MigrationRehearsalState
WHERE ForwardComplete = 1
  AND RollbackComplete = 0;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NULL
    THROW 51465, 'Canonical or retained rollback table is absent.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Failed', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Failed', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Failed', N'U') IS NOT NULL
    THROW 51466, 'A prior failed-forward artifact exists.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.dm_exec_sessions AS session
    LEFT JOIN sys.dm_exec_requests AS request
      ON request.session_id = session.session_id
    WHERE session.is_user_process = 1
      AND session.session_id <> @@SPID
      AND COALESCE(request.database_id, session.database_id) = DB_ID()
      AND NOT
      (
          request.session_id IS NULL
          AND session.status = N'sleeping'
          AND session.open_transaction_count = 0
          AND session.program_name =
              N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
      )
)
    THROW 51467,
        'A conflicting user session is connected; stop the application/import and retry.',
        1;

IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @ExpectedKs4Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @ExpectedKs5Rows
   OR EXISTS (SELECT 1 FROM dbo.IMPORT_STAGING)
   OR (SELECT MAX(TRY_CONVERT(int, SCANORDER))
       FROM dbo.KingdomScanData4) <> @ExpectedMaxScan
   OR (SELECT MAX(TRY_CONVERT(int, SCANORDER))
       FROM dbo.KingdomScanData5) <> @ExpectedMaxScan
    THROW 51468,
        'Post-forward data drift detected; early metadata-swap rollback is unsafe.',
        1;

DECLARE
    @StartDataFileSizeMb decimal(19, 2),
    @StartDataFreeInsideMb decimal(19, 2),
    @StartLogSizeMb decimal(19, 2),
    @StartUsedLogMb decimal(19, 2),
    @StartTempdbAllocatedMb decimal(19, 2),
    @StartVolumeFreeMb decimal(19, 2);

SELECT
    @StartDataFileSizeMb = SUM(CASE WHEN type = 0 THEN size END) * 8.0 / 1024.0,
    @StartDataFreeInsideMb =
        SUM(CASE WHEN type = 0
                 THEN size - FILEPROPERTY(name, 'SpaceUsed') END) * 8.0 / 1024.0,
    @StartLogSizeMb = SUM(CASE WHEN type = 1 THEN size END) * 8.0 / 1024.0
FROM sys.database_files;

SELECT @StartUsedLogMb = used_log_space_in_bytes / 1048576.0
FROM sys.dm_db_log_space_usage;

SELECT @StartTempdbAllocatedMb =
    SUM(allocated_extent_page_count) * 8.0 / 1024.0
FROM tempdb.sys.dm_db_file_space_usage;

SELECT TOP (1) @StartVolumeFreeMb = volume.available_bytes / 1048576.0
FROM sys.database_files AS file_info
CROSS APPLY sys.dm_os_volume_stats(DB_ID(), file_info.file_id) AS volume
WHERE file_info.type = 0;

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
    RowCount bigint NOT NULL,
    Digest varbinary(32) NOT NULL,
    PRIMARY KEY (LogicalName, DigestKind)
);

INSERT @DigestWork
VALUES
    (N'KS4', N'KingdomScanData4', 'CURRENT'),
    (N'KS5', N'KingdomScanData5', 'CURRENT'),
    (N'STAGING', N'IMPORT_STAGING', 'CURRENT'),
    (N'KS4', N'KingdomScanData4_Phase2_Old', 'RETAINED'),
    (N'KS5', N'KingdomScanData5_Phase2_Old', 'RETAINED'),
    (N'STAGING', N'IMPORT_STAGING_Phase2_Old', 'RETAINED');

DECLARE
    @LogicalName sysname,
    @PhysicalName sysname,
    @DigestKind varchar(10),
    @Projection nvarchar(max),
    @CanonicalRows nvarchar(max),
    @Digest varbinary(32),
    @DigestRows bigint,
    @Sql nvarchar(max);

SET @StepStartedAtUtc = SYSUTCDATETIME();

DECLARE digest_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT LogicalName, PhysicalName, DigestKind
FROM @DigestWork
ORDER BY DigestKind, LogicalName;

OPEN digest_cursor;
FETCH NEXT FROM digest_cursor
INTO @LogicalName, @PhysicalName, @DigestKind;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @Projection =
        STRING_AGG(
            CONVERT(nvarchar(max),
                CASE
                    WHEN bigint_map.ColumnName IS NOT NULL
                        THEN N'CONVERT(bigint, source.'
                             + QUOTENAME(column_info.name) + N') AS '
                             + QUOTENAME(column_info.name)
                    WHEN int_map.ColumnName IS NOT NULL
                        THEN N'CONVERT(int, source.'
                             + QUOTENAME(column_info.name) + N') AS '
                             + QUOTENAME(column_info.name)
                    WHEN string_map.ColumnName IS NOT NULL
                        THEN N'CONVERT(nvarchar('
                             + CONVERT(nvarchar(10), string_map.TargetLength)
                             + N'), '
                             + CASE WHEN string_map.TrimRight = 1
                                    THEN N'RTRIM(source.'
                                         + QUOTENAME(column_info.name) + N')'
                                    ELSE N'source.' + QUOTENAME(column_info.name)
                               END
                             + N') COLLATE Latin1_General_CI_AS AS '
                             + QUOTENAME(column_info.name)
                    WHEN @LogicalName = N'KS4'
                         AND column_info.name = N'AsOfDate'
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

    INSERT @Digests (LogicalName, DigestKind, RowCount, Digest)
    VALUES (@LogicalName, @DigestKind, @DigestRows, @Digest);

    FETCH NEXT FROM digest_cursor
    INTO @LogicalName, @PhysicalName, @DigestKind;
END;

CLOSE digest_cursor;
DEALLOCATE digest_cursor;

IF EXISTS
(
    SELECT 1
    FROM @Digests AS observed
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN observed.LogicalName = N'KS4'
                     AND observed.DigestKind = 'CURRENT'
                    THEN state_row.ForwardKs4Digest
                WHEN observed.LogicalName = N'KS5'
                     AND observed.DigestKind = 'CURRENT'
                    THEN state_row.ForwardKs5Digest
                WHEN observed.LogicalName = N'STAGING'
                     AND observed.DigestKind = 'CURRENT'
                    THEN state_row.ForwardStagingDigest
                WHEN observed.LogicalName = N'KS4'
                    THEN state_row.BaselineKs4Digest
                WHEN observed.LogicalName = N'KS5'
                    THEN state_row.BaselineKs5Digest
                ELSE state_row.BaselineStagingDigest
            END AS ExpectedDigest,
            CASE observed.LogicalName
                WHEN N'KS4' THEN state_row.BaselineKs4Rows
                WHEN N'KS5' THEN state_row.BaselineKs5Rows
                ELSE state_row.BaselineStagingRows
            END AS ExpectedRows
        FROM dbo.KS4_Phase1_MigrationRehearsalState AS state_row
        WHERE state_row.RunId = @RunId
    ) AS expected
    WHERE observed.Digest <> expected.ExpectedDigest
       OR observed.RowCount <> expected.ExpectedRows
)
    THROW 51469,
        'Current or retained row count/digest drift makes metadata rollback unsafe.',
        1;

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'ROLLBACK', N'pre_rollback_normalized_digests',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     (@ExpectedKs4Rows + @ExpectedKs5Rows) * 2,
     N'Current matches forward; retained originals match baseline.');

DECLARE @Modules table
(
    SchemaName sysname NOT NULL,
    ObjectName sysname NOT NULL,
    ObjectType char(2) NOT NULL,
    PRIMARY KEY (SchemaName, ObjectName)
);

INSERT @Modules (SchemaName, ObjectName, ObjectType)
SELECT DISTINCT
    OBJECT_SCHEMA_NAME(module.object_id),
    OBJECT_NAME(module.object_id),
    module.type
FROM sys.objects AS module
JOIN sys.sql_modules AS sql_module
  ON sql_module.object_id = module.object_id
LEFT JOIN sys.sql_expression_dependencies AS dependency
  ON dependency.referencing_id = module.object_id
WHERE module.type IN ('P', 'V', 'FN', 'IF', 'TF', 'TR')
  AND
  (
      dependency.referenced_id IN
      (
          OBJECT_ID(N'dbo.KingdomScanData4'),
          OBJECT_ID(N'dbo.KingdomScanData5'),
          OBJECT_ID(N'dbo.IMPORT_STAGING')
      )
      OR sql_module.definition LIKE N'%KingdomScanData4%'
      OR sql_module.definition LIKE N'%KingdomScanData5%'
      OR sql_module.definition LIKE N'%IMPORT_STAGING%'
  );

SET @StepStartedAtUtc = SYSUTCDATETIME();
BEGIN TRANSACTION;

DECLARE @ApplicationLockResult int;
EXEC @ApplicationLockResult = sys.sp_getapplock
    @Resource = N'K98:KingdomScanData4:Migration',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 0,
    @DbPrincipal = N'public';

IF @ApplicationLockResult < 0
    THROW 51470, 'Could not acquire the migration application lock.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.dm_exec_sessions AS session
    LEFT JOIN sys.dm_exec_requests AS request
      ON request.session_id = session.session_id
    WHERE session.is_user_process = 1
      AND session.session_id <> @@SPID
      AND COALESCE(request.database_id, session.database_id) = DB_ID()
      AND NOT
      (
          request.session_id IS NULL
          AND session.status = N'sleeping'
          AND session.open_transaction_count = 0
          AND session.program_name =
              N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
      )
)
    THROW 51471, 'A conflicting user session connected before rollback cutover.', 1;

EXEC sys.sp_rename
    N'dbo.IMPORT_STAGING', N'IMPORT_STAGING_Phase2_Failed', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.IMPORT_STAGING_Phase2_Old', N'IMPORT_STAGING', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.KingdomScanData5', N'KingdomScanData5_Phase2_Failed', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.KingdomScanData5_Phase2_Old', N'KingdomScanData5', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.KingdomScanData4', N'KingdomScanData4_Phase2_Failed', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.KingdomScanData4_Phase2_Old', N'KingdomScanData4', N'OBJECT';

DECLARE
    @ModuleSchema sysname,
    @ModuleName sysname,
    @ModuleType char(2),
    @QualifiedModule nvarchar(517);

DECLARE module_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT SchemaName, ObjectName, ObjectType
FROM @Modules
ORDER BY CASE WHEN ObjectType = 'V' THEN 1 ELSE 2 END,
         SchemaName, ObjectName;

OPEN module_cursor;
FETCH NEXT FROM module_cursor
INTO @ModuleSchema, @ModuleName, @ModuleType;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @QualifiedModule =
        QUOTENAME(@ModuleSchema) + N'.' + QUOTENAME(@ModuleName);
    IF @ModuleType = 'V'
        EXEC sys.sp_refreshview @QualifiedModule;
    ELSE
        EXEC sys.sp_refreshsqlmodule @QualifiedModule;

    FETCH NEXT FROM module_cursor
    INTO @ModuleSchema, @ModuleName, @ModuleType;
END;

CLOSE module_cursor;
DEALLOCATE module_cursor;

IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @ExpectedKs4Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @ExpectedKs5Rows
   OR EXISTS (SELECT 1 FROM dbo.IMPORT_STAGING)
    THROW 51472, 'Canonical row counts changed during rollback cutover.', 1;

UPDATE dbo.KS4_Phase1_MigrationRehearsalState
SET RollbackComplete = 1,
    RollbackCompletedAtUtc = SYSUTCDATETIME()
WHERE RunId = @RunId;

COMMIT TRANSACTION;
SET @StepFinishedAtUtc = SYSUTCDATETIME();

INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'ROLLBACK', N'transactional_metadata_swap_and_module_refresh',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     (SELECT COUNT(*) FROM @Modules),
     N'Retained original tables restored; views refreshed before other modules.');

SET @StepStartedAtUtc = SYSUTCDATETIME();

DBCC CHECKTABLE (N'dbo.KingdomScanData4') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.KingdomScanData5') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.IMPORT_STAGING') WITH NO_INFOMSGS;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS column_info
    JOIN sys.types AS type_info
      ON type_info.user_type_id = column_info.user_type_id
    WHERE column_info.object_id = OBJECT_ID(N'dbo.KingdomScanData4')
      AND column_info.name = N'GovernorID'
      AND type_info.name = N'float'
      AND column_info.is_nullable = 0
)
   OR (SELECT COUNT(*) FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
         AND index_id > 0) <> 10
   OR NOT EXISTS
(
    SELECT 1
    FROM sys.computed_columns
    WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
      AND name = N'AsOfDate'
      AND is_persisted = 1
)
   OR NOT EXISTS
(
    SELECT 1
    FROM sys.database_permissions AS permission
    JOIN sys.database_principals AS principal
      ON principal.principal_id = permission.grantee_principal_id
    WHERE permission.major_id = OBJECT_ID(N'dbo.KingdomScanData4')
      AND principal.name = N'ImportProcUser'
      AND permission.permission_name = N'SELECT'
      AND permission.state = N'G'
)
    THROW 51473,
        'Post-rollback original schema, index, computed, or permission check failed.',
        1;

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'ROLLBACK', N'post_rollback_checktable_and_schema',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     @ExpectedKs4Rows + @ExpectedKs5Rows,
     N'DBCC CHECKTABLE and original float/nchar schema checks passed.');

SET @OverallFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'ROLLBACK', N'total_rollback_outage',
     @OverallStartedAtUtc, @OverallFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @OverallStartedAtUtc, @OverallFinishedAtUtc) / 1000.0,
     @ExpectedKs4Rows + @ExpectedKs5Rows,
     N'Application/import must remain stopped for this complete interval.');

DECLARE
    @EndDataFileSizeMb decimal(19, 2),
    @EndDataFreeInsideMb decimal(19, 2),
    @EndLogSizeMb decimal(19, 2),
    @EndUsedLogMb decimal(19, 2),
    @EndTempdbAllocatedMb decimal(19, 2),
    @EndVolumeFreeMb decimal(19, 2);

SELECT
    @EndDataFileSizeMb = SUM(CASE WHEN type = 0 THEN size END) * 8.0 / 1024.0,
    @EndDataFreeInsideMb =
        SUM(CASE WHEN type = 0
                 THEN size - FILEPROPERTY(name, 'SpaceUsed') END) * 8.0 / 1024.0,
    @EndLogSizeMb = SUM(CASE WHEN type = 1 THEN size END) * 8.0 / 1024.0
FROM sys.database_files;

SELECT @EndUsedLogMb = used_log_space_in_bytes / 1048576.0
FROM sys.dm_db_log_space_usage;

SELECT @EndTempdbAllocatedMb =
    SUM(allocated_extent_page_count) * 8.0 / 1024.0
FROM tempdb.sys.dm_db_file_space_usage;

SELECT TOP (1) @EndVolumeFreeMb = volume.available_bytes / 1048576.0
FROM sys.database_files AS file_info
CROSS APPLY sys.dm_os_volume_stats(DB_ID(), file_info.file_id) AS volume
WHERE file_info.type = 0;

SELECT
    N'migration_rollback_summary' AS EvidenceSection,
    @ScriptRevision AS ScriptRevision,
    @RunId AS RunId,
    DB_NAME() AS DatabaseName,
    @OverallStartedAtUtc AS StartedAtUtc,
    @OverallFinishedAtUtc AS FinishedAtUtc,
    DATEDIFF_BIG(microsecond, @OverallStartedAtUtc, @OverallFinishedAtUtc)
        / 1000.0 AS TotalOutageMs,
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
    @ExpectedKs4Rows AS Ks4Rows,
    @ExpectedKs5Rows AS Ks5Rows,
    N'PASS' AS RollbackStatus;

SELECT
    N'migration_rollback_digest' AS EvidenceSection,
    LogicalName,
    DigestKind,
    RowCount,
    CONVERT(char(64), Digest, 2) AS NormalizedDigestSha256
FROM @Digests
ORDER BY LogicalName, DigestKind;

SELECT
    N'migration_rollback_step' AS EvidenceSection,
    Direction,
    StepName,
    StartedAtUtc,
    FinishedAtUtc,
    DurationMs,
    RowsAffected,
    Notes
FROM dbo.KS4_Phase1_MigrationRehearsalReceipt
WHERE RunId = @RunId
  AND Direction = 'ROLLBACK'
ORDER BY ReceiptId;

SELECT
    N'migration_rollback_failed_forward_retained' AS EvidenceSection,
    schema_info.name AS SchemaName,
    object_info.name AS ObjectName,
    object_info.type_desc AS ObjectType
FROM sys.objects AS object_info
JOIN sys.schemas AS schema_info
  ON schema_info.schema_id = object_info.schema_id
WHERE object_info.name IN
(
    N'KingdomScanData4_Phase2_Failed',
    N'KingdomScanData5_Phase2_Failed',
    N'IMPORT_STAGING_Phase2_Failed'
)
ORDER BY object_info.name;
