"""Combined exact-number candidate versus frozen endpoint baseline, local only."""

from collections import Counter
from decimal import ROUND_HALF_UP, Decimal, localcontext
import importlib.util
import json

import pytest
import test_summary_endpoints as ref

PACK = ref.ROOT / "qualification/p02_phase1"
spec = importlib.util.spec_from_file_location("phase1_apply", PACK / "apply.py")
upgrade = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upgrade)
AGG_IDS = (999999997, 999999998, 999999999)
SUMMARY_TABLES = (
    "DEADSSUMMARY",
    "POWERSUMMARY",
    "KILLSUMMARY",
    "KILL4SUMMARY",
    "KILL5SUMMARY",
    "KILLPOINTSSUMMARY",
    "HEALEDSUMMARY",
    "RANGEDSUMMARY",
)


@pytest.fixture(scope="module")
def databases():
    generator = ref.databases.__wrapped__()
    pair = next(generator)
    try:
        for con in pair:
            ref.install_bodies(con, True, frozen=False)
            con.execute("CREATE PROCEDURE dbo.GOVERNOR_NAMES_PROC AS RETURN;")
            con.execute(upgrade.BEFORE["GOVERNOR_NAMES_PROC"])
            con.execute(
                ref.TABLE_FILES["all_govs_names"][1].read_text(encoding="utf-8-sig")
            )
        upgrade.apply(pair[1])
        yield pair
    finally:
        try:
            next(generator)
        except StopIteration:
            pass


def install(con, numeric, frozen=True):
    for name in ref.ALL_MODULES:
        text = upgrade.candidate(name) if numeric else upgrade.BEFORE[name]
        if frozen:
            text = text.replace(
                "SYSUTCDATETIME()", "CONVERT(datetime2(7),'2026-11-07T12:00:00',126)"
            )
        con.execute(text)


@pytest.fixture
def pair(databases):
    for numeric, con in enumerate(databases):
        for table in ref.TABLES + ["ALL_GOVS_NAMES"]:
            con.execute(f"TRUNCATE TABLE dbo.[{table}]")
        install(con, bool(numeric))
    yield databases
    for con in databases:
        if con.execute("SELECT @@TRANCOUNT").fetchval():
            con.execute("ROLLBACK")


def rows(con, table):
    cursor = con.execute(f"SELECT * FROM dbo.[{table}]")
    cols = [c[0] for c in cursor.description]
    return cols, [tuple(r) for r in cursor.fetchall()]


def verify_exact_averages(con):
    aggregate_fields = {}
    for table in SUMMARY_TABLES:
        cols, data = rows(con, table)
        lower = [c.lower() for c in cols]
        gi, ri = lower.index("governorid"), lower.index("powerrank")
        metrics = [
            i
            for i, c in enumerate(lower)
            if c not in {"governorid", "governorname", "powerrank"}
        ]
        for gov, rank in zip(AGG_IDS, (50, 100, 150), strict=True):
            found = [r for r in data if r[gi] == gov]
            if not found:
                continue
            assert len(found) == 1
            actual = found[0]
            players = [r for r in data if r[gi] not in AGG_IDS and r[ri] <= rank]
            for i in metrics:
                values = [r[i] for r in players if r[i] is not None]
                with localcontext() as context:
                    context.prec = 60
                    expected = (
                        int(
                            (sum(map(Decimal, values)) / Decimal(len(values))).quantize(
                                Decimal(1), rounding=ROUND_HALF_UP
                            )
                        )
                        if values
                        else None
                    )
                assert actual[i] == expected, (table, gov, cols[i], actual[i], expected)
                aggregate_fields[(gov, cols[i].lower())] = expected
    return aggregate_fields


def compare(pair, proc="SUMMARY_PROC"):
    for con in pair:
        con.execute(f"EXEC dbo.[{proc}]")
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
    expected_aggregates = verify_exact_averages(pair[1])
    changes = []
    for table in ref.OUTPUTS:
        cols, old = rows(pair[0], table)
        cols_new, new = rows(pair[1], table)
        assert cols == cols_new
        if table == "SUMMARY_PROC_STATE":
            assert Counter(old) == Counter(new)
            continue
        gi = next(i for i, c in enumerate(cols) if c.lower() == "governorid")
        assert Counter(r for r in old if r[gi] not in AGG_IDS) == Counter(
            r for r in new if r[gi] not in AGG_IDS
        ), table
        old_agg = {r[gi]: r for r in old if r[gi] in AGG_IDS}
        new_agg = {r[gi]: r for r in new if r[gi] in AGG_IDS}
        assert old_agg.keys() == new_agg.keys()
        for gov, row in new_agg.items():
            for i, (left, right) in enumerate(zip(old_agg[gov], row, strict=True)):
                if left != right:
                    # Every difference must be an independently calculated exact
                    # aggregate field. No tolerance and no player-row exceptions.
                    assert (gov, cols[i].lower()) in expected_aggregates
                    assert right == expected_aggregates[(gov, cols[i].lower())]
                    changes.append(
                        dict(
                            table=table,
                            governor=gov,
                            column=cols[i],
                            before=left,
                            after=right,
                        )
                    )
    return changes


