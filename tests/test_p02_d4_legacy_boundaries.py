"""Legacy retirement and queue coexistence in a newly owned local database."""

import hashlib
import json
import re
from pathlib import Path

import pytest
from test_p02_d4_installed_dependencies import dependencies as dependencies

ROOT = Path(__file__).resolve().parents[1]
RETIRED = ("UPDATE_ALL", "UPDATE_RALLY_DATA", "TEST")
QUEUE = (
    "usp_GetPendingLogBackupTriggers",
    "usp_MarkLogBackupTriggerProcessed",
    "usp_CleanupLogBackupTriggerQueue",
)
CALLS = {
    "UPDATE_ALL": "EXEC dbo.UPDATE_ALL @CompletedFileName=N'd4-never-read.csv'",
    "UPDATE_RALLY_DATA": "EXEC dbo.UPDATE_RALLY_DATA",
    "TEST": "EXEC dbo.TEST",
    "usp_GetPendingLogBackupTriggers": "EXEC dbo.usp_GetPendingLogBackupTriggers",
    "usp_MarkLogBackupTriggerProcessed": (
        "EXEC dbo.usp_MarkLogBackupTriggerProcessed @TriggerID=1,"
        "@ProcessedBy=N'd4-test',@BackupResult=N'must-not-be-recorded'"
    ),
    "usp_CleanupLogBackupTriggerQueue": (
        "EXEC dbo.usp_CleanupLogBackupTriggerQueue @RetentionDays=0"
    ),
}


def test_original_definitions_are_retained_exactly():
    manifest = json.loads(
        (ROOT / "qualification/p02_d4/legacy_source_history.json").read_text(
            encoding="utf-8-sig"
        )
    )
    assert manifest["sourceRevision"] == "b8e6b9258abae2d0abf4775b711e7bf98d9b7c70"
    assert [m["name"] for m in manifest["modules"]] == [f"dbo.{n}" for n in RETIRED]
    expected = (
        "c4e28d91f76402bd7cd102f149f0122a90ee8670876d519f95895dd2a09b2896",
        "9764efb9471e0cec5459c0c555dd908795c0ef9287c6286b9479e6542e197f01",
        "7261da51f1f5c549355dcbf0b18828697f1db976c2385913f7b58659445369dd",
    )
    for module, digest in zip(manifest["modules"], expected, strict=True):
        assert module["sha256"] == digest
        assert (
            hashlib.sha256((ROOT / module["path"]).read_bytes()).hexdigest() == digest
        )


@pytest.fixture(scope="module")
def legacy(dependencies):
    con, _ = dependencies
    helper = (
        ROOT / "sql_schema/dbo.usp_P02LegacyQueueState.StoredProcedure.sql"
    ).read_text(encoding="utf-8-sig")
    for batch in re.split(r"(?im)^GO\s*$", helper):
        if batch.strip():
            con.execute(batch)
    for name in (*RETIRED, *QUEUE):
        source = (ROOT / f"sql_schema/dbo.{name}.StoredProcedure.sql").read_text(
            encoding="utf-8-sig"
        )
        definition = source[source.index("ALTER PROCEDURE") :]
        con.execute("CREATE OR " + definition)
    con.execute(
        (ROOT / "sql_schema/dbo.LogBackupTriggerQueue.Table.sql").read_text(
            encoding="utf-8-sig"
        )
    )
    con.execute(
        "CREATE TABLE dbo.D4Sentinel(ID int PRIMARY KEY, Value int NOT NULL);"
        "INSERT dbo.D4Sentinel VALUES(1, 47);"
        "CREATE USER d4_legacy_allowed WITHOUT LOGIN;"
        "CREATE USER d4_legacy_denied WITHOUT LOGIN;"
        "GRANT VIEW DEFINITION TO d4_legacy_allowed;"
        "CREATE USER d4_queue_hidden WITHOUT LOGIN;"
    )
    for name in (*RETIRED, *QUEUE):
        con.execute(f"GRANT EXECUTE ON dbo.{name} TO d4_legacy_allowed;")
        con.execute(f"DENY EXECUTE ON dbo.{name} TO d4_legacy_denied;")
    for name in QUEUE:
        con.execute(f"GRANT EXECUTE ON dbo.{name} TO d4_queue_hidden;")
    yield con


