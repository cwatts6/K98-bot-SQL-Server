r"""Opt-in native parity tests using two uniquely owned, disposable local databases.

K98_SUMMARY_SQL_TESTS=1 enables lpc:localhost\K98DEV only. No restore, import,
provider, production database or retained rehearsal database is accessed.
"""

from collections import Counter
from datetime import datetime, timedelta
import hashlib
import json
import os
from pathlib import Path
import re
import uuid

import pytest

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "qualification/p021_summary"
LEGACY = json.loads((PACK / "legacy_modules.json").read_text(encoding="utf-8"))
MANIFEST = json.loads((PACK / "manifest.json").read_text(encoding="utf-8"))
NAMES = list(LEGACY)
HISTORY = MANIFEST["historyTables"]
NOW = datetime(2026, 11, 7, 12)
REFERENCE = ROOT / "qualification/p02_phase1"
ENDPOINT_MODULES = json.loads(
    (REFERENCE / "endpoint_modules.json").read_text(encoding="utf-8")
)
ENDPOINT_TABLES = json.loads(
    (REFERENCE / "endpoint_tables.json").read_text(encoding="utf-8")
)


def source(name):
    return ENDPOINT_MODULES[name]


def module_body(name, candidate, frozen=True):
    text = source(name) if candidate or name == "SUMMARY_PROC" else LEGACY[name]
    if frozen:
        text = text.replace(
            "SYSUTCDATETIME()", "CONVERT(datetime2(7),'2026-11-07T12:00:00',126)"
        )
    return text


ALL_MODULES = NAMES + ["SUMMARY_PROC"]
TABLE_FILES = {}
for _file in (ROOT / "sql_schema").glob("*.Table.sql"):
    _match = re.search(
        r"CREATE TABLE \[dbo\]\.\[([^]]+)\]",
        _file.read_text(encoding="utf-8-sig"),
        re.I,
    )
    if _match:
        TABLE_FILES[_match[1].lower()] = (_match[1], _file)
TABLES = set(HISTORY)
for _name in ALL_MODULES:
    for _obj in re.findall(r"\bdbo\.(?:\[([^]]+)\]|(\w+))", source(_name), re.I):
        _table = next(x for x in _obj if x)
        if _table.lower() in TABLE_FILES:
            TABLES.add(TABLE_FILES[_table.lower()][0])
TABLES = sorted(TABLES, key=str.lower)
OUTPUTS = [t for t in TABLES if t not in HISTORY and t != "KingdomScanData4"]


def test_source_contracts():
    assert len(HISTORY) == 32 and len(NAMES) == 9
    assert len(OUTPUTS) == 42  # 8 latest + 8 final + 24 delta + export/state
    for name in NAMES:
        old, new = LEGACY[name], source(name)
        assert (
            hashlib.sha256(old.encode()).hexdigest()
            == MANIFEST["modules"][name]["beforeSHA256"]
        )
        assert (
            hashlib.sha256(new.encode()).hexdigest()
            == MANIFEST["modules"][name]["afterSHA256"]
        )
        assert new.count("-- Retain only first/last rows") == 4
        assert len(re.findall(r"WHERE RowAsc\w+ = 1 OR RowDesc\w+ = 1;", new)) == 4
        for table in HISTORY:
            assert not re.search(r"\bdbo\." + re.escape(table) + r"\b", new, re.I)
        # Final outputs/aggregates/state only change their history input names.
        tail = old[old.index(";WITH FirstLastAll AS") :]
        for table in HISTORY:
            tail = re.sub(
                r"\bdbo\." + re.escape(table) + r"\b",
                "#P021_" + table,
                tail,
                flags=re.I,
            )
        assert new[new.index(";WITH FirstLastAll AS") :] == tail
        assert (
            old.split(";WITH LatestScanOrder AS", 1)[1].split(";", 1)[0]
            == new.split(";WITH LatestScanOrder AS", 1)[1].split(";", 1)[0]
        )
    for filename in ["install.sql", "rollback.sql"]:
        text = (PACK / filename).read_text()
        assert "9SX2VF4\\K98DEV" in text and "P021SummaryFixtureOwner" in text
        assert "EXEC dbo." not in text


