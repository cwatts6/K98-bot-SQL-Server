"""Remaining native protocol edges in one new small database; no business replay."""

from contextlib import contextmanager
from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time

PURPOSE = "p02-new-fixture-protocol-edges"
PRIOR = Path("Q:/P02Observer/20261122111933615")
PRIOR_SHA = "2b3bb5d70ea826a5041dee6fca679bd74924f645bc48c38cac0619a5da5e103e"
ARCHIVE_SHA = "13a1e098b781d7f7f1c1bc62b7cb6265ef1d072d60642be86e4c84c33abfeffa"
STATE_SQL = """SELECT @@SPID AS session_id,@@TRANCOUNT AS transaction_count,
XACT_STATE() AS transaction_state,
APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session') AS marker"""
FIXTURE_SQL = """CREATE ROLE ExportLegacyEntryReader;
CREATE USER P02EdgeUser WITHOUT LOGIN;
CREATE TABLE dbo.P02EdgeConstraint(Value int NOT NULL CHECK(Value>0));"""
DOOM_SQL = """SET NOCOUNT ON; SET XACT_ABORT ON;
IF @@TRANCOUNT=0 BEGIN TRANSACTION;
DECLARE @cause int,@refusal int,@before_count int,@before_state int,@after_count int,@after_state int;
BEGIN TRY
 INSERT dbo.P02EdgeConstraint(Value) VALUES(-1);
END TRY
BEGIN CATCH
 SET @cause=ERROR_NUMBER();
END CATCH;
SELECT @before_count=@@TRANCOUNT,@before_state=XACT_STATE();
BEGIN TRY
 EXEC dbo.usp_P02ReadObservationBoundary;
END TRY
BEGIN CATCH
 SET @refusal=ERROR_NUMBER();
END CATCH;
SELECT @after_count=@@TRANCOUNT,@after_state=XACT_STATE();
IF @@TRANCOUNT>0 ROLLBACK;
SET XACT_ABORT OFF;
SELECT @cause AS cause,@refusal AS refusal,@before_count AS before_count,
@before_state AS before_state,@after_count AS after_count,@after_state AS after_state;"""
RANGE_SQL = """SET NOCOUNT ON; DECLARE @remaining bigint,@first sql_variant,@last sql_variant;
SELECT @remaining=CONVERT(bigint,9223372036854775807)-CONVERT(bigint,current_value)
FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration');
IF @remaining IS NULL OR @remaining<=0 THROW 51979,'Fresh nonexhausted fixture required.',1;
EXEC sys.sp_sequence_get_range @sequence_name=N'dbo.P02ObservationGeneration',
 @range_size=@remaining,@range_first_value=@first OUTPUT,@range_last_value=@last OUTPUT;
SELECT CONVERT(bigint,@first) AS first_value,CONVERT(bigint,@last) AS last_value;"""
SEQUENCE_SQL = """SELECT object_id,create_date,modify_date,
CONVERT(bigint,current_value) AS generation,is_exhausted
FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration')"""
MUTATIONS = {
    "role-create": "CREATE ROLE P02EdgeRole",
    "role-membership": "ALTER ROLE P02EdgeRole ADD MEMBER P02EdgeUser",
    "object-permission": "GRANT SELECT ON OBJECT::dbo.P02EdgeConstraint TO P02EdgeRole",
}
HEALTH = (
    (
        "missing-row-invalidator",
        "DROP TRIGGER dbo.tr_P02HeaderObservation",
        "dbo.tr_P02HeaderObservation.Trigger.sql",
    ),
    (
        "changed-row-invalidator",
        "CREATE OR ALTER TRIGGER dbo.tr_P02HeaderObservation ON dbo.KVKFinalReportHeader AFTER INSERT,UPDATE,DELETE AS BEGIN SET NOCOUNT ON; END;",
        "dbo.tr_P02HeaderObservation.Trigger.sql",
    ),
    (
        "missing-ddl-invalidator",
        "DROP TRIGGER tr_P02CatalogueObservation ON DATABASE",
        "tr_P02CatalogueObservation.DatabaseTrigger.sql",
    ),
)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_packet(packet, manifest):
    name = manifest.get("database", "")
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest.get("purpose") != PURPOSE
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("production_eligible") is not False
        or manifest.get("business_operations") != 0
        or manifest.get("maintenance_dispatches") != 0
        or manifest.get("enable_application_login") is not False
        or not re.fullmatch(r"K98_P02Observer_[0-9]{17}", name)
        or manifest.get("guest_directory")
        != "Q:\\P02Observer\\" + name.removeprefix("K98_P02Observer_")
        or packet.resolve() != Path(manifest["guest_directory"]).resolve()
    ):
        raise ValueError("Exact new isolated protocol fixture required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed protocol member changed")


