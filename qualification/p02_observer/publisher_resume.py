"""Preserve both committed publications; qualify one fresh observer-first case."""

import json
import os
from pathlib import Path
import re
import sys
from uuid import UUID

PURPOSE = "preserved-db18-publisher-continuation"
PRIOR = Path("Q:/P02Observer/20261122104807927")
RECEIPT_SHA = "57859b76eda21d26cd08b9c1848c45afdd50863e84ecfded2d9f4c9253e1dd1d"
ARCHIVE_SHA = "1d41b63754a5255ae9733b439e9edc2707c8f54cc2ea6fc5eb991a0069afe7aa"


def adjudicate(value):
    import publisher_state

    wanted = dict(
        outcome="failed",
        first_failure=dict(
            stage="actual KVK publisher and observer: observer_first", error_type="ValueError"
        ),
        cleanup_failures=[],
        original_preserved=True,
        login_disabled=True,
        physical_custody_retained=False,
        business_operations=2,
        maintenance_dispatches=0,
        restore_replayed=False,
        storage_replayed=False,
        migration_replayed=False,
        completed_reports_replayed=False,
        original_claim_released=False,
    )
    if any(value.get(k) != v for k, v in wanted.items()):
        raise ValueError("Exact settled publisher failure required")
    if (
        value["original_before"] != value["original_after"]
        or value["databases_before"] != value["databases_after"]
    ):
        raise ValueError("Retained claim or fixture changed")
    cases = value["publisher_coexistence"]["cases"]
    if [c["order"] for c in cases] != ["publisher_first", "observer_first"]:
        raise ValueError("Exact completed order pair required")
    before = value["publisher_prestate"]
    for index, case in enumerate(cases, 1):
        if case["first_failure"] or case["cleanup_failures"] or not case["ordering_proven"]:
            raise ValueError("Original ordered entry differs")
        worker = case["workers"]["publisher"]
        observer = case["workers"]["observer"]
        if (
            worker["outcome"] != "passed"
            or not worker.get("publisher_response_acknowledged")
            or worker["result"]["operation_id"] != case["request_id"]
        ):
            raise ValueError("Original publisher must have acknowledged response")
        for role in (worker, observer):
            if (
                not role["physical_cleanup"]["safe_to_exit"]
                or not role["physical_cleanup"]["all_closed_by_callers"]
            ):
                raise ValueError("Original owner remains unresolved")
        publisher_state.require_delta(before, case["durable_poststate"], index)
        before = case["durable_poststate"]
    if (
        not cases[0]["publication_committed"]
        or not cases[0]["post_contracts_passed"]
        or not cases[0]["functional_passed"]
    ):
        raise ValueError("First accepted publication must remain complete")
    last = cases[1]
    if (
        last["workers"]["observer"]["first_failure"]
        != dict(error_type="ProgrammingError", sqlstate="42000", native_code=1222)
        or last.get("poststate_failure") != dict(error_type="ValueError")
        or before["generation"] != 461
    ):
        raise ValueError("Exact catalogue timeout and tied-rank check required")
    from recovery_coexistence import overlap

    if not last["engine_overlap"] or not any(
        overlap(
            s["rows"],
            last["workers"]["publisher"]["identity"],
            last["workers"]["observer"]["connections"],
        )
        for s in last["samples"]
    ):
        raise ValueError("Original native engine overlap must be retained")
    return dict(
        outcome="both_publications_committed_observer_first_incomplete",
        first_revision=538,
        second_revision=539,
        generation=461,
        rank_rule="complete integer DKP descending intervals; ties unconstrained by source",
        original_receipt_sha256=RECEIPT_SHA,
    )


def authenticate(packet):
    from independent_readers import sha

    raw = (packet / "evidence/publisher-failed.json").read_bytes()
    if (
        sha(raw) != RECEIPT_SHA
        or raw != (PRIOR / "receipt.json").read_bytes()
        or sha((PRIOR / "packet.zip").read_bytes()) != ARCHIVE_SHA
    ):
        raise ValueError("Exact original publisher packet required")
    value = json.loads(raw)
    adjudicate(value)
    observation = (packet / "evidence/publisher-original-observation.json").read_bytes()
    if observation != (PRIOR / "fresh-contract-observation.json").read_bytes():
        raise ValueError("Original complete source observation changed")
    return value, json.loads(observation)


