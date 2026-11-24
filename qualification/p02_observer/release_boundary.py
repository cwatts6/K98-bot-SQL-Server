"""Grouped native release-boundary qualification without runtime publication."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys

PRIOR_PATH = r"Q:\P02Observer\20261120222218753\receipt.json"
PRIOR_SHA = "9cf4e784ae42a0c11fb138d725533521a54ffd67990b834e7b97666ea9da8a4c"
_DLL_HANDLES = []
RESOURCE_SQL = """SELECT ResourceKey,ActiveJobID,ActivePreparationID,ActiveOutputOperationID,
OwnerID,Fence,Version,CASE WHEN BlockedReason IS NULL THEN 0 ELSE 1 END AS blocked
FROM dbo.ExportResource WHERE ResourceKey=N'sql_snapshot:legacy_outputs'"""
PREPARATION_SQL = """SELECT p.PreparationID,p.ConsumerKind,p.State,p.OwnerID,p.Fence,p.Version,p.JobID
FROM dbo.ExportPreparation p JOIN dbo.ExportResource r ON r.ActivePreparationID=p.PreparationID
WHERE r.ResourceKey=N'sql_snapshot:legacy_outputs'"""
COUNTS_SQL = "SELECT State,COUNT_BIG(*) AS preparation_count FROM dbo.ExportPreparation GROUP BY State ORDER BY State"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_prior(value):
    if (
        value.get("outcome") != "completed_with_cost_miss"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures")
        or value.get("functional_overlap_passed") is not True
        or value.get("application_batch_cost_passed") is not True
        or value.get("all_batch_cost_passed") is not False
        or value.get("login_disabled") is not True
        or value.get("admin_connections_closed") != 1
        or value.get("before") != value.get("after")
        or value.get("master_before") != value.get("master_after")
        or len(value.get("cases", [])) != 2
        or any(
            c.get("settled") is not True
            or any(
                child.get("outcome") != "passed" or child.get("exit_code") != 0
                for child in c.get("children", [])
            )
            for c in value["cases"]
        )
    ):
        raise ValueError("Exact settled successful readers with retained cost miss required")


def native_paths(packet):
    site = Path(r"C:\discord_file_downloader\venv\Lib\site-packages")
    paths = [site, site / "win32", site / "win32/lib", site / "pywin32_system32"]
    if not all(p.is_dir() for p in paths):
        raise ValueError("Existing isolated guest Python dependencies differ")
    sys.path[:0] = [
        str(packet / "bot"),
        str(packet / "qualification/p02_observer"),
        *(str(p) for p in paths),
    ]
    _DLL_HANDLES.append(os.add_dll_directory(str(site / "pywin32_system32")))
    os.environ.update(
        PYTHON_DOTENV_DISABLED="1",
        OUR_KINGDOM="98",
        SQL_SERVER="MINI_AMD",
        SQL_DATABASE="ROK_TRACKER",
        DISABLE_FILE_LOGGING="1",
        SMOKE_IMPORTS="1",
        NO_DISCORD_LOGIN="1",
        DISABLE_STARTUP_TASKS="1",
    )


def owner_inventory(connection):
    from independent_readers import query

    return {
        name: query(connection, sql)
        for name, sql in (
            ("resource", RESOURCE_SQL),
            ("active_preparation", PREPARATION_SQL),
            ("preparation_counts", COUNTS_SQL),
        )
    }


def run(packet, manifest, prior):
    import configured_reader
    import fixed_contract_cost as cost
    from independent_readers import query, state, write_new
    import pyodbc
    import release_windows_boundary as windows
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts

    receipt = dict(
        schema="p02-native-release-boundary/1",
        outcome="running",
        stage="preflight",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        admin_connections_closed=0,
        login_disabled=None,
        enable_attempted=False,
        setup_replayed=False,
        migration_replayed=False,
        restore_replayed=False,
        business_operations=0,
        provider_operations=0,
        production_operations=0,
        runtime_published=False,
        protected_seed_issued=False,
        protected_fixture_state="not_attempted",
        check_failures=[],
    )
    connection = None
    before_owners = None

    def save():
        tmp = packet / "progress.pending"
        tmp.write_text(json.dumps(receipt, indent=2, default=str), encoding="utf-8")
        tmp.replace(packet / "progress.json")

    def failed(error):
        fact = dict(stage=receipt["stage"], **sql_error_facts(error))
        fact["chain"] = configured_reader.refusal_facts(error)
        receipt["check_failures"].append(fact)
        if receipt["first_failure"] is None:
            receipt["first_failure"] = fact
        receipt["outcome"] = "failed"
        save()

    try:
        connection = pyodbc.connect(
            "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
            "DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;"
            "Trusted_Connection=yes;APP=P02ReleaseBoundaryOwner;",
            autocommit=True,
            timeout=3,
        )
        connection.timeout = 3
        receipt["before"], receipt["master_before"] = state(connection, prior)
        receipt["login_disabled"] = True
        services = query(connection, cost.SERVICES_SQL)
        agent = [r for r in services if r["servicename"] == "SQL Server Agent (MSSQLSERVER)"]
        if (
            len(agent) != 1
            or agent[0]["status_desc"] != "Stopped"
            or agent[0]["startup_type_desc"] != "Disabled"
        ):
            raise ValueError("SQL Agent must remain stopped and disabled")
        receipt["services"] = services
        before_owners = owner_inventory(connection)
        receipt["owners_before"] = before_owners
        receipt["stage"] = "native protected file boundary"
        save()
        receipt["protected_fixture_state"] = "attempted; retain any partial files"
        receipt["windows"] = {}
        try:
            windows.prepare(manifest, receipt["windows"], save)
        except Exception as error:
            failed(error)
            receipt["windows"]["outcome"] = "failed"
            receipt["windows"]["restart_read"] = {
                "outcome": "skipped",
                "reason": "protected write not accepted",
            }
        else:
            receipt["protected_fixture_state"] = "created and verified"
            receipt["stage"] = "independent protected-file restart read"
            try:
                windows.run_restart(packet, manifest, receipt["windows"], save)
            except Exception as error:
                failed(error)
                receipt["windows"]["outcome"] = "failed"
                if receipt["windows"].get("child_pid") and not receipt["windows"].get(
                    "child_settled"
                ):
                    raise ValueError("Original protected-read child custody unresolved") from error
        write_new(packet / "stage-1.json", receipt["windows"])
        receipt["stage"] = "actual configured application profile"
        receipt["enable_attempted"] = True
        save()
        receipt["login_disabled"] = None
        query(connection, control.ENABLE)
        receipt["login_disabled"] = False
        receipt["configured_reader"] = dict(outcome="running")
        configured_reader.run(packet, manifest, receipt["configured_reader"])
        receipt["outcome"] = "passed" if not receipt["check_failures"] else "failed"
        receipt["stage"] = (
            "native boundaries verified; no seed or runtime published"
            if receipt["outcome"] == "passed"
            else "group completed with retained boundary refusal"
        )
    except BaseException as error:
        failed(error)
    finally:
        os.environ.pop("S11_SQL_PASSWORD", None)
        if connection is not None:
            if receipt["enable_attempted"]:
                try:
                    query(connection, control.DISABLE)
                    receipt["login_disabled"] = True
                except BaseException as error:
                    receipt["cleanup_failures"].append(
                        dict(operation="disable application login", **sql_error_facts(error))
                    )
            if receipt["login_disabled"] and "before" in receipt:
                try:
                    receipt["after"], receipt["master_after"] = state(connection, prior)
                    receipt["owners_after"] = owner_inventory(connection)
                    if receipt["owners_after"] != before_owners:
                        raise ValueError(
                            "Durable producer ownership changed during read-only qualification"
                        )
                except BaseException as error:
                    receipt["cleanup_failures"].append(
                        dict(operation="retained state", **sql_error_facts(error))
                    )
            try:
                connection.close()
                receipt["admin_connections_closed"] += 1
            except BaseException as error:
                receipt["cleanup_failures"].append(
                    dict(operation="admin close", **sql_error_facts(error))
                )
        if "configured_reader" in receipt and not (packet / "stage-3.json").exists():
            try:
                write_new(packet / "stage-3.json", receipt["configured_reader"])
            except BaseException as error:
                receipt["cleanup_failures"].append(
                    dict(operation="configured reader evidence", **sql_error_facts(error))
                )
        if receipt["cleanup_failures"]:
            receipt["outcome"] = "failed"
        receipt["credential_environment_cleared"] = "S11_SQL_PASSWORD" not in os.environ
        receipt["finished"] = datetime.now(UTC).isoformat()
        write_new(packet / "receipt.json", receipt)
    return 0 if receipt["outcome"] == "passed" else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["purpose"] != "native-release-boundary"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated release-boundary fixture required")
    for name, expected in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != expected:
            raise ValueError("Sealed qualification source changed")
    raw = (packet / "evidence/latest-state.json").read_bytes()
    if sha(raw) != PRIOR_SHA or Path(PRIOR_PATH).read_bytes() != raw:
        raise ValueError("Latest retained guest state changed")
    prior = json.loads(raw)
    require_prior(prior)
    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    if sys.argv[1:] == ["--boundary-read"]:
        from independent_readers import write_new
        import release_windows_boundary as windows

        try:
            value = windows.restart_read(manifest)
        except BaseException as error:
            value = dict(
                outcome="failed",
                pid=os.getpid(),
                error_type=type(error).__name__,
                winerror=getattr(error, "winerror", None),
            )
        write_new(packet / "stage-2.json", value)
        return 0 if value["outcome"] == "passed" else 1
    if len(sys.argv) != 1:
        raise ValueError("Unexpected qualification arguments")
    return run(packet, manifest, prior)


def guarded_main():
    """Even evidence-write failure must not print a chained credential exception."""
    try:
        return main()
    except BaseException as error:
        safe = {
            "outcome": "failed",
            "error_type": type(error).__name__[:80],
            "detail": "Inspect retained progress; no replay permitted.",
        }
        try:
            sys.stderr.write(json.dumps(safe) + "\n")
        except BaseException:
            pass
        return 1


if __name__ == "__main__":
    raise SystemExit(guarded_main())