def authenticate(packet, manifest):
    import retained_reader_state

    raw = (packet / "evidence/publisher-success.json").read_bytes()
    if (
        sha(raw) != PRIOR_SHA
        or raw != (PRIOR / "receipt.json").read_bytes()
        or sha((PRIOR / "packet.zip").read_bytes()) != ARCHIVE_SHA
    ):
        raise ValueError("Exact completed publisher receipt and archive required")
    latest = json.loads(raw)
    wanted = dict(
        outcome="passed",
        first_failure=None,
        cleanup_failures=[],
        original_preserved=True,
        login_disabled=True,
        physical_custody_retained=False,
    )
    if any(latest.get(k) != v for k, v in wanted.items()):
        raise ValueError("Latest publisher must be settled")
    prior, old_manifest, _ = retained_reader_state.authenticate(packet, manifest)
    return latest, prior, old_manifest


def preserved(packet, manifest, record, save, expected, *, fixture=None):
    import business_overlap_state as completed
    from fixed_contract_cost import SERVICES_SQL
    from fresh_business import require_login
    import fresh_business_state as state
    from publisher_baseline import owned
    import publisher_state
    from restart_read import require_services

    latest, prior, old_manifest = expected
    value = {}
    with owned("master", record, save) as owner:
        state.require_identity(owner.read(state.IDENTITY), "master", 1)
        require_login(owner.read)
        require_services(owner.read(SERVICES_SQL))
        if owner.read(state.SESSIONS) or owner.read(state.LOCKS):
            raise ValueError("Foreign application activity prevents qualification")
        databases = state.normalized(owner.read(state.DATABASES))
        added = [r for r in databases if r not in latest["databases_after"]]
        if added != ([] if fixture is None else [fixture]):
            raise ValueError("Only the acknowledged new fixture may be added")
        if [r for r in databases if r not in added] != latest["databases_after"]:
            raise ValueError("A retained database identity changed")
        value["databases"] = latest["databases_after"]
        value["files"] = state.normalized(owner.read(state.FILE_IDENTITIES))
        if value["files"] != prior["files_before"]:
            raise ValueError("Retained database files changed")
    with owned(state.RETAINED, record, save) as owner:
        value["original"] = state.original_state(
            owner, latest["original_after"]["state"], state.RETAINED
        )
        if value["original"] != latest["original_after"]:
            raise ValueError("Original claim changed")
    with owned("ROK_TRACKER", record, save) as owner:
        value["completed"] = completed.require_fresh(owner, prior, old_manifest)
        if value["completed"] != latest["completed_after"]:
            raise ValueError("Completed captures/migrations changed")
        current = publisher_state.read(owner)
        # Log-use measurements are informative, not logical business equality.
        value["publisher"] = {k: v for k, v in current.items() if k != "log"}
        if value["publisher"] != {
            k: v for k, v in latest["publisher_coexistence"]["settled_state"].items() if k != "log"
        }:
            raise ValueError("Completed publisher/maintenance changed")
    return value


def fixture_owner(name, record, save, *, autocommit=True):
    from fresh_business_owner import HELD, SqlOwner
    import pyodbc

    if not re.fullmatch(r"K98_P02Observer_[0-9]{17}", name) or type(autocommit) is not bool:
        raise ValueError("Only the newly owned fixture may be mutated")
    # Reuse the audited cursor/close implementation; extend no production owner allowlist.
    owner = SqlOwner.__new__(SqlOwner)
    owner.record, owner.save, owner.cursors = record, save, []
    owner.connection, owner.close_attempted = None, False
    owner.connection = pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;DATABASE="
        + name
        + ";Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;APP=P02ProtocolEdges;",
        autocommit=autocommit,
        timeout=3,
    )
    HELD.append(owner)
    owner.connection.timeout = 3
    return owner


