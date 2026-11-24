"""Resume only the exact completed cost setup and unstarted first workload."""

from copy import deepcopy
from datetime import datetime, timedelta
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace

PRIOR = Path(r"Q:\P02Observer\20261122165456787")
RECEIPT_SHA = "edfd7c226e1ea8824badaa49c83101cb7f9def8140b46d2a8cefebe5cc6e7643"
ARCHIVE_SHA = "0e47339e4fe562a7f4680a1b5a0aa54e7af5e1c3a0371dea0faaf7b3705a1485"
CHILD_SHA = "72c4abee6f80c4e54a1a3806e889d7e8af1acbc52758cffe7e0662b182b04b6a"
HISTORY = "SELECT MigrationId,ChecksumSha256,GitCommit,CONVERT(varchar(36),DeploymentId) AS DeploymentId,Status FROM dbo.SchemaMigrationHistory ORDER BY MigrationId"
SEQUENCE = "SELECT object_id,create_date,modify_date,CONVERT(bigint,current_value) AS generation,is_exhausted FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration')"
HISTORY_TABLES = {"SchemaMigrationHistory", "DeploymentRunHistory"}


def require_setup(value, child, binding):
    if (
        value.get("outcome") != "failed"
        or value.get("cleanup_failures") != []
        or value.get("preservation_failure") is not None
        or any(
            value.get(k) is not True
            for k in ("original_preserved", "original_name_restored", "login_disabled")
        )
        or any(
            value.get(k) is not False
            for k in (
                "physical_custody_retained",
                "name_transition_uncertain",
                "measured_cost_accepted",
            )
        )
        or value.get("admin_connections_closed") != 28
        or value.get("pairs") != []
        or value.get("before") != binding["after"]
        or len(value.get("actions", [])) != 16
        or any(a.get("acknowledged") is not True for a in value["actions"])
        or len(value.get("children", [])) != 1
        or value.get("cost_readiness", {}).get("current_statistics_equality") is not True
    ):
        raise ValueError("Exact settled completed setup required")
    c = value["children"][0]
    if (
        c.get("number") != 0
        or c.get("mode") != "OFF"
        or c.get("role") != "workload"
        or c.get("settled") is not True
        or c.get("exit_code") != 1
        or c.get("receipt_sha256") != CHILD_SHA
        or child.get("outcome") != "failed"
        or child.get("cases") != []
        or child.get("actions") != []
        or child.get("admin_dispatches") != 0
        or child.get("cleanup_failures") != []
        or child.get("physical_custody_retained") is not False
        or child.get("credential_environment_cleared") is not True
        or child.get("first_failure")
        != dict(
            stage="authenticate actual workload",
            error_type="SourceConflict",
            detail="Direct permission metadata differs from protected approved fingerprint.",
        )
        or child.get("physical_cleanup", {}).get("connections")
        != [dict(closed_by_caller=True, cleanup_close=False)] * 2
        or child["physical_cleanup"].get("safe_to_exit") is not True
        or child["physical_cleanup"].get("all_closed_by_callers") is not True
    ):
        raise ValueError(
            "Original first workload must have stopped before business with closed handles"
        )
    stages = value["coordinator"]
    if (
        [x["operation"] for x in stages] != ["Status", "Preflight", "Apply", "Verify"]
        or any(x.get("acknowledged") is not True or x.get("settled") is not True for x in stages)
        or [x["exit_code"] for x in stages] != [10, 0, 0, 0]
        or stages[-1]["result"] != stages[-2]["result"]
        or stages[-1]["result"].get("state") != "committed"
        or stages[-1]["result"].get("deployment_id") != "a3955992-44fb-4ec5-a029-ff9645980419"
        or stages[-1]["result"]["observation_installation"]["database_id"] != 26
        or len(value.get("cost_backups", [])) != 2
        or any(
            x.get("acknowledged") is not True or x.get("verified") is not True
            for x in value["cost_backups"]
        )
    ):
        raise ValueError("Completed backups and committed ON installation required")
    # Only the already acknowledged final rename dates may change preservation.
    before = deepcopy(value["name_inventory_before"])
    after = value["name_inventory_after"]
    for number in (18, 25, 26):
        actions = [
            a
            for a in value["name_transitions"]
            if a["database_id"] == number and a["kind"] == "rename"
        ]
        if not actions or any(a["acknowledged"] is not True for a in actions):
            raise ValueError("Complete acknowledged name return required")
        old = next(r for r in before if r["database_id"] == number)
        new = next(r for r in after if r["database_id"] == number)
        last = actions[-1]
        date = datetime.fromisoformat(new["create_date"])
        if last["to"] != old["name"] or not datetime.fromisoformat(last["before"]) - timedelta(
            milliseconds=4
        ) <= date <= datetime.fromisoformat(last["after"]) + timedelta(milliseconds=4):
            raise ValueError("Returned name/date does not match its acknowledged boundary")
        old["create_date"] = new["create_date"]
    if before != after or value["name_inventory_current"] != after:
        raise ValueError("Physical inventory changed beyond completed name transitions")
    wanted = deepcopy(value["before"])
    for row in wanted["databases"]:
        if row["database_id"] == 18:
            row["create_date"] = next(r["create_date"] for r in after if r["database_id"] == 18)
    if wanted != value["after"]:
        raise ValueError("Completed original work changed outside acknowledged name date")


