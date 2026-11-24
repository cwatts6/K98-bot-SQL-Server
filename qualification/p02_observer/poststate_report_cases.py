"""Real player-report captures across allowed index states; legacy KVK stays separate."""

import json

from poststate_cases import add_index, capture_facts, index_state, verify_old_captures

REPORT_SOURCE = """WITH latest AS (
 SELECT MAX(SCANORDER) AS scan FROM dbo.KingdomScanData4
), eligible AS (
 SELECT TOP (1) p.KVKVersion FROM dbo.ProcConfig p CROSS JOIN latest l
 WHERE p.ConfigKey='MATCHMAKING_SCAN'
 AND TRY_CONVERT(int,p.ConfigValue) IS NOT NULL
 AND p.ConfigValue=CONVERT(float,TRY_CONVERT(int,p.ConfigValue))
 AND TRY_CONVERT(int,p.ConfigValue)<=l.scan ORDER BY p.KVKVersion DESC
), bounds AS (
 SELECT l.scan AS latest_scan,(SELECT KVKVersion FROM eligible) AS selected_kvk,
 e.end_scan,CASE WHEN e.end_scan>0 AND e.end_value=CONVERT(float,e.end_scan)
 THEN CASE WHEN l.scan>e.end_scan THEN e.end_scan ELSE l.scan END END AS final_scan
 FROM latest l OUTER APPLY (
  SELECT ConfigValue AS end_value,TRY_CONVERT(int,ConfigValue) AS end_scan
  FROM dbo.ProcConfig
  WHERE KVKVersion=(SELECT KVKVersion FROM eligible) AND ConfigKey='KVK_END_SCAN'
 ) e
)
SELECT b.latest_scan,b.selected_kvk,b.end_scan,b.final_scan,
 (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4 WHERE SCANORDER=1244)
 AS publisher_source_rows,
 (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4 WHERE SCANORDER=b.final_scan)
 AS report_source_rows FROM bounds b"""
LEGACY_SIZE = """SELECT SUM(p.row_count) AS rows
FROM sys.dm_db_partition_stats p
WHERE p.object_id=OBJECT_ID(N'KVK.KVK_AllPlayers_Raw') AND p.index_id IN (0,1)"""
LEGACY_CENSUS = """WITH seasons AS (
 SELECT KVK_NO FROM KVK.KVK_Scan UNION SELECT KVK_NO FROM KVK.SeasonSource
 UNION SELECT KVK_NO FROM KVK.KVK_Windows
)
SELECT s.KVK_NO,c.SourceKey,c.SeasonState,c.SeasonVersion,
 (SELECT COUNT_BIG(*) FROM KVK.KVK_Scan x WHERE x.KVK_NO=s.KVK_NO) AS scans,
 (SELECT COUNT_BIG(*) FROM KVK.KVK_AllPlayers_Raw x WHERE x.KVK_NO=s.KVK_NO) AS raw_rows,
 (SELECT COUNT_BIG(*) FROM KVK.KVK_Player_Baseline x WHERE x.KVK_NO=s.KVK_NO) AS baselines,
 (SELECT COUNT_BIG(*) FROM KVK.KVK_DKPWeights x WHERE x.KVK_NO=s.KVK_NO) AS weights,
 (SELECT COUNT_BIG(*) FROM KVK.KVK_Windows x WHERE x.KVK_NO=s.KVK_NO) AS windows
FROM seasons s LEFT JOIN KVK.SeasonSource c ON c.KVK_NO=s.KVK_NO ORDER BY s.KVK_NO"""


def require_report_source(rows):
    expected = dict(latest_scan=1244, selected_kvk=16, end_scan=1193, final_scan=1193)
    counts = ("publisher_source_rows", "report_source_rows")
    if len(rows) != 1 or set(rows[0]) != set(expected) | set(counts):
        raise ValueError("Exact genuine report source prerequisite required")
    row = rows[0]
    for key, value in row.items():
        if type(value) is not int:
            raise ValueError(f"Report source {key} requires a native integer")
    for key, value in expected.items():
        if row[key] != value:
            raise ValueError(f"Report source {key}: expected {value}, observed {row[key]}")
    for key in counts:
        if not 0 < row[key] <= 250000:
            raise ValueError(f"Report source {key}: nonempty bounded source required")


