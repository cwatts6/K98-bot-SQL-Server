"""Preserve the existing D5e fixture, install candidate sources, prove reader overlap.

No queued preparation, import, provider operation or maintenance job is invoked.
This is representative mechanism evidence, not protected contract acceptance.
"""

from collections import Counter
from contextlib import closing
from datetime import UTC, datetime
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
manifest = json.loads((PACKET / "manifest.json").read_bytes())
DATABASE = "K98_P025_D5e_Cost_20261115"
if (
    os.environ.get("COMPUTERNAME") != "MINI_AMD"
    or manifest["database"] != DATABASE
    or manifest["stage"]
    not in {
        "representative-install-and-recovery",
        "representative-reader-resume",
        "representative-cost-read",
        "representative-batched-cost-read",
        "representative-query-correction",
        "representative-columns-correction",
        "representative-complete-cost-read",
        "representative-identity-correction",
        "representative-publisher-overlap",
        "representative-publisher-final-read",
        "representative-combined-read",
        "representative-combined-categories",
    }
    or not re.fullmatch(r"K98_P02Observer_D5eBefore_[0-9]{17}", manifest["snapshot"])
):
    raise RuntimeError("Exact isolated representative fixture required")
for name, expected_hash in manifest["files"].items():
    path = PACKET / name
    if (
        not path.resolve().is_relative_to(PACKET)
        or hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash
    ):
        raise RuntimeError("Sealed member differs: " + name)

import pyodbc

from core.recovery_sql_snapshot import recovery_snapshot
from core.sql_connection_custody import connection_retained, retain_connection
from scripts.inspect_p02_observer_query_plans import PLAN_SQL
from services.application_maintenance_contract import POLICY
from services.application_maintenance_dal import coherent_maintenance_snapshot
from services.catalogue_observation_dal import (
    BOUNDARY_SQL,
    canonical_module,
    observe_catalogue,
    read_boundary,
)
from services.catalogue_observation_query_dal import (
    CATALOGUE_BATCH_QUERIES,
    IDENTITY_BATCH_QUERIES,
)
from services.export_execution_dal import (
    _METADATA_QUERIES,
    _application_scoped_rows,
    application_installation_snapshot,
)
from services.export_schema_fingerprint import FORMAT, application_metadata_fingerprint

pyodbc.pooling = False
BASE = "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;DATABASE="
inventory = json.loads((PACKET / "evidence/representative-inventory.json").read_bytes())
prior = next(r for r in inventory["databases"] if r["database"] == DATABASE)
protocol = json.loads((PACKET / "source/protocol.json").read_bytes())
expected_modules = {row["name"]: row["definition"] for row in protocol["modules"]}
source_scope = json.loads((PACKET / "source/activation-scope.json").read_bytes())
scope = sorted(set(source_scope["objects"]) | {"dbo.EXCEL_FOR_KVK_16"})
assert len(scope) == 484 and set(source_scope["objects"]) <= set(scope)
approved_shape = {
    "version": 3,
    "maintenance_policy": POLICY,
    "d4_installation": "20261111_001_p02_d4_combined",
    "dynamic_objects": [
        {
            "name": "dbo.EXCEL_FOR_KVK_16",
            "type": "U",
            "producer_modules": ["dbo.sp_ExcelOutput_ByKVK"],
        }
    ],
}
receipt = dict(
    schema="p02-observer-representative/1",
    database=DATABASE,
    started=datetime.now(UTC).isoformat(),
    checks=[],
    production_operations=0,
    business_operations=0,
    connections_closed=0,
    scope_limit="Representative full collector and real recovery reader; no protected contract acceptance, publisher or maintenance qualification inferred.",
)
connections = []


def write_json(name, value):
    with (PACKET / name).open("x", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, default=str)


class Connection:
    def __init__(self, raw):
        object.__setattr__(self, "raw", raw)
        object.__setattr__(self, "closed", False)

    def __getattr__(self, name):
        return getattr(self.raw, name)

    def __setattr__(self, name, value):
        setattr(self.raw, name, value)

    def close(self):
        self.raw.close()
        object.__setattr__(self, "closed", True)
        receipt["connections_closed"] += 1


