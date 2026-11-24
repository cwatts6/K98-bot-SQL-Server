"""Actual caller workload for a fixed OFF/ON cost comparison; no retries."""

from copy import deepcopy
from datetime import datetime, timedelta
import hashlib
import json
from pathlib import Path
import time
from uuid import UUID

from cost_pair_control import owned
from cost_workload_binding import COLUMNS, QUERIES, content_sql, require_content

CLOCKS = "SELECT SYSUTCDATETIME() AS utc_time,SYSDATETIME() AS local_time"
GUARDS = (
    "K98:post-import-stats:v1",
    "k98-legacy-output-snapshot",
    "K98:TargetPublication:DeltaPreprocessing",
    "K98:StatsForUpload:Publish",
    "K98:maintenance-schema:v1",
)
ACQUIRE = """DECLARE @rc int; EXEC @rc=sys.sp_getapplock @Resource=?,
@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
IF @rc<0 THROW 51976,'Fresh cost guard unavailable.',1;"""
RELEASE = """DECLARE @rc int; EXEC @rc=sys.sp_releaseapplock @Resource=?,@LockOwner='Session';
IF @rc<0 THROW 51976,'Fresh cost guard release unconfirmed.',1;"""
REWIND = """SET XACT_ABORT ON;
IF DB_ID() NOT IN (25,26) OR DB_NAME()<>N'ROK_TRACKER' OR @@TRANCOUNT<>0
 THROW 51976,'Exact fresh cost copy required.',1;
IF (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4)<>486427
 OR (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)<>1244
 OR (SELECT COUNT(*) FROM dbo.SUMMARY_PROC_STATE)<>9
 OR EXISTS(SELECT 1 FROM dbo.SUMMARY_PROC_STATE WHERE LastScanOrder<>1244)
 THROW 51976,'Recorded cost source/cursor boundary changed.',1;
BEGIN TRANSACTION;
UPDATE dbo.SUMMARY_PROC_STATE SET LastScanOrder=1243;
IF @@ROWCOUNT<>9 THROW 51976,'Nine owned cost cursors required.',1;
COMMIT;"""
DEMAND = """SET XACT_ABORT ON; DECLARE @request uniqueidentifier=?;
BEGIN TRANSACTION;
EXEC dbo.usp_MaintenanceDue @Kind='import',@RequestID=@request,@ImportKS4=1;
EXEC dbo.usp_MaintenanceDue @Kind='player_report',@RequestID=@request;
EXEC dbo.usp_MaintenanceDue @Kind='final_stats',@RequestID=@request,@FinalDashboard=1,@FinalSummary=1;
DECLARE @n int=0;
WHILE @n<14 BEGIN
 EXEC dbo.usp_MaintenanceConfigurationDue @RowsProcessed=415,@LastScan=1244;
 SET @n+=1;
END;
DECLARE @rc int;
EXEC @rc=sys.sp_getapplock @Resource=N'K98:maintenance-schema:v1',@LockMode='Shared',@LockOwner='Transaction',@LockTimeout=0;
IF @rc<0 THROW 51976,'Fresh cost transaction guard unavailable.',1;
EXEC dbo.usp_MaintenanceKvkDue @KVKNo=16;
COMMIT;"""
MAINTENANCE = "EXEC dbo.usp_update_stats @RequestID=?;"
SETTLED = "SELECT @@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state"
PROCEDURE_COUNTERS = """SELECT OBJECT_SCHEMA_NAME(object_id)+N'.'+OBJECT_NAME(object_id) AS name,
execution_count,total_worker_time,total_elapsed_time,total_logical_reads,total_physical_reads,total_logical_writes,
cached_time FROM sys.dm_exec_procedure_stats WHERE database_id=DB_ID() ORDER BY object_id"""
SOURCE_BOUNDARY = """SELECT CASE WHEN EXISTS(
SELECT 1 FROM dbo.KingdomScanData4 WHERE GovernorID<>0 GROUP BY GovernorID,SCANORDER HAVING COUNT_BIG(*)>1)
OR EXISTS(SELECT 1 FROM dbo.KingdomScanData4 CROSS JOIN (VALUES(3),(6),(12)) v(months)
WHERE ABS(DATEDIFF_BIG(second,ScanDate,DATEADD(month,-v.months,SYSUTCDATETIME())))<=3600
OR ABS(DATEDIFF_BIG(second,ScanDate,DATEADD(month,-v.months,GETDATE())))<=3600)
THEN 1 ELSE 0 END AS ambiguous"""
ERROR_AUDIT = "SELECT COUNT_BIG(*) AS rows,MAX(ErrorTime) AS latest FROM dbo.ErrorAudit"
STATE_TABLES = {"dbo.SUMMARY_PROC_STATE", "dbo.MaintenanceWork", "dbo.MaintenanceKvkWork"}


