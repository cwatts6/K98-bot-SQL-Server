"""One sealed two-generation report/capture proof in the isolated DB16 fixture."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def private_spool(manifest):
    from core.export_execution_host import current_sid
    from core.export_startup_windows import (
        _attributes,
        administrative_path,
        create_private_directory,
    )
    import win32file

    stamp = Path(manifest["guest_directory"]).name
    root = Path(r"C:\Program Files") / ("K98-P02-" + stamp)
    if str(root) != manifest["private_directory"] or root.exists():
        raise ValueError("Fresh exact private capture root required")
    administrative_path(root.parent, private=False)
    sid = current_sid()
    win32file.CreateDirectory(str(root), _attributes(sid, directory=True))
    administrative_path(root, private=True)
    create_private_directory(root / "spool", sid)
    return dict(path=str(root), sid=sid, spool=str(root / "spool"), existing_acls_changed=False)


def require_post_business(connection, manifest, before, cases):
    from independent_readers import query
    from producer_fixture import (
        FRESH_ACCOUNT,
        ORIGINAL_PREPARATIONS,
        REPORT_COUNT_SQL,
        RESOURCE_SQL,
    )

    if (
        query(connection, ORIGINAL_PREPARATIONS, manifest["account"], manifest["account"])
        != before["original_preparations"]
    ):
        raise ValueError("An original preparation changed")
    rows = query(connection, FRESH_ACCOUNT, manifest["account"])
    count = len(cases)
    if count not in (1, 2) or (
        count == 1 and (manifest.get("capture_indices") != [2] or cases[0].get("index") != 2)
    ):
        raise ValueError("Exact declared capture operation count required")
    if len(rows) != count or any(
        r["State"] != "captured" or r["StorageOwner"] != manifest["storage_owner"] for r in rows
    ):
        raise ValueError("Exactly the declared fresh captured generations required")
    expected = [case["preparation_id"] for case in cases]
    if [str(r["PreparationID"]).lower() for r in rows] != expected:
        raise ValueError("Fresh preparation identities or order differ")
    resource = query(connection, RESOURCE_SQL, "account:" + manifest["account"])
    if len(resource) != 2 or any(
        r["blocked"]
        or any(
            r[k] is not None
            for k in ("ActiveJobID", "ActivePreparationID", "ActiveOutputOperationID", "OwnerID")
        )
        for r in resource
    ):
        raise ValueError("Original generation still owns a durable resource")
    global_row = next(r for r in resource if r["ResourceKey"] == "sql_snapshot:legacy_outputs")
    original = before["owners"]["resource"][0]
    if (
        global_row["Version"] != original["Version"] + 2 * count
        or global_row["Fence"] <= original["Fence"]
    ):
        raise ValueError("Global resource does not show the acknowledged claim/release pairs")
    report = query(connection, REPORT_COUNT_SQL)
    if len(report) != 1 or report[0]["report_rows"] != before["header"][0]["OutputRowCount"]:
        raise ValueError("Actual report row count differs from genuine source header")
    return dict(
        preparations=rows, resources=resource, report=report, original_preparations_unchanged=True
    )


def dependency_preflight():
    """Resolve actual business/capture and refusal-path imports before mutation."""
    from importlib import import_module

    names = (
        "player_stats_cache",
        "gsheet_module",
        "services.player_report_sql",
        "services.application_observation_admission",
        "services.legacy_snapshot_admission",
        "services.sql_lock_holder_diagnostics",
        "services.export_sql_health_dal",
        "services.import_capture_recovery_dal",
        "services.export_legacy_grid_identity",
        "services.legacy_export_snapshot_dal",
        "services.legacy_export_snapshot_service",
        "services.export_snapshot_store",
        "services.stats_import_outcome_service",
        "services.upload_outcome_service",
        "core.export_startup_windows",
    )
    for name in names:
        import_module(name)
    return dict(imported=list(names), sql_dispatched=False, business_dispatched=False)


def parent(packet, manifest, prior):
    from configured_reader import refusal_facts
    import fixed_contract_cost as cost
    from independent_readers import query, state, write_new
    import producer_fixture as fixture
    import producer_pair as pair
    import pyodbc
    from scripts.verify_k98_running_release import sql_error_facts
    import three_contracts as control

    record = dict(
        schema="p02-producer-capture/1",
        outcome="running",
        stage="preflight",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        restore_replayed=False,
        migration_replayed=False,
        setup_replayed=False,
        original_publications_replayed=False,
        provider_operations=0,
        production_operations=0,
        runtime_published=False,
        protected_seed_issued=False,
        enable_attempted=False,
        login_disabled=None,
        admin_connections_closed=0,
        cases=[],
        snapshot_attempted=False,
    )
    admin = None

    def save():
        pending = packet / "progress.pending"
        pending.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        pending.replace(packet / "progress.json")

    try:
        record["dependencies"] = dependency_preflight()
        admin = pyodbc.connect(
            "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
            "DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;Trusted_Connection=yes;"
            "APP=P02CaptureOwner;",
            autocommit=True,
            timeout=3,
        )
        admin.timeout = 3
        record["before"], record["master_before"] = state(admin, prior)
        record["login_disabled"] = True
        agent = [
            r
            for r in query(admin, cost.SERVICES_SQL)
            if r["servicename"] == "SQL Server Agent (MSSQLSERVER)"
        ]
        if (
            len(agent) != 1
            or agent[0]["status_desc"] != "Stopped"
            or agent[0]["startup_type_desc"] != "Disabled"
        ):
            raise ValueError("Agent must remain stopped and disabled")
        record["preflight"] = fixture.preflight(admin, packet, manifest, prior)
        record["stage"] = "preserve fresh pre-business DB16 snapshot"
        record["snapshot_attempted"] = True
        save()
        record["snapshot"] = fixture.create_snapshot(admin, manifest)
        record["stage"] = "create fresh private immutable spool"
        save()
        record["private_fixture"] = private_spool(manifest)
        write_new(
            packet / "stage-1.json",
            dict(
                preflight=record["preflight"],
                snapshot=record["snapshot"],
                private_fixture=record["private_fixture"],
            ),
        )
        record["enable_attempted"] = True
        record["login_disabled"] = None
        save()
        query(admin, control.ENABLE)
        record["login_disabled"] = False
        for index in (1, 2):
            record["stage"] = "fresh report/capture order " + str(index)
            case = {}
            record["cases"].append(case)
            pair.run_pair(packet, manifest, admin, index, case, save)
            case["report_after"] = query(admin, fixture.REPORT_VALUE_SQL)
            save()
        if record["cases"][0]["report_after"] != record["cases"][1]["report_after"]:
            raise ValueError("Two fresh report generations produced different business rows")
        record["stage"] = "independent next consumer read"
        consumer = pair.launch(packet, "consumer", 1)
        held = dict(
            stage="original consumer retained",
            children=[dict(pid=consumer["process"].pid, role="consumer")],
        )
        record["consumer_process"] = held
        pair.settle(packet, manifest, [consumer], held, save)
        value = json.loads((packet / "stage-8.json").read_bytes())
        if (
            consumer["exit_code"] != 0
            or held.get("cleanup_failures")
            or value.get("outcome") != "passed"
            or value.get("pid") != consumer["process"].pid
        ):
            raise ValueError("Independent consumer did not verify retained generations")
        record["consumer"] = value
        record["stage"] = "verify exact durable generation post-state"
        record["business_after"] = require_post_business(
            admin, manifest, record["preflight"], record["cases"]
        )
        write_new(packet / "stage-9.json", record["business_after"])
        record["functional_capture_passed"] = True
        record["both_engine_orders_passed"] = all(
            c["simultaneous_running_or_runnable"] and c.get("first_request_observed")
            for c in record["cases"]
        )
        record["reader_batch_cost_passed"] = all(
            json.loads((packet / f"stage-{n}.json").read_bytes())["maximum_batch_seconds"] <= 0.250
            for n in (3, 6)
        )
        record["outcome"] = (
            "completed_without_full_engine_overlap"
            if not record["both_engine_orders_passed"]
            else "completed_with_cost_miss" if not record["reader_batch_cost_passed"] else "passed"
        )
        record["stage"] = "two real reports/captures and next consumer verified"
    except BaseException as error:
        record["outcome"] = "failed"
        record["first_failure"] = dict(stage=record["stage"], **sql_error_facts(error))
        record["failure_chain"] = refusal_facts(error)
    finally:
        if admin is not None:
            if record["enable_attempted"]:
                try:
                    query(admin, control.DISABLE)
                    record["login_disabled"] = True
                except BaseException as error:
                    record["cleanup_failures"].append(
                        dict(operation="disable application login", **sql_error_facts(error))
                    )
            if record["login_disabled"]:
                try:
                    record["after"], record["master_after"] = state(admin, prior)
                except BaseException as error:
                    record["cleanup_failures"].append(
                        dict(operation="retained SQL state", **sql_error_facts(error))
                    )
            try:
                record["fresh_preparations_observed"] = query(
                    admin, fixture.FRESH_ACCOUNT, manifest["account"]
                )
                record["resources_observed"] = query(
                    admin, fixture.RESOURCE_SQL, "account:" + manifest["account"]
                )
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="durable outcome read", **sql_error_facts(error))
                )
            try:
                admin.close()
                record["admin_connections_closed"] = 1
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="administrative close", **sql_error_facts(error))
                )
        if record["cleanup_failures"]:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        write_new(packet / "receipt.json", record)
    return (
        0
        if record["outcome"]
        in ("passed", "completed_with_cost_miss", "completed_without_full_engine_overlap")
        else 1
    )


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["purpose"] != "fresh-report-capture-and-consumer"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated producer qualification required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed qualification member changed")
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    from producer_fixture import PRIOR_PATH, PRIOR_SHA, require_prior

    raw = (packet / "evidence/latest-state.json").read_bytes()
    if sha(raw) != PRIOR_SHA or Path(PRIOR_PATH).read_bytes() != raw:
        raise ValueError("Original completed boundary evidence changed")
    prior = json.loads(raw)
    require_prior(prior)
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    if len(sys.argv) == 1:
        return parent(packet, manifest, prior)
    if len(sys.argv) != 5 or sys.argv[1] != "--role" or sys.argv[3] != "--index":
        raise ValueError("Exact original child entry required")
    role, index = sys.argv[2], int(sys.argv[4])
    if (
        role not in ("producer", "reader", "consumer")
        or index not in (1, 2)
        or (role == "consumer" and index != 1)
    ):
        raise ValueError("Unknown child role or case")
    from producer_runtime import run_role

    return run_role(packet, manifest, prior, role, index)


def guarded_main():
    try:
        return main()
    except BaseException as error:
        try:
            sys.stderr.write(
                json.dumps(
                    dict(
                        outcome="failed",
                        error_type=type(error).__name__,
                        detail="Retain original progress and ownership; no replay permitted.",
                    )
                )
                + "\n"
            )
        except BaseException:
            pass
        return 1


if __name__ == "__main__":
    raise SystemExit(guarded_main())