def connect(database=DATABASE, *, application=False, manual=False):
    assert database in {DATABASE, "master"}
    connection = Connection(pyodbc.connect(BASE + database, autocommit=True, timeout=5))
    connections.append(connection)
    connection.timeout = 15
    sql(
        connection,
        "SET LOCK_TIMEOUT 0; SET TRANSACTION ISOLATION LEVEL READ COMMITTED; SET NOCOUNT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON",
    )
    if application:
        sql(connection, "EXECUTE AS LOGIN='S11_ExportApplication_P02Qual'")
        connection.timeout = 3
    connection.autocommit = not manual
    return connection


def sql(connection, statement, *parameters):
    with closing(connection.cursor()) as cursor:
        cursor.execute(statement, *parameters)
        result = []
        while True:
            if cursor.description:
                keys = [column[0] for column in cursor.description]
                result.extend(dict(zip(keys, row, strict=True)) for row in cursor.fetchall())
            if not cursor.nextset():
                break
        return result


def normalized(value):
    return json.loads(json.dumps(value, default=str))


def check(name, action):
    started = time.perf_counter()
    print("START " + name, flush=True)
    try:
        facts = action()
    except BaseException as error:
        receipt["checks"].append(
            dict(
                name=name,
                passed=False,
                seconds=time.perf_counter() - started,
                error=type(error).__name__,
                detail=str(error)[:2000],
            )
        )
        raise
    receipt["checks"].append(
        dict(name=name, passed=True, seconds=time.perf_counter() - started, facts=facts)
    )
    (PACKET / "progress.json").write_text(
        json.dumps(receipt, indent=2, default=str), encoding="utf-8"
    )
    print("PASS " + name, flush=True)


def business_state(connection):
    return {
        "maintenance": sql(connection, "SELECT * FROM dbo.MaintenanceWork ORDER BY Kind"),
        "kvk_work": sql(connection, "SELECT * FROM dbo.MaintenanceKvkWork ORDER BY KVKNo"),
        "headers": sql(connection, "SELECT * FROM dbo.KVKFinalReportHeader ORDER BY KVK_NO"),
        "preparations": sql(
            connection,
            "SELECT State,COUNT_BIG(*) AS [RowCount] FROM dbo.ExportPreparation GROUP BY State ORDER BY State",
        ),
        "imports": sql(
            connection,
            "SELECT State,COUNT_BIG(*) AS [RowCount] FROM dbo.StatsImportExecution GROUP BY State ORDER BY State",
        ),
    }


def preflight_and_preserve():
    admin = connect()
    target = sql(
        admin,
        "SELECT DB_NAME() AS DatabaseName,DB_ID() AS DatabaseID,create_date,collation_name,compatibility_level,state_desc,is_read_only,snapshot_isolation_state_desc,is_read_committed_snapshot_on,source_database_id FROM sys.databases WHERE database_id=DB_ID()",
    )
    assert len(target) == 1 and all(
        normalized(target[0][k]) == prior["target"][0][k] for k in target[0]
    )
    files = sql(
        admin,
        "SELECT file_id,name,type_desc,physical_name FROM sys.database_files ORDER BY file_id",
    )
    assert files == [{k: row[k] for k in files[0]} for row in prior["files"]]
    assert (
        sql(
            admin,
            "SELECT session_id FROM sys.dm_exec_sessions WHERE is_user_process=1 AND database_id=DB_ID() AND session_id<>@@SPID",
        )
        == []
    )
    existing_observer = sql(
        admin,
        "SELECT object_id FROM sys.objects WHERE name IN (SELECT value FROM OPENJSON(?)) UNION ALL SELECT object_id FROM sys.triggers WHERE parent_class=0 AND name='tr_P02CatalogueObservation'",
        json.dumps(sorted({*expected_modules, "P02ObservationGeneration"})),
    )
    assert existing_observer == [], existing_observer
    assert (
        sql(
            admin,
            "SELECT name FROM sys.database_principals WHERE sid=SUSER_SID('S11_ExportApplication_P02Qual') OR name='S11_ExportApplication_P02Qual'",
        )
        == []
    )
    actor = sql(
        admin,
        "SELECT LOWER(CONVERT(varchar(170),sid,2)) AS LoginSID,is_disabled,IS_SRVROLEMEMBER('sysadmin',name) AS Sysadmin FROM sys.server_principals WHERE name='S11_ExportApplication_P02Qual'",
    )
    assert actor == [
        dict(LoginSID="a00eddaa8c5045558e818cebb113d52e", is_disabled=False, Sysadmin=0)
    ]
    for record in prior["selected_modules"]:
        actual = sql(
            admin,
            "SELECT s.name+'.'+o.name AS ObjectName,o.type,o.object_id,o.create_date,o.modify_date,m.definition,m.uses_ansi_nulls,m.uses_quoted_identifier,m.execute_as_principal_id FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id JOIN sys.sql_modules m ON m.object_id=o.object_id WHERE o.object_id=OBJECT_ID(?)",
            record["ObjectName"],
        )
        assert normalized(actual) == [record], record["ObjectName"]
    before = business_state(admin)
    assert (
        before["preparations"] == prior["preparation_states"]
        and before["imports"] == prior["import_states"]
    )
    assert all(
        r["State"] == "complete" and r["DueGeneration"] == r["CompletedGeneration"]
        for r in before["maintenance"] + before["kvk_work"]
    )
    write_json("representative-before.json", before)
    master = connect("master")
    assert (
        sql(master, "SELECT database_id FROM sys.databases WHERE name=?", manifest["snapshot"])
        == []
    )
    sql(master, (PACKET / "sql/preserve-d5e.sql").read_text())
    snapshot = sql(
        master,
        "SELECT name,source_database_id,state_desc,is_read_only FROM sys.databases WHERE name=?",
        manifest["snapshot"],
    )
    assert snapshot == [
        dict(
            name=manifest["snapshot"], source_database_id=11, state_desc="ONLINE", is_read_only=True
        )
    ]
    master.close()
    return admin, before, snapshot


