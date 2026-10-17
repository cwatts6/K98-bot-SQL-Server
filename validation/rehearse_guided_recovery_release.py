"""Qualify the real coordinated SQL adapter on fresh retained local databases.

The expected images come from installing immutable source definitions and the
reviewed literal migrations in an independent fixture, never from the target.
Only this disposable harness injects failures into retained copies of the runner.
Run with --allow-disposable-sql. No production endpoint or existing DB is accepted.
"""

import hashlib
import json
from pathlib import Path
import re
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
    for path in fixture.git(
        "diff", "--name-only", fixture.BASE, fixture.HEAD, "--", "sql_schema"
    )
    .decode()
    .splitlines()
)

# Independently transcribed from bot grant-plan delta ded19ccd..c2d9a961;
# never obtained by executing or parsing the adapter being qualified.
APPLICATION_GRANTS = {
    "dbo.ExportContainedStream": ("SELECT",),
    "dbo.ExportContainedTarget": ("SELECT",),
    "dbo.ExportReplacementActivation": ("SELECT",),
    "dbo.ExportReplacementDelivery": ("INSERT", "SELECT"),
    "dbo.ExportReplacementPlan": ("SELECT",),
    "dbo.ExportReplacementTarget": ("SELECT",),
    "dbo.ExportReplacementVerification": ("SELECT",),
    "dbo.ExportTargetContainment": ("SELECT",),
    "dbo.RecoveryAction": ("INSERT", "SELECT", "UPDATE"),
    "dbo.RecoveryIncident": ("INSERT", "SELECT", "UPDATE"),
    "dbo.RecoveryInputDraft": ("INSERT", "SELECT", "UPDATE"),
    "dbo.usp_ExportJobContainTargets": ("EXECUTE",),
    "dbo.usp_ExportReplacementActivate": ("EXECUTE",),
    "dbo.usp_ExportReplacementPlanCreate": ("EXECUTE",),
    "dbo.usp_ExportReplacementVerificationTransition": ("EXECUTE",),
}


def install_application_baseline(connection):
    # Reproduce existing object-level evidence role permissions from immutable
    # installation source. The adapter fingerprints these grants as well as DDL.
    # Select only literal statements for this fixture's existing affected objects;
    # never execute the historical installation scripts or infer grants from live SQL.
    selected = []
    for path, count in (
        ("20261001_004_export_execution_evidence_installation.sql", 15),
        ("20261001_005_manual_export_registration_installation.sql", 2),
    ):
        source = fixture.source(fixture.BASE, "migrations/" + path)
        statements = re.findall(
            r"(?m)^(?:GRANT|DENY) [A-Z ,]+ ON OBJECT::([A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*) TO (?:public|ExportExecutionAuthority|ExportExecutionReader);$",
            source,
        )
        admitted = [name for name in statements if name in NAMES]
        assert len(admitted) == count, (path, admitted)
        lines = [
            line
            for line in source.splitlines()
            if re.fullmatch(
                r"(?:GRANT|DENY) [A-Z ,]+ ON OBJECT::(?:"
                + "|".join(map(re.escape, admitted))
                + r") TO (?:public|ExportExecutionAuthority|ExportExecutionReader);",
                line,
            )
        ]
        assert len(lines) == count
        selected.extend(lines)
    assert len(selected) == 17 and len(set(selected)) == 17
    fixture.execute(connection, "\n".join(selected))
    # Reconstruct the two reviewed installed representations from immutable Git
    # bodies. Never install a definition taken from a live database as expected.
    for name, leading, trailing, expected in (
        (
            "dbo.sp_TARGETS_MASTER",
            "\n",
            "\n\n",
            "578319ad6aa111babd04e4dee61f333699b9d8341aebd682989774dfc2ae616c",
        ),
        (
            "dbo.usp_ExportManualOutputEnrollmentTransition",
            "",
            "",
            "698f8b6c8acf014bad92c5f3bf994abb3cc8acdd5551efa5a8ed9ec486319752",
        ),
    ):
        raw = fixture.source(
            fixture.BASE, "sql_schema/" + name + ".StoredProcedure.sql"
        )
        declaration = re.search(
            r"(?m)^(?:CREATE(?: OR ALTER)?|ALTER)\s+PROCEDURE\b", raw
        )
        assert declaration, name
        body = next(fixture.batches(raw[declaration.end() :])).strip()
        installed = leading + "CREATE   PROCEDURE " + body + trailing
        canonical = (
            installed.replace("CREATE   PROCEDURE", "CREATE PROCEDURE", 1)
            if not leading
            else installed
        )
        assert hashlib.sha256(canonical.encode("utf-16le")).hexdigest() == expected
        fixture.execute(
            connection,
            (leading + "CREATE OR ALTER PROCEDURE " + body + trailing).replace(
                "\n", "\r\n"
            ),
        )
    fixture.execute(
        connection,
        """CREATE USER S11_ExportApplication WITHOUT LOGIN;
CREATE ROLE ExportLegacyEntryReader AUTHORIZATION dbo;
CREATE USER ImportProcUser WITHOUT LOGIN;
ALTER ROLE ExportExecutionAuthority ADD MEMBER S11_ExportApplication;
ALTER ROLE ExportLegacyEntryReader ADD MEMBER S11_ExportApplication;
GRANT EXECUTE ON OBJECT::dbo.sp_TARGETS_MASTER TO ExportLegacyEntryReader;
GRANT EXECUTE ON OBJECT::dbo.sp_TARGETS_MASTER TO ImportProcUser;
GRANT SELECT,UPDATE ON OBJECT::KVK.SourceOutputPool TO S11_ExportApplication;
GRANT SELECT ON OBJECT::dbo.ExportExecutionStream TO S11_ExportApplication;
GRANT INSERT,SELECT,UPDATE ON OBJECT::dbo.ExportPreparation TO S11_ExportApplication;
GRANT EXECUTE ON OBJECT::dbo.sp_TARGETS_MASTER TO S11_ExportApplication;""",
    )


