"""Authenticate completed DB18 captures; derive read-only preservation expectations."""

import hashlib
import json
from pathlib import Path
import zipfile

SOURCES = (
    (
        "20261121193756509",
        "5585c9148dd2b950eeae2c02dac333b6bfd1005a03e6a829dd0a1a24ded1bbf7",
        "330ae31ea470acc64491842cfb5c86ce67eaf3ad8c6560001e5d12d9ca59e18d",
    ),
    (
        "20261121210559194",
        "b43d77c30c8ed16c5a0b61bbe02625dc350d3a6409d956c469e9c16bfc7f5e63",
        "b419e6fed5cfd9317ca75dc0d35bc46777842f2f9fb712e24048e52bb4677dab",
    ),
    (
        "20261121214611154",
        "2bc2b90d7c6617e46fe04107acfc01bb1e82eddccc6d1cbedf8b7fbcf7a5b33e",
        "68edd14bef92fd2b92d14ebc95857ecbe9a77d5ab8d7e798af4dc79a809ec3a1",
    ),
    (
        "20261121222011376",
        "28a166c451f30b51e70de64ca89e0735dd1787fb55cf9f952b5e5b9fdebcde26",
        "7d82a8c6fbb96471d5c53db59a9a089f6b09c0c0075364d93f7fe076929af7cd",
    ),
)
PURPOSE = "preserved-db18-index-reader-qualification"
RECOVERY_PURPOSE = "preserved-db18-recovery-coexistence"
ACTOR_PURPOSE = "preserved-db18-actor-qualification"
MAINTENANCE_PURPOSE = "preserved-db18-maintenance-continuation"
ACTOR_PRIOR = Path("Q:/P02Observer/20261122082403359")
ACTOR_PRIOR_SHA = "d76feecb852732b0d74b35d763c542a5d456e83477b8a784b915268fb951a436"
ACTOR_ARCHIVE_SHA = "0db61af440bc4f2f86f921de213df764df11ee861c6c303726b284599b475b0e"
READER_PASS = Path("Q:/P02Observer/20261122080447891")
READER_PASS_SHA = "60c9118a54dcd90022879c63fec9390664bcf4406bbdaf13fe5b9d9aaf59f691"
READER_ARCHIVE_SHA = "c5fb64ca9e0ddd580592641ad163ed3672878f5350f382f9ef9eca9fefe5f408"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def authenticate(packet, manifest):
    sources = []
    for stamp, receipt_sha, archive_sha in SOURCES:
        native = Path("Q:/P02Observer") / stamp
        evidence = packet / "evidence/retained" / stamp
        names = ["receipt.json", "fresh-runtime.json", "stage-5.json"]
        if stamp == SOURCES[0][0]:
            names.append("stage-2.json")
        for name in names:
            raw = (evidence / name).read_bytes()
            if raw != (native / name).read_bytes():
                raise ValueError("Completed native evidence changed")
        if sha((evidence / "receipt.json").read_bytes()) != receipt_sha:
            raise ValueError("Exact completed receipt required")
        if sha((native / "packet.zip").read_bytes()) != archive_sha:
            raise ValueError("Original capture archive changed")
        with zipfile.ZipFile(native / "packet.zip") as archive:
            for name in (
                "manifest.json",
                "candidate-contracts.json",
                "bot/config/sheet_config.json",
            ):
                if archive.read(name) != (native / name).read_bytes():
                    raise ValueError("Original runtime configuration changed")
            source_manifest = json.loads(archive.read("manifest.json"))
        if source_manifest["release"] != manifest["release"]:
            raise ValueError("Committed release identity changed")
        receipt = json.loads((evidence / "receipt.json").read_bytes())
        context = json.loads((evidence / "fresh-runtime.json").read_bytes())
        sources.append((native, source_manifest, context, receipt))
    latest = sources[-1][3]
    expected = dict(
        outcome="completed_with_cost_miss",
        first_failure=None,
        cleanup_failures=[],
        physical_custody_retained=False,
        original_preserved=True,
        login_disabled=True,
        functional_capture_passed=True,
        producer_first_engine_overlap=True,
    )
    if any(latest.get(k) != v for k, v in expected.items()):
        raise ValueError("Settled five-capture engine-overlap milestone required")
    if latest["original_before"] != latest["original_after"]:
        raise ValueError("Original claim preservation differs")
    for key in ("four_capture_readback_before_business", "retained_capture_readback"):
        if (
            latest[key]["outcome"] != "passed"
            or not latest[key]["physical_cleanup"]["all_closed_by_callers"]
        ):
            raise ValueError("Four preceding consumers must have completed")
    if latest["consumer"]["outcome"] != "passed":
        raise ValueError("Fifth independent consumer must have completed")
    # Derived expectations are not a replacement or edited native receipt.
    prior = dict(sources[0][3])
    for key in (
        "databases_after",
        "original_after",
        "business_after",
        "cases",
        "configured_reader",
    ):
        prior[key] = latest[key]
    prior["earlier_capture_sets"] = []
    for _, source_manifest, _, receipt in sources[:-1]:
        post = receipt.get("business_after")
        if post is None:
            post = latest["fourth_capture_reconciliation"]["native_post_state"]
        prior["earlier_capture_sets"].append(
            dict(
                account=source_manifest["account"],
                preparations=post["preparations"],
                resources=post["resources"],
            )
        )
    if manifest["purpose"] in (RECOVERY_PURPOSE, ACTOR_PURPOSE, MAINTENANCE_PURPOSE):
        raw = (packet / "evidence/reader-pass.json").read_bytes()
        if (
            sha(raw) != READER_PASS_SHA
            or raw != (READER_PASS / "receipt.json").read_bytes()
            or sha((READER_PASS / "packet.zip").read_bytes()) != READER_ARCHIVE_SHA
        ):
            raise ValueError("Exact completed index qualification required")
        passed = json.loads(raw)
        for key, value in dict(
            outcome="passed",
            first_failure=None,
            cleanup_failures=[],
            original_preserved=True,
            login_disabled=True,
            physical_custody_retained=False,
            batch_cost_passed=True,
        ).items():
            if passed.get(key) != value:
                raise ValueError("Completed read-only owner did not settle")
        if (
            passed["databases_before"] != passed["databases_after"]
            or passed["databases_after"] != latest["databases_after"]
            or passed["original_before"] != passed["original_after"]
            or passed["original_after"] != latest["original_after"]
            or passed["completed_before"] != passed["completed_after"]
        ):
            raise ValueError("Completed index qualification changed retained state")
    if manifest["purpose"] in (ACTOR_PURPOSE, MAINTENANCE_PURPOSE):
        raw = (packet / "evidence/actor-prior.json").read_bytes()
        if (
            sha(raw) != ACTOR_PRIOR_SHA
            or raw != (ACTOR_PRIOR / "receipt.json").read_bytes()
            or sha((ACTOR_PRIOR / "packet.zip").read_bytes()) != ACTOR_ARCHIVE_SHA
        ):
            raise ValueError("Exact settled recovery group required")
        previous = json.loads(raw)
        if any(
            previous.get(k) != v
            for k, v in dict(
                outcome="completed_without_full_engine_overlap",
                first_failure=None,
                cleanup_failures=[],
                original_preserved=True,
                login_disabled=True,
                physical_custody_retained=False,
                batch_cost_passed=False,
            ).items()
        ):
            raise ValueError("Original grouped owner must have settled")
        if any(
            previous[k + "_before"] != previous[k + "_after"]
            for k in ("original", "completed", "databases")
        ):
            raise ValueError("Original read-only group changed retained state")
        if any(
            previous["maintenance_before"][k] != previous["maintenance_after"][k]
            for k in ("work", "kvk", "stats")
        ):
            raise ValueError("Read-only maintenance inventory changed")
        # Log use was informational; original values differ by 1,843,200 bytes.
        # Capacity is verified afresh against the existing <70 percent gate.
        if (
            previous["databases_after"] != latest["databases_after"]
            or previous["original_after"] != latest["original_after"]
        ):
            raise ValueError("Original inventory or claim changed")
    if manifest["purpose"] == MAINTENANCE_PURPOSE:
        from maintenance_continuation import authenticate_failed

        authenticate_failed(packet)
    return prior, sources[-1][1], sources


