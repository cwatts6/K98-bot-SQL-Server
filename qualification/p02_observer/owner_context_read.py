"""Probe restored dbo context and its import-lock helper; never publish a report."""

import hashlib
import json
from pathlib import Path
import sys

PURPOSE = "retained-owner-context-and-lock"
RESTART_DIRECTORY = "Q:/P02Observer/20261121150156807"
RESTART_SHA = "53add883365b9aac41dfbb6153025e36c57ff1e994c5b33bff64f81f890020af"
OWNER_EXPECTED = [
    {
        "name": "ROK_TRACKER",
        "database_id": 16,
        "database_owner_sid": "010500000000000515000000cfc07a55bb14094237a8f0cfe9030000",
        "owner_login": "MINI_AMD\\K98LabAdmin",
        "dbo_type": "WINDOWS_USER",
        "dbo_sid": "01050000000000051500000082350cb1d5dfa006bae7a2e4e9030000",
    }
]
IDLE_SQL = "SELECT @@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state"
LOCK_COUNT_SQL = """SELECT COUNT_BIG(*) AS application_lock_count
FROM sys.dm_tran_locks WHERE request_session_id=@@SPID
AND resource_database_id=16 AND resource_type=N'APPLICATION'"""
OWNER_CONTEXT_SQL = """SET NOCOUNT ON;
IF DB_ID()<>16 OR DB_NAME()<>N'ROK_TRACKER' OR @@TRANCOUNT<>0
 OR ORIGINAL_LOGIN()<>N'MINI_AMD\\K98LabAdmin'
 THROW 51976,'Exact isolated idle diagnostic owner required.',1;
DECLARE @cookie varbinary(8000),@active bit=0,@error int=NULL,@cleanup int=NULL,
 @inside sysname=NULL,@entry_sid varbinary(85)=SUSER_SID(),@entry_user int=USER_ID();
BEGIN TRY
 EXECUTE AS USER=N'dbo' WITH COOKIE INTO @cookie;
 SET @active=1;
 SET @inside=USER_NAME();
END TRY
BEGIN CATCH
 SET @error=ERROR_NUMBER();
END CATCH;
IF @active=1
BEGIN
 BEGIN TRY
  REVERT WITH COOKIE=@cookie;
  SET @active=0;
 END TRY
 BEGIN CATCH
  SET @cleanup=ERROR_NUMBER();
 END CATCH;
END;
SELECT N'owner_context' AS probe,@error AS error_number,@cleanup AS cleanup_error_number,
 @inside AS inside_user,@active AS context_still_active,
 CAST(CASE WHEN SUSER_SID()=@entry_sid AND USER_ID()=@entry_user THEN 1 ELSE 0 END AS bit) AS context_restored,
 @@TRANCOUNT AS transaction_count;"""
IMPORT_LOCK_SQL = """SET NOCOUNT ON;
IF DB_ID()<>16 OR DB_NAME()<>N'ROK_TRACKER' OR @@TRANCOUNT<>0
 OR ORIGINAL_LOGIN()<>N'MINI_AMD\\K98LabAdmin'
 THROW 51976,'Exact isolated idle diagnostic owner required.',1;
DECLARE @error int=NULL,@cleanup int=NULL,@lock_result int=NULL,@begun bit=0,
 @rolled_back bit=0,@entry_sid varbinary(85)=SUSER_SID(),@entry_user int=USER_ID();
BEGIN TRY
 BEGIN TRANSACTION;
 SET @begun=1;
 EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK @LockTimeout=0,@LockResult=@lock_result OUTPUT;
END TRY
BEGIN CATCH
 SET @error=ERROR_NUMBER();
END CATCH;
IF @@TRANCOUNT>0
BEGIN
 BEGIN TRY
  ROLLBACK TRANSACTION;
  SET @rolled_back=1;
 END TRY
 BEGIN CATCH
  SET @cleanup=ERROR_NUMBER();
 END CATCH;
END;
SELECT N'import_lock' AS probe,@error AS error_number,@cleanup AS cleanup_error_number,
 @lock_result AS lock_result,@begun AS transaction_begun,@rolled_back AS rollback_acknowledged,
 CAST(CASE WHEN SUSER_SID()=@entry_sid AND USER_ID()=@entry_user THEN 1 ELSE 0 END AS bit) AS context_restored,
 @@TRANCOUNT AS transaction_count;"""


