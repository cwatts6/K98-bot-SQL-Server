"""Grouped normal maintenance owners and stable native overlap evidence."""

import json
import threading
import time
from uuid import UUID

import recovery_coexistence as recovery

ACTIVE_SQL = """SELECT r.session_id,CONVERT(varchar(36),r.connection_id) AS connection_id,
r.status AS request_status,r.command,r.blocking_session_id,r.wait_type,
r.cpu_time,r.logical_reads,
(SELECT COUNT(*) FROM sys.dm_tran_locks l
 WHERE l.request_session_id=r.session_id AND l.resource_database_id=18
 AND l.resource_type='APPLICATION' AND l.request_status='GRANT'
 AND l.resource_description LIKE '%K98:catalogue-mutation:v1%') AS marker_locks
FROM sys.dm_exec_requests r WHERE r.database_id=18
AND r.connection_id IN(SELECT CONVERT(uniqueidentifier,value) FROM OPENJSON(?))
ORDER BY r.session_id"""
GENERATION_SQL = "SELECT CONVERT(bigint,current_value) AS generation FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration')"
SLOW_HASHES = (
    "1782eca233e33b9612b56c314c9e43a260896f9f761bca3de08bd6564c937aae",
    "e4486e1a17e218425e0fad6dfd33a905c15a50a0559a15d0910fa8d5cb47288e",
)


def canonical(value):
    return json.loads(json.dumps(value, default=str))


def read_cached_plans(admin, record):
    from fixed_contract_cost import PLAN_SQL
    from independent_readers import sha

    from services.export_execution_dal import _APPLICATION_SCOPED_METADATA, _METADATA_QUERIES

    queries = {}
    for name, query in _METADATA_QUERIES.items():
        query = (
            _APPLICATION_SCOPED_METADATA[name].replace("@scope", "?")
            if name in ("indexes", "foreign_keys")
            else "WITH required AS (SELECT OBJECT_ID(value) AS object_id FROM OPENJSON(?)) " + query
        )
        if sha(query.encode()) in SLOW_HASHES:
            queries[name] = query
    if {sha(q.encode()) for q in queries.values()} != set(SLOW_HASHES):
        raise ValueError("Exact measured fixed queries must resolve before any maintenance")
    # ODBC replaces the bound parameter marker in cached SQL. Match the
    # source-pinned suffix, retaining its complete query identity in evidence.
    record["prior_cost_plans"] = {}
    for name, query in queries.items():
        if query.count("?") != 1:
            raise ValueError("One exact scope parameter required for cached-plan lookup")
        predicate = query.split("?", 1)[1]
        if len(predicate) < 100:
            raise ValueError("Source-specific cache predicate required")
        record["prior_cost_plans"][name] = dict(
            query_sha256=sha(query.encode()),
            predicate_sha256=sha(predicate.encode()),
            rows=admin.read(PLAN_SQL, predicate),
        )


def generation(admin):
    rows = admin.read(GENERATION_SQL)
    if len(rows) != 1 or type(rows[0]["generation"]) is not int:
        raise ValueError("Exact installed generation required")
    return rows[0]["generation"]


def require_initial(value, expected):
    if canonical(value["work"]) != expected["work"] or canonical(value["kvk"]) != expected["kvk"]:
        raise ValueError("Recorded maintenance work changed; do not dispatch")
    by_kind = {row["Kind"]: row for row in value["work"]}
    if len(by_kind) != 6 or value["kvk"]:
        raise ValueError("Six exact kinds and no KVK work required")
    for kind, row in by_kind.items():
        due = 5 if kind == "player_report" else 0
        state = "pending" if due else "complete"
        if (row["DueGeneration"], row["CompletedGeneration"], row["State"]) != (due, 0, state):
            raise ValueError("Only the five completed reports may have pending maintenance")
        if (
            row["ClaimID"] is not None
            or row["FirstErrorNumber"] is not None
            or row["LastErrorNumber"] is not None
        ):
            raise ValueError("No earlier maintenance claim/error can be adopted")
    require_headroom(value)


def require_headroom(value):
    if len(value["log"]) != 1 or not 0 <= value["log"][0]["used_log_space_in_percent"] < 70:
        raise ValueError("Existing maintenance log headroom prerequisite failed")


