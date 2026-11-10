"""Native direct-child boundaries in a new, uniquely owned local test database."""

from contextlib import closing
import os
from pathlib import Path
import re
from types import SimpleNamespace
from uuid import uuid4

import pytest

GUARDS = (
    "K98:post-import-stats:v1",
    "k98-legacy-output-snapshot",
    "K98:TargetPublication:DeltaPreprocessing",
    "K98:StatsForUpload:Publish",
    "K98:maintenance-schema:v1",
)
CALLS = {
    "Import": "@IncludeKS4=0",
    "Configuration": "@RowsProcessed=0,@LastBatchRows=0,@NewMaxScan=0,@LargeBatchDue=0,@Generation=0",
    "PlayerReport": "",
    "KvkOutput": "@Generation=0,@ClaimID=NULL,@AllDone=NULL",
    "FinalStats": "@Dashboard=0,@Summary=0,@Generation=0,@ClaimID=NULL",
    "PostImport": "",
}


@pytest.fixture(scope="module")
def children():
    if os.getenv("K98_D3_NATIVE_SQL") != "CREATE_DISPOSABLE_LOCAL_ONLY":
        pytest.skip("Requires a new disposable local SQL database")
    import pyodbc

    pyodbc.pooling = False
    name = "K98_D4_Children_" + uuid4().hex
    base = (
        r"DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost\K98DEV;"
        "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;DATABASE="
    )
    admin = pyodbc.connect(base + "master;", autocommit=True, timeout=5)
    admin.timeout = 10
    created = False
    try:
        assert tuple(admin.execute("SELECT @@SERVERNAME,DB_NAME()").fetchone()) == (
            r"9SX2VF4\K98DEV",
            "master",
        )
        assert admin.execute("SELECT DB_ID(?)", name).fetchval() is None
        admin.execute(f"CREATE DATABASE [{name}]")
        created = True

        def connect():
            con = pyodbc.connect(base + name + ";", autocommit=True, timeout=5)
            con.timeout = 3
            return con

        with closing(connect()) as owner:
            root = Path(__file__).resolve().parents[1] / "sql_schema"
            for kind in CALLS:
                source = (
                    root / f"dbo.usp_Maintenance{kind}.StoredProcedure.sql"
                ).read_text(encoding="utf-8-sig")
                for batch in re.split(r"(?im)^GO\s*$", source):
                    if batch.strip():
                        owner.execute(batch)
            owner.execute(
                "CREATE USER d4_child WITHOUT LOGIN; CREATE USER d4_denied WITHOUT LOGIN;"
            )
            for kind in CALLS:
                owner.execute(f"GRANT EXECUTE ON dbo.usp_Maintenance{kind} TO d4_child")
        yield SimpleNamespace(connect=connect)
    finally:
        try:
            if created:
                admin.execute("SET LOCK_TIMEOUT 1000")
                admin.execute(f"DROP DATABASE [{name}]")
        finally:
            admin.close()


def acquire(con, resource):
    con.execute(
        "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=?,"
        "@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0,@DbPrincipal='public';"
        "IF @r<0 THROW 50000,'Fixture lock unavailable.',1;",
        resource,
    )


def invoke(con, kind):
    cursor = con.cursor()
    try:
        cursor.execute(f"EXEC dbo.usp_Maintenance{kind} {CALLS[kind]}")
        while cursor.nextset():
            pass
    finally:
        cursor.close()


@pytest.mark.parametrize("kind", CALLS)
@pytest.mark.parametrize("missing", GUARDS)
def test_restricted_direct_child_refuses_each_foreign_owned_guard(
    children, kind, missing
):
    with closing(children.connect()) as holder, closing(children.connect()) as caller:
        acquire(holder, missing)
        caller.execute("EXECUTE AS USER='d4_child'")
        for guard in GUARDS:
            if guard != missing:
                acquire(caller, guard)
        with pytest.raises(Exception, match=r"5196[12]"):
            invoke(caller, kind)
        assert caller.execute("SELECT @@TRANCOUNT").fetchval() == 0


@pytest.mark.parametrize("kind", CALLS)
@pytest.mark.parametrize("mode", ["active", "implicit"])
def test_direct_child_refuses_transaction_modes_before_business_access(
    children, kind, mode
):
    with closing(children.connect()) as caller:
        caller.execute("EXECUTE AS USER='d4_child'")
        for guard in GUARDS:
            acquire(caller, guard)
        caller.execute(
            "BEGIN TRANSACTION" if mode == "active" else "SET IMPLICIT_TRANSACTIONS ON"
        )
        try:
            with pytest.raises(Exception, match="51962"):
                invoke(caller, kind)
            assert caller.execute("SELECT @@TRANCOUNT").fetchval() == (
                1 if mode == "active" else 0
            )
        finally:
            caller.execute("IF @@TRANCOUNT>0 ROLLBACK; SET IMPLICIT_TRANSACTIONS OFF")


@pytest.mark.parametrize("kind", CALLS)
def test_ungranted_direct_caller_remains_denied(children, kind):
    with closing(children.connect()) as caller:
        caller.execute("EXECUTE AS USER='d4_denied'")
        with pytest.raises(Exception, match="229"):
            invoke(caller, kind)


def test_owned_post_import_child_executes_real_statistics(children):
    with closing(children.connect()) as caller:
        caller.execute("EXECUTE AS USER='d4_child'")
        for guard in GUARDS:
            acquire(caller, guard)
        invoke(caller, "PostImport")
        assert caller.execute("SELECT @@TRANCOUNT").fetchval() == 0