@pytest.fixture(scope="module")
def databases():
    if os.environ.get("K98_SUMMARY_SQL_TESTS") != "1":
        pytest.skip("Native SQL explicitly opt-in; uniquely owned local fixtures only")
    pyodbc = pytest.importorskip("pyodbc")
    pyodbc.pooling = False
    base = "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost\\K98DEV;Trusted_Connection=yes;Encrypt=no;APP=P021SummaryRegression;"
    master = pyodbc.connect(base + "DATABASE=master", autocommit=True, timeout=5)
    owned = []
    try:
        assert (
            master.execute(
                "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))"
            ).fetchval()
            == "9SX2VF4\\K98DEV"
        )
        for arm in ["baseline", "candidate"]:
            token = uuid.uuid4().hex
            name = "K98_P021_SummaryTest_" + token
            master.execute(f"CREATE DATABASE [{name}] COLLATE Latin1_General_CI_AS")
            con = pyodbc.connect(base + f"DATABASE={name}", autocommit=True, timeout=5)
            owned.append((name, token, con))
            con.timeout = 60
            con.execute(
                "EXEC sys.sp_addextendedproperty @name=N'P021SummaryFixtureOwner',@value=?",
                token,
            )
            con.execute(
                "EXEC sys.sp_set_session_context @key=N'P021SummaryFixtureOwner',@value=?",
                token,
            )
            con.execute(
                "SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;"
            )
            # Canonical table references an absent sequence source. This unused fixture
            # dependency is synthetic; every inserted SCAN_UNO is supplied explicitly.
            con.execute("CREATE SEQUENCE dbo.KS4_UNO_SEQ AS int START WITH 1;")
            for table in TABLES:
                sql = ENDPOINT_TABLES[table]
                for batch in re.split(r"(?im)^GO\s*$", sql):
                    if batch.strip():
                        con.execute(batch)
            for proc in ALL_MODULES:
                con.execute(f"CREATE PROCEDURE dbo.[{proc}] AS RETURN;")
            con.execute("CREATE USER SummaryFixtureReader WITHOUT LOGIN;")
            for proc in ALL_MODULES:
                con.execute(f"GRANT EXECUTE ON dbo.[{proc}] TO SummaryFixtureReader;")
        yield [item[2] for item in owned]
    finally:
        for name, token, con in owned:
            try:
                if con.execute("SELECT @@TRANCOUNT").fetchval():
                    con.execute("ROLLBACK TRANSACTION")
            finally:
                con.close()
            # No forced disconnect, no wildcard cleanup, no pre-existing DB removal.
            actual = master.execute(
                f"SELECT CONVERT(nvarchar(32),value) FROM [{name}].sys.extended_properties WHERE class=0 AND name=N'P021SummaryFixtureOwner'"
            ).fetchval()
            assert actual == token
            master.execute(f"DROP DATABASE [{name}]")
        master.close()


def install_bodies(con, candidate, frozen=True):
    for proc in ALL_MODULES:
        con.execute(module_body(proc, candidate, frozen))


@pytest.fixture
def pair(databases):
    for candidate, con in enumerate(databases):
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
        for table in TABLES:
            con.execute(f"TRUNCATE TABLE dbo.[{table}]")
        install_bodies(con, bool(candidate))
    return databases


COLUMNS = [
    "PowerRank",
    "GovernorName",
    "GovernorID",
    "Power",
    "KillPoints",
    "Deads",
    "T1_Kills",
    "T2_Kills",
    "T3_Kills",
    "T4_Kills",
    "T5_Kills",
    "T4&T5_KILLS",
    "RSSAssistance",
    "Helps",
    "ScanDate",
    "SCANORDER",
    "SCAN_UNO",
    "HealedTroops",
    "RangedPoints",
]


