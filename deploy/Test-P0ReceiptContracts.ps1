param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
function P0-Hash([string]$Value) {
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant()
}
$manifest = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deploy/export_stats_import_outcome_source.json') -Raw | ConvertFrom-Json
$migration = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'migrations/20261022_001_p0_pipeline_receipts.sql')).Replace("`r`n","`n")
$bodies = [regex]::Matches($migration,"EXEC sys\.sp_executesql N'(?<body>(?:[^']|'')*)';",[Text.RegularExpressions.RegexOptions]::Singleline)
foreach ($name in @('UPDATE_ALL2','usp_S11CompleteStatsReports','usp_S11ValidateStatsReportStage','usp_update_stats')) {
    $text = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "sql_schema/dbo.$name.StoredProcedure.sql")).Replace("`r`n","`n")
    $start = [regex]::Match($text,'(?m)^(ALTER|CREATE OR ALTER|CREATE) PROCEDURE\b')
    if (-not $start.Success) { throw "Missing module declaration: $name" }
    $body = [regex]::Split($text.Substring($start.Index),'(?im)^GO\s*$')[0].Trim()
    $body = [regex]::Replace($body,'^(ALTER|CREATE OR ALTER|CREATE) PROCEDURE','CREATE OR ALTER PROCEDURE')
    if (@($bodies | Where-Object { $_.Groups['body'].Value.Replace("''","'") -ceq $body }).Count -ne 1) { throw "P0 migration body differs: $name" }
    if ($name -cne 'usp_update_stats') {
        $row = @($manifest.modules | Where-Object name -CEQ "dbo.$name")
        if ($row.Count -ne 1 -or (P0-Hash $text) -cne $row[0].source_sha256) { throw "P0 source hash differs: $name" }
    }
}
foreach ($name in @('StatsImportReportContinuation','ProcessingPipelineRun','ProcessingPipelineStage','ExportContainmentAttestation','ExportRegistrationAttestation','ExportUnownedHoldDisposition')) {
    if (-not $migration.Contains("CREATE TABLE dbo.$name")) { throw "Missing P0 receipt table: $name" }
    foreach ($operation in @('DELETE FROM','TRUNCATE TABLE')) {
        if ($migration.Contains("$operation dbo.$name")) { throw "P0 migration mutates receipt data: $name" }
    }
}
foreach ($guard in @('K98:S11:schema','Authority sessions must be closed','SQL snapshot producer is live','Scan writer is live','Checks contract differs','index contract differs','Unreviewed UPDATE_ALL2 preimage','ROLLBACK')) {
    if (-not $migration.Contains($guard)) { throw "Missing migration guard: $guard" }
}
$baseline = Join-Path $RepositoryRoot 'deploy/source_baselines/UPDATE_ALL2-before-p0-receipts.txt'
if ((Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -cne '830b0a96b06904f3871962e067884529b053b59657d9068e4503cd73ca07663a') { throw 'Historical UPDATE_ALL2 source differs' }
Write-Output 'PASS: exact P0 module postimages, source identities, receipt tables, historical source and migration guards. No SQL connection.'