def legacy_import_permissions(connection):
    """Preserve the existing importer grant; the production adapter never adds it.

    MINI_AMD's 2026-10-17 metadata report identified this one omitted fixture
    permission. Declare it explicitly above, then derive both images by running
    the immutable migrations locally; never import observed hashes as policy.
    """
    return [
        tuple(row)
        for row in connection.execute(
            "SELECT p.permission_name,p.state,USER_NAME(p.grantor_principal_id),p.minor_id "
            "FROM sys.database_permissions p WHERE p.class=1 "
            "AND p.major_id=OBJECT_ID('dbo.sp_TARGETS_MASTER') "
            "AND p.grantee_principal_id=USER_ID('ImportProcUser') ORDER BY 1,2,3,4"
        )
    ]


def application_permissions(connection):
    return [
        tuple(row)
        for row in connection.execute(
            "SELECT SCHEMA_NAME(o.schema_id)+'.'+o.name,p.permission_name,p.state "
            "FROM sys.database_permissions p JOIN sys.objects o ON o.object_id=p.major_id "
            "WHERE p.class=1 AND p.grantee_principal_id=USER_ID('S11_ExportApplication') "
            "ORDER BY 1,2,3"
        )
    ]


def assert_effective_grants(connection):
    expected = [
        (name, permission)
        for name, permissions in APPLICATION_GRANTS.items()
        for permission in permissions
    ]
    assert len(expected) == 22
    # Evaluate actual application effective permissions, not the deployment owner.
    fixture.execute(connection, "EXECUTE AS USER='S11_ExportApplication';")
    try:
        for name, permission in expected:
            assert (
                connection.execute(
                    "SELECT HAS_PERMS_BY_NAME(?,'OBJECT',?)", name, permission
                ).fetchval()
                == 1
            ), (name, permission)
        assert (
            connection.execute(
                "SELECT IS_ROLEMEMBER('ExportExecutionReader')"
            ).fetchval()
            == 0
        )
    finally:
        fixture.execute(connection, "REVERT;")


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
    install_application_baseline(connection)
    assert legacy_import_permissions(connection) == [("EXECUTE", "G", "dbo", 0)]
    before = image_snapshot()
    scripts = []
    for mid in fixture.MIGRATIONS:
        raw = fixture.git("show", fixture.HEAD + ":migrations/" + mid + ".sql")
        (OUTPUT / (mid + ".sql")).write_bytes(raw)
        scripts.append(dict(id=mid, sha256=hashlib.sha256(raw).hexdigest()))
        fixture.execute(connection, raw.decode("utf-8-sig").replace("\r\n", "\n"))
    for name, permissions in APPLICATION_GRANTS.items():
        fixture.execute(
            connection,
            f"GRANT {','.join(permissions)} ON OBJECT::{name} TO S11_ExportApplication;",
        )
    assert_effective_grants(connection)
    after = image_snapshot()
    assert legacy_import_permissions(connection) == [("EXECUTE", "G", "dbo", 0)]
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
    (OUTPUT / "recovery.release.json").write_text(
        json.dumps(profile, indent=2), encoding="utf-8"
    )
    report.update(
        reference_profile=str(OUTPUT / "recovery.release.json"), images=len(NAMES)
    )


