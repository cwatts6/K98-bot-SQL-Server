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

$canonicalPath = 'sql_schema\dbo.usp_GetLeadershipPlayerLastActive.StoredProcedure.sql'
$migrationPath = 'migrations\20260721_005_add_leadership_player_last_active.sql'
$rollbackPath = 'migrations\rollback\20260721_005_add_leadership_player_last_active_rollback.sql'
$measurementPath = 'deploy\Measure-Phase81LeadershipPerformance.sql'

$canonical = Get-SqlSource $canonicalPath
$migration = Get-SqlSource $migrationPath
$rollback = Get-SqlSource $rollbackPath
$measurement = Get-SqlSource $measurementPath

foreach ($source in @($canonical, $migration)) {
    Assert-Contains $source 'CREATE OR ALTER PROCEDURE\s+dbo\.usp_GetLeadershipPlayerLastActive' 'The Last Active procedure must use the approved additive object name.'
    Assert-Contains $source '@HistoryDays\s+smallint\s*=\s*720' 'The Last Active procedure must default to 720 bounded days.'
    Assert-Contains $source '@GovernorID\s+IS\s+NULL\s+OR\s+@GovernorID\s*<=\s*0' 'The Last Active procedure must reject missing or non-positive Governor IDs.'
    Assert-Contains $source '@HistoryDays\s+IS\s+NULL\s+OR\s+@HistoryDays\s*<\s*1\s+OR\s+@HistoryDays\s*>\s*720' 'The Last Active procedure must reject missing or unbounded history.'
    Assert-Contains $source 'source\.AsOfDate\s+BETWEEN\s+@HistoryStartDate\s+AND\s+@EffectiveUtcDate' 'Kingdom scans must be bounded by UTC calendar dates.'
    Assert-Contains $source 'TRY_CONVERT\(datetime2\(0\),\s*source\.ScanDate\)\s+IS\s+NOT\s+NULL' 'Complete-scan cutoffs must have an authoritative UTC ScanDate.'
    Assert-Contains $source 'ROW_NUMBER\(\)\s+OVER[\s\S]+source\.ScanDate\s+DESC,\s*source\.SCAN_UNO\s+DESC' 'Duplicate Governor rows must use deterministic latest-row ordering.'
    Assert-Contains $source 'LAG\(ScanOrder\)\s+OVER\s*\(ORDER BY ScanDateUtc,\s*ScanOrder\)' 'Last Active must compare target-present complete scans in authoritative date order.'
    Assert-Contains $source 'ORDER BY ScanDateUtc\s+DESC,\s*ScanOrder\s+DESC,\s*SourceOrder' 'Latest qualifying activity must use authoritative ScanDate first.'
    Assert-Contains $source 'source\.Power' 'Power must be an eligible Last Active signal.'
    Assert-Contains $source 'source\.HealedTroops' 'Healed must be an eligible Last Active signal.'
    Assert-Contains $source 'source\.RSS_Gathered' 'RSS Gathered must be an eligible Last Active signal.'
    Assert-Contains $source 'source\.RSSAssistance' 'RSS Assisted must be an eligible Last Active signal.'
    Assert-Contains $source 'source\.Helps' 'Helps must be an eligible Last Active signal.'
    Assert-Contains $source 'header\.CompletionState\s*=\s*N''COMPLETE''' 'Alliance Activity must require accepted COMPLETE evidence.'
    Assert-Contains $source 'activity_row\.BuildingTotal' 'Building Minutes must use the authoritative Alliance Activity row.'
    Assert-Contains $source 'activity_row\.TechDonationTotal' 'Tech Donations must use the authoritative Alliance Activity row.'
    Assert-Contains $source 'dbo\.RallyDailySnapshotHeader' 'Rally activity must require completion evidence.'
    Assert-Contains $source 'COALESCE\(rally_row\.TotalRallies,\s*0\)' 'A completed Rally report with no Governor row must be explicit zero.'
    Assert-Contains $source 'rally_header\.AsOfDate\s*>\s*CONVERT\(date,\s*comparison\.PreviousScanDateUtc\)' 'Rally activity must use the interval after the prior complete scan.'
    Assert-Contains $source '@LastActiveDate\s*<\s*DATEADD\(DAY,\s*-30,\s*@EffectiveUtcDate\)' 'Exactly 30 UTC calendar days must remain ACTIVE.'
    Assert-Contains $source 'N''NOT_RECORDED''' 'No qualifying observation must remain Not recorded.'
    if ($source -match '\b(CREATE|ALTER)\s+(?:(?:UNIQUE|CLUSTERED|NONCLUSTERED)\s+)*(?:TABLE|INDEX)\s+(?!#)') {
        $failures.Add('The approved Last Active SQL must not add a permanent table or index.')
    }
    if (($source -match '\b(?:DROP|TRUNCATE)\s+(?:TABLE|INDEX)\b') -or
        ($source -match '\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE)\s+dbo\.')) {
        $failures.Add('The approved Last Active SQL must not mutate permanent objects or data.')
    }
    if ($source -match '\bEXEC\s*\(' -or $source -match 'sp_executesql') {
        $failures.Add('The Last Active SQL contract must remain static and parameterized.')
    }
}

