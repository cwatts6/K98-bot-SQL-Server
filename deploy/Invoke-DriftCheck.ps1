param(
    [string]$ServerName = "MINI_AMD",
    [string]$DatabaseName = "ROK_TRACKER",
    [string]$RepoPath
)

. "$PSScriptRoot\SqlDeploy.Common.ps1"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Get-K98RepoRoot
}

$repoRoot = (Resolve-Path $RepoPath).ProviderPath
$snapshotPath = Join-Path (Join-Path $repoRoot "exports") ("prod-schema-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

& (Join-Path $PSScriptRoot "Export-ProdSchemaSnapshot.ps1") `
    -ServerName $ServerName `
    -DatabaseName $DatabaseName `
    -RepoPath $repoRoot `
    -SnapshotOutputPath $snapshotPath `
    -DriftOnly

& (Join-Path $PSScriptRoot "Compare-ProdSchema.ps1") `
    -RepoPath $repoRoot `
    -ActualSchemaPath $snapshotPath
