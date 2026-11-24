"""One grouped, genuine DB18 release and report/capture qualification.

The original DB16 and its uncertain claim are evidence, never retry authority.
This entry owns a fresh directory; any existing entry refuses before SQL.
"""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys
import time

PURPOSE = "fresh-db18-release-report-capture"
RESUME_PURPOSE = "fresh-db18-backup-preflight-continuation"
OVERLAP_PURPOSE = "fresh-db18-producer-first-overlap"
RESTORE_DIRECTORY = Path(r"Q:\P02Observer\20261121181435617")
RESTORE_SHA = "84c6d8d1fe622e9727c40a6680672226d787a53be73afad3a56d7ca17ec7538b"


def stamp():
    return datetime.now(UTC).isoformat()


def require_packet(packet, manifest):
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") not in (PURPOSE, RESUME_PURPOSE, OVERLAP_PURPOSE)
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or str(packet) != manifest.get("guest_directory")
        or manifest.get("target_database_id") != 18
    ):
        raise ValueError("Exact isolated fresh DB18 packet required")
    if manifest.get("purpose") == OVERLAP_PURPOSE and (
        manifest.get("prepared_reader") is not True
        or manifest.get("capture_indices") != [2]
        or manifest.get("fresh_report_operations") != 1
        or manifest.get("report_retries") != 1
    ):
        raise ValueError("Exact single remaining case required")
    if manifest.get("continued_packet") is not None and (
        manifest.get("continued_packet") != "20261121210559194"
        or manifest.get("controlled_report_barrier") is not True
        or manifest.get("barrier_expected_rows") != 415
        or manifest.get("purpose") != OVERLAP_PURPOSE
    ):
        raise ValueError("Exact completed third-capture control continuation required")
    if manifest.get("resume_control_failure") is not None and (
        manifest["resume_control_failure"] != "20261121214611154"
        or manifest.get("continued_packet") != "20261121210559194"
        or manifest.get("control_release_preflight") is not True
        or manifest.get("preserve_capture_count") != 4
    ):
        raise ValueError("Exact settled fourth-capture continuation required")
    if manifest.get("resume_control_preflight") is not None and (
        manifest["resume_control_preflight"] != "20261121215726740"
        or manifest.get("resume_control_failure") != "20261121214611154"
        or manifest.get("separate_control_boundaries") is not True
    ):
        raise ValueError("Exact no-business preflight continuation required")
    if manifest.get("resume_authentication_failure") is not None and (
        manifest["resume_authentication_failure"] != "20261121220646479"
        or manifest.get("resume_control_preflight") != "20261121215726740"
    ):
        raise ValueError("Exact no-SQL entry continuation required")
    if manifest.get("resume_release_batch_failure") is not None and (
        manifest["resume_release_batch_failure"] != "20261121221132033"
        or manifest.get("standalone_release_boundary") is not True
        or manifest.get("resume_authentication_failure") != "20261121220646479"
    ):
        raise ValueError("Exact standalone-release continuation required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if (
            not path.is_relative_to(packet)
            or hashlib.sha256(path.read_bytes()).hexdigest() != digest
        ):
            raise ValueError("Sealed qualification member changed")
    raw = (packet / "evidence/restore.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RESTORE_SHA
        or (RESTORE_DIRECTORY / "guest-receipt.json").read_bytes() != raw
    ):
        raise ValueError("Completed restore identity changed")
    return json.loads(raw)


def require_login(read):
    import three_contracts as control

    rows = read(control.LOGIN_STATE)
    selected = [r for r in rows if r["name"] == control.PRINCIPAL]
    if (
        len(selected) != 1
        or selected[0]["sid"] != control.NEW_SID
        or selected[0]["is_disabled"] is not True
    ):
        raise ValueError("Original disabled application login required")
    return rows


