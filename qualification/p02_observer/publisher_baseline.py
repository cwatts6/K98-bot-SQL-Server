"""One read-only inventory for remaining publisher and comparable cost fixtures."""

from contextlib import contextmanager
from datetime import UTC, datetime
import json
import os
from pathlib import Path
import re
import shutil
import sys
import time

PURPOSE = "preserved-db18-publisher-baseline"
QUERIES = {
    "configuration": "SELECT KVKVersion,ConfigKey,ConfigValue,LastUpdated FROM dbo.ProcConfig WHERE KVKVersion=16 ORDER BY ConfigKey",
    "source_windows": """WITH bounds AS (
SELECT (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4) AS latest,
CAST(MAX(CASE WHEN ConfigKey='KVK_END_SCAN' THEN ConfigValue END) AS int) AS kvk_end,
CAST(MAX(CASE WHEN ConfigKey='PRE_PASS_4_SCAN' THEN ConfigValue END) AS int) AS pre_pass,
CAST(MAX(CASE WHEN ConfigKey='LASTKVKEND' THEN ConfigValue END) AS int) AS last_kvk
FROM dbo.ProcConfig WHERE KVKVersion=16)
SELECT w.label,w.scan_order,(SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4 s
WHERE s.SCANORDER=w.scan_order) AS source_rows FROM bounds b
CROSS APPLY (VALUES ('latest',b.latest),('kvk_end',b.kvk_end),
('pre_pass',b.pre_pass),('last_kvk',b.last_kvk)) w(label,scan_order)
ORDER BY w.label""",
    "header": "SELECT * FROM dbo.KVKFinalReportHeader WHERE KVK_NO=16",
    "kvk_work": "SELECT * FROM dbo.MaintenanceKvkWork WHERE KVKNo=16",
    "table_sizes": """SELECT SCHEMA_NAME(t.schema_id) AS schema_name,t.name,
t.object_id,t.create_date,t.modify_date,SUM(p.row_count) AS rows,
SUM(p.reserved_page_count)*CONVERT(bigint,8192) AS reserved_bytes
FROM sys.tables t JOIN sys.dm_db_partition_stats p ON p.object_id=t.object_id
AND p.index_id IN (0,1)
WHERE t.name IN (N'KingdomScanData4',N'STAGING_STATS',N'EXCEL_FOR_KVK_16',N'STATS_FOR_UPLOAD')
GROUP BY t.schema_id,t.name,t.object_id,t.create_date,t.modify_date ORDER BY t.name""",
    "database_options": """SELECT database_id,name,compatibility_level,collation_name,
recovery_model_desc,page_verify_option_desc,is_auto_create_stats_on,
is_auto_update_stats_on,is_auto_update_stats_async_on,
snapshot_isolation_state_desc,is_read_committed_snapshot_on
FROM sys.databases WHERE database_id=DB_ID()""",
    "files": """SELECT file_id,name,type_desc,physical_name,
size*CONVERT(bigint,8192) AS allocated_bytes,
FILEPROPERTY(name,'SpaceUsed')*CONVERT(bigint,8192) AS used_bytes,max_size,growth,is_percent_growth
FROM sys.database_files ORDER BY file_id""",
    "module_identities": """SELECT SCHEMA_NAME(o.schema_id) AS schema_name,o.name,
o.object_id,o.modify_date,m.uses_ansi_nulls,m.uses_quoted_identifier,
m.execute_as_principal_id,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',m.definition),2)) AS native_definition_sha256
FROM sys.objects o LEFT JOIN sys.sql_modules m ON m.object_id=o.object_id
WHERE o.object_id IN (OBJECT_ID(N'dbo.UPDATE_ALL2'),
OBJECT_ID(N'dbo.usp_S11CompleteStatsReportsCore'),OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK'),
OBJECT_ID(N'dbo.sp_Build_Prekvk_And_Honor_Rankings'),
OBJECT_ID(N'dbo.sp_Refresh_View_EXCEL_FOR_KVK_All'),OBJECT_ID(N'dbo.usp_MaintenanceKvkDue'),
OBJECT_ID(N'dbo.usp_S11ValidateStatsReportStage')) ORDER BY o.name""",
}


def require_packet(packet, manifest):
    from independent_readers import sha

    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("target_database_id") != 18
        or manifest.get("production_eligible") is not False
        or manifest.get("business_operations") != 0
        or manifest.get("maintenance_dispatches") != 0
        or manifest.get("enable_application_login") is not False
        or manifest.get("recovery_replayed") is not False
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
    ):
        raise ValueError("Exact read-only remaining-scope packet required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed read-only member changed")