def test_phase1_source_contract():
    assert len(upgrade.MANIFEST["tables"]) == 139
    assert len(upgrade.INDEXES) == 31
    for name in ref.NAMES:
        text = upgrade.candidate(name)
        assert "[float]" not in text
        assert text.count("AVG(CONVERT(decimal(38,6),") == 18
        assert "BEGIN TRANSACTION" in text or "BEGIN TRAN;" in text
        assert "ROLLBACK" in text
    assert upgrade.candidate("SUMMARY_PROC") == upgrade.BEFORE["SUMMARY_PROC"]
    assert (
        upgrade.candidate("GOVERNOR_NAMES_PROC")
        == upgrade.BEFORE["GOVERNOR_NAMES_PROC"]
    )


def test_combined_names_summary_and_enumerated_rounding(pair, tmp_path):
    for con in pair:
        ref.seed(con, ref.history_rows())
        con.execute(
            "UPDATE dbo.KingdomScanData4 SET GovernorName=CASE WHEN ScanOrder<5 THEN N'ALPHA' ELSE N'Alpha' END WHERE GovernorID=1"
        )
        # Execute the exact changed name statement against this owned source;
        # the full legacy proc's explicit production DB binding is never invoked.
        step = (
            upgrade.candidate("GOVERNOR_NAMES_PROC")
            .split("-- Step 4:", 1)[1]
            .split("-- Step 5:", 1)[0]
        )
        step = step[step.index("TRUNCATE TABLE") :].replace("ROK_TRACKER.dbo.", "dbo.")
        con.execute(step)
        assert (
            con.execute(
                "SELECT RTRIM(GovernorName) FROM dbo.ALL_GOVS_NAMES WHERE GovernorID=1"
            ).fetchval()
            == "Alpha"
        )
    changes = compare(pair)
    assert changes  # bigint AVG truncation is intentionally corrected.
    (tmp_path / "phase1_expected_rounding_changes.json").write_text(
        json.dumps(changes, indent=2), encoding="utf-8"
    )
    for con in pair:
        con.execute(
            "UPDATE dbo.KingdomScanData4 SET Power=7777,Deads=88 WHERE GovernorID=1 AND ScanOrder=1"
        )
        ref.seed(con, [ref.record(1, 6, ref.NOW, 255), ref.record(11, 6, ref.NOW, 999)])
    compare(pair)
    before = [ref.snap(c) for c in pair]
    compare(pair)
    assert [ref.snap(c) for c in pair] == before
    assert not any(v[1] for v in ref.snap(pair[1], ref.HISTORY).values())


@pytest.mark.parametrize("proc", ref.NAMES)
def test_all_direct_entries(pair, proc):
    for con in pair:
        ref.seed(con, ref.history_rows())
    compare(pair, proc)
    for con in pair:
        ref.seed(con, [ref.record(1, 6, ref.NOW, 107)])
    compare(pair, proc)


@pytest.mark.parametrize("value", [2**31, 2**53 + 1, 2**63 - 1])
def test_exact_large_values_and_non_overflowing_averages(pair, value):
    con = pair[1]
    records = [ref.record(g, 1, ref.NOW, 1) for g in (1, 2, 3)]
    for record in records:
        for metric in (
            "Power",
            "KillPoints",
            "Deads",
            "T4_Kills",
            "T5_Kills",
            "T4&T5_KILLS",
            "HealedTroops",
            "RangedPoints",
        ):
            record[ref.COLUMNS.index(metric)] = value
    ref.seed(con, records)
    con.execute("EXEC dbo.SUMMARY_PROC")
    values = con.execute(
        "SELECT GovernorID,Power,KillPoints,HealedTroops FROM dbo.SUMMARY_CHANGE_EXPORT"
    ).fetchall()
    assert len(values) == 6
    assert all(tuple(row[1:]) == (value, value, value) for row in values)
    assert all(type(v) is int for row in values for v in row)
    verify_exact_averages(con)


