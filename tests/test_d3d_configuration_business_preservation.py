"""Compare D3d retained business SQL to its immutable predecessor."""

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "faddbd12ea0ea5d376214bd60d6a8ae3cf802338"


def source(path):
    return (
        subprocess.check_output(["git", "show", BASE + ":" + path], cwd=ROOT)
        .decode("utf-8-sig")
        .replace("\r\n", "\n")
    )


def test_configuration_business_preserved():
    path = "sql_schema/dbo.CREATE_DELTA_TABLES.StoredProcedure.sql"
    old = source(path)
    new = (ROOT / path).read_text(encoding="utf-8-sig")
    cutoff = "    ----------------------------------------------------------------\n    -- Step 6: LIGHTWEIGHT MAINTENANCE"
    old_business = old[: old.index(cutoff)]
    thresholds = "    -- For low-volume processing (500-2000/day), run maintenance weekly\n    DECLARE @MaintenanceRowThreshold INT = 5000;\n    DECLARE @MaintenanceHourThreshold INT = 168; -- 7 days\n"
    old_business = old_business.replace(thresholds, "")
    due = "        EXEC dbo.usp_MaintenanceConfigurationDue @RowsProcessed=@RowsProcessed,@LastScan=@NewMaxScan;\n"
    assert new.count(due) == 1
    assert new.index(due) < new.index("        COMMIT TRANSACTION;")
    new_business = new[: new.index("    -- Optional upkeep and timing logs")].replace(
        due, ""
    )
    assert new_business == old_business
    assert (
        "UPDATE STATISTICS" not in new
        and "ALTER INDEX" not in new
        and "DeltaProcessingLog" not in new
    )
    target = "sql_schema/dbo.sp_TARGETS_MASTER.StoredProcedure.sql"
    assert (ROOT / target).read_text(encoding="utf-8-sig") == source(target)
    child = (
        ROOT / "sql_schema/dbo.usp_MaintenanceConfiguration.StoredProcedure.sql"
    ).read_text()
    for statement in [
        line.strip() for line in old.splitlines() if "UPDATE STATISTICS" in line
    ]:
        assert statement in child
    for required in (
        "@MaintenanceRowThreshold int=5000,@MaintenanceHourThreshold int=168",
        "AND ips.page_count > 1000",
        "WHERE FragmentationPercent > 15",
        "IF @Fragmentation > 50",
        "MAXDOP = 2",
        "SORT_IN_TEMPDB = ON",
        "WITH SAMPLE 25 PERCENT",
        "QUOTENAME(@IndexName)",
        "THROW; -- Preserve the actual first child failure",
    ):
        assert required in child


if __name__ == "__main__":
    test_configuration_business_preserved()
    print(
        "PASS: configuration calculations, publication caller and maintenance thresholds preserved."
    )
