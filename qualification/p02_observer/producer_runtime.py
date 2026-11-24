"""Actual report, immutable capture and next-consumer roles for fresh lab work."""

from contextlib import contextmanager, nullcontext
from datetime import UTC, datetime
import json
import os
from pathlib import Path
import time


def role_file(packet, role, index, suffix):
    if role not in {"producer", "reader", "consumer"} or index not in (1, 2):
        raise ValueError("Exact qualification role required")
    return packet / f"{role}-{index}.{suffix}.json"


def wait_signal(packet, manifest, role, index, *, clock=time.monotonic, wait=time.sleep):
    start = clock()
    expected = dict(pid=os.getpid(), role=role, index=index, packet=manifest["guest_directory"])
    while True:
        abort = role_file(packet, role, index, "abort")
        if abort.exists():
            if json.loads(abort.read_bytes()) != expected:
                raise ValueError("Abort signal has another owner")
            raise ValueError("Original role stopped before business dispatch")
        signal = role_file(packet, role, index, "go")
        if signal.exists():
            if json.loads(signal.read_bytes()) != expected:
                raise ValueError("Start signal has another owner")
            return
        if clock() - start >= 90:
            raise TimeoutError("Original admitted role retained without a start signal")
        wait(0.02)


@contextmanager
def application_credentials(manifest):
    from independent_readers import sha
    import three_contracts as control

    try:
        spec = manifest["credential"]
        if spec["path"] != control.CREDENTIAL_PATH:
            raise ValueError("Exact existing guest-only credential required")
        raw = Path(spec["path"]).read_bytes()
        if sha(raw) != spec["sha256"]:
            raise ValueError("Original guest credential changed")
        value = control.unprotect(raw)
        os.environ.update(S11_SQL_USERNAME=control.PRINCIPAL, S11_SQL_PASSWORD=value)
        value = None
        yield
    finally:
        value = None
        os.environ.pop("S11_SQL_PASSWORD", None)


class Connections:
    """Return actual raw driver handles; do not proxy physical identity."""

    def __init__(self):
        self.items = []

    def __call__(self):
        from kvk.dal.new_source_admin_dal import configured_connection

        connection = configured_connection(sql_profile="application")
        self.items.append(connection)
        return connection

    def finish(self):
        from core.export_sql_connection import setup_custody_snapshot
        from core.sql_connection_custody import connection_retained, custody_snapshot
        import pyodbc

        rows = []
        for connection in self.items:
            row = {"closed_by_caller": False, "cleanup_close": False}
            if connection_retained(connection):
                row["retained_by_original_owner"] = True
                rows.append(row)
                continue
            try:
                cursor = connection.cursor()
            except pyodbc.ProgrammingError as error:
                if str(error) == "Attempt to use a closed connection.":
                    row["closed_by_caller"] = True
                else:
                    row["close_probe_error"] = type(error).__name__
            except BaseException as error:
                row["close_probe_error"] = type(error).__name__
            else:
                try:
                    cursor.close()
                    connection.close()
                    row["cleanup_close"] = True
                except BaseException as error:
                    row["cleanup_error"] = type(error).__name__
            rows.append(row)
        setup, custody = setup_custody_snapshot(), custody_snapshot()
        return dict(
            connections=rows,
            setup=setup,
            custody=custody,
            safe_to_exit=all(r["closed_by_caller"] or r["cleanup_close"] for r in rows)
            and setup["admission"] == "open"
            and custody["admission"] == "open",
            all_closed_by_callers=all(r["closed_by_caller"] for r in rows),
        )


def build_runtime(packet, manifest, prior, connect):
    from core.export_startup_windows import administrative_path
    from producer_fixture import capture_configuration
    from services.export_coordination_dal import ExportCoordinationDAL
    from services.export_snapshot_store import ExportSnapshotStore
    from services.legacy_export_snapshot_dal import LegacySnapshotDAL
    from services.legacy_export_snapshot_service import LegacyExportRuntime
    from services.observer_release_issuance import bind_observer_candidate

    candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
    # Installation identity is a release expectation. Each writer still performs
    # its own fresh complete admission and actual-connection boundary checks.
    bound = bind_observer_candidate(
        manifest["release"], candidate, prior["configured_reader"]["native_application_receipt"]
    )
    spool = administrative_path(Path(manifest["private_directory"]) / "spool", private=True)
    dal = LegacySnapshotDAL(
        connect,
        output_operations=True,
        execution_evidence=True,
        legacy_sql_contract=bound["legacy_sql_contract"],
        application_sql_contract=bound["application_sql_contract"],
        sql_profile="application",
    )
    coordinator = ExportCoordinationDAL(
        connect, preparations=True, output_operations=True, execution_evidence=True
    )
    return LegacyExportRuntime(
        dal=dal,
        coordinator=coordinator,
        store=ExportSnapshotStore(spool, manifest["storage_owner"]),
        account=manifest["account"],
        configuration=capture_configuration(packet, manifest),
    )


