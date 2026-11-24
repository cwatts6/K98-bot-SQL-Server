"""Preserve the completed reader/cost/source fixtures around the new L1 work.

No completed producer, maintenance worker, restore or reader-cost gate is replayed.
"""

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import zipfile

READER = Path("Q:/P02Observer/20261123101535375")
READER_SHA = "fb955a12371f7083a16090e6a87dce8b765298337572b1e3e727525e753fea43"
READER_LAUNCH_SHA = "84ab2c99cf3234a4b1ca520bc35bff53d6f604864771fa07ae9696c8a68ca51e"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def context(packet):
    import cost_fixture_state
    import cost_reader_completion as completed
    from cost_resume import preservation_context

    raw = (packet / "evidence/completed-reader/receipt.json").read_bytes()
    launch_raw = (packet / "evidence/completed-reader/launch-result.json").read_bytes()
    if (
        sha(raw) != READER_SHA
        or raw != (READER / "receipt.json").read_bytes()
        or sha(launch_raw) != READER_LAUNCH_SHA
    ):
        raise ValueError("Exact final reader receipt and launch required")
    reader = json.loads(raw)
    launch = json.loads(launch_raw)
    if (
        reader.get("outcome") != "passed"
        or reader.get("first_failure") is not None
        or reader.get("cleanup_failures")
        or reader.get("physical_custody_retained") is not False
        or reader.get("original_preserved") is not True
        or reader.get("original_name_restored") is not True
        or reader.get("login_disabled") is not True
        or reader.get("reader_cost_passed") is not True
        or reader.get("admin_connections_closed") != 25
        or reader.get("name_transition_uncertain") is not False
        or launch.get("state") != "exited"
        or launch.get("exitCode") != 0
        or launch.get("path") != str(READER)
        or launch.get("PSComputerName") != "K98-MGE-Qualification-20261029"
    ):
        raise ValueError("Completed reader did not settle successfully")
    with zipfile.ZipFile(completed.PRIOR / "packet.zip") as archive:
        original = json.loads(archive.read("manifest.json"))
    cost = completed.authenticate(packet, original)
    expected, source = cost_fixture_state.context(packet, original)
    expected = preservation_context(expected, reader)
    bindings = json.loads((packet / "evidence/cost-ready/restore-bindings.json").read_bytes())[
        "fixtures"
    ]
    return dict(
        reader=reader,
        original=original,
        cost=cost,
        expected=expected,
        source=source,
        bindings=bindings,
    )


def observe(packet, record, save, ctx, *, fixture=None, acknowledged_names=None):
    """Compare complete preserved business evidence, allowing only new acknowledged identity."""
    import cost_fixture_state
    from cost_pair_control import adjusted_preservation
    import cost_reader_completion as completed
    from cost_readiness import logical_differences

    expected = deepcopy(ctx["expected"])
    wanted = deepcopy(ctx["reader"]["after"])
    if acknowledged_names is not None:
        expected = adjusted_preservation(expected, acknowledged_names)
        date = next(r["create_date"] for r in acknowledged_names.current if r["database_id"] == 18)
        for row in wanted["databases"]:
            if row["database_id"] == 18:
                row["create_date"] = date
    if fixture is not None:
        if fixture["database_id"] != 27 or any(
            r["database_id"] == 27 for r in expected[0]["databases_after"]
        ):
            raise ValueError("Only the acknowledged new DB27 may extend preservation")
    value = cost_fixture_state.observe(
        packet,
        ctx["original"],
        "after",
        record,
        save,
        expected,
        ctx["source"],
        ctx["bindings"],
        extra_fixture=fixture,
    )
    if value != wanted or record["new_fixtures"] != ctx["reader"]["new_fixtures"]:
        raise ValueError("Original claim, publications, captures or fixture identities changed")
    copies = completed.copies(packet, ctx["original"], ctx["cost"], record, save)
    prior = ctx["reader"]["cost_after"]
    if copies["state"] != prior["state"] or any(
        logical_differences(a, b) for a, b in zip(copies["copies"], prior["copies"], strict=True)
    ):
        raise ValueError(
            "Completed cost outputs, captures, histories or observer generation changed"
        )
    return dict(
        original=value, cost_state=copies["state"], completed_reader_receipt_sha256=READER_SHA
    )


