"""Opt-in engine regressions using source-defined session-local tables only.

K98_PERSONAL_STATS_SQL_TESTS=1 and K98_PERSONAL_STATS_SQL_DATABASE must identify
an already-authorized local disposable database containing dbo.IntList. No
permanent source tables, stored procedures or database settings are modified.
"""

import os
from pathlib import Path
import re
from uuid import uuid4

import pytest

ROOT = Path(__file__).resolve().parents[1]
pytestmark = pytest.mark.skipif(
    os.getenv("K98_PERSONAL_STATS_SQL_TESTS") != "1",
    reason="Explicit disposable SQL engine opt-in required",
)


@pytest.fixture
def sql():
    import pyodbc

    database = os.environ["K98_PERSONAL_STATS_SQL_DATABASE"]
    assert re.fullmatch(r"K98_P016_Disposable_[0-9]{8}_[0-9a-f]{8}", database)
    pyodbc.pooling = False
    connection = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};SERVER=lpc:localhost\\K98DEV;"
        "Trusted_Connection=yes;TrustServerCertificate=yes;DATABASE=" + database,
        timeout=5,
        autocommit=False,
    )
    connection.timeout = 15
    try:
        identity = connection.execute(
            "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME(),TYPE_ID('dbo.IntList')"
        ).fetchone()
        assert (
            identity[0] == r"9SX2VF4\K98DEV" and identity[1] == database and identity[2]
        )
        for name in (
            "KingdomScanData4",
            "AllianceActivitySnapshotHeader",
            "AllianceActivitySnapshotRow",
            "cur_RallyDaily",
        ):
            source = (ROOT / "sql_schema" / ("dbo." + name + ".Table.sql")).read_text(
                encoding="utf-8-sig"
            )
            body = source[source.index("CREATE TABLE") : source.index("\nEND")]
            body = body.replace("[dbo].[" + name + "]", "[#" + name + "]")
            suffix = uuid4().hex
            body = re.sub(
                r"CONSTRAINT \[([^]]+)\]",
                lambda m: "CONSTRAINT [P016_" + suffix + "_" + m[1] + "]",
                body,
            )
            connection.execute(body)
        yield connection
    finally:
        connection.rollback()
        connection.close()


def execute(connection, ids, days, baseline=False):
    if baseline:
        rollback = (
            ROOT
            / "migrations/rollback/20261106_001_personal_stats_daily_read_plan_rollback.sql"
        ).read_text()
        source = re.findall(r"EXEC\s+sys\.sp_executesql\s+N'((?:[^']|'')*)'", rollback)[
            0
        ].replace("''", "'")
    else:
        source = (
            ROOT / "sql_schema/dbo.usp_GetPersonalStatsDaily.StoredProcedure.sql"
        ).read_text(encoding="utf-8-sig")
    body = source[source.index("\nAS\n") + 4 :].strip().removesuffix("GO").strip()
    for name in (
        "KingdomScanData4",
        "AllianceActivitySnapshotHeader",
        "AllianceActivitySnapshotRow",
        "cur_RallyDaily",
    ):
        body = body.replace("dbo." + name, "#" + name)
    placeholders = ",".join("(?)" for _ in ids)
    insert = "INSERT @ids VALUES " + placeholders + ";" if ids else ""
    cursor = connection.cursor()
    try:
        cursor.execute(
            "DECLARE @ids dbo.IntList;"
            + insert
            + "EXEC sys.sp_executesql ?,N'@GovernorIDs dbo.IntList READONLY,@HistoryDays smallint',@ids,?;",
            (*ids, body, days),
        )
        result = []
        while True:
            if cursor.description:
                columns = [d[0] for d in cursor.description]
                result.append([dict(zip(columns, row)) for row in cursor.fetchall()])
            if not cursor.nextset():
                break
        return result
    finally:
        cursor.close()


