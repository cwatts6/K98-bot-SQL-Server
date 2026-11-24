"""Two real recovery/observer lifetimes; no maintenance or business dispatch.

The recovery context hook adds a bounded test handoff after its real shared
schema guard. All application reads and physical cleanup remain the actual DAL.
Native concurrent requests and held-guard coexistence are recorded separately.
"""

from contextlib import contextmanager
import json
import threading
import time
from uuid import UUID

IDENTITY_SQL = """SELECT @@SPID AS session_id,DB_ID() AS database_id,
SUSER_SNAME() AS login_name,
(SELECT CONVERT(varchar(36),connection_id) FROM sys.dm_exec_connections WHERE session_id=@@SPID AND parent_connection_id IS NULL) AS connection_id,
@@TRANCOUNT AS transaction_count,
APPLOCK_MODE('public','K98:maintenance-schema:v1','Transaction') AS schema_mode,
APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session') AS marker_mode,
(SELECT transaction_isolation_level FROM sys.dm_exec_sessions
 WHERE session_id=@@SPID) AS isolation_level"""
OBSERVER_ID_SQL = """SELECT @@SPID AS session_id,DB_ID() AS database_id,SUSER_SNAME() AS login_name,
(SELECT CONVERT(varchar(36),connection_id) FROM sys.dm_exec_connections WHERE session_id=@@SPID AND parent_connection_id IS NULL) AS connection_id"""
ACTIVE_SQL = """SELECT r.session_id,CONVERT(varchar(36),r.connection_id) AS connection_id,r.status AS request_status,r.command,
r.blocking_session_id,r.wait_type,r.cpu_time,r.logical_reads
FROM sys.dm_exec_requests r
WHERE r.database_id=18 AND r.session_id IN (?,?,?,?,?) ORDER BY r.session_id"""
MAINTENANCE_SQL = "SELECT * FROM dbo.MaintenanceWork ORDER BY Kind"
KVK_SQL = "SELECT TOP (129) * FROM dbo.MaintenanceKvkWork ORDER BY KVKNo"
STATS_SQL = """SELECT stats_id,name,STATS_DATE(object_id,stats_id) AS updated
FROM sys.stats WHERE object_id=OBJECT_ID(N'dbo.STATS_FOR_UPLOAD') ORDER BY stats_id"""
LOG_SQL = "SELECT total_log_size_in_bytes,used_log_space_in_bytes,used_log_space_in_percent FROM sys.dm_db_log_space_usage"


def one(cursor):
    names = [column[0] for column in cursor.description]
    row = cursor.fetchone()
    if row is None or cursor.fetchone() is not None:
        raise ValueError("One complete identity result required")
    return dict(zip(names, row, strict=True))


def connection_identity(value):
    result = str(UUID(value["connection_id"])).lower()
    if type(value["session_id"]) is not int or value["session_id"] <= 0:
        raise ValueError("Positive physical session identity required")
    return value["session_id"], result


def snapshot_identity(value):
    connection_identity(value)
    if (
        type(value.get("session_id")) is not int
        or value["session_id"] <= 0
        or value.get("database_id") != 18
        or value.get("login_name") != "S11_ExportApplication"
        or value.get("transaction_count") != 1
        or value.get("schema_mode") != "Shared"
        or value.get("marker_mode") != "NoLock"
        or value.get("isolation_level") != 5
    ):
        raise ValueError("Actual application SNAPSHOT transaction and shared schema guard required")


def summary(value, expected):
    row = value["preparation"]
    if (
        str(row["PreparationID"]).lower() != expected["preparation_id"]
        or row["State"] != "captured"
        or row["Version"] != 7
        or row["Fence"] != expected["fence"]
        or str(row["OwnerID"]).lower() != expected["owner_id"]
        or row["SpoolKey"] != expected["snapshot"]["key"]
        or value["resources"]
        or value["action"] != "hold"
    ):
        raise ValueError(
            "Recovery preview must preserve the exact completed capture and grant no action"
        )
    return dict(
        preparation_id=str(row["PreparationID"]).lower(),
        state=row["State"],
        version=row["Version"],
        fence=row["Fence"],
        token=value["token"],
        action=value["action"],
        execution_present=value["execution"] is not None,
        captured=value["captured"],
        resource_count=len(value["resources"]),
    )


def overlap(rows, recovery, observers):
    recovery = connection_identity(recovery)
    observers = {connection_identity(value) for value in observers}
    if recovery in observers:
        raise ValueError("Two distinct physical roles required")
    active = {
        connection_identity(row)
        for row in rows
        if row["request_status"] in {"running", "runnable"} and not row["blocking_session_id"]
    }
    return recovery in active and bool(observers & active)


