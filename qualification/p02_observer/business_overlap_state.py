"""Exact completed DB18 work is preservation evidence, never replay authority."""

import hashlib
import json
from pathlib import Path
import zipfile

PRIOR = Path(r"Q:\P02Observer\20261121193756509")
RECEIPT_SHA = "5585c9148dd2b950eeae2c02dac333b6bfd1005a03e6a829dd0a1a24ded1bbf7"
ARCHIVE_SHA = "330ae31ea470acc64491842cfb5c86ce67eaf3ad8c6560001e5d12d9ca59e18d"
NAMES = ("receipt.json", "fresh-runtime.json", "stage-2.json", "stage-5.json")


def load_prior(packet, manifest):
    values = {}
    for name in NAMES:
        raw = (packet / "evidence/completed" / name).read_bytes()
        if (PRIOR / name).read_bytes() != raw:
            raise ValueError("Completed native evidence changed")
        values[name] = json.loads(raw)
    if hashlib.sha256((PRIOR / "receipt.json").read_bytes()).hexdigest() != RECEIPT_SHA:
        raise ValueError("Exact completed grouped receipt required")
    archive = PRIOR / "packet.zip"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Completed source archive changed")
    with zipfile.ZipFile(archive) as zipped:
        raw = zipped.read("manifest.json")
        if raw != (PRIOR / "manifest.json").read_bytes():
            raise ValueError("Completed native manifest changed")
        old_manifest = json.loads(raw)
        for name in ("candidate-contracts.json", "bot/config/sheet_config.json"):
            if zipped.read(name) != (PRIOR / name).read_bytes():
                raise ValueError("Retained capture configuration changed")
    if manifest["release"] != old_manifest["release"]:
        raise ValueError("Committed release identity must be preserved")
    value = values["receipt.json"]
    if (
        value.get("outcome") != "completed_without_full_engine_overlap"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("physical_custody_retained") is not False
        or value.get("original_preserved") is not True
        or value.get("original_before") != value.get("original_after")
        or value.get("login_disabled") is not True
        or value.get("functional_capture_passed") is not True
        or value.get("fresh_observer_verified") is not True
        or len(value.get("cases", [])) != 2
        or any(c.get("functional_passed") is not True for c in value["cases"])
    ):
        raise ValueError(
            "Settled completed installation, captures and original preservation required"
        )
    result = value, old_manifest, values["fresh-runtime.json"]
    if manifest.get("continued_packet") is not None:
        if (
            manifest["continued_packet"] != "20261121210559194"
            or manifest.get("controlled_report_barrier") is not True
        ):
            raise ValueError("Exact third-capture continuation required")
        from business_barrier_state import extend

        result = extend(packet, manifest, result)
    if manifest.get("resume_control_failure") is not None:
        from business_barrier_resume import authenticate

        result = authenticate(packet, manifest, result)
    return result


def require_inventory(owner, prior, snapshot=None):
    import fresh_business_state as state

    current = state.normalized(owner.read(state.DATABASES))
    original_ids = {r["database_id"] for r in prior["databases_after"]}
    additions = [r for r in current if r["database_id"] not in original_ids]
    if additions and (
        len(additions) != 1
        or snapshot is None
        or additions[0]["database_id"] != snapshot["database_id"]
        or additions[0]["name"] != snapshot["name"]
        or additions[0]["source_database_id"] != 18
        or additions[0]["state_desc"] != "ONLINE"
        or additions[0]["is_read_only"] is not True
    ):
        raise ValueError("Only the acknowledged new recovery snapshot may be added")
    if [r for r in current if r not in additions] != prior["databases_after"] or state.normalized(
        owner.read(state.FILE_IDENTITIES)
    ) != prior["files_before"]:
        raise ValueError("Completed physical database or file identity changed")
    return current


def require_fresh(owner, prior, old_manifest, *, after=False):
    import application_identity as identity
    import fresh_business_state as state
    import producer_fixture as fixture
    from restart_read import OWNER_SQL
    from services.export_observer_contract import MIGRATION_ID

    state.require_identity(owner.read(state.IDENTITY), "ROK_TRACKER", 18)
    if state.normalized(owner.read(identity.TARGET)) != prior["fresh_before"]["target"]:
        raise ValueError("Committed DB18 target changed")
    if state.normalized(owner.read(OWNER_SQL)) != prior["fresh_before"]["owner"]:
        raise ValueError("Completed DB18 dbo owner changed")
    if (
        state.normalized(owner.read(identity.QUERIES["database_users"]))
        != prior["fresh_before"]["users"]
    ):
        raise ValueError("Completed application mapping changed")
    history = identity.normalized_history(owner.read(identity.HISTORY))
    previous = [r for r in history if r["MigrationId"] != MIGRATION_ID]
    if previous != identity.normalized_history(prior["fresh_before"]["history"]):
        raise ValueError("An original migration history row changed")
    native = prior["configured_reader"]["native_application_receipt"]
    expected = dict(
        MigrationId=MIGRATION_ID,
        ChecksumSha256=native["profile_sha256"],
        GitCommit=native["sql_commit"],
        DeploymentId=native["deployment_id"],
        Status="Applied",
    )
    if [r for r in history if r["MigrationId"] == MIGRATION_ID] != [expected]:
        raise ValueError("Completed observer migration changed")
    captures = state.normalized(owner.read(fixture.FRESH_ACCOUNT, old_manifest["account"]))
    if captures != prior["business_after"]["preparations"]:
        raise ValueError("A completed capture row changed")
    resources = state.normalized(
        owner.read(fixture.RESOURCE_SQL, "account:" + old_manifest["account"])
    )
    old_resources = prior["business_after"]["resources"]

    def account(rows):
        return [r for r in rows if r["ResourceKey"] != "sql_snapshot:legacy_outputs"]

    if (not after and resources != old_resources) or account(resources) != account(old_resources):
        raise ValueError("Retained resource ownership changed")
    for old in prior.get("earlier_capture_sets", []):
        if (
            state.normalized(owner.read(fixture.FRESH_ACCOUNT, old["account"]))
            != old["preparations"]
        ):
            raise ValueError("An earlier completed capture changed")
        earlier_resources = state.normalized(
            owner.read(fixture.RESOURCE_SQL, "account:" + old["account"])
        )
        if account(earlier_resources) != account(old["resources"]):
            raise ValueError("An earlier completed account resource changed")
    if owner.read(fixture.REPORT_VALUE_SQL) != prior["cases"][-1]["report_after"]:
        raise ValueError("Retained report value changed")
    return dict(history=history, captures=captures, resources=resources)
