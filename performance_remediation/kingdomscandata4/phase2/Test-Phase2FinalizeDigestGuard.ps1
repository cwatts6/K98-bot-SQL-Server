[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptPath = Join-Path $PSScriptRoot '03_finalize.sql'
$source = Get-Content -Raw -LiteralPath $scriptPath

function Assert-Contains {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($source -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-Before {
    param(
        [Parameter(Mandatory)]
        [string]$Earlier,

        [Parameter(Mandatory)]
        [string]$Later,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $earlierIndex = $source.IndexOf($Earlier, [StringComparison]::Ordinal)
    $laterIndex = $source.IndexOf($Later, [StringComparison]::Ordinal)

    if ($earlierIndex -lt 0 -or $laterIndex -lt 0 -or $earlierIndex -ge $laterIndex) {
        throw $Message
    }
}

Assert-Contains `
    -Pattern 'DECLARE\s+@ConfirmRunId\s+uniqueidentifier\s*=\s*NULL' `
    -Message 'The exact-run confirmation must default to refusal.'
Assert-Contains `
    -Pattern 'DECLARE\s+@ConfirmIrreversibleFinalize\s+bit\s*=\s*0' `
    -Message 'The irreversible-finalize confirmation must default to refusal.'
Assert-Contains `
    -Pattern 'KS4_Phase2_PreflightState\s+WITH\s*\(UPDLOCK,\s*HOLDLOCK\)' `
    -Message 'The accepted verification receipt must be locked through finalization.'

$lockedTables = @(
    'dbo.IMPORT_STAGING',
    'dbo.KingdomScanData5',
    'dbo.KingdomScanData4',
    'dbo.IMPORT_STAGING_Phase2_Old',
    'dbo.KingdomScanData5_Phase2_Old',
    'dbo.KingdomScanData4_Phase2_Old'
)

foreach ($tableName in $lockedTables) {
    $escapedTableName = [regex]::Escape($tableName)
    Assert-Contains `
        -Pattern "FROM\s+$escapedTableName\s+WITH\s*\(TABLOCKX,\s*HOLDLOCK\)" `
        -Message "$tableName must be held under an exclusive transaction lock."
}

$digestBindings = @(
    "N'KingdomScanData4',\s*'CURRENT',\s*@ExpectedKs4Rows,\s*@ForwardKs4Digest",
    "N'KingdomScanData5',\s*'CURRENT',\s*@ExpectedKs5Rows,\s*@ForwardKs5Digest",
    "N'IMPORT_STAGING',\s*'CURRENT',\s*@ExpectedStagingRows,\s*@ForwardStagingDigest",
    "N'KingdomScanData4_Phase2_Old',\s*'RETAINED',\s*@ExpectedKs4Rows,\s*@BaselineKs4Digest",
    "N'KingdomScanData5_Phase2_Old',\s*'RETAINED',\s*@ExpectedKs5Rows,\s*@BaselineKs5Digest",
    "N'IMPORT_STAGING_Phase2_Old',\s*'RETAINED',\s*@ExpectedStagingRows,\s*@BaselineStagingDigest"
)

foreach ($binding in $digestBindings) {
    Assert-Contains `
        -Pattern $binding `
        -Message "Missing exact finalization digest binding: $binding"
}

Assert-Contains `
    -Pattern "HASHBYTES\(''SHA2_256''" `
    -Message 'Finalization must recompute normalized SHA-256 digests.'
Assert-Contains `
    -Pattern '@DigestRows\s*<>\s*@ExpectedRows[\s\S]*@Digest\s*<>\s*@ExpectedDigest' `
    -Message 'Finalization must reject row-count or digest drift.'
Assert-Contains `
    -Pattern "THROW\s+51674,\s*'Finalization digest guard failed;" `
    -Message 'Finalization must expose a deterministic stale-state failure.'
Assert-Contains `
    -Pattern "THROW\s+51675,\s*'A conflicting user session connected during finalization verification\.'" `
    -Message 'Finalization must recheck connected sessions after the digest pass.'
Assert-Contains `
    -Pattern "Direction,\s*StepName[\s\S]*'FINALIZE',\s*N'pre_finalize_digest_guard'" `
    -Message 'Finalization must retain a digest-guard migration receipt.'
Assert-Contains `
    -Pattern "KS4_Phase2_IndexInventory\s+WITH\s*\(HOLDLOCK\)[\s\S]*ObjectName\s*=\s*N'KingdomScanData5'[\s\S]*IsPrimaryKey\s*=\s*1" `
    -Message 'Finalization must lock and reuse the exact KS5 primary-key name captured by preflight.'
Assert-Contains `
    -Pattern "sys\.key_constraints[\s\S]*parent_object_id\s*=\s*OBJECT_ID\(N'dbo\.KingdomScanData5',\s*N'U'\)[\s\S]*name\s*=\s*@ExpectedKs5PrimaryKeyName" `
    -Message 'Finalization must verify the captured KS5 primary-key name on the canonical table.'

if ($source -match "sp_rename[\s\r\n]+N'dbo\.PK_KingdomScanData5_Phase2_New'") {
    throw 'Finalization must not rename the KS5 primary key a second time.'
}

Assert-Before `
    -Earlier 'BEGIN TRANSACTION;' `
    -Later 'FROM dbo.IMPORT_STAGING WITH (TABLOCKX, HOLDLOCK);' `
    -Message 'Exclusive table locks must be transaction-owned.'
Assert-Before `
    -Earlier "THROW 51674, 'Finalization digest guard failed;" `
    -Later 'DROP TABLE dbo.IMPORT_STAGING_Phase2_Old;' `
    -Message 'The stale-state guard must run before retained originals are dropped.'
Assert-Before `
    -Earlier "THROW 51675, 'A conflicting user session connected during finalization verification.'" `
    -Later 'DROP TABLE dbo.IMPORT_STAGING_Phase2_Old;' `
    -Message 'The post-digest session check must run before retained originals are dropped.'
Assert-Before `
    -Earlier 'DROP TABLE dbo.KingdomScanData4_Phase2_Old;' `
    -Later "Status = 'FINALIZED'" `
    -Message 'The durable state must not become FINALIZED before cleanup succeeds.'

if ($source -match '(?im)^\s*DROP\s+DATABASE\b') {
    throw 'The finalizer must not drop any database or retained snapshot.'
}

[pscustomobject]@{
    Test = 'Phase2FinalizeDigestGuard'
    ScriptRevision = '20260726.1'
    LockedTableCount = $lockedTables.Count
    DigestBindingCount = $digestBindings.Count
    Result = 'PASS'
}
