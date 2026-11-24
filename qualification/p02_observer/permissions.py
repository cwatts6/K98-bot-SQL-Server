"""Focused continuation: prevent trigger bypass using the existing lab login.

Only the dedicated observer database is changed. Existing login/server grants
are inspected, never changed. Completed work for KVK 900001 remains untouched;
900002 is a new permission-regression case, not a replay of that business claim.
"""

import hashlib
from pathlib import Path
import re

import pyodbc

from services.catalogue_observation_dal import ObservationDeferred

TABLES = ("KVKFinalReportHeader", "MaintenanceKvkWork", "MaintenanceWork")
TRIGGERS = (
    ("KVKFinalReportHeader", "tr_P02HeaderObservation"),
    ("MaintenanceKvkWork", "tr_P02KvkWorkObservation"),
    ("MaintenanceWork", "tr_P02MaintenanceObservation"),
)


def run(manifest, packet, connect, sql, check, boundary):
    admin, observer = connect(), connect()
    name = manifest["database"]
    original = {}
    installed = manifest["reuse"].get("permissions_installed", False)

    def preflight():
        assert manifest["reuse"]["stage"] == "lifecycle-permissions"
        identity = sql(
            admin,
            "SELECT DB_ID(),object_id,CONVERT(bigint,current_value),create_date FROM sys.sequences WHERE object_id=OBJECT_ID('dbo.P02ObservationGeneration','SO')",
        )[0]
        assert tuple(identity[:2]) == (13, 1557580587)
        assert identity[2] >= 5 and str(identity[3]) == "2026-11-19 18:04:42.567000"
        assert sql(admin, "SELECT COUNT_BIG(*) FROM dbo.KVKFinalReportHeader")[0][0] == 0
        original["work"] = [
            list(row) for row in sql(admin, "SELECT * FROM dbo.MaintenanceKvkWork ORDER BY KVKNo")
        ]
        assert len(original["work"]) == 1
        assert tuple(
            sql(admin, "SELECT KVKNo,State,CompletedGeneration FROM dbo.MaintenanceKvkWork")[0]
        ) == (900001, "complete", 1)
        assert tuple(
            sql(
                admin,
                "SELECT State,DueGeneration,CompletedGeneration FROM dbo.MaintenanceWork WHERE Kind='kvk_output'",
            )[0]
        ) == ("complete", 1, 1)
        assert sql(admin, "SELECT COUNT_BIG(*) FROM dbo.EXCEL_FOR_KVK_900001")[0][0] == 2
        assert (
            sql(
                admin,
                "SELECT COUNT_BIG(*) FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.EXCEL_FOR_KVK_900001') AND index_id>0",
            )[0][0]
            == 2
        )
        assert (
            sql(
                admin,
                "SELECT COUNT_BIG(*) FROM sys.triggers WHERE name IN ('tr_P02QualificationAfterDDL','tr_P02QualificationAfterLifecycle')",
            )[0][0]
            == 0
        )
        principals = tuple(
            sql(
                admin,
                "SELECT DATABASE_PRINCIPAL_ID('ExportLegacyEntryReader'),DATABASE_PRINCIPAL_ID('P02ObserverApplication'),OBJECT_ID('dbo.EXCEL_FOR_KVK_900002')",
            )[0]
        )
        if installed:
            assert identity[2] == manifest["reuse"]["generation"] == 60
            assert all(type(value) is int for value in principals[:2]) and principals[2] is None
            assert (
                sql(
                    admin,
                    "SELECT COUNT_BIG(*) FROM sys.database_permissions WHERE grantee_principal_id=DATABASE_PRINCIPAL_ID('ExportLegacyEntryReader') AND class=1 AND state='D' AND permission_name='ALTER' AND major_id IN (OBJECT_ID('dbo.KVKFinalReportHeader'),OBJECT_ID('dbo.MaintenanceKvkWork'),OBJECT_ID('dbo.MaintenanceWork'))",
                )[0][0]
                == 3
            )
            assert (
                sql(
                    admin,
                    "SELECT COUNT_BIG(*) FROM sys.database_role_members WHERE member_principal_id=DATABASE_PRINCIPAL_ID('P02ObserverApplication') AND role_principal_id=DATABASE_PRINCIPAL_ID('ExportLegacyEntryReader')",
                )[0][0]
                == 1
            )
        else:
            assert principals == (None, None, None)
        boundary(observer)
        # Retain raw definitions before the permission decision. Comparison does
        # not replace source/options validation or rely on learned live bodies.
        definitions = [
            list(row)
            for row in sql(
                admin,
                "SELECT object_id,definition,uses_ansi_nulls,uses_quoted_identifier,execute_as_principal_id FROM sys.sql_modules ORDER BY object_id",
            )
        ]
        raw = repr(definitions).encode("utf-8")
        (packet / "protocol-definitions.txt").write_bytes(raw)
        login = sql(
            admin,
            "SELECT principal_id,type_desc,is_disabled FROM sys.server_principals WHERE name=N'S11_ExportApplication_P02Qual'",
        )
        assert len(login) == 1 and login[0][1] == "SQL_LOGIN"
        original["login"] = list(login[0])
        return {
            "generation": identity[2],
            "truncated_header_preserved": True,
            "previous_work": original["work"],
            "definitions_sha256": hashlib.sha256(raw).hexdigest(),
            "existing_lab_login": original["login"],
            "prior_receipt_sha256": manifest["reuse"]["receipt_sha256"],
            "permissions_installation_replayed": False,
        }

    check("verified-post-truncate-fixture-without-business-replay", preflight)

    def permissions():
        # These are the relevant legacy-role grants from the authoritative direct
        # permission migration, plus narrowly scoped proof DML/worker entry.
        # No login, server permission, or earlier database is altered.
        sql(
            admin,
            "BEGIN TRAN; CREATE ROLE ExportLegacyEntryReader AUTHORIZATION dbo; CREATE USER P02ObserverApplication FOR LOGIN S11_ExportApplication_P02Qual; ALTER ROLE ExportLegacyEntryReader ADD MEMBER P02ObserverApplication; GRANT CONNECT TO P02ObserverApplication; GRANT VIEW DEFINITION TO P02ObserverApplication; GRANT CREATE TABLE TO ExportLegacyEntryReader; GRANT CREATE VIEW TO ExportLegacyEntryReader; GRANT VIEW DATABASE PERFORMANCE STATE TO ExportLegacyEntryReader; GRANT ALTER ON SCHEMA::dbo TO ExportLegacyEntryReader; GRANT INSERT ON SCHEMA::dbo TO ExportLegacyEntryReader; GRANT SELECT ON SCHEMA::dbo TO ExportLegacyEntryReader; GRANT UPDATE,DELETE ON OBJECT::dbo.KVKFinalReportHeader TO P02ObserverApplication; GRANT UPDATE,DELETE ON OBJECT::dbo.MaintenanceKvkWork TO P02ObserverApplication; GRANT UPDATE,DELETE ON OBJECT::dbo.MaintenanceWork TO P02ObserverApplication; GRANT EXECUTE ON OBJECT::dbo.usp_RunMaintenance TO P02ObserverApplication; COMMIT",
        )
        sql(admin, "EXECUTE AS USER='P02ObserverApplication'")
        try:
            before = sql(
                admin,
                "SELECT HAS_PERMS_BY_NAME('dbo.KVKFinalReportHeader','OBJECT','ALTER'),HAS_PERMS_BY_NAME('dbo.MaintenanceKvkWork','OBJECT','ALTER'),HAS_PERMS_BY_NAME('dbo.MaintenanceWork','OBJECT','ALTER')",
            )[0]
            assert tuple(before) == (1, 1, 1)
        finally:
            sql(admin, "REVERT")
        fragment = (packet / "qualification/p02_observer/lifecycle_permissions.sql").read_text(
            encoding="utf-8"
        )
        sql(admin, "BEGIN TRAN; EXEC dbo.usp_P02BeginCatalogueMutation")
        try:
            sql(admin, fragment)
            sql(admin, "COMMIT")
        except BaseException:
            sql(admin, "IF @@TRANCOUNT>0 ROLLBACK")
            raise
        return {"before_alter": list(before), "denied_tables": TABLES, "server_changes": 0}

    if not installed:
        check("candidate-lifecycle-permissions-only-in-proof-database", permissions)
    actor = connect()
    impersonated = False
    try:
        sql(actor, "EXECUTE AS LOGIN='S11_ExportApplication_P02Qual'")
        impersonated = True

        def actual_actor():
            facts = sql(
                actor,
                "SELECT USER_NAME(),SUSER_SNAME(),DB_ID(),IS_SRVROLEMEMBER('sysadmin'),IS_ROLEMEMBER('db_owner'),HAS_PERMS_BY_NAME(NULL,NULL,'ADMINISTER BULK OPERATIONS'),HAS_PERMS_BY_NAME('dbo.KVKFinalReportHeader','OBJECT','ALTER'),HAS_PERMS_BY_NAME('dbo.MaintenanceKvkWork','OBJECT','ALTER'),HAS_PERMS_BY_NAME('dbo.MaintenanceWork','OBJECT','ALTER'),HAS_PERMS_BY_NAME('dbo.P02DirectDDL','OBJECT','ALTER')",
            )[0]
            assert tuple(facts) == (
                "P02ObserverApplication",
                "S11_ExportApplication_P02Qual",
                13,
                0,
                0,
                1,
                0,
                0,
                0,
                1,
            ), repr(tuple(facts))
            boundary(actor)
            return {
                "principal": facts[0],
                "bulk_permission": facts[5],
                "lifecycle_alter": list(facts[6:9]),
                "other_table_alter": facts[9],
            }

        check("actual-restricted-lab-principal-and-observer-read", actual_actor)

        def refused(statement):
            before = boundary(observer)
            try:
                sql(actor, statement)
            except pyodbc.Error as error:
                # A timeout/file error is not evidence that ALTER was denied.
                detail = str(error)
                assert error.args[0] == "42000" and re.search(
                    r"permission|does not exist", detail, re.I
                ), detail
                assert boundary(observer).generation == before.generation
                return {"statement": statement, "error": detail[:1500]}
            raise AssertionError("Trigger-bypassing operation was allowed: " + statement)

        def truncate_and_disable():
            facts = []
            for table in TABLES:
                facts.append(refused(f"TRUNCATE TABLE dbo.{table}"))
            for table, trigger in TRIGGERS:
                facts.append(refused(f"DISABLE TRIGGER dbo.{trigger} ON dbo.{table}"))
            assert sql(admin, "SELECT COUNT_BIG(*) FROM dbo.KVKFinalReportHeader")[0][0] == 0
            assert [
                list(row)
                for row in sql(admin, "SELECT * FROM dbo.MaintenanceKvkWork ORDER BY KVKNo")
            ] == original["work"]
            return facts

        check("application-truncate-and-trigger-suppression-refused", truncate_and_disable)

        data_root = Path(
            sql(admin, "SELECT CONVERT(nvarchar(260),SERVERPROPERTY('InstanceDefaultDataPath'))")[
                0
            ][0]
        )
        data_file = data_root / (name + "_900002_bulk.txt")
        assert data_file.is_absolute() and "'" not in str(data_file)
        with data_file.open("xb") as handle:
            handle.write(b"900002\t2026-11-19 19:00:00\t1\t2\t1\tOUTPUT_COMPLETE\tLIVE_OUTPUT\n")
        bulk_path = str(data_file)

        def bulk_enforcement():
            bypass = f"BULK INSERT dbo.KVKFinalReportHeader FROM '{bulk_path}' WITH (FIELDTERMINATOR='\t',ROWTERMINATOR='0x0a',CHECK_CONSTRAINTS)"
            denial = refused(bypass)
            assert sql(admin, "SELECT COUNT_BIG(*) FROM dbo.KVKFinalReportHeader")[0][0] == 0
            before = boundary(observer)
            sql(
                actor,
                f"BULK INSERT dbo.KVKFinalReportHeader FROM '{bulk_path}' WITH (FIELDTERMINATOR='\t',ROWTERMINATOR='0x0a',CHECK_CONSTRAINTS,FIRE_TRIGGERS)",
            )
            after = boundary(observer)
            assert after.generation > before.generation
            assert tuple(
                sql(admin, "SELECT KVK_NO,Revision,OutputRowCount FROM dbo.KVKFinalReportHeader")[0]
            ) == (900002, 1, 2)
            return {
                "without_triggers": denial,
                "with_triggers": "inserted-and-invalidated",
                "data_file": bulk_path,
                "generation": [before.generation, after.generation],
            }

        check("same-file-bulk-bypass-denied-and-triggered-import-works", bulk_enforcement)

        def normal_worker():
            before = boundary(observer)
            sql(
                actor,
                "CREATE TABLE dbo.EXCEL_FOR_KVK_900002(Gov_ID bigint NOT NULL,KVK_NO int NOT NULL); INSERT dbo.EXCEL_FOR_KVK_900002 VALUES(1,900002),(2,900002); UPDATE dbo.KVKFinalReportHeader SET Revision=Revision WHERE KVK_NO=900002; INSERT dbo.MaintenanceKvkWork(KVKNo,DueGeneration,DueObjectID,DueObjectCreateDate,DueHeaderRevision) SELECT 900002,1,object_id,create_date,1 FROM sys.tables WHERE object_id=OBJECT_ID('dbo.EXCEL_FOR_KVK_900002'); UPDATE dbo.MaintenanceWork SET DueGeneration=2,State='pending' WHERE Kind='kvk_output'; EXEC dbo.usp_RunMaintenance @Kind='kvk_output'",
            )
            assert boundary(observer).generation > before.generation
            assert tuple(
                sql(
                    admin,
                    "SELECT State,CompletedGeneration FROM dbo.MaintenanceKvkWork WHERE KVKNo=900002",
                )[0]
            ) == ("complete", 1)
            assert tuple(
                sql(
                    admin,
                    "SELECT State,CompletedGeneration FROM dbo.MaintenanceWork WHERE Kind='kvk_output'",
                )[0]
            ) == ("complete", 2)
            indexes = [
                row[0]
                for row in sql(
                    admin,
                    "SELECT name FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.EXCEL_FOR_KVK_900002') AND index_id>0 ORDER BY name",
                )
            ]
            assert indexes == ["IX_EXCEL_FOR_KVK_900002_GovID", "IX_EXCEL_FOR_KVK_900002_KVK_NO"]
            assert [
                list(row)
                for row in sql(admin, "SELECT * FROM dbo.MaintenanceKvkWork WHERE KVKNo=900001")
            ] == original["work"]
            assert (
                sql(admin, "SELECT COUNT_BIG(*) FROM dbo.KVKFinalReportHeader WHERE KVK_NO=900001")[
                    0
                ][0]
                == 0
            )
            return {
                "new_case": 900002,
                "previous_case_untouched": 900001,
                "indexes": indexes,
                "physical_completion": True,
            }

        check("restricted-actor-normal-ddl-lifecycle-and-real-maintenance", normal_worker)

        def replacement_transaction():
            # Standalone SELECT INTO must be invalidated too, including a first
            # creation where DROP IF EXISTS has no previous object to remove.
            first = boundary(observer)
            sql(actor, "SELECT CONVERT(int,1) AS ID INTO dbo.P02Replacement")
            assert (
                boundary(observer).generation > first.generation
            ), "SELECT INTO bypasses catalogue invalidation"
            initial_object = tuple(
                sql(
                    admin,
                    "SELECT object_id,create_date FROM sys.tables WHERE object_id=OBJECT_ID('dbo.P02Replacement')",
                )[0]
            )
            outcomes = []
            for completion in ("COMMIT", "ROLLBACK"):
                before = boundary(observer)
                sql(
                    actor,
                    "BEGIN TRAN; EXEC dbo.usp_P02BeginCatalogueMutation; DROP TABLE dbo.P02Replacement",
                )
                for statement in (None, "SELECT CONVERT(int,?) AS ID INTO dbo.P02Replacement"):
                    if statement is not None:
                        sql(actor, statement, 2 if completion == "COMMIT" else 3)
                    try:
                        boundary(observer)
                    except ObservationDeferred as error:
                        assert error.reason == "active_writer"
                    else:
                        raise AssertionError(
                            "Drop/recreate gap was admitted before transaction completion"
                        )
                sql(actor, completion)
                after = boundary(observer)
                assert after.generation > before.generation
                assert sql(admin, "SELECT ID FROM dbo.P02Replacement")[0][0] == 2
                object_identity = tuple(
                    sql(
                        admin,
                        "SELECT object_id,create_date FROM sys.tables WHERE object_id=OBJECT_ID('dbo.P02Replacement')",
                    )[0]
                )
                if completion == "COMMIT":
                    committed_object = object_identity
                else:
                    assert object_identity == committed_object
                outcomes.append(
                    {
                        "completion": completion,
                        "generation": [before.generation, after.generation],
                        "object_identity": object_identity,
                    }
                )
            return {
                "standalone_select_into_invalidated": True,
                "initial_object": initial_object,
                "transactions": outcomes,
            }

        check("drop-select-into-commit-and-rollback-observation", replacement_transaction)
    finally:
        if impersonated:
            sql(actor, "IF @@TRANCOUNT>0 ROLLBACK; REVERT")
            assert (
                sql(actor, "SELECT SUSER_SNAME(),ORIGINAL_LOGIN()")[0][0]
                == sql(actor, "SELECT ORIGINAL_LOGIN()")[0][0]
            )
        assert (
            list(
                sql(
                    admin,
                    "SELECT principal_id,type_desc,is_disabled FROM sys.server_principals WHERE name=N'S11_ExportApplication_P02Qual'",
                )[0]
            )
            == original["login"]
        )
