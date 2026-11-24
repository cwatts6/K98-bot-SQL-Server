"""Finish only the fixed-reader cost gate after all five business pairs settled."""

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

PURPOSE = "p02-completed-cost-fixed-reader"
PRIOR = Path(r"Q:\P02Observer\20261123091156366")
RECEIPT_SHA = "81b18ce8350e467fc0818fc9dbac6b8db15981ab86c5cd8b2ab7c3fb5ec2f483"
ARCHIVE_SHA = "f4a20269afa47b7ad7fe5d2e958bb492d685fb11cd676587a4207046d55ddc87"
LAUNCH_SHA = "e3a9760fc8aa063b44bb50855d69072ef77a0fbd058143faf954d12bf870c022"
QUERY_SHA = "1782eca233e33b9612b56c314c9e43a260896f9f761bca3de08bd6564c937aae"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_completed(value, children):
    from cost_execution import adjudicate, compare_pair, schedule

    wanted = dict(
        outcome="completed_with_cost_miss",
        first_failure=None,
        cleanup_failures=[],
        preservation_failure=None,
        original_preserved=True,
        original_name_restored=True,
        name_transition_uncertain=False,
        login_disabled=True,
        physical_custody_retained=False,
        admin_connections_closed=93,
        measured_cost_accepted=False,
        restores=0,
        provider_operations=0,
        prior_migrations_replayed=False,
    )
    if any(value.get(k) != v for k, v in wanted.items()) or len(children) != 20:
        raise ValueError("Exact completed five-pair group and settled owners required")
    arms = []
    captures = {"OFF": [], "ON": []}
    for n, (pair, mode) in enumerate(schedule()):
        work, consumer = children[n * 2 : n * 2 + 2]
        for child, role in ((work, "workload"), (consumer, "consumer")):
            if (
                child.get("outcome") != "passed"
                or child.get("first_failure") is not None
                or child.get("cleanup_failures") != []
                or child.get("physical_custody_retained") is not False
                or child.get("credential_environment_cleared") is not True
                or child.get("role") != role
                or child.get("mode") != mode
                or child.get("pair") != pair
            ):
                raise ValueError("Original child outcome or physical custody changed")
            for key in ("physical_cleanup", "consumer_cleanup"):
                if key in child and (
                    child[key].get("safe_to_exit") is not True
                    or child[key].get("all_closed_by_callers") is not True
                ):
                    raise ValueError("Every original child connection must be closed")
        if len(work["cases"]) != 2 or work["cases"][1]["outcome"] != "passed":
            raise ValueError("Both completed phases required")
        captures[mode].extend(c["preparation_id"] for c in work["cases"])
        if consumer["consumer"] != dict(
            preparations=captures[mode], provider_operations=0, export_jobs_created=0
        ):
            raise ValueError("Every committed capture must have its independent consumer proof")
        arms.append(work)
        if n % 2:
            group = {a["mode"]: a for a in arms[-2:]}
            if compare_pair(group["OFF"], group["ON"]):
                raise ValueError("Completed pair differs")
    if (
        value["pairs"] != [dict(pair=n, differences=[]) for n in range(1, 6)]
        or adjudicate(arms) != value["cost"]
    ):
        raise ValueError("Retained full equality or measured costs changed")
    if not value["cost"]["paired_workload_cost_passed"] or value["cost"]["reader_cost_passed"]:
        raise ValueError("Only the measured fixed-reader cost miss remains")
    return arms


