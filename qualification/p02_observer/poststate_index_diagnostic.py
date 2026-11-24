"""Retained DB27 guard diagnosis only; never publish, capture, create DDL or rename."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import zipfile

PURPOSE = "p02-capture-index-diagnostic"
TOKEN = "captured-index-refused-20261123163556234"
PRIOR = Path("Q:/P02Observer/20261123163556234")
PINS = {
    "packet.zip": "2684cd4495c7a64c816d7e2522a2202b4554108f23487e324353e4162852c048",
    "integration/receipt.json": "ffe605edac43205d5e286c516b1e917e981d2a64276608538d48beb8e6254137",
    "integration.launch.json": "d23a85cb22315ea732dfca64e4e001400f4367a7d3492a1b77f69260f7a8614b",
    "chain-workload/receipt.json": "f7eb17c1d1a545d4ed5694b4a818994fccc9a1dbc8076c28ec075a3cf07cf7d9",
    "publisher-before.json": "83d84c36775ca49b2f049d4887b67bd1307f99fd628c6f8376907eac3e3878b3",
    "publisher-after.json": "d621eee455b06bad0d36fe1c1276e67bc017961275b7a76b6113af7be5f5ea12",
    "chain-contracts-0.json": "9b6b1c961582d9721cb48a62b44abeff99842c60477abb0ab45d0c7f5c06e229",
    "restore-bindings.json": "6a1a28edfc2585c42ce316f8a00fd28100107eb29851e2566749d6522bf3bcaa",
}

PROBE = """SET NOCOUNT ON; SET XACT_ABORT ON; SET LOCK_TIMEOUT 1000;
DECLARE @entry_count int=@@TRANCOUNT,@entry_state int=XACT_STATE(),
 @output int=NULL,@schema int=NULL,@phase varchar(16)='entry',
 @output_mode nvarchar(32)=NULL,@schema_mode nvarchar(32)=NULL;
IF DB_ID()<>27 OR DB_NAME()<>N'K98_P02CaptureChain_20261123150616134'
 OR ORIGINAL_LOGIN()<>N'MINI_AMD\\K98LabAdmin' OR IS_SRVROLEMEMBER('sysadmin')<>1
 OR @entry_count<>0 OR @entry_state<>0
 THROW 51976,'Exact settled retained DB27 diagnostic owner required.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 SET @phase='output';
 EXEC @output=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',
  @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @output IN (0,1)
 BEGIN
  SET @phase='schema';
  EXEC @schema=sys.sp_getapplock @Resource=N'K98:maintenance-schema:v1',
   @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 END;
 SET @output_mode=APPLOCK_MODE('public','k98-legacy-output-snapshot','Transaction');
 SET @schema_mode=APPLOCK_MODE('public','K98:maintenance-schema:v1','Transaction');
 IF @output IN (0,1) AND @schema IN (0,1) SET @phase='complete';
 ROLLBACK TRANSACTION;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