def install(admin, before):
    sql(admin, "BEGIN TRANSACTION")
    try:
        for name in manifest["install_sources"]:
            for batch in re.split(r"(?im)^GO\s*$", (PACKET / name).read_text(encoding="utf-8-sig")):
                if batch.strip():
                    sql(admin, batch)
        for name, expected in manifest["root_definitions"].items():
            rows = sql(
                admin,
                "SELECT definition,uses_ansi_nulls,uses_quoted_identifier FROM sys.sql_modules WHERE object_id=OBJECT_ID(?)",
                name,
            )
            assert len(rows) == 1 and canonical_module(rows[0]["definition"]) == expected
            assert rows[0]["uses_ansi_nulls"] and rows[0]["uses_quoted_identifier"]
        assert business_state(admin) == before
        sql(admin, "COMMIT TRANSACTION")
    except BaseException as error:
        try:
            sql(admin, "IF @@TRANCOUNT>0 ROLLBACK TRANSACTION")
        except BaseException as cleanup:
            error.add_note("Installation rollback was not acknowledged: " + str(cleanup)[:1000])
            retain_connection(admin, effect="unknown", first_failure=error, cleanup_error=cleanup)
        raise
    # Both checks are outside installation's transaction and mutation marker.
    with closing(admin.cursor()) as cursor:
        boundary = read_boundary(cursor, expected_modules)
    assert business_state(admin) == before
    return dict(
        generation=boundary.generation,
        sequence_identity=boundary.identity[9:],
        source_batches=len(manifest["install_sources"]),
        new_lab_user="S11_ExportApplication_P02Qual",
        server_grants_changed=False,
        business_state_unchanged=True,
    )


class TimedCursor:
    """Measure native calls without changing SQL, parameters or result handling."""

    def __init__(self, cursor, records):
        self.cursor = cursor
        self.records = records
        self.current = None

    def __getattr__(self, name):
        return getattr(self.cursor, name)

    def _call(self, method, *args):
        started = time.perf_counter()
        try:
            value = getattr(self.cursor, method)(*args)
            if method == "fetchall":
                self.current["rows"] += len(value)
            elif method == "fetchone" and value is not None:
                self.current["rows"] += 1
            return value
        except BaseException as error:
            self.current["failure"] = type(error).__name__
            raise
        finally:
            elapsed = time.perf_counter() - started
            self.current["calls"].append(dict(method=method, seconds=elapsed))
            self.current["native_seconds"] += elapsed

    def execute(self, statement, *parameters):
        self.current = dict(
            ordinal=len(self.records) + 1,
            statement_sha256=hashlib.sha256(statement.encode()).hexdigest(),
            boundary=statement == BOUNDARY_SQL,
            embedded_boundary=statement.endswith("\n;" + BOUNDARY_SQL),
            native_seconds=0.0,
            rows=0,
            calls=[],
        )
        self.records.append(self.current)
        self._call("execute", statement, *parameters)
        return self

    def fetchone(self):
        return self._call("fetchone")

    def fetchall(self):
        return self._call("fetchall")

    def nextset(self):
        return self._call("nextset")

    def close(self):
        started = time.perf_counter()
        try:
            self.cursor.close()
        finally:
            if self.current is not None:
                self.current["cursor_close_seconds"] = time.perf_counter() - started


