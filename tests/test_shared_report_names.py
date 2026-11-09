"""Shared display-name contract on new, uniquely owned local SQL fixtures."""

from collections import Counter
from pathlib import Path
import json
import os
import re
import uuid

import pytest

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "qualification/p02_report_names"
SOURCES = json.loads((PACK / "reviewed_sources.json").read_text())
TARGETS = json.loads((PACK / "targets.json").read_text())


def batches(text):
    return [p for p in re.split(r"(?im)^GO\s*$", text) if p.strip()]


@pytest.fixture(scope="module")
def database():
    if os.getenv("K98_REPORT_NAMES_SQL_TESTS") != "CREATE_DISPOSABLE_LOCAL_ONLY":
        pytest.skip("New disposable local database opt-in required")
    import pyodbc

    pyodbc.pooling = False
    base = "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost\\K98DEV;Trusted_Connection=yes;Encrypt=no;APP=P02ReportNames;"
    master = pyodbc.connect(base + "DATABASE=master", autocommit=True, timeout=5)
    token = uuid.uuid4().hex
    name = "K98_P02_ReportNames_" + token
    cn = None
    created = False
    try:
        assert (
            master.execute(
                "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))"
            ).fetchval()
            == "9SX2VF4\\K98DEV"
        )
        master.execute(f"CREATE DATABASE [{name}] COLLATE Latin1_General_CI_AS")
        created = True
        cn = pyodbc.connect(base + f"DATABASE={name}", autocommit=True, timeout=5)
        cn.timeout = 15
        cn.execute(
            "EXEC sys.sp_addextendedproperty @name=N'P02ReportNameFixtureOwner',@value=?",
            token,
        )
        cn.execute(
            "CREATE TABLE dbo.KingdomScanData4(GovernorID bigint,GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS,ScanOrder int)"
        )
        for table, ident, label in TARGETS.values():
            cn.execute(
                f"CREATE TABLE dbo.[{table}]([{ident}] bigint NULL,[{label}] nvarchar(255) NULL,Metric bigint NULL,Ordinal int NOT NULL)"
            )
        cn.execute(
            "CREATE TABLE dbo.RALLY_EXPORT(GOVENOR nvarchar(4000) NOT NULL,RALLY_LAUNCHED int NOT NULL,RALLY_JOINED int NULL,TOTAL_RALLIES_COMPLETED int NULL)"
        )
        for file in [
            "dbo.v_ReportGovernorNames.View.sql",
            "dbo.usp_ApplyReportGovernorNames.StoredProcedure.sql",
        ]:
            for batch in batches((ROOT / "sql_schema" / file).read_text()):
                cn.execute(batch)
        yield cn
    finally:
        if cn:
            if cn.execute("SELECT @@TRANCOUNT").fetchval():
                cn.execute("ROLLBACK")
            cn.close()
        if created:
            assert (
                master.execute(
                    f"SELECT CONVERT(nvarchar(32),value) FROM [{name}].sys.extended_properties WHERE class=0 AND name='P02ReportNameFixtureOwner'"
                ).fetchval()
                == token
            )
            master.execute(f"DROP DATABASE [{name}]")
        master.close()


