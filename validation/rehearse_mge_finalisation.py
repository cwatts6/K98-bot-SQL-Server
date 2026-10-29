"""Native MGE qualification. Default is SELECT-only discovery; writes are opt-in.

Never creates, drops, restores or renames a database. Execution requires a separately
approved, already-created, empty database and exact source/identity/file bindings.
Reports retain incomplete cases rather than treating missing evidence as success.
"""

import argparse
from contextlib import closing
from datetime import UTC, datetime
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import types
import uuid

from build_mge_finalisation_profile import profile

ROOT = Path(__file__).resolve().parents[1]
SERVER = r"lpc:localhost\K98DEV"
IDENTITY = r"9SX2VF4\K98DEV"
DATABASE = "K98_MGE_Finalisation_Qualification_20261029_A"
PS = r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
FIXTURES = (
    "MGE_Variants",
    "MGE_Commanders",
    "MGE_Events",
    "MGE_Signups",
    "MGE_Awards",
    "MGE_SignupAudit",
    "MGE_AwardAudit",
    "MGE_ResultImports",
    "MGE_FinalResults",
    "MGE_DefaultRules",
    "MGE_RuleAudit",
    "SchemaMigrationHistory",
    "DeploymentRunHistory",
)
APPROVAL_FIELDS = {
    "version",
    "server",
    "database",
    "login",
    "create_date",
    "files",
    "backup_path",
    "bot_commit",
    "sql_commit",
    "database_collation",
    "tempdb_collation",
    "compatibility_level",
    "allow_fixture_writes",
    "allow_child_faults",
}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def connect(database):
    # No CLI/env connection-string override; import is deferred for offline guard tests.
    if database not in ("master", DATABASE):
        raise ValueError("Fixed disposable target only")
    import pyodbc

    return pyodbc.connect(
        f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE={database};"
        "Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;",
        autocommit=False,
        timeout=5,
    )


def rows(connection, sql, *args):
    with closing(connection.cursor()) as cursor:
        cursor.execute(sql, *args)
        names = [c[0] for c in cursor.description]
        return [dict(zip(names, row, strict=True)) for row in cursor.fetchall()]


def identity(connection):
    row = rows(
        connection,
        "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server,"
        "DB_NAME() AS [database], ORIGINAL_LOGIN() AS [login]",
    )[0]
    if row["server"] != IDENTITY:
        raise ValueError("Observed server identity differs; no writes")
    return row


def discover():
    """Only SELECTs on master; no temp tables, schema probes or profile preflight."""
    with closing(connect("master")) as connection:
        observed = identity(connection)
        if observed["database"] != "master":
            raise ValueError("Discovery connection identity differs")
        observed.update(
            rows(
                connection,
                "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS version,"
                "CONVERT(nvarchar(128),SERVERPROPERTY('Collation')) AS server_collation,"
                "CONVERT(nvarchar(128),DATABASEPROPERTYEX('tempdb','Collation')) AS tempdb_collation,"
                "CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultDataPath')) AS data_path,"
                "CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultLogPath')) AS log_path,"
                "CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath')) AS backup_path",
            )[0]
        )
        observed["target"] = rows(
            connection,
            "SELECT name,create_date,state_desc,collation_name,compatibility_level,"
            "recovery_model_desc,is_read_committed_snapshot_on,snapshot_isolation_state_desc "
            "FROM sys.databases WHERE name=?",
            DATABASE,
        )
        observed["target_files"] = rows(
            connection,
            "SELECT type_desc,physical_name FROM sys.master_files WHERE database_id=DB_ID(?) "
            "ORDER BY file_id",
            DATABASE,
        )
        observed["storage"] = {}
        for field in ("data_path", "log_path", "backup_path"):
            try:
                usage = shutil.disk_usage(observed[field])
                observed["storage"][field] = dict(free=usage.free, total=usage.total)
            except (OSError, TypeError) as exc:
                observed["storage"][field] = dict(unverified=type(exc).__name__)
        observed.update(
            utc=datetime.now(UTC).isoformat(),
            database_writes=False,
            proposed_database=DATABASE,
        )
        connection.rollback()
        return observed


