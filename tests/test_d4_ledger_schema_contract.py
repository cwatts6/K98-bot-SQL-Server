"""Stable native release images and unchanged ledger semantics in owned local SQL."""

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import subprocess

import pytest
from test_p02_d4_installed_dependencies import dependencies as dependencies

ROOT = Path(__file__).resolve().parents[1]
BASE = "eb82d32a9aa7d262c377f29fcc0b2dea255b408a"
TABLES = (
    "MaintenanceWork",
    "MaintenanceConfigurationWork",
    "MaintenanceBackupWork",
    "MaintenanceKvkWork",
)


def install(con, source):
    for batch in re.split(r"(?im)^GO\s*$", source):
        if batch.strip():
            con.execute(batch)


def image(con, name):
    # Exercise the same image query used by the coordinated release runner.
    source = (ROOT / "deploy/SqlDeploy.RecoveryRelease.ps1").read_text(
        encoding="utf-8-sig"
    )
    function = source.split("function Get-K98RecoveryImage", 1)[1]
    query = re.search(r"@'\n(.*?)\n'@", function, re.S)[1]
    return con.execute("DECLARE @name sysname=?;\n" + query, "dbo." + name).fetchval()


def semantics(raw):
    value = deepcopy(json.loads(raw))
    for column in value["columns_json"]:
        column.pop("default_name", None)
    for index in value["indexes_json"]:
        index.pop("name", None)
    for check in value["checks_json"]:
        check.pop("name", None)
    for key in ("indexes_json", "checks_json"):
        value[key].sort(key=lambda row: json.dumps(row, sort_keys=True))
    return value


@pytest.mark.parametrize("name", TABLES)
def test_named_ledgers_preserve_native_rules_seeds_and_repeatable_images(
    dependencies, name
):
    con, _ = dependencies
    path = f"sql_schema/dbo.{name}.Table.sql"
    before = subprocess.check_output(
        ["git", "show", BASE + ":" + path], cwd=ROOT, timeout=10
    ).decode("utf-8-sig")
    after = (ROOT / path).read_text(encoding="utf-8-sig")
    old_rules = None
    old_rows = None
    stable = []
    for stage, source in enumerate((before, after, after)):
        install(con, source)
        try:
            raw = image(con, name)
            rows = sorted(
                tuple(row) for row in con.execute(f"SELECT * FROM dbo.{name}")
            )
            if stage == 0:
                old_rules, old_rows = semantics(raw), rows
            else:
                assert semantics(raw) == old_rules
                assert rows == old_rows
                assert (
                    con.execute(
                        "SELECT SUM(n) FROM ("
                        "SELECT COUNT(*) n FROM sys.default_constraints WHERE parent_object_id=OBJECT_ID(?) AND is_system_named=1 UNION ALL "
                        "SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(?) AND is_system_named=1 UNION ALL "
                        "SELECT COUNT(*) FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(?) AND is_system_named=1) names",
                        *(["dbo." + name] * 3),
                    ).fetchval()
                    == 0
                )
                stable.append(hashlib.sha256(raw.encode()).hexdigest())
                # Existing committed work is deliberately excluded from schema identity.
                if name == "MaintenanceWork":
                    con.execute(
                        "UPDATE dbo.MaintenanceWork SET DueGeneration=1,ClaimedGeneration=1,ClaimID=NEWID(),State='unknown' WHERE Kind='import'"
                    )
                elif name == "MaintenanceBackupWork":
                    con.execute(
                        "UPDATE dbo.MaintenanceBackupWork SET DueGeneration=1,ClaimedGeneration=1,ClaimID=NEWID(),State='unknown' WHERE ID=1"
                    )
                elif name == "MaintenanceConfigurationWork":
                    con.execute(
                        "UPDATE dbo.MaintenanceConfigurationWork SET DueRows=47,LastBatchRows=47 WHERE ID=1"
                    )
                else:
                    con.execute(
                        "INSERT dbo.MaintenanceKvkWork(KVKNo,DueGeneration,DueObjectID,DueObjectCreateDate,DueHeaderRevision,State) VALUES(99,1,123,'2026-01-01',1,'unknown')"
                    )
                assert image(con, name) == raw
                # A real shape change must still invalidate the image.
                con.execute(f"ALTER TABLE dbo.{name} ADD UnreviewedColumn int NULL")
                assert image(con, name) != raw
        finally:
            con.execute(f"DROP TABLE dbo.{name}")
    assert stable[0] == stable[1]
