/*
Purpose:
    Create one checksum-verified COPY_ONLY seed backup from the pristine
    restored UPDATE_ALL2 source database. The seed is restored before every
    committed benchmark ordinal so all six runs start from identical bytes.

Safety:
    - Refuses production and any source other than the exact restored copy.
    - Requires the guarded pristine snapshot to remain online and owned by
      the source database.
    - Requires the exact Phase 1 row/scan baseline and isolated path override.
    - Refuses to overwrite an existing seed file.
    - Does not modify or drop the source database or its snapshot.
*/

USE [master];
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SourceDatabase sysname = N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @ExpectedSnapshot sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
DECLARE @SeedBackupFile nvarchar(4000) =
    N'C:\sql_backup\ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK_SEED_20260724.bak';
DECLARE @ConfirmCreateSeedBackup bit = 0;
DECLARE @ExpectedKs4Rows bigint = 394506;
DECLARE @ExpectedKs5Rows bigint = 394526;
DECLARE @ExpectedMaxScan bigint = 1020;

IF @ConfirmCreateSeedBackup <> 1
BEGIN
    THROW 51300,
        'Safety stop: set @ConfirmCreateSeedBackup = 1 after reviewing the fixed source and seed path.',
        1;
END;

IF @SourceDatabase = N'ROK_TRACKER'
BEGIN
    THROW 51301,
        'Safety stop: production ROK_TRACKER cannot be a benchmark seed source.',
        1;
END;

IF DB_ID(@SourceDatabase) IS NULL
BEGIN
    THROW 51302,
        'The exact restored source database does not exist.',
        1;
END;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
BEGIN
    THROW 51303,
        'Creating and verifying the benchmark seed requires a sysadmin session.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51304,
        'Run seed creation with no existing user transaction.',
        1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.databases AS snapshot_db
    JOIN sys.databases AS source_db
      ON source_db.database_id = snapshot_db.source_database_id
    WHERE snapshot_db.name = @ExpectedSnapshot
      AND snapshot_db.state_desc = N'ONLINE'
      AND source_db.name = @SourceDatabase
)
BEGIN
    THROW 51305,
        'The guarded pristine snapshot is not online for the exact source database.',
        1;
END;

DECLARE @SeedFileExists int = 0;
EXEC master.dbo.xp_fileexist
    @SeedBackupFile,
    @SeedFileExists OUTPUT;

IF @SeedFileExists = 1
BEGIN
    THROW 51306,
        'The configured seed backup already exists; this script refuses to overwrite it.',
        1;
END;

DECLARE
    @Ks4Rows bigint,
    @Ks5Rows bigint,
    @Ks4MaxScan bigint,
    @Ks5MaxScan bigint,
    @LiveReferenceCount int,
    @TestReferenceCount int,
    @DefinitionHash char(64);

DECLARE @PreflightSql nvarchar(max) = N'
USE ' + QUOTENAME(@SourceDatabase) + N';

SELECT
    @Ks4RowsOut = COUNT_BIG(*),
    @Ks4MaxScanOut = MAX(TRY_CONVERT(bigint, SCANORDER))
FROM dbo.KingdomScanData4;

SELECT
    @Ks5RowsOut = COUNT_BIG(*),
    @Ks5MaxScanOut = MAX(TRY_CONVERT(bigint, SCANORDER))
FROM dbo.KingdomScanData5;

DECLARE @Definition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N''dbo.IMPORT_STAGING_PROC'', N''P''));

IF @Definition IS NULL
BEGIN
    THROW 51307,
        ''dbo.IMPORT_STAGING_PROC is missing or its definition is unavailable.'',
        1;
END;

DECLARE @LiveRoot nvarchar(4000) =
    N''C:\discord_file_downloader\downloads\'';
DECLARE @TestRoot nvarchar(4000) =
    N''C:\discord_file_downloader\downloads_test\'';

SET @LiveReferenceCountOut =
    (
        LEN(@Definition COLLATE Latin1_General_CI_AS)
        - LEN(
            REPLACE(
                @Definition COLLATE Latin1_General_CI_AS,
                @LiveRoot COLLATE Latin1_General_CI_AS,
                N'''' COLLATE Latin1_General_CI_AS
            )
        )
    )
        / LEN(@LiveRoot);
SET @TestReferenceCountOut =
    (
        LEN(@Definition COLLATE Latin1_General_CI_AS)
        - LEN(
            REPLACE(
                @Definition COLLATE Latin1_General_CI_AS,
                @TestRoot COLLATE Latin1_General_CI_AS,
                N'''' COLLATE Latin1_General_CI_AS
            )
        )
    )
        / LEN(@TestRoot);
SET @DefinitionHashOut =
    CONVERT(char(64), HASHBYTES(''SHA2_256'', @Definition), 2);
';

EXEC sys.sp_executesql
    @PreflightSql,
    N'@Ks4RowsOut bigint OUTPUT,
      @Ks5RowsOut bigint OUTPUT,
      @Ks4MaxScanOut bigint OUTPUT,
      @Ks5MaxScanOut bigint OUTPUT,
      @LiveReferenceCountOut int OUTPUT,
      @TestReferenceCountOut int OUTPUT,
      @DefinitionHashOut char(64) OUTPUT',
    @Ks4RowsOut = @Ks4Rows OUTPUT,
    @Ks5RowsOut = @Ks5Rows OUTPUT,
    @Ks4MaxScanOut = @Ks4MaxScan OUTPUT,
    @Ks5MaxScanOut = @Ks5MaxScan OUTPUT,
    @LiveReferenceCountOut = @LiveReferenceCount OUTPUT,
    @TestReferenceCountOut = @TestReferenceCount OUTPUT,
    @DefinitionHashOut = @DefinitionHash OUTPUT;

