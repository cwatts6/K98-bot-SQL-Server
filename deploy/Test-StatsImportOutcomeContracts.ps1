param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
. (Join-Path $RepositoryRoot 'deploy/StatsImportOutcome.Source.ps1')
function Get-OutcomeHash([string]$Value, [switch]$Definition) {
    if ($Definition) {
        $Value = $Value.Replace("`r`n", "`n").Trim([char[]]" `t`r`n")
        $Value = [regex]::Replace($Value,'^(ALTER|CREATE OR ALTER)\b','CREATE')
        $bytes = [Text.Encoding]::Unicode.GetBytes($Value)
    } else { $bytes = [Text.Encoding]::UTF8.GetBytes($Value) }
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
$historical = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deploy/export_legacy_direct_permission_manifest.json') -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deploy/export_stats_import_outcome_source.json') -Raw | ConvertFrom-Json
if ($source.modules.Count -ne 39 -or $source.roots.Count -ne 8 -or $source.signatures.Count -ne 0) { throw 'Outcome source closure differs' }
if (($source.roots -join '|') -cne ((@($historical.roots) + 'dbo.usp_S11RunStatsImport') -join '|')) { throw 'Unrelated root permissions changed' }
$expectedGrants = @($historical.grants) + [pscustomobject]@{database='ROK_TRACKER';principal='ExportLegacyEntryReader';securable_class='OBJECT';target='dbo.usp_S11RunStatsImport';permission='EXECUTE'}
if (($source.grants | ConvertTo-Json -Depth 64 -Compress) -cne ($expectedGrants | ConvertTo-Json -Depth 64 -Compress)) { throw 'Unrelated grants changed' }
$migration = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'migrations/20261009_001_stats_import_outcomes.sql'))
$bodies = [regex]::Matches($migration,"EXEC sys\.sp_executesql N'(?<body>(?:[^']|'')*)';",[Text.RegularExpressions.RegexOptions]::Singleline)
if ($bodies.Count -ne 2) { throw 'Exactly two outcome module bodies required' }
foreach ($name in @('dbo.UPDATE_ALL2','dbo.usp_S11RunStatsImport')) {
    $module = @($source.modules | Where-Object name -CEQ $name)
    if ($module.Count -ne 1) { throw "Missing exact module: $name" }
    $text = [IO.File]::ReadAllText((Join-Path $RepositoryRoot $module[0].path)).Replace("`r`n","`n")
    if ((Get-OutcomeHash $text) -cne $module[0].source_sha256) { throw "Source hash differs: $name" }
    $start = [regex]::Match($text,'(?m)^(ALTER PROCEDURE|CREATE OR ALTER PROCEDURE)')
    $body = $text.Substring($start.Index).Trim([char[]]" `t`r`n")
    if ((Get-OutcomeHash $body -Definition) -cne $module[0].definition_sha256) { throw "Definition hash differs: $name" }
    if (@($bodies | Where-Object { $_.Groups['body'].Value.Replace("''","'") -ceq $body }).Count -ne 1) { throw "Migration body differs: $name" }
    if ($name -ceq 'dbo.UPDATE_ALL2') {
        $old = @($historical.modules | Where-Object name -CEQ $name)[0]
        $before = (Get-S11PreOutcomeSource $text).Replace("`n","`r`n")
        if ((Get-OutcomeHash $before) -cne $old.source_sha256) { throw 'Outcome amendment changes unrelated legacy source' }
        if ($text.IndexOf("State='import_committed', ScanOrder=@AllocatedScanOrder") -gt $text.IndexOf('Import is now durable')) { throw 'Phase A receipt is outside its transaction' }
        if (-not $text.Contains("State='completed',")) { throw 'Exact completion marker missing' }
        if (-not $text.Contains('OUTPUT inserted.LastRunCounter INTO @S11CompletionCounters (LastRunCounter)') -or
            -not $text.Contains('LastRunCounter=(SELECT LastRunCounter FROM @S11CompletionCounters)') -or
            -not $text.Contains("MAX(LastRunCounter) FROM dbo.SP_TaskStatus WITH (UPDLOCK,HOLDLOCK) WHERE TaskName='UPDATE_ALL2'")) {
            throw 'Completion counter must be atomically allocated and bound to this inserted status row'
        }
    }
}
foreach ($module in $historical.modules | Where-Object name -CNE 'dbo.UPDATE_ALL2') {
    $actual = @($source.modules | Where-Object name -CEQ $module.name)
    if ($actual.Count -ne 1 -or ($actual[0] | ConvertTo-Json -Depth 64 -Compress) -cne ($module | ConvertTo-Json -Depth 64 -Compress)) { throw "Unrelated source changed: $($module.name)" }
}
foreach ($guard in @('K98:S11:schema','Execution sessions must be closed','Unsigned caller module required','StatsImportExecution CHECK contract differs','StatsImportExecution index keys differ','ROLLBACK')) {
    if (-not $migration.Contains($guard)) { throw "Missing migration guard: $guard" }
}
Write-Output 'PASS: exact outcome source and migration bodies, inverse legacy source, transactional markers and migration guards. No SQL connection.'
