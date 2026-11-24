"""Finite protocol proof: new isolated-VM fixture; preserve all old databases."""

from datetime import datetime, timezone
from contextlib import closing
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import traceback

PACKET = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PACKET / "bot"))
sys.path.append(r"C:\discord_file_downloader\venv\Lib\site-packages")
manifest = json.loads((PACKET / "manifest.json").read_text(encoding="utf-8"))
NAME = manifest["database"]
if os.environ.get("COMPUTERNAME") != "MINI_AMD" or not re.fullmatch(
    r"K98_P02Observer_[0-9]{17}", NAME
):
    raise RuntimeError("Exact isolated lab launch required")
for name, digest in manifest["files"].items():
    path = PACKET / name
    if (
        not path.resolve().is_relative_to(PACKET)
        or hashlib.sha256(path.read_bytes()).hexdigest() != digest
    ):
        raise RuntimeError("Packet member differs: " + name)
import pyodbc
from services.catalogue_observation_dal import (
    MODULES,
    ObservationContractError,
    ObservationDeferred,
    observe_catalogue,
    read_boundary,
)
from services.export_execution_dal import application_installation_snapshot

pyodbc.pooling = False
BASE = "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;DATABASE="
receipt = {
    "schema": "p02-observer-native/1",
    "database": NAME,
    "started": datetime.now(timezone.utc).isoformat(),
    "checks": [],
    "production_operations": 0,
    "retained_databases_changed": 0,
    "connections_closed": 0,
}
connections = []


def expected_sources(names):
    result = {}
    for name in names:
        source = (PACKET / name).read_text(encoding="utf-8")
        body = re.split(r"(?im)^GO\s*$", source)[1]
        module = re.search(r"(?i)(?:PROCEDURE|TRIGGER)\s+(?:dbo\.)?(\w+)", body)[1]
        result[module] = body
    assert set(result) == MODULES
    return result


expected = expected_sources(manifest["protocol_sources"])

DDL_HOLD = """CREATE OR ALTER TRIGGER tr_P02QualificationAfterDDL ON DATABASE FOR ALTER_TABLE AS
BEGIN
 SET NOCOUNT ON;
 IF CONVERT(int,SESSION_CONTEXT(N'P02QualificationHold'))=1
 BEGIN
  DECLARE @r int;
  EXEC @r=sys.sp_getapplock @Resource=N'P02Qualification:after-invalidator',@LockMode='Shared',@LockOwner='Session',@LockTimeout=10000;
  IF @r NOT IN (0,1) THROW 51979,'Qualification barrier timed out.',1;
  EXEC @r=sys.sp_releaseapplock @Resource=N'P02Qualification:after-invalidator',@LockOwner='Session';
  IF @r<>0 THROW 51979,'Qualification barrier release failed.',1;
 END;
END;"""
DML_HOLD = """CREATE OR ALTER TRIGGER dbo.tr_P02QualificationAfterLifecycle ON dbo.MaintenanceWork AFTER UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF CONVERT(int,SESSION_CONTEXT(N'P02QualificationHold'))=1
 BEGIN
  DECLARE @r int;
  EXEC @r=sys.sp_getapplock @Resource=N'P02Qualification:after-invalidator',@LockMode='Shared',@LockOwner='Session',@LockTimeout=10000;
  IF @r NOT IN (0,1) THROW 51979,'Qualification barrier timed out.',1;
  EXEC @r=sys.sp_releaseapplock @Resource=N'P02Qualification:after-invalidator',@LockOwner='Session';
  IF @r<>0 THROW 51979,'Qualification barrier release failed.',1;
 END;
END;"""


