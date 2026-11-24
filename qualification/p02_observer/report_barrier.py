"""A separately owned read-only table lock, never an observer or report lock."""

import time

SESSION_SQL = "SELECT @@SPID AS session_id"
ACQUIRE_SQL = """SET NOCOUNT ON; SET LOCK_TIMEOUT 0;
IF DB_ID()<>18 OR DB_NAME()<>N'ROK_TRACKER' OR @@TRANCOUNT<>0
 OR IS_SRVROLEMEMBER('sysadmin')<>1
 THROW 51976,'Exact fresh DB18 control owner required.',1;
DECLARE @Object int=OBJECT_ID(N'dbo.STATS_FOR_UPLOAD',N'U'),@Rows bigint;
IF @Object IS NULL THROW 51976,'Exact report output table required.',1;
BEGIN TRANSACTION;
SELECT @Rows=COUNT_BIG(*) FROM dbo.STATS_FOR_UPLOAD WITH(TABLOCK,HOLDLOCK);
SELECT @@SPID AS session_id,DB_ID() AS database_id,@Object AS object_id,
 @Rows AS rows_count,@@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state,
 (SELECT COUNT(*) FROM sys.dm_tran_locks WHERE request_session_id=@@SPID
  AND resource_database_id=18 AND resource_type='OBJECT'
  AND resource_associated_entity_id=@Object AND request_mode='S'
  AND request_status='GRANT' AND request_owner_type='TRANSACTION') AS shared_table_locks,
 (SELECT COUNT(*) FROM sys.dm_tran_locks WHERE request_session_id=@@SPID
  AND resource_type='APPLICATION') AS application_locks;"""
RELEASE_SQL = """SET NOCOUNT ON;
IF DB_ID()<>18 OR @@SPID<>{session_id} THROW 51976,'Original control session required.',1;
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;"""
IDLE_SQL = "SELECT @@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state"
RELEASE_LOCKS_SQL = """SET NOCOUNT ON;
IF DB_ID()<>18 OR @@SPID<>? THROW 51976,'Original control session required.',1;
SELECT COUNT(*) AS remaining_target_locks FROM sys.dm_tran_locks
WHERE request_session_id=@@SPID AND resource_database_id=18 AND resource_type='OBJECT'
AND resource_associated_entity_id=?;"""


def release_sql(session_id, object_id):
    # Only native integer identities may enter this direct (non-RPC) control batch.
    # Ending an ambient transaction through prepared execution raised SQL 266.
    if type(session_id) is not int or not 1 <= session_id <= 32767:
        raise ValueError("Exact native control session required")
    if object_id is not None and (type(object_id) is not int or not 1 <= object_id <= 2147483647):
        raise ValueError("Exact native target object required")
    return RELEASE_SQL.format(
        session_id=session_id, object_id="NULL" if object_id is None else object_id
    )