def require_after(before, after, request, index):
    """Permit only normal player-report consumption and one fresh post-import request."""
    old = {row["Kind"]: row for row in canonical(before["work"])}
    new = {row["Kind"]: row for row in canonical(after["work"])}
    if set(old) != set(new) or canonical(before["kvk"]) != canonical(after["kvk"]):
        raise ValueError("Maintenance work identities changed")
    for kind, row in new.items():
        if kind not in ({"player_report", "post_import"} if index == 1 else {"post_import"}):
            if row != old[kind]:
                raise ValueError("Unexpected maintenance kind changed")
            continue
        due = 5 if kind == "player_report" else index
        if (
            row["DueGeneration"] != due
            or row["CompletedGeneration"] != due
            or row["ClaimedGeneration"] != due
            or row["State"] != "complete"
            or not row["ClaimID"]
            or not row["StartedUTC"]
            or not row["CompletedUTC"]
            or row["FirstErrorNumber"] is not None
            or row["LastErrorNumber"] is not None
        ):
            raise ValueError("Actual maintenance must acknowledge exact useful completion")
        UUID(str(row["ClaimID"]))
        allowed = {
            "CompletedGeneration",
            "ClaimedGeneration",
            "ClaimID",
            "State",
            "StartedUTC",
            "CompletedUTC",
        }
        if kind == "post_import":
            allowed |= {"DueGeneration", "DueUTC", "LastRequestID"}
            if str(row["LastRequestID"]).lower() != request:
                raise ValueError("Maintenance request identity changed")
        if {k: v for k, v in row.items() if k not in allowed} != {
            k: v for k, v in old[kind].items() if k not in allowed
        }:
            raise ValueError("Maintenance changed an unrelated generation or first failure")
    require_headroom(after)


