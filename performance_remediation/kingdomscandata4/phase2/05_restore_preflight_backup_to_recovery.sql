/*
KingdomScanData4 Phase 2 representative recovery restore.

This script restores the verified preflight copy-only backup to a new,
separately named non-production database. It never uses WITH REPLACE and
refuses every protected database name.

Edit only the confirmation values in a local execution copy.
*/
USE [master];
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ConfirmSourceDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK';
DECLARE @ConfirmRecoveryDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY';
DECLARE @ConfirmRunId uniqueidentifier =
    '00000000-0000-0000-0000-000000000000';
DECLARE @ExecuteRestore bit = 0;

DECLARE @StartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @BackupPath nvarchar(4000);
DECLARE @BackupVerified bit;
DECLARE @ReceiptDatabase sysname;
DECLARE @ReceiptStatus varchar(16);
DECLARE @ReceiptSql nvarchar(max);

IF @ExecuteRestore <> 1
    THROW 51700, 'Recovery restore is disabled. Set @ExecuteRestore = 1 only in a reviewed local execution copy.', 1;

IF @ConfirmRunId = '00000000-0000-0000-0000-000000000000'
    THROW 51701, 'Set @ConfirmRunId to the exact verified preflight run ID.', 1;

IF @ConfirmSourceDatabase <> N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK'
    THROW 51702, 'The representative recovery script requires the exact benchmark source database.', 1;

IF @ConfirmRecoveryDatabase <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY'
    THROW 51703, 'The representative recovery script requires the exact separately named recovery database.', 1;

IF @ConfirmSourceDatabase IN
   (
       N'ROK_TRACKER',
       N'ROK_TRACKER_BACKUP_TEST_KS4',
       N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE'
   )
   OR @ConfirmRecoveryDatabase IN
   (
       N'ROK_TRACKER',
       N'ROK_TRACKER_BACKUP_TEST_KS4',
       N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE',
       N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK'
   )
    THROW 51704, 'A protected production, source, snapshot, or benchmark database name was supplied.', 1;

IF DB_ID(@ConfirmSourceDatabase) IS NULL
    THROW 51705, 'The exact benchmark source database does not exist.', 1;

IF DB_ID(@ConfirmRecoveryDatabase) IS NOT NULL
    THROW 51706, 'The separately named recovery database already exists; this script will not replace or drop it.', 1;

SET @ReceiptSql =
    N'SELECT
          @BackupPathOut = BackupPath,
          @BackupVerifiedOut = BackupVerified,
          @ReceiptDatabaseOut = DatabaseName,
          @ReceiptStatusOut = Status
      FROM ' + QUOTENAME(@ConfirmSourceDatabase)
      + N'.dbo.KS4_Phase2_PreflightState
      WHERE RunId = @RunId;';

EXEC sys.sp_executesql
    @ReceiptSql,
    N'@RunId uniqueidentifier,
      @BackupPathOut nvarchar(4000) OUTPUT,
      @BackupVerifiedOut bit OUTPUT,
      @ReceiptDatabaseOut sysname OUTPUT,
      @ReceiptStatusOut varchar(16) OUTPUT',
    @RunId = @ConfirmRunId,
    @BackupPathOut = @BackupPath OUTPUT,
    @BackupVerifiedOut = @BackupVerified OUTPUT,
    @ReceiptDatabaseOut = @ReceiptDatabase OUTPUT,
    @ReceiptStatusOut = @ReceiptStatus OUTPUT;

IF @BackupPath IS NULL
   OR @BackupVerified <> 1
   OR @ReceiptDatabase <> @ConfirmSourceDatabase
   OR @ReceiptStatus NOT IN ('PASS', 'FORWARD_PASS', 'VERIFIED')
    THROW 51707, 'The matching verified preflight backup receipt is missing or ineligible.', 1;

RESTORE VERIFYONLY
FROM DISK = @BackupPath
WITH CHECKSUM;

RESTORE HEADERONLY
FROM DISK = @BackupPath;

CREATE TABLE #FileList
(
    LogicalName nvarchar(128) NOT NULL,
    PhysicalName nvarchar(260) NOT NULL,
    [Type] char(1) NOT NULL,
    FileGroupName nvarchar(128) NULL,
    Size numeric(20, 0) NOT NULL,
    MaxSize numeric(20, 0) NOT NULL,
    FileId bigint NOT NULL,
    CreateLSN numeric(25, 0) NULL,
    DropLSN numeric(25, 0) NULL,
    UniqueID uniqueidentifier NOT NULL,
    ReadOnlyLSN numeric(25, 0) NULL,
    ReadWriteLSN numeric(25, 0) NULL,
    BackupSizeInBytes bigint NOT NULL,
    SourceBlockSize int NOT NULL,
    FileGroupId int NOT NULL,
    LogGroupGUID uniqueidentifier NULL,
    DifferentialBaseLSN numeric(25, 0) NULL,
    DifferentialBaseGUID uniqueidentifier NULL,
    IsReadOnly bit NOT NULL,
    IsPresent bit NOT NULL,
    TDEThumbprint varbinary(32) NULL,
    SnapshotURL nvarchar(360) NULL
);

