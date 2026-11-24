"""One remaining real producer-first case; preserve every completed stage."""

import json
import os
import time


def parent(packet, manifest, restore):
    import business_overlap_state as previous
    import fixed_contract_cost as cost
    from fresh_business import require_login, snapshot, stamp
    from fresh_business_owner import HELD, SqlOwner
    import fresh_business_state as state
    from independent_readers import encode, sha, write_new
    from producer_capture import dependency_preflight, private_spool, require_post_business
    import producer_fixture as fixture
    import producer_pair as pair
    import producer_runtime as runtime
    from release_boundary import owner_inventory
    from restart_read import require_services
    from scripts.verify_k98_running_release import sql_error_facts
    import three_contracts as control

    record = dict(
        schema="p02-remaining-report-overlap/1",
        outcome="running",
        started=stamp(),
        stage="authenticate completed grouped work",
        first_failure=None,
        cleanup_failures=[],
        actions=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        cases=[],
        login_enable_attempted=False,
        login_disabled=None,
        original_preserved=False,
        physical_custody_retained=False,
        production_operations=0,
        provider_operations=0,
        restore_replayed=False,
        storage_replayed=False,
        migration_replayed=False,
        completed_reports_replayed=False,
        original_claim_released=False,
    )

    def save():
        temporary = packet / "progress.pending"
        temporary.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        temporary.replace(packet / "progress.json")

    write_new(packet / "entered.json", dict(pid=os.getpid(), started=stamp()))
    prior = old_manifest = context = None
    owner = None
    try:
        if manifest.get("capture_indices") != [2] or manifest.get("prepared_reader") is not True:
            raise ValueError("One declared fresh producer-first case required")
        state.require_restore(restore)
        prior, old_manifest, context = previous.load_prior(packet, manifest)
        record["completed_receipt_sha256"] = context.get(
            "_latest_receipt_sha256", previous.RECEIPT_SHA
        )
        record["dependencies"] = dependency_preflight()
        owner = SqlOwner("master", record, save)
        state.require_identity(owner.read(state.IDENTITY), "master", 1)
        require_login(owner.read)
        require_services(owner.read(cost.SERVICES_SQL))
        if owner.read(state.SESSIONS) or owner.read(state.LOCKS):
            raise ValueError("Foreign target activity prevents continuation")
        record["databases_before"] = previous.require_inventory(owner, prior)
        owner.close()
        owner = SqlOwner(state.RETAINED, record, save)
        record["original_before"] = state.original_state(
            owner, prior["original_after"]["state"], state.RETAINED
        )
        if record["original_before"] != prior["original_after"]:
            raise ValueError("Original retained claim or setup changed")
        owner.close()
        owner = SqlOwner("ROK_TRACKER", record, save)
        if context.get("_failed_control") is not None:
            from business_barrier_resume import reconcile

            record["stage"] = "reconcile fourth committed capture without replay"
            prior, old_manifest, context = reconcile(owner, prior, old_manifest, context, record)
            record["completed_receipt_sha256"] = context["_latest_receipt_sha256"]
        record["completed_before"] = previous.require_fresh(owner, prior, old_manifest)
        if manifest.get("control_release_preflight") is True:
            from report_barrier import ReportBarrier

            record["stage"] = "verify direct control release before any new business"
            release_check = {}
            record["control_release_preflight"] = release_check
            barrier = ReportBarrier(release_check, save, manifest["barrier_expected_rows"])
            try:
                barrier.acquire()
                barrier.release()
            finally:
                barrier.finish()
            release_check["outcome"] = "passed"
        live = dict(owners_after=owner_inventory(owner.connection))
        record["business_preflight"] = fixture.preflight(owner.connection, packet, manifest, live)
        record["stage"] = "fresh recovery snapshot before one remaining case"
        record["snapshot_attempted"] = True
        save()
        record["snapshot"] = snapshot(owner, manifest)
        record["private_fixture"] = private_spool(manifest)
        write_new(
            packet / "stage-1.json",
            dict(
                preflight=record["business_preflight"],
                snapshot=record["snapshot"],
                private_fixture=record["private_fixture"],
            ),
        )
        record["login_enable_attempted"] = True
        save()
        owner.mutate("enable existing application login for remaining case", control.ENABLE)
        record["login_disabled"] = False
        connections = runtime.Connections()
        application = {}
        record["configured_reader"] = application
        try:
            with runtime.application_credentials(manifest):
                actual = control.run_contracts(
                    connections,
                    json.loads((packet / "candidate-contracts.json").read_bytes()),
                    manifest["release"],
                    application,
                )
        finally:
            cleanup = connections.finish()
            application["physical_cleanup"] = cleanup
            if not cleanup["safe_to_exit"]:
                HELD.append(connections)
        if not cleanup["all_closed_by_callers"] or not cleanup["safe_to_exit"]:
            raise ValueError("Actual reader cleanup unconfirmed")
        if (
            application["native_application_receipt"]
            != prior["configured_reader"]["native_application_receipt"]
        ):
            raise ValueError("Completed native release binding changed")
        for k, section in (
            ("retained_application_value_sha256", "application"),
            ("retained_fixed_value_sha256", "installation"),
        ):
            value = sha(encode(actual[section]))
            if value != context[k]:
                raise ValueError("Completed contract rows changed")
            manifest[k] = value
        application["complete_parity_passed"] = True
        live["configured_reader"] = application
        write_new(packet / "fresh-contract-observation.json", actual)
        write_new(
            packet / "fresh-runtime.json",
            dict(
                prior=live,
                **{
                    k: manifest[k]
                    for k in ("retained_application_value_sha256", "retained_fixed_value_sha256")
                },
            ),
        )
        record["three_contracts_passed"] = True
        if manifest.get("resume_control_failure") is not None:
            from business_barrier_resume import read_captures

            record["stage"] = "verify all four committed captures before new business"
            read_captures(context, record, runtime, HELD)
            save()
        record["stage"] = "one new producer-first report and prepared reader"
        case = {}
        record["cases"].append(case)
        save()
        pair.run_pair(packet, manifest, owner.connection, 2, case, save)
        case["report_after"] = owner.read(fixture.REPORT_VALUE_SQL)
        record["stage"] = "independent new capture consumer"
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
            raise ValueError("Original new consumer did not settle successfully")
        record["consumer"] = value
        record["business_after"] = require_post_business(
            owner.connection, manifest, record["business_preflight"], [case]
        )
        write_new(packet / "stage-9.json", record["business_after"])
        record["stage"] = "reread all preceding completed immutable captures"
        connections = runtime.Connections()
        retained = {}
        record["retained_capture_readback"] = retained
        try:
            with runtime.application_credentials(old_manifest):
                sources = context.get("_retained_sources")
                if sources is None:
                    runtime.consumer(
                        previous.PRIOR, old_manifest, context["prior"], retained, connections
                    )
                else:
                    from pathlib import Path

                    retained["sources"] = []
                    for directory, source_manifest, source_prior in sources:
                        result = {}
                        retained["sources"].append(result)
                        runtime.consumer(
                            Path(directory), source_manifest, source_prior, result, connections
                        )
                        if result.get("outcome") != "passed":
                            raise ValueError("A preceding capture source did not verify")
                    retained["outcome"] = "passed"
        finally:
            cleanup = connections.finish()
            retained["physical_cleanup"] = cleanup
            if not cleanup["safe_to_exit"]:
                HELD.append(connections)
        if (
            retained.get("outcome") != "passed"
            or not cleanup["all_closed_by_callers"]
            or not cleanup["safe_to_exit"]
        ):
            raise ValueError("Retained capture readback or cleanup differs")
        record["completed_after"] = previous.require_fresh(owner, prior, old_manifest, after=True)
        reader = json.loads((packet / "stage-6.json").read_bytes())
        record["functional_capture_passed"] = True
        record["reader_batch_cost_passed"] = reader["maximum_batch_seconds"] <= 0.250
        record["producer_first_engine_overlap"] = case[
            "simultaneous_running_or_runnable"
        ] and case.get("first_request_observed", False)
        record["outcome"] = (
            "completed_without_engine_overlap"
            if not record["producer_first_engine_overlap"]
            else "completed_with_cost_miss" if not record["reader_batch_cost_passed"] else "passed"
        )
    except BaseException as error:
        record["outcome"] = "failed"
        record["first_failure"] = dict(stage=record["stage"], **sql_error_facts(error))
        from configured_reader import refusal_facts

        record["failure_chain"] = refusal_facts(error)
    finally:
        for held in list(HELD):
            if isinstance(held, SqlOwner):
                try:
                    held.close()
                except BaseException as error:
                    record["cleanup_failures"].append(
                        dict(operation="admin close", **sql_error_facts(error))
                    )
        if not HELD and prior is not None:
            try:
                owner = SqlOwner("master", record, save)
                if record["login_enable_attempted"]:
                    owner.mutate(
                        "disable existing application login after remaining case", control.DISABLE
                    )
                require_login(owner.read)
                record["login_disabled"] = True
                require_services(owner.read(cost.SERVICES_SQL))
                record["databases_after"] = previous.require_inventory(
                    owner, prior, record.get("snapshot")
                )
                owner.close()
                owner = SqlOwner(state.RETAINED, record, save)
                record["original_after"] = state.original_state(
                    owner, prior["original_after"]["state"], state.RETAINED
                )
                if record["original_after"] != prior["original_after"]:
                    raise ValueError("Original claim or setup changed")
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
        in ("passed", "completed_with_cost_miss", "completed_without_engine_overlap")
        else 1
    )
