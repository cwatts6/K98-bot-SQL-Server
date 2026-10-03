param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
# Offline source validation only. No SQL, keys, credentials or live workflow.
& (Join-Path $RepositoryRoot 'deploy/Test-ExportLegacyModulePermissionContracts.ps1') -RepositoryRoot $RepositoryRoot
$checks = 0
function Assert-Direct([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
$manifestPath = Join-Path $RepositoryRoot 'deploy/export_legacy_direct_permission_manifest.json'
$bytes = [IO.File]::ReadAllBytes($manifestPath)
$text = [Text.Encoding]::UTF8.GetString($bytes)
Assert-Direct (-not $text.Contains("`r")) 'Direct manifest requires exact LF bytes'
$hash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
$direct = $text | ConvertFrom-Json
$signed = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deploy/export_legacy_module_permission_manifest.json') -Raw | ConvertFrom-Json
Assert-Direct ($direct.version -eq 2 -and $direct.permission_model -ceq 'direct_application_v1' -and $direct.signatures.Count -eq 0) 'Explicit direct profile required'
foreach ($field in @('database','default_schema','roots','modules','scan_queries','compatibility_forms','compatibility_forms_sha256')) {
    Assert-Direct (($direct.$field | ConvertTo-Json -Depth 64 -Compress) -ceq ($signed.$field | ConvertTo-Json -Depth 64 -Compress)) "Reviewed source closure drift: $field"
}
$attributes = [IO.File]::ReadAllText((Join-Path $RepositoryRoot '.gitattributes'))
Assert-Direct ([regex]::Matches($attributes,'(?m)^deploy/export_legacy_direct_permission_manifest\.json text eol=lf\r?$').Count -eq 1) 'Exact LF checkout attribute required'
$migration = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'migrations/20261003_001_export_legacy_direct_permissions.sql'))
Assert-Direct ($migration.Contains("ManifestHash COLLATE Latin1_General_100_BIN2=N'$hash'")) 'Installation input must bind actual file bytes'
Assert-Direct ($migration.Contains("@name=N'S11LegacyDirectPermissionManifest',@value=N'$hash'")) 'Installed marker must bind actual file bytes'
$primaryRows = [regex]::Matches($migration,"\(N'[^']+',0x[0-9a-f]{64},'[A-Z]+',(?:NULL|-2)\)")
$compatibleRows = [regex]::Matches($migration,"\(N'[^']+',0x[0-9a-f]{64}\)")
Assert-Direct ($primaryRows.Count -eq 38 -and $compatibleRows.Count -eq 27) 'Exact source/compatible row counts required'
foreach ($module in $direct.modules) {
    $context = if ($null -eq $module.execute_as) { 'NULL' } else { [string]$module.execute_as }
    Assert-Direct ($migration.Contains("(N'$($module.name)',0x$($module.definition_sha256),'$($module.object_type)',$context)")) "Primary row drift: $($module.name)"
    foreach ($variant in @($module.compatible_definition_sha256 | Where-Object { $null -ne $_ })) {
        Assert-Direct ($migration.Contains("(N'$($module.name)',0x$variant)")) "Compatible row drift: $($module.name)"
    }
}
$expectedGrants = @($signed.grants | ForEach-Object {
    $principal = if ($_.database -ceq 'ROK_TRACKER') { 'ExportLegacyEntryReader' } else { '$application' }
    @($_.database,$principal,$_.securable_class,$_.target,$_.permission) -join '|'
} | Sort-Object -Unique)
$actualGrants = @($direct.grants | ForEach-Object { @($_.database,$_.principal,$_.securable_class,$_.target,$_.permission) -join '|' } | Sort-Object)
Assert-Direct (($expectedGrants -join "`n") -ceq ($actualGrants -join "`n")) 'Exact remapped direct grant inventory required'
$expectedRoleSql = @($direct.grants | Where-Object database -CEQ 'ROK_TRACKER' | ForEach-Object {
    $target = if ($_.securable_class -ceq 'DATABASE') { '' } else {
        $quoted = ($_.target.Split('.') | ForEach-Object { '[' + $_ + ']' }) -join '.'
        ' ON ' + $_.securable_class + '::' + $quoted
    }
    'GRANT ' + $_.permission + $target + ' TO [ExportLegacyEntryReader];'
} | Sort-Object)
$actualRoleSql = @([regex]::Matches($migration,'(?m)^\s*(GRANT [^\r\n]+;)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
Assert-Direct (($expectedRoleSql -join "`n") -ceq ($actualRoleSql -join "`n")) 'Role SQL differs from exact direct manifest'
Write-Output "PASS: $checks offline direct permission checks plus independently derived legacy source checks. No installation or token proof."
