"""Fresh DB18 recovery backups before its genuine canonical observer install."""

from datetime import timedelta
from pathlib import Path
import shutil
from uuid import UUID

PACKET_ROOT = Path(r"Q:\P02Observer")

SPACE_SQL = """SELECT
(SELECT SUM(CONVERT(bigint,FILEPROPERTY(name,'SpaceUsed')))*8192
 FROM sys.database_files WHERE type=0) AS used_data_bytes,
used_log_space_in_bytes AS used_log_bytes FROM sys.dm_db_log_space_usage"""
HISTORY_SQL = """SELECT CONVERT(varchar(36),b.backup_set_uuid) AS backup_set_uuid,
b.database_name,b.type,b.position,b.backup_start_date,b.backup_finish_date,
b.has_backup_checksums,b.is_damaged,b.is_copy_only,
CONVERT(varchar(36),b.database_guid) AS database_guid,
CONVERT(varchar(36),b.family_guid) AS family_guid,f.physical_device_name
FROM msdb.dbo.backupset b JOIN msdb.dbo.backupmediafamily f ON f.media_set_id=b.media_set_id
WHERE f.physical_device_name=? ORDER BY b.backup_set_id"""
HEADER_SQL = "RESTORE HEADERONLY FROM DISK=?;"
STATEMENTS = {
    "full": """IF DB_ID()<>18 OR DB_NAME()<>N'ROK_TRACKER' OR @@TRANCOUNT<>0
 THROW 51976,'Exact fresh DB18 backup owner required.',1;
BACKUP DATABASE [ROK_TRACKER] TO DISK=? WITH COPY_ONLY,COMPRESSION,CHECKSUM,STOP_ON_ERROR;""",
    "log": """IF DB_ID()<>18 OR DB_NAME()<>N'ROK_TRACKER' OR @@TRANCOUNT<>0
 THROW 51976,'Exact fresh DB18 backup owner required.',1;
BACKUP LOG [ROK_TRACKER] TO DISK=? WITH COPY_ONLY,COMPRESSION,CHECKSUM,STOP_ON_ERROR;""",
    "verify": "RESTORE VERIFYONLY FROM DISK=? WITH FILE=1,CHECKSUM,STOP_ON_ERROR;",
}


def file_facts(path):
    stat = path.stat()
    if (
        not path.is_file()
        or path.is_symlink()
        or stat.st_file_attributes & 0x400
        or stat.st_size <= 0
    ):
        raise ValueError("Ordinary nonempty native backup file required")
    return dict(bytes=stat.st_size, modified_ns=stat.st_mtime_ns)


def require_space(rows, free):
    if (
        len(rows) != 1
        or any(
            type(rows[0].get(k)) is not int or rows[0][k] < 0
            for k in ("used_data_bytes", "used_log_bytes")
        )
        or rows[0]["used_data_bytes"] == 0
    ):
        raise ValueError("Measured native backup size required")
    # The full backup can also contain recovery log; allow log space twice.
    required = rows[0]["used_data_bytes"] + 2 * rows[0]["used_log_bytes"] + 20 * 1024**3
    if free < required:
        raise ValueError("Measured uncompressed backups and recovery reserve do not fit")
    return required


def require_backup(history, header, source, kind, path, start, finish):
    if len(history) != 1 or len(header) != 1 or kind not in ("full", "log"):
        raise ValueError("One fresh full/log backup set and native header required")
    b, h = history[0], header[0]
    if (
        b["database_name"] != "ROK_TRACKER"
        or b["type"] != {"full": "D", "log": "L"}[kind]
        or b["physical_device_name"] != str(path)
        or b["position"] != 1
        or b["has_backup_checksums"] is not True
        or b["is_copy_only"] is not True
        or b["is_damaged"] is not False
        or h["DatabaseName"] != "ROK_TRACKER"
        or h["BackupType"] != {"full": 1, "log": 2}[kind]
        or h["Position"] != 1
        or h["HasBackupChecksums"] is not True
        or h["IsCopyOnly"] is not True
        or h["IsDamaged"] is not False
        or UUID(str(h["BackupSetGUID"])) != UUID(b["backup_set_uuid"])
        or UUID(str(h["FamilyGUID"])) != UUID(source["family_guid"])
        or UUID(b["database_guid"]) != UUID(source["database_guid"])
        or UUID(b["family_guid"]) != UUID(source["family_guid"])
    ):
        raise ValueError("Fresh backup checksum or physical database lineage differs")
    earliest = start.replace(microsecond=0)
    latest = finish + timedelta(seconds=1)
    if not (
        earliest <= b["backup_start_date"] <= b["backup_finish_date"] <= latest
        and earliest <= h["BackupStartDate"] <= h["BackupFinishDate"] <= latest
    ):
        raise ValueError("Backup predates or falls outside the owned operation")