def authenticate(packet, manifest):
    raw = (PRIOR / "receipt.json").read_bytes()
    if sha(raw) != RECEIPT_SHA or sha((PRIOR / "packet.zip").read_bytes()) != ARCHIVE_SHA:
        raise ValueError("Completed workload evidence changed")
    launch_raw = (packet / "evidence/completed-cost/launch-result.json").read_bytes()
    launch = json.loads(launch_raw)
    if (
        sha(launch_raw) != LAUNCH_SHA
        or launch.get("state") != "exited"
        or launch.get("exitCode") != 0
        or launch.get("pid") != 5528
        or launch.get("path") != str(PRIOR)
        or launch.get("PSComputerName") != "K98-MGE-Qualification-20261029"
    ):
        raise ValueError("Exact completed process required")
    value = json.loads(raw)
    children = []
    if len(value.get("children", [])) != 20:
        raise ValueError("Twenty settled child roles required")
    for item in value["children"]:
        if (
            item.get("acknowledged") is not True
            or item.get("settled") is not True
            or item.get("exit_code") != 0
        ):
            raise ValueError("Unsettled workload child cannot be replayed")
        raw = (PRIOR / item["receipt"]).read_bytes()
        if sha(raw) != item["receipt_sha256"]:
            raise ValueError("Original child receipt changed")
        children.append(json.loads(raw))
    arms = require_completed(value, children)
    with zipfile.ZipFile(PRIOR / "packet.zip") as z:
        old = json.loads(z.read("manifest.json"))
    for key in (
        "account",
        "storage_owner",
        "private_directory",
        "credential",
        "release",
        "databases",
        "data_directory",
        "requests",
    ):
        if manifest.get(key) != old[key]:
            raise ValueError("Completed cost identity differs")
    raw = (PRIOR / "cost-evidence/09-ON-workload/contracts.json").read_bytes()
    if sha(raw) != arms[-1]["contract_evidence_sha256"]:
        raise ValueError("Completed native contract evidence changed")
    expected = json.loads(raw)["contract_result"]["installation"]
    return dict(latest=value, arms=arms, expected=expected)


def verify_copy(index, value, accounts, resources, context):
    from cost_workload import require_settled_capture_set
    from fresh_business_state import normalized

    arms = [a for a in context["arms"] if a["mode"] == ("OFF", "ON")[index]]
    last = arms[-1]["cases"][-1]
    expected = {
        n: dict(columns=x["columns"], content=x["raw_content"]) for n, x in last["outputs"].items()
    }
    actual = {n: {k: x[k] for k in ("columns", "content")} for n, x in value["outputs"].items()}
    if (
        normalized(actual) != normalized(expected)
        or normalized(value["modules"]) != context["latest"]["workload_copies"][index]["modules"]
    ):
        raise ValueError("Completed business outputs or producer definitions changed")
    for key in ("source", "configuration_work", "backup_work"):
        wanted = last["source_after"] if key == "source" else last[key]
        if normalized(value["queries"][key]) != normalized(wanted):
            raise ValueError("Completed business state changed")
    cases = [c for a in arms for c in a["cases"]]
    require_settled_capture_set(accounts, resources, cases)
    for row, case in zip(accounts, cases, strict=True):
        snap = case["snapshot"]
        if (
            row["StorageOwner"] != snap["storage_owner"]
            or row["SpoolKey"] != snap["key"]
            or row["SpoolBytes"] != snap["byte_count"]
            or row["SpoolHash"] != snap["sha256"]
            or json.loads(row["GenerationJson"]) != case["generation"]
        ):
            raise ValueError("Completed immutable capture registration changed")


def copies(packet, manifest, context, record, save):
    import cost_workload_binding as binding
    from cost_resume import HISTORY, SEQUENCE
    from producer_fixture import FRESH_ACCOUNT, RESOURCE_SQL
    from fresh_business_state import normalized

    start = len(record["workload_copies"])
    extra = []
    workload = json.loads((packet / "workload.json").read_bytes())
    for index, name in enumerate(binding.NAMES):
        with binding.owned_copy(name, record, save) as owner:
            value = binding.read_copy(owner, workload, record, save, time.monotonic() + 120)
            accounts = owner.read(FRESH_ACCOUNT, manifest["account"])
            resources = owner.read(RESOURCE_SQL, "account:" + manifest["account"])
            history = owner.read(HISTORY)
            sequence = owner.read(SEQUENCE)
            verify_copy(index, value, accounts, resources, context)
            if normalized(history) != context["latest"]["copy_histories"][index]:
                raise ValueError("Completed migration history changed")
            old = context["latest"]["copy_sequences"][index]
            if index == 0 and sequence:
                raise ValueError("OFF observer appeared")
            if index == 1:
                current = normalized(sequence)
                if (
                    len(current) != 1
                    or current[0]["generation"] < old[0]["generation"]
                    or current[0]["is_exhausted"] is not False
                    or any(
                        current[0][k] != old[0][k]
                        for k in ("object_id", "create_date", "modify_date")
                    )
                ):
                    raise ValueError("Committed ON observer incarnation changed")
            extra.append(
                normalized(
                    dict(accounts=accounts, resources=resources, history=history, sequence=sequence)
                )
            )
    return dict(copies=normalized(record["workload_copies"][start:]), state=extra)


