"""Read-only diagnosis of the retained pre-workload source refusal on DB25/26.

This records complete aggregate counts and bounded examples. It neither admits a
workload nor relaxes the existing cost guard. Completed operations are not replayed.
"""

from copy import deepcopy
from datetime import UTC, datetime, timedelta
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time

PURPOSE = "p02-cost-source-diagnostic"
PRIOR = Path(r"Q:\P02Observer\20261122172517241")
PINS = {
    "receipt.json": "194f4329f2bbc9340be5b8132b2080786eecc020e66aff684dca6fda8633a79d",
    "cost-evidence/00-OFF-workload/receipt.json": "a1b973c33f07edf09c8cf03861c86752321af91c34a3f89cd291ad8ca7088470",
    "cost-evidence/00-OFF-workload/contracts.json": "a586b68faa9ad5e77c6f03f2e498e26f7af92acbb7d788153d94d0efa4a72292",
}
ARCHIVE_SHA = "42a56825495098446b734c53597dca8c0b7fbd1efbd4c734f50baa4a805c1727"
CLOCKS = "SELECT SYSUTCDATETIME() AS utc_now,GETDATE() AS local_now"
GROUPS = """WITH g AS (
SELECT GovernorID,SCANORDER,COUNT_BIG(*) AS row_count,
MIN(ScanDate) AS first_date,MAX(ScanDate) AS last_date
FROM dbo.KingdomScanData4 WHERE GovernorID<>0 GROUP BY GovernorID,SCANORDER)
"""
DUPLICATES = GROUPS + """SELECT COUNT_BIG(*) AS duplicate_groups,
COALESCE(SUM(row_count-1),0) AS excess_rows,MIN(SCANORDER) AS first_scan,
MAX(SCANORDER) AS last_scan,COALESCE(MAX(row_count),0) AS maximum_group_rows,
COALESCE(SUM(CONVERT(bigint,CASE WHEN first_date<>last_date THEN 1 ELSE 0 END)),0)
AS groups_with_different_dates FROM g WHERE row_count>1"""
DUPLICATE_SCANS = GROUPS + """SELECT TOP (100) SCANORDER,COUNT_BIG(*) AS duplicate_groups,
SUM(row_count) AS rows_in_groups,MIN(first_date) AS first_date,MAX(last_date) AS last_date
FROM g WHERE row_count>1 GROUP BY SCANORDER ORDER BY SCANORDER"""
# TOP limits only examples, never the aggregate totals. Binary JSON hashes compare
# all selected payload values, preserving NULL and string case without logging names.
DUPLICATE_EXAMPLES = GROUPS + """, chosen AS (
SELECT TOP (100) * FROM g WHERE row_count>1 ORDER BY SCANORDER,GovernorID)
SELECT c.GovernorID,c.SCANORDER,c.row_count,c.first_date,c.last_date,
COUNT(DISTINCT HASHBYTES('SHA2_256',j.payload)) AS selected_payload_variants
FROM chosen c JOIN dbo.KingdomScanData4 k
ON k.GovernorID=c.GovernorID AND k.SCANORDER=c.SCANORDER
CROSS APPLY (SELECT k.GovernorName,k.Alliance,k.PowerRank,k.Power,k.KillPoints,k.Deads,
k.T1_Kills,k.T2_Kills,k.T3_Kills,k.T4_Kills,k.T5_Kills,k.[T4&T5_KILLS],
k.TOTAL_KILLS,k.RSS_Gathered,k.RSSAssistance,k.Helps,k.ScanDate,k.HealedTroops,
k.RangedPoints,k.Civilization,k.KvKPlayed,k.MostKvKKill,k.MostKvKDead,k.MostKvKHeal,
k.Acclaim,k.HighestAcclaim,k.AOOJoined,k.AOOWon,k.AOOAvgKill,k.AOOAvgDead,k.AOOAvgHeal,
k.AutarchTimes,k.Conduct,k.[City Hall] FOR JSON PATH,INCLUDE_NULL_VALUES,
WITHOUT_ARRAY_WRAPPER) j(payload)
GROUP BY c.GovernorID,c.SCANORDER,c.row_count,c.first_date,c.last_date
ORDER BY c.SCANORDER,c.GovernorID"""
ENDPOINT_TIES = """DECLARE @utc datetime2=CONVERT(datetime2,?,126);
WITH w AS (SELECT * FROM (VALUES (0),(3),(6),(12)) x(months)),
g AS (SELECT w.months,k.GovernorID,k.SCANORDER,COUNT_BIG(*) AS row_count
FROM dbo.KingdomScanData4 k CROSS JOIN w WHERE k.GovernorID<>0
AND (w.months=0 OR k.ScanDate>=DATEADD(month,-w.months,@utc))
GROUP BY w.months,k.GovernorID,k.SCANORDER),
b AS (SELECT months,GovernorID,MIN(SCANORDER) AS first_scan,MAX(SCANORDER) AS last_scan
FROM g GROUP BY months,GovernorID)
SELECT g.months,COUNT_BIG(*) AS governor_scan_groups,
SUM(CONVERT(bigint,CASE WHEN g.row_count>1 THEN 1 ELSE 0 END)) AS duplicate_groups,
SUM(CONVERT(bigint,CASE WHEN g.row_count>1 AND g.SCANORDER=b.first_scan THEN 1 ELSE 0 END)) AS first_ties,
SUM(CONVERT(bigint,CASE WHEN g.row_count>1 AND g.SCANORDER=b.last_scan THEN 1 ELSE 0 END)) AS last_ties,
SUM(CONVERT(bigint,CASE WHEN g.row_count>1 AND g.SCANORDER=b.first_scan AND b.last_scan=1244 THEN 1 ELSE 0 END)) AS affected_first_ties,
SUM(CONVERT(bigint,CASE WHEN g.row_count>1 AND g.SCANORDER=b.last_scan AND b.last_scan=1244 THEN 1 ELSE 0 END)) AS affected_last_ties
FROM g JOIN b ON b.months=g.months AND b.GovernorID=g.GovernorID
GROUP BY g.months ORDER BY g.months"""
DATE_BOUNDARIES = """DECLARE @utc datetime2=CONVERT(datetime2,?,126),
@local datetime2=CONVERT(datetime2,?,126);
WITH cutoffs AS (
SELECT v.months,CAST('utc' AS varchar(5)) AS clock,DATEADD(month,-v.months,@utc) AS cutoff
FROM (VALUES (3),(6),(12)) v(months)
UNION ALL SELECT v.months,'local',DATEADD(month,-v.months,@local)
FROM (VALUES (3),(6),(12)) v(months)),
latest AS (SELECT GovernorID,MAX(ScanDate) AS last_login FROM dbo.KingdomScanData4
GROUP BY GovernorID)
SELECT 'months' AS unit,c.months AS amount,c.clock,c.cutoff,
SUM(CONVERT(bigint,CASE WHEN ABS(DATEDIFF_BIG(second,k.ScanDate,c.cutoff))<=3600 THEN 1 ELSE 0 END)) AS rows_within_hour,
MIN(ABS(DATEDIFF_BIG(second,k.ScanDate,c.cutoff))) AS nearest_seconds
FROM cutoffs c CROSS JOIN dbo.KingdomScanData4 k GROUP BY c.months,c.clock,c.cutoff
UNION ALL
SELECT 'days',v.days,'local',DATEADD(day,-v.days,@local),
SUM(CONVERT(bigint,CASE WHEN ABS(DATEDIFF_BIG(second,k.last_login,DATEADD(day,-v.days,@local)))<=3600 THEN 1 ELSE 0 END)),
MIN(ABS(DATEDIFF_BIG(second,k.last_login,DATEADD(day,-v.days,@local))))
FROM (VALUES (1),(100)) v(days) CROSS JOIN latest k GROUP BY v.days
ORDER BY unit,amount,clock"""
INACTIVE_TIES = """WITH latest AS (
SELECT GovernorID,MAX(ScanDate) AS last_login FROM dbo.KingdomScanData4 GROUP BY GovernorID),
g AS (SELECT l.GovernorID,COUNT_BIG(*) AS row_count,
COUNT(DISTINCT HASHBYTES('SHA2_256',j.payload)) AS payload_variants
FROM latest l JOIN dbo.KingdomScanData4 k
ON k.GovernorID=l.GovernorID AND k.ScanDate=l.last_login
CROSS APPLY (SELECT k.GovernorName,k.Power,k.ScanDate
FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER) j(payload)
GROUP BY l.GovernorID)
SELECT COUNT_BIG(*) AS governors,COALESCE(SUM(CONVERT(bigint,
CASE WHEN row_count>1 THEN 1 ELSE 0 END)),0) AS tied_latest_dates,
COALESCE(SUM(CONVERT(bigint,CASE WHEN payload_variants>1 THEN 1 ELSE 0 END)),0)
AS differing_latest_payloads FROM g"""
QUERY_NAMES = (
    "original_guard",
    "duplicate_summary",
    "duplicate_scans",
    "duplicate_examples",
    "endpoint_ties",
    "date_boundaries",
    "inactive_latest_ties",
)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_latest(value, child, contracts, completed):
    if (
        value.get("outcome") != "failed"
        or value.get("first_failure", {}).get("stage") != "paired actual workload 1 OFF"
        or value.get("completed_setup_reused")
        != "edfd7c226e1ea8824badaa49c83101cb7f9def8140b46d2a8cefebe5cc6e7643"
        or value.get("admin_connections_closed") != 27
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
        or value.get("pairs") != []
        or len(value.get("children", [])) != 1
        or len(value.get("actions", [])) != 12
        or any(a.get("acknowledged") is not True for a in value["actions"])
        or len(value.get("coordinator", [])) != 1
        or value["coordinator"][0].get("operation") != "Verify"
        or value["coordinator"][0].get("settled") is not True
        or value["coordinator"][0].get("acknowledged") is not True
        or value["coordinator"][0].get("result") != completed["coordinator"][-1]["result"]
        or value["before"] != completed["after"]
    ):
        raise ValueError("Exact settled cost attempt and preserved committed setup required")
    c = value["children"][0]
    if (
        c.get("settled") is not True
        or c.get("exit_code") != 1
        or c.get("receipt_sha256") != PINS["cost-evidence/00-OFF-workload/receipt.json"]
        or child.get("first_failure")
        != dict(
            stage="authenticate actual workload",
            error_type="ValueError",
            detail="Source tie or moving date boundary prevents a fair paired workload",
        )
        or child.get("actions") != []
        or len(child.get("cases", [])) != 1
        or child.get("physical_custody_retained") is not False
        or child.get("credential_environment_cleared") is not True
        or child.get("cleanup_failures") != []
        or child.get("contract_evidence_sha256")
        != PINS["cost-evidence/00-OFF-workload/contracts.json"]
        or contracts.get("contracts_passed") is not True
        or child.get("physical_cleanup", {}).get("safe_to_exit") is not True
        or child["physical_cleanup"].get("all_closed_by_callers") is not True
        or child["physical_cleanup"].get("connections")
        != [dict(closed_by_caller=True, cleanup_close=False)] * 2
    ):
        raise ValueError("Exact first workload refusal and closed application handles required")
    case = child["cases"][0]
    if (
        case.get("phase") != "warmup"
        or case.get("mode") != "OFF"
        or case.get("pair") != 1
        or case.get("admin_dispatches") != 1
        or case.get("admin_connections_closed") != 1
        or case.get("actions") != []
        or case.get("cleanup_failures") != []
        or case.get("physical_custody_retained") is not False
        or any(k in case for k in ("clock_before", "source_before", "preparation_id"))
    ):
        raise ValueError("Workload must have stopped at its sole pre-business source read")
    before = deepcopy(value["name_inventory_before"])
    after = value["name_inventory_after"]
    for number in (18, 25, 26):
        transitions = [
            a
            for a in value["name_transitions"]
            if a["database_id"] == number and a["kind"] == "rename"
        ]
        if not transitions or any(a["acknowledged"] is not True for a in transitions):
            raise ValueError("Settled name return required")
        old = next(r for r in before if r["database_id"] == number)
        new = next(r for r in after if r["database_id"] == number)
        last = transitions[-1]
        date = datetime.fromisoformat(new["create_date"])
        if last["to"] != old["name"] or not (
            datetime.fromisoformat(last["before"]) - timedelta(milliseconds=4)
            <= date
            <= datetime.fromisoformat(last["after"]) + timedelta(milliseconds=4)
        ):
            raise ValueError("Acknowledged name/date boundary changed")
        old["create_date"] = new["create_date"]
    if before != after or value["name_inventory_current"] != after:
        raise ValueError("Returned physical identity differs")
    wanted = deepcopy(value["before"])
    for row in wanted["databases"]:
        if row["database_id"] == 18:
            row["create_date"] = next(r["create_date"] for r in after if r["database_id"] == 18)
    if wanted != value["after"]:
        raise ValueError("Original work changed beyond acknowledged name return")


