"""Qualify P0 receipt schema in a new, retained local K98DEV database only."""

import hashlib
import json
import re

import pyodbc

import build_p0_receipt_migration as build
import rehearse_guided_recovery_migrations as fixture

fixture.BASE = fixture.HEAD = build.BASE
fixture.DATABASE = fixture.DATABASE.replace("P0a_Migrations", "P0_Receipts")


def install(connection, name, revision=None):
    path = f"sql_schema/dbo.{name}.StoredProcedure.sql"
    text = (
        fixture.source(revision, path)
        if revision
        else (build.ROOT / path).read_text(encoding="utf-8-sig")
    )
    body = build.module_body(text)
    body = re.sub(r"^(?:CREATE OR ALTER|CREATE|ALTER) PROCEDURE", "CREATE OR ALTER PROCEDURE", body)
    fixture.execute(connection, body)


def rejected(connection, sql, expected):
    try:
        fixture.execute(connection, sql)
    except pyodbc.Error as exc:
        assert expected in str(exc), str(exc)
    else:
        raise AssertionError("Expected refusal: " + expected)
    assert connection.execute("SELECT @@TRANCOUNT").fetchval() == 0


def qualification(connection, report, output):
    fixture.execute(
        connection, "CREATE ROLE ExportLegacyEntryReader; CREATE ROLE K98ImportLockPrincipal;"
    )
    install(connection, "ACQUIRE_KS4_IMPORT_LOCK", build.BASE)
    for name in build.MODULES[3:]:
        install(connection, name, build.BASE)
    # Reproduce the independently retained deployed spelling rather than only
    # the consolidated source-export header. Its body must remain identical.
    prior = build.module_body(
        fixture.source(build.BASE, "sql_schema/dbo.usp_update_stats.StoredProcedure.sql")
    )
    assert prior.startswith("ALTER PROCEDURE [dbo].[usp_update_stats]")
    fixture.execute(connection, "DROP PROCEDURE dbo.usp_update_stats;")
    fixture.execute(
        connection,
        prior.replace(
            "ALTER PROCEDURE [dbo].[usp_update_stats]", "CREATE   PROC dbo.usp_update_stats", 1
        ),
    )
    migration = (build.ROOT / "migrations" / (build.MIGRATION + ".sql")).read_bytes()
    sql = migration.decode("utf-8")
    report["migration_sha256"] = hashlib.sha256(migration).hexdigest()
    before = fixture.catalogue(connection)
    # Actual worker-session lock, separate from the migration connection.
    with fixture.connect(fixture.DATABASE) as writer:
        fixture.execute(
            writer,
            "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; IF @r<0 THROW 51959,'Fixture could not acquire guard.',1;",
        )
        rejected(connection, sql, "SQL snapshot producer is live")
        fixture.execute(
            writer,
            "EXEC sys.sp_releaseapplock @Resource=N'k98-legacy-output-snapshot',@LockOwner='Session';",
        )
    assert fixture.catalogue(connection) == before
    interrupted = sql.replace(
        "\nCOMMIT;\nEND TRY",
        "\nTHROW 51959,'Injected precommit interruption.',1;\nCOMMIT;\nEND TRY",
    )
    assert interrupted != sql
    rejected(connection, interrupted, "Injected precommit interruption")
    assert fixture.catalogue(connection) == before, "Interrupted schema changes survived rollback"
    fixture.execute(connection, sql)
    after = fixture.catalogue(connection)
    fixture.execute(connection, sql)
    assert fixture.catalogue(connection) == after, "Reapply changed the schema contract"
    fixture.execute(
        connection,
        "ALTER TABLE dbo.ProcessingPipelineStage NOCHECK CONSTRAINT CK_ProcessingPipelineStage_State;",
    )
    rejected(connection, sql, "Checks contract differs")
    fixture.execute(
        connection,
        "ALTER TABLE dbo.ProcessingPipelineStage WITH CHECK CHECK CONSTRAINT CK_ProcessingPipelineStage_State;",
    )
    fixture.execute(
        connection, "ALTER PROCEDURE dbo.usp_update_stats WITH EXECUTE AS OWNER AS SELECT 42;"
    )
    rejected(connection, sql, "Unreviewed usp_update_stats preimage")
    install(connection, "usp_update_stats")
    fixture.execute(connection, sql)
    assert fixture.catalogue(connection) == after
    from validate_p0_report_entry_permissions import validate

    report["entry_permissions"] = validate(connection)
    assert fixture.catalogue(connection) == after, "Permission fixture escaped its rollback"
    report["verified"] = [
        "live_writer_refused",
        "precommit_rollback",
        "apply",
        "exact_reapply",
        "disabled_check_refused",
        "unreviewed_preimage_refused",
    ]
    print(json.dumps(dict(stage="p0_receipt_migration_verified", **report)), flush=True)


if __name__ == "__main__":
    fixture.main(qualification)
