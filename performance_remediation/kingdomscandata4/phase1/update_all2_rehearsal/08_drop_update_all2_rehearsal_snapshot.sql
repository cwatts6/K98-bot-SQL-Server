/*
Purpose:
    Guarded cleanup for the disposable UPDATE_ALL2 rehearsal snapshot.

The default confirmation is deliberately off. Dropping the snapshot does not
drop, revert, or otherwise modify the restored-copy source database.
*/

USE [master];
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SourceDatabase sysname = N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @SnapshotDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
DECLARE @ConfirmDropSnapshot bit = 0;

IF @ConfirmDropSnapshot <> 1
BEGIN
    THROW 51260,
        'Safety stop: set @ConfirmDropSnapshot = 1 only when snapshot cleanup is intended.',
        1;
END;

IF @SourceDatabase = N'ROK_TRACKER'
BEGIN
    THROW 51261,
        'Safety stop: the cleanup target cannot be production ROK_TRACKER.',
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
    THROW 51262,
        'The configured snapshot does not exist or is not owned by the expected restored copy.',
        1;
END;

DECLARE @DropSnapshotSql nvarchar(max) =
    N'DROP DATABASE ' + QUOTENAME(@SnapshotDatabase) + N';';

EXEC sys.sp_executesql @DropSnapshotSql;

SELECT
    N'update_all2_rehearsal_snapshot_cleanup' AS EvidenceSection,
    @SourceDatabase AS SourceDatabaseUnaffected,
    @SnapshotDatabase AS DroppedSnapshot,
    SYSUTCDATETIME() AS DroppedAtUtc;
