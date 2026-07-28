[CmdletBinding()]
param(
    [string] $RepoPath = (
        Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    ).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failures = New-Object System.Collections.Generic.List[string]

function Get-RepoText {
    param([Parameter(Mandatory = $true)][string] $RelativePath)

    $path = Join-Path $RepoPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing required file: $RelativePath")
        return ''
    }

    return [System.IO.File]::ReadAllText($path)
}

function Assert-Matches {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [Parameter(Mandatory = $true)][string] $Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-NotMatches {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [Parameter(Mandatory = $true)][string] $Message
    )

    if ($Text -match $Pattern) {
        $failures.Add($Message)
    }
}

$migration = Get-RepoText (
    'migrations\20260727_001_phase4_view_type_alignment.sql'
)
$retirement = Get-RepoText (
    'migrations\20260727_000_retire_vAllianceActivity_WeeklyCumulative.sql'
)
$rollback = Get-RepoText (
    'migrations\rollback\20260727_001_phase4_view_type_alignment_rollback.sql'
)
$activePlayers = Get-RepoText (
    'sql_schema\dbo.v_Active_Players.View.sql'
)
$mgeSignupReview = Get-RepoText (
    'sql_schema\dbo.v_MGE_SignupReview.View.sql'
)
$dailyExport = Get-RepoText (
    'sql_schema\dbo.vDaily_PlayerExport.View.sql'
)
$globalLatest = Get-RepoText (
    'sql_schema\dbo.vw_Governor_KVK_Summary_GlobalLatest.View.sql'
)
$governorNames = Get-RepoText (
    'sql_schema\dbo.v_GovernorNames.View.sql'
)
$under50 = Get-RepoText (
    'sql_schema\dbo.v_KVK_Under50_Last3_WithLatest.View.sql'
)
$preflight = Get-RepoText (
    'performance_remediation\kingdomscandata4\phase4\01_preflight.sql'
)
$verify = Get-RepoText (
    'performance_remediation\kingdomscandata4\phase4\02_verify.sql'
)
$benchmarks = Get-RepoText (
    'performance_remediation\kingdomscandata4\phase4\03_run_view_benchmarks.sql'
)
$plans = Get-RepoText (
    'performance_remediation\kingdomscandata4\phase4\04_capture_plan_evidence.sql'
)

Assert-Matches $migration `
    'MigrationId:\s*20260727_001_phase4_view_type_alignment' `
    'The Phase 4 migration ID is missing or incorrect.'
Assert-Matches $migration 'Rollback:\s*Included' `
    'The Phase 4 migration must declare its reviewed rollback.'
Assert-Matches $migration 'TransactionMode:\s*Required' `
    'The Phase 4 migration must require one deployment connection/transaction.'
Assert-Matches $rollback `
    'RollbackForMigrationId:\s*20260727_001_phase4_view_type_alignment' `
    'The Phase 4 rollback does not target the exact migration.'
Assert-Matches $rollback `
    'DECLARE\s+@ExpectedPhase4Definitions\s+TABLE' `
    'The Phase 4 rollback must declare exact expected post-Phase-4 definitions.'
Assert-Matches $rollback `
    "THROW\s+52065,\s*'Phase 4 rollback refused unexpected current view-definition drift\.'" `
    'The Phase 4 rollback must abort when a deployed Phase 4 view definition drifts.'

