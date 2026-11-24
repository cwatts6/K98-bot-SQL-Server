"""Resume only unstarted lab maintenance after exact read-only reconciliation.

The actual operational caller is exercised with an explicitly substituted local
Windows transport. This is not production SQL_USERNAME credential acceptance.
Application readers keep their original dedicated SQL login without new grants.
"""

import hashlib
import json
import os
from pathlib import Path

PRINCIPAL = r"MINI_AMD\K98LabAdmin"
PRIOR = Path("Q:/P02Observer/20261122092941075")
RECEIPT_SHA = "c1ce2819e3ca67af4b3474eeb71404d9f670fc693ad9b5742e610a5e2b19298d"
ARCHIVE_SHA = "619daaa04c6b0e411871d65bc1068fd7c6895d32b338c5c9442dd212a7eb07f8"


def authenticate_failed(packet):
    from recovery_coexistence import overlap

    raw = (packet / "evidence/maintenance-failed.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RECEIPT_SHA
        or raw != (PRIOR / "receipt.json").read_bytes()
    ):
        raise ValueError("Exact original permission failure required")
    if hashlib.sha256((PRIOR / "packet.zip").read_bytes()).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Original failed archive changed")
    prior = json.loads(raw)
    if any(
        prior.get(k) != v
        for k, v in dict(
            outcome="failed",
            cleanup_failures=[],
            original_preserved=True,
            login_disabled=True,
            physical_custody_retained=False,
        ).items()
    ):
        raise ValueError("Original actor owners must have settled")
    if (
        prior["original_before"] != prior["original_after"]
        or prior["databases_before"] != prior["databases_after"]
    ):
        raise ValueError("Retained original state changed")
    cases = prior["maintenance_coexistence"]["cases"]
    if len(cases) != 1:
        raise ValueError("Only the original first maintenance attempt is admissible")
    case = cases[0]
    worker = case["workers"]["maintenance"]
    if (
        case["order"] != "maintenance_first"
        or case["ordering_proven"]
        or worker.get("dispatch_attempted") is not True
        or worker.get("first_failure")
        != dict(error_type="ProgrammingError", sqlstate="42000", native_code=229)
        or "result" in worker
    ):
        raise ValueError(
            "Exact refused operational entry required; no completed work may be repeated"
        )
    for role in case["workers"].values():
        if (
            not role["physical_cleanup"]["all_closed_by_callers"]
            or not role["physical_cleanup"]["safe_to_exit"]
        ):
            raise ValueError("Original physical cleanup was not acknowledged")
    recovery = prior["recovery_coexistence"]["cases"]
    if [c["order"] for c in recovery] != ["recovery_first", "observer_first"]:
        raise ValueError("Two accepted recovery orders required")
    for value in recovery:
        if (
            not value["functional_passed"]
            or value["first_failure"]
            or value["cleanup_failures"]
            or not any(
                overlap(s["rows"], value["recovery_identity"], value["observer_connections"])
                for s in value["samples"]
            )
        ):
            raise ValueError("Accepted native recovery evidence differs")
    return prior


def operational_connections():
    import producer_runtime as runtime

    class Connections(runtime.Connections):
        def __call__(self):
            if (
                os.environ.get("COMPUTERNAME") != "MINI_AMD"
                or os.environ.get("SQL_SERVER") != "MINI_AMD"
                or os.environ.get("SQL_DATABASE") != "ROK_TRACKER"
            ):
                raise ValueError("Exact guest-only operational transport required")
            import pyodbc

            raw = pyodbc.connect(
                "DRIVER={ODBC Driver 18 for SQL Server};SERVER=MINI_AMD;DATABASE=ROK_TRACKER;"
                "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=no;",
                autocommit=False,
                timeout=5,
            )
            self.items.append(raw)
            return raw

    return Connections()


def invoke_operational(once, request):
    import file_utils

    original = file_utils._conn
    file_utils._conn = once
    try:
        # The legacy transport is fixture-bound. The real wrapper must still
        # choose operational=True, and the real DAL owns the original connection.
        return file_utils.run_post_import_stats_update(
            "MINI_AMD", "ROK_TRACKER", "", "", timeout_seconds=300, request_id=request
        )
    finally:
        file_utils._conn = original


def preflight(admin, prior, actual):
    import recovery_coexistence as recovery
    import remaining_actors as actors

    current = recovery.inventory(admin)
    expected = prior["maintenance_coexistence"]["before"]
    actors.require_initial(current, expected)
    if actors.canonical(current["stats"]) != expected["stats"]:
        raise ValueError("Statistics changed since the refused request")
    value = actors.generation(admin)
    if value != 1 or actual["application_observation"]["generation"] != 1:
        raise ValueError("Refused operation may have advanced generation; stop without replay")
    return current


def run_checks(packet, manifest, record, save, admin, actual, sources):
    import producer_runtime as runtime
    import remaining_actors as actors
    from retained_reader_cost import application_group

    prior = authenticate_failed(packet)
    old = set(prior["maintenance_coexistence"]["requests"])
    if old & set(manifest["maintenance_requests"]):
        raise ValueError("Fresh continuation request identities required")
    record["stage"] = "reconcile exact refused maintenance state before any new work"
    record["maintenance_reconciliation"] = preflight(admin, prior, actual)
    record["accepted_recovery_receipt_sha256"] = RECEIPT_SHA
    record["recovery_coexistence"] = dict(
        retained_prior=True, batch_cost_passed=True, both_engine_orders=True, both_guard_orders=True
    )

    def captures(connect, value):
        value["sources"] = []
        for native, source, context, _ in sources:
            item = {}
            value["sources"].append(item)
            runtime.consumer(native, source, context["prior"], item, connect)
            if item.get("outcome") != "passed":
                raise ValueError("Retained capture readback must pass before maintenance")
        if sum(len(s["captures"]) for s in value["sources"]) != 5:
            raise ValueError("All five completed captures required")
        value["outcome"] = "passed"

    application_group(manifest, record, "captures_before_maintenance", captures)
    actors.run_checks(
        packet,
        manifest,
        record,
        save,
        admin,
        actual,
        sources,
        prior_record=prior,
        operational_factory=operational_connections,
    )
