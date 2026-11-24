"""Authenticate the settled backup-gate refusal; reuse DB16/18 handover once."""

import hashlib
import json
from pathlib import Path
import zipfile

PURPOSE = "fresh-db18-backup-preflight-continuation"
PRIOR_DIRECTORY = Path(r"Q:\P02Observer\20261121190045743")
PRIOR_SHA = "c71907840ca92147ade45aabee7e4480056ac459bf2ba23af8c3c9a02857f864"
ARCHIVE_SHA = "6a700273ecf5688d44f7428baab3042dc20b089ca92179f3124b83f8ae703e81"
STDERR_SHA = "182a36499828d43a2237f2dd2cece829ed12cecf9c13348dccb5fda8addb9ba1"


def require_prior(value):
    operations = value.get("coordinator", [])
    if (
        value.get("outcome") != "failed"
        or value.get("stage") != "fresh canonical observer Preflight"
        or value.get("first_failure")
        != {"stage": "fresh canonical observer Preflight", "error_type": "ValueError"}
        or value.get("cleanup_failures") != []
        or value.get("admin_connections_closed") != 7
        or value.get("physical_custody_retained") is not False
        or value.get("original_preserved") is not True
        or value.get("login_enable_attempted") is not False
        or value.get("login_disabled") is not True
        or value.get("cases") != []
        or any(
            k in value
            for k in (
                "snapshot_attempted",
                "fresh_observer_committed",
                "configured_reader",
                "three_contracts_passed",
            )
        )
        or len(operations) != 2
        or [r.get("operation") for r in operations] != ["Status", "Preflight"]
        or operations[0].get("acknowledged") is not True
        or operations[0].get("exit_code") != 10
        or operations[0].get("result", {}).get("state") != "unstarted"
        or operations[1].get("acknowledged") is not False
        or operations[1].get("exit_code") != 20
        or any(r.get("settled") is not True for r in operations)
        or value.get("databases_after") != value.get("databases_named")
        or len(value.get("actions", [])) != 3
        or [r.get("stage") for r in value["actions"]]
        != [
            "rename physical DB16",
            "rename physical DB18",
            "allow actual application connections to fresh DB18",
        ]
        or any(r.get("acknowledged") is not True for r in value["actions"])
    ):
        raise ValueError("Exact settled backup-preflight refusal and completed handover required")
    if (
        value["original_before"]["state"]["ownership"]
        != value["original_after"]["state"]["ownership"]
        or value["original_before"]["state"]["business_hashes"]
        != value["original_after"]["state"]["business_hashes"]
    ):
        raise ValueError("Original claim or business state changed")


def load_prior(packet, manifest):
    raw = (packet / "evidence/stopped-fresh-business.json").read_bytes()
    stderr = (packet / "evidence/stopped-preflight.stderr.txt").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != PRIOR_SHA
        or hashlib.sha256(stderr).hexdigest() != STDERR_SHA
        or (PRIOR_DIRECTORY / "receipt.json").read_bytes() != raw
        or (PRIOR_DIRECTORY / "Preflight.stderr.txt").read_bytes() != stderr
    ):
        raise ValueError("Original failed packet evidence changed")
    archive = PRIOR_DIRECTORY / "packet.zip"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA:
        raise ValueError("Original sealed archive changed")
    with zipfile.ZipFile(archive) as zipped:
        raw_manifest = zipped.read("manifest.json")
    if (PRIOR_DIRECTORY / "manifest.json").read_bytes() != raw_manifest:
        raise ValueError("Original extracted manifest changed")
    previous_manifest = json.loads(raw_manifest)
    if previous_manifest["release"] != manifest["release"]:
        raise ValueError("Continuation must retain the original unstarted release identity")
    for name in (
        "Apply.stdout.txt",
        "Apply.stderr.txt",
        "Verify.stdout.txt",
        "fresh-runtime.json",
        "stage-1.json",
    ):
        if (PRIOR_DIRECTORY / name).exists():
            raise ValueError("A later original stage exists; do not replay")
    prior = json.loads(raw)
    require_prior(prior)
    return prior


def reconcile(packet, manifest, restore, record, save):
    import fixed_contract_cost as cost
    from fresh_business import fresh_preflight, require_login
    from fresh_business_owner import SqlOwner
    import fresh_business_state as state
    from restart_read import require_services

    prior = load_prior(packet, manifest)
    record.update(
        resumed_from_sha256=PRIOR_SHA,
        completed_name_handover_reused=True,
        databases_before=prior["databases_before"],
        databases_named=prior["databases_named"],
        files_before=prior["files_before"],
    )
    record["stage"] = "reconcile completed name handover and preserved claim"
    save()
    owner = SqlOwner("master", record, save)
    state.require_identity(owner.read(state.IDENTITY), "master", 1)
    require_login(owner.read)
    require_services(owner.read(cost.SERVICES_SQL))
    if owner.read(state.SESSIONS) or owner.read(state.LOCKS):
        raise ValueError("Foreign SQL activity prevents continuation")
    if (
        state.normalized(owner.read(state.DATABASES)) != prior["databases_after"]
        or state.normalized(owner.read(state.FILE_IDENTITIES)) != prior["files_before"]
    ):
        raise ValueError("Completed physical database identities changed")
    owner.close()
    owner = SqlOwner(state.RETAINED, record, save)
    observed = state.original_state(owner, prior["original_after"]["state"], state.RETAINED)
    if observed != prior["original_after"]:
        raise ValueError("Original retained owner, modules or business state changed")
    record["original_before"] = observed
    owner.close()
    owner = SqlOwner("ROK_TRACKER", record, save)
    record["fresh_before"] = fresh_preflight(owner, restore, named=True)
    owner.close()
    record["completed_handover_reconciled"] = True
    save()