foreach ($expectedPhase4Hash in @(
    'A6AB97DCA84D77938BB704C16EF2068D4068F984BBE16387F86AD0EC83A277D9',
    '19517DDD876737A0048C52ED9F6063612DCBC0D9DFEA1D39B7F3F47E2F6F6166',
    'A7A956AD759C68C23DF88F9E9DF13080196366C57AE2B5260F84370F4D0307C6',
    '4214C47A48AF5D9D3958122B177CC0FEA111AAAB476B165836AF68E9B5B4ED3C'
)) {
    if ($expectedPhase4Hash.Length -ne 64) {
        $failures.Add(
            "Expected deployed Phase 4 definition hash is not 64 characters: $expectedPhase4Hash"
        )
    }
    Assert-Matches $rollback $expectedPhase4Hash `
        "The Phase 4 rollback is missing reviewed deployed-definition hash: $expectedPhase4Hash"
}

$rollbackDriftGuardIndex = $rollback.IndexOf(
    'DECLARE @ExpectedPhase4Definitions TABLE',
    [System.StringComparison]::Ordinal
)
$rollbackFirstDefinitionIndex = $rollback.IndexOf(
    'CREATE OR ALTER VIEW dbo.',
    [System.StringComparison]::Ordinal
)
if (
    $rollbackDriftGuardIndex -lt 0 -or
    $rollbackFirstDefinitionIndex -lt 0 -or
    $rollbackDriftGuardIndex -gt $rollbackFirstDefinitionIndex
) {
    $failures.Add(
        'The Phase 4 rollback drift guard must execute before the first view definition change.'
    )
}

Assert-Matches $retirement `
    'MigrationId:\s*20260727_000_retire_vAllianceActivity_WeeklyCumulative' `
    'The Phase 4 retirement migration ID is missing or incorrect.'
Assert-Matches $retirement 'Rollback:\s*Forward Fix Only' `
    'The invalid unused view retirement must not claim a misleading automatic rollback.'
Assert-Matches $retirement `
    'DROP\s+VIEW\s+dbo\.vAllianceActivity_WeeklyCumulative' `
    'The retirement migration does not remove the obsolete view.'
foreach ($guard in @(
    'sys\.sql_expression_dependencies',
    'sys\.database_permissions',
    'sys\.crypt_properties',
    'sys\.extended_properties',
    'DD5C6AC7E3D179463AB22C2618026A0479BC8A0C0D9564D766F1553237465CF4'
)) {
    Assert-Matches $retirement $guard `
        "The retirement migration is missing required guard: $guard"
    Assert-Matches $preflight $guard `
        "The Phase 4 preflight is missing retirement guard: $guard"
}

$retiredCanonicalPath = Join-Path $RepoPath (
    'sql_schema\dbo.vAllianceActivity_WeeklyCumulative.View.sql'
)
if (Test-Path -LiteralPath $retiredCanonicalPath) {
    $failures.Add(
        'The retired vAllianceActivity_WeeklyCumulative canonical schema file still exists.'
    )
}

foreach ($source in @($migration, $rollback)) {
    Assert-Matches $source `
        "K98:KingdomScanData4:Migration" `
        'Phase 4 forward and rollback must hold the shared migration mutex.'
    Assert-Matches $source `
        'EXEC\s+dbo\.ACQUIRE_KS4_IMPORT_LOCK' `
        'Phase 4 forward and rollback must hold the Phase 3 import mutex.'
    Assert-Matches $source `
        'BEGIN\s+TRANSACTION' `
        'Phase 4 forward and rollback must be transactional.'
    Assert-Matches $source `
        'COMMIT\s+TRANSACTION' `
        'Phase 4 forward and rollback must commit only after validation.'
    Assert-Matches $source `
        'EXCEPT' `
        'Phase 4 forward and rollback must prove bidirectional value equivalence.'
    Assert-Matches $source `
        'MetadataBefore' `
        'Phase 4 forward and rollback must snapshot result metadata.'
    Assert-Matches $source `
        'MetadataAfter' `
        'Phase 4 forward and rollback must compare result metadata.'
}

foreach ($source in @($migration, $rollback, $preflight, $verify)) {
    Assert-Matches $source `
        'sys\.crypt_properties' `
        'Every Phase 4 refresh path must refuse signed modules before metadata refresh.'
    Assert-Matches $source `
        "class_desc\s*=\s*N'OBJECT_OR_COLUMN'" `
        'The Phase 4 signed-module guard must target object signatures explicitly.'
}

Assert-Matches $activePlayers `
    'CAST\s*\(\s*KS4\.\[GovernorID\]\s+AS\s+bigint\s*\)' `
    'v_Active_Players must retain the select cast that preserves legacy result nullability.'

Assert-NotMatches $mgeSignupReview `
    'CAST\s*\(\s*ls\.GovernorID\s+AS\s+BIGINT\s*\)' `
    'v_MGE_SignupReview retains an obsolete GovernorID join cast.'
Assert-Matches $mgeSignupReview `
    'ON\s+ls\.GovernorID\s*=\s*s\.GovernorId' `
    'v_MGE_SignupReview must join aligned bigint operands directly.'

Assert-Matches $globalLatest `
    'CAST\s*\(\s*ls\.GovernorID\s+AS\s+bigint\s*\)\s+AS\s+\[GovernorId\]' `
    'The global-latest view must retain the select cast that preserves legacy result nullability.'
Assert-Matches $globalLatest `
    'kvk_latest\.Gov_ID\s*=\s*ls\.GovernorID' `
    'The global-latest view must join aligned bigint operands directly.'
Assert-Matches $globalLatest `
    'kvk_prev\.Gov_ID\s*=\s*ls\.GovernorID' `
    'The global-latest previous-KVK join must use aligned bigint operands.'

foreach ($metric in @(
    'Power',
    'KillPoints',
    'Deads',
    'RSS_Gathered',
    'RSSAssistance',
    'Helps',
    'T4_Kills',
    'T5_Kills'
)) {
    Assert-NotMatches $dailyExport `
        ("TRY_CONVERT\s*\(\s*bigint\s*,\s*ks\." + [regex]::Escape($metric)) `
        "vDaily_PlayerExport retains obsolete bigint conversion for $metric."
}
Assert-NotMatches $dailyExport `
    'TRY_CONVERT\s*\(\s*bigint\s*,\s*ks\.\[T4&T5_KILLS\]' `
    'vDaily_PlayerExport retains obsolete bigint conversion for T4&T5_KILLS.'

Assert-Matches $dailyExport `
    'TRY_CONVERT\s*\(\s*bigint\s*,\s*ks\.\[Troops Power\]' `
    'vDaily_PlayerExport must retain the float-to-bigint Troops Power contract.'
Assert-Matches $dailyExport `
    'TRY_CONVERT\s*\(\s*bigint\s*,\s*ks\.\[Tech Power\]' `
    'vDaily_PlayerExport must retain the float-to-bigint Tech Power contract.'
Assert-Matches $dailyExport `
    'LTRIM\s*\(\s*RTRIM\s*\(\s*ks\.GovernorName' `
    'vDaily_PlayerExport must retain GovernorName display trimming.'
Assert-Matches $dailyExport `
    'LTRIM\s*\(\s*RTRIM\s*\(\s*ks\.Alliance' `
    'vDaily_PlayerExport must retain Alliance display trimming.'
Assert-Matches $governorNames `
    'NULLIF\s*\(\s*LTRIM\s*\(\s*RTRIM' `
    'v_GovernorNames must retain blank-to-null and fallback trimming.'
Assert-Matches $under50 `
    'TRY_CONVERT\s*\(\s*decimal\(9,2\)\s*,\s*pkh\.KillPercent' `
    'The KVK under-50 view must retain KillPercent boundary conversion.'

foreach ($viewName in @(
    'v_Active_Players',
    'v_GovernorNames',
    'v_KVK_Under50_Last3_WithLatest',
    'v_MGE_SignupReview',
    'v_PlayerLatestStats',
    'vDaily_Helps',
    'vDaily_PlayerExport',
    'vDaily_RSSAssisted',
    'vDaily_RSSGathered',
    'vWTD_Helps',
    'vWTD_RSSAssisted',
    'vWTD_RSSGathered',
    'vw_Governor_KVK_Summary_GlobalLatest'
)) {
    foreach ($source in @($preflight, $verify, $benchmarks)) {
        Assert-Matches $source ([regex]::Escape($viewName)) `
            "Phase 4 validation coverage is missing $viewName."
    }
}

foreach ($consumerName in @(
    'v_GovernorNames_Strict',
    'vAllianceActivity_DailyDelta',
    'vAllianceActivity_WeeklyDelta',
    'v_PlayerProfile',
    'v_PlayerAccounts_Migrate',
    'fn_StatsWindowDeltas',
    'fn_StatsWindowDeltas_GovCsv',
    'usp_GetPlayerStatsWindows'
)) {
    foreach ($source in @($preflight, $verify)) {
        Assert-Matches $source ([regex]::Escape($consumerName)) `
            "Phase 4 refresh/compile coverage is missing $consumerName."
    }
}

Assert-Matches $preflight `
    'retirement_eligibility' `
    'Phase 4 preflight does not emit an obsolete-view retirement eligibility receipt.'
Assert-Matches $verify `
    "OBJECT_ID\s*\(\s*N'dbo\.vAllianceActivity_WeeklyCumulative'\s*\)\s+IS\s+NOT\s+NULL" `
    'Phase 4 verification does not fail when the retired view remains present.'
foreach ($source in @($migration, $rollback, $verify)) {
    Assert-NotMatches $source `
        "sp_refreshview\s+N'dbo\.vAllianceActivity_WeeklyCumulative'" `
        'A Phase 4 refresh path still attempts to compile the retired invalid view.'
}

Assert-Matches $benchmarks `
    'WHILE\s+@RunNumber\s*<=\s*5' `
    'The Phase 4 benchmark must run one warm-up plus five measured executions.'
Assert-Matches $benchmarks `
    'COUNT\s*\(\s*DISTINCT\s+ResultDigest\s*\)' `
    'The Phase 4 benchmark must prove digest stability.'
Assert-Matches $plans `
    'SET\s+STATISTICS\s+XML\s+ON' `
    'The Phase 4 plan collector must capture actual XML plans.'
Assert-Matches $plans `
    'SET\s+STATISTICS\s+IO\s+ON' `
    'The Phase 4 plan collector must capture reads.'
Assert-Matches $plans `
    'SET\s+STATISTICS\s+TIME\s+ON' `
    'The Phase 4 plan collector must capture CPU and duration.'

$forwardDefinitions = [regex]::Matches(
    $migration,
    '(?im)^CREATE OR ALTER VIEW dbo\.'
)
$rollbackDefinitions = [regex]::Matches(
    $rollback,
    '(?im)^CREATE OR ALTER VIEW dbo\.'
)

if ($forwardDefinitions.Count -ne 4) {
    $failures.Add(
        "Expected 4 Phase 4 forward view definitions; found $($forwardDefinitions.Count)."
    )
}

if ($rollbackDefinitions.Count -ne 4) {
    $failures.Add(
        "Expected 4 Phase 4 rollback view definitions; found $($rollbackDefinitions.Count)."
    )
}

if ($failures.Count -ne 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    throw "Phase 4 contract validation failed with $($failures.Count) issue(s)."
}

Write-Host 'Phase 4 static contract validation passed.'
Write-Host "Forward view definitions: $($forwardDefinitions.Count)"
Write-Host "Rollback view definitions: $($rollbackDefinitions.Count)"
