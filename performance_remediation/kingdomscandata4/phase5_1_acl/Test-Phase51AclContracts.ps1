[CmdletBinding()]
param(
    [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).ProviderPath
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

function Read-RequiredFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $path = Join-Path $RepoPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing required file: $RelativePath")
        return ''
    }
    return [IO.File]::ReadAllText($path)
}

function Require-Match {
    param([string]$Text, [string]$Pattern, [string]$Message)

    if ($Text -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

function Require-Order {
    param([string]$Text, [string]$First, [string]$Second, [string]$Message)

    $firstIndex = $Text.IndexOf($First, [StringComparison]::Ordinal)
    $secondIndex = $Text.IndexOf($Second, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
        $failures.Add($Message)
    }
}

$migration = Read-RequiredFile 'migrations\20260816_001_phase5_1_claim_acl_hardening.sql'
$rollback = Read-RequiredFile 'migrations\rollback\20260816_001_phase5_1_claim_acl_hardening_rollback.sql'
$table = Read-RequiredFile 'sql_schema\dbo.KS4_ImportFileClaim.Table.sql'
$claim = Read-RequiredFile 'sql_schema\dbo.CLAIM_KS4_IMPORT_FILE.StoredProcedure.sql'
$preflight = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5_1_acl\01_preflight.sql'
$verify = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5_1_acl\02_verify.sql'
$protocol = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\immutable_file_protocol.md'

Require-Match $migration 'MigrationId:\s*20260816_001_phase5_1_claim_acl_hardening' 'ACL migration ID is missing or incorrect.'
Require-Match $migration 'Rollback:\s*Included' 'ACL migration must include the guarded early rollback.'
Require-Match $migration '(?s)ADD AclHardenedAtUtc datetime2\(3\) NULL,\s*AclOwnerIdentity nvarchar\(256\) NULL;\s*GO\s*ALTER TABLE dbo\.KS4_ImportFileClaim WITH CHECK\s*ADD CONSTRAINT CK_KS4_ImportFileClaim_AclEvidence' 'ACL migration must separate the column add from the evidence constraint with a batch boundary.'
Require-Match $rollback 'RollbackForMigrationId:\s*20260816_001_phase5_1_claim_acl_hardening' 'ACL rollback targets the wrong migration.'
Require-Match $rollback 'AclHardenedAtUtc IS NOT NULL' 'ACL rollback must refuse after the hardened contract was used.'
Require-Match $table 'AclHardenedAtUtc' 'Claim table source is missing the ACL timestamp.'
Require-Match $table 'AclOwnerIdentity' 'Claim table source is missing the ACL owner identity.'
Require-Match $table 'CK_KS4_ImportFileClaim_AclEvidence' 'Claim table source is missing paired ACL evidence validation.'
Require-Match $claim "xp_cmdshell N'WHOAMI'" 'Claim procedure must resolve the real xp_cmdshell identity.'
Require-Match $claim '\%\[\^0-9A-Za-z \._\\\$-\]\%' 'Claim procedure must allowlist the resolved OS identity before shell use.'
Require-Match $claim '/RESET /Q' 'Claim procedure must reset the moved file to the Claimed ACL.'
Require-Match $claim '/SETOWNER "' 'Claim procedure must transfer file ownership to the SQL identity.'
Require-Match $claim '/VERIFY /Q' 'Claim procedure must verify the resulting DACL.'
Require-Order $claim 'MOVE "' '/SETOWNER "' 'Claim procedure must move before transferring ownership.'
Require-Order $claim '/SETOWNER "' '/RESET /Q' 'Claim procedure must transfer ownership before the final DACL reset.'
Require-Order $claim '/RESET /Q' '/VERIFY /Q' 'Claim procedure must reset the DACL before ACL verification.'
Require-Order $claim '/VERIFY /Q' 'EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE' 'Claim procedure must finish ACL hardening before hashing.'
Require-Match $claim 'AclHardenedAtUtc = COALESCE\(AclHardenedAtUtc, @AclHardenedAtUtc\)' 'Claim procedure must preserve the first hardening timestamp.'
Require-Match $claim 'AclOwnerIdentity = COALESCE\(AclOwnerIdentity, @AclOwnerIdentity\)' 'Claim procedure must preserve the first hardened owner.'
Require-Match $preflight 'ClaimStatus NOT IN \(N''archived'', N''duplicate_archived''\)' 'ACL preflight must refuse nonterminal claims.'
Require-Match $verify 'is_not_trusted = 0' 'ACL verification must require a trusted evidence constraint.'
Require-Match $protocol 'transfers file ownership to the xp_cmdshell identity' 'Immutable protocol does not document the owner transition.'
Require-Match $protocol 'final reset of\s+that exact file to the inherited Claimed-directory DACL' 'Immutable protocol does not document the final runtime DACL transition.'

if ($failures.Count -ne 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    throw "Phase 5.1 ACL static contract validation failed with $($failures.Count) issue(s)."
}

Write-Host 'Phase 5.1 ACL static contract validation passed.'
