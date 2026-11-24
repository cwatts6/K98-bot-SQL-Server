"""Remaining source-event and native-value evidence in one new small lab fixture."""

from copy import deepcopy
from datetime import datetime
from decimal import Decimal
import json
from pathlib import Path
import secrets
import sys
from uuid import UUID

PURPOSE = "p02-remaining-source-events-and-types"
PRIOR = Path("Q:/P02Observer/20261122122324235")
RECEIPT_SHA = "dec53d098868a8509fb41a68bb20c54bdf46feed8e9aefa0f3dfb38ca1065091"
ARCHIVE_SHA = "d2aa528d9c24f20a9b0b8438052418cae6b645d37144ff50b6693f2f513d7b21"
COMPLETED = (
    "doomed-preserved-autocommit-True",
    "nested-preserved-autocommit-False",
    "doomed-preserved-autocommit-False",
    "role-create-invalidates",
    "role-membership-invalidates",
    "object-permission-invalidates",
    "missing-row-invalidator",
    "changed-row-invalidator",
    "missing-ddl-invalidator",
    "new-incarnation-rejects-old-proof",
    "exhausted-sequence-refuses-observation",
)
EVENT_GROUPS = (
    (
        "table-index-statistics-events",
        (
            "CREATE TABLE dbo.P02SourceValues(Value int NOT NULL, Extra int NULL)",
            "ALTER TABLE dbo.P02SourceValues ADD CONSTRAINT CK_P02SourceValues CHECK(Value>0)",
            "CREATE INDEX IX_P02SourceValues ON dbo.P02SourceValues(Value)",
            "ALTER INDEX IX_P02SourceValues ON dbo.P02SourceValues DISABLE",
            "ALTER INDEX IX_P02SourceValues ON dbo.P02SourceValues REBUILD",
            "UPDATE STATISTICS dbo.P02SourceValues IX_P02SourceValues WITH FULLSCAN",
            "DROP INDEX IX_P02SourceValues ON dbo.P02SourceValues",
        ),
    ),
    (
        "dynamic-module-type-and-synonym-events",
        (
            "EXEC sys.sp_executesql N'CREATE VIEW dbo.P02SourceView AS SELECT Value FROM dbo.P02SourceValues'",
            "EXEC sys.sp_executesql N'ALTER VIEW dbo.P02SourceView AS SELECT Value,Extra FROM dbo.P02SourceValues'",
            "CREATE TYPE dbo.P02SourceTableType AS TABLE(Value smallint NOT NULL)",
            "CREATE SYNONYM dbo.P02SourceSynonym FOR dbo.P02SourceValues",
            "DROP SYNONYM dbo.P02SourceSynonym",
            "CREATE SYNONYM dbo.P02SourceSynonym FOR dbo.P02SourceView",
            "EXEC sys.sp_addtype @typename=N'P02SourceLegacyType',@phystype=N'int',@nulltype=N'NULL'",
            "DROP TYPE dbo.P02SourceLegacyType",
        ),
    ),
)
SIGNATURE_SQL = """SELECT COUNT_BIG(*) AS signatures FROM sys.crypt_properties
WHERE major_id=OBJECT_ID(N'dbo.P02SourceSigned') AND class=1"""
NATIVE_SQL = """SELECT CONVERT(smallint,-123) AS small_value,
CONVERT(int,2147483647) AS int_value,CONVERT(bigint,9223372036854775806) AS bigint_value,
CONVERT(decimal(28,6),N'1234567890123456789012.345678') AS decimal_value,
CONVERT(uniqueidentifier,N'3f92cf90-9863-44d7-88ef-9845bd303269') AS PreparationID,
CONVERT(binary(4),0x00FE7F01) AS binary_value,
CONVERT(varbinary(4),0x00FE7F) AS bytes_value,
CONVERT(datetime2(6),N'2026-11-22T12:34:56.123456') AS datetime_value,
CONVERT(bit,1) AS flag_value"""


def require_completed(value):
    wanted = dict(
        outcome="passed",
        first_failure=None,
        cleanup_failures=[],
        preservation_failure=None,
        original_preserved=True,
        login_disabled=True,
        physical_custody_retained=False,
        admin_connections_closed=11,
        business_operations=0,
        maintenance_dispatches=0,
        login_enable_attempted=False,
    )
    if (
        any(value.get(k) != v for k, v in wanted.items())
        or value.get("before") != value.get("after")
        or tuple(r.get("name") for r in value.get("checks", [])) != COMPLETED
        or any(r.get("passed") is not True for r in value["checks"])
        or len(value.get("actions", [])) != 18
        or any(r.get("acknowledged") is not True for r in value["actions"])
        or value.get("fixture", {}).get("database_id") != 23
        or value["fixture"].get("name") != "K98_P02Observer_20261122115928689"
        or value["checks"][-1]["facts"].get("fixture_left_exhausted") is not True
    ):
        raise ValueError("Exact completed edge group and settled custody required")


