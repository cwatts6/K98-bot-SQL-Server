"""Source-derived report materialisation in private temp tables; never publish."""

import hashlib
import json
from pathlib import Path
import re
import sys
import time

PASSED_DIRECTORY = "Q:/P02Observer/20261121125443276"
PASSED_SHA = "665ff2d638f7ec5986732470afd3bd718b8cab4c67f6d93b508190554a723034"
PURPOSE = "retained-report-candidate-isolation"
QUERY_STORE_OPTIONS = "SELECT actual_state_desc,desired_state_desc,readonly_reason FROM sys.database_query_store_options"
LOCK_PRINCIPAL_SQL = "SELECT name,principal_id,type_desc,USER_NAME(owning_principal_id) AS owner_name FROM sys.database_principals WHERE name IN (N'dbo',N'K98ImportLockPrincipal') ORDER BY name"
QUERY_STORE_FAILURES = """SELECT TOP (40) q.query_id,p.plan_id,q.object_id,
OBJECT_NAME(q.object_id) AS module_name,r.execution_type,r.execution_type_desc,
r.first_execution_time,r.last_execution_time,r.count_executions,r.max_duration,
LOWER(CONVERT(varchar(16),q.query_hash,2)) AS query_hash,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',t.query_sql_text),2)) AS statement_sha256,
CASE WHEN CHARINDEX(N'#StatsForUploadCandidate',t.query_sql_text)>0 THEN 1 ELSE 0 END AS candidate_statement,
CASE WHEN CHARINDEX(N'#P02LocalReportNames',t.query_sql_text)>0 THEN 1 ELSE 0 END AS names_statement,
CASE WHEN CHARINDEX(N'MaintenanceWork',t.query_sql_text)>0 THEN 1 ELSE 0 END AS maintenance_statement
FROM sys.query_store_runtime_stats r
JOIN sys.query_store_plan p ON p.plan_id=r.plan_id
JOIN sys.query_store_query q ON q.query_id=p.query_id
JOIN sys.query_store_query_text t ON t.query_text_id=q.query_text_id
WHERE r.execution_type IN (3,4)
AND r.last_execution_time>=CONVERT(datetimeoffset,'2026-11-21T11:45:55+00:00',127)
AND r.first_execution_time<=CONVERT(datetimeoffset,'2026-11-21T11:46:15+00:00',127)
AND (q.object_id IN (OBJECT_ID(N'dbo.SP_Stats_for_Upload'),OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK'),
OBJECT_ID(N'dbo.usp_ApplyReportGovernorNames'),OBJECT_ID(N'dbo.usp_MaintenanceDue'))
OR (q.object_id=0 AND CHARINDEX(N'#StatsForUploadCandidate',t.query_sql_text)>0))
ORDER BY r.last_execution_time DESC,q.query_id,p.plan_id,r.runtime_stats_id"""


def failure_facts(error):
    from scripts.verify_k98_running_release import sql_error_facts

    facts = sql_error_facts(error)
    args = getattr(error, "args", ())
    if (
        len(args) > 1
        and isinstance(args[0], str)
        and re.fullmatch(r"[A-Z0-9]{5}", args[0])
        and isinstance(args[1], str)
    ):
        allowed = {
            207,
            208,
            229,
            245,
            248,
            468,
            515,
            547,
            1222,
            2601,
            2627,
            2628,
            3621,
            8114,
            8115,
            8152,
            8164,
            15151,
            15404,
            15517,
        }
        facts["known_native_codes"] = sorted(
            {
                int(value)
                for value in re.findall(
                    r"\((-?\d{1,10})\)(?=\s*(?:\(SQL[A-Za-z0-9_]+\)|;\s*\[[A-Z0-9]{5}\]|\Z))",
                    args[1][:8192],
                )
                if int(value) in allowed
            }
        )
    return facts


def require_completed(value, original, diagnostic):
    app = value.get("application", {})
    reads = app.get("reads", {})
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures")
        or value.get("connections_closed") != 2
        or value.get("login_disabled") is not True
        or value.get("physical_custody_retained") is not False
        or value.get("before") != original["after"]
        or value.get("after") != original["after"]
        or value.get("master_before") != original["master_after"]
        or value.get("master_after") != original["master_after"]
        or value.get("ownership_before") != diagnostic["ownership_before"]
        or value.get("ownership_after") != diagnostic["ownership_before"]
        or app.get("connection_closed") is not True
        or app.get("credential_environment_cleared") is not True
        or app.get("first_failure") is not None
        or app.get("cleanup_failures")
        or app.get("transaction_boundaries")
        != {
            name: [dict(transaction_count=0, transaction_state=0)]
            for name in ("before_identity", "after_identity", "after_diagnostics")
        }
        or reads.get("effective_permissions", {}).get("outcome") != "read"
        or len(reads.get("effective_permissions", {}).get("rows", [])) != 60
        or reads.get("candidate_select_compilation", {}).get("outcome") != "read"
        or len(reads.get("candidate_select_compilation", {}).get("rows", [])) != 62
        or any(r["error_number"] is not None for r in reads["candidate_select_compilation"]["rows"])
    ):
        raise ValueError("Exact completed application diagnostic required")