def observe(
    connection,
    hook=None,
    *,
    timings=None,
    observation_batches=False,
    hook_before_checkpoint=False,
    combined_boundaries=False,
):
    actual = connection.cursor()
    with closing(actual if timings is None else TimedCursor(actual, timings)) as owned_cursor:
        cursor = owned_cursor
        if combined_boundaries:
            from services.catalogue_observation_batch_dal import CatalogueBatchCursor

            cursor = CatalogueBatchCursor(owned_cursor)

        def collect(checkpoint):
            count = 0

            def bounded_checkpoint():
                nonlocal count
                if hook is not None and hook_before_checkpoint and count == 0:
                    hook()
                checkpoint()
                count += 1
                if hook is not None and not hook_before_checkpoint and count == 1:
                    hook()

            return application_installation_snapshot(
                cursor,
                scope=scope,
                metadata_format=FORMAT,
                checkpoint=bounded_checkpoint,
                observation_batches=observation_batches,
            )

        return coherent_maintenance_snapshot(cursor, approved_shape, expected_modules, collect)


def read_changed_catalogue_queries(
    connection,
    timings,
    *,
    columns_only=False,
    identity_only=False,
    identity_columns_only=False,
    objects_only=False,
    combined_only=False,
):
    with closing(TimedCursor(connection.cursor(), timings)) as owned_cursor:
        cursor = owned_cursor
        if combined_only:
            from services.catalogue_observation_batch_dal import CatalogueBatchCursor

            cursor = CatalogueBatchCursor(owned_cursor)

        def collect(checkpoint):
            selected = {"metadata.columns": None}
            if not columns_only:
                selected.update(CATALOGUE_BATCH_QUERIES)
            if identity_only:
                selected = IDENTITY_BATCH_QUERIES
            if identity_columns_only:
                selected = {"identity.columns": IDENTITY_BATCH_QUERIES["identity.columns"]}
            if objects_only:
                selected = {
                    "metadata.objects": "WITH required AS (SELECT OBJECT_ID(value) AS object_id FROM OPENJSON(?)) "
                    + _METADATA_QUERIES["objects"]
                }
            if combined_only:
                selected = {
                    "metadata.indexes": CATALOGUE_BATCH_QUERIES["metadata.indexes"],
                    "identity.default_constraints": IDENTITY_BATCH_QUERIES[
                        "identity.default_constraints"
                    ],
                }
            return {
                category: _application_scoped_rows(cursor, query, scope, checkpoint, category, True)
                for category, query in selected.items()
            }

        return observe_catalogue(cursor, expected_modules, collect)


