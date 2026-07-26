/*
Purpose:
    Restore the exact benchmark seed before one committed UPDATE_ALL2 ordinal.

Safety:
    - Targets only ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK.
    - Refuses production, the retained source, and the retained snapshot.
    - Refuses any snapshot owned by the benchmark target.
    - Validates source file shape and exact post-restore rows/scans/path override.
    - Requires an explicit confirmation for each restore.
*/

USE [master];
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK';
DECLARE @RetainedSourceDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @RetainedSnapshot sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
DECLARE @SeedBackupFile nvarchar(4000) =
    N'C:\sql_backup\ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK_SEED_20260724.bak';
DECLARE @ApprovedBackupSetGuid uniqueidentifier = NULL;
DECLARE @ConfirmRestoreBenchmark bit = 0;
DECLARE @ExpectedKs4Rows bigint = 394506;
DECLARE @ExpectedKs5Rows bigint = 394526;
DECLARE @ExpectedMaxScan bigint = 1020;

IF @ConfirmRestoreBenchmark <> 1
BEGIN
    THROW 51320,
        'Safety stop: set @ConfirmRestoreBenchmark = 1 for one deliberate benchmark reset.',
        1;
END;

IF @TargetDatabase IN
(
    N'ROK_TRACKER',
    @RetainedSourceDatabase,
    @RetainedSnapshot
)
BEGIN
    THROW 51321,
        'Safety stop: the configured target is production or retained evidence.',
        1;
END;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
BEGIN
    THROW 51322,
        'Restoring the benchmark database requires a sysadmin session.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51323,
        'Run the benchmark restore with no existing user transaction.',
        1;
END;

DECLARE @SeedFileExists int = 0;
EXEC master.dbo.xp_fileexist
    @SeedBackupFile,
    @SeedFileExists OUTPUT;

IF @SeedFileExists <> 1
BEGIN
    THROW 51324,
        'The checksum-verified benchmark seed backup is missing.',
        1;
END;

IF @ApprovedBackupSetGuid IS NULL
BEGIN
    THROW 51335,
        'Paste the approved BackupSetGUID from the retained seed-creation receipt before restore.',
        1;
END;

DECLARE
    @ExpectedBackupSetId int,
    @ExpectedBackupSetGuid uniqueidentifier,
    @ExpectedFamilyGuid uniqueidentifier,
    @ExpectedDatabaseGuid uniqueidentifier,
    @ExpectedFirstLsn numeric(25,0),
    @ExpectedLastLsn numeric(25,0),
    @ExpectedCheckpointLsn numeric(25,0),
    @ExpectedBackupSize numeric(20,0),
    @ExpectedBackupFinishDate datetime,
    @ExpectedBackupPosition smallint,
    @ExpectedMediaSetId int,
    @ExpectedMediaFamilyCount int;

SELECT TOP (1)
    @ExpectedBackupSetId = backup_set.backup_set_id,
    @ExpectedBackupSetGuid = backup_set.backup_set_uuid,
    @ExpectedFamilyGuid = backup_set.family_guid,
    @ExpectedDatabaseGuid = backup_set.database_guid,
    @ExpectedFirstLsn = backup_set.first_lsn,
    @ExpectedLastLsn = backup_set.last_lsn,
    @ExpectedCheckpointLsn = backup_set.checkpoint_lsn,
    @ExpectedBackupSize = backup_set.backup_size,
    @ExpectedBackupFinishDate = backup_set.backup_finish_date,
    @ExpectedBackupPosition = backup_set.position,
    @ExpectedMediaSetId = backup_set.media_set_id
FROM msdb.dbo.backupset AS backup_set
JOIN msdb.dbo.backupmediafamily AS media_family
  ON media_family.media_set_id = backup_set.media_set_id
WHERE backup_set.database_name = @RetainedSourceDatabase
  AND backup_set.type = N'D'
  AND backup_set.is_copy_only = 1
  AND backup_set.has_backup_checksums = 1
  AND backup_set.backup_set_uuid = @ApprovedBackupSetGuid
  AND media_family.physical_device_name COLLATE DATABASE_DEFAULT =
      @SeedBackupFile COLLATE DATABASE_DEFAULT
ORDER BY backup_set.backup_finish_date DESC, backup_set.backup_set_id DESC;