@contextmanager
def owned_fixture(name, record, save, *, autocommit=True):
    owner = fixture_owner(name, record, save, autocommit=autocommit)
    first = None
    try:
        yield owner
    except BaseException as error:
        first = error
        raise
    finally:
        try:
            # Qualification owns these transactions, never a business/caller transaction.
            # One rollback attempt before close; retain the handle if it is unacknowledged.
            if owner.cursors or owner.close_attempted:
                raise ValueError("Retain unresolved fixture cursor/connection")
            if owner.connection.autocommit:
                owner.read("IF @@TRANCOUNT>0 ROLLBACK")
            else:
                owner.connection.rollback()
            owner.close()
        except BaseException as error:
            record["cleanup_failures"].append(
                dict(operation="fixture rollback/close", error_type=type(error).__name__)
            )
            if first is None:
                raise
            first.add_note("Fixture cleanup unacknowledged; original native handle retained.")


def boundary(owner):
    from services.catalogue_observation_contract import reviewed_protocol_modules
    from services.catalogue_observation_dal import read_boundary

    if owner.cursors or owner.close_attempted:
        raise ValueError("Settled fixture cursor required")
    cursor = owner.connection.cursor()
    owner.cursors.append(cursor)
    first = None
    try:
        owner.record["boundary_reads"] = owner.record.get("boundary_reads", 0) + 1
        return read_boundary(cursor, reviewed_protocol_modules())
    except BaseException as error:
        first = error
        raise
    finally:
        try:
            cursor.close()
            owner.cursors.remove(cursor)
        except BaseException as error:
            owner.record["cleanup_failures"].append(
                dict(operation="boundary cursor close", error_type=type(error).__name__)
            )
            if first is None:
                raise


def require_refusal(action, *, code=None, contract=False):
    from scripts.verify_k98_running_release import sql_error_facts
    from services.catalogue_observation_dal import ObservationContractError

    try:
        action()
    except Exception as error:
        facts = sql_error_facts(error)
        if contract and isinstance(error, ObservationContractError):
            return facts
        native = sorted(
            {
                int(n)
                for arg in getattr(error, "args", ())[1:5]
                if isinstance(arg, str)
                for n in re.findall(r"\((\d+)\)", arg[:8192])
            }
        )
        if code is not None and getattr(error, "args", (None,))[0] == "42000" and code in native:
            return dict(facts, native_numbers=native)
        raise
    raise AssertionError("Unsupported native state was accepted")


def batches(packet, name):
    return [
        b
        for b in re.split(r"(?im)^GO\s*$", (packet / "sql" / name).read_text(encoding="utf-8-sig"))
        if b.strip()
    ]


def install(packet, manifest, record, save):
    import fresh_business_state as state
    from publisher_baseline import owned

    name = manifest["database"]
    with owned("master", record, save) as owner:
        if owner.read("SELECT DB_ID(?) AS database_id", name) != [{"database_id": None}]:
            raise ValueError("New fixture database already exists")
        paths = owner.read(
            "SELECT CONVERT(nvarchar(260),SERVERPROPERTY('InstanceDefaultDataPath')) AS data_path,CONVERT(nvarchar(260),SERVERPROPERTY('InstanceDefaultLogPath')) AS log_path"
        )
        if len(paths) != 1 or not all(paths[0].values()):
            raise ValueError("Actual isolated SQL data/log directories required")
        data = str(Path(paths[0]["data_path"]) / (name + ".mdf"))
        log = str(Path(paths[0]["log_path"]) / (name + ".ldf"))
        if Path(data).exists() or Path(log).exists():
            raise ValueError("New fixture files already exist")
        record["fixture_files"] = [data, log]
        if "'" in data + log:
            raise ValueError("Invalid fixed fixture path")
        sql = (
            f"CREATE DATABASE [{name}] ON PRIMARY (NAME=N'{name}',FILENAME=N'{data}',"
            "SIZE=64MB,MAXSIZE=512MB,FILEGROWTH=32MB) "
            f"LOG ON (NAME=N'{name}_log',FILENAME=N'{log}',SIZE=32MB,MAXSIZE=256MB,FILEGROWTH=32MB)"
        )
        owner.mutate("create only new edge fixture", sql)
        identity = [r for r in state.normalized(owner.read(state.DATABASES)) if r["name"] == name]
        if len(identity) != 1 or identity[0]["source_database_id"] is not None:
            raise ValueError("One new ordinary database identity required")
        record["fixture"] = identity[0]
        save()
        owner.mutate("new fixture recovery", f"ALTER DATABASE [{name}] SET RECOVERY SIMPLE")
    with owned_fixture(name, record, save) as owner:
        owner.mutate("new fixture controls", FIXTURE_SQL)
        for name in manifest["install_sources"]:
            for i, sql in enumerate(batches(packet, name)):
                owner.mutate("install fixture source " + name + ":" + str(i), sql)
        value = boundary(owner)
        return dict(identity=value.identity, generation=value.generation)


