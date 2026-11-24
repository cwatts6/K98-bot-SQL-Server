"""Continue only application diagnostic reads using the qualified SQL profile."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys
import time

DIAGNOSTIC_DIRECTORY = r"Q:\P02Observer\20261121120042532"
DIAGNOSTIC_SHA = "4815a51572da38d7448d23e81d0b4225d0d7fa8cbd54249630a6eaaf0895355e"
CONTEXT_ATTEMPT_DIRECTORY = "Q:/P02Observer/20261121121927619"
CONTEXT_ATTEMPT_SHA = "b0f48d919027ba6244823a3f5fee48c379ef887520cd75a4ad8a9b2b4630bfa7"
TRANSACTION_SQL = "SELECT @@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state"
_HELD = []


def require_diagnostic(value, original):
    app = value.get("application", {})
    comparison = value.get("business_comparison", {})
    if (
        value.get("outcome") != "failed"
        or value.get("connections_closed") != 2
        or value.get("cleanup_failures")
        or value.get("before") != original["after"]
        or value.get("master_before") != original["master_after"]
        or value.get("first_failure")
        != dict(
            stage="inspect report dependency identity and effective application permissions",
            error_type="ValueError",
        )
        or app.get("first_failure") != {"error_type": "ValueError"}
        or app.get("reads") != {}
        or app.get("cleanup_failures")
        or app.get("connection_closed") is not True
        or app.get("reverted") is not True
        or set(comparison)
        != {"STATS_FOR_UPLOAD", "MaintenanceWork", "KVKFinalReportHeader", "EXCEL_FOR_KVK_16"}
        or any(
            not row.get("unchanged") or row["live"] != row["snapshot"]
            for row in comparison.values()
        )
        or len(value.get("admin_candidate_compilation", [])) != 62
        or any(row["error_number"] is not None for row in value["admin_candidate_compilation"])
    ):
        raise ValueError("Exact settled diagnostic refusal and completed reads required")


def require_context_attempt(value, original, diagnostic):
    app = value.get("application", {})
    expected_context = [
        dict(
            database_id=16,
            database_name="ROK_TRACKER",
            execution_login="S11_ExportApplication",
            transaction_count=0,
            transaction_state=1,
        )
    ]
    if (
        value.get("outcome") != "failed"
        or value.get("first_failure")
        != dict(stage="actual application diagnostic reads", error_type="ValueError")
        or value.get("connections_closed") != 2
        or value.get("cleanup_failures")
        or value.get("login_disabled") is not True
        or value.get("physical_custody_retained") is not False
        or value.get("before") != original["after"]
        or value.get("after") != original["after"]
        or value.get("master_before") != original["master_after"]
        or value.get("master_after") != original["master_after"]
        or value.get("ownership_before") != diagnostic["ownership_before"]
        or value.get("ownership_after") != diagnostic["ownership_before"]
        or value.get("live_business_hashes")
        != {name: item["live"] for name, item in diagnostic["business_comparison"].items()}
        or any(
            value.get(name) != 0
            for name in (
                "business_operations",
                "claim_releases",
                "setup_replays",
                "migrations",
                "restores",
            )
        )
        or value.get("setup_custody") != dict(admission="open", pending=0, unconfirmed=0)
        or value.get("connection_custody") != dict(admission="open", unconfirmed=0)
        or app.get("observed_context") != expected_context
        or app.get("refusal_kind") != "actual_application_context_mismatch"
        or app.get("first_failure") != dict(error_type="ValueError")
        or app.get("reads") != {}
        or app.get("cleanup_failures")
        or app.get("connection_closed") is not True
        or app.get("credential_environment_cleared") is not True
    ):
        raise ValueError("Exact settled actual-application context refusal required")


def application_reads(manifest, projection, record, retained, *, diagnostic_reads=None):
    from independent_readers import query
    from producer_runtime import application_credentials
    from report_failure_read import CONTEXT_SQL, DESCRIBE_SQL, PERMISSIONS_SQL

    from core.export_sql_connection import setup_custody_snapshot
    from core.sql_connection_custody import custody_snapshot, preserve_failure
    from kvk.dal.new_source_admin_dal import configured_connection
    from scripts.verify_k98_running_release import sql_error_facts

    connection = None
    failure = None
    record.update(
        authentication="actual configured application SQL profile",
        connection_closed=False,
        reads={},
        transaction_boundaries={},
        cleanup_failures=[],
        first_failure=None,
    )
    try:
        with application_credentials(manifest):
            try:
                connection = configured_connection(sql_profile="application")
                # This fresh connection performs diagnostic SELECTs only.
                connection.autocommit = True

                def require_idle(phase):
                    # Separate statement boundary from metadata-function evaluation.
                    rows = query(connection, TRANSACTION_SQL)
                    record["transaction_boundaries"][phase] = rows
                    if rows != [dict(transaction_count=0, transaction_state=0)]:
                        record["refusal_kind"] = "nonidle_" + phase
                        raise ValueError("Idle application diagnostic boundary required")

                require_idle("before_identity")
                context = query(connection, CONTEXT_SQL)
                record["observed_context"] = context
                expected = [
                    dict(
                        database_id=16,
                        database_name="ROK_TRACKER",
                        execution_login="S11_ExportApplication",
                        transaction_count=0,
                    )
                ]
                identity = [
                    {k: v for k, v in row.items() if k != "transaction_state"} for row in context
                ]
                if identity != expected or context[0].get("transaction_state") not in (0, 1):
                    record["refusal_kind"] = "actual_application_context_mismatch"
                    raise ValueError("Exact actual application context required")
                require_idle("after_identity")
                if diagnostic_reads is None:
                    for name, statement, parameters in (
                        ("effective_permissions", PERMISSIONS_SQL, ()),
                        ("candidate_select_compilation", DESCRIBE_SQL, (projection,)),
                    ):
                        try:
                            record["reads"][name] = dict(
                                outcome="read", rows=query(connection, statement, *parameters)
                            )
                        except Exception as error:
                            record["reads"][name] = dict(
                                outcome="query_refused", **sql_error_facts(error)
                            )
                else:
                    diagnostic_reads(connection, record)
                require_idle("after_diagnostics")
            except BaseException as error:
                failure = error
                record["first_failure"] = sql_error_facts(error)
            finally:
                if connection is not None:
                    try:
                        connection.close()
                        record["connection_closed"] = True
                    except BaseException as error:
                        retained.append(connection)
                        failure = preserve_failure(failure, error, "application_diagnostic_close")
                        record["cleanup_failures"].append(sql_error_facts(error))
    finally:
        record["credential_environment_cleared"] = "S11_SQL_PASSWORD" not in os.environ
        record["setup_custody"] = setup_custody_snapshot()
        record["connection_custody"] = custody_snapshot()
    if failure is not None:
        raise failure
    if (
        record["setup_custody"]["admission"] != "open"
        or record["connection_custody"]["admission"] != "open"
    ):
        raise ValueError("Original SQL setup or connection custody remains retained")


def admin_connection():
    import pyodbc

    connection = pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;Trusted_Connection=yes;APP=P02ReportDiagnosticContinue;",
        autocommit=True,
        timeout=3,
    )
    try:
        connection.timeout = 3
    except BaseException as original:
        try:
            connection.close()
        except BaseException as cleanup:
            _HELD.append(connection)
            original.add_note("Administrative setup close unconfirmed: " + type(cleanup).__name__)
        raise
    return connection


def run(
    packet, manifest, original, diagnostic, *, application_reader=None, administrative_reader=None
):
    import fixed_contract_cost as cost
    from independent_readers import query, state, write_new
    from producer_fixture import FRESH_ACCOUNT, ORIGINAL_PREPARATIONS, RESOURCE_SQL
    import report_failure_read as old
    import three_contracts as control

    from core.export_sql_connection import setup_custody_snapshot
    from core.sql_connection_custody import custody_snapshot
    from scripts.verify_k98_running_release import sql_error_facts

    record = dict(
        outcome="running",
        stage="verify retained identity and claim",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        connections_closed=0,
        enable_attempted=False,
        login_disabled=None,
        business_operations=0,
        claim_releases=0,
        setup_replays=0,
        migrations=0,
        restores=0,
        completed_read_receipt_sha256=DIAGNOSTIC_SHA,
        completed_reads_reused=True,
        retained_context_refusal_sha256=CONTEXT_ATTEMPT_SHA,
    )
    connection = None

    def save():
        pending = packet / "progress.pending"
        pending.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        pending.replace(packet / "progress.json")

    def ownership():
        return dict(
            preparations=query(connection, FRESH_ACCOUNT, old.ACCOUNT),
            resources=query(connection, RESOURCE_SQL, "account:" + old.ACCOUNT),
            original_preparations=query(
                connection, ORIGINAL_PREPARATIONS, old.ACCOUNT, old.ACCOUNT
            ),
        )

    try:
        connection = admin_connection()
        record["before"], record["master_before"] = state(connection, original)
        record["login_disabled"] = True
        record["ownership_before"] = ownership()
        if record["ownership_before"] != diagnostic["ownership_before"]:
            raise ValueError("Original retained claim changed")
        record["snapshot"] = query(connection, old.SNAPSHOT_SQL)
        if record["snapshot"] != diagnostic["snapshot"]:
            raise ValueError("Original recovery snapshot changed")
        agent = [
            r
            for r in query(connection, cost.SERVICES_SQL)
            if r["servicename"] == "SQL Server Agent (MSSQLSERVER)"
        ]
        if (
            len(agent) != 1
            or agent[0]["status_desc"] != "Stopped"
            or agent[0]["startup_type_desc"] != "Disabled"
        ):
            raise ValueError("Retained stopped/disabled lab Agent required")
        record["live_business_hashes"] = {
            table: query(connection, old.digest_sql("ROK_TRACKER", table)) for table in old.OBJECTS
        }
        if any(
            record["live_business_hashes"][table]
            != diagnostic["business_comparison"][table]["live"]
            for table in old.OBJECTS
        ):
            raise ValueError("Accepted snapshot comparison no longer describes current data")
        write_new(
            packet / "stage-1.json",
            {k: record[k] for k in ("ownership_before", "snapshot", "live_business_hashes")},
        )
        if administrative_reader is not None:
            record["additional_admin_reads"] = {}
            administrative_reader(connection, record["additional_admin_reads"])
        record["stage"] = "actual application diagnostic reads"
        record["enable_attempted"] = True
        record["login_disabled"] = None
        save()
        query(connection, control.ENABLE)
        record["login_disabled"] = False
        record["application"] = {}
        (application_reader or application_reads)(
            manifest,
            (packet / "candidate-projection.sql").read_text(encoding="utf-8-sig"),
            record["application"],
            _HELD,
        )
        write_new(packet / "stage-2.json", record["application"])
        record["outcome"] = "passed"
        record["stage"] = "actual application diagnostics collected; original claim preserved"
    except BaseException as error:
        record["outcome"] = "failed"
        record["first_failure"] = dict(stage=record["stage"], **sql_error_facts(error))
    finally:
        if connection is not None:
            if record["enable_attempted"]:
                try:
                    query(connection, control.DISABLE)
                    record["login_disabled"] = True
                except BaseException as error:
                    record["cleanup_failures"].append(
                        dict(operation="disable application login", **sql_error_facts(error))
                    )
            if record["login_disabled"] and "before" in record:
                try:
                    record["ownership_after"] = ownership()
                    if record["ownership_after"] != diagnostic["ownership_before"]:
                        raise ValueError("Retained ownership changed during diagnosis")
                    record["after"], record["master_after"] = state(connection, original)
                    if "live_business_hashes" in record:
                        record["business_hashes_after"] = {
                            table: query(connection, old.digest_sql("ROK_TRACKER", table))
                            for table in old.OBJECTS
                        }
                        if record["business_hashes_after"] != record["live_business_hashes"]:
                            raise ValueError("Persistent business rows changed during diagnosis")
                except BaseException as error:
                    record["cleanup_failures"].append(
                        dict(operation="final identity and claim", **sql_error_facts(error))
                    )
            try:
                connection.close()
                record["connections_closed"] += 1
            except BaseException as error:
                _HELD.append(connection)
                record["cleanup_failures"].append(
                    dict(operation="administrative close", **sql_error_facts(error))
                )
        if record.get("application", {}).get("connection_closed"):
            record["connections_closed"] += 1
        record["setup_custody"] = setup_custody_snapshot()
        record["connection_custody"] = custody_snapshot()
        retained = (
            bool(_HELD)
            or record["setup_custody"]["admission"] != "open"
            or record["connection_custody"]["admission"] != "open"
        )
        record["physical_custody_retained"] = retained
        if record["cleanup_failures"] or retained:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        try:
            write_new(packet / "receipt.json", record)
        finally:
            if retained:
                while True:
                    time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def main(
    *,
    expected_purpose="idle-boundary-application-diagnostic",
    before_native=None,
    application_reader=None,
    administrative_reader=None,
):
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["purpose"] != expected_purpose
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated diagnostic continuation required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if (
            not path.is_relative_to(packet)
            or hashlib.sha256(path.read_bytes()).hexdigest() != digest
        ):
            raise ValueError("Sealed diagnostic continuation changed")
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    import report_failure_read as old

    original = json.loads((packet / "evidence/receipt.json").read_bytes())
    stages = {}
    for name in ("receipt.json", "stage-1.json", "stage-2.json", "stage-3.json", "stage-4.json"):
        raw = (packet / "evidence" / name).read_bytes()
        if (Path(old.PRIOR_DIRECTORY) / name).read_bytes() != raw:
            raise ValueError("Original business attempt evidence changed")
        if name == "receipt.json" and hashlib.sha256(raw).hexdigest() != old.PRIOR_SHA:
            raise ValueError("Exact original business failure required")
        if name != "receipt.json":
            stages[name] = json.loads(raw)
    old.require_prior(original, stages)
    raw = (packet / "evidence/diagnostic-receipt.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != DIAGNOSTIC_SHA
        or (Path(DIAGNOSTIC_DIRECTORY) / "receipt.json").read_bytes() != raw
    ):
        raise ValueError("Original settled diagnostic changed")
    diagnostic = json.loads(raw)
    require_diagnostic(diagnostic, original)
    raw = (packet / "evidence/context-refusal.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != CONTEXT_ATTEMPT_SHA
        or (Path(CONTEXT_ATTEMPT_DIRECTORY) / "receipt.json").read_bytes() != raw
    ):
        raise ValueError("Original actual-application refusal changed")
    require_context_attempt(json.loads(raw), original, diagnostic)
    if before_native is not None:
        before_native(packet, manifest, original, diagnostic)
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    return run(
        packet,
        manifest,
        original,
        diagnostic,
        application_reader=application_reader,
        administrative_reader=administrative_reader,
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
                    detail="Retain original claim and both failures; no replay.",
                )
            )
            + "\n"
        )
        result = 1
    raise SystemExit(result)
