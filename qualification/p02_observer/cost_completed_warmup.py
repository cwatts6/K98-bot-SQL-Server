"""Exact completed warm-up reuse; retain first failure and never replay its writes."""

from copy import deepcopy
from datetime import datetime
import hashlib
import json
from pathlib import Path

PRIOR = Path(r"Q:\P02Observer\20261123084025172")
RECEIPT_SHA = "c04c8dddf34511b779e77c4f3dfdcab1f9e03febd3f0b7b562b8d21155de0d38"
ARCHIVE_SHA = "22b1890d194ae7f6f9abae8614799b687f06588314b5fe0a8ccf1c06ee2a17bc"
LAUNCH_SHA = "35ebc7f73a77329dd5747069324085a563e64e730beaaa9a723e26488d81ef82"
KINDS = {"configuration", "final_stats", "import", "kvk_output", "player_report", "post_import"}


def require_reconciled(value, latest, case):
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("preservation_failure") is not None
        or value.get("before") != latest["after"]
        or value.get("after") != latest["after"]
        or value.get("new_fixtures") != latest["new_fixtures"]
        or value.get("original_preserved") is not True
        or value.get("login_disabled") is not True
        or value.get("physical_custody_retained") is not False
        or value.get("admin_connections_closed") != 14
        or value.get("actions") != []
        or value.get("login_enable_attempted") is not False
        or any(
            value.get(k) != 0
            for k in (
                "business_operations",
                "maintenance_dispatches",
                "migrations",
                "renames",
                "restores",
                "backups",
                "provider_operations",
            )
        )
        or len(value.get("diagnostics", [])) != 2
        or len(value.get("workload_copies", [])) != 2
    ):
        raise ValueError(
            "Exact settled read-only reconciliation and original preservation required"
        )
    capture = value["retained_capture"]
    if (
        capture.get("verified") is not True
        or capture["preparation_id"] != case["preparation_id"]
        or capture["snapshot"] != case["snapshot"]
        or capture["sections_sha256"] != case["sections_sha256"]
        or capture["section_count"] != case["section_count"]
    ):
        raise ValueError("Original completed immutable capture differs")
    for index, mode in enumerate(("OFF", "ON")):
        item = value["diagnostics"][index]
        q = item["queries"]
        if (
            item["mode"] != mode
            or q["active"]
            or q["maintenance"] != q["maintenance_after_reads"]
            or q["preparations"] != q["preparations_after_reads"]
            or q["error_audit"] != case["audit_before"]
            or q["sequence"] != latest["statistics_preparation"][index]["sequence_after"]
            or len(value["workload_copies"][index]["outputs"]) != 59
            or value["workload_copies"][index]["queries"]["source"] != case["source_before"]
        ):
            raise ValueError("Recorded postwork source, capture or maintenance changed")
        rows = q["maintenance"]
        if len(rows) != 6 or {r["Kind"] for r in rows} != KINDS:
            raise ValueError("All six exact maintenance kinds required")
        for row in rows:
            if (
                row["State"] != "complete"
                or row["DueGeneration"] != row["CompletedGeneration"]
                or any(
                    row[k] is not None
                    for k in ("FirstErrorNumber", "FirstErrorUTC", "LastErrorNumber")
                )
            ):
                raise ValueError("Unfinished or failed maintenance cannot be replayed")
            if index == 0:
                due = {"configuration": 14, "player_report": 2}.get(row["Kind"], 1)
                if (
                    row["DueGeneration"] != due
                    or row["ClaimedGeneration"] != due
                    or not row["ClaimID"]
                ):
                    raise ValueError("Original maintenance completion generation differs")
                if (
                    row["LastRequestID"] is not None
                    and row["LastRequestID"].lower() != case["maintenance_request"]
                ):
                    raise ValueError("Maintenance request belongs to different work")
            elif row["DueGeneration"] != 0 or row["ClaimID"] is not None:
                raise ValueError("ON warm-up already ran")
        if index == 1 and q["preparations"]:
            raise ValueError("ON account already has work")
    off = value["diagnostics"][0]["queries"]
    cfg = off["configuration_work"][0]
    kvk = off["kvk_work"]
    if (
        cfg["DueRows"] != 5810
        or cfg["CompletedRows"] != 5810
        or cfg["UpkeepCompletedGeneration"] != 14
        or cfg["UpkeepDisposition"] != "complete"
        or cfg["FirstLogErrorNumber"] is not None
        or len(kvk) != 1
        or kvk[0]["KVKNo"] != 16
        or kvk[0]["DueGeneration"] != kvk[0]["CompletedGeneration"]
        or kvk[0]["State"] != "complete"
        or kvk[0]["FirstErrorNumber"] is not None
    ):
        raise ValueError("Original configuration/KVK work did not settle")