def before_native(packet, manifest, original, diagnostic):
    raw = (packet / "evidence/completed-diagnostic.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != PASSED_SHA
        or (Path(PASSED_DIRECTORY) / "receipt.json").read_bytes() != raw
    ):
        raise ValueError("Completed diagnostic evidence changed")
    require_completed(json.loads(raw), original, diagnostic)


def administrative_reads(connection, record):
    from independent_readers import query

    for name, statement in (
        ("import_lock_principal", LOCK_PRINCIPAL_SQL),
        ("query_store_options", QUERY_STORE_OPTIONS),
        ("original_window_exceptions", QUERY_STORE_FAILURES),
    ):
        started = time.monotonic()
        try:
            record[name] = dict(outcome="read", rows=query(connection, statement))
        except Exception as error:
            record[name] = dict(outcome="query_refused", **failure_facts(error))
        record[name]["seconds"] = time.monotonic() - started
    record["interpretation"] = (
        "Existing aggregate history only; absence is not proof of no error and correlation is not exact session attribution."
    )


def candidate_reads(connection, record, steps):
    from independent_readers import query

    from core.sql_connection_custody import preserve_failure

    record.update(
        temporary_steps={},
        temporary_cleanup=[],
        temporary_objects_absent=False,
        persistent_writes=0,
        report_procedure_calls=0,
        claim_releases=0,
    )
    connection.timeout = 15
    owned = []
    failure = None

    def step(name):
        record["candidate_phase"] = name
        started = time.monotonic()
        try:
            rows = query(connection, steps[name])
            record["temporary_steps"][name] = dict(
                outcome="completed", rows=rows, seconds=time.monotonic() - started
            )
            return rows
        except BaseException as error:
            record["temporary_steps"][name] = dict(
                outcome="failed", seconds=time.monotonic() - started, **failure_facts(error)
            )
            raise

    try:
        if step("preflight") != [
            dict(
                candidate_object=None,
                names_object=None,
                scan_rows=410,
                scan_min="2026-09-29T14:44:00",
                scan_max="2026-09-29T14:44:00",
            )
        ]:
            raise ValueError("Exact empty private temp namespace and retained scan inputs required")
        owned.append("candidate")
        step("create_candidate")
        step("insert_candidate")
        if step("summarize_candidate") != [dict(row_count=415, invalid_rows=0, duplicate_groups=0)]:
            raise ValueError("Temporary candidate shape differs from retained source")
        owned.append("names")
        step("create_names")
        step("populate_names")
        step("update_candidate_names")
        rows = step("summarize_names")
        if (
            len(rows) != 1
            or rows[0]["names_rows"] <= 0
            or rows[0]["candidate_rows"] != 415
            or rows[0]["unresolved_names"] != 0
        ):
            raise ValueError("Temporary report names did not resolve consistently")
        record["temporary_candidate_passed"] = True
    except BaseException as error:
        failure = error
        record["candidate_first_failure"] = dict(
            phase=record.get("candidate_phase"), **failure_facts(error)
        )
    finally:
        for name in reversed(owned):
            try:
                query(connection, steps["drop_" + name])
                record["temporary_cleanup"].append(dict(object=name, dropped=True))
            except BaseException as error:
                failure = preserve_failure(failure, error, "drop_private_" + name)
                record["temporary_cleanup"].append(
                    dict(object=name, dropped=False, **failure_facts(error))
                )
        try:
            rows = query(connection, steps["after_cleanup"])
            record["temporary_objects_after"] = rows
            record["temporary_objects_absent"] = rows == [
                dict(candidate_object=None, names_object=None)
            ]
            if not record["temporary_objects_absent"]:
                raise ValueError("Private temporary objects remain")
        except BaseException as error:
            failure = preserve_failure(failure, error, "verify_private_temp_cleanup")
    if failure is not None:
        raise failure


def application_reads(manifest, projection, record, retained):
    import report_application_read as base

    packet = Path(__file__).resolve().parents[2]
    steps = json.loads((packet / "candidate-steps.json").read_bytes())
    record["completed_diagnostic_reused_sha256"] = PASSED_SHA
    return base.application_reads(
        manifest,
        projection,
        record,
        retained,
        diagnostic_reads=lambda connection, evidence: candidate_reads(connection, evidence, steps),
    )


def main():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import report_application_read as base

    return base.main(
        expected_purpose=PURPOSE,
        before_native=before_native,
        application_reader=application_reads,
        administrative_reader=administrative_reads,
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
                    detail="Retain original claim and all completed diagnostics; no replay.",
                )
            )
            + "\n"
        )
        result = 1
    raise SystemExit(result)