def read_group(packet, manifest, context, record, save):
    import cost_workload as work
    from producer_runtime import Connections, application_credentials
    from scripts.verify_k98_running_release import ObservationConnections
    from services.export_execution_dal import (
        _APPLICATION_SCOPED_METADATA,
        INSTALLATION_OBJECTS,
        rows,
    )
    from services.export_execution_protocol import encode
    from independent_readers import write_new

    query = _APPLICATION_SCOPED_METADATA["indexes"].replace("@scope", "?")
    if sha(query.encode()) != QUERY_SHA:
        raise ValueError("Exact measured original index query required")
    connections = Connections()
    record["reader_samples"] = []
    first = None
    try:
        with application_credentials(manifest):
            owner = ObservationConnections(connections)
            try:
                with owner:
                    owner.observation_phase("export")
                    connection = owner()
                    try:
                        cursor = connection.cursor()
                        try:
                            cursor.execute(query, json.dumps(sorted(INSTALLATION_OBJECTS)))
                            original = rows(cursor)
                        finally:
                            cursor.close()
                    finally:
                        connection.close()
                if encode(original) != encode(context["expected"]["metadata"]["indexes"]):
                    raise ValueError("Original fixed index rows changed")
                record["original_index_row_sha256"] = sha(encode(original))
            finally:
                record["original_index_reader"] = owner.evidence()
                save()
            started = time.monotonic()
            for number in range(6):
                if time.monotonic() - started >= 100:
                    raise TimeoutError("Grouped reader deadline reached")
                sample = dict(number=number, warmup=number == 0)
                record["reader_samples"].append(sample)
                save()
                try:
                    work.contracts(packet, manifest, "ON", sample, connections)
                    observed = sample["contract_result"]["installation"]
                    if encode(observed) != encode(context["expected"]):
                        raise ValueError("Complete fixed contract parity changed")
                    if number == 0:
                        write_new(
                            packet / "application-observation.json", sample["contract_result"]
                        )
                    sample["fixed_value_sha256"] = sha(encode(observed))
                    sample["batch_cost_passed"] = sample["maximum_batch_seconds"] <= 0.250
                    sample["application_deadline_passed"] = sample["application_read_seconds"] <= 15
                    sample["outcome"] = "passed"
                finally:
                    # Preserve full first observation separately; every sample retains
                    # exact per-statement timings and its strict comparator result.
                    sample.pop("contract_result", None)
                    save()
    except BaseException as error:
        first = error
        raise
    finally:
        record["application_cleanup"] = dict(safe_to_exit=False, all_closed_by_callers=False)
        try:
            record["application_cleanup"] = connections.finish()
            if (
                not record["application_cleanup"]["safe_to_exit"]
                or not record["application_cleanup"]["all_closed_by_callers"]
            ):
                raise ValueError("Application physical cleanup is not confirmed")
        except BaseException as error:
            record.setdefault("cleanup_failures", []).append(
                dict(operation="application cleanup", error_type=type(error).__name__)
            )
            if first is None:
                raise
        finally:
            record["credential_environment_cleared"] = "S11_SQL_PASSWORD" not in os.environ
            save()
    return all(
        s["batch_cost_passed"] and s["application_deadline_passed"]
        for s in record["reader_samples"]
    )