def validate_approval(approval, expected_hash, raw):
    if (
        not re.fullmatch(r"[a-f0-9]{64}", expected_hash or "")
        or digest(raw) != expected_hash
        or not isinstance(approval, dict)
        or set(approval) != APPROVAL_FIELDS
        or type(approval["version"]) is not int
        or approval["version"] != 1
        or approval["server"] != IDENTITY
        or approval["database"] != DATABASE
        or approval["allow_fixture_writes"] is not True
        or type(approval["allow_child_faults"]) is not bool
        or not isinstance(approval["login"], str)
        or not approval["login"]
        or not isinstance(approval["create_date"], str)
        or not isinstance(approval["files"], list)
        or len(approval["files"]) != 2
        or any(
            not isinstance(path, str) or not Path(path).is_absolute()
            for path in approval["files"]
        )
        or not isinstance(approval["backup_path"], str)
        or not Path(approval["backup_path"]).is_absolute()
        or Path(approval["backup_path"]).name != DATABASE + "_qualification.bak"
        or any(
            not isinstance(approval[k], str)
            or not re.fullmatch(r"[a-f0-9]{40}", approval[k])
            for k in ("bot_commit", "sql_commit")
        )
    ):
        raise ValueError("Exact reviewed approval bytes and bindings required")
    if (
        os.environ.get("K98_MGE_APPROVED_TARGET")
        != IDENTITY + "|" + DATABASE + "|" + expected_hash
    ):
        raise ValueError("Separate exact write opt-in required")
    profile(
        approval["database_collation"],
        approval["tempdb_collation"],
        approval["compatibility_level"],
    )


def verify_checkout(root, commit):
    def git(*args):
        return subprocess.check_output(
            ["git", "--no-optional-locks", "-C", str(root), *args], timeout=30
        )

    if git("rev-parse", "HEAD").decode().strip() != commit:
        raise ValueError("Exact approved source commit required")
    if git("status", "--porcelain", "--untracked-files=normal").strip():
        raise ValueError("Clean reviewed checkout required")
    # Executed bytes must equal the reviewed blobs, allowing only Git newline conversion.
    manifest = {}
    paths = [
        p
        for p in git("ls-files", "-z").decode().split("\0")
        if p and p.endswith((".py", ".ps1", ".sql", ".json"))
    ]
    batch = subprocess.run(
        ["git", "--no-optional-locks", "-C", str(root), "cat-file", "--batch"],
        input="".join(commit + ":" + p + "\n" for p in paths).encode(),
        capture_output=True,
        check=True,
        timeout=60,
    ).stdout
    offset = 0
    for path in paths:
        end = batch.index(b"\n", offset)
        oid, kind, length = batch[offset:end].split()
        if kind != b"blob":
            raise ValueError("Ordinary reviewed source blob required")
        start = end + 1
        size = int(length)
        expected = batch[start : start + size]
        offset = start + size + 1
        file = root / path
        if file.is_symlink():
            raise ValueError("Ordinary source files required")
        actual = file.read_bytes()
        if actual.replace(b"\r\n", b"\n") != expected.replace(b"\r\n", b"\n"):
            raise ValueError("Reviewed executable bytes differ: " + path)
        manifest[path] = dict(
            git_sha256=digest(expected), executed_sha256=digest(actual)
        )
    return manifest


def guard_identity(connection, approval):
    """Verify the fixed disposable identity, creation timestamp and storage."""
    if identity(connection) != {
        k: approval[k] for k in ("server", "database", "login")
    }:
        raise ValueError("Observed database/login differs; no writes")
    metadata = rows(
        connection,
        "SELECT create_date,collation_name,compatibility_level,state_desc,is_read_only,recovery_model_desc,"
        "CONVERT(nvarchar(128),DATABASEPROPERTYEX('tempdb','Collation')) AS temp_collation "
        "FROM sys.databases WHERE database_id=DB_ID()",
    )[0]
    if (
        metadata["create_date"].isoformat() != approval["create_date"]
        or metadata["collation_name"] != approval["database_collation"]
        or metadata["compatibility_level"] != approval["compatibility_level"]
        or metadata["temp_collation"] != approval["tempdb_collation"]
        or metadata["recovery_model_desc"] != "SIMPLE"
        or metadata["state_desc"] != "ONLINE"
        or metadata["is_read_only"]
    ):
        raise ValueError("Disposable database metadata differs; no writes")
    files = rows(
        connection, "SELECT physical_name FROM sys.database_files ORDER BY file_id"
    )
    if [r["physical_name"] for r in files] != approval["files"]:
        raise ValueError("Approved database files differ; no writes")


