"""Actual zero/one/two-index -> KVK capture -> next-writer/consumer chain on DB27."""

from copy import deepcopy
import hashlib
import json
import time

INDEX_NAMES = ("IX_EXCEL_FOR_KVK_16_GovID", "IX_EXCEL_FOR_KVK_16_KVK_NO")
INDEXES = """SELECT i.name,i.type,i.is_unique,i.is_disabled,i.has_filter,
 c.name AS column_name,ic.key_ordinal,ic.is_included_column,ic.is_descending_key
FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
WHERE i.object_id=OBJECT_ID(N'dbo.EXCEL_FOR_KVK_16') AND i.index_id>0
ORDER BY i.name,ic.index_column_id"""
KVK_PREFLIGHT = """SELECT
(SELECT COUNT_BIG(*) FROM KVK.KVK_Scan WHERE KVK_NO=16) AS scans,
(SELECT COUNT_BIG(*) FROM KVK.KVK_AllPlayers_Raw WHERE KVK_NO=16) AS raw_rows,
(SELECT COUNT_BIG(*) FROM KVK.KVK_DKPWeights WHERE KVK_NO=16) AS weights,
(SELECT COUNT_BIG(*) FROM KVK.KVK_Windows WHERE KVK_NO=16) AS windows,
(SELECT COUNT_BIG(*) FROM KVK.KVK_Player_Baseline WHERE KVK_NO=16) AS baselines,
(SELECT COUNT_BIG(*) FROM KVK.SeasonSource WHERE KVK_NO=16 AND SourceKey='legacy_full_data' AND SeasonState='open') AS admitted_season"""


def require_kvk_source(rows):
    if len(rows) != 1 or set(rows[0]) != {
        "scans",
        "raw_rows",
        "weights",
        "windows",
        "baselines",
        "admitted_season",
    }:
        raise ValueError("Complete genuine KVK source preflight required")
    if any(type(v) is not int or v <= 0 for v in rows[0].values()):
        raise ValueError(
            "Genuine open legacy KVK 16 source and complete input data are required; no synthetic replacement"
        )
    if rows[0]["admitted_season"] != 1:
        raise ValueError("Exactly one open legacy season is required")
    if rows[0]["raw_rows"] > 1000000:
        raise ValueError("KVK source exceeds this bounded integration fixture")


def index_state(record, save, count):
    from fresh_business_state import IDENTITY, require_identity
    from poststate_owner import owned

    if count not in (0, 1, 2):
        raise ValueError("Only the three declared deferred-index states are supported")
    with owned("ROK_TRACKER", record, save, timeout=15) as owner:
        require_identity(owner.read(IDENTITY), "ROK_TRACKER", 27)
        rows = owner.read(INDEXES)
    expected = [
        dict(
            name=INDEX_NAMES[i],
            type=2,
            is_unique=False,
            is_disabled=False,
            has_filter=False,
            column_name=("Gov_ID", "KVK_NO")[i],
            key_ordinal=1,
            is_included_column=False,
            is_descending_key=False,
        )
        for i in range(count)
    ]
    if rows != expected:
        raise ValueError("Exact permitted index state differs before the complete comparator")
    return rows


