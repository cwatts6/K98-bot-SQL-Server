"""Exact six-row cost-fixture statistics preparation; no business replay."""

from copy import deepcopy
import hashlib
import json
from pathlib import Path

PRIOR = Path(r"Q:\P02Observer\20261122183003323")
RECEIPT_SHA = "9b438453b416d66d4cfb96aaa88d45d2fb0b850f06441cbf72b606a8a8d189ac"
ARCHIVE_SHA = "80e7ba65587daf900c152321871ac784b74ca43a1c24e4dbd7b13ee984a00264"
HOST_LAUNCH_SHA = "b4aeb5ac731462bacab2be3a2b5cfc0820b767c96ea2cbc0d58a39256b2983f8"
ENTRY_FAILED = Path(r"Q:\P02Observer\20261122191637500")
ENTRY_ARCHIVE_SHA = "e4ce3d5096e33a3274ba51fdd41a0115081e3399fc72a1eaa964d18335a1b9d0"
ENTRY_STDERR_SHA = "57772d414665a58184770577d533015cf2295f042fc16c4bdcea32a079582bd0"
ENTRY_LAUNCH_SHA = "744a0b4e2afcdd90036231b762d1582a2012ffa46928608586f7b4256f2ab3cc"
KEY = ("dbo", "MaintenanceWork", 1)
SAMPLED = dict(
    rows=6,
    rows_sampled=6,
    steps=6,
    unfiltered_rows=6,
    modification_counter=0,
    persisted_sample_percent=0.0,
)
PREPARE = """SET XACT_ABORT ON;
IF NOT ((DB_ID()=25 AND DB_NAME()=N'K98_P02Cost_OFF_20261122130322703')
 OR (DB_ID()=26 AND DB_NAME()=N'K98_P02Cost_ON_20261122130322703'))
 OR @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
 THROW 51976,'Exact restricted cost statistics owner required.',1;
IF (SELECT user_access_desc FROM sys.databases WHERE database_id=DB_ID())<>N'RESTRICTED_USER'
 OR (SELECT COUNT_BIG(*) FROM dbo.MaintenanceWork)<>6
 OR NOT EXISTS(SELECT 1 FROM sys.stats WHERE object_id=OBJECT_ID(N'dbo.MaintenanceWork')
 AND stats_id=1 AND name=N'PK_MaintenanceWork')
 THROW 51976,'Exact six-row declared statistic required.',1;
UPDATE STATISTICS dbo.MaintenanceWork PK_MaintenanceWork WITH FULLSCAN;"""
SETTLED = """SELECT @@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state,
APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session') AS session_marker"""


def key(row):
    return row["schema_name"], row["table_name"], row["stats_id"]


def inventory(raw):
    from cost_readiness import CURRENT_STATISTICS

    if len(raw) != 1:
        raise ValueError("One complete statistics inventory required")
    value = raw[0]
    text = value["statistics_json"]
    rows = json.loads(text)
    if (
        value["statistics_count"] != CURRENT_STATISTICS[0]["statistics_count"]
        or len(rows) != value["statistics_count"]
        or len({key(r) for r in rows}) != len(rows)
        or value["json_bytes"] != len(text.encode("utf-16-le"))
        or not 0 < value["json_bytes"] <= 4 * 1024**2
    ):
        raise ValueError("Complete bounded statistics inventory differs")
    return rows


def business(rows):
    from cost_resume import HISTORY_TABLES

    return [
        {k: v for k, v in r.items() if k != "last_updated"}
        for r in rows
        if not (r["schema_name"] == "dbo" and r["table_name"] in HISTORY_TABLES)
    ]


def require_known_delta(stopped, completed):
    """Only the recorded initial population of this one OFF PK is explained."""
    for index in (0, 1):
        current = inventory(stopped["statistics_observations"][index])
        old = inventory(completed["statistics_observations"][index])
        target = next(r for r in old if key(r) == KEY)
        if (
            target["statistics_name"] != "PK_MaintenanceWork"
            or target["columns"] != [dict(stats_column_id=1, column_id=1, name="Kind")]
            or any(target[k] is not None for k in (*SAMPLED, "last_updated"))
        ):
            raise ValueError("Exact initially unpopulated six-row PK required")
        expected = deepcopy(old)
        if index == 0:
            t = next(r for r in expected if key(r) == KEY)
            t.update(SAMPLED)
        if business(current) != business(expected):
            raise ValueError("Unexplained non-ledger statistics change; no preparation admitted")
    if business(inventory(stopped["statistics_observations"][0])) == business(
        inventory(stopped["statistics_observations"][1])
    ):
        raise ValueError("Recorded mismatch must remain retained, not silently accepted")


