"""Continue the retained fixture: health and full collector integration.

No business work is replayed. Only the observation procedure is amended; a
single lifecycle ALTER denial is temporarily removed and restored for the
fresh-enforcement negative case. Earlier fixtures and receipts are retained.
"""

from contextlib import closing
import re

import pyodbc

from services.application_maintenance_contract import POLICY
from services.application_maintenance_dal import coherent_maintenance_snapshot
from services.catalogue_observation_dal import read_boundary
from services.export_execution_dal import application_installation_snapshot
from services.export_schema_fingerprint import FORMAT, canonical_application_metadata


def run(manifest, packet, connect, sql, check, boundary, expected_sources):
    admin, actor = connect(), connect()
    expected = expected_sources(manifest["protocol_sources"])
    previous = expected_sources(manifest["reuse"]["previous_protocol_sources"])
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

    def amend():
        reader_installed = manifest["reuse"].get("reader_installed", False)
        assert tuple(
            sql(
                admin,
                "SELECT DB_ID(),object_id,CONVERT(bigint,current_value) FROM sys.sequences WHERE object_id=OBJECT_ID('dbo.P02ObservationGeneration','SO')",
            )[0]
        ) == (13, 1557580587, 82 if reader_installed else 80)
        assert tuple(sql(admin, "SELECT KVK_NO,Revision FROM dbo.KVKFinalReportHeader")[0]) == (
            900002,
            1,
        )
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
            read_boundary(cursor, previous)
        if reader_installed:
            assert manifest["reuse"]["amendments"] == []
            assert manifest["reuse"]["metadata_grant"] == {
                "object": "sys.sql_expression_dependencies",
                "permission": "SELECT",
            }
            # Already required by deploy/s11_application_grants.json. The small
            # fixture omitted it; no new production permission is proposed.
            sql(
                admin,
                "GRANT SELECT ON OBJECT::sys.sql_expression_dependencies TO P02ObserverApplication",
            )
            return {
                "reader_installation_replayed": False,
                "restored_existing_application_grant": manifest["reuse"]["metadata_grant"],
                "business_replayed": False,
                "prior_receipt_sha256": manifest["reuse"]["receipt_sha256"],
                "generation": boundary(admin).generation,
            }
        assert manifest["reuse"]["amendments"] == [
            "sql/dbo.usp_P02ReadObservationBoundary.StoredProcedure.sql"
        ]
        source = (packet / manifest["reuse"]["amendments"][0]).read_text(encoding="utf-8")
        sql(admin, "BEGIN TRAN; EXEC dbo.usp_P02BeginCatalogueMutation")
        try:
            for batch in re.split(r"(?im)^GO\s*$", source):
                if batch.strip():
                    sql(admin, batch)
            sql(admin, "COMMIT")
        except BaseException:
            sql(admin, "IF @@TRANCOUNT>0 ROLLBACK")
            raise
        return {
            "changed_module": manifest["reuse"]["amendments"][0],
            "business_replayed": False,
            "prior_receipt_sha256": manifest["reuse"]["receipt_sha256"],
            "generation": boundary(admin).generation,
        }

    check(
        (
            "verified-installed-reader-and-fixture-metadata-grant"
            if manifest["reuse"].get("reader_installed")
            else "verified-successful-fixture-and-amended-reader-only"
        ),
        amend,
    )
    sql(actor, "EXECUTE AS LOGIN='S11_ExportApplication_P02Qual'")
    try:

        def collect(cursor, checkpoint):
            return application_installation_snapshot(
                cursor, scope=scope, metadata_format=FORMAT, checkpoint=checkpoint
            )

        def full_read():
            assert tuple(
                sql(
                    actor,
                    "SELECT USER_NAME(),SUSER_SNAME(),IS_SRVROLEMEMBER('sysadmin'),IS_ROLEMEMBER('db_owner')",
                )[0]
            ) == ("P02ObserverApplication", "S11_ExportApplication_P02Qual", 0, 0)
            with closing(actor.cursor()) as cursor:
                result = coherent_maintenance_snapshot(
                    cursor, approved, expected, lambda checkpoint: collect(cursor, checkpoint)
                )
            canonical = canonical_application_metadata(
                result.value["metadata"], result.value["schema_identity"]
            )
            assert len(result.value["metadata"]) == 10
            assert (
                result.value["schema_permissions"]
                and result.value["object_permissions"]
                and result.value["column_permissions"]
            )
            proof = result.value["maintenance_lifecycle"]
            assert proof["guard"] == result.guard == "catalogue_generation_v1"
            assert len(proof["outputs"]) == 1
            assert proof["outputs"][0]["ObjectID"] == proof["outputs"][0]["DueObjectID"]
            assert (
                proof["outputs"][0]["State"] == proof["outputs"][0]["AggregateState"] == "complete"
            )
            return {
                "metadata_categories": sorted(result.value["metadata"]),
                "identity_categories": sorted(result.value["schema_identity"]),
                "canonical_index_count": len(canonical["metadata"]["indexes"]),
                "lifecycle": proof,
                "generation": result.boundary.generation,
                "scope_limit": "one known output plus global metadata; not representative full-application contract acceptance",
            }

        check("actual-actor-complete-collector-checkpoints-and-lifecycle", full_read)

        def permission_drift():
            dispatched = []
            removed = False
            try:
                with closing(actor.cursor()) as cursor:

                    def read_until_drift(checkpoint):
                        def change_after_first_batch():
                            nonlocal removed
                            if not removed:
                                sql(
                                    admin,
                                    "REVOKE ALTER ON OBJECT::dbo.KVKFinalReportHeader FROM ExportLegacyEntryReader",
                                )
                                removed = True
                            dispatched.append("boundary-after-consumed-batch")
                            checkpoint()

                        return collect(cursor, change_after_first_batch)

                    try:
                        coherent_maintenance_snapshot(cursor, approved, expected, read_until_drift)
                    except pyodbc.Error as error:
                        assert "51972" in str(error), str(error)
                        refusal = str(error)
                    else:
                        raise AssertionError("Missing lifecycle denial was accepted")
                assert removed and len(dispatched) == 1
            finally:
                if removed:
                    sql(
                        admin,
                        "DENY ALTER ON OBJECT::dbo.KVKFinalReportHeader TO ExportLegacyEntryReader",
                    )
            with closing(actor.cursor()) as cursor:
                settled = coherent_maintenance_snapshot(
                    cursor, approved, expected, lambda checkpoint: collect(cursor, checkpoint)
                )
            return {
                "refusal": refusal,
                "stopped_at_first_checkpoint": True,
                "restored_and_read": settled.boundary.generation,
                "claim_count": sql(admin, "SELECT COUNT_BIG(*) FROM dbo.MaintenanceKvkWork")[0][0],
            }

        check("fresh-denial-health-refuses-drift-and-recovers-after-restoration", permission_drift)
    finally:
        sql(actor, "IF @@TRANCOUNT>0 ROLLBACK; REVERT")