def baseline_contracts(candidate, bot):
    """Reconstruct immutable reviewed D4 contracts, authenticate, then bind the lab server."""
    from scripts.prepare_k98_update import D4_CONTRACT_UPDATES, D4_SOURCE_FILES
    from scripts.verify_k98_update_pair import P02_MAINTENANCE_REPAIR, p02_maintenance_transition

    value = deepcopy(candidate)
    for key, contract in value.items():
        contract["server"] = "mini_AMD"
        contract.pop("observer_installation", None)
        contract.pop("fingerprint_format", None)
        contract.update(D4_CONTRACT_UPDATES.get(key, {}))
        if key in D4_SOURCE_FILES:
            field, name = D4_SOURCE_FILES[key]
            contract[field] = json.loads((bot / name).read_bytes())
    app = value["application_sql_contract"]
    app["fingerprint_format"] = "application_schema_v2"
    app.pop("maintenance_policy", None)
    approved = p02_maintenance_transition(P02_MAINTENANCE_REPAIR["predecessor"], value)
    return {key: dict(item["after"]) for key, item in approved["contracts"].items()}


def lab_baseline_contracts(candidate, bot, evidence):
    """Bind only the exact lab spelling using authenticated historical evidence."""
    from kvk.dal.new_source_import_dal import digest
    from services.export_runtime_composition import verify_legacy_installation_contract

    raw = evidence.read_bytes()
    if (
        hashlib.sha256(raw).hexdigest()
        != "7eb2f4450cf5ca48fb608354d298675913ea58ae352daf7c203a3b6736f2b1e2"
    ):
        raise ValueError("Exact authenticated original D4 observation required")
    original = json.loads(raw)
    historical = baseline_contracts(candidate, bot)
    verify_legacy_installation_contract(
        original, historical["legacy_sql_contract"], profile=historical["sql_contract"]["profile"]
    )
    projected = deepcopy(original)
    if projected["target"][0]["ServerName"] != "mini_AMD":
        raise ValueError("Historical server spelling differs")
    projected["target"][0]["ServerName"] = "MINI_AMD"
    bound = {key: dict(value, server="MINI_AMD") for key, value in historical.items()}
    bound["legacy_sql_contract"]["metadata_hash"] = digest(projected).hex()
    verify_legacy_installation_contract(
        projected, bound["legacy_sql_contract"], profile=bound["sql_contract"]["profile"]
    )
    return bound


def runtime(packet, manifest, contracts, connections):
    from producer_fixture import capture_configuration

    from core.export_startup_windows import administrative_path
    from services.export_coordination_dal import ExportCoordinationDAL
    from services.export_snapshot_store import ExportSnapshotStore
    from services.legacy_export_snapshot_dal import LegacySnapshotDAL
    from services.legacy_export_snapshot_service import LegacyExportRuntime

    spool = administrative_path(Path(manifest["private_directory"]) / "spool", private=True)
    return LegacyExportRuntime(
        dal=LegacySnapshotDAL(
            connections,
            output_operations=True,
            execution_evidence=True,
            legacy_sql_contract=contracts["legacy_sql_contract"],
            application_sql_contract=contracts["application_sql_contract"],
            sql_profile="application",
        ),
        coordinator=ExportCoordinationDAL(
            connections, preparations=True, output_operations=True, execution_evidence=True
        ),
        store=ExportSnapshotStore(spool, manifest["storage_owner"]),
        account=manifest["account"],
        configuration=capture_configuration(packet, manifest),
    )