def record(gov, scan, date, value=100, rank=1, null_optional=False):
    return [
        rank,
        None if gov == 6 else f"Player {gov} scan {scan}",
        gov,
        value * 100,
        value * 10,
        value,
        1,
        2,
        3,
        value * 3,
        value * 2,
        None if null_optional else value * 5,
        1,
        1,
        date,
        scan,
        gov * 100 + scan,
        None if null_optional else value * 7,
        None if null_optional else value * 11,
    ]


def seed(con, rows):
    sql = (
        "INSERT dbo.KingdomScanData4 ("
        + ",".join(f"[{c}]" for c in COLUMNS)
        + ") VALUES ("
        + ",".join("?" for _ in COLUMNS)
        + ")"
    )
    con.cursor().executemany(sql, rows)


def history_rows():
    rows = []
    ranks = [1, 50, 51, 100, 101, 150, 151, 75]
    for gov, rank in enumerate(ranks, 1):
        for scan, days, value in [
            (1, 800, 123),
            (2, 250, 500),
            (3, 120, 321),
            (4, 40, 890),
            (5, 1, 700),
        ]:
            rows.append(
                record(
                    gov,
                    scan,
                    NOW - timedelta(days=days),
                    value + gov,
                    rank,
                    null_optional=gov in [4, 6] and scan in [1, 5],
                )
            )
    rows.append(record(9, 5, NOW - timedelta(days=800), 25, 30))  # no rolling window
    rows.append(record(10, 5, NOW - timedelta(days=1), 27, 80))  # one scan
    rows.append(record(0, 5, NOW, 99, 1))  # excluded governor
    return rows


def snap(con, tables=OUTPUTS, include_clock=True):
    result = {}
    for table in tables:
        cursor = con.execute(f"SELECT * FROM dbo.[{table}]")
        columns = [c[0] for c in cursor.description]
        indexes = [
            i for i, c in enumerate(columns) if include_clock or c != "LastRunTime"
        ]
        result[table] = (
            [columns[i] for i in indexes],
            Counter(tuple(row[i] for i in indexes) for row in cursor.fetchall()),
        )
    return result


def execute_pair(pair, proc="SUMMARY_PROC"):
    for con in pair:
        con.execute(f"EXEC dbo.[{proc}]")
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
    assert snap(pair[0]) == snap(pair[1])


def test_parent_first_subsequent_correction_and_stale_cache_parity(pair):
    for con in pair:
        seed(con, history_rows())
    execute_pair(pair)
    assert sum(sum(v[1].values()) for v in snap(pair[0], HISTORY).values()) > 0
    assert sum(sum(v[1].values()) for v in snap(pair[1], HISTORY).values()) == 0
    # Copy retained old caches into candidate, then prove the next import ignores
    # them and does not update them. These are newly owned test DBs only.
    for table in HISTORY:
        rows = pair[0].execute(f"SELECT * FROM dbo.[{table}]").fetchall()
        if rows:
            pair[1].cursor().executemany(
                f"INSERT dbo.[{table}] VALUES (" + ",".join("?" for _ in rows[0]) + ")",
                [tuple(r) for r in rows],
            )
    before_caches = snap(pair[1], HISTORY)
    unchanged = (
        pair[1].execute("SELECT * FROM dbo.POWERSUMMARY WHERE GovernorID=2").fetchone()
    )
    for con in pair:
        con.execute(
            "UPDATE dbo.KingdomScanData4 SET Power=7777,Deads=88 WHERE GovernorID=1 AND ScanOrder=1"
        )
        con.execute(
            "UPDATE dbo.KingdomScanData4 SET Power=12345 WHERE GovernorID=2 AND ScanOrder=1"
        )
        seed(con, [record(1, 6, NOW, 250, 51), record(11, 6, NOW, 999, 49)])
    execute_pair(pair)
    assert snap(pair[1], HISTORY) == before_caches
    assert tuple(
        pair[1].execute("SELECT * FROM dbo.POWERSUMMARY WHERE GovernorID=2").fetchone()
    ) == tuple(unchanged)
    assert (
        pair[1]
        .execute("SELECT StartingPower FROM dbo.POWERSUMMARY WHERE GovernorID=1")
        .fetchval()
        == 7777
    )
    before = [snap(c) for c in pair]
    execute_pair(pair)
    assert [snap(c) for c in pair] == before


