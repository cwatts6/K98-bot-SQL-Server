"""Two fresh real publisher invocations; completed work is never replayed."""

import json
import os
from pathlib import Path
import re
import sys
from uuid import UUID

PURPOSE = "preserved-db18-publisher-orders"


def require_packet(packet, manifest):
    from independent_readers import sha

    requests = manifest.get("publisher_operations", [])
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("target_database_id") != 18
        or manifest.get("production_eligible") is not False
        or manifest.get("business_operations") != 2
        or manifest.get("maintenance_dispatches") != 0
        or manifest.get("recovery_replayed") is not False
        or manifest.get("preserve_capture_count") != 5
        or manifest.get("orders") != ["publisher_first", "observer_first"]
        or len(requests) != 2
        or len(set(requests)) != 2
        or any(str(UUID(v)) != v for v in requests)
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
    ):
        raise ValueError("Exact sealed two-publication fixture required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed publisher member changed")


def preflight(packet, manifest, record, save, admin, prior, old_manifest):
    import maintenance_result
    import publisher_baseline as baseline
    import publisher_state as state
    from remaining_actors import canonical, require_headroom

    record["stage"] = "authenticate exact completed maintenance and publisher baseline"
    latest = state.authenticate(packet)
    maintenance = maintenance_result.authenticate(packet)
    record["maintenance_adjudication"] = maintenance_result.adjudicate(maintenance)
    if (
        prior["original_after"] != latest["before"]["original"]
        or record["completed_before"] != latest["before"]["completed"]
        or record["databases_before"] != latest["before"]["databases"]
    ):
        raise ValueError("Completed evidence chains diverge")
    for key in (
        "configuration",
        "source_windows",
        "header",
        "kvk_work",
        "table_sizes",
        "database_options",
        "module_identities",
    ):
        if canonical(admin.read(baseline.QUERIES[key])) != latest["publisher_baseline"][key]:
            raise ValueError(
                "Publisher inputs or source identities changed before dispatch: " + key
            )
    current = state.read(admin)
    for key in ("work", "kvk", "stats"):
        if current[key] != latest["before"]["maintenance"][key]:
            raise ValueError("Completed maintenance changed")
    if current["generation"] != 433:
        raise ValueError("Original generation changed; do not replay")
    require_headroom(current)
    record["publisher_prestate"] = current
    record["publisher_baseline_receipt_sha256"] = state.RECEIPT_SHA
    record["maintenance_dispatches"] = 0
    save()


def compare(collected, actual, value):
    from independent_readers import encode, sha

    # run_contracts already performed all three independently pinned comparators.
    # Raw application evidence may legitimately reflect a new pending output.
    for key in ("installation", "legacy"):
        if sha(encode(collected[key])) != sha(encode(actual[key])):
            raise ValueError("Fixed/legacy contract changed during publication")
    value["application_value_sha256"] = sha(encode(collected["application"]))
    value["observed_generation"] = collected["application_observation"]["generation"]
    value["complete_parity_passed"] = True


def run_checks(packet, manifest, record, save, admin, actual, sources, *, start_index=1):
    from fresh_business_owner import HELD
    from independent_readers import write_new
    import maintenance_continuation
    import producer_runtime as runtime
    import publisher_state as state
    import publisher_worker
    import remaining_actors as actors
    from retained_reader_cost import application_group
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts

    candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
    before = record["publisher_prestate"]
    group = record["publisher_coexistence"] = dict(
        cases=[],
        batch_cost_passed=True,
        both_functional_orders=False,
        observer_first_engine_overlap=False,
    )
    for index, (order, operation) in enumerate(
        zip(manifest["orders"], manifest["publisher_operations"], strict=True), start_index
    ):
        record["stage"] = "actual KVK publisher and observer: " + order
        value = {}
        group["cases"].append(value)
        first = None

        def dispatch(once, request, worker):
            record["business_operations"] += 1
            return publisher_worker.run(once, request, worker, save)

        def comparison(collected, worker):
            compare(collected, actual, worker)
            write_new(packet / (order + "-overlap-observation.json"), collected)

        try:
            with runtime.application_credentials(manifest):
                actors.case(
                    admin,
                    manifest,
                    candidate,
                    actual,
                    order,
                    operation,
                    value,
                    save,
                    operational_factory=maintenance_continuation.operational_connections,
                    actor_role="publisher",
                    actor_dispatch=dispatch,
                    compare_observation=comparison,
                )
        except BaseException as error:
            first = error
        # Reconcile settled effects even when an observer/comparator failed.
        # Retained physical owners forbid a second connection or new business.
        if not any(item is not admin for item in HELD):
            try:
                after = state.read(admin)
                value["durable_poststate"] = after
                write_new(
                    packet / (order + "-durable-poststate.json"),
                    dict(
                        operation_id=operation,
                        database_id=18,
                        database_guid="9DC35927-02A8-4C11-BC05-210381ECA28D",
                        state=after,
                    ),
                )
                state.require_delta(before, after, index)
                value["publication_committed"] = True
                save()
            except BaseException as error:
                value["poststate_failure"] = sql_error_facts(error)
                if first is None:
                    first = error
                else:
                    first.add_note(
                        "Post-publication reconciliation failed: " + type(error).__name__
                    )
        elif first is None:
            first = ValueError("Original publisher/observer ownership remains unresolved")
        if first is not None:
            raise first
        record["stage"] = "fresh complete post-publication contracts: " + order

        def post(connect, worker):
            observed = control.run_contracts(connect, candidate, manifest["release"], worker)
            compare(observed, actual, worker)
            state.require_post_observation(observed, after)
            write_new(packet / (order + "-post-observation.json"), observed)

        key = order + "_post_contracts"
        application_group(manifest, record, key, post)
        value["post_contracts_passed"] = True
        group["batch_cost_passed"] &= value["workers"]["observer"][
            "maximum_batch_seconds"
        ] <= 0.250 and all(
            s["execute_seconds"] + s["fetch_seconds"] <= 0.250
            for s in record[key]["application_reader"]["statements"]
        )
        before = after
        save()
        if not value["functional_passed"]:
            group["remaining_order_unstarted"] = True
            break
    group["both_functional_orders"] = len(group["cases"]) == 2 and all(
        c["functional_passed"] and c["publication_committed"] and c["post_contracts_passed"]
        for c in group["cases"]
    )
    group["observer_first_engine_overlap"] = (
        len(group["cases"]) == 2 and group["cases"][1]["engine_overlap"]
    )
    group["settled_state"] = before
    save()


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    require_packet(packet, manifest)
    if len(sys.argv) != 1:
        raise ValueError("Exact publisher parent entry only")
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    from retained_reader_cost import run

    return run(packet, manifest, actor_checks=run_checks, preflight=preflight)


if __name__ == "__main__":
    raise SystemExit(main())
