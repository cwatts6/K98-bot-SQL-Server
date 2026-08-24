[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).ProviderPath
$verifierPath = Join-Path $PSScriptRoot 'Verify-Phase52CombinedPostPhase51.sql'
$phase2VerifyPath = Join-Path $repoRoot `
    'performance_remediation\kingdomscandata4\phase2\02_verify.sql'
$phase2FinalizerPath = Join-Path $repoRoot `
    'performance_remediation\kingdomscandata4\phase2\03_finalize.sql'

foreach ($requiredPath in @(
        $verifierPath,
        $phase2VerifyPath,
        $phase2FinalizerPath
    )) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing combined-verifier contract input: $requiredPath"
    }
}

$source = [IO.File]::ReadAllText($verifierPath)

function Require-Match {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )

    if ($source -notmatch $Pattern) {
        throw $Message
    }
}

function Require-Order {
    param(
        [Parameter(Mandatory)][string]$First,
        [Parameter(Mandatory)][string]$Second,
        [Parameter(Mandatory)][string]$Message
    )

    $firstIndex = $source.IndexOf($First, [StringComparison]::Ordinal)
    $secondIndex = $source.IndexOf($Second, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or
        $firstIndex -ge $secondIndex) {
        throw $Message
    }
}

function Test-ControlledReapplyName {
    param([Parameter(Mandatory)][string]$DatabaseName)

    $prefix = 'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_'
    if (-not $DatabaseName.StartsWith(
            $prefix,
            [StringComparison]::Ordinal
        )) {
        return $false
    }

    $tail = $DatabaseName.Substring($prefix.Length)
    if ($tail -match '^[0-9]{8}$') {
        $dateText = $tail
    }
    elseif ($tail -match '^R([1-9][0-9]*)_([0-9]{8})$') {
        $dateText = $Matches[2]
    }
    else {
        return $false
    }

    $parsedDate = [DateTime]::MinValue
    return [DateTime]::TryParseExact(
        $dateText,
        'yyyyMMdd',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,
        [ref]$parsedDate
    )
}

Require-Match `
    -Pattern "DECLARE\s+@ConfirmTargetDatabase\s+sysname\s*=\s*N''" `
    -Message 'The repository verifier must refuse without an exact target declaration.'
Require-Match `
    -Pattern 'DECLARE\s+@ConfirmPhase2RunId\s+uniqueidentifier\s*=\s*NULL' `
    -Message 'The repository verifier must refuse without an exact Phase 2 run ID.'
Require-Match `
    -Pattern 'DECLARE\s+@ExecuteCombinedVerification\s+bit\s*=\s*0' `
    -Message 'The repository verifier must remain disabled by default.'
Require-Match `
    -Pattern "DB_NAME\(\)\s*=\s*N'ROK_TRACKER'[\s\S]*THROW 52603" `
    -Message 'The combined verifier must refuse the production database.'
Require-Match `
    -Pattern "Status\s*=\s*'VERIFIED'[\s\S]*VerifiedAtUtc IS NOT NULL[\s\S]*RollbackCompletedAtUtc IS NULL[\s\S]*FinalizedAtUtc IS NULL" `
    -Message 'The exact pre-existing VERIFIED Phase 2 state is not required.'
Require-Match `
    -Pattern 'DATALENGTH\(actual\.ErrorMessage\)\s*<>\s*0' `
    -Message 'Runner-canonical non-null zero-length ErrorMessage is not required.'
Require-Match `
    -Pattern 'LEN\(actual\.GitCommit\)\s*<>\s*12' `
    -Message 'Applied history is not constrained to the runner 12-character commit.'
Require-Match `
    -Pattern 'Unexpected external target session or request exists' `
    -Message 'The external session refusal gate is absent.'
Require-Match `
    -Pattern 'Unexpected external target transaction exists' `
    -Message 'The external transaction refusal gate is absent.'