def qualify_adapter(connection, report, output):
    # Backups are real; the production adapter's backup guard is not bypassed.
    fixture.execute(
        connection, f"ALTER DATABASE [{fixture.DATABASE}] SET RECOVERY SIMPLE"
    )
    directory = connection.execute(
        "SELECT CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath'))"
    ).fetchval()
    backup = str(Path(directory) / (fixture.DATABASE + ".bak"))
    cursor = connection.cursor()
    cursor.execute(
        f"BACKUP DATABASE [{fixture.DATABASE}] TO DISK=? WITH CHECKSUM;", backup
    )
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
        cases.append(
            dict(operation=operation, expected=expected, actual=result.returncode)
        )
        assert result.returncode == expected, result.stdout + result.stderr
        print(json.dumps(cases[-1]), flush=True)
        return result

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

    # Missing/misclassified application identities cannot pass preflight.
    run("Preflight", 20)
    install_application_baseline(connection)
    before = fixture.catalogue(connection)
    before_permissions = application_permissions(connection)
    run("Preflight", 0)
    # A missing legacy grant and an additional permission both remain drift.
    # The corrected profile preserves exactly one existing EXECUTE permission.
    for change, restore in (
        (
            "REVOKE EXECUTE ON OBJECT::dbo.sp_TARGETS_MASTER FROM ImportProcUser;",
            "GRANT EXECUTE ON OBJECT::dbo.sp_TARGETS_MASTER TO ImportProcUser;",
        ),
        (
            "GRANT VIEW DEFINITION ON OBJECT::dbo.sp_TARGETS_MASTER TO ImportProcUser;",
            "REVOKE VIEW DEFINITION ON OBJECT::dbo.sp_TARGETS_MASTER FROM ImportProcUser;",
        ),
    ):
        fixture.execute(connection, change)
        result = run("Preflight", 20)
        diagnostic = " ".join((result.stdout + result.stderr).split())
        assert (
            "dbo.sp_TARGETS_MASTER expected=" in diagnostic
            and "observed=" in diagnostic
        )
        fixture.execute(connection, restore)
        run("Preflight", 0)
    assert legacy_import_permissions(connection) == [("EXECUTE", "G", "dbo", 0)]
    run("Verify", 10)
    assert fixture.catalogue(connection) == before
    assert (
        connection.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval()
        == 0
    )
    # A changed body is not an alternate spelling. Check the literal migration's
    # own guard independently from the adapter's complete-image preflight.
    for name in (
        "dbo.usp_ExportManualOutputEnrollmentTransition",
        "dbo.sp_TARGETS_MASTER",
    ):
        call = "Invoke-K98RecoveryChain $connection $transaction $loaded $ExpectedCommit $attempt"
        changed = injected_runner(
            "changed-body-" + name.split(".")[1],
            call,
            "$null=Invoke-K98ModuleQuery $connection $transaction 'ALTER PROCEDURE "
            + name
            + " AS SELECT 123456;'\n                "
            + call,
        )
        result = run("Apply", 20, runner=changed)
        assert "Exact reviewed" in result.stdout + result.stderr
        run("Verify", 11)
        assert fixture.catalogue(connection) == before
        assert application_permissions(connection) == before_permissions
        assert (
            connection.execute(
                "SELECT COUNT(*) FROM dbo.SchemaMigrationHistory"
            ).fetchval()
            == 0
        )
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
            while "DISPOSABLE_FAULT_READY" not in crash_output.read_text(
                encoding="utf-8"
            ):
                assert process.poll() is None, crash_output.read_text(encoding="utf-8")
                assert time.monotonic() < deadline, "Fault boundary was not reached"
                time.sleep(0.2)
        finally:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=10)
    run("Verify", 11)
    assert fixture.catalogue(connection) == before
    assert application_permissions(connection) == before_permissions
    assert (
        connection.execute("SELECT COUNT(*) FROM dbo.SchemaMigrationHistory").fetchval()
        == 0
    )
    # All twelve scripts and receipts have executed before this rollback fault.
    rollback = injected_runner(
        "rollback-runner",
        "$commitRequested=$true",
        "throw 'Injected interruption before commit'\n            $commitRequested=$true",
    )
    run("Apply", 20, runner=rollback)
    assert fixture.catalogue(connection) == before
    assert application_permissions(connection) == before_permissions
    assert (
        connection.execute("SELECT COUNT(*) FROM dbo.SchemaMigrationHistory").fetchval()
        == 0
    )
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
    expected_added = {
        (name, permission, "G")
        for name, permissions in APPLICATION_GRANTS.items()
        for permission in permissions
    }
    assert (
        set(application_permissions(connection))
        == set(before_permissions) | expected_added
    )
    assert_effective_grants(connection)
    assert legacy_import_permissions(connection) == [("EXECUTE", "G", "dbo", 0)]
    fixture.execute(
        connection,
        "REVOKE EXECUTE ON OBJECT::dbo.sp_TARGETS_MASTER FROM ImportProcUser;",
    )
    result = run("Verify", 20)
    assert "dbo.sp_TARGETS_MASTER expected=" in " ".join(
        (result.stdout + result.stderr).split()
    )
    fixture.execute(
        connection, "GRANT EXECUTE ON OBJECT::dbo.sp_TARGETS_MASTER TO ImportProcUser;"
    )
    run("Verify", 0)
    attempts = connection.execute(
        "SELECT COUNT(*) FROM dbo.DeploymentRunHistory"
    ).fetchval()
    run("Apply", 0)
    assert (
        connection.execute("SELECT COUNT(*) FROM dbo.DeploymentRunHistory").fetchval()
        == attempts
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
    # Neither an Applied receipt nor all object definitions conceal grant/role drift.
    fixture.execute(
        connection,
        "REVOKE UPDATE ON OBJECT::dbo.RecoveryIncident FROM S11_ExportApplication;",
    )
    run("Verify", 20)
    fixture.execute(
        connection,
        "GRANT UPDATE ON OBJECT::dbo.RecoveryIncident TO S11_ExportApplication;",
    )
    run("Verify", 0)
    fixture.execute(
        connection, "ALTER ROLE ExportExecutionReader ADD MEMBER S11_ExportApplication;"
    )
    run("Verify", 20)
    fixture.execute(
        connection,
        "ALTER ROLE ExportExecutionReader DROP MEMBER S11_ExportApplication;",
    )
    run("Verify", 0)
    # A valid receipt cannot conceal drift in a committed module.
    fixture.execute(
        connection, "ALTER PROCEDURE dbo.usp_ExportJobContainTargets AS SELECT 1;"
    )
    run("Verify", 20)
    report.update(
        profile_sha256=digest,
        release_id=release,
        cases=cases,
        artifacts=str(OUTPUT),
        backup=backup,
        application_grants=len(expected_added),
        application_permissions_verified=True,
        legacy_import_execute_preserved=True,
        post_test_state="retained intentional module drift; not an install target",
    )


if __name__ == "__main__":
    fixture.main(build_reference)
    fixture.DATABASE = "K98_P0a_Atomic_" + uuid4().hex[:12]
    fixture.main(qualify_adapter)
    print(str(OUTPUT), flush=True)
