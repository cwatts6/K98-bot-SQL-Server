/*
Purpose:
    Timed Phase 1 forward rehearsal for the selected shadow-copy method.

Safety:
    - Refuses production and every database except the dedicated benchmark copy.
    - Requires the exact fresh seed and the application/import fully stopped.
    - Refuses other user sessions and any prior rehearsal artifacts.
    - Retains all original tables as *_Phase2_Old for metadata-swap rollback.
    - Does not use a database snapshot.

This is test-only Gate 5 evidence, not production-oriented Phase 2 DDL.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;

DECLARE @ScriptRevision varchar(20) = '20260725.1';
DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK';
DECLARE @ExpectedKs4Rows bigint = 394506;
DECLARE @ExpectedKs5Rows bigint = 394526;
DECLARE @ExpectedMaxScan int = 1020;
DECLARE @RunId uniqueidentifier = NEWID();
DECLARE @OverallStartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @StepStartedAtUtc datetime2(7);
DECLARE @StepFinishedAtUtc datetime2(7);
DECLARE @RowsCopied bigint;

IF DB_NAME() <> @ExpectedDatabase OR DB_NAME() = N'ROK_TRACKER'
    THROW 51420,
        'Safety stop: connect to the exact benchmark database, never production.',
        1;

IF @@TRANCOUNT <> 0
    THROW 51421, 'Run the forward rehearsal with no existing transaction.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE source_database_id = DB_ID()
       OR database_id = DB_ID() AND source_database_id IS NOT NULL
)
    THROW 51422, 'A database snapshot is associated with the benchmark target.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING', N'U') IS NULL
    THROW 51423, 'One or more canonical source tables are absent.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KS4_Phase1_MigrationRehearsalState', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KS4_Phase1_MigrationRehearsalReceipt', N'U') IS NOT NULL
    THROW 51424,
        'Prior rehearsal artifacts exist; restore the benchmark seed before running.',
        1;

IF EXISTS
(
    SELECT 1
    FROM sys.dm_exec_sessions AS session
    LEFT JOIN sys.dm_exec_requests AS request
      ON request.session_id = session.session_id
    WHERE session.is_user_process = 1
      AND session.session_id <> @@SPID
      AND COALESCE(request.database_id, session.database_id) = DB_ID()
)
    THROW 51425,
        'Other user sessions are connected; stop the application/import and retry.',
        1;

IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) <> @ExpectedKs4Rows
   OR (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5) <> @ExpectedKs5Rows
   OR (SELECT MAX(TRY_CONVERT(int, SCANORDER))
       FROM dbo.KingdomScanData4) <> @ExpectedMaxScan
   OR (SELECT MAX(TRY_CONVERT(int, SCANORDER))
       FROM dbo.KingdomScanData5) <> @ExpectedMaxScan
   OR EXISTS (SELECT 1 FROM dbo.IMPORT_STAGING)
    THROW 51426, 'Fresh-seed row, scan, or empty-staging drift detected.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_permissions AS permission
    JOIN sys.database_principals AS principal
      ON principal.principal_id = permission.grantee_principal_id
    WHERE permission.class = 1
      AND permission.major_id = OBJECT_ID(N'dbo.KingdomScanData4')
      AND permission.minor_id = 0
      AND principal.name = N'ImportProcUser'
      AND permission.state = N'G'
      AND permission.permission_name = N'SELECT'
)
   OR (SELECT COUNT(*)
       FROM sys.database_permissions
       WHERE class = 1
         AND major_id IN
         (
             OBJECT_ID(N'dbo.KingdomScanData4'),
             OBJECT_ID(N'dbo.KingdomScanData5'),
             OBJECT_ID(N'dbo.IMPORT_STAGING')
         )) <> 1
    THROW 51427, 'Explicit object permissions drifted from the preflight receipt.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.extended_properties
    WHERE class = 1
      AND major_id IN
      (
          OBJECT_ID(N'dbo.KingdomScanData4'),
          OBJECT_ID(N'dbo.KingdomScanData5'),
          OBJECT_ID(N'dbo.IMPORT_STAGING')
      )
)
    THROW 51428, 'Unexpected extended properties require explicit preservation.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.sql_expression_dependencies
    WHERE referenced_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
      AND OBJECTPROPERTYEX(referencing_id, 'IsSchemaBound') = 1
)
    THROW 51429, 'Schema-bound dependency prevents the guarded name swap.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.crypt_properties AS signature
    JOIN sys.sql_expression_dependencies AS dependency
      ON dependency.referencing_id = signature.major_id
    WHERE dependency.referenced_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
)
    THROW 51430, 'A signed dependent module requires explicit signature handling.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE parent_object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
       OR referenced_object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
)
   OR EXISTS
(
    SELECT 1
    FROM sys.triggers
    WHERE parent_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
)
    THROW 51431, 'Unexpected foreign key or trigger blocks this rehearsal branch.', 1;

DECLARE @MinimumVolumeFreeBytes bigint =
    CONVERT(bigint, 20) * 1024 * 1024 * 1024;
IF EXISTS
(
    SELECT 1
    FROM sys.database_files AS file_info
    CROSS APPLY sys.dm_os_volume_stats(DB_ID(), file_info.file_id) AS volume
    WHERE file_info.type = 0
      AND volume.available_bytes < @MinimumVolumeFreeBytes
)
    THROW 51432, 'Less than 20 GB is free on the data volume.', 1;

CREATE TABLE dbo.KS4_Phase1_MigrationRehearsalState
(
    RunId uniqueidentifier NOT NULL
        CONSTRAINT PK_KS4_Phase1_MigrationRehearsalState PRIMARY KEY,
    ScriptRevision varchar(20) NOT NULL,
    StartedAtUtc datetime2(7) NOT NULL,
    ForwardCompletedAtUtc datetime2(7) NULL,
    RollbackCompletedAtUtc datetime2(7) NULL,
    BaselineKs4Rows bigint NOT NULL,
    BaselineKs5Rows bigint NOT NULL,
    BaselineStagingRows bigint NOT NULL,
    BaselineKs4Digest varbinary(32) NULL,
    BaselineKs5Digest varbinary(32) NULL,
    BaselineStagingDigest varbinary(32) NULL,
    ForwardKs4Digest varbinary(32) NULL,
    ForwardKs5Digest varbinary(32) NULL,
    ForwardStagingDigest varbinary(32) NULL,
    ForwardComplete bit NOT NULL
        CONSTRAINT DF_KS4_Phase1_State_ForwardComplete DEFAULT (0),
    RollbackComplete bit NOT NULL
        CONSTRAINT DF_KS4_Phase1_State_RollbackComplete DEFAULT (0)
);

CREATE TABLE dbo.KS4_Phase1_MigrationRehearsalReceipt
(
    ReceiptId bigint IDENTITY(1, 1) NOT NULL
        CONSTRAINT PK_KS4_Phase1_MigrationRehearsalReceipt PRIMARY KEY,
    RunId uniqueidentifier NOT NULL,
    Direction varchar(12) NOT NULL,
    StepName nvarchar(128) NOT NULL,
    StartedAtUtc datetime2(7) NOT NULL,
    FinishedAtUtc datetime2(7) NOT NULL,
    DurationMs decimal(19, 3) NOT NULL,
    RowsAffected bigint NULL,
    Notes nvarchar(1000) NULL
);

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

/*
Preallocate outside the measured outage. The restored copy has only about
50 MB free inside its data file and a 64 MB growth increment. Production
preflight will calculate its own exact target; this test-only rehearsal
reserves 8 GB so copy/index timings are not dominated by dozens of growths.
*/
SET @StepStartedAtUtc = SYSUTCDATETIME();
DECLARE
    @DataLogicalName sysname,
    @CurrentDataSizeMb bigint,
    @CurrentDataFreeMb bigint,
    @TargetDataSizeMb bigint,
    @PreallocationSql nvarchar(max);

