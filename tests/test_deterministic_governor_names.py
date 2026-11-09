"""Offline source contracts and opt-in, uniquely owned local SQL fixtures.

K98_NAME_SQL_TESTS=1 enables native tests on local K98DEV only. The fixture
creates/drops its own UUID-named database; it never executes the business proc.
"""

from collections import Counter
import os
import json
from pathlib import Path
import re
import uuid

import pytest

ROOT = Path(__file__).resolve().parents[1]
MID = "20261107_001_deterministic_governor_names"
FORWARD = ROOT / "migrations" / f"{MID}.sql"
BACKWARD = ROOT / "migrations" / "rollback" / f"{MID}_rollback.sql"
SNAPSHOT = ROOT / "sql_schema" / "dbo.GOVERNOR_NAMES_PROC.StoredProcedure.sql"


def images(path):
    text = path.read_text(encoding="utf-8-sig")
    return tuple(
        re.search(rf"DECLARE @{name} nvarchar\(max\) = N'((?:[^']|'')*)';", text)
        .group(1)
        .replace("''", "'")
        for name in ("before", "after")
    )


def step4(module):
    return module.split("-- Step 4:", 1)[1].split("-- Step 5:", 1)[0]


def test_images_match_and_only_step4_changes():
    before, after = images(FORWARD)
    # This migration is the original alias-history step. Shared display names
    # is a separately guarded additive package; neither historical image changes.
    shared = json.loads((ROOT / "qualification/p02_report_names/reviewed_sources.json").read_text())
    record = shared[SNAPSHOT.name]
    assert SNAPSHOT.read_text(encoding="utf-8-sig") == record["after"]
    snapshot = record["before"]
    assert (
        after
        == snapshot[
            snapshot.index("ALTER PROCEDURE [dbo].[GOVERNOR_NAMES_PROC]") :
        ].strip()
    )
    assert images(BACKWARD) == (after, before)
    assert before.split("-- Step 4:")[0] == after.split("-- Step 4:")[0]
    assert before.split("-- Step 5:")[1] == after.split("-- Step 5:")[1]
    assert "SELECT DISTINCT" in step4(before)
    assert "PARTITION BY GovernorID, GovernorName" in step4(after)
    assert after.count("ROK_TRACKER.dbo.KingdomScanData4") == before.count(
        "ROK_TRACKER.dbo.KingdomScanData4"
    )


@pytest.fixture(scope="module")
def engine():
    if os.environ.get("K98_NAME_SQL_TESTS") != "1":
        pytest.skip("Native SQL explicitly opt-in; owned disposable local fixture only")
    pyodbc = pytest.importorskip("pyodbc")
    pyodbc.pooling = False
    base = "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost\\K98DEV;Trusted_Connection=yes;Encrypt=no;APP=P021NameRegression;"
    master = pyodbc.connect(base + "DATABASE=master", autocommit=True, timeout=5)
    name = "K98_P021_NameTest_" + uuid.uuid4().hex
    created = False
    connection = None
    try:
        assert master.execute("SELECT @@SERVERNAME").fetchval() == "9SX2VF4\\K98DEV"
        master.execute(f"CREATE DATABASE [{name}]")
        created = True
        connection = pyodbc.connect(
            base + f"DATABASE={name}", autocommit=True, timeout=5
        )
        connection.timeout = 15
        connection.execute("SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;")
        connection.execute("CREATE PROCEDURE dbo.GOVERNOR_NAMES_PROC AS RETURN;")
        # Deferred name resolution permits installing the exact body without running it.
        connection.execute(images(FORWARD)[0])
        connection.execute(
            "CREATE USER NameTestReader WITHOUT LOGIN; GRANT EXECUTE ON dbo.GOVERNOR_NAMES_PROC TO NameTestReader;"
        )
        yield connection
    finally:
        if connection is not None:
            connection.close()
        if created:
            # No SINGLE_USER/forced disconnection: retain on unexpected use.
            master.execute(f"DROP DATABASE [{name}]")
        master.close()


