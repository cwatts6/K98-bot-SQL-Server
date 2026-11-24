"""One real KVK publisher call on its original owned lab connection; no retry."""

from types import SimpleNamespace
from uuid import UUID

from core.sql_connection_custody import (
    SqlCleanupUnknown,
    preserve_failure,
    require_sql_admission,
    retain_connection,
)
from core.sql_operation_policy import DEFAULT_STATEMENT_SECONDS, METADATA_LOCK_MILLISECONDS
from services.legacy_snapshot_admission import acquire_snapshot_guard
from services.maintenance_dal import RELEASE_SESSION, SESSION_STATE

PUBLISH_SQL = "EXEC dbo.sp_ExcelOutput_ByKVK @KVK=?,@Scan=?"
QUIET_SQL = "SELECT @@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state"
POLICY_SQL = "SET LOCK_TIMEOUT 1000; SET XACT_ABORT ON"


def run(connect, operation_id, record, save):
    operation_id = str(UUID(operation_id))
    require_sql_admission()
    connection = connect()
    cursor = None
    first = None
    cleanup = None
    owned = False
    retain = False
    try:
        connection.autocommit = True
        connection.timeout = DEFAULT_STATEMENT_SECONDS
        assert DEFAULT_STATEMENT_SECONDS == 15 and METADATA_LOCK_MILLISECONDS == 1000
        cursor = connection.cursor()
        cursor.execute(SESSION_STATE)
        if tuple(cursor.fetchone() or ()) != (0, *("NoLock",) * 6):
            retain = True
            raise SqlCleanupUnknown("Publisher entered with existing SQL ownership.")
        owned = True
        cursor.execute(POLICY_SQL)
        while cursor.nextset():
            if cursor.description:
                raise ValueError("Unexpected publisher setup response")
        acquire_snapshot_guard(cursor)
        while cursor.nextset():
            if cursor.description:
                raise ValueError("Unexpected publisher guard response")
        if record.get("publisher_dispatch_attempted"):
            raise ValueError("Original publisher operation cannot be repeated")
        record.update(operation_id=operation_id, publisher_dispatch_attempted=True)
        save()
        cursor.execute(PUBLISH_SQL, 16, 1244)
        while True:
            if cursor.description:
                while cursor.fetchmany(128):
                    pass
            if not cursor.nextset():
                break
        # Independent request after all procedure responses are consumed.
        cursor.execute(QUIET_SQL)
        if tuple(cursor.fetchone() or ()) != (0, 0):
            raise SqlCleanupUnknown("Publisher transaction completion is unconfirmed.")
        record["publisher_response_acknowledged"] = True
        save()
    except BaseException as error:
        first = error
    finally:
        if owned:
            try:
                connection.timeout = 3
                cursor.execute(RELEASE_SESSION)
                if tuple(cursor.fetchone() or ()) != (0, *("NoLock",) * 6):
                    raise SqlCleanupUnknown("Publisher guard release is unconfirmed.")
                while cursor.nextset():
                    pass
            except BaseException as error:
                first = preserve_failure(first, error, "publisher_release")
                cleanup = error
                retain = True
        elif cursor is not None:
            retain = True
            cleanup = first
        for phase, action in (
            ("cursor_close", cursor.close if cursor is not None else None),
            ("close", connection.close),
        ):
            if action is None or retain:
                continue
            try:
                action()
            except BaseException as error:
                first = preserve_failure(first, error, phase)
                cleanup = cleanup or error
                retain = True
        if retain or cleanup is not None:
            retain_connection(
                SimpleNamespace(connection=connection, cursor=cursor),
                effect="unknown",
                first_failure=first,
                cleanup_error=cleanup,
            )
    if first is not None:
        raise first
    return dict(
        operation_id=operation_id,
        procedure="dbo.sp_ExcelOutput_ByKVK",
        kvk=16,
        scan=1244,
        response_acknowledged=True,
        cleanup_acknowledged=True,
    )