@pytest.mark.parametrize("proc", NAMES)
def test_direct_entry_parity(pair, proc):
    for con in pair:
        seed(con, history_rows())
    execute_pair(pair, proc)
    for con in pair:
        seed(con, [record(1, 6, NOW, 111, 51)])
    execute_pair(pair, proc)
    before = [snap(c) for c in pair]
    execute_pair(pair, proc)
    assert [snap(c) for c in pair] == before


@pytest.mark.parametrize(
    "months,cutoff",
    [
        (3, datetime(2026, 8, 7, 12)),
        (6, datetime(2026, 5, 7, 12)),
        (12, datetime(2025, 11, 7, 12)),
    ],
)
def test_inclusive_window_boundaries(pair, months, cutoff):
    rows = [
        record(1, 1, cutoff - timedelta(milliseconds=3), 10),
        record(1, 2, cutoff, 100),
        record(1, 3, cutoff + timedelta(milliseconds=3), 150),
        record(1, 4, NOW, 200),
    ]
    for con in pair:
        seed(con, rows)
    execute_pair(pair)
    assert (
        pair[1]
        .execute(
            f"SELECT DeadsDelta{months}Months FROM dbo.DEADSSUMMARY WHERE GovernorID=1"
        )
        .fetchval()
        == 100
    )


@pytest.mark.parametrize(
    "proc", ["SUMMARY_PROC", "DEADSSUMMARY_PROC", "HEALEDSUMMARY_PROC_OPT"]
)
def test_empty_zero_only_and_no_new_scan_time_advance(pair, proc):
    execute_pair(pair, proc)
    for con in pair:
        seed(con, [record(0, 1, NOW)])
    execute_pair(pair, proc)
    for con in pair:
        seed(con, history_rows())
    execute_pair(pair, proc)
    before = [snap(c) for c in pair]
    for candidate, con in enumerate(pair):
        for name in ALL_MODULES:
            con.execute(
                module_body(name, bool(candidate)).replace(
                    "2026-11-07T12:00:00", "2027-04-07T12:00:00"
                )
            )
    execute_pair(pair, proc)
    assert [snap(c) for c in pair] == before


def test_duplicate_latest_rejected_and_parent_rolls_back(pair):
    for con in pair:
        seed(con, history_rows())
    execute_pair(pair)
    before = [snap(c, [t for t in TABLES if t != "KingdomScanData4"]) for c in pair]
    for i, con in enumerate(pair):
        seed(con, [record(1, 6, NOW, 100), record(1, 6, NOW, 200)])
        with pytest.raises(Exception, match=r"(?i)(MERGE|duplicate|unique)"):
            con.execute("EXEC dbo.SUMMARY_PROC")
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
        assert snap(con, [t for t in TABLES if t != "KingdomScanData4"]) == before[i]


def test_identical_historical_ties_and_float_conversion(pair):
    rows = history_rows()
    rows += [
        record(20, 1, NOW - timedelta(days=400), 90071992547410),
        record(20, 1, NOW - timedelta(days=400), 90071992547410),
        record(20, 5, NOW, 90071992547411),
    ]
    for con in pair:
        seed(con, rows)
    execute_pair(pair)


def test_mid_parent_failure_is_atomic(pair):
    for con in pair:
        seed(con, history_rows())
    execute_pair(pair)
    for con in pair:
        seed(con, [record(1, 6, NOW, 888)])
        before = snap(con, [t for t in TABLES if t != "KingdomScanData4"])
        con.execute(
            "CREATE TRIGGER dbo.P021FailSummary ON dbo.HEALEDSUMMARY AFTER INSERT,UPDATE AS BEGIN THROW 51090,'P021 injected summary failure',1; END"
        )
        try:
            with pytest.raises(Exception, match="P021 injected summary failure"):
                con.execute("EXEC dbo.SUMMARY_PROC")
            assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
            assert snap(con, [t for t in TABLES if t != "KingdomScanData4"]) == before
        finally:
            con.execute("DROP TRIGGER dbo.P021FailSummary")