def installed(connection):
    text = connection.execute(
        "SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.GOVERNOR_NAMES_PROC'))"
    ).fetchval()
    text = text.replace("\r\n", "\n").strip()
    return re.sub(r"\ACREATE(?: OR ALTER)? PROCEDURE", "ALTER PROCEDURE", text)


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_install_repeat_rollback_repeat_reinstall(engine, newline):
    before, after = images(FORWARD)
    for path, expected in [
        (BACKWARD, before),
        (FORWARD, after),
        (FORWARD, after),
        (BACKWARD, before),
        (BACKWARD, before),
        (FORWARD, after),
    ]:
        engine.execute(path.read_text(encoding="utf-8-sig").replace("\n", newline))
        assert installed(engine) == expected
        assert engine.execute("SELECT @@TRANCOUNT").fetchval() == 0
        assert (
            engine.execute(
                "SELECT COUNT(*) FROM sys.database_permissions WHERE major_id=OBJECT_ID(N'dbo.GOVERNOR_NAMES_PROC') AND grantee_principal_id=USER_ID(N'NameTestReader') AND permission_name=N'EXECUTE'"
            ).fetchval()
            == 1
        )


@pytest.mark.parametrize("path", [FORWARD, BACKWARD])
def test_unknown_definition_refused_without_change(engine, path):
    engine.execute("ALTER PROCEDURE dbo.GOVERNOR_NAMES_PROC AS SELECT 9876;")
    old = installed(engine)
    try:
        with pytest.raises(Exception, match="Unrecognized governor names"):
            engine.execute(path.read_text(encoding="utf-8-sig"))
        assert installed(engine) == old
        assert engine.execute("SELECT @@TRANCOUNT").fetchval() == 0
    finally:
        engine.execute(images(FORWARD)[0])


def test_create_header_recognized(engine):
    before, after = images(FORWARD)
    engine.execute("DROP PROCEDURE dbo.GOVERNOR_NAMES_PROC")
    engine.execute(before.replace("ALTER PROCEDURE", "CREATE PROCEDURE", 1))
    engine.execute("GRANT EXECUTE ON dbo.GOVERNOR_NAMES_PROC TO NameTestReader")
    engine.execute(FORWARD.read_text(encoding="utf-8-sig"))
    assert installed(engine) == after


@pytest.mark.parametrize("path", [FORWARD, BACKWARD])
def test_context_drift_refused(engine, path):
    before, _ = images(FORWARD)
    engine.execute(before.replace("WITH EXECUTE AS CALLER", "WITH EXECUTE AS OWNER", 1))
    old = installed(engine)
    try:
        with pytest.raises(Exception, match="options or execution context"):
            engine.execute(path.read_text(encoding="utf-8-sig"))
        assert installed(engine) == old
    finally:
        engine.execute(before)


def test_signed_module_refused(engine):
    before, _ = images(FORWARD)
    engine.execute(before)
    engine.execute(
        "CREATE CERTIFICATE NameTestCertificate ENCRYPTION BY PASSWORD='DisposableFixtureOnly123!' WITH SUBJECT='Disposable name migration test';"
    )
    engine.execute(
        "ADD SIGNATURE TO dbo.GOVERNOR_NAMES_PROC BY CERTIFICATE NameTestCertificate WITH PASSWORD='DisposableFixtureOnly123!';"
    )
    try:
        for path in (FORWARD, BACKWARD):
            with pytest.raises(Exception, match="Signed module"):
                engine.execute(path.read_text(encoding="utf-8-sig"))
            assert installed(engine) == before
            assert (
                engine.execute(
                    "SELECT COUNT(*) FROM sys.crypt_properties WHERE major_id=OBJECT_ID(N'dbo.GOVERNOR_NAMES_PROC')"
                ).fetchval()
                == 1
            )
    finally:
        engine.execute(
            "DROP SIGNATURE FROM dbo.GOVERNOR_NAMES_PROC BY CERTIFICATE NameTestCertificate"
        )
        engine.execute("DROP CERTIFICATE NameTestCertificate")


