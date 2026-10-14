"""Actual SqlClient table-profile rehearsal in an explicitly approved disposable DB.

Adds isolated fixture schemas and missing deployment ledgers; retains all evidence
and fixtures. Never creates/drops a database or connects to production.
"""

import argparse
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

from build_history_release_profile import profile
import pyodbc

ROOT = Path(__file__).resolve().parents[1]
SERVER = r"lpc:localhost\K98DEV"
PS = r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"


def run(database):
    expected = r"9SX2VF4\K98DEV|" + database
    if (
        not database.startswith("K98_S8B_Disposable_ExportHistory_")
        or not database.replace("_", "").isalnum()
        or os.environ.get("K98_TABLE_TEST_APPROVED_TARGET") != expected
    ):
        raise ValueError("Exact approved disposable database required")
    run_id = uuid.uuid4().hex[:10]
    output = ROOT / "validation/artifacts" / ("tables_" + run_id)
    output.mkdir(parents=True, exist_ok=False)
    c = pyodbc.connect(
        f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE={database};"
        "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;",
        autocommit=True,
        timeout=5,
    )
    assert (
        c.execute("SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))").fetchval()
        == r"9SX2VF4\K98DEV"
    )
    assert c.execute("SELECT DB_NAME()").fetchval() == database

    def execute(sql, *args):
        cursor = c.cursor()
        try:
            cursor.execute(sql, *args)
            while cursor.nextset():
                pass
        finally:
            cursor.close()

    for name in ("SchemaMigrationHistory", "DeploymentRunHistory"):
        if c.execute("SELECT OBJECT_ID(?,N'U')", "dbo." + name).fetchval() is None:
            execute((ROOT / f"sql_schema/dbo.{name}.Table.sql").read_text(encoding="utf-8-sig"))
    backup_dir = c.execute(
        "SELECT CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath'))"
    ).fetchval()
    backup = str(Path(backup_dir) / (database + "_updater_" + run_id + ".bak"))
    execute(f"BACKUP DATABASE [{database}] TO DISK=? WITH CHECKSUM;", backup)
    env = c.execute(
        "SELECT CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),'Collation')),"
        "CONVERT(nvarchar(128),DATABASEPROPERTYEX('tempdb','Collation')),compatibility_level "
        "FROM sys.databases WHERE database_id=DB_ID()"
    ).fetchone()
    release, commit = str(uuid.uuid4()), "a" * 40
    counter, observations = 0, []

    def fixture(label):
        schema = "Updater_" + run_id + "_" + label
        execute(f"CREATE SCHEMA [{schema}]")
        execute(
            f"CREATE TABLE [{schema}].[SourceExportIntent](SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,"
            "KVK_NO int NOT NULL,IntentID uniqueidentifier NOT NULL,UNIQUE(SourceKey,KVK_NO,IntentID));"
        )
        p = profile(*env)
        p["migration_id"] = "20261013_901_" + run_id + "_" + label
        for table in p["tables"]:
            table["schema"] = schema
            for fk in table["foreign_keys"]:
                fk["schema"] = schema
        return p

    def save(p):
        path = output / (p["migration_id"] + ".release.json")
        path.write_text(json.dumps(p, indent=2) + "\n", encoding="utf-8")
        return path

    def arguments(path, operation, runner=None, release_id=None):
        return [
            PS,
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(runner or ROOT / "deploy/Deploy-SqlMigration.ps1"),
            "-ServerName",
            SERVER,
            "-DatabaseName",
            database,
            "-MigrationId",
            json.loads(path.read_text())["migration_id"],
            "-ProfilePath",
            str(path),
            "-ProfileSHA256",
            hashlib.sha256(path.read_bytes()).hexdigest(),
            "-ExpectedCommit",
            commit,
            "-ReleaseId",
            release_id or release,
            "-Operation",
            operation,
        ]

    def outer(path, operation, expected_code, **kwargs):
        nonlocal counter
        counter += 1
        result = subprocess.run(
            arguments(path, operation, **kwargs), capture_output=True, timeout=60
        )
        (output / f"{counter:02d}-{operation}.stdout.txt").write_bytes(result.stdout)
        (output / f"{counter:02d}-{operation}.stderr.txt").write_bytes(result.stderr)
        assert result.returncode == expected_code, (
            result.returncode,
            result.stdout.decode(errors="replace"),
            result.stderr.decode(errors="replace"),
        )
        observations.append(dict(case=counter, operation=operation, expected_exit=expected_code))
        return result.stdout.decode(errors="replace")

    def attempts(p):
        return c.execute(
            "SELECT COUNT(*) FROM dbo.DeploymentRunHistory WHERE JSON_VALUE(ErrorMessage,'$.migration_id')=?",
            p["migration_id"],
        ).fetchval()

    # Compare the generated contract against the already-reviewed SQL migration,
    # in an isolated schema. Existing matching tables without this profile's
    # own receipt remain non-adoptable by the public runner.
    legacy = fixture("legacy")
    legacy_schema = legacy["tables"][0]["schema"]
    migration = (ROOT / "migrations/20261013_001_kvk_export_history.sql").read_text(
        encoding="utf-8-sig"
    )
    migration = migration.replace("KVK.", legacy_schema + ".").replace(
        "SCHEMA_ID(N'KVK')", "SCHEMA_ID(N'" + legacy_schema + "')"
    )
    execute(migration)
    legacy_path = save(legacy)
    verification = output / "verify-legacy-shape.ps1"
    verification.write_text(
        ". '" + str(ROOT / "deploy/SqlDeploy.ModuleRelease.ps1") + "'\n"
        "$path='" + str(legacy_path) + "'\n"
        "$loaded=Read-K98ModuleProfile $path (Get-K98ModuleHash ([IO.File]::ReadAllBytes($path))) '"
        + legacy["migration_id"]
        + "'\n"
        "$c=[Data.SqlClient.SqlConnection]::new('Data Source="
        + SERVER
        + ";Initial Catalog="
        + database
        + ";Integrated Security=True;Encrypt=True;TrustServerCertificate=True;')\n"
        "try{$c.Open();Assert-K98ModuleImages $c $null $loaded $true;Write-Output 'LEGACY_SHAPE_MATCH'}finally{$c.Dispose()}\n",
        encoding="utf-8",
    )
    checked = subprocess.run(
        [
            PS,
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(verification),
        ],
        capture_output=True,
        timeout=30,
    )
    (output / "legacy-shape.stdout.txt").write_bytes(checked.stdout)
    (output / "legacy-shape.stderr.txt").write_bytes(checked.stderr)
    assert (
        checked.returncode == 0 and b"LEGACY_SHAPE_MATCH" in checked.stdout
    ), checked.stderr.decode(errors="replace")

    # The alternative legacy installation path must also reject physical drift.
    def legacy_refuses_drift():
        try:
            execute(migration)
        except pyodbc.Error as exc:
            assert "History unexpected trigger, partition, compression or table mode" in str(exc)
        else:
            raise AssertionError("Legacy migration accepted physical table drift")
        assert c.execute("SELECT @@TRANCOUNT").fetchval() == 0

    for compression in ("ROW", "PAGE"):
        execute(
            f"ALTER INDEX ALL ON [{legacy_schema}].SourceExportHistoryRow "
            f"REBUILD WITH (DATA_COMPRESSION = {compression});"
        )
        legacy_refuses_drift()
        execute(
            f"ALTER INDEX ALL ON [{legacy_schema}].SourceExportHistoryRow "
            "REBUILD WITH (DATA_COMPRESSION = NONE);"
        )
        execute(migration)
    partition = "Updater_" + run_id + "_partition"
    execute(f"CREATE PARTITION FUNCTION [{partition}] (bigint) AS RANGE RIGHT FOR VALUES (1);")
    execute(f"CREATE PARTITION SCHEME [{partition}] AS PARTITION [{partition}] ALL TO ([PRIMARY]);")
    execute(
        f"ALTER TABLE [{legacy_schema}].SourceExportHistoryRow DROP CONSTRAINT PK_SourceExportHistoryRow;"
        f"ALTER TABLE [{legacy_schema}].SourceExportHistoryRow ADD CONSTRAINT PK_SourceExportHistoryRow "
        f"PRIMARY KEY CLUSTERED(IntentID,GuildID,HistoryVersion,Ordinal) ON [{partition}](Ordinal);"
    )
    legacy_refuses_drift()
    (output / "legacy-physical-drift.json").write_text(
        json.dumps({"ROW": "REFUSED", "PAGE": "REFUSED", "partition_scheme": "REFUSED"}),
        encoding="utf-8",
    )

    p = fixture("success")
    path = save(p)
    outer(path, "Preflight", 0)
    assert attempts(p) == 0
    outer(path, "Status", 10)
    outer(path, "Apply", 0)
    outer(path, "Apply", 0)
    outer(path, "Verify", 0)
    assert attempts(p) == 1
    schema = p["tables"][0]["schema"]
    intent = str(uuid.uuid4())
    execute(f"INSERT [{schema}].SourceExportIntent VALUES('snapshot_report_v1',16,?);", intent)
    execute(
        f"INSERT [{schema}].SourceExportHistory VALUES(?,'123','source_export_history_v1','snapshot_report_v1',16,0x00,SYSUTCDATETIME(),0,0x00);",
        intent,
    )
    outer(path, "Verify", 0)
    assert c.execute(f"SELECT COUNT(*) FROM [{schema}].SourceExportHistory").fetchval() == 1
    for op in ("Preflight", "Status", "Verify", "Apply"):
        outer(path, op, 20, release_id=str(uuid.uuid4()))
    assert attempts(p) == 1
    adoption = deepcopy(p)
    adoption["migration_id"] += "_adopt"
    outer(save(adoption), "Apply", 20)
    assert attempts(adoption) == 0

    partial = fixture("partial")
    schema_partial = partial["tables"][0]["schema"]
    execute(f"CREATE TABLE [{schema_partial}].SourceExportHistory(Unexpected int);")
    outer(save(partial), "Preflight", 20)
    assert attempts(partial) == 0

    invalid = fixture("rollback")
    invalid["tables"][1]["foreign_keys"][0]["columns"] = ["Ordinal", "GuildID", "HistoryVersion"]
    bad_path = save(invalid)
    outer(bad_path, "Apply", 20)
    assert '"state":"rolled_back"' in outer(bad_path, "Status", 11)
    assert (
        c.execute(
            "SELECT OBJECT_ID(?)", invalid["tables"][0]["schema"] + ".SourceExportHistory"
        ).fetchval()
        is None
    )
    assert attempts(invalid) == 1

    # A prior attempt under the other supported profile owns the migration ID
    # too. Simulate that retained historical receipt with absent table preimages.
    execute(
        "UPDATE dbo.DeploymentRunHistory SET BranchName='module_grants_v1' "
        "WHERE JSON_VALUE(ErrorMessage,'$.migration_id')=?",
        invalid["migration_id"],
    )
    outer(bad_path, "Status", 20)
    outer(bad_path, "Apply", 20)
    assert attempts(invalid) == 1

    # Exact entrypoint, instrumented library only for deterministic real process death.
    for when in ("before_commit", "after_commit"):
        death = fixture(when)
        death_path = save(death)
        harness = output / when
        harness.mkdir()
        for name in ("Deploy-SqlMigration.ps1", "SqlDeploy.TableRelease.ps1"):
            (harness / name).write_bytes((ROOT / "deploy" / name).read_bytes())
        marker = harness / "paused.txt"
        hook = "\n$script:queryOriginal=${function:Invoke-K98ModuleQuery}\n$script:reads=0\n"
        hook += "function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {\n"
        if when == "before_commit":
            hook += (
                "if($Sql.StartsWith('INSERT dbo.SchemaMigrationHistory')) { [IO.File]::WriteAllText('"
                + str(marker)
                + "','paused'); Start-Sleep -Seconds 120 }\n"
            )
        else:
            hook += (
                "if($null -eq $Transaction -and $Sql.StartsWith('SELECT Status,ChecksumSha256,GitCommit')) { $script:reads++; if($script:reads -eq 2){ [IO.File]::WriteAllText('"
                + str(marker)
                + "','paused'); Start-Sleep -Seconds 120 } }\n"
            )
        hook += "$result=& $script:queryOriginal $Connection $Transaction $Sql $Values; return ,$result\n}\n"
        (harness / "SqlDeploy.ModuleRelease.ps1").write_bytes(
            (ROOT / "deploy/SqlDeploy.ModuleRelease.ps1").read_bytes() + hook.encode()
        )
        with (harness / "stdout.txt").open("wb") as out, (harness / "stderr.txt").open("wb") as err:
            process = subprocess.Popen(
                arguments(death_path, "Apply", harness / "Deploy-SqlMigration.ps1"),
                stdout=out,
                stderr=err,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            try:
                deadline = time.monotonic() + 30
                while (
                    not marker.exists() and process.poll() is None and time.monotonic() < deadline
                ):
                    time.sleep(0.1)
                assert marker.exists(), (harness / "stderr.txt").read_text(errors="replace")
                outer(death_path, "Status", 20)
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=10)
        outer(death_path, "Status", 11 if when == "before_commit" else 0)
        before_count = attempts(death)
        outer(death_path, "Apply", 0)
        assert attempts(death) - before_count == (1 if when == "before_commit" else 0)
        outer(death_path, "Verify", 0)

    # Metadata drift must be refused without replay; retained data stays present.
    execute(f"ALTER TABLE [{schema}].SourceExportHistory ADD Unexpected int NULL;")
    outer(path, "Verify", 20)
    outer(path, "Apply", 20)
    assert attempts(p) == 1
    assert c.execute(f"SELECT COUNT(*) FROM [{schema}].SourceExportHistory").fetchval() == 1
    result = dict(
        status="PASS",
        server=r"9SX2VF4\K98DEV",
        database=database,
        cases=counter,
        backup=backup,
        evidence=str(output),
        observations=observations,
        production_touched=False,
        qualification="Actual Windows PowerShell 5.1/SqlClient; isolated schemas retained in approved disposable DB",
    )
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    c.close()
    print(json.dumps(result))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", required=True)
    run(parser.parse_args().database)
