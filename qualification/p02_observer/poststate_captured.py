"""Resume only the retained publication/capture after the settled diagnostic stop."""

import hashlib
import json
from pathlib import Path

TOKEN = "captured-index-diagnosed-20261123170039650"
DIAGNOSTIC = Path("Q:/P02Observer/20261123170039650")
PINS = {
    "integration/receipt.json": "0fab868bf606d6f3dc82c0c09a67cf630b19b2242c849072e12ab2088274659e",
    "integration.launch.json": "6d889dd0c4be9713f19c64cbf5d7a0eac33c2e4d6d23b675a10e5db350f12207",
    "index-diagnostic-before.json": "6501d0beeb035dab25d7f11c7857c4dbd2e94530c4ef3e7912fc738ac3965131",
    "packet.zip": "c91b2c0c36048705235ac606969300aafef8a90479539fd751b7b6fc25dc59ae",
}


def require_diagnostic_stop(record, launch, before, prior, capture):
    """Authenticate the failed observation; never reinterpret it as a passed run."""
    if (
        record.get("outcome") != "failed"
        or record.get("first_failure")
        != dict(
            stage="one temporary transaction-owned guard probe; no DDL",
            error_type="ValueError",
            detail="Diagnostic transaction/guard release remains unconfirmed",
        )
        or record.get("cleanup_failures") != []
        or record.get("physical_custody_retained") is not False
        or record.get("admin_connections_closed") != 2
        or record.get("actions") != []
        or any(
            record.get(key) != 0
            for key in (
                "business_operations",
                "ddl_operations",
                "migration_operations",
                "login_changes",
                "rename_operations",
                "provider_operations",
                "production_operations",
            )
        )
        or launch.get("settled") is not True
        or launch.get("exit_code") != 1
        or launch.get("receipt_sha256") != PINS["integration/receipt.json"]
        or record.get("inventory_before") != prior["name_inventory_after"]
    ):
        raise ValueError("Exact settled read-only diagnostic failure required")
    probe = record.get("probe", [])
    if len(probe) != 1 or probe[0] != dict(
        session_id=62,
        database_id=27,
        database_name="K98_P02CaptureChain_20261123150616134",
        entry_count=0,
        entry_state=0,
        phase="complete",
        output_result=0,
        schema_result=0,
        output_mode="Exclusive",
        schema_mode="Exclusive",
        exit_count=0,
        exit_state=1,
        output_session_mode="NoLock",
        schema_session_mode="NoLock",
        own_application_locks=0,
    ):
        raise ValueError("Exact historical mixed-query result required; no healthy-state inference")
    snapshot = dict(
        capture,
        private_spool=r"C:\Program Files\K98-P02-20261123163556234\spool",
        verified_sha256=capture["snapshot"]["sha256"],
    )
    if record.get("retained_snapshot") != snapshot or before["holders"] or before["indexes"]:
        raise ValueError("Original captured bytes and zero-index state required")
    from cost_workload import require_settled_capture_set
    from poststate_index_diagnostic import require_capture_row

    require_settled_capture_set(before["preparations"], before["resources"], [capture])
    require_capture_row(before["preparations"][0], capture)


