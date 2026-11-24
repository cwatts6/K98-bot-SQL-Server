"""Read genuine backup lineage and preserved state before a separate test fixture."""

import copy
from datetime import datetime
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import sys

PURPOSE = "retained-business-fixture-preflight"
CORRECTION_DIRECTORY = "Q:/P02Observer/20261121155755458"
CORRECTION_SHA = "f804d88cebcc390b67616697165877dfdf51a6ac2ce88531e4eb640d6b05582d"
INSTALL_DIRECTORY = "Q:/P02Release/observer-release-20261120194240117"
INSTALL_SHA = "c67fb4d3481575b7556ce7db4af1ee53831c939ec09fdfbe4403915c90023a95"
# PS5.1 saved indented JSON and returned compact JSON; pin both exact forms.
INSTALL_GUEST_SHA = "4596d723430f9d1c056dbd040eccbd2a11ab56bba93efe986f4c2c1c0478dedd"
STOP_DIRECTORY = "Q:/P02Observer/20261121162149242"
STOP_ARCHIVE_SHA = "6c2d6008c6ac770d63c0083aaa040eae397c35848107b8108af747efa55ebbd9"
STOP_STDERR_SHA = "7e958da2ab13c31753a10c7f7e4a0243e94b99633096a98a94474460e7411cc2"
STOP_LAUNCH_SHA = "59b2fedd493039fd771d1bc8dc4e02d06bf8e5ba22d24944ce45c61c30b2d936"
INVENTORY_SHA = "42eb5d74466027c98c1cb99399eaf87d30b5adf673a9161ea4fbf6ab82e5e6a6"
_ENTRY_STAGE = "sealed packet and retained receipt validation"
_ENTRY_FACTS = {}
BACKUP_PATH = "Q:/P02Release/observer-release-20261120194240117/db16-before-observer.bak"
HEADER_SQL = r"RESTORE HEADERONLY FROM DISK=N'Q:\P02Release\observer-release-20261120194240117\db16-before-observer.bak';"
FILES_SQL = r"RESTORE FILELISTONLY FROM DISK=N'Q:\P02Release\observer-release-20261120194240117\db16-before-observer.bak';"
HISTORY_SQL = r"""SELECT b.backup_set_uuid,b.database_name,b.type,b.position,
b.backup_start_date,b.backup_finish_date,b.has_backup_checksums,b.is_damaged,
b.database_guid,b.family_guid,b.is_copy_only
FROM msdb.dbo.backupset b JOIN msdb.dbo.backupmediafamily f ON f.media_set_id=b.media_set_id
WHERE f.physical_device_name=N'Q:\P02Release\observer-release-20261120194240117\db16-before-observer.bak'
ORDER BY b.backup_set_id"""
SOURCE_SQL = """SELECT d.name,d.database_id,d.create_date,
r.database_guid,r.family_guid FROM sys.databases d
JOIN sys.database_recovery_status r ON r.database_id=d.database_id WHERE d.database_id=16"""
VACANT_SQL = "SELECT DB_ID(?) AS database_id"


def require_correction(value, original, baseline):
    import owner_mapping_repair as repair
    import restart_read as shared

    facts = value.get("owner_repair", {})
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("connections_closed") != 1
        or value.get("physical_custody_retained") is not False
        or value.get("persistent_writes") != 1
        or value.get("before_differences") != []
        or value.get("after_differences") != []
        or shared.differences(value["before"], original)
        or repair.compare_after(value, original)
        or facts.get("modules_before") != baseline["modules"]
        or facts.get("modules_after") != baseline["modules"]
        or facts.get("guards_before") != facts.get("guards_after")
        or facts.get("guards_after", {}).get("differences") != []
        or facts.get("locks_after") != [dict(application_lock_count=0)]
    ):
        raise ValueError("Exact committed correction and preserved state required")
    for rows in facts["probes"].values():
        if len(rows) != 1 or rows[0]["error_number"] is not None:
            raise ValueError("Both corrected native probes must have passed")
    shared.require_services(value["services_after"])


def pinned(packet, name, directory, digest):
    raw = (packet / "evidence" / name).read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != digest
        or (Path(directory) / "receipt.json").read_bytes() != raw
    ):
        raise ValueError("Exact retained receipt differs")
    return json.loads(raw)


def current_baseline(packet, original, baseline):
    global _ENTRY_STAGE
    _ENTRY_STAGE = "authenticate committed owner correction"
    # Read and authenticate the latest state; never alter a retained receipt.
    value = pinned(packet, "owner-correction.json", CORRECTION_DIRECTORY, CORRECTION_SHA)
    require_correction(value, original, baseline)
    adjusted = copy.deepcopy(original)
    state = value["after"]
    adjusted.update(
        after=state["database"],
        master_after=state["master"],
        ownership_after=state["ownership"],
        snapshot=state["snapshot"],
        business_hashes_after=state["business_hashes"],
    )
    _ENTRY_STAGE = "initialize existing native dependencies"
    return adjusted, baseline