@pytest.fixture
def db(database):
    cn = database
    cn.execute("DELETE dbo.KingdomScanData4;DELETE dbo.RALLY_EXPORT")
    for table, ident, label in TARGETS.values():
        cn.execute(f"DELETE dbo.[{table}]")
    history = [
        (1, "Old", 1),
        (1, "Newest", 2),
        (1, None, 3),
        (1, "   ", 4),
        (2, "same", 1),
        (3, "same", 1),
        (4, "Umhie", 1),
        (4, "Umhie\u1d3e\u1d34", 2),
        (5, "alpha", 7),
        (5, "Alpha", 7),
        (5, "Alpha ", 7),
        (0, "zero", 9),
        (999999997, "Wrong aggregate", 9),
    ]
    cn.cursor().executemany("INSERT dbo.KingdomScanData4 VALUES(?,?,?)", history)
    rows = [
        (1, "Old", 9007199254740993, 1),
        (1, "Older", -5, 2),
        (2, "old2", None, 3),
        (3, "old3", 12, 4),
        (4, "Umhie", 42, 5),
        (5, "old5", 0, 6),
        (88, "Unknown preserved", 100, 7),
        (999999997, "Top50", 200, 8),
        (None, "No identity", 0, 9),
        (0, "Zero", 1, 10),
    ]
    for table, ident, label in TARGETS.values():
        cn.cursor().executemany(f"INSERT dbo.[{table}] VALUES(?,?,?,?)", rows)
    yield cn
    if cn.execute("SELECT @@TRANCOUNT").fetchval():
        cn.execute("ROLLBACK")
    cn.execute("DROP TABLE IF EXISTS #P02ReportNames")


def actual(cn, table):
    return [
        tuple(r) for r in cn.execute(f"SELECT * FROM dbo.[{table}] ORDER BY Ordinal")
    ]


def test_canonical_latest_nonempty_unicode_ties_and_unique_identity(db):
    assert sorted(
        tuple(r) for r in db.execute("SELECT * FROM dbo.v_ReportGovernorNames")
    ) == [
        (1, "Newest"),
        (2, "same"),
        (3, "same"),
        (4, "Umhie\u1d3e\u1d34"),
        (5, "Alpha"),
    ]
    db.execute(
        "SELECT * INTO #Copy FROM dbo.KingdomScanData4;DELETE dbo.KingdomScanData4;INSERT dbo.KingdomScanData4 SELECT * FROM #Copy ORDER BY ScanOrder DESC,GovernorName DESC;DROP TABLE #Copy"
    )
    assert (
        db.execute(
            "SELECT GovernorName FROM dbo.v_ReportGovernorNames WHERE GovernorID=5"
        ).fetchval()
        == "Alpha"
    )


@pytest.mark.parametrize("target", list(TARGETS))
def test_target_changes_names_only_and_no_other_report(db, target):
    before = {n: actual(db, n) for n in TARGETS}
    db.execute("EXEC dbo.usp_ApplyReportGovernorNames @Report=?", target)
    for table in TARGETS:
        after = actual(db, table)
        assert [(r[0], r[2], r[3]) for r in after] == [
            (r[0], r[2], r[3]) for r in before[table]
        ]
        if table != target:
            assert after == before[table]
        else:
            assert [r[1] for r in after] == [
                "Newest",
                "Newest",
                "same",
                "same",
                "Umhie\u1d3e\u1d34",
                "Alpha",
                "Unknown preserved",
                "Top50",
                "No identity",
                "Zero",
            ]


def test_completed_batch_includes_rally_suffix_and_preserves_malformed_rows(db):
    rows = [
        ("Old (1)", 4, 5, 9),
        ("Name (with brackets) (4)", 1, 2, 3),
        ("Unknown (88)", 1, None, 1),
        ("bad (1) junk", 1, 2, 3),
        ("Name(1)", 1, 2, 3),
        ("Name (01)", 1, 2, 3),
        ("(", 1, 2, 3),
        (")", 1, 2, 3),
        ("empty", 1, 2, 3),
    ]
    db.cursor().executemany("INSERT dbo.RALLY_EXPORT VALUES(?,?,?,?)", rows)
    db.execute("EXEC dbo.usp_ApplyReportGovernorNames N'CompletedReports'")
    after = [tuple(r) for r in db.execute("SELECT * FROM dbo.RALLY_EXPORT")]
    assert Counter(r[1:] for r in after) == Counter(r[1:] for r in rows)
    assert Counter(r[0] for r in after) == Counter(
        ["Newest (1)", "Umhie\u1d3e\u1d34 (4)"] + [r[0] for r in rows[2:]]
    )
    for table in TARGETS:
        assert actual(db, table)[0][1] == "Newest"


