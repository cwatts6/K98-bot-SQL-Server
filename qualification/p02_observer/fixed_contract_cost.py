"""Read retained fixed-contract plans and native seed dependencies; no replay."""

from datetime import UTC, datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import time

PREVIOUS = r"Q:\P02Observer\20261120204912023\receipt.json"
PREVIOUS_SHA = "8e54f0917e29a3e8270e367191bd8cd5c4cc5ccff711572e15cdf13b172679cf"
QUERY_SHA = "2f9fc21b435805b5ec13ac6eb3b4e4aedca2e63780b8a967a20c05a833e9b51f"

PLAN_SQL = """WITH selected AS (
SELECT TOP (4) qs.plan_handle,qs.statement_start_offset,qs.statement_end_offset,
qs.creation_time,qs.last_execution_time,qs.execution_count,qs.plan_generation_num,
qs.last_worker_time,qs.last_elapsed_time,qs.last_logical_reads,qs.last_logical_writes,
qs.last_physical_reads,qs.last_rows,qs.total_worker_time,qs.total_elapsed_time,
qs.total_logical_reads,st.text AS BatchText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa
WHERE pa.attribute=N'dbid' AND CONVERT(int,pa.value)=DB_ID()
AND st.objectid IS NULL AND CHARINDEX(?,st.text)>0
AND st.text NOT LIKE N'%sys.dm_exec_query_stats%'
ORDER BY qs.last_execution_time DESC,qs.statement_start_offset)
SELECT s.*,DATALENGTH(qp.query_plan) AS plan_bytes,
CASE WHEN DATALENGTH(qp.query_plan)<=2097152
THEN CONVERT(nvarchar(max),qp.query_plan) ELSE NULL END AS plan_xml
FROM selected s
OUTER APPLY sys.dm_exec_query_plan(s.plan_handle) qp
ORDER BY s.last_execution_time DESC,s.statement_start_offset"""
SERVICES_SQL = """SELECT servicename,startup_type_desc,status_desc
FROM sys.dm_server_services WHERE servicename IN
(N'SQL Server (MSSQLSERVER)',N'SQL Server Agent (MSSQLSERVER)')
ORDER BY servicename"""


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_prior(prior):
    if (
        prior.get("outcome") != "passed"
        or prior.get("first_failure") is not None
        or prior.get("cleanup_failures")
        or prior.get("master_mapping_committed") is not True
        or prior.get("contracts_verified") is not True
        or prior.get("commit_binding_verified") is not True
        or prior.get("login_disabled") is not True
        or prior.get("admin_connections_closed") != 1
        or prior.get("before") != prior.get("after")
        or len(prior.get("application_reader", {}).get("connections", [])) != 4
        or any(
            not item.get("closed") or item.get("close_failed")
            for item in prior["application_reader"]["connections"]
        )
    ):
        raise ValueError("Completed three-contract proof and acknowledged closure required")


