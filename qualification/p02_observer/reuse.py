"""Actual borrowed-session metadata reuse; no business operation or SQL install."""

from contextlib import closing
from copy import deepcopy

from services.application_maintenance_contract import POLICY
from services.application_maintenance_dal import coherent_maintenance_snapshot
from services.catalogue_observation_dal import BOUNDARY_SQL, ObservationDeferred, read_boundary
from services.export_execution_dal import (
    application_authority_snapshot,
    application_installation_snapshot,
)
from services.export_schema_fingerprint import FORMAT, canonical_application_metadata


def run(manifest, packet, connect, sql, check, boundary, expected_sources):
    admin, origin, producer = connect(), connect(), connect()
    expected = expected_sources(manifest["protocol_sources"])
    approved = {
        "version": 3,
        "maintenance_policy": POLICY,
        "d4_installation": "20261111_001_p02_d4_combined",
        "dynamic_objects": [
            {
                "name": "dbo.EXCEL_FOR_KVK_900002",
                "type": "U",
                "producer_modules": ["dbo.sp_ExcelOutput_ByKVK"],
            }
        ],
    }
    scope = ["dbo.EXCEL_FOR_KVK_900002"]

    def preflight():
        assert manifest["reuse"]["amendments"] == []
        assert tuple(
            sql(
                admin,
                "SELECT DB_ID(),object_id,CONVERT(bigint,current_value) FROM sys.sequences WHERE object_id=OBJECT_ID('dbo.P02ObservationGeneration','SO')",
            )[0]
        ) == (13, 1557580587, 84)
        assert [
            tuple(row)
            for row in sql(
                admin,
                "SELECT KVKNo,State,CompletedGeneration FROM dbo.MaintenanceKvkWork ORDER BY KVKNo",
            )
        ] == [(900001, "complete", 1), (900002, "complete", 1)]
        assert tuple(
            sql(
                admin,
                "SELECT State,DueGeneration,CompletedGeneration FROM dbo.MaintenanceWork WHERE Kind='kvk_output'",
            )[0]
        ) == ("complete", 2, 2)
        with closing(admin.cursor()) as cursor:
            read_boundary(cursor, expected)
        return {
            "generation": 84,
            "installation_replayed": False,
            "business_replayed": False,
            "prior_receipt_sha256": manifest["reuse"]["receipt_sha256"],
        }

    check("verified-retained-collector-proof-for-borrowed-session-entry", preflight)
    sql(origin, "EXECUTE AS LOGIN='S11_ExportApplication_P02Qual'")
    sql(producer, "EXECUTE AS LOGIN='S11_ExportApplication_P02Qual'")
    try:
        with closing(origin.cursor()) as cursor:
            baseline = coherent_maintenance_snapshot(
                cursor,
                approved,
                expected,
                lambda checkpoint: application_installation_snapshot(
                    cursor, scope=scope, metadata_format=FORMAT, checkpoint=checkpoint
                ),
            )

        class CountedCursor:
            def __init__(self, cursor):
                self.cursor = cursor
                self.reads = 0

            def execute(self, statement, *parameters):
                if statement != BOUNDARY_SQL:
                    self.reads += 1
                return self.cursor.execute(statement, *parameters)

            def __getattr__(self, name):
                return getattr(self.cursor, name)

        def reuse(cursor):
            def collect(checkpoint):
                current = application_authority_snapshot(cursor, scope=scope, checkpoint=checkpoint)
                return dict(
                    version=2,
                    metadata=deepcopy(baseline.value["metadata"]),
                    schema_identity=deepcopy(baseline.value["schema_identity"]),
                    **current
                )

            return coherent_maintenance_snapshot(
                cursor, approved, expected, collect, previous_boundary=baseline.boundary
            )

        def borrowed_entry():
            producer.autocommit = False
            sql(producer, "SELECT COUNT_BIG(*) FROM dbo.MaintenanceKvkWork")
            before = tuple(
                sql(
                    producer,
                    "SELECT @@SPID,@@TRANCOUNT,XACT_STATE(),USER_NAME(),SUSER_SNAME(),APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session')",
                )[0]
            )
            assert before[1:] == (
                1,
                1,
                "P02ObserverApplication",
                "S11_ExportApplication_P02Qual",
                "NoLock",
            ), before
            with closing(producer.cursor()) as actual:
                cursor = CountedCursor(actual)
                result = reuse(cursor)
            after = tuple(
                sql(
                    producer,
                    "SELECT @@SPID,@@TRANCOUNT,XACT_STATE(),USER_NAME(),SUSER_SNAME(),APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session')",
                )[0]
            )
            assert after == before and not producer.autocommit
            assert result.boundary.identity[5] != baseline.boundary.identity[5]
            assert result.boundary.identity[6:9] == (1, 1, 2)
            assert cursor.reads == 5
            assert canonical_application_metadata(
                result.value["metadata"], result.value["schema_identity"]
            ) == canonical_application_metadata(
                baseline.value["metadata"], baseline.value["schema_identity"]
            )
            assert all(
                result.value[name] == baseline.value[name]
                for name in (
                    "target",
                    "schema_permissions",
                    "object_permissions",
                    "column_permissions",
                    "maintenance_lifecycle",
                )
            )
            return {
                "generation": result.boundary.generation,
                "origin_session": baseline.boundary.identity[5],
                "producer_session": before[0],
                "fresh_reads": cursor.reads,
                "transaction_state_preserved": list(after[1:3]),
                "isolation": result.boundary.identity[8],
                "scope_limit": "native collection mechanism on one output; protected admission/comparator assembly is separately tested offline and not enabled",
            }

        check(
            "borrowed-application-session-reuses-metadata-with-fresh-authority-and-lifecycle",
            borrowed_entry,
        )
        producer.rollback()  # Explicit fixture owner, never the observation helper.
        producer.autocommit = True

        def stale_entry():
            sql(admin, "BEGIN TRAN; EXEC dbo.usp_P02BeginCatalogueMutation; ROLLBACK")
            with closing(producer.cursor()) as actual:
                cursor = CountedCursor(actual)
                try:
                    reuse(cursor)
                except ObservationDeferred as error:
                    assert error.reason == "generation_changed"
                else:
                    raise AssertionError("Stale cross-session metadata was accepted")
            assert cursor.reads == 0
            return {
                "generation": boundary(admin).generation,
                "fresh_reads": cursor.reads,
                "business_mutations": 0,
                "reason": "generation_changed",
            }

        check(
            "changed-generation-refuses-reuse-before-any-authority-or-lifecycle-read", stale_entry
        )
    finally:
        producer.rollback()
        producer.autocommit = True
        sql(producer, "REVERT")
        sql(origin, "REVERT")
