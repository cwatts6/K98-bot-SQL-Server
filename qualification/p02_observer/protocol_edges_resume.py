"""Continue only the settled DB23 edge fixture; retain install and passed case."""

import json
import os
from pathlib import Path
import re
import sys

PURPOSE = "p02-retained-fixture-protocol-edges"
FAILED = Path("Q:/P02Observer/20261122115928689")
RECEIPT_SHA = "5f45a5dd5fe7feb555295d009534fd3bf58c98bb75cd31154f5af27f215821f5"
ARCHIVE_SHA = "af3df7ea77614cfebb83a18d033264b2a8c49d8d6402c5dd2490b3ece53c26ca"
DATABASE = "K98_P02Observer_20261122115928689"
COMPLETED = ("nested-preserved-autocommit-True",)
IDENTITY_SQL = """SELECT DB_ID() AS database_id,DB_NAME() AS database_name,
ORIGINAL_LOGIN() AS login_name,IS_SRVROLEMEMBER('sysadmin') AS administrator"""
FILES_SQL = """SELECT physical_name FROM sys.database_files ORDER BY file_id"""
QUIET_SQL = """SELECT s.session_id FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_requests r ON r.session_id=s.session_id
WHERE s.is_user_process=1 AND s.session_id<>@@SPID
AND (s.database_id=DB_ID() OR r.database_id=DB_ID())"""
LOCKS_SQL = """SELECT request_session_id FROM sys.dm_tran_locks
WHERE resource_database_id=DB_ID() AND request_session_id<>@@SPID
AND request_session_id>0"""
ROWS_SQL = """SELECT
(SELECT COUNT_BIG(*) FROM dbo.P02EdgeConstraint) AS fixture_rows,
(SELECT COUNT_BIG(*) FROM dbo.KVKFinalReportHeader) AS header_rows,
(SELECT COUNT_BIG(*) FROM dbo.MaintenanceKvkWork) AS kvk_rows,
(SELECT COUNT_BIG(*) FROM dbo.MaintenanceWork) AS work_rows,
DATABASE_PRINCIPAL_ID(N'P02EdgeRole') AS later_role"""
TABLES_SQL = """SELECT SCHEMA_NAME(schema_id) AS schema_name,name
FROM sys.tables WHERE is_ms_shipped=0 ORDER BY name"""


SEED_SOURCE_SHA = "ec50b60e036e37fa6d544fdc238c98110ecd90cc4eeaba62f8a87905d1f215fa"
WORK_SQL = "SELECT * FROM dbo.MaintenanceWork ORDER BY Kind"
STOPPED = Path("Q:/P02Observer/20261122120859950")
STOPPED_SHA = "92b2fb7fa6ad759323f7cc0ad57e0c4f194832357d0dcc30041f9685900307d6"
STOPPED_ARCHIVE_SHA = "04cf1460fe5c0c57425e50d67f6a2e02f8e238a591e531cb88bbbe3651757d85"


def expected_seed_rows():
    """All 19 fields from the pinned CREATE/defaults and six INSERT literals."""
    zero = (
        "DueGeneration",
        "CompletedGeneration",
        "KS4DueGeneration",
        "KS4CompletedGeneration",
        "DashboardDueGeneration",
        "DashboardCompletedGeneration",
        "SummaryDueGeneration",
        "SummaryCompletedGeneration",
    )
    nullable = (
        "ClaimedGeneration",
        "ClaimID",
        "LastRequestID",
        "DueUTC",
        "StartedUTC",
        "CompletedUTC",
        "FirstErrorNumber",
        "FirstErrorUTC",
        "LastErrorNumber",
    )
    return [
        dict(Kind=kind, State="complete", **dict.fromkeys(zero, 0), **dict.fromkeys(nullable))
        for kind in (
            "configuration",
            "final_stats",
            "import",
            "kvk_output",
            "player_report",
            "post_import",
        )
    ]


