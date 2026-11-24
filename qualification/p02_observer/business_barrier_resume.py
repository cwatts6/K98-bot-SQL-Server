"""Reconcile a committed child after the exact settled SQL-266 control failure."""

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import zipfile

FAILED = Path(r"Q:\P02Observer\20261121214611154")
RECEIPT_SHA = "2bc2b90d7c6617e46fe04107acfc01bb1e82eddccc6d1cbedf8b7fbcf7a5b33e"
ARCHIVE_SHA = "68edd14bef92fd2b92d14ebc95857ecbe9a77d5ab8d7e798af4dc79a809ec3a1"
NAMES = ("receipt.json", "fresh-runtime.json", "stage-5.json", "stage-6.json")
PREFLIGHT = Path("Q:/P02Observer/20261121215726740")
PREFLIGHT_SHA = "20a42cc55d28a4ae490dc27c2731a421cbc1c14b774289d9852dead53d48ceeb"
PREFLIGHT_ARCHIVE = "ee49632ba6358c0558589cd9ae3f1e18724d152e1b56a413e50b652b18a13e1d"
ENTRY_FAILURE = Path("Q:/P02Observer/20261121220646479")
ENTRY_FAILURE_SHA = "15dbf8bf5f19efd27c4388a0c276539d55d418d83eed0155bddd69342dd48869"
BATCH_PREFLIGHT = Path("Q:/P02Observer/20261121221132033")
BATCH_PREFLIGHT_SHA = "e37e598ab3d11b852cf18666ada3ffe11eb4bce6d6e8d9d2c9587beb0fb92f13"


def authenticate(packet, manifest, original):
    from business_barrier_state import LATEST_SHA

    prior, old_manifest, context = original
    if manifest.get("resume_authentication_failure") is not None:
        authenticate_entry_failure(packet, manifest)
    if manifest.get("resume_control_failure") != "20261121214611154":
        raise ValueError("Exact settled control failure required")
    values = {}
    for name in NAMES:
        raw = (packet / "evidence/control-failure" / name).read_bytes()
        if raw != (FAILED / name).read_bytes():
            raise ValueError("Failed-control native evidence changed")
        values[name] = json.loads(raw)
    if hashlib.sha256((FAILED / "receipt.json").read_bytes()).hexdigest() != RECEIPT_SHA:
        raise ValueError("Exact failed-control receipt required")
    archive = FAILED / "packet.zip"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Failed-control source archive changed")
    with zipfile.ZipFile(archive) as zipped:
        for name in ("manifest.json", "candidate-contracts.json", "bot/config/sheet_config.json"):
            if (FAILED / name).read_bytes() != zipped.read(name):
                raise ValueError("Failed-control native source or capture configuration changed")
        failed_manifest = json.loads(zipped.read("manifest.json"))
    value, producer, reader = (values[n] for n in ("receipt.json", "stage-5.json", "stage-6.json"))
    case = value.get("cases", [{}])[0]
    barrier = case.get("controlled_barrier", {})
    if (
        value.get("outcome") != "failed"
        or value.get("first_failure")
        != dict(
            stage="one new producer-first report and prepared reader",
            error_type="ProgrammingError",
            sqlstate="25000",
            native_code=266,
        )
        or value.get("completed_receipt_sha256") != LATEST_SHA
        or value.get("cleanup_failures") != []
        or value.get("physical_custody_retained") is not False
        or value.get("login_disabled") is not True
        or value.get("original_preserved") is not True
        or value.get("original_before") != prior["original_after"]
        or value.get("original_after") != prior["original_after"]
        or value.get("configured_reader", {}).get("native_application_receipt")
        != prior["configured_reader"]["native_application_receipt"]
        or len(value.get("cases", [])) != 1
        or case.get("functional_passed") is not True
        or case.get("settled") is not True
        or case.get("retained_running") != []
        or barrier.get("acquired") is not True
        or barrier.get("release_attempted") is not True
        or barrier.get("released") is not False
        or barrier.get("admin_connections_closed") != 1
        or barrier.get("cleanup_failures")
        != [dict(operation="control rollback", error_type="ValueError")]
        or "business_after" in value
        or "consumer" in value
        or failed_manifest["release"] != manifest["release"]
    ):
        raise ValueError("Only the recorded settled control failure may continue")
    for child in (producer, reader):
        if (
            child.get("outcome") != "passed"
            or child.get("first_failure") is not None
            or child.get("physical_cleanup", {}).get("all_closed_by_callers") is not True
        ):
            raise ValueError("Original reader and committed producer must be physically settled")
    if (
        producer.get("writer_closed") is not True
        or producer.get("preparation_state") != "captured"
        or producer.get("commit_checkpoint", {}).get("completion") != "committed"
        or producer.get("preparation_id") != case.get("preparation_id")
    ):
        raise ValueError("Fourth report and capture are committed preservation evidence")
    derived = deepcopy(prior)
    # Inventory is observed in the failed receipt; business state is deliberately
    # not invented here. Reconcile it through native reads before any new work.
    derived["databases_after"] = value["databases_after"]
    context["_failed_control"] = dict(
        receipt=value,
        manifest=failed_manifest,
        producer=producer,
        runtime=values["fresh-runtime.json"],
    )
    if manifest.get("resume_control_preflight") is not None:
        context["_control_preflight_refusal"] = authenticate_preflight(packet, manifest, derived)
    if manifest.get("resume_release_batch_failure") is not None:
        authenticate_batch_preflight(packet, manifest, context["_control_preflight_refusal"])
    return derived, old_manifest, context


