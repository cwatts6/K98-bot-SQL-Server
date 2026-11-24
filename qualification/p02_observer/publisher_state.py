"""Source-defined publication deltas; preserve all completed maintenance and captures."""

from collections import defaultdict
import json
from pathlib import Path

from independent_readers import sha
from recovery_coexistence import inventory
from remaining_actors import canonical, generation, require_headroom

PRIOR = Path("Q:/P02Observer/20261122102414728")
RECEIPT_SHA = "5d512313325815c1dd132d229c8adb9db3082261b885e7b026e9d2dd663e91f3"
ARCHIVE_SHA = "59ad746c7e9e18ae04cecfbec87647143ec294056c8284ccecc73892fb9f84ca"
HEADER_SQL = "SELECT * FROM dbo.KVKFinalReportHeader ORDER BY KVK_NO"
OUTPUT_SQL = "SELECT * FROM dbo.EXCEL_FOR_KVK_16 ORDER BY Gov_ID"
OBJECT_SQL = "SELECT object_id,create_date FROM sys.tables WHERE schema_id=SCHEMA_ID('dbo') AND name=N'EXCEL_FOR_KVK_16'"


def authenticate(packet):
    raw = (packet / "evidence/publisher-baseline.json").read_bytes()
    if (
        sha(raw) != RECEIPT_SHA
        or raw != (PRIOR / "receipt.json").read_bytes()
        or sha((PRIOR / "packet.zip").read_bytes()) != ARCHIVE_SHA
    ):
        raise ValueError("Exact completed publisher inventory required")
    value = json.loads(raw)
    wanted = dict(
        outcome="passed",
        first_failure=None,
        cleanup_failures=[],
        original_preserved=True,
        login_disabled=True,
        login_enable_attempted=False,
        physical_custody_retained=False,
        business_operations=0,
        maintenance_dispatches=0,
    )
    if any(value.get(k) != v for k, v in wanted.items()) or value["before"] != value["after"]:
        raise ValueError("Settled unchanged publisher baseline required")
    return value


def read(admin):
    from producer_fixture import REPORT_VALUE_SQL

    value = inventory(admin)
    value.update(
        headers=admin.read(HEADER_SQL),
        output=admin.read(OUTPUT_SQL),
        incarnation=admin.read(OBJECT_SQL),
        report=admin.read(REPORT_VALUE_SQL),
        generation=generation(admin),
    )
    return canonical(value)


