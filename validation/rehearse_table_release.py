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
        # Decode as a real profile would be read: no shared in-memory column objects.
        p = json.loads(json.dumps(profile(*env)))
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

    hypothetical = fixture("hypothetical")
    schema = hypothetical["tables"][0]["schema"]
    key_name = c.execute(
        "SELECT name FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(?) AND type='UQ'",
        schema + ".SourceExportIntent",
    ).fetchval()
    assert key_name and "]" not in key_name
    execute(f"ALTER TABLE [{schema}].[SourceExportIntent] DROP CONSTRAINT [{key_name}]")
    execute(
        f"CREATE UNIQUE INDEX [HypotheticalTarget] ON [{schema}].[SourceExportIntent]"
        "(SourceKey,KVK_NO,IntentID) WITH (STATISTICS_ONLY = -1)"
    )
    assert tuple(
        c.execute(
            "SELECT is_unique,is_hypothetical FROM sys.indexes WHERE object_id=OBJECT_ID(?) "
            "AND name='HypotheticalTarget'",
            schema + ".SourceExportIntent",
        ).fetchone()
    ) == (True, True)
    hypothetical_path = save(hypothetical)
    outer(hypothetical_path, "Preflight", 20)
    outer(hypothetical_path, "Apply", 20)
    assert attempts(hypothetical) == 0
    assert c.execute("SELECT OBJECT_ID(?,N'U')", schema + ".SourceExportHistory").fetchval() is None

    legacy_hypothetical = (ROOT / "migrations/20261013_001_kvk_export_history.sql").read_text(
        encoding="utf-8-sig"
    )
    legacy_hypothetical = legacy_hypothetical.replace("KVK.", schema + ".").replace(
        "SCHEMA_ID(N'KVK')", "SCHEMA_ID(N'" + schema + "')"
    )
    try:
        execute(legacy_hypothetical)
    except pyodbc.Error as exc:
        assert "SourceExportIntent scoped key missing" in str(exc)
    else:
        raise AssertionError("Legacy migration accepted a hypothetical prerequisite index")
    assert c.execute("SELECT @@TRANCOUNT").fetchval() == 0
    assert c.execute("SELECT OBJECT_ID(?,N'U')", schema + ".SourceExportHistory").fetchval() is None
    assert (
        c.execute("SELECT OBJECT_ID(?,N'U')", schema + ".SourceExportHistoryRow").fetchval() is None
    )
    (output / "legacy-hypothetical-key.json").write_text(
        json.dumps({"result": "REFUSED_BEFORE_DDL", "transaction_count": 0, "new_tables": 0}),
        encoding="utf-8",
    )

    # Internal FK targets must be rejected before any Started attempt is written.
    invalid_key = fixture("invalid_key")
    invalid_key["tables"][0]["primary_key"]["columns"] = ["IntentID"]
    invalid_path = save(invalid_key)
    outer(invalid_path, "Preflight", 20)
    outer(invalid_path, "Apply", 20)
    assert attempts(invalid_key) == 0
    assert (
        c.execute(
            "SELECT OBJECT_ID(?,N'U')",
            invalid_key["tables"][0]["schema"] + ".SourceExportHistory",
        ).fetchval()
        is None
    )

    for field, table_index in (
        ("schema", 1),
        ("table", 1),
        ("schema", 0),
        ("table", 0),
        ("columns", 1),
        ("columns", 0),
        ("target_columns", 0),
        ("own_schema", 0),
    ):
        mismatched = fixture("case_" + str(table_index) + "_" + field)
        target = mismatched["tables"][table_index]["foreign_keys"][0]
        if field == "own_schema":
            for table in mismatched["tables"]:
                table["schema"] = table["schema"].swapcase()
                for fk in table["foreign_keys"]:
                    fk["schema"] = fk["schema"].swapcase()
        elif field in ("columns", "target_columns"):
            target[field][0] = target[field][0].swapcase()
        else:
            target[field] = target[field].swapcase()
        mismatch_path = save(mismatched)
        outer(mismatch_path, "Preflight", 20)
        outer(mismatch_path, "Apply", 20)
        assert attempts(mismatched) == 0
        assert (
            c.execute(
                "SELECT OBJECT_ID(?,N'U')",
                mismatched["tables"][0]["schema"] + ".SourceExportHistory",
            ).fetchval()
            is None
        )

    for label, table_index, column_index, field, value in (
        ("internal_type", 1, 0, "type", "int"),
        ("internal_collation", 1, 1, "collation", "Latin1_General_CI_AS"),
        ("internal_length", 1, 1, "type", "varchar(31)"),
        ("external_type", 0, 4, "type", "bigint"),
        ("external_collation", 0, 3, "collation", "Latin1_General_CI_AS"),
        ("external_length", 0, 3, "type", "varchar(31)"),
    ):
        incompatible = fixture(label)
        incompatible["tables"][table_index]["columns"][column_index][field] = value
        incompatible_path = save(incompatible)
        outer(incompatible_path, "Preflight", 20)
        outer(incompatible_path, "Apply", 20)
        assert attempts(incompatible) == 0
        assert (
            c.execute(
                "SELECT OBJECT_ID(?,N'U')",
                incompatible["tables"][0]["schema"] + ".SourceExportHistory",
            ).fetchval()
            is None
        )

    prerequisite_results = {}
    original_migration = (ROOT / "migrations/20261013_001_kvk_export_history.sql").read_text(
        encoding="utf-8-sig"
    )

    def refuse_before_installation(candidate, schema, diagnostic):
        try:
            execute(candidate)
        except pyodbc.Error as exc:
            assert diagnostic in str(exc)
        else:
            raise AssertionError("Legacy migration accepted: " + diagnostic)
        assert c.execute("SELECT @@TRANCOUNT").fetchval() == 0
        for table in ("SourceExportHistory", "SourceExportHistoryRow"):
            assert c.execute("SELECT OBJECT_ID(?,N'U')", schema + "." + table).fetchval() is None

    for label in ("parent_case", "schema_case"):
        identity = fixture("legacy_" + label)
        schema = identity["tables"][0]["schema"]
        expected_schema = schema.lower() if label == "schema_case" else schema
        candidate = original_migration.replace("KVK.", expected_schema + ".").replace(
            "SCHEMA_ID(N'KVK')", "SCHEMA_ID(N'" + expected_schema + "')"
        )
        if label == "parent_case":
            execute(
                "EXEC sys.sp_rename ?, ?, 'OBJECT';",
                schema + ".SourceExportIntent",
                "sourceexportintent",
            )
        refuse_before_installation(
            candidate, schema, "SourceExportIntent prerequisite catalog identity differs"
        )
        prerequisite_results[label] = "REFUSED_BEFORE_INSTALLATION_DDL"

    collision = fixture("legacy_constraint_collision")
    schema = collision["tables"][0]["schema"]
    candidate = original_migration.replace("KVK.", schema + ".").replace(
        "SCHEMA_ID(N'KVK')", "SCHEMA_ID(N'" + schema + "')"
    )
    execute(f"CREATE TABLE [{schema}].UnrelatedConstraintOwner(Value int NOT NULL);")
    collision_names = []
    for table in collision["tables"]:
        for constraint in (
            [table["primary_key"]] + table["unique_keys"] + table["checks"] + table["foreign_keys"]
        ):
            name = constraint["name"]
            # Constraint types share the schema object namespace. Lowercase one
            # name also exercises collisions under the database CI collation.
            actual_name = name.lower() if not collision_names else name
            execute(
                f"ALTER TABLE [{schema}].UnrelatedConstraintOwner ADD CONSTRAINT [{actual_name}] CHECK (Value>0);"
            )
            refuse_before_installation(
                candidate, schema, "Export history constraint name already exists"
            )
            execute(
                f"ALTER TABLE [{schema}].UnrelatedConstraintOwner DROP CONSTRAINT [{actual_name}];"
            )
            collision_names.append(name)
    assert len(collision_names) == 11
    (output / "legacy-constraint-collisions.json").write_text(
        json.dumps(collision_names), encoding="utf-8"
    )

    for label, source_type, source_collation, season_type, intent_type in (
        (
            "unicode",
            "nvarchar(32)",
            "Latin1_General_100_BIN2",
            "int",
            "uniqueidentifier",
        ),
        ("length", "varchar(31)", "Latin1_General_100_BIN2", "int", "uniqueidentifier"),
        ("collation", "varchar(32)", "Latin1_General_CI_AS", "int", "uniqueidentifier"),
        (
            "season",
            "varchar(32)",
            "Latin1_General_100_BIN2",
            "bigint",
            "uniqueidentifier",
        ),
        ("intent", "varchar(32)", "Latin1_General_100_BIN2", "int", "varchar(36)"),
    ):
        prerequisite = fixture("legacy_prerequisite_" + label)
        schema = prerequisite["tables"][0]["schema"]
        # This isolated fixture has no children or application data.
        execute(f"DROP TABLE [{schema}].SourceExportIntent;")
        execute(
            f"CREATE TABLE [{schema}].SourceExportIntent("
            f"SourceKey {source_type} COLLATE {source_collation} NOT NULL,"
            f"KVK_NO {season_type} NOT NULL,IntentID {intent_type} NOT NULL,"
            "UNIQUE(SourceKey,KVK_NO,IntentID));"
        )
        candidate = (ROOT / "migrations/20261013_001_kvk_export_history.sql").read_text(
            encoding="utf-8-sig"
        )
        candidate = candidate.replace("KVK.", schema + ".").replace(
            "SCHEMA_ID(N'KVK')", "SCHEMA_ID(N'" + schema + "')"
        )
        try:
            execute(candidate)
        except pyodbc.Error as exc:
            assert "SourceExportIntent prerequisite column shape differs" in str(exc)
        else:
            raise AssertionError("Legacy migration accepted prerequisite drift: " + label)
        assert c.execute("SELECT @@TRANCOUNT").fetchval() == 0
        for table in ("SourceExportHistory", "SourceExportHistoryRow"):
            assert c.execute("SELECT OBJECT_ID(?,N'U')", schema + "." + table).fetchval() is None
        prerequisite_results[label] = "REFUSED_BEFORE_INSTALLATION_DDL"
    (output / "legacy-prerequisite-shapes.json").write_text(
        json.dumps(prerequisite_results), encoding="utf-8"
    )

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

    masked = {}
    for table, column in (
        ("SourceExportHistory", "CapturedUTC"),
        ("SourceExportHistoryRow", "PayloadJson"),
    ):
        execute(
            f"ALTER TABLE [{legacy_schema}].[{table}] ALTER COLUMN [{column}] "
            "ADD MASKED WITH (FUNCTION='default()');"
        )
        try:
            execute(migration)
        except pyodbc.Error as exc:
            assert "History masked column conflict" in str(exc)
        else:
            raise AssertionError("Legacy rerun accepted masked column: " + column)
        assert c.execute("SELECT @@TRANCOUNT").fetchval() == 0
        execute(f"ALTER TABLE [{legacy_schema}].[{table}] ALTER COLUMN [{column}] DROP MASKED;")
        execute(migration)
        masked[table + "." + column] = "REFUSED_AND_RECOVERED"
    (output / "legacy-masked-columns.json").write_text(json.dumps(masked), encoding="utf-8")

    # Renames must not silently pass the alternative legacy exact-postimage path.
    renamed = {}
    for name, expected_error in (
        ("CK_SourceExportHistory_Count", "History named check shape conflict"),
        ("PK_SourceExportHistoryRow", "History named index shape conflict"),
        ("UQ_SourceExportHistoryRow_Attempt", "History named index shape conflict"),
    ):
        execute(
            "EXEC sys.sp_rename ?, ?, 'OBJECT';",
            legacy_schema + "." + name,
            name + "_Changed",
        )
        try:
            execute(migration)
        except pyodbc.Error as exc:
            assert expected_error in str(exc)
        else:
            raise AssertionError("Legacy rerun accepted renamed constraint: " + name)
        assert c.execute("SELECT @@TRANCOUNT").fetchval() == 0
        execute(
            "EXEC sys.sp_rename ?, ?, 'OBJECT';",
            legacy_schema + "." + name + "_Changed",
            name,
        )
        execute(migration)
        renamed[name] = "REFUSED"
    (output / "legacy-named-drift.json").write_text(json.dumps(renamed), encoding="utf-8")

    # The alternative legacy installation path must also reject physical drift.
    # Exercise each catalog predicate with a fixed fault injection. Do not enable
    # database-wide CDC/replication or create server Agent jobs for a guard test.
    modes = {}
    for flag in (
        "is_filetable",
        "is_replicated",
        "is_merge_published",
        "is_sync_tran_subscribed",
        "is_tracked_by_cdc",
        "filestream_data_space_id",
    ):
        needle = "t." + flag + "<>0"
        assert migration.count(needle) == 1
        try:
            execute(migration.replace(needle, "1<>0"))
        except pyodbc.Error as exc:
            assert "History unexpected trigger, partition, compression or table mode" in str(exc)
        else:
            raise AssertionError("Legacy mode guard accepted injected " + flag)
        assert c.execute("SELECT @@TRANCOUNT").fetchval() == 0
        execute(migration)
        modes[flag] = "INJECTED_CATALOG_FLAG_REFUSED"
    (output / "legacy-mode-guards.json").write_text(json.dumps(modes), encoding="utf-8")

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
    for table, column in (
        ("SourceExportHistory", "CapturedUTC"),
        ("SourceExportHistoryRow", "PayloadJson"),
    ):
        execute(
            f"ALTER TABLE [{schema}].[{table}] ALTER COLUMN [{column}] "
            "ADD MASKED WITH (FUNCTION='default()');"
        )
        for operation in ("Verify", "Apply"):
            outer(path, operation, 20)
            error = (output / f"{counter:02d}-{operation}.stderr.txt").read_text()
            assert "Unsupported additive table metadata" in " ".join(error.split())
        assert attempts(p) == 1
        execute(f"ALTER TABLE [{schema}].[{table}] ALTER COLUMN [{column}] DROP MASKED;")
        outer(path, "Verify", 0)
    # Exercise both verifiers against the same real catalog mutations. These
    # fixtures are empty, isolated, and have exactly one successful receipt.
    success_migration = migration.replace(legacy_schema + ".", schema + ".").replace(
        "SCHEMA_ID(N'" + legacy_schema + "')", "SCHEMA_ID(N'" + schema + "')"
    )

    def refuse_postimage(expected_legacy_error, expected_additive_error):
        try:
            execute(success_migration)
        except pyodbc.Error as exc:
            assert expected_legacy_error in str(exc)
        else:
            raise AssertionError("Legacy migration accepted: " + expected_legacy_error)
        assert c.execute("SELECT @@TRANCOUNT").fetchval() == 0
        for operation in ("Verify", "Apply"):
            outer(path, operation, 20)
            error = (output / f"{counter:02d}-{operation}.stderr.txt").read_text()
            assert expected_additive_error in " ".join(error.split())
        assert attempts(p) == 1

    def recovered_postimage():
        execute(success_migration)
        outer(path, "Verify", 0)

    payload = (
        success_migration.split("-- HISTORY_INSTALL_PAYLOAD_BEGIN\n", 1)[1]
        .split("-- HISTORY_INSTALL_PAYLOAD_END", 1)[0]
        .strip()
    )
    prefix = "EXEC sys.sp_executesql N'"
    assert payload.startswith(prefix) and payload.endswith("';")
    plaintext_ddl = payload[len(prefix) : -2].replace("''", "'")

    def rebuild_empty_history(ddl):
        for table in ("SourceExportHistoryRow", "SourceExportHistory"):
            assert c.execute(f"SELECT COUNT(*) FROM [{schema}].[{table}]").fetchval() == 0
        execute(f"DROP TABLE [{schema}].SourceExportHistoryRow, [{schema}].SourceExportHistory;")
        execute(ddl)

    index_option_results = []
    for table in ("SourceExportHistory", "SourceExportHistoryRow"):
        for option, mutation, recovery in (
            ("fill_factor", "REBUILD WITH (FILLFACTOR=80)", None),
            ("is_padded", "REBUILD WITH (PAD_INDEX=ON)", "REBUILD WITH (PAD_INDEX=OFF)"),
            ("allow_row_locks", "SET (ALLOW_ROW_LOCKS=OFF)", "SET (ALLOW_ROW_LOCKS=ON)"),
            ("allow_page_locks", "SET (ALLOW_PAGE_LOCKS=OFF)", "SET (ALLOW_PAGE_LOCKS=ON)"),
            (
                "optimize_for_sequential_key",
                "SET (OPTIMIZE_FOR_SEQUENTIAL_KEY=ON)",
                "SET (OPTIMIZE_FOR_SEQUENTIAL_KEY=OFF)",
            ),
        ):
            prefix = f"ALTER INDEX [PK_{table}] ON [{schema}].[{table}] "
            execute(prefix + mutation)
            refuse_postimage("History index shape conflict", "Additive table shape differs")
            if recovery is None:
                rebuild_empty_history(plaintext_ddl)
            else:
                execute(prefix + recovery)
            recovered_postimage()
            index_option_results.append(table + "." + option)
    (output / "mutable-index-options.json").write_text(
        json.dumps(index_option_results), encoding="utf-8"
    )

    statistics_results = []
    for table, index in (
        ("SourceExportHistory", "PK_SourceExportHistory"),
        ("SourceExportHistoryRow", "PK_SourceExportHistoryRow"),
        ("SourceExportHistoryRow", "UQ_SourceExportHistoryRow_Attempt"),
    ):
        prefix = f"ALTER INDEX [{index}] ON [{schema}].[{table}] REBUILD WITH "
        execute(prefix + "(STATISTICS_NORECOMPUTE=ON)")
        assert (
            c.execute(
                "SELECT no_recompute FROM sys.stats WHERE object_id=OBJECT_ID(?) AND name=?",
                schema + "." + table,
                index,
            ).fetchval()
            == 1
        )
        refuse_postimage("History index shape conflict", "Additive table shape differs")
        execute(prefix + "(STATISTICS_NORECOMPUTE=OFF)")
        recovered_postimage()
        statistics_results.append(table + "." + index)
    (output / "index-statistics-options.json").write_text(
        json.dumps(statistics_results), encoding="utf-8"
    )

    for table in ("SourceExportHistory", "SourceExportHistoryRow"):
        execute("EXEC sys.sp_rename ?, ?, 'OBJECT';", schema + "." + table, table.lower())
        refuse_postimage("History catalog identity conflict", "Additive object identity differs")
        execute("EXEC sys.sp_rename ?, ?, 'OBJECT';", schema + "." + table.lower(), table)
        recovered_postimage()

    execute(
        f"CREATE FUNCTION [{schema}].HistoryGate(@guild varchar(32)) RETURNS TABLE "
        "WITH SCHEMABINDING AS RETURN SELECT 1 AS Allowed WHERE @guild='allowed';"
    )
    for table in ("SourceExportHistory", "SourceExportHistoryRow"):
        for kind in ("FILTER", "BLOCK"):
            for state in ("ON", "OFF"):
                suffix = " AFTER INSERT" if kind == "BLOCK" else ""
                execute(
                    f"CREATE SECURITY POLICY [{schema}].HistoryPolicy ADD {kind} PREDICATE "
                    f"[{schema}].HistoryGate(GuildID) ON [{schema}].[{table}]{suffix} "
                    f"WITH (STATE={state});"
                )
                refuse_postimage(
                    "History security predicate conflict", "Unsupported additive table metadata"
                )
                execute(f"DROP SECURITY POLICY [{schema}].HistoryPolicy;")
                recovered_postimage()

    # Always Encrypted metadata can be created without a real certificate or
    # private key. The dummy CEK bytes are never used for encryption/decryption.
    # No certificate store, external key service, or application rows are used.
    key = "Updater_" + run_id + "_metadata"
    execute(
        f"CREATE COLUMN MASTER KEY [{key}] WITH (KEY_STORE_PROVIDER_NAME=N'MSSQL_CERTIFICATE_STORE',"
        "KEY_PATH=N'CurrentUser/My/0000000000000000000000000000000000000000');"
    )
    execute(
        f"CREATE COLUMN ENCRYPTION KEY [{key}] WITH VALUES (COLUMN_MASTER_KEY=[{key}],"
        "ALGORITHM='RSA_OAEP',ENCRYPTED_VALUE=0x01);"
    )
    for column, encryption in (
        ("VectorHash", "DETERMINISTIC"),
        ("ContentHash", "RANDOMIZED"),
        ("RowHash", "DETERMINISTIC"),
    ):
        needle = column + " binary(32) NOT NULL"
        assert plaintext_ddl.count(needle) == 1
        encrypted_ddl = plaintext_ddl.replace(
            needle,
            column
            + " binary(32) ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY=["
            + key
            + "]"
            + ",ENCRYPTION_TYPE="
            + encryption
            + ",ALGORITHM='AEAD_AES_256_CBC_HMAC_SHA_256') NOT NULL",
        )
        rebuild_empty_history(encrypted_ddl)
        observed = c.execute(
            "SELECT encryption_type FROM sys.columns WHERE object_id=OBJECT_ID(?) AND name=?",
            schema
            + "."
            + ("SourceExportHistoryRow" if column == "RowHash" else "SourceExportHistory"),
            column,
        ).fetchval()
        assert observed == (1 if encryption == "DETERMINISTIC" else 2)
        refuse_postimage("History encrypted column conflict", "Unsupported additive table metadata")
        rebuild_empty_history(plaintext_ddl)
        recovered_postimage()
    (output / "security-catalog-drift.json").write_text(
        json.dumps(
            {
                "table_case": 2,
                "filter_block_enabled_disabled": 8,
                "encrypted_columns": 3,
                "result": "BOTH_VERIFIERS_REFUSED_AND_RECOVERED",
                "extra_attempts": 0,
            }
        ),
        encoding="utf-8",
    )

    # Persisted sampling needs populated statistics; normal row/sample counts
    # remain outside the schema contract and must not cause false drift.
    sampling_intent = str(uuid.uuid4())
    execute(
        f"INSERT [{schema}].SourceExportIntent VALUES('snapshot_report_v1',16,?);", sampling_intent
    )
    execute(
        f"WITH numbers AS (SELECT TOP (100) ROW_NUMBER() OVER(ORDER BY object_id) n FROM sys.all_objects) "
        f"INSERT [{schema}].SourceExportHistory "
        "SELECT ?,CONVERT(varchar(32),n),'source_export_history_v1','snapshot_report_v1',16,"
        "0x00,SYSUTCDATETIME(),1,0x00 FROM numbers;",
        sampling_intent,
    )
    execute(
        f"INSERT [{schema}].SourceExportHistoryRow "
        f"SELECT IntentID,GuildID,HistoryVersion,1,NEWID(),N'{{}}',0x00 FROM [{schema}].SourceExportHistory;"
    )
    sampling_results = []
    for table, index in (
        ("SourceExportHistory", "PK_SourceExportHistory"),
        ("SourceExportHistoryRow", "PK_SourceExportHistoryRow"),
        ("SourceExportHistoryRow", "UQ_SourceExportHistoryRow_Attempt"),
    ):
        prefix = f"UPDATE STATISTICS [{schema}].[{table}] [{index}] WITH "
        execute(prefix + "SAMPLE 10 PERCENT, PERSIST_SAMPLE_PERCENT=ON;")
        observed = c.execute(
            "SELECT s.no_recompute,s.has_persisted_sample,p.persisted_sample_percent "
            "FROM sys.stats s OUTER APPLY sys.dm_db_stats_properties(s.object_id,s.stats_id) p "
            "WHERE s.object_id=OBJECT_ID(?) AND s.name=?",
            schema + "." + table,
            index,
        ).fetchone()
        assert tuple(observed) == (False, True, 10.0), observed
        refuse_postimage("History index shape conflict", "Additive table shape differs")
        execute(prefix + "FULLSCAN, PERSIST_SAMPLE_PERCENT=OFF;")
        recovered_postimage()
        sampling_results.append(table + "." + index)
    (output / "persisted-sampling-options.json").write_text(
        json.dumps(sampling_results), encoding="utf-8"
    )
    execute(f"DELETE FROM [{schema}].SourceExportHistoryRow;")
    execute(f"DELETE FROM [{schema}].SourceExportHistory;")
    execute(f"DELETE FROM [{schema}].SourceExportIntent WHERE IntentID=?;", sampling_intent)

    intent = str(uuid.uuid4())
    execute(
        f"INSERT [{schema}].SourceExportIntent VALUES('snapshot_report_v1',16,?);",
        intent,
    )
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
    bad_path = save(invalid)
    # An intentional mid-transaction fault keeps rollback coverage independent
    # of malformed profiles, which now fail before any attempt is written.
    fault = output / "rollback-fault"
    fault.mkdir()
    for name in ("Deploy-SqlMigration.ps1", "SqlDeploy.TableRelease.ps1"):
        (fault / name).write_bytes((ROOT / "deploy" / name).read_bytes())
    hook = "\n$script:queryOriginal=${function:Invoke-K98ModuleQuery}\n"
    hook += "function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {\n"
    hook += (
        "if($null -ne $Transaction -and $Sql.StartsWith('CREATE TABLE ["
        + invalid["tables"][0]["schema"]
        + "].[SourceExportHistoryRow]')){throw 'Intentional fixture rollback fault'}\n"
    )
    hook += "$result=& $script:queryOriginal $Connection $Transaction $Sql $Values; return ,$result\n}\n"
    (fault / "SqlDeploy.ModuleRelease.ps1").write_bytes(
        (ROOT / "deploy/SqlDeploy.ModuleRelease.ps1").read_bytes() + hook.encode()
    )
    outer(bad_path, "Apply", 20, runner=fault / "Deploy-SqlMigration.ps1")
    assert '"state":"rolled_back"' in outer(bad_path, "Status", 11)
    assert (
        c.execute(
            "SELECT OBJECT_ID(?)",
            invalid["tables"][0]["schema"] + ".SourceExportHistory",
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
