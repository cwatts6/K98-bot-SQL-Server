"""Two real isolated observer callers, both arrival orders, with engine evidence.

This qualifies startup's application SQL stage and the complete release reader.
It does not publish a runtime, start a provider, or run a business producer.
"""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

PRIOR_PATH = r"Q:\P02Observer\20261120215611885\receipt.json"
PRIOR_SHA = "38f560dcf804c3e76d7b126fd51e199c92795e8ce27e16a4775087484d2818ca"
ENGINE_SQL = """SELECT s.session_id,s.program_name,s.host_process_id,s.login_name,
r.database_id,r.status AS request_status,r.command,r.wait_type,r.wait_time,r.start_time,
LOWER(CONVERT(varchar(130),r.plan_handle,2)) AS plan_handle,
CASE WHEN CHARINDEX(?,t.text)>0 THEN 1 ELSE 0 END AS fixed_foreign_key_query,
r.blocking_session_id,r.cpu_time,r.total_elapsed_time,r.reads,r.writes,r.logical_reads,
s.open_transaction_count,s.transaction_isolation_level,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',SUBSTRING(t.text,
(r.statement_start_offset/2)+1,
(CASE WHEN r.statement_end_offset=-1 THEN DATALENGTH(t.text)
ELSE r.statement_end_offset END-r.statement_start_offset)/2+1)),2)) AS statement_sha256
FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id=r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.program_name IN (?,?) AND s.is_user_process=1
AND s.login_name=N'S11_ExportApplication' AND r.database_id=16
ORDER BY s.program_name,s.session_id"""

ACTIVE_PLAN_SQL = """SELECT DATALENGTH(query_plan) AS plan_bytes,
CASE WHEN DATALENGTH(query_plan)<=2097152
THEN CONVERT(nvarchar(max),query_plan) ELSE NULL END AS plan_xml
FROM sys.dm_exec_query_plan(CONVERT(varbinary(64),?,2))"""


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def encode(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), default=str).encode()


def write_new(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, default=str)


def require_prior(value):
    cases = value.get("cases", [])
    group = value.get("fixed_reader_repeats", {})
    if (
        value.get("outcome") != "failed"
        or value.get("stage") != "two caller orders"
        or value.get("first_failure")
        != {
            "stage": "two caller orders",
            "error_type": "ValueError",
            "detail": "Child reader failed; original child evidence retained",
        }
        or value.get("cleanup_failures")
        or value.get("admin_connections_closed") != 1
        or value.get("login_disabled") is not True
        or value.get("before") != value.get("after")
        or value.get("master_before") != value.get("master_after")
        or len(cases) != 1
        or cases[0].get("first") != "startup"
        or cases[0].get("settled") is not True
        or [(c.get("role"), c.get("index")) for c in cases[0].get("children", [])]
        != [("startup", 1), ("release", 2)]
        or any(
            c.get("outcome") != "failed" or c.get("exit_code") != 1 for c in cases[0]["children"]
        )
        or len(group.get("samples", [])) != 6
        or any(s.get("outcome") != "passed" for s in group["samples"])
    ):
        raise ValueError("Exact settled cost regression and closed ownership required")


def require_prior_children(packet, prior):
    for child in prior["cases"][0]["children"]:
        name = "stage-" + str(child["index"]) + ".json"
        raw = (packet / "evidence" / name).read_bytes()
        if (
            sha(raw) != child["receipt_sha256"]
            or Path(PRIOR_PATH).with_name(name).read_bytes() != raw
        ):
            raise ValueError("Original child receipt identity changed")
        value = json.loads(raw)
        if (
            value.get("pid") != child["pid"]
            or value.get("role") != child["role"]
            or value.get("index") != child["index"]
            or value.get("outcome") != "failed"
            or value.get("first_failure")
            != {
                "error_type": "ObservationDeferred",
                "detail": "Catalogue observation deferred: observation_deadline.",
            }
            or value["application_reader"].get("first_failure")
            != {
                "phase": "application",
                "operation": "contract_or_session_comparison",
                "error_type": "ObservationDeferred",
            }
            or not value["application_reader"].get("connections")
            or any(
                c.get("closed") is not True or c.get("close_failed") is not False
                for c in value["application_reader"]["connections"]
            )
        ):
            raise ValueError("Original deferred child cleanup is not acknowledged")


