"""Correct only the proven lab dbo mapping; preserve the original business claim."""

import copy
import hashlib
import json
from pathlib import Path
import sys

PURPOSE = "retained-lab-dbo-mapping-repair"
PRIOR_DIRECTORY = "Q:/P02Observer/20261121153219394"
PRIOR_SHA = "dfbc745db21a56eaaece0a3c8922625e4fabae20f2fb204d1abf80239de34c20"
FAILED_DIRECTORY = "Q:/P02Observer/20261121154909768"
FAILED_SHA = "7fa1277ff607ee51988f350c24e6235d826ef916e946cbe68953a540cab4033b"
# Exact prior DB16 metadata hashes; each body was verified against the installed
# release literal. SQL Server stored CREATE headers for CREATE OR ALTER input.
GUARD_HASHES = {
    "tr_P02CatalogueObservation": "ec796b629874c0d426677619b5cb36da5acbd51074fe0dae35a36d83cd9d148c",
    "dbo.usp_P02BeginCatalogueMutation": "6d2fca4c3877031363f3f388f9d021852f5b79abb3fddcbf0c69af000a603161",
}
DDL_TRIGGERS_SQL = """SELECT t.name,t.is_disabled,m.execute_as_principal_id,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',m.definition),2)) AS definition_sha256
FROM sys.triggers t LEFT JOIN sys.sql_modules m ON m.object_id=t.object_id
WHERE t.parent_class=0 ORDER BY t.name"""
HELPER_SQL = """SELECT N'dbo.usp_P02BeginCatalogueMutation' AS name,
m.execute_as_principal_id,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',m.definition),2)) AS definition_sha256
FROM sys.sql_modules m WHERE m.object_id=OBJECT_ID(N'dbo.usp_P02BeginCatalogueMutation')"""
SERVER_TRIGGERS_SQL = """SELECT name,is_disabled FROM sys.server_triggers
WHERE is_disabled=0 ORDER BY name"""
REPAIR_SQL = """SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 1000;
IF DB_ID()<>16 OR DB_NAME()<>N'ROK_TRACKER' OR @@TRANCOUNT<>0
 OR ORIGINAL_LOGIN()<>N'MINI_AMD\\K98LabAdmin'
 THROW 51976,'Exact isolated idle correction owner required.',1;
DECLARE @error int=NULL,@cleanup int=NULL,@committed bit=0,@rolled_back bit=0;
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE database_id=16
  AND owner_sid=0x010500000000000515000000cfc07a55bb14094237a8f0cfe9030000)
  OR SUSER_SID(N'MINI_AMD\\K98LabAdmin')<>0x010500000000000515000000cfc07a55bb14094237a8f0cfe9030000
  OR NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE principal_id=1
   AND sid=0x01050000000000051500000082350cb1d5dfa006bae7a2e4e9030000)
  OR NOT EXISTS(SELECT 1 FROM sys.sequences WHERE name=N'P02ObservationGeneration'
   AND object_id=757342954 AND CONVERT(bigint,current_value)=1)
  THROW 51976,'Exact original lab owner and generation required; no replay.',1;
 ALTER AUTHORIZATION ON DATABASE::ROK_TRACKER TO [MINI_AMD\\K98LabAdmin];
 IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE principal_id=1
   AND sid=0x010500000000000515000000cfc07a55bb14094237a8f0cfe9030000
   AND type_desc=N'WINDOWS_USER')
  OR NOT EXISTS(SELECT 1 FROM sys.databases WHERE database_id=16
   AND owner_sid=0x010500000000000515000000cfc07a55bb14094237a8f0cfe9030000)
  OR NOT EXISTS(SELECT 1 FROM sys.sequences WHERE name=N'P02ObservationGeneration'
   AND object_id=757342954 AND CONVERT(bigint,current_value)=2)
  THROW 51976,'Owner correction or single observation increment differs.',1;
 COMMIT TRANSACTION;
 SET @committed=1;
END TRY
BEGIN CATCH
 SET @error=ERROR_NUMBER();
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
END CATCH;
SELECT N'dbo_mapping' AS repair,@error AS error_number,@cleanup AS cleanup_error_number,
 @committed AS committed,@rolled_back AS rollback_acknowledged,
 @@TRANCOUNT AS transaction_count,XACT_STATE() AS transaction_state;"""