def cases(packet, manifest, record, save, *, completed=()):
    if completed not in ((), ("nested-preserved-autocommit-True",)):
        raise ValueError("Only the authenticated first nested case may be retained")
    name = manifest["database"]

    def check(label, action):
        if label in completed:
            return
        row = dict(name=label, passed=False)
        record["checks"].append(row)
        record["stage"] = label
        save()
        started = time.monotonic()
        row["facts"] = action()
        row.update(passed=True, seconds=time.monotonic() - started)
        save()

    # The Python DAL must leave an unsupported borrowed nested transaction intact.
    for autocommit in (True, False):

        def nested(autocommit=autocommit):
            with owned_fixture(name, record, save, autocommit=autocommit) as owner:
                owner.read("IF @@TRANCOUNT=0 BEGIN TRANSACTION; BEGIN TRANSACTION;")
                before = owner.read(STATE_SQL)
                record["checks"][-1]["observed"] = {"before": before}
                save()
                if before[0]["transaction_count"] != 2 or before[0]["transaction_state"] != 1:
                    raise ValueError("Expected native nested transaction was not established")
                error = require_refusal(lambda: boundary(owner), code=51971)
                after = owner.read(STATE_SQL)
                record["checks"][-1]["observed"]["after"] = after
                save()
                if before != after or owner.connection.autocommit is not autocommit:
                    raise ValueError("Borrowed nested state was repaired or changed")
                return dict(before=before, after=after, error=error, autocommit=autocommit)

        check("nested-preserved-autocommit-" + str(autocommit), nested)

        def doomed(autocommit=autocommit):
            with owned_fixture(name, record, save, autocommit=autocommit) as owner:
                rows = owner.read(DOOM_SQL)
                record["checks"][-1]["observed"] = rows
                save()
                expected = dict(
                    cause=547,
                    refusal=51971,
                    before_count=1,
                    before_state=-1,
                    after_count=1,
                    after_state=-1,
                )
                if rows != [expected] or owner.connection.autocommit is not autocommit:
                    raise ValueError("Native doomed transaction was not refused unchanged")
                return dict(
                    native=rows[0],
                    autocommit=autocommit,
                    scope="Actual SQL boundary inside the owning batch; batch-end rollback is not caller repair",
                )

        check("doomed-preserved-autocommit-" + str(autocommit), doomed)

    with owned_fixture(name, record, save) as owner:
        for label, sql in MUTATIONS.items():

            def event(sql=sql):
                before = boundary(owner)
                owner.mutate("new fixture event", sql)
                after = boundary(owner)
                if after.generation <= before.generation:
                    raise ValueError("DDL event failed to advance observation")
                return dict(before=before.generation, after=after.generation)

            check(label + "-invalidates", event)

        for label, sql, source in HEALTH:

            def health(sql=sql, source=source):
                owner.mutate("new fixture unhealthy invalidator", sql)
                failure = require_refusal(lambda: boundary(owner), contract=True)
                for batch in batches(packet, source):
                    owner.mutate("restore only fixture invalidator", batch)
                current = boundary(owner)
                return dict(failure=failure, restored_generation=current.generation)

            check(label, health)

        def recreated():
            from services.catalogue_observation_dal import require_same_catalogue

            before = boundary(owner)
            denied = require_refusal(
                lambda: owner.read("DROP SEQUENCE dbo.P02ObservationGeneration"), code=51970
            )
            owner.mutate(
                "drain new fixture protocol", "DROP TRIGGER tr_P02CatalogueObservation ON DATABASE"
            )
            owner.mutate(
                "replace only new fixture sequence", "DROP SEQUENCE dbo.P02ObservationGeneration"
            )
            for source in (
                "dbo.P02ObservationGeneration.Sequence.sql",
                "tr_P02CatalogueObservation.DatabaseTrigger.sql",
            ):
                for batch in batches(packet, source):
                    owner.mutate("new fixture replacement source", batch)
            after = boundary(owner)
            refusal = require_refusal(lambda: require_same_catalogue(before, after), contract=True)
            return dict(
                protection=denied,
                before=before.identity,
                after=after.identity,
                stale_refusal=refusal,
            )

        check("new-incarnation-rejects-old-proof", recreated)

        def exhausted():
            result = owner.read(RANGE_SQL)
            record["checks"][-1]["observed_range"] = result
            save()
            if len(result) != 1 or result[0]["last_value"] != 2**63 - 1:
                raise ValueError("Exact terminal sequence range not allocated")
            native = owner.read(SEQUENCE_SQL)
            record["checks"][-1]["observed_sequence"] = native
            save()
            if len(native) != 1 or native[0]["is_exhausted"] is not True:
                raise ValueError("Native sequence did not report exhaustion")
            failure = require_refusal(lambda: boundary(owner), contract=True)
            return dict(range=result, sequence=native, refusal=failure, fixture_left_exhausted=True)

        check("exhausted-sequence-refuses-observation", exhausted)


