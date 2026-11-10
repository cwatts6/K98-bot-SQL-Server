"""Observed dependency contracts in a newly owned local database; no backup call."""

from contextlib import closing
import os
from pathlib import Path
from uuid import uuid4

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def dependencies():
    if os.getenv("K98_D3_NATIVE_SQL") != "CREATE_DISPOSABLE_LOCAL_ONLY":
        pytest.skip("Requires a new disposable local SQL database")
    import pyodbc

    pyodbc.pooling = False
    name = "K98_D4_Dependencies_" + uuid4().hex
    base = (
        r"DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost\K98DEV;"
        "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;DATABASE="
    )
    with closing(pyodbc.connect(base + "master;", autocommit=True, timeout=5)) as admin:
        admin.timeout = 10
        assert tuple(admin.execute("SELECT @@SERVERNAME,DB_NAME()").fetchone()) == (
            r"9SX2VF4\K98DEV",
            "master",
        )
        assert admin.execute("SELECT DB_ID(?)", name).fetchval() is None
        assert (
            admin.execute(
                "SELECT available_physical_memory_kb FROM sys.dm_os_sys_memory"
            ).fetchval()
            >= 8 * 1024 * 1024
        )
        assert (
            admin.execute(
                "SELECT MIN(v.available_bytes) FROM sys.master_files f "
                "CROSS APPLY sys.dm_os_volume_stats(f.database_id,f.file_id) v "
                "WHERE f.database_id IN (1,2)"
            ).fetchval()
            >= 8 * 1024**3
        )
        admin.execute(f"CREATE DATABASE [{name}]")
        try:
            with closing(
                pyodbc.connect(base + name + ";", autocommit=True, timeout=5)
            ) as con:
                con.timeout = 3
                con.execute(
                    (ROOT / "sql_schema/dbo.KS4_UNO_SEQ.Sequence.sql").read_text()
                )
                template = (
                    ROOT / "qualification/p02_d4/msdb_log_backup_wrapper.template.sql"
                ).read_text()
                assert template.count("__K98_LOG_BACKUP_JOB_ID__") == 1
                body = template.replace("__K98_LOG_BACKUP_JOB_ID__", str(uuid4()))
                con.execute("SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;")
                con.execute(body)
                yield con, body
        finally:
            admin.execute("SET LOCK_TIMEOUT 1000")
            admin.execute(f"DROP DATABASE [{name}]")


def sequence_metadata(con):
    return tuple(
        con.execute(
            "SELECT TYPE_NAME(user_type_id),CONVERT(bigint,start_value),"
            "CONVERT(bigint,increment),CONVERT(bigint,minimum_value),"
            "CONVERT(bigint,maximum_value),is_cycling,is_cached,cache_size "
            "FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.KS4_UNO_SEQ')"
        ).fetchone()
    )


def test_observed_sequence_structure(dependencies):
    con, _ = dependencies
    assert sequence_metadata(con) == (
        "int",
        130489,
        1,
        -2147483648,
        2147483647,
        False,
        False,
        None,
    )


def test_wrapper_body_owner_and_restricted_visibility_without_dispatch(dependencies):
    con, body = dependencies
    actual, owner = con.execute(
        "SELECT definition,execute_as_principal_id FROM sys.sql_modules "
        "WHERE object_id=OBJECT_ID(N'dbo.usp_start_rok_tracker_log_backup')"
    ).fetchone()
    assert actual == body
    assert owner == -2
    con.execute(
        "CREATE USER d4_wrapper_allowed WITHOUT LOGIN; CREATE USER d4_wrapper_denied WITHOUT LOGIN;"
        "GRANT EXECUTE ON dbo.usp_start_rok_tracker_log_backup TO d4_wrapper_allowed;"
        "DENY EXECUTE ON dbo.usp_start_rok_tracker_log_backup TO d4_wrapper_denied;"
    )
    for principal, expected in (("d4_wrapper_allowed", 1), ("d4_wrapper_denied", 0)):
        con.execute(f"EXECUTE AS USER=N'{principal}';")
        try:
            assert (
                con.execute(
                    "SELECT HAS_PERMS_BY_NAME(N'dbo.usp_start_rok_tracker_log_backup',N'OBJECT',N'EXECUTE')"
                ).fetchval()
                == expected
            )
        finally:
            con.execute("REVERT;")