def require_packet(packet, manifest):
    from cost_workload_binding import NAMES

    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or tuple(manifest.get("databases", [])) != NAMES
        or manifest.get("data_directory") != r"S:\P02Cost_20261122130322703"
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
        or any(
            manifest.get(k) != 0
            for k in (
                "business_operations",
                "migrations",
                "renames",
                "restores",
                "backups",
                "provider_operations",
            )
        )
        or manifest.get("enable_application_login") is not False
        or manifest.get("prior_receipt_sha256") != PINS["receipt.json"]
    ):
        raise ValueError("Exact isolated read-only source diagnostic required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed source diagnostic member changed")


def authenticate(packet):
    from cost_execution import require_binding
    import cost_resume

    binding = json.loads((packet / "evidence/cost-binding.json").read_bytes())
    require_binding(binding)
    completed = cost_resume.authenticate(packet, binding)
    values = {}
    for name, digest in PINS.items():
        raw = (PRIOR / name).read_bytes()
        if sha(raw) != digest:
            raise ValueError("Original stopped cost evidence changed")
        values[name] = json.loads(raw)
    if sha((PRIOR / "packet.zip").read_bytes()) != ARCHIVE_SHA:
        raise ValueError("Original stopped cost archive changed")
    latest = values["receipt.json"]
    require_latest(
        latest,
        values["cost-evidence/00-OFF-workload/receipt.json"],
        values["cost-evidence/00-OFF-workload/contracts.json"],
        completed,
    )
    return latest, completed