def refused(con, call):
    return tuple(
        con.execute(
            f"BEGIN TRY {call}; SELECT 0 AS error_number,@@TRANCOUNT,XACT_STATE();"
            " END TRY BEGIN CATCH SELECT ERROR_NUMBER(),@@TRANCOUNT,XACT_STATE(); END CATCH;"
        ).fetchone()
    )


@pytest.mark.parametrize("name", RETIRED)
@pytest.mark.parametrize("mode", ("autocommit", "ambient", "implicit"))
def test_retired_entry_refuses_without_business_effects(legacy, name, mode):
    con = legacy
    before = con.execute("SELECT COUNT(*) FROM sys.objects").fetchval()
    con.execute("SET XACT_ABORT OFF; SET IMPLICIT_TRANSACTIONS OFF;")
    if mode == "ambient":
        con.execute("BEGIN TRANSACTION; UPDATE dbo.D4Sentinel SET Value=48 WHERE ID=1;")
    try:
        con.execute("EXECUTE AS USER=N'd4_legacy_allowed';")
        try:
            if mode == "implicit":
                con.execute("SET IMPLICIT_TRANSACTIONS ON;")
            entry = tuple(con.execute("SELECT @@TRANCOUNT,XACT_STATE();").fetchone())
            error, depth, state = refused(con, CALLS[name])
            assert error == 52940
            assert entry == ((1, 1) if mode == "ambient" else (0, 0))
            assert (depth, state) == entry
        finally:
            con.execute("REVERT;")
    finally:
        con.execute("SET IMPLICIT_TRANSACTIONS OFF; IF @@TRANCOUNT>0 ROLLBACK;")
    assert con.execute("SELECT Value FROM dbo.D4Sentinel WHERE ID=1").fetchval() == 47
    assert con.execute("SELECT COUNT(*) FROM sys.objects").fetchval() == before


@pytest.mark.parametrize("name", (*RETIRED, *QUEUE))
def test_retirement_preserves_denied_principal_boundary(legacy, name):
    con = legacy
    con.execute("EXECUTE AS USER=N'd4_legacy_denied';")
    try:
        assert refused(con, CALLS[name])[0] == 229
    finally:
        con.execute("REVERT;")


def queue_rows(con):
    return [
        tuple(row)
        for row in con.execute("SELECT * FROM dbo.LogBackupTriggerQueue ORDER BY ID")
    ]


@pytest.mark.parametrize("ledger_kind", ("table", "view"))
def test_new_contract_holds_old_queue_without_adoption_or_expiry(legacy, ledger_kind):
    con = legacy
    con.execute(
        "DELETE dbo.LogBackupTriggerQueue; DBCC CHECKIDENT('dbo.LogBackupTriggerQueue', RESEED, 0);"
    )
    con.execute(
        "INSERT dbo.LogBackupTriggerQueue(TriggerTime,ProcedureName,Reason,Processed,ProcessedTime,BackupResult)"
        " VALUES('2020-01-01',N'old',N'unknown',0,NULL,NULL),"
        " ('2020-01-01',N'old',N'recorded',1,'2020-01-02',N'retained receipt');"
    )
    if ledger_kind == "table":
        con.execute("CREATE TABLE dbo.MaintenanceBackupWork(ID int);")
    else:
        con.execute("CREATE VIEW dbo.MaintenanceBackupWork AS SELECT 1 AS ID;")
    before = queue_rows(con)
    try:
        for _ in range(2):  # A repeated call cannot adopt or clean the old evidence.
            con.execute("EXECUTE AS USER=N'd4_legacy_allowed';")
            try:
                for name in QUEUE:
                    assert refused(con, CALLS[name])[0] == 52941
            finally:
                con.execute("REVERT;")
            assert queue_rows(con) == before
        con.execute("EXECUTE AS USER=N'd4_queue_hidden';")
        try:
            for name in QUEUE:
                assert refused(con, CALLS[name])[0] == 52941
        finally:
            con.execute("REVERT;")
        assert queue_rows(con) == before
    finally:
        con.execute(f"DROP {ledger_kind.upper()} dbo.MaintenanceBackupWork;")


