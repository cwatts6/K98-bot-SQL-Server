"""Physical owners for the fresh isolated fixture; never retry an unknown stage."""

import hashlib
import json
import os
import subprocess
import time

HELD = []


class SqlOwner:
    def __init__(self, database, record, save):
        from fresh_business_state import FRESH, RETAINED
        import pyodbc

        if database not in ("master", "ROK_TRACKER", FRESH, RETAINED):
            raise ValueError("Exact qualification database required")
        self.record, self.save, self.cursors = record, save, []
        self.connection = None
        self.close_attempted = False
        self.connection = pyodbc.connect(
            "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;DATABASE="
            + database
            + ";Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;"
            "APP=P02FreshBusinessOwner;",
            autocommit=True,
            timeout=3,
        )
        self.connection.timeout = 3
        HELD.append(self)

    def read(self, statement, *parameters):
        if self.close_attempted or self.cursors:
            raise ValueError("Preceding physical SQL ownership is unresolved")
        cursor = self.connection.cursor()
        self.cursors.append(cursor)
        first = None
        self.record["admin_dispatches"] += 1
        started = time.monotonic()
        try:
            cursor.execute(statement, *parameters)
            if cursor.description:
                columns = [r[0] for r in cursor.description]
                rows = cursor.fetchmany(501)
                if len(rows) > 500 or cursor.nextset():
                    raise ValueError("Bounded single administrative result required")
                return [dict(zip(columns, row, strict=True)) for row in rows]
            while cursor.nextset():
                if cursor.description:
                    raise ValueError("Unexpected administrative result")
            return []
        except BaseException as error:
            first = error
            raise
        finally:
            try:
                cursor.close()
                self.cursors.remove(cursor)
            except BaseException as error:
                self.record["cleanup_failures"].append(
                    dict(operation="cursor close", error_type=type(error).__name__)
                )
                if first is None:
                    raise
            self.record["admin_seconds"] += time.monotonic() - started

    def mutate(self, label, statement, *parameters):
        item = dict(
            stage=label,
            sql_sha256=hashlib.sha256(statement.encode()).hexdigest(),
            acknowledged=False,
        )
        self.record["stage"] = label
        self.record["actions"].append(item)
        self.save()
        self.read(statement, *parameters)
        item["acknowledged"] = True
        self.save()

    def close(self):
        if self.connection is None:
            return
        if self.close_attempted or self.cursors:
            raise ValueError("Retain original SQL handles; do not retry cleanup")
        self.close_attempted = True
        self.connection.close()
        self.connection = None
        HELD.remove(self)
        self.record["admin_connections_closed"] += 1


def coordinator(packet, manifest, operation, record, save, *, database_id=18):
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
        or database_id not in (18, 26)
        or (database_id == 26 and manifest.get("purpose") != "p02-balanced-cost-workload")
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
            handles.append((packet / (operation + "." + stream + ".txt")).open("xb"))
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
        value = json.loads((packet / (operation + ".stdout.txt")).read_text(encoding="utf-8-sig"))
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
