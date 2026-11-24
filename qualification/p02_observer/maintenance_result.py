"""Adjudicate completed maintenance against its declared writer/yield contract."""

import hashlib
import json
from pathlib import Path

PRIOR = Path("Q:/P02Observer/20261122095859785")
RECEIPT_SHA = "c9efb5d31209cf18f94bf1fbe6bda0d11f7ccebdc3294a2525b471232ad9ca05"
ARCHIVE_SHA = "efa1d1d2227fd1a371b1fbf95aff35ba109b0f379d9561912889f03e1394492a"


def adjudicate(value):
    from recovery_coexistence import overlap
    from remaining_actors import canonical, require_after

    wanted = dict(
        outcome="completed_without_full_engine_overlap",
        first_failure=None,
        cleanup_failures=[],
        original_preserved=True,
        login_disabled=True,
        physical_custody_retained=False,
        batch_cost_passed=True,
        business_operations=0,
        provider_operations=0,
        production_operations=0,
        storage_replayed=False,
        restore_replayed=False,
        migration_replayed=False,
        completed_reports_replayed=False,
        original_claim_released=False,
    )
    if any(value.get(k) != v for k, v in wanted.items()):
        raise ValueError("Exact settled maintenance result required")
    for k in ("original", "databases", "completed"):
        if value[k + "_before"] != value[k + "_after"]:
            raise ValueError("Preserved state changed")
    for key in (
        "contracts",
        "post_maintenance_contracts",
        "captures_before_maintenance",
        "retained_captures",
    ):
        group = value[key]
        clean = group["physical_cleanup"]
        if not clean["safe_to_exit"] or not clean["all_closed_by_callers"]:
            raise ValueError("Original application handles must have closed")
        if "captures" in key:
            if (
                group["outcome"] != "passed"
                or sum(len(s["captures"]) for s in group["sources"]) != 5
                or any(s["outcome"] != "passed" for s in group["sources"])
            ):
                raise ValueError("All five captures required before and after maintenance")
        elif not group["complete_parity_passed"]:
            raise ValueError("Complete contract parity required")
    group = value["maintenance_coexistence"]
    cases = group["cases"]
    if [c["order"] for c in cases] != ["maintenance_first", "observer_first"]:
        raise ValueError("Two original completed orders required")
    before = group["before"]
    generation = 1
    accepted = []
    for index, case in enumerate(cases, 1):
        observer = case["workers"]["observer"]
        worker = case["workers"]["maintenance"]
        if (
            case["first_failure"]
            or case["cleanup_failures"]
            or not case["functional_passed"]
            or not case["ordering_proven"]
        ):
            raise ValueError("Actual useful work and ordered entry required")
        if not 0 < case["seconds"] <= 45 or not 0 < worker["seconds"] <= 300:
            raise ValueError("Existing owner budgets required")
        for role in (observer, worker):
            if (
                role["outcome"] != "passed"
                or role["first_failure"]
                or not role["physical_cleanup"]["all_closed_by_callers"]
                or not role["physical_cleanup"]["safe_to_exit"]
            ):
                raise ValueError("Original worker and reader must settle")
        if not observer["complete_parity_passed"] or observer["maximum_batch_seconds"] > 0.250:
            raise ValueError("Complete bounded catalogue comparison required")
        if len(observer["reader"]["statements"]) > 256 or any(
            r["collections"] > 2 or r["boundary_checks"] > 3 for r in observer["requests"]
        ):
            raise ValueError("No reset of continuation budget allowed")
        if sum(r["collections"] for r in observer["requests"]) != 2:
            raise ValueError("One original observation and one bounded continuation required")
        if (
            case["request_id"] != group["requests"][index - 1]
            or worker["result"]["request_id"] != case["request_id"]
            or "backup_request" in worker["result"]
        ):
            raise ValueError("Exact once-only request with no backup required")
        require_after(before, case["after"], case["request_id"], index)
        if case["generation_before"] != generation or case["generation_after"] <= generation:
            raise ValueError("Exact successive generations required")
        generation = case["generation_after"]
        before = case["after"]
        rows = [row for sample in case["samples"] for row in sample["rows"]]
        if not any(
            row["connection_id"] == worker["identity"]["connection_id"]
            and row["marker_locks"] > 0
            and not row["blocking_session_id"]
            for row in rows
        ):
            raise ValueError("Native worker entry and useful ownership required")
        actual_overlap = any(
            overlap(sample["rows"], worker["identity"], observer["connections"])
            for sample in case["samples"]
        )
        if bool(case["engine_overlap"]) != actual_overlap:
            raise ValueError("Native overlap label differs from physical samples")
        if index == 2 and not actual_overlap:
            raise ValueError("Observer-first native engine evidence required")
        accepted.append(
            dict(
                order=case["order"],
                functional_passed=True,
                engine_overlap=actual_overlap,
                observer_seconds=observer["seconds"],
                maintenance_seconds=worker["seconds"],
                maximum_batch_seconds=observer["maximum_batch_seconds"],
            )
        )
    if (
        any(
            canonical(before[k]) != canonical(group["settled_state"][k])
            for k in ("work", "kvk", "stats")
        )
        or generation != 433
    ):
        raise ValueError("Completed maintenance state must remain exact")
    return dict(
        outcome="maintenance_both_orders_accepted",
        receipt_sha256=RECEIPT_SHA,
        cases=accepted,
        final_generation=generation,
        interpretation="Maintenance-first permits writer progress while the observer yields; simultaneous engine work is not required by that design row.",
        limits="Lab operational transport only; balanced OFF/ON cost, other actors, startup/updater and final review remain open.",
    )


def authenticate(packet):
    raw = (packet / "evidence/maintenance-pass.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RECEIPT_SHA
        or raw != (PRIOR / "receipt.json").read_bytes()
        or hashlib.sha256((PRIOR / "packet.zip").read_bytes()).hexdigest() != ARCHIVE_SHA
    ):
        raise ValueError("Exact completed maintenance evidence required")
    result = json.loads(raw)
    adjudicate(result)
    return result