@pytest.mark.parametrize(
    "proc", ["SUMMARY_PROC", "POWERSUMMARY_PROC", "HEALEDSUMMARY_PROC_OPT"]
)
def test_overflow_rolls_back_outputs_and_state(pair, proc):
    con = pair[1]
    first = ref.record(1, 1, ref.NOW, 1)
    second = ref.record(1, 2, ref.NOW, 1)
    field = "HealedTroops" if "HEALED" in proc else "Power"
    first[ref.COLUMNS.index(field)] = -(2**63)
    second[ref.COLUMNS.index(field)] = 2**63 - 1
    ref.seed(con, [first, second])
    before = ref.snap(con)
    with pytest.raises(Exception, match=r"(?i)overflow"):
        con.execute(f"EXEC dbo.[{proc}]")
    assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
    assert ref.snap(con) == before


def test_negative_halfway_rounding(pair):
    con = pair[1]
    data = [ref.record(1, 1, ref.NOW, 1), ref.record(2, 1, ref.NOW, 1)]
    data[0][ref.COLUMNS.index("Power")] = -1
    data[1][ref.COLUMNS.index("Power")] = -2
    ref.seed(con, data)
    con.execute("EXEC dbo.SUMMARY_PROC")
    assert (
        con.execute(
            "SELECT Power FROM dbo.POWERSUMMARY WHERE GovernorID=999999997"
        ).fetchval()
        == -2
    )


def test_migration_round_trip_data_indexes_and_permissions(pair):
    con = pair[1]
    install(con, True, frozen=False)
    ref.seed(con, ref.history_rows())
    con.execute("EXEC dbo.SUMMARY_PROC")
    before = ref.snap(con)
    upgrade.apply(con)
    upgrade.apply(con, "rollback")
    upgrade.apply(con, "rollback")
    assert ref.snap(con) == before
    upgrade.apply(con)
    assert ref.snap(con) == before
    assert (
        con.execute(
            "SELECT COUNT(*) FROM sys.database_permissions WHERE grantee_principal_id=USER_ID('SummaryFixtureReader') AND permission_name='EXECUTE'"
        ).fetchval()
        == 10
    )


def test_migration_rejects_fraction_and_unknown_index_atomically(pair):
    con = pair[1]
    install(con, True, frozen=False)
    upgrade.apply(con, "rollback")
    try:
        con.execute(
            "INSERT dbo.POWERSUMMARY(GovernorID,PowerRank,Power) VALUES(1,1,1.5)"
        )
        with pytest.raises(ValueError, match="Unsafe numeric conversion"):
            upgrade.apply(con)
        assert con.execute("SELECT Power FROM dbo.POWERSUMMARY").fetchval() == 1.5
        con.execute("TRUNCATE TABLE dbo.POWERSUMMARY")
        con.execute("CREATE INDEX Phase1Unexpected ON dbo.POWERSUMMARY(GovernorID)")
        try:
            with pytest.raises(ValueError, match="index layout"):
                upgrade.apply(con)
        finally:
            con.execute("DROP INDEX Phase1Unexpected ON dbo.POWERSUMMARY")
    finally:
        con.execute("TRUNCATE TABLE dbo.POWERSUMMARY")
        upgrade.apply(con)


def test_rollback_rejects_new_large_values_without_changes(pair):
    con = pair[1]
    install(con, True, frozen=False)
    con.execute(
        "INSERT dbo.POWERSUMMARY(GovernorID,PowerRank,Power) VALUES(1,1,9007199254740993)"
    )
    before = ref.snap(con)
    with pytest.raises(ValueError, match="Unsafe numeric conversion"):
        upgrade.apply(con, "rollback")
    assert ref.snap(con) == before
    assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0


def test_migration_rejects_wrong_owner_and_drift(pair):
    con = pair[1]
    install(con, True, frozen=False)
    token = con.execute(
        "SELECT CONVERT(nvarchar(32),SESSION_CONTEXT(N'P021SummaryFixtureOwner'))"
    ).fetchval()
    con.execute(
        "EXEC sys.sp_set_session_context @key=N'P021SummaryFixtureOwner',@value=N'wrong'"
    )
    try:
        with pytest.raises(ValueError, match="exact owned local fixture"):
            upgrade.apply(con)
    finally:
        con.execute(
            "EXEC sys.sp_set_session_context @key=N'P021SummaryFixtureOwner',@value=?",
            token,
        )
    con.execute("ALTER PROCEDURE dbo.RANGEDSUMMARY_PROC AS SELECT 1")
    try:
        with pytest.raises(ValueError, match="module body drift"):
            upgrade.apply(con)
    finally:
        install(con, True, frozen=False)