def fresh_preflight(owner, restore, *, named):
    import application_identity as identity
    from fresh_business_state import FRESH, IDENTITY, normalized, require_identity
    from producer_fixture import FRESH_ACCOUNT
    from release_boundary import owner_inventory
    import report_failure_read as old
    from restart_read import OWNER_SQL
    import three_contracts as control

    require_identity(owner.read(IDENTITY), "ROK_TRACKER" if named else FRESH, 18)
    rows = owner.read(identity.TARGET)
    if (
        len(rows) != 1
        or rows[0]["state_desc"] != "ONLINE"
        or rows[0]["is_read_only"]
        or rows[0]["snapshot_isolation_state"] != 1
        or rows[0]["is_read_committed_snapshot_on"]
    ):
        raise ValueError("Fresh baseline isolation differs")
    history = owner.read(identity.HISTORY)
    if identity.normalized_history(history) != identity.normalized_history(restore["history"]):
        raise ValueError("Genuine restored migration history differs")
    if owner.read(identity.QUERIES["observer_sequence"]):
        raise ValueError("Fresh observer already exists; no installation replay")
    principals = owner.read(identity.QUERIES["database_users"])
    app = [r for r in principals if r["name"] == control.PRINCIPAL]
    if len(app) != 1 or app[0]["sid"] != control.NEW_SID or app[0]["type_desc"] != "SQL_USER":
        raise ValueError("Restored application user mapping differs")
    db_owner = owner.read(OWNER_SQL)
    expected = restore["owner"][0]
    if (
        len(db_owner) != 1
        or db_owner[0]["database_owner_sid"] != expected["owner_sid"]
        or db_owner[0]["dbo_sid"] != expected["dbo_sid"]
        or db_owner[0]["owner_login"] != expected["owner_login"]
    ):
        raise ValueError("Completed fresh dbo owner differs")
    ownership = owner_inventory(owner.connection)
    resource = ownership["resource"]
    if (
        len(resource) != 1
        or ownership["active_preparation"]
        or resource[0]["blocked"]
        or any(
            resource[0][k] is not None
            for k in ("ActiveJobID", "ActivePreparationID", "ActiveOutputOperationID", "OwnerID")
        )
        or owner.read(FRESH_ACCOUNT, old.ACCOUNT)
    ):
        raise ValueError("Fresh baseline must be free and exclude original failed claim")
    return normalized(
        dict(target=rows, history=history, users=principals, owner=db_owner, owners=ownership)
    )


def handover(packet, manifest, restore, record, save):
    from fresh_business_owner import SqlOwner
    import fresh_business_state as state
    from independent_readers import write_new

    master = SqlOwner("master", record, save)
    state.require_identity(master.read(state.IDENTITY), "master", 1)
    require_login(master.read)
    if master.read(state.SESSIONS) or master.read(state.LOCKS):
        raise ValueError("Foreign SQL activity prevents name handover")
    before = state.normalized(master.read(state.DATABASES))
    files = state.normalized(master.read(state.FILE_IDENTITIES))
    state.require_files(files)
    names = {r["database_id"]: r["name"] for r in before}
    if (
        names.get(16) != "ROK_TRACKER"
        or names.get(18) != state.FRESH
        or state.RETAINED in names.values()
    ):
        raise ValueError("Unstarted exact DB16/DB18 name handover required")
    record["databases_before"], record["files_before"] = before, files
    record["name_changes"] = {}
    for number, source, target in (
        (16, "ROK_TRACKER", state.RETAINED),
        (18, state.FRESH, "ROK_TRACKER"),
    ):
        if master.read(state.SESSIONS) or master.read(state.LOCKS):
            raise ValueError("Foreign activity appeared before name transition")
        item = dict(
            name=target, acknowledged=False, before=str(master.read(state.CLOCK)[0]["local_time"])
        )
        record["name_changes"][number] = item
        master.mutate(
            "rename physical DB" + str(number),
            "SET LOCK_TIMEOUT 1000; ALTER DATABASE [" + source + "] MODIFY NAME=[" + target + "]; ",
        )
        item.update(acknowledged=True, after=str(master.read(state.CLOCK)[0]["local_time"]))
        observed = state.normalized(master.read(state.DATABASES))
        state.require_handover(
            before,
            observed,
            files,
            state.normalized(master.read(state.FILE_IDENTITIES)),
            record["name_changes"],
        )
        record["databases_named"] = observed
        save()
    master.mutate(
        "allow actual application connections to fresh DB18",
        "IF DB_ID(N'ROK_TRACKER')<>18 THROW 51976,'Fresh DB18 required.',1; "
        "ALTER DATABASE [ROK_TRACKER] SET MULTI_USER WITH NO_WAIT;",
    )
    record["name_changes"][18]["multi_user"] = True
    record["databases_named"] = state.normalized(master.read(state.DATABASES))
    state.require_handover(
        before,
        record["databases_named"],
        files,
        state.normalized(master.read(state.FILE_IDENTITIES)),
        record["name_changes"],
    )
    master.close()
    write_new(
        packet / "handover.json",
        dict(
            databases_before=before,
            databases_after=record["databases_named"],
            files=files,
            changes=record["name_changes"],
        ),
    )


