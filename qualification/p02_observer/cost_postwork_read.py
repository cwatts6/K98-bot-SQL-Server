"""Read-only reconciliation of the first committed cost warm-up; never replay it."""

from copy import deepcopy
from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import zipfile

PURPOSE = "p02-cost-postwork-reconciliation"
PRIOR = Path(r"Q:\P02Observer\20261122213134190")
ARCHIVE_SHA = "d82aaa55df6ae6385b7babcd10950e39539602ddce56f0174619e96a1fd8c688"
LAUNCH_SHA = "bfa078d5e92accdc7e94412fc020908411cb4ffc7b6929ec8a736317b1fbcbcb"
PINS = {
    "receipt.json": "455fe50354a983238b6e6e16a61709116f984911a13f1aafb4a65211a6eb584f",
    "cost-evidence/00-OFF-workload/receipt.json": "af5c5fefbdb89b57a22829eb11802d23ceebe3f2b164001854bf9fb4bcfd5e67",
    "cost-evidence/00-OFF-workload/bound-contracts.json": "8d5f7700ebe19cfb7225216b5e2d83380ed1cfafb24378847a63e67594b2b95a",
}
MAINTENANCE_MODULES = (
    "usp_update_stats",
    "usp_RunMaintenance",
    "usp_MaintenanceImport",
    "usp_MaintenanceConfiguration",
    "usp_MaintenancePlayerReport",
    "usp_MaintenanceKvkOutput",
    "usp_MaintenanceFinalStats",
    "usp_MaintenancePostImport",
)
ERRORS = "SELECT COUNT_BIG(*) AS rows,MAX(ErrorTime) AS latest FROM dbo.ErrorAudit"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_packet(packet, manifest):
    from cost_workload_binding import NAMES

    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or tuple(manifest.get("databases", [])) != NAMES
        or manifest.get("data_directory") != r"S:\P02Cost_20261122130322703"
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
        or any(
            manifest.get(k) != 0
            for k in (
                "business_operations",
                "maintenance_dispatches",
                "migrations",
                "renames",
                "restores",
                "backups",
                "provider_operations",
            )
        )
        or manifest.get("enable_application_login") is not False
        or manifest.get("prior_receipt_sha256") != PINS["receipt.json"]
    ):
        raise ValueError("Exact isolated read-only postwork reconciliation required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed postwork diagnostic member changed")


def require_latest(latest, child):
    if (
        latest.get("outcome") != "failed"
        or latest.get("first_failure", {}).get("stage") != "paired actual workload 1 OFF"
        or latest.get("admin_connections_closed") != 31
        or latest.get("cleanup_failures") != []
        or latest.get("preservation_failure") is not None
        or any(
            latest.get(k) is not True
            for k in ("original_preserved", "original_name_restored", "login_disabled")
        )
        or any(
            latest.get(k) is not False
            for k in (
                "physical_custody_retained",
                "name_transition_uncertain",
                "measured_cost_accepted",
            )
        )
        or latest.get("pairs") != []
        or len(latest.get("children", [])) != 1
        or latest["children"][0].get("settled") is not True
        or latest["children"][0].get("exit_code") != 1
        or latest["children"][0].get("receipt_sha256")
        != PINS["cost-evidence/00-OFF-workload/receipt.json"]
        or len(latest.get("actions", [])) != 14
        or any(a.get("acknowledged") is not True for a in latest["actions"])
        or len(latest.get("coordinator", [])) != 1
        or latest["coordinator"][0].get("operation") != "Verify"
        or latest["coordinator"][0].get("acknowledged") is not True
    ):
        raise ValueError("Exact settled parent and preserved original work required")
    prep = latest.get("statistics_preparation", [])
    if len(prep) != 2 or any(
        x.get("acknowledged") is not True or x.get("verified") is not True for x in prep
    ):
        raise ValueError("Both completed statistics preparations must remain preserved")
    if prep[0]["sequence_after"] != [] or prep[1]["sequence_after"][0]["generation"] != 2:
        raise ValueError("Exact prepared observer generation required")
    clean = child.get("physical_cleanup", {})
    if (
        child.get("outcome") != "failed"
        or child.get("first_failure")
        != dict(
            stage="release cost due-state guard",
            error_type="ValueError",
            detail="Bounded single administrative result required",
        )
        or child.get("cleanup_failures") != []
        or child.get("credential_environment_cleared") is not True
        or child.get("physical_custody_retained") is not False
        or not clean.get("safe_to_exit")
        or not clean.get("all_closed_by_callers")
        or clean.get("connections") != [dict(closed_by_caller=True, cleanup_close=False)] * 15
        or len(child.get("cases", [])) != 1
    ):
        raise ValueError("Exact settled first warm-up failure required")
    case = child["cases"][0]
    if (
        case.get("phase") != "warmup"
        or case.get("mode") != "OFF"
        or case.get("pair") != 1
        or case.get("admin_connections_closed") != 3
        or case.get("preparation_id") != "919038c2-8f13-42a6-bf3c-fe88e18fee46"
        or case.get("writer_closed") is not True
        or case.get("generation", {}).get("capture") != "complete"
        or case.get("generation", {}).get("completion") != "committed"
        or case.get("actions", [])[-1] != dict(stage="actual cost maintenance", acknowledged=False)
        or any(a.get("acknowledged") is not True for a in case["actions"][:-1])
    ):
        raise ValueError(
            "Committed names/report/capture and unresolved maintenance must remain retained"
        )
    return case


