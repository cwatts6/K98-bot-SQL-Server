"""Retained-state comparisons, full contracts and explicitly declared actor checks."""

from datetime import UTC, datetime
import json
import os
from pathlib import Path
import statistics
import sys
import threading
import time


def index_queries():
    from services import export_execution_dal as dal

    return dict(
        original="WITH required AS (SELECT OBJECT_ID(value) AS object_id FROM OPENJSON(?)) "
        + dal._METADATA_QUERIES["indexes"],
        candidate=dal._APPLICATION_SCOPED_METADATA["indexes"].replace("@scope", "?"),
    )


def index_pairs(connect, expected, record, save, *, clock=time.monotonic):
    from independent_readers import encode, sha

    from scripts.verify_k98_running_release import ObservationConnections
    from services.export_execution_dal import INSTALLATION_OBJECTS, rows

    queries = index_queries()
    group = record["index_pairs"] = dict(samples=[], cost_passed=True, warmups=1, pairs=5)
    started = clock()
    # Alternate both ways, and separate the warmup from all five measurements.
    for index in range(6):
        order = ("original", "candidate") if index % 2 == 0 else ("candidate", "original")
        sample = dict(index=index, warmup=index == 0, order=order, reads=[])
        group["samples"].append(sample)
        for kind in order:
            if clock() - started >= 90:
                raise TimeoutError("Index group exhausted; do not start another read")
            owner = ObservationConnections(connect)
            value = dict(kind=kind, outcome="running")
            sample["reads"].append(value)
            save()
            try:
                with owner:
                    owner.observation_phase("export")
                    connection = owner()
                    cursor = connection.cursor()
                    try:
                        cursor.execute(queries[kind], json.dumps(sorted(INSTALLATION_OBJECTS)))
                        actual = rows(cursor)
                        if actual != expected:
                            raise ValueError("Complete index catalogue rows differ")
                        value.update(rows=len(actual), value_sha256=sha(encode(actual)))
                    finally:
                        cursor.close()
                    connection.close()
                value["outcome"] = "passed"
            finally:
                value["reader"] = owner.evidence()
                save()
            sql_sha = sha(queries[kind].encode())
            statements = [s for s in value["reader"]["statements"] if s["sql_sha256"] == sql_sha]
            if len(statements) != 1:
                raise ValueError("One original SQL dispatch required per index sample")
            value["batch_seconds"] = (
                statements[0]["execute_seconds"] + statements[0]["fetch_seconds"]
            )
            if kind == "candidate":
                group["cost_passed"] &= value["batch_seconds"] <= 0.250
            save()
    group["distribution"] = {}
    for kind in queries:
        values = sorted(
            v["batch_seconds"]
            for s in group["samples"]
            if not s["warmup"]
            for v in s["reads"]
            if v["kind"] == kind
        )
        group["distribution"][kind] = dict(
            median=statistics.median(values),
            maximum=max(values),
            p95=max(values),
            p95_method="nearest rank; five samples",
            count=len(values),
        )
    group["seconds"] = clock() - started
    group["scope"] = "Index query comparison only; not business OFF/ON cost or overlap acceptance"


def application_group(manifest, record, key, callback):
    from fresh_business_owner import HELD
    import producer_runtime as runtime

    connections = runtime.Connections()
    group = record[key] = {}
    first = None
    try:
        with runtime.application_credentials(manifest):
            return callback(connections, group)
    except BaseException as error:
        first = error
        from scripts.verify_k98_running_release import sql_error_facts

        group["first_failure"] = sql_error_facts(error)
        raise
    finally:
        cleanup = connections.finish()
        group["physical_cleanup"] = cleanup
        if not cleanup["safe_to_exit"]:
            HELD.append(connections)
        if first is None and (not cleanup["safe_to_exit"] or not cleanup["all_closed_by_callers"]):
            raise ValueError("Original application cleanup did not complete")