def authenticate(packet, binding):
    raw = (packet / "evidence/cost-completed/receipt.json").read_bytes()
    child_raw = (packet / "evidence/cost-completed/child-receipt.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RECEIPT_SHA
        or raw != (PRIOR / "receipt.json").read_bytes()
        or hashlib.sha256((PRIOR / "packet.zip").read_bytes()).hexdigest() != ARCHIVE_SHA
        or hashlib.sha256(child_raw).hexdigest() != CHILD_SHA
        or child_raw != (PRIOR / "cost-evidence/00-OFF-workload/receipt.json").read_bytes()
    ):
        raise ValueError("Immutable completed setup or stopped child changed")
    for operation in ("Status", "Preflight", "Apply", "Verify"):
        for stream in ("stdout", "stderr"):
            name = operation + "." + stream + ".txt"
            if (packet / "evidence/cost-completed" / name).read_bytes() != (
                PRIOR / name
            ).read_bytes():
                raise ValueError("Original coordinator evidence differs")
    if (packet / "evidence/cost-completed/manifest.json").read_bytes() != (
        PRIOR / "manifest.json"
    ).read_bytes():
        raise ValueError("Original finite workload identity changed")
    value = json.loads(raw)
    require_setup(value, json.loads(child_raw), binding)
    return value


def preservation_context(expected, completed):
    from cost_pair_control import adjusted_preservation

    return adjusted_preservation(
        expected, SimpleNamespace(current=completed["name_inventory_after"])
    )


def require_history(rows, expected, mode, completed):
    def normalized(values):
        return sorted(
            [{**r, "DeploymentId": str(r["DeploymentId"]).lower()} for r in values],
            key=lambda r: r["MigrationId"],
        )

    wanted = deepcopy(expected)
    if mode == "ON":
        result = completed["coordinator"][-1]["result"]
        wanted.append(
            dict(
                MigrationId=result["migration_id"],
                ChecksumSha256=result["profile_sha256"],
                GitCommit=result["sql_commit"],
                DeploymentId=result["deployment_id"],
                Status="Applied",
            )
        )
    if normalized(rows) != normalized(wanted):
        raise ValueError("Prior migration history or only committed ON successor changed")


def require_sequence(rows, mode, completed):
    if mode == "OFF":
        if rows:
            raise ValueError("OFF must remain the genuine predecessor")
        return
    wanted = completed["coordinator"][-1]["result"]["observation_installation"]
    if (
        len(rows) != 1
        or rows[0]["object_id"] != wanted["sequence_object_id"]
        or rows[0]["create_date"].isoformat(timespec="microseconds") != wanted["sequence_created"]
        or rows[0]["modify_date"].isoformat(timespec="microseconds") != wanted["sequence_modified"]
        or rows[0]["generation"] != 1
        or rows[0]["is_exhausted"] is not False
    ):
        raise ValueError("Completed ON incarnation or unstarted generation differs")


def project_workload(value, old, mode):
    from fresh_business_state import normalized

    from services.application_observation_fingerprint import reviewed_procedure_hashes

    result = normalized(value)
    if mode == "ON":
        pins = reviewed_procedure_hashes()
        for name in pins.keys() & result["modules"].keys():
            actual = result["modules"][name]
            if actual["canonical_definition_sha256"] != pins[name]:
                raise ValueError("ON workload module differs from independent committed source")
            for key in ("canonical_definition_sha256", "native_definition_sha256"):
                actual[key] = old["modules"][name][key]
    return result


def require_current_pair(copies, completed, raw_statistics):
    from cost_readiness import logical_differences
    from cost_workload_binding import compare_copies

    def business_stats(rows):
        return [
            {k: v for k, v in r.items() if k != "last_updated"}
            for r in rows
            if not (r["schema_name"] == "dbo" and r["table_name"] in HISTORY_TABLES)
        ]

    projected = []
    for i, mode in enumerate(("OFF", "ON")):
        old = completed["workload_copies"][i]
        current = project_workload(copies[i], old, mode)
        if logical_differences(current, old):
            raise ValueError("Completed setup has changed unstarted business workload")
        # Installation ledger statistics differ legitimately after the genuine commit.
        # Preserve them; all non-ledger definitions/sampling/work counters must match.
        row = raw_statistics[i][0]
        text = row["statistics_json"]
        current_stats = json.loads(text)
        if (
            not 0 < row["json_bytes"] <= 4 * 1024**2
            or row["json_bytes"] != len(text.encode("utf-16-le"))
            or not 0 < row["statistics_count"] <= 5000
            or len(current_stats) != row["statistics_count"]
        ):
            raise ValueError("Complete bounded current statistics required")
        old_stats = json.loads(completed["statistics_observations"][i][0]["statistics_json"])
        if business_stats(current_stats) != business_stats(old_stats):
            raise ValueError("Unstarted non-ledger statistics workload changed")
        current["queries"]["statistics"] = deepcopy(old["queries"]["statistics"])
        projected.append(current)
    if compare_copies(*projected):
        raise ValueError("Current complete workload copies differ")
    return dict(
        logical_equality=True,
        non_ledger_statistics_equality=True,
        committed_ledger_statistics_retained=True,
        observer_source_verified=True,
    )


def reuse_backups(completed):
    from fresh_business_backup import file_facts

    for value in completed["cost_backups"]:
        if file_facts(Path(value["path"])) != value["file"]:
            raise ValueError("Retained verified recovery backup changed")