def require_prior(value, baseline):
    import owner_context_read as owner

    facts = value.get("owner_diagnostics", {})
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
        or facts.get("owner_before") != owner.OWNER_EXPECTED
        or facts.get("owner_after") != owner.OWNER_EXPECTED
        or facts.get("modules_before") != baseline["modules"]
        or facts.get("application_locks_after") != [dict(application_lock_count=0)]
    ):
        raise ValueError("Exact settled owner diagnostic required")
    for name in ("owner_context", "import_lock"):
        rows = facts["probes"][name]
        owner.require_probe(rows, name)
        if rows[0]["error_number"] != 15517:
            raise ValueError("Both exact native owner-context failures required")
    if facts["probes"]["import_lock"][0]["rollback_acknowledged"] is not True:
        raise ValueError("Original diagnostic rollback acknowledgement required")


def require_stopped(value, diagnostic):
    facts = value.get("owner_repair", {})
    if (
        value.get("outcome") != "failed"
        or value.get("stage") != "scoped retained-state diagnostic"
        or value.get("first_failure")
        != dict(stage="scoped retained-state diagnostic", error_type="ValueError")
        or value.get("cleanup_failures") != []
        or value.get("connections_closed") != 1
        or value.get("physical_custody_retained") is not False
        or value.get("dispatches") != 34
        or value.get("checkpoint_count") != 4
        or value.get("persistent_writes") != 0
        or value.get("before_differences") != []
        or value.get("before") != diagnostic["after"]
        or "after" in value
        or facts.get("attempted") is not False
        or facts.get("committed") is not None
        or facts.get("probes") != {}
        or "result" in facts
        or facts.get("owner_before") != diagnostic["owner_diagnostics"]["owner_before"]
        or facts.get("modules_before") != diagnostic["owner_diagnostics"]["modules_before"]
        or facts.get("boundaries") != dict(before=[dict(transaction_count=0, transaction_state=0)])
    ):
        raise ValueError("Exact settled refusal before owner mutation required")


def before_native(packet, manifest, prior, baseline):
    import owner_context_read as owner
    import restart_read as shared

    owner.before_native(packet, manifest, prior, baseline)
    raw = (packet / "evidence/owner-diagnostic-receipt.json").read_bytes()
    if (
        hashlib.sha256(raw).hexdigest() != PRIOR_SHA
        or (Path(PRIOR_DIRECTORY) / "receipt.json").read_bytes() != raw
    ):
        raise ValueError("Retained owner diagnostic receipt changed")
    value = json.loads(raw)
    require_prior(value, baseline)
    if shared.differences(value["after"], prior):
        raise ValueError("Retained complete state changed")
    failed_raw = (packet / "evidence/owner-repair-refusal.json").read_bytes()
    if (
        hashlib.sha256(failed_raw).hexdigest() != FAILED_SHA
        or (Path(FAILED_DIRECTORY) / "receipt.json").read_bytes() != failed_raw
    ):
        raise ValueError("Original stopped owner correction receipt changed")
    require_stopped(json.loads(failed_raw), value)


def expected_owner():
    import owner_context_read as owner

    rows = copy.deepcopy(owner.OWNER_EXPECTED)
    rows[0]["dbo_sid"] = rows[0]["database_owner_sid"]
    return rows


def validate_guards(read, facts):
    # Save every completed read before comparing, including on a refusal.
    facts["database_triggers"] = read(DDL_TRIGGERS_SQL)
    facts["helper"] = read(HELPER_SQL)
    facts["enabled_server_triggers"] = read(SERVER_TRIGGERS_SQL)
    expected = dict(
        database_triggers=[
            dict(
                name="tr_P02CatalogueObservation",
                is_disabled=False,
                execute_as_principal_id=None,
                definition_sha256=GUARD_HASHES["tr_P02CatalogueObservation"],
            )
        ],
        helper=[
            dict(
                name="dbo.usp_P02BeginCatalogueMutation",
                execute_as_principal_id=None,
                definition_sha256=GUARD_HASHES["dbo.usp_P02BeginCatalogueMutation"],
            )
        ],
        enabled_server_triggers=[],
    )
    facts["differences"] = [name for name, value in expected.items() if facts[name] != value]
    if facts["differences"]:
        raise ValueError("Exact installed observation guards and no active server trigger required")
    return facts


