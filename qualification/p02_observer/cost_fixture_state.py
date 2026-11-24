"""Read-only before/after preservation for two new, restricted cost baselines."""

from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time

PURPOSE = "p02-matching-cost-fixtures"
PRIOR = Path("Q:/P02Observer/20261122123623540")
RECEIPT_SHA = "57003ed1ee27977277438fdea7e53adc07c0156f0d79a3a178ec6aa63e132e81"
ARCHIVE_SHA = "9901169eaa4106de21be5232ba0bfaaa28c48850d406e311f325a732695c9c44"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


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
        or manifest.get("databases") != ["K98_P02Cost_OFF_" + stamp, "K98_P02Cost_ON_" + stamp]
        or manifest.get("data_directory") != "S:\\P02Cost_" + stamp
        or manifest.get("new_disk_bytes") != 256 * 1024**3
        or manifest.get("drive_letter") != "S"
    ):
        raise ValueError("Exact isolated matching-fixture packet required")
    for name, digest in manifest["files"].items():
        p = (packet / name).resolve()
        if not p.is_relative_to(packet) or sha(p.read_bytes()) != digest:
            raise ValueError("Sealed cost-fixture source differs")


def require_source_result(value):
    wanted = dict(
        outcome="passed",
        first_failure=None,
        cleanup_failures=[],
        preservation_failure=None,
        original_preserved=True,
        login_disabled=True,
        physical_custody_retained=False,
        admin_connections_closed=11,
        login_enable_attempted=False,
        business_operations=0,
        maintenance_dispatches=0,
    )
    names = (
        "table-index-statistics-events",
        "dynamic-module-type-and-synonym-events",
        "signature-add-remove-invalidates",
        "disabled-row-invalidator-refuses",
        "native-values-through-real-canonicalizers",
    )
    if (
        any(value.get(k) != v for k, v in wanted.items())
        or tuple(r.get("name") for r in value.get("checks", [])) != names
        or any(r.get("passed") is not True for r in value["checks"])
        or value.get("before") != value.get("after")
        or value.get("exhausted_fixture_before") != value.get("exhausted_fixture_after")
        or value.get("fixture", {}).get("database_id") != 24
        or value["fixture"].get("name") != "K98_P02Observer_20261122123623540"
        or len(value.get("actions", [])) != 45
        or any(r.get("acknowledged") is not True for r in value["actions"])
    ):
        raise ValueError("Exact completed source/type group required")


def context(packet, manifest):
    import protocol_source_types as source

    raw = (packet / "evidence/source-types-success.json").read_bytes()
    if (
        sha(raw) != RECEIPT_SHA
        or raw != (PRIOR / "receipt.json").read_bytes()
        or sha((PRIOR / "packet.zip").read_bytes()) != ARCHIVE_SHA
    ):
        raise ValueError("Completed source/type receipt or archive changed")
    value = json.loads(raw)
    require_source_result(value)
    latest, prior, old_manifest = source.authenticate(packet, manifest)
    if value["before"]["databases"] != latest["databases_after"]:
        raise ValueError("Completed database lineage differs")
    latest = deepcopy(latest)
    latest["databases_after"].append(value["fixture"])
    return (latest, prior, old_manifest), value


def validate_added(rows, bindings, manifest, prior_rows, *, labels=("OFF", "ON")):
    if labels not in (("OFF",), ("OFF", "ON")):
        raise ValueError("Exact cost fixture labels required")
    names = manifest["databases"][: len(labels)]
    if (
        len(rows) != len(labels)
        or [r["name"] for r in rows] != names
        or len(bindings) != len(labels)
    ):
        raise ValueError("Exactly two acknowledged new baselines required")
    prior_ids = {r["database_id"] for r in prior_rows}
    for row, binding, label in zip(rows, bindings, labels, strict=True):
        if (
            row["name"] != binding["name"]
            or row["database_id"] != binding["database_id"]
            or row["database_id"] in prior_ids
            or row["database_id"] <= 24
            or row["state_desc"] != "ONLINE"
            or row["user_access_desc"] != "RESTRICTED_USER"
            or row["is_read_only"] is not False
            or row["source_database_id"] is not None
            or str(row["database_guid"]).lower() != str(binding["database_guid"]).lower()
            or str(row["family_guid"]).lower() != str(binding["family_guid"]).lower()
            or row["owner_sid"] != "010500000000000515000000cfc07a55bb14094237a8f0cfe9030000"
            or binding.get("data") != manifest["data_directory"] + "\\" + label + ".mdf"
            or binding.get("log") != manifest["data_directory"] + "\\" + label + ".ldf"
        ):
            raise ValueError("Restored fixture acknowledgement or physical identity differs")
    if len({r["database_id"] for r in rows}) != len(labels) or len(
        {r["database_guid"] for r in rows}
    ) != len(labels):
        raise ValueError("Restored fixtures must have distinct physical identities")