def inspect(connect, prior, receipt, query, identity, control, audit):
    """One owned admin connection; never enable a login or execute the target query."""
    require_prior(prior)
    if sha(query.encode()) != QUERY_SHA:
        raise ValueError("Exact measured fixed-contract query required")
    connection = None
    failure = None
    started = time.monotonic()

    def canonical(value):
        return json.loads(json.dumps(value, default=str))

    def read(statement, *parameters):
        if len(receipt["dispatches"]) >= 48 or time.monotonic() - started >= 45:
            raise ValueError("Read-only inspection owner exhausted")
        cursor = connection.cursor()
        item = {"sha256": sha(statement.encode()), "seconds": None}
        receipt["dispatches"].append(item)
        tick = time.monotonic()
        read_failure = None
        try:
            cursor.execute(statement, *parameters)
            if not cursor.description:
                raise ValueError("Read-only result required")
            names = [column[0] for column in cursor.description]
            values = cursor.fetchmany(501)
            if len(values) > 500 or cursor.nextset():
                raise ValueError("Bounded single result required")
            return [dict(zip(names, row, strict=True)) for row in values]
        except BaseException as error:
            read_failure = error
            raise
        finally:
            item["seconds"] = time.monotonic() - tick
            try:
                cursor.close()
            except BaseException:
                receipt["cleanup_failures"].append("admin cursor close unconfirmed")
                if read_failure is None:
                    raise

    def state():
        value = dict(
            target=read(identity.TARGET),
            history=read(identity.HISTORY),
            logins=read(control.LOGIN_STATE),
            server_permissions=read(control.SERVER_PERMISSIONS),
            server_roles=read(control.SERVER_ROLES),
        )
        identity.validate_target(value["target"])
        for name, sql in identity.QUERIES.items():
            if name not in ("logins", "server_permissions", "server_roles"):
                value[name] = read(sql)
        value = canonical(value)
        master = {name: read(sql) for name, sql in audit.MASTER.items()}
        if value != prior["after"] or master != prior["master_after"]:
            raise ValueError("Completed setup or retained database state changed")
        if read(control.SESSIONS):
            raise ValueError("Application session remains present")
        return value, master

    try:
        connection = connect()
        connection.timeout = 3
        connection.autocommit = True
        receipt["before"], receipt["master_before"] = state()
        receipt["services"] = read(SERVICES_SQL)
        agent = [
            row
            for row in receipt["services"]
            if row["servicename"] == "SQL Server Agent (MSSQLSERVER)"
        ]
        if (
            len(agent) != 1
            or agent[0]["status_desc"] != "Stopped"
            or agent[0]["startup_type_desc"] != "Disabled"
        ):
            raise ValueError("SQL Agent must remain stopped and disabled")
        receipt["plans"] = read(PLAN_SQL, query)
        for row in receipt["plans"]:
            row["plan_handle"] = bytes(row["plan_handle"]).hex()
            if query not in row["BatchText"]:
                raise ValueError("Cached plan belongs to another query")
        receipt["cached_plan_found"] = bool(receipt["plans"])
        receipt["after"], receipt["master_after"] = state()
        receipt["stage"] = "retained state and cached query inspected"
        receipt["outcome"] = "passed"
    except BaseException as error:
        failure = error
        raise
    finally:
        if connection is not None:
            try:
                connection.close()
                receipt["admin_connections_closed"] += 1
            except BaseException:
                receipt["cleanup_failures"].append("admin connection close unconfirmed")
                if failure is None:
                    raise


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["purpose"] != "fixed-contract-cost-and-seed-prerequisite-read"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated read-only inspection required")
    for name, digest in manifest["files"].items():
        member = (packet / name).resolve()
        if not member.is_relative_to(packet) or sha(member.read_bytes()) != digest:
            raise ValueError("Sealed inspection member changed")
    raw = (packet / "evidence/three-contract-pass.json").read_bytes()
    if sha(raw) != PREVIOUS_SHA or Path(PREVIOUS).read_bytes() != raw:
        raise ValueError("Original successful receipt changed")
    prior = json.loads(raw)
    require_prior(prior)
    sys.path[:0] = [
        str(packet / "bot"),
        str(packet / "qualification/p02_observer"),
        r"C:\discord_file_downloader\venv\Lib\site-packages",
    ]
    os.environ["PYTHON_DOTENV_DISABLED"] = "1"
    import application_identity as identity
    import application_privileges as audit
    import pyodbc
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts
    from services.export_execution_dal import _METADATA_QUERIES

    pyodbc.pooling = False
    receipt = dict(
        schema="p02-fixed-contract-cached-plan-read/1",
        stage="retained-state preflight",
        outcome="running",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        dispatches=[],
        admin_connections_closed=0,
        production_operations=0,
        business_operations=0,
        setup_replayed=False,
        migration_replayed=False,
        restore_replayed=False,
        application_login_enabled=False,
        target_query_reexecuted=False,
    )
    try:
        query = (
            "WITH required AS (SELECT OBJECT_ID(value) AS object_id FROM OPENJSON(?)) "
            + _METADATA_QUERIES["foreign_keys"]
        )
        inspect(
            lambda: pyodbc.connect(
                "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
                "DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;"
                "Trusted_Connection=yes;APP=P02RetainedPlanRead;",
                autocommit=True,
                timeout=3,
            ),
            prior,
            receipt,
            query,
            identity,
            control,
            audit,
        )
        site = Path(r"C:\discord_file_downloader\venv\Lib\site-packages")
        receipt["seed_prerequisites"] = {
            "python_version": list(sys.version_info[:3]),
            "isolated": sys.flags.isolated,
            "no_site": sys.flags.no_site,
            "win32security_discoverable": importlib.util.find_spec("win32security") is not None,
            "pywintypes_discoverable": importlib.util.find_spec("pywintypes") is not None,
            "win32_directory_exists": (site / "win32").is_dir(),
            "win32_lib_directory_exists": (site / "win32/lib").is_dir(),
            "pywin32_system32_exists": (site / "pywin32_system32").is_dir(),
        }
    except BaseException as error:
        receipt["outcome"] = "failed"
        receipt["first_failure"] = dict(stage=receipt["stage"], **sql_error_facts(error))
        if isinstance(error, ValueError):
            receipt["first_failure"]["detail"] = str(error)[:400]
    finally:
        if receipt["cleanup_failures"]:
            receipt["outcome"] = "failed"
        receipt["finished"] = datetime.now(UTC).isoformat()
        with (packet / "receipt.json").open("x", encoding="utf-8") as stream:
            json.dump(receipt, stream, indent=2, default=str)
    return 0 if receipt["outcome"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
