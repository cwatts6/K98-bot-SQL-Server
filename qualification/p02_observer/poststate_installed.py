"""Continue only the settled application-permission refusal after DB27 installation."""

import hashlib
import json
from pathlib import Path
from uuid import UUID
import zipfile

TOKEN = "installed-publisher-refused-20261123160455336"
PRIOR = Path("Q:/P02Observer/20261123160455336")
PINS = {
    "packet.zip": "d0b8c5ef5eb57f00f00562c1fa011215f61750515223d87634dd81cbc74b60a8",
    "integration/receipt.json": "024ebf97af740212784cc8a1bd4295f5c471526b99c6adf81a2e718454f490dd",
    "integration.launch.json": "5d673e5ea63b848a91108494bd8de1001289b123f29bd274df013a5353c871fe",
    "chain-workload/receipt.json": "91d31b94a9c8c095627289d0f9b232370118fe6d3e1a8ba1721eafc719e0370c",
    "chain-initial-contracts.json": "988371a96bbf1b401e1921a9ad635da11f3f8899ce5839354b02799e65077ead",
    "coordinator-Verify.stdout.txt": "e670d638f1fa3aecb530c94738062ba3d4ee89a5b1f077d070504ac2f2e3a63d",
}


def require_stop(record, launch, worker, initial):
    if (
        record.get("outcome") != "failed"
        or record.get("first_failure")
        != dict(
            stage="original workload process",
            error_type="ValueError",
            detail="Original workload role failed; preserve its exact result",
        )
        or any(
            record.get(k) is not True
            for k in ("original_preserved", "original_name_restored", "login_disabled")
        )
        or record.get("cleanup_failures") != []
        or record.get("preservation_failure") is not None
        or record.get("physical_custody_retained") is not False
        or record.get("name_transition_uncertain") is not False
        or launch.get("settled") is not True
        or launch.get("exit_code") != 1
        or launch.get("receipt_sha256") != PINS["integration/receipt.json"]
    ):
        raise ValueError("Exact settled installed-fixture stop required")
    stages = record.get("coordinator", [])
    if (
        [s.get("operation") for s in stages] != ["Status", "Preflight", "Apply", "Verify"]
        or any(s.get("acknowledged") is not True or s.get("settled") is not True for s in stages)
        or [s.get("exit_code") for s in stages] != [10, 0, 0, 0]
        or stages[-1]["result"] != stages[-2]["result"]
        or stages[-1]["result"].get("state") != "committed"
        or stages[-1]["result"]["observation_installation"]["database_id"] != 27
    ):
        raise ValueError("Original committed observer must never be reapplied")
    children = record.get("children", [])
    if (
        len(children) != 1
        or children[0].get("role") != "workload"
        or children[0].get("settled") is not True
        or children[0].get("exit_code") != 1
        or children[0].get("receipt_sha256") != PINS["chain-workload/receipt.json"]
    ):
        raise ValueError("Only the original settled refused workload is admissible")
    if (
        worker.get("outcome") != "failed"
        or worker.get("first_failure")
        != dict(
            stage="one fresh legacy publication for the zero-index state",
            error_type="ProgrammingError",
            sqlstate="42000",
            native_code=229,
        )
        or worker.get("publisher_dispatch_attempted") is not True
        or any(k in worker for k in ("publication", "publisher_response_acknowledged", "cases"))
        or worker.get("actions") != []
        or worker.get("cleanup_failures") != []
        or worker.get("physical_custody_retained") is not False
        or worker.get("credential_environment_cleared") is not True
        or any(
            worker.get("application_cleanup", {}).get(k) is not True
            for k in ("safe_to_exit", "all_closed_by_callers")
        )
    ):
        raise ValueError("Original publisher refusal and closed ownership required")
    result = initial.get("contract_result", {})
    permissions = [
        r["PermissionName"]
        for r in result["application"]["object_permissions"]
        if r["ObjectName"] == "dbo.sp_ExcelOutput_ByKVK"
    ]
    if (
        initial.get("contracts_passed") is not True
        or set(permissions) != {"ALTER", "VIEW DEFINITION"}
        or result["application_observation"]["generation"] != 1
    ):
        raise ValueError("Original application denial and generation one required")


def authenticate(packet, manifest):
    import poststate_continue as setup

    if manifest.get("continuation") != TOKEN:
        raise ValueError("Exact installed publisher continuation required")
    values = {}
    for name, digest in PINS.items():
        raw = (PRIOR / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError("Original installed-fixture evidence changed: " + name)
        if name.endswith(".json"):
            values[name] = json.loads(raw)
    with zipfile.ZipFile(PRIOR / "packet.zip") as archive:
        old = json.loads(archive.read("manifest.json"))
    retained = setup.authenticate(packet, old)
    for key in (
        "release",
        "databases",
        "data_directory",
        "backup_directory",
        "account",
        "storage_owner",
        "requests",
        "credential",
        "capture_route",
        "verifier_manifest_sha256",
    ):
        if manifest[key] != old[key]:
            raise ValueError("Retained capture identity differs: " + key)
    if (
        str(UUID(manifest["publisher_operation"])) != manifest["publisher_operation"]
        or manifest["publisher_operation"] == old["publisher_operation"]
        or manifest.get("refused_publisher_operation") != old["publisher_operation"]
    ):
        raise ValueError("Fresh publisher identity must preserve the refused operation")
    current = values["integration/receipt.json"]
    require_stop(
        current,
        values["integration.launch.json"],
        values["chain-workload/receipt.json"],
        values["chain-initial-contracts.json"],
    )
    if (
        current["retained_fixture_content"] != retained["restore"]["fixtures"][0]["content"]
        or current["reused_fixture_backups"] != retained["record"]["new_fixture_backups"]
    ):
        raise ValueError("Original restored content or verified backups changed")
    retained.update(record=current, installed=current["coordinator"][-1]["result"])
    return retained


def previous_names(retained):
    from poststate_continue import previous_names as names

    return names(retained)


def verify_retained(record, save, manifest, retained, current):
    from poststate_continue import verify_retained as verify

    verify(record, save, manifest, retained, current, installed=True)
