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

$aliasMigration = Get-SqlSource 'migrations\20260719_007_wire_governor_name_history_post_scan.sql'
Assert-Contains $aliasMigration 'UNICODE\(SUBSTRING\(@UpperUpdateDefinition,\s*@HeaderPosition,\s*1\)\)[\s\r\n]+IN\s*\(9,\s*10,\s*13,\s*32\)' 'The alias-hook migration must skip spaces, tabs, CR, and LF before parsing the UPDATE_ALL2 header.'
Assert-Contains $aliasMigration '@HeaderPosition\s+NOT\s+BETWEEN\s+1\s+AND\s+64' 'The alias-hook migration must constrain header parsing to the module prefix.'
Assert-Contains $aliasMigration "SUBSTRING\(@UpperUpdateDefinition,\s*@HeaderPosition,\s*LEN\(N'CREATE'\)\)\s*=\s*N'CREATE'" 'The alias-hook migration must parse CREATE independently from following SQL whitespace.'
Assert-Contains $aliasMigration "SUBSTRING\(@UpperUpdateDefinition,\s*@ProcedureTokenPosition,\s*LEN\(N'PROC'\)\)\s*<>\s*N'PROC'" 'The alias-hook migration must validate PROC or PROCEDURE after skipping SQL whitespace.'
Assert-Contains $aliasMigration "STUFF\([\s\S]+@HeaderPosition,\s*LEN\(N'CREATE'\),\s*N'ALTER'" 'The alias-hook migration must replace only the leading CREATE keyword.'
Assert-Before $aliasMigration "@HeaderPosition, LEN(N'CREATE'), N'ALTER'" 'EXEC sys.sp_executesql @UpdateDefinition' 'The alias-hook migration must normalize the leading CREATE keyword before executing UPDATE_ALL2.'
Assert-Contains $aliasMigration "THROW\s+51205" 'The alias-hook migration must fail closed for an unexpected UPDATE_ALL2 module header.'
if ($aliasMigration -match "CHARINDEX\(N'CREATE (?:PROCEDURE|PROC)'") {
    $failures.Add('The alias-hook migration still depends on exact single-space CREATE PROCEDURE syntax.')
}

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

$allianceBackfillMigration = Get-SqlSource 'migrations\20260721_002_backfill_leadership_activity_completion.sql'
Assert-Contains $allianceBackfillMigration 'LEGACY_ASSUMED_ZERO' 'The historical Alliance Activity assumption must remain explicit.'
Assert-Contains $allianceBackfillMigration 'SOURCE_VALIDATED' 'Future Alliance Activity completion must record source validation.'
Assert-Contains $allianceBackfillMigration 'MissingMetricCount' 'Future completion evidence must distinguish missing metric cells.'
Assert-Contains $allianceBackfillMigration 'AUDIT_BACKFILL' 'Rally history must prefer successful import audit evidence.'
Assert-Contains $allianceBackfillMigration 'INFERRED_DATE' 'Rally history without audit evidence must remain explicitly inferred.'
Assert-Contains $allianceBackfillMigration 'rows\.SourceRowCount\s*=\s*rows\.DistinctGovernorCount' 'Rally backfill must reject duplicate Governor IDs.'
Assert-Contains $allianceBackfillMigration 'rows\.InvalidGovernorIdRowCount\s*=\s*0' 'Rally backfill must reject non-positive Governor IDs.'
Assert-Contains $allianceBackfillMigration 'rows\.InvalidMetricRowCount\s*=\s*0' 'Rally backfill must reject invalid stored metrics.'
Assert-Contains $allianceBackfillMigration 'OUTER\s+APPLY[\s\S]+candidate\.Status\s*=\s*N''success''[\s\S]+candidate\.RowsIn\s*=\s*rows\.SourceRowCount[\s\S]+candidate\.EndedAt\s+IS\s+NOT\s+NULL[\s\S]+candidate\.FileHash\s+IS\s+NOT\s+NULL' 'Rally backfill must rank only successful audit rows that match the stored date row count and have completion evidence.'
Assert-Contains $allianceBackfillMigration 'header\.Row_Count\s*=\s*stored\.StoredRowCount' 'Legacy Alliance Activity backfill must match source and stored row counts.'
Assert-Contains $allianceBackfillMigration 'stored\.InvalidStoredMetricCount\s*=\s*0' 'Legacy Alliance Activity backfill must reject negative stored metrics.'
Assert-Contains $allianceBackfillMigration 'DATALENGTH\(header\.SourceFileSha1\)\s*=\s*20' 'Legacy Alliance Activity backfill must require source-file provenance.'