SELECT TOP (1)
    @DataLogicalName = name,
    @CurrentDataSizeMb = CONVERT(bigint, CEILING(size * 8.0 / 1024.0)),
    @CurrentDataFreeMb = CONVERT(
        bigint,
        FLOOR((size - FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024.0))
FROM sys.database_files
WHERE type = 0
ORDER BY file_id;

IF @CurrentDataFreeMb < 8192
BEGIN
    SET @TargetDataSizeMb =
        @CurrentDataSizeMb + (8192 - @CurrentDataFreeMb);
    SET @PreallocationSql =
        N'ALTER DATABASE ' + QUOTENAME(DB_NAME())
        + N' MODIFY FILE (NAME = ' + QUOTENAME(@DataLogicalName, '''')
        + N', SIZE = ' + CONVERT(nvarchar(30), @TargetDataSizeMb) + N'MB);';
    EXEC sys.sp_executesql @PreallocationSql;
END;

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'preallocate_data_file_outside_outage',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     NULL, N'Ensures at least 8 GB free inside the benchmark data file.');

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

INSERT @DigestWork (LogicalName, PhysicalName, DigestKind)
VALUES
    (N'KS4', N'KingdomScanData4', 'BASELINE'),
    (N'KS5', N'KingdomScanData5', 'BASELINE'),
    (N'STAGING', N'IMPORT_STAGING', 'BASELINE');

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
WHERE DigestKind = 'BASELINE'
ORDER BY LogicalName;

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
            N','
        ) WITHIN GROUP (ORDER BY column_info.column_id)
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
    WHERE column_info.object_id =
        OBJECT_ID(N'dbo.' + @PhysicalName);

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

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'baseline_normalized_digests',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     @ExpectedKs4Rows + @ExpectedKs5Rows,
     N'SHA-256 over sorted normalized SHA-256 row digests; staging is empty.');

INSERT dbo.KS4_Phase1_MigrationRehearsalState
(
    RunId, ScriptRevision, StartedAtUtc,
    BaselineKs4Rows, BaselineKs5Rows, BaselineStagingRows,
    BaselineKs4Digest, BaselineKs5Digest, BaselineStagingDigest
)
VALUES
(
    @RunId, @ScriptRevision, @OverallStartedAtUtc,
    @ExpectedKs4Rows, @ExpectedKs5Rows, 0,
    (SELECT Digest FROM @Digests
     WHERE LogicalName = N'KS4' AND DigestKind = 'BASELINE'),
    (SELECT Digest FROM @Digests
     WHERE LogicalName = N'KS5' AND DigestKind = 'BASELINE'),
    (SELECT Digest FROM @Digests
     WHERE LogicalName = N'STAGING' AND DigestKind = 'BASELINE')
);

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

ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN PowerRank int NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN GovernorName nvarchar(200) COLLATE Latin1_General_CI_AS NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN GovernorID bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN Alliance nvarchar(100) COLLATE Latin1_General_CI_AS NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN Power bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN KillPoints bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN Deads bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T1_Kills bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T2_Kills bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T3_Kills bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T4_Kills bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN T5_Kills bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN [T4&T5_KILLS] bigint NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN TOTAL_KILLS bigint NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN RSS_Gathered bigint NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New
    ALTER COLUMN RSSAssistance bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN Helps bigint NOT NULL;
ALTER TABLE dbo.KingdomScanData5_Phase2_New ALTER COLUMN SCANORDER int NULL;

SELECT TOP (0) *
INTO dbo.IMPORT_STAGING_Phase2_New
FROM dbo.IMPORT_STAGING;

ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN Name nvarchar(200) COLLATE Latin1_General_CI_AS NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [Governor ID] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN Alliance nvarchar(100) COLLATE Latin1_General_CI_AS NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN Power bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [Total Kill Points] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [Dead Troops] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [T1-Kills] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [T2-Kills] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [T3-Kills] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [T4-Kills] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [T5-Kills] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [Kills (T4+)] bigint NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN KILLS bigint NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [RSS Gathered] bigint NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [RSS Assistance] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN [Alliance Helps] bigint NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New ALTER COLUMN SCANORDER int NULL;
ALTER TABLE dbo.IMPORT_STAGING_Phase2_New
    ALTER COLUMN Updated_on nvarchar(200) COLLATE Latin1_General_CI_AS NULL;

IF COLUMNPROPERTY(
       OBJECT_ID(N'dbo.KingdomScanData5_Phase2_New'),
       N'SCAN_UNO', 'IsIdentity') <> 1
    THROW 51433, 'KingdomScanData5 shadow did not preserve identity semantics.', 1;

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'create_empty_typed_shadows',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     0, N'Column order/nullability retained; AsOfDate remains persisted.');

DECLARE @CopyWork table
(
    LogicalName sysname NOT NULL,
    SourceName sysname NOT NULL,
    TargetName sysname NOT NULL,
    HasIdentity bit NOT NULL,
    StepName nvarchar(128) NOT NULL,
    PRIMARY KEY (LogicalName)
);
INSERT @CopyWork
VALUES
    (N'STAGING', N'IMPORT_STAGING', N'IMPORT_STAGING_Phase2_New',
     0, N'copy_import_staging'),
    (N'KS5', N'KingdomScanData5', N'KingdomScanData5_Phase2_New',
     1, N'copy_kingdomscandata5'),
    (N'KS4', N'KingdomScanData4', N'KingdomScanData4_Phase2_New',
     0, N'copy_kingdomscandata4');

DECLARE
    @SourceName sysname,
    @TargetName sysname,
    @HasIdentity bit,
    @CopyStepName nvarchar(128),
    @InsertColumns nvarchar(max),
    @CopyProjection nvarchar(max);

DECLARE copy_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT LogicalName, SourceName, TargetName, HasIdentity, StepName
FROM @CopyWork
ORDER BY CASE LogicalName WHEN N'STAGING' THEN 1 WHEN N'KS5' THEN 2 ELSE 3 END;

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
                        THEN N'CONVERT(bigint, source.'
                             + QUOTENAME(column_info.name) + N')'
                    WHEN int_map.ColumnName IS NOT NULL
                        THEN N'CONVERT(int, source.'
                             + QUOTENAME(column_info.name) + N')'
                    WHEN string_map.ColumnName IS NOT NULL
                        THEN N'CONVERT(nvarchar('
                             + CONVERT(nvarchar(10), string_map.TargetLength)
                             + N'), '
                             + CASE WHEN string_map.TrimRight = 1
                                    THEN N'RTRIM(source.'
                                         + QUOTENAME(column_info.name) + N')'
                                    ELSE N'source.' + QUOTENAME(column_info.name)
                               END
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
        + N' (' + @InsertColumns + N')'
        + N' SELECT ' + @CopyProjection
        + N' FROM dbo.' + QUOTENAME(@SourceName) + N' AS source;'
        + N' SET @Copied = @@ROWCOUNT;'
        + CASE WHEN @HasIdentity = 1
               THEN N' SET IDENTITY_INSERT dbo.' + QUOTENAME(@TargetName) + N' OFF;'
               ELSE N'' END;

    EXEC sys.sp_executesql
        @Sql, N'@Copied bigint OUTPUT', @Copied = @RowsCopied OUTPUT;

    SET @StepFinishedAtUtc = SYSUTCDATETIME();
    INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'FORWARD', @CopyStepName,
         @StepStartedAtUtc, @StepFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
         @RowsCopied, N'One explicit normalized copy pass.');

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
        PAD_INDEX = OFF,
        STATISTICS_NORECOMPUTE = OFF,
        IGNORE_DUP_KEY = OFF,
        ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON,
        OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    );

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'build_kingdomscandata5_primary_key',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     @ExpectedKs5Rows, N'Current clustered primary-key contract retained.');

SET @StepStartedAtUtc = SYSUTCDATETIME();

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

UPDATE STATISTICS dbo.KingdomScanData4_Phase2_New WITH FULLSCAN;
UPDATE STATISTICS dbo.KingdomScanData5_Phase2_New WITH FULLSCAN;

GRANT SELECT ON OBJECT::dbo.KingdomScanData4_Phase2_New
TO ImportProcUser;

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'build_kingdomscandata4_indexes_and_statistics',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     @ExpectedKs4Rows,
     N'All ten named indexes retained; FULLSCAN stats; ImportProcUser SELECT copied.');

INSERT @DigestWork (LogicalName, PhysicalName, DigestKind)
VALUES
    (N'KS4', N'KingdomScanData4_Phase2_New', 'SHADOW'),
    (N'KS5', N'KingdomScanData5_Phase2_New', 'SHADOW'),
    (N'STAGING', N'IMPORT_STAGING_Phase2_New', 'SHADOW');

SET @StepStartedAtUtc = SYSUTCDATETIME();

DECLARE shadow_digest_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT LogicalName, PhysicalName, DigestKind
FROM @DigestWork
WHERE DigestKind = 'SHADOW'
ORDER BY LogicalName;

OPEN shadow_digest_cursor;
FETCH NEXT FROM shadow_digest_cursor
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

    FETCH NEXT FROM shadow_digest_cursor
    INTO @LogicalName, @PhysicalName, @DigestKind;
END;

CLOSE shadow_digest_cursor;
DEALLOCATE shadow_digest_cursor;

IF EXISTS
(
    SELECT 1
    FROM @Digests AS baseline
    JOIN @Digests AS shadow_copy
      ON shadow_copy.LogicalName = baseline.LogicalName
     AND shadow_copy.DigestKind = 'SHADOW'
    WHERE baseline.DigestKind = 'BASELINE'
      AND (baseline.RowCount <> shadow_copy.RowCount
           OR baseline.Digest <> shadow_copy.Digest)
)
    THROW 51434, 'Shadow row count or normalized SHA-256 digest mismatch.', 1;

UPDATE state_row
SET ForwardKs4Digest =
        (SELECT Digest FROM @Digests
         WHERE LogicalName = N'KS4' AND DigestKind = 'SHADOW'),
    ForwardKs5Digest =
        (SELECT Digest FROM @Digests
         WHERE LogicalName = N'KS5' AND DigestKind = 'SHADOW'),
    ForwardStagingDigest =
        (SELECT Digest FROM @Digests
         WHERE LogicalName = N'STAGING' AND DigestKind = 'SHADOW')
FROM dbo.KS4_Phase1_MigrationRehearsalState AS state_row
WHERE state_row.RunId = @RunId;

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'verify_shadow_normalized_digests',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     @ExpectedKs4Rows + @ExpectedKs5Rows,
     N'All three row counts and normalized SHA-256 digests match.');

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
    THROW 51435, 'Could not acquire the migration application lock.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.dm_exec_sessions AS session
    LEFT JOIN sys.dm_exec_requests AS request
      ON request.session_id = session.session_id
    WHERE session.is_user_process = 1
      AND session.session_id <> @@SPID
      AND COALESCE(request.database_id, session.database_id) = DB_ID()
)
    THROW 51436, 'A user session connected before cutover.', 1;

EXEC sys.sp_rename
    N'dbo.IMPORT_STAGING', N'IMPORT_STAGING_Phase2_Old', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.IMPORT_STAGING_Phase2_New', N'IMPORT_STAGING', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.KingdomScanData5', N'KingdomScanData5_Phase2_Old', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.KingdomScanData5_Phase2_New', N'KingdomScanData5', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.KingdomScanData4', N'KingdomScanData4_Phase2_Old', N'OBJECT';
EXEC sys.sp_rename
    N'dbo.KingdomScanData4_Phase2_New', N'KingdomScanData4', N'OBJECT';

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
    THROW 51437, 'Canonical row counts changed during cutover.', 1;

UPDATE dbo.KS4_Phase1_MigrationRehearsalState
SET ForwardComplete = 1,
    ForwardCompletedAtUtc = SYSUTCDATETIME()
WHERE RunId = @RunId;

COMMIT TRANSACTION;
SET @StepFinishedAtUtc = SYSUTCDATETIME();

INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'transactional_cutover_and_module_refresh',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     (SELECT COUNT(*) FROM @Modules),
     N'Three metadata swaps; affected views refreshed before other modules.');

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
      AND type_info.name = N'bigint'
      AND column_info.is_nullable = 0
)
   OR NOT EXISTS
(
    SELECT 1
    FROM sys.computed_columns
    WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
      AND name = N'AsOfDate'
      AND is_persisted = 1
)
   OR (SELECT COUNT(*) FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
         AND index_id > 0) <> 10
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
    THROW 51438, 'Post-cutover schema, index, computed, or permission check failed.', 1;

SET @StepFinishedAtUtc = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'post_cutover_checktable_and_schema',
     @StepStartedAtUtc, @StepFinishedAtUtc,
     DATEDIFF_BIG(microsecond, @StepStartedAtUtc, @StepFinishedAtUtc) / 1000.0,
     @ExpectedKs4Rows + @ExpectedKs5Rows,
     N'DBCC CHECKTABLE passed; types, AsOfDate, indexes and permission verified.');

DECLARE @OverallFinishedAtUtc datetime2(7) = SYSUTCDATETIME();
INSERT dbo.KS4_Phase1_MigrationRehearsalReceipt
    (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
     DurationMs, RowsAffected, Notes)
VALUES
    (@RunId, 'FORWARD', N'total_forward_outage',
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
    N'migration_forward_summary' AS EvidenceSection,
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
    10 AS RetainedKs4Indexes,
    N'PASS' AS ForwardStatus;

SELECT
    N'migration_forward_digest' AS EvidenceSection,
    LogicalName,
    DigestKind,
    RowCount,
    CONVERT(char(64), Digest, 2) AS NormalizedDigestSha256
FROM @Digests
ORDER BY LogicalName, DigestKind;

SELECT
    N'migration_forward_step' AS EvidenceSection,
    Direction,
    StepName,
    StartedAtUtc,
    FinishedAtUtc,
    DurationMs,
    RowsAffected,
    Notes
FROM dbo.KS4_Phase1_MigrationRehearsalReceipt
WHERE RunId = @RunId
ORDER BY ReceiptId;

SELECT
    N'migration_forward_retained_rollback_object' AS EvidenceSection,
    schema_info.name AS SchemaName,
    object_info.name AS ObjectName,
    object_info.type_desc AS ObjectType
FROM sys.objects AS object_info
JOIN sys.schemas AS schema_info
  ON schema_info.schema_id = object_info.schema_id
WHERE object_info.name IN
(
    N'KingdomScanData4_Phase2_Old',
    N'KingdomScanData5_Phase2_Old',
    N'IMPORT_STAGING_Phase2_Old'
)
ORDER BY object_info.name;
