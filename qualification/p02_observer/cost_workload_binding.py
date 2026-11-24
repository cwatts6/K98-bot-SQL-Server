"""Read-only workload binding for the two completed, restricted Q07 copies.

This records readiness, never measured cost or permission to replay earlier work.
The application login stays disabled. No protected target check is bypassed.
"""

from contextlib import contextmanager
from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time

PURPOSE = "p02-matching-cost-workload-binding"
PRIOR = Path("Q:/P02Observer/20261122133857710")
PINS = {
    "packet.zip": "f32b17a44fa374874842849e8a76064f3eb4c5ae844fd483052de3d86ea2b5e1",
    "guest-receipt.json": "c8936123c1018b720c1f957609b9e24a561feb1a439cc00e81eb58148e846671",
    "after/receipt.json": "a3b1c9b39587bde334f77fe382eae07193e7e0cfb269adfac31ff1b460563ce5",
    "restore-bindings.json": "64a229202b2967a3b2a0cc876dcb1433fa1093ea52f8383f9ae4a9b7d0ece73f",
}
NAMES = ("K98_P02Cost_OFF_20261122130322703", "K98_P02Cost_ON_20261122130322703")
EMPTY_SHA = "5ee9173b1b564e61afd2359a897c180b5ea83875a91a28537df4202aad4b3aa7"
QUERIES = {
    "source": """SELECT COUNT_BIG(*) AS source_rows,MAX(SCANORDER) AS latest_scan,
MIN(ScanDate) AS first_scan_date,MAX(ScanDate) AS last_scan_date FROM dbo.KingdomScanData4""",
    "summary_cursors": "SELECT MetricName,LastScanOrder,LastRunTime FROM dbo.SUMMARY_PROC_STATE ORDER BY MetricName",
    "maintenance": "SELECT * FROM dbo.MaintenanceWork ORDER BY Kind",
    "configuration_work": "SELECT * FROM dbo.MaintenanceConfigurationWork ORDER BY ID",
    "backup_work": "SELECT * FROM dbo.MaintenanceBackupWork ORDER BY ID",
    "kvk_work": "SELECT * FROM dbo.MaintenanceKvkWork ORDER BY KVKNo",
    "resources": "SELECT * FROM dbo.ExportResource ORDER BY ResourceKey",
    "statistics": """SELECT COUNT_BIG(*) AS statistics_count,
COALESCE(SUM(CONVERT(bigint,CASE WHEN p.modification_counter>0 OR t.is_memory_optimized=1 THEN 1 ELSE 0 END)),0) AS eligible_count,
SUM(COALESCE(p.modification_counter,0)) AS modifications
FROM sys.stats s JOIN sys.tables t ON t.object_id=s.object_id
OUTER APPLY sys.dm_db_stats_properties(s.object_id,s.stats_id) p WHERE t.is_ms_shipped=0""",
    "log_space": "SELECT total_log_size_in_bytes,used_log_space_in_bytes,used_log_space_in_percent,log_space_in_bytes_since_last_backup FROM sys.dm_db_log_space_usage",
    "session_counters": """SELECT session_id,cpu_time,reads,writes,logical_reads,
open_transaction_count FROM sys.dm_exec_sessions WHERE session_id=@@SPID""",
    "tempdb_counters": """SELECT session_id,user_objects_alloc_page_count,
user_objects_dealloc_page_count,internal_objects_alloc_page_count,
internal_objects_dealloc_page_count FROM tempdb.sys.dm_db_session_space_usage
WHERE session_id=@@SPID""",
    "io_counters": """SELECT file_id,num_of_reads,num_of_bytes_read,io_stall_read_ms,
num_of_writes,num_of_bytes_written,io_stall_write_ms,size_on_disk_bytes
FROM sys.dm_io_virtual_file_stats(DB_ID(),NULL) ORDER BY file_id""",
    "active": """SELECT s.session_id,s.login_name,s.database_id,r.database_id AS request_database,
s.open_transaction_count FROM sys.dm_exec_sessions s LEFT JOIN sys.dm_exec_requests r
ON r.session_id=s.session_id WHERE s.is_user_process=1 AND s.session_id<>@@SPID
AND (s.database_id=DB_ID() OR r.database_id=DB_ID()) ORDER BY s.session_id""",
}
COLUMNS = """SELECT c.column_id,c.name,SCHEMA_NAME(t.schema_id) AS type_schema,t.name AS type_name,
c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name,c.is_identity,c.is_computed
FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id
WHERE c.object_id=OBJECT_ID(?) ORDER BY c.column_id"""
MODULES = """SELECT s.name AS schema_name,o.name,o.type_desc,m.definition,
m.uses_ansi_nulls,m.uses_quoted_identifier,m.execute_as_principal_id
FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
JOIN sys.sql_modules m ON m.object_id=o.object_id WHERE o.object_id=OBJECT_ID(?)"""


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def content_sql(name):
    if name != "dbo.LATEST_T4&T5_KILLS" and not re.fullmatch(
        r"dbo\.[A-Za-z_][A-Za-z0-9_]{0,127}", name
    ):
        raise ValueError("Only sealed dbo output identifiers may select content")
    table = "[dbo].[" + name[4:] + "]"
    return f"""SET NOCOUNT ON;
DECLARE @rows bigint=(SELECT COUNT_BIG(*) FROM {table});
DECLARE @content nvarchar(max)=(SELECT j.doc FROM {table} t
CROSS APPLY (SELECT t.* FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER) j(doc)
ORDER BY j.doc COLLATE Latin1_General_100_BIN2 FOR JSON PATH);
IF @rows=0 AND @content IS NULL SET @content=N'[]';
SELECT @rows AS rows,(SELECT COUNT_BIG(*) FROM OPENJSON(@content)) AS json_rows,
ISJSON(@content) AS valid_json,DATALENGTH(@content) AS json_bytes,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@content),2)) AS content_sha256;"""