def main():
    from datetime import UTC, datetime
    import os
    import re
    import sys
    import time

    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    stamp = packet.name
    if (
        len(sys.argv) not in (2, 3)
        or sys.argv[1] not in ("before", "after")
        or os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != "p02-poststate-capture-chain"
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or not re.fullmatch(r"[0-9]{17}", stamp)
        or packet != Path(manifest["guest_directory"])
        or manifest.get("databases") != ["K98_P02CaptureChain_" + stamp]
    ):
        raise ValueError("Exact fresh capture-chain preservation packet required")
    for name, digest in manifest["files"].items():
        source = (packet / name).resolve()
        if not source.is_relative_to(packet) or sha(source.read_bytes()) != digest:
            raise ValueError("Sealed capture-chain source differs")
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    from cost_execution import blank, writer
    from fresh_business_owner import HELD
    from fresh_business_state import DATABASES, normalized
    from independent_readers import write_new
    from publisher_baseline import owned

    from scripts.verify_k98_running_release import sql_error_facts

    root = packet / sys.argv[1]
    root.mkdir(exist_ok=False)
    record = blank("preserve accepted fixtures")
    record.update(
        workload_copies=[],
        production_operations=0,
        business_operations=0,
        maintenance_dispatches=0,
        restores=0,
        migrations=0,
        backups=0,
    )
    save = writer(root, record)
    write_new(root / "entered.json", dict(pid=os.getpid(), phase=sys.argv[1]))
    safe = False
    try:
        fixture = None
        if sys.argv[1] == "after":
            raw = (packet / "restore-bindings.json").read_bytes()
            if len(sys.argv) != 3 or sha(raw) != sys.argv[2]:
                raise ValueError("Acknowledged original restore binding required")
            bindings = json.loads(raw)["fixtures"]
            if (
                len(bindings) != 1
                or bindings[0]["database_id"] != 27
                or bindings[0]["name"] != manifest["databases"][0]
            ):
                raise ValueError("Only the new restricted DB27 may be observed")
            with owned("master", record, save) as owner:
                rows = normalized(owner.read(DATABASES))
            fixture = next(r for r in rows if r["database_id"] == 27)
            if (
                str(fixture["database_guid"]).lower() != bindings[0]["database_guid"].lower()
                or fixture["name"] != bindings[0]["name"]
                or fixture["user_access_desc"] != "RESTRICTED_USER"
            ):
                raise ValueError("Restored physical fixture differs from its acknowledgement")
        elif len(sys.argv) != 2:
            raise ValueError("Before observation cannot accept a restore binding")
        record["preserved"] = observe(packet, record, save, context(packet), fixture=fixture)
        if sys.argv[1] == "before":
            from cost_workload_binding import NAMES, owned_copy
            from poststate_chain import capture_cases

            cases = capture_cases(manifest)
            with owned_copy(NAMES[0], record, save) as owner:
                if manifest["capture_route"] == "player_report":
                    cases.prerequisites(owner, record, save)
                    record["legacy_kvk_capture_qualified"] = False
                else:
                    record["genuine_kvk_source"] = owner.read(cases.KVK_PREFLIGHT)
                    cases.require_kvk_source(record["genuine_kvk_source"])
        record["fixture"] = fixture
        record.update(outcome="passed", stage="complete retained state verified")
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        safe = not HELD
        record["physical_custody_retained"] = not safe
        if not safe or record["cleanup_failures"]:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        try:
            save()
            write_new(root / "receipt.json", record)
        finally:
            # Evidence storage failure cannot terminate an uncertain physical owner.
            while not safe:
                time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