def seed(connection):
    for governor, stamp, order, uno, power, troop, rss, healed in (
        (1, "2026-01-01T12:00:00", 1, 1, 100, 100.75, 10, 10),
        (1, "2026-04-01T12:00:00", 2, 2, 200, 150.75, None, 5),
        (1, "2026-04-02T18:00:00", 3, 3, 230, 170.75, 20, 3),
        (1, "2026-04-02T18:00:00", 4, 4, 240, 180.75, 30, 2),
        (1, "2026-04-02T18:00:00", 4, 5, 250, None, 40, 1),
        (99, "2026-04-03T20:00:00", 5, 6, 900, 500.0, 100, 100),
    ):
        connection.execute(
            """INSERT #KingdomScanData4
            (GovernorID,ScanDate,SCANORDER,SCAN_UNO,Power,[Troops Power],RSS_Gathered,HealedTroops,
             PowerRank,KillPoints,Deads,T1_Kills,T2_Kills,T3_Kills,T4_Kills,T5_Kills,RSSAssistance,Helps)
            VALUES (?,?,?,?,?,?,?,?,1,10,10,1,2,3,4,5,10,10)""",
            governor,
            stamp,
            order,
            uno,
            power,
            troop,
            rss,
            healed,
        )
    for sid, stamp, week, building in (
        (1, "2026-04-01T12:00:00", "2026-03-30", 100),
        (2, "2026-04-02T12:00:00", "2026-03-30", 125),
        (3, "2026-04-03T12:00:00", "2026-03-30", 140),
        (4, "2026-04-03T12:00:00", "2026-03-30", 150),
        (5, "2026-04-03T12:00:00", "2026-04-03", 7),
    ):
        connection.execute(
            """INSERT #AllianceActivitySnapshotHeader
            (SnapshotTsUtc,WeekStartUtc,SourceFileName,SourceFileSha1,CreatedUtc,CompletionState)
            VALUES (?,?,N'Synthetic regression',?,SYSUTCDATETIME(),N'PARTIAL')""",
            stamp,
            week,
            bytes(f"{sid:020d}", "ascii"),
        )
        connection.execute(
            "INSERT #AllianceActivitySnapshotRow(SnapshotId,GovernorID,BuildingTotal,TechDonationTotal) VALUES (?,2,?,?)",
            sid,
            building,
            building,
        )
    connection.execute(
        "INSERT #cur_RallyDaily(AsOfDate,GovernorID,TotalRallies,RalliesLaunched,RalliesJoined,InsertedAt) VALUES ('2026-04-03',3,4,1,3,SYSUTCDATETIME())"
    )


@pytest.mark.parametrize("days", [1, 2, 7, 90, 180])
@pytest.mark.parametrize("ids", [[1], [1, 2, 3], list(range(1, 27))])
def test_sparse_day_end_and_weekly_contract(sql, ids, days):
    seed(sql)
    actual = execute(sql, ids, days)
    assert actual == execute(sql, ids, days, baseline=True)
    assert str(actual[0][0]["StatsAnchorDate"]) == "2026-04-03"
    assert actual[0][0]["RequestedGovernorCount"] == len(ids)
    rows = {(r["GovernorID"], str(r["AsOfDate"])): r for r in actual[1]}
    if days >= 2:
        row = rows[(1, "2026-04-02")]
        assert row["PowerValue"] == 250 and row["PowerDelta"] == 50
        assert row["TroopPowerDelta"] is None and row["RSSGatheredDelta"] is None
        assert row["HealedTroopsDelta"] == -4
        assert str(row["PreviousStatsDate"]) == "2026-04-01"
    if 2 in ids:
        activity = rows[(2, "2026-04-03")]
        assert not activity["HasStats"] and activity["HasAllianceActivity"]
        assert activity["BuildActivityDelta"] == 32
        assert str(activity["PreviousActivityDate"]) == "2026-04-02"
    if 3 in ids:
        assert rows[(3, "2026-04-03")]["FortsTotal"] == 4


def test_empty_stats_anchor(sql):
    result = execute(sql, [1, 2, 3], 180)
    assert result == execute(sql, [1, 2, 3], 180, baseline=True)
    assert result[0][0]["StatsAnchorDate"] is None and result[1] == []


@pytest.mark.parametrize(
    "ids,days,code",
    [
        ([], 180, "50001"),
        (list(range(1, 28)), 180, "50001"),
        ([-1], 180, "50002"),
        ([1], 0, "50003"),
        ([1], 181, "50003"),
        ([1], None, "50003"),
    ],
)
def test_parameter_rejections(sql, ids, days, code):
    import pyodbc

    with pytest.raises(pyodbc.Error, match=code):
        execute(sql, ids, days)