Require-Match `
    -Pattern "OBJECT_ID\(N'dbo\.vAllianceActivity_WeeklyCumulative'\) IS NOT NULL" `
    -Message 'The intentionally retired Phase 4 view is not required absent.'
Require-Match `
    -Pattern 'DBCC CHECKTABLE \(N''dbo\.IMPORT_STAGING_Phase2_Old''\)' `
    -Message 'The sixth current/retained Phase 2 table is not DBCC checked.'

$historyStart = $source.IndexOf(
    'INSERT @ExpectedHistory',
    [StringComparison]::Ordinal
)
$historyEnd = $source.IndexOf(
    'IF (SELECT COUNT(*) FROM @ExpectedHistory)',
    [StringComparison]::Ordinal
)
if ($historyStart -lt 0 -or $historyEnd -le $historyStart) {
    throw 'The exact migration-history block could not be isolated.'
}
$historyBlock = $source.Substring($historyStart, $historyEnd - $historyStart)
$historyIds = @(
    [regex]::Matches(
        $historyBlock,
        "N'(2026[0-9]{4}_[0-9]{3}_[A-Za-z0-9_]+)'"
    ) | ForEach-Object { $_.Groups[1].Value }
)
$expectedHistoryIds = @(
    '20260725_001_kingdomscandata4_shadow_type_remediation',
    '20260726_001_phase3_import_concurrency_and_direct_type_alignment',
    '20260727_000_retire_vAllianceActivity_WeeklyCumulative',
    '20260727_001_phase4_view_type_alignment',
    '20260728_001_phase5_immutable_import_file_handoff',
    '20260816_001_phase5_1_claim_acl_hardening'
)
if (($historyIds -join "`n") -cne ($expectedHistoryIds -join "`n")) {
    throw 'The combined verifier does not freeze the exact six migration IDs in order.'
}
if ([regex]::Matches($historyBlock, "'[A-F0-9]{64}'").Count -ne 6) {
    throw 'The combined verifier does not freeze six exact applied migration digests.'
}

$moduleStart = $source.IndexOf(
    'INSERT @AllowedChangedModules',
    [StringComparison]::Ordinal
)
$moduleEnd = $source.IndexOf(
    'IF (SELECT COUNT(*) FROM @AllowedChangedModules)',
    [StringComparison]::Ordinal
)
if ($moduleStart -lt 0 -or $moduleEnd -le $moduleStart) {
    throw 'The module-supersession block could not be isolated.'
}
$moduleBlock = $source.Substring($moduleStart, $moduleEnd - $moduleStart)
$changedModules = @(
    [regex]::Matches($moduleBlock, "\(N'dbo', N'([^']+)'\)") |
        ForEach-Object { $_.Groups[1].Value }
)
if ($changedModules.Count -ne 33 -or
    @($changedModules | Select-Object -Unique).Count -ne 33) {
    throw 'The exact 33-module Phase 2 supersession set is not frozen.'
}

$digestWorkStart = $source.IndexOf(
    'INSERT @DigestWork',
    [StringComparison]::Ordinal
)
$digestWorkEnd = $source.IndexOf(
    '@DigestSequenceNo int,',
    [StringComparison]::Ordinal
)
if ($digestWorkStart -lt 0 -or $digestWorkEnd -le $digestWorkStart) {
    throw 'The current/retained digest worklist could not be isolated.'
}
$digestWorkBlock = $source.Substring(
    $digestWorkStart,
    $digestWorkEnd - $digestWorkStart
)
if ([regex]::Matches(
        $digestWorkBlock,
        "N'(?:KS4|KS5|STAGING)_(?:CURRENT|RETAINED)'"
    ).Count -ne 6) {
    throw 'The verifier does not recompute all six current/retained digests.'
}