def require_content(rows):
    if len(rows) != 1:
        raise ValueError("One complete output digest required")
    value = rows[0]
    n = value.get("rows")
    if (
        type(n) is not int
        or not 0 <= n <= 250000
        or type(value.get("json_rows")) is not int
        or value["json_rows"] != n
        or value.get("valid_json") != 1
        or type(value.get("json_bytes")) is not int
        or not 4 <= value["json_bytes"] <= 256 * 1024**2
        or not re.fullmatch(r"[a-f0-9]{64}", value.get("content_sha256") or "")
        or (n == 0 and (value["json_bytes"] != 4 or value["content_sha256"] != EMPTY_SHA))
        or (n > 0 and value["json_bytes"] <= 4)
    ):
        raise ValueError("Complete output row multiset digest unavailable")
    return value


def require_completed(value, after, bindings):
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failure") is not None
        or not value.get("execution_settled")
        or value.get("connections_closed") != 1
        or value.get("preservation_connections_closed") != 12
        or value.get("matching_content") is not True
        or [a.get("operation") for a in value.get("actions", [])]
        != ["restore only unfinished restricted ON database", "bind only new ON database owner"]
        or any(a.get("acknowledged") is not True for a in value["actions"])
        or after.get("outcome") != "passed"
        or after.get("original_preserved") is not True
        or after.get("physical_custody_retained") is not False
        or after.get("login_disabled") is not True
        or after.get("cleanup_failures") != []
        or after.get("first_failure") is not None
        or [b.get("name") for b in bindings] != list(NAMES)
        or [b.get("database_id") for b in bindings] != [25, 26]
        or len(value.get("fixtures", [])) != 2
        or value["fixtures"][0]["content"] != value["fixtures"][1]["content"]
        or value["fixtures"][0]["history"] != value["fixtures"][1]["history"]
        or len(value["fixtures"][0]["history"]) != 105
        or any(v["observer_objects"] for v in value["fixtures"])
    ):
        raise ValueError("Exact completed matching restricted baselines required")


def require_packet(packet, manifest):
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("production_eligible") is not False
        or tuple(manifest.get("databases", [])) != NAMES
        or manifest.get("data_directory") != r"S:\P02Cost_20261122130322703"
        or not re.fullmatch(r"Q:\\P02Observer\\[0-9]{17}", manifest.get("guest_directory", ""))
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
        or any(
            manifest.get(k) != 0
            for k in ("business_operations", "migrations", "renames", "restores")
        )
        or manifest.get("enable_application_login") is not False
    ):
        raise ValueError("Exact read-only matching-workload packet required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed workload-binding source changed")
    for name, digest in PINS.items():
        if sha((PRIOR / name).read_bytes()) != digest:
            raise ValueError("Completed matching-fixture receipt or archive changed")
    for name in ("guest-receipt.json", "after/receipt.json", "restore-bindings.json"):
        if (PRIOR / name).read_bytes() != (packet / "evidence/cost-ready" / name).read_bytes():
            raise ValueError("Sealed completed-baseline evidence differs")


@contextmanager
def owned_copy(name, record, save):
    from fresh_business_owner import HELD, SqlOwner
    import pyodbc

    if name not in NAMES:
        raise ValueError("Only either exact completed cost copy may be opened")
    owner = SqlOwner.__new__(SqlOwner)
    owner.record, owner.save, owner.cursors = record, save, []
    owner.connection, owner.close_attempted = None, False
    owner.connection = pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;DATABASE="
        + name
        + ";Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;APP=P02CostBinding;",
        autocommit=True,
        timeout=3,
    )
    HELD.append(owner)
    owner.connection.timeout = 15  # Lab data equality, not an application observation.
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
            record["cleanup_failures"].append(
                dict(operation="cost copy close", error_type=type(error).__name__)
            )
            if first is None:
                raise