def query(connection, statement, *parameters):
    cursor = connection.cursor()
    failure = None
    try:
        cursor.execute(statement, *parameters)
        if cursor.description:
            columns = [item[0] for item in cursor.description]
            values = cursor.fetchmany(501)
            if len(values) > 500 or cursor.nextset():
                raise ValueError("Bounded single administrative result required")
            return [dict(zip(columns, row, strict=True)) for row in values]
        while cursor.nextset():
            if cursor.description:
                raise ValueError("Unexpected administrative result")
        return []
    except BaseException as error:
        failure = error
        raise
    finally:
        try:
            cursor.close()
        except BaseException as cleanup:
            if failure is not None:
                failure.add_note("Administrative cursor close also unconfirmed")
            else:
                raise cleanup


def state(connection, prior):
    import application_identity as identity
    import application_privileges as audit
    import three_contracts as control

    value = dict(
        target=query(connection, identity.TARGET),
        history=query(connection, identity.HISTORY),
        logins=query(connection, control.LOGIN_STATE),
        server_permissions=query(connection, control.SERVER_PERMISSIONS),
        server_roles=query(connection, control.SERVER_ROLES),
    )
    identity.validate_target(value["target"])
    for name, statement in identity.QUERIES.items():
        if name not in ("logins", "server_permissions", "server_roles"):
            value[name] = query(connection, statement)
    value = json.loads(json.dumps(value, default=str))
    master = {name: query(connection, statement) for name, statement in audit.MASTER.items()}
    if value != prior["after"] or master != prior["master_after"]:
        raise ValueError("Completed setup or retained database state changed")
    if query(connection, control.SESSIONS):
        raise ValueError("Application sessions remain; no replay permitted")
    return value, master


def original_cached_query(text, query_text):
    """ODBC binds '?' as a named server parameter; never change the projection."""
    match = re.match(r"^\((@P[0-9]+)\s+nvarchar\((?:[0-9]+|max)\)\)", text, re.IGNORECASE)
    if match:
        return text[match.end() :].strip() == query_text.replace("?", match[1]).strip()
    return text.strip() == query_text.strip()


def sample_overlap(rows, processes):
    expected = {item["application"]: item["process"].pid for item in processes}
    for row in rows:
        if (
            row["program_name"] not in expected
            or row["host_process_id"] != expected[row["program_name"]]
        ):
            raise ValueError("Observed SQL request belongs to another process incarnation")
    active = {row["program_name"] for row in rows}
    executing = {
        row["program_name"] for row in rows if row["request_status"] in ("running", "runnable")
    }
    return len(expected) == 2 and active == set(expected), len(expected) == 2 and executing == set(
        expected
    )


def run_startup_stage(connect, candidate, release, receipt):
    from core.recovery_sql_snapshot import require_recovery_snapshot_isolation
    from scripts.verify_k98_running_release import ObservationConnections
    from services.application_observation_schedule import (
        observe_application,
        read_owned_observation,
    )
    from services.export_observer_contract import observation_record
    from services.observer_release_dal import committed_observer_receipt
    from services.observer_release_issuance import bind_observer_candidate

    owner = ObservationConnections(connect)
    started = time.monotonic()
    try:
        with owner:
            native = read_owned_observation(
                owner, committed_observer_receipt, request=owner.observation_request()
            )
            receipt["native_application_receipt"] = native
            bound = bind_observer_candidate(release, candidate, native)
            receipt["commit_binding_verified"] = True
            owner.observation_phase("application")
            result = observe_application(
                owner,
                bound["application_sql_contract"],
                request=owner.observation_request(),
                after_read=require_recovery_snapshot_isolation,
            )
            receipt["recovery_isolation_verified"] = True
        return dict(application=result.value, application_observation=observation_record(result))
    finally:
        receipt["application_reader"] = owner.evidence()
        receipt["application_seconds"] = time.monotonic() - started


