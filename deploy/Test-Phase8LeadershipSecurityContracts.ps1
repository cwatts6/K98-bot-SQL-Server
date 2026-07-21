[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Get-SqlSource {
    param([Parameter(Mandatory)][string]$RelativePath)
    return Get-Content -Raw -LiteralPath (Join-Path $repoRoot $RelativePath)
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )
    if ($Source -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-Before {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$First,
        [Parameter(Mandatory)][string]$Second,
        [Parameter(Mandatory)][string]$Message
    )
    $firstIndex = $Source.IndexOf($First, [StringComparison]::Ordinal)
    $secondIndex = $Source.IndexOf($Second, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
        $failures.Add($Message)
    }
}

$kvkOutputPaths = @(
    'sql_schema\dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql',
    'migrations\20260719_004_add_kvk_final_report_header.sql'
)
foreach ($path in $kvkOutputPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'Requested final ScanOrder=%d has no source rows\.' "$path must reject a missing exact final scan."
    Assert-Contains $source 'Resolved final ScanOrder=%d has no source rows\.' "$path must reject a missing resolved output-ending scan."
}
Assert-Before (Get-SqlSource 'sql_schema\dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql') 'Requested final ScanOrder=%d has no source rows.' 'TRUNCATE TABLE dbo.STAGING_STATS' 'The canonical KVK output procedure must validate the exact scan before destructive staging work.'
Assert-Before (Get-SqlSource 'sql_schema\dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql') 'Resolved final ScanOrder=%d has no source rows.' 'TRUNCATE TABLE dbo.STAGING_STATS' 'The canonical KVK output procedure must validate the resolved output-ending scan before destructive staging work.'
$kvkOutput = Get-SqlSource 'sql_schema\dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql'
Assert-Contains $kvkOutput '@FinalScanOrder\s*=\s*@LatestScanToUse' 'The KVK completion header must record the actual output-ending scan.'
$kvkMigration = Get-SqlSource 'migrations\20260719_004_add_kvk_final_report_header.sql'
Assert-Contains $kvkMigration 'REPLACE\(@OutputDefinition,\s*@ScanCapMarker,\s*@ScanEvidenceGuard\)' 'The KVK migration must inject the exact-scan guard at the pre-transaction scan-cap marker.'
Assert-Contains $kvkMigration 'REPLACE\([\s\S]+@TransactionMarker,[\s\S]+@LatestScanEvidenceGuard' 'The KVK migration must inject the resolved-scan guard before the transaction.'
Assert-Contains $kvkMigration '@FinalScanOrder\s*=\s*@LatestScanToUse' 'The KVK migration must inject the actual output-ending scan.'
Assert-Contains $kvkMigration "CHARINDEX\(N'CREATE PROCEDURE',\s*@UpperOutputDefinition\)" 'The KVK migration must detect a stored CREATE PROCEDURE header before replaying the definition.'
Assert-Contains $kvkMigration "N'ALTER PROCEDURE'" 'The KVK migration must replay an existing output procedure with ALTER semantics.'
Assert-Before $kvkMigration "N'ALTER PROCEDURE'" 'EXEC sys.sp_executesql @OutputDefinition' 'The KVK migration must normalize CREATE to ALTER before executing the modified definition.'
Assert-Contains $kvkMigration 'IF\s+@CreateProcedurePosition\s+BETWEEN\s+1\s+AND\s+64' 'The KVK migration must only rewrite a CREATE token in the module header.'
Assert-Contains $kvkMigration "CHARINDEX\(N'CREATE PROC',\s*@UpperOutputDefinition\)" 'The KVK migration must detect a stored CREATE PROC header before replaying the definition.'
Assert-Contains $kvkMigration '@CreateProcPosition\s+BETWEEN\s+1\s+AND\s+64' 'The KVK migration must only rewrite a CREATE PROC token in the module header.'
Assert-Before $kvkMigration "@CreateProcPosition, LEN(N'CREATE PROC')" 'EXEC sys.sp_executesql @OutputDefinition' 'The KVK migration must normalize a CREATE PROC header to ALTER before executing the modified definition.'

$kvkHeaderPaths = @(
    'sql_schema\dbo.KVKFinalReportHeader.Table.sql',
    'migrations\20260719_004_add_kvk_final_report_header.sql'
)
foreach ($path in $kvkHeaderPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'OutputRowCount\s*>\s*0' "$path must prohibit zero-row completion headers."
    if ($source -match 'OutputRowCount\s*>=\s*0') {
        $failures.Add("$path still permits zero-row completion headers.")
    }
}

$kvkRecorderPaths = @(
    'sql_schema\dbo.usp_RecordKvkFinalReportCompletion.StoredProcedure.sql',
    'migrations\20260719_004_add_kvk_final_report_header.sql'
)
foreach ($path in $kvkRecorderPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'IF\s+@OutputRowCount\s*<=\s*0' "$path must reject empty final output."
    Assert-Contains $source 'IF\s+@@TRANCOUNT\s*=\s*0' "$path must own a transaction when called standalone."
    Assert-Contains $source 'KVKFinalReportHeader\s+WITH\s*\(UPDLOCK,\s*HOLDLOCK\)' "$path must serialize header revisions."
}

$allianceHeaderPaths = @(
    'sql_schema\dbo.AllianceActivitySnapshotHeader.Table.sql',
    'migrations\20260719_002_add_alliance_activity_completion_evidence.sql'
)
foreach ($path in $allianceHeaderPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'CK_AllianceActivityHeader_CompleteEvidence' "$path must enforce COMPLETE evidence at the table boundary."
    Assert-Contains $source 'ValidatedAtUtc[^\r\n]+IS NOT NULL' "$path must require a validation timestamp for COMPLETE evidence."
}

$allianceProcedurePaths = @(
    'sql_schema\dbo.usp_SetAllianceActivitySnapshotCompletion.StoredProcedure.sql',
    'migrations\20260719_002_add_alliance_activity_completion_evidence.sql'
)
foreach ($path in $allianceProcedurePaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source '@ExpectedGovernorCount\s+IS NULL' "$path must reject null evidence counts explicitly."
    Assert-Contains $source 'AllianceActivitySnapshotHeader\s+WITH\s*\(UPDLOCK,\s*HOLDLOCK\)' "$path must lock the completion header."
    Assert-Contains $source 'AllianceActivitySnapshotRow\s+WITH\s*\(UPDLOCK,\s*HOLDLOCK\)' "$path must hold the row range while validating counts."
    Assert-Contains $source 'IF\s+@@TRANCOUNT\s*=\s*0' "$path must own a transaction when called standalone."
}

$leadershipPaths = @(
    'sql_schema\dbo.usp_GetLeadershipPlayerReview.StoredProcedure.sql',
    'migrations\20260719_006_add_leadership_player_review_contracts.sql'
)
foreach ($path in $leadershipPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'WHEN\s+4\s+THEN\s+rows\.RSSValue' "$path must count NULL RSS observations as missing metric units."
    Assert-Contains $source 'AND\s+NOT EXISTS[\s\S]+WHEN\s+4\s+THEN\s+rows\.RSSValue' "$path must exclude an incomplete RSS component from ranking and Activity Index."
    Assert-Contains $source 'r\.HelpsValue\s+IS NOT NULL[\s\S]+r\.RSSValue\s+IS NOT NULL[\s\S]+r\.PowerValue\s+IS NOT NULL' "$path must label Stats coverage complete only for valid required observations."
}

$auditPurgePaths = @(
    'sql_schema\dbo.usp_PurgeLeadershipPlayerReviewAudit.StoredProcedure.sql',
    'migrations\20260719_005_add_leadership_player_review_audit.sql'
)
foreach ($path in $auditPurgePaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'BEGIN\s+TRY[\s\S]+BEGIN\s+TRANSACTION' "$path must guard the audit purge transaction with TRY/CATCH."
    Assert-Contains $source 'BEGIN\s+CATCH[\s\S]+IF\s+@@TRANCOUNT\s*>\s*0[\s\S]+ROLLBACK\s+TRANSACTION[\s\S]+THROW' "$path must roll back and rethrow purge failures."
}

$kvkHistoryPaths = @(
    'sql_schema\dbo.usp_GetLeadershipPlayerKvkHistory.StoredProcedure.sql',
    'migrations\20260719_006_add_leadership_player_review_contracts.sql'
)
foreach ($path in $kvkHistoryPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'TRY_CONVERT\(bigint,\s*exemption\.GovernorID\)\s*=\s*history\.Gov_ID' "$path must compare exemption Governor IDs as exact BIGINT values."
}

$rankPaths = @(
    'sql_schema\dbo.usp_GetKvkHistorySummaryMetricRanks.StoredProcedure.sql',
    'migrations\20260719_006_add_leadership_player_review_contracts.sql'
)
foreach ($path in $rankPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'TRY_CONVERT\(decimal\(38,8\),\s*history\.\[KillPointsDelta\]\)' "$path must rank integer-scale metrics without narrowing canonical Tanking Score precision."
    if ($source -match 'TRY_CONVERT\(decimal\(38,6\),\s*history\.\[(Acclaim|T4&T5_Kills|KillPointsDelta|Deads_Delta|HealedTroopsDelta|DKP_SCORE|Max_PreKvk_Points|Max_HonorPoints)\]\)') {
        $failures.Add("$path still narrows the canonical Tanking Score UNION to six decimal places.")
    }
    if ($source -match 'TRY_CONVERT\(float,\s*history\.\[(Acclaim|T4&T5_Kills|KillPointsDelta|Deads_Delta|HealedTroopsDelta|DKP_SCORE|Max_PreKvk_Points|Max_HonorPoints)\]\)') {
        $failures.Add("$path still converts a ranked KVK metric to FLOAT.")
    }
}

$combatMetricPaths = @(
    'sql_schema\dbo.fn_KvkCombatMetrics.UserDefinedFunction.sql',
    'migrations\20260719_006_add_leadership_player_review_contracts.sql'
)
foreach ($path in $combatMetricPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'CONVERT\(decimal\(20,1\),\s*@KillPoints\)' "$path must preserve at least eight fractional Tanking Score digits through SQL division."
    Assert-Contains $source 'NULLIF\(CONVERT\(decimal\(22,1\),' "$path must size the Tanking Score denominator for BIGINT healed and deads inputs."
    if ($source -match 'CONVERT\(decimal\(38,8\),\s*@KillPoints\)\s*/\s*NULLIF\(CONVERT\(decimal\(38,8\),') {
        $failures.Add("$path still forces SQL Server decimal division to six fractional digits.")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Phase 8 leadership security contract checks passed.'