def execute_owned(owner, kind, path):
    """A dedicated finite backup call; application and control limits stay intact.

    A driver timeout is a failed/unknown backup, never permission to repeat it.
    SqlOwner keeps any unconfirmed cursor/connection; no later stage is admitted.
    """
    if kind not in STATEMENTS or owner.cursors or owner.close_attempted:
        raise ValueError("Exact settled backup owner required")
    owner.connection.timeout = 240
    try:
        owner.mutate("fresh DB18 backup " + kind, STATEMENTS[kind], str(path))
    finally:
        if not owner.cursors:
            owner.connection.timeout = 3


def prepare(packet, manifest, record, save):
    from fresh_business import require_login
    from fresh_business_owner import SqlOwner
    import fresh_business_state as state
    from independent_readers import write_new

    if packet != Path(manifest["guest_directory"]) or packet.parent != PACKET_ROOT:
        raise ValueError("Exact fresh guest backup directory required")
    paths = {
        "full": packet / "db18-before-observer.bak",
        "log": packet / "db18-before-observer.trn",
    }
    if any(path.exists() for path in paths.values()):
        raise ValueError("Existing backup files must never be overwritten or replayed")
    owner = SqlOwner("ROK_TRACKER", record, save)
    state.require_identity(owner.read(state.IDENTITY), "ROK_TRACKER", 18)
    require_login(owner.read)
    if owner.read(state.SESSIONS) or owner.read(state.LOCKS):
        raise ValueError("Foreign SQL activity prevents fresh backup preparation")
    databases = state.normalized(owner.read(state.DATABASES))
    if (
        databases != record["databases_named"]
        or state.normalized(owner.read(state.FILE_IDENTITIES)) != record["files_before"]
    ):
        raise ValueError("Completed handover changed before fresh backups")
    source = next(row for row in databases if row["database_id"] == 18)
    space = owner.read(SPACE_SQL)
    free = shutil.disk_usage(packet).free
    required = require_space(space, free)
    facts = dict(
        source=source,
        space=space,
        free_before=free,
        required_bytes=required,
        copies=[],
        completed=False,
        existing_files_changed=False,
        backup_deadline_seconds=240,
    )
    record["fresh_backups"] = facts
    for kind, path in paths.items():
        if owner.read(HISTORY_SQL, str(path)):
            raise ValueError("Prior backup history occupies the fresh packet path")
    save()
    for kind, path in paths.items():
        row = dict(
            kind=kind, path=str(path), backup_acknowledged=False, verification_acknowledged=False
        )
        facts["copies"].append(row)
        start = owner.read(state.CLOCK)[0]["local_time"]
        row["started"] = start
        save()
        execute_owned(owner, kind, path)
        row["backup_acknowledged"] = True
        finish = owner.read(state.CLOCK)[0]["local_time"]
        row["finished"] = finish
        row["file_before_verify"] = file_facts(path)
        row["history"] = owner.read(HISTORY_SQL, str(path))
        row["header"] = owner.read(HEADER_SQL, str(path))
        require_backup(row["history"], row["header"], source, kind, path, start, finish)
        save()
        execute_owned(owner, "verify", path)
        row["file_after_verify"] = file_facts(path)
        if row["file_before_verify"] != row["file_after_verify"]:
            raise ValueError("Backup file changed during native checksum verification")
        row["verification_acknowledged"] = True
        save()
    facts["free_after"] = shutil.disk_usage(packet).free
    if facts["free_after"] < 20 * 1024**3:
        raise ValueError("Backup reserve fell below the agreed safety margin")
    owner.close()
    facts["completed"] = True
    save()
    write_new(packet / "fresh-backups.json", facts)
    return facts