def require_seed_source(packet):
    import protocol_edges as edge

    raw = (packet / "sql/dbo.MaintenanceWork.Table.sql").read_bytes().replace(b"\r\n", b"\n")
    if edge.sha(raw) != SEED_SOURCE_SHA:
        raise ValueError("Exact reviewed baseline-row source required")


def require_stopped_preflight(value, previous):
    wanted = dict(
        outcome="failed",
        stage="verify retained edge fixture before unfinished checks",
        first_failure=dict(
            stage="verify retained edge fixture before unfinished checks",
            error_type="ValueError",
            detail="Retained fixture identity, emptiness or physical ownership changed",
        ),
        cleanup_failures=[dict(operation="final preservation", error_type="ValueError")],
        checks=[],
        actions=[],
        original_preserved=False,
        login_disabled=True,
        physical_custody_retained=False,
        admin_connections_closed=4,
        business_operations=0,
        maintenance_dispatches=0,
        login_enable_attempted=False,
    )
    if (
        any(value.get(k) != v for k, v in wanted.items())
        or "before" in value
        or value.get("after") != previous["after"]
        or value.get("fixture") != previous["fixture"]
        or value.get("retained_installation") != previous["installed"]
        or value.get("retained_checks") != previous["checks"][:1]
        or value.get("fixture_preflight", {}).get("rows")
        != [dict(fixture_rows=0, header_rows=0, kvk_rows=0, work_rows=6, later_role=None)]
        or value["fixture_preflight"].get("boundary", {}).get("generation") != 7
        or value["fixture_preflight"].get("sessions") != []
        or value["fixture_preflight"].get("locks") != []
    ):
        raise ValueError("Only the exact settled read-only preflight failure may continue")


def authenticate_stopped(packet, previous):
    import protocol_edges as edge

    raw = (packet / "evidence/edge-preflight-failed.json").read_bytes()
    if (
        edge.sha(raw) != STOPPED_SHA
        or raw != (STOPPED / "receipt.json").read_bytes()
        or edge.sha((STOPPED / "packet.zip").read_bytes()) != STOPPED_ARCHIVE_SHA
    ):
        raise ValueError("Exact retained preflight receipt and source required")
    value = json.loads(raw)
    require_stopped_preflight(value, previous)
    return value


