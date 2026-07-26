/*
Purpose:
    Read-only preflight for the Phase 1 shadow-copy forward/rollback rehearsal.

Safety:
    - Refuses production and every database except the dedicated benchmark copy.
    - Requires the exact fresh seed state.
    - Refuses snapshots on the benchmark target.
    - Does not create, alter, drop, execute, or refresh application objects.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @CollectorRevision varchar(20) = '20260725.2';
DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK';
DECLARE @ExpectedKs4Rows bigint = 394506;
DECLARE @ExpectedKs5Rows bigint = 394526;
DECLARE @ExpectedMaxScan bigint = 1020;

IF DB_NAME() <> @ExpectedDatabase OR DB_NAME() = N'ROK_TRACKER'
    THROW 51400,
        'Safety stop: connect to the exact benchmark database, never production.',
        1;

IF @@TRANCOUNT <> 0
    THROW 51401, 'Run the preflight with no existing user transaction.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE source_database_id = DB_ID()
       OR database_id = DB_ID()
          AND source_database_id IS NOT NULL
)
    THROW 51402,
        'A database snapshot is associated with the benchmark target.',
        1;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING', N'U') IS NULL
    THROW 51403, 'One or more required source tables are absent.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NOT NULL
    THROW 51404,
        'A prior migration-rehearsal table exists; restore the seed before preflight.',
        1;

DECLARE
    @Ks4Rows bigint,
    @Ks5Rows bigint,
    @Ks4MaxScan bigint,
    @Ks5MaxScan bigint;

SELECT
    @Ks4Rows = COUNT_BIG(*),
    @Ks4MaxScan = MAX(TRY_CONVERT(bigint, SCANORDER))
FROM dbo.KingdomScanData4;

SELECT
    @Ks5Rows = COUNT_BIG(*),
    @Ks5MaxScan = MAX(TRY_CONVERT(bigint, SCANORDER))
FROM dbo.KingdomScanData5;

IF @Ks4Rows <> @ExpectedKs4Rows
   OR @Ks5Rows <> @ExpectedKs5Rows
   OR @Ks4MaxScan <> @ExpectedMaxScan
   OR @Ks5MaxScan <> @ExpectedMaxScan
    THROW 51405,
        'Fresh-seed drift: restore the benchmark seed before migration preflight.',
        1;

SELECT
    N'migration_preflight_identity' AS EvidenceSection,
    @CollectorRevision AS CollectorRevision,
    DB_NAME() AS DatabaseName,
    @@SERVERNAME AS ServerName,
    @Ks4Rows AS Ks4Rows,
    @Ks5Rows AS Ks5Rows,
    @Ks4MaxScan AS Ks4MaxScan,
    @Ks5MaxScan AS Ks5MaxScan,
    SYSUTCDATETIME() AS CollectedAtUtc;

DECLARE @ExpectedTypes table
(
    ObjectName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    DataType sysname NOT NULL,
    MaxLength smallint NOT NULL,
    IsNullable bit NOT NULL,
    PRIMARY KEY (ObjectName, ColumnName)
);

INSERT @ExpectedTypes
    (ObjectName, ColumnName, DataType, MaxLength, IsNullable)
VALUES
    (N'KingdomScanData4', N'PowerRank', N'float', 8, 0),
    (N'KingdomScanData4', N'GovernorName', N'nchar', 510, 1),
    (N'KingdomScanData4', N'GovernorID', N'float', 8, 0),
    (N'KingdomScanData4', N'Alliance', N'nchar', 510, 1),
    (N'KingdomScanData4', N'Power', N'float', 8, 0),
    (N'KingdomScanData4', N'KillPoints', N'float', 8, 0),
    (N'KingdomScanData4', N'Deads', N'float', 8, 0),
    (N'KingdomScanData4', N'T1_Kills', N'float', 8, 0),
    (N'KingdomScanData4', N'T2_Kills', N'float', 8, 0),
    (N'KingdomScanData4', N'T3_Kills', N'float', 8, 0),
    (N'KingdomScanData4', N'T4_Kills', N'float', 8, 0),
    (N'KingdomScanData4', N'T5_Kills', N'float', 8, 0),
    (N'KingdomScanData4', N'T4&T5_KILLS', N'float', 8, 1),
    (N'KingdomScanData4', N'TOTAL_KILLS', N'float', 8, 1),
    (N'KingdomScanData4', N'RSS_Gathered', N'float', 8, 1),
    (N'KingdomScanData4', N'RSSAssistance', N'float', 8, 0),
    (N'KingdomScanData4', N'Helps', N'float', 8, 0),
    (N'KingdomScanData4', N'SCANORDER', N'float', 8, 0),
    (N'KingdomScanData5', N'PowerRank', N'float', 8, 0),
    (N'KingdomScanData5', N'GovernorName', N'nchar', 510, 1),
    (N'KingdomScanData5', N'GovernorID', N'float', 8, 0),
    (N'KingdomScanData5', N'Alliance', N'nchar', 510, 1),
    (N'KingdomScanData5', N'Power', N'float', 8, 0),
    (N'KingdomScanData5', N'KillPoints', N'float', 8, 0),
    (N'KingdomScanData5', N'Deads', N'float', 8, 0),
    (N'KingdomScanData5', N'T1_Kills', N'float', 8, 0),
    (N'KingdomScanData5', N'T2_Kills', N'float', 8, 0),
    (N'KingdomScanData5', N'T3_Kills', N'float', 8, 0),
    (N'KingdomScanData5', N'T4_Kills', N'float', 8, 0),
    (N'KingdomScanData5', N'T5_Kills', N'float', 8, 0),
    (N'KingdomScanData5', N'T4&T5_KILLS', N'float', 8, 1),
    (N'KingdomScanData5', N'TOTAL_KILLS', N'float', 8, 1),
    (N'KingdomScanData5', N'RSS_Gathered', N'float', 8, 1),
    (N'KingdomScanData5', N'RSSAssistance', N'float', 8, 0),
    (N'KingdomScanData5', N'Helps', N'float', 8, 0),
    (N'KingdomScanData5', N'SCANORDER', N'float', 8, 1),
    (N'IMPORT_STAGING', N'Name', N'nchar', 510, 1),
    (N'IMPORT_STAGING', N'Governor ID', N'float', 8, 0),
    (N'IMPORT_STAGING', N'Alliance', N'nchar', 510, 1),
    (N'IMPORT_STAGING', N'Power', N'float', 8, 0),
    (N'IMPORT_STAGING', N'Total Kill Points', N'float', 8, 0),
    (N'IMPORT_STAGING', N'Dead Troops', N'float', 8, 0),
    (N'IMPORT_STAGING', N'T1-Kills', N'float', 8, 0),
    (N'IMPORT_STAGING', N'T2-Kills', N'float', 8, 0),
    (N'IMPORT_STAGING', N'T3-Kills', N'float', 8, 0),
    (N'IMPORT_STAGING', N'T4-Kills', N'float', 8, 0),
    (N'IMPORT_STAGING', N'T5-Kills', N'float', 8, 0),
    (N'IMPORT_STAGING', N'Kills (T4+)', N'float', 8, 1),
    (N'IMPORT_STAGING', N'KILLS', N'float', 8, 1),
    (N'IMPORT_STAGING', N'RSS Gathered', N'float', 8, 1),
    (N'IMPORT_STAGING', N'RSS Assistance', N'float', 8, 0),
    (N'IMPORT_STAGING', N'Alliance Helps', N'float', 8, 0),
    (N'IMPORT_STAGING', N'SCANORDER', N'float', 8, 1),
    (N'IMPORT_STAGING', N'Updated_on', N'varchar', 50, 1);

;WITH Actual AS
(
    SELECT
        OBJECT_NAME(c.object_id) AS ObjectName,
        c.name AS ColumnName,
        ty.name AS DataType,
        c.max_length AS MaxLength,
        c.is_nullable AS IsNullable
    FROM sys.columns AS c
    JOIN sys.types AS ty
      ON ty.user_type_id = c.user_type_id
    WHERE c.object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
)
SELECT
    N'migration_preflight_type_drift' AS EvidenceSection,
    expected.ObjectName,
    expected.ColumnName,
    expected.DataType AS ExpectedDataType,
    actual.DataType AS ActualDataType,
    expected.MaxLength AS ExpectedMaxLength,
    actual.MaxLength AS ActualMaxLength,
    expected.IsNullable AS ExpectedIsNullable,
    actual.IsNullable AS ActualIsNullable
FROM @ExpectedTypes AS expected
LEFT JOIN Actual AS actual
  ON actual.ObjectName = expected.ObjectName
 AND actual.ColumnName = expected.ColumnName
WHERE actual.ColumnName IS NULL
   OR actual.DataType <> expected.DataType
   OR actual.MaxLength <> expected.MaxLength
   OR actual.IsNullable <> expected.IsNullable
ORDER BY expected.ObjectName, expected.ColumnName;

IF EXISTS
(
    SELECT 1
    FROM @ExpectedTypes AS expected
    LEFT JOIN sys.columns AS c
      ON c.object_id = OBJECT_ID(N'dbo.' + expected.ObjectName)
     AND c.name = expected.ColumnName
    LEFT JOIN sys.types AS ty
      ON ty.user_type_id = c.user_type_id
    WHERE c.column_id IS NULL
       OR ty.name <> expected.DataType
       OR c.max_length <> expected.MaxLength
       OR c.is_nullable <> expected.IsNullable
)
    THROW 51406, 'Source type/nullability drift detected.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.computed_columns
    WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
      AND name = N'AsOfDate'
      AND is_persisted = 1
      AND definition = N'(CONVERT([date],[ScanDate]))'
)
    THROW 51407, 'The persisted AsOfDate contract drifted.', 1;

DECLARE @ConversionEvidence table
(
    ObjectName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    TargetType sysname NOT NULL,
    RowCount bigint NOT NULL,
    NullCount bigint NOT NULL,
    FractionalCount bigint NOT NULL,
    IntOutOfRangeCount bigint NOT NULL,
    BigintFailedCount bigint NOT NULL,
    PRIMARY KEY (ObjectName, ColumnName)
);

;WITH ValuesToCheck AS
(
    SELECT N'KingdomScanData4' AS ObjectName, checked.ColumnName,
           checked.TargetType, checked.CandidateValue
    FROM dbo.KingdomScanData4 AS source
    CROSS APPLY (VALUES
        (N'GovernorID', N'bigint', source.GovernorID),
        (N'PowerRank', N'int', source.PowerRank),
        (N'SCANORDER', N'int', source.SCANORDER),
        (N'Power', N'bigint', source.Power),
        (N'KillPoints', N'bigint', source.KillPoints),
        (N'Deads', N'bigint', source.Deads),
        (N'T1_Kills', N'bigint', source.T1_Kills),
        (N'T2_Kills', N'bigint', source.T2_Kills),
        (N'T3_Kills', N'bigint', source.T3_Kills),
        (N'T4_Kills', N'bigint', source.T4_Kills),
        (N'T5_Kills', N'bigint', source.T5_Kills),
        (N'T4&T5_KILLS', N'bigint', source.[T4&T5_KILLS]),
        (N'TOTAL_KILLS', N'bigint', source.TOTAL_KILLS),
        (N'RSS_Gathered', N'bigint', source.RSS_Gathered),
        (N'RSSAssistance', N'bigint', source.RSSAssistance),
        (N'Helps', N'bigint', source.Helps)
    ) AS checked(ColumnName, TargetType, CandidateValue)
    UNION ALL
    SELECT N'KingdomScanData5', checked.ColumnName,
           checked.TargetType, checked.CandidateValue
    FROM dbo.KingdomScanData5 AS source
    CROSS APPLY (VALUES
        (N'GovernorID', N'bigint', source.GovernorID),
        (N'PowerRank', N'int', source.PowerRank),
        (N'SCANORDER', N'int', source.SCANORDER),
        (N'Power', N'bigint', source.Power),
        (N'KillPoints', N'bigint', source.KillPoints),
        (N'Deads', N'bigint', source.Deads),
        (N'T1_Kills', N'bigint', source.T1_Kills),
        (N'T2_Kills', N'bigint', source.T2_Kills),
        (N'T3_Kills', N'bigint', source.T3_Kills),
        (N'T4_Kills', N'bigint', source.T4_Kills),
        (N'T5_Kills', N'bigint', source.T5_Kills),
        (N'T4&T5_KILLS', N'bigint', source.[T4&T5_KILLS]),
        (N'TOTAL_KILLS', N'bigint', source.TOTAL_KILLS),
        (N'RSS_Gathered', N'bigint', source.RSS_Gathered),
        (N'RSSAssistance', N'bigint', source.RSSAssistance),
        (N'Helps', N'bigint', source.Helps)
    ) AS checked(ColumnName, TargetType, CandidateValue)
    UNION ALL
    SELECT N'IMPORT_STAGING', checked.ColumnName,
           checked.TargetType, checked.CandidateValue
    FROM dbo.IMPORT_STAGING AS source
    CROSS APPLY (VALUES
        (N'Governor ID', N'bigint', source.[Governor ID]),
        (N'SCANORDER', N'int', source.SCANORDER),
        (N'Power', N'bigint', source.Power),
        (N'Total Kill Points', N'bigint', source.[Total Kill Points]),
        (N'Dead Troops', N'bigint', source.[Dead Troops]),
        (N'T1-Kills', N'bigint', source.[T1-Kills]),
        (N'T2-Kills', N'bigint', source.[T2-Kills]),
        (N'T3-Kills', N'bigint', source.[T3-Kills]),
        (N'T4-Kills', N'bigint', source.[T4-Kills]),
        (N'T5-Kills', N'bigint', source.[T5-Kills]),
        (N'Kills (T4+)', N'bigint', source.[Kills (T4+)]),
        (N'KILLS', N'bigint', source.KILLS),
        (N'RSS Gathered', N'bigint', source.[RSS Gathered]),
        (N'RSS Assistance', N'bigint', source.[RSS Assistance]),
        (N'Alliance Helps', N'bigint', source.[Alliance Helps])
    ) AS checked(ColumnName, TargetType, CandidateValue)
)
INSERT @ConversionEvidence
    (ObjectName, ColumnName, TargetType, RowCount, NullCount,
     FractionalCount, IntOutOfRangeCount, BigintFailedCount)
SELECT
    ObjectName,
    ColumnName,
    TargetType,
    COUNT_BIG(*) AS RowCount,
    SUM(CASE WHEN CandidateValue IS NULL THEN CONVERT(bigint, 1) ELSE 0 END)
        AS NullCount,
    SUM(CASE
        WHEN CandidateValue IS NOT NULL
         AND CandidateValue <> FLOOR(CandidateValue)
        THEN CONVERT(bigint, 1) ELSE 0 END) AS FractionalCount,
    SUM(CASE
        WHEN TargetType = N'int'
         AND CandidateValue IS NOT NULL
         AND (CandidateValue < -2147483648.0
              OR CandidateValue > 2147483647.0)
        THEN CONVERT(bigint, 1) ELSE 0 END) AS IntOutOfRangeCount,
    SUM(CASE
        WHEN TargetType = N'bigint'
         AND CandidateValue IS NOT NULL
         AND TRY_CONVERT(bigint, CandidateValue) IS NULL
        THEN CONVERT(bigint, 1) ELSE 0 END) AS BigintFailedCount
FROM ValuesToCheck
GROUP BY ObjectName, ColumnName, TargetType;

SELECT
    N'migration_preflight_conversion' AS EvidenceSection,
    ObjectName,
    ColumnName,
    TargetType,
    RowCount,
    NullCount,
    FractionalCount,
    IntOutOfRangeCount,
    BigintFailedCount
FROM @ConversionEvidence
ORDER BY ObjectName, ColumnName;

IF EXISTS
(
    SELECT 1
    FROM @ConversionEvidence AS failures
    WHERE failures.FractionalCount <> 0
       OR failures.IntOutOfRangeCount <> 0
       OR failures.BigintFailedCount <> 0
)
    THROW 51408, 'Numeric conversion preflight failed.', 1;

SELECT
    N'migration_preflight_strings' AS EvidenceSection,
    strings.ObjectName,
    strings.ColumnName,
    strings.TargetLength,
    strings.RowCount,
    strings.NullCount,
    strings.MaxTrimmedLength,
    strings.OverTargetCount,
    strings.LeadingSpaceCount
FROM
(
    SELECT N'KingdomScanData4' AS ObjectName, N'GovernorName' AS ColumnName,
           200 AS TargetLength, COUNT_BIG(*) AS RowCount,
           SUM(CASE WHEN GovernorName IS NULL THEN 1 ELSE 0 END) AS NullCount,
           MAX(LEN(RTRIM(GovernorName))) AS MaxTrimmedLength,
           SUM(CASE WHEN LEN(RTRIM(GovernorName)) > 200 THEN 1 ELSE 0 END)
               AS OverTargetCount,
           SUM(CASE WHEN GovernorName <> LTRIM(GovernorName) THEN 1 ELSE 0 END)
               AS LeadingSpaceCount
    FROM dbo.KingdomScanData4
    UNION ALL
    SELECT N'KingdomScanData4', N'Alliance', 100, COUNT_BIG(*),
           SUM(CASE WHEN Alliance IS NULL THEN 1 ELSE 0 END),
           MAX(LEN(RTRIM(Alliance))),
           SUM(CASE WHEN LEN(RTRIM(Alliance)) > 100 THEN 1 ELSE 0 END),
           SUM(CASE WHEN Alliance <> LTRIM(Alliance) THEN 1 ELSE 0 END)
    FROM dbo.KingdomScanData4
    UNION ALL
    SELECT N'KingdomScanData5', N'GovernorName', 200, COUNT_BIG(*),
           SUM(CASE WHEN GovernorName IS NULL THEN 1 ELSE 0 END),
           MAX(LEN(RTRIM(GovernorName))),
           SUM(CASE WHEN LEN(RTRIM(GovernorName)) > 200 THEN 1 ELSE 0 END),
           SUM(CASE WHEN GovernorName <> LTRIM(GovernorName) THEN 1 ELSE 0 END)
    FROM dbo.KingdomScanData5
    UNION ALL
    SELECT N'KingdomScanData5', N'Alliance', 100, COUNT_BIG(*),
           SUM(CASE WHEN Alliance IS NULL THEN 1 ELSE 0 END),
           MAX(LEN(RTRIM(Alliance))),
           SUM(CASE WHEN LEN(RTRIM(Alliance)) > 100 THEN 1 ELSE 0 END),
           SUM(CASE WHEN Alliance <> LTRIM(Alliance) THEN 1 ELSE 0 END)
    FROM dbo.KingdomScanData5
    UNION ALL
    SELECT N'IMPORT_STAGING', N'Name', 200, COUNT_BIG(*),
           SUM(CASE WHEN Name IS NULL THEN 1 ELSE 0 END),
           MAX(LEN(RTRIM(Name))),
           SUM(CASE WHEN LEN(RTRIM(Name)) > 200 THEN 1 ELSE 0 END),
           SUM(CASE WHEN Name <> LTRIM(Name) THEN 1 ELSE 0 END)
    FROM dbo.IMPORT_STAGING
    UNION ALL
    SELECT N'IMPORT_STAGING', N'Alliance', 100, COUNT_BIG(*),
           SUM(CASE WHEN Alliance IS NULL THEN 1 ELSE 0 END),
           MAX(LEN(RTRIM(Alliance))),
           SUM(CASE WHEN LEN(RTRIM(Alliance)) > 100 THEN 1 ELSE 0 END),
           SUM(CASE WHEN Alliance <> LTRIM(Alliance) THEN 1 ELSE 0 END)
    FROM dbo.IMPORT_STAGING
    UNION ALL
    SELECT N'IMPORT_STAGING', N'Updated_on', 200, COUNT_BIG(*),
           SUM(CASE WHEN Updated_on IS NULL THEN 1 ELSE 0 END),
           MAX(LEN(Updated_on)),
           SUM(CASE WHEN LEN(Updated_on) > 200 THEN 1 ELSE 0 END),
           0
    FROM dbo.IMPORT_STAGING
) AS strings
ORDER BY strings.ObjectName, strings.ColumnName;

IF EXISTS
(
    SELECT 1
    FROM
    (
        SELECT MAX(LEN(RTRIM(GovernorName))) AS MaximumLength, 200 AS TargetLength
        FROM dbo.KingdomScanData4
        UNION ALL SELECT MAX(LEN(RTRIM(Alliance))), 100
        FROM dbo.KingdomScanData4
        UNION ALL SELECT MAX(LEN(RTRIM(GovernorName))), 200
        FROM dbo.KingdomScanData5
        UNION ALL SELECT MAX(LEN(RTRIM(Alliance))), 100
        FROM dbo.KingdomScanData5
        UNION ALL SELECT MAX(LEN(RTRIM(Name))), 200
        FROM dbo.IMPORT_STAGING
        UNION ALL SELECT MAX(LEN(RTRIM(Alliance))), 100
        FROM dbo.IMPORT_STAGING
        UNION ALL SELECT MAX(LEN(Updated_on)), 200
        FROM dbo.IMPORT_STAGING
    ) AS lengths
    WHERE lengths.MaximumLength > lengths.TargetLength
)
    THROW 51409, 'String-width preflight failed.', 1;

SELECT
    N'migration_preflight_table_storage' AS EvidenceSection,
    OBJECT_NAME(p.object_id) AS ObjectName,
    SUM(CASE WHEN p.index_id IN (0, 1) THEN p.rows ELSE 0 END)
        AS ApproximateRows,
    CONVERT(decimal(19, 2), SUM(a.total_pages) * 8.0 / 1024.0) AS TotalSizeMb,
    CONVERT(decimal(19, 2), SUM(a.used_pages) * 8.0 / 1024.0) AS UsedSizeMb,
    MIN(p.data_compression_desc) AS Compression
FROM sys.partitions AS p
JOIN sys.allocation_units AS a
  ON a.container_id =
     CASE WHEN a.type IN (1, 3) THEN p.hobt_id ELSE p.partition_id END
WHERE p.object_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.KingdomScanData5'),
    OBJECT_ID(N'dbo.IMPORT_STAGING')
)
GROUP BY p.object_id
ORDER BY ObjectName;

SELECT
    N'migration_preflight_database_files' AS EvidenceSection,
    df.name AS LogicalFileName,
    df.type_desc AS FileType,
    df.physical_name AS PhysicalPath,
    CONVERT(decimal(19, 2), df.size * 8.0 / 1024.0) AS SizeMb,
    CASE WHEN df.type = 0
         THEN CONVERT(decimal(19, 2),
              (df.size - FILEPROPERTY(df.name, 'SpaceUsed')) * 8.0 / 1024.0)
         END AS FreeInsideFileMb,
    CASE WHEN df.max_size = -1 THEN N'UNLIMITED'
         ELSE CONVERT(nvarchar(30),
              CONVERT(decimal(19, 2), df.max_size * 8.0 / 1024.0))
         END AS MaxSizeMb,
    CASE WHEN df.is_percent_growth = 1
         THEN CONVERT(nvarchar(30), df.growth) + N'%'
         ELSE CONVERT(nvarchar(30),
              CONVERT(decimal(19, 2), df.growth * 8.0 / 1024.0)) + N' MB'
         END AS GrowthSetting,
    CONVERT(decimal(19, 2), volume.total_bytes / 1048576.0) AS VolumeTotalMb,
    CONVERT(decimal(19, 2), volume.available_bytes / 1048576.0) AS VolumeFreeMb
FROM sys.database_files AS df
CROSS APPLY sys.dm_os_volume_stats(DB_ID(), df.file_id) AS volume
ORDER BY df.file_id;

SELECT
    N'migration_preflight_log' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    d.recovery_model_desc AS RecoveryModel,
    d.log_reuse_wait_desc AS LogReuseWait,
    CONVERT(decimal(19, 2), usage.total_log_size_in_bytes / 1048576.0)
        AS TotalLogMb,
    CONVERT(decimal(19, 2), usage.used_log_space_in_bytes / 1048576.0)
        AS UsedLogMb,
    usage.used_log_space_in_percent AS UsedLogPercent
FROM sys.databases AS d
CROSS JOIN sys.dm_db_log_space_usage AS usage
WHERE d.database_id = DB_ID();

SELECT
    N'migration_preflight_tempdb' AS EvidenceSection,
    SUM(total_page_count) * 8.0 / 1024.0 AS TotalFileMb,
    SUM(allocated_extent_page_count) * 8.0 / 1024.0 AS AllocatedFileMb,
    SUM(unallocated_extent_page_count) * 8.0 / 1024.0 AS UnallocatedFileMb
FROM tempdb.sys.dm_db_file_space_usage;

SELECT
    N'migration_preflight_indexes' AS EvidenceSection,
    OBJECT_NAME(i.object_id) AS ObjectName,
    i.index_id AS IndexId,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_unique AS IsUnique,
    i.is_primary_key AS IsPrimaryKey,
    i.is_disabled AS IsDisabled,
    i.has_filter AS HasFilter,
    i.filter_definition AS FilterDefinition
FROM sys.indexes AS i
WHERE i.object_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.KingdomScanData5'),
    OBJECT_ID(N'dbo.IMPORT_STAGING')
)
  AND i.index_id > 0
ORDER BY ObjectName, i.index_id;

SELECT
    N'migration_preflight_dependency' AS EvidenceSection,
    dependency.ReferencingSchema,
    dependency.ReferencingObject,
    dependency.ObjectType,
    dependency.IsSchemaBound,
    dependency.FoundBy
FROM
(
    SELECT DISTINCT
        OBJECT_SCHEMA_NAME(sed.referencing_id) AS ReferencingSchema,
        OBJECT_NAME(sed.referencing_id) AS ReferencingObject,
        o.type_desc AS ObjectType,
        CONVERT(bit, OBJECTPROPERTYEX(sed.referencing_id, 'IsSchemaBound'))
            AS IsSchemaBound,
        N'sql_expression_dependencies' AS FoundBy
    FROM sys.sql_expression_dependencies AS sed
    JOIN sys.objects AS o
      ON o.object_id = sed.referencing_id
    WHERE sed.referenced_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
    UNION
    SELECT
        OBJECT_SCHEMA_NAME(sm.object_id),
        OBJECT_NAME(sm.object_id),
        o.type_desc,
        CONVERT(bit, OBJECTPROPERTYEX(sm.object_id, 'IsSchemaBound')),
        N'module_text'
    FROM sys.sql_modules AS sm
    JOIN sys.objects AS o
      ON o.object_id = sm.object_id
    WHERE sm.definition LIKE N'%KingdomScanData4%'
       OR sm.definition LIKE N'%KingdomScanData5%'
       OR sm.definition LIKE N'%IMPORT_STAGING%'
) AS dependency
ORDER BY dependency.ReferencingSchema, dependency.ReferencingObject,
         dependency.FoundBy;

IF EXISTS
(
    SELECT 1
    FROM sys.sql_expression_dependencies AS sed
    WHERE sed.referenced_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
      AND OBJECTPROPERTYEX(sed.referencing_id, 'IsSchemaBound') = 1
)
    THROW 51410, 'Schema-bound dependency prevents the proposed name swap.', 1;

SELECT
    N'migration_preflight_structural_dependency' AS EvidenceSection,
    N'FOREIGN_KEY' AS DependencyType,
    fk.name AS DependencyName,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) + N'.'
        + OBJECT_NAME(fk.parent_object_id) AS ParentObject,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) + N'.'
        + OBJECT_NAME(fk.referenced_object_id) AS ReferencedObject
FROM sys.foreign_keys AS fk
WHERE fk.parent_object_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.KingdomScanData5'),
    OBJECT_ID(N'dbo.IMPORT_STAGING')
)
   OR fk.referenced_object_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.KingdomScanData5'),
    OBJECT_ID(N'dbo.IMPORT_STAGING')
)
UNION ALL
SELECT
    N'migration_preflight_structural_dependency',
    N'TRIGGER',
    tr.name,
    OBJECT_SCHEMA_NAME(tr.parent_id) + N'.' + OBJECT_NAME(tr.parent_id),
    NULL
FROM sys.triggers AS tr
WHERE tr.parent_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.KingdomScanData5'),
    OBJECT_ID(N'dbo.IMPORT_STAGING')
);

IF EXISTS
(
    SELECT 1
    FROM sys.foreign_keys AS fk
    WHERE fk.parent_object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
       OR fk.referenced_object_id IN
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
    THROW 51411,
        'Unexpected foreign key or trigger requires an explicit migration branch.',
        1;

SELECT
    N'migration_preflight_object_permission' AS EvidenceSection,
    OBJECT_NAME(permission.major_id) AS ObjectName,
    principal.name AS PrincipalName,
    permission.state_desc AS PermissionState,
    permission.permission_name AS PermissionName,
    permission.minor_id AS ColumnId
FROM sys.database_permissions AS permission
JOIN sys.database_principals AS principal
  ON principal.principal_id = permission.grantee_principal_id
WHERE permission.class = 1
  AND permission.major_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.KingdomScanData5'),
    OBJECT_ID(N'dbo.IMPORT_STAGING')
)
ORDER BY ObjectName, PrincipalName, PermissionName, ColumnId;

SELECT
    N'migration_preflight_extended_property' AS EvidenceSection,
    OBJECT_NAME(property.major_id) AS ObjectName,
    property.minor_id AS ColumnId,
    property.name AS PropertyName,
    CONVERT(nvarchar(4000), property.value) AS PropertyValue
FROM sys.extended_properties AS property
WHERE property.class = 1
  AND property.major_id IN
(
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.KingdomScanData5'),
    OBJECT_ID(N'dbo.IMPORT_STAGING')
)
ORDER BY ObjectName, ColumnId, PropertyName;

SELECT
    N'migration_preflight_other_user_sessions' AS EvidenceSection,
    session.session_id AS SessionId,
    session.login_name AS LoginName,
    session.host_name AS HostName,
    session.program_name AS ProgramName,
    request.status AS RequestStatus,
    request.command AS RequestCommand,
    request.blocking_session_id AS BlockingSessionId
FROM sys.dm_exec_sessions AS session
LEFT JOIN sys.dm_exec_requests AS request
  ON request.session_id = session.session_id
WHERE session.is_user_process = 1
  AND session.session_id <> @@SPID
  AND COALESCE(request.database_id, session.database_id) = DB_ID()
ORDER BY session.session_id;

SELECT
    N'migration_preflight_completion' AS EvidenceSection,
    @CollectorRevision AS CollectorRevision,
    DB_NAME() AS DatabaseName,
    @ExpectedKs4Rows AS ExpectedKs4Rows,
    @ExpectedKs5Rows AS ExpectedKs5Rows,
    @ExpectedMaxScan AS ExpectedMaxScan,
    N'PASS' AS PreflightStatus,
    SYSUTCDATETIME() AS CompletedAtUtc;