@contextmanager
def owned(database, record, save):
    from fresh_business_owner import SqlOwner

    from scripts.verify_k98_running_release import sql_error_facts

    owner = SqlOwner(database, record, save)
    first = None
    try:
        yield owner
    except BaseException as error:
        first = error
        raise
    finally:
        try:
            owner.close()
        except BaseException as error:
            record["cleanup_failures"].append(sql_error_facts(error))
            if first is None:
                raise
            first.add_note("Original close unacknowledged; native custody retained.")


def preservation(prior, latest, old_manifest, record, save):
    import business_overlap_state as completed
    from fixed_contract_cost import SERVICES_SQL
    from fresh_business import require_login
    import fresh_business_state as state
    from recovery_coexistence import inventory
    from remaining_actors import canonical, generation, require_headroom
    from restart_read import require_services

    result = {}
    with owned("master", record, save) as owner:
        state.require_identity(owner.read(state.IDENTITY), "master", 1)
        require_login(owner.read)
        require_services(owner.read(SERVICES_SQL))
        if owner.read(state.SESSIONS) or owner.read(state.LOCKS):
            raise ValueError("Foreign activity prevents grouped read-only inspection")
        result["databases"] = completed.require_inventory(owner, prior)
    with owned(state.RETAINED, record, save) as owner:
        result["original"] = state.original_state(
            owner, prior["original_after"]["state"], state.RETAINED
        )
        if result["original"] != latest["original_after"]:
            raise ValueError("Retained original claim changed")
    with owned("ROK_TRACKER", record, save) as owner:
        result["completed"] = completed.require_fresh(owner, prior, old_manifest)
        if result["completed"] != latest["completed_after"]:
            raise ValueError("Completed capture/migration/resource state changed")
        value = inventory(owner)
        for key in ("work", "kvk", "stats"):
            if canonical(value[key]) != latest["maintenance_coexistence"]["settled_state"][key]:
                raise ValueError("Completed maintenance changed; do not continue")
        require_headroom(value)
        result["maintenance"] = {key: canonical(value[key]) for key in ("work", "kvk", "stats")}
        result["generation"] = generation(owner)
        if result["generation"] != 433:
            raise ValueError("Completed observation generation differs")
    return result


def run(packet, manifest):
    from fresh_business_owner import HELD
    import fresh_business_state as state
    from independent_readers import write_new
    import maintenance_result
    import retained_reader_state

    from scripts.verify_k98_running_release import sql_error_facts

    record = dict(
        schema="p02-publisher-baseline/1",
        outcome="running",
        stage="authenticate completed maintenance",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        production_operations=0,
        provider_operations=0,
        business_operations=0,
        maintenance_dispatches=0,
        login_enable_attempted=False,
        login_disabled=None,
        original_preserved=False,
        physical_custody_retained=False,
    )

    def save():
        pending = packet / "progress.pending"
        pending.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        pending.replace(packet / "progress.json")

    write_new(packet / "entered.json", dict(pid=os.getpid(), started=record["started"]))
    try:
        latest = maintenance_result.authenticate(packet)
        record["maintenance_adjudication"] = maintenance_result.adjudicate(latest)
        prior, old_manifest, _ = retained_reader_state.authenticate(packet, manifest)
        if (
            prior["original_after"] != latest["original_after"]
            or prior["databases_after"] != latest["databases_after"]
        ):
            raise ValueError("Completed native evidence chains diverge")
        record["stage"] = "verify preserved ownership and completed maintenance"
        record["before"] = preservation(prior, latest, old_manifest, record, save)
        record["login_disabled"] = True
        record["stage"] = "read publisher inputs and workload fixture dimensions"
        record["publisher_baseline"] = {}
        with owned("ROK_TRACKER", record, save) as owner:
            state.require_identity(owner.read(state.IDENTITY), "ROK_TRACKER", 18)
            for name, sql in QUERIES.items():
                record["publisher_baseline"][name] = owner.read(sql)
                save()
        record["storage"] = {
            letter: dict(
                zip(("total", "used", "free"), shutil.disk_usage(letter + ":\\"), strict=True)
            )
            for letter in ("Q", "R")
        }
        record["stage"] = "verify unchanged post-inspection state"
        record["after"] = preservation(prior, latest, old_manifest, record, save)
        if record["before"] != record["after"]:
            raise ValueError("Read-only inventory changed preserved state")
        record.update(
            outcome="passed",
            original_preserved=True,
            login_disabled=True,
            stage="publisher and cost baseline inventoried; completed work preserved",
        )
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
    finally:
        record["physical_custody_retained"] = bool(HELD)
        if HELD or record["cleanup_failures"]:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        try:
            save()
            write_new(packet / "receipt.json", record)
        finally:
            while HELD:
                time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    require_packet(packet, manifest)
    if len(sys.argv) != 1:
        raise ValueError("Read-only parent entry only")
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    return run(packet, manifest)


if __name__ == "__main__":
    raise SystemExit(main())
