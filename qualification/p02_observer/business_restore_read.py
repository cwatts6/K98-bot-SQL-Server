"""Reuse the retained-state owner before/after one separately owned fresh restore."""

import copy
import hashlib
import json
import os
from pathlib import Path
import sys

PREFLIGHT_SHA = "d5b01fe1a785fdb8b47cde510a16a252cfeb62120b63783e234f0889ee3c5f59"
PREFLIGHT_DIRECTORY = "Q:/P02Observer/20261121165621800"
PURPOSE = "fresh-business-baseline-restore"


def expected_state(preflight, original):
    if (
        preflight.get("outcome") != "passed"
        or preflight.get("first_failure") is not None
        or preflight.get("cleanup_failures") != []
        or preflight.get("connections_closed") != 1
        or preflight.get("physical_custody_retained") is not False
        or preflight.get("before") != preflight.get("after")
        or preflight.get("before_differences") != []
        or preflight.get("after_differences") != []
        or preflight.get("persistent_writes") != 0
    ):
        raise ValueError("Exact settled successful backup preflight required")
    state = preflight["after"]
    adjusted = copy.deepcopy(original)
    adjusted.update(
        after=state["database"],
        master_after=state["master"],
        ownership_after=state["ownership"],
        snapshot=state["snapshot"],
        business_hashes_after=state["business_hashes"],
    )
    return adjusted


def probe(read, record):
    import owner_mapping_repair as repair
    import report_failure_read as report
    import restart_read as shared

    packet = Path(__file__).resolve().parents[2]
    modules = json.loads((packet / "evidence/module-baseline.json").read_bytes())
    facts = dict(
        latest_preflight_sha256=PREFLIGHT_SHA,
        database_owner=read(shared.OWNER_SQL),
        modules=read(report.MODULE_SQL),
    )
    record["fresh_restore_preservation"] = facts
    if facts["database_owner"] != repair.expected_owner() or facts["modules"] != modules["modules"]:
        raise ValueError("Original corrected owner or report modules changed")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("before", "after"):
        raise ValueError("One exact preservation phase required")
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("production_eligible") is not False
    ):
        raise ValueError("Exact isolated restore qualification required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if (
            not path.is_relative_to(packet)
            or hashlib.sha256(path.read_bytes()).hexdigest() != digest
        ):
            raise ValueError("Sealed restore qualification member differs")
    raw = (packet / "evidence/business-preflight.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != PREFLIGHT_SHA
        or (Path(PREFLIGHT_DIRECTORY) / "receipt.json").read_bytes() != raw
    ):
        raise ValueError("Original successful backup preflight differs")
    original = json.loads((packet / "evidence/latest-receipt.json").read_bytes())
    modules = json.loads((packet / "evidence/module-baseline.json").read_bytes())
    prior = expected_state(json.loads(raw), original)
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc
    import restart_read as shared

    pyodbc.pooling = False
    phase = packet / sys.argv[1]
    phase.mkdir(exist_ok=False)
    return shared.run(
        phase,
        prior,
        modules,
        diagnostic=probe,
        completion_stage="original database, claim and setup preserved "
        + sys.argv[1]
        + " fresh restore",
    )


if __name__ == "__main__":
    try:
        code = main()
    except BaseException as error:
        sys.stderr.write(json.dumps(dict(outcome="failed", error_type=type(error).__name__)) + "\n")
        code = 1
    raise SystemExit(code)