def run(packet, manifest, context):
    import cost_fixture_state as preservation
    import cost_resume as resume
    from cost_pair_control import NameOwner, adjusted_preservation, owned
    from cost_readiness import logical_differences
    from cost_execution import blank, writer
    from fresh_business import require_login
    from fresh_business_owner import HELD
    from independent_readers import write_new
    import three_contracts as control
    from scripts.verify_k98_running_release import sql_error_facts

    record = blank("authenticate completed business group")
    record.update(
        workload_copies=[],
        original_preserved=False,
        original_name_restored=False,
        login_disabled=None,
        reader_samples=[],
        business_operations=0,
        maintenance_dispatches=0,
        restores=0,
        migrations=0,
        backups=0,
        provider_operations=0,
        completed_workload_receipt=RECEIPT_SHA,
    )
    save = writer(packet, record)
    write_new(packet / "entered.json", dict(pid=os.getpid(), purpose=PURPOSE))
    before = None
    names = None
    login_attempted = False
    reader_attempted = False
    try:
        expected, source = preservation.context(packet, manifest)
        expected = resume.preservation_context(expected, context["latest"])
        bindings = json.loads((packet / "evidence/cost-ready/restore-bindings.json").read_bytes())[
            "fixtures"
        ]
        before = preservation.observe(
            packet, manifest, "after", record, save, expected, source, bindings
        )
        if (
            before != context["latest"]["after"]
            or record["new_fixtures"] != context["latest"]["new_fixtures"]
        ):
            raise ValueError("Completed original identities changed")
        record["before"] = before
        record["cost_before"] = copies(packet, manifest, context, record, save)
        save()
        names = NameOwner(manifest, record, save)
        names.begin()
        names.activate(26)
        with owned("master", record, save) as owner:
            require_login(owner.read)
            login_attempted = True
            owner.mutate("enable existing login for fixed reader only", control.ENABLE)
        record["stage"] = "one original index read and six complete candidate contract reads"
        save()
        reader_attempted = True
        record["reader_cost_passed"] = read_group(packet, manifest, context, record, save)
        record["outcome"] = "passed" if record["reader_cost_passed"] else "completed_with_cost_miss"
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        safe = record.get("application_cleanup", {}).get("safe_to_exit", True) and not HELD
        if login_attempted:
            try:
                with owned("master", record, save) as owner:
                    owner.mutate("disable existing login after fixed reader group", control.DISABLE)
                    require_login(owner.read)
                record["login_disabled"] = True
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="disable login", **sql_error_facts(error))
                )
        if names is not None and names.current is not None and not names.uncertain and safe:
            try:
                names.restore_original()
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="restore canonical name", **sql_error_facts(error))
                )
        if before is not None and safe and (names is None or record["original_name_restored"]):
            try:
                if reader_attempted:
                    record["cost_after"] = copies(packet, manifest, context, record, save)
                    if record["cost_before"]["state"] != record["cost_after"]["state"] or any(
                        logical_differences(a, b)
                        for a, b in zip(
                            record["cost_before"]["copies"],
                            record["cost_after"]["copies"],
                            strict=True,
                        )
                    ):
                        raise ValueError("Reader group changed completed cost work")
                current = expected if names is None else adjusted_preservation(expected, names)
                after = preservation.observe(
                    packet, manifest, "after", record, save, current, source, bindings
                )
                wanted = deepcopy(before)
                if names is not None:
                    for row in wanted["databases"]:
                        if row["database_id"] == 18:
                            row["create_date"] = next(
                                x["create_date"] for x in names.current if x["database_id"] == 18
                            )
                if after != wanted:
                    raise ValueError("Original work changed beyond acknowledged rename")
                record.update(after=after, original_preserved=True, login_disabled=True)
            except BaseException as error:
                record["preservation_failure"] = sql_error_facts(error)
                record["outcome"] = "failed"
        record["name_transition_uncertain"] = names.uncertain if names else False
        safe = safe and not HELD
        record["physical_custody_retained"] = not safe
        if record["cleanup_failures"] or not safe:
            record["outcome"] = "failed"
        if record["outcome"] in ("passed", "completed_with_cost_miss"):
            record["stage"] = (
                "complete reader group verified; all business work and names preserved"
            )
        record["finished"] = datetime.now(UTC).isoformat()
        save()
        write_new(packet / "receipt.json", record)
        while not safe:
            time.sleep(1)
    return 0 if record["outcome"] in ("passed", "completed_with_cost_miss") else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
        or manifest.get("reader_samples") != 6
        or any(
            manifest.get(k) != 0
            for k in (
                "business_operations",
                "maintenance_dispatches",
                "restores",
                "migrations",
                "backups",
                "provider_operations",
            )
        )
    ):
        raise ValueError("Exact isolated reader-only continuation required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed reader continuation member changed")
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    context = authenticate(packet, manifest)
    return run(packet, manifest, context)


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(main())