IF @ExpectedBackupSetGuid IS NULL
BEGIN
    THROW 51330,
        'No trusted checksum/copy-only msdb identity exists for the configured seed path.',
        1;
END;

SELECT @ExpectedMediaFamilyCount = COUNT(*)
FROM msdb.dbo.backupmediafamily
WHERE media_set_id = @ExpectedMediaSetId;

IF @ExpectedMediaFamilyCount <> 1 OR @ExpectedBackupPosition <> 1
BEGIN
    THROW 51331,
        'The trusted seed identity is not a single-device, position-1 backup set.',
        1;
END;

/*
An earlier guarded attempt can fail after creating the session-local header
table. Remove only this script-owned temporary object so the same reviewed
batch is repeatable in a retained SSMS session.
*/
DROP TABLE IF EXISTS #SeedBackupHeader;

CREATE TABLE #SeedBackupHeader
(
    BackupName nvarchar(128) NULL,
    BackupDescription nvarchar(255) NULL,
    BackupType smallint NULL,
    ExpirationDate datetime NULL,
    Compressed bit NULL,
    Position smallint NULL,
    DeviceType tinyint NULL,
    UserName nvarchar(128) NULL,
    ServerName nvarchar(128) NULL,
    DatabaseName nvarchar(128) NULL,
    DatabaseVersion int NULL,
    DatabaseCreationDate datetime NULL,
    BackupSize numeric(20,0) NULL,
    FirstLSN numeric(25,0) NULL,
    LastLSN numeric(25,0) NULL,
    CheckpointLSN numeric(25,0) NULL,
    DatabaseBackupLSN numeric(25,0) NULL,
    BackupStartDate datetime NULL,
    BackupFinishDate datetime NULL,
    SortOrder smallint NULL,
    CodePage smallint NULL,
    UnicodeLocaleId int NULL,
    UnicodeComparisonStyle int NULL,
    CompatibilityLevel tinyint NULL,
    SoftwareVendorId int NULL,
    SoftwareVersionMajor int NULL,
    SoftwareVersionMinor int NULL,
    SoftwareVersionBuild int NULL,
    MachineName nvarchar(128) NULL,
    Flags int NULL,
    BindingID uniqueidentifier NULL,
    RecoveryForkID uniqueidentifier NULL,
    Collation nvarchar(128) NULL,
    FamilyGUID uniqueidentifier NULL,
    HasBulkLoggedData bit NULL,
    IsSnapshot bit NULL,
    IsReadOnly bit NULL,
    IsSingleUser bit NULL,
    HasBackupChecksums bit NULL,
    IsDamaged bit NULL,
    BeginsLogChain bit NULL,
    HasIncompleteMetaData bit NULL,
    IsForceOffline bit NULL,
    IsCopyOnly bit NULL,
    FirstRecoveryForkID uniqueidentifier NULL,
    ForkPointLSN numeric(25,0) NULL,
    RecoveryModel nvarchar(60) NULL,
    DifferentialBaseLSN numeric(25,0) NULL,
    DifferentialBaseGUID uniqueidentifier NULL,
    BackupTypeDescription nvarchar(60) NULL,
    BackupSetGUID uniqueidentifier NULL,
    CompressedBackupSize bigint NULL,
    Containment tinyint NULL,
    KeyAlgorithm nvarchar(32) NULL,
    EncryptorThumbprint varbinary(20) NULL,
    EncryptorType nvarchar(32) NULL,
    LastValidRestoreTime datetime NULL,
    TimeZone nvarchar(32) NULL,
    CompressionAlgorithm nvarchar(32) NULL
);