def require_stopped(value, latest, completed):
    if (
        value.get("outcome") != "failed"
        or value.get("first_failure")
        != dict(
            stage="authenticate completed work and bind fresh cost ownership",
            error_type="ValueError",
            detail="Unstarted non-ledger statistics workload changed",
        )
        or value.get("before") != latest["after"]
        or value.get("after") != latest["after"]
        or value.get("new_fixtures") != latest["new_fixtures"]
        or value.get("admin_connections_closed") != 14
        or value.get("original_preserved") is not True
        or value.get("login_disabled") is not True
        or any(
            value.get(k) is not False
            for k in (
                "original_name_restored",
                "physical_custody_retained",
                "name_transition_uncertain",
                "measured_cost_accepted",
                "prior_migrations_replayed",
            )
        )
        or value.get("restores") != 0
        or value.get("provider_operations") != 0
        or any(
            value.get(k) != []
            for k in ("actions", "children", "coordinator", "pairs", "cleanup_failures")
        )
        or value.get("readiness_differences") != [[], []]
        or any(
            k in value
            for k in ("private_spool", "source_preflight", "preservation_failure", "cost")
        )
    ):
        raise ValueError("Exact settled statistics refusal before any operation required")
    require_known_delta(value, completed)


def host_launch(packet, relative, digest, pid, guest):
    # The host writes this after receiving the child's result. It does not exist
    # in the old guest directory; transport its immutable bytes in the new seal.
    raw = (packet / relative).read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError("Authenticated host launch record changed")
    value = json.loads(raw)
    if (
        value.get("state") != "exited"
        or value.get("exitCode") != 1
        or value.get("pid") != pid
        or value.get("path") != str(guest)
        or value.get("PSComputerName") != "K98-MGE-Qualification-20261029"
    ):
        raise ValueError("Exact settled failed host launch required")
    return value


def authenticate_entry_failure(packet):
    host_launch(
        packet,
        "evidence/cost-entry-failed/launch-result.json",
        ENTRY_LAUNCH_SHA,
        3708,
        ENTRY_FAILED,
    )
    raw = (ENTRY_FAILED / "stderr.txt").read_bytes()
    if (
        hashlib.sha256((ENTRY_FAILED / "packet.zip").read_bytes()).hexdigest() != ENTRY_ARCHIVE_SHA
        or hashlib.sha256(raw).hexdigest() != ENTRY_STDERR_SHA
        or raw != (packet / "evidence/cost-entry-failed/stderr.txt").read_bytes()
        or (ENTRY_FAILED / "stdout.txt").read_bytes()
        or any(
            (ENTRY_FAILED / name).exists()
            for name in (
                "entered.json",
                "progress.json",
                "receipt.json",
                "cost-evidence",
                "Status.stdout.txt",
                "Preflight.stdout.txt",
                "Apply.stdout.txt",
                "Verify.stdout.txt",
            )
        )
    ):
        raise ValueError("Original entry failure changed or reached a later stage")


def authenticate(packet):
    import cost_source_resume

    authenticate_entry_failure(packet)
    completed, latest, diagnostic = cost_source_resume.authenticate(packet)
    raw = (PRIOR / "receipt.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RECEIPT_SHA
        or hashlib.sha256((PRIOR / "packet.zip").read_bytes()).hexdigest() != ARCHIVE_SHA
    ):
        raise ValueError("Original statistics refusal evidence changed")
    value = json.loads(raw)
    require_stopped(value, latest, completed)
    host_launch(
        packet, "evidence/cost-statistics-refusal/launch-result.json", HOST_LAUNCH_SHA, 5568, PRIOR
    )
    if list((PRIOR / "cost-evidence").iterdir()):
        raise ValueError("Stopped original cost process must be settled with no child")
    return completed, latest, diagnostic, value


