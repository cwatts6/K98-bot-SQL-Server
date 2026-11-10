from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "8ba5850a1f9fca700b828d2363a7794aa0c5fbd3"


def test_import_business_and_upkeep_are_preserved_exactly():
    old = (
        subprocess.check_output(
            ["git", "show", BASE + ":sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql"],
            cwd=ROOT,
        )
        .decode("utf-8-sig")
        .replace("\r\n", "\n")
    )
    current = (ROOT / "sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql").read_text(
        encoding="utf-8-sig"
    )
    start = old.index("        -- SMART INDEX MAINTENANCE: Only update stats for KS5")
    end = old.index("        -- Cache MAX(SCANORDER)", start)
    ks5 = old[start:end]
    old = old[:start] + old[end:]
    start = old.index(
        "            ----------------------------------------------------------------\n            -- SMART INDEX MAINTENANCE for KS4"
    )
    end = old.index(
        "\n        END\n\n        EXEC dbo.usp_UpsertGovernorNameHistoryForScan", start
    )
    ks4 = old[start:end]
    business = (
        "\t\t\tEXEC [dbo].[Refresh_PlayerScanMeta] @MinScanOrder = @MaxScanOrder5\n"
    )
    old = old[:start] + business + old[end:]
    due = "        DECLARE @ImportKS4 bit=CASE WHEN @rowsKS4>0 THEN 1 ELSE 0 END;\n        EXEC dbo.usp_MaintenanceDue @Kind='import',@RequestID=@ExportPreparationID,@ImportKS4=@ImportKS4;\n"
    assert current.count(due) == 1
    assert current.replace(due, "") == old
    assert current.index(due) < current.index("        COMMIT;  --")
    child = (
        ROOT / "sql_schema/dbo.usp_MaintenanceImport.StoredProcedure.sql"
    ).read_text()
    assert ks5 in child
    assert ks4.replace(business, "") in child
    assert "Refresh_PlayerScanMeta" not in child
    assert "UPDATE STATISTICS" not in current and "ALTER INDEX" not in current
    # The typed/file/scan importer has no upkeep to extract.
    path = "sql_schema/dbo.IMPORT_STAGING_PROC_CORE.StoredProcedure.sql"
    assert (ROOT / path).read_bytes().replace(
        b"\r\n", b"\n"
    ) == subprocess.check_output(["git", "show", BASE + ":" + path], cwd=ROOT).replace(
        b"\r\n", b"\n"
    )


if __name__ == "__main__":
    test_import_business_and_upkeep_are_preserved_exactly()
    print("PASS: exact import business and upkeep preservation; no SQL execution.")
