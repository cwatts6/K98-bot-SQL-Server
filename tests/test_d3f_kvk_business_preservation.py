"""D3f retains KVK business SQL and required output publication children."""

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "462ac993af52cfa6de68a3930084b9381fd0b26c"


def old_source(path):
    return (
        subprocess.check_output(["git", "show", BASE + ":" + path], cwd=ROOT)
        .decode("utf-8-sig")
        .replace("\r\n", "\n")
    )


def test_kvk_business_preservation():
    path = "sql_schema/dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql"
    old = old_source(path)
    new = (ROOT / path).read_text(encoding="utf-8-sig")
    start = old.index("\t-- Call index creation procedure with BOTH parameters")
    end = old.index("    DROP TABLE IF EXISTS #DKP, #HD1;", start)
    removed = old[start:end]
    assert "sp_Create_Excel_For_Kvk_Indexes" in removed and "WITH FULLSCAN" in removed
    old = old[:start] + old[end:]
    guard = """        DECLARE @MaintenanceSchemaResult int;
        EXEC @MaintenanceSchemaResult=sys.sp_getapplock @Resource=N'K98:maintenance-schema:v1',
            @LockMode='Shared',@LockOwner='Transaction',@LockTimeout=0;
        IF @MaintenanceSchemaResult<0
            THROW 51966,'KVK publication deferred while maintenance owns schema.',1;
"""
    due = "        EXEC dbo.usp_MaintenanceKvkDue @KVKNo=@KVK;\n\n"
    assert new.count(guard) == new.count(due) == 1
    assert new.replace(guard, "", 1).replace(due, "", 1) == old
    assert new.index(guard) < new.index("TRUNCATE TABLE dbo.STAGING_STATS")
    assert new.index(due) > new.index("EXEC dbo.usp_RecordKvkFinalReportCompletion")
    for name in (
        "sp_Refresh_View_EXCEL_FOR_KVK_All",
        "usp_RecordKvkFinalReportCompletion",
        "sp_Build_Prekvk_And_Honor_Rankings",
        "sp_Create_Excel_For_Kvk_Indexes",
    ):
        path = "sql_schema/dbo." + name + ".StoredProcedure.sql"
        assert (ROOT / path).read_text(encoding="utf-8-sig") == old_source(path)


if __name__ == "__main__":
    test_kvk_business_preservation()
    print(
        "PASS: KVK business SQL, required views/receipt/ranking children preserved; only post-output upkeep deferred."
    )