def require_packet(packet, manifest):
    import protocol_edges as edge

    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("production_eligible") is not False
        or manifest.get("database") != DATABASE
        or manifest.get("resume_receipt_sha256") != RECEIPT_SHA
        or manifest.get("stopped_preflight_receipt_sha256") != STOPPED_SHA
        or manifest.get("business_operations") != 0
        or manifest.get("maintenance_dispatches") != 0
        or manifest.get("enable_application_login") is not False
        or manifest.get("new_database") is not False
        or manifest.get("install_replayed") is not False
        or manifest.get("completed_checks") != list(COMPLETED)
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or Path(manifest["guest_directory"]).resolve() in (FAILED.resolve(), STOPPED.resolve())
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
    ):
        raise ValueError("Exact retained edge-fixture continuation required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or edge.sha(path.read_bytes()) != digest:
            raise ValueError("Sealed edge continuation member changed")


def authenticate(packet):
    import protocol_edges as edge

    raw = (packet / "evidence/edge-failed.json").read_bytes()
    if (
        edge.sha(raw) != RECEIPT_SHA
        or raw != (FAILED / "receipt.json").read_bytes()
        or edge.sha((FAILED / "packet.zip").read_bytes()) != ARCHIVE_SHA
    ):
        raise ValueError("Exact settled failed edge packet required")
    value = json.loads(raw)
    require_settled(value)
    return value


def require_settled(value):
    wanted = dict(
        outcome="failed",
        stage="doomed-preserved-autocommit-True",
        cleanup_failures=[],
        original_preserved=True,
        login_disabled=True,
        physical_custody_retained=False,
        admin_connections_closed=10,
        business_operations=0,
        maintenance_dispatches=0,
        login_enable_attempted=False,
    )
    if (
        any(value.get(k) != v for k, v in wanted.items())
        or value.get("first_failure")
        != dict(
            stage="doomed-preserved-autocommit-True",
            error_type="ValueError",
            detail="Unexpected administrative result",
        )
        or value.get("before") != value.get("after")
        or len(value.get("actions", [])) != 24
        or any(row.get("acknowledged") is not True for row in value["actions"])
        or len(value.get("checks", [])) != 2
        or value["checks"][0].get("name") != COMPLETED[0]
        or value["checks"][0].get("passed") is not True
        or value["checks"][0].get("observed", {}).get("before")
        != value["checks"][0].get("observed", {}).get("after")
        or value["checks"][1] != dict(name="doomed-preserved-autocommit-True", passed=False)
        or value.get("fixture", {}).get("name") != DATABASE
        or value["fixture"].get("database_id") != 23
        or value.get("installed", {}).get("generation") != 7
    ):
        raise ValueError("Only the recorded settled fixture/result-shape failure may continue")


def require_live(value, previous):
    import fresh_business_state as state

    old = previous["installed"]
    if (
        value["identity"]
        != [
            dict(
                database_id=23,
                database_name=DATABASE,
                login_name="MINI_AMD\\K98LabAdmin",
                administrator=1,
            )
        ]
        or value["sessions"]
        or value["locks"]
        or value["files"] != [{"physical_name": p} for p in previous["fixture_files"]]
        or value["rows"]
        != [dict(fixture_rows=0, header_rows=0, kvk_rows=0, work_rows=6, later_role=None)]
        or value["work"] != expected_seed_rows()
        or value["tables"]
        != [
            {"schema_name": "dbo", "name": n}
            for n in (
                "KVKFinalReportHeader",
                "MaintenanceKvkWork",
                "MaintenanceWork",
                "P02EdgeConstraint",
            )
        ]
    ):
        raise ValueError("Retained fixture identity, baseline data or physical ownership changed")
    current = state.normalized(value["boundary"].identity)
    if (
        current[:5] + current[9:] != old["identity"][:5] + old["identity"][9:]
        or value["boundary"].generation != 7
    ):
        raise ValueError("Retained installed protocol or sequence changed")
    if len(value["sequence"]) != 1 or value["sequence"][0]["is_exhausted"] is not False:
        raise ValueError("Retained sequence is not the original healthy installation")


def load(packet, manifest, record, save):
    previous = authenticate(packet)
    authenticate_stopped(packet, previous)
    require_seed_source(packet)
    record["stopped_preflight_receipt_sha256"] = STOPPED_SHA
    record["fixture"] = previous["fixture"]
    record["fixture_files"] = previous["fixture_files"]
    record["retained_installation"] = previous["installed"]
    record["retained_checks"] = previous["checks"][:1]
    record["resume_receipt_sha256"] = RECEIPT_SHA
    save()
    return previous


def verify_fixture(packet, manifest, record, save, previous):
    import protocol_edges as edge

    require_seed_source(packet)
    record["stage"] = "verify retained edge fixture before unfinished checks"
    facts = {}
    record["fixture_preflight"] = facts
    save()
    with edge.owned_fixture(DATABASE, record, save) as owner:
        for name, sql in (
            ("identity", IDENTITY_SQL),
            ("sessions", QUIET_SQL),
            ("locks", LOCKS_SQL),
            ("files", FILES_SQL),
            ("rows", ROWS_SQL),
            ("work", WORK_SQL),
            ("tables", TABLES_SQL),
            ("sequence", edge.SEQUENCE_SQL),
        ):
            facts[name] = owner.read(sql)
            save()
        current = edge.boundary(owner)
        facts["boundary"] = dict(identity=current.identity, generation=current.generation)
        save()
        require_live(dict(facts, boundary=current), previous)
    return previous


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    require_packet(packet, manifest)
    from release_boundary import native_paths

    native_paths(packet)
    import protocol_edges as edge
    import pyodbc

    pyodbc.pooling = False
    return edge.run(packet, manifest, resume_loader=load, resume_verifier=verify_fixture)


if __name__ == "__main__":
    raise SystemExit(main())