$durableUpdates = @(
    [regex]::Matches(
        $source,
        '(?im)^\s*UPDATE\s+dbo\.[A-Za-z0-9_]+'
    ) | ForEach-Object { $_.Value.Trim() }
)
if ($durableUpdates.Count -ne 1 -or
    $durableUpdates[0] -cne 'UPDATE dbo.KS4_Phase2_PreflightState') {
    throw 'The combined verifier must have exactly one durable UPDATE target.'
}
if ($source -match '(?im)^\s*(INSERT|DELETE|MERGE)\s+dbo\.' -or
    $source -match '(?im)^\s*(ALTER|DROP|TRUNCATE|CREATE)\s+') {
    throw 'The combined verifier contains an unauthorized durable mutation.'
}
if ($source -match '(?is)(UPDATE|INSERT|DELETE|MERGE)\s+dbo\.(SchemaMigrationHistory|KS4_Phase2_ModuleInventory)') {
    throw 'The combined verifier must never edit history or the Phase 2 module inventory.'
}

Require-Order `
    -First "DBCC CHECKTABLE (N'dbo.IMPORT_STAGING_Phase2_Old')" `
    -Second 'UPDATE dbo.KS4_Phase2_PreflightState' `
    -Message 'VerifiedAtUtc is refreshed before all DBCC checks pass.'
Require-Order `
    -First '@GlobalLatestRows <> 411' `
    -Second 'UPDATE dbo.KS4_Phase2_PreflightState' `
    -Message 'VerifiedAtUtc is refreshed before the critical read smokes pass.'
Require-Order `
    -First "THROW 52630, 'Combined verification leaked a transaction" `
    -Second 'UPDATE dbo.KS4_Phase2_PreflightState' `
    -Message 'VerifiedAtUtc is refreshed before the final transaction gate.'
Require-Order `
    -First 'SET VerifiedAtUtc = SYSUTCDATETIME()' `
    -Second "N'phase5_2_combined_post_phase5_1'" `
    -Message 'PASS output precedes the exact timestamp refresh.'

$positiveTargets = @(
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_20260824',
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_R2_20260821',
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_R27_20261231'
)
foreach ($target in $positiveTargets) {
    if (-not (Test-ControlledReapplyName -DatabaseName $target)) {
        throw "Positive controlled-target case was refused: $target"
    }
}

$refusedTargets = @(
    'ROK_TRACKER',
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_FORWARD_20260824',
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_R0_20260824',
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_R_20260824',
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_R2_20260230',
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_R2_20260824_EXTRA'
)
foreach ($target in $refusedTargets) {
    if (Test-ControlledReapplyName -DatabaseName $target) {
        throw "Refusal target was unexpectedly accepted: $target"
    }
}

$phase2VerifySha256 = (
    Get-FileHash -LiteralPath $phase2VerifyPath -Algorithm SHA256
).Hash
$phase2FinalizerSha256 = (
    Get-FileHash -LiteralPath $phase2FinalizerPath -Algorithm SHA256
).Hash
if ($phase2VerifySha256 -cne
    'A7167AD0B6BF6599A63AB6CCA83FEC7CCB55EF8DF62B07E54A2EC7DC703DFD94') {
    throw 'The canonical Phase 2 verifier changed.'
}
if ($phase2FinalizerSha256 -cne
    '74BD70825E0BF2BE9DDA2D4FAD8C239D476ACCFB203A241B154A6FFE2DF93373') {
    throw 'The canonical Phase 2 finalizer changed.'
}

[pscustomobject]@{
    Test = 'Phase52CombinedPostPhase51Verifier'
    PositiveTargetCases = $positiveTargets.Count
    RefusalTargetCases = $refusedTargets.Count
    FrozenMigrationCount = $historyIds.Count
    SupersededPhase2ModuleCount = $changedModules.Count
    CurrentAndRetainedDigestCount = 6
    DurableUpdateCount = $durableUpdates.Count
    CanonicalPhase2VerifySha256 = $phase2VerifySha256
    CanonicalPhase2FinalizerSha256 = $phase2FinalizerSha256
    Result = 'PASS'
}