def require_packet(packet, manifest):
    from independent_readers import sha

    requests = manifest.get("publisher_operations", [])
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("target_database_id") != 18
        or manifest.get("production_eligible") is not False
        or manifest.get("business_operations") != 1
        or manifest.get("maintenance_dispatches") != 0
        or manifest.get("recovery_replayed") is not False
        or manifest.get("preserve_capture_count") != 5
        or manifest.get("orders") != ["observer_first"]
        or len(requests) != 1
        or str(UUID(requests[0])) != requests[0]
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
    ):
        raise ValueError("Exact one-fresh-publication continuation required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed continuation member changed")


def require_unentered_attempt(packet):
    from independent_readers import sha

    prior = Path("Q:/P02Observer/20261122110846878")
    raw = (packet / "evidence/publisher-entry-failure.txt").read_bytes()
    if (
        sha(raw) != "918275c9ca90cc20869674a492e535144d023b6d67f34e216a7296224bc7305d"
        or raw != (prior / "stderr.txt").read_bytes()
        or sha((prior / "packet.zip").read_bytes())
        != "8ba7b76b8ac5cd42d0dfeb3ae863b5a0d5d4de45e519319d3eab44a3c0be2de4"
        or (prior / "stdout.txt").read_bytes() != b""
        or any(
            (prior / name).exists() for name in ("entered.json", "progress.json", "receipt.json")
        )
    ):
        raise ValueError(
            "Exact stopped pre-entry failure required; unresolved work is not replayable"
        )


def preflight(packet, manifest, record, save, admin, prior, old_manifest):
    import publisher_baseline
    import publisher_state
    from remaining_actors import canonical, require_headroom

    require_unentered_attempt(packet)
    previous, _ = authenticate(packet)
    baseline = publisher_state.authenticate(packet)
    record["stage"] = "preserve both completed publications before any fresh work"
    record["publisher_adjudication"] = adjudicate(previous)
    if manifest["publisher_operations"][0] in {
        c["request_id"] for c in previous["publisher_coexistence"]["cases"]
    }:
        raise ValueError("A completed invocation cannot be reused")
    if (
        record["original_before"] != previous["original_after"]
        or record["databases_before"] != previous["databases_after"]
        or record["completed_before"] != previous["completed_before"]
    ):
        raise ValueError("Original completed ownership changed")
    current = publisher_state.read(admin)
    expected = previous["publisher_coexistence"]["cases"][1]["durable_poststate"]
    if {k: v for k, v in current.items() if k != "log"} != {
        k: v for k, v in expected.items() if k != "log"
    }:
        raise ValueError("Exact second committed output changed; no new business")
    require_headroom(current)
    for key in ("configuration", "source_windows", "module_identities", "database_options"):
        if (
            canonical(admin.read(publisher_baseline.QUERIES[key]))
            != baseline["publisher_baseline"][key]
        ):
            raise ValueError("Original source/configuration changed")
    record["publisher_prestate"] = current
    record["maintenance_dispatches"] = 0
    save()


def contract_check(packet, manifest, record, actual, group):
    import publisher_orders
    import publisher_state

    _, original = authenticate(packet)
    publisher_orders.compare(actual, original, group)
    publisher_state.require_post_observation(actual, record["publisher_prestate"])


def run_checks(packet, manifest, record, save, admin, actual, sources):
    import producer_runtime as runtime
    import publisher_orders
    from retained_reader_cost import application_group

    def captures(connect, group):
        group["sources"] = []
        for native, source, context, _ in sources:
            item = {}
            group["sources"].append(item)
            runtime.consumer(native, source, context["prior"], item, connect)
            if item.get("outcome") != "passed":
                raise ValueError("Retained capture readback failed")
        if sum(len(v["captures"]) for v in group["sources"]) != 5:
            raise ValueError("Exactly five original captures required")
        group["outcome"] = "passed"

    record["stage"] = "finish five retained capture checks before fresh publication"
    application_group(manifest, record, "captures_before_publication", captures)
    publisher_orders.run_checks(
        packet, manifest, record, save, admin, actual, sources, start_index=3
    )
    group = record["publisher_coexistence"]
    case = group["cases"][0]
    group["retained_publisher_first_receipt_sha256"] = RECEIPT_SHA
    group["both_functional_orders"] = bool(
        case.get("functional_passed")
        and case.get("publication_committed")
        and case.get("post_contracts_passed")
    )
    group["observer_first_engine_overlap"] = case["engine_overlap"]
    save()


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    require_packet(packet, manifest)
    if len(sys.argv) != 1:
        raise ValueError("Exact continuation parent entry only")
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    from retained_reader_cost import run

    return run(
        packet,
        manifest,
        actor_checks=run_checks,
        preflight=preflight,
        contract_check=contract_check,
    )


if __name__ == "__main__":
    raise SystemExit(main())
