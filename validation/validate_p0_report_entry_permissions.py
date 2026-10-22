"""Exercise the installed report entry boundary in a disposable database.

The real wrapper and installed permission rows are retained. Only the private
business calculation and UPDATE_ALL2 import body are replaced transactionally
with a counted write and the exact authored static report call. No import or
production reporting work is executed. Rollback restores the installed images.
"""

import re

import pyodbc

import build_p0_receipt_migration as build


def validate(connection):
    assert connection.execute("SELECT DB_NAME()").fetchval().startswith("K98_P0_")
    assert connection.execute("SELECT @@TRANCOUNT").fetchval() == 0
    core = "dbo.usp_S11CompleteStatsReportsCore"
    assert tuple(
        connection.execute(
            "SELECT p.state,USER_NAME(p.grantee_principal_id) FROM sys.database_permissions p "
            "WHERE p.class=1 AND p.major_id=OBJECT_ID(?) AND p.type='EX' "
            "AND p.grantee_principal_id=DATABASE_PRINCIPAL_ID('public')",
            core,
        ).fetchone()
    ) == ("D", "public")
    source = build.module_body(
        (build.ROOT / "sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql").read_text(
            encoding="utf-8-sig"
        )
    )
    call = re.search(r"EXEC dbo\.usp_S11CompleteStatsReportsCore\b[\s\S]*?;", source)[0]
    private = build.module_body(
        (
            build.ROOT / "sql_schema/dbo.usp_S11CompleteStatsReportsCore.StoredProcedure.sql"
        ).read_text(encoding="utf-8-sig")
    )
    passed = []
    connection.execute("SET XACT_ABORT OFF")
    connection.execute("BEGIN TRANSACTION")
    try:
        connection.execute("CREATE USER P0ReceiptCaller WITHOUT LOGIN")
        connection.execute("CREATE USER P0UnrelatedOwner WITHOUT LOGIN")
        connection.execute("ALTER ROLE ExportLegacyEntryReader ADD MEMBER P0ReceiptCaller")
        connection.execute("CREATE TABLE dbo.P0ReceiptProbe(PreparationID uniqueidentifier NULL)")
        connection.execute(
            private[: private.index("AS\nBEGIN")]
            + "AS INSERT dbo.P0ReceiptProbe VALUES(@ExportPreparationID);"
        )
        # Keep the actual UPDATE_ALL2 call and its parameter declarations.
        connection.execute(
            "CREATE OR ALTER PROCEDURE dbo.UPDATE_ALL2 @CompletedFileName nvarchar(260),"
            "@ExportPreparationID uniqueidentifier=NULL AS BEGIN "
            "DECLARE @actual_param1 float,@actual_param2 nvarchar(100),@rowsKS5 int=0,"
            "@rowsKS4 int=0,@StartTime datetime; " + call + " END;"
        )
        connection.execute("GRANT EXECUTE ON dbo.UPDATE_ALL2 TO P0ReceiptCaller")
        connection.execute(
            "CREATE PROCEDURE dbo.P0NestedRecovery AS "
            "EXEC dbo.usp_S11CompleteStatsReports @CompletedFileName=N'test.csv';"
        )
        connection.execute(
            "CREATE PROCEDURE dbo.P0DynamicCore AS "
            "EXEC sys.sp_executesql N'EXEC dbo.usp_S11CompleteStatsReportsCore "
            "@CompletedFileName=N''test.csv''';"
        )
        connection.execute(
            "CREATE PROCEDURE dbo.P0UnrelatedCore AS "
            "EXEC dbo.usp_S11CompleteStatsReportsCore @CompletedFileName=N'test.csv';"
        )
        connection.execute("ALTER AUTHORIZATION ON dbo.P0UnrelatedCore TO P0UnrelatedOwner")
        for proc in ("P0NestedRecovery", "P0DynamicCore", "P0UnrelatedCore"):
            connection.execute("GRANT EXECUTE ON dbo." + proc + " TO P0ReceiptCaller")
        connection.execute("EXECUTE AS USER='P0ReceiptCaller'")
        try:
            assert (
                connection.execute("SELECT HAS_PERMS_BY_NAME('dbo','SCHEMA','ALTER')").fetchval()
                == 0
            )
            connection.execute("EXEC sys.sp_set_session_context N'P0TrustedLegacyCaller',1")
            refused = {
                "omitted_id": ("EXEC dbo.usp_S11CompleteStatsReports N'test.csv'", "51961"),
                "explicit_null": ("EXEC dbo.usp_S11CompleteStatsReports N'test.csv',NULL", "51961"),
                "dynamic_null": (
                    "EXEC sys.sp_executesql N'EXEC dbo.usp_S11CompleteStatsReports "
                    "N''test.csv'',NULL'",
                    "51961",
                ),
                "nested_null": ("EXEC dbo.P0NestedRecovery", "51961"),
                "direct_core": ("EXEC dbo.usp_S11CompleteStatsReportsCore N'test.csv'", "229"),
                "dynamic_core": ("EXEC dbo.P0DynamicCore", "229"),
                "unrelated_owner_core": ("EXEC dbo.P0UnrelatedCore", "229"),
            }
            for name, (statement, error) in refused.items():
                try:
                    connection.execute(statement)
                except pyodbc.Error as exc:
                    assert error in str(exc), (name, str(exc))
                else:
                    raise AssertionError("Receipt boundary accepted " + name)
                passed.append(name)
        finally:
            connection.execute("REVERT")
        assert connection.execute("SELECT COUNT(*) FROM dbo.P0ReceiptProbe").fetchval() == 0
        connection.execute("EXECUTE AS USER='P0ReceiptCaller'")
        try:
            connection.execute("EXEC dbo.UPDATE_ALL2 N'test.csv',NULL")
            # The public continuation entry now owns its validation transaction;
            # this fixture deliberately has a caller-owned transaction.
            try:
                connection.execute(
                    "EXEC dbo.usp_S11CompleteStatsReports "
                    "N'test.csv','00000000-0000-0000-0000-000000000001'"
                )
            except pyodbc.Error as exc:
                assert "51961" in str(exc)
            else:
                raise AssertionError("Caller transaction entered recovery wrapper")
        finally:
            connection.execute("REVERT")
        assert connection.execute("SELECT COUNT(*) FROM dbo.P0ReceiptProbe").fetchval() == 1
        assert (
            connection.execute(
                "SELECT COUNT(*) FROM dbo.P0ReceiptProbe WHERE PreparationID IS NULL"
            ).fetchval()
            == 1
        )
        passed.extend(("legacy_static_null_chain", "recovery_caller_transaction_refused"))
    finally:
        connection.execute("ROLLBACK")
        connection.execute("SET XACT_ABORT ON")
    return passed
