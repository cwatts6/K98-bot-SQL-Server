"""Local Phase 1 qualification only; deliberately refuses VM/production targets.

Converts the qualified endpoint-only baseline to exact numeric outputs, or back.
Rollback retains current output/state rows and the endpoint rewrite/name fix. It
never runs a business procedure or rebuilds immutable queued provider payloads.
"""

import hashlib
import json
from pathlib import Path
import re

PACK = Path(__file__).resolve().parent
ROOT = PACK.parents[1]
MANIFEST = json.loads((PACK / "manifest.json").read_text(encoding="utf-8"))
BEFORE = json.loads((PACK / "endpoint_modules.json").read_text(encoding="utf-8"))
INDEXES = json.loads((PACK / "index_contract.json").read_text(encoding="utf-8"))
BASE_TABLES = json.loads((PACK / "endpoint_tables.json").read_text(encoding="utf-8"))


def q(name):
    return "[" + name.replace("]", "]]") + "]"


def body(text):
    text = text.replace("\r\n", "\n").strip()
    return re.sub(r"\ACREATE(?: OR ALTER)? PROCEDURE", "ALTER PROCEDURE", text)


def candidate(name):
    # Immutable numeric-stage qualification. Shared report names is installed
    # separately from qualification/p02_report_names after this stage.
    return json.loads((PACK / "numeric_modules.json").read_text(encoding="utf-8"))[name]


def _indexes(con, table):
    result = []
    for i in con.execute(
        "SELECT index_id,i.name,i.type,is_unique,is_disabled,has_filter,fill_factor,"
        "is_padded,ignore_dup_key,allow_row_locks,allow_page_locks,"
        "ds.name FROM sys.indexes i JOIN sys.data_spaces ds ON ds.data_space_id=i.data_space_id "
        "WHERE object_id=OBJECT_ID(?) AND index_id>0 AND is_primary_key=0 ORDER BY i.name",
        "dbo." + table,
    ).fetchall():
        columns = con.execute(
            "SELECT c.name,ic.is_descending_key,ic.is_included_column "
            "FROM sys.index_columns ic JOIN sys.columns c "
            "ON c.object_id=ic.object_id AND c.column_id=ic.column_id "
            "WHERE ic.object_id=OBJECT_ID(?) AND ic.index_id=? ORDER BY ic.index_column_id",
            "dbo." + table,
            i[0],
        ).fetchall()
        if tuple(i[4:]) != (False, False, 0, False, False, True, True, "PRIMARY"):
            raise ValueError("Unreviewed index options: " + table + "." + i[1])
        result.append(
            dict(
                name=i[1],
                type=i[2],
                unique=bool(i[3]),
                keys=[[c[0], "DESC" if c[1] else "ASC"] for c in columns if not c[2]],
                includes=[c[0] for c in columns if c[2]],
            )
        )
    if con.execute(
        "SELECT COUNT(*) FROM sys.indexes i JOIN sys.stats s ON s.object_id=i.object_id AND s.stats_id=i.index_id "
        "WHERE i.object_id=OBJECT_ID(?) AND i.index_id>0 AND (i.fill_factor<>0 OR i.is_padded<>0 OR i.ignore_dup_key<>0 OR i.allow_row_locks<>1 OR i.allow_page_locks<>1 OR i.optimize_for_sequential_key<>0 OR s.no_recompute<>0)",
        "dbo." + table,
    ).fetchval():
        raise ValueError("Unreviewed index/statistics options: " + table)
    expected = sorted(
        [{k: v for k, v in i.items() if k != "sql"} for i in INDEXES[table]],
        key=lambda i: i["name"],
    )
    if result != expected:
        raise ValueError("Unreviewed index layout: " + table)
    if con.execute(
        "SELECT COUNT(*) FROM sys.partitions WHERE object_id=OBJECT_ID(?) "
        "AND (partition_number<>1 OR data_compression<>0)",
        "dbo." + table,
    ).fetchval():
        raise ValueError("Unreviewed compression/partition layout: " + table)