def producer(packet, manifest, prior, index, record, save, connections):
    from independent_readers import write_new
    import player_stats_cache
    from services.legacy_export_snapshot_service import (
        producer_capture_scope,
        use_runtime,
        writer_scope,
    )
    from services.player_report_sql import player_connection
    from services.producer_recovery_intent import current_intent, player_cache_intent

    runtime = build_runtime(packet, manifest, prior, connections)

    @player_cache_intent
    def call():
        record["producer_intent"] = current_intent()
        record["stage"] = "fresh actual writer admission"
        save()
        admission_start = time.monotonic()
        with writer_scope("scan_data") as owner:
            record["preparation_id"] = owner.claim.preparation_id
            record["owner_id"] = owner.claim.owner
            record["fence"] = owner.claim.fence
            record["admission_seconds"] = time.monotonic() - admission_start
            record["fresh_observation_present"] = owner.observation is not None
            if not record["fresh_observation_present"]:
                raise ValueError("Fresh observer admission is required")
            record["stage"] = "admitted; awaiting original start signal"
            save()
            write_new(
                role_file(packet, "producer", index, "ready"),
                dict(
                    pid=os.getpid(),
                    role="producer",
                    index=index,
                    packet=manifest["guest_directory"],
                    preparation_id=owner.claim.preparation_id,
                ),
            )
            wait_signal(packet, manifest, "producer", index)
            record["stage"] = "actual report caller entered"
            record["business_dispatch_attempted"] = True
            save()
            started = time.monotonic()
            with player_connection(operation="p02_fresh_report_qualification") as connection:
                # Existing decorator, fresh actual connection authorization, real
                # procedure, atomic completion checkpoint and original cleanup.
                player_stats_cache._execute_sp_with_retries(connection, retries=1)
            record["report_seconds"] = time.monotonic() - started
            record["producer_authorized"] = owner.producer_authorized
            record["commit_checkpoint"] = owner.completion
            if (
                not owner.producer_authorized
                or owner.completion is None
                or owner.completion["producer"]
                != {"procedure": "dbo.SP_Stats_for_Upload", "atomic_checkpoint": 1}
            ):
                raise ValueError("Actual atomic report completion is unconfirmed")
            record["stage"] = "actual caller committed; completing original capture"
            save()
        record["writer_closed"] = owner.closed
        record["stage"] = "verifying immutable captured generation"
        row, receipt, metadata = runtime.verified_snapshot(owner.claim.preparation_id)
        if row["State"] != "captured":
            raise ValueError("Actual producer did not leave a captured generation")
        record["snapshot"] = dict(
            key=receipt.key,
            byte_count=receipt.byte_count,
            sha256=receipt.sha256,
            storage_owner=receipt.storage_owner,
        )
        record["captured_generation"] = metadata["generation"]
        record["captured_output_sections"] = len(metadata["config"]["outputs"])
        record["preparation_state"] = row["State"]
        record["outcome"] = "passed"
        record["stage"] = "real report and immutable capture verified"

    with use_runtime(runtime), producer_capture_scope():
        call()


def reader(packet, manifest, index, record, save, connections):
    from independent_readers import encode, sha, write_new
    import three_contracts as control

    candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
    owner = None
    if manifest.get("prepared_reader") is True:
        from prepared_reader import PreparedConnections

        if manifest.get("purpose") != "fresh-db18-producer-first-overlap" or index != 2:
            raise ValueError("Exact remaining producer-first case required")
        owner = PreparedConnections(connections)
    started = time.monotonic()
    try:
        with owner if owner is not None else nullcontext():
            if owner is not None:
                owner.prepare()
                record["prepared_connection_seconds"] = time.monotonic() - started
                record["prepared_connections"] = len(owner.connections)
                record["original_deadline"] = owner.deadline
            write_new(
                role_file(packet, "reader", index, "ready"),
                dict(
                    pid=os.getpid(), role="reader", index=index, packet=manifest["guest_directory"]
                ),
            )
            record["stage"] = "reader ready; awaiting original start signal"
            save()
            wait_signal(packet, manifest, "reader", index)
            record["stage"] = "complete independent three-contract read"
            save()
            actual = control.run_contracts(
                connections,
                candidate,
                manifest["release"],
                record,
                **({"owner": owner} if owner is not None else {}),
            )
            if owner is not None and owner.pending:
                raise ValueError("Complete reader did not consume its expected connections")
    finally:
        if owner is not None:
            record["prepared_reader_elapsed_seconds"] = time.monotonic() - started
            record["prepared_reader_evidence"] = owner.evidence()
    record["application_value_sha256"] = sha(encode(actual["application"]))
    record["fixed_value_sha256"] = sha(encode(actual["installation"]))
    if (
        record["application_value_sha256"] != manifest["retained_application_value_sha256"]
        or record["fixed_value_sha256"] != manifest["retained_fixed_value_sha256"]
    ):
        raise ValueError("Complete retained contract rows changed")
    raw_path = packet / f"reader-{index}.complete-observation.json"
    write_new(raw_path, actual)
    record["observation_file_sha256"] = sha(raw_path.read_bytes())
    rows = record["application_reader"]["statements"]
    record["maximum_batch_seconds"] = max(r["execute_seconds"] + r["fetch_seconds"] for r in rows)
    record["outcome"] = "passed"
    record["stage"] = "complete independent comparator passed"