def guard_target(connection, approval):
    guard_identity(connection, approval)
    if rows(connection, "SELECT name FROM sys.objects WHERE is_ms_shipped=0"):
        raise ValueError(
            "Fresh empty disposable database required; retain previous runs"
        )
    if rows(connection, "SELECT name FROM sys.triggers WHERE parent_class=0"):
        raise ValueError("No database DDL triggers allowed")
    if rows(connection, "SELECT name FROM sys.server_triggers WHERE is_disabled=0"):
        raise ValueError("No enabled server DDL triggers allowed")
    if (
        rows(
            connection,
            "SELECT HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY DEFINITION') AS visible",
        )[0]["visible"]
        != 1
    ):
        raise ValueError("Metadata visibility required")
    backup = Path(approval["backup_path"])
    if not backup.parent.is_dir():
        raise ValueError("Backup directory must be accessible and approved")
    try:
        backup.stat()
    except FileNotFoundError:
        pass
    else:
        raise ValueError("New approved backup file required; retain existing files")
    connection.rollback()


class NativeRun:
    def __init__(self, approval, bot_root, output):
        self.approval, self.bot_root, self.output = approval, bot_root, output
        self.release = str(uuid.uuid4())
        self.results = {f"N{i:02}": dict(status="NOT_RUN") for i in range(17)}
        self.operations = []
        self.event_ids = []

    def connection(self):
        connection = connect(DATABASE)
        if identity(connection) != {
            k: self.approval[k] for k in ("server", "database", "login")
        }:
            connection.close()
            raise ValueError("Native connection identity changed")
        connection.rollback()
        connection.execute(
            "SET LOCK_TIMEOUT 10000; SET XACT_ABORT ON; SET NOCOUNT OFF;"
        )
        connection.commit()
        return connection

    def execute(self, sql, *args):
        with closing(self.connection()) as connection:
            try:
                cursor = connection.execute(sql, *args)
                result = cursor.fetchall() if cursor.description else []
                while cursor.nextset():
                    pass
                connection.commit()
                return result
            except BaseException:
                connection.rollback()
                raise

    def query(self, sql, *args):
        with closing(self.connection()) as connection:
            return rows(connection, sql, *args)

    def install_fixtures(self):
        for name in FIXTURES:
            source = (ROOT / f"sql_schema/dbo.{name}.Table.sql").read_text(
                encoding="utf-8-sig"
            )
            for batch in re.split(r"(?im)^\s*GO\s*$", source):
                if batch.strip():
                    self.execute(batch)
        # BACKUP needs autocommit and the separately approved exact destination.
        with closing(self.connection()) as connection:
            connection.autocommit = True
            cursor = connection.execute(
                f"BACKUP DATABASE [{DATABASE}] TO DISK=? WITH CHECKSUM;",
                self.approval["backup_path"],
            )
            while cursor.nextset():
                pass
        p = profile(
            self.approval["database_collation"],
            self.approval["tempdb_collation"],
            self.approval["compatibility_level"],
        )
        self.profile_path = self.output / (p["migration_id"] + ".release.json")
        self.profile_path.write_text(json.dumps(p, indent=2) + "\n", encoding="utf-8")
        self.variant = self.execute(
            "INSERT dbo.MGE_Variants(VariantName) OUTPUT INSERTED.VariantId VALUES(N'Qualification');"
        )[0][0]
        self.commander = self.execute(
            "INSERT dbo.MGE_Commanders(CommanderName) OUTPUT INSERTED.CommanderId VALUES(N'Qualification');"
        )[0][0]

    def runner(self, operation, expected=0):
        arguments = [
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
            DATABASE,
            "-MigrationId",
            self.profile_path.stem.removesuffix(".release"),
            "-ProfilePath",
            str(self.profile_path),
            "-ProfileSHA256",
            digest(self.profile_path.read_bytes()),
            "-ExpectedCommit",
            self.approval["sql_commit"],
            "-ReleaseId",
            self.release,
            "-Operation",
            operation,
        ]
        result = subprocess.run(arguments, capture_output=True, timeout=120)
        prefix = str(len(self.operations)) + "-" + operation
        (self.output / (prefix + ".stdout.txt")).write_bytes(result.stdout)
        (self.output / (prefix + ".stderr.txt")).write_bytes(result.stderr)
        self.operations.append(
            dict(operation=operation, exit=result.returncode, expected=expected)
        )
        if result.returncode != expected:
            raise AssertionError(
                f"{operation} returned {result.returncode}; expected {expected}; see {prefix}"
            )

    def load_dal(self):
        """Import actual DAL with explicit test-owned connection adapters, never dotenv."""
        sys.path.insert(0, str(self.bot_root))
        os.environ.update(K98_TEST_MODE="1", PYTEST_RUNNING="1", OUR_KINGDOM="98")
        db = types.ModuleType("stats_alerts.db")

        def write(callback):
            with closing(self.connection()) as connection:
                try:
                    value = callback(connection.cursor())
                    connection.commit()
                    return value
                except BaseException:
                    connection.rollback()
                    raise

        db.exec_with_cursor = write
        db.run_query = lambda sql, params=(): self.query(sql, *params)
        db.run_scalar = lambda sql, params=(): next(
            iter(self.query(sql, *params)[0].values())
        )
        files = types.ModuleType("file_utils")
        files.get_conn_with_retries = self.connection

        def forbidden_file_write(*args, **kwargs):
            raise AssertionError("Unexpected filesystem write from native DAL exercise")

        files.atomic_json_write = forbidden_file_write
        sys.modules["stats_alerts.db"] = db
        sys.modules["file_utils"] = files
        package = types.ModuleType("mge.dal")
        package.__path__ = [str(self.bot_root / "mge/dal")]
        sys.modules["mge.dal"] = package
        return {
            name: importlib.import_module("mge.dal.mge_" + name + "_dal")
            for name in (
                "completion",
                "finalisation",
                "signup",
                "roster",
                "rules",
                "results",
            )
        }

    def event(self, targets=3, status="signup_open"):
        values = [101, 201, 102, 202, 103, 203]
        values[targets * 2 :] = [None] * (6 - targets * 2)
        event = self.execute(
            "INSERT dbo.MGE_Events(VariantId,EventName,StartUtc,EndUtc,SignupCloseUtc,Status,"
            "SignupEmbedChannelId,SignupEmbedMessageId,LeadershipEmbedChannelId,LeadershipEmbedMessageId,"
            "AwardEmbedChannelId,AwardEmbedMessageId) OUTPUT INSERTED.EventId "
            "VALUES(?,N'Qualification',DATEADD(day,-7,SYSUTCDATETIME()),SYSUTCDATETIME(),SYSUTCDATETIME(),?,?,?,?,?,?,?);",
            self.variant,
            status,
            *values,
        )[0][0]
        self.event_ids.append(event)
        return event

    def record(self, case, function):
        start = datetime.now(UTC)
        try:
            details = function() or {}
        except BaseException as exc:
            self.results[case] = dict(
                status="FAIL",
                error=type(exc).__name__ + ": " + str(exc),
                started=start.isoformat(),
                finished=datetime.now(UTC).isoformat(),
            )
            self.save()
            raise
        self.results[case] = dict(
            status="PASS",
            evidence=details,
            started=start.isoformat(),
            finished=datetime.now(UTC).isoformat(),
        )
        self.save()

    def save(self):
        (self.output / "results.json").write_text(
            json.dumps(
                dict(
                    release=self.release,
                    target=DATABASE,
                    event_ids=self.event_ids,
                    cases=self.results,
                    sql_operations=self.operations,
                    updater_native_status="NOT_RUN_SEPARATE_PROTECTED_WINDOWS_APPROVAL",
                ),
                indent=2,
                default=str,
            ),
            encoding="utf-8",
        )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--approval")
    parser.add_argument("--approval-sha256")
    parser.add_argument("--bot-root")
    parser.add_argument(
        "--output", required=True, help="New evidence directory; never overwrite"
    )
    args = parser.parse_args(argv)
    output = Path(args.output).resolve()
    if output.exists():
        raise ValueError("New evidence directory required")
    if not args.run:
        observation = discover()
        output.mkdir(parents=True, exist_ok=False)
        (output / "discovery.json").write_text(
            json.dumps(observation, indent=2, default=str), encoding="utf-8"
        )
        print("SELECT-only discovery retained; no database writes. " + str(output))
        return 0
    if not args.approval or not args.bot_root:
        raise ValueError("Explicit approval and bot root required before connecting")
    raw = Path(args.approval).read_bytes()
    if len(raw) > 65536:
        raise ValueError("Approval exceeds bound")
    approval = json.loads(raw)
    validate_approval(approval, args.approval_sha256, raw)
    bot_root = Path(args.bot_root).resolve()
    sources = dict(
        sql=verify_checkout(ROOT, approval["sql_commit"]),
        bot=verify_checkout(bot_root, approval["bot_commit"]),
    )
    with closing(connect(DATABASE)) as connection:
        guard_target(connection, approval)
    output.mkdir(parents=True, exist_ok=False)
    (output / "sources.json").write_text(
        json.dumps(sources, indent=2), encoding="utf-8"
    )
    (output / "approval.json").write_bytes(raw)
    native = NativeRun(approval, bot_root, output)
    native.save()
    native.install_fixtures()
    from mge_finalisation_cases import run_cases

    run_cases(native)
    native.save()
    return 0 if all(r["status"] == "PASS" for r in native.results.values()) else 2


if __name__ == "__main__":
    raise SystemExit(main())