def worker(packet, manifest, role, index):
    import pyodbc
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts

    receipt = dict(
        role=role,
        index=index,
        pid=os.getpid(),
        outcome="running",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        business_operations=0,
    )
    try:
        credential = manifest["credential"]
        if credential["path"] != control.CREDENTIAL_PATH:
            raise ValueError("Original guest-only credential required")
        encrypted = Path(credential["path"]).read_bytes()
        if sha(encrypted) != credential["sha256"]:
            raise ValueError("Original guest credential changed")
        password = control.unprotect(encrypted)
        candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
        application = manifest["applications"][str(index)]
        base = (
            "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
            "DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;"
        )

        def connect():
            return pyodbc.connect(
                base + f"UID={control.PRINCIPAL};PWD={{{password}}};APP={application};",
                autocommit=True,
                timeout=3,
            )

        run = run_startup_stage if role == "startup" else control.run_contracts
        actual = run(connect, candidate, manifest["release"], receipt)
        password = None
        receipt["application_value_sha256"] = sha(encode(actual["application"]))
        if receipt["application_value_sha256"] != manifest["retained_application_value_sha256"]:
            raise ValueError(
                "Current complete application rows differ from retained successful read"
            )
        write_new(packet / ("stage-" + str(index + 4) + ".json"), actual)
        statements = receipt["application_reader"]["statements"]
        receipt["maximum_application_batch_seconds"] = max(
            item["execute_seconds"] + item["fetch_seconds"]
            for item in statements
            if item["phase"] == "application"
        )
        receipt["maximum_all_batch_seconds"] = max(
            item["execute_seconds"] + item["fetch_seconds"] for item in statements
        )
        receipt["application_batch_cost_passed"] = (
            receipt["maximum_application_batch_seconds"] <= 0.250
        )
        receipt["all_batch_cost_passed"] = receipt["maximum_all_batch_seconds"] <= 0.250
        receipt["outcome"] = "passed"
    except BaseException as error:
        receipt["outcome"] = "failed"
        receipt["first_failure"] = sql_error_facts(error)
        if isinstance(error, ValueError):
            receipt["first_failure"]["detail"] = str(error)[:400]
    finally:
        receipt["finished"] = datetime.now(UTC).isoformat()
        write_new(packet / ("stage-" + str(index) + ".json"), receipt)
    return 0 if receipt["outcome"] == "passed" else 1