def contracts(packet, manifest, mode, record, connections):
    import three_contracts

    from scripts.verify_k98_running_release import ObservationConnections
    from scripts.verify_k98_update_pair import verify_bot_sql_contracts
    from services.observer_release_issuance import bind_observer_candidate

    class TimedConnections(ObservationConnections):
        def __init__(self, connect):
            super().__init__(connect)
            self.phase_started = time.monotonic()
            self.phase_seconds = {}

        def finish_phase(self):
            now = time.monotonic()
            self.phase_seconds[self.phase] = (
                self.phase_seconds.get(self.phase, 0.0) + now - self.phase_started
            )
            self.phase_started = now

        def observation_phase(self, phase):
            self.finish_phase()
            super().observation_phase(phase)

        def evidence(self):
            self.finish_phase()
            return dict(super().evidence(), phase_seconds=dict(self.phase_seconds))

    owner = TimedConnections(connections)
    candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
    if mode == "ON":
        result = three_contracts.run_contracts(
            connections, candidate, manifest["release"], record, owner=owner
        )
        bound = bind_observer_candidate(
            manifest["release"], candidate, record["native_application_receipt"]
        )
    elif mode == "OFF":
        bound = lab_baseline_contracts(
            candidate, packet / "bot", packet / "evidence/d4-original-legacy.json"
        )
        started = time.monotonic()
        try:
            with owner:
                result = verify_bot_sql_contracts(bound, connection_factory=owner)
        except BaseException as error:
            if (
                str(error)
                == "Direct permission metadata differs from protected approved fingerprint."
            ):
                from services.application_observation_schedule import read_owned_observation
                from services.export_execution_dal import legacy_installation_snapshot

                diagnostic = ObservationConnections(connections)
                try:
                    with diagnostic:
                        record["legacy_failure_observation"] = read_owned_observation(
                            diagnostic,
                            lambda cursor: legacy_installation_snapshot(
                                cursor, bound["legacy_sql_contract"]["source"]
                            ),
                        )
                except BaseException as diagnostic_error:
                    record["legacy_diagnostic_failure"] = type(diagnostic_error).__name__
                finally:
                    record["legacy_diagnostic_owner"] = diagnostic.evidence()
            raise
        finally:
            record["application_reader"] = owner.evidence()
            record["application_seconds"] = time.monotonic() - started
    else:
        raise ValueError("Exact OFF/ON mode required")
    record["contracts_passed"] = True
    statements = record["application_reader"]["statements"]
    record["maximum_batch_seconds"] = max(
        (r["execute_seconds"] + r["fetch_seconds"] for r in statements), default=0.0
    )
    record["application_read_seconds"] = record["application_reader"]["phase_seconds"][
        "application"
    ]
    record["statement_count"] = len(statements)
    record["contract_result"] = result
    return bound


