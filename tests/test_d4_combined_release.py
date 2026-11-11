"""Native fixed-batch and receipt checks; only newly created local metadata fixtures.

The exact private installed receipt is an optional input, never a repository asset.
No production connection, provider dispatch, or retained business input is used.
"""

from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import uuid

import pytest

ROOT = Path(__file__).resolve().parents[1]
ID = "20261111_001_p02_d4_combined"
COMMIT = "a" * 40
RELEASE = "11111111-1111-4111-8111-111111111111"


def execute(c, text, *args):
    cur = c.execute(text, *args)
    while cur.nextset():
        pass


def quote(value):
    return "[" + value.replace("]", "]]") + "]"


@pytest.fixture(scope="module")
def native():
    if os.getenv("K98_D4_RELEASE_NATIVE") != "OWNED_LOCAL_METADATA_ONLY":
        pytest.skip("Requires owned local metadata database and exact private receipt")
    import pyodbc

    raw = Path(os.environ["K98_D4_INSTALLED_RECEIPT"]).read_bytes()
    assert (
        hashlib.sha256(raw).hexdigest()
        == "9a7a79500678598c120d247e8949787d04ede7a12b5af235f541f8db4553c598"
    )
    receipt = json.loads(raw.decode("utf-8-sig"))
    sections = [s for s in receipt["sections"] if s["database"] == "ROK_TRACKER"]
    observed = {
        r["requested_name"]: r
        for s in sections
        if s["name"] == "objects"
        for r in s["rows"]
    }
    grants = [r for s in sections if s["name"] == "grants" for r in s["rows"]]
    profile = json.loads((ROOT / f"migrations/{ID}.release.json").read_bytes())
    pyodbc.pooling = False
    base = r"DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost\K98DEV;Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;DATABASE="
    name = "K98_D4_ReleaseNative_" + uuid.uuid4().hex
    with closing(pyodbc.connect(base + "master;", autocommit=True, timeout=5)) as admin:
        admin.timeout = 10
        assert admin.execute("SELECT @@SERVERNAME").fetchval() == r"9SX2VF4\K98DEV"
        assert admin.execute("SELECT DB_ID(?)", name).fetchval() is None
        assert (
            admin.execute(
                "SELECT available_physical_memory_kb FROM sys.dm_os_sys_memory"
            ).fetchval()
            >= 8 * 1024**2
        )
        assert (
            admin.execute(
                "SELECT MIN(v.available_bytes) FROM sys.master_files f CROSS APPLY sys.dm_os_volume_stats(f.database_id,f.file_id)v WHERE f.database_id IN(1,2)"
            ).fetchval()
            >= 8 * 1024**3
        )
        admin.execute(
            "CREATE DATABASE " + quote(name) + " COLLATE Latin1_General_CI_AS"
        )
        try:
            with closing(
                pyodbc.connect(base + name + ";", autocommit=True, timeout=5)
            ) as c:
                c.timeout = 10
                execute(
                    c,
                    "SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET XACT_ABORT ON;SET LOCK_TIMEOUT 0;",
                )
                principals = {"dbo", "public"}
                for item in profile["images"]:
                    n = item["name"].removeprefix("dbo.")
                    row = observed.get(n)
                    if row and row["definition"]:
                        execute(c, row["definition"])
                        assert (
                            row["object_owner"] in (None, "dbo")
                            and row["schema_owner"] == "dbo"
                        )
                        if row["object_owner"] == "dbo":
                            c.execute(
                                "ALTER AUTHORIZATION ON OBJECT::dbo."
                                + quote(n)
                                + " TO dbo"
                            )
                        for g in grants:
                            if g["object_name"] != n:
                                continue
                            assert (
                                g["class_desc"] == "OBJECT_OR_COLUMN"
                                and g["minor_id"] == 0
                                and g["grantor"] == "dbo"
                                and g["state_desc"] in ("GRANT", "DENY")
                            )
                            principal = g["grantee"]
                            if principal not in principals:
                                c.execute(
                                    "CREATE USER " + quote(principal) + " WITHOUT LOGIN"
                                )
                                principals.add(principal)
                            c.execute(
                                g["state_desc"]
                                + " "
                                + g["permission_name"]
                                + " ON OBJECT::dbo."
                                + quote(n)
                                + " TO "
                                + quote(principal)
                            )
                for table in (
                    "SchemaMigrationHistory",
                    "DeploymentRunHistory",
                    "LogBackupTriggerQueue",
                ):
                    execute(
                        c,
                        (ROOT / f"sql_schema/dbo.{table}.Table.sql").read_text(
                            encoding="utf-8-sig"
                        ),
                    )
                c.execute(
                    "INSERT dbo.LogBackupTriggerQueue(ProcedureName,Reason,BackupResult) VALUES(N'fixture',N'preserve',N'unknown')"
                )
                yield c, name, profile
        finally:
            admin.execute("SET LOCK_TIMEOUT 1000;")
            admin.execute("DROP DATABASE " + quote(name))


