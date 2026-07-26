/*
Purpose:
    Revert the restored-copy database to the guarded pristine UPDATE_ALL2
    rehearsal snapshot.

Important:
    This resets database state only. Collect/reset the isolated filesystem
    evidence separately before staging the next stats.csv fixture.
*/

USE [master];
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SourceDatabase sysname = N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @SnapshotDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
DECLARE @FunctionalLogSizeMB int = 16384;
DECLARE @FunctionalLogGrowthMB int = 4096;
DECLARE @FunctionalLogMaxSizeMB int = 32768;

IF @SourceDatabase = N'ROK_TRACKER'
BEGIN
    THROW 51240,
        'Safety stop: production ROK_TRACKER cannot be reverted by this script.',
        1;
END;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
BEGIN
    THROW 51241,
        'Reverting the rehearsal database requires a sysadmin session.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51242,
        'Revert the rehearsal database with no existing user transaction.',
        1;
END;

IF DB_ID(@SourceDatabase) IS NULL
BEGIN
    THROW 51243,
        'The configured restored-copy source database does not exist.',
        1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE name = @SnapshotDatabase
      AND source_database_id = DB_ID(@SourceDatabase)
)
BEGIN
    THROW 51244,
        'The configured pristine snapshot does not exist or belongs to another source database.',
        1;
END;

IF
(
    SELECT COUNT(*)
    FROM sys.databases
    WHERE source_database_id = DB_ID(@SourceDatabase)
) <> 1
BEGIN
    THROW 51245,
        'Snapshot revert requires exactly one snapshot for the restored-copy source database.',
        1;
END;

IF
(
    SELECT COUNT(*)
    FROM sys.master_files
    WHERE database_id = DB_ID(@SourceDatabase)
      AND type_desc = N'LOG'
) <> 1
BEGIN
    THROW 51247,
        'Functional log preparation requires exactly one log file on the restored-copy database.',
        1;
END;

DECLARE @LogLogicalName sysname =
(
    SELECT name
    FROM sys.master_files
    WHERE database_id = DB_ID(@SourceDatabase)
      AND type_desc = N'LOG'
);

DECLARE @SetSingleUserSql nvarchar(max) =
    N'ALTER DATABASE '
        + QUOTENAME(@SourceDatabase)
        + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';

DECLARE @RevertSql nvarchar(max) =
    N'RESTORE DATABASE '
        + QUOTENAME(@SourceDatabase)
        + N' FROM DATABASE_SNAPSHOT = N'''
        + REPLACE(@SnapshotDatabase, N'''', N'''''')
        + N''';';

DECLARE @SetMultiUserSql nvarchar(max) =
    N'ALTER DATABASE '
        + QUOTENAME(@SourceDatabase)
        + N' SET MULTI_USER;';

DECLARE @PrepareLogSql nvarchar(max) =
    N'ALTER DATABASE '
        + QUOTENAME(@SourceDatabase)
        + N' MODIFY FILE
(
    NAME = N'''
        + REPLACE(@LogLogicalName, N'''', N'''''')
        + N''',
    SIZE = '
        + CONVERT(nvarchar(20), @FunctionalLogSizeMB)
        + N'MB,
    FILEGROWTH = '
        + CONVERT(nvarchar(20), @FunctionalLogGrowthMB)
        + N'MB,
    MAXSIZE = '
        + CONVERT(nvarchar(20), @FunctionalLogMaxSizeMB)
        + N'MB
);';

BEGIN TRY
    EXEC sys.sp_executesql @SetSingleUserSql;
    EXEC sys.sp_executesql @RevertSql;
    EXEC sys.sp_executesql @SetMultiUserSql;
    EXEC sys.sp_executesql @PrepareLogSql;
END TRY
BEGIN CATCH
    DECLARE @ResetError nvarchar(2048) = ERROR_MESSAGE();

    BEGIN TRY
        IF DB_ID(@SourceDatabase) IS NOT NULL
            EXEC sys.sp_executesql @SetMultiUserSql;
    END TRY
    BEGIN CATCH
        -- Preserve the original reset error.
    END CATCH;

    THROW 51246, @ResetError, 1;
END CATCH;

SELECT
    N'update_all2_rehearsal_reset' AS EvidenceSection,
    database_state.name AS DatabaseName,
    database_state.state_desc AS DatabaseState,
    database_state.user_access_desc AS UserAccess,
    snapshot_state.name AS SnapshotName,
    snapshot_state.state_desc AS SnapshotState,
    log_file.name AS LogicalLogName,
    CONVERT(decimal(19, 2), log_file.size / 128.0) AS LogSizeMB,
    CONVERT(decimal(19, 2), log_file.growth / 128.0) AS LogGrowthMB,
    CASE log_file.max_size
        WHEN -1 THEN NULL
        ELSE CONVERT(decimal(19, 2), log_file.max_size / 128.0)
    END AS LogMaxSizeMB,
    SYSUTCDATETIME() AS ResetCompletedAtUtc,
    N'Database reset only; collect filesystem evidence and stage the next fixture separately.'
        AS OperatorNextStep
FROM sys.databases AS database_state
JOIN sys.databases AS snapshot_state
  ON snapshot_state.source_database_id = database_state.database_id
JOIN sys.master_files AS log_file
  ON log_file.database_id = database_state.database_id
 AND log_file.type_desc = N'LOG'
WHERE database_state.name = @SourceDatabase
  AND snapshot_state.name = @SnapshotDatabase;