def authenticate(packet):
    from cost_statistics_resume import authenticate as earlier, host_launch

    completed, _, _, _ = earlier(packet)
    values = {}
    for name, digest in PINS.items():
        raw = (PRIOR / name).read_bytes()
        if sha(raw) != digest:
            raise ValueError("Original cost work evidence changed")
        values[name] = json.loads(raw)
    if sha((PRIOR / "packet.zip").read_bytes()) != ARCHIVE_SHA:
        raise ValueError("Original cost work archive changed")
    host_launch(packet, "evidence/cost-postwork/launch-result.json", LAUNCH_SHA, 5044, PRIOR)
    with zipfile.ZipFile(PRIOR / "packet.zip") as archive:
        raw = archive.read("manifest.json")
    if raw != (PRIOR / "manifest.json").read_bytes():
        raise ValueError("Original cost manifest changed")
    old = json.loads(raw)
    latest = values["receipt.json"]
    case = require_latest(latest, values["cost-evidence/00-OFF-workload/receipt.json"])
    return latest, completed, old, case


def verify_capture(rows, resources, old, case):
    from cost_workload import require_settled_capture_set

    require_settled_capture_set(rows, resources, [case])
    row = rows[0]
    snapshot = case["snapshot"]
    if (
        row["StorageOwner"] != old["storage_owner"]
        or row["SpoolKey"] != snapshot["key"]
        or row["SpoolBytes"] != snapshot["byte_count"]
        or row["SpoolHash"] != snapshot["sha256"]
        or json.loads(row["GenerationJson"]) != case["generation"]
    ):
        raise ValueError("Committed capture SQL registration changed")
    return snapshot


def capture_bytes(old, case, snapshot):
    from core.export_startup_windows import administrative_path
    from services.export_snapshot_store import ExportSnapshotStore, SnapshotReceipt
    from services.legacy_export_snapshot_service import LegacySnapshot

    root = administrative_path(Path(old["private_directory"]) / "spool", private=True)
    store = ExportSnapshotStore(root, old["storage_owner"])
    raw = store.read(SnapshotReceipt(**snapshot))
    metadata = LegacySnapshot.load(raw).metadata()
    if (
        metadata["preparation_id"] != case["preparation_id"]
        or metadata["generation"] != case["generation"]
    ):
        raise ValueError("Retained capture metadata changed")
    sections = []
    for section in json.loads(raw)["sections"]:
        item = deepcopy(section)
        item["rows"] = sorted(
            item["rows"], key=lambda r: json.dumps(r, sort_keys=True, separators=(",", ":"))
        )
        sections.append(item)
    digest = sha(json.dumps(sections, sort_keys=True, separators=(",", ":")).encode())
    if digest != case["sections_sha256"] or len(sections) != case["section_count"]:
        raise ValueError("Complete retained capture row multiset changed")
    return dict(
        verified=True,
        preparation_id=case["preparation_id"],
        snapshot=snapshot,
        sections_sha256=digest,
        section_count=len(sections),
        bytes_read=len(raw),
        scope="Read-only SQL registration and immutable typed capture; no consumer admission or delivery",
    )