def before_native(packet, manifest, original, baseline):
    global _ENTRY_STAGE
    _ENTRY_STAGE = "verify previous stop before SQL entry"
    require_previous_stop(packet)
    _ENTRY_STAGE = "authenticate original observer installation receipt"
    raw = (packet / "evidence/observer-installation.json").read_bytes()
    if hashlib.sha256(raw).hexdigest() != INSTALL_SHA:
        raise ValueError("Original host installation receipt differs")
    guest_raw = (Path(INSTALL_DIRECTORY) / "guest-receipt.json").read_bytes()
    _ENTRY_FACTS["installation_receipt"] = dict(
        host_sha256=hashlib.sha256(raw).hexdigest(),
        guest_sha256=hashlib.sha256(guest_raw).hexdigest(),
        host_bytes=len(raw),
        guest_bytes=len(guest_raw),
        expected_guest_sha256=INSTALL_GUEST_SHA,
    )
    if hashlib.sha256(guest_raw).hexdigest() != INSTALL_GUEST_SHA:
        raise ValueError("Original indented guest installation receipt differs")
    install = json.loads(raw)
    if (
        install.get("outcome") != "passed"
        or install.get("observer_committed") is not True
        or install.get("execution_settled") is not True
        or install.get("first_failure") is not None
        or install.get("cleanup_failure") is not None
        or install.get("database_backup", "").replace("\\", "/") != BACKUP_PATH
        or len(install["before"]["history"]) != 105
    ):
        raise ValueError("Genuine completed post-D4 backup source required")
    _ENTRY_STAGE = "validate prospective fixture identity"
    stamp = Path(manifest["guest_directory"]).name
    if (
        len(stamp) != 17
        or not stamp.isdecimal()
        or manifest.get("fresh_database") != "K98_P02Business_" + stamp
    ):
        raise ValueError("Exact prospective fresh database name required")


def require_previous_stop(packet):
    prior = Path(STOP_DIRECTORY)
    facts = dict(directory=STOP_DIRECTORY)
    _ENTRY_FACTS["previous_stop"] = facts
    launch_raw = (packet / "evidence/fixture-preflight-launch.json").read_bytes()
    if hashlib.sha256(launch_raw).hexdigest() != STOP_LAUNCH_SHA:
        raise ValueError("Exact exited preflight launch required")
    facts["launch"] = json.loads(launch_raw)
    facts["archive_sha256"] = hashlib.sha256((prior / "packet.zip").read_bytes()).hexdigest()
    facts["stderr_sha256"] = hashlib.sha256((prior / "stderr.txt").read_bytes()).hexdigest()
    facts["stdout_bytes"] = (prior / "stdout.txt").stat().st_size
    forbidden = ["entered.json", "receipt.json", "progress.json"]
    forbidden += [f"stage-{i}.json" for i in range(1, 11)]
    facts["unexpected_execution_files"] = [name for name in forbidden if (prior / name).exists()]
    if (
        facts["archive_sha256"] != STOP_ARCHIVE_SHA
        or facts["stderr_sha256"] != STOP_STDERR_SHA
        or facts["stdout_bytes"] != 0
        or facts["unexpected_execution_files"]
    ):
        raise ValueError("Prior SQL entry or different refusal observed; preserve it")
    inventory_raw = (packet / "evidence/fixture-host-inventory.json").read_bytes()
    if hashlib.sha256(inventory_raw).hexdigest() != INVENTORY_SHA:
        raise ValueError("Exact completed storage inventory required")
    facts["completed_inventory_sha256"] = INVENTORY_SHA


def write_entry_failure(packet, error):
    # run() writes entered.json before connecting. Never replace its evidence.
    if (packet / "entered.json").exists() or (packet / "receipt.json").exists():
        return False
    value = dict(
        schema="p02-fixture-preflight-entry-failure/1",
        outcome="failed",
        stage=_ENTRY_STAGE,
        first_failure=dict(error_type=type(error).__name__, stage=_ENTRY_STAGE),
        entry_facts=_ENTRY_FACTS,
        sql_dispatches=0,
        connections_closed=0,
        physical_custody_retained=False,
        persistent_writes=0,
        business_operations=0,
        claim_releases=0,
        migrations=0,
        restores=0,
        production_operations=0,
    )
    with (packet / "receipt.json").open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2)
        stream.flush()
        os.fsync(stream.fileno())
    return True


def file_identity(path):
    info = path.lstat()
    if not path.is_file() or path.is_symlink() or getattr(info, "st_file_attributes", 0) & 0x400:
        raise ValueError("Ordinary retained backup file required")
    return dict(bytes=info.st_size, modified_ns=info.st_mtime_ns)


def guid(value):
    from uuid import UUID

    return str(UUID(str(value)))