def run_pair(
    packet,
    manifest,
    connection,
    first,
    indexes,
    receipt,
    save,
    *,
    launch=None,
    clock=None,
    wait=None,
):
    clock = clock or time.monotonic
    wait = wait or time.sleep
    from services.export_execution_dal import _METADATA_QUERIES

    fixed_projection = _METADATA_QUERIES["foreign_keys"].replace(
        "FROM required)", "FROM @required)"
    )
    started = clock()
    processes = []
    result = dict(
        first=first,
        children=[],
        samples=[],
        first_observed=False,
        simultaneous_requests=False,
        simultaneous_running_or_runnable=False,
        samples_limit=512,
        active_fixed_plans=[],
        settled=False,
    )
    receipt["cases"].append(result)

    def start(role, index):
        if launch is not None:
            process, handles = launch(role, index)
        else:
            out = (packet / ("worker-" + str(index) + "-stdout.txt")).open("xb")
            err = (packet / ("worker-" + str(index) + "-stderr.txt")).open("xb")
            try:
                process = subprocess.Popen(
                    [
                        sys.executable,
                        "-I",
                        "-S",
                        "-B",
                        str(Path(__file__).resolve()),
                        "--worker",
                        role,
                        str(index),
                    ],
                    cwd=packet,
                    stdout=out,
                    stderr=err,
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
            except BaseException:
                out.close()
                err.close()
                raise
            handles = (out, err)
        item = dict(
            role=role,
            index=index,
            process=process,
            handles=handles,
            application=manifest["applications"][str(index)],
        )
        processes.append(item)
        result["children"].append(dict(role=role, index=index, pid=process.pid))
        save()

    failure = None
    try:
        roles = (first, "release" if first == "startup" else "startup")
        start(roles[0], indexes[0])
        while processes[0]["process"].poll() is None and clock() - started < 10:
            rows = query(
                connection,
                ENGINE_SQL,
                fixed_projection,
                manifest["applications"][str(indexes[0])],
                manifest["applications"][str(indexes[1])],
            )
            sample_overlap(rows, processes)
            result["samples"].append(dict(seconds=clock() - started, requests=rows))
            if rows:
                result["first_observed"] = True
                break
            wait(0.020)
        if not result["first_observed"]:
            raise ValueError(
                "Leading actor had no observed engine request; second actor not launched"
            )
        start(roles[1], indexes[1])
        while any(item["process"].poll() is None for item in processes):
            if clock() - started >= 60:
                raise TimeoutError("Original child still owned after the group deadline")
            proof_collected = result["simultaneous_running_or_runnable"] and (
                result["active_fixed_plans"] or clock() - started >= 3
            )
            sampling = len(result["samples"]) < result["samples_limit"] and not proof_collected
            if sampling:
                rows = query(
                    connection,
                    ENGINE_SQL,
                    fixed_projection,
                    *(item["application"] for item in processes),
                )
                active, executing = sample_overlap(rows, processes)
                result["simultaneous_requests"] |= active
                result["simultaneous_running_or_runnable"] |= executing
                result["samples"].append(dict(seconds=clock() - started, requests=rows))
                # One bounded plan read while the measured query is still active;
                # an ODBC connection close may retire a prepared-plan cache entry.
                candidates = [row for row in rows if row.get("fixed_foreign_key_query")]
                if candidates and not result["active_fixed_plans"]:
                    row = candidates[0]
                    if not re.fullmatch(r"[0-9a-f]{2,128}", row["plan_handle"]):
                        raise ValueError("Native plan handle format differs")
                    result["active_fixed_plans"].append(
                        dict(
                            session_id=row["session_id"],
                            host_process_id=row["host_process_id"],
                            plan_handle=row["plan_handle"],
                            sampled_seconds=clock() - started,
                            rows=query(connection, ACTIVE_PLAN_SQL, row["plan_handle"]),
                        )
                    )
            if not sampling and proof_collected and "sampling_completed_seconds" not in result:
                result["sampling_completed_seconds"] = clock() - started
                save()
            wait(0.020 if sampling else 0.100)
    except BaseException as error:
        failure = error
    finally:
        # No terminate/relaunch. Retain native handles and publish unresolved
        # ownership while awaiting only the already-started children.
        if any(item["process"].poll() is None for item in processes):
            result["retained_running"] = True
            save()
        while any(item["process"].poll() is None for item in processes):
            save()
            wait(1.0)
        for item in processes:
            item["process"].wait()
            for handle in item["handles"]:
                handle.close()
        result["settled"] = True
        result["seconds"] = clock() - started
        for item, summary in zip(processes, result["children"], strict=True):
            summary["exit_code"] = item["process"].returncode
            path = packet / ("stage-" + str(item["index"]) + ".json")
            if path.exists():
                raw = path.read_bytes()
                child = json.loads(raw)
                owner = child.get("application_reader", {})
                if (
                    child.get("role") != item["role"]
                    or child.get("index") != item["index"]
                    or child.get("pid") != item["process"].pid
                    or (
                        child.get("outcome") == "passed"
                        and (
                            child.get("first_failure") is not None
                            or not owner.get("connections")
                            or any(
                                not c.get("closed") or c.get("close_failed")
                                for c in owner["connections"]
                            )
                        )
                    )
                ):
                    if failure is None:
                        failure = ValueError(
                            "Child receipt identity or acknowledged cleanup differs"
                        )
                summary.update(
                    receipt_sha256=sha(raw),
                    outcome=child["outcome"],
                    application_seconds=child.get("application_seconds"),
                    application_batch_cost_passed=child.get("application_batch_cost_passed"),
                    all_batch_cost_passed=child.get("all_batch_cost_passed"),
                )
        save()
    if failure is not None:
        raise failure
    if any(item["process"].returncode != 0 for item in processes):
        raise ValueError("Child reader failed; original child evidence retained")
    if not result["simultaneous_requests"] or not result["simultaneous_running_or_runnable"]:
        raise ValueError("Simultaneous engine execution not observed; no timing-only acceptance")
    if any(item.get("outcome") != "passed" for item in result["children"]):
        raise ValueError("Complete child reader receipts required")
    return result


def parent(packet, manifest, prior):
    import fixed_contract_cost as cost
    import pyodbc
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts
    from services.export_execution_dal import _APPLICATION_SCOPED_METADATA, _METADATA_QUERIES

    receipt = dict(
        schema="p02-independent-readers/1",
        outcome="running",
        stage="preflight",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        business_operations=0,
        production_operations=0,
        setup_replayed=False,
        migration_replayed=False,
        restore_replayed=False,
        admin_connections_closed=0,
        cases=[],
        login_disabled=False,
        scope="Actual startup application SQL stage versus complete release reader; no runtime publication, durable producer, capture or provider work.",
    )
    connection = None
    enable_attempted = False

    def save():
        # Parent progress is current state; final receipt is created only once.
        pending = packet / "progress.pending"
        pending.write_text(json.dumps(receipt, indent=2, default=str), encoding="utf-8")
        pending.replace(packet / "progress.json")

    try:
        connection = pyodbc.connect(
            "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
            "DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;"
            "Trusted_Connection=yes;APP=P02ReaderOverlapOwner;",
            autocommit=True,
            timeout=3,
        )
        connection.timeout = 3
        receipt["before"], receipt["master_before"] = state(connection, prior)
        services = query(connection, cost.SERVICES_SQL)
        agent = [row for row in services if row["servicename"] == "SQL Server Agent (MSSQLSERVER)"]
        if (
            len(agent) != 1
            or agent[0]["status_desc"] != "Stopped"
            or agent[0]["startup_type_desc"] != "Disabled"
        ):
            raise ValueError("SQL Agent must remain stopped and disabled")
        receipt["services"] = services
        enable_attempted = True
        query(connection, control.ENABLE)
        from fixed_reader_cost import run as fixed_cost_run

        receipt["stage"] = "fixed-reader parity and repeat cost"
        fixed_cost_run(packet, manifest, receipt, save)
        receipt["stage"] = "two caller orders"
        save()
        run_pair(packet, manifest, connection, "startup", (1, 2), receipt, save)
        run_pair(packet, manifest, connection, "release", (3, 4), receipt, save)
        receipt["stage"] = "cost evidence"
        query_text = _APPLICATION_SCOPED_METADATA["foreign_keys"].replace("@scope", "?")
        # Match the complete parameter-free projection. Preserve and classify
        # the server's parameter declaration separately from the ODBC '?' text.
        plans = query(
            connection,
            cost.PLAN_SQL,
            _METADATA_QUERIES["foreign_keys"].replace("FROM required)", "FROM @required)"),
        )
        for plan in plans:
            plan["plan_handle"] = bytes(plan["plan_handle"]).hex()
            plan["matches_original_query"] = original_cached_query(plan["BatchText"], query_text)
        receipt["fixed_query_plans"] = plans
        receipt["functional_overlap_passed"] = True
        receipt["application_batch_cost_passed"] = all(
            child["application_batch_cost_passed"]
            for case in receipt["cases"]
            for child in case["children"]
        )
        receipt["all_batch_cost_passed"] = all(
            child["all_batch_cost_passed"]
            for case in receipt["cases"]
            for child in case["children"]
        )
        receipt["all_batch_cost_passed"] &= receipt["fixed_reader_repeats"]["batch_cost_passed"]
        receipt["outcome"] = (
            "passed" if receipt["all_batch_cost_passed"] else "completed_with_cost_miss"
        )
    except BaseException as error:
        receipt["outcome"] = "failed"
        receipt["first_failure"] = dict(stage=receipt["stage"], **sql_error_facts(error))
        if isinstance(error, (ValueError, TimeoutError)):
            receipt["first_failure"]["detail"] = str(error)[:400]
    finally:
        if connection is not None:
            if enable_attempted:
                try:
                    query(connection, control.DISABLE)
                    receipt["login_disabled"] = True
                except BaseException as error:
                    receipt["cleanup_failures"].append(
                        dict(operation="disable login", **sql_error_facts(error))
                    )
            if not receipt["cleanup_failures"] and "before" in receipt:
                try:
                    receipt["after"], receipt["master_after"] = state(connection, prior)
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
        if receipt["cleanup_failures"]:
            receipt["outcome"] = "failed"
        receipt["finished"] = datetime.now(UTC).isoformat()
        write_new(packet / "receipt.json", receipt)
    return 0 if receipt["outcome"] in ("passed", "completed_with_cost_miss") else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["purpose"] != "qualified-foreign-key-reuse-and-overlap"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated reader qualification required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed reader packet changed")
    raw = (packet / "evidence/latest-state.json").read_bytes()
    if sha(raw) != PRIOR_SHA or Path(PRIOR_PATH).read_bytes() != raw:
        raise ValueError("Latest completed guest state changed")
    prior = json.loads(raw)
    require_prior(prior)
    require_prior_children(packet, prior)
    sys.path[:0] = [
        str(packet / "bot"),
        str(packet / "qualification/p02_observer"),
        r"C:\discord_file_downloader\venv\Lib\site-packages",
    ]
    os.environ["PYTHON_DOTENV_DISABLED"] = "1"
    import pyodbc

    pyodbc.pooling = False
    if len(sys.argv) == 4 and sys.argv[1] == "--worker":
        role, index = sys.argv[2], int(sys.argv[3])
        if (role, index) not in (("startup", 1), ("release", 2), ("release", 3), ("startup", 4)):
            raise ValueError("Exact one-shot child identity required")
        return worker(packet, manifest, role, index)
    if len(sys.argv) != 1:
        raise ValueError("Unexpected qualification arguments")
    return parent(packet, manifest, prior)


if __name__ == "__main__":
    raise SystemExit(main())