def case(admin, source, expected, baseline, candidate, release, actual, order, record, save):
    import producer_runtime as runtime
    import services.stats_import_outcome_dal as outcomes
    from fresh_business_owner import HELD
    from independent_readers import encode, sha
    from prepared_reader import PreparedConnections
    from scripts.verify_k98_running_release import sql_error_facts
    import three_contracts as control

    if order not in ("recovery_first", "observer_first"):
        raise ValueError("Exact two arrival orders required")
    events = {
        name: threading.Event()
        for name in (
            "observer_ready",
            "observer_application",
            "observer_go",
            "recovery_entry",
            "recovery_ready",
            "recovery_go",
            "abort",
        )
    }
    record.update(
        order=order,
        first_failure=None,
        workers={},
        samples=[],
        engine_overlap=False,
        guard_coexistence=False,
        cleanup_failures=[],
    )
    original_snapshot = outcomes.recovery_snapshot
    started = time.monotonic()

    def wait(event, seconds=12):
        deadline = time.monotonic() + seconds
        while not event.is_set():
            if events["abort"].is_set():
                raise ValueError("Original companion failed; no new recovery/observer work")
            if time.monotonic() >= deadline:
                raise TimeoutError("Bounded qualification handoff expired")
            event.wait(0.01)

    @contextmanager
    def handoff(factory):
        with original_snapshot(factory) as cursor:
            cursor.execute(IDENTITY_SQL)
            value = one(cursor)
            snapshot_identity(value)
            record["recovery_identity"] = value
            events["recovery_ready"].set()
            wait(events["recovery_go"])
            yield cursor

    def worker(name, body):
        connections = runtime.Connections()
        value = record["workers"][name] = dict(outcome="running", first_failure=None)
        try:
            body(connections, value)
            value["outcome"] = "passed"
        except BaseException as error:
            value["outcome"] = "failed"
            value["first_failure"] = sql_error_facts(error)
            events["abort"].set()
        finally:
            try:
                cleanup = connections.finish()
                value["physical_cleanup"] = cleanup
                if not cleanup["safe_to_exit"]:
                    HELD.append(connections)
                if not cleanup["all_closed_by_callers"] or not cleanup["safe_to_exit"]:
                    value["outcome"] = "failed"
                    events["abort"].set()
            except BaseException as error:
                HELD.append(connections)
                value["cleanup_failure"] = sql_error_facts(error)
                value["outcome"] = "failed"
                events["abort"].set()

    def recovery(connections, value):
        wait(events["recovery_entry"])
        dal = outcomes.StatsImportOutcomeDAL(
            connections, account=source["account"], storage_owner=source["storage_owner"]
        )
        value["preview"] = summary(dal.inspect(expected["preparation_id"]), expected)
        if value["preview"] != baseline:
            raise ValueError("Recovery snapshot changed under a read-only observer")

    def observer(connections, value):
        class ApplicationPhaseOwner(PreparedConnections):
            def observation_phase(self, phase):
                super().observation_phase(phase)
                if phase == "application":
                    events["observer_application"].set()

        owner = ApplicationPhaseOwner(connections)
        try:
            with owner:
                owner.prepare()
                ids = []
                identities = []
                for connection in owner.connections:
                    cursor = connection.cursor()
                    try:
                        cursor.execute(OBSERVER_ID_SQL)
                        identity = one(cursor)
                        if (
                            identity["database_id"] != 18
                            or identity["login_name"] != "S11_ExportApplication"
                        ):
                            raise ValueError("Exact observer application connection required")
                        connection_identity(identity)
                        ids.append(identity["session_id"])
                        identities.append(identity)
                    finally:
                        cursor.close()
                if len(set(ids)) != 4:
                    raise ValueError("Four independently owned observer connections required")
                record["observer_ids"] = ids
                record["observer_connections"] = identities
                events["observer_ready"].set()
                wait(events["observer_go"])
                collected = control.run_contracts(
                    connections, candidate, release, value, owner=owner
                )
                for key in ("application", "installation", "legacy"):
                    if sha(encode(collected[key])) != sha(encode(actual[key])):
                        raise ValueError("Complete concurrent contract rows differ")
                value["complete_parity_passed"] = True
        finally:
            value["reader"] = owner.evidence()
        value["maximum_batch_seconds"] = max(
            s["execute_seconds"] + s["fetch_seconds"] for s in value["reader"]["statements"]
        )

    threads = []
    outcomes.recovery_snapshot = handoff
    try:
        for name, body in (("observer", observer), ("recovery", recovery)):
            thread = threading.Thread(
                target=worker, args=(name, body), name="P02-" + name, daemon=False
            )
            thread.start()
            threads.append(thread)
        wait(events["observer_ready"])
        if order == "recovery_first":
            events["recovery_entry"].set()
            wait(events["recovery_ready"])
        events["observer_go"].set()
        wait(events["observer_application"])
        deadline = time.monotonic() + 3
        # Observe actual SQL entry, not only a thread or client-side signal.
        while time.monotonic() < deadline:
            if events["abort"].is_set():
                raise ValueError("Companion failed before actual observer entry")
            rid = record.get("recovery_identity", {}).get("session_id", -1)
            rows = admin.read(ACTIVE_SQL, rid, *record["observer_ids"])
            record["samples"].append(
                dict(phase="arrival", seconds=time.monotonic() - started, rows=rows)
            )
            if any(
                connection_identity(r)
                in {connection_identity(v) for v in record["observer_connections"]}
                for r in rows
            ):
                record["first_observer_request_observed"] = True
                break
            time.sleep(0.005)
        if not record.get("first_observer_request_observed"):
            raise ValueError("Actual observer entry not observed; do not manufacture an order")
        if order == "observer_first":
            events["recovery_entry"].set()
            wait(events["recovery_ready"])
        if not threads[0].is_alive():
            raise ValueError("Observer ended before recovery guard entry")
        record["guard_coexistence"] = True
        events["recovery_go"].set()
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            rows = admin.read(
                ACTIVE_SQL, record["recovery_identity"]["session_id"], *record["observer_ids"]
            )
            record["samples"].append(
                dict(phase="caller_reads", seconds=time.monotonic() - started, rows=rows)
            )
            record["engine_overlap"] |= overlap(
                rows, record["recovery_identity"], record["observer_connections"]
            )
            if record["engine_overlap"] or not threads[1].is_alive():
                break
            time.sleep(0.005)
    except BaseException as error:
        record["first_failure"] = sql_error_facts(error)
        events["abort"].set()
    finally:
        # Settling keeps each original physical owner alive. No terminate/retry.
        progress_failed = False
        for thread in threads:
            while thread.is_alive():
                thread.join(1)
                if thread.is_alive():
                    record["retained_workers"] = [t.name for t in threads if t.is_alive()]
                    if not progress_failed:
                        try:
                            save()
                        except BaseException as error:
                            progress_failed = True
                            record["cleanup_failures"].append(sql_error_facts(error))
        outcomes.recovery_snapshot = original_snapshot
        record["retained_workers"] = []
        record["seconds"] = time.monotonic() - started
        save()
    if (
        record["first_failure"]
        or record["cleanup_failures"]
        or len(record["workers"]) != 2
        or any(
            w["outcome"] != "passed"
            or not w.get("physical_cleanup", {}).get("all_closed_by_callers")
            for w in record["workers"].values()
        )
    ):
        raise ValueError("Original recovery/observer pair did not complete")
    record["functional_passed"] = True