def read_copy(owner, workload, record, save, deadline):
    from services.catalogue_observation_dal import canonical_module

    value = dict(queries={}, outputs={}, modules={}, statements=[])
    record["workload_copies"].append(value)

    def read(label, sql, *parameters):
        if time.monotonic() >= deadline:
            raise TimeoutError("Read-only binding deadline reached; no business was started")
        started = time.monotonic()
        row = dict(label=label, sql_sha256=sha(sql.encode()), acknowledged=False)
        value["statements"].append(row)
        save()
        result = owner.read(sql, *parameters)
        row.update(acknowledged=True, seconds=time.monotonic() - started)
        return result

    for label, sql in QUERIES.items():
        value["queries"][label] = read(label, sql)
        if label == "active" and value["queries"][label]:
            raise ValueError("A cost copy has another session; no work may proceed")
    for name in workload["outputs"]:
        statement = content_sql(name)
        columns = read(name + " columns", COLUMNS, name)
        if not columns:
            raise ValueError("A declared workload output is missing")
        count = read(name + " bound", "SELECT COUNT_BIG(*) AS rows FROM [dbo].[" + name[4:] + "]")[
            0
        ]["rows"]
        if type(count) is not int or not 0 <= count <= 250000:
            raise ValueError("Declared output exceeds this bounded equality read")
        content = require_content(read(name + " full multiset", statement))
        if content["rows"] != count:
            raise ValueError("Output changed during binding")
        value["outputs"][name] = dict(columns=columns, content=content)
    for name in workload["modules"]:
        rows = read(name + " definition", MODULES, name)
        if len(rows) != 1 or not isinstance(rows[0].get("definition"), str):
            raise ValueError("Complete declared producer source required")
        module = dict(rows[0])
        module["native_definition_sha256"] = sha(module["definition"].encode("utf-16-le"))
        module["canonical_definition_sha256"] = sha(
            canonical_module(module.pop("definition")).encode("utf-16-le")
        )
        value["modules"][name] = module
    save()
    return value


def compare_copies(off, on):
    # Performance counters and physical identifiers are deliberately retained,
    # never equated or represented as measured workload cost.
    differing = [k for k in ("outputs", "modules") if off[k] != on[k]]
    stable = (
        "source",
        "summary_cursors",
        "maintenance",
        "configuration_work",
        "backup_work",
        "kvk_work",
        "resources",
        "statistics",
        "active",
    )
    differing.extend("queries." + k for k in stable if off["queries"][k] != on["queries"][k])
    return differing


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    require_packet(packet, manifest)
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    import cost_fixture_state as cost
    from fresh_business_owner import HELD
    from fresh_business_state import normalized
    from independent_readers import write_new

    from scripts.verify_k98_running_release import sql_error_facts

    record = dict(
        outcome="running",
        stage="authenticate completed baselines",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        original_preserved=False,
        login_disabled=None,
        physical_custody_retained=False,
        actions=[],
        production_operations=0,
        business_operations=0,
        maintenance_dispatches=0,
        migrations=0,
        restores=0,
        renames=0,
        workload_copies=[],
        measured_cost_accepted=False,
    )

    def save():
        pending = packet / "progress.pending"
        pending.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        pending.replace(packet / "progress.json")

    write_new(packet / "entered.json", dict(pid=os.getpid(), purpose=PURPOSE))
    before = None
    try:
        root = packet / "evidence/cost-ready"
        completed = json.loads((root / "guest-receipt.json").read_bytes())
        after = json.loads((root / "after/receipt.json").read_bytes())
        bindings = json.loads((root / "restore-bindings.json").read_bytes())["fixtures"]
        require_completed(completed, after, bindings)
        expected, source = cost.context(packet, manifest)
        record["before"] = cost.observe(
            packet, manifest, "after", record, save, expected, source, bindings
        )
        if record["before"] != after["state"] or record["new_fixtures"] != after["new_fixtures"]:
            raise ValueError("Completed baseline or original state drifted")
        before = record["before"]
        record["stage"] = "bind complete workload on both restricted copies"
        workload = json.loads((packet / "workload.json").read_bytes())
        deadline = time.monotonic() + 150
        for name in NAMES:
            with owned_copy(name, record, save) as owner:
                read_copy(owner, workload, record, save, deadline)
        record["differences"] = compare_copies(*record["workload_copies"])
        record["outcome"] = "passed" if not record["differences"] else "readiness_mismatch"
        record["stage"] = "complete workload bound; cost measurement remains unrun"
    except BaseException as error:
        record.update(outcome="failed", first_failure=sql_error_facts(error))
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        if before is not None and not HELD:
            try:
                record["after"] = cost.observe(
                    packet, manifest, "after", record, save, expected, source, bindings
                )
                if record["after"] != before or record["new_fixtures"] != after["new_fixtures"]:
                    raise ValueError("Original work or completed cost copy identity changed")
                record.update(original_preserved=True, login_disabled=True)
            except BaseException as error:
                record["preservation_failure"] = sql_error_facts(error)
                record["outcome"] = "failed"
        record["physical_custody_retained"] = bool(HELD)
        if HELD or record["cleanup_failures"]:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        save()
        write_new(packet / "receipt.json", normalized(record))
    while HELD:
        time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(main())
