"""Compare extracted business SQL to the immutable pre-P0 UPDATE_ALL2 body.

This qualifies calculation/call preservation, not transaction or runtime results.
The separate SQL fixtures qualify stage commit, rollback and continuation behavior.
"""

import hashlib
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def tokens(text):
    # Preserve quoted values and identifiers exactly; ignore comments/formatting.
    pattern = r"--[^\n]*|/\*[\s\S]*?\*/|N?'(?:''|[^'])*'|\[(?:\]\]|[^\]])*\]|[^\s]"
    return [m[0] for m in re.finditer(pattern, text) if not m[0].startswith(("--", "/*"))]


def section(text, start, end):
    offset = text.index(start)
    return text[offset : text.index(end, offset)]


def validate():
    raw = (ROOT / "deploy/source_baselines/UPDATE_ALL2-before-p0-receipts.txt").read_bytes()
    assert (
        hashlib.sha256(raw).hexdigest()
        == "830b0a96b06904f3871962e067884529b053b59657d9068e4503cd73ca07663a"
    )
    old = raw.decode("utf-8-sig").replace("\r\n", "\n")
    new = (ROOT / "sql_schema/dbo.usp_S11CompleteStatsReports.StoredProcedure.sql").read_text(
        encoding="utf-8-sig"
    )
    blocks = (
        (
            "averages_and_dashboard",
            "SET @CurrentAuditPhase = N'update_all2_create_averages';",
            "DECLARE @LatestKVK_Upload INT;",
        ),
        (
            "season_and_scan_selection",
            "DECLARE @LatestKVK_Upload INT;",
            "PRINT 'Step 4a: Refreshing EXCEL_FOR_KVK_'",
        ),
        (
            "kvk_calculation_and_arguments",
            "EXEC dbo.sp_ExcelOutput_ByKVK",
            "PRINT 'sp_ExcelOutput_ByKVK:",
        ),
        (
            "dashboard_monthly_summary_names_and_diagnostics",
            "TRUNCATE TABLE dbo.ALL_STATS_FOR_DASHBAORD;",
            "DECLARE @S11CompletionCounters TABLE",
        ),
    )
    for name, start, end in blocks:
        assert tokens(section(old, start, end)) == tokens(section(new, start, end)), name
    assert new.count("EXEC dbo.SP_Stats_for_Upload;") == 1
    assert (
        "IF @LatestKVK_Upload IS NOT NULL AND @ScanToUse_Upload IS NOT NULL\n                EXEC dbo.SP_Stats_for_Upload;"
        in new
    )
    assert not re.search(
        r"EXEC\s+dbo\.(?:UPDATE_ALL2|IMPORT_STAGING_PROC_CORE|CLAIM_KS4_IMPORT_FILE)\b", new
    )
    # A change to a nested calculator is a separate business change, not part of
    # this extraction. Compare every retained closure member to the fixed base.
    import json
    import subprocess

    before = json.loads(
        subprocess.check_output(
            ["git", "show", "716c74e:deploy/export_stats_import_outcome_source.json"], cwd=ROOT
        )
    )
    after = json.loads((ROOT / "deploy/export_stats_import_outcome_source.json").read_bytes())
    current = {r["name"]: r for r in after["modules"]}
    for module in before["modules"]:
        if module["name"] != "dbo.UPDATE_ALL2":
            assert current[module["name"]] == module, module["name"]
    return [name for name, _, _ in blocks]


if __name__ == "__main__":
    print(
        "PASS: unchanged business SQL blocks and nested calculator closure:", ", ".join(validate())
    )
