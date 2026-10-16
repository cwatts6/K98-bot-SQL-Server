"""Qualify the real coordinated SQL adapter on fresh retained local databases.

The expected images come from installing immutable source definitions and the
reviewed literal migrations in an independent fixture, never from the target.
Only this disposable harness injects failures into retained copies of the runner.
Run with --allow-disposable-sql. No production endpoint or existing DB is accepted.
"""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from uuid import uuid4

import rehearse_guided_recovery_migrations as fixture

ROOT = fixture.ROOT
PS = r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
PROFILE_ID = "20261016_003_guided_recovery_release"
OUTPUT = Path(tempfile.mkdtemp(prefix="K98_P0a_Release_"))
NAMES = sorted(
    path.removeprefix("sql_schema/").rsplit(".", 2)[0]
    for path in fixture.git("diff", "--name-only", fixture.BASE, fixture.HEAD, "--", "sql_schema")
    .decode()
    .splitlines()
)


def powershell(script, *arguments):
    result = subprocess.run(
        [
            PS,
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            *arguments,
        ],
        capture_output=True,
        text=True,
        timeout=120,
    )
    return result


def image_snapshot():
    script = OUTPUT / "snapshot.ps1"
    if not script.exists():
        script.write_text(
            r"""param([string]$Root,[string]$Server,[string]$Database,[string]$Names)
$ErrorActionPreference='Stop'
. "$Root\deploy\SqlDeploy.ModuleRelease.ps1"
. "$Root\deploy\SqlDeploy.RecoveryRelease.ps1"
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source']=$Server;$builder['Initial Catalog']=$Database
$builder['Integrated Security']=$true;$builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true
$c=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
try {
 $c.Open();$images=@{}
 foreach($name in (Get-Content -LiteralPath $Names -Raw|ConvertFrom-Json)){$images[$name]=Get-K98RecoveryImage $c $null $name}
 [Console]::WriteLine(($images|ConvertTo-Json -Compress))
}finally{$c.Dispose()}
""",
            encoding="utf-8",
        )
    names = OUTPUT / "names.json"
    names.write_text(json.dumps(NAMES), encoding="utf-8")
    result = powershell(
        script,
        "-Root",
        str(ROOT),
        "-Server",
        fixture.SERVER,
        "-Database",
        fixture.DATABASE,
        "-Names",
        str(names),
    )
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    images = json.loads(result.stdout)
    assert set(images) == set(NAMES) and len(images) == 26
    return images


def build_reference(connection, report, output):
    before = image_snapshot()
    scripts = []
    for mid in fixture.MIGRATIONS:
        raw = fixture.git("show", fixture.HEAD + ":migrations/" + mid + ".sql")
        (OUTPUT / (mid + ".sql")).write_bytes(raw)
        scripts.append(dict(id=mid, sha256=hashlib.sha256(raw).hexdigest()))
        fixture.execute(connection, raw.decode("utf-8-sig").replace("\r\n", "\n"))
    after = image_snapshot()
    environment = connection.execute(
        "SELECT CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),'Collation')),"
        "CONVERT(nvarchar(128),DATABASEPROPERTYEX('tempdb','Collation')),"
        "compatibility_level FROM sys.databases WHERE database_id=DB_ID()"
    ).fetchone()
    profile = dict(
        version=1,
        profile="coordinated_recovery_v1",
        migration_id=PROFILE_ID,
        database_collation=environment[0],
        tempdb_collation=environment[1],
        compatibility_level=environment[2],
        requires=[],
        scripts=scripts,
        images=[dict(name=n, before=before[n], after=after[n]) for n in NAMES],
    )
    (OUTPUT / "recovery.release.json").write_text(json.dumps(profile, indent=2), encoding="utf-8")
    report.update(reference_profile=str(OUTPUT / "recovery.release.json"), images=len(NAMES))