def test_one_batch_list_is_stable_then_standalone_uses_new_name(db):
    db.execute("SELECT * INTO #P02ReportNames FROM dbo.v_ReportGovernorNames")
    db.execute("INSERT dbo.KingdomScanData4 VALUES(1,N'Later',8)")
    db.execute("EXEC dbo.usp_ApplyReportGovernorNames N'CompletedReports'")
    assert actual(db, "POWER_BY_MONTH")[0][1] == "Newest"
    db.execute("DROP TABLE #P02ReportNames")
    db.execute("EXEC dbo.usp_ApplyReportGovernorNames N'POWER_BY_MONTH'")
    assert actual(db, "POWER_BY_MONTH")[0][1] == "Later"


@pytest.mark.parametrize(
    "target", [None, "", "POWER_BY_MONTH; DELETE dbo.KingdomScanData4", "unknown"]
)
def test_unreviewed_target_is_rejected_without_changes(db, target):
    before = actual(db, "POWER_BY_MONTH")
    with pytest.raises(Exception, match="Unknown report name target"):
        db.execute("EXEC dbo.usp_ApplyReportGovernorNames @Report=?", target)
    assert actual(db, "POWER_BY_MONTH") == before


def test_name_publication_rolls_back_with_caller(db):
    before = actual(db, "POWER_BY_MONTH")
    db.execute("BEGIN TRANSACTION")
    db.execute("EXEC dbo.usp_ApplyReportGovernorNames N'CompletedReports'")
    assert actual(db, "POWER_BY_MONTH") != before
    db.execute("ROLLBACK")
    assert actual(db, "POWER_BY_MONTH") == before


def test_execute_permission_does_not_require_direct_source_access(db):
    db.execute(
        "CREATE USER NameReportReader WITHOUT LOGIN; GRANT EXECUTE ON dbo.usp_ApplyReportGovernorNames TO NameReportReader"
    )
    try:
        db.execute("EXECUTE AS USER='NameReportReader'")
        db.execute("EXEC dbo.usp_ApplyReportGovernorNames N'POWER_BY_MONTH'")
        with pytest.raises(Exception):
            db.execute("SELECT * FROM dbo.KingdomScanData4").fetchall()
    finally:
        db.execute("REVERT; DROP USER NameReportReader")
    assert actual(db, "POWER_BY_MONTH")[0][1] == "Newest"


def test_monthly_existing_groups_and_exact_numbers_survive_shared_names(db):
    db.execute(
        "CREATE TABLE #Monthly(GovernorID bigint,GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS,Power bigint,MonthEnd date)"
    )
    db.cursor().executemany(
        "INSERT #Monthly VALUES(?,?,?,?)",
        [
            (4, "Umhie", 3, "2024-09-30"),
            (4, "Umhie\u1d3e\u1d34", 10, "2024-09-30"),
            (4, "Older alias", 9007199254740993, "2024-09-30"),
            (2, "same", 12, "2024-09-30"),
        ],
    )
    old = [
        tuple(r)
        for r in db.execute(
            "SELECT GovernorID,GovernorName,MAX(Power),MonthEnd FROM #Monthly GROUP BY GovernorID,GovernorName,MonthEnd"
        )
    ]
    db.execute("DELETE dbo.POWER_BY_MONTH")
    for i, r in enumerate(old):
        db.execute("INSERT dbo.POWER_BY_MONTH VALUES(?,?,?,?)", r[0], r[1], r[2], i)
    db.execute("EXEC dbo.usp_ApplyReportGovernorNames N'POWER_BY_MONTH'")
    new = actual(db, "POWER_BY_MONTH")
    assert len(old) == len(new) == 3
    assert Counter((r[0], r[2]) for r in old) == Counter((r[0], r[2]) for r in new)
    assert [r[1] for r in new if r[0] == 4] == ["Umhie\u1d3e\u1d34"] * 2
    db.execute("DROP TABLE #Monthly")