DECLARE @HeaderSql nvarchar(max) =
    N'RESTORE HEADERONLY FROM DISK = N'''
    + REPLACE(@SeedBackupFile, N'''', N'''''')
    + N''' WITH CHECKSUM;';

INSERT #SeedBackupHeader
EXEC sys.sp_executesql @HeaderSql;

IF (SELECT COUNT(*) FROM #SeedBackupHeader) <> 1
BEGIN
    THROW 51332,
        'The configured seed must contain exactly one backup set.',
        1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM #SeedBackupHeader AS actual
    WHERE actual.BackupType = 1
      AND actual.Position = @ExpectedBackupPosition
      AND actual.DatabaseName COLLATE DATABASE_DEFAULT =
          @RetainedSourceDatabase COLLATE DATABASE_DEFAULT
      AND actual.HasBackupChecksums = 1
      AND actual.IsCopyOnly = 1
      AND actual.IsDamaged = 0
      AND actual.BackupSetGUID = @ExpectedBackupSetGuid
      AND actual.FamilyGUID = @ExpectedFamilyGuid
      AND actual.BindingID = @ExpectedDatabaseGuid
      AND actual.FirstLSN = @ExpectedFirstLsn
      AND actual.LastLSN = @ExpectedLastLsn
      AND actual.CheckpointLSN = @ExpectedCheckpointLsn
      AND actual.BackupSize = @ExpectedBackupSize
      AND actual.BackupFinishDate = @ExpectedBackupFinishDate
)
BEGIN
    THROW 51333,
        'The seed file header does not match its trusted msdb backup identity.',
        1;
END;

RESTORE VERIFYONLY
FROM DISK = @SeedBackupFile
WITH CHECKSUM;

IF EXISTS
(
    SELECT 1
    FROM sys.databases AS snapshot_db
    JOIN sys.databases AS source_db
      ON source_db.database_id = snapshot_db.source_database_id
    WHERE source_db.name = @TargetDatabase
)
BEGIN
    THROW 51325,
        'A database snapshot references the benchmark target; remove or reconcile it before restore.',
        1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.databases AS snapshot_db
    JOIN sys.databases AS source_db
      ON source_db.database_id = snapshot_db.source_database_id
    WHERE snapshot_db.name = @RetainedSnapshot
      AND snapshot_db.state_desc = N'ONLINE'
      AND source_db.name = @RetainedSourceDatabase
)
BEGIN
    THROW 51326,
        'The retained source snapshot is not online; this workflow must not consume or replace it.',
        1;
END;

IF
(
    SELECT COUNT(*)
    FROM sys.master_files
    WHERE database_id = DB_ID(@RetainedSourceDatabase)
) <> 2
OR
(
    SELECT COUNT(*)
    FROM sys.master_files
    WHERE database_id = DB_ID(@RetainedSourceDatabase)
      AND type_desc = N'ROWS'
) <> 1
OR
(
    SELECT COUNT(*)
    FROM sys.master_files
    WHERE database_id = DB_ID(@RetainedSourceDatabase)
      AND type_desc = N'LOG'
) <> 1
BEGIN
    THROW 51327,
        'Unexpected retained-source file layout; expected exactly one ROWS and one LOG file.',
        1;
END;

DECLARE
    @DataLogicalName sysname,
    @LogLogicalName sysname,
    @SourceDataPath nvarchar(4000),
    @SourceLogPath nvarchar(4000),
    @TargetDataPath nvarchar(4000),
    @TargetLogPath nvarchar(4000);

SELECT
    @DataLogicalName = name,
    @SourceDataPath = physical_name
FROM sys.master_files
WHERE database_id = DB_ID(@RetainedSourceDatabase)
  AND type_desc = N'ROWS';

SELECT
    @LogLogicalName = name,
    @SourceLogPath = physical_name
FROM sys.master_files
WHERE database_id = DB_ID(@RetainedSourceDatabase)
  AND type_desc = N'LOG';