def consumer(packet, manifest, prior, record, connections):
    from independent_readers import sha

    runtime = build_runtime(packet, manifest, prior, connections)
    values = []
    indices = tuple(manifest.get("capture_indices", (1, 2)))
    if indices not in ((1, 2), (2,)):
        raise ValueError("Exact completed capture set required")
    for index in indices:
        original = json.loads((packet / f"stage-{2 if index == 1 else 5}.json").read_bytes())
        if original["outcome"] != "passed" or not original["writer_closed"]:
            raise ValueError("Both original committed captures must be settled")
        row, receipt, metadata = runtime.verified_snapshot(original["preparation_id"])
        actual = dict(
            key=receipt.key,
            byte_count=receipt.byte_count,
            sha256=receipt.sha256,
            storage_owner=receipt.storage_owner,
        )
        if (
            actual != original["snapshot"]
            or metadata["generation"] != original["captured_generation"]
        ):
            raise ValueError("Original immutable capture changed after the next writer")
        if sha(runtime.store.read(receipt)) != receipt.sha256:
            raise ValueError("Original capture readback hash differs")
        values.append(
            dict(
                preparation_id=str(row["PreparationID"]).lower(),
                state=row["State"],
                snapshot=actual,
            )
        )
    latest = runtime.resolve_preparation(consumer="scan_data")
    if latest != values[-1]["preparation_id"] or len({v["preparation_id"] for v in values}) != len(
        values
    ):
        raise ValueError("Next consumer selected the wrong retained generation")
    record.update(
        outcome="passed",
        stage="declared retained captures read; latest consumer selected",
        captures=values,
        latest_preparation_id=latest,
        provider_operations=0,
        export_jobs_created=0,
    )


def run_role(packet, manifest, prior, role, index):
    from configured_reader import refusal_facts
    from independent_readers import write_new
    from scripts.verify_k98_running_release import sql_error_facts

    stage = {"producer": {1: 2, 2: 5}, "reader": {1: 3, 2: 6}, "consumer": {1: 8}}[role][index]
    record = dict(
        outcome="running",
        role=role,
        index=index,
        pid=os.getpid(),
        started=datetime.now(UTC).isoformat(),
        stage="role entry",
        first_failure=None,
        cleanup_failures=[],
        business_dispatch_attempted=False,
    )
    connections = Connections()

    def save():
        tmp = role_file(packet, role, index, "pending")
        tmp.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        tmp.replace(role_file(packet, role, index, "progress"))

    # A second entry cannot issue even a fresh admission or business callback.
    write_new(role_file(packet, role, index, "entered"), dict(pid=os.getpid()))
    try:
        with application_credentials(manifest):
            if role == "producer":
                producer(packet, manifest, prior, index, record, save, connections)
            elif role == "reader":
                reader(packet, manifest, index, record, save, connections)
            else:
                consumer(packet, manifest, prior, record, connections)
    except BaseException as error:
        record["outcome"] = "failed"
        record["first_failure"] = dict(stage=record["stage"], **sql_error_facts(error))
        record["failure_chain"] = refusal_facts(error)
        if role == "producer":
            from report_errors import report_error_facts

            record["report_failure"] = report_error_facts(error)
    finally:
        try:
            record["physical_cleanup"] = connections.finish()
        except BaseException as error:
            record["physical_cleanup"] = dict(
                all_closed_by_callers=False,
                safe_to_exit=False,
                error_type=type(error).__name__,
            )
        if (
            not record["physical_cleanup"]["all_closed_by_callers"]
            or not record["physical_cleanup"]["safe_to_exit"]
        ):
            record["outcome"] = "failed"
            record["cleanup_failures"].append(
                "Original caller did not confirm every connection close"
            )
        record["credential_environment_cleared"] = "S11_SQL_PASSWORD" not in os.environ
        record["finished"] = datetime.now(UTC).isoformat()
        try:
            write_new(packet / f"stage-{stage}.json", record)
        finally:
            if not record["physical_cleanup"]["safe_to_exit"]:
                # Retain original handles even if the receipt cannot be written.
                # Never retry uncertain cleanup or release durable ownership by age.
                while True:
                    time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1