def run(packet, manifest, *, actor_checks=None, preflight=None, contract_check=None):
    import business_overlap_state as previous
    import fixed_contract_cost as cost
    from fresh_business import require_login
    from fresh_business_owner import HELD, SqlOwner
    import fresh_business_state as state
    from independent_readers import encode, sha, write_new
    from restart_read import require_services
    import retained_reader_state as retained
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts

    record = dict(
        schema="p02-retained-reader-cost/1",
        outcome="running",
        started=stamp(),
        stage="authenticate completed work",
        first_failure=None,
        cleanup_failures=[],
        actions=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        login_enable_attempted=False,
        login_disabled=None,
        original_preserved=False,
        physical_custody_retained=False,
        production_operations=0,
        provider_operations=0,
        business_operations=0,
        restore_replayed=False,
        storage_replayed=False,
        migration_replayed=False,
        completed_reports_replayed=False,
        original_claim_released=False,
    )

    save_lock = threading.RLock()

    def save():
        with save_lock:
            tmp = packet / "progress.pending"
            tmp.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
            tmp.replace(packet / "progress.json")

    write_new(packet / "entered.json", dict(pid=os.getpid(), started=stamp()))
    prior = old_manifest = sources = None
    owner = None
    try:
        prior, old_manifest, sources = retained.authenticate(packet, manifest)
        record["preserved_receipt_sha256"] = retained.SOURCES[-1][1]
        owner = SqlOwner("master", record, save)
        state.require_identity(owner.read(state.IDENTITY), "master", 1)
        require_login(owner.read)
        require_services(owner.read(cost.SERVICES_SQL))
        if owner.read(state.SESSIONS) or owner.read(state.LOCKS):
            raise ValueError("Foreign activity prevents read-only qualification")
        record["databases_before"] = previous.require_inventory(owner, prior)
        owner.close()
        owner = SqlOwner(state.RETAINED, record, save)
        record["original_before"] = state.original_state(
            owner, prior["original_after"]["state"], state.RETAINED
        )
        if record["original_before"] != prior["original_after"]:
            raise ValueError("Original retained claim changed")
        owner.close()
        owner = SqlOwner("ROK_TRACKER", record, save)
        record["completed_before"] = previous.require_fresh(owner, prior, old_manifest)
        if actor_checks is None:
            record["plans_before"] = {
                k: owner.read(cost.PLAN_SQL, sql) for k, sql in index_queries().items()
            }
        if manifest["purpose"] in (retained.ACTOR_PURPOSE, retained.MAINTENANCE_PURPOSE):
            from remaining_actors import read_cached_plans

            read_cached_plans(owner, record)
        if preflight is not None:
            preflight(packet, manifest, record, save, owner, prior, old_manifest)
        record["login_enable_attempted"] = True
        save()
        owner.mutate("enable existing application login for declared qualification", control.ENABLE)
        record["login_disabled"] = False

        def contracts(connect, group):
            candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
            actual = control.run_contracts(connect, candidate, manifest["release"], group)
            if (
                group["native_application_receipt"]
                != prior["configured_reader"]["native_application_receipt"]
            ):
                raise ValueError("Committed application release binding changed")
            if contract_check is not None:
                contract_check(packet, manifest, record, actual, group)
            else:
                for section, key in (
                    ("application", "retained_application_value_sha256"),
                    ("installation", "retained_fixed_value_sha256"),
                ):
                    if sha(encode(actual[section])) != sources[-1][2][key]:
                        raise ValueError("Complete retained contract rows changed")
            group["complete_parity_passed"] = True
            write_new(packet / "fresh-contract-observation.json", actual)
            return actual

        record["stage"] = "complete candidate three-contract comparison"
        actual = application_group(manifest, record, "contracts", contracts)
        if actor_checks is not None:
            actor_checks(packet, manifest, record, save, owner, actual, sources)
        else:
            record["stage"] = "balanced original and candidate index reads"
            application_group(
                manifest,
                record,
                "query_group",
                lambda connect, group: index_pairs(
                    connect, actual["installation"]["metadata"]["indexes"], group, save
                ),
            )
            record["stage"] = "complete fixed contract cost and parity"
            from fixed_reader_cost import qualify

            candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
            application_group(
                manifest,
                record,
                "fixed_group",
                lambda connect, group: qualify(
                    connect,
                    candidate["sql_contract"],
                    sources[-1][2]["retained_fixed_value_sha256"],
                    group,
                    save,
                ),
            )
        record["stage"] = "verify all five retained captures"

        def captures(connect, group):
            import producer_runtime as runtime

            group["sources"] = []
            for native, source_manifest, context, _ in sources:
                value = {}
                group["sources"].append(value)
                runtime.consumer(native, source_manifest, context["prior"], value, connect)
                if value.get("outcome") != "passed":
                    raise ValueError("Retained capture failed independent verification")
            if sum(len(v["captures"]) for v in group["sources"]) != 5:
                raise ValueError("Exactly five retained captures required")
            group["outcome"] = "passed"

        application_group(manifest, record, "retained_captures", captures)
        if actor_checks is None:
            record["plans_after"] = {
                k: owner.read(cost.PLAN_SQL, sql) for k, sql in index_queries().items()
            }
        record["completed_after"] = previous.require_fresh(owner, prior, old_manifest)
        if record["completed_after"] != record["completed_before"]:
            raise ValueError("Completed database state changed during reads")
        record["maximum_contract_batch_seconds"] = max(
            s["execute_seconds"] + s["fetch_seconds"]
            for s in record["contracts"]["application_reader"]["statements"]
        )
        record["batch_cost_passed"] = record["maximum_contract_batch_seconds"] <= 0.250
        if actor_checks is None:
            record["batch_cost_passed"] &= (
                record["query_group"]["index_pairs"]["cost_passed"]
                and record["fixed_group"]["fixed_reader_repeats"]["batch_cost_passed"]
            )
        elif "publisher_coexistence" in record:
            record["batch_cost_passed"] &= record["publisher_coexistence"]["batch_cost_passed"]
        else:
            record["batch_cost_passed"] &= record["recovery_coexistence"]["batch_cost_passed"]
        if "maintenance_coexistence" in record:
            record["batch_cost_passed"] &= record["maintenance_coexistence"]["batch_cost_passed"]
            record["batch_cost_passed"] &= all(
                s["execute_seconds"] + s["fetch_seconds"] <= 0.250
                for s in record["post_maintenance_contracts"]["application_reader"]["statements"]
            )
        record["outcome"] = "passed" if record["batch_cost_passed"] else "completed_with_cost_miss"
        if (
            "recovery_coexistence" in record
            and not record["recovery_coexistence"]["both_engine_orders"]
        ):
            record["outcome"] = "completed_without_full_engine_overlap"
        if "maintenance_coexistence" in record:
            if not record["maintenance_coexistence"]["both_engine_orders"]:
                record["outcome"] = "completed_without_full_engine_overlap"
            if not record["maintenance_coexistence"]["both_functional_orders"]:
                record["outcome"] = "completed_with_deferred_observer"
        if "publisher_coexistence" in record:
            group = record["publisher_coexistence"]
            if not group["observer_first_engine_overlap"]:
                record["outcome"] = "completed_without_full_engine_overlap"
            if not group["both_functional_orders"]:
                record["outcome"] = "completed_with_deferred_observer"
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
                    owner.mutate("disable existing login after grouped checks", control.DISABLE)
                require_login(owner.read)
                record["login_disabled"] = True
                require_services(owner.read(cost.SERVICES_SQL))
                if owner.read(state.SESSIONS) or owner.read(state.LOCKS):
                    raise ValueError("Target activity remains after qualification")
                record["databases_after"] = previous.require_inventory(owner, prior)
                owner.close()
                owner = SqlOwner(state.RETAINED, record, save)
                record["original_after"] = state.original_state(
                    owner, prior["original_after"]["state"], state.RETAINED
                )
                if record["original_after"] != prior["original_after"]:
                    raise ValueError("Original retained claim changed")
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
        in (
            "passed",
            "completed_with_cost_miss",
            "completed_without_full_engine_overlap",
            "completed_with_deferred_observer",
        )
        else 1
    )


def stamp():
    return datetime.now(UTC).isoformat()


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    from retained_reader_state import require_packet

    require_packet(packet, manifest)
    if len(sys.argv) != 1:
        raise ValueError("Exact parent entry only; no business child dispatch")
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    from retained_reader_state import ACTOR_PURPOSE, MAINTENANCE_PURPOSE, RECOVERY_PURPOSE

    if manifest["purpose"] == MAINTENANCE_PURPOSE:
        from maintenance_continuation import run_checks

        return run(packet, manifest, actor_checks=run_checks)
    if manifest["purpose"] == ACTOR_PURPOSE:
        from remaining_actors import run_checks

        return run(packet, manifest, actor_checks=run_checks)

    if manifest["purpose"] == RECOVERY_PURPOSE:
        from recovery_coexistence import run_checks

        return run(packet, manifest, actor_checks=run_checks)
    return run(packet, manifest)


if __name__ == "__main__":
    raise SystemExit(main())