def observe(
    packet,
    manifest,
    phase,
    record,
    save,
    expected,
    source_result,
    bindings,
    *,
    retained_bindings=(),
    extra_fixture=None,
):
    import fresh_business_state as state
    import protocol_edges as edge
    import protocol_source_types as source
    from publisher_baseline import owned

    latest, prior, old_manifest = expected
    current = deepcopy(latest)
    with owned("master", record, save) as owner:
        actual = state.normalized(owner.read(state.DATABASES))
        added = [r for r in actual if r["name"] in manifest["databases"]]
        if phase == "before":
            if retained_bindings:
                validate_added(
                    added, retained_bindings, manifest, latest["databases_after"], labels=("OFF",)
                )
                current["databases_after"].extend(added)
            elif added:
                raise ValueError("New cost names already exist; do not replay")
        else:
            validate_added(added, bindings, manifest, latest["databases_after"])
            if retained_bindings and bindings[0] != retained_bindings[0]:
                raise ValueError("Completed OFF restore binding changed")
            current["databases_after"].extend(added)
    value = edge.preserved(
        packet, manifest, record, save, (current, prior, old_manifest), fixture=extra_fixture
    )
    # New fixture identity is recorded separately; all prior database and business
    # evidence must remain exactly comparable to the pre-restore receipt.
    value["databases"] = latest["databases_after"]
    record["new_fixtures"] = added
    previous = source.completed_receipt(packet)
    with edge.owned_fixture(previous["fixture"]["name"], record, save) as owner:
        record["exhausted_fixture"] = source.require_old_fixture(owner, previous)
    with edge.owned_fixture(source_result["fixture"]["name"], record, save) as owner:
        rows = state.normalized(owner.read(edge.SEQUENCE_SQL))
        identity = source_result["installed"]["identity"]
        wanted = [
            dict(
                object_id=identity[9],
                create_date=identity[10],
                modify_date=identity[11],
                generation=26,
                is_exhausted=False,
            )
        ]
        if rows != wanted:
            raise ValueError("Completed source/type fixture changed")
        record["source_type_fixture"] = rows
    return value


def main(*, plan_checker=require_plan, observer=observe):
    if len(sys.argv) not in (2, 3) or sys.argv[1] not in ("before", "after"):
        raise ValueError("Exact preservation phase required")
    phase = sys.argv[1]
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    plan_checker(packet, manifest)
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    from fresh_business_owner import HELD
    from independent_readers import write_new

    from scripts.verify_k98_running_release import sql_error_facts

    root = packet / phase
    root.mkdir(exist_ok=False)
    record = dict(
        outcome="running",
        stage=phase + " cost fixtures",
        first_failure=None,
        cleanup_failures=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        original_preserved=False,
        login_disabled=None,
        physical_custody_retained=False,
        actions=[],
        production_operations=0,
        business_operations=0,
        maintenance_dispatches=0,
    )

    def save():
        p = root / "progress.pending"
        p.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        p.replace(root / "progress.json")

    write_new(root / "entered.json", dict(pid=os.getpid(), phase=phase))
    try:
        expected, source_result = context(packet, manifest)
        bindings = []
        if phase == "after":
            raw = (packet / "restore-bindings.json").read_bytes()
            if len(sys.argv) != 3 or sha(raw) != sys.argv[2]:
                raise ValueError("Acknowledged restore bindings required")
            bindings = json.loads(raw)["fixtures"]
        elif len(sys.argv) != 2:
            raise ValueError("No before-phase bindings permitted")
        record["state"] = observer(
            packet, manifest, phase, record, save, expected, source_result, bindings
        )
        if phase == "after":
            before = json.loads((packet / "before/receipt.json").read_bytes())
            if before.get("outcome") != "passed" or record["state"] != before["state"]:
                raise ValueError("Original business state changed during fixture preparation")
        record.update(outcome="passed", original_preserved=True, login_disabled=True)
    except BaseException as error:
        record.update(outcome="failed", first_failure=sql_error_facts(error))
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        record["physical_custody_retained"] = bool(HELD)
        if HELD or record["cleanup_failures"]:
            record["outcome"] = "failed"
        save()
        write_new(root / "receipt.json", record)
    while HELD:
        time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