def require_packet(packet, manifest):
    import os
    import re

    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose")
        not in (PURPOSE, RECOVERY_PURPOSE, ACTOR_PURPOSE, MAINTENANCE_PURPOSE)
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("target_database_id") != 18
        or manifest.get("production_eligible") is not False
        or manifest.get("business_operations") != 0
        or manifest.get("preserve_capture_count") != 5
        or (
            manifest.get("purpose") == PURPOSE
            and (manifest.get("query_pairs") != 5 or manifest.get("query_warmups") != 1)
        )
        or (
            manifest.get("purpose") == RECOVERY_PURPOSE
            and (
                manifest.get("orders") != ["recovery_first", "observer_first"]
                or manifest.get("maintenance_dispatches") != 0
            )
        )
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
    ):
        raise ValueError("Exact isolated retained-fixture qualification required")
    if manifest["purpose"] in (ACTOR_PURPOSE, MAINTENANCE_PURPOSE):
        from uuid import UUID

        requests = manifest.get("maintenance_requests")
        if (
            not isinstance(requests, list)
            or len(requests) != 2
            or any(str(UUID(v)) != v for v in requests)
            or len(set(requests)) != 2
            or (
                manifest["purpose"] == ACTOR_PURPOSE
                and manifest.get("orders") != ["recovery_first", "observer_first"]
            )
            or (
                manifest["purpose"] == MAINTENANCE_PURPOSE
                and (manifest.get("recovery_replayed") is not False or manifest.get("orders") != [])
            )
            or manifest.get("maintenance_orders") != ["maintenance_first", "observer_first"]
        ):
            raise ValueError("Two fresh exact maintenance requests and declared orders required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed read-only qualification member changed")