def test_duplicate_latest_and_mid_parent_failure(pair):
    con = pair[1]
    ref.seed(con, ref.history_rows())
    con.execute("EXEC dbo.SUMMARY_PROC")
    ref.seed(con, [ref.record(1, 6, ref.NOW, 88)])
    before = ref.snap(con)
    con.execute(
        "CREATE TRIGGER dbo.Phase1Fault ON dbo.HEALEDSUMMARY AFTER INSERT,UPDATE AS BEGIN THROW 51090,'Phase1 injected failure',1; END"
    )
    try:
        with pytest.raises(Exception, match="Phase1 injected failure"):
            con.execute("EXEC dbo.SUMMARY_PROC")
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
        assert ref.snap(con) == before
    finally:
        con.execute("DROP TRIGGER dbo.Phase1Fault")
    ref.seed(con, [ref.record(1, 6, ref.NOW, 99)])
    with pytest.raises(Exception, match=r"(?i)(MERGE|duplicate|unique)"):
        con.execute("EXEC dbo.SUMMARY_PROC")
    assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
    assert ref.snap(con) == before


@pytest.mark.parametrize(
    "months,cutoff",
    [
        (3, ref.datetime(2026, 8, 7, 12)),
        (6, ref.datetime(2026, 5, 7, 12)),
        (12, ref.datetime(2025, 11, 7, 12)),
    ],
)
def test_window_boundaries(pair, months, cutoff):
    ref.test_inclusive_window_boundaries(pair, months, cutoff)


def test_exact_caller_permission_boundary(pair):
    con = pair[1]
    install(con, True, frozen=False)
    ref.seed(con, ref.history_rows())
    con.execute("EXECUTE AS USER='SummaryFixtureReader'")
    try:
        with pytest.raises(Exception, match="SUMMARY_CHANGE_EXPORT"):
            con.execute("EXEC dbo.SUMMARY_PROC")
    finally:
        con.execute("REVERT")
    assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
    assert not con.execute("SELECT 1 FROM dbo.SUMMARY_PROC_STATE").fetchall()
    con.execute("GRANT ALTER ON dbo.SUMMARY_CHANGE_EXPORT TO SummaryFixtureReader")
    con.execute("EXECUTE AS USER='SummaryFixtureReader'")
    try:
        con.execute("EXEC dbo.SUMMARY_PROC")
    finally:
        con.execute("REVERT")
        con.execute(
            "REVOKE ALTER ON dbo.SUMMARY_CHANGE_EXPORT FROM SummaryFixtureReader"
        )
    verify_exact_averages(con)


def test_migration_signed_module_and_mid_schema_failure_are_atomic(pair):
    con = pair[1]
    install(con, True, frozen=False)
    con.execute(
        "CREATE CERTIFICATE Phase1FixtureCert ENCRYPTION BY PASSWORD='FixtureOnly_7N!k2xR' WITH SUBJECT='Disposable phase1';"
    )
    con.execute(
        "ADD SIGNATURE TO dbo.DEADSSUMMARY_PROC BY CERTIFICATE Phase1FixtureCert WITH PASSWORD='FixtureOnly_7N!k2xR';"
    )
    try:
        with pytest.raises(ValueError, match="Signed module"):
            upgrade.apply(con)
    finally:
        con.execute(
            "DROP SIGNATURE FROM dbo.DEADSSUMMARY_PROC BY CERTIFICATE Phase1FixtureCert"
        )
        con.execute("DROP CERTIFICATE Phase1FixtureCert")
    con.execute(
        "CREATE TRIGGER Phase1AlterFault ON DATABASE FOR ALTER_TABLE AS BEGIN THROW 51091,'Phase1 schema fault',1; END"
    )
    try:
        with pytest.raises(Exception, match="Phase1 schema fault"):
            upgrade.apply(con, "rollback")
        assert con.execute("SELECT @@TRANCOUNT").fetchval() == 0
        # All definitions/types/indexes must still satisfy a repeated candidate install.
        upgrade.apply(con)
    finally:
        con.execute("DROP TRIGGER Phase1AlterFault ON DATABASE")