$allianceCompletionSource = Get-SqlSource 'sql_schema\dbo.usp_SetAllianceActivitySnapshotCompletion.StoredProcedure.sql'
Assert-Contains $allianceCompletionSource '@MissingMetricCount\s+int' 'Alliance Activity completion must receive missing metric evidence.'
Assert-Contains $allianceCompletionSource '@CompletionBasis\s+nvarchar\(32\)' 'Alliance Activity completion must record its validation basis.'
Assert-Contains $allianceCompletionSource '@ExpectedGovernorCount\s*>\s*@ObservedGovernorCount' 'Alliance Activity completion must reject COMPLETE evidence with fewer observed rows than expected governors.'
if ($allianceCompletionSource -match '@ExpectedGovernorCount\s*<>\s*@ObservedGovernorCount') {
    $failures.Add('Alliance Activity completion still rejects valid source rows outside the current scan cohort.')
}

$allianceCurrentEvidencePaths = @(
    'sql_schema\dbo.AllianceActivitySnapshotHeader.Table.sql',
    'migrations\20260721_002_backfill_leadership_activity_completion.sql'
)
foreach ($path in $allianceCurrentEvidencePaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'ExpectedGovernorCount\]?\s*<=\s*\[?ObservedGovernorCount' "$path must reject COMPLETE evidence with fewer observed rows than expected governors."
}

$leadershipCanonicalPath = 'sql_schema\dbo.usp_GetLeadershipPlayerReview.StoredProcedure.sql'
$leadershipCanonical = Get-SqlSource $leadershipCanonicalPath
Assert-Contains $leadershipCanonical 'WHEN\s+4\s+THEN\s+rows\.RSSValue' "$leadershipCanonicalPath must count NULL RSS observations as missing metric units."
Assert-Contains $leadershipCanonical 'CASE\s+WHEN\s+EXISTS[\s\S]+daily\.MetricValue\s+IS NOT NULL[\s\S]+THEN\s+1\s+ELSE\s+0\s+END' "$leadershipCanonicalPath must make a Stats metric available when at least one valid observation exists."
Assert-Contains $leadershipCanonical 'WHEN\s+population\.IsCurrentlyAllied\s*=\s*0\s+THEN\s+0[\s\S]+WHEN\s+COUNT\(daily\.MetricValue\)\s*=\s*0\s+THEN\s+0' "$leadershipCanonicalPath must require current alliance membership and at least one valid Building/Tech observation."
if ($leadershipCanonical -match 'AND\s+NOT EXISTS[\s\S]+WHEN\s+4\s+THEN\s+rows\.RSSValue') {
    $failures.Add("$leadershipCanonicalPath still excludes a Stats metric from ranking when any observation is missing.")
}
if ($leadershipCanonical -match 'WHEN\s+COUNT\(DISTINCT\s+headers\.SnapshotDate\)\s*=\s*0\s+THEN\s+0[\s\S]+WHEN\s+COUNT\(daily\.MetricValue\)\s*=\s*0') {
    $failures.Add("$leadershipCanonicalPath still requires complete Alliance Activity coverage before ranking.")
}