def qualify_adapter(connection, report, output):
    # Backups are real; the production adapter's backup guard is not bypassed.
    fixture.execute(connection, f"ALTER DATABASE [{fixture.DATABASE}] SET RECOVERY SIMPLE")
    directory = connection.execute(
        "SELECT CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath'))"
    ).fetchval()
    backup = str(Path(directory) / (fixture.DATABASE + ".bak"))
    cursor = connection.cursor()
    cursor.execute(f"BACKUP DATABASE [{fixture.DATABASE}] TO DISK=? WITH CHECKSUM;", backup)
    while cursor.nextset():
        pass
    cursor.close()
    release = str(uuid4())
    path = OUTPUT / "recovery.release.json"
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    cases = []

    def run(operation, expected, *, runner=ROOT / "deploy", identity=release):
        result = powershell(
            runner / "Deploy-SqlMigration.ps1",
            "-ServerName",
            fixture.SERVER,
            "-DatabaseName",
            fixture.DATABASE,
            "-MigrationId",
            PROFILE_ID,
            "-ProfilePath",
            str(path),
            "-ProfileSHA256",
            digest,
            "-ExpectedCommit",
            fixture.HEAD,
            "-ReleaseId",
            identity,
            "-Operation",
            operation,
        )
        (OUTPUT / f"case-{len(cases):02d}-{operation}.txt").write_text(
            result.stdout + result.stderr, encoding="utf-8"
        )
        cases.append(dict(operation=operation, expected=expected, actual=result.returncode))
        assert result.returncode == expected, result.stdout + result.stderr
        print(json.dumps(cases[-1]), flush=True)

    def injected_runner(name, old, new):
        target = OUTPUT / name
        target.mkdir()
        for member in (
            "Deploy-SqlMigration.ps1",
            "SqlDeploy.ModuleRelease.ps1",
            "SqlDeploy.RecoveryRelease.ps1",
        ):
            shutil.copyfile(ROOT / "deploy" / member, target / member)
        module = target / "SqlDeploy.ModuleRelease.ps1"
        text = module.read_text(encoding="utf-8-sig")
        assert text.count(old) == 1
        module.write_text(text.replace(old, new), encoding="utf-8")
        return target

    before = fixture.catalogue(connection)
    run("Preflight", 0)
    run("Verify", 10)
    assert fixture.catalogue(connection) == before
    assert connection.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval() == 0
    # An external active owner is unresolved; it must not be called unstarted.
    fixture.execute(
        connection,
        "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'K98_Module_Release_v1',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; IF @r<0 THROW 51959,'Fixture lock unavailable.',1;",
    )
    run("Verify", 20)
    fixture.execute(
        connection,
        "EXEC sys.sp_releaseapplock @Resource=N'K98_Module_Release_v1',@LockOwner='Session';",
    )
    # Kill only the process created here after it confirms reaching the real
    # uncommitted boundary. A later verifier must prove rollback independently.
    crash = injected_runner(
        "crash-runner",
        "$commitRequested=$true",
        "[Console]::WriteLine('DISPOSABLE_FAULT_READY'); [Console]::Out.Flush(); Start-Sleep -Seconds 120\n            $commitRequested=$true",
    )
    crash_output = OUTPUT / "process-interruption.txt"
    with crash_output.open("w", encoding="utf-8") as stream:
        process = subprocess.Popen(
            [
                PS,
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(crash / "Deploy-SqlMigration.ps1"),
                "-ServerName",
                fixture.SERVER,
                "-DatabaseName",
                fixture.DATABASE,
                "-MigrationId",
                PROFILE_ID,
                "-ProfilePath",
                str(path),
                "-ProfileSHA256",
                digest,
                "-ExpectedCommit",
                fixture.HEAD,
                "-ReleaseId",
                release,
                "-Operation",
                "Apply",
            ],
            stdout=stream,
            stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 45
            while "DISPOSABLE_FAULT_READY" not in crash_output.read_text(encoding="utf-8"):
                assert process.poll() is None, crash_output.read_text(encoding="utf-8")
                assert time.monotonic() < deadline, "Fault boundary was not reached"
                time.sleep(0.2)
        finally:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=10)
    run("Verify", 11)
    assert fixture.catalogue(connection) == before
    assert connection.execute("SELECT COUNT(*) FROM dbo.SchemaMigrationHistory").fetchval() == 0
    # All twelve scripts and receipts have executed before this rollback fault.
    rollback = injected_runner(
        "rollback-runner",
        "$commitRequested=$true",
        "throw 'Injected interruption before commit'\n            $commitRequested=$true",
    )
    run("Apply", 20, runner=rollback)
    assert fixture.catalogue(connection) == before
    assert connection.execute("SELECT COUNT(*) FROM dbo.SchemaMigrationHistory").fetchval() == 0
    run("Verify", 11)
    run("Verify", 20, identity=str(uuid4()))
    # The real commit occurs, then the caller loses its success acknowledgement.
    lost = injected_runner(
        "lost-reply-runner",
        "$transaction.Commit();$transaction.Dispose();$transaction=$null",
        "$transaction.Commit();$transaction.Dispose();$transaction=$null; throw 'Injected lost commit acknowledgement'",
    )
    run("Apply", 20, runner=lost)
    run("Verify", 0)
    attempts = connection.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval()
    run("Apply", 0)
    assert (
        connection.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval() == attempts
    )
    assert (
        connection.execute(
            "SELECT COUNT(*) FROM dbo.SchemaMigrationHistory WHERE Status='Applied'"
        ).fetchval()
        == 13
    )
    # Child receipts are necessary, not just the outer success marker.
    child = fixture.MIGRATIONS[0]
    child_hash = json.loads(path.read_text())["scripts"][0]["sha256"]
    connection.execute(
        "UPDATE dbo.SchemaMigrationHistory SET ChecksumSha256=? WHERE MigrationId=?",
        "0" * 64,
        child,
    )
    run("Verify", 20)
    connection.execute(
        "UPDATE dbo.SchemaMigrationHistory SET ChecksumSha256=? WHERE MigrationId=?",
        child_hash,
        child,
    )
    run("Verify", 0)
    # A valid receipt cannot conceal drift in a committed module.
    fixture.execute(connection, "ALTER PROCEDURE dbo.usp_ExportJobContainTargets AS SELECT 1;")
    run("Verify", 20)
    report.update(
        profile_sha256=digest,
        release_id=release,
        cases=cases,
        artifacts=str(OUTPUT),
        backup=backup,
        post_test_state="retained intentional module drift; not an install target",
    )


if __name__ == "__main__":
    fixture.main(build_reference)
    fixture.DATABASE = "K98_P0a_Atomic_" + uuid4().hex[:12]
    fixture.main(qualify_adapter)
    print(str(OUTPUT), flush=True)