def _primary_key(con, table):
    expected = re.search(
        r"PRIMARY KEY (CLUSTERED|NONCLUSTERED)\s*\((.*?)\)WITH (.*? ON \[PRIMARY\])",
        BASE_TABLES[table],
        re.S,
    )
    rows = con.execute(
        "SELECT name,type,is_unique,is_disabled FROM sys.indexes WHERE object_id=OBJECT_ID(?) AND is_primary_key=1",
        "dbo." + table,
    ).fetchall()
    if bool(expected) != bool(rows) or len(rows) > 1:
        raise ValueError("Unreviewed primary key layout: " + table)
    if not rows:
        return None
    name, kind, unique, disabled = rows[0]
    keys = con.execute(
        "SELECT c.name,ic.is_descending_key FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id JOIN sys.indexes i ON i.object_id=ic.object_id AND i.index_id=ic.index_id WHERE i.object_id=OBJECT_ID(?) AND i.is_primary_key=1 ORDER BY ic.key_ordinal",
        "dbo." + table,
    ).fetchall()
    expected_keys = re.findall(r"\[([^]]+)\]\s+(ASC|DESC)", expected[2])
    if (
        kind != (1 if expected[1] == "CLUSTERED" else 2)
        or not unique
        or disabled
        or [(r[0], "DESC" if r[1] else "ASC") for r in keys] != expected_keys
    ):
        raise ValueError("Unreviewed primary key columns: " + table)
    return (
        name,
        "ALTER TABLE dbo."
        + q(table)
        + " ADD CONSTRAINT "
        + q(name)
        + " "
        + expected[0],
    )


