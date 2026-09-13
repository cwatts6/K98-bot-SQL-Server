[CmdletBinding()]
param([string]$RepoPath = (Split-Path -Parent $PSScriptRoot))
# Static text validation only. No SQL connection, evaluation, deployment or external writes.
$ErrorActionPreference = 'Stop'
$reviewRoot = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
$reviewSchema = (Get-Content -LiteralPath (Join-Path $reviewRoot 'sql_schema/KVK.SourceAdminReview.Table.sql') -Raw).Replace("`r`n","`n")
$reviewMigration = (Get-Content -LiteralPath (Join-Path $reviewRoot 'migrations/20260913_002_kvk_source_admin_reviews.sql') -Raw).Replace("`r`n","`n")
$reviewFixture = Get-Content -LiteralPath (Join-Path $reviewRoot 'validation/kvk_source/s8c_admin_reviews.sql') -Raw
$reviewStart = $reviewSchema.IndexOf('CREATE TABLE KVK.SourceAdminReview')
$reviewEnd = $reviewSchema.IndexOf("`n);",$reviewStart)
if ($reviewStart -lt 0 -or $reviewEnd -lt $reviewStart -or -not $reviewMigration.Contains($reviewSchema.Substring($reviewStart,$reviewEnd+3-$reviewStart))) { throw 'Migration and reference table differ.' }
foreach ($reviewToken in @('ReviewSequence bigint IDENTITY(1,1)', 'PayloadHash binary(32)', 'CK_SourceAdminReview_State', 'CK_SourceAdminReview_Time', 'CK_SourceAdminReview_Payload', 'IX_SourceAdminReview_Owner')) {
    if (-not $reviewMigration.Contains($reviewToken)) { throw "Missing review contract: $reviewToken" }
}
foreach ($reviewHeader in @('RequiresBackup: Yes','DataChange: No','TransactionMode: Auto','CreatedUtc: 2026-09-13')) {
    if (-not $reviewMigration.Contains($reviewHeader)) { throw "Missing migration header: $reviewHeader" }
}
$reviewExecutable = ($reviewMigration -replace '(?s)/\*.*?\*/','') -replace '(?m)--[^\n]*',''
if ($reviewExecutable -match '(?i)\b(DROP|DELETE|TRUNCATE|GRANT|INSERT|UPDATE|MERGE)\b') { throw 'The additive review migration contains a data or permission mutation.' }
if ($reviewFixture -notmatch 'K98\[_\]S8C\[_\]Disposable' -or $reviewFixture -notmatch 'ROLLBACK TRANSACTION' -or $reviewFixture -notmatch 'Synthetic rows survived rollback') { throw 'Disposable fixture scope/rollback guard missing.' }
Write-Output 'S8C static review contracts passed (13 checks); no SQL executed.'