IF @Ks4Rows <> @ExpectedKs4Rows
   OR @Ks5Rows <> @ExpectedKs5Rows
   OR @Ks4MaxScan <> @ExpectedMaxScan
   OR @Ks5MaxScan <> @ExpectedMaxScan
BEGIN
    DECLARE @DriftMessage nvarchar(2048) =
        CONCAT(
            N'Source drift: KS4 rows/scan=',
            @Ks4Rows,
            N'/',
            @Ks4MaxScan,
            N'; KS5 rows/scan=',
            @Ks5Rows,
            N'/',
            @Ks5MaxScan,
            N'.'
        );
    THROW 51308, @DriftMessage, 1;
END;

IF @LiveReferenceCount <> 0 OR @TestReferenceCount <> 3
BEGIN
    THROW 51309,
        'The source does not contain exactly the isolated three-reference import-path override.',
        1;
END;

DECLARE @BackupSql nvarchar(max) =
    N'BACKUP DATABASE ' + QUOTENAME(@SourceDatabase)
    + N' TO DISK = @BackupFile'
    + N' WITH COPY_ONLY, CHECKSUM, COMPRESSION, INIT, STATS = 5;';
DECLARE @BackupStartedAtUtc datetime2(7) = SYSUTCDATETIME();

EXEC sys.sp_executesql
    @BackupSql,
    N'@BackupFile nvarchar(4000)',
    @BackupFile = @SeedBackupFile;

RESTORE VERIFYONLY
FROM DISK = @SeedBackupFile
WITH CHECKSUM;

DECLARE @SeedFileVisibleAfter int = 0;
EXEC master.dbo.xp_fileexist
    @SeedBackupFile,
    @SeedFileVisibleAfter OUTPUT;

IF @SeedFileVisibleAfter <> 1
BEGIN
    THROW 51310,
        'The seed backup completed but the configured file is not visible.',
        1;
END;

DECLARE
    @BackupSetGuid uniqueidentifier,
    @BackupFamilyGuid uniqueidentifier,
    @BackupDatabaseGuid uniqueidentifier,
    @BackupFirstLsn numeric(25,0),
    @BackupLastLsn numeric(25,0),
    @BackupCheckpointLsn numeric(25,0),
    @BackupSize numeric(20,0),
    @BackupFinishDate datetime,
    @BackupPosition smallint,
    @BackupMediaSetId int,
    @BackupMediaFamilyCount int;

SELECT TOP (1)
    @BackupSetGuid = backup_set.backup_set_uuid,
    @BackupFamilyGuid = backup_set.family_guid,
    @BackupDatabaseGuid = backup_set.database_guid,
    @BackupFirstLsn = backup_set.first_lsn,
    @BackupLastLsn = backup_set.last_lsn,
    @BackupCheckpointLsn = backup_set.checkpoint_lsn,
    @BackupSize = backup_set.backup_size,
    @BackupFinishDate = backup_set.backup_finish_date,
    @BackupPosition = backup_set.position,
    @BackupMediaSetId = backup_set.media_set_id
FROM msdb.dbo.backupset AS backup_set
JOIN msdb.dbo.backupmediafamily AS media_family
  ON media_family.media_set_id = backup_set.media_set_id
WHERE backup_set.database_name = @SourceDatabase
  AND backup_set.type = N'D'
  AND backup_set.is_copy_only = 1
  AND backup_set.has_backup_checksums = 1
  AND backup_set.backup_start_date >=
      DATEADD(minute, -1, CONVERT(datetime, @BackupStartedAtUtc))
  AND media_family.physical_device_name COLLATE DATABASE_DEFAULT =
      @SeedBackupFile COLLATE DATABASE_DEFAULT
ORDER BY backup_set.backup_finish_date DESC, backup_set.backup_set_id DESC;

IF @BackupSetGuid IS NULL
BEGIN
    THROW 51311,
        'The completed seed backup has no matching checksum/copy-only msdb identity receipt.',
        1;
END;

SELECT @BackupMediaFamilyCount = COUNT(*)
FROM msdb.dbo.backupmediafamily
WHERE media_set_id = @BackupMediaSetId;

IF @BackupMediaFamilyCount <> 1 OR @BackupPosition <> 1
BEGIN
    THROW 51312,
        'The seed backup identity is not a single-device, position-1 backup set.',
        1;
END;

SELECT
    N'update_all2_benchmark_seed' AS EvidenceSection,
    @SourceDatabase AS SourceDatabase,
    @ExpectedSnapshot AS RetainedSnapshot,
    @SeedBackupFile AS SeedBackupFile,
    @Ks4Rows AS Ks4Rows,
    @Ks5Rows AS Ks5Rows,
    @Ks4MaxScan AS Ks4MaxScan,
    @Ks5MaxScan AS Ks5MaxScan,
    @LiveReferenceCount AS LivePathReferenceCount,
    @TestReferenceCount AS TestPathReferenceCount,
    @DefinitionHash AS ImportProcedureSha256,
    @BackupSetGuid AS BackupSetGUID,
    @BackupFamilyGuid AS FamilyGUID,
    @BackupDatabaseGuid AS BindingID,
    @BackupFirstLsn AS FirstLSN,
    @BackupLastLsn AS LastLSN,
    @BackupCheckpointLsn AS CheckpointLSN,
    @BackupSize AS BackupSize,
    @BackupFinishDate AS BackupFinishDate,
    @BackupPosition AS BackupPosition,
    @BackupMediaFamilyCount AS BackupMediaFamilyCount,
    CONVERT(bit, 1) AS BackupChecksumEnabled,
    CONVERT(bit, 1) AS RestoreVerifyOnlyPassed,
    SYSUTCDATETIME() AS CompletedAtUtc;
