"""Reconcile one unstarted cost attempt and compare current physical readiness."""

from copy import deepcopy
import hashlib
import json
from pathlib import Path

FAILED = Path(r"Q:\P02Observer\20261122162709081")
RECEIPT_SHA = "248d2cd1bd74d4962fa2f4875711a094191e0d45a0b1db59d9085fd4f2877332"
ARCHIVE_SHA = "f3432e3b6b675956ff25367c95e2b2b39de1cab51d6a70abf62e8762756d70e6"
OLD_STATISTICS = [dict(statistics_count=2101, eligible_count=358, modifications=100797)]
CURRENT_STATISTICS = [dict(statistics_count=2310, eligible_count=358, modifications=100797)]
STATISTICS = """DECLARE @statistics nvarchar(max)=(
SELECT TOP (5001) SCHEMA_NAME(t.schema_id) AS schema_name,t.name AS table_name,
s.stats_id,s.name AS statistics_name,s.auto_created,s.user_created,s.no_recompute,
s.has_filter,s.filter_definition,s.is_incremental,s.has_persisted_sample,
s.stats_generation_method,s.auto_drop,t.is_memory_optimized,
p.last_updated,p.rows,p.rows_sampled,p.steps,p.unfiltered_rows,p.modification_counter,
p.persisted_sample_percent,
JSON_QUERY((SELECT sc.stats_column_id,c.column_id,c.name FROM sys.stats_columns sc
JOIN sys.columns c ON c.object_id=sc.object_id AND c.column_id=sc.column_id
WHERE sc.object_id=s.object_id AND sc.stats_id=s.stats_id
ORDER BY sc.stats_column_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS columns
FROM sys.stats s JOIN sys.tables t ON t.object_id=s.object_id
OUTER APPLY sys.dm_db_stats_properties(s.object_id,s.stats_id) p WHERE t.is_ms_shipped=0
ORDER BY SCHEMA_NAME(t.schema_id),t.name,s.stats_id FOR JSON PATH,INCLUDE_NULL_VALUES);
SELECT @statistics AS statistics_json,DATALENGTH(@statistics) AS json_bytes,
(SELECT COUNT_BIG(*) FROM OPENJSON(@statistics)) AS statistics_count;"""


def logical_differences(current, recorded):
    from cost_workload_binding import compare_copies
    from fresh_business_state import normalized

    # The immutable receipt uses default=str for native datetimes/decimals.
    # Preserve that exact precision; statistics have their own current-pair gate.
    live = normalized(current)
    live["queries"]["statistics"] = deepcopy(recorded["queries"]["statistics"])
    return compare_copies(live, recorded)


def require_unstarted(value, binding, launch):
    if (
        value.get("outcome") != "failed"
        or value.get("first_failure")
        != dict(
            stage="authenticate completed work and bind fresh cost ownership",
            error_type="ValueError",
            detail="Recorded ready workload changed before new business",
        )
        or value.get("before") != binding["after"]
        or value.get("after") != binding["after"]
        or value.get("new_fixtures") != binding["new_fixtures"]
        or value.get("admin_connections_closed") != 13
        or value.get("original_preserved") is not True
        or value.get("login_disabled") is not True
        or value.get("physical_custody_retained") is not False
        or value.get("name_transition_uncertain") is not False
        or value.get("original_name_restored") is not False
        or value.get("measured_cost_accepted") is not False
        or value.get("restores") != 0
        or value.get("provider_operations") != 0
        or value.get("prior_migrations_replayed") is not False
        or any(
            value.get(key) != []
            for key in ("actions", "children", "coordinator", "pairs", "cleanup_failures")
        )
        or any(key in value for key in ("private_spool", "preservation_failure", "cost"))
        or len(value.get("workload_copies", [])) != 1
        or launch.get("state") != "exited"
        or launch.get("pid") != 2980
        or launch.get("exitCode") != 1
        or launch.get("path") != str(FAILED)
        or launch.get("PSComputerName") != "K98-MGE-Qualification-20261029"
    ):
        raise ValueError("Only the exact settled pre-mutation cost failure may continue")
    copy = value["workload_copies"][0]
    if (
        logical_differences(copy, binding["workload_copies"][0])
        or copy["queries"]["statistics"] != CURRENT_STATISTICS
        or not copy["statements"]
        or any(row.get("acknowledged") is not True for row in copy["statements"])
    ):
        raise ValueError("Stopped logical binding or recorded statistics differ")


