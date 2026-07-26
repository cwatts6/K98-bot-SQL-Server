/*
Purpose:
    Create one guarded pristine database snapshot after the test-only import
    path override has been applied.

Use:
    Run from any database. The CREATE DATABASE statement executes in master.
    This snapshot is for functional tests only, not timed benchmark runs.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SourceDatabase sysname = N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @SnapshotDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
DECLARE @TestRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\';
DECLARE @LiveRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads\';

IF DB_ID(@SourceDatabase) IS NULL
BEGIN
    THROW 51220,
        'Required restored-copy source database does not exist.',
        1;
END;

IF @SourceDatabase = N'ROK_TRACKER'
BEGIN
    THROW 51221,
        'Safety stop: production ROK_TRACKER cannot be a rehearsal snapshot source.',
        1;
END;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
BEGIN
    THROW 51222,
        'Creating the rehearsal snapshot requires a sysadmin session.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51223,
        'Create the rehearsal snapshot with no existing user transaction.',
        1;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE name = @SnapshotDatabase
      AND ISNULL(source_database_id, -1) <> DB_ID(@SourceDatabase)
)
BEGIN
    THROW 51224,
        'A database already uses the configured snapshot name but is not a snapshot of the expected source.',
        1;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE source_database_id = DB_ID(@SourceDatabase)
      AND name <> @SnapshotDatabase
)
BEGIN
    THROW 51225,
        'Another snapshot already exists for the restored copy; remove or reconcile it before creating the rehearsal snapshot.',
        1;
END;

DECLARE @VerifyOverrideSql nvarchar(max) =
    N'USE ' + QUOTENAME(@SourceDatabase) + N';
DECLARE @Definition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N''dbo.IMPORT_STAGING_PROC'', N''P''));

IF @Definition IS NULL
    THROW 51226, ''dbo.IMPORT_STAGING_PROC is missing from the restored copy.'', 1;

IF @Definition LIKE N''%'' + @LiveRoot + N''%''
   OR @Definition NOT LIKE N''%'' + @TestRoot + N''%''
    THROW 51227, ''The isolated import-path override is not active in the restored copy.'', 1;';

EXEC sys.sp_executesql
    @VerifyOverrideSql,
    N'@LiveRoot nvarchar(4000), @TestRoot nvarchar(4000)',
    @LiveRoot = @LiveRoot,
    @TestRoot = @TestRoot;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE name = @SnapshotDatabase
      AND source_database_id = DB_ID(@SourceDatabase)
)
BEGIN
    PRINT 'The guarded rehearsal snapshot already exists.';
END;
ELSE
BEGIN
    DECLARE @SnapshotFileClauses nvarchar(max);

    SELECT
        @SnapshotFileClauses =
            STRING_AGG(
                CONVERT(
                    nvarchar(max),
                    N'(NAME = N'''
                        + REPLACE(files.name, N'''', N'''''')
                        + N''', FILENAME = N'''
                        + REPLACE(
                            paths.DataDirectory
                                + @SnapshotDatabase
                                + N'_'
                                + CONVERT(nvarchar(20), files.file_id)
                                + N'.ss',
                            N'''',
                            N''''''
                        )
                        + N''')'
                ),
                N',' + CHAR(13) + CHAR(10)
            ) WITHIN GROUP (ORDER BY files.file_id)
    FROM sys.master_files AS files
    CROSS APPLY
    (
        SELECT
            LEFT(
                files.physical_name,
                LEN(files.physical_name)
                    - CHARINDEX(N'\', REVERSE(files.physical_name))
                    + 1
            ) AS DataDirectory
    ) AS paths
    WHERE files.database_id = DB_ID(@SourceDatabase)
      AND files.type_desc = N'ROWS';

    IF @SnapshotFileClauses IS NULL
    BEGIN
        THROW 51228,
            'No ROWS data files were found for the restored-copy database.',
            1;
    END;

    DECLARE @CreateSnapshotSql nvarchar(max) =
        N'USE [master];'
        + CHAR(13) + CHAR(10)
        + N'CREATE DATABASE '
        + QUOTENAME(@SnapshotDatabase)
        + N' ON '
        + CHAR(13) + CHAR(10)
        + @SnapshotFileClauses
        + CHAR(13) + CHAR(10)
        + N'AS SNAPSHOT OF '
        + QUOTENAME(@SourceDatabase)
        + N';';

    EXEC sys.sp_executesql @CreateSnapshotSql;
END;

SELECT
    N'update_all2_rehearsal_snapshot' AS EvidenceSection,
    source_db.name AS SourceDatabase,
    snapshot_db.name AS SnapshotDatabase,
    snapshot_db.state_desc AS SnapshotState,
    snapshot_db.create_date AS SnapshotCreatedAt,
    files.name AS SourceLogicalFile,
    files.physical_name AS SnapshotSparseFile
FROM sys.databases AS snapshot_db
JOIN sys.databases AS source_db
  ON source_db.database_id = snapshot_db.source_database_id
JOIN sys.master_files AS files
  ON files.database_id = snapshot_db.database_id
WHERE snapshot_db.name = @SnapshotDatabase
ORDER BY files.file_id;
