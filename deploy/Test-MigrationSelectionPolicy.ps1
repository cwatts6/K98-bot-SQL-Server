# Offline policy regression only: parse the runner, execute its pure function, never invoke it.
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'Deploy-SqlMigration.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Runner parse failed' }
$function = $ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-K98ExplicitMigrationSelection'}, $true)
if (-not $function) { throw 'Missing pure migration selection policy' }
. ([scriptblock]::Create($function.Extent.Text))
$source = [IO.File]::ReadAllText($runner)
$call = $source.IndexOf('Assert-K98ExplicitMigrationSelection -MigrationId')
$helper = $source.IndexOf('. "$PSScriptRoot\SqlDeploy.Common.ps1"')
if ($call -lt 0 -or $helper -le $call) { throw 'Policy must execute before helpers or SQL' }
$migrationDirectory = Join-Path $PSScriptRoot '../migrations'
$cases = 0
function Assert-Blocked([string]$Id, [bool]$Target, [string]$Message) {
    $caught = $false
    try { Assert-K98ExplicitMigrationSelection -MigrationId $Id -ExplicitTarget $Target -MigrationDirectory $migrationDirectory }
    catch { if ($_.Exception.Message -notlike "*$Message*") { throw }; $caught = $true }
    if (-not $caught) { throw "Unsafe migration selection was admitted: $Id" }
    $script:cases++
}
foreach ($id in @('', '   ')) { Assert-Blocked $id $true 'Batch deployment is disabled' }
$superseded = @(
    '20261009_001_stats_import_outcomes',
    '20261010_001_stats_import_outcomes_collation',
    '20260914_002_legacy_export_preparation', '20260915_001_kvk_output_pool_rollover',
    '20260915_002_kvk_output_operation_ownership', '20260924_001_export_execution_evidence',
    '20260929_001_manual_export_registration', '20260929_002_manual_public_viewer_policy'
)
foreach ($id in $superseded) {
    Assert-Blocked $id $true 'Superseded migration'
    Assert-Blocked $id.ToUpperInvariant() $true 'Superseded migration'
}
foreach ($id in @('../20261001_001_legacy_export_preparation_installation', '*', '20261001_001_bad.sql')) {
    Assert-Blocked $id $true 'Invalid exact migration selection'
}
Assert-Blocked '20990101_001_not_present' $true 'Migration not found'
$corrected = @(Get-ChildItem (Join-Path $PSScriptRoot '../migrations/20261001_*.sql') -File)
if ($corrected.Count -ne 10) { throw 'Expected ten corrected/forward migration files' }
$corrected += Get-Item -LiteralPath (Join-Path $migrationDirectory '20261010_002_stats_import_outcomes_encoding.sql')
$corrected += Get-Item -LiteralPath (Join-Path $migrationDirectory '20261010_003_stats_import_outcome_postimages.sql')
foreach ($file in $corrected) {
    Assert-Blocked $file.BaseName $false 'explicit -ServerName and -DatabaseName'
    Assert-K98ExplicitMigrationSelection -MigrationId $file.BaseName -ExplicitTarget $true -MigrationDirectory $migrationDirectory
    $cases++
}
Assert-K98ExplicitMigrationSelection -MigrationId '20260912_001_kvk_season_complete_updates' -ExplicitTarget $false -MigrationDirectory $migrationDirectory
$cases++
$permissionText = [IO.File]::ReadAllText((Join-Path $migrationDirectory '20260924_002_export_legacy_module_permissions.sql'))
if ($permissionText -notmatch "MigrationId IN \('20260924_001_export_execution_evidence','20261001_004_export_execution_evidence_installation'\) AND Status='Applied'") {
    throw 'Permissions prerequisite must recognize only the original or corrected Applied evidence migration'
}
$cases++
Write-Host "Migration selection policy: $cases cases passed; no deployment runner or SQL execution."