def authenticate(packet, binding):
    raw = (packet / "evidence/cost-stopped/receipt.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RECEIPT_SHA
        or raw != (FAILED / "receipt.json").read_bytes()
        or hashlib.sha256((FAILED / "packet.zip").read_bytes()).hexdigest() != ARCHIVE_SHA
        or (FAILED / "stdout.txt").read_bytes()
        or (FAILED / "stderr.txt").read_bytes()
        or list((FAILED / "cost-evidence").iterdir())
        or any(
            (FAILED / (op + "." + stream + ".txt")).exists()
            for op in ("Status", "Preflight", "Apply", "Verify")
            for stream in ("stdout", "stderr")
        )
    ):
        raise ValueError("Retained stopped attempt differs or has later work")
    value = json.loads(raw)
    launch = json.loads((packet / "evidence/cost-stopped/launch-result.json").read_bytes())
    entered = json.loads((FAILED / "entered.json").read_bytes())
    if entered != dict(pid=2980, purpose="p02-balanced-cost-workload"):
        raise ValueError("Stopped process identity differs")
    require_unstarted(value, binding, launch)
    return dict(
        receipt_sha256=RECEIPT_SHA,
        archive_sha256=ARCHIVE_SHA,
        outcome="settled before mutation",
        original_failure_preserved=True,
    )


def statistics_inventory(rows):
    if len(rows) != 1:
        raise ValueError("One complete statistics inventory required")
    row = rows[0]
    raw = row["statistics_json"]
    if (
        not isinstance(raw, str)
        or not 0 < row["json_bytes"] <= 4 * 1024**2
        or row["json_bytes"] != len(raw.encode("utf-16-le"))
        or row["statistics_count"] != CURRENT_STATISTICS[0]["statistics_count"]
    ):
        raise ValueError("Complete bounded statistics inventory differs")
    values = json.loads(raw)
    keys = [(r["schema_name"], r["table_name"], r["stats_id"]) for r in values]
    if len(values) != row["statistics_count"] or len(set(keys)) != len(keys):
        raise ValueError("Duplicate or missing statistics identity")
    if any(not r["columns"] for r in values):
        raise ValueError("Statistics columns must be complete")
    calculated = [
        dict(
            statistics_count=len(values),
            eligible_count=sum(
                bool((r["modification_counter"] or 0) > 0 or r["is_memory_optimized"])
                for r in values
            ),
            modifications=sum(r["modification_counter"] or 0 for r in values),
        )
    ]
    if calculated != CURRENT_STATISTICS:
        raise ValueError("Current statistics work eligibility differs")
    return values


def require_ready_pair(copies, binding, inventories):
    from cost_workload_binding import compare_copies
    from fresh_business_state import normalized

    if len(copies) != 2 or len(inventories) != 2:
        raise ValueError("Both current cost copies required")
    for current, old in zip(copies, binding["workload_copies"], strict=True):
        if (
            logical_differences(current, old)
            or old["queries"]["statistics"] != OLD_STATISTICS
            or current["queries"]["statistics"] != CURRENT_STATISTICS
        ):
            raise ValueError("Recorded logical state or current statistics changed")
    if compare_copies(normalized(copies[0]), normalized(copies[1])):
        raise ValueError("Current complete workload copies differ")
    comparable = [
        [{k: v for k, v in row.items() if k != "last_updated"} for row in values]
        for values in inventories
    ]
    if comparable[0] != comparable[1]:
        raise ValueError("Current statistics definitions or work eligibility differ")
    return dict(
        logical_equality=True,
        current_statistics_equality=True,
        historical_statistics=OLD_STATISTICS,
        current_statistics=CURRENT_STATISTICS,
        statistics_definitions_sha256=hashlib.sha256(
            json.dumps(comparable[0], sort_keys=True).encode()
        ).hexdigest(),
        last_updated_retained_but_not_equated=True,
    )
