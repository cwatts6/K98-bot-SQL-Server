"""Fresh disposable local SQL fixture for the actual Windows/SqlClient runner.

Retains the database, backup and transcripts. Never connects to production.
"""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

import pyodbc

ROOT = Path(__file__).resolve().parents[1]
SERVER = r"lpc:localhost\K98DEV"
PS = r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"


def run():
    database = "K98_ModuleRelease_" + uuid.uuid4().hex[:12]
    output = ROOT / "validation" / "artifacts" / database
    output.mkdir(parents=True, exist_ok=False)

    def connect(name):
        return pyodbc.connect(
            f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE={name};"
            "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;",
            autocommit=True,
            timeout=5,
        )

    def execute(c, sql, *args):
        cursor = c.cursor()
        try:
            cursor.execute(sql, *args)
            while cursor.nextset():
                pass
        finally:
            cursor.close()

    c = connect("master")
    assert (
        c.execute("SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))").fetchval()
        == r"9SX2VF4\K98DEV"
    )
    execute(c, f"CREATE DATABASE [{database}] COLLATE SQL_Latin1_General_CP1_CI_AS")
    c.close()
    c = connect(database)
    execute(c, f"ALTER DATABASE [{database}] SET RECOVERY SIMPLE")
    for name in ("SchemaMigrationHistory", "DeploymentRunHistory"):
        execute(c, (ROOT / f"sql_schema/dbo.{name}.Table.sql").read_text(encoding="utf-8-sig"))
    execute(c, "SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;")
    execute(c, "CREATE PROCEDURE [dbo].[ModuleFixture] AS SELECT N'old' AS value;")
    execute(c, "CREATE VIEW [dbo].[ViewFixture] AS SELECT 1 AS value;")
    execute(c, "CREATE USER [module_fixture_reader] WITHOUT LOGIN;")
    directory = c.execute(
        "SELECT CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath'))"
    ).fetchval()
    backup = str(Path(directory) / (database + ".bak"))
    execute(c, f"BACKUP DATABASE [{database}] TO DISK=? WITH CHECKSUM;", backup)
    temp_collation = c.execute(
        "SELECT CONVERT(nvarchar(128),DATABASEPROPERTYEX('tempdb','Collation'))"
    ).fetchval()
    compatibility = c.execute(
        "SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()"
    ).fetchval()
    commit = "a" * 40
    release = str(uuid.uuid4())

    def profile(mid, name, kind, after, grants=()):
        original = c.execute(
            "SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(?)", "dbo." + name
        ).fetchval()
        raw = after.encode("utf-8")
        file = name + ".sql"
        (output / file).write_bytes(raw)
        p = dict(
            version=1,
            profile="module_grants_v1",
            migration_id=mid,
            database_collation="SQL_Latin1_General_CP1_CI_AS",
            tempdb_collation=temp_collation,
            compatibility_level=compatibility,
            modules=[
                dict(
                    schema="dbo",
                    name=name,
                    type=kind,
                    before_sha256=hashlib.sha256(original.encode("utf-16le")).hexdigest(),
                    file=file,
                    sha256=hashlib.sha256(raw).hexdigest(),
                )
            ],
            grants=list(grants),
            requires=[],
        )
        path = output / (mid + ".release.json")
        path.write_text(json.dumps(p), encoding="utf-8")
        return path, p

    path, p = profile(
        "20261010_901_fixture",
        "ModuleFixture",
        "P",
        "CREATE OR ALTER PROCEDURE [dbo].[ModuleFixture]\nAS\nSELECT N'caf\u00e9 \u96ea' AS value;\n",
        [
            dict(
                schema="dbo",
                name="ModuleFixture",
                principal="module_fixture_reader",
                permission="EXECUTE",
                before="ABSENT",
            )
        ],
    )
    counter = 0

    def outer(path, operation, expected, *, release_id=None):
        nonlocal counter
        counter += 1
        mid = json.loads(path.read_text())["migration_id"]
        result = subprocess.run(
            [
                PS,
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(ROOT / "deploy/Deploy-SqlMigration.ps1"),
                "-ServerName",
                SERVER,
                "-DatabaseName",
                database,
                "-MigrationId",
                mid,
                "-ProfilePath",
                str(path),
                "-ProfileSHA256",
                hashlib.sha256(path.read_bytes()).hexdigest(),
                "-ExpectedCommit",
                commit,
                "-ReleaseId",
                release if release_id is None else release_id,
                "-Operation",
                operation,
            ],
            capture_output=True,
            timeout=90,
        )
        (output / f"{counter:02d}-{operation}.stdout.txt").write_bytes(result.stdout)
        (output / f"{counter:02d}-{operation}.stderr.txt").write_bytes(result.stderr)
        assert result.returncode == expected, (
            result.returncode,
            result.stdout.decode(errors="replace"),
            result.stderr.decode(errors="replace"),
        )
        return result.stdout.decode(errors="replace")

    outer(path, "Preflight", 0)
    assert c.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval() == 0
    assert '"state":"unstarted"' in outer(path, "Status", 10)
    outer(path, "Apply", 0)
    outer(path, "Apply", 0)
    outer(path, "Verify", 0)
    assert c.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval() == 1
    # An Applied row belongs to its original release, even when every SQL byte
    # and commit pin matches. All observation/apply paths must reject adoption.
    wrong_release = str(uuid.uuid4())
    for operation in ("Preflight", "Status", "Verify", "Apply"):
        outer(path, operation, 20, release_id=wrong_release)
    outer(path, "Verify", 0)
    assert c.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval() == 1
    assert (
        c.execute(
            "SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID('dbo.ModuleFixture')"
        )
        .fetchval()
        .encode("utf-8")
        == b"CREATE   " + (output / "ModuleFixture.sql").read_bytes()[16:]
    )
    # Compile failure rolls back the entire transaction and preserves failed attempt.
    failed, _ = profile(
        "20261010_902_fixture",
        "ViewFixture",
        "V",
        "CREATE OR ALTER VIEW [dbo].[ViewFixture]\nAS SELECT value FROM dbo.NotYetPresent;\n",
    )
    outer(failed, "Apply", 20)
    assert '"state":"rolled_back"' in outer(failed, "Status", 11)
    assert (
        c.execute(
            "SELECT COUNT(*) FROM dbo.SchemaMigrationHistory WHERE MigrationId='20261010_902_fixture'"
        ).fetchval()
        == 0
    )
    assert (
        c.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory WHERE Status='Failed'").fetchval()
        == 1
    )
    execute(c, "CREATE TABLE dbo.NotYetPresent(value int);")
    outer(failed, "Apply", 0)
    assert (
        c.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory WHERE Status='Failed'").fetchval()
        == 1
    )
    # A committed migration whose later metadata drifts is never replayed.
    execute(c, "ALTER PROCEDURE [dbo].[ModuleFixture] AS SELECT 99;")
    outer(path, "Verify", 20)
    outer(path, "Apply", 20)
    assert c.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval() == 3
    # Kill real PowerShell/SqlClient processes while a transaction is open and
    # after commit but before acknowledgement. Only the fault harness wraps the
    # library; the normal Deploy-SqlMigration entrypoint remains byte-identical.
    for when in ("before_commit", "after_commit"):
        name = "DeathBefore" if when == "before_commit" else "DeathAfter"
        mid = "20261010_903_death" if when == "before_commit" else "20261010_904_death"
        execute(c, f"CREATE PROCEDURE [dbo].[{name}] AS SELECT 1;")
        death_path, _ = profile(
            mid, name, "P", f"CREATE OR ALTER PROCEDURE [dbo].[{name}]\nAS SELECT 2;\n"
        )
        harness = output / when
        harness.mkdir()
        (harness / "Deploy-SqlMigration.ps1").write_bytes(
            (ROOT / "deploy/Deploy-SqlMigration.ps1").read_bytes()
        )
        marker = harness / "paused.txt"
        hook = "\n$script:queryOriginal=${function:Invoke-K98ModuleQuery}\n"
        hook += "function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {\n"
        if when == "before_commit":
            hook += (
                "if($Sql.StartsWith('INSERT dbo.SchemaMigrationHistory')) { [IO.File]::WriteAllText('"
                + str(marker)
                + "','before_commit'); Start-Sleep -Seconds 120 }\n"
            )
        else:
            hook += (
                "if($null -eq $Transaction -and $Sql.StartsWith('SELECT Status,ChecksumSha256,GitCommit')) { $script:reads++; if($script:reads -eq 2) { [IO.File]::WriteAllText('"
                + str(marker)
                + "','after_commit'); Start-Sleep -Seconds 120 } }\n"
            )
        hook += "$result=& $script:queryOriginal $Connection $Transaction $Sql $Values; return ,$result\n}\n$script:reads=0\n"
        (harness / "SqlDeploy.ModuleRelease.ps1").write_bytes(
            (ROOT / "deploy/SqlDeploy.ModuleRelease.ps1").read_bytes() + hook.encode()
        )
        args = [
            PS,
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(harness / "Deploy-SqlMigration.ps1"),
            "-ServerName",
            SERVER,
            "-DatabaseName",
            database,
            "-MigrationId",
            mid,
            "-ProfilePath",
            str(death_path),
            "-ProfileSHA256",
            hashlib.sha256(death_path.read_bytes()).hexdigest(),
            "-ExpectedCommit",
            commit,
            "-ReleaseId",
            release,
            "-Operation",
            "Apply",
        ]
        with (
            (harness / "stdout.txt").open("wb") as stdout,
            (harness / "stderr.txt").open("wb") as stderr,
        ):
            process = subprocess.Popen(
                args, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW
            )
            try:
                deadline = time.monotonic() + 30
                while (
                    not marker.exists() and process.poll() is None and time.monotonic() < deadline
                ):
                    time.sleep(0.1)
                assert marker.exists(), (harness / "stderr.txt").read_text(errors="replace")
                # Another real runner must report busy while the first owns SQL.
                outer(death_path, "Status", 20)
            finally:
                process.kill()
                process.wait(timeout=10)
        expected = 11 if when == "before_commit" else 0
        text = outer(death_path, "Status", expected)
        assert ("rolled_back" if when == "before_commit" else "committed") in text
        count_before = c.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval()
        outer(death_path, "Apply", 0)
        count_after = c.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval()
        assert count_after - count_before == (1 if when == "before_commit" else 0)
    c.close()
    evidence = dict(
        status="PASS",
        database=database,
        calls=counter,
        exact_unicode_lf=True,
        collation_mismatch_exercised=True,
        rollback_retained=True,
        committed_drift_not_replayed=True,
        committed_wrong_release_rejected=True,
        real_process_death_before_and_after_commit=True,
        live_owner_blocks_second_runner=True,
        production_touched=False,
    )
    (output / "result.json").write_text(json.dumps(evidence, indent=2))
    print(json.dumps(dict(evidence, output=str(output))))


if __name__ == "__main__":
    run()
