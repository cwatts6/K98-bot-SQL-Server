"""Use the existing guest-only operational publisher transport; no permission changes."""

from maintenance_continuation import operational_connections

IDENTITY = """SELECT ORIGINAL_LOGIN() AS principal,IS_SRVROLEMEMBER('sysadmin') AS sysadmin,
DB_ID() AS database_id,DB_NAME() AS database_name,
CONVERT(varchar(36),database_guid) AS database_guid
FROM sys.database_recovery_status WHERE database_id=DB_ID()"""


def require_identity(row):
    if tuple(row) != (
        r"MINI_AMD\K98LabAdmin",
        1,
        27,
        "ROK_TRACKER",
        "6A0068DA-C67F-4A8C-A934-C2FEB49EDF2E",
    ):
        raise ValueError("Exact operational principal and retained DB27 required")


def run(packet, manifest, record, save):
    from types import SimpleNamespace

    from fresh_business_owner import HELD
    from independent_readers import write_new
    from poststate_owner import owned
    import publisher_state as state
    import publisher_worker

    from core.sql_connection_custody import preserve_failure, retain_connection
    from scripts.verify_k98_running_release import sql_error_facts

    with owned("ROK_TRACKER", record, save, timeout=15) as owner:
        before = state.read(owner)
    if before["generation"] != 1:
        raise ValueError("Publisher generation changed before dispatch; no replay")
    write_new(packet / "publisher-before.json", before)
    factory = operational_connections()
    record["operational_cleanup"] = dict(safe_to_exit=False, all_closed_by_callers=False)

    def connect():
        if factory.items:
            raise ValueError("Only one fresh operational publisher connection is permitted")
        connection = factory()
        cursor = None
        cursor_close_attempted = False
        try:
            connection.autocommit = True
            connection.timeout = 15
            cursor = connection.cursor()
            cursor.execute(IDENTITY)
            row = cursor.fetchone()
            require_identity(row or ())
            if cursor.fetchone() is not None or cursor.nextset():
                raise ValueError("Unexpected operational identity response")
            record["publisher_identity"] = dict(
                zip(
                    ("principal", "sysadmin", "database_id", "database_name", "database_guid"),
                    tuple(row),
                    strict=True,
                )
            )
            save()
            cursor_close_attempted = True
            cursor.close()
            cursor = None
            return connection
        except BaseException as error:
            if cursor_close_attempted and cursor is not None:
                retain_connection(
                    SimpleNamespace(connection=connection, cursor=cursor),
                    effect="none",
                    first_failure=error,
                    cleanup_error=error,
                )
                raise
            first = error
            for phase, action in (
                ("identity_cursor_close", cursor.close if cursor is not None else None),
                ("identity_connection_close", connection.close),
            ):
                if action is None:
                    continue
                try:
                    action()
                except BaseException as cleanup:
                    first = preserve_failure(first, cleanup, phase)
                    retain_connection(
                        SimpleNamespace(connection=connection, cursor=cursor),
                        effect="none",
                        first_failure=first,
                        cleanup_error=cleanup,
                    )
                    break
            raise first

    first = None
    result = None
    try:
        result = publisher_worker.run(connect, manifest["publisher_operation"], record, save)
    except BaseException as error:
        first = error
    try:
        cleanup = factory.finish()
        record["operational_cleanup"] = cleanup
        if not cleanup["safe_to_exit"]:
            HELD.append(factory)
        if not cleanup["safe_to_exit"] or not cleanup["all_closed_by_callers"]:
            raise ValueError("Original operational publisher ownership must settle")
    except BaseException as error:
        if not record["operational_cleanup"]["safe_to_exit"] and factory not in HELD:
            HELD.append(factory)
        record["cleanup_failures"].append(
            dict(operation="operational publisher cleanup", **sql_error_facts(error))
        )
        first = preserve_failure(first, error, "operational_cleanup")
    # An uncertain owner forbids another connection, including reconciliation.
    if not HELD:
        try:
            with owned("ROK_TRACKER", record, save, timeout=15) as owner:
                after = state.read(owner)
            write_new(packet / "publisher-after.json", after)
        except BaseException as error:
            record["publisher_poststate_failure"] = sql_error_facts(error)
            first = preserve_failure(first, error, "publisher_poststate")
    try:
        save()
    except BaseException as error:
        first = preserve_failure(first, error, "publisher_progress")
    if first is not None:
        raise first
    state.require_delta(before, after, 1)
    record["publication_poststate_verified"] = True
    record["publisher_transport"] = (
        "isolated Windows operational transport; not production credential acceptance"
    )
    save()
    return result