$leadershipCoveragePaths = @(
    $leadershipCanonicalPath,
    'migrations\20260719_006_add_leadership_player_review_contracts.sql'
)
foreach ($path in $leadershipCoveragePaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'r\.HelpsValue\s+IS NOT NULL[\s\S]+r\.RSSValue\s+IS NOT NULL[\s\S]+r\.PowerValue\s+IS NOT NULL' "$path must label Stats coverage complete only for valid required observations."
}

$partialRankingMigration = Get-SqlSource 'migrations\20260721_003_allow_partial_leadership_activity_ranking.sql'
Assert-Contains $partialRankingMigration 'AND NOT EXISTS' 'The partial-ranking migration must remove the legacy Stats completeness gate.'
Assert-Contains $partialRankingMigration 'WHEN COUNT\(DISTINCT headers\.SnapshotDate\) = 0 THEN 0' 'The partial-ranking migration must remove the legacy Alliance Activity completeness gate.'
Assert-Contains $partialRankingMigration 'WHEN COUNT\(daily\.MetricValue\) = 0 THEN 0' 'The partial-ranking migration must retain the valid-observation requirement.'
Assert-Contains $partialRankingMigration 'WHEN population\.IsCurrentlyAllied = 0 THEN 0' 'The partial-ranking migration must retain the current-alliance requirement.'
Assert-Contains $partialRankingMigration 'THROW\s+51541' 'The partial-ranking migration must fail closed if the Stats contract marker is absent.'
Assert-Contains $partialRankingMigration 'THROW\s+51542' 'The partial-ranking migration must fail closed if the Alliance Activity contract marker is absent.'
Assert-Contains $partialRankingMigration "STUFF\([\s\S]+LEN\(N'CREATE OR ALTER'\),\s*N'ALTER'" 'The partial-ranking migration must replay an existing procedure with ALTER semantics.'

$auditPurgePaths = @(
    'sql_schema\dbo.usp_PurgeLeadershipPlayerReviewAudit.StoredProcedure.sql',
    'migrations\20260719_005_add_leadership_player_review_audit.sql'
)
foreach ($path in $auditPurgePaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'BEGIN\s+TRY[\s\S]+BEGIN\s+TRANSACTION' "$path must guard the audit purge transaction with TRY/CATCH."
    Assert-Contains $source 'BEGIN\s+CATCH[\s\S]+IF\s+@@TRANCOUNT\s*>\s*0[\s\S]+ROLLBACK\s+TRANSACTION[\s\S]+THROW' "$path must roll back and rethrow purge failures."
}