def add_index(record, save, count):
    from fresh_business_state import IDENTITY, require_identity
    from poststate_owner import owned

    if count not in (1, 2):
        raise ValueError("Only the two reviewed performance index definitions are permitted")
    index_state(record, save, count - 1)
    name, column = INDEX_NAMES[count - 1], ("Gov_ID", "KVK_NO")[count - 1]
    sql = (
        """SET NOCOUNT ON; SET XACT_ABORT ON; SET LOCK_TIMEOUT 1000;
-- Capture the control state before identity/metadata expressions are evaluated.
DECLARE @entry_count int=@@TRANCOUNT,@entry_state int=XACT_STATE();
IF @entry_count<>0 OR @entry_state<>0 OR (@@OPTIONS & 2)=2
 THROW 51976,'Settled explicit index transaction owner required.',1;
IF DB_ID()<>27 OR DB_NAME()<>N'ROK_TRACKER'
 OR ORIGINAL_LOGIN()<>N'MINI_AMD\\K98LabAdmin' OR IS_SRVROLEMEMBER('sysadmin')<>1
 THROW 51976,'Exact settled fresh DB27 index owner required.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @r int;
 EXEC @r=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @r IS NULL OR @r NOT IN (0,1) THROW 51977,'Fresh output ownership refused.',1;
 EXEC @r=sys.sp_getapplock @Resource=N'K98:maintenance-schema:v1',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @r IS NULL OR @r NOT IN (0,1) THROW 51978,'Fresh schema ownership refused.',1;
 EXEC dbo.usp_P02BeginCatalogueMutation @Owner='Transaction';
 CREATE NONCLUSTERED INDEX ["""
        + name
        + "] ON dbo.EXCEL_FOR_KVK_16 (["
        + column
        + "] ASC);"
        + """
 COMMIT TRANSACTION;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
DECLARE @exit_count int=@@TRANCOUNT,@exit_state int=XACT_STATE();
SELECT @exit_count AS transaction_count,@exit_state AS transaction_state;"""
    )
    with owned("ROK_TRACKER", record, save, timeout=15) as owner:
        require_identity(owner.read(IDENTITY), "ROK_TRACKER", 27)
        item = dict(index=name, acknowledged=False)
        record.setdefault("index_actions", []).append(item)
        save()
        if owner.read(sql) != [dict(transaction_count=0, transaction_state=0)]:
            raise ValueError("Fresh index transaction did not settle")
        item["acknowledged"] = True
        save()
    return index_state(record, save, count)


