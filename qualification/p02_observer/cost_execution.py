"""One sealed, finite five-pair comparison on completed DB25/26 lab copies."""

from copy import deepcopy
from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import time

PURPOSE = "p02-balanced-cost-workload"
PRIOR = Path(r"Q:\P02Observer\20261122151433639")
PRIOR_RECEIPT = "b8a2b02c4f61ba2e43f36fd260d1877add855119a3782ead1eef3b3941ae9a8b"
PRIOR_ARCHIVE = "32c7ba52f55fc253713b6f97cefdbd22495373bc1cbe05df8d3b57d2304e1aeb"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def schedule():
    # Five balanced pairs; every arm has its own matched post-rename warm-up.
    return [
        (pair, mode)
        for pair in range(1, 6)
        for mode in (("OFF", "ON") if pair % 2 else ("ON", "OFF"))
    ]


def require_binding(value):
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("before") != value.get("after")
        or value.get("differences") != []
        or value.get("admin_connections_closed") != 14
        or value.get("original_preserved") is not True
        or value.get("login_disabled") is not True
        or value.get("physical_custody_retained") is not False
        or len(value.get("workload_copies", [])) != 2
    ):
        raise ValueError("Exact complete matching-workload receipt required")
    for copy in value["workload_copies"]:
        source = copy["queries"]["source"]
        if (
            len(copy["outputs"]) != 59
            or len(copy["modules"]) != 7
            or len(source) != 1
            or source[0]["source_rows"] != 486427
            or source[0]["latest_scan"] != 1244
        ):
            raise ValueError("Recorded complete workload or scan boundary differs")


def require_packet(packet, manifest):
    import re

    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
        or manifest.get("pairs") != 5
        or manifest.get("fresh_reports")
        != (19 if manifest.get("retained_warmup_receipt_sha256") else 20)
        or manifest.get("provider_operations") != 0
        or manifest.get("restores") != 0
        or manifest.get("new_observer_installations") != []
        or manifest.get("completed_setup_receipt_sha256")
        != "edfd7c226e1ea8824badaa49c83101cb7f9def8140b46d2a8cefebe5cc6e7643"
        or manifest.get("source_diagnostic_receipt_sha256")
        != "bbd4b95dab26eae5da9166f63471bfd3b3f5f36a8bf77861b592955d3da1bf2f"
        or manifest.get("unstarted_cost_receipt_sha256")
        != "194f4329f2bbc9340be5b8132b2080786eecc020e66aff684dca6fda8633a79d"
        or manifest.get("statistics_refusal_receipt_sha256")
        != "9b438453b416d66d4cfb96aaa88d45d2fb0b850f06441cbf72b606a8a8d189ac"
        or manifest.get("entry_failure_launch_sha256")
        != "744a0b4e2afcdd90036231b762d1582a2012ffa46928608586f7b4256f2ab3cc"
        or manifest.get("statistics_preparation")
        != {
            "table": "dbo.MaintenanceWork",
            "statistics": "PK_MaintenanceWork",
            "rows": 6,
            "copies": [25, 26],
            "method": "FULLSCAN",
        }
    ):
        raise ValueError("Exact isolated finite cost packet required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed cost packet member changed")
    raw = (packet / "evidence/cost-binding.json").read_bytes()
    if (
        sha(raw) != PRIOR_RECEIPT
        or raw != (PRIOR / "receipt.json").read_bytes()
        or sha((PRIOR / "packet.zip").read_bytes()) != PRIOR_ARCHIVE
    ):
        raise ValueError("Complete native workload binding changed")
    value = json.loads(raw)
    require_binding(value)
    from cost_readiness import authenticate

    authenticate(packet, value)
    return value


def blank(stage):
    return dict(
        outcome="running",
        stage=stage,
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        actions=[],
        physical_custody_retained=False,
    )


def writer(root, record):
    def save():
        pending = root / "progress.pending"
        pending.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        pending.replace(root / "progress.json")

    return save


def independent_consumer(packet, manifest, bound, captures, record):
    # A separate process and new physical SQL handles are required; no live
    # writer/runtime or observation metadata is handed across this boundary.
    from cost_workload import consume
    from producer_runtime import Connections

    connections = Connections()
    try:
        record["consumer"] = consume(packet, manifest, bound, connections, captures)
    finally:
        record["consumer_cleanup"] = dict(safe_to_exit=False, all_closed_by_callers=False)
        record["consumer_cleanup"] = connections.finish()
        if (
            not record["consumer_cleanup"]["safe_to_exit"]
            or not record["consumer_cleanup"]["all_closed_by_callers"]
        ):
            raise ValueError("Independent consumer physical cleanup is unconfirmed")