def connect(database=NAME):
    connection = pyodbc.connect(BASE + database, autocommit=True, timeout=5)
    connection.timeout = 15
    connections.append(connection)
    sql(connection, "SET LOCK_TIMEOUT 1000; SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
    return connection


def sql(connection, statement, *parameters):
    with closing(connection.cursor()) as cursor:
        cursor.execute(statement, *parameters)
        result = cursor.fetchall() if cursor.description else []
        while cursor.nextset():
            if cursor.description:
                result.extend(cursor.fetchall())
        return result


def check(name, action):
    start = time.perf_counter()
    print("START " + name, flush=True)
    try:
        facts = action()
    except BaseException as error:
        receipt["checks"].append(
            {
                "name": name,
                "passed": False,
                "seconds": time.perf_counter() - start,
                "error": type(error).__name__,
                "detail": str(error)[:2000],
            }
        )
        raise
    receipt["checks"].append(
        {"name": name, "passed": True, "seconds": time.perf_counter() - start, "facts": facts}
    )
    (PACKET / "progress.json").write_text(
        json.dumps(receipt, indent=2, default=str), encoding="utf-8"
    )
    print("PASS " + name, flush=True)


def deferred(action, reason):
    try:
        action()
    except ObservationDeferred as error:
        assert error.reason == reason
    else:
        raise AssertionError("An overlapping candidate was accepted")


def install():
    admin = connect("master")
    assert sql(admin, "SELECT DB_ID(?)", NAME)[0][0] is None
    paths = sql(
        admin,
        "SELECT CONVERT(nvarchar(260),SERVERPROPERTY('InstanceDefaultDataPath')),CONVERT(nvarchar(260),SERVERPROPERTY('InstanceDefaultLogPath'))",
    )[0]
    mdf = str(Path(paths[0]) / (NAME + ".mdf"))
    ldf = str(Path(paths[1]) / (NAME + ".ldf"))
    assert "'" not in mdf + ldf
    sql(
        admin,
        f"CREATE DATABASE [{NAME}] ON PRIMARY (NAME=N'{NAME}',FILENAME=N'{mdf}',SIZE=64MB,MAXSIZE=512MB,FILEGROWTH=32MB) LOG ON (NAME=N'{NAME}_log',FILENAME=N'{ldf}',SIZE=32MB,MAXSIZE=256MB,FILEGROWTH=32MB)",
    )
    sql(admin, f"ALTER DATABASE [{NAME}] SET RECOVERY SIMPLE")
    connection = connect()
    for name in manifest["install_sources"]:
        source = (PACKET / name).read_text(encoding="utf-8-sig")
        for batch in re.split(r"(?im)^GO\s*$", source):
            if batch.strip():
                sql(connection, batch)
    return {"source_files": len(manifest["install_sources"]), "maximum_fixture_mb": 768}


def boundary(connection):
    with closing(connection.cursor()) as cursor:
        return read_boundary(cursor, expected)


def run_cases():
    if manifest.get("reuse", {}).get("stage") == "metadata-reuse":
        sys.path.insert(0, str(PACKET / "qualification/p02_observer"))
        from reuse import run

        run(manifest, PACKET, connect, sql, check, boundary, expected_sources)
        return
    if manifest.get("reuse", {}).get("stage") == "collector-integration":
        sys.path.insert(0, str(PACKET / "qualification/p02_observer"))
        from integration import run

        run(manifest, PACKET, connect, sql, check, boundary, expected_sources)
        return
    if manifest.get("reuse", {}).get("stage") == "lifecycle-permissions":
        sys.path.insert(0, str(PACKET / "qualification/p02_observer"))
        from permissions import run

        run(manifest, PACKET, connect, sql, check, boundary)
        return
    if "reuse" in manifest:

        def reuse():
            connection = connect()
            target = sql(
                connection,
                "SELECT DB_ID(),object_id,CONVERT(bigint,current_value) FROM sys.sequences WHERE object_id=OBJECT_ID('dbo.P02ObservationGeneration','SO')",
            )[0]
            assert tuple(target) == (
                manifest["reuse"]["database_id"],
                manifest["reuse"]["sequence_object_id"],
                manifest["reuse"]["generation"],
            )
            assert sql(connection, "SELECT COUNT_BIG(*) FROM dbo.KVKFinalReportHeader")[0][0] == 0
            assert sql(connection, "SELECT COUNT_BIG(*) FROM dbo.MaintenanceKvkWork")[0][0] == 0
            assert (
                sql(
                    connection,
                    "SELECT COUNT_BIG(*) FROM dbo.MaintenanceWork WHERE DueGeneration=0 AND CompletedGeneration=0 AND State='complete'",
                )[0][0]
                == 6
            )
            previous = expected_sources(manifest["reuse"]["previous_protocol_sources"])
            with closing(connection.cursor()) as cursor:
                read_boundary(cursor, previous)
            amendments = manifest["reuse"]["amendments"]
            if amendments:
                assert (
                    sql(connection, "SELECT COL_LENGTH('dbo.P02DirectDDL','Revision')")[0][0]
                    is None
                )
                sql(connection, "BEGIN TRAN; EXEC dbo.usp_P02BeginCatalogueMutation")
                try:
                    for name in amendments:
                        for batch in re.split(
                            r"(?im)^GO\s*$", (PACKET / name).read_text(encoding="utf-8")
                        ):
                            if batch.strip():
                                sql(connection, batch)
                    sql(connection, "COMMIT")
                except BaseException:
                    sql(connection, "IF @@TRANCOUNT>0 ROLLBACK")
                    raise
                boundary(connection)
            return {
                "installation_replayed": False,
                "trigger_amendments": amendments,
                "prior_receipt_sha256": manifest["reuse"]["receipt_sha256"],
            }

        check("verified-retained-pre-mutation-fixture-reused", reuse)
    else:
        check("isolated-source-installation", install)
    observer, writer, second = connect(), connect(), connect()
    first = boundary(observer)

    def first_change():
        sql(writer, "BEGIN TRAN; EXEC dbo.usp_P02BeginCatalogueMutation")
        deferred(lambda: boundary(observer), "active_writer")
        sql(writer, "ROLLBACK")
        after = boundary(observer)
        assert after.generation > first.generation
        return {"baseline_generation": first.generation, "after_rollback": after.generation}

    amended = manifest.get("reuse", {}).get("stage") == "trigger-enrollment"
    if not amended:
        check("bootstrap-first-mutation-and-rollback", first_change)

    def two_writers():
        for connection in (writer, second):
            sql(connection, "BEGIN TRAN; EXEC dbo.usp_P02BeginCatalogueMutation")
        deferred(lambda: boundary(observer), "active_writer")
        sql(writer, "ROLLBACK")
        deferred(lambda: boundary(observer), "active_writer")
        sql(second, "ROLLBACK")
        return {"quiet_generation": boundary(observer).generation}

    if not amended:
        check("compatible-writers-held-until-both-physical-rollbacks", two_writers)

    def direct_ddl():
        before = boundary(observer)
        sql(writer, "BEGIN TRAN; CREATE TABLE dbo.P02DirectDDL(ID int NOT NULL)")
        deferred(lambda: boundary(observer), "active_writer")
        sql(writer, "COMMIT")
        assert boundary(observer).generation > before.generation
        return {"direct_ddl_committed": True}

    if not amended:
        check("direct-ddl-invalidator-transaction-lifetime", direct_ddl)

    def overlapping_read():
        with closing(observer.cursor()) as cursor:

            def collect(checkpoint):
                sql(observer, "SELECT name FROM sys.tables")
                sql(writer, "ALTER TABLE dbo.P02DirectDDL ADD Revision int NULL")
                checkpoint()
                raise AssertionError("Reader continued after change")

            deferred(lambda: observe_catalogue(cursor, expected, collect), "generation_changed")
        with closing(observer.cursor()) as cursor:
            result = observe_catalogue(
                cursor, expected, lambda checkpoint: application_installation_snapshot(cursor)
            )
        return {"full_metadata_categories": sorted(result.value["metadata"]), "guard": result.guard}

    check("mixed-candidate-discarded-and-full-current-metadata-read", overlapping_read)

    def trigger_lifetime():
        sql(writer, "BEGIN TRAN")
        sql(writer, DDL_HOLD)
        sql(writer, DML_HOLD)
        sql(
            writer,
            "EXEC sys.sp_settriggerorder @triggername=N'tr_P02CatalogueObservation',@order='First',@stmttype='ALTER_TABLE',@namespace='DATABASE'; EXEC sys.sp_settriggerorder @triggername=N'tr_P02QualificationAfterDDL',@order='Last',@stmttype='ALTER_TABLE',@namespace='DATABASE'; EXEC sys.sp_settriggerorder @triggername=N'dbo.tr_P02MaintenanceObservation',@order='First',@stmttype='UPDATE'; EXEC sys.sp_settriggerorder @triggername=N'dbo.tr_P02QualificationAfterLifecycle',@order='Last',@stmttype='UPDATE'; COMMIT",
        )
        writer_id = sql(writer, "SELECT @@SPID")[0][0]
        outcomes = []
        for actor_sql in (
            "ALTER TABLE dbo.P02DirectDDL ADD HeldRevision int NULL",
            "UPDATE dbo.MaintenanceWork SET State=State WHERE Kind='kvk_output'",
        ):
            before = boundary(observer)
            sql(writer, "EXEC sys.sp_set_session_context @key=N'P02QualificationHold',@value=1")
            assert (
                sql(
                    second,
                    "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'P02Qualification:after-invalidator',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; SELECT @r",
                )[0][0]
                == 0
            )
            with ThreadPoolExecutor(max_workers=1) as pool:
                pending = pool.submit(sql, writer, actor_sql)
                first_error = None
                try:
                    deadline = time.monotonic() + 5
                    while True:
                        waiting = sql(
                            second,
                            "SELECT COUNT_BIG(*) FROM sys.dm_tran_locks WHERE request_session_id=? AND resource_type='APPLICATION' AND request_status='WAIT'",
                            writer_id,
                        )[0][0]
                        if waiting == 1:
                            break
                        if pending.done():
                            pending.result()
                            raise AssertionError("Actor bypassed the later-trigger barrier")
                        if time.monotonic() >= deadline:
                            raise AssertionError("Later-trigger barrier was not observed")
                        time.sleep(0.02)
                    # The first trigger already returned. Its marker must still
                    # cover the physically unfinished enclosing statement.
                    assert (
                        sql(
                            observer,
                            "SELECT APPLOCK_TEST('public','K98:catalogue-mutation:v1','Exclusive','Session')",
                        )[0][0]
                        == 0
                    ), "Marker released before its surrounding statement finished"
                    deferred(lambda: boundary(observer), "active_writer")
                except BaseException as error:
                    first_error = error
                    raise
                finally:
                    try:
                        released = sql(
                            second,
                            "DECLARE @r int; EXEC @r=sys.sp_releaseapplock @Resource=N'P02Qualification:after-invalidator',@LockOwner='Session'; SELECT @r,APPLOCK_MODE('public','P02Qualification:after-invalidator','Session')",
                        )[0]
                        assert tuple(released) == (0, "NoLock")
                    except BaseException as cleanup:
                        if first_error is None:
                            raise
                        first_error.add_note("Barrier cleanup also failed: " + str(cleanup))
                pending.result(timeout=20)
            assert boundary(observer).generation > before.generation
            assert tuple(sql(writer, "SELECT @@TRANCOUNT,XACT_STATE()")[0]) == (0, 0)
            outcomes.append(
                {
                    "statement": actor_sql,
                    "marker_held_after_invalidator_returned": True,
                    "physical_completion": True,
                }
            )
        sql(
            writer,
            "EXEC sys.sp_set_session_context @key=N'P02QualificationHold',@value=NULL; DROP TRIGGER tr_P02QualificationAfterDDL ON DATABASE; DROP TRIGGER dbo.tr_P02QualificationAfterLifecycle; EXEC sys.sp_settriggerorder @triggername=N'tr_P02CatalogueObservation',@order='None',@stmttype='ALTER_TABLE',@namespace='DATABASE'; EXEC sys.sp_settriggerorder @triggername=N'dbo.tr_P02MaintenanceObservation',@order='None',@stmttype='UPDATE'",
        )
        return outcomes

    check("autocommit-ddl-and-dml-marker-lifetime-at-later-trigger-barriers", trigger_lifetime)

    def lifecycle_and_maintenance():
        sql(
            writer,
            "CREATE TABLE dbo.EXCEL_FOR_KVK_900001(Gov_ID bigint NOT NULL,KVK_NO int NOT NULL); INSERT dbo.EXCEL_FOR_KVK_900001 VALUES(1,900001),(2,900001)",
        )
        before = boundary(observer)
        sql(
            writer,
            "BEGIN TRAN; INSERT dbo.KVKFinalReportHeader VALUES(900001,SYSUTCDATETIME(),1,2,1,N'OUTPUT_COMPLETE',N'LIVE_OUTPUT')",
        )
        deferred(lambda: boundary(observer), "active_writer")
        sql(writer, "COMMIT")
        assert boundary(observer).generation > before.generation
        sql(
            writer,
            "INSERT dbo.MaintenanceKvkWork(KVKNo,DueGeneration,DueObjectID,DueObjectCreateDate,DueHeaderRevision) SELECT 900001,1,object_id,create_date,1 FROM sys.tables WHERE object_id=OBJECT_ID('dbo.EXCEL_FOR_KVK_900001'); UPDATE dbo.MaintenanceWork SET DueGeneration=1,State='pending' WHERE Kind='kvk_output'",
        )
        with closing(observer.cursor()) as cursor:

            def collect(checkpoint):
                sql(
                    observer,
                    "SELECT name FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.EXCEL_FOR_KVK_900001')",
                )
                sql(writer, "EXEC dbo.usp_RunMaintenance @Kind='kvk_output'")
                checkpoint()

            deferred(lambda: observe_catalogue(cursor, expected, collect), "generation_changed")
        indexes = [
            r[0]
            for r in sql(
                observer,
                "SELECT name FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.EXCEL_FOR_KVK_900001') AND index_id>0 ORDER BY name",
            )
        ]
        assert indexes == ["IX_EXCEL_FOR_KVK_900001_GovID", "IX_EXCEL_FOR_KVK_900001_KVK_NO"]
        assert tuple(
            sql(
                observer,
                "SELECT State,CompletedGeneration FROM dbo.MaintenanceKvkWork WHERE KVKNo=900001",
            )[0]
        ) == ("complete", 1)
        assert tuple(
            sql(
                observer,
                "SELECT State,CompletedGeneration FROM dbo.MaintenanceWork WHERE Kind='kvk_output'",
            )[0]
        ) == ("complete", 1)
        boundary(observer)
        return {
            "actual_worker": "usp_RunMaintenance/usp_MaintenanceKvkOutput",
            "indexes": indexes,
            "claim_completed": True,
        }

    check(
        "lifecycle-marking-and-real-maintenance-progress-observer-first", lifecycle_and_maintenance
    )

    def session_marker():
        sql(writer, "EXEC dbo.usp_P02BeginCatalogueMutation @Owner='Session'")
        deferred(lambda: boundary(observer), "active_writer")
        sql(
            writer,
            "EXEC dbo.usp_P02BeginCatalogueMutation @Owner='Session'; EXEC dbo.usp_P02EndCatalogueMutation",
        )
        boundary(observer)
        return {"nested_helper_reference_balanced": True}

    check("autocommit-worker-marker-and-acknowledged-release", session_marker)

    def owned_and_transaction_states():
        for statement in (
            "BEGIN TRAN; EXEC dbo.usp_P02BeginCatalogueMutation",
            "BEGIN TRAN; BEGIN TRAN",
            "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE",
        ):
            sql(writer, statement)
            try:
                boundary(writer)
            except pyodbc.Error as error:
                assert "51971" in str(error)
            else:
                raise AssertionError("Unsupported/owned session accepted")
            sql(writer, "IF @@TRANCOUNT>0 ROLLBACK; SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
        sql(writer, "BEGIN TRAN")
        assert boundary(writer).identity[6] == 1
        sql(writer, "ROLLBACK")
        return {"accepted_counts": [0, 1], "refused": ["own-marker", "nested", "serializable"]}

    check("native-borrowed-session-preconditions", owned_and_transaction_states)

    def disabled_and_reset():
        sql(writer, "DISABLE TRIGGER dbo.tr_P02HeaderObservation ON dbo.KVKFinalReportHeader")
        try:
            boundary(observer)
        except ObservationContractError:
            pass
        else:
            raise AssertionError("Disabled invalidator accepted")
        sql(writer, "ENABLE TRIGGER dbo.tr_P02HeaderObservation ON dbo.KVKFinalReportHeader")
        boundary(observer)
        try:
            sql(writer, "ALTER SEQUENCE dbo.P02ObservationGeneration RESTART WITH 1")
        except pyodbc.Error as error:
            assert "51970" in str(error)
        else:
            raise AssertionError("Sequence reset accepted")
        sql(writer, "IF @@TRANCOUNT>0 ROLLBACK")
        return {"disabled_refused": True, "reset_refused": True}

    check("invalidator-health-and-counter-reset-refusal", disabled_and_reset)

    def unsupported_truncate():
        before = boundary(observer)
        sql(writer, "TRUNCATE TABLE dbo.KVKFinalReportHeader")
        after = boundary(observer)
        assert (
            after.generation > before.generation
        ), "TRUNCATE bypasses invalidation; enforced entry/permission coverage required"
        return {"detected": True}

    check("direct-lifecycle-truncate-coverage", unsupported_truncate)


try:
    run_cases()
    receipt["outcome"] = "core-protocol-cases-passed"
except BaseException as error:
    receipt["outcome"] = "failed"
    receipt["first_failure"] = {
        "type": type(error).__name__,
        "detail": str(error)[:2000],
        "traceback": traceback.format_exc(),
    }
finally:
    for connection in reversed(connections):
        try:
            connection.close()
            receipt["connections_closed"] += 1
        except BaseException as error:
            receipt.setdefault("cleanup_errors", []).append(str(error)[:1000])
            receipt["outcome"] = "cleanup-unknown"
    receipt["finished"] = datetime.now(timezone.utc).isoformat()
    with (PACKET / "receipt.json").open("x", encoding="utf-8") as handle:
        json.dump(receipt, handle, indent=2, default=str)
print(
    json.dumps({"outcome": receipt["outcome"], "checks": len(receipt["checks"]), "database": NAME}),
    flush=True,
)
sys.exit(0 if receipt["outcome"] == "core-protocol-cases-passed" else 1)