def case(
    admin,
    manifest,
    candidate,
    actual,
    order,
    request,
    record,
    save,
    *,
    operational_factory=None,
    actor_role="maintenance",
    actor_dispatch=None,
    compare_observation=None
):
    from fresh_business_owner import HELD
    from independent_readers import encode, sha
    import producer_runtime as runtime
    import three_contracts as control

    from scripts.verify_k98_running_release import ObservationConnections, sql_error_facts
    from services.catalogue_observation_dal import ObservationDeferred
    from services.maintenance_dal import run_maintenance

    if actor_role not in {"maintenance", "publisher"} or order not in {
        actor_role + "_first",
        "observer_first",
    }:
        raise ValueError("Exact declared actor and arrival order required")
    if actor_role == "publisher" and (
        actor_dispatch is None or operational_factory is None or compare_observation is None
    ):
        raise ValueError("Source-bound publisher owner and comparator required")
    events = {
        name: threading.Event()
        for name in (
            "observer_ready",
            "observer_go",
            actor_role + "_ready",
            actor_role + "_go",
            "abort",
        )
    }
    record.update(
        order=order,
        request_id=request,
        workers={},
        samples=[],
        first_failure=None,
        cleanup_failures=[],
        engine_overlap=False,
        ordering_proven=False,
    )
    started = time.monotonic()
    threads = []

    def wait(name, seconds=12):
        deadline = time.monotonic() + seconds
        while not events[name].is_set():
            if events["abort"].is_set():
                raise ValueError("Original companion failed; no new dispatch")
            if time.monotonic() >= deadline:
                raise TimeoutError("Bounded actor handoff expired")
            events[name].wait(0.01)

    def worker(name, body):
        connections = (
            operational_factory()
            if name == actor_role and operational_factory is not None
            else runtime.Connections()
        )
        value = record["workers"][name] = dict(outcome="running", first_failure=None)
        try:
            body(connections, value)
            if value["outcome"] == "running":
                value["outcome"] = "passed"
        except BaseException as error:
            value.update(outcome="failed", first_failure=sql_error_facts(error))
            events["abort"].set()
        finally:
            try:
                value["physical_cleanup"] = connections.finish()
                clean = value["physical_cleanup"]
                if not clean["safe_to_exit"]:
                    HELD.append(connections)
                if not clean["all_closed_by_callers"] or not clean["safe_to_exit"]:
                    value["outcome"] = "failed"
                    events["abort"].set()
            except BaseException as error:
                HELD.append(connections)
                value.update(outcome="failed", cleanup_failure=sql_error_facts(error))
                events["abort"].set()

    def observer(connections, value):
        class TrackedOwner(ObservationConnections):
            def observation_phase(self, phase):
                super().observation_phase(phase)
                if phase == "application":
                    events["observer_ready"].set()
                    wait("observer_go")

            def __call__(self):
                connection = super().__call__()
                cursor = connection.cursor()
                try:
                    cursor.execute(recovery.OBSERVER_ID_SQL)
                    identity = recovery.one(cursor)
                    if (
                        identity["database_id"] != 18
                        or identity["login_name"] != "S11_ExportApplication"
                    ):
                        raise ValueError("Exact application observer required")
                    recovery.connection_identity(identity)
                    value.setdefault("connections", []).append(identity)
                finally:
                    cursor.close()
                return connection

            def observation_request(self):
                result = super().observation_request()
                value.setdefault("_requests", []).append(result)
                return result

        owner = TrackedOwner(connections)
        try:
            collected = control.run_contracts(
                connections, candidate, manifest["release"], value, owner=owner
            )
            if compare_observation is not None:
                compare_observation(collected, value)
            else:
                for key in ("application", "installation", "legacy"):
                    if sha(encode(collected[key])) != sha(encode(actual[key])):
                        raise ValueError("Full observer comparison changed under maintenance")
            value["complete_parity_passed"] = True
        except ObservationDeferred as error:
            if error.reason not in {
                "active_writer",
                "generation_changed",
                "catalogue_busy",
                "observation_deadline",
            }:
                raise
            value.update(outcome="deferred", deferred_reason=error.reason)
        finally:
            value["requests"] = [
                dict(
                    statements=r.statements,
                    collections=r.collections,
                    boundary_checks=r.boundary_checks,
                )
                for r in value.pop("_requests", [])
            ]
            value["reader"] = owner.evidence()
            statements = value["reader"]["statements"]
            value["maximum_batch_seconds"] = max(
                (s["execute_seconds"] + s["fetch_seconds"] for s in statements), default=0
            )
            value["seconds"] = time.monotonic() - started

    def maintenance(connections, value):
        # Factory setup is owned here until passed exactly once to the real DAL.
        raw = connections()
        cursor = None
        handed = False
        try:
            raw.autocommit = True
            raw.timeout = 3
            cursor = raw.cursor()
            cursor.execute(recovery.OBSERVER_ID_SQL)
            identity = recovery.one(cursor)
            from maintenance_continuation import PRINCIPAL

            expected_login = (
                PRINCIPAL if operational_factory is not None else "S11_ExportApplication"
            )
            if identity["database_id"] != 18 or identity["login_name"] != expected_login:
                raise ValueError("Exact declared maintenance connection required")
            value["connection_profile"] = (
                (
                    "lab Windows operational transport; actual bot operational caller"
                    if actor_role == "maintenance"
                    else "lab Windows operational transport; actual publisher procedure"
                )
                if operational_factory is not None
                else "original application fixture"
            )
            recovery.connection_identity(identity)
            value["identity"] = identity
            cursor.close()
            cursor = None
            events[actor_role + "_ready"].set()
            wait(actor_role + "_go")

            def once():
                nonlocal handed
                if handed:
                    raise ValueError("One original maintenance connection only")
                handed = True
                return raw

            value["dispatch_attempted"] = True
            tick = time.monotonic()
            if actor_dispatch is not None:
                value["result"] = actor_dispatch(once, request, value)
            elif operational_factory is not None:
                from maintenance_continuation import invoke_operational

                value["result"] = invoke_operational(once, request)
            else:
                value["result"] = run_maintenance(once, timeout_seconds=300, request_id=request)
            value["seconds"] = time.monotonic() - tick
            if "backup_request" in value["result"]:
                raise ValueError("Zero final_stats due must not dispatch a backup")
        finally:
            if not handed:
                try:
                    if cursor is not None:
                        cursor.close()
                    raw.close()
                except BaseException:
                    HELD.append(raw)
                    raise

    def sample(phase):
        observer_ids = record["workers"].get("observer", {}).get("connections", [])
        maintenance_id = record["workers"].get(actor_role, {}).get("identity")
        identities = observer_ids + ([maintenance_id] if maintenance_id else [])
        rows = admin.read(ACTIVE_SQL, json.dumps([r["connection_id"] for r in identities]))
        record["samples"].append(dict(phase=phase, seconds=time.monotonic() - started, rows=rows))
        if maintenance_id and observer_ids:
            record["engine_overlap"] |= recovery.overlap(rows, maintenance_id, observer_ids)
        return rows

    try:
        for name, body in (("observer", observer), (actor_role, maintenance)):
            thread = threading.Thread(
                target=worker, args=(name, body), name="P02-" + name, daemon=False
            )
            thread.start()
            threads.append(thread)
        wait("observer_ready")
        wait(actor_role + "_ready")
        first = actor_role if order == actor_role + "_first" else "observer"
        events[first + "_go"].set()
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            if events["abort"].is_set():
                raise ValueError("Original worker failed before ordered entry")
            rows = sample("arrival")
            mid = record["workers"][actor_role]["identity"]
            observer_ids = {
                recovery.connection_identity(r)
                for r in record["workers"]["observer"].get("connections", [])
            }
            if first == actor_role:
                proven = any(
                    recovery.connection_identity(r) == recovery.connection_identity(mid)
                    and r["marker_locks"] > 0
                    for r in rows
                )
            else:
                proven = any(recovery.connection_identity(r) in observer_ids for r in rows)
            if proven:
                record["ordering_proven"] = True
                break
            time.sleep(0.005)
        if not record["ordering_proven"]:
            raise ValueError("Exact native first actor entry not observed; do not retry")
        events[("observer" if first == actor_role else actor_role) + "_go"].set()
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline and all(t.is_alive() for t in threads):
            sample("coexistence")
            if record["engine_overlap"]:
                break
            time.sleep(0.005)
    except BaseException as error:
        record["first_failure"] = sql_error_facts(error)
        events["abort"].set()
    finally:
        progress_failed = False
        for thread in threads:
            while thread.is_alive():
                thread.join(1)
                if thread.is_alive() and not progress_failed:
                    try:
                        save()
                    except BaseException as error:
                        progress_failed = True
                        record["cleanup_failures"].append(sql_error_facts(error))
        record["seconds"] = time.monotonic() - started
        save()
    if (
        record["first_failure"]
        or record["cleanup_failures"]
        or len(record["workers"]) != 2
        or any(w["outcome"] == "failed" for w in record["workers"].values())
    ):
        raise ValueError("Actual maintenance/observer owner did not settle successfully")
    record["functional_passed"] = record["workers"]["observer"]["outcome"] == "passed"