-- Observe user transaction state before metadata starts its own statement context.
DECLARE @exit_count int=@@TRANCOUNT,@exit_state int=XACT_STATE();
SELECT @@SPID AS session_id,DB_ID() AS database_id,DB_NAME() AS database_name,
 @entry_count AS entry_count,@entry_state AS entry_state,@phase AS phase,
 @output AS output_result,@schema AS schema_result,@output_mode AS output_mode,
 @schema_mode AS schema_mode,@exit_count AS exit_count,@exit_state AS exit_state,
 APPLOCK_MODE('public','k98-legacy-output-snapshot','Session') AS output_session_mode,
 APPLOCK_MODE('public','K98:maintenance-schema:v1','Session') AS schema_session_mode,
 (SELECT COUNT_BIG(*) FROM sys.dm_tran_locks WHERE request_session_id=@@SPID
  AND resource_type='APPLICATION') AS own_application_locks;"""

SESSION = """DECLARE @count int=@@TRANCOUNT,@state int=XACT_STATE();
SELECT @@SPID AS session_id,DB_ID() AS database_id,DB_NAME() AS database_name,
@count AS transaction_count,@state AS transaction_state,@@OPTIONS AS options,
ORIGINAL_LOGIN() AS principal,IS_SRVROLEMEMBER('sysadmin') AS administrator"""
HOLDERS = """SELECT l.request_session_id,l.request_owner_type,l.request_mode,l.request_status AS lock_status,
l.resource_description,s.login_name,s.host_process_id,s.open_transaction_count,
r.status AS request_status,r.command,r.blocking_session_id,r.wait_type
FROM sys.dm_tran_locks l LEFT JOIN sys.dm_exec_sessions s ON s.session_id=l.request_session_id
LEFT JOIN sys.dm_exec_requests r ON r.session_id=l.request_session_id
WHERE l.resource_database_id=27 AND l.resource_type='APPLICATION'
ORDER BY l.request_session_id,l.resource_description"""
SEQUENCE = """SELECT object_id,create_date,modify_date,CONVERT(bigint,current_value) AS generation,
is_exhausted FROM sys.sequences WHERE name=N'P02ObservationGeneration' AND schema_id=SCHEMA_ID('dbo')"""


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_packet(packet, manifest):
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or not re.fullmatch(r"[0-9]{17}", packet.name)
        or packet != Path(manifest.get("guest_directory", ""))
        or manifest.get("purpose") != PURPOSE
        or manifest.get("continuation") != TOKEN
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("new_disk_bytes") != 0
        or manifest.get("databases") != ["K98_P02CaptureChain_20261123150616134"]
    ):
        raise ValueError("Exact isolated retained-state diagnostic required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed diagnostic member differs")


def require_stop(parent, launch, worker):
    if (
        parent.get("outcome") != "failed"
        or any(
            parent.get(k) is not True
            for k in ("original_preserved", "original_name_restored", "login_disabled")
        )
        or parent.get("cleanup_failures") != []
        or parent.get("physical_custody_retained") is not False
        or parent.get("name_transition_uncertain") is not False
        or parent.get("preservation_failure") is not None
        or launch.get("settled") is not True
        or launch.get("exit_code") != 1
        or launch.get("receipt_sha256") != PINS["integration/receipt.json"]
    ):
        raise ValueError("Settled original capture stop required")
    children = parent.get("children", [])
    if (
        len(children) != 1
        or children[0].get("role") != "workload"
        or children[0].get("settled") is not True
        or children[0].get("exit_code") != 1
        or children[0].get("receipt_sha256") != PINS["chain-workload/receipt.json"]
    ):
        raise ValueError("Exact settled original workload required")
    stages = parent.get("coordinator", [])
    if (
        len(stages) != 1
        or stages[0].get("operation") != "Verify"
        or stages[0].get("acknowledged") is not True
        or stages[0].get("settled") is not True
        or stages[0].get("exit_code") != 0
        or stages[0]["result"].get("state") != "committed"
        or stages[0]["result"]["observation_installation"]["database_id"] != 27
    ):
        raise ValueError("Exact committed observer verification required")
    cases = worker.get("cases", [])
    if (
        worker.get("outcome") != "failed"
        or worker.get("first_failure")
        != dict(
            stage="complete comparator and new report capture with 1 indexes",
            error_type="ProgrammingError",
            sqlstate="42000",
            native_code=51976,
        )
        or worker.get("publication_poststate_verified") is not True
        or worker.get("publication", {}).get("operation_id")
        != "3127f4b3-2c23-40c2-bbab-8e19fd2ff494"
        or any(
            worker["publication"].get(k) is not True
            for k in ("response_acknowledged", "cleanup_acknowledged")
        )
        or worker.get("cleanup_failures") != []
        or worker.get("physical_custody_retained") is not False
        or len(cases) != 2
        or cases[0].get("outcome") != "passed"
        or cases[0].get("writer_closed") is not True
        or cases[0].get("indexes_after") != []
        or cases[1] != dict(index_count=1, outcome="running")
        or worker.get("index_actions")
        != [dict(index="IX_EXCEL_FOR_KVK_16_GovID", acknowledged=False)]
        or any(
            worker.get(k, {}).get(v) is not True
            for k in ("application_cleanup", "operational_cleanup")
            for v in ("safe_to_exit", "all_closed_by_callers")
        )
    ):
        raise ValueError("Completed publication/capture and unacknowledged index required")


def authenticate(packet, manifest):
    values = {}
    for name, digest in PINS.items():
        raw = (PRIOR / name).read_bytes()
        if sha(raw) != digest:
            raise ValueError("Original completed evidence changed: " + name)
        if name.endswith(".json"):
            values[name] = json.loads(raw)
    with zipfile.ZipFile(PRIOR / "packet.zip") as archive:
        old = json.loads(archive.read("manifest.json"))
    for key in (
        "databases",
        "data_directory",
        "backup_directory",
        "account",
        "storage_owner",
        "private_directory",
        "release",
        "credential",
        "verifier_manifest_sha256",
    ):
        if manifest[key] != old[key]:
            raise ValueError("Diagnostic changed retained identity: " + key)
    if (packet / "restore-bindings.json").read_bytes() != (
        PRIOR / "restore-bindings.json"
    ).read_bytes():
        raise ValueError("Original restore binding changed")
    require_stop(
        values["integration/receipt.json"],
        values["integration.launch.json"],
        values["chain-workload/receipt.json"],
    )
    return values, old


def require_capture_row(row, capture):
    wanted = capture["snapshot"]
    if (
        str(row["PreparationID"]).lower() != capture["preparation_id"]
        or row["State"] != "captured"
        or row["StorageOwner"] != wanted["storage_owner"]
        or row["SpoolKey"] != wanted["key"]
        or row["SpoolBytes"] != wanted["byte_count"]
        or row["SpoolHash"] != wanted["sha256"]
        or json.loads(row["GenerationJson"]) != capture["generation"]
    ):
        raise ValueError("Exact completed capture registration changed")


def require_probe(rows):
    if len(rows) != 1:
        raise ValueError("One consumed guard-probe result required")
    row = rows[0]
    if (
        row["database_id"] != 27
        or row["entry_count"] != 0
        or row["entry_state"] != 0
        or row["exit_count"] != 0
        or row["exit_state"] != 0
        or row["own_application_locks"] != 0
        or row["output_session_mode"] != "NoLock"
        or row["schema_session_mode"] != "NoLock"
    ):
        raise ValueError("Diagnostic transaction/guard release remains unconfirmed")
    if row["phase"] not in ("output", "schema", "complete"):
        raise ValueError("Unknown diagnostic phase")
    successful = row["output_result"] in (0, 1) and row["schema_result"] in (0, 1)
    if row["phase"] == "complete":
        if not successful or row["output_mode"] != "Exclusive" or row["schema_mode"] != "Exclusive":
            raise ValueError("Successful guard result lacks original exclusive ownership")
    elif row["phase"] == "output":
        if row["output_result"] not in (-999, -3, -2, -1) or row["schema_result"] is not None:
            raise ValueError("Output refusal result differs")
    elif row["output_result"] not in (0, 1) or row["schema_result"] not in (-999, -3, -2, -1):
        raise ValueError("Schema refusal result differs")
    return successful


def observe(owner, manifest):
    from cost_resume import HISTORY
    from poststate_cases import INDEXES
    from producer_fixture import FRESH_ACCOUNT, ORIGINAL_PREPARATIONS, RESOURCE_SQL
    from publisher_state import HEADER_SQL, OBJECT_SQL, OUTPUT_SQL
    from recovery_coexistence import KVK_SQL, MAINTENANCE_SQL

    return dict(
        session=owner.read(SESSION),
        holders=owner.read(HOLDERS),
        sequence=owner.read(SEQUENCE),
        indexes=owner.read(INDEXES),
        history=owner.read(HISTORY),
        headers=owner.read(HEADER_SQL),
        output=owner.read(OUTPUT_SQL),
        incarnation=owner.read(OBJECT_SQL),
        work=owner.read(MAINTENANCE_SQL),
        kvk=owner.read(KVK_SQL),
        preparations=owner.read(FRESH_ACCOUNT, manifest["account"]),
        resources=owner.read(RESOURCE_SQL, "account:" + manifest["account"]),
        original_preparations=owner.read(
            ORIGINAL_PREPARATIONS, manifest["account"], manifest["account"]
        ),
    )


def run(packet, manifest, binding_sha):
    from cost_execution import blank, writer
    from cost_resume import require_history
    from cost_workload import require_settled_capture_set
    from fresh_business import require_login
    from fresh_business_owner import HELD
    from fresh_business_state import DATABASES, IDENTITY, normalized, require_identity
    from independent_readers import write_new
    from poststate_owner import FILES, bind_fixture, owned

    from core.export_startup_windows import administrative_path
    from scripts.verify_k98_running_release import sql_error_facts
    from services.export_snapshot_store import ExportSnapshotStore, SnapshotReceipt

    values, old = authenticate(packet, manifest)
    bind_fixture(packet, old, binding_sha)
    prior = values["integration/receipt.json"]
    capture = values["chain-workload/receipt.json"]["cases"][0]["capture"]
    root = packet / "integration"
    root.mkdir(exist_ok=False)
    record = blank("authenticate retained publication and capture")
    record.update(
        provider_operations=0,
        production_operations=0,
        business_operations=0,
        ddl_operations=0,
        migration_operations=0,
        login_changes=0,
        rename_operations=0,
    )
    save = writer(root, record)
    write_new(root / "entered.json", dict(pid=os.getpid(), purpose=PURPOSE))
    safe = False
    before = None
    try:
        with owned("master", record, save) as owner:
            require_login(owner.read)
            inventory = normalized(owner.read(DATABASES))
            files = normalized(owner.read(FILES))
        if inventory != prior["name_inventory_after"] or files != prior["name_files"]:
            raise ValueError("Retained database inventory or file identity changed")
        record["inventory_before"] = inventory
        spool = administrative_path(Path(old["private_directory"]) / "spool", private=True)
        store = ExportSnapshotStore(spool, old["storage_owner"])
        data = store.read(SnapshotReceipt(**capture["snapshot"]))
        record["retained_snapshot"] = dict(
            capture, private_spool=str(spool), verified_sha256=sha(data)
        )
        with owned(old["databases"][0], record, save, timeout=15) as owner:
            require_identity(owner.read(IDENTITY), old["databases"][0], 27)
            record["original_connection_state"] = owner.read(SESSION)
            owner.read("SET NOCOUNT ON; SET XACT_ABORT ON; SET LOCK_TIMEOUT 1000;")
            before = observe(owner, old)
            write_new(packet / "index-diagnostic-before.json", before)
            require_settled_capture_set(before["preparations"], before["resources"], [capture])
            require_capture_row(before["preparations"][0], capture)
            if (
                before["indexes"]
                or normalized(before["original_preparations"]) != prior["original_preparations"]
            ):
                raise ValueError("Index/capture work advanced beyond the retained boundary")
            published = values["publisher-after.json"]
            for key in ("headers", "output", "incarnation", "kvk"):
                if normalized(before[key]) != published[key]:
                    raise ValueError("Completed publisher state differs: " + key)
            history = json.loads((packet / "evidence/backup-baseline.json").read_bytes())["history"]
            require_history(before["history"], history, "ON", prior)
            record["stage"] = "one temporary transaction-owned guard probe; no DDL"
            save()
            record["probe"] = owner.read(PROBE)
            record["guards_available"] = require_probe(record["probe"])
            save()
            after = observe(owner, old)
            write_new(packet / "index-diagnostic-after.json", after)
            if normalized(before) != normalized(after):
                raise ValueError("Retained state or observed owners changed during diagnosis")
        if store.read(SnapshotReceipt(**capture["snapshot"])) != data:
            raise ValueError("Original capture changed during diagnosis")
        with owned("master", record, save) as owner:
            require_login(owner.read)
            if (
                normalized(owner.read(DATABASES)) != inventory
                or normalized(owner.read(FILES)) != files
            ):
                raise ValueError("Physical inventory changed during diagnosis")
        record.update(
            outcome="passed",
            stage="retained state and separate guard results recorded",
            original_name_restored=True,
            login_disabled=True,
            retained_capture_unchanged=True,
            no_publication_or_capture_replayed=True,
        )
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        safe = not HELD
        record.update(physical_custody_retained=not safe, finished=datetime.now(UTC).isoformat())
        if not safe or record["cleanup_failures"]:
            record["outcome"] = "failed"
        try:
            save()
            write_new(root / "receipt.json", record)
        finally:
            while not safe:
                time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    require_packet(packet, manifest)
    if len(sys.argv) != 2 or sys.argv[1] != PINS["restore-bindings.json"]:
        raise ValueError("Exact original restore-binding hash required")
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    return run(packet, manifest, sys.argv[1])


if __name__ == "__main__":
    raise SystemExit(main())