def apply(con, direction="forward"):
    if direction not in {"forward", "rollback"}:
        raise ValueError("Unknown Phase 1 direction")
    server, database, token, owner, transactions = con.execute(
        "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME(),"
        "CONVERT(nvarchar(32),SESSION_CONTEXT(N'P021SummaryFixtureOwner')),"
        "(SELECT CONVERT(nvarchar(32),value) FROM sys.extended_properties "
        "WHERE class=0 AND name=N'P021SummaryFixtureOwner'),@@TRANCOUNT"
    ).fetchone()
    if (
        server != "9SX2VF4\\K98DEV"
        or not re.fullmatch(r"K98_P021_SummaryTest_[0-9a-f]{32}", database)
        or token != database[-32:]
        or owner != token
        or transactions
    ):
        raise ValueError(
            "Phase 1 requires its own transaction and exact owned local fixture"
        )
    after = {name: candidate(name) for name in BEFORE}
    for name in BEFORE:
        for label, text in [("before", BEFORE[name]), ("after", after[name])]:
            if (
                hashlib.sha256(text.encode()).hexdigest()
                != MANIFEST["modules"][name][label + "SHA256"]
            ):
                raise ValueError("Phase 1 source package drift: " + name)
    con.execute("SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;")
    con.execute("BEGIN TRANSACTION")
    try:
        kinds = set()
        primary_keys = {}
        for table in INDEXES:
            # Exclude concurrent writers until schema, data and module checks commit.
            con.execute(
                f"SELECT COUNT_BIG(*) FROM dbo.{q(table)} WITH(TABLOCKX,HOLDLOCK)"
            ).fetchval()
            _indexes(con, table)
            primary_keys[table] = _primary_key(con, table)
        for c in MANIFEST["tables"]:
            actual = con.execute(
                "SELECT t.name,c.is_nullable FROM sys.columns c JOIN sys.types t "
                "ON t.user_type_id=c.user_type_id WHERE c.object_id=OBJECT_ID(?) AND c.name=?",
                "dbo." + c["table"],
                c["column"],
            ).fetchone()
            if actual is None or bool(actual[1]) != c["nullable"]:
                raise ValueError("Phase 1 column contract drift")
            if actual[0] == c["before"]:
                kinds.add("before")
            elif actual[0] == c["after"]:
                kinds.add("after")
            else:
                raise ValueError("Phase 1 column type drift")
        if len(kinds) != 1:
            raise ValueError("Mixed Phase 1 schema state")
        state = kinds.pop()
        for name in BEFORE:
            row = con.execute(
                "SELECT definition,execute_as_principal_id,uses_ansi_nulls,uses_quoted_identifier "
                "FROM sys.sql_modules WHERE object_id=OBJECT_ID(?)",
                "dbo." + name,
            ).fetchone()
            if (
                row is None
                or row[0] is None
                or row[1] is not None
                or not row[2]
                or not row[3]
            ):
                raise ValueError("Phase 1 module execution contract drift")
            expected = BEFORE[name] if state == "before" else after[name]
            if body(row[0]) != expected:
                raise ValueError("Phase 1 module body drift: " + name)
            if con.execute(
                "SELECT COUNT(*) FROM sys.crypt_properties WHERE major_id=OBJECT_ID(?)",
                "dbo." + name,
            ).fetchval():
                raise ValueError("Signed module requires a separately reviewed release")
        wanted = "after" if direction == "forward" else "before"
        if state != wanted:
            # Fail on fractions/out-of-range before any ALTER, including rollback
            # when new values no longer fit the old consecutive-integer domain.
            for c in MANIFEST["tables"]:
                col = q(c["column"])
                if direction == "forward":
                    predicate = f"{col}<>FLOOR({col}) OR TRY_CONVERT({c['after']},{col}) IS NULL"
                else:
                    predicate = f"{col}>9007199254740992 OR {col}<-9007199254740992"
                if con.execute(
                    f"SELECT TOP(1) 1 FROM dbo.{q(c['table'])} WHERE {col} IS NOT NULL AND ({predicate})"
                ).fetchone():
                    raise ValueError(
                        "Unsafe numeric conversion: " + c["table"] + "." + c["column"]
                    )
            if direction == "rollback":
                # Old endpoint temps are float: refuse future replay precision loss
                # even when the new source value has not reached an output yet.
                cols = [
                    "GovernorID",
                    "Power",
                    "Deads",
                    "T4_Kills",
                    "T5_Kills",
                    "T4&T5_KILLS",
                    "KillPoints",
                    "HealedTroops",
                    "RangedPoints",
                ]
                predicate = " OR ".join(
                    f"{q(c)}>9007199254740992 OR {q(c)}<-9007199254740992" for c in cols
                )
                if con.execute(
                    "SELECT TOP(1) 1 FROM dbo.KingdomScanData4 WHERE " + predicate
                ).fetchone():
                    raise ValueError("Source history exceeds safe float rollback range")
            for table, indexes in INDEXES.items():
                for index in indexes:
                    con.execute(f"DROP INDEX {q(index['name'])} ON dbo.{q(table)}")
            for table, pk in primary_keys.items():
                if pk:
                    con.execute(
                        f"ALTER TABLE dbo.{q(table)} DROP CONSTRAINT {q(pk[0])}"
                    )
            for c in MANIFEST["tables"]:
                target = c[wanted]
                null = "NULL" if c["nullable"] else "NOT NULL"
                con.execute(
                    f"ALTER TABLE dbo.{q(c['table'])} ALTER COLUMN {q(c['column'])} {target} {null}"
                )
            for pk in primary_keys.values():
                if pk:
                    con.execute(pk[1])
            for indexes in INDEXES.values():
                for index in indexes:
                    con.execute(index["sql"])
            for name in BEFORE:
                con.execute(after[name] if direction == "forward" else BEFORE[name])
        con.execute("COMMIT TRANSACTION")
    except BaseException:
        if con.execute("SELECT @@TRANCOUNT").fetchval():
            con.execute("ROLLBACK TRANSACTION")
        raise
