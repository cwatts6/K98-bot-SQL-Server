"""Opt-in owned local SQL proof: implicit mode must not create maintenance work."""

import os
from pathlib import Path
import re
from uuid import uuid4

import pytest


@pytest.fixture
def database():
    if os.getenv("K98_D3_NATIVE_SQL") != "CREATE_DISPOSABLE_LOCAL_ONLY":
        pytest.skip("Requires an explicitly created local D3 disposable database")
    import pyodbc

    pyodbc.pooling = False
    name = "K98_D3_Disposable_" + uuid4().hex
    base = (r"DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost\K98DEV;"
            "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;DATABASE=")
    admin = pyodbc.connect(base + "master;", autocommit=True, timeout=5)
    owner = None
    created = False
    try:
        assert tuple(admin.execute("SELECT @@SERVERNAME,DB_NAME()").fetchone()) == (r"9SX2VF4\K98DEV", "master")
        assert admin.execute("SELECT DB_ID(?)", name).fetchval() is None
        admin.execute(f"CREATE DATABASE [{name}]")
        created = True
        owner = pyodbc.connect(base + name + ";", autocommit=True, timeout=5)
        owner.timeout = 10
        root = Path(__file__).resolve().parents[1] / "sql_schema"
        for file in ("dbo.MaintenanceWork.Table.sql", "dbo.usp_MaintenanceDue.StoredProcedure.sql",
                     "dbo.usp_MaintenancePostImport.StoredProcedure.sql", "dbo.usp_RunMaintenance.StoredProcedure.sql",
                     "dbo.usp_update_stats.StoredProcedure.sql"):
            for batch in re.split(r"(?im)^GO\s*$", (root / file).read_text(encoding="utf-8-sig")):
                if batch.strip():
                    owner.execute(batch)
        yield owner
    finally:
        try:
            if owner is not None:
                owner.close()
            if created:
                admin.execute("SET LOCK_TIMEOUT 1000")
                admin.execute(f"DROP DATABASE [{name}]")
        finally:
            admin.close()


@pytest.mark.parametrize("procedure", ["dbo.usp_update_stats", "dbo.usp_RunMaintenance 'post_import'"])
def test_implicit_mode_refused_before_state_read_or_due(database, procedure):
    database.execute("SET IMPLICIT_TRANSACTIONS ON")
    try:
        with pytest.raises(Exception, match="51962"):
            cursor = database.execute("EXEC " + procedure)
            while cursor.nextset():
                pass
        assert database.execute("SELECT @@TRANCOUNT").fetchval() == 0
    finally:
        database.execute("IF @@TRANCOUNT>0 ROLLBACK; SET IMPLICIT_TRANSACTIONS OFF")
    assert tuple(database.execute("SELECT DueGeneration,CompletedGeneration,State FROM dbo.MaintenanceWork WHERE Kind='post_import'").fetchone()) == (0, 0, "complete")
