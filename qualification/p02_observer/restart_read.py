"""Read the exact preserved lab after a host/VM restart; never replay work."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys
import time

VM_ID = "2ac1b401-7076-4965-af71-de36ee0f9f9c"
PURPOSE = "retained-lab-post-restart-read"
LATEST_DIRECTORY = "Q:/P02Observer/20261121131946827"
LATEST_SHA = "1011e2488e37067467f1368d3dd0098a6dea31881e469ab915fc2aaec55d911d"
MODULE_DIRECTORY = "Q:/P02Observer/20261121120042532"
MODULE_SHA = "4815a51572da38d7448d23e81d0b4225d0d7fa8cbd54249630a6eaaf0895355e"
RUNTIME_SQL = """SELECT sqlserver_start_time,@@SPID AS reader_session_id,
SYSUTCDATETIME() AS observed_utc FROM sys.dm_os_sys_info"""
STORAGE_SQL = """SELECT f.file_id,f.name,f.type_desc,f.physical_name,
CONVERT(bigint,f.size)*8192 AS allocated_bytes,v.volume_mount_point,
v.total_bytes,v.available_bytes
FROM sys.database_files f CROSS APPLY sys.dm_os_volume_stats(DB_ID(),f.file_id) v
ORDER BY f.file_id"""
DEPENDENCIES_SQL = """SELECT OBJECT_SCHEMA_NAME(d.referencing_id)+N'.'+
OBJECT_NAME(d.referencing_id) AS referencing_object,d.referenced_server_name,
d.referenced_database_name,d.referenced_schema_name,d.referenced_entity_name,
d.referenced_id,d.referenced_minor_id,d.is_caller_dependent,d.is_ambiguous
FROM sys.sql_expression_dependencies d
WHERE d.referencing_id IN (OBJECT_ID(N'dbo.SP_Stats_for_Upload'),
OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK'),OBJECT_ID(N'dbo.usp_ApplyReportGovernorNames'),
OBJECT_ID(N'dbo.usp_MaintenanceDue'),OBJECT_ID(N'dbo.v_ReportGovernorNames'))
ORDER BY referencing_object,d.referenced_server_name,d.referenced_database_name,
d.referenced_schema_name,d.referenced_entity_name,d.referenced_minor_id"""
TRIGGERS_SQL = """SELECT t.name,OBJECT_SCHEMA_NAME(t.parent_id)+N'.'+
OBJECT_NAME(t.parent_id) AS parent_object,t.is_disabled,t.is_instead_of_trigger,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',m.definition),2)) AS definition_sha256
FROM sys.triggers t LEFT JOIN sys.sql_modules m ON m.object_id=t.object_id
WHERE t.parent_id IN (OBJECT_ID(N'dbo.STATS_FOR_UPLOAD'),OBJECT_ID(N'dbo.MaintenanceWork'))
ORDER BY parent_object,t.name"""
OWNER_SQL = """SELECT d.name,d.database_id,
LOWER(CONVERT(varchar(170),d.owner_sid,2)) AS database_owner_sid,
SUSER_SNAME(d.owner_sid) AS owner_login,dp.type_desc AS dbo_type,
LOWER(CONVERT(varchar(170),dp.sid,2)) AS dbo_sid
FROM sys.databases d CROSS JOIN sys.database_principals dp
WHERE d.database_id=DB_ID() AND dp.principal_id=1"""
JOB_SQL = """SELECT CONVERT(varchar(36),job_id) AS job_id,name,enabled,
(SELECT COUNT_BIG(*) FROM msdb.dbo.sysjobsteps s WHERE s.job_id=j.job_id) AS steps,
(SELECT COUNT_BIG(*) FROM msdb.dbo.sysjobschedules s WHERE s.job_id=j.job_id) AS schedules
FROM msdb.dbo.sysjobs j WHERE job_id='69BC82B2-2753-485A-A251-986E4D925012'"""
_HELD = []


def normalized(value):
    return json.loads(json.dumps(value, default=str))


def require_latest(value):
    app = value.get("application", {})
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("connections_closed") != 2
        or value.get("login_disabled") is not True
        or value.get("physical_custody_retained") is not False
        or not value.get("before")
        or value["before"] != value.get("after")
        or not value.get("master_before")
        or value["master_before"] != value.get("master_after")
        or not value.get("ownership_before")
        or value["ownership_before"] != value.get("ownership_after")
        or set(value.get("live_business_hashes", {}))
        != {"STATS_FOR_UPLOAD", "MaintenanceWork", "KVKFinalReportHeader", "EXCEL_FOR_KVK_16"}
        or value["live_business_hashes"] != value.get("business_hashes_after")
        or len(value["after"].get("history", [])) != 106
        or not value.get("snapshot")
        or app.get("temporary_candidate_passed") is not True
        or app.get("temporary_objects_absent") is not True
        or app.get("connection_closed") is not True
        or app.get("credential_environment_cleared") is not True
    ):
        raise ValueError("Exact passed pre-restart receipt and settled cleanup required")


def read_state(read):
    import application_identity as identity
    import application_privileges as audit
    import three_contracts as control

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
    master = {name: read(sql) for name, sql in audit.MASTER.items()}
    return normalized(value), normalized(master), read(control.SESSIONS)


def read_snapshot(read):
    from producer_fixture import FRESH_ACCOUNT, ORIGINAL_PREPARATIONS, RESOURCE_SQL
    import report_failure_read as old

    value, master, sessions = read_state(read)
    return normalized(
        dict(
            database=value,
            master=master,
            application_sessions=sessions,
            ownership=dict(
                preparations=read(FRESH_ACCOUNT, old.ACCOUNT),
                resources=read(RESOURCE_SQL, "account:" + old.ACCOUNT),
                original_preparations=read(ORIGINAL_PREPARATIONS, old.ACCOUNT, old.ACCOUNT),
            ),
            snapshot=read(old.SNAPSHOT_SQL),
            business_hashes={t: read(old.digest_sql("ROK_TRACKER", t)) for t in old.OBJECTS},
        )
    )


def differences(value, prior):
    expected = dict(
        database=prior["after"],
        master=prior["master_after"],
        application_sessions=[],
        ownership=prior["ownership_after"],
        snapshot=prior["snapshot"],
        business_hashes=prior["business_hashes_after"],
    )
    return [name for name, wanted in expected.items() if value.get(name) != wanted]


def require_services(rows):
    lookup = {r["servicename"]: r for r in rows}
    if (
        len(rows) != 2
        or lookup.get("SQL Server (MSSQLSERVER)", {}).get("status_desc") != "Running"
        or lookup.get("SQL Server Agent (MSSQLSERVER)", {}).get("status_desc") != "Stopped"
        or lookup.get("SQL Server Agent (MSSQLSERVER)", {}).get("startup_type_desc") != "Disabled"
    ):
        raise ValueError("Running SQL engine and stopped/disabled Agent required")


class Reader:
    """One physical owner, bounded results; no retry after uncertain cleanup."""

    def __init__(self, connection, record, clock=time.monotonic):
        self.connection, self.record, self.clock = connection, record, clock
        self.started = clock()
        self.cursors = []

    def read(self, sql, *parameters):
        from scripts.verify_k98_running_release import sql_error_facts

        if self.cursors:
            raise RuntimeError("Prior cursor cleanup is unconfirmed")
        if self.clock() - self.started > 120 or self.record["dispatches"] >= 110:
            raise TimeoutError("Grouped read deadline reached; do not replay")
        self.record["dispatches"] += 1
        cursor = self.connection.cursor()
        self.cursors.append(cursor)
        original = None
        tick = self.clock()
        try:
            cursor.execute(sql, *parameters)
            if cursor.description is None:
                raise ValueError("Read-only single result required")
            columns = [c[0] for c in cursor.description]
            rows = cursor.fetchmany(501)
            if len(rows) > 500 or cursor.nextset():
                raise ValueError("Bounded single result required")
            return [dict(zip(columns, row, strict=True)) for row in rows]
        except BaseException as error:
            original = error
            raise
        finally:
            try:
                cursor.close()
                self.cursors.remove(cursor)
            except BaseException as cleanup:
                self.record["cleanup_failures"].append(
                    dict(operation="cursor close", **sql_error_facts(cleanup))
                )
                if original is None:
                    raise
                original.add_note("Original cursor close unconfirmed")
            finally:
                self.record["timings"].append(
                    dict(dispatch=self.record["dispatches"], seconds=self.clock() - tick)
                )


def checkpoint(packet, record):
    # Immutable phase files avoid Windows replacement-sharing failures and retain
    # commit intent/acknowledgement independently. The existing host collects 1..10.
    index = record.get("checkpoint_count", 0) + 1
    if index > 10:
        raise ValueError("Bounded stage record limit reached")
    record["checkpoint_count"] = index
    with (packet / f"stage-{index}.json").open("x", encoding="utf-8") as stream:
        json.dump(record, stream, indent=2, default=str)
        stream.flush()
        os.fsync(stream.fileno())


def run(
    packet,
    prior,
    module_baseline,
    connect=None,
    hold=None,
    *,
    diagnostic=None,
    final_compare=None,
    completion_stage=None,
):
    import fixed_contract_cost as cost
    from independent_readers import write_new
    import report_failure_read as old

    from scripts.verify_k98_running_release import sql_error_facts

    record = dict(
        schema="p02-lab-post-restart-read/1",
        outcome="running",
        stage="SQL connection",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        connections_closed=0,
        dispatches=0,
        timings=[],
        physical_custody_retained=False,
        login_enables=0,
        business_operations=0,
        claim_releases=0,
        migrations=0,
        restores=0,
        persistent_writes=0,
        production_operations=0,
        prior_receipt_sha256=LATEST_SHA,
    )
    connection = reader = None

    def save():
        checkpoint(packet, record)

    # Native and offline entry both enforce one owned attempt before connecting.
    write_new(packet / "entered.json", dict(pid=os.getpid(), started=record["started"]))
    try:
        save()
        if connect is None:
            import pyodbc

            connect = lambda: pyodbc.connect(
                "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
                "DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;"
                "Trusted_Connection=yes;APP=P02PostRestartRead;",
                autocommit=True,
                timeout=3,
            )
        connection = connect()
        connection.timeout = 3
        reader = Reader(connection, record)
        read = reader.read
        record["stage"] = "verify SQL services after restart"
        record["services_before"] = read(cost.SERVICES_SQL)
        require_services(record["services_before"])
        record["runtime"] = read(RUNTIME_SQL)
        record["stage"] = "compare completed setup, original claim and business rows"
        save()
        record["before"] = read_snapshot(read)
        record["before_differences"] = differences(record["before"], prior)
        save()
        if record["before_differences"]:
            raise ValueError("Post-restart retained state differs; no dependent work permitted")
        if diagnostic is not None:
            record["schema"] = "p02-retained-state-diagnostic/1"
            record["stage"] = "scoped retained-state diagnostic"
            save()
            diagnostic(read, record)
        else:
            record["stage"] = "grouped report dependency and fixture planning reads"
            save()
            record["metadata"] = {}
            for name, sql in (
                ("files_and_space", STORAGE_SQL),
                ("dependencies", DEPENDENCIES_SQL),
                ("target_triggers", TRIGGERS_SQL),
                ("database_owner", OWNER_SQL),
                ("modules", old.MODULE_SQL),
                ("authentic_backup_job", JOB_SQL),
            ):
                record["metadata"][name] = normalized(read(sql))
            if record["metadata"]["modules"] != module_baseline["modules"]:
                raise ValueError("Original report module definitions or owners changed")
            if len(record["metadata"]["authentic_backup_job"]) != 1:
                raise ValueError("Authentic retained backup job identity missing")
        record["stage"] = "verify final preserved state"
        save()
        record["after"] = read_snapshot(read)
        record["after_differences"] = (
            final_compare(record, prior)
            if final_compare is not None
            else differences(record["after"], prior)
        )
        record["services_after"] = read(cost.SERVICES_SQL)
        save()
        require_services(record["services_after"])
        if record["after_differences"] or (
            final_compare is None and record["before"] != record["after"]
        ):
            raise ValueError("Retained state changed during restart verification")
        record["outcome"] = "passed"
        record["stage"] = completion_stage or (
            "diagnostics collected; completed setup and original claim preserved"
            if diagnostic is not None
            else "restart state verified; completed setup and original claim preserved"
        )
    except BaseException as error:
        record["outcome"] = "failed"
        record["first_failure"] = dict(stage=record["stage"], **sql_error_facts(error))
    finally:
        if connection is not None:
            try:
                connection.close()
                record["connections_closed"] = 1
                if reader is not None:
                    reader.cursors.clear()
            except BaseException as cleanup:
                _HELD.append((connection, reader))
                record["cleanup_failures"].append(
                    dict(operation="connection close", **sql_error_facts(cleanup))
                )
        record["physical_custody_retained"] = bool(_HELD)
        if record["cleanup_failures"] or _HELD:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        try:
            write_new(packet / "receipt.json", record)
        finally:
            if _HELD:
                if hold is not None:
                    hold()
                else:
                    while True:
                        time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def main(
    *,
    expected_purpose=PURPOSE,
    before_native=None,
    baseline_adapter=None,
    diagnostic=None,
    final_compare=None,
    completion_stage=None,
):
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != expected_purpose
        or manifest.get("vm_id") != VM_ID
        or manifest.get("production_eligible") is not False
    ):
        raise ValueError("Exact isolated post-restart packet required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if (
            not path.is_relative_to(packet)
            or hashlib.sha256(path.read_bytes()).hexdigest() != digest
        ):
            raise ValueError("Sealed restart packet member changed")
    values = []
    for name, directory, digest in (
        ("latest-receipt.json", LATEST_DIRECTORY, LATEST_SHA),
        ("module-baseline.json", MODULE_DIRECTORY, MODULE_SHA),
    ):
        raw = (packet / "evidence" / name).read_bytes()
        if (
            hashlib.sha256(raw).hexdigest() != digest
            or (Path(directory) / "receipt.json").read_bytes() != raw
        ):
            raise ValueError("Retained pre-restart evidence changed")
        values.append(json.loads(raw))
    require_latest(values[0])
    if before_native is not None:
        before_native(packet, manifest, *values)
    if baseline_adapter is not None:
        values = baseline_adapter(packet, *values)
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    return run(
        packet,
        *values,
        diagnostic=diagnostic,
        final_compare=final_compare,
        completion_stage=completion_stage,
    )


if __name__ == "__main__":
    try:
        result = main()
    except BaseException as error:
        sys.stderr.write(
            json.dumps(
                dict(
                    outcome="failed",
                    error_type=type(error).__name__,
                    detail="Retain restart evidence and original claim; no replay.",
                )
            )
            + "\n"
        )
        result = 1
    raise SystemExit(result)