def comparable_reference(completed):
    """Independent exact expected properties after two acknowledged FULLSCANs."""
    expected = deepcopy(completed)
    for index in (0, 1):
        rows = inventory(expected["statistics_observations"][index])
        next(r for r in rows if key(r) == KEY).update(SAMPLED)
        text = json.dumps(rows)
        expected["statistics_observations"][index] = [
            dict(
                statistics_json=text,
                json_bytes=len(text.encode("utf-16-le")),
                statistics_count=len(rows),
            )
        ]
    return expected


def require_prepared_sequence(rows, mode, completed):
    import cost_resume

    current = deepcopy(rows)
    if mode == "ON":
        if len(current) != 1 or current[0]["generation"] != 2:
            raise ValueError("One acknowledged statistics invalidation required")
        current[0]["generation"] = 1
    cost_resume.require_sequence(current, mode, completed)


def prepare(packet, record, save, completed, stopped, copies, raw_statistics):
    import cost_readiness
    import cost_resume
    from cost_workload_binding import NAMES, QUERIES, owned_copy
    from fresh_business_state import normalized

    # Refuse changed input before the first update. Keep each real post-update
    # observation and acknowledgement; any partial preparation is non-replayable.
    require_known_delta(stopped, completed)
    for index in (0, 1):
        if inventory(raw_statistics[index]) != inventory(stopped["statistics_observations"][index]):
            raise ValueError("Recorded pre-preparation statistics changed")
    record["statistics_refusal_reused"] = RECEIPT_SHA
    record["statistics_preparation"] = []
    post = []
    expected = comparable_reference(completed)
    for index, name in enumerate(NAMES):
        mode = ("OFF", "ON")[index]
        record["stage"] = "prepare exact six-row statistic " + mode
        item = dict(database=name, mode=mode, acknowledged=False)
        record["statistics_preparation"].append(item)
        save()
        with owned_copy(name, record, save) as owner:
            if owner.read(QUERIES["active"]):
                raise ValueError("Cost statistics copy has another physical owner")
            item["statistics_before"] = owner.read(cost_readiness.STATISTICS)
            if inventory(item["statistics_before"]) != inventory(
                stopped["statistics_observations"][index]
            ):
                raise ValueError("Statistics changed immediately before preparation")
            item["maintenance_before"] = owner.read(QUERIES["maintenance"])
            if (
                normalized(item["maintenance_before"])
                != stopped["workload_copies"][index]["queries"]["maintenance"]
            ):
                raise ValueError("Six-row maintenance work changed")
            item["sequence_before"] = owner.read(cost_resume.SEQUENCE)
            cost_resume.require_sequence(item["sequence_before"], mode, completed)
            save()
            owner.mutate("prepare exact six-row PK statistic " + mode, PREPARE)
            item["acknowledged"] = True
            save()
            item["settled"] = owner.read(SETTLED)
            item["statistics_after"] = owner.read(cost_readiness.STATISTICS)
            item["maintenance_after"] = owner.read(QUERIES["maintenance"])
            item["sequence_after"] = owner.read(cost_resume.SEQUENCE)
            item["history_after"] = owner.read(cost_resume.HISTORY)
            save()
            if item["settled"] != [
                dict(transaction_count=0, transaction_state=0, session_marker="NoLock")
            ]:
                raise ValueError("Statistics preparation ownership is unconfirmed")
            if item["maintenance_before"] != item["maintenance_after"]:
                raise ValueError("Business maintenance rows changed during statistics preparation")
            if business(inventory(item["statistics_after"])) != business(
                inventory(expected["statistics_observations"][index])
            ):
                raise ValueError("Prepared statistics differ outside the exact six-row change")
            if inventory(item["statistics_after"]) == inventory(item["statistics_before"]):
                raise ValueError("Statistics acknowledgement lacks a new observation")
            require_prepared_sequence(item["sequence_after"], mode, completed)
            prior = json.loads((packet / "evidence/cost-ready/guest-receipt.json").read_bytes())
            cost_resume.require_history(
                item["history_after"], prior["fixtures"][index]["history"], mode, completed
            )
            post.append(item["statistics_after"])
            item["verified"] = True
            save()
    result = cost_resume.require_current_pair(copies, expected, post)
    result.update(
        exact_six_row_preparation=True,
        original_mismatch_preserved=True,
        full_non_ledger_statistics_equality=True,
        observer_generation_after=2,
    )
    record["prepared_statistics_observations"] = post
    save()
    return result
