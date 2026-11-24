"""Genuine observer installation and fresh backup on the acknowledged new DB27 only."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from fresh_business_owner import HELD
from poststate_owner import owned


def backups(packet, manifest, record, save, names):
    import fresh_business_backup as backup
    from fresh_business_state import CLOCK, IDENTITY, require_identity

    root = Path(manifest["backup_directory"])
    if root != Path(manifest["data_directory"]) / "before-observer":
        raise ValueError("Only the fresh fixture backup directory is supported")
    root.mkdir(exist_ok=False)
    record["new_fixture_backups"] = []
    with owned("ROK_TRACKER", record, save, timeout=240) as owner:
        require_identity(owner.read(IDENTITY), "ROK_TRACKER", 27)
        source = next(r for r in names.current if r["database_id"] == 27)
        backup.require_space(owner.read(backup.SPACE_SQL), shutil.disk_usage(root).free)
        for kind, suffix in (("full", "bak"), ("log", "trn")):
            path = root / ("db27-before-observer." + suffix)
            if path.exists() or owner.read(backup.HISTORY_SQL, str(path)):
                raise ValueError("Fresh backup path is occupied; do not replay")
            row = dict(kind=kind, path=str(path), acknowledged=False, verified=False)
            record["new_fixture_backups"].append(row)
            start = owner.read(CLOCK)[0]["local_time"]
            save()
            statement = (
                backup.STATEMENTS[kind]
                .replace("DB_ID()<>18", "DB_ID()<>27")
                .replace("DB18", "DB27")
            )
            owner.mutate("new fixture backup " + kind, statement, str(path))
            row["acknowledged"] = True
            finish = owner.read(CLOCK)[0]["local_time"]
            row["history"] = owner.read(backup.HISTORY_SQL, str(path))
            row["header"] = owner.read(backup.HEADER_SQL, str(path))
            backup.require_backup(row["history"], row["header"], source, kind, path, start, finish)
            row["file"] = backup.file_facts(path)
            save()
            owner.mutate(
                "verify new fixture backup " + kind, backup.STATEMENTS["verify"], str(path)
            )
            if backup.file_facts(path) != row["file"]:
                raise ValueError("Fresh backup changed during verification")
            row["verified"] = True
            save()
        if shutil.disk_usage(root).free < 20 * 1024**3:
            raise ValueError("Fresh fixture reserve exhausted")


def coordinator(packet, manifest, operation, record, save, *, database_id=27):
    from services.export_observer_contract import MIGRATION_ID, PROFILE_SHA256

    expected = {
        "Status": (10, "unstarted"),
        "Preflight": (0, "unstarted"),
        "Apply": (0, "committed"),
        "Verify": (0, "committed"),
    }
    if (
        operation not in expected
        or HELD
        or database_id != 27
        or manifest.get("purpose") != "p02-poststate-capture-chain"
    ):
        raise ValueError("Settled coordinator operation required")
    repo = packet / "sql-package"
    args = [
        r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(repo / "Deploy-SqlMigration.ps1"),
        "-ServerName",
        "MINI_AMD",
        "-DatabaseName",
        "ROK_TRACKER",
        "-MigrationId",
        MIGRATION_ID,
        "-ProfilePath",
        str(repo / (MIGRATION_ID + ".release.json")),
        "-ProfileSHA256",
        PROFILE_SHA256,
        "-ExpectedCommit",
        manifest["release"]["sql"]["commit"],
        "-ReleaseId",
        manifest["release"]["release_id"],
        "-Operation",
        operation,
    ]
    item = dict(operation=operation, acknowledged=False)
    record["coordinator"].append(item)
    record["stage"] = "fresh canonical observer " + operation
    save()
    handles = []
    child = None
    try:
        for stream in ("stdout", "stderr"):
            handles.append(
                (packet / ("coordinator-" + operation + "." + stream + ".txt")).open("xb")
            )
        env = {k: v for k, v in os.environ.items() if k not in ("S11_SQL_PASSWORD", "SQL_PASSWORD")}
        child = subprocess.Popen(
            args,
            cwd=repo,
            env=env,
            stdout=handles[0],
            stderr=handles[1],
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        HELD.append(child)
        child._p02_output_handles = handles
        item["pid"] = child.pid
        save()
        started = time.monotonic()
        while child.poll() is None and time.monotonic() - started < 240:
            time.sleep(1)
        if child.poll() is None:
            raise TimeoutError("Retain original coordinator process; no successor or replay")
        child.wait()
        item.update(exit_code=child.returncode, seconds=time.monotonic() - started, settled=True)
        HELD.remove(child)
        for handle in handles:
            handle.close()
        handles.clear()
        if child.returncode != expected[operation][0]:
            raise ValueError("Canonical coordinator refused; inspect original logs")
        value = json.loads(
            (packet / ("coordinator-" + operation + ".stdout.txt")).read_text(encoding="utf-8-sig")
        )
        if (
            value["state"] != expected[operation][1]
            or value["migration_id"] != MIGRATION_ID
            or value["profile_sha256"] != PROFILE_SHA256
            or value["sql_commit"] != manifest["release"]["sql"]["commit"]
        ):
            raise ValueError("Canonical coordinator result differs")
        if operation in ("Apply", "Verify") and (
            value["release_id"] != manifest["release"]["release_id"]
            or value["observation_installation"]["database_id"] != database_id
        ):
            raise ValueError("Fresh committed incarnation differs")
        item.update(acknowledged=True, result=value)
        save()
        return value
    finally:
        if child is None or child.poll() is not None:
            for handle in handles:
                handle.close()
        # A live child and its redirected handles remain owned by this process.
        # The caller retains this Python process if HELD is nonempty.