def run(packet, manifest, latest, completed):
    import cost_fixture_state as preservation
    import cost_resume
    from cost_workload import SOURCE_BOUNDARY
    import cost_workload_binding as binding
    from fresh_business_owner import HELD
    from fresh_business_state import normalized
    from independent_readers import write_new

    from scripts.verify_k98_running_release import sql_error_facts

    record = dict(
        outcome="running",
        stage="verify preserved work before source reads",
        first_failure=None,
        cleanup_failures=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        actions=[],
        original_preserved=False,
        login_disabled=None,
        physical_custody_retained=False,
        business_operations=0,
        migrations=0,
        renames=0,
        restores=0,
        backups=0,
        provider_operations=0,
        login_enable_attempted=False,
        measured_cost_accepted=False,
        source_diagnostics=[],
        prior_receipt_sha256=PINS["receipt.json"],
    )

    def save():
        p = packet / "progress.pending"
        p.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        p.replace(packet / "progress.json")

    before = None
    write_new(packet / "entered.json", dict(pid=os.getpid(), purpose=PURPOSE))
    try:
        expected, source = preservation.context(packet, manifest)
        expected = cost_resume.preservation_context(expected, latest)
        bindings = json.loads((packet / "evidence/cost-ready/restore-bindings.json").read_bytes())[
            "fixtures"
        ]

        def observe():
            value = preservation.observe(
                packet, manifest, "after", record, save, expected, source, bindings
            )
            if value != latest["after"] or record["new_fixtures"] != latest["new_fixtures"]:
                raise ValueError("Completed original work or restricted copy identity changed")
            return value

        record["before"] = observe()
        before = record["before"]
        deadline = time.monotonic() + 120
        # One shared clock pair makes date-window differences between copies assessable.
        clocks = None
        for index, name in enumerate(binding.NAMES):
            item = dict(database=name, mode=("OFF", "ON")[index], queries={}, query_seconds={})
            record["source_diagnostics"].append(item)
            with binding.owned_copy(name, record, save) as owner:
                owner.connection.timeout = 15
                if clocks is None:
                    clocks = owner.read(CLOCKS)[0]
                    record["clock"] = clocks
                utc = clocks["utc_now"].isoformat(timespec="microseconds")
                local = clocks["local_now"].isoformat(timespec="microseconds")
                queries = [
                    ("source", binding.QUERIES["source"], ()),
                    ("summary_cursors", binding.QUERIES["summary_cursors"], ()),
                    ("history", cost_resume.HISTORY, ()),
                    ("sequence", cost_resume.SEQUENCE, ()),
                    ("original_guard", SOURCE_BOUNDARY, ()),
                    ("duplicate_summary", DUPLICATES, ()),
                    ("duplicate_scans", DUPLICATE_SCANS, ()),
                    ("duplicate_examples", DUPLICATE_EXAMPLES, ()),
                    ("endpoint_ties", ENDPOINT_TIES, (utc,)),
                    ("date_boundaries", DATE_BOUNDARIES, (utc, local)),
                    ("inactive_latest_ties", INACTIVE_TIES, ()),
                ]
                for label, sql, parameters in queries:
                    if time.monotonic() >= deadline:
                        raise TimeoutError("Bounded source diagnostic deadline reached")
                    record["stage"] = f"read {item['mode']} {label}"
                    save()
                    start = time.monotonic()
                    rows = owner.read(sql, *parameters)
                    item["queries"][label] = rows
                    item["query_seconds"][label] = time.monotonic() - start
                    save()  # Keep the refusal's raw inputs, including partial groups.
                    if label in ("source", "summary_cursors"):
                        if normalized(rows) != latest["workload_copies"][index]["queries"][label]:
                            raise ValueError("Unstarted source or summary cursor changed")
                    elif label == "history":
                        previous = json.loads(
                            (packet / "evidence/cost-ready/guest-receipt.json").read_bytes()
                        )
                        cost_resume.require_history(
                            rows, previous["fixtures"][index]["history"], item["mode"], completed
                        )
                    elif label == "sequence":
                        cost_resume.require_sequence(rows, item["mode"], completed)
        a, b = record["source_diagnostics"]
        record["diagnostic_differences"] = [
            k for k in QUERY_NAMES if normalized(a["queries"][k]) != normalized(b["queries"][k])
        ]
        record["outcome"] = (
            "passed" if not record["diagnostic_differences"] else "diagnostic_copies_differ"
        )
        record["stage"] = "source refusal diagnosed; no workload admitted"
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, (ValueError, TimeoutError)):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        if before is not None and not HELD:
            try:
                record["after"] = observe()
                record.update(original_preserved=True, login_disabled=True)
            except BaseException as error:
                record["preservation_failure"] = sql_error_facts(error)
                record["outcome"] = "failed"
        record["physical_custody_retained"] = bool(HELD)
        if HELD or record["cleanup_failures"]:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        save()
        try:
            write_new(packet / "receipt.json", record)
        finally:
            while HELD:
                time.sleep(1)
    return 0 if record["outcome"] in ("passed", "diagnostic_copies_differ") else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    require_packet(packet, manifest)
    latest, completed = authenticate(packet)
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    return run(packet, manifest, latest, completed)


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(main())