def require_restart(value, prior, module_baseline):
    import restart_read as shared

    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("connections_closed") != 1
        or value.get("physical_custody_retained") is not False
        or not value.get("before")
        or value["before"] != value.get("after")
        or value.get("before_differences") != []
        or value.get("after_differences") != []
        or shared.differences(value["after"], prior)
        or value.get("metadata", {}).get("modules") != module_baseline["modules"]
        or value.get("metadata", {}).get("database_owner") != OWNER_EXPECTED
    ):
        raise ValueError("Exact passed restart evidence and owner mismatch required")
    shared.require_services(value["services_before"])
    shared.require_services(value["services_after"])


def before_native(packet, manifest, prior, module_baseline):
    raw = (packet / "evidence/restart-receipt.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != RESTART_SHA
        or (Path(RESTART_DIRECTORY) / "receipt.json").read_bytes() != raw
    ):
        raise ValueError("Passed restart receipt changed")
    require_restart(json.loads(raw), prior, module_baseline)


def require_probe(rows, name):
    if len(rows) != 1:
        raise ValueError("One bounded diagnostic result required")
    row = rows[0]
    if (
        row.get("probe") != name
        or row.get("cleanup_error_number") is not None
        or row.get("context_restored") is not True
        or row.get("transaction_count") != 0
    ):
        raise ValueError("Probe context or transaction cleanup unconfirmed")
    number = row.get("error_number")
    if number is not None and (type(number) is not int or not 1 <= number <= 2147483647):
        raise ValueError("Unexpected diagnostic SQL error number")
    if name == "owner_context":
        if row.get("context_still_active") not in (0, False):
            raise ValueError("Original context switch remains active")
        if number is None and row.get("inside_user") != "dbo":
            raise ValueError("Successful owner context identity differs")
    elif name == "import_lock":
        if row.get("transaction_begun") not in (1, True):
            raise ValueError("Owned diagnostic transaction was not established")
        if number is None and row.get("lock_result") not in (0, 1, -1, -2, -3, -999):
            raise ValueError("Unexpected application lock result")


def probe(read, record):
    import report_failure_read as old
    import restart_read as shared

    facts = dict(restart_receipt_sha256=RESTART_SHA, boundary_reads={}, probes={})
    record["owner_diagnostics"] = facts

    def idle(name):
        rows = read(IDLE_SQL)
        facts["boundary_reads"][name] = rows
        if rows != [dict(transaction_count=0, transaction_state=0)]:
            raise ValueError("Separate diagnostic transaction boundary must be idle")

    idle("before")
    facts["owner_before"] = shared.normalized(read(shared.OWNER_SQL))
    if facts["owner_before"] != OWNER_EXPECTED:
        raise ValueError("Retained owner identities changed")
    facts["modules_before"] = shared.normalized(read(old.MODULE_SQL))
    # Exact module hashes and owners were pinned in the passed restart receipt.
    packet = Path(__file__).resolve().parents[2]
    restart = json.loads((packet / "evidence/restart-receipt.json").read_bytes())
    if facts["modules_before"] != restart["metadata"]["modules"]:
        raise ValueError("Original helper or report source changed before probe")
    facts["application_locks_before"] = read(LOCK_COUNT_SQL)
    if facts["application_locks_before"] != [dict(application_lock_count=0)]:
        raise ValueError("Fresh diagnostic connection already owns an application lock")
    for name, sql in (("owner_context", OWNER_CONTEXT_SQL), ("import_lock", IMPORT_LOCK_SQL)):
        facts["probes"][name] = read(sql)
        require_probe(facts["probes"][name], name)
        idle("after_" + name)
    facts["application_locks_after"] = read(LOCK_COUNT_SQL)
    if facts["application_locks_after"] != [dict(application_lock_count=0)]:
        raise ValueError("Diagnostic application lock cleanup unconfirmed")
    facts["owner_after"] = shared.normalized(read(shared.OWNER_SQL))
    if facts["owner_after"] != facts["owner_before"]:
        raise ValueError("Database owner metadata changed")
    facts["interpretation"] = (
        "Current context/helper diagnostics only; the original report inner error remains "
        "unrecorded. No report, owner correction, persistent business write or claim release ran."
    )


def main():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import restart_read as shared

    return shared.main(expected_purpose=PURPOSE, before_native=before_native, diagnostic=probe)


if __name__ == "__main__":
    try:
        result = main()
    except BaseException as error:
        sys.stderr.write(
            json.dumps(
                dict(
                    outcome="failed",
                    error_type=type(error).__name__,
                    detail="Retain original report claim and owner-probe evidence; no replay.",
                )
            )
            + "\n"
        )
        result = 1
    raise SystemExit(result)