class ReportBarrier:
    def __init__(self, record, save, expected_rows):
        self.owner = None
        self.save = save
        self.expected_rows = expected_rows
        self.facts = dict(
            admin_dispatches=0,
            admin_seconds=0.0,
            admin_connections_closed=0,
            actions=[],
            cleanup_failures=[],
            acquire_attempted=False,
            acquired=False,
            release_attempted=False,
            released=False,
            close_attempted=False,
            business_mutations=0,
            observer_owned=False,
        )
        record["controlled_barrier"] = self.facts

    def acquire(self):
        from fresh_business_owner import SqlOwner

        if self.facts["acquire_attempted"]:
            raise ValueError("Control acquisition cannot repeat")
        self.facts["acquire_attempted"] = True
        self.save()
        self.owner = SqlOwner("ROK_TRACKER", self.facts, self.save)
        row = self.owner.read(SESSION_SQL)
        if len(row) != 1 or type(row[0]["session_id"]) is not int:
            raise ValueError("Exact control session required")
        self.facts["session_id"] = row[0]["session_id"]
        rows = self.owner.read(ACQUIRE_SQL)
        if len(rows) != 1:
            raise ValueError("One native control-lock receipt required")
        row = rows[0]
        self.facts["native"] = row
        if (
            row["session_id"] != self.facts["session_id"]
            or row["database_id"] != 18
            or type(row["object_id"]) is not int
            or row["object_id"] <= 0
            or row["rows_count"] != self.expected_rows
            or row["transaction_count"] != 1
            or row["transaction_state"] != 1
            or row["shared_table_locks"] < 1
            or row["application_locks"] != 0
        ):
            raise ValueError("Exact read-only S table lock is not owned")
        self.facts.update(acquired=True, acquired_clock=time.monotonic())
        self.save()

    def is_blocked_report(self, row, pid):
        return bool(
            self.facts["acquired"]
            and row["host_process_id"] == pid
            and row["report_batch"]
            and row["request_status"] == "suspended"
            and row["blocking_session_id"] == self.facts["session_id"]
            and str(row["wait_type"]).startswith("LCK_M_")
        )

    def release(self):
        if self.facts["released"] or self.owner is None:
            return
        if self.facts["release_attempted"]:
            raise ValueError("Unknown control rollback cannot repeat")
        self.facts["release_attempted"] = True
        # No disk write between rollback ACK and overlap sampling: this is a
        # short native scheduling barrier, not a delay inserted into the report.
        statement = release_sql(
            self.facts["session_id"], self.facts.get("native", {}).get("object_id")
        )
        self.facts["release_parameter_count"] = 0
        rows = self.owner.read(statement)
        self.facts["rollback_result"] = rows
        if rows != []:
            raise ValueError("Control rollback batch returned an unexpected result")
        self.facts["rollback_batch_completed"] = True
        # A SELECT inside the rollback batch is not a separate request boundary.
        # SqlOwner.read has consumed completion and closed that cursor before this.
        boundary = self.owner.read(IDLE_SQL)
        self.facts["release_boundary_before_locks"] = boundary
        expected = dict(transaction_count=0, transaction_state=0)
        if boundary != [expected]:
            raise ValueError("Original control session is not idle after rollback batch")
        # Metadata evaluation can report its own statement transaction. Reuse
        # the native-proven pure boundary check before and after the lock read.
        locks = self.owner.read(
            RELEASE_LOCKS_SQL,
            self.facts["session_id"],
            self.facts.get("native", {}).get("object_id"),
        )
        self.facts["release_lock_result"] = locks
        if locks != [dict(remaining_target_locks=0)]:
            raise ValueError("Original control target locks remain")
        boundary = self.owner.read(IDLE_SQL)
        self.facts["release_boundary_after_locks"] = boundary
        if boundary != [expected]:
            raise ValueError("Original control session is not idle after lock read")
        self.facts.update(released=True, released_clock=time.monotonic())

    def finish(self):
        first = None
        if self.owner is None:
            return
        try:
            if not self.facts["release_attempted"]:
                self.release()
            elif not self.facts["released"]:
                raise ValueError("Original rollback outcome remains unknown")
        except BaseException as error:
            first = error
            self.facts["cleanup_failures"].append(
                dict(operation="control rollback", error_type=type(error).__name__)
            )
        finally:
            if not self.facts["close_attempted"]:
                self.facts["close_attempted"] = True
                try:
                    self.owner.close()
                except BaseException as error:
                    self.facts["cleanup_failures"].append(
                        dict(operation="control close", error_type=type(error).__name__)
                    )
                    first = first or error
        if first is not None:
            raise first


def release_when_reader_enters(
    barrier, connection, children, record, started, *, clock=time.monotonic, wait=time.sleep
):
    from producer_pair import active

    reader = next(c["process"].pid for c in children if c["role"] == "reader")
    barrier.facts.setdefault("observed_blocking_clock", clock())
    deadline = barrier.facts["observed_blocking_clock"] + 0.250
    while True:
        if clock() >= deadline:
            barrier.facts["reader_request_observed_before_release"] = False
            break
        rows = active(connection, children)
        record["samples"].append(dict(seconds=clock() - started, phase="control_pause", rows=rows))
        if any(
            r["host_process_id"] == reader and r["request_status"] in ("running", "runnable")
            for r in rows
        ):
            barrier.facts["reader_request_observed_before_release"] = True
            break
        if clock() >= deadline:
            barrier.facts["reader_request_observed_before_release"] = False
            break
        wait(0.005)
    barrier.release()
    barrier.facts["observed_pause_seconds"] = clock() - barrier.facts["observed_blocking_clock"]
