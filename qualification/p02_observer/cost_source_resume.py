"""Resume unstarted cost work after the exact settled source diagnosis.

A historical clock check explains the retained refusal. Fresh guards remain
mandatory before any new workload. This is qualification, not production policy.
"""

from datetime import datetime
import hashlib
import json
from pathlib import Path

PRIOR = Path(r"Q:\P02Observer\20261122174532709")
RECEIPT_SHA = "bbd4b95dab26eae5da9166f63471bfd3b3f5f36a8bf77861b592955d3da1bf2f"
ARCHIVE_SHA = "38d65445c8acf21f4c18d8dda88db95161db6da8525d9dc2e7a2d5ac93e83c8f"
STOP_SHA = "194f4329f2bbc9340be5b8132b2080786eecc020e66aff684dca6fda8633a79d"
REFUSAL_UTC = "2026-11-22T17:29:24.939400"
HISTORICAL_WINDOWS = """DECLARE @utc datetime2=CONVERT(datetime2,?,126);
SELECT v.months,@utc AS original_utc,DATEADD(month,-v.months,@utc) AS cutoff,
d.rows_within_hour,d.first_source_date,d.last_source_date
FROM (VALUES(3),(6),(12)) v(months)
CROSS APPLY (SELECT COUNT_BIG(*) AS rows_within_hour,MIN(ScanDate) AS first_source_date,
MAX(ScanDate) AS last_source_date FROM dbo.KingdomScanData4
WHERE ABS(DATEDIFF_BIG(second,ScanDate,DATEADD(month,-v.months,@utc)))<=3600) d
ORDER BY v.months"""


def require_diagnostic(value, latest):
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("preservation_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("admin_connections_closed") != 14
        or value.get("actions") != []
        or value.get("original_preserved") is not True
        or value.get("login_disabled") is not True
        or value.get("physical_custody_retained") is not False
        or value.get("login_enable_attempted") is not False
        or value.get("measured_cost_accepted") is not False
        or value.get("prior_receipt_sha256") != STOP_SHA
        or value.get("before") != latest["after"]
        or value.get("after") != latest["after"]
        or value.get("new_fixtures") != latest["new_fixtures"]
        or value.get("diagnostic_differences") != []
        or len(value.get("source_diagnostics", [])) != 2
        or any(
            value.get(k) != 0
            for k in (
                "business_operations",
                "migrations",
                "renames",
                "restores",
                "backups",
                "provider_operations",
            )
        )
    ):
        raise ValueError("Exact settled read-only diagnostic and unchanged original work required")
    from cost_source_diagnostic import QUERY_NAMES
    from cost_workload_binding import NAMES

    for index, copy in enumerate(value["source_diagnostics"]):
        q = copy["queries"]
        if (
            copy["database"] != NAMES[index]
            or copy["mode"] != ("OFF", "ON")[index]
            or q["original_guard"] != [dict(ambiguous=0)]
            or q["duplicate_summary"][0]["duplicate_groups"] != 0
            or q["duplicate_summary"][0]["excess_rows"] != 0
            or q["duplicate_scans"] != []
            or q["duplicate_examples"] != []
            or len(q["date_boundaries"]) != 8
            or any(r["rows_within_hour"] != 0 for r in q["date_boundaries"])
            or len(q["inactive_latest_ties"]) != 1
            or q["inactive_latest_ties"][0]["differing_latest_payloads"] != 0
        ):
            raise ValueError("Recorded source diagnosis differs")
    left, right = value["source_diagnostics"]
    if any(left["queries"][k] != right["queries"][k] for k in QUERY_NAMES):
        raise ValueError("Recorded complete diagnostic copies differ")


def authenticate(packet):
    import cost_source_diagnostic as source

    latest, completed = source.authenticate(packet)
    raw = (PRIOR / "receipt.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RECEIPT_SHA
        or hashlib.sha256((PRIOR / "packet.zip").read_bytes()).hexdigest() != ARCHIVE_SHA
    ):
        raise ValueError("Immutable completed source diagnostic changed")
    value = json.loads(raw)
    require_diagnostic(value, latest)
    return completed, latest, value


def check_source(owner, case, save):
    """Save each raw input before refusing; do not admit from old diagnostic values."""
    import cost_source_diagnostic as source
    from cost_workload import SOURCE_BOUNDARY

    value = {}
    case["source_eligibility"] = value
    value["clock"] = owner.read(source.CLOCKS)[0]
    save()
    value["original_guard"] = owner.read(SOURCE_BOUNDARY)
    save()
    if value["original_guard"] != [dict(ambiguous=0)]:
        raise ValueError("Source tie or moving date boundary prevents a fair paired workload")
    clock = value["clock"]
    value["date_boundaries"] = owner.read(
        source.DATE_BOUNDARIES,
        clock["utc_now"].isoformat(timespec="microseconds"),
        clock["local_now"].isoformat(timespec="microseconds"),
    )
    save()
    expected = {
        ("days", 1, "local"),
        ("days", 100, "local"),
        *(("months", n, kind) for n in (3, 6, 12) for kind in ("utc", "local")),
    }
    rows = value["date_boundaries"]
    if (
        len(rows) != 8
        or {(r["unit"], r["amount"], r["clock"]) for r in rows} != expected
        or any(
            r["rows_within_hour"] != 0
            or r["nearest_seconds"] is None
            or r["nearest_seconds"] <= 3600
            for r in rows
        )
    ):
        raise ValueError("Current month or inactivity date boundary prevents fair paired work")
    value["inactive_latest_ties"] = owner.read(source.INACTIVE_TIES)
    save()
    rows = value["inactive_latest_ties"]
    if len(rows) != 1 or rows[0]["governors"] != 2448 or rows[0]["differing_latest_payloads"] != 0:
        raise ValueError("Current inactivity latest-row payload is ambiguous")
    value["passed"] = True
    save()


def preflight(record, save):
    from cost_workload_binding import NAMES, owned_copy

    record["source_preflight"] = []
    for name in NAMES:
        record["stage"] = "verify original and current source windows " + name
        item = dict(database=name)
        record["source_preflight"].append(item)
        save()
        with owned_copy(name, record, save) as owner:
            rows = owner.read(HISTORICAL_WINDOWS, REFUSAL_UTC)
            item["original_refusal_windows"] = rows
            save()
            if (
                [r["months"] for r in rows] != [3, 6, 12]
                or any(r["original_utc"] != datetime.fromisoformat(REFUSAL_UTC) for r in rows)
                or not any(r["rows_within_hour"] > 0 for r in rows)
            ):
                raise ValueError(
                    "Original source refusal is not explained by the recorded UTC window"
                )
            check_source(owner, item, save)
    a, b = record["source_preflight"]
    if a["original_refusal_windows"] != b["original_refusal_windows"]:
        raise ValueError("Original source-window diagnosis differs between copies")