def run(packet, manifest, latest, completed, old, case):
    import cost_fixture_state as preservation
    import cost_readiness
    import cost_resume
    import cost_workload_binding as binding
    from cost_execution import blank, writer
    from fresh_business_owner import HELD
    from fresh_business_state import normalized
    from independent_readers import write_new
    from producer_fixture import FRESH_ACCOUNT, RESOURCE_SQL

    from scripts.verify_k98_running_release import sql_error_facts

    record = blank("authenticate retained postwork identities")
    record.update(
        original_preserved=False,
        login_disabled=None,
        workload_copies=[],
        diagnostics=[],
        business_operations=0,
        maintenance_dispatches=0,
        migrations=0,
        renames=0,
        restores=0,
        backups=0,
        provider_operations=0,
        login_enable_attempted=False,
        measured_cost_accepted=False,
        prior_receipt_sha256=PINS["receipt.json"],
    )
    save = writer(packet, record)
    before = None
    write_new(packet / "entered.json", dict(pid=os.getpid(), purpose=PURPOSE))
    try:
        expected, source = preservation.context(packet, manifest)
        expected = cost_resume.preservation_context(expected, latest)
        bindings = json.loads((packet / "evidence/cost-ready/restore-bindings.json").read_bytes())[
            "fixtures"
        ]

        def observe():
            value = preservation.observe(
                packet, manifest, "after", record, save, expected, source, bindings
            )
            if value != latest["after"] or record["new_fixtures"] != latest["new_fixtures"]:
                raise ValueError(
                    "Original work, retained claim or restricted copy identities changed"
                )
            return value

        record["before"] = observe()
        before = record["before"]
        workload = json.loads((packet / "workload.json").read_bytes())
        deadline = time.monotonic() + 180
        for index, name in enumerate(binding.NAMES):
            mode = ("OFF", "ON")[index]
            item = dict(database=name, mode=mode, queries={}, maintenance_modules={})
            record["diagnostics"].append(item)
            with binding.owned_copy(name, record, save) as owner:
                owner.connection.timeout = 15
                record["stage"] = "read durable maintenance and capture state " + mode
                save()
                # Durable outcome comes before full data reads; retain it even if a later read refuses.
                for key in (
                    "active",
                    "maintenance",
                    "configuration_work",
                    "kvk_work",
                    "backup_work",
                ):
                    item["queries"][key] = owner.read(binding.QUERIES[key])
                    save()
                if item["queries"]["active"]:
                    raise ValueError("Cost copy has another physical owner")
                item["queries"]["preparations"] = owner.read(FRESH_ACCOUNT, old["account"])
                item["queries"]["resources"] = owner.read(RESOURCE_SQL, "account:" + old["account"])
                item["queries"]["error_audit"] = owner.read(ERRORS)
                item["queries"]["history"] = owner.read(cost_resume.HISTORY)
                item["queries"]["sequence"] = owner.read(cost_resume.SEQUENCE)
                save()
                prior = json.loads((packet / "evidence/cost-ready/guest-receipt.json").read_bytes())
                cost_resume.require_history(
                    item["queries"]["history"], prior["fixtures"][index]["history"], mode, completed
                )
                if (
                    normalized(item["queries"]["sequence"])
                    != latest["statistics_preparation"][index]["sequence_after"]
                ):
                    raise ValueError("Cost copy observer incarnation changed after recorded work")
                if index == 0:
                    snap = verify_capture(
                        item["queries"]["preparations"], item["queries"]["resources"], old, case
                    )
                    record["retained_capture"] = capture_bytes(old, case, snap)
                    save()
                elif item["queries"]["preparations"]:
                    raise ValueError("Unstarted ON account has business work")
                for module in MAINTENANCE_MODULES:
                    item["maintenance_modules"][module] = owner.read(
                        binding.MODULES, "dbo." + module
                    )
                record["stage"] = "inventory all retained cost outputs " + mode
                save()
                binding.read_copy(owner, workload, record, save, deadline)
                item["queries"]["complete_statistics"] = owner.read(cost_readiness.STATISTICS)
                item["queries"]["maintenance_after_reads"] = owner.read(
                    binding.QUERIES["maintenance"]
                )
                item["queries"]["preparations_after_reads"] = owner.read(
                    FRESH_ACCOUNT, old["account"]
                )
                if (
                    item["queries"]["maintenance_after_reads"] != item["queries"]["maintenance"]
                    or item["queries"]["preparations_after_reads"]
                    != item["queries"]["preparations"]
                ):
                    raise ValueError("Durable work changed during read-only reconciliation")
                save()
        record["outcome"] = "passed"
        record["stage"] = "maintenance outcome and completed capture inventoried without replay"
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, (ValueError, TimeoutError)):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        if before is not None and not HELD:
            try:
                record["after"] = observe()
                record.update(original_preserved=True, login_disabled=True)
            except BaseException as error:
                record["preservation_failure"] = sql_error_facts(error)
                record["outcome"] = "failed"
        record["physical_custody_retained"] = bool(HELD)
        if HELD or record["cleanup_failures"]:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        save()
        try:
            write_new(packet / "receipt.json", record)
        finally:
            while HELD:
                time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    require_packet(packet, manifest)
    latest, completed, old, case = authenticate(packet)
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    return run(packet, manifest, latest, completed, old, case)


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(main())
