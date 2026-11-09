"""Execute the actual numeric summary package with and without shared names."""

import sys
from pathlib import Path
import json
import re
from collections import Counter

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
import test_phase1_summary as numeric
import test_summary_endpoints as ref

SOURCES = json.loads(
    (ROOT / "qualification/p02_report_names/reviewed_sources.json").read_text()
)


def install_new(con):
    for name in [
        "dbo.v_ReportGovernorNames.View.sql",
        "dbo.usp_ApplyReportGovernorNames.StoredProcedure.sql",
    ]:
        for sql in re.split(r"(?im)^GO\s*$", SOURCES[name]["after"]):
            if sql.strip():
                con.execute(sql)
    for name in ref.ALL_MODULES:
        text = SOURCES[f"dbo.{name}.StoredProcedure.sql"]["after"]
        text = text[text.index("ALTER PROCEDURE [dbo].") :]
        text = text.replace(
            "SYSUTCDATETIME()", "CONVERT(datetime2(7),'2026-11-07T12:00:00',126)"
        )
        con.execute(text)


@pytest.fixture(scope="module")
def databases():
    generator = numeric.databases.__wrapped__()
    pair = next(generator)
    try:
        numeric.upgrade.apply(pair[0])
        yield pair
    finally:
        try:
            next(generator)
        except StopIteration:
            pass


@pytest.fixture
def pair(databases):
    for con in databases:
        if con.execute("SELECT @@TRANCOUNT").fetchval():
            con.execute("ROLLBACK")
        con.execute("DROP TABLE IF EXISTS #P02ReportNames")
        for table in ref.TABLES + ["ALL_GOVS_NAMES"]:
            con.execute(f"TRUNCATE TABLE dbo.[{table}]")
        numeric.install(con, True)
        ref.seed(con, ref.history_rows())
        con.execute(
            "UPDATE dbo.KingdomScanData4 SET GovernorName=N'Known earlier' WHERE GovernorID=1 AND ScanOrder<5; UPDATE dbo.KingdomScanData4 SET GovernorName=NULL WHERE GovernorID=1 AND ScanOrder=5"
        )
    install_new(databases[1])
    return databases


@pytest.mark.parametrize("proc", ref.ALL_MODULES)
def test_actual_summary_entry_preserves_every_numeric_cell_and_row(pair, proc):
    for con in pair:
        con.execute(f"EXEC dbo.[{proc}]")
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
    for table in ref.OUTPUTS:
        oldcols, oldrows = numeric.rows(pair[0], table)
        cols, rows = numeric.rows(pair[1], table)
        assert oldcols == cols
        keep = [
            i
            for i, c in enumerate(cols)
            if c.lower() not in ["governorname", "lastruntime"]
        ]
        assert Counter(tuple(r[i] for i in keep) for r in oldrows) == Counter(
            tuple(r[i] for i in keep) for r in rows
        ), table
    targets = {
        "SUMMARY_PROC": "SUMMARY_CHANGE_EXPORT",
        "HEALEDSUMMARY_PROC_OPT": "HEALEDSUMMARY",
    }
    targets.update(dict(zip(ref.NAMES[:8], numeric.SUMMARY_TABLES)))
    # Explicit mapping avoids depending on source inventory ordering.
    targets.update(
        DEADSSUMMARY_PROC="DEADSSUMMARY",
        POWERSUMMARY_PROC="POWERSUMMARY",
        KILLSSUMMARY_PROC="KILLSUMMARY",
        KT4SUMMARY_PROC="KILL4SUMMARY",
        KT5SUMMARY_PROC="KILL5SUMMARY",
        KILLPOINTSSUMMARY_PROC="KILLPOINTSSUMMARY",
        HEALEDSUMMARY_PROC="HEALEDSUMMARY",
        RANGEDSUMMARY_PROC="RANGEDSUMMARY",
    )
    assert (
        pair[1]
        .execute(
            f"SELECT RTRIM(GovernorName) FROM dbo.[{targets[proc]}] WHERE GovernorID=1"
        )
        .fetchval()
        == "Known earlier"
    )
    before = ref.snap(pair[1])
    pair[1].execute(f"EXEC dbo.[{proc}]")
    assert ref.snap(pair[1]) == before


def test_actual_parent_uses_one_shared_batch_name_list(pair):
    con = pair[1]
    con.execute("SELECT * INTO #P02ReportNames FROM dbo.v_ReportGovernorNames")
    con.execute(
        "UPDATE dbo.KingdomScanData4 SET GovernorName=N'Changed after list' WHERE GovernorID=1"
    )
    con.execute("EXEC dbo.SUMMARY_PROC")
    for table in [*numeric.SUMMARY_TABLES, "SUMMARY_CHANGE_EXPORT"]:
        assert (
            con.execute(
                f"SELECT RTRIM(GovernorName) FROM dbo.[{table}] WHERE GovernorID=1"
            ).fetchval()
            == "Known earlier"
        )
    con.execute("DROP TABLE #P02ReportNames")