$auditCollationPaths = @(
    'sql_schema\dbo.usp_PurgeLeadershipPlayerReviewAudit.StoredProcedure.sql',
    'migrations\20260721_001_fix_leadership_audit_temp_collation.sql'
)
foreach ($path in $auditCollationPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'Action\s+nvarchar\(32\)\s+COLLATE\s+DATABASE_DEFAULT' "$path must align the audit action temp column with the deployed database-default audit collation."
    Assert-Contains $source 'Outcome\s+nvarchar\(24\)\s+COLLATE\s+DATABASE_DEFAULT' "$path must align the audit outcome temp column with the deployed database-default audit collation."
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

$positiveHealedPaths = @(
    'sql_schema\dbo.fn_KvkCombatMetrics.UserDefinedFunction.sql',
    'migrations\20260722_002_add_leadership_kvk_index_contract.sql'
)
foreach ($path in $positiveHealedPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source '@HealedTroops\s*<=\s*0' "$path must require positive Healed evidence before calculating Tanking Score."
}

$leadershipKvkIndexPaths = @(
    'sql_schema\dbo.usp_GetLeadershipPlayerKvkHistory.StoredProcedure.sql',
    'migrations\20260722_002_add_leadership_kvk_index_contract.sql'
)
foreach ($path in $leadershipKvkIndexPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'CASE WHEN KillPoints > 0' "$path must rank only positive Kill Points values."
    Assert-Contains $source 'ORDER BY KillPoints DESC' "$path must rank Kill Points descending."
    Assert-Contains $source 'CASE WHEN Deads > 0' "$path must rank only positive Deads values."
    Assert-Contains $source 'ORDER BY Deads DESC' "$path must rank Deads descending."
    Assert-Contains $source 'CASE WHEN IsEngaged = 1 AND Healed > 0' "$path must require positive Healed evidence for Healed rank."
    Assert-Contains $source 'COUNT\(CASE WHEN IsEngaged = 1 AND Healed > 0 THEN 1 END\)' "$path must count only positive-Healed engaged rows."
    Assert-Contains $source 'ranks\.KillPointsRank,\s*ranks\.DeadsRank' "$path must append leadership Kill Points and Deads ranks."
    if ($source -notmatch 'healed_coverage\.Healed\s*>\s*0' -and
        $source -notmatch 'WHERE\s+calculated\.Healed\s*>\s*0') {
        $failures.Add("$path must expose KVK-level positive-Healed source evidence.")
    }
    Assert-Contains $source 'AS HealedDataAvailable' "$path must name the additive Healed availability result field."
    if ($source -match 'FROM\s+#Calculated\s+WHERE\s+IsEngaged\s*=\s*1') {
        $failures.Add("$path must not gate Kill Points and Deads ranks on shared engagement eligibility.")
    }
}

$leadershipCompositeIndexPaths = @(
    'sql_schema\dbo.usp_GetLeadershipPlayerKvkHistory.StoredProcedure.sql',
    'migrations\20260722_003_add_leadership_kvk_index_rank.sql'
)
foreach ($path in $leadershipCompositeIndexPaths) {
    $source = Get-SqlSource $path
    Assert-Contains $source 'SELECT TOP \(3\) index_details\.KVK_NO' "$path must bound the composite index to the latest three finalized KVKs."
    Assert-Contains $source 'FROM dbo\.KVK_Details AS index_details' "$path must select composite-index KVKs from global KVK details, not the caller candidate horizon."
    Assert-Contains $source 'SELECT index_kvk\.KVK_NO FROM #KvkIndexKvks AS index_kvk' "$path must add globally selected index KVKs to the calculation set."
    Assert-Contains $source 'JOIN #Candidates AS output_candidate' "$path must keep the player-history result inside the caller candidate horizon."
    Assert-Contains $source 'calculated\.IsExempt\s*=\s*1' "$path must exclude exempt KVK rows from the composite index."
    Assert-Contains $source 'calculated\.T4T5Kills\s*=\s*0' "$path must score an observed zero Kills value as zero."
    Assert-Contains $source 'calculated\.Deads\s*=\s*0' "$path must score an observed zero Deads value as zero."
    Assert-Contains $source 'calculated\.Healed\s*=\s*0' "$path must score an observed zero Healed value as zero."
    Assert-Before $source 'WHEN calculated.T4T5Kills = 0' 'WHEN calculated.KillTargetPercent IS NULL' "$path must score observed zero metrics before excluding unavailable derived percentages."
    Assert-Contains $source 'CREATE TABLE #HealedCoverage' "$path must precompute KVK-level positive-Healed evidence."
    Assert-Contains $source 'LEFT JOIN #HealedCoverage AS healed_coverage' "$path must reuse precomputed positive-Healed evidence."
    if ($source -match 'NOT\s+EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+#Calculated\s+AS\s+healed_coverage') {
        $failures.Add("$path must not correlate positive-Healed coverage checks against #Calculated.")
    }
    Assert-Contains $source 'ORDER BY indexes\.KvkIndexValue DESC' "$path must rank the uncapped KVK Index descending."
    Assert-Contains $source 'AS KvkIndexCohortCount' "$path must expose the eligible kingdom cohort count."
    Assert-Contains $source 'AS CandidateKvkCount' "$path must expose the globally finalized candidate count."
    Assert-Contains $source 'AS Availability' "$path must expose honest KVK Index availability."
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Phase 8 leadership security contract checks passed.'