def run():
    saved = []

    def preserve():
        saved.extend(preflight_and_preserve())
        return dict(
            snapshot=saved[2],
            inventory_sha256=manifest["inventory_sha256"],
            pending_work_replayed=False,
        )

    if manifest["stage"] != "representative-install-and-recovery":
        admin = connect()
        before = json.loads((PACKET / "evidence/representative-before.json").read_bytes())

        def reuse():
            assert sql(admin, "SELECT DB_ID() AS DatabaseID") == [dict(DatabaseID=11)]
            assert normalized(business_state(admin)) == before
            snapshots = sql(
                admin,
                "SELECT name,source_database_id,state_desc,is_read_only FROM sys.databases WHERE name=?",
                manifest["snapshot"],
            )
            assert snapshots == [
                dict(
                    name=manifest["snapshot"],
                    source_database_id=11,
                    state_desc="ONLINE",
                    is_read_only=True,
                )
            ]
            for name, expected in manifest["root_definitions"].items():
                rows = sql(
                    admin,
                    "SELECT definition,uses_ansi_nulls,uses_quoted_identifier FROM sys.sql_modules WHERE object_id=OBJECT_ID(?)",
                    name,
                )
                assert len(rows) == 1 and canonical_module(rows[0]["definition"]) == expected
                assert rows[0]["uses_ansi_nulls"] and rows[0]["uses_quoted_identifier"]
            with closing(admin.cursor()) as cursor:
                boundary = read_boundary(cursor, expected_modules)
            assert boundary.generation == manifest["reuse"]["generation"]
            assert normalized(boundary.identity[9:]) == manifest["reuse"]["sequence_identity"]
            return dict(
                generation=boundary.generation,
                snapshot=manifest["snapshot"],
                predecessor_receipt=manifest["reuse"]["receipt_sha256"],
                sql_installation_replayed=False,
                business_state_unchanged=True,
            )

        check("verified-installed-representative-fixture-without-reinstallation", reuse)
    else:
        check("preserved-representative-d5e-starting-state", preserve)
        admin, before, _ = saved
        check("atomic-candidate-source-and-lab-permission-install", lambda: install(admin, before))
    if manifest["stage"] == "representative-combined-categories":
        sys.path.insert(0, str(PACKET))
        from qualification.p02_observer.combined_read import prove_combined_categories

        prove_combined_categories(
            connect=connect,
            observe=read_changed_catalogue_queries,
            baseline=json.loads((PACKET / "evidence/combined-baseline.json").read_bytes()),
            write_json=write_json,
            check=check,
            receipt=receipt,
        )
        return
    if manifest["stage"] == "representative-combined-read":
        sys.path.insert(0, str(PACKET))
        from qualification.p02_observer.combined_read import prove_combined_read

        prove_combined_read(
            connect=connect,
            observe=observe,
            baseline=json.loads((PACKET / "evidence/combined-baseline.json").read_bytes()),
            write_json=write_json,
            check=check,
            receipt=receipt,
        )
        return
    if manifest["stage"] == "representative-publisher-final-read":
        sys.path.insert(0, str(PACKET))
        from qualification.p02_observer.publisher_overlap import finish_publisher_observation

        finish_publisher_observation(
            admin,
            json.loads((PACKET / "evidence/publisher-observer-first-output.json").read_bytes()),
            connect=connect,
            sql=sql,
            read_observation=observe,
            business_state=business_state,
            write_json=write_json,
            check=check,
            receipt=receipt,
            generation=manifest["reuse"]["generation"],
            expected_fingerprint=manifest["reuse"]["observed_fingerprint"],
        )
        return
    if manifest["stage"] == "representative-publisher-overlap":
        sys.path.insert(0, str(PACKET))
        from qualification.p02_observer.publisher_overlap import run_publisher_overlap

        prior_output = None
        if manifest.get("resume_after_actor_first"):
            prior_output = json.loads(
                (PACKET / "evidence/publisher-actor-first-output.json").read_bytes()
            )

            def remaining_object_cost():
                baseline = json.loads(
                    (PACKET / "evidence/publisher-actor-first-observation.json").read_bytes()
                )
                timings = []
                reader = connect(application=True)
                first = None
                try:
                    observed = read_changed_catalogue_queries(reader, timings, objects_only=True)
                except BaseException as error:
                    first = error
                    raise
                finally:
                    try:
                        reader.close()
                    except BaseException as cleanup:
                        retain_connection(
                            reader,
                            effect="none",
                            first_failure=first or cleanup,
                            cleanup_error=cleanup,
                        )
                        if first is not None:
                            first.add_note("Object-reader close not acknowledged: " + str(cleanup))
                        else:
                            raise
                write_json(
                    "publisher-object-read.json",
                    dict(
                        boundary=observed.boundary.__dict__, value=observed.value, timings=timings
                    ),
                )
                assert observed.boundary.generation == manifest["reuse"]["generation"]
                actual = normalized(observed.value["metadata.objects"])
                expected = baseline["value"]["metadata"]["objects"]
                assert Counter(json.dumps(r, sort_keys=True) for r in actual) == Counter(
                    json.dumps(r, sort_keys=True) for r in expected
                )
                assert len(actual) == 482 and len(timings) == 8
                assert sum(not r["boundary"] for r in timings) == 3
                maximum = max(r["native_seconds"] for r in timings)
                assert maximum <= 0.250, dict(maximum_query_seconds=maximum)
                return dict(
                    rows=482,
                    reads=3,
                    boundaries=5,
                    exact_parity=True,
                    maximum_query_seconds=maximum,
                    prior_publication_replayed=False,
                )

            check("remaining-object-read-parity-and-cost", remaining_object_cost)

        # observe() only collects metadata; it cannot call run() or this branch.
        # The proof also rejects a second entry before any publication dispatch.
        run_publisher_overlap(
            admin,
            before,
            connect=connect,
            sql=sql,
            read_observation=observe,
            business_state=business_state,
            write_json=write_json,
            check=check,
            receipt=receipt,
            publisher_contracts=json.loads(
                (PACKET / "source/publisher-contracts.json").read_bytes()
            ),
            prior_output=prior_output,
            initial_generation=manifest["reuse"]["generation"],
        )
        return
    observer = connect(application=True)
    if manifest["stage"] in {
        "representative-query-correction",
        "representative-columns-correction",
        "representative-identity-correction",
    }:
        columns_only = manifest["stage"] == "representative-columns-correction"
        identity_only = manifest["stage"] == "representative-identity-correction"
        identity_columns_only = identity_only and manifest.get("identity_columns_only", False)

        def changed_queries():
            timings = []
            completed = False
            started = time.perf_counter()
            try:
                value = read_changed_catalogue_queries(
                    observer,
                    timings,
                    columns_only=columns_only,
                    identity_only=identity_only,
                    identity_columns_only=identity_columns_only,
                )
                completed = True
            finally:
                elapsed = time.perf_counter() - started
                write_json(
                    "catalogue-timings.json",
                    dict(
                        complete=completed,
                        observation_seconds=elapsed,
                        statements=timings,
                        scope="Only the declared corrected categories; prior passing categories are not replayed.",
                    ),
                )
            write_json(
                "changed-catalogue-observation.json",
                dict(
                    boundary=value.boundary.__dict__,
                    value=value.value,
                ),
            )
            baseline = json.loads((PACKET / "evidence/native-observation.json").read_bytes())[
                "value"
            ]
            expected_categories = (
                {"metadata.columns"}
                if columns_only
                else {
                    "metadata.columns",
                    "metadata.indexes",
                    "identity.indexes",
                    "metadata.checks",
                }
            )
            if identity_only:
                expected_categories = {
                    "identity.columns",
                    "identity.default_constraints",
                    "identity.dependencies",
                }
            if identity_columns_only:
                expected_categories = {"identity.columns"}
            assert set(value.value) == expected_categories
            assert value.boundary.generation == 238
            for category, observed_rows in value.value.items():
                section, name = category.split(".")
                section = "schema_identity" if section == "identity" else section
                expected_rows = baseline[section][name]
                actual_counts = Counter(
                    json.dumps(row, sort_keys=True, separators=(",", ":"))
                    for row in normalized(observed_rows)
                )
                expected_counts = Counter(
                    json.dumps(row, sort_keys=True, separators=(",", ":")) for row in expected_rows
                )
                assert actual_counts == expected_counts, category
            assert normalized(business_state(admin)) == before
            ordinary = [r for r in timings if not r["boundary"]]
            boundaries = [r for r in timings if r["boundary"]]
            expected_count = (
                11 if identity_columns_only else 13 if identity_only else 56 if columns_only else 68
            )
            assert len(ordinary) == expected_count
            assert len(boundaries) == len(ordinary) + 2
            facts = dict(
                observation_seconds=elapsed,
                normal_statements=len(ordinary),
                boundary_statements=len(boundaries),
                max_catalogue_seconds=max(r["native_seconds"] for r in ordinary),
                max_boundary_seconds=max(r["native_seconds"] for r in boundaries),
                native_rows_and_multiplicities_equal=True,
                business_state_unchanged=True,
                categories={k: len(v) for k, v in value.value.items()},
                scope="Declared corrected categories only; complete-observer overlap/cost remains open.",
            )
            write_json("catalogue-cost-result.json", facts)
            assert (
                elapsed <= 15
                and facts["max_catalogue_seconds"] <= 0.250
                and facts["max_boundary_seconds"] <= 0.250
            ), facts
            return facts

        try:
            check(
                (
                    "identity-query-parity-and-cost"
                    if identity_only
                    else (
                        "decomposed-column-parity-and-cost"
                        if columns_only
                        else "four-corrected-catalogue-query-parity-and-cost"
                    )
                ),
                changed_queries,
            )
        finally:
            try:
                retained_plans = sql(admin, PLAN_SQL)
                write_json(
                    "catalogue-query-plans.json",
                    dict(
                        rows=retained_plans,
                        possibly_truncated=len(retained_plans) == 96,
                        scope="Read existing retained plans after the focused proof; no test replay or cache change.",
                    ),
                )
            except Exception as error:
                receipt.setdefault("diagnostic_errors", []).append(str(error)[:2000])
        return
    if manifest["stage"] in {
        "representative-cost-read",
        "representative-batched-cost-read",
        "representative-complete-cost-read",
    }:

        def cost_read():
            timings = []
            started = time.perf_counter()
            completed = False
            try:
                value = observe(
                    observer,
                    timings=timings,
                    observation_batches=manifest["stage"] != "representative-cost-read",
                )
                completed = True
            finally:
                elapsed = time.perf_counter() - started
                write_json(
                    "catalogue-timings.json",
                    dict(
                        complete=completed,
                        observation_seconds=elapsed,
                        statements=timings,
                        limit="Native execute/fetch/completion timings exclude Python processing, JSON writing and fingerprint comparison; observation_seconds includes Python and cursor close.",
                    ),
                )
            assert value.boundary.generation == 238
            assert (
                application_metadata_fingerprint(
                    value.value["metadata"], value.value["schema_identity"]
                )
                == manifest["reuse"]["observed_fingerprint"]
            )
            assert normalized(business_state(admin)) == before
            if manifest["stage"] != "representative-cost-read":
                write_json(
                    "representative-observation.json",
                    dict(
                        boundary=value.boundary.__dict__,
                        value=value.value,
                    ),
                )
                previous = json.loads((PACKET / "evidence/native-observation.json").read_bytes())[
                    "value"
                ]
                actual = normalized(value.value)
                assert actual.keys() == previous.keys()

                def canonical_rows(rows):
                    return Counter(
                        json.dumps(row, sort_keys=True, separators=(",", ":")) for row in rows
                    )

                for section in ("metadata", "schema_identity"):
                    assert actual[section].keys() == previous[section].keys()
                    for category in previous[section]:
                        assert canonical_rows(actual[section][category]) == canonical_rows(
                            previous[section][category]
                        ), (section, category)
                for section in actual.keys() - {"metadata", "schema_identity"}:
                    assert actual[section] == previous[section], section
            ordinary = [r for r in timings if not r["boundary"]]
            boundaries = [r for r in timings if r["boundary"]]
            batched = manifest["stage"] != "representative-cost-read"
            assert len(ordinary) == (124 if batched else 23)
            assert len(boundaries) == (126 if batched else 25)
            facts = dict(
                observation_seconds=elapsed,
                normal_statements=len(ordinary),
                boundary_statements=len(boundaries),
                max_catalogue_seconds=max(r["native_seconds"] for r in ordinary),
                max_boundary_seconds=max(r["native_seconds"] for r in boundaries),
                native_seconds=sum(r["native_seconds"] for r in timings),
                same_observed_fingerprint=True,
                native_row_and_permission_parity=True if batched else None,
                business_state_unchanged=True,
            )
            write_json("catalogue-cost-result.json", facts)
            assert elapsed <= 15, facts
            assert (
                facts["max_catalogue_seconds"] <= 0.250 and facts["max_boundary_seconds"] <= 0.250
            ), facts
            return facts

        try:
            check("representative-per-statement-cost-gate", cost_read)
        finally:
            try:
                retained_plans = sql(admin, PLAN_SQL)
                write_json(
                    "catalogue-query-plans.json",
                    dict(
                        rows=retained_plans,
                        possibly_truncated=len(retained_plans) == 96,
                        scope="Existing retained plans after the full read; no test replay or cache change.",
                    ),
                )
            except Exception as error:
                receipt.setdefault("diagnostic_errors", []).append(str(error)[:2000])
        return
    baseline = []

    def full_read():
        value = observe(observer)
        baseline.append(value)
        write_json(
            "representative-observation.json",
            dict(boundary=value.boundary.__dict__, value=value.value),
        )
        assert value.value["target"]["DatabaseName"] == DATABASE
        assert value.value["target"]["Principal"] == "S11_ExportApplication_P02Qual"
        actual_scope = {row["ObjectName"] for row in value.value["metadata"]["objects"]}
        actual_scope |= {row["TypeName"] for row in value.value["metadata"]["table_types"]}
        assert actual_scope == set(scope), dict(
            missing=sorted(set(scope) - actual_scope), extra=sorted(actual_scope - set(scope))
        )
        fingerprint = application_metadata_fingerprint(
            value.value["metadata"], value.value["schema_identity"]
        )
        return dict(
            generation=value.boundary.generation,
            metadata_rows={k: len(v) for k, v in value.value["metadata"].items()},
            observed_fingerprint=fingerprint,
            approval_inferred=False,
            statement_timeout_seconds=observer.timeout,
        )

    check("representative-whole-catalogue-observation", full_read)

    def recovery_read():
        return recovery_snapshot(lambda: connect(application=True, manual=True))

    def recovery_facts(cursor):
        cursor.execute(
            "SELECT @@SPID,@@TRANCOUNT,XACT_STATE(),APPLOCK_MODE('public','K98:maintenance-schema:v1','Transaction'),COUNT_BIG(*) FROM dbo.ExportPreparation"
        )
        row = tuple(cursor.fetchone())
        assert row[1:4] == (1, 1, "Shared") and row[4] == 6965
        return row

    def reader_first():
        with recovery_read() as cursor:
            facts = recovery_facts(cursor)
            current = observe(observer)
            assert current.boundary == baseline[0].boundary
            assert current.boundary.identity[5] != facts[0]
            assert recovery_facts(cursor) == facts
        return dict(
            recovery_session=facts[0],
            observer_session=current.boundary.identity[5],
            generation=current.boundary.generation,
            recovery_cleanup="acknowledged",
        )

    check("recovery-first-whole-observer-coexists", reader_first)

    def observer_first():
        facts = []

        def enter_recovery():
            with recovery_read() as cursor:
                facts.append(recovery_facts(cursor))

        current = observe(observer, enter_recovery)
        assert len(facts) == 1 and current.boundary == baseline[0].boundary
        assert current.boundary.identity[5] != facts[0][0]
        assert normalized(business_state(admin)) == normalized(before)
        return dict(
            recovery_session=facts[0][0],
            observer_session=current.boundary.identity[5],
            entered_after_consumed_batch=1,
            generation=current.boundary.generation,
            recovery_cleanup="acknowledged",
            business_state_unchanged=True,
        )

    check("observer-first-real-recovery-enters-between-batches", observer_first)