def completed_receipt(packet):
    import protocol_edges as edge

    raw = (packet / "evidence/edge-success.json").read_bytes()
    if (
        edge.sha(raw) != RECEIPT_SHA
        or raw != (PRIOR / "receipt.json").read_bytes()
        or edge.sha((PRIOR / "packet.zip").read_bytes()) != ARCHIVE_SHA
    ):
        raise ValueError("Completed edge receipt/source differs")
    value = json.loads(raw)
    require_completed(value)
    return value


def authenticate(packet, manifest):
    import protocol_edges as edge

    value = completed_receipt(packet)
    latest, prior, old_manifest = edge.authenticate(packet, manifest)
    if value["before"]["databases"] != latest["databases_after"]:
        raise ValueError("Completed fixture has different original database lineage")
    latest = deepcopy(latest)
    latest["databases_after"].append(value["fixture"])
    return latest, prior, old_manifest


def require_packet(packet, manifest):
    import protocol_edges as edge

    if (
        manifest.get("purpose") != PURPOSE
        or manifest.get("completed_edge_receipt_sha256") != RECEIPT_SHA
        or manifest.get("new_database") is not True
        or manifest.get("replay_completed_cases") is not False
    ):
        raise ValueError("Exact remaining source/type qualification required")
    edge.require_packet(packet, dict(manifest, purpose=edge.PURPOSE))


def require_old_fixture(owner, previous):
    import fresh_business_state as state
    import protocol_edges as edge

    rows = state.normalized(owner.read(edge.SEQUENCE_SQL))
    wanted = previous["checks"][-1]["facts"]["sequence"]
    if rows != wanted:
        raise ValueError("Completed exhausted fixture changed")
    return rows


def changed(owner, record, save, label, sql):
    import protocol_edges as edge

    from services.catalogue_observation_dal import ObservationDeferred, require_same_catalogue

    before = edge.boundary(owner)
    owner.mutate(label, sql)
    after = edge.boundary(owner)
    if after.generation <= before.generation:
        raise ValueError("Source event did not invalidate observation: " + label)
    try:
        require_same_catalogue(before, after)
    except ObservationDeferred as error:
        if error.reason != "generation_changed":
            raise
    else:
        raise ValueError("Prior observation survived source event")
    return dict(
        before=before.generation,
        after=after.generation,
        stale_result_refused=True,
        sql_sha256=edge.sha(sql.encode()),
    )


def native_values(rows):
    from kvk.dal.new_source_import_dal import canonical
    from scripts.verify_k98_running_release import retained_row
    from services.export_execution_protocol import ProtocolError, decode, encode
    from services.legacy_export_snapshot_service import (
        OutputSection,
        SnapshotUnavailable,
        _uncell,
        output_digest,
    )

    if len(rows) != 1:
        raise ValueError("One native-value row required")
    row = rows[0]
    expected = dict(
        small_value=-123,
        int_value=2147483647,
        bigint_value=9223372036854775806,
        decimal_value=Decimal("1234567890123456789012.345678"),
        binary_value=b"\x00\xfe\x7f\x01",
        bytes_value=b"\x00\xfe\x7f",
        datetime_value=datetime(2026, 11, 22, 12, 34, 56, 123456),
        flag_value=True,
    )
    if set(row) != set(expected) | {"PreparationID"}:
        raise ValueError("Native projection shape differs")
    for name, value in expected.items():
        if type(row[name]) is not type(value) or row[name] != value:
            raise ValueError("Native SQL value/type differs: " + name)
    normalized = retained_row(row)
    if normalized["PreparationID"] != "3f92cf90-9863-44d7-88ef-9845bd303269":
        raise ValueError("Actual retained UUID normalization differs")
    keep = {k: v for k, v in normalized.items() if k not in {"binary_value", "bytes_value"}}
    section = OutputSection("native_type_qualification", tuple(keep), (tuple(keep.values()),))
    document = section.document()
    decoded = decode(encode(document))
    recovered = OutputSection(
        decoded["name"],
        tuple(decoded["columns"]),
        tuple(tuple(_uncell(v) for v in row) for row in decoded["rows"]),
    )
    if recovered != section:
        raise ValueError("Native output scalar round trip changed values")
    source = json.loads(canonical(keep))
    if (
        source["decimal_value"] != "1234567890123456789012.345678"
        or source["datetime_value"] != "2026-11-22T12:34:56.123456"
    ):
        raise ValueError("Actual source canonicalizer lost precision")
    refusals = []
    for name in ("binary_value", "bytes_value"):
        for kind, action, error_type in (
            (
                "snapshot",
                lambda: OutputSection("unsupported", (name,), ((row[name],),)).document(),
                SnapshotUnavailable,
            ),
            ("source", lambda: canonical({name: row[name]}), TypeError),
            ("message", lambda: encode({name: row[name]}), ProtocolError),
        ):
            try:
                action()
            except error_type:
                refusals.append(name + ":" + kind)
            else:
                raise ValueError("Unsupported raw binary accepted by " + kind)
    # SQL UUIDs may arrive as strings; the actual retained-row normalizer also
    # accepts native UUID objects without broadening other column normalization.
    if (
        retained_row({"PreparationID": UUID(str(row["PreparationID"]))})["PreparationID"]
        != normalized["PreparationID"]
    ):
        raise ValueError("Retained UUID object form differs")
    emitted = encode(dict(source=source, output_section=document, raw_binary_refusals=refusals))
    if decode(emitted)["source"] != source:
        raise ValueError("Actual bounded emitter changed native canonical values")
    import protocol_edges as edge

    return dict(
        native_types={k: type(v).__name__ for k, v in row.items()},
        output_sha256=output_digest((section,)),
        message_sha256=edge.sha(emitted),
        decimal_precision_preserved=True,
        datetime_precision_preserved=True,
        raw_binary_refusals=refusals,
        durable_capture_claimed=False,
    )


