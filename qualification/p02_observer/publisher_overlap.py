"""Fresh lab publications with physical transaction barriers in both orders.

The observer pauses at a consumed-query boundary. This proves transaction
interleaving and useful real publisher work, not simultaneous executing queries
or protected contract acceptance. No queued preparation/import is invoked.
"""

from contextlib import closing, contextmanager
import hashlib
import json
import time
from types import SimpleNamespace

from core.sql_connection_custody import retain_connection
from core.sql_operation_policy import DEFAULT_STATEMENT_SECONDS, METADATA_LOCK_MILLISECONDS
from services.catalogue_observation_dal import ObservationDeferred
from services.export_execution_dal import legacy_definition_hash
from services.export_schema_fingerprint import application_metadata_fingerprint
from services.legacy_snapshot_admission import acquire_snapshot_guard


def run_publisher_overlap(
    admin,
    before,
    *,
    connect,
    sql,
    read_observation,
    business_state,
    write_json,
    check,
    receipt,
    publisher_contracts,
    prior_output=None,
    initial_generation=238,
):
    if receipt.get("publisher_proof_entered"):
        raise RuntimeError("Publisher proof cannot be entered more than once.")
    receipt["publisher_proof_entered"] = True
    receipt["scope_limit"] = (
        "Two fresh KVK 16 lab publications with transaction barriers; no queued work, "
        "provider action, protected comparator acceptance or simultaneous-query cost inferred. "
        "Direct child entry uses one transaction-local EXECUTE grant, removed before commit; "
        "this does not qualify normal parent entry or independently prove root invalidation."
    )
    receipt["publisher_dispatches"] = 0
    receipt["publisher_commits"] = 0
    orders = ("actor-first", "observer-first") if prior_output is None else ("observer-first",)
    receipt["retained_publications"] = int(prior_output is not None)
    receipt["remaining_orders"] = list(orders)

    def normalized(value):
        return json.loads(json.dumps(value, default=str))

    @contextmanager
    def owned(*, producer=False):
        # The lab connection already starts as the authenticated fixture admin.
        # Only the producer needs that original context for the temporary grant;
        # the entire business body still runs under the existing application login.
        connection = connect(application=not producer)
        failure = None
        try:
            if producer:
                connection.timeout = DEFAULT_STATEMENT_SECONDS
                assert METADATA_LOCK_MILLISECONDS == 1000
                sql(connection, "SET LOCK_TIMEOUT 1000; SET XACT_ABORT ON")
                sql(connection, "EXECUTE AS LOGIN='S11_ExportApplication_P02Qual'")
                assert sql(
                    connection,
                    "SELECT SUSER_SNAME() AS LoginName,IS_SRVROLEMEMBER('sysadmin') AS Sysadmin,"
                    "HAS_PERMS_BY_NAME('dbo.sp_ExcelOutput_ByKVK','OBJECT','EXECUTE') AS DirectExecute",
                ) == [dict(LoginName="S11_ExportApplication_P02Qual", Sysadmin=0, DirectExecute=0)]
            yield connection
        except BaseException as error:
            failure = error
            raise
        finally:
            try:
                connection.timeout = 3
                if producer:
                    result = sql(
                        connection,
                        "IF @@TRANCOUNT>0 ROLLBACK TRANSACTION; "
                        "IF APPLOCK_MODE('public','k98-legacy-output-snapshot','Session')='Exclusive' "
                        "EXEC sys.sp_releaseapplock @Resource=N'k98-legacy-output-snapshot',@LockOwner='Session'; "
                        "SELECT @@TRANCOUNT AS Transactions,XACT_STATE() AS XactState,"
                        "APPLOCK_MODE('public','k98-legacy-output-snapshot','Session') AS SnapshotMode,"
                        "APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session') AS MarkerMode",
                    )
                    assert result == [
                        dict(
                            Transactions=0, XactState=0, SnapshotMode="NoLock", MarkerMode="NoLock"
                        )
                    ]
                connection.close()
            except BaseException as cleanup:
                receipt["publisher_cleanup_unknown"] = True
                retain_connection(
                    SimpleNamespace(connection=connection, cursor=None),
                    effect="uncertain",
                    first_failure=failure or cleanup,
                    cleanup_error=cleanup,
                )
                if failure is not None:
                    failure.add_note("Publisher proof cleanup not acknowledged: " + str(cleanup))
                else:
                    raise

    def preflight():
        for name, contract in publisher_contracts.items():
            rows = sql(
                admin,
                "SELECT definition,uses_ansi_nulls,uses_quoted_identifier,execute_as_principal_id "
                "FROM sys.sql_modules WHERE object_id=OBJECT_ID(?)",
                name,
            )
            assert len(rows) == 1
            actual = rows[0]
            assert (
                legacy_definition_hash(actual["definition"]) in contract["definition_hashes"]
            ), name
            assert actual["uses_ansi_nulls"] and actual["uses_quoted_identifier"]
            assert actual["execute_as_principal_id"] == contract["execute_as"], name
        scan = sql(admin, "SELECT MAX(ScanOrder) AS Scan FROM dbo.KingdomScanData4")[0]["Scan"]
        config = sql(admin, "SELECT ConfigKey,ConfigValue FROM dbo.ProcConfig WHERE KVKVersion=16")
        values = {row["ConfigKey"]: row["ConfigValue"] for row in config}
        assert type(scan) is int and scan > 0
        assert len(values) == len(config)
        final_scan = min(scan, int(values["KVK_END_SCAN"]))
        count = sql(
            admin, "SELECT COUNT_BIG(*) AS [Rows] FROM dbo.KingdomScanData4 WHERE ScanOrder=?", scan
        )[0]["Rows"]
        assert count > 0 and final_scan > 0
        facts = dict(
            scan=scan,
            final_scan=final_scan,
            source_rows=count,
            configuration=config,
            source_pinned_children=sorted(publisher_contracts),
            queued_work_replayed=False,
        )
        write_json("publisher-before.json", dict(facts=facts, business_state=before))
        return facts

    selected = []
    check(
        "publisher-source-and-fresh-input-preflight",
        lambda: (selected.append(preflight()) or selected[0]),
    )
    inputs = selected[0]
    previous = before
    first_output = None if prior_output is None else prior_output["rows"]
    if prior_output is not None:
        assert prior_output["state"] == normalized(before)
        assert len(first_output) == inputs["source_rows"]

    for order in orders:

        def case():
            nonlocal previous, first_output
            started = time.perf_counter()
            held = []
            attempt_timings = []
            body_started = []
            with owned(producer=True) as producer:

                def publish_to_barrier():
                    assert not held and not body_started
                    body_started.append(time.perf_counter())
                    with closing(producer.cursor()) as cursor:
                        acquire_snapshot_guard(cursor)
                        while cursor.nextset():
                            if cursor.description:
                                raise AssertionError("Unexpected admission result")
                    # Parent ownership chaining normally supplies child entry.
                    # This isolated child test admits only that entry permission.
                    # Grant and revoke are in the SAME physical transaction as
                    # publication; rollback cannot leave an added permission.
                    sql(
                        producer,
                        "REVERT; BEGIN TRANSACTION; "
                        "GRANT EXECUTE ON OBJECT::dbo.sp_ExcelOutput_ByKVK TO S11_ExportApplication_P02Qual; "
                        "EXECUTE AS LOGIN='S11_ExportApplication_P02Qual'; "
                        "IF ISNULL(SUSER_SNAME(),'')<>'S11_ExportApplication_P02Qual' OR ISNULL(IS_SRVROLEMEMBER('sysadmin'),-1)<>0 "
                        "OR ISNULL(HAS_PERMS_BY_NAME('dbo.sp_ExcelOutput_ByKVK','OBJECT','EXECUTE'),-1)<>1 "
                        "THROW 51974,'Lab publisher application entry was not established.',1;",
                    )
                    assert receipt["publisher_dispatches"] < len(orders)
                    receipt["publisher_dispatches"] += 1
                    receipt["business_operations"] += 1
                    sql(
                        producer, "EXEC dbo.sp_ExcelOutput_ByKVK @KVK=?,@Scan=?", 16, inputs["scan"]
                    )
                    state = sql(
                        producer,
                        "SELECT @@SPID AS SessionID,@@TRANCOUNT AS Transactions,XACT_STATE() AS XactState,"
                        "APPLOCK_MODE('public','k98-legacy-output-snapshot','Session') AS SnapshotMode,"
                        "APPLOCK_MODE('public','K98:maintenance-schema:v1','Transaction') AS MaintenanceMode,"
                        "APPLOCK_MODE('public','K98:catalogue-mutation:v1','Transaction') AS MarkerMode",
                    )[0]
                    assert state["Transactions"] == state["XactState"] == 1
                    assert state["SnapshotMode"] == "Exclusive"
                    assert state["MaintenanceMode"] == state["MarkerMode"] == "Shared"
                    held.append(dict(**state, body_seconds=time.perf_counter() - body_started[0]))

                with owned() as observer:
                    observer_session = sql(observer, "SELECT @@SPID AS SessionID")[0]["SessionID"]
                    if order == "actor-first":
                        publish_to_barrier()
                    try:
                        read_observation(
                            observer,
                            publish_to_barrier if order == "observer-first" else None,
                            timings=attempt_timings,
                            observation_batches=True,
                            hook_before_checkpoint=True,
                        )
                    except ObservationDeferred as error:
                        assert error.reason == "active_writer"
                    else:
                        raise AssertionError("Active real publication was certified")
                    assert len(held) == 1 and held[0]["SessionID"] != observer_session
                    assert sum(not r["boundary"] for r in attempt_timings) == (
                        0 if order == "actor-first" else 1
                    )
                # The deferred observer is physically closed before commit/continuation.
                commit_started = time.perf_counter()
                sql(
                    producer,
                    "REVERT; REVOKE EXECUTE ON OBJECT::dbo.sp_ExcelOutput_ByKVK FROM S11_ExportApplication_P02Qual; "
                    "EXECUTE AS LOGIN='S11_ExportApplication_P02Qual'; "
                    "IF ISNULL(HAS_PERMS_BY_NAME('dbo.sp_ExcelOutput_ByKVK','OBJECT','EXECUTE'),-1)<>0 "
                    "THROW 51974,'Temporary lab publisher entry permission remains; commit refused.',1; "
                    "COMMIT TRANSACTION;",
                )
                receipt["publisher_commits"] += 1
                commit_seconds = time.perf_counter() - commit_started
                assert sql(
                    producer, "SELECT @@TRANCOUNT AS Transactions,XACT_STATE() AS XactState"
                ) == [dict(Transactions=0, XactState=0)]
            # Record the committed outcome before any post-state/cost assertion.
            write_json(
                "publisher-" + order + "-commit.json",
                dict(
                    order=order,
                    committed=True,
                    held=held[0],
                    observer_session=observer_session,
                    deferred_attempt=attempt_timings,
                    commit_seconds=commit_seconds,
                    publisher_cleanup="acknowledged",
                    observer_cleanup="acknowledged",
                    temporary_child_entry="transaction-local grant removed before commit",
                ),
            )
            after = normalized(business_state(admin))
            output = normalized(sql(admin, "SELECT * FROM dbo.EXCEL_FOR_KVK_16 ORDER BY Gov_ID"))
            identity = normalized(
                sql(
                    admin,
                    "SELECT object_id,CONVERT(nvarchar(30),create_date,126) AS ObjectCreated "
                    "FROM sys.tables WHERE object_id=OBJECT_ID(N'dbo.EXCEL_FOR_KVK_16','U')",
                )
            )
            write_json(
                "publisher-" + order + "-output.json",
                dict(state=after, identity=identity, rows=output),
            )
            assert after["preparations"] == previous["preparations"]
            assert after["imports"] == previous["imports"]
            old_header = next(r for r in previous["headers"] if r["KVK_NO"] == 16)
            header = next(r for r in after["headers"] if r["KVK_NO"] == 16)
            old_due = next(r for r in previous["maintenance"] if r["Kind"] == "kvk_output")
            due = next(r for r in after["maintenance"] if r["Kind"] == "kvk_output")
            old_work = next(r for r in previous["kvk_work"] if r["KVKNo"] == 16)
            work = next(r for r in after["kvk_work"] if r["KVKNo"] == 16)
            assert header["Revision"] == old_header["Revision"] + 1
            assert (
                header["State"] == "OUTPUT_COMPLETE"
                and header["FinalizationBasis"] == "LIVE_OUTPUT"
            )
            assert header["FinalScanOrder"] == inputs["final_scan"]
            assert header["OutputRowCount"] == len(output) == inputs["source_rows"]
            assert len({r["Gov_ID"] for r in output}) == len(output)
            assert all(r["KVK_NO"] == 16 for r in output)
            assert due["DueGeneration"] == old_due["DueGeneration"] + 1
            assert due["CompletedGeneration"] == old_due["CompletedGeneration"]
            assert work["DueGeneration"] == due["DueGeneration"]
            assert work["CompletedGeneration"] == old_work["CompletedGeneration"]
            assert work["State"] == due["State"] == "pending"
            assert len(identity) == 1 and work["DueObjectID"] == identity[0]["object_id"]
            assert work["DueHeaderRevision"] == header["Revision"]
            work_changes = {
                "DueGeneration",
                "DueObjectID",
                "DueObjectCreateDate",
                "DueHeaderRevision",
                "State",
            }
            assert {k: v for k, v in work.items() if k not in work_changes} == {
                k: v for k, v in old_work.items() if k not in work_changes
            }
            due_changes = {"DueGeneration", "DueUTC", "LastRequestID", "State"}
            assert {k: v for k, v in due.items() if k not in due_changes} == {
                k: v for k, v in old_due.items() if k not in due_changes
            }
            assert [r for r in after["headers"] if r["KVK_NO"] != 16] == [
                r for r in previous["headers"] if r["KVK_NO"] != 16
            ]
            assert [r for r in after["maintenance"] if r["Kind"] != "kvk_output"] == [
                r for r in previous["maintenance"] if r["Kind"] != "kvk_output"
            ]
            assert [r for r in after["kvk_work"] if r["KVKNo"] != 16] == [
                r for r in previous["kvk_work"] if r["KVKNo"] != 16
            ]
            if first_output is None:
                first_output = output
            else:
                assert output == first_output
            timings = []
            observation_started = time.perf_counter()
            with owned() as fresh:
                observed = read_observation(fresh, timings=timings, observation_batches=True)
            observation_seconds = time.perf_counter() - observation_started
            write_json(
                "publisher-" + order + "-observation.json",
                dict(boundary=observed.boundary.__dict__, value=observed.value, timings=timings),
            )
            assert observed.boundary.generation > initial_generation
            lifecycle = observed.value["maintenance_lifecycle"]["outputs"]
            assert len(lifecycle) == 1
            current = lifecycle[0]
            assert current["ObjectID"] == current["DueObjectID"] == work["DueObjectID"]
            assert (
                current["ObjectCreated"]
                == current["DueObjectCreated"]
                == identity[0]["ObjectCreated"]
            )
            assert current["HeaderRevision"] == current["DueHeaderRevision"] == header["Revision"]
            assert current["DueGeneration"] == current["AggregateDue"] == due["DueGeneration"]
            assert (
                current["CompletedGeneration"]
                == current["AggregateCompleted"]
                == due["CompletedGeneration"]
            )
            assert current["State"] == current["AggregateState"] == "pending"
            assert sum(not r["boundary"] for r in timings) == 126
            assert sum(r["boundary"] for r in timings) == 128
            maximum = max(r["native_seconds"] for r in timings)
            facts = dict(
                order=order,
                publisher_session=held[0]["SessionID"],
                observer_session=observer_session,
                body_seconds=held[0]["body_seconds"],
                commit_seconds=commit_seconds,
                committed_once=True,
                deferred_attempts=1,
                fresh_continuations=1,
                output_rows=len(output),
                header_revision=header["Revision"],
                due_generation=due["DueGeneration"],
                observation_generation=observed.boundary.generation,
                maximum_query_seconds=maximum,
                observation_seconds=observation_seconds,
                observed_fingerprint=application_metadata_fingerprint(
                    observed.value["metadata"], observed.value["schema_identity"]
                ),
                output_sha256=hashlib.sha256(
                    json.dumps(output, sort_keys=True).encode()
                ).hexdigest(),
                total_seconds=time.perf_counter() - started,
                queued_work_unchanged=True,
                cleanup="acknowledged",
                scope="Physical transaction interleaving at a consumed-query barrier; no simultaneous-query or protected comparator acceptance.",
            )
            previous = after
            assert (
                maximum <= 0.250 and observation_seconds <= 15 and facts["total_seconds"] <= 45
            ), facts
            return facts

        try:
            check("real-publisher-" + order + "-and-fresh-observer", case)
        except BaseException as first:
            # No replay: preserve the settled state for any later continuation.
            # A retained native handle must be reconciled before more SQL.
            if not receipt.get("publisher_cleanup_unknown"):
                try:
                    write_json(
                        "publisher-failure-state.json",
                        dict(
                            business_state=business_state(admin),
                            sequence=sql(
                                admin,
                                "SELECT object_id,create_date,modify_date,CONVERT(bigint,current_value) AS current_value,"
                                "CONVERT(bigint,last_used_value) AS last_used_value "
                                "FROM sys.sequences WHERE object_id=OBJECT_ID('dbo.P02ObservationGeneration')",
                            ),
                            direct_entry_permissions=sql(
                                admin,
                                "SELECT state,permission_name FROM sys.database_permissions "
                                "WHERE class=1 AND major_id=OBJECT_ID('dbo.sp_ExcelOutput_ByKVK') "
                                "AND grantee_principal_id=USER_ID('S11_ExportApplication_P02Qual')",
                            ),
                        ),
                    )
                except BaseException as diagnostic:
                    first.add_note("Post-failure read did not complete: " + str(diagnostic))
            raise

    assert receipt["publisher_dispatches"] == receipt["publisher_commits"] == len(orders)


