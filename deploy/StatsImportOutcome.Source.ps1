function Get-S11PrePipelineSource([string]$Source) {
    $source = $Source.Replace("`r`n", "`n")
    if (-not $source.Contains('EXEC dbo.usp_S11CompleteStatsReports')) { return $source }
    $root = Split-Path $PSScriptRoot -Parent
    $manifest = Get-Content -LiteralPath (Join-Path $root 'deploy/export_stats_import_outcome_source.json') -Raw | ConvertFrom-Json
    $module = @($manifest.modules | Where-Object name -CEQ 'dbo.UPDATE_ALL2')
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($source)))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
    if ($module.Count -ne 1 -or $hash -cne $module[0].source_sha256) { throw 'Unverified P0 reporting source' }
    $path = Join-Path $root 'deploy/source_baselines/UPDATE_ALL2-before-p0-receipts.txt'
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne '830b0a96b06904f3871962e067884529b053b59657d9068e4503cd73ca07663a') { throw 'Exact pre-P0 outcome source required' }
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}

function Get-S11PreOutcomeSource([string]$Source) {
    # Inverse of the reviewed receipt and exact counter-binding edits. The caller must first validate the
    # forward postimage; this never adds a historical runtime allowlist entry.
    $source = Get-S11PrePipelineSource $Source
    $source = $source.Replace("@CompletedFileName [nvarchar](260),`n    @ExportPreparationID uniqueidentifier = NULL", '@CompletedFileName [nvarchar](260)')
    $source = [regex]::Replace($source, '(?ms)^    IF @ExportPreparationID IS NOT NULL\n    BEGIN\n.*?^    END;\n\n', '')
    $source = [regex]::Replace($source, '(?ms)^        IF @ExportPreparationID IS NOT NULL\n        BEGIN\n.*?^        END;\n', '')
    $source = $source.Replace("        DECLARE @S11CompletionCounters TABLE (LastRunCounter int NOT NULL);`n", '')
    $source = $source.Replace("        OUTPUT inserted.LastRunCounter INTO @S11CompletionCounters (LastRunCounter)`n", '')
    $source = $source.Replace('FROM dbo.SP_TaskStatus WITH (UPDLOCK,HOLDLOCK)', 'FROM dbo.SP_TaskStatus')
    if ($source.Contains('@ExportPreparationID') -or $source.Contains('StatsImportExecution')) {
        throw 'Incomplete outcome amendment inversion'
    }
    return $source
}
