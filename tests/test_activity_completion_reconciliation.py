"""Opt-in SQL engine rehearsal using session-local tables; no installed changes."""

import os
from pathlib import Path
from uuid import uuid4

import pytest

pytestmark = pytest.mark.skipif(
    os.getenv("K98_ACTIVITY_SQL_TESTS") != "1",
    reason="Explicit disposable local SQL opt-in",
)
ROOT = Path(__file__).resolve().parents[1]


def rewrite(text):
    for name in (
        "AllianceActivitySnapshotHeader",
        "AllianceActivitySnapshotRow",
        "usp_SetAllianceActivitySnapshotCompletion",
    ):
        text = text.replace("dbo." + name, "#" + name).replace(
            "[dbo].[" + name + "]", "#" + name
        )
    return text


@pytest.fixture
def sql():
    import pyodbc

    cxn = pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost\\K98DEV;"
        "DATABASE=master;Trusted_Connection=yes;TrustServerCertificate=yes",
        autocommit=True,
    )
    try:
        for name in ("AllianceActivitySnapshotHeader", "AllianceActivitySnapshotRow"):
            source = (ROOT / "sql_schema" / ("dbo." + name + ".Table.sql")).read_text(
                encoding="utf-8-sig"
            )
            body = source[source.index("CREATE TABLE") : source.index("\nEND")]
            # Table definition, keys and nullability are source-owned; indexes after END are irrelevant.
            cxn.execute(rewrite(body))
        source = (
            ROOT
            / "sql_schema/dbo.usp_SetAllianceActivitySnapshotCompletion.StoredProcedure.sql"
        ).read_text(encoding="utf-8-sig")
        cxn.execute(rewrite(source[source.index("CREATE OR ALTER PROCEDURE") :]))
        yield cxn
    finally:
        cxn.close()


def add(
    cxn,
    *,
    source=2,
    observed=2,
    missing=1,
    metric=0,
    invalid=0,
    basis="SOURCE_VALIDATED",
    stored=2,
):
    sid = cxn.execute(
        """INSERT #AllianceActivitySnapshotHeader
        (SnapshotTsUtc,WeekStartUtc,SourceFileName,SourceFileSha1,Row_Count,CreatedUtc,
        CompletionState,ExpectedGovernorCount,ObservedGovernorCount,MissingExpectedGovernorCount,
        MissingMetricCount,InvalidMetricCount,ValidatedAtUtc,CompletionBasis)
        OUTPUT inserted.SnapshotId VALUES (GETUTCDATE(),GETUTCDATE(),'fixture',?, ?, GETUTCDATE(),
        'PARTIAL',4,?,?,?,?,GETUTCDATE(),?)""",
        uuid4().bytes + b"test",
        source,
        observed,
        missing,
        metric,
        invalid,
        basis,
    ).fetchval()
    for i in range(stored):
        cxn.execute(
            "INSERT #AllianceActivitySnapshotRow(SnapshotId,GovernorID,BuildingTotal,TechDonationTotal) VALUES (?,?,10,20)",
            sid,
            i + 1,
        )
    return sid


def run(cxn, apply):
    script = rewrite(
        (
            ROOT / "deploy/recovery/activity_snapshot_completion_20261027/reconcile.sql"
        ).read_text()
    )
    script = script.replace(
        "DECLARE @Apply bit = 0;", f"DECLARE @Apply bit = {int(apply)};"
    )
    cur = cxn.execute(script)
    results = []
    while True:
        if cur.description:
            results.append([tuple(r) for r in cur.fetchall()])
        if not cur.nextset():
            break
    return results


def test_preview_apply_and_repeat_preserve_business_rows(sql):
    add(sql)
    sql.execute("UPDATE #AllianceActivitySnapshotHeader SET ValidatedAtUtc='2020-01-01'")
    original = [
        tuple(r)
        for r in sql.execute("SELECT * FROM #AllianceActivitySnapshotRow").fetchall()
    ]
    assert len(run(sql, False)[0]) == 1
    assert (
        sql.execute(
            "SELECT CompletionState FROM #AllianceActivitySnapshotHeader"
        ).fetchval()
        == "PARTIAL"
    )
    result = run(sql, True)
    assert len(result[0]) == 1
    assert result[0][0][-1].year == 2020  # Original evidence is returned for the audit.
    assert result[1][0][-2].year > 2020  # Current stored-row revalidation time.
    assert tuple(
        sql.execute(
            "SELECT CompletionState,ExpectedGovernorCount,ObservedGovernorCount,MissingExpectedGovernorCount FROM #AllianceActivitySnapshotHeader"
        ).fetchone()
    ) == ("COMPLETE", 2, 2, 0)
    assert [
        tuple(r)
        for r in sql.execute("SELECT * FROM #AllianceActivitySnapshotRow").fetchall()
    ] == original
    assert run(sql, True)[0] == []


@pytest.mark.parametrize(
    "options",
    [
        dict(source=3),
        dict(observed=1),
        dict(stored=1),
        dict(metric=1),
        dict(invalid=1),
        dict(basis="LEGACY_ASSUMED_ZERO"),
        dict(missing=0),
    ],
)
def test_incomplete_or_unverifiable_snapshot_is_never_relabelled(sql, options):
    add(sql, **options)
    assert run(sql, True)[0] == []
    assert (
        sql.execute(
            "SELECT CompletionState FROM #AllianceActivitySnapshotHeader"
        ).fetchval()
        == "PARTIAL"
    )


def test_negative_stored_metric_is_not_certified_by_header(sql):
    add(sql)
    sql.execute(
        "UPDATE #AllianceActivitySnapshotRow SET BuildingTotal=-1 WHERE GovernorID=1"
    )
    assert run(sql, True)[0] == []


def test_missing_original_source_hash_is_not_relabelled(sql):
    add(sql)
    sql.execute("UPDATE #AllianceActivitySnapshotHeader SET SourceFileSha1=NULL")
    assert run(sql, True)[0] == []


def test_failed_second_completion_rolls_back_first(sql):
    add(sql)
    add(sql)
    source = (
        ROOT
        / "sql_schema/dbo.usp_SetAllianceActivitySnapshotCompletion.StoredProcedure.sql"
    ).read_text(encoding="utf-8-sig")
    source = rewrite(source[source.index("CREATE OR ALTER PROCEDURE") :])
    source = source.replace(
        "    SET NOCOUNT ON;",
        "    IF @SnapshotID=2 THROW 51112, 'Injected fixture failure', 1;\n    SET NOCOUNT ON;",
        1,
    )
    sql.execute(source)
    with pytest.raises(Exception, match="Injected fixture failure"):
        run(sql, True)
    assert [
        r[0]
        for r in sql.execute(
            "SELECT CompletionState FROM #AllianceActivitySnapshotHeader"
        )
    ] == ["PARTIAL", "PARTIAL"]
    assert sql.execute("SELECT @@TRANCOUNT").fetchval() == 0