def inventory(admin):
    value = dict(
        work=admin.read(MAINTENANCE_SQL),
        kvk=admin.read(KVK_SQL),
        stats=admin.read(STATS_SQL),
        log=admin.read(LOG_SQL),
    )
    if len(value["work"]) != 6 or len(value["kvk"]) > 128:
        raise ValueError("Finite complete maintenance readiness inventory required")
    return value


def run_checks(packet, manifest, record, save, admin, actual, sources):
    from retained_reader_cost import application_group
    import producer_runtime as runtime
    import services.stats_import_outcome_dal as outcomes

    source = sources[-1][1]
    expected = json.loads((sources[-1][0] / "stage-5.json").read_bytes())
    record["stage"] = "read maintenance readiness without dispatch"
    record["maintenance_before"] = inventory(admin)
    group = record["recovery_coexistence"] = dict(cases=[], maintenance_dispatches=0)

    def inspect(connect, value):
        dal = outcomes.StatsImportOutcomeDAL(
            connect, account=source["account"], storage_owner=source["storage_owner"]
        )
        value["preview"] = summary(dal.inspect(expected["preparation_id"]), expected)
        return value["preview"]

    baseline = application_group(manifest, record, "recovery_baseline", inspect)
    candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
    for order in ("recovery_first", "observer_first"):
        record["stage"] = "actual recovery and observer: " + order
        value = {}
        group["cases"].append(value)
        with runtime.application_credentials(manifest):
            case(
                admin,
                source,
                expected,
                baseline,
                candidate,
                manifest["release"],
                actual,
                order,
                value,
                save,
            )
    group["batch_cost_passed"] = all(
        c["workers"]["observer"]["maximum_batch_seconds"] <= 0.250 for c in group["cases"]
    )
    group["both_engine_orders"] = all(c["engine_overlap"] for c in group["cases"])
    group["both_guard_orders"] = all(c["guard_coexistence"] for c in group["cases"])
    record["maintenance_after"] = inventory(admin)
    for key in ("work", "kvk", "stats"):
        if record["maintenance_before"][key] != record["maintenance_after"][key]:
            raise ValueError("Read-only pair changed maintenance state")
