"""Disposable local migration-chain rehearsal; never connects to production.

Baseline definitions come only from an immutable SQL Git revision. No business
procedures or provider operations run. The created database is retained for audit.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
from uuid import uuid4

import pyodbc

ROOT = Path(__file__).resolve().parents[1]
BASE = "b3480656e3454fbe713905460177f8d038c2bd5f"
HEAD = "ee71a4ae9ae1ea3a523a608c685b0992c58244eb"
SERVER = r"lpc:localhost\K98DEV"
DATABASE = "K98_P0a_Migrations_" + uuid4().hex[:12]
EXPECTED_SERVER = r"9SX2VF4\K98DEV"
MIGRATIONS = (
    "20261015_001_failed_read_history",
    "20261015_002_guided_recovery",
    "20261015_003_read_prefix_history",
    "20261015_004_failed_publication_probe",
    "20261015_005_read_prefix_closure",
    "20261015_006_failed_probe_request_events",
    "20261015_007_read_dispatch_containment",
    "20261015_008_export_target_containment",
    "20261015_009_guided_export_replacement",
    "20261015_010_configuration_replacement",
    "20261016_001_rollover_replacement",
    "20261016_002_atomic_configuration_publication",
)
FIRST_CHANGE = {
    "dbo.usp_ExportReconciliationProofIssue": MIGRATIONS[0],
    "dbo.usp_ExportExecutionStreamTransition": MIGRATIONS[3],
    "dbo.usp_ExportProviderRequestEventAppend": MIGRATIONS[5],
    "dbo.usp_ExportExecutionSessionTransition": MIGRATIONS[6],
    "dbo.usp_ExportManualOutputEnrollmentTransition": MIGRATIONS[8],
    "dbo.usp_ExportOutputEnrollmentTransition": MIGRATIONS[8],
    "dbo.sp_TARGETS_MASTER": MIGRATIONS[11],
}


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def source(revision, path):
    return git("show", revision + ":" + path).decode("utf-8-sig").replace("\r\n", "\n")


def execute(connection, text):
    # Source snapshot USE statements alone are removed for this fresh fixture.
    # Migration scripts are never rewritten by this helper.
    if re.search(r"(?im)^\s*USE\b", text):
        raise ValueError("Unexpected database switch")
    cursor = connection.cursor()
    try:
        cursor.execute(text)
        while cursor.nextset():
            pass
    finally:
        cursor.close()


def batches(text):
    for batch in re.split(r"(?im)^GO\s*$", text):
        if batch.strip():
            yield batch.lstrip("\n")


def connect(database):
    assert database == "master" or database == DATABASE
    connection = pyodbc.connect(
        f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE={database};"
        "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;",
        autocommit=True,
        timeout=5,
    )
    connection.timeout = 30
    actual = tuple(
        connection.execute(
            "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME()"
        ).fetchone()
    )
    assert actual == (EXPECTED_SERVER, database), actual
    return connection


def catalogue(connection):
    """Capture fixture metadata independently of migration success messages."""
    queries = (
        "SELECT SCHEMA_NAME(schema_id),name,type,OBJECT_DEFINITION(object_id) "
        "FROM sys.objects WHERE is_ms_shipped=0 ORDER BY object_id",
        "SELECT object_id,name,column_id,user_type_id,max_length,precision,scale,"
        "collation_name,is_nullable,is_identity,is_computed FROM sys.columns "
        "WHERE object_id IN (SELECT object_id FROM sys.objects WHERE is_ms_shipped=0) "
        "ORDER BY object_id,column_id",
        "SELECT class,major_id,minor_id,grantee_principal_id,grantor_principal_id,type,state "
        "FROM sys.database_permissions ORDER BY class,major_id,minor_id,grantee_principal_id,type",
        "SELECT object_id,name,index_id,type,is_unique,is_primary_key,is_unique_constraint,"
        "is_disabled,has_filter,filter_definition FROM sys.indexes "
        "WHERE object_id IN (SELECT object_id FROM sys.objects WHERE is_ms_shipped=0) "
        "ORDER BY object_id,index_id",
    )
    return [[tuple(row) for row in connection.execute(query)] for query in queries]


def main(qualification=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-disposable-sql", action="store_true", required=True)
    parser.parse_args()
    files = (
        git("ls-tree", "-r", "--name-only", BASE, "sql_schema").decode().splitlines()
    )
    table_paths = {
        p[len("sql_schema/") : -len(".Table.sql")]: p
        for p in files
        if p.endswith(".Table.sql")
    }
    selected = {
        name for name in table_paths if name.startswith(("dbo.Export", "KVK.Source"))
    } | {
        "dbo.ProcConfig",
        "dbo.StatsImportExecution",
        "dbo.SchemaMigrationHistory",
        "dbo.DeploymentRunHistory",
    }
    tables, deferred = {}, []
    pending = list(selected)
    while pending:
        name = pending.pop()
        if name in tables:
            continue
        raw = source(BASE, table_paths[name])
        # These fixed schema files have one-line out-of-line constraints. Delay
        # them until all tables exist, preserving their literal SQL and checks.
        lines, delayed = [], []
        for line in raw.splitlines(keepends=True):
            if line.startswith("ALTER TABLE") and "FOREIGN KEY" in line:
                delayed.append(line)
            else:
                lines.append(line)
        raw = "".join(lines)
        unquoted = raw.replace("[", "").replace("]", "")
        dependencies = set(
            re.findall(r"REFERENCES\s+([A-Za-z_]\w*\.[A-Za-z_]\w*)", unquoted, re.I)
        ) - {name}
        for dep in dependencies:
            if dep not in table_paths:
                raise ValueError("Missing authoritative table: " + dep)
        pending.extend(dependencies - tables.keys())
        tables[name] = (raw, dependencies)
        deferred.extend(delayed)
    ordered, remaining = [], set(tables)
    while remaining:
        ready = sorted(name for name in remaining if not tables[name][1] & remaining)
        if not ready:
            raise ValueError(
                "Unresolved baseline table cycle: " + ",".join(sorted(remaining))
            )
        ordered.extend(ready)
        remaining.difference_update(ready)
    changed = (
        git("diff", "--name-only", BASE, HEAD, "--", "sql_schema").decode().splitlines()
    )
    modules = [p for p in changed if p.endswith(".StoredProcedure.sql") and p in files]
    report = dict(
        database=DATABASE,
        server=EXPECTED_SERVER,
        base=BASE,
        head=HEAD,
        baseline_tables=len(ordered),
        baseline_modules=len(modules),
        applied=[],
    )
    output = Path(tempfile.gettempdir()) / (DATABASE + ".json")
    pyodbc.pooling = False
    with connect("master") as connection:
        assert (
            connection.execute(
                "SELECT COUNT(*) FROM sys.databases WHERE name=?", DATABASE
            ).fetchval()
            == 0
        )
        execute(
            connection, f"CREATE DATABASE [{DATABASE}] COLLATE Latin1_General_CI_AS"
        )
    print(json.dumps(dict(stage="created_disposable_fixture", **report)), flush=True)
    try:
        with connect(DATABASE) as connection:
            execute(connection, "CREATE SCHEMA KVK")
            execute(
                connection,
                "CREATE ROLE ExportExecutionAuthority; CREATE ROLE ExportExecutionReader;",
            )
            for name in ordered:
                for batch in batches(tables[name][0]):
                    execute(connection, batch)
            for statement in deferred:
                execute(connection, statement)
            for path in modules:
                raw = source(BASE, path)
                raw = re.sub(r"(?im)^ALTER PROCEDURE", "CREATE PROCEDURE", raw, count=1)
                declaration = re.search(r"(?m)^CREATE(?: OR ALTER)? PROCEDURE\b", raw)
                assert declaration, path
                raw = raw[declaration.start() :]
                execute(connection, "SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;")
                for batch in batches(raw):
                    name = path[len("sql_schema/") : -len(".StoredProcedure.sql")]
                    migration = source(
                        HEAD, "migrations/" + FIRST_CHANGE[name] + ".sql"
                    )
                    # Historical installers differ only in preserving the final
                    # newline. Select the finite source-derived form explicitly
                    # pinned by this object's reviewed first migration. Never
                    # read an observed hash as its own expected preimage.
                    forms = [batch.strip(), batch.strip() + "\n"]
                    admitted = [
                        body
                        for body in forms
                        if "0x" + hashlib.sha256(body.encode("utf-16le")).hexdigest()
                        in migration
                    ]
                    assert 1 <= len(admitted) <= 2, (
                        name,
                        "missing source-derived preimage",
                    )
                    # Both final-newline representations may now be explicitly
                    # admitted. Prefer the exported newline form deterministically.
                    execute(connection, admitted[-1])
            print(
                json.dumps(
                    dict(
                        stage="baseline_installed",
                        tables=len(ordered),
                        modules=len(modules),
                    )
                ),
                flush=True,
            )
            if qualification is not None:
                qualification(connection, report, output)
                report["status"] = "passed"
                return
            for migration in MIGRATIONS:
                raw = git("show", HEAD + ":migrations/" + migration + ".sql")
                batch = raw.decode("utf-8-sig").replace("\r\n", "\n")
                if migration == MIGRATIONS[8]:
                    before = catalogue(connection)
                    boundary = "\nCOMMIT;\nEND TRY\nBEGIN CATCH\n"
                    assert batch.count(boundary) == 1
                    injected = batch.replace(
                        boundary,
                        "\nTHROW 51959,'Rehearsal interruption before commit.',1;"
                        + boundary,
                    )
                    try:
                        execute(connection, injected)
                    except pyodbc.Error as exc:
                        assert "51959" in str(exc), str(exc)
                    else:
                        raise AssertionError(
                            "Fault injection did not interrupt migration"
                        )
                    assert connection.execute("SELECT @@TRANCOUNT").fetchval() == 0
                    assert (
                        catalogue(connection) == before
                    ), "Partial schema/permission changes survived rollback"
                    report["replacement_rollback_verified"] = True
                    print(
                        json.dumps(dict(stage="replacement_rollback_verified")),
                        flush=True,
                    )
                execute(connection, batch)
                assert connection.execute("SELECT @@TRANCOUNT").fetchval() == 0
                report["applied"].append(
                    dict(id=migration, sha256=hashlib.sha256(raw).hexdigest())
                )
                print(
                    json.dumps(dict(stage="migration_applied", id=migration)),
                    flush=True,
                )
            report["status"] = "passed"
    except Exception as exc:
        report.update(status="failed", error=str(exc))
        raise
    finally:
        output.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(str(output), flush=True)


if __name__ == "__main__":
    main()