def prerequisites(owner, record, save):
    result = dict(stage="report source observation")
    record["source_prerequisites"] = result
    result["report_source"] = owner.read(REPORT_SOURCE)
    result["report_source_types"] = [
        {key: type(value).__name__ for key, value in row.items()} for row in result["report_source"]
    ]
    save()
    require_report_source(result["report_source"])
    result["stage"] = "legacy source inventory"
    result["legacy_size"] = owner.read(LEGACY_SIZE)
    save()
    size = result["legacy_size"]
    if len(size) != 1 or type(size[0].get("rows")) is not int or size[0]["rows"] < 0:
        raise ValueError("Legacy source inventory size is unavailable")
    if size[0]["rows"] <= 1000000:
        result["legacy_census"] = owner.read(LEGACY_CENSUS)
        result["legacy_census_status"] = "read_only_counts_not_admission_or_capture"
    else:
        result["legacy_census"] = []
        result["legacy_census_status"] = "not_read_source_exceeds_bounded_inventory"
    result["stage"] = "complete prerequisites observed"
    save()
    return result


def report_capture(packet, manifest, bound, connections, record, save, previous):
    import cost_workload as work

    work.report(packet, manifest, bound, connections, record, save, "ON")
    rt = work.runtime(packet, manifest, bound, connections)
    capture = capture_facts(rt, record["preparation_id"])
    if (
        capture["consumer"] != "scan_data"
        or capture["row_count"] <= 0
        or not record.get("writer_closed")
        or capture["preparation_id"] in {c["preparation_id"] for c in previous}
    ):
        raise ValueError("One fresh nonempty closed report capture is required")
    if previous and any(
        capture[key] != previous[0][key]
        for key in ("sections_sha256", "section_count", "row_count")
    ):
        raise ValueError("Full report output changed across the permitted index states")
    verify_old_captures(rt, previous)
    record["capture"] = capture
    save()
    return capture


def run(packet, manifest, record, save, connections):
    import cost_workload as work
    from fresh_business_state import IDENTITY, require_identity
    from independent_readers import write_new
    from poststate_owner import owned
    import poststate_publisher

    if manifest.get("continuation") == "captured-index-diagnosed-20261123170039650":
        return resume(packet, manifest, record, save, connections)

    with owned("ROK_TRACKER", record, save, timeout=15) as owner:
        require_identity(owner.read(IDENTITY), "ROK_TRACKER", 27)
        prerequisites(owner, record, save)
    initial = {}
    try:
        work.contracts(packet, manifest, "ON", initial, connections)
    finally:
        write_new(packet / "chain-initial-contracts.json", initial)
    record["stage"] = "one fresh legacy publication for the zero-index state"
    save()
    record["publication"] = poststate_publisher.run(packet, manifest, record, save)
    captures = []
    record["cases"] = []
    for count in (0, 1, 2):
        case = dict(index_count=count, outcome="running")
        record["cases"].append(case)
        record["stage"] = (
            "complete comparator and new report capture with " + str(count) + " indexes"
        )
        save()
        if count:
            add_index(record, save, count)
        case["indexes_before"] = index_state(record, save, count)
        evidence = {}
        try:
            bound = work.contracts(packet, manifest, "ON", evidence, connections)
        finally:
            write_new(packet / ("chain-contracts-" + str(count) + ".json"), evidence)
        case["full_comparator_passed"] = True
        captures.append(report_capture(packet, manifest, bound, connections, case, save, captures))
        case["indexes_after"] = index_state(record, save, count)
        case["outcome"] = "passed"
        save()
    record["stage"] = "next actual report writer after the two-index capture"
    save()
    next_writer = {}
    record["next_writer"] = next_writer
    captures.append(
        report_capture(packet, manifest, bound, connections, next_writer, save, captures)
    )
    index_state(record, save, 2)
    record.update(
        captures=captures,
        actual_kvk_recomputes=0,
        actual_report_writes=4,
        actual_legacy_publications=1,
        legacy_kvk_capture_qualified=False,
        full_startup_runtime_qualified=False,
        provider_operations=0,
    )
    write_new(packet / "chain-captures.json", captures)
    write_new(packet / "chain-bound-contracts.json", bound)
    save()