def allocated_size(value):
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, Decimal))
        or (isinstance(value, Decimal) and not value.is_finite())
        or value <= 0
        or value != int(value)
        or value > 120 * 1024**3
    ):
        raise ValueError("Positive bounded integral SQL file size required")
    return int(value)


def require_backup(facts, install):
    header, files, history, source = (
        facts[key] for key in ("header", "files", "history", "source")
    )
    if not (len(header) == len(history) == len(source) == 1) or len(files) != 2:
        raise ValueError("One genuine backup set, source and two files required")
    h, b, s = header[0], history[0], source[0]
    if (
        h["DatabaseName"] != "ROK_TRACKER"
        or h["BackupType"] != 1
        or h["Position"] != 1
        or not h["HasBackupChecksums"]
        or h["IsDamaged"]
        or b["database_name"] != "ROK_TRACKER"
        or b["type"] != "D"
        or b["position"] != 1
        or not b["has_backup_checksums"]
        or b["is_damaged"]
        or s["name"] != "ROK_TRACKER"
        or s["database_id"] != 16
        or guid(h["BackupSetGUID"]) != guid(b["backup_set_uuid"])
        or guid(h["FamilyGUID"]) != guid(b["family_guid"])
        or guid(b["family_guid"]) != guid(s["family_guid"])
        or guid(b["database_guid"]) != guid(s["database_guid"])
    ):
        raise ValueError("Backup lineage, checksums or retained source differs")
    start = datetime.fromisoformat(install["started"].replace("Z", "+00:00")).replace(tzinfo=None)
    end = datetime.fromisoformat(install["finished"].replace("Z", "+00:00")).replace(tzinfo=None)
    # Backup metadata records whole seconds; the receipt has subsecond precision.
    if not start.replace(microsecond=0) <= h["BackupStartDate"] <= h["BackupFinishDate"] <= end:
        raise ValueError("Backup is outside the completed installation window")
    expected = {"D": "ROK_TRACKER", "L": "ROK_TRACKER_log"}
    allocated = sum(allocated_size(row["Size"]) for row in files)
    if {row["Type"]: row["LogicalName"] for row in files} != expected or allocated > 120 * 1024**3:
        raise ValueError("Expected bounded genuine data/log files required")
    return dict(
        backup_set_guid=guid(h["BackupSetGUID"]),
        required_allocated_bytes=allocated,
        migration_rows_in_source_receipt=105,
        checksum_flag_present=True,
        checksum_verification_ran=False,
        restore_ran=False,
        current_claim_preserved=True,
    )


def probe(read, record):
    import owner_mapping_repair as repair
    import restart_read as shared

    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    install = json.loads((packet / "evidence/observer-installation.json").read_bytes())
    facts = dict(state_baseline_receipt_sha256=CORRECTION_SHA)
    record["fixture_preflight"] = facts
    record["entry_facts"] = copy.deepcopy(_ENTRY_FACTS)
    facts["current_owner"] = read(shared.OWNER_SQL)
    if facts["current_owner"] != repair.expected_owner():
        raise ValueError("Committed owner mapping changed")
    backup = Path(BACKUP_PATH)
    facts["file_before"] = file_identity(backup)
    facts["header"] = read(HEADER_SQL)
    facts["files"] = read(FILES_SQL)
    facts["history"] = read(HISTORY_SQL)
    facts["source"] = read(SOURCE_SQL)
    facts["prospective_database"] = manifest["fresh_database"]
    facts["prospective_name_state"] = read(VACANT_SQL, manifest["fresh_database"])
    if facts["prospective_name_state"] != [dict(database_id=None)]:
        raise ValueError("Prospective fresh name already exists; preserve it")
    facts["assessment"] = require_backup(facts, install)
    facts["file_after"] = file_identity(backup)
    if facts["file_before"] != facts["file_after"]:
        raise ValueError("Backup file changed during metadata reads")


def main():
    global _ENTRY_STAGE
    _ENTRY_STAGE = "sealed packet and retained receipt validation"
    _ENTRY_FACTS.clear()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import restart_read as shared

    return shared.main(
        expected_purpose=PURPOSE,
        before_native=before_native,
        baseline_adapter=current_baseline,
        diagnostic=probe,
        completion_stage="fresh-fixture metadata verified; completed work and original claim preserved",
    )


if __name__ == "__main__":
    try:
        result = main()
    except BaseException as error:
        try:
            write_entry_failure(Path(__file__).resolve().parents[2], error)
        except BaseException:
            pass  # Preserve the original refusal if evidence creation also fails.
        sys.stderr.write(
            json.dumps(
                dict(
                    outcome="failed",
                    error_type=type(error).__name__,
                    detail="Retain fixture-preflight evidence; no restore, setup or business replay.",
                )
            )
            + "\n"
        )
        result = 1
    raise SystemExit(result)