DECLARE @FileListSql nvarchar(max) =
    N'RESTORE FILELISTONLY FROM DISK = N'''
    + REPLACE(@BackupPath, N'''', N'''''') + N''';';

INSERT #FileList
EXEC (@FileListSql);

IF (SELECT COUNT(*) FROM #FileList WHERE [Type] = 'D' AND IsPresent = 1) <> 1
   OR (SELECT COUNT(*) FROM #FileList WHERE [Type] = 'L' AND IsPresent = 1) <> 1
   OR EXISTS (SELECT 1 FROM #FileList WHERE [Type] NOT IN ('D', 'L') AND IsPresent = 1)
    THROW 51708, 'The approved rehearsal restore requires exactly one data file and one log file.', 1;

DECLARE @DataLogicalName sysname =
    (SELECT LogicalName FROM #FileList WHERE [Type] = 'D' AND IsPresent = 1);
DECLARE @LogLogicalName sysname =
    (SELECT LogicalName FROM #FileList WHERE [Type] = 'L' AND IsPresent = 1);
DECLARE @DefaultDataPath nvarchar(260) =
    CONVERT(nvarchar(260), SERVERPROPERTY('InstanceDefaultDataPath'));
DECLARE @DefaultLogPath nvarchar(260) =
    CONVERT(nvarchar(260), SERVERPROPERTY('InstanceDefaultLogPath'));

IF @DefaultDataPath IS NULL OR @DefaultLogPath IS NULL
    THROW 51709, 'SQL Server instance default data or log path is unavailable.', 1;

IF RIGHT(@DefaultDataPath, 1) NOT IN (N'\', N'/')
    SET @DefaultDataPath += N'\';
IF RIGHT(@DefaultLogPath, 1) NOT IN (N'\', N'/')
    SET @DefaultLogPath += N'\';

DECLARE @DataTarget nvarchar(4000) =
    @DefaultDataPath + @ConfirmRecoveryDatabase + N'.mdf';
DECLARE @LogTarget nvarchar(4000) =
    @DefaultLogPath + @ConfirmRecoveryDatabase + N'_log.ldf';
DECLARE @RestoreSql nvarchar(max) =
    N'RESTORE DATABASE ' + QUOTENAME(@ConfirmRecoveryDatabase)
    + N' FROM DISK = @BackupPath
        WITH MOVE @DataLogicalName TO @DataTarget,
             MOVE @LogLogicalName TO @LogTarget,
             CHECKSUM, RECOVERY, STATS = 10;';

EXEC sys.sp_executesql
    @RestoreSql,
    N'@BackupPath nvarchar(4000),
      @DataLogicalName sysname,
      @DataTarget nvarchar(4000),
      @LogLogicalName sysname,
      @LogTarget nvarchar(4000)',
    @BackupPath = @BackupPath,
    @DataLogicalName = @DataLogicalName,
    @DataTarget = @DataTarget,
    @LogLogicalName = @LogLogicalName,
    @LogTarget = @LogTarget;

IF DB_ID(@ConfirmRecoveryDatabase) IS NULL
    THROW 51710, 'The separately named recovery database was not created.', 1;

SELECT
    N'phase2_recovery_restore_completion' AS EvidenceSection,
    @ConfirmRunId AS RunId,
    @ConfirmSourceDatabase AS SourceDatabase,
    @ConfirmRecoveryDatabase AS RecoveryDatabase,
    @BackupPath AS BackupPath,
    @DataLogicalName AS DataLogicalName,
    @DataTarget AS DataTarget,
    @LogLogicalName AS LogLogicalName,
    @LogTarget AS LogTarget,
    @StartedAtUtc AS StartedAtUtc,
    SYSUTCDATETIME() AS CompletedAtUtc,
    DATEDIFF_BIG(millisecond, @StartedAtUtc, SYSUTCDATETIME()) AS DurationMs,
    N'PASS' AS RestoreStatus;

SELECT
    N'phase2_recovery_filelist' AS EvidenceSection,
    LogicalName,
    PhysicalName AS BackupPhysicalName,
    [Type],
    Size,
    BackupSizeInBytes,
    FileId,
    IsReadOnly,
    IsPresent
FROM #FileList
ORDER BY FileId;

SELECT TOP (1)
    N'phase2_recovery_restore_history' AS EvidenceSection,
    restore_history.destination_database_name,
    restore_history.restore_date,
    restore_history.restore_type,
    restore_history.recovery,
    restore_history.replace,
    backup_set.database_name AS BackupDatabaseName,
    backup_set.backup_start_date,
    backup_set.backup_finish_date,
    backup_set.first_lsn,
    backup_set.last_lsn,
    backup_set.checkpoint_lsn,
    backup_set.database_backup_lsn,
    backup_set.has_backup_checksums
FROM msdb.dbo.restorehistory AS restore_history
JOIN msdb.dbo.backupset AS backup_set
  ON backup_set.backup_set_id = restore_history.backup_set_id
WHERE restore_history.destination_database_name = @ConfirmRecoveryDatabase
ORDER BY restore_history.restore_date DESC;
