"""Read the retained failed report and DB17 snapshot; never replay or release it."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys
import time

PRIOR_DIRECTORY = r"Q:\P02Observer\20261121090047837"
PRIOR_SHA = "f822d18c73a94ca6cbd852b39ba824cc4acddc162d7bd3cb8a856af1a3d76152"
ACCOUNT = "p02_capture_20261121090047837"
PREPARATION = "6eafa515-0655-4091-a168-27cfe498cd8d"
SNAPSHOT = "K98_P02Capture_20261121090047837"
IMPERSONATE = "EXECUTE AS LOGIN=N'S11_ExportApplication';"
REVERT = "REVERT;"
CONTEXT_SQL = "SELECT DB_ID() AS database_id,DB_NAME() AS database_name,SUSER_SNAME() AS execution_login,@@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state"
SNAPSHOT_SQL = """SELECT name,database_id,source_database_id,state_desc,is_read_only
FROM sys.databases WHERE database_id=17"""
OWNER_SQL = """SELECT d.name,d.database_id,LOWER(CONVERT(varchar(170),d.owner_sid,2)) AS owner_sid,
SUSER_SNAME(d.owner_sid) AS owner_login,dp.name AS dbo_name,dp.type_desc AS dbo_type
FROM sys.databases d CROSS JOIN sys.database_principals dp
WHERE d.database_id=DB_ID() AND dp.principal_id=1"""
MODULE_SQL = """SELECT SCHEMA_NAME(o.schema_id)+'.'+o.name AS object_name,o.type_desc,
m.execute_as_principal_id,USER_NAME(m.execute_as_principal_id) AS execute_as_user,
COALESCE(o.principal_id,s.principal_id) AS effective_owner_id,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',m.definition),2)) AS definition_sha256
FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
LEFT JOIN sys.sql_modules m ON m.object_id=o.object_id
WHERE o.object_id IN (OBJECT_ID(N'dbo.SP_Stats_for_Upload'),OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK'),
OBJECT_ID(N'dbo.usp_ApplyReportGovernorNames'),OBJECT_ID(N'dbo.usp_MaintenanceDue'),
OBJECT_ID(N'dbo.v_ReportGovernorNames')) ORDER BY object_name"""
PERMISSIONS_SQL = """SELECT SUSER_SNAME() AS execution_login,USER_NAME() AS execution_user,
o.object_name,p.permission_name,HAS_PERMS_BY_NAME(o.object_name,'OBJECT',p.permission_name) AS effective_permission
FROM (VALUES (N'dbo.SP_Stats_for_Upload'),(N'dbo.ACQUIRE_KS4_IMPORT_LOCK'),
(N'dbo.usp_ApplyReportGovernorNames'),(N'dbo.usp_MaintenanceDue'),(N'dbo.v_ReportGovernorNames'),
(N'dbo.ProcConfig'),(N'dbo.KingdomScanData4'),(N'dbo.KVKFinalReportHeader'),
(N'dbo.EXCEL_FOR_KVK_16'),(N'dbo.EXEMPT_FROM_STATS'),(N'dbo.STATS_FOR_UPLOAD'),
(N'dbo.MaintenanceWork')) o(object_name)
CROSS JOIN (VALUES (N'SELECT'),(N'INSERT'),(N'UPDATE'),(N'DELETE'),(N'EXECUTE')) p(permission_name)
ORDER BY o.object_name,p.permission_name"""
DESCRIBE_SQL = """SELECT column_ordinal,name,is_nullable,system_type_name,error_number,error_severity,
error_state,LEFT(error_message,600) AS error_message
FROM sys.dm_exec_describe_first_result_set(?,N'@pLatestKVK int,@pProvenScanDate datetime2(0)',0)
WHERE is_hidden=0 OR error_number IS NOT NULL ORDER BY column_ordinal"""
OBJECTS = {
    "STATS_FOR_UPLOAD": ("Gov_ID", "1=1"),
    "MaintenanceWork": ("Kind", "1=1"),
    "KVKFinalReportHeader": ("KVK_NO", "KVK_NO=16"),
    "EXCEL_FOR_KVK_16": ("Gov_ID", "1=1"),
}


def digest_sql(database, table):
    if database not in ("ROK_TRACKER", SNAPSHOT) or table not in OBJECTS:
        raise ValueError("Exact retained business source required")
    order, condition = OBJECTS[table]
    source = f"[{database}].[dbo].[{table}]"
    return f"""SELECT COUNT_BIG(*) AS rows_count,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',
