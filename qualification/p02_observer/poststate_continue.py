"""Continue only the authenticated DB27 stop before coordinator Preflight launch."""

from copy import deepcopy
from datetime import datetime, timedelta
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace
import zipfile

PRIOR = Path("Q:/P02Observer/20261123150616134")
PINS = {
    "packet.zip": "5014ff4672bc2e9066551e787d328c06ea955be1ad1c46dc3120e68499108add",
    "integration/receipt.json": "bd62aad4691aa1755c8dc2ce3857a23202ef787605387db6a4294d6764a7603e",
    "integration.launch.json": "77a976fbb9ac6370e3230787857dc941e8861d8fa31fec9daa46593ecc595a1e",
    "restore-bindings.json": "6a1a28edfc2585c42ce316f8a00fd28100107eb29851e2566749d6522bf3bcaa",
    "guest-receipt.json": "6e0591fc870bb9ba20db4f1560ceab36943847fc3dab76d52a0519ff57969c05",
    "storage-receipt.json": "5272245c0a47dbbeeb85ea5feed260d947a08bf9f0091dfc594b13ec41b63589",
    "before/receipt.json": "19421cc7d0c3a8732ebb19ad9dd1afac3bc7e183a8a0e20ec87e4068e4dbd80c",
    "after/receipt.json": "e862cf23e902289a33f78845947f41f523342d80b9bf318024cb034179a30057",
    "Status.stdout.txt": "e533fc804b7f3ed77e7d49e12e9e885b3d46fb91309e76bd3c0f7b01cbbadb93",
}


def require_setup(record, launch, restore, binding):
    if (
        record.get("outcome") != "failed"
        or record.get("first_failure")
        != dict(stage="fresh canonical observer Preflight", error_type="FileExistsError")
        or record.get("cleanup_failures") != []
        or record.get("preservation_failure") is not None
        or any(
            record.get(k) is not True
            for k in ("original_preserved", "original_name_restored", "login_disabled")
        )
        or record.get("physical_custody_retained") is not False
        or record.get("name_transition_uncertain") is not False
        or record.get("children") != []
        or record.get("admin_connections_closed") != 26
        or launch.get("settled") is not True
        or launch.get("exit_code") != 1
        or launch.get("receipt_sha256") != PINS["integration/receipt.json"]
    ):
        raise ValueError("Exact settled pre-coordinator failure required")
    stages = record["coordinator"]
    if (
        len(stages) != 2
        or stages[0].get("operation") != "Status"
        or stages[0].get("acknowledged") is not True
        or stages[0].get("settled") is not True
        or stages[0].get("exit_code") != 10
        or stages[0].get("result", {}).get("state") != "unstarted"
        or stages[1] != dict(operation="Preflight", acknowledged=False)
    ):
        raise ValueError("Preflight must not have launched; no migration replay")
    if (
        restore.get("outcome") != "passed"
        or restore.get("first_failure") is not None
        or restore.get("cleanup_failure") is not None
        or restore.get("execution_settled") is not True
        or len(restore.get("fixtures", [])) != 1
        or restore["fixtures"][0].get("observer_objects") != []
        or len(restore["fixtures"][0].get("history", [])) != 105
        or len(binding.get("fixtures", [])) != 1
        or binding["fixtures"][0].get("database_guid") != "6a0068da-c67f-4a8c-a934-c2feb49edf2e"
        or record["new_fixture"]["database_id"] != 27
        or record["new_fixture"]["user_access_desc"] != "RESTRICTED_USER"
    ):
        raise ValueError("Genuine retained DB27 predecessor is required")
    backups = record.get("new_fixture_backups", [])
    if (
        [row.get("kind") for row in backups] != ["full", "log"]
        or any(
            row.get("acknowledged") is not True or row.get("verified") is not True
            for row in backups
        )
        or len(record.get("actions", [])) != 10
        or any(a.get("acknowledged") is not True for a in record["actions"])
    ):
        raise ValueError("Both original verified backups and settled name return required")
    before = deepcopy(record["name_inventory_before"])
    after = record["name_inventory_after"]
    for number in (18, 27):
        actions = [
            a
            for a in record["name_transitions"]
            if a["database_id"] == number and a["kind"] == "rename"
        ]
        old = next(row for row in before if row["database_id"] == number)
        new = next(row for row in after if row["database_id"] == number)
        if len(actions) != 2 or any(a["acknowledged"] is not True for a in actions):
            raise ValueError("Exact acknowledged name round trip required")
        last = actions[-1]
        date = datetime.fromisoformat(new["create_date"])
        if last["to"] != old["name"] or not (
            datetime.fromisoformat(last["before"]) - timedelta(milliseconds=4)
            <= date
            <= datetime.fromisoformat(last["after"]) + timedelta(milliseconds=4)
        ):
            raise ValueError("Retained name date lacks acknowledged transition")
        old["create_date"] = new["create_date"]
    if before != after or record["name_inventory_current"] != after:
        raise ValueError("Retained inventory changed beyond acknowledged name dates")