def images(c, profile, side):
    source = (ROOT / "deploy/SqlDeploy.RecoveryRelease.ps1").read_text(
        encoding="utf-8-sig"
    )
    query = re.search(
        r"@'\n(.*?)\n'@", source.split("function Get-K98RecoveryImage", 1)[1], re.S
    )[1]
    for item in profile["images"]:
        raw = c.execute("DECLARE @name sysname=?;\n" + query, item["name"]).fetchval()
        value = hashlib.sha256(raw.encode()).hexdigest()
        assert value == item[side], item["name"]


def outcome(name, state=None, commit=COMMIT, release=RELEASE, error=None):
    proc = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-File",
            str(ROOT / "tests/native_d4_outcome.ps1"),
            "-Database",
            name,
            "-Commit",
            commit,
            "-Release",
            release,
        ],
        capture_output=True,
        text=True,
        timeout=45,
    )
    output = proc.stdout + proc.stderr
    if error:
        assert proc.returncode != 0 and error in output, output
    else:
        assert proc.returncode == 0 and "OUTCOME:" + state in output, output


def test_complete_batch_transaction_guards_and_durable_resume(native):
    import pyodbc

    c, name, profile = native
    raw = (ROOT / f"migrations/{ID}.sql").read_text(encoding="utf-8")
    assert hashlib.sha256(raw.encode()).hexdigest() == profile["script"]["sha256"]
    guard = "IF DB_NAME()<>N'ROK_TRACKER'"
    assert raw.count(guard) == 1
    # Only the target name differs in the owned fixture. The unmodified guard is
    # exercised first; the production file is never changed or passed to Apply.
    local = raw.replace(guard, "IF DB_NAME()<>N'" + name + "'")
    images(c, profile, "before")
    outcome(name, "unstarted")
    for sql, prefix, message in (
        (raw, "", "transaction required"),
        (raw, "BEGIN TRAN;", "production database required"),
        (local, "BEGIN TRAN;BEGIN TRAN;", "transaction required"),
    ):
        if prefix:
            execute(c, prefix)
        try:
            with pytest.raises(pyodbc.Error, match=message):
                execute(c, sql)
        finally:
            execute(c, "IF @@TRANCOUNT>0 ROLLBACK;")
        images(c, profile, "before")
    execute(c, "BEGIN TRAN;")
    execute(c, local)
    images(c, profile, "after")
    execute(c, "ROLLBACK;")
    images(c, profile, "before")
    outcome(name, "unstarted")
    attempt = str(uuid.uuid4())
    digest = hashlib.sha256(
        (ROOT / f"migrations/{ID}.release.json").read_bytes()
    ).hexdigest()
    binding = json.dumps(
        dict(
            migration_id=ID,
            profile_sha256=digest,
            sql_commit=COMMIT,
            release_id=RELEASE,
        )
    )
    c.execute(
        "INSERT dbo.DeploymentRunHistory(DeploymentId,StartedAtUtc,GitCommit,BranchName,MigrationCount,Status,ErrorMessage) VALUES(?,SYSUTCDATETIME(),?,'p02_d4_v1',1,'Started',?)",
        attempt,
        COMMIT,
        binding,
    )
    outcome(name, "rolled_back")
    outcome(name, commit="b" * 40, error="attempt identity/outcome differs")
    outcome(name, release=str(uuid.uuid4()), error="attempt identity/outcome differs")
    c.execute("UPDATE dbo.DeploymentRunHistory SET BranchName='p02_phase1_v1'")
    outcome(name, error="profile identity differs")
    c.execute("UPDATE dbo.DeploymentRunHistory SET BranchName='p02_d4_v1'")
    execute(c, "BEGIN TRAN;")
    execute(c, local)
    images(c, profile, "after")
    c.execute(
        "INSERT dbo.SchemaMigrationHistory(MigrationId,MigrationFile,ChecksumSha256,AppliedAtUtc,GitCommit,BranchName,DeploymentId,Status) VALUES(?,?,?,SYSUTCDATETIME(),?,'p02_d4_v1',?,'Applied')",
        ID,
        ID + ".release.json",
        digest,
        COMMIT,
        attempt,
    )
    c.execute(
        "UPDATE dbo.DeploymentRunHistory SET Status='Succeeded',FinishedAtUtc=SYSUTCDATETIME() WHERE DeploymentId=?",
        attempt,
    )
    execute(c, "COMMIT;")
    outcome(name, "committed")
    # Work arriving after commit must not be reseeded on coordinator resume.
    c.execute(
        "UPDATE dbo.MaintenanceWork SET DueGeneration=1,ClaimedGeneration=1,ClaimID=NEWID(),State='unknown' WHERE Kind='import'"
    )
    c.execute(
        "UPDATE dbo.MaintenanceBackupWork SET DueGeneration=1,ClaimedGeneration=1,ClaimID=NEWID(),State='unknown' WHERE ID=1"
    )
    c.execute(
        "UPDATE dbo.MaintenanceConfigurationWork SET DueRows=47,LastBatchRows=47 WHERE ID=1"
    )
    c.execute(
        "INSERT dbo.MaintenanceKvkWork(KVKNo,DueGeneration,DueObjectID,DueObjectCreateDate,DueHeaderRevision,State) VALUES(99,1,123,'2026-01-01',1,'unknown')"
    )
    tables = [
        "MaintenanceWork",
        "MaintenanceBackupWork",
        "MaintenanceConfigurationWork",
        "MaintenanceKvkWork",
        "LogBackupTriggerQueue",
    ]
    rows = {t: [tuple(r) for r in c.execute("SELECT * FROM dbo." + t)] for t in tables}
    for _ in range(2):
        outcome(name, "committed")
        assert {
            t: [tuple(r) for r in c.execute("SELECT * FROM dbo." + t)] for t in tables
        } == rows
    outcome(name, commit="b" * 40, error="Migration history differs")
    outcome(
        name, release=str(uuid.uuid4()), error="Committed migration release differs"
    )
    c.execute("UPDATE dbo.DeploymentRunHistory SET Status='Started'")
    outcome(name, error="Committed migration attempt differs")
    c.execute("UPDATE dbo.DeploymentRunHistory SET Status='Succeeded'")
    c.execute("ALTER TABLE dbo.MaintenanceWork ADD UnreviewedColumn int NULL")
    outcome(name, error="postimage differs")
    c.execute("ALTER TABLE dbo.MaintenanceWork DROP COLUMN UnreviewedColumn")
    outcome(name, "committed")
    execute(c, "BEGIN TRAN;")
    try:
        with pytest.raises(pyodbc.Error, match="already an object"):
            execute(c, local)
    finally:
        execute(c, "IF @@TRANCOUNT>0 ROLLBACK;")
    assert {
        t: [tuple(r) for r in c.execute("SELECT * FROM dbo." + t)] for t in tables
    } == rows
    c.execute("DELETE dbo.SchemaMigrationHistory WHERE MigrationId=?", ID)
    c.execute("UPDATE dbo.DeploymentRunHistory SET Status='Started'")
    outcome(name, error="preimage differs")


