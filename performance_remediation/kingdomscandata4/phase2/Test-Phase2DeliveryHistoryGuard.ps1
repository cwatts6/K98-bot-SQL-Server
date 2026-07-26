[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\..')
)
$rollbackPath = Join-Path $repoRoot `
    'migrations\rollback\20260725_001_kingdomscandata4_shadow_type_remediation_rollback.sql'
$deployPath = Join-Path $repoRoot 'deploy\Deploy-SqlMigration.ps1'
$historySchemaPath = Join-Path $repoRoot 'sql_schema\dbo.SchemaMigrationHistory.Table.sql'
$phase2ReadmePath = Join-Path $PSScriptRoot 'README.md'
$runtimeRehearsalPath = Join-Path $PSScriptRoot `
    '07_test_migration_history_retryability.sql'

$rollback = Get-Content -Raw -LiteralPath $rollbackPath
$deploy = Get-Content -Raw -LiteralPath $deployPath
$historySchema = Get-Content -Raw -LiteralPath $historySchemaPath
$phase2Readme = Get-Content -Raw -LiteralPath $phase2ReadmePath
$runtimeRehearsal = Get-Content -Raw -LiteralPath $runtimeRehearsalPath

$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Matches {
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        [Parameter(Mandatory)]
        [string]$Pattern,
        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

Assert-Matches -Text $rollback `
    -Pattern "MigrationId\s*=\s*N'20260725_001_kingdomscandata4_shadow_type_remediation'" `
    -Message 'Rollback does not target the exact Phase 2 migration-history row.'
Assert-Matches -Text $rollback `
    -Pattern "SET\s+Status\s*=\s*N'Pending'" `
    -Message 'Rollback does not reset the applied migration to Pending.'
Assert-Matches -Text $rollback `
    -Pattern "AND\s+Status\s*=\s*N'Applied'" `
    -Message 'Rollback does not restrict the history reset to an Applied row.'
Assert-Matches -Text $rollback `
    -Pattern 'WITH\s*\(UPDLOCK,\s*HOLDLOCK\)' `
    -Message 'Rollback history reconciliation is not locked with the rollback transaction.'
Assert-Matches -Text $deploy `
    -Pattern "Status\s*=\s*N'Applied'" `
    -Message 'Deployment runner no longer uses Applied as its completed-migration state.'
Assert-Matches -Text $historySchema `
    -Pattern "\[Status\]\s*=\s*N'Pending'" `
    -Message 'SchemaMigrationHistory does not permit the retryable Pending state.'
Assert-Matches -Text $phase2Readme `
    -Pattern 'migration-history retryability' `
    -Message 'Phase 2 README does not document migration-history retryability.'
Assert-Matches -Text $runtimeRehearsal `
    -Pattern "DB_NAME\(\)\s*=\s*N'ROK_TRACKER'" `
    -Message 'Runtime retryability rehearsal does not forbid production.'
Assert-Matches -Text $runtimeRehearsal `
    -Pattern 'BEGIN\s+TRANSACTION' `
    -Message 'Runtime retryability rehearsal is not transactional.'
Assert-Matches -Text $runtimeRehearsal `
    -Pattern 'ROLLBACK\s+TRANSACTION' `
    -Message 'Runtime retryability rehearsal does not roll back its test mutation.'
Assert-Matches -Text $runtimeRehearsal `
    -Pattern 'PASS_BEFORE_ROLLBACK' `
    -Message 'Runtime retryability rehearsal does not emit the pre-rollback PASS receipt.'
Assert-Matches -Text $runtimeRehearsal `
    -Pattern "N'PASS'\s+AS\s+Result" `
    -Message 'Runtime retryability rehearsal does not emit the cleanup PASS receipt.'

$moduleVerificationOffset = $rollback.IndexOf(
    "THROW 51633, 'Post-rollback module metadata differs from the captured contract.'",
    [System.StringComparison]::Ordinal
)
$historyUpdateOffset = $rollback.IndexOf(
    'UPDATE dbo.SchemaMigrationHistory WITH (UPDLOCK, HOLDLOCK)',
    [System.StringComparison]::Ordinal
)
$commitOffset = if ($historyUpdateOffset -ge 0) {
    $rollback.IndexOf(
        'COMMIT TRANSACTION;',
        $historyUpdateOffset,
        [System.StringComparison]::Ordinal
    )
}
else {
    -1
}

if (
    $moduleVerificationOffset -lt 0 -or
    $historyUpdateOffset -le $moduleVerificationOffset -or
    $commitOffset -le $historyUpdateOffset
) {
    $failures.Add(
        'Migration-history reconciliation must occur after module verification and before rollback commit.'
    )
}

if ($failures.Count -gt 0) {
    throw (
        "Phase 2 delivery-history guard validation failed:`n - " +
        ($failures -join "`n - ")
    )
}

Write-Host (
    'PASS: Phase 2 early rollback resets only the exact Applied migration ' +
    'to the supported Pending state before commit, preserving retryability.'
)