def authenticate(packet, manifest):
    if manifest.get("continuation") != "status-before-preflight-20261123150616134":
        raise ValueError("Exact capture continuation required")
    values = {}
    for name, digest in PINS.items():
        raw = (PRIOR / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError("Original capture evidence changed: " + name)
        if name.endswith(".json"):
            values[name] = json.loads(raw)
    with zipfile.ZipFile(PRIOR / "packet.zip") as archive:
        old = json.loads(archive.read("manifest.json"))
    for key in (
        "release",
        "databases",
        "data_directory",
        "backup_directory",
        "account",
        "storage_owner",
        "publisher_operation",
        "requests",
        "credential",
        "capture_route",
        "verifier_manifest_sha256",
    ):
        if manifest[key] != old[key]:
            raise ValueError("Continuation changed a retained operation identity: " + key)
    binding = values["restore-bindings.json"]
    if (packet / "restore-bindings.json").read_bytes() != (
        PRIOR / "restore-bindings.json"
    ).read_bytes():
        raise ValueError("Original restore binding changed")
    record = values["integration/receipt.json"]
    require_setup(record, values["integration.launch.json"], values["guest-receipt.json"], binding)
    return dict(record=record, restore=values["guest-receipt.json"], binding=binding)


def previous_names(retained):
    return SimpleNamespace(current=retained["record"]["name_inventory_after"])


def require_unstarted_capture(preparations, resources):
    # The restored global resource exists even though this account is unused.
    if (
        preparations
        or len(resources) != 1
        or resources[0].get("ResourceKey") != "sql_snapshot:legacy_outputs"
        or resources[0].get("blocked") != 0
        or any(
            resources[0].get(key) is not None
            for key in ("ActiveJobID", "ActivePreparationID", "ActiveOutputOperationID", "OwnerID")
        )
    ):
        raise ValueError("Capture work or existing physical ownership must not be replayed")


def verify_retained(record, save, manifest, retained, current, *, installed=False):
    from cost_resume import HISTORY, require_history
    from cost_workload_binding import content_sql, require_content
    import fresh_business_backup as backup
    from fresh_business_state import IDENTITY, normalized, require_identity
    from poststate_owner import FILES, owned
    from poststate_report_cases import prerequisites

    prior = retained["record"]
    if current != prior["name_inventory_after"]:
        raise ValueError("Current physical inventory differs from retained name return")
    with owned("master", record, save) as owner:
        if normalized(owner.read(FILES)) != prior["name_files"]:
            raise ValueError("Retained physical database files changed")
    with owned(manifest["databases"][0], record, save, timeout=15) as owner:
        require_identity(owner.read(IDENTITY), manifest["databases"][0], 27)
        require_history(
            owner.read(HISTORY),
            retained["restore"]["fixtures"][0]["history"],
            "ON" if installed else "OFF",
            prior if installed else {},
        )
        if not installed and owner.read(
            "SELECT name,type_desc FROM sys.objects "
            "WHERE name LIKE N'%P02%Observation%' OR name=N'P02ObservationGeneration'"
        ):
            raise ValueError("Observer installation already started; no replay")
        if installed:
            from producer_fixture import FRESH_ACCOUNT, ORIGINAL_PREPARATIONS, RESOURCE_SQL
            from remaining_actors import generation

            if generation(owner) != 1:
                raise ValueError("Refused publisher may have changed generation; no dispatch")
            if (
                owner.read(ORIGINAL_PREPARATIONS, manifest["account"], manifest["account"])
                != prior["original_preparations"]
            ):
                raise ValueError("Original preparations changed after refusal")
            require_unstarted_capture(
                owner.read(FRESH_ACCOUNT, manifest["account"]),
                owner.read(RESOURCE_SQL, "account:" + manifest["account"]),
            )
            record["refused_publication_generation"] = 1
        content = []
        for item in retained["restore"]["fixtures"][0]["content"]:
            facts = require_content(owner.read(content_sql("dbo." + item["table"])))
            actual = dict(
                table=item["table"], rows=facts["rows"], content_sha256=facts["content_sha256"]
            )
            if actual != item:
                raise ValueError("Restored business content changed before continuation")
            content.append(actual)
        record["retained_fixture_content"] = content
        for row in prior["reused_fixture_backups" if installed else "new_fixture_backups"]:
            path = Path(row["path"])
            if path.parent != Path(manifest["backup_directory"]):
                raise ValueError("Retained backup path differs")
            if (
                backup.file_facts(path) != row["file"]
                or normalized(owner.read(backup.HISTORY_SQL, str(path))) != row["history"]
                or normalized(owner.read(backup.HEADER_SQL, str(path))) != row["header"]
            ):
                raise ValueError("Retained verified backup changed; do not replace")
        record["reused_fixture_backups"] = prior[
            "reused_fixture_backups" if installed else "new_fixture_backups"
        ]
        prerequisites(owner, record, save)
    save()
