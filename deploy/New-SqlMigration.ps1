param(
    [Parameter(Mandatory=$true)][string]$Description,
    [string]$Author = "cwatts",
    [string]$RepoPath,
    [ValidateSet("Low", "Medium", "High")][string]$RiskLevel = "Low",
    [ValidateSet("Yes", "No")][string]$RequiresBackup = "Yes",
    [ValidateSet("Manual", "Included", "NotPossible")][string]$Rollback = "Manual",
    [ValidateSet("Auto", "Required", "None")][string]$TransactionMode = "Auto"
)

. "$PSScriptRoot\SqlDeploy.Common.ps1"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Get-K98RepoRoot
}

$repoRoot = (Resolve-Path $RepoPath).ProviderPath
$migrationDir = Join-Path $repoRoot "migrations"
Ensure-K98Directory -Path $migrationDir

$datePart = Get-Date -Format "yyyyMMdd"
$safeDescription = $Description.ToLowerInvariant() -replace "[^a-z0-9]+", "_"
$safeDescription = $safeDescription.Trim("_")
if ([string]::IsNullOrWhiteSpace($safeDescription)) {
    throw "Description must contain at least one letter or number."
}

$existing = Get-ChildItem -Path $migrationDir -Filter "$datePart`_*.sql" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "^$datePart`_(\d{3})_" }

$nextNumber = 1
foreach ($file in $existing) {
    if ($file.Name -match "^$datePart`_(\d{3})_") {
        $n = [int]$matches[1]
        if ($n -ge $nextNumber) {
            $nextNumber = $n + 1
        }
    }
}

$sequence = "{0:000}" -f $nextNumber
$migrationId = "$datePart`_$sequence`_$safeDescription"
$path = Join-Path $migrationDir "$migrationId.sql"

$createdUtc = [DateTime]::UtcNow.ToString("yyyy-MM-dd")
$content = @"
/*
MigrationId: $migrationId
Purpose: $Description
Author: $Author
CreatedUtc: $createdUtc
RequiresBackup: $RequiresBackup
RiskLevel: $RiskLevel
Rollback: $Rollback
TransactionMode: $TransactionMode
RelatedBotPR:
RelatedSQLPR:
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Add migration SQL here.
"@

Set-Content -Path $path -Value $content -Encoding UTF8
Write-Host "Created migration: $path"