def require_delta(before, after, index):
    require_headroom(after)
    if (
        index not in (1, 2, 3)
        or len(after["incarnation"]) != 1
        or after["incarnation"] == before["incarnation"]
    ):
        raise ValueError("One new output incarnation required")
    if after["generation"] <= before["generation"]:
        raise ValueError("Publication must advance catalogue generation")
    if after["stats"] != before["stats"] or after["report"] != before["report"]:
        raise ValueError("Completed report or maintenance statistics changed")
    old = {r["KVK_NO"]: r for r in before["headers"]}
    new = {r["KVK_NO"]: r for r in after["headers"]}
    if set(new) != set(old) or any(new[k] != old[k] for k in new if k != 16):
        raise ValueError("Another final report changed")
    h = new[16]
    wanted = dict(
        KVK_NO=16,
        FinalScanOrder=1193,
        OutputRowCount=414,
        Revision=537 + index,
        State="OUTPUT_COMPLETE",
        FinalizationBasis="LIVE_OUTPUT",
    )
    if (
        any(h.get(k) != v for k, v in wanted.items())
        or not h["FinalDataAtUtc"]
        or h["FinalDataAtUtc"] < old[16]["FinalDataAtUtc"]
    ):
        raise ValueError("Exact durable publication receipt required")
    rows = after["output"]
    if (
        len(rows) != 414
        or len({r["Gov_ID"] for r in rows}) != 414
        or any(r["KVK_NO"] != 16 for r in rows)
    ):
        raise ValueError("Full output identity/count differs from source window")
    require_rank_intervals(rows)
    if index > 1:
        require_same_values(before["output"], rows)
    oldwork = {r["Kind"]: r for r in before["work"]}
    newwork = {r["Kind"]: r for r in after["work"]}
    if set(oldwork) != set(newwork) or any(
        newwork[k] != oldwork[k] for k in newwork if k != "kvk_output"
    ):
        raise ValueError("Completed maintenance changed")
    allowed = {"DueGeneration", "DueUTC", "LastRequestID", "State"}
    row = newwork["kvk_output"]
    oldrow = oldwork["kvk_output"]
    if (
        row["DueGeneration"] != index
        or row["CompletedGeneration"] != 0
        or row["State"] != "pending"
        or row["LastRequestID"] is not None
        or not row["DueUTC"]
        or {k: v for k, v in row.items() if k not in allowed}
        != {k: v for k, v in oldrow.items() if k not in allowed}
    ):
        raise ValueError("Only one new coalesced KVK demand is allowed")
    if (
        len(after["kvk"]) != 1
        or (index == 1 and before["kvk"])
        or (index > 1 and len(before["kvk"]) != 1)
    ):
        raise ValueError("One coalesced KVK output row required")
    row = after["kvk"][0]
    identity = after["incarnation"][0]
    wanted = dict(
        KVKNo=16,
        DueGeneration=index,
        CompletedGeneration=0,
        DueObjectID=identity["object_id"],
        DueObjectCreateDate=identity["create_date"],
        DueHeaderRevision=537 + index,
        State="pending",
    )
    if any(row.get(k) != v for k, v in wanted.items()) or any(
        v is not None for k, v in row.items() if k not in wanted
    ):
        raise ValueError(
            "New pending upkeep must bind exact output/header without claims or errors"
        )


def require_post_observation(observed, state):
    proof = observed["application"]["maintenance_lifecycle"]["outputs"]
    rows = [r for r in proof if r["ObjectName"] == "dbo.EXCEL_FOR_KVK_16"]
    if len(rows) != 1:
        raise ValueError("Complete source-bound KVK lifecycle proof required")
    row = rows[0]
    identity = state["incarnation"][0]
    work = state["kvk"][0]
    wanted = dict(
        ObjectID=identity["object_id"],
        DueObjectID=identity["object_id"],
        HeaderRevision=work["DueHeaderRevision"],
        DueHeaderRevision=work["DueHeaderRevision"],
        DueGeneration=work["DueGeneration"],
        AggregateDue=work["DueGeneration"],
        CompletedGeneration=0,
        AggregateCompleted=0,
        State="pending",
        AggregateState="pending",
        HeaderState="OUTPUT_COMPLETE",
    )
    if (
        any(row.get(k) != v for k, v in wanted.items())
        or observed["application_observation"]["generation"] != state["generation"]
    ):
        raise ValueError("Fresh comparator did not observe the exact new pending publication")


def require_rank_intervals(rows):
    """The actual publisher rounds DKP to an integer then ROW_NUMBERs DESC.

    No tie-breaker is present in the source. Require every rank exactly once
    in its score's complete interval; never discard ranks from validation.
    """
    groups = defaultdict(list)
    for row in rows:
        score, rank = row["DKP_SCORE"], row["KVK_RANK"]
        if type(score) is not int or type(rank) is not int:
            raise ValueError("Exact integer score/rank required for this fixture")
        groups[score].append(rank)
    position = 1
    for score in sorted(groups, reverse=True):
        ranks = groups[score]
        if sorted(ranks) != list(range(position, position + len(ranks))):
            raise ValueError("Rank assignment crosses scores or has duplicate/missing ranks")
        position += len(ranks)


def require_same_values(before, after):
    require_rank_intervals(before)
    require_rank_intervals(after)

    def values(rows):
        result = {r["Gov_ID"]: {k: v for k, v in r.items() if k != "KVK_RANK"} for r in rows}
        if len(result) != len(rows):
            raise ValueError("Duplicate output identity")
        return result

    if values(before) != values(after):
        raise ValueError("Unchanged source inputs produced different non-tie values")