try:
    run()
    receipt["outcome"] = (
        "representative-publisher-overlap-passed"
        if manifest["stage"] == "representative-publisher-overlap"
        else (
            "representative-query-correction-passed"
            if manifest["stage"]
            in {
                "representative-query-correction",
                "representative-columns-correction",
                "representative-identity-correction",
            }
            else (
                "representative-cost-read-passed"
                if manifest["stage"]
                in {
                    "representative-cost-read",
                    "representative-batched-cost-read",
                    "representative-complete-cost-read",
                }
                else "representative-reader-cases-passed"
            )
        )
    )
    if manifest["stage"] == "representative-publisher-final-read":
        receipt["outcome"] = "representative-publisher-poststate-passed"
    if manifest["stage"] == "representative-combined-read":
        receipt["outcome"] = "representative-combined-read-passed"
    if manifest["stage"] == "representative-combined-categories":
        receipt["outcome"] = "representative-combined-categories-passed"
except BaseException as error:
    receipt["outcome"] = "failed"
    receipt["first_failure"] = dict(
        type=type(error).__name__, detail=str(error)[:2000], traceback=traceback.format_exc()
    )
finally:
    for connection in reversed(connections):
        if connection.closed:
            continue
        if connection_retained(connection) or connection_retained(connection.raw):
            receipt["outcome"] = "cleanup-unknown"
            receipt.setdefault("cleanup_errors", []).append("Physical SQL custody retained")
            continue
        try:
            connection.close()
        except BaseException as error:
            receipt["outcome"] = "cleanup-unknown"
            receipt.setdefault("cleanup_errors", []).append(str(error)[:1000])
    receipt["finished"] = datetime.now(UTC).isoformat()
    write_json("receipt.json", receipt)
print(
    json.dumps(dict(outcome=receipt["outcome"], checks=len(receipt["checks"]), database=DATABASE)),
    flush=True,
)
sys.exit(
    0
    if receipt["outcome"]
    in {
        "representative-reader-cases-passed",
        "representative-cost-read-passed",
        "representative-query-correction-passed",
        "representative-publisher-overlap-passed",
        "representative-publisher-poststate-passed",
        "representative-combined-read-passed",
        "representative-combined-categories-passed",
    }
    else 1
)