Assert-Contains $migration 'Rollback:\s*Included' 'The migration must declare its included rollback.'
Assert-Contains $migration 'SET ANSI_NULLS ON\s+GO\s+SET QUOTED_IDENTIFIER ON\s+GO\s+CREATE OR ALTER PROCEDURE' 'Procedure creation must begin a deployable SQL batch.'
Assert-Contains $rollback 'DROP PROCEDURE IF EXISTS\s+dbo\.usp_GetLeadershipPlayerLastActive' 'Rollback must remove only the additive procedure.'
Assert-Contains $measurement 'SET STATISTICS IO ON' 'The performance harness must capture logical reads.'
Assert-Contains $measurement 'SET STATISTICS TIME ON' 'The performance harness must capture SQL CPU and elapsed time.'
Assert-Contains $measurement 'dm_db_stats_properties' 'The performance harness must capture statistics age and sampling.'
Assert-Contains $measurement 'dm_db_index_usage_stats' 'The performance harness must capture index usage.'
Assert-Contains $measurement 'dm_db_index_operational_stats' 'The performance harness must capture locking and latch evidence.'
Assert-Contains $measurement 'dm_db_missing_index' 'The performance harness must retain missing-index hints only as evidence.'
Assert-Contains $measurement 'dm_db_partition_stats' 'The performance harness must capture per-index row and page size.'
Assert-Contains $measurement 'dm_exec_procedure_stats' 'The performance harness must capture cached procedure history.'
Assert-Contains $measurement 'BEFORE_HARNESS' 'The performance harness must capture a procedure-counter baseline.'
Assert-Contains $measurement 'AFTER_HARNESS' 'The performance harness must capture post-measurement procedure counters.'
Assert-Contains $measurement 'PlanBaselineComparable' 'Procedure deltas must fail closed when the cached-plan baseline changes.'
Assert-Contains $measurement 'ReadsPerWrite' 'Index evidence must expose read benefit against write cost.'
Assert-Contains $measurement 'query_store_runtime_stats' 'The performance harness must capture bounded Query Store history when available.'
Assert-Contains $measurement 'do not select query text or plan XML' 'Query Store evidence must exclude sensitive SQL text and plans.'
Assert-Contains $measurement 'Do not clear the plan cache or buffer pool' 'The performance harness must prohibit disruptive cache clearing.'
Assert-Contains $measurement '#Phase81GovernorCases' 'Representative IDs must enter through an untracked private session table.'
Assert-Contains $measurement 'CREATE TABLE\s+#Phase81GovernorCases' 'The private session-table shape must be reproducible without tracked IDs.'
Assert-Contains $measurement 'Never put real Governor IDs in this repository file' 'The harness must prohibit tracked representative IDs.'
Assert-Contains $measurement 'reports/phase81_private' 'Raw evidence must use the ignored private report directory.'
Assert-Contains $measurement 'Never commit or share raw plans/Results' 'Raw SQL evidence must remain private.'
Assert-Contains $measurement 'ParameterCompiledValue/ParameterRuntimeValue' 'Shared plan summaries must remove parameter values.'
Assert-Contains $measurement 'CURSOR LOCAL FAST_FORWARD' 'The harness must run representative cases sequentially.'
if (($measurement -match '\bDBCC\b') -or
    ($measurement -match 'ALTER\s+DATABASE\s+SCOPED\s+CONFIGURATION') -or
    ($measurement -match '\b(CREATE|ALTER|DROP|TRUNCATE)\s+(?:(?:UNIQUE|CLUSTERED|NONCLUSTERED)\s+)*(?:TABLE|INDEX)\s+(?!#)') -or
    ($measurement -match '\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE)\s+dbo\.')) {
    $failures.Add('The performance harness must remain read-only and must not clear caches.')
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Phase 8.1 leadership Last Active contract checks passed.'