def test_native_dependency_hashes_and_fail_closed_guards(native):
    import pyodbc

    c, _, _ = native
    receipt = json.loads(
        Path(os.environ["K98_D4_INSTALLED_RECEIPT"]).read_text(encoding="utf-8-sig")
    )
    sections = [s for s in receipt["sections"] if s["database"] == "msdb"]
    row = next(
        r
        for s in sections
        if s["name"] == "objects"
        for r in s["rows"]
        if r["requested_name"] == "usp_start_rok_tracker_log_backup"
    )
    execute(c, row["definition"])
    assert row["schema_owner"] == "dbo" and row["object_owner"] in (None, "dbo")
    if row["object_owner"] == "dbo":
        c.execute(
            "ALTER AUTHORIZATION ON OBJECT::dbo.usp_start_rok_tracker_log_backup TO dbo"
        )
    for g in [
        r
        for s in sections
        if s["name"] == "grants"
        for r in s["rows"]
        if r["object_name"] == "usp_start_rok_tracker_log_backup"
    ]:
        assert (
            g["minor_id"] == 0 and g["grantor"] == "dbo" and g["state_desc"] == "GRANT"
        )
        if not c.execute(
            "SELECT COUNT(*) FROM sys.database_principals WHERE name=?", g["grantee"]
        ).fetchval():
            c.execute("CREATE USER " + quote(g["grantee"]) + " WITHOUT LOGIN")
        c.execute(
            "GRANT "
            + g["permission_name"]
            + " ON OBJECT::dbo.usp_start_rok_tracker_log_backup TO "
            + quote(g["grantee"])
        )
    execute(
        c,
        (ROOT / "qualification/p02_d4/ks4_sequence.sql").read_text(
            encoding="utf-8-sig"
        ),
    )
    source = (ROOT / "deploy/SqlDeploy.P02D4Release.ps1").read_text(
        encoding="utf-8-sig"
    )
    function = source.split("function Assert-K98D4Dependencies", 1)[1].split(
        "function Assert-K98D4Resources", 1
    )[0]
    queries = re.findall(r"@'\n(.*?)\n'@", function, re.S)
    assert len(queries) == 2
    # Test the actual SQL guards against exact receipt metadata in this owned DB.
    # System job ownership is separately observed on MINI_AMD; no job is invoked.
    guard = (
        queries[1]
        .split("IF ISNULL((SELECT IS_SRVROLEMEMBER", 1)[0]
        .replace("msdb.", "")
    )
    execute(c, guard)
    guid = re.findall(
        r"[0-9A-Fa-f]{8}-(?:[0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}", row["definition"]
    )
    assert len(guid) == 1
    jobhash = c.execute(
        "SELECT CONVERT(varchar(64),HASHBYTES('SHA2_256',UPPER(CONVERT(nvarchar(36),CONVERT(uniqueidentifier,?)))),2)",
        guid[0],
    ).fetchval()
    assert "='" + jobhash + "'" in queries[1]
    # Sequence current value is intentionally unpinned and never consumed here.
    c.execute("ALTER SEQUENCE dbo.KS4_UNO_SEQ INCREMENT BY 2")
    with pytest.raises(pyodbc.Error, match="sequence structure"):
        execute(c, guard)
    c.execute("ALTER SEQUENCE dbo.KS4_UNO_SEQ INCREMENT BY 1")
    c.execute("GRANT EXECUTE ON OBJECT::dbo.usp_start_rok_tracker_log_backup TO public")
    with pytest.raises(pyodbc.Error, match="object permissions differ"):
        execute(c, guard)
    c.execute(
        "REVOKE EXECUTE ON OBJECT::dbo.usp_start_rok_tracker_log_backup FROM public"
    )
    execute(c, guard)
    c.execute("DROP PROCEDURE dbo.usp_start_rok_tracker_log_backup")
    with pytest.raises(pyodbc.Error, match="fixed backup wrapper required"):
        execute(c, guard)