def capture_facts(runtime, preparation):
    row, receipt, metadata = runtime.verified_snapshot(preparation)
    raw = runtime.store.read(receipt)
    document = json.loads(raw)
    if row["State"] != "captured" or not document["sections"]:
        raise ValueError("New immutable captured output required")
    sections = deepcopy(document["sections"])
    for section in sections:
        section["rows"] = sorted(
            section["rows"], key=lambda r: json.dumps(r, sort_keys=True, separators=(",", ":"))
        )
    return dict(
        preparation_id=str(row["PreparationID"]).lower(),
        consumer=row["ConsumerKind"],
        snapshot=dict(
            key=receipt.key,
            byte_count=receipt.byte_count,
            sha256=receipt.sha256,
            storage_owner=receipt.storage_owner,
        ),
        generation=metadata["generation"],
        section_count=len(sections),
        row_count=sum(len(s["rows"]) for s in sections),
        sections_sha256=hashlib.sha256(
            json.dumps(sections, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest(),
    )


def verify_old_captures(runtime, captures):
    for old in captures:
        if capture_facts(runtime, old["preparation_id"]) != old:
            raise ValueError("A prior immutable capture changed after the next writer")


def kvk_capture(packet, manifest, bound, connections, record, save, previous):
    from cost_workload import runtime

    from kvk.dal import kvk_admin_dal
    from services.legacy_export_snapshot_service import (
        producer_capture_scope,
        use_runtime,
        writer_scope,
    )

    rt = runtime(packet, manifest, bound, connections)
    started = time.monotonic()
    with use_runtime(rt), producer_capture_scope():
        with writer_scope("all_kvk") as owner:
            record.update(
                preparation_id=owner.claim.preparation_id,
                fresh_observation_present=owner.observation is not None,
            )
            if owner.observation is None:
                raise ValueError("The actual KVK writer must have fresh observer admission")
            record["kvk_dispatch_attempted"] = True
            save()
            result = kvk_admin_dal.recompute_windows(16, owner_token=owner)
            if result != 16 or not owner.producer_authorized or owner.completion is None:
                raise ValueError("Actual KVK recompute completion is unconfirmed")
            record["commit_checkpoint"] = owner.completion
        if not owner.closed or owner.failed:
            raise ValueError("Actual KVK writer cleanup is unconfirmed")
    capture = capture_facts(rt, owner.claim.preparation_id)
    if capture["consumer"] != "all_kvk" or capture["row_count"] <= 0:
        raise ValueError("A nonempty genuine KVK capture is required")
    verify_old_captures(rt, previous)
    record.update(capture=capture, writer_closed=True, seconds=time.monotonic() - started)
    save()
    return capture


def run(packet, manifest, record, save, connections):
    import cost_workload as work
    from fresh_business_state import IDENTITY, require_identity
    from independent_readers import write_new
    from poststate_owner import owned
    import publisher_worker

    with owned("ROK_TRACKER", record, save, timeout=15) as owner:
        require_identity(owner.read(IDENTITY), "ROK_TRACKER", 27)
        source = owner.read(KVK_PREFLIGHT)
        require_kvk_source(source)
    record["kvk_source"] = source
    initial = {}
    try:
        work.contracts(packet, manifest, "ON", initial, connections)
    finally:
        write_new(packet / "chain-initial-contracts.json", initial)
    record["stage"] = "one fresh legacy publication for the zero-index state"
    save()
    record["publication"] = publisher_worker.run(
        connections, manifest["publisher_operation"], record, save
    )
    captures = []
    record["cases"] = []
    for count in (0, 1, 2):
        case = dict(index_count=count, outcome="running")
        record["cases"].append(case)
        record["stage"] = "complete comparator and new KVK capture with " + str(count) + " indexes"
        save()
        if count:
            add_index(record, save, count)
        case["indexes"] = index_state(record, save, count)
        evidence = {}
        try:
            bound = work.contracts(packet, manifest, "ON", evidence, connections)
        finally:
            write_new(packet / ("chain-contracts-" + str(count) + ".json"), evidence)
        case["full_comparator_passed"] = True
        captures.append(kvk_capture(packet, manifest, bound, connections, case, save, captures))
        case["outcome"] = "passed"
        save()
    record["stage"] = "next actual report writer after the final KVK capture"
    save()
    report = {}
    record["next_writer"] = report
    work.report(packet, manifest, bound, connections, report, save, "ON")
    rt = work.runtime(packet, manifest, bound, connections)
    verify_old_captures(rt, captures)
    report_capture = capture_facts(rt, report["preparation_id"])
    if report_capture["consumer"] != "scan_data" or report_capture["row_count"] <= 0:
        raise ValueError("Next writer did not retain its real report capture")
    captures.append(report_capture)
    record.update(
        next_writer=report,
        captures=captures,
        actual_kvk_recomputes=3,
        actual_report_writes=1,
        actual_legacy_publications=1,
        provider_operations=0,
    )
    write_new(packet / "chain-captures.json", captures)
    write_new(packet / "chain-bound-contracts.json", bound)
    index_state(record, save, 2)
    save()


def consume(packet, manifest, record, save, connections):
    import cost_workload as work
    from independent_readers import write_new

    captures = json.loads((packet / "chain-captures.json").read_bytes())
    if len(captures) != 4 or [c["consumer"] for c in captures] != ["all_kvk"] * 3 + ["scan_data"]:
        raise ValueError("Exactly the acknowledged new KVK/report captures are required")
    evidence = {}
    try:
        bound = work.contracts(packet, manifest, "ON", evidence, connections)
    finally:
        write_new(packet / "chain-consumer-contracts.json", evidence)
    rt = work.runtime(packet, manifest, bound, connections)
    verify_old_captures(rt, captures)
    if (
        rt.resolve_preparation(consumer="all_kvk", kvk_no=16) != captures[2]["preparation_id"]
        or rt.resolve_preparation(consumer="scan_data") != captures[3]["preparation_id"]
    ):
        raise ValueError("Fresh consuming process selected an incorrect generation")
    index_state(record, save, 2)
    record.update(
        full_comparator_passed=True,
        captures_verified=[c["preparation_id"] for c in captures],
        provider_operations=0,
        business_operations=0,
        export_jobs_created=0,
    )
    save()