def authenticate(packet):
    import cost_postwork_read as post

    latest, completed, old, case = post.authenticate(packet)
    raw = (PRIOR / "receipt.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RECEIPT_SHA
        or hashlib.sha256((PRIOR / "packet.zip").read_bytes()).hexdigest() != ARCHIVE_SHA
    ):
        raise ValueError("Immutable postwork reconciliation changed")
    launch_raw = (packet / "evidence/cost-reconciled/launch-result.json").read_bytes()
    launch = json.loads(launch_raw)
    if (
        hashlib.sha256(launch_raw).hexdigest() != LAUNCH_SHA
        or launch.get("state") != "exited"
        or launch.get("exitCode") != 0
        or launch.get("pid") != 2708
        or launch.get("path") != str(PRIOR)
        or launch.get("PSComputerName") != "K98-MGE-Qualification-20261029"
    ):
        raise ValueError("Exact completed reconciliation process required")
    value = json.loads(raw)
    require_reconciled(value, latest, case)
    child = json.loads((post.PRIOR / "cost-evidence/00-OFF-workload/receipt.json").read_bytes())
    return dict(
        latest=latest, completed=completed, old=old, case=case, reconciled=value, child=child
    )


def require_manifest(manifest, context):
    old = context["old"]
    if (
        manifest.get("retained_warmup_receipt_sha256") != RECEIPT_SHA
        or manifest.get("fresh_reports") != 19
        or manifest.get("retained_reports") != 1
        or manifest.get("total_reports") != 20
        or any(
            manifest.get(k) != old[k]
            for k in (
                "requests",
                "account",
                "storage_owner",
                "private_directory",
                "credential",
                "release",
                "databases",
                "data_directory",
            )
        )
    ):
        raise ValueError("Only the nineteen original unstarted cases may continue")


def require_copy(index, value, statistics, history, sequence, accounts, context):
    from cost_readiness import logical_differences
    from fresh_business_state import normalized

    recorded = context["reconciled"]
    q = recorded["diagnostics"][index]["queries"]
    differences = logical_differences(value, recorded["workload_copies"][index])
    if (
        differences
        or normalized(statistics) != q["complete_statistics"]
        or normalized(history) != q["history"]
        or normalized(sequence) != q["sequence"]
        or normalized(accounts) != q["preparations"]
    ):
        raise ValueError("Cost copy differs from its own authenticated post-warm-up state")
    return dict(
        mode=("OFF", "ON")[index],
        exact_recorded_state=True,
        statistics_count=statistics[0]["statistics_count"],
        cross_copy_equality_claimed=False,
    )


def reuse_spool(manifest, context):
    from cost_postwork_read import capture_bytes

    require_manifest(manifest, context)
    verified = capture_bytes(context["old"], context["case"], context["case"]["snapshot"])
    return dict(
        path=manifest["private_directory"],
        spool=str(Path(manifest["private_directory"]) / "spool"),
        retained=True,
        existing_acls_changed=False,
        capture=verified,
    )


def retained_case(context):
    from cost_workload import STATE_TABLES, normalize_state

    case = deepcopy(context["case"])
    post = context["reconciled"]
    copy = post["workload_copies"][0]
    # This is a process-exit upper bound, not a fabricated measured SQL clock.
    end = datetime.fromisoformat(context["child"]["finished"])
    if end.utcoffset().total_seconds() != 0:
        raise ValueError("Original UTC process completion bound required")
    end_bound = dict(utc_time=end.replace(tzinfo=None).isoformat())
    outputs = {}
    raw_state = {
        "dbo.SUMMARY_PROC_STATE": copy["queries"]["summary_cursors"],
        "dbo.MaintenanceWork": post["diagnostics"][0]["queries"]["maintenance"],
        "dbo.MaintenanceKvkWork": post["diagnostics"][0]["queries"]["kvk_work"],
    }
    for name, item in copy["outputs"].items():
        result = dict(columns=item["columns"], raw_content=item["content"])
        if name in STATE_TABLES:
            rows = raw_state[name]
            result["raw_rows"] = rows
            result["logical_rows"] = normalize_state(
                name, rows, case["clock_before"], end_bound, case["maintenance_request"]
            )
        outputs[name] = result
    case.update(
        outcome="reconciled_complete",
        original_first_failure=case["first_failure"],
        first_failure=None,
        reconciliation_receipt_sha256=RECEIPT_SHA,
        replayed=False,
        cost_measurement_eligible=False,
        process_exit_upper_bound=context["child"]["finished"],
        source_after=copy["queries"]["source"],
        configuration_work=copy["queries"]["configuration_work"],
        backup_work=copy["queries"]["backup_work"],
        outputs=outputs,
    )
    return case


def child_warmup(packet, manifest, number):
    if manifest.get("retained_warmup_receipt_sha256") is None or number != 0:
        return None
    context = authenticate(packet)
    require_manifest(manifest, context)
    return retained_case(context)