CASES = [
    ([(1, "Example", 1), (1, "EXAMPLE", 2)], [(1.0, "EXAMPLE")]),
    ([(1, "Example", 2), (1, "EXAMPLE", 1)], [(1.0, "Example")]),
    ([(1, "Example", 2), (1, "EXAMPLE", 2)], [(1.0, "EXAMPLE")]),
    ([(1, "\u024e\u024eExample", 1), (1, "Example", 2)], [(1.0, "Example")]),
    (
        [(1, "\u024e\u024eExample", 2), (1, "Example", 1)],
        [(1.0, "\u024e\u024eExample")],
    ),
    ([(1, "\u024e\u024eExample", 2), (1, "Example", 2)], [(1.0, "Example")]),
    ([(1, "Example   ", 2), (1, "Example", 2)], [(1.0, "Example")]),
    ([(1, "Cafe", 1), (1, "Caf\u00e9", 2)], [(1.0, "Cafe"), (1.0, "Caf\u00e9")]),
    (
        [(1, "Example", 1), (2, "Example", 2), (1, "Other", 3)],
        [(1.0, "Example"), (2.0, "Example"), (1.0, "Other")],
    ),
    ([(0, "Excluded", 1), (1, None, 2), (1, "", 3)], [(1.0, "")]),
    ([(1, "Example", 1), (1, "Example", 1)], [(1.0, "Example")]),
    ([], []),
]


@pytest.mark.parametrize("rows, expected", CASES)
@pytest.mark.parametrize("reverse", [False, True])
def test_real_step4_query(engine, rows, expected, reverse):
    query = step4(images(FORWARD)[1])
    query = query[query.index("TRUNCATE TABLE") :]
    query = (
        query.replace("ROK_TRACKER.dbo.KingdomScanData4", "#NameHistory")
        .replace("dbo.ALL_GOVS_NAMES", "#NameOutput")
        .replace("INSERT INTO ALL_GOVS_NAMES", "INSERT INTO #NameOutput")
    )
    engine.execute(
        "CREATE TABLE #NameHistory (GovernorID bigint NOT NULL, GovernorName nvarchar(200) COLLATE Latin1_General_CI_AS NULL, ScanOrder int NOT NULL); CREATE TABLE #NameOutput (GovernorID float NOT NULL, GovernorName nchar(255) COLLATE Latin1_General_CI_AS NULL);"
    )
    try:
        for row in list(reversed(rows)) if reverse else rows:
            engine.execute("INSERT #NameHistory VALUES (?,?,?)", *row)
        engine.execute(query)
        actual = engine.execute(
            "SELECT GovernorID, GovernorName FROM #NameOutput"
        ).fetchall()
        assert Counter((row[0], row[1]) for row in actual) == Counter(
            (gov, name.ljust(255)) for gov, name in expected
        )
        # Both directions preserve original SQL equivalence groups, independently of spelling.
        assert (
            engine.execute(
                "SELECT COUNT(*) FROM (SELECT GovernorID, RTRIM(GovernorName) AS GovernorName FROM #NameHistory WHERE GovernorID<>0 AND GovernorName IS NOT NULL EXCEPT SELECT GovernorID, GovernorName FROM #NameOutput) d"
            ).fetchval()
            == 0
        )
        assert (
            engine.execute(
                "SELECT COUNT(*) FROM (SELECT GovernorID, GovernorName FROM #NameOutput EXCEPT SELECT GovernorID, RTRIM(GovernorName) FROM #NameHistory WHERE GovernorID<>0 AND GovernorName IS NOT NULL) d"
            ).fetchval()
            == 0
        )
    finally:
        engine.execute("DROP TABLE #NameOutput; DROP TABLE #NameHistory;")