def report(packet, manifest, bound, connections, record, save, mode):
    import player_stats_cache
    from services.legacy_export_snapshot_service import (
        producer_capture_scope,
        use_runtime,
        writer_scope,
    )
    from services.player_report_sql import player_connection
    from services.producer_recovery_intent import current_intent, player_cache_intent

    rt = runtime(packet, manifest, bound, connections)

    @player_cache_intent
    def call():
        record["producer_intent"] = current_intent()
        started = time.monotonic()
        with writer_scope("scan_data") as owner:
            record["admission_seconds"] = time.monotonic() - started
            record["preparation_id"] = owner.claim.preparation_id
            record["fresh_observation_present"] = owner.observation is not None
            if record["fresh_observation_present"] != (mode == "ON"):
                raise ValueError("Actual predecessor/successor admission path differs")
            record["business_dispatch_attempted"] = True
            save()
            started = time.monotonic()
            with player_connection(operation="p02_balanced_cost_report") as connection:
                player_stats_cache._execute_sp_with_retries(connection, retries=1)
            record["report_seconds"] = time.monotonic() - started
            record["commit_checkpoint"] = owner.completion
            if (
                not owner.producer_authorized
                or owner.completion is None
                or owner.completion["producer"]
                != {"procedure": "dbo.SP_Stats_for_Upload", "atomic_checkpoint": 1}
            ):
                raise ValueError("Actual report atomic completion is unconfirmed")
        return owner

    started = time.monotonic()
    with use_runtime(rt), producer_capture_scope():
        owner = call()
    record["caller_total_seconds"] = time.monotonic() - started
    # Qualification readback/hash work is measured separately from the real
    # caller's admission, producer, capture and physical-close interval.
    verified_at = time.monotonic()
    if not owner.closed:
        raise ValueError("Actual writer physical close is unconfirmed")
    row, receipt, metadata = rt.verified_snapshot(owner.claim.preparation_id)
    if row["State"] != "captured":
        raise ValueError("Actual immutable capture missing")
    payload = rt.store.read(receipt)
    document = json.loads(payload)
    # Preserve raw immutable bytes; compare complete typed row multisets,
    # including duplicates, independently of incidental SQL row ordering.
    sections = []
    for section in document["sections"]:
        item = deepcopy(section)
        item["rows"] = sorted(
            item["rows"], key=lambda r: json.dumps(r, sort_keys=True, separators=(",", ":"))
        )
        sections.append(item)
    record.update(
        snapshot=dict(
            key=receipt.key,
            byte_count=receipt.byte_count,
            sha256=receipt.sha256,
            storage_owner=receipt.storage_owner,
        ),
        generation=metadata["generation"],
        writer_closed=True,
        sections_sha256=hashlib.sha256(
            json.dumps(sections, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest(),
        section_count=len(sections),
    )
    record["capture_verification_seconds"] = time.monotonic() - verified_at


def names_summary(record, save):
    with owned("ROK_TRACKER", record, save, timeout=120) as owner:
        for guard in GUARDS:
            owner.mutate("acquire fresh cost guard", ACQUIRE, guard)
        owner.mutate("prepare nine new cost cursor workloads", REWIND)
        record["names_session_before"] = owner.read(QUERIES["session_counters"])
        record["names_tempdb_before"] = owner.read(QUERIES["tempdb_counters"])
        for name, sql in (
            ("names", "EXEC dbo.GOVERNOR_NAMES_PROC;"),
            ("summary", "EXEC dbo.SUMMARY_PROC;"),
        ):
            action = dict(
                stage="actual " + name + " cost work",
                sql_sha256=hashlib.sha256(sql.encode()).hexdigest(),
                acknowledged=False,
            )
            record["actions"].append(action)
            save()
            started = time.monotonic()
            owner.read(sql)
            record[name + "_seconds"] = time.monotonic() - started
            action["acknowledged"] = True
            save()
        record["names_session_after"] = owner.read(QUERIES["session_counters"])
        record["names_tempdb_after"] = owner.read(QUERIES["tempdb_counters"])
        if owner.read(SETTLED) != [dict(transaction_count=0, transaction_state=0)]:
            raise ValueError("Names/summary transaction remains open")
        for guard in reversed(GUARDS):
            owner.mutate("release fresh cost guard", RELEASE, guard)


def read_maintenance_results(owner, request, record, save):
    """Drain this procedure's bounded result stream before acknowledging its work."""
    if owner.close_attempted or owner.cursors:
        raise ValueError("Preceding physical SQL ownership is unresolved")
    cursor = owner.connection.cursor()
    owner.cursors.append(cursor)
    owner.record["admin_dispatches"] += 1
    started = time.monotonic()
    first = None
    terminal = None
    record["maintenance_result_sets"] = []
    try:
        cursor.execute(MAINTENANCE, request)
        for _ in range(32):
            if cursor.description:
                columns = [r[0] for r in cursor.description]
                values = cursor.fetchmany(501)
                if len(values) > 500:
                    raise ValueError("Maintenance result exceeds the bounded row allowance")
                rows = [dict(zip(columns, row, strict=True)) for row in values]
                record["maintenance_result_sets"].append(dict(columns=columns, rows=rows))
                save()
                if terminal is not None:
                    raise ValueError("Unexpected result after maintenance's final status")
                if columns == [
                    "Kind",
                    "DueGeneration",
                    "CompletedGeneration",
                    "ClaimedGeneration",
                    "ClaimID",
                    "State",
                    "FirstErrorNumber",
                    "LastErrorNumber",
                ]:
                    terminal = rows
                elif columns != ["IndexName", "FragmentationPercent", "Action"]:
                    raise ValueError("Unexpected maintenance intermediate result shape")
            if not cursor.nextset():
                if terminal is None:
                    raise ValueError("Maintenance's final six-kind result is missing")
                return terminal
        raise ValueError("Maintenance result stream exceeds the bounded set allowance")
    except BaseException as error:
        first = error
        raise
    finally:
        try:
            cursor.close()
            owner.cursors.remove(cursor)
        except BaseException as error:
            owner.record["cleanup_failures"].append(
                dict(operation="maintenance cursor close", error_type=type(error).__name__)
            )
            if first is None:
                raise
        owner.record["admin_seconds"] += time.monotonic() - started


def maintenance(record, save, request):
    UUID(request)
    with owned("ROK_TRACKER", record, save, timeout=180) as owner:
        for guard in GUARDS:
            owner.mutate("acquire cost due-state guard", ACQUIRE, guard)
        owner.mutate("fresh cost maintenance demand", DEMAND, request)
        for guard in reversed(GUARDS):
            owner.mutate("release cost due-state guard", RELEASE, guard)
        record["maintenance_session_before"] = owner.read(QUERIES["session_counters"])
        record["maintenance_tempdb_before"] = owner.read(QUERIES["tempdb_counters"])
        # The actual worker drains all six declared kinds with original guard
        # order and original physical ownership. Never wrap it in a transaction.
        record["stage"] = "actual cost maintenance"
        row = dict(stage=record["stage"], acknowledged=False)
        record["actions"].append(row)
        save()
        started = time.monotonic()
        result = read_maintenance_results(owner, request, record, save)
        row["acknowledged"] = True
        record["maintenance_seconds"] = time.monotonic() - started
        if len(result) != 6 or any(
            r["State"] != "complete"
            or r["DueGeneration"] != r["CompletedGeneration"]
            or r["FirstErrorNumber"] is not None
            or r["LastErrorNumber"] is not None
            for r in result
        ):
            raise ValueError("Actual cost maintenance did not settle all six kinds")
        record["maintenance_result"] = result
        record["maintenance_session_after"] = owner.read(QUERIES["session_counters"])
        record["maintenance_tempdb_after"] = owner.read(QUERIES["tempdb_counters"])
        if owner.read(SETTLED) != [dict(transaction_count=0, transaction_state=0)]:
            raise ValueError("Maintenance left an open transaction")


def normalize_state(name, rows, before, after, request):
    result = deepcopy(rows)
    for row in result:
        if name == "dbo.SUMMARY_PROC_STATE":
            if row["LastScanOrder"] != 1244:
                raise ValueError("Summary did not complete the declared scan")
            time_fields = ("LastRunTime",)
        elif name in ("dbo.MaintenanceWork", "dbo.MaintenanceKvkWork"):
            if (
                row["State"] != "complete"
                or row["DueGeneration"] != row["CompletedGeneration"]
                or row["FirstErrorNumber"] is not None
                or row["LastErrorNumber"] is not None
                or row["FirstErrorUTC"] is not None
            ):
                raise ValueError("Maintenance state is not a clean completed outcome")
            if row["ClaimID"] is None or row["ClaimedGeneration"] != row["CompletedGeneration"]:
                raise ValueError("Completed maintenance claim evidence missing")
            UUID(str(row["ClaimID"]))
            row["ClaimID"] = "completed-owned-claim"
            if name == "dbo.MaintenanceWork":
                if (
                    row["LastRequestID"] is not None
                    and str(row["LastRequestID"]).lower() != request
                ):
                    raise ValueError("Maintenance request is not the fresh declared request")
                if row["LastRequestID"] is not None:
                    row["LastRequestID"] = "fresh-declared-request"
                time_fields = ("DueUTC", "StartedUTC", "CompletedUTC")
            else:
                time_fields = ("CompletedUTC",)
        else:
            raise ValueError("No other output state normalization is allowed")
        start = datetime.fromisoformat(str(before["utc_time"])) - timedelta(milliseconds=4)
        end = datetime.fromisoformat(str(after["utc_time"])) + timedelta(milliseconds=4)
        for field in time_fields:
            stamp = row[field]
            if stamp is None or not start <= datetime.fromisoformat(str(stamp)) <= end:
                raise ValueError("Generated time lies outside the acknowledged workload")
            row[field] = "within-owned-workload"
    return result


def counters(owner):
    return {
        key: owner.read(sql)
        for key, sql in (
            ("log", QUERIES["log_space"]),
            ("io", QUERIES["io_counters"]),
            ("statistics", QUERIES["statistics"]),
            ("procedures", PROCEDURE_COUNTERS),
        )
    }


def outputs(owner, workload, record, save):
    result = {}
    deadline = time.monotonic() + 150
    for name in workload["outputs"]:
        if time.monotonic() >= deadline:
            raise TimeoutError("Complete equality read exceeded its finite lab boundary")
        columns = owner.read(COLUMNS, name)
        count = owner.read("SELECT COUNT_BIG(*) AS rows FROM [dbo].[" + name[4:] + "]")[0]["rows"]
        if not 0 <= count <= 250000:
            raise ValueError("Complete output exceeds the sealed content bound")
        digest = require_content(owner.read(content_sql(name)))
        if digest["rows"] != count:
            raise ValueError("Output changed during complete equality read")
        item = dict(columns=columns, raw_content=digest)
        if name in STATE_TABLES:
            rows = owner.read(
                "SELECT * FROM [dbo].["
                + name[4:]
                + "] ORDER BY "
                + {
                    "dbo.SUMMARY_PROC_STATE": "MetricName",
                    "dbo.MaintenanceWork": "Kind",
                    "dbo.MaintenanceKvkWork": "KVKNo",
                }[name]
            )
            item["raw_rows"] = rows
            item["logical_rows"] = normalize_state(
                name,
                rows,
                record["clock_before"],
                record["clock_after"],
                record["maintenance_request"],
            )
        result[name] = item
    record["outputs"] = result
    save()
    return result


def equality(value):
    return {
        name: (
            dict(columns=item["columns"], logical_rows=item["logical_rows"])
            if name in STATE_TABLES
            else dict(columns=item["columns"], content=item["raw_content"])
        )
        for name, item in value.items()
    }


def consume(packet, manifest, bound, connections, captures):
    rt = runtime(packet, manifest, bound, connections)
    result = []
    for old in captures:
        row, receipt, metadata = rt.verified_snapshot(old["preparation_id"])
        actual = dict(
            key=receipt.key,
            byte_count=receipt.byte_count,
            sha256=receipt.sha256,
            storage_owner=receipt.storage_owner,
        )
        if (
            row["State"] != "captured"
            or actual != old["snapshot"]
            or metadata["generation"] != old["generation"]
        ):
            raise ValueError("Earlier immutable cost capture changed after the next writer")
        rt.store.read(receipt)
        result.append(str(row["PreparationID"]).lower())
    if rt.resolve_preparation(consumer="scan_data") != result[-1] or len(result) != len(
        set(result)
    ):
        raise ValueError("Independent next consumer chose an incorrect captured generation")
    return dict(preparations=result, provider_operations=0, export_jobs_created=0)


def require_settled_capture_set(rows, resources, captures):
    if [str(r["PreparationID"]).lower() for r in rows] != [
        str(r["preparation_id"]).lower() for r in captures
    ] or any(r["State"] != "captured" for r in rows):
        raise ValueError("Exactly the acknowledged fresh captured generations required")
    if len(resources) != 2 or any(
        r["blocked"]
        or any(
            r[k] is not None
            for k in ("ActiveJobID", "ActivePreparationID", "ActiveOutputOperationID", "OwnerID")
        )
        for r in resources
    ):
        raise ValueError("Settled cost arm left a stranded durable owner")