def run(
    packet,
    manifest,
    *,
    resume_loader=None,
    resume_verifier=None,
    authenticator=None,
    case_runner=None,
):
    from fresh_business_owner import HELD
    from independent_readers import write_new

    from scripts.verify_k98_running_release import sql_error_facts

    record = dict(
        schema="p02-protocol-edges/1",
        outcome="running",
        started=datetime.now(UTC).isoformat(),
        stage="authenticate completed work",
        checks=[],
        actions=[],
        first_failure=None,
        cleanup_failures=[],
        admin_dispatches=0,
        admin_seconds=0.0,
        admin_connections_closed=0,
        business_operations=0,
        maintenance_dispatches=0,
        production_operations=0,
        provider_operations=0,
        login_enable_attempted=False,
        login_disabled=None,
        original_preserved=False,
        preservation_failure=None,
        physical_custody_retained=False,
        fixture=None,
    )

    def save():
        pending = packet / "progress.pending"
        pending.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")
        pending.replace(packet / "progress.json")

    write_new(packet / "entered.json", dict(pid=os.getpid(), started=record["started"]))
    expected = None
    try:
        expected = (authenticator or authenticate)(packet, manifest)
        previous = None if resume_loader is None else resume_loader(packet, manifest, record, save)
        record["before"] = preserved(
            packet, manifest, record, save, expected, fixture=record["fixture"]
        )
        record["login_disabled"] = True
        if previous is None:
            record["installed"] = install(packet, manifest, record, save)
            completed = ()
        else:
            if resume_verifier is None:
                raise ValueError("Exact retained fixture verifier required")
            resume_verifier(packet, manifest, record, save, previous)
            record["installed"] = previous["installed"]
            completed = ("nested-preserved-autocommit-True",)
        (case_runner or cases)(packet, manifest, record, save, completed=completed)
        record["outcome"] = "passed"
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, (ValueError, AssertionError)):
            record["first_failure"]["detail"] = str(error)[:500]
    finally:
        if expected is not None and not HELD:
            try:
                record["after"] = preserved(
                    packet, manifest, record, save, expected, fixture=record["fixture"]
                )
                # preserved() independently checks the authenticated completed receipts.
                # Absence of this run's first snapshot is not evidence of changed work.
                record["preservation_basis"] = (
                    "same-run-and-authenticated-completed-receipts"
                    if "before" in record
                    else "authenticated-completed-receipts"
                )
                record["original_preserved"] = (
                    "before" not in record or record["before"] == record["after"]
                )
                record["login_disabled"] = True
                if not record["original_preserved"]:
                    raise ValueError("Preserved business state differs")
            except BaseException as error:
                record["preservation_failure"] = dict(
                    operation="final preservation", **sql_error_facts(error)
                )
                if isinstance(error, (ValueError, AssertionError)):
                    record["preservation_failure"]["detail"] = str(error)[:500]
                if record["first_failure"] is None:
                    record["first_failure"] = dict(
                        stage="final preservation", **record["preservation_failure"]
                    )
        record["physical_custody_retained"] = bool(HELD)
        if HELD or record["cleanup_failures"] or record["preservation_failure"]:
            record["outcome"] = "failed"
        record["finished"] = datetime.now(UTC).isoformat()
        save()
        write_new(packet / "receipt.json", record)
    if HELD:
        print("Native fixture handles retained; collect without replay.", flush=True)
        while HELD:
            time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    require_packet(packet, manifest)
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    return run(packet, manifest)


if __name__ == "__main__":
    raise SystemExit(main())