def cases(packet, manifest, record, save, *, completed=()):
    import protocol_edges as edge

    if completed:
        raise ValueError("This group contains only previously unexecuted questions")
    prior = completed_receipt(packet)
    old_name = prior["fixture"]["name"]
    with edge.owned_fixture(old_name, record, save) as old:
        record["exhausted_fixture_before"] = require_old_fixture(old, prior)

    def check(label, action):
        item = dict(name=label, passed=False)
        record["checks"].append(item)
        record["stage"] = label
        save()
        item["facts"] = action()
        item["passed"] = True
        save()

    with edge.owned_fixture(manifest["database"], record, save) as owner:
        for group, statements in EVENT_GROUPS:

            def events(group=group, statements=statements):
                return [
                    changed(owner, record, save, group + ":" + str(i), sql)
                    for i, sql in enumerate(statements)
                ]

            check(group, events)

        def signatures():
            # Ephemeral key protection is generated only in the guest. It is not
            # an application credential; neither value nor SQL text is emitted.
            password = secrets.token_hex(32)
            actions = (
                "CREATE PROCEDURE dbo.P02SourceSigned AS BEGIN SET NOCOUNT ON; SELECT 1 AS value; END",
                "CREATE CERTIFICATE P02SourceCertificate ENCRYPTION BY PASSWORD='"
                + password
                + "' WITH SUBJECT='isolated source event qualification'",
                "ADD SIGNATURE TO OBJECT::dbo.P02SourceSigned BY CERTIFICATE P02SourceCertificate WITH PASSWORD='"
                + password
                + "'",
            )
            result = [
                changed(owner, record, save, "signature event:" + str(i), sql)
                for i, sql in enumerate(actions)
            ]
            if owner.read(SIGNATURE_SQL) != [dict(signatures=1)]:
                raise ValueError("Actual module signature missing")
            result.append(
                changed(
                    owner,
                    record,
                    save,
                    "signature removed",
                    "DROP SIGNATURE FROM OBJECT::dbo.P02SourceSigned BY CERTIFICATE P02SourceCertificate",
                )
            )
            if owner.read(SIGNATURE_SQL) != [dict(signatures=0)]:
                raise ValueError("Removed signature remained")
            return result

        check("signature-add-remove-invalidates", signatures)

        def disabled():
            owner.mutate(
                "disable only new fixture row invalidator",
                "DISABLE TRIGGER dbo.tr_P02HeaderObservation ON dbo.KVKFinalReportHeader",
            )
            failure = edge.require_refusal(lambda: edge.boundary(owner), contract=True)
            owner.mutate(
                "restore new fixture invalidator",
                "ENABLE TRIGGER dbo.tr_P02HeaderObservation ON dbo.KVKFinalReportHeader",
            )
            result = edge.boundary(owner)
            return dict(refusal=failure, restored_generation=result.generation)

        check("disabled-row-invalidator-refuses", disabled)
        check(
            "native-values-through-real-canonicalizers",
            lambda: native_values(owner.read(NATIVE_SQL)),
        )
        record["final_fixture_boundary"] = dict(identity=edge.boundary(owner).identity)
    with edge.owned_fixture(old_name, record, save) as old:
        record["exhausted_fixture_after"] = require_old_fixture(old, prior)
    if record["exhausted_fixture_before"] != record["exhausted_fixture_after"]:
        raise ValueError("Retained exhausted fixture changed")


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    sys.path.insert(0, str(packet / "qualification/p02_observer"))
    require_packet(packet, manifest)
    from release_boundary import native_paths

    native_paths(packet)
    import protocol_edges as edge
    import pyodbc

    pyodbc.pooling = False
    return edge.run(packet, manifest, authenticator=authenticate, case_runner=cases)


if __name__ == "__main__":
    raise SystemExit(main())