SET @TargetDataPath =
    LEFT(
        @SourceDataPath,
        LEN(@SourceDataPath)
            - CHARINDEX(N'\', REVERSE(@SourceDataPath)) + 1
    )
    + @TargetDatabase + N'.mdf';

SET @TargetLogPath =
    LEFT(
        @SourceLogPath,
        LEN(@SourceLogPath)
            - CHARINDEX(N'\', REVERSE(@SourceLogPath)) + 1
    )
    + @TargetDatabase + N'_log.ldf';

IF @TargetDataPath IN (@SourceDataPath, @SourceLogPath)
   OR @TargetLogPath IN (@SourceDataPath, @SourceLogPath)
BEGIN
    THROW 51328,
        'Computed benchmark file paths collide with retained-source files.',
        1;
END;

DECLARE @RestoreStartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @PriorRestoreHistoryId int =
    ISNULL
    (
        (
            SELECT MAX(restore_history.restore_history_id)
            FROM msdb.dbo.restorehistory AS restore_history
            WHERE restore_history.destination_database_name
                      COLLATE DATABASE_DEFAULT =
                  @TargetDatabase COLLATE DATABASE_DEFAULT
        ),
        0
    );

IF DB_ID(@TargetDatabase) IS NOT NULL
BEGIN
    DECLARE @SingleUserSql nvarchar(max) =
        N'ALTER DATABASE ' + QUOTENAME(@TargetDatabase)
        + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
    EXEC sys.sp_executesql @SingleUserSql;
END;

BEGIN TRY
    DECLARE @RestoreSql nvarchar(max) =
        N'RESTORE DATABASE ' + QUOTENAME(@TargetDatabase)
        + N' FROM DISK = @BackupFile'
        + N' WITH REPLACE, CHECKSUM, RECOVERY,'
        + N' MOVE @DataLogical TO @DataPath,'
        + N' MOVE @LogLogical TO @LogPath, STATS = 5;';

    /*
    RESTORE MOVE does not accept parameter markers for logical/path values,
    so quote only values obtained from guarded metadata and fixed settings.
    */
    SET @RestoreSql =
        N'RESTORE DATABASE ' + QUOTENAME(@TargetDatabase)
        + N' FROM DISK = N'''
        + REPLACE(@SeedBackupFile, N'''', N'''''')
        + N''' WITH REPLACE, CHECKSUM, RECOVERY, MOVE N'''
        + REPLACE(@DataLogicalName, N'''', N'''''')
        + N''' TO N'''
        + REPLACE(@TargetDataPath, N'''', N'''''')
        + N''', MOVE N'''
        + REPLACE(@LogLogicalName, N'''', N'''''')
        + N''' TO N'''
        + REPLACE(@TargetLogPath, N'''', N'''''')
        + N''', STATS = 5;';

    EXEC sys.sp_executesql @RestoreSql;

    DECLARE @MultiUserSql nvarchar(max) =
        N'ALTER DATABASE ' + QUOTENAME(@TargetDatabase)
        + N' SET MULTI_USER;';
    EXEC sys.sp_executesql @MultiUserSql;
END TRY
BEGIN CATCH
    IF DB_ID(@TargetDatabase) IS NOT NULL
    BEGIN
        DECLARE @RecoveryMultiUserSql nvarchar(max) =
            N'ALTER DATABASE ' + QUOTENAME(@TargetDatabase)
            + N' SET MULTI_USER;';
        BEGIN TRY
            EXEC sys.sp_executesql @RecoveryMultiUserSql;
        END TRY
        BEGIN CATCH
            PRINT N'Benchmark restore failed and MULTI_USER recovery also failed.';
        END CATCH;
    END;
    THROW;
END CATCH;

/*
The pre-restore HEADERONLY/VERIFYONLY checks reject a substituted file before
target mutation. Bind the completed restore to the same trusted msdb backup
set as well, so a file replacement in the narrow verification-to-restore
window cannot authorize later benchmark procedure execution.
*/
DECLARE
    @ActualRestoreHistoryId int,
    @ActualRestoredBackupSetId int,
    @ActualRestoredBackupSetGuid uniqueidentifier,
    @ActualRestoredTargetDatabaseGuid uniqueidentifier,
    @ActualRestoredFamilyGuid uniqueidentifier;

SELECT TOP (1)
    @ActualRestoreHistoryId = restore_history.restore_history_id,
    @ActualRestoredBackupSetId = restore_history.backup_set_id,
    @ActualRestoredBackupSetGuid = backup_set.backup_set_uuid
FROM msdb.dbo.restorehistory AS restore_history
JOIN msdb.dbo.backupset AS backup_set
  ON backup_set.backup_set_id = restore_history.backup_set_id
WHERE restore_history.destination_database_name COLLATE DATABASE_DEFAULT =
      @TargetDatabase COLLATE DATABASE_DEFAULT
  AND restore_history.restore_type = N'D'
  AND restore_history.restore_history_id > @PriorRestoreHistoryId
ORDER BY restore_history.restore_history_id DESC;

SELECT
    @ActualRestoredTargetDatabaseGuid = recovery_status.database_guid,
    @ActualRestoredFamilyGuid = recovery_status.family_guid
FROM sys.database_recovery_status AS recovery_status
WHERE recovery_status.database_id = DB_ID(@TargetDatabase);

IF @ActualRestoreHistoryId IS NULL
   OR @ActualRestoredBackupSetId IS NULL
   OR @ActualRestoredBackupSetId <> @ExpectedBackupSetId
   OR @ActualRestoredBackupSetGuid IS NULL
   OR @ActualRestoredBackupSetGuid <> @ExpectedBackupSetGuid
   /*
   The restored target has its own database_guid. It is not the source
   backup's HEADERONLY BindingID when the backup is restored under the
   benchmark database name. Require a materialized target identity, while
   binding the consumed backup through restorehistory and the stable family.
   */
   OR @ActualRestoredTargetDatabaseGuid IS NULL
   OR @ActualRestoredFamilyGuid IS NULL
   OR @ActualRestoredFamilyGuid <> @ExpectedFamilyGuid
BEGIN
    THROW 51334,
        'The completed restore does not match the trusted msdb backup identity.',
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

DECLARE @VerifySql nvarchar(max) = N'
USE ' + QUOTENAME(@TargetDatabase) + N';

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
    @VerifySql,
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
   OR @LiveReferenceCount <> 0
   OR @TestReferenceCount <> 3
BEGIN
    THROW 51329,
        'The restored benchmark database failed row/scan/path verification.',
        1;
END;

SELECT
    N'update_all2_benchmark_restore' AS EvidenceSection,
    @TargetDatabase AS TargetDatabase,
    @SeedBackupFile AS SeedBackupFile,
    @TargetDataPath AS TargetDataPath,
    @TargetLogPath AS TargetLogPath,
    @RestoreStartedAtUtc AS RestoreStartedAtUtc,
    @PriorRestoreHistoryId AS PriorRestoreHistoryId,
    SYSUTCDATETIME() AS RestoreFinishedAtUtc,
    CONVERT(
        decimal(19,3),
        DATEDIFF_BIG(
            microsecond,
            @RestoreStartedAtUtc,
            SYSUTCDATETIME()
        ) / 1000.0
    ) AS RestoreDurationMs,
    @Ks4Rows AS Ks4Rows,
    @Ks5Rows AS Ks5Rows,
    @Ks4MaxScan AS Ks4MaxScan,
    @Ks5MaxScan AS Ks5MaxScan,
    @LiveReferenceCount AS LivePathReferenceCount,
    @TestReferenceCount AS TestPathReferenceCount,
    @DefinitionHash AS ImportProcedureSha256,
    @ExpectedBackupSetGuid AS VerifiedBackupSetGUID,
    @ApprovedBackupSetGuid AS ApprovedBackupSetGUID,
    @ActualRestoreHistoryId AS VerifiedRestoreHistoryId,
    @ActualRestoredBackupSetId AS VerifiedRestoredBackupSetId,
    @ActualRestoredBackupSetGuid AS VerifiedRestoredBackupSetGUID,
    @ActualRestoredTargetDatabaseGuid AS RestoredTargetDatabaseGUID,
    @ActualRestoredFamilyGuid AS VerifiedRestoredFamilyGUID,
    @ExpectedFamilyGuid AS VerifiedFamilyGUID,
    @ExpectedDatabaseGuid AS VerifiedSourceBackupBindingID,
    @ExpectedFirstLsn AS VerifiedFirstLSN,
    @ExpectedLastLsn AS VerifiedLastLSN,
    @ExpectedCheckpointLsn AS VerifiedCheckpointLSN,
    @ExpectedBackupSize AS VerifiedBackupSize,
    @ExpectedBackupFinishDate AS VerifiedBackupFinishDate,
    @ExpectedBackupPosition AS VerifiedBackupPosition,
    @ExpectedMediaFamilyCount AS VerifiedBackupMediaFamilyCount,
    CONVERT(bit, 1) AS RestoreVerifyOnlyPassed,
    CONVERT(bit, 0) AS BenchmarkSnapshotPresent,
    @RetainedSnapshot AS RetainedSourceSnapshot;

DROP TABLE IF EXISTS #SeedBackupHeader;