def child(packet, manifest, number, role):
    from cost_pair_control import owned
    import cost_workload as work
    from fresh_business_owner import HELD
    from independent_readers import write_new
    from producer_runtime import Connections, application_credentials

    from scripts.verify_k98_running_release import sql_error_facts

    pair, mode = schedule()[number]
    root = packet / "cost-evidence" / f"{number:02d}-{mode}-{role}"
    root.mkdir(exist_ok=False)
    record = blank("authenticate actual " + role)
    record.update(pair=pair, mode=mode, role=role, pid=os.getpid(), cases=[])
    save = writer(root, record)
    write_new(root / "entered.json", dict(pid=os.getpid(), role=role, number=number))
    connections = Connections()
    bound = None
    safe = False
    try:
        with application_credentials(manifest):
            if role == "consumer":
                source = packet / "cost-evidence" / f"{number:02d}-{mode}-workload" / "receipt.json"
                old = json.loads(source.read_bytes())
                if old["outcome"] != "passed" or old["first_failure"] is not None:
                    raise ValueError("Only acknowledged completed captures may be consumed")
                bound = json.loads((source.parent / "bound-contracts.json").read_bytes())
                captures = json.loads(
                    (packet / "cost-evidence" / f"captures-{number:02d}.json").read_bytes()
                )
                independent_consumer(packet, manifest, bound, captures, record)
            elif role == "workload":
                contract_record = {}
                try:
                    bound = work.contracts(packet, manifest, mode, contract_record, connections)
                except BaseException:
                    try:
                        write_new(root / "contracts.json", contract_record)
                    except BaseException as collection_error:
                        record["contract_collection_failure"] = type(collection_error).__name__
                    raise
                else:
                    write_new(root / "contracts.json", contract_record)
                write_new(root / "bound-contracts.json", bound)
                record["contract_evidence_sha256"] = sha((root / "contracts.json").read_bytes())
                record["reader_cost"] = {
                    k: contract_record[k]
                    for k in (
                        "maximum_batch_seconds",
                        "application_read_seconds",
                        "statement_count",
                    )
                }
                workload = json.loads((packet / "workload.json").read_bytes())
                from cost_completed_warmup import child_warmup

                retained_warmup = child_warmup(packet, manifest, number)
                for index, phase in enumerate(("warmup", "measured")):
                    if index == 0 and retained_warmup is not None:
                        record["cases"].append(retained_warmup)
                        record["retained_warmup_reused"] = retained_warmup[
                            "reconciliation_receipt_sha256"
                        ]
                        save()
                        continue
                    case = blank(phase + " actual workload")
                    case.update(
                        phase=phase,
                        mode=mode,
                        pair=pair,
                        maintenance_request=manifest["requests"][number * 2 + index],
                    )
                    record["cases"].append(case)

                    def save_case():
                        record["stage"] = case["stage"]
                        save()

                    with owned("ROK_TRACKER", case, save_case, timeout=15) as owner:
                        from cost_source_resume import check_source

                        case["stage"] = phase + " source eligibility"
                        save_case()
                        check_source(owner, case, save_case)
                        case["clock_before"] = owner.read(work.CLOCKS)[0]
                        case["counters_before"] = work.counters(owner)
                        case["source_before"] = owner.read(work.QUERIES["source"])
                        case["audit_before"] = owner.read(work.ERROR_AUDIT)
                    work.names_summary(case, save_case)
                    work.report(packet, manifest, bound, connections, case, save_case, mode)
                    work.maintenance(case, save_case, case["maintenance_request"])
                    with owned("ROK_TRACKER", case, save_case, timeout=15) as owner:
                        case["clock_after"] = owner.read(work.CLOCKS)[0]
                        case["counters_after"] = work.counters(owner)
                        case["source_after"] = owner.read(work.QUERIES["source"])
                        case["audit_after"] = owner.read(work.ERROR_AUDIT)
                        if case["audit_after"] != case["audit_before"]:
                            raise ValueError("A new SQL incident was recorded during cost work")
                        if case["source_after"] != case["source_before"]:
                            raise ValueError("Business source changed during measured work")
                        work.outputs(owner, workload, case, save_case)
                        case["configuration_work"] = owner.read(work.QUERIES["configuration_work"])
                        case["backup_work"] = owner.read(work.QUERIES["backup_work"])
                    case["total_seconds"] = sum(
                        case[k]
                        for k in (
                            "names_seconds",
                            "summary_seconds",
                            "caller_total_seconds",
                            "maintenance_seconds",
                        )
                    )
                    case["outcome"] = "passed"
                    save()
            else:
                raise ValueError("Exact workload or independent consumer role required")
        record["outcome"] = "passed"
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
        if record["cases"] and record["cases"][-1]["outcome"] == "running":
            record["cases"][-1].update(
                outcome="failed", first_failure=deepcopy(record["first_failure"])
            )
    finally:
        try:
            record["physical_cleanup"] = connections.finish()
            safe = record["physical_cleanup"]["safe_to_exit"] and not HELD
            if not record["physical_cleanup"]["all_closed_by_callers"]:
                record["outcome"] = "failed"
        except BaseException as error:
            record["cleanup_failures"].append(
                dict(operation="application connections", error_type=type(error).__name__)
            )
        consumer_cleanup = record.get("consumer_cleanup", {})
        if consumer_cleanup and not consumer_cleanup.get("safe_to_exit"):
            safe = False
        record["credential_environment_cleared"] = "S11_SQL_PASSWORD" not in os.environ
        record["physical_custody_retained"] = not safe
        if not safe or record["cleanup_failures"]:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        save()
        try:
            write_new(root / "receipt.json", record)
        finally:
            while not safe:
                time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def launch(packet, manifest, number, role, record, save):
    from fresh_business_owner import HELD

    pair, mode = schedule()[number]
    root = packet / "cost-evidence"
    name = f"{number:02d}-{mode}-{role}"
    if (root / name).exists() or HELD:
        raise ValueError("New settled child role required; never replay a child")
    item = dict(pair=pair, mode=mode, role=role, number=number, acknowledged=False)
    record["children"].append(item)
    save()
    handles = []
    process = None
    try:
        for stream in ("stdout", "stderr"):
            handles.append((root / (name + "." + stream + ".txt")).open("xb"))
        env = {k: v for k, v in os.environ.items() if k not in ("S11_SQL_PASSWORD", "SQL_PASSWORD")}
        process = subprocess.Popen(
            [
                r"C:\Program Files\Python311\python.exe",
                "-I",
                "-S",
                "-B",
                str(packet / "qualification/p02_observer/cost_execution.py"),
                "child",
                str(number),
                role,
            ],
            cwd=packet,
            env=env,
            stdout=handles[0],
            stderr=handles[1],
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        HELD.append(process)
        process._p02_output_handles = handles
        item["pid"] = process.pid
        save()
        started = time.monotonic()
        while process.poll() is None and time.monotonic() - started < 600:
            time.sleep(1)
        if process.poll() is None:
            raise TimeoutError("Original cost child retained; no termination, successor or replay")
        process.wait()
        item.update(settled=True, exit_code=process.returncode, seconds=time.monotonic() - started)
        for handle in handles:
            handle.close()
        handles.clear()
        HELD.remove(process)
        raw = (root / name / "receipt.json").read_bytes()
        value = json.loads(raw)
        item["receipt_sha256"] = sha(raw)
        item["receipt"] = str(Path("cost-evidence") / name / "receipt.json")
        item["first_failure"] = value.get("first_failure")
        if (
            process.returncode != 0
            or value.get("outcome") != "passed"
            or value.get("first_failure") is not None
            or value.get("physical_custody_retained") is not False
            or value.get("credential_environment_cleared") is not True
        ):
            raise ValueError(
                "Original cost child failed; retain its complete evidence and completed work"
            )
        item["acknowledged"] = True
        save()
        return value
    finally:
        if process is None or process.poll() is not None:
            for handle in handles:
                handle.close()


def compare_pair(off, on):
    from cost_workload import equality

    differences = []
    for i in (0, 1):
        left, right = off["cases"][i], on["cases"][i]
        for key in (
            "phase",
            "sections_sha256",
            "section_count",
            "source_before",
            "source_after",
            "configuration_work",
            "backup_work",
        ):
            if left[key] != right[key]:
                differences.append(left["phase"] + "." + key)
        if equality(left["outputs"]) != equality(right["outputs"]):
            differences.append(left["phase"] + ".complete_output_state")
    return differences


def cost_metrics(arms):
    metrics = {}
    for key, allowance in (
        ("total_seconds", 1.0),
        ("names_seconds", 0.250),
        ("summary_seconds", 0.250),
        ("report_seconds", 0.250),
        ("caller_total_seconds", 0.250),
        ("maintenance_seconds", 0.250),
    ):
        values = {
            mode: [a["cases"][1][key] for a in arms if a["mode"] == mode] for mode in ("OFF", "ON")
        }
        medians = {mode: statistics.median(rows) for mode, rows in values.items()}
        ceiling = medians["OFF"] * 1.2 + allowance
        metrics[key] = dict(
            samples=values, medians=medians, ceiling=ceiling, passed=medians["ON"] <= ceiling
        )
    return metrics


def adjudicate(arms):
    if len(arms) != 10 or [(a["pair"], a["mode"]) for a in arms] != schedule():
        raise ValueError("Exactly the five balanced measured pairs required")
    metrics = cost_metrics(arms)
    reused = [i for i, a in enumerate(arms) if a.get("retained_warmup_reused")]
    uninterrupted = None
    if reused:
        from cost_completed_warmup import RECEIPT_SHA

        if reused != [0] or arms[0]["retained_warmup_reused"] != RECEIPT_SHA:
            raise ValueError("Only the authenticated first OFF warm-up may be reused")
        # The interrupted first warm-up has no immediate timing relationship to its
        # measurement. Require the same limits without that entire pair as well.
        uninterrupted = cost_metrics([a for a in arms if a["pair"] != 1])
    reader_cost = [a["reader_cost"] for a in arms if a["mode"] == "ON"]
    reader_passed = all(
        r["maximum_batch_seconds"] <= 0.250 and r["application_read_seconds"] <= 15
        for r in reader_cost
    )
    return dict(
        metrics=metrics,
        reader_cost=reader_cost,
        reader_cost_passed=reader_passed,
        uninterrupted_pairs_metrics=uninterrupted,
        interrupted_warmup_pair=1 if reused else None,
        paired_workload_cost_passed=all(m["passed"] for m in metrics.values())
        and (uninterrupted is None or all(m["passed"] for m in uninterrupted.values())),
    )


def run(
    packet, manifest, binding, *, completed=None, retained=None, statistics_stop=None, warmup=None
):
    import cost_fixture_state as preservation
    from cost_pair_control import NameOwner, adjusted_preservation, backups, owned
    import cost_readiness as readiness
    import cost_resume as resume
    import cost_workload_binding as binding_reader
    from fresh_business import require_login
    from fresh_business_owner import HELD, coordinator
    from independent_readers import write_new
    from producer_capture import dependency_preflight, private_spool
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts

    record = blank("authenticate completed work and bind fresh cost ownership")
    record.update(
        children=[],
        coordinator=[],
        original_preserved=False,
        login_disabled=None,
        restores=0,
        prior_migrations_replayed=False,
        provider_operations=0,
        original_name_restored=False,
        measured_cost_accepted=False,
        pairs=[],
    )
    save = writer(packet, record)
    write_new(packet / "entered.json", dict(pid=os.getpid(), purpose=PURPOSE))
    (packet / "cost-evidence").mkdir(exist_ok=False)
    names = None
    before = None
    login_attempted = False
    arms = []
    captures = {"OFF": [], "ON": []}
    try:
        expected, source = preservation.context(packet, manifest)
        if completed is not None:
            expected = resume.preservation_context(expected, retained or completed)
            resume.reuse_backups(completed)
            record["completed_setup_reused"] = resume.RECEIPT_SHA
        known = retained or (completed if completed is not None else binding)
        if warmup is not None:
            from cost_completed_warmup import require_manifest

            require_manifest(manifest, warmup)
        restored = json.loads((packet / "evidence/cost-ready/restore-bindings.json").read_bytes())[
            "fixtures"
        ]
        before = preservation.observe(
            packet, manifest, "after", record, save, expected, source, restored
        )
        if before != known["after"] or record["new_fixtures"] != known["new_fixtures"]:
            raise ValueError("Completed work or matching copy identity changed")
        record["before"] = before
        record["dependency_preflight"] = dependency_preflight()
        # Recheck the recorded complete logical binding before the first mutation.
        workload = json.loads((packet / "workload.json").read_bytes())
        record["workload_copies"] = []
        record["statistics_observations"] = []
        inventories = []
        record["copy_histories"] = []
        record["copy_sequences"] = []
        record["unstarted_account_rows"] = []
        record["readiness_differences"] = []
        for index, name in enumerate(binding_reader.NAMES):
            with binding_reader.owned_copy(name, record, save) as owner:
                value = binding_reader.read_copy(
                    owner, workload, record, save, time.monotonic() + 150
                )
                rows = owner.read(readiness.STATISTICS)
                record["statistics_observations"].append(rows)
                save()  # Preserve a refused inventory as well as a successful one.
                if completed is None:
                    inventories.append(readiness.statistics_inventory(rows))
                else:
                    history = owner.read(resume.HISTORY)
                    sequence = owner.read(resume.SEQUENCE)
                    record["copy_histories"].append(history)
                    record["copy_sequences"].append(sequence)
                    previous = json.loads(
                        (packet / "evidence/cost-ready/guest-receipt.json").read_bytes()
                    )
                    mode = ("OFF", "ON")[index]
                    resume.require_history(
                        history, previous["fixtures"][index]["history"], mode, completed
                    )
                    if warmup is None:
                        resume.require_sequence(sequence, mode, completed)
                    from producer_fixture import FRESH_ACCOUNT

                    old_manifest = json.loads(
                        (packet / "evidence/cost-completed/manifest.json").read_bytes()
                    )
                    old_account = owner.read(FRESH_ACCOUNT, old_manifest["account"])
                    new_account = owner.read(FRESH_ACCOUNT, manifest["account"])
                    record["unstarted_account_rows"].append(
                        dict(previous=old_account, current=new_account)
                    )
                    if warmup is not None:
                        from cost_completed_warmup import require_copy

                        if old_account:
                            raise ValueError("Earlier unstarted account gained business work")
                        record.setdefault("retained_copy_checks", []).append(
                            require_copy(index, value, rows, history, sequence, new_account, warmup)
                        )
                    elif old_account or new_account:
                        raise ValueError("An old or current cost account already has business work")
            if warmup is not None:
                record["readiness_differences"].append([])
                save()
                continue
            compared = (
                value
                if completed is None
                else resume.project_workload(
                    value, known["workload_copies"][index], ("OFF", "ON")[index]
                )
            )
            differences = readiness.logical_differences(compared, known["workload_copies"][index])
            record["readiness_differences"].append(differences)
            save()
            if differences:
                raise ValueError("Recorded ready logical workload changed before new business")
        if retained is not None:
            from cost_source_resume import RECEIPT_SHA, STOP_SHA, preflight

            record["source_diagnostic_reused"] = RECEIPT_SHA
            record["unstarted_cost_reused"] = STOP_SHA
            preflight(record, save)
        if warmup is not None:
            record["cost_readiness"] = dict(
                exact_recorded_postwork=True,
                retained_warmup_receipt=manifest["retained_warmup_receipt_sha256"],
                statistics_preparation_replayed=False,
                cross_copy_prework_equality_claimed=False,
            )
        elif statistics_stop is not None:
            from cost_statistics_resume import prepare

            record["cost_readiness"] = prepare(
                packet,
                record,
                save,
                completed,
                statistics_stop,
                record["workload_copies"],
                record["statistics_observations"],
            )
        else:
            record["cost_readiness"] = (
                readiness.require_ready_pair(record["workload_copies"], binding, inventories)
                if completed is None
                else resume.require_current_pair(
                    record["workload_copies"], completed, record["statistics_observations"]
                )
            )
        save()
        if warmup is not None:
            from cost_completed_warmup import reuse_spool

            record["private_spool"] = reuse_spool(manifest, warmup)
        else:
            record["private_spool"] = private_spool(manifest)
        names = NameOwner(manifest, record, save)
        names.begin()
        names.activate(26)
        record["stage"] = "fresh ON recovery backups and genuine canonical observer install"
        save()
        if completed is None:
            backups(packet, manifest, record, save, names)
            for operation in ("Status", "Preflight", "Apply", "Verify"):
                coordinator(packet, manifest, operation, record, save, database_id=26)
        else:
            record["stage"] = "verify retained committed ON setup without replay"
            verified = coordinator(packet, manifest, "Verify", record, save, database_id=26)
            if verified != completed["coordinator"][-1]["result"]:
                raise ValueError("Completed observer identity changed; no business admitted")
        names.park_active()
        for number, (pair, mode) in enumerate(schedule()):
            record["stage"] = f"paired actual workload {pair} {mode}"
            save()
            names.activate(25 if mode == "OFF" else 26)
            with owned("master", record, save) as owner:
                require_login(owner.read)
                login_attempted = True
                owner.mutate("enable existing login for cost copy only", control.ENABLE)
            record["stage"] = f"paired actual workload {pair} {mode}"
            save()
            value = launch(packet, manifest, number, "workload", record, save)
            captures[mode].extend(
                {k: case[k] for k in ("preparation_id", "snapshot", "generation")}
                for case in value["cases"]
            )
            from cost_workload import require_settled_capture_set
            from producer_fixture import FRESH_ACCOUNT, RESOURCE_SQL

            with owned("ROK_TRACKER", record, save) as owner:
                rows = owner.read(FRESH_ACCOUNT, manifest["account"])
                resources = owner.read(RESOURCE_SQL, "account:" + manifest["account"])
                require_settled_capture_set(rows, resources, captures[mode])
                record["last_settled_cost_resources"] = resources
            write_new(packet / "cost-evidence" / f"captures-{number:02d}.json", captures[mode])
            launch(packet, manifest, number, "consumer", record, save)
            with owned("master", record, save) as owner:
                owner.mutate("disable existing login after settled cost arm", control.DISABLE)
                require_login(owner.read)
            login_attempted = False
            arms.append(value)
            names.park_active()
            if number % 2:
                current = {a["mode"]: a for a in arms[-2:]}
                diff = compare_pair(current["OFF"], current["ON"])
                record["pairs"].append(dict(pair=pair, differences=diff))
                save()
                if diff:
                    raise ValueError(
                        "Complete paired output/state equality failed; no further pair admitted"
                    )
        record["cost"] = adjudicate(arms)
        record["measured_cost_accepted"] = (
            record["cost"]["paired_workload_cost_passed"] and record["cost"]["reader_cost_passed"]
        )
        record["outcome"] = (
            "passed" if record["measured_cost_accepted"] else "completed_with_cost_miss"
        )
        record["stage"] = "five balanced actual workload pairs and independent consumers completed"
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        if login_attempted:
            try:
                with owned("master", record, save) as owner:
                    owner.mutate("disable existing login after cost group", control.DISABLE)
                    require_login(owner.read)
                record["login_disabled"] = True
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="login disable", **sql_error_facts(error))
                )
        if names is not None and names.current is not None and not names.uncertain and not HELD:
            try:
                names.restore_original()
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="restore original canonical name", **sql_error_facts(error))
                )
        if before is not None and not HELD and (names is None or record["original_name_restored"]):
            try:
                context = expected if names is None else adjusted_preservation(expected, names)
                after = preservation.observe(
                    packet, manifest, "after", record, save, context, source, restored
                )
                wanted = deepcopy(before)
                if names is not None:
                    date = next(r["create_date"] for r in names.current if r["database_id"] == 18)
                    for row in wanted["databases"]:
                        if row["database_id"] == 18:
                            row["create_date"] = date
                if after != wanted:
                    raise ValueError(
                        "Completed original work changed beyond acknowledged rename date"
                    )
                record.update(after=after, original_preserved=True, login_disabled=True)
            except BaseException as error:
                record["preservation_failure"] = sql_error_facts(error)
                record["outcome"] = "failed"
        record["name_transition_uncertain"] = names.uncertain if names is not None else False
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
    return 0 if record["outcome"] in ("passed", "completed_with_cost_miss") else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    binding = require_packet(packet, manifest)
    warmup = None
    if manifest.get("retained_warmup_receipt_sha256"):
        from cost_completed_warmup import authenticate, require_manifest

        warmup = authenticate(packet)
        require_manifest(manifest, warmup)
        completed, retained, statistics_stop = warmup["completed"], warmup["latest"], None
    else:
        from cost_statistics_resume import authenticate

        completed, retained, diagnostic, statistics_stop = authenticate(packet)
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    if len(sys.argv) == 4 and sys.argv[1] == "child":
        number = int(sys.argv[2])
        if not 0 <= number < 10 or sys.argv[3] not in ("workload", "consumer"):
            raise ValueError("Exact finite child role required")
        return child(packet, manifest, number, sys.argv[3])
    if len(sys.argv) != 1:
        raise ValueError("Unexpected cost entry arguments")
    return run(
        packet,
        manifest,
        binding,
        completed=completed,
        retained=retained,
        statistics_stop=statistics_stop,
        warmup=warmup,
    )


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(main())