def test_exact_unmodified_bodies_and_caller_permissions(pair):
    for candidate, con in enumerate(pair):
        install_bodies(con, bool(candidate), frozen=False)
        seed(con, history_rows())
        con.execute("EXECUTE AS USER='SummaryFixtureReader'")
        try:
            # Existing parent TRUNCATE requires ALTER; EXECUTE alone is insufficient
            # in both arms. The rewrite must not bypass that boundary.
            with pytest.raises(Exception, match="SUMMARY_CHANGE_EXPORT"):
                con.execute("EXEC dbo.SUMMARY_PROC")
        finally:
            con.execute("REVERT")
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
        assert not con.execute("SELECT 1 FROM dbo.SUMMARY_PROC_STATE").fetchall()
        con.execute("GRANT ALTER ON dbo.SUMMARY_CHANGE_EXPORT TO SummaryFixtureReader")
        con.execute("EXECUTE AS USER='SummaryFixtureReader'")
        try:
            con.execute("EXEC dbo.SUMMARY_PROC")
        finally:
            con.execute("REVERT")
            con.execute(
                "REVOKE ALTER ON dbo.SUMMARY_CHANGE_EXPORT FROM SummaryFixtureReader"
            )
    assert snap(pair[0], include_clock=False) == snap(pair[1], include_clock=False)


def run_bundle(con, filename):
    cursor = con.execute((PACK / filename).read_text(encoding="utf-8"))
    while cursor.nextset():
        pass
    assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0


def definitions(con):
    return {
        n: re.sub(
            r"\ACREATE(?: OR ALTER)? PROCEDURE",
            "ALTER PROCEDURE",
            con.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(?))", "dbo." + n)
            .fetchval()
            .replace("\r\n", "\n")
            .strip(),
        )
        for n in NAMES
    }


def test_local_install_repeat_rollback_freshness_and_grants(pair):
    for con in pair:
        install_bodies(con, False, frozen=False)
        seed(con, history_rows())
        con.execute("EXEC dbo.SUMMARY_PROC")
    baseline, candidate = pair
    run_bundle(candidate, "install.sql")
    assert definitions(candidate) == {n: source(n) for n in NAMES}
    run_bundle(candidate, "install.sql")
    old_caches = snap(candidate, HISTORY)
    for con in pair:
        seed(con, [record(gov, 6, NOW, 500 + gov) for gov in range(1, 12)])
        con.execute("EXEC dbo.SUMMARY_PROC")
    assert snap(baseline, include_clock=False) == snap(candidate, include_clock=False)
    assert snap(candidate, HISTORY) == old_caches
    outputs = snap(candidate)
    run_bundle(candidate, "rollback.sql")
    assert definitions(candidate) == LEGACY
    assert snap(candidate) == outputs  # no watermark rewind or output re-execution
    assert snap(candidate, HISTORY) == snap(baseline, HISTORY)
    run_bundle(candidate, "rollback.sql")
    assert snap(candidate) == outputs
    assert (
        candidate.execute(
            "SELECT COUNT(*) FROM sys.database_permissions WHERE grantee_principal_id=USER_ID('SummaryFixtureReader') AND permission_name='EXECUTE'"
        ).fetchval()
        == 10
    )
    run_bundle(candidate, "install.sql")


@pytest.mark.parametrize("filename", ["install.sql", "rollback.sql"])
def test_local_bundle_rejects_drift_and_wrong_owner_atomically(pair, filename):
    con = pair[1]
    install_bodies(con, False, frozen=False)
    before = definitions(con)
    token = con.execute(
        "SELECT CONVERT(nvarchar(32),SESSION_CONTEXT(N'P021SummaryFixtureOwner'))"
    ).fetchval()
    try:
        con.execute(
            "EXEC sys.sp_set_session_context @key=N'P021SummaryFixtureOwner',@value=N'wrong'"
        )
        with pytest.raises(Exception, match="ownership token"):
            run_bundle(con, filename)
        assert definitions(con) == before
    finally:
        con.execute(
            "EXEC sys.sp_set_session_context @key=N'P021SummaryFixtureOwner',@value=?",
            token,
        )
    con.execute("ALTER PROCEDURE dbo.RANGEDSUMMARY_PROC AS SELECT 98765;")
    before = definitions(con)
    with pytest.raises(Exception, match="Unrecognized summary definition"):
        run_bundle(con, filename)
    assert definitions(con) == before
    assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0