def authenticate_preflight(packet, manifest, prior):
    raw = (packet / "evidence/control-preflight/receipt.json").read_bytes()
    if (
        manifest.get("resume_control_preflight") != "20261121215726740"
        or manifest.get("separate_control_boundaries") is not True
        or hashlib.sha256(raw).hexdigest() != PREFLIGHT_SHA
        or raw != (PREFLIGHT / "receipt.json").read_bytes()
        or hashlib.sha256((PREFLIGHT / "packet.zip").read_bytes()).hexdigest() != PREFLIGHT_ARCHIVE
    ):
        raise ValueError("Exact settled preflight refusal required")
    value = json.loads(raw)
    control = value.get("control_release_preflight", {}).get("controlled_barrier", {})
    if (
        value.get("outcome") != "failed"
        or value.get("first_failure")
        != dict(
            stage="verify direct control release before any new business", error_type="ValueError"
        )
        or value.get("cases") != []
        or value.get("actions") != []
        or value.get("login_enable_attempted") is not False
        or value.get("login_disabled") is not True
        or value.get("physical_custody_retained") is not False
        or value.get("cleanup_failures") != []
        or value.get("original_before") != prior["original_after"]
        or value.get("original_after") != prior["original_after"]
        or value.get("databases_after") != prior["databases_after"]
        or value.get("completed_receipt_sha256") != RECEIPT_SHA
        or "snapshot" in value
        or value.get("fourth_capture_reconciliation", {}).get("outcome") != "passed"
        or control.get("admin_connections_closed") != 1
        or control.get("release_parameter_count") != 0
        or control.get("rollback_result")
        != [dict(session_id=69, transaction_count=0, transaction_state=1, remaining_target_locks=0)]
    ):
        raise ValueError("Preflight refusal must be settled without any new business")
    return value


def reconcile(owner, prior, old_manifest, context, record):
    from business_overlap_state import require_fresh
    from fresh_business_state import normalized
    from producer_capture import require_post_business
    from producer_fixture import REPORT_VALUE_SQL

    failed = context["_failed_control"]
    receipt, manifest, producer = (failed[k] for k in ("receipt", "manifest", "producer"))
    # Prior account/capture/report values stay exact; only the known new global
    # claim/release pair may have advanced since that preceding receipt.
    preserved = require_fresh(owner, prior, old_manifest, after=True)
    current = normalized(
        require_post_business(
            owner.connection, manifest, receipt["business_preflight"], receipt["cases"]
        )
    )
    refusal = context.get("_control_preflight_refusal")
    if (
        refusal is not None
        and current != refusal["fourth_capture_reconciliation"]["native_post_state"]
    ):
        raise ValueError("Fourth capture changed since the settled preflight refusal")
    row = current["preparations"][0]
    if (
        row["Version"] != 7
        or str(row["OwnerID"]).lower() != producer["owner_id"]
        or row["Fence"] != producer["fence"]
        or row["SpoolKey"] != producer["snapshot"]["key"]
        or row["SpoolBytes"] != producer["snapshot"]["byte_count"]
        or row["SpoolHash"] != producer["snapshot"]["sha256"]
        or json.loads(row["GenerationJson"]) != producer["captured_generation"]
    ):
        raise ValueError("Fourth captured row does not match its committed child receipt")
    derived = deepcopy(prior)
    derived["earlier_capture_sets"].append(
        dict(
            account=old_manifest["account"],
            preparations=prior["business_after"]["preparations"],
            resources=prior["business_after"]["resources"],
        )
    )
    derived["business_after"] = current
    derived["cases"] = [
        dict(receipt["cases"][0], report_after=normalized(owner.read(REPORT_VALUE_SQL)))
    ]
    derived["snapshot"] = receipt["snapshot"]
    context["_retained_sources"].append((str(FAILED), manifest, failed["runtime"]["prior"]))
    context["_latest_receipt_sha256"] = RECEIPT_SHA
    record["fourth_capture_reconciliation"] = dict(
        outcome="passed",
        original_failure_retained=receipt["first_failure"],
        preceding=preserved,
        native_post_state=current,
        report_replayed=False,
    )
    return derived, manifest, context


