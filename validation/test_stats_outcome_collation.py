"""Run explicitly on local K98DEV; retain a new READ_ONLY synthetic database.

No import procedure is invoked. The old retained rehearsal databases are untouched.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

import pyodbc

pyodbc.pooling = False

ROOT = Path(__file__).resolve().parents[1]
SERVER = r"lpc:localhost\K98DEV"
IDENTITY = r"9SX2VF4\K98DEV"
DATABASE = "K98_S11_Collation_20261010_r3"
OLD = "20261009_001_stats_import_outcomes"
NEW = "20261010_001_stats_import_outcomes_collation"
OLD_HASH = "344f050165a7f64078615db9deac10a687babdc1c28c2536eaedcda07fae87f3"


def connect(database):
    c = pyodbc.connect(
        f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE={database};"
        "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;",
        autocommit=True,
        timeout=5,
    )
    c.timeout = 30
    assert tuple(
        c.execute("SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME()").fetchone()
    ) == (IDENTITY, database)
    return c


def execute(c, text):
    cur = c.cursor()
    try:
        cur.execute(text)
        while cur.nextset():
            pass
    finally:
        cur.close()


def definition_hash(text):
    text = text.replace("\r\n", "\n").strip(" \t\r\n")
    text = re.sub(r"^(?:ALTER|CREATE OR ALTER)", "CREATE", text)
    return hashlib.sha256(text.encode("utf-16-le")).hexdigest()


def run():
    old_bytes = (ROOT / "migrations" / (OLD + ".sql")).read_bytes()
    assert hashlib.sha256(old_bytes).hexdigest() == OLD_HASH
    old_body = subprocess.check_output(
        ["git", "-C", str(ROOT), "show", "6072697:sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql"]
    ).decode("utf-8-sig")
    old_body = old_body[
        re.search(r"(?m)^(?:ALTER|CREATE OR ALTER) PROCEDURE", old_body).start() :
    ].strip()
    assert (
        definition_hash(old_body)
        == "d89d8cdd46020f3a464baf5cb0cbc1f30fb5734efe36316865dac88cabd24b68"
    )
    c = connect("master")
    try:
        assert (
            c.execute("SELECT COUNT(*) FROM sys.databases WHERE name=?", DATABASE).fetchval() == 0
        ), "Fixture already exists; preserve it"
        temp_collation = c.execute(
            "SELECT collation_name FROM sys.databases WHERE name=N'tempdb'"
        ).fetchval()
        collation = (
            "SQL_Latin1_General_CP1_CI_AS"
            if temp_collation != "SQL_Latin1_General_CP1_CI_AS"
            else "Latin1_General_CI_AS"
        )
        execute(c, f"CREATE DATABASE [{DATABASE}] COLLATE {collation};")
    finally:
        c.close()
    c = connect(DATABASE)
    try:
        execute(c, "CREATE SCHEMA KVK")
        execute(c, "CREATE ROLE ExportLegacyEntryReader")
        execute(
            c,
            "CREATE TABLE dbo.ExportJob(JobID uniqueidentifier PRIMARY KEY); CREATE TABLE dbo.ExportJobResource(JobID uniqueidentifier NOT NULL,ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,PRIMARY KEY(JobID,ResourceKey)); CREATE TABLE KVK.SourceOutputOperationResource(OperationID uniqueidentifier NOT NULL,ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,PRIMARY KEY(OperationID,ResourceKey)); CREATE TABLE dbo.ExportExecutionSession(State varchar(32) NOT NULL)",
        )
        execute(
            c, (ROOT / "sql_schema/dbo.ExportPreparation.Table.sql").read_text(encoding="utf-8-sig")
        )
        resource = (ROOT / "sql_schema/dbo.ExportResource.Table.sql").read_text(
            encoding="utf-8-sig"
        )
        constraints = re.findall(r"(?m)^ALTER TABLE.*;", resource)
        execute(c, re.sub(r"(?m)^ALTER TABLE.*;", "", resource))
        execute(
            c,
            (ROOT / "sql_schema/dbo.ExportPreparationResource.Table.sql").read_text(
                encoding="utf-8-sig"
            ),
        )
        for constraint in constraints:
            execute(c, constraint)
        execute(c, re.sub(r"^(?:ALTER|CREATE OR ALTER) PROCEDURE", "CREATE PROCEDURE", old_body))
        execute(
            c,
            (ROOT / "sql_schema/dbo.SchemaMigrationHistory.Table.sql").read_text(
                encoding="utf-8-sig"
            ),
        )
        original = old_bytes.decode("utf-8-sig").replace("<> N'ROK_TRACKER'", f"<> N'{DATABASE}'")
        try:
            execute(c, original)
        except pyodbc.Error as exc:
            assert "468" in str(exc) and "collation" in str(exc).lower()
        else:
            raise AssertionError("Original migration should reproduce mixed-collation failure")
    finally:
        c.close()
    c = connect(DATABASE)
    try:
        assert tuple(
            c.execute(
                "SELECT OBJECT_ID(N'dbo.StatsImportExecution'),OBJECT_ID(N'dbo.usp_S11RunStatsImport')"
            ).fetchone()
        ) == (None, None)
        before = c.execute(
            "SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.UPDATE_ALL2')"
        ).fetchval()
        assert definition_hash(before) == definition_hash(old_body)
        c.execute(
            "INSERT dbo.SchemaMigrationHistory(MigrationId,MigrationFile,ChecksumSha256,AppliedAtUtc,Status,ErrorMessage) VALUES(?,?,?,SYSUTCDATETIME(),N'Failed',N'Synthetic collation regression')",
            OLD,
            OLD + ".sql",
            OLD_HASH,
        )
        receipt = tuple(
            c.execute(
                "SELECT * FROM dbo.SchemaMigrationHistory WHERE MigrationId=?", OLD
            ).fetchone()
        )
        corrected = (
            (ROOT / "migrations" / (NEW + ".sql"))
            .read_text(encoding="utf-8-sig")
            .replace("<> N'ROK_TRACKER'", f"<> N'{DATABASE}'")
        )
        execute(c, corrected)
        assert all(
            v is not None
            for v in c.execute(
                "SELECT OBJECT_ID(N'dbo.StatsImportExecution'),OBJECT_ID(N'dbo.usp_S11RunStatsImport')"
            ).fetchone()
        )
        for name in ["UPDATE_ALL2", "usp_S11RunStatsImport"]:
            expected = (ROOT / "sql_schema" / f"dbo.{name}.StoredProcedure.sql").read_text(
                encoding="utf-8-sig"
            )
            expected = expected[
                re.search(r"(?m)^(?:ALTER|CREATE OR ALTER) PROCEDURE", expected).start() :
            ]
            actual = c.execute(
                "SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(?)", "dbo." + name
            ).fetchval()
            allowed = {definition_hash(expected)}
            if name == "usp_S11RunStatsImport":
                # SQL Server preserves CREATE OR ALTER as CREATE plus three spaces.
                # This exact spelling is already pinned by the original migration.
                allowed.add("034ca049c92a8b8ea654edca21f03269afae4884d398ea7d26e7ab0aade0b81e")
            assert definition_hash(actual) in allowed, name
        execute(c, corrected)
        assert (
            tuple(
                c.execute(
                    "SELECT * FROM dbo.SchemaMigrationHistory WHERE MigrationId=?", OLD
                ).fetchone()
            )
            == receipt
        )
        assert c.execute("SELECT COUNT(*) FROM dbo.StatsImportExecution").fetchval() == 0
    finally:
        c.close()
    c = connect("master")
    try:
        execute(c, f"ALTER DATABASE [{DATABASE}] SET READ_ONLY WITH NO_WAIT;")
    finally:
        c.close()
    return dict(
        status="PASS",
        database=DATABASE,
        database_collation=collation,
        tempdb_collation=temp_collation,
        original_conflict_reproduced=True,
        original_transaction_rollback_observed=True,
        corrected_installation=True,
        exact_module_postimages=True,
        repeat_installation_metadata_check=True,
        original_failed_receipt_unchanged=True,
        business_work_executed=False,
        retained_read_only=True,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not args.execute:
        print(
            json.dumps(
                dict(
                    server=SERVER,
                    database=DATABASE,
                    action="New synthetic mixed-collation fixture; old failure then corrected installation; no business execution; retain READ_ONLY",
                )
            )
        )
    else:
        result = run()
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result))
