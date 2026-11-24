"""Resume only the authenticated OFF-complete cost fixture preparation."""

import json
import os
from pathlib import Path
import re
import sys

if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))

import cost_fixture_state as cost

PURPOSE = "p02-complete-matching-cost-fixtures"
STAMP = "20261122130322703"
PRIOR = Path("Q:/P02Observer") / STAMP
PINS = {
    "packet.zip": "f41d8951c79aba38ad648660c1afd3936b95be35e517be64853a3e5b1c3e12d6",
    "guest-receipt.json": "7d6432e273c4ed0ed15f645111bf6eb774730305d6aba30caa6d6ea24d4a2999",
    "storage-receipt.json": "b81f22701ac7775f0b9890b308f7d5cbf12e68c1025f3dadc84684cdb0a32d4f",
    "before/receipt.json": "c89dd9a3268d295ad0c2af296237ff7979032a0afb763ebfc3942e692edff67b",
}


def require_plan(packet, manifest):
    stamp = Path(manifest.get("guest_directory", "")).name
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("production_eligible") is not False
        or not re.fullmatch(r"[0-9]{17}", stamp)
        or manifest.get("guest_directory") != "Q:\\P02Observer\\" + stamp
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
        or manifest.get("fixture_stamp") != STAMP
        or manifest.get("databases") != ["K98_P02Cost_OFF_" + STAMP, "K98_P02Cost_ON_" + STAMP]
        or manifest.get("data_directory") != "S:\\P02Cost_" + STAMP
        or manifest.get("new_disk_bytes") != 256 * 1024**3
        or manifest.get("drive_letter") != "S"
    ):
        raise ValueError("Exact settled cost continuation required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or cost.sha(path.read_bytes()) != digest:
            raise ValueError("Sealed cost continuation differs")


def require_stopped(value):
    if (
        value.get("outcome") != "failed"
        or value.get("cleanup_failure") is not None
        or value.get("execution_settled") is not True
        or value.get("connections_closed") != 1
        or value.get("preservation_connections_closed") != 6
        or value.get("first_failure")
        != {
            "stage": "bind only new OFF database owner",
            "type": "System.Management.Automation.RuntimeException",
            "detail": "Complete baseline content digest unavailable",
        }
        or [(r.get("operation"), r.get("acknowledged")) for r in value.get("actions", [])]
        != [
            ("verify genuine backup checksums once", True),
            ("restore new restricted OFF database", True),
            ("bind only new OFF database owner", True),
        ]
        or len(value.get("fixtures", [])) != 1
    ):
        raise ValueError("Only the exact settled OFF-complete attempt may continue")
    f = value["fixtures"][0]
    if (
        f.get("name") != "K98_P02Cost_OFF_" + STAMP
        or f.get("restore_committed") is not True
        or f.get("owner_committed") is not True
        or len(f.get("history", [])) != 105
        or f.get("observer_objects") != []
        or len(f.get("identity", [])) != 1
        or f["identity"][0]["database_id"] != 25
        or f["identity"][0]["database_guid"].lower() != "ae978926-979d-4dcb-a343-3fab62c82280"
        or [r["table"] for r in f.get("content", [])]
        != [
            "STATS_FOR_UPLOAD",
            "EXCEL_FOR_KVK_16",
            "KVKFinalReportHeader",
            "ProcConfig",
            "MaintenanceWork",
        ]
    ):
        raise ValueError("Acknowledged OFF fixture identity or content differs")
    return f


def authenticate(packet):
    values = {}
    for name, digest in PINS.items():
        raw = (PRIOR / name).read_bytes()
        if cost.sha(raw) != digest:
            raise ValueError("Original cost-stage evidence changed")
        if name.endswith(".json"):
            values[name] = json.loads(raw)
    if (packet / "evidence/cost-stopped.json").read_bytes() != (
        PRIOR / "guest-receipt.json"
    ).read_bytes():
        raise ValueError("Sealed stopped receipt differs")
    for name in ("after", "after.stdout.txt", "restore-bindings.json", "restore-stage-11.json"):
        if (PRIOR / name).exists():
            raise ValueError("Original attempt advanced beyond recorded boundary")
    fixture = require_stopped(values["guest-receipt.json"])
    before = values["before/receipt.json"]
    if (
        before.get("outcome") != "passed"
        or before.get("admin_connections_closed") != 6
        or before.get("first_failure") is not None
        or before.get("cleanup_failures") != []
        or before.get("physical_custody_retained") is not False
        or before.get("original_preserved") is not True
        or before.get("login_disabled") is not True
    ):
        raise ValueError("Original before-state proof did not settle")
    identity = fixture["identity"][0]
    binding = {k: identity[k] for k in ("name", "database_id", "database_guid", "family_guid")}
    binding.update(
        data=fixture["files"][0]["physical_name"], log=fixture["files"][1]["physical_name"]
    )
    return [binding], before


def observe(packet, manifest, phase, record, save, expected, source_result, bindings):
    retained, before = authenticate(packet)
    result = cost.observe(
        packet,
        manifest,
        phase,
        record,
        save,
        expected,
        source_result,
        bindings,
        retained_bindings=retained,
    )
    if result != before["state"]:
        raise ValueError("Original business state changed since completed OFF restore")
    record["prior_before_receipt_sha256"] = PINS["before/receipt.json"]
    record["completed_off_preserved"] = True
    return result


if __name__ == "__main__":
    raise SystemExit(cost.main(plan_checker=require_plan, observer=observe))