def run_checks(
    packet,
    manifest,
    record,
    save,
    admin,
    actual,
    sources,
    *,
    prior_record=None,
    operational_factory=None
):
    from fresh_business_owner import HELD
    from independent_readers import encode, sha
    import producer_runtime as runtime
    from retained_reader_cost import application_group
    import three_contracts as control

    if prior_record is None:
        # The original grouped entry remains reproducible from its sealed archive.
        recovery.run_checks(packet, manifest, record, save, admin, actual, sources)
        previous = json.loads((packet / "evidence/actor-prior.json").read_bytes())
        expected = previous["maintenance_after"]
    else:
        # A settled exact failure may continue only uncompleted maintenance.
        expected = prior_record["maintenance_coexistence"]["before"]
    before = recovery.inventory(admin)
    require_initial(before, expected)
    group = record["maintenance_coexistence"] = dict(
        cases=[], before=before, requests=manifest["maintenance_requests"]
    )
    candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
    first = None
    try:
        for index, (order, request) in enumerate(
            zip(
                ("maintenance_first", "observer_first"),
                manifest["maintenance_requests"],
                strict=True,
            ),
            1,
        ):
            record["stage"] = "actual maintenance and observer: " + order
            value = {}
            group["cases"].append(value)
            start = generation(admin)
            with runtime.application_credentials(manifest):
                options = (
                    {}
                    if operational_factory is None
                    else dict(operational_factory=operational_factory)
                )
                case(admin, manifest, candidate, actual, order, request, value, save, **options)
            after = recovery.inventory(admin)
            require_after(before, after, request, index)
            value.update(generation_before=start, generation_after=generation(admin), after=after)
            if value["generation_after"] <= start:
                raise ValueError("Actual maintenance must invalidate the original observation")
            before = after
            if not value["functional_passed"]:
                group["remaining_order_unstarted"] = True
                break
    except BaseException as error:
        first = error
        raise
    finally:
        # The current parent read owner is legitimate. Any other retained owner
        # prevents reconciliation until physical custody is settled.
        if not any(item is not admin for item in HELD):
            try:
                group["settled_state"] = recovery.inventory(admin)
                save()
            except BaseException as error:
                from scripts.verify_k98_running_release import sql_error_facts

                group["settled_state_failure"] = sql_error_facts(error)
                if first is None:
                    raise
                first.add_note("Post-case state read failed: " + type(error).__name__)
    group["both_functional_orders"] = len(group["cases"]) == 2 and all(
        c["functional_passed"] for c in group["cases"]
    )
    group["both_engine_orders"] = len(group["cases"]) == 2 and all(
        c["engine_overlap"] for c in group["cases"]
    )
    group["batch_cost_passed"] = all(
        c["workers"]["observer"]["maximum_batch_seconds"] <= 0.250 for c in group["cases"]
    )

    def poststate(connect, value):
        observed = control.run_contracts(connect, candidate, manifest["release"], value)
        if any(
            sha(encode(observed[k])) != sha(encode(actual[k]))
            for k in ("application", "installation", "legacy")
        ):
            raise ValueError("Final full contract comparison differs after actual maintenance")
        value["complete_parity_passed"] = True

    record["stage"] = "fresh post-maintenance full comparator"
    application_group(manifest, record, "post_maintenance_contracts", poststate)