def read_captures(context, record, runtime, held):
    connections = runtime.Connections()
    result = dict(sources=[])
    record["four_capture_readback_before_business"] = result
    try:
        for directory, manifest, prior in context["_retained_sources"]:
            item = {}
            result["sources"].append(item)
            with runtime.application_credentials(manifest):
                runtime.consumer(Path(directory), manifest, prior, item, connections)
            if item.get("outcome") != "passed":
                raise ValueError("A committed capture failed independent readback")
        if sum(len(s["captures"]) for s in result["sources"]) != 4:
            raise ValueError("All four preceding captures must verify before new business")
    finally:
        cleanup = connections.finish()
        result["physical_cleanup"] = cleanup
        if not cleanup["safe_to_exit"]:
            held.append(connections)
    if not cleanup["all_closed_by_callers"] or not cleanup["safe_to_exit"]:
        raise ValueError("Preceding capture consumer cleanup unconfirmed")
    result["outcome"] = "passed"


def authenticate_entry_failure(packet, manifest):
    raw = (packet / "evidence/entry-failure/receipt.json").read_bytes()
    if (
        manifest.get("resume_authentication_failure") != "20261121220646479"
        or hashlib.sha256(raw).hexdigest() != ENTRY_FAILURE_SHA
        or raw != (ENTRY_FAILURE / "receipt.json").read_bytes()
    ):
        raise ValueError("Exact original entry failure required")
    value = json.loads(raw)
    if (
        value.get("outcome") != "failed"
        or value.get("first_failure")
        != dict(stage="authenticate completed grouped work", error_type="FileNotFoundError")
        or value.get("admin_dispatches") != 0
        or value.get("cases") != []
        or value.get("actions") != []
        or value.get("login_enable_attempted") is not False
        or value.get("physical_custody_retained") is not False
        or value.get("cleanup_failures") != []
    ):
        raise ValueError("Entry failure must have dispatched no SQL or business")


def authenticate_batch_preflight(packet, manifest, preceding):
    raw = (packet / "evidence/release-batch/receipt.json").read_bytes()
    if (
        manifest.get("resume_release_batch_failure") != "20261121221132033"
        or manifest.get("standalone_release_boundary") is not True
        or hashlib.sha256(raw).hexdigest() != BATCH_PREFLIGHT_SHA
        or raw != (BATCH_PREFLIGHT / "receipt.json").read_bytes()
    ):
        raise ValueError("Exact settled rollback-batch refusal required")
    value = json.loads(raw)
    expected = dict(
        outcome="failed",
        cases=[],
        actions=[],
        login_enable_attempted=False,
        login_disabled=True,
        original_preserved=True,
        physical_custody_retained=False,
        cleanup_failures=[],
        first_failure=dict(
            stage="verify direct control release before any new business", error_type="ValueError"
        ),
    )
    if any(value.get(k) != v for k, v in expected.items()):
        raise ValueError("Rollback-batch refusal must precede all new business")
    for key in ("original_before", "original_after", "databases_after"):
        if value.get(key) != preceding[key]:
            raise ValueError("Preflight preserved state changed")
    if (
        value["fourth_capture_reconciliation"]["native_post_state"]
        != preceding["fourth_capture_reconciliation"]["native_post_state"]
    ):
        raise ValueError("Fourth captured state differs between settled preflights")
    control = value["control_release_preflight"]["controlled_barrier"]
    if (
        control.get("admin_connections_closed") != 1
        or control.get("rollback_result")
        != [dict(session_id=58, transaction_count=0, transaction_state=1)]
        or "snapshot" in value
    ):
        raise ValueError("Exact closed original control refusal required")