def test_rollback_failure_restores_candidate_and_keeps_watermarks(pair):
    con = pair[1]
    install_bodies(con, True, frozen=False)
    seed(con, history_rows())
    con.execute("EXEC dbo.SUMMARY_PROC")
    before_bodies = definitions(con)
    before_data = snap(con, [t for t in TABLES if t != "KingdomScanData4"])
    con.execute(
        "CREATE TRIGGER dbo.P021FailCache ON dbo.HEALED_ALL AFTER INSERT AS BEGIN THROW 51091,'P021 injected cache rebuild failure',1; END"
    )
    try:
        with pytest.raises(Exception, match="P021 injected cache rebuild failure"):
            run_bundle(con, "rollback.sql")
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
        assert definitions(con) == before_bodies
        assert snap(con, [t for t in TABLES if t != "KingdomScanData4"]) == before_data
    finally:
        con.execute("DROP TRIGGER dbo.P021FailCache")


@pytest.mark.parametrize("filename", ["install.sql", "rollback.sql"])
def test_local_bundle_wrong_database_and_execution_context_refused(pair, filename):
    con = pair[1]
    install_bodies(con, False, frozen=False)
    name = con.execute("SELECT DB_NAME()").fetchval()
    try:
        con.execute("USE master")
        with pytest.raises(Exception, match="not an owned local fixture"):
            run_bundle(con, filename)
    finally:
        con.execute(f"USE [{name}]")
    con.execute(
        LEGACY["RANGEDSUMMARY_PROC"].replace("EXECUTE AS CALLER", "EXECUTE AS OWNER")
    )
    before = definitions(con)
    with pytest.raises(Exception, match="execution context or options"):
        run_bundle(con, filename)
    assert definitions(con) == before


@pytest.mark.parametrize("filename", ["install.sql", "rollback.sql"])
def test_local_bundle_signed_module_refused(pair, filename):
    con = pair[1]
    install_bodies(con, False, frozen=False)
    con.execute(
        "CREATE CERTIFICATE P021FixtureCert ENCRYPTION BY PASSWORD='FixtureOnly_7N!k2xR' WITH SUBJECT='Disposable summary test';"
    )
    con.execute(
        "ADD SIGNATURE TO dbo.DEADSSUMMARY_PROC BY CERTIFICATE P021FixtureCert WITH PASSWORD='FixtureOnly_7N!k2xR';"
    )
    before = definitions(con)
    try:
        with pytest.raises(Exception, match="Signed summary module"):
            run_bundle(con, filename)
        assert definitions(con) == before
        assert (
            con.execute(
                "SELECT COUNT(*) FROM sys.crypt_properties WHERE major_id=OBJECT_ID('dbo.DEADSSUMMARY_PROC')"
            ).fetchval()
            == 1
        )
    finally:
        con.execute(
            "DROP SIGNATURE FROM dbo.DEADSSUMMARY_PROC BY CERTIFICATE P021FixtureCert;"
        )
        con.execute("DROP CERTIFICATE P021FixtureCert;")


def test_healed_opt_then_parent_no_stale_cache_dependency(pair):
    for con in pair:
        seed(con, history_rows())
    execute_pair(pair)
    for con in pair:
        seed(con, [record(1, 6, NOW, 555)])
    execute_pair(pair, "HEALEDSUMMARY_PROC_OPT")
    execute_pair(pair)
    for con in pair:
        seed(con, [record(1, 7, NOW, 333)])
    execute_pair(pair)
    execute_pair(pair, "HEALEDSUMMARY_PROC_OPT")