def snapshot(owner, manifest):
    from fresh_business_state import FILES
    from producer_fixture import SNAPSHOT_SQL

    # The original source is restricted to DB16. This sealed successor changes
    # only its exact physical DB/file guard, retaining the same snapshot owner.
    sql = SNAPSHOT_SQL.replace("DB_ID()<>16", "DB_ID()<>18").replace("Exact DB16", "Exact DB18")
    sql = sql.replace(FILES[16], FILES[18])
    name, path = manifest["snapshot"]["name"], manifest["snapshot"]["path"]
    rows = owner.read(sql, name, path)
    if (
        len(rows) != 1
        or rows[0]["name"] != name
        or rows[0]["source_database_id"] != 18
        or rows[0]["state_desc"] != "ONLINE"
        or rows[0]["is_read_only"] is not True
    ):
        raise ValueError("Fresh DB18 recovery snapshot acknowledgement differs")
    return rows[0]


def run_business(packet, manifest, prior, owner, record, save):
    from independent_readers import write_new
    from producer_capture import private_spool, require_post_business
    import producer_fixture as fixture
    import producer_pair as pair

    preflight = fixture.preflight(owner.connection, packet, manifest, prior)
    record["business_preflight"] = preflight
    record["stage"] = "fresh DB18 recovery snapshot"
    save()
    record["snapshot_attempted"] = True
    save()
    record["snapshot"] = snapshot(owner, manifest)
    record["private_fixture"] = private_spool(manifest)
    write_new(
        packet / "stage-1.json",
        dict(
            preflight=preflight,
            snapshot=record["snapshot"],
            private_fixture=record["private_fixture"],
        ),
    )
    for index in (1, 2):
        record["stage"] = "fresh report/capture order " + str(index)
        case = {}
        record["cases"].append(case)
        pair.run_pair(packet, manifest, owner.connection, index, case, save)
        case["report_after"] = owner.read(fixture.REPORT_VALUE_SQL)
        save()
    if record["cases"][0]["report_after"] != record["cases"][1]["report_after"]:
        raise ValueError("Two fresh reports produced different business rows")
    record["stage"] = "independent next consumer"
    child = pair.launch(packet, "consumer", 1)
    held = dict(children=[dict(pid=child["process"].pid, role="consumer")])
    record["consumer_process"] = held
    pair.settle(packet, manifest, [child], held, save)
    value = json.loads((packet / "stage-8.json").read_bytes())
    if (
        child["exit_code"] != 0
        or held.get("cleanup_failures")
        or value.get("outcome") != "passed"
        or value.get("pid") != child["process"].pid
    ):
        raise ValueError("Independent consumer did not verify both retained generations")
    record["consumer"] = value
    record["business_after"] = require_post_business(
        owner.connection, manifest, preflight, record["cases"]
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


def parent(packet, manifest, restore):
    import fixed_contract_cost as cost
    from fresh_business_owner import HELD, SqlOwner, coordinator
    import fresh_business_state as state
    from independent_readers import encode, sha, write_new
    from producer_capture import dependency_preflight
    from producer_runtime import Connections, application_credentials
    from release_boundary import owner_inventory
    from restart_read import require_services
    from scripts.verify_k98_running_release import sql_error_facts
    import three_contracts as control

    record = dict(
        schema="p02-fresh-business/1",
        outcome="running",
        stage="entry",
        started=stamp(),
        actions=[],
        coordinator=[],
        first_failure=None,
        cleanup_failures=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        login_enable_attempted=False,
        login_disabled=True,
        production_operations=0,
        restore_replayed=False,
        storage_replayed=False,
        original_setup_replayed=False,
        original_claim_released=False,
        provider_operations=0,
        protected_seed_issued=False,
        runtime_published=False,
        cases=[],
        original_preserved=False,
    )

    def save():
        temporary = packet / "progress.pending"
        temporary.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        temporary.replace(packet / "progress.json")

    write_new(packet / "entered.json", dict(pid=os.getpid(), started=stamp()))
    baseline = json.loads((packet / "evidence/original-state.json").read_bytes())
    original = baseline["after"]
    owner = None
    try:
        state.require_restore(restore)
        for phase in ("before", "after"):
            pointer = restore[phase + "_preservation"]
            raw = (RESTORE_DIRECTORY / phase / "receipt.json").read_bytes()
            if sha(raw) != pointer["sha256"]:
                raise ValueError("Native final preservation receipt changed")
            state.require_native_reader(json.loads(raw), original)
            write_new(packet / (phase + "-restore-reader.json"), json.loads(raw))
        record["dependencies"] = dependency_preflight()
        if manifest.get("purpose") == RESUME_PURPOSE:
            from fresh_business_resume import reconcile

            reconcile(packet, manifest, restore, record, save)
        else:
            owner = SqlOwner("ROK_TRACKER", record, save)
            services = owner.read(cost.SERVICES_SQL)
            require_services(services)
            record["services_before"] = services
            record["original_before"] = state.original_state(owner, original, "ROK_TRACKER")
            if (
                record["original_before"]["owner"]
                != baseline["fresh_restore_preservation"]["database_owner"]
                or record["original_before"]["modules"]
                != baseline["fresh_restore_preservation"]["modules"]
            ):
                raise ValueError("Original corrected owner or modules changed")
            owner.close()
            owner = SqlOwner(state.FRESH, record, save)
            record["fresh_before"] = fresh_preflight(owner, restore, named=False)
            import shutil

            if shutil.disk_usage("R:/").free < 40 * 1024**3:
                raise ValueError("Fresh snapshot and cleanup reserve required")
            owner.close()
            owner = None
            handover(packet, manifest, restore, record, save)
            named = next(r for r in record["databases_named"] if r["database_id"] == 16)
            expected = state.expected_original(original, state.RETAINED, named["create_date"])
            owner = SqlOwner(state.RETAINED, record, save)
            record["original_after_handover"] = state.original_state(
                owner, expected, state.RETAINED
            )
            owner.close()
            owner = SqlOwner("ROK_TRACKER", record, save)
            fresh_preflight(owner, restore, named=True)
            owner.close()
            owner = None
        for operation in ("Status", "Preflight", "Apply", "Verify"):
            if operation == "Preflight":
                from fresh_business_backup import prepare

                prepare(packet, manifest, record, save)
            coordinator(packet, manifest, operation, record, save)
            if operation == "Apply":
                record["fresh_observer_committed"] = True
                save()
            elif operation == "Verify":
                record["fresh_observer_verified"] = True
                save()
        owner = SqlOwner("ROK_TRACKER", record, save)
        state.require_identity(owner.read(state.IDENTITY), "ROK_TRACKER", 18)
        require_services(owner.read(cost.SERVICES_SQL))
        prior = dict(owners_after=owner_inventory(owner.connection))
        record["login_enable_attempted"] = True
        record["login_disabled"] = None
        save()
        owner.mutate("enable existing application login for fresh DB18 only", control.ENABLE)
        record["login_disabled"] = False
        application = {}
        record["configured_reader"] = application
        connections = Connections()
        try:
            with application_credentials(manifest):
                candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
                actual = control.run_contracts(
                    connections, candidate, manifest["release"], application
                )
        finally:
            cleanup = connections.finish()
            application["physical_cleanup"] = cleanup
            if not cleanup["safe_to_exit"]:
                HELD.append(connections)
        if not cleanup["all_closed_by_callers"] or not cleanup["safe_to_exit"]:
            raise ValueError("Actual contract reader did not settle physical ownership")
        application["complete_parity_passed"] = True
        prior["configured_reader"] = application
        manifest["retained_application_value_sha256"] = sha(encode(actual["application"]))
        manifest["retained_fixed_value_sha256"] = sha(encode(actual["installation"]))
        write_new(packet / "fresh-contract-observation.json", actual)
        write_new(
            packet / "fresh-runtime.json",
            dict(
                prior=prior,
                retained_application_value_sha256=manifest["retained_application_value_sha256"],
                retained_fixed_value_sha256=manifest["retained_fixed_value_sha256"],
            ),
        )
        record["three_contracts_passed"] = True
        save()
        run_business(packet, manifest, prior, owner, record, save)
        record["outcome"] = (
            "completed_without_full_engine_overlap"
            if not record["both_engine_orders_passed"]
            else "completed_with_cost_miss" if not record["reader_batch_cost_passed"] else "passed"
        )
        record["stage"] = "fresh genuine release, two captures and independent consumer verified"
    except BaseException as error:
        record["outcome"] = "failed"
        record["first_failure"] = dict(stage=record["stage"], **sql_error_facts(error))
        from configured_reader import refusal_facts

        record["failure_chain"] = refusal_facts(error)
    finally:
        # Close each owned cursor/connection at most once. Unknown handles block
        # successors and preserve this process for inspection.
        for held in list(HELD):
            if isinstance(held, SqlOwner):
                try:
                    held.close()
                except BaseException as error:
                    record["cleanup_failures"].append(
                        dict(operation="admin close", error_type=type(error).__name__)
                    )
        if not HELD:
            try:
                owner = SqlOwner("master", record, save)
                if record["login_enable_attempted"]:
                    owner.mutate(
                        "disable existing application login after grouped checks", control.DISABLE
                    )
                require_login(owner.read)
                record["login_disabled"] = True
                require_services(owner.read(cost.SERVICES_SQL))
                current = state.normalized(owner.read(state.DATABASES))
                record["databases_after"] = current
                if record.get("databases_named"):
                    # The only permitted additional database is our acknowledged
                    # fresh DB18 recovery snapshot, never an original replacement.
                    snapshots = [
                        r
                        for r in current
                        if r["database_id"]
                        not in {v["database_id"] for v in record["databases_before"]}
                    ]
                    if snapshots and (
                        len(snapshots) != 1
                        or not record.get("snapshot")
                        or snapshots[0]["database_id"] != record["snapshot"]["database_id"]
                        or snapshots[0]["source_database_id"] != 18
                    ):
                        raise ValueError("Unexpected additional database")
                    retained = [r for r in current if r not in snapshots]
                    if (
                        retained != record["databases_named"]
                        or state.normalized(owner.read(state.FILE_IDENTITIES))
                        != record["files_before"]
                    ):
                        raise ValueError("Database or physical files changed after handover")
                db = next(r for r in current if r["database_id"] == 16)
                owner.close()
                owner = SqlOwner(db["name"], record, save)
                expected_date = original["database"]["target"][0]["create_date"]
                if record.get("databases_named"):
                    acknowledged = next(
                        r for r in record["databases_named"] if r["database_id"] == 16
                    )
                    if acknowledged["name"] != db["name"]:
                        raise ValueError("Original name change is not acknowledged")
                    expected_date = acknowledged["create_date"]
                elif db["name"] != "ROK_TRACKER":
                    raise ValueError("Original rename outcome requires reconciliation")
                expected = state.expected_original(original, db["name"], expected_date)
                record["original_after"] = state.original_state(owner, expected, db["name"])
                if (
                    record["original_after"]["modules"]
                    != baseline["fresh_restore_preservation"]["modules"]
                ):
                    raise ValueError("Original modules changed")
                expected_owner = baseline["fresh_restore_preservation"]["database_owner"][0].copy()
                expected_owner["name"] = db["name"]
                if record["original_after"]["owner"] != [expected_owner]:
                    raise ValueError("Original dbo owner changed")
                record["original_preserved"] = True
                owner.close()
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="final preservation", **sql_error_facts(error))
                )
                if owner is not None and owner in HELD:
                    try:
                        owner.close()
                    except BaseException:
                        pass
        record["physical_custody_retained"] = bool(HELD)
        if record["cleanup_failures"] or HELD or record["login_disabled"] is not True:
            record["outcome"] = "failed"
        record["finished"] = stamp()
        try:
            save()
            write_new(packet / "receipt.json", record)
        finally:
            while HELD:
                time.sleep(1)
    return (
        0
        if record["outcome"]
        in ("passed", "completed_with_cost_miss", "completed_without_full_engine_overlap")
        else 1
    )


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    restore = require_packet(packet, manifest)
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    if len(sys.argv) == 1:
        if manifest["purpose"] == OVERLAP_PURPOSE:
            from business_overlap import parent as continuation

            return continuation(packet, manifest, restore)
        return parent(packet, manifest, restore)
    if len(sys.argv) != 5 or sys.argv[1] != "--role" or sys.argv[3] != "--index":
        raise ValueError("Exact fresh child entry required")
    role, index = sys.argv[2], int(sys.argv[4])
    if (
        role not in ("producer", "reader", "consumer")
        or index not in (1, 2)
        or (role == "consumer" and index != 1)
        or (manifest["purpose"] == OVERLAP_PURPOSE and role != "consumer" and index != 2)
    ):
        raise ValueError("Exact child role required")
    context = json.loads((packet / "fresh-runtime.json").read_bytes())
    if (
        context["prior"]["configured_reader"]["complete_parity_passed"] is not True
        or context["prior"]["configured_reader"]["native_application_receipt"]["database_id"] != 18
    ):
        raise ValueError("Actual fresh committed application binding required")
    manifest.update(
        {
            k: context[k]
            for k in ("retained_application_value_sha256", "retained_fixed_value_sha256")
        }
    )
    from producer_runtime import run_role

    return run_role(packet, manifest, context["prior"], role, index)


if __name__ == "__main__":
    try:
        result = main()
    except BaseException as error:
        sys.stderr.write(json.dumps(dict(outcome="failed", error_type=type(error).__name__)) + "\n")
        result = 1
    raise SystemExit(result)