def authenticate(packet, manifest):
    import poststate_index_diagnostic as diagnostic
    import poststate_installed

    if manifest.get("continuation") != TOKEN or manifest.get("capture_route") != "player_report":
        raise ValueError("Exact captured player-report continuation required")
    values, old = diagnostic.authenticate(packet, manifest)
    retained = poststate_installed.authenticate(packet, old)
    for key in ("requests", "publisher_operation", "capture_route", "private_directory"):
        if manifest[key] != old[key]:
            raise ValueError("Completed capture identity changed: " + key)
    evidence = {}
    for name, digest in PINS.items():
        raw = (DIAGNOSTIC / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError("Retained diagnostic evidence changed: " + name)
        if name.endswith(".json"):
            evidence[name] = json.loads(raw)
    if (DIAGNOSTIC / "index-diagnostic-after.json").exists():
        raise ValueError("Historical failed diagnostic boundary unexpectedly advanced")
    prior = values["integration/receipt.json"]
    capture = values["chain-workload/receipt.json"]["cases"][0]["capture"]
    require_diagnostic_stop(
        evidence["integration/receipt.json"],
        evidence["integration.launch.json"],
        evidence["index-diagnostic-before.json"],
        prior,
        capture,
    )
    retained.update(
        record=prior,
        installed=prior["coordinator"][0]["result"],
        capture=capture,
        captured_case=values["chain-workload/receipt.json"]["cases"][0],
        publication=values["chain-workload/receipt.json"]["publication"],
        diagnostic=evidence,
        published=values["publisher-after.json"],
    )
    return retained


def previous_names(retained):
    from poststate_continue import previous_names as names

    return names(retained)


def require_live_state(actual, expected):
    from fresh_business_state import normalized

    session = actual["session"]
    if len(session) != 1 or any(
        session[0].get(key) != value
        for key, value in dict(
            database_id=27,
            database_name="K98_P02CaptureChain_20261123150616134",
            transaction_count=0,
            transaction_state=0,
            principal=r"MINI_AMD\K98LabAdmin",
            administrator=1,
            options=22328,
        ).items()
    ):
        raise ValueError("Standalone settled administrative transaction state required")
    # Session ID and the historical mixed-query state are not durable database state.
    if set(actual) != set(expected):
        raise ValueError("Complete retained observation shape required")
    for key in actual:
        if key != "session" and normalized(actual[key]) != expected[key]:
            raise ValueError("Retained publication/capture/ownership changed: " + key)


def verify_retained(record, save, manifest, retained, current):
    from cost_resume import require_history
    import fresh_business_backup as backup
    from fresh_business_state import IDENTITY, normalized, require_identity
    from independent_readers import write_new
    from poststate_index_diagnostic import observe
    from poststate_owner import FILES, owned

    prior = retained["record"]
    if current != prior["name_inventory_after"]:
        raise ValueError("Retained capture database inventory changed")
    with owned("master", record, save) as owner:
        if normalized(owner.read(FILES)) != prior["name_files"]:
            raise ValueError("Retained physical files changed")
    with owned(manifest["databases"][0], record, save, timeout=15) as owner:
        require_identity(owner.read(IDENTITY), manifest["databases"][0], 27)
        owner.read("SET NOCOUNT ON; SET XACT_ABORT ON; SET LOCK_TIMEOUT 1000;")
        actual = observe(owner, manifest)
        write_new(Path(manifest["guest_directory"]) / "captured-resume-before.json", actual)
        require_live_state(actual, retained["diagnostic"]["index-diagnostic-before.json"])
        require_history(
            actual["history"], retained["restore"]["fixtures"][0]["history"], "ON", prior
        )
        for row in prior["reused_fixture_backups"]:
            path = Path(row["path"])
            if path.parent != Path(manifest["backup_directory"]) or (
                backup.file_facts(path) != row["file"]
                or normalized(owner.read(backup.HISTORY_SQL, str(path))) != row["history"]
                or normalized(owner.read(backup.HEADER_SQL, str(path))) != row["header"]
            ):
                raise ValueError("Original verified backup changed")
    record.update(
        retained_publication=retained["publication"],
        retained_capture=retained["capture"],
        reused_fixture_backups=prior["reused_fixture_backups"],
        diagnostic_poststate_reconciled=True,
        publication_replayed=False,
        capture_replayed=False,
    )
    save()


def verify_private(packet, manifest, record, retained):
    from core.export_startup_windows import administrative_path
    from services.export_snapshot_store import ExportSnapshotStore, SnapshotReceipt

    root = administrative_path(Path(manifest["private_directory"]), private=True)
    spool = administrative_path(root / "spool", private=True)
    store = ExportSnapshotStore(spool, manifest["storage_owner"])
    raw = store.read(SnapshotReceipt(**retained["capture"]["snapshot"]))
    verifier = administrative_path(root / "verifier", private=True)
    sealed = packet / "verifier"
    inventory = (sealed / "update-tool.json").read_bytes()
    if hashlib.sha256(inventory).hexdigest() != manifest["verifier_manifest_sha256"]:
        raise ValueError("Original sealed protected verifier differs")
    value = json.loads(inventory)
    for name, digest in {
        **value["files"],
        "update-tool.json": manifest["verifier_manifest_sha256"],
    }.items():
        if Path(name).name != name:
            raise ValueError("Exact protected verifier basename required")
        content = administrative_path(verifier / name, private=True).read_bytes()
        if content != (sealed / name).read_bytes() or hashlib.sha256(content).hexdigest() != digest:
            raise ValueError("Original protected verifier changed")
    record["private_spool"] = dict(
        path=str(root),
        spool=str(spool),
        reused=True,
        existing_acls_changed=False,
        retained_snapshot_sha256=hashlib.sha256(raw).hexdigest(),
    )
    record["protected_verifier"] = dict(
        path=str(verifier),
        reused=True,
        manifest_sha256=manifest["verifier_manifest_sha256"],
        members=len(value["files"]),
    )