def consume(packet, manifest, record, save, connections):
    import cost_workload as work
    from independent_readers import write_new

    captures = json.loads((packet / "chain-captures.json").read_bytes())
    if (
        len(captures) != 4
        or any(c["consumer"] != "scan_data" or c["row_count"] <= 0 for c in captures)
        or len({c["preparation_id"] for c in captures}) != 4
        or len({c["sections_sha256"] for c in captures}) != 1
    ):
        raise ValueError("Exactly four distinct equal-content report captures are required")
    evidence = {}
    try:
        bound = work.contracts(packet, manifest, "ON", evidence, connections)
    finally:
        write_new(packet / "chain-consumer-contracts.json", evidence)
    rt = work.runtime(packet, manifest, bound, connections)
    verify_old_captures(rt, captures)
    if rt.resolve_preparation(consumer="scan_data") != captures[-1]["preparation_id"]:
        raise ValueError("Fresh consuming process selected an incorrect report generation")
    index_state(record, save, 2)
    record.update(
        full_comparator_passed=True,
        captures_verified=[c["preparation_id"] for c in captures],
        legacy_kvk_capture_qualified=False,
        full_startup_runtime_qualified=False,
        provider_operations=0,
        business_operations=0,
        export_jobs_created=0,
    )
    save()


def resume(packet, manifest, record, save, connections):
    """Keep the published zero-index capture; run only its unstarted successors."""
    import cost_workload as work
    from independent_readers import write_new
    from poststate_captured import authenticate

    retained = authenticate(packet, manifest)
    capture = retained["capture"]
    captures = [capture]
    record.update(
        cases=[],
        retained_case=retained["captured_case"],
        retained_publication=retained["publication"],
        publication_replayed=False,
        zero_index_capture_replayed=False,
    )
    for count in (1, 2):
        case = dict(index_count=count, outcome="running")
        record["cases"].append(case)
        record["stage"] = (
            "remaining comparator and new report capture with " + str(count) + " indexes"
        )
        save()
        add_index(record, save, count)
        case["indexes_before"] = index_state(record, save, count)
        evidence = {}
        try:
            bound = work.contracts(packet, manifest, "ON", evidence, connections)
        finally:
            write_new(packet / ("chain-contracts-" + str(count) + ".json"), evidence)
        case["full_comparator_passed"] = True
        rt = work.runtime(packet, manifest, bound, connections)
        verify_old_captures(rt, captures)
        captures.append(report_capture(packet, manifest, bound, connections, case, save, captures))
        case["indexes_after"] = index_state(record, save, count)
        case["outcome"] = "passed"
        save()
    record["stage"] = "next actual report writer after the two-index capture"
    next_writer = {}
    record["next_writer"] = next_writer
    save()
    captures.append(
        report_capture(packet, manifest, bound, connections, next_writer, save, captures)
    )
    index_state(record, save, 2)
    record.update(
        captures=captures,
        actual_kvk_recomputes=0,
        actual_report_writes=3,
        actual_legacy_publications=0,
        retained_captures=1,
        new_captures=3,
        legacy_kvk_capture_qualified=False,
        full_startup_runtime_qualified=False,
        provider_operations=0,
    )
    write_new(packet / "chain-captures.json", captures)
    write_new(packet / "chain-bound-contracts.json", bound)
    save()
