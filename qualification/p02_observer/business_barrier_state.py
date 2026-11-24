"""Extend the immutable completed-state chain through the third captured report."""

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import zipfile

LATEST = Path(r"Q:\P02Observer\20261121210559194")
LATEST_SHA = "b43d77c30c8ed16c5a0b61bbe02625dc350d3a6409d956c469e9c16bfc7f5e63"
ARCHIVE_SHA = "b419e6fed5cfd9317ca75dc0d35bc46777842f2f9fb712e24048e52bb4677dab"
NAMES = ("receipt.json", "fresh-runtime.json", "stage-5.json")


def extend(packet, manifest, original):
    from business_overlap_state import PRIOR, RECEIPT_SHA

    base, base_manifest, base_context = original
    values = {}
    for name in NAMES:
        raw = (packet / "evidence/latest" / name).read_bytes()
        if raw != (LATEST / name).read_bytes():
            raise ValueError("Latest completed native evidence changed")
        values[name] = json.loads(raw)
    if hashlib.sha256((LATEST / "receipt.json").read_bytes()).hexdigest() != LATEST_SHA:
        raise ValueError("Exact third captured report receipt required")
    archive = LATEST / "packet.zip"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Latest completed source archive changed")
    with zipfile.ZipFile(archive) as zipped:
        raw = zipped.read("manifest.json")
        if (LATEST / "manifest.json").read_bytes() != raw:
            raise ValueError("Latest native manifest changed")
        old_manifest = json.loads(raw)
        for name in ("candidate-contracts.json", "bot/config/sheet_config.json"):
            if (LATEST / name).read_bytes() != zipped.read(name):
                raise ValueError("Latest capture configuration changed")
    value = values["receipt.json"]
    if (
        value.get("outcome") != "completed_without_engine_overlap"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("physical_custody_retained") is not False
        or value.get("login_disabled") is not True
        or value.get("original_preserved") is not True
        or value.get("functional_capture_passed") is not True
        or value.get("completed_receipt_sha256") != RECEIPT_SHA
        or value.get("original_before") != base["original_after"]
        or value.get("original_after") != base["original_after"]
        or value.get("retained_capture_readback", {}).get("outcome") != "passed"
        or value.get("completed_after", {}).get("captures")
        != base["business_after"]["preparations"]
        or value.get("configured_reader", {}).get("native_application_receipt")
        != base["configured_reader"]["native_application_receipt"]
        or len(value.get("cases", [])) != 1
        or value["cases"][0].get("functional_passed") is not True
        or old_manifest["release"] != manifest["release"]
    ):
        raise ValueError("Settled third capture and all preceding preservation required")
    context = values["fresh-runtime.json"]
    for key in ("retained_application_value_sha256", "retained_fixed_value_sha256"):
        if context[key] != base_context[key]:
            raise ValueError("Retained full contract comparison changed")
    # Derive only fields already authenticated by the preceding receipt chain.
    # This does not fabricate a native receipt or rewrite any original artifact.
    derived = deepcopy(value)
    derived["files_before"] = base["files_before"]
    derived["fresh_before"] = base["fresh_before"]
    derived["earlier_capture_sets"] = [
        dict(
            account=base_manifest["account"],
            preparations=base["business_after"]["preparations"],
            resources=base["business_after"]["resources"],
        )
    ]
    context["_retained_sources"] = [
        (str(PRIOR), base_manifest, base_context["prior"]),
        (str(LATEST), old_manifest, context["prior"]),
    ]
    context["_latest_receipt_sha256"] = LATEST_SHA
    return derived, old_manifest, context
