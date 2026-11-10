"""Exact business preservation across the optional final-report upkeep extraction."""

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "6504865ec34fe1e3d7567d25aa892f7c811a636d"


def old_source(name):
    return (
        subprocess.check_output(
            ["git", "show", BASE + ":sql_schema/dbo." + name + ".StoredProcedure.sql"],
            cwd=ROOT,
        )
        .decode("utf-8-sig")
        .replace("\r\n", "\n")
    )


def test_business_preserved():
    old = old_source("usp_S11CompleteStatsReportsCore")
    new = (
        ROOT / "sql_schema/dbo.usp_S11CompleteStatsReportsCore.StoredProcedure.sql"
    ).read_text(encoding="utf-8-sig")
    a = old.index("        -- ⚡ OPTIMIZATION: Update statistics on newly built table")
    b = old.index("        SET @StepEnd", a)
    old = old[:a] + old[b:]
    old = old.replace(
        "        -- ⚡ OPTIMIZATION: Update statistics after bulk insert\n        UPDATE STATISTICS dbo.ALL_STATS_FOR_DASHBAORD WITH FULLSCAN;\n",
        "",
    )
    a = old.index("        -- Force checkpoint to write dirty pages")
    b = old.index("        DECLARE @EndTime", a)
    old = (
        old[:a]
        + "        -- Optional upkeep and backup dispatch belong to the owned maintenance path.\n        DECLARE @FinalLogUsedPct DECIMAL(5,2) = NULL;\n        DECLARE @LogBackupTriggered BIT = 0;\n\n"
        + old[b:]
    )
    old = old.replace("'No (queued for Python)'", "'No (maintenance deferred)'")
    for flag in ("Dashboard", "Summary"):
        demand = (
            "            EXEC dbo.usp_MaintenanceDue @Kind='final_stats',@Final"
            + flag
            + "=1;\n"
        )
        assert new.count(demand) == 1
        new = new.replace(demand, "", 1)
    assert old == new, "Business calculations, headroom or stage receipts changed"
    assert new.count("CHECKPOINT;") == 1, "The admission checkpoint must remain"
    assert "UPDATE STATISTICS" not in new


if __name__ == "__main__":
    test_business_preserved()
    print(
        "PASS: exact D3g business/headroom/stage preservation; optional upkeep only removed."
    )
