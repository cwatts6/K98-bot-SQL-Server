"""Exact D3e business preservation and fixed optional FULLSCAN."""

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "aa53d3ed22b5381602a0113d8a810a43c9cea9e2"


def test_player_report_business_preserved():
    path = "sql_schema/dbo.SP_Stats_for_Upload.StoredProcedure.sql"
    old = (
        subprocess.check_output(["git", "show", BASE + ":" + path], cwd=ROOT)
        .decode("utf-8-sig")
        .replace("\r\n", "\n")
    )
    new = (ROOT / path).read_text(encoding="utf-8-sig")
    before = "        SET @FailureStage = N'target-statistics';\n        UPDATE STATISTICS dbo.STATS_FOR_UPLOAD WITH FULLSCAN;"
    after = "        SET @FailureStage = N'maintenance-registration';\n        EXEC dbo.usp_MaintenanceDue @Kind='player_report';"
    assert old.count(before) == new.count(after) == 1
    assert new == old.replace(before, after)
    child = (
        ROOT / "sql_schema/dbo.usp_MaintenancePlayerReport.StoredProcedure.sql"
    ).read_text()
    assert "UPDATE STATISTICS dbo.STATS_FOR_UPLOAD WITH FULLSCAN;" in child
    assert "K98:StatsForUpload:Publish" in child
    assert "EXECUTE AS OWNER" in child


if __name__ == "__main__":
    test_player_report_business_preserved()
    print(
        "PASS: player report business SQL preserved exactly apart from deferred FULLSCAN registration."
    )
