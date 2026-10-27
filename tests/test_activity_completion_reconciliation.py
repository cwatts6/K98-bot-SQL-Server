"""Opt-in SQL engine rehearsal using session-local tables; no installed changes."""

import os
from pathlib import Path

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
        bytes(range(20)),
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
    assert len(run(sql, True)[0]) == 1
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
