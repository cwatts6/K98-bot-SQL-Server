"""Generate declarative history-table metadata; never connects to SQL.

The operator supplies observed collations/compatibility. Commit and review the
resulting migration profile before pinning it in a Bot release description.
"""

import argparse
import json
from pathlib import Path


def column(name, kind):
    return dict(
        name=name,
        type=kind,
        nullable=False,
        collation="Latin1_General_100_BIN2" if "varchar" in kind else None,
    )


def term(op, column, value):
    return dict(op=op, column=column, value=value)


def check(name, *terms):
    return dict(
        name=name, expression=terms[0] if len(terms) == 1 else dict(op="and", args=list(terms))
    )


def history_tables():
    scope = [
        column("IntentID", "uniqueidentifier"),
        column("GuildID", "varchar(32)"),
        column("HistoryVersion", "varchar(64)"),
    ]
    keys = ["IntentID", "GuildID", "HistoryVersion"]
    return [
        dict(
            schema="KVK",
            name="SourceExportHistory",
            columns=scope
            + [
                column("SourceKey", "varchar(32)"),
                column("KVK_NO", "int"),
                column("VectorHash", "binary(32)"),
                column("CapturedUTC", "datetime2(0)"),
                column("AttemptCount", "bigint"),
                column("ContentHash", "binary(32)"),
            ],
            primary_key=dict(name="PK_SourceExportHistory", columns=keys),
            unique_keys=[],
            checks=[
                check(
                    "CK_SourceExportHistory_Scope",
                    term("eq", "SourceKey", "snapshot_report_v1"),
                    term("bytes_eq", "SourceKey", 18),
                    term("gt", "KVK_NO", 0),
                ),
                check(
                    "CK_SourceExportHistory_Guild",
                    term("bytes_between", "GuildID", [1, 32]),
                    term("digits", "GuildID", True),
                ),
                check(
                    "CK_SourceExportHistory_Version",
                    term("eq", "HistoryVersion", "source_export_history_v1"),
                    term("bytes_eq", "HistoryVersion", 24),
                ),
                check("CK_SourceExportHistory_Count", term("ge", "AttemptCount", 0)),
            ],
            foreign_keys=[
                dict(
                    name="FK_SourceExportHistory_Intent",
                    columns=["SourceKey", "KVK_NO", "IntentID"],
                    schema="KVK",
                    table="SourceExportIntent",
                    target_columns=["SourceKey", "KVK_NO", "IntentID"],
                )
            ],
        ),
        dict(
            schema="KVK",
            name="SourceExportHistoryRow",
            columns=scope
            + [
                column("Ordinal", "bigint"),
                column("AttemptID", "uniqueidentifier"),
                column("PayloadJson", "nvarchar(max)"),
                column("RowHash", "binary(32)"),
            ],
            primary_key=dict(name="PK_SourceExportHistoryRow", columns=keys + ["Ordinal"]),
            unique_keys=[
                dict(name="UQ_SourceExportHistoryRow_Attempt", columns=keys + ["AttemptID"])
            ],
            checks=[
                check("CK_SourceExportHistoryRow_Ordinal", term("gt", "Ordinal", 0)),
                check(
                    "CK_SourceExportHistoryRow_Payload",
                    term("json", "PayloadJson", 1),
                    term("bytes_max", "PayloadJson", 16384),
                ),
            ],
            foreign_keys=[
                dict(
                    name="FK_SourceExportHistoryRow_History",
                    columns=keys,
                    schema="KVK",
                    table="SourceExportHistory",
                    target_columns=keys,
                )
            ],
        ),
    ]


def profile(database_collation, tempdb_collation, compatibility_level):
    return dict(
        version=1,
        profile="additive_tables_v1",
        migration_id="20261013_001_kvk_export_history",
        database_collation=database_collation,
        tempdb_collation=tempdb_collation,
        compatibility_level=compatibility_level,
        tables=history_tables(),
        requires=[],
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-collation", required=True)
    parser.add_argument("--tempdb-collation", required=True)
    parser.add_argument(
        "--compatibility-level", required=True, type=int, choices=[130, 140, 150, 160]
    )
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    import re

    if any(
        not re.fullmatch(r"[A-Za-z0-9_]{1,128}", value)
        for value in (args.database_collation, args.tempdb_collation)
    ):
        parser.error("Ordinary observed collation names required")
    with args.output.open("x", encoding="utf-8", newline="\n") as output:
        output.write(
            json.dumps(
                profile(args.database_collation, args.tempdb_collation, args.compatibility_level),
                indent=2,
            )
            + "\n"
        )
    print("PROFILE_WRITTEN_NOT_APPLIED: " + str(args.output))