def probe(read, record):
    import owner_context_read as owner
    import report_failure_read as old
    import restart_read as shared

    packet = Path(__file__).resolve().parents[2]
    prior = json.loads((packet / "evidence/owner-diagnostic-receipt.json").read_bytes())
    facts = dict(
        prior_receipt_sha256=PRIOR_SHA, attempted=False, committed=None, probes={}, boundaries={}
    )
    record["owner_repair"] = facts

    def save():
        shared.checkpoint(packet, record)

    def idle(name):
        facts["boundaries"][name] = read(owner.IDLE_SQL)
        if facts["boundaries"][name] != [dict(transaction_count=0, transaction_state=0)]:
            raise ValueError("Separate correction boundary must be idle")

    idle("before")
    facts["owner_before"] = read(shared.OWNER_SQL)
    facts["modules_before"] = read(old.MODULE_SQL)
    if (
        facts["owner_before"] != owner.OWNER_EXPECTED
        or facts["modules_before"] != prior["owner_diagnostics"]["modules_before"]
    ):
        raise ValueError("Original owner or report helpers changed")
    facts["guards_before"] = {}
    validate_guards(read, facts["guards_before"])
    facts["locks_before"] = read(owner.LOCK_COUNT_SQL)
    if facts["locks_before"] != [dict(application_lock_count=0)]:
        raise ValueError("Fresh correction owner already holds application locks")
    facts["attempted"] = True
    record["persistent_writes"] = None
    record["stage"] = "single lab owner correction; commit acknowledgement pending"
    save()
    facts["result"] = read(REPAIR_SQL)
    rows = facts["result"]
    if len(rows) != 1:
        raise ValueError("One owner correction result required")
    row = rows[0]
    facts["committed"] = row.get("committed")
    if (
        row.get("repair") != "dbo_mapping"
        or row.get("error_number") is not None
        or row.get("cleanup_error_number") is not None
        or row.get("committed") is not True
        or row.get("rollback_acknowledged") is not False
        or row.get("transaction_count") != 0
        or row.get("transaction_state") != 0
    ):
        save()
        raise ValueError("Owner correction not confirmed; retain result without replay")
    record["persistent_writes"] = 1
    record["stage"] = "lab owner correction committed; verify focused execution"
    save()
    idle("after_correction")
    facts["owner_after"] = read(shared.OWNER_SQL)
    if facts["owner_after"] != expected_owner():
        raise ValueError("Corrected dbo identity differs")
    for name, sql in (
        ("owner_context", owner.OWNER_CONTEXT_SQL),
        ("import_lock", owner.IMPORT_LOCK_SQL),
    ):
        facts["probes"][name] = read(sql)
        owner.require_probe(facts["probes"][name], name)
        row = facts["probes"][name][0]
        if row["error_number"] is not None:
            raise ValueError("Corrected owner/helper still refuses")
        if name == "import_lock" and (
            row["lock_result"] not in (0, 1) or row["rollback_acknowledged"] is not True
        ):
            raise ValueError("Zero-wait import lock or rollback not acknowledged")
        idle("after_" + name)
    facts["guards_after"] = {}
    validate_guards(read, facts["guards_after"])
    facts["modules_after"] = read(old.MODULE_SQL)
    facts["locks_after"] = read(owner.LOCK_COUNT_SQL)
    if (
        facts["modules_after"] != facts["modules_before"]
        or facts["locks_after"] != [dict(application_lock_count=0)]
        or facts["guards_before"] != facts["guards_after"]
    ):
        raise ValueError("Guard/module preservation or application lock cleanup differs")
    facts["interpretation"] = (
        "Local restored dbo correction and helper proof only. Original report cause "
        "remains unrecorded; original uncertain claim and all business work preserved."
    )


def compare_after(record, prior):
    expected = copy.deepcopy(record["before"])
    sequence = expected["database"]["observer_sequence"]
    if len(sequence) != 1 or sequence[0]["generation"] != 1:
        raise ValueError("Exact original observation generation required")
    sequence[0]["generation"] = 2
    facts = record.get("owner_repair", {})
    if facts.get("committed") is not True or facts.get("owner_after") != expected_owner():
        raise ValueError("Committed lab owner correction required")
    return [name for name, value in expected.items() if record["after"].get(name) != value]


def main():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import restart_read as shared

    return shared.main(
        expected_purpose=PURPOSE,
        before_native=before_native,
        diagnostic=probe,
        final_compare=compare_after,
        completion_stage="lab dbo mapping committed and focused probes passed; original claim preserved",
    )


if __name__ == "__main__":
    try:
        result = main()
    except BaseException as error:
        sys.stderr.write(
            json.dumps(
                dict(
                    outcome="failed",
                    error_type=type(error).__name__,
                    detail="Retain owner-correction evidence and original claim; no replay.",
                )
            )
            + "\n"
        )
        result = 1
    raise SystemExit(result)