(SELECT s.* FROM {source} s WHERE {condition} ORDER BY [{order}]
FOR JSON PATH,INCLUDE_NULL_VALUES)),2)) AS rows_sha256
FROM {source} WHERE {condition}"""


def require_prior(prior, stages):
    if (
        prior.get("outcome") != "failed"
        or prior.get("cleanup_failures")
        or prior.get("login_disabled") is not True
        or prior.get("admin_connections_closed") != 1
        or prior.get("before") != prior.get("after")
        or prior.get("master_before") != prior.get("master_after")
        or len(prior.get("cases", [])) != 1
        or stages["stage-4.json"].get("settled") is not True
    ):
        raise ValueError("Exact settled failed original attempt required")
    producer = stages["stage-2.json"]
    reader = stages["stage-3.json"]
    if (
        producer.get("preparation_id") != PREPARATION
        or producer.get("first_failure", {}).get("native_code") != 52819
        or producer.get("business_dispatch_attempted") is not True
        or producer.get("physical_cleanup", {}).get("all_closed_by_callers") is not True
        or reader.get("outcome") != "passed"
        or reader.get("physical_cleanup", {}).get("all_closed_by_callers") is not True
    ):
        raise ValueError("Original producer failure or reader cleanup differs")


def log_facts(directory):
    from report_errors import report_error_text

    result = {}
    for name in ("producer-1.stdout.txt", "producer-1.stderr.txt", "reader-1.stderr.txt"):
        path = directory / name
        if not path.is_file():
            result[name] = {"available": False}
            continue
        if path.resolve().parent != directory.resolve() or path.stat().st_size > 1048576:
            raise ValueError("Retained log binding or bound differs")
        raw = path.read_bytes()
        text = raw.decode("utf-8", errors="replace")
        wrappers = [report_error_text(line) for line in text.splitlines()]
        result[name] = dict(
            available=True,
            byte_count=len(raw),
            sha256=hashlib.sha256(raw).hexdigest(),
            sql_wrappers=[value for value in wrappers if value],
            wrapper_code_present="52819" in text,
        )
    return result


def application_reads(connect, projection, record, save=lambda: None):
    from independent_readers import query

    from core.sql_connection_custody import preserve_failure
    from scripts.verify_k98_running_release import sql_error_facts

    connection = connect()
    failure = None
    record.update(
        impersonation_attempted=False,
        reverted=False,
        connection_closed=False,
        reads={},
        cleanup_failures=[],
    )
    try:
        record["impersonation_attempted"] = True
        query(connection, IMPERSONATE)
        context = query(connection, CONTEXT_SQL)
        if context != [
            dict(
                database_id=16,
                database_name="ROK_TRACKER",
                execution_login="S11_ExportApplication",
                transaction_count=0,
                transaction_state=0,
            )
        ]:
            raise ValueError("Exact read-only application impersonation context required")
        record["context"] = context
        for name, statement, parameters in (
            ("effective_permissions", PERMISSIONS_SQL, ()),
            ("candidate_select_compilation", DESCRIBE_SQL, (projection,)),
        ):
            try:
                record["reads"][name] = dict(
                    outcome="read", rows=query(connection, statement, *parameters)
                )
            except Exception as error:
                record["reads"][name] = dict(outcome="query_refused", **sql_error_facts(error))
    except BaseException as error:
        failure = error
        record["first_failure"] = sql_error_facts(error)
    finally:
        if record["impersonation_attempted"]:
            try:
                query(connection, REVERT)
                record["reverted"] = True
            except BaseException as error:
                failure = preserve_failure(failure, error, "diagnostic_revert")
                record["cleanup_failures"].append(
                    dict(operation="revert", **sql_error_facts(error))
                )
        try:
            connection.close()
            record["connection_closed"] = True
        except BaseException as error:
            failure = preserve_failure(failure, error, "diagnostic_close")
            record["cleanup_failures"].append(dict(operation="close", **sql_error_facts(error)))
        if not record["connection_closed"]:
            try:
                save()
            finally:
                while True:
                    time.sleep(1)
    if failure is not None:
        raise failure


def run(packet, prior, stages):
    from independent_readers import query, state, write_new
    from producer_fixture import FRESH_ACCOUNT, ORIGINAL_PREPARATIONS, RESOURCE_SQL
    import pyodbc

    from scripts.verify_k98_running_release import sql_error_facts

    record = dict(
        outcome="running",
        stage="read-only exact original state",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        connections_closed=0,
        business_operations=0,
        claim_releases=0,
        login_enables=0,
        migrations=0,
        restores=0,
    )
    connection = None

    def save():
        pending = packet / "progress.pending"
        pending.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        pending.replace(packet / "progress.json")

    def connect():
        cn = pyodbc.connect(
            "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;Trusted_Connection=yes;APP=P02ReportReadOnly;",
            autocommit=True,
            timeout=3,
        )
        cn.timeout = 3
        return cn

    def ownership():
        return dict(
            preparations=query(connection, FRESH_ACCOUNT, ACCOUNT),
            resources=query(connection, RESOURCE_SQL, "account:" + ACCOUNT),
            original_preparations=query(connection, ORIGINAL_PREPARATIONS, ACCOUNT, ACCOUNT),
        )

    try:
        record["retained_logs"] = log_facts(Path(PRIOR_DIRECTORY))
        connection = connect()
        record["before"], record["master_before"] = state(connection, prior)
        before = ownership()
        if (
            before["preparations"] != prior["fresh_preparations_observed"]
            or before["resources"] != prior["resources_observed"]
            or before["original_preparations"]
            != stages["stage-1.json"]["preflight"]["original_preparations"]
        ):
            raise ValueError("Original durable ownership changed; no continuation authorized")
        snapshot = query(connection, SNAPSHOT_SQL)
        if snapshot != [prior["snapshot"]]:
            raise ValueError("Exact retained DB17 recovery snapshot required")
        record["ownership_before"] = before
        record["snapshot"] = snapshot
        write_new(
            packet / "stage-1.json",
            dict(ownership=before, snapshot=snapshot, retained_logs=record["retained_logs"]),
        )
        record["stage"] = "compare retained snapshot business state"
        values = {}
        for table in OBJECTS:
            live = query(connection, digest_sql("ROK_TRACKER", table))
            frozen = query(connection, digest_sql(SNAPSHOT, table))
            values[table] = dict(live=live, snapshot=frozen, unchanged=live == frozen)
        record["business_comparison"] = values
        write_new(packet / "stage-2.json", values)
        record["stage"] = "inspect report dependency identity and effective application permissions"
        record["database_owner"] = query(connection, OWNER_SQL)
        record["modules"] = query(connection, MODULE_SQL)
        projection = (packet / "candidate-projection.sql").read_text(encoding="utf-8-sig")
        record["admin_candidate_compilation"] = query(connection, DESCRIBE_SQL, projection)
        record["application"] = {}
        save()
        application_reads(connect, projection, record["application"], save)
        write_new(
            packet / "stage-3.json",
            {
                k: record[k]
                for k in ("database_owner", "modules", "admin_candidate_compilation", "application")
            },
        )
        record["ownership_after"] = ownership()
        if record["ownership_after"] != before:
            raise ValueError("Read-only ownership changed during observation")
        record["after"], record["master_after"] = state(connection, prior)
        record["outcome"] = "passed"
        record["stage"] = "read-only diagnosis collected; retained claim unchanged"
    except BaseException as error:
        record["outcome"] = "failed"
        record["first_failure"] = dict(stage=record["stage"], **sql_error_facts(error))
    finally:
        if connection is not None:
            try:
                connection.close()
                record["connections_closed"] += 1
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="administrative close", **sql_error_facts(error))
                )
                record["outcome"] = "failed"
        if record.get("application", {}).get("connection_closed"):
            record["connections_closed"] += 1
        record["finished"] = datetime.now(UTC).isoformat()
        try:
            write_new(packet / "receipt.json", record)
        finally:
            if connection is not None and record["cleanup_failures"]:
                while True:
                    time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["purpose"] != "retained-report-failure-read-only"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated read-only diagnosis required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if (
            not path.is_relative_to(packet)
            or hashlib.sha256(path.read_bytes()).hexdigest() != digest
        ):
            raise ValueError("Sealed diagnosis source changed")
    stages = {}
    for name in ("receipt.json", "stage-1.json", "stage-2.json", "stage-3.json", "stage-4.json"):
        raw = (packet / "evidence" / name).read_bytes()
        if (Path(PRIOR_DIRECTORY) / name).read_bytes() != raw:
            raise ValueError("Original failed packet evidence changed")
        if name == "receipt.json":
            if hashlib.sha256(raw).hexdigest() != PRIOR_SHA:
                raise ValueError("Exact failed receipt required")
            prior = json.loads(raw)
        else:
            stages[name] = json.loads(raw)
    require_prior(prior, stages)
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    return run(packet, prior, stages)


if __name__ == "__main__":
    try:
        result = main()
    except BaseException as error:
        sys.stderr.write(
            json.dumps(
                dict(
                    outcome="failed",
                    error_type=type(error).__name__,
                    detail="Retain original failure and claim; no replay.",
                )
            )
            + "\n"
        )
        result = 1
    raise SystemExit(result)