def test_legacy_only_deployment_retains_original_queue_behavior(legacy):
    con = legacy
    con.execute(
        "DELETE dbo.LogBackupTriggerQueue; DBCC CHECKIDENT('dbo.LogBackupTriggerQueue', RESEED, 0);"
    )
    con.execute(
        "INSERT dbo.LogBackupTriggerQueue(ProcedureName,Reason) VALUES(N'd4',N'legacy');"
    )
    con.execute("EXECUTE AS USER=N'd4_legacy_allowed';")
    try:
        assert len(con.execute(CALLS[QUEUE[0]]).fetchall()) == 1
        con.execute(CALLS[QUEUE[1]])
    finally:
        con.execute("REVERT;")
    assert queue_rows(con)[0][4] is True
    con.execute("UPDATE dbo.LogBackupTriggerQueue SET ProcessedTime='2020-01-01';")
    con.execute("EXECUTE AS USER=N'd4_legacy_allowed';")
    try:
        con.execute(CALLS[QUEUE[2]])
    finally:
        con.execute("REVERT;")
    assert queue_rows(con) == []


def test_legacy_only_caller_does_not_need_extra_metadata_grants(legacy):
    con = legacy
    con.execute("EXECUTE AS USER=N'd4_queue_hidden';")
    try:
        assert con.execute(CALLS[QUEUE[0]]).fetchall() == []
        assert con.execute("SELECT USER_NAME()").fetchval() == "d4_queue_hidden"
    finally:
        con.execute("REVERT;")


@pytest.mark.parametrize("denial", ("OBJECT::dbo.MaintenanceBackupWork", "SCHEMA::dbo"))
def test_narrow_metadata_denial_cannot_reopen_legacy_queue(legacy, denial):
    con = legacy
    con.execute("CREATE TABLE dbo.MaintenanceBackupWork(ID int);")
    before = queue_rows(con)
    con.execute(f"DENY VIEW DEFINITION ON {denial} TO d4_legacy_allowed;")
    try:
        con.execute("EXECUTE AS USER=N'd4_legacy_allowed';")
        try:
            assert (
                con.execute(
                    "SELECT HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','VIEW DEFINITION')"
                ).fetchval()
                == 1
            )
            assert (
                con.execute("SELECT OBJECT_ID(N'dbo.MaintenanceBackupWork')").fetchval()
                is None
            )
            for name in QUEUE:
                assert refused(con, CALLS[name])[0] == 52941
        finally:
            con.execute("REVERT;")
        assert queue_rows(con) == before
    finally:
        con.execute(f"REVOKE VIEW DEFINITION ON {denial} FROM d4_legacy_allowed;")
        con.execute("DROP TABLE dbo.MaintenanceBackupWork;")


def test_changed_metadata_owner_refuses_before_queue_access(legacy):
    con = legacy
    before = queue_rows(con)
    con.execute(
        "ALTER AUTHORIZATION ON OBJECT::dbo.usp_P02LegacyQueueState TO d4_queue_hidden;"
    )
    try:
        for name in QUEUE:
            assert refused(con, CALLS[name])[0] == 52942
        assert con.execute("SELECT USER_NAME()").fetchval() == "dbo"
        assert queue_rows(con) == before
    finally:
        con.execute(
            "ALTER AUTHORIZATION ON OBJECT::dbo.usp_P02LegacyQueueState TO SCHEMA OWNER;"
        )


def test_missing_metadata_helper_never_falls_back(legacy):
    con = legacy
    before = queue_rows(con)
    con.execute("DROP PROCEDURE dbo.usp_P02LegacyQueueState;")
    try:
        for name in QUEUE:
            assert refused(con, CALLS[name])[0] == 2812
        assert queue_rows(con) == before
    finally:
        source = (
            ROOT / "sql_schema/dbo.usp_P02LegacyQueueState.StoredProcedure.sql"
        ).read_text(encoding="utf-8-sig")
        for batch in re.split(r"(?im)^GO\s*$", source):
            if batch.strip():
                con.execute(batch)
