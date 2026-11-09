from pathlib import Path
import re
import pytest
from test_shared_report_names import database, db, ROOT, SOURCES, batches


def test_target_view_and_regeneration_preserve_selected_table_columns_and_numbers(db):
    sql = (ROOT / "sql_schema/dbo.EXCEL_EXPORT_KVK_TARGETS_15.Table.sql").read_text(
        encoding="utf-8-sig"
    )
    for batch in batches(sql):
        db.execute(batch)
    # Use real column types/order. Populate required fixed-format columns without
    # inventing target calculations or running target publication.
    cols = list(
        db.execute(
            "SELECT c.name,t.name,c.is_nullable FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id WHERE c.object_id=OBJECT_ID('dbo.EXCEL_EXPORT_KVK_TARGETS_15') ORDER BY c.column_id"
        )
    )
    names = []
    values = []
    for col, typ, nullable in cols:
        if col == "Gov_ID":
            value = 1
        elif col == "Governor_Name":
            value = "Old"
        elif nullable:
            continue
        elif typ in ["varchar", "nvarchar", "char", "nchar"]:
            value = ""
        else:
            value = 0
        names.append("[" + col + "]")
        values.append(value)
    db.execute(
        "INSERT dbo.EXCEL_EXPORT_KVK_TARGETS_15 ("
        + ",".join(names)
        + ") VALUES("
        + ",".join("?" for _ in values)
        + ")",
        *values
    )
    for batch in batches(SOURCES["dbo.v_TARGETS_FOR_UPLOAD.View.sql"]["after"]):
        db.execute(batch)
    before = tuple(
        db.execute("SELECT * FROM dbo.EXCEL_EXPORT_KVK_TARGETS_15").fetchone()
    )
    cur = db.execute("SELECT * FROM dbo.v_TARGETS_FOR_UPLOAD")
    columns = [c[0] for c in cur.description]
    after = tuple(cur.fetchone())
    ni = columns.index("Governor_Name")
    assert before[:ni] + before[ni + 1 :] == after[:ni] + after[ni + 1 :]
    assert after[ni] == "Newest"
    # Execute the actual view-regeneration fragment with another selected table,
    # including a column that exercises identifier escaping.
    db.execute(
        "CREATE TABLE dbo.P02TargetRollover(Gov_ID bigint,Governor_Name nvarchar(255),[Metric]]value] bigint);INSERT dbo.P02TargetRollover VALUES(4,N'Old',9007199254740993)"
    )
    text = SOURCES["dbo.sp_TARGETS_MASTER.StoredProcedure.sql"]["after"]
    fragment = text[
        text.index("                    DECLARE @LegacyNameColumns") : text.index(
            "                    EXEC sys.sp_executesql @LegacyViewSql;"
        )
        + len("                    EXEC sys.sp_executesql @LegacyViewSql;")
    ]
    db.execute(
        "DECLARE @ExportTableQuoted nvarchar(300)=N'[dbo].[P02TargetRollover]';\n"
        + fragment
    )
    cur = db.execute("SELECT * FROM dbo.v_TARGETS_FOR_UPLOAD")
    assert [c[0] for c in cur.description] == [
        "Gov_ID",
        "Governor_Name",
        "Metric]value",
    ]
    assert tuple(cur.fetchone()) == (4, "Umhie\u1d3e\u1d34", 9007199254740993)
    # Reapplying bootstrap must not redirect an existing rollover view.
    for batch in batches(SOURCES["dbo.v_TARGETS_FOR_UPLOAD.View.sql"]["after"]):
        db.execute(batch)
    assert tuple(db.execute("SELECT * FROM dbo.v_TARGETS_FOR_UPLOAD").fetchone()) == (
        4,
        "Umhie\u1d3e\u1d34",
        9007199254740993,
    )


def test_account_view_uses_latest_name_without_mutating_account_record(db):
    db.execute(
        "CREATE TABLE dbo.PlayerAccountStatus(GovernorID bigint,GovernorName nvarchar(255),Status nvarchar(30),UpdatedAt datetime2,AccountType nvarchar(30),Main_GovernorID bigint);CREATE TABLE dbo.PlayerLocation(GovernorID bigint,X int,Y int,LastUpdated datetime2);CREATE TABLE dbo.v_PlayerProfile(GovernorID bigint,Power bigint);CREATE TABLE dbo.v_PlayerLatestStats(GovernorID bigint,[Troops Power] bigint)"
    )
    db.execute(
        "INSERT dbo.PlayerAccountStatus VALUES(1,N'Account old','Migrate','2026-11-07','Main',1),(88,N'Unknown account','Migrate','2026-11-07','Main',88);INSERT dbo.v_PlayerProfile VALUES(1,9007199254740993),(88,100);INSERT dbo.v_PlayerLatestStats VALUES(1,10),(88,20)"
    )
    for batch in batches(SOURCES["dbo.v_PlayerAccounts_Migrate.View.sql"]["after"]):
        db.execute(batch)
    result = list(
        db.execute(
            "SELECT GovernorID,GovernorName,Power FROM dbo.v_PlayerAccounts_Migrate ORDER BY GovernorID"
        )
    )
    assert [tuple(r) for r in result] == [
        (1, "Newest", 9007199254740993),
        (88, "Unknown account", 100),
    ]
    assert (
        db.execute(
            "SELECT GovernorName FROM dbo.PlayerAccountStatus WHERE GovernorID=1"
        ).fetchval()
        == "Account old"
    )