def finish_publisher_observation(
    admin,
    saved_output,
    *,
    connect,
    sql,
    read_observation,
    business_state,
    write_json,
    check,
    receipt,
    generation,
    expected_fingerprint,
):
    """Read only after both committed cases; never enter publication again."""
    receipt.update(
        retained_publications=2,
        publisher_dispatches=0,
        publisher_commits=0,
        scope_limit="Read-only final published-state/observer check. Both publications retained; raw rank equality remains a separate recorded finding.",
    )

    def state_check():
        current = json.loads(json.dumps(business_state(admin), default=str))
        assert current == saved_output["state"]
        rows = json.loads(
            json.dumps(
                sql(admin, "SELECT * FROM dbo.EXCEL_FOR_KVK_16 ORDER BY Gov_ID"), default=str
            )
        )
        assert rows == saved_output["rows"] and len(rows) == 415
        permissions = sql(
            admin,
            "SELECT state,permission_name FROM sys.database_permissions "
            "WHERE class=1 AND major_id=OBJECT_ID('dbo.sp_ExcelOutput_ByKVK') "
            "AND grantee_principal_id=USER_ID('S11_ExportApplication_P02Qual')",
        )
        assert permissions == []
        return dict(
            exact_saved_state=True,
            exact_saved_output=True,
            rows=415,
            temporary_entry_removed=True,
            publications_replayed=0,
        )

    check("both-publications-retained-and-exact-current-output", state_check)

    def final_read():
        timings = []
        connection = connect(application=True)
        first = None
        started = time.perf_counter()
        try:
            observed = read_observation(connection, timings=timings, observation_batches=True)
        except BaseException as error:
            first = error
            try:
                write_json(
                    "publisher-final-observation.json", dict(complete=False, timings=timings)
                )
            except BaseException as diagnostic:
                first.add_note("Failed-read timing write did not complete: " + str(diagnostic))
            raise
        finally:
            try:
                connection.close()
            except BaseException as cleanup:
                retain_connection(
                    connection, effect="none", first_failure=first or cleanup, cleanup_error=cleanup
                )
                if first is not None:
                    first.add_note("Final observer close not acknowledged: " + str(cleanup))
                else:
                    raise
        elapsed = time.perf_counter() - started
        write_json(
            "publisher-final-observation.json",
            dict(
                complete=True,
                boundary=observed.boundary.__dict__,
                value=observed.value,
                timings=timings,
                observation_seconds=elapsed,
            ),
        )
        assert observed.boundary.generation == generation
        state = saved_output["state"]
        header = next(r for r in state["headers"] if r["KVK_NO"] == 16)
        work = next(r for r in state["kvk_work"] if r["KVKNo"] == 16)
        due = next(r for r in state["maintenance"] if r["Kind"] == "kvk_output")
        outputs = observed.value["maintenance_lifecycle"]["outputs"]
        assert len(outputs) == 1
        current = outputs[0]
        assert (
            current["ObjectID"]
            == current["DueObjectID"]
            == work["DueObjectID"]
            == saved_output["identity"][0]["object_id"]
        )
        assert (
            current["ObjectCreated"]
            == current["DueObjectCreated"]
            == saved_output["identity"][0]["ObjectCreated"]
        )
        assert current["HeaderRevision"] == current["DueHeaderRevision"] == header["Revision"]
        assert (
            current["DueGeneration"]
            == current["AggregateDue"]
            == due["DueGeneration"]
            == work["DueGeneration"]
        )
        assert (
            current["CompletedGeneration"]
            == current["AggregateCompleted"]
            == due["CompletedGeneration"]
            == work["CompletedGeneration"]
        )
        assert current["State"] == current["AggregateState"] == "pending"
        fingerprint = application_metadata_fingerprint(
            observed.value["metadata"], observed.value["schema_identity"]
        )
        assert fingerprint == expected_fingerprint
        assert sum(not r["boundary"] for r in timings) == 126
        assert sum(r["boundary"] for r in timings) == 128
        facts = dict(
            generation=generation,
            header_revision=header["Revision"],
            due_generation=due["DueGeneration"],
            observation_seconds=elapsed,
            maximum_query_seconds=max(r["native_seconds"] for r in timings),
            ordinary_reads=126,
            boundaries=128,
            fingerprint=fingerprint,
            cleanup="acknowledged",
            business_dispatches=0,
        )
        assert elapsed <= 15 and facts["maximum_query_seconds"] <= 0.250, facts
        return facts

    check("final-complete-observer-and-published-state", final_read)
    assert receipt["business_operations"] == receipt["publisher_dispatches"] == 0
