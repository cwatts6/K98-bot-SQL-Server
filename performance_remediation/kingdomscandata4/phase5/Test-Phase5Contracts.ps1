[CmdletBinding()]
param(
    [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).ProviderPath
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

function Read-RequiredFile {
    param([string]$RelativePath)

    $path = Join-Path $RepoPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing required file: $RelativePath")
        return ''
    }

    return [IO.File]::ReadAllText($path)
}

function Require-Match {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

function Require-Order {
    param(
        [string]$Text,
        [string]$First,
        [string]$Second,
        [string]$Message
    )

    $firstIndex = $Text.IndexOf($First, [StringComparison]::Ordinal)
    $secondIndex = $Text.IndexOf($Second, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
        $failures.Add($Message)
    }
}

$migration = Read-RequiredFile 'migrations\20260728_001_phase5_immutable_import_file_handoff.sql'
$rollback = Read-RequiredFile 'migrations\rollback\20260728_001_phase5_immutable_import_file_handoff_rollback.sql'
$claimTable = Read-RequiredFile 'sql_schema\dbo.KS4_ImportFileClaim.Table.sql'
$claimProc = Read-RequiredFile 'sql_schema\dbo.CLAIM_KS4_IMPORT_FILE.StoredProcedure.sql'
$hashProc = Read-RequiredFile 'sql_schema\dbo.HASH_KS4_IMPORT_ARCHIVE_FILE.StoredProcedure.sql'
$archiveProc = Read-RequiredFile 'sql_schema\dbo.ARCHIVE_IMPORT_STAGING_FILE.StoredProcedure.sql'
$coreProc = Read-RequiredFile 'sql_schema\dbo.IMPORT_STAGING_PROC_CORE.StoredProcedure.sql'
$publicProc = Read-RequiredFile 'sql_schema\dbo.IMPORT_STAGING_PROC.StoredProcedure.sql'
$updateAll = Read-RequiredFile 'sql_schema\dbo.UPDATE_ALL.StoredProcedure.sql'
$updateAll2 = Read-RequiredFile 'sql_schema\dbo.UPDATE_ALL2.StoredProcedure.sql'
$protocol = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\immutable_file_protocol.md'
$preflight = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\01_preflight.sql'
$verify = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\02_verify.sql'
$override = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\03_apply_test_path_override.sql'
$smokes = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\04_run_protocol_smokes.sql'
$initializer = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\Initialize-Phase5RehearsalFile.ps1'
$runner = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\Invoke-Phase5Rehearsal.ps1'
$reset = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\Reset-Phase5FailedRehearsal.ps1'
$fixture = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\fixtures\valid_minimal.csv'
$recoveryFixture = Read-RequiredFile 'performance_remediation\kingdomscandata4\phase5\fixtures\valid_recovery.csv'

Require-Match $migration 'MigrationId:\s*20260728_001_phase5_immutable_import_file_handoff' `
    'The Phase 5.0 migration ID is missing or incorrect.'
Require-Match $migration 'Rollback:\s*Included' `
    'The Phase 5.0 migration must declare its reviewed rollback.'
Require-Match $migration 'TransactionMode:\s*Required' `
    'The Phase 5.0 migration must require one deployment connection and transaction.'
Require-Match $rollback 'RollbackForMigrationId:\s*20260728_001_phase5_immutable_import_file_handoff' `
    'The Phase 5.0 rollback does not target the exact migration.'
Require-Match $rollback "NOT LIKE N'%C:\\discord_file_downloader\\downloads\\stats\.csv%'" `
    'The rollback mutable-path guard must remain transformable with the full canonical root.'
Require-Match $migration "NOT LIKE N'%C:\\discord_file_downloader\\downloads\\stats\.csv%'" `
    'The forward mutable-path guard must remain transformable with the full canonical root.'
Require-Match $migration 'COMMIT TRANSACTION;' `
    'The Phase 5.0 migration must commit only after post-definition validation.'
Require-Match $migration 'DECLARE @HasUnreconciledRetainedClaimEvidence bit = 0;' `
    'The Phase 5.0 migration must defer compilation of its optional retained-claim query.'
Require-Match $migration 'EXEC sys\.sp_executesql[\s\S]*@HasUnreconciled = @HasUnreconciledRetainedClaimEvidence OUTPUT' `
    'The Phase 5.0 migration must query retained claim rows only after the optional table exists.'
Require-Match $migration 'SET @ImportError = @PersistedError[\s\S]*IF @EntryTranCount = 0' `
    'The Phase 5.0 migration must return nested errors and persist locally owned failures only after rollback.'
$migrationFirstBatch = ($migration -split '(?m)^\s*GO\s*$')[0]
$migrationFirstBatchWithoutStrings = [regex]::Replace(
    $migrationFirstBatch,
    "N?'(?:''|[^'])*'",
    "''",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if ($migrationFirstBatchWithoutStrings -match '(?im)\bFROM\s+(?:\[dbo\]\.|dbo\.)?\[?KS4_ImportFileClaim\]?') {
    $failures.Add(
        'The first migration batch must not statically query the optional Phase 5 claim table before creating it.'
    )
}
Require-Match $rollback 'ClaimStatus NOT IN \(N''archived'', N''duplicate_archived''\)' `
    'The Phase 5.0 rollback must refuse an in-flight claim.'

foreach ($sourcePath in @(
    'sql_schema\dbo.KS4_ImportFileClaim.Table.sql',
    'sql_schema\dbo.HASH_KS4_IMPORT_ARCHIVE_FILE.StoredProcedure.sql',
    'sql_schema\dbo.ARCHIVE_IMPORT_STAGING_FILE.StoredProcedure.sql',
    'sql_schema\dbo.CLAIM_KS4_IMPORT_FILE.StoredProcedure.sql',
    'sql_schema\dbo.IMPORT_STAGING_PROC_CORE.StoredProcedure.sql',
    'sql_schema\dbo.IMPORT_STAGING_PROC.StoredProcedure.sql',
    'sql_schema\dbo.UPDATE_ALL.StoredProcedure.sql',
    'sql_schema\dbo.UPDATE_ALL2.StoredProcedure.sql'
)) {
    if (-not $migration.Contains("-- Source: $sourcePath")) {
        $failures.Add("The migration is missing canonical source marker: $sourcePath")
    }
}

Require-Match $claimTable 'CK_KS4_ImportFileClaim_Status' `
    'The claim ledger is missing its state constraint.'
Require-Match $claimTable "N'duplicate_archived'" `
    'The claim ledger is missing deterministic duplicate archival state.'
Require-Match $claimProc 'DATALENGTH\(@CompletedFileName\) <> 96' `
    'The claim procedure must enforce the fixed 48-character completed name.'
Require-Match $claimProc 'stats_<32 lowercase hex>\.ready\.csv' `
    'The claim procedure is missing its actionable filename error.'
Require-Match $claimProc '\%\[\^0-9a-f\]\%' `
    'The claim procedure must reject uppercase completed-file identities.'
Require-Match $hashProc '\%\[\^0-9a-f\]\%' `
    'The hash helper must reject uppercase completed-file identities.'
Require-Order $claimProc 'Import_Ready' 'Import_Claimed' `
    'The claim procedure must derive ready identity before claimed identity.'
Require-Match $claimProc 'MOVE "' `
    'The claim procedure is missing the ready-to-claimed move.'
Require-Match $claimProc 'ClaimStatus = CASE WHEN @Duplicate = 1' `
    'The claim procedure is missing durable duplicate classification.'
Require-Match $claimProc "N'claimed', N'archived', N'duplicate_archived'" `
    "A losing concurrent claimant can still downgrade another session's valid claimed state."

if (($coreProc -split 'HASH_KS4_IMPORT_ARCHIVE_FILE').Count -lt 3) {
    $failures.Add('The import core must hash both before and after BULK INSERT.')
}
Require-Order $coreProc 'HASH_KS4_IMPORT_ARCHIVE_FILE' 'BULK INSERT dbo.IMPORT_STAGING_CSV_RAW' `
    'The import core must hash the claimed file before BULK INSERT.'
Require-Match $coreProc 'detected claimed-file mutation across BULK INSERT' `
    'The import core is missing the post-bulk digest guard.'
Require-Match $coreProc '@ImportError \[nvarchar\]\(2000\) = NULL OUTPUT' `
    'The import core must return exact nested error detail to transaction-owning callers.'
Require-Match $coreProc 'SET @ImportError = @PersistedError[\s\S]*IF @EntryTranCount = 0' `
    'The import core must not write nested errors inside a caller-owned transaction.'
Require-Match $coreProc "ClaimStatus = N'imported'" `
    'The import core must commit the imported claim with the receipt.'

if (($archiveProc -split 'HASH_KS4_IMPORT_ARCHIVE_FILE').Count -lt 4) {
    $failures.Add('The archive procedure must hash source, destination, and reconciliation paths.')
}
Require-Match $archiveProc 'archive destination rehash changed' `
    'The archive procedure is missing its post-move destination rehash.'
Require-Match $archiveProc "N'duplicate_archived'" `
    'The archive procedure is missing duplicate archival convergence.'

foreach ($entryPoint in @($publicProc, $updateAll, $updateAll2)) {
    Require-Match $entryPoint '@CompletedFileName' `
        'A public import entry point is missing @CompletedFileName.'
    Require-Order $entryPoint 'CLAIM_KS4_IMPORT_FILE' 'IMPORT_STAGING_PROC_CORE' `
        'A public import entry point does not claim before importing.'
}

foreach ($authoritativeEntryPoint in @($updateAll, $updateAll2)) {
    if ($authoritativeEntryPoint -match '@CompletedFileName \[nvarchar\]\(260\)\s*=\s*NULL') {
        $failures.Add('An authoritative update entry point still makes @CompletedFileName optional.')
    }
    Require-Match $authoritativeEntryPoint '@ImportError = @ImportError OUTPUT' `
        'An authoritative update entry point does not receive the exact nested import error.'
    Require-Match $authoritativeEntryPoint 'ROLLBACK;[\s\S]*SET LastError = @(?:OuterPersistedError|PersistedImportError)' `
        'An authoritative update entry point must persist the import error only after its outer rollback.'
}

Require-Match $initializer '\^stats_\[0-9a-f\]\{32\}\\\.ready\\\.csv\$' `
    'The rehearsal publisher must enforce lowercase completed-file identities.'

foreach ($consumer in @($claimProc, $hashProc, $archiveProc, $coreProc)) {
    if ($consumer -match [regex]::Escape('C:\discord_file_downloader\downloads\stats.csv')) {
        $failures.Add('The Phase 5.0 immutable SQL consumer still contains the reusable stats.csv path.')
    }
}

Require-Match $migration 'DENY EXECUTE ON OBJECT::dbo\.CLAIM_KS4_IMPORT_FILE TO public' `
    'The migration must deny direct public claim execution.'
Require-Match $migration 'DENY SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo\.KS4_ImportFileClaim TO public' `
    'The migration must deny direct public claim-ledger mutation.'
Require-Match $preflight 'Import_Ready' 'The Phase 5.0 preflight is missing the ready-directory gate.'
Require-Match $verify 'claimed-file mutation across BULK INSERT' `
    'The Phase 5.0 verification is missing immutable guards.'
Require-Match $override 'refuses production ROK_TRACKER' 'The test-path override must refuse production.'
Require-Match $override 'ELSE IF @Definition NOT LIKE N''%'' \+ @TestRoot' `
    'The test-path override must accept only canonical or already test-bound definitions.'
Require-Match $override "LEFT\(@Definition, LEN\(N'CREATE PROCEDURE'\)\) = N'CREATE PROCEDURE'[\s\S]*STUFF\([\s\S]*N'ALTER PROCEDURE'" `
    'The test-path override must normalize a retrieved CREATE PROCEDURE before reapplying it.'
Require-Match $override "THROW 52393, 'Phase 5\.0 test-path override found an unexpected module declaration\.'" `
    'The test-path override must reject an unexpected dynamic module declaration.'
Require-Match $smokes 'duplicate_archived' 'The protocol smokes are missing duplicate convergence.'
Require-Match $smokes 'controlled archive failure' 'The protocol smokes are missing recovery coverage.'
Require-Match $smokes 'SELECT LastError[\s\S]*WHERE CompletedFileName = @FirstName' `
    'The protocol smokes must surface a persisted normal-import error.'
Require-Match $initializer 'Move-Item -LiteralPath \$temporaryPath -Destination \$readyPath' `
    'The rehearsal initializer must publish by same-directory rename.'
Require-Match $runner "ValidateSet\('ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'\)" `
    'The rehearsal runner must remain pinned to the approved isolated database.'
Require-Match $runner "expectedComputerName = 'MINI_AMD'" `
    'The rehearsal runner must refuse execution away from MINI_AMD.'
Require-Match $runner 'ConfirmIsolatedTarget' `
    'The rehearsal runner must require explicit isolated-target confirmation.'
Require-Match $runner 'ConfirmWritersStopped' `
    'The rehearsal runner must require explicit stopped-writer confirmation.'
Require-Match $runner 'OtherUserSessions -ne 0' `
    'The rehearsal runner must refuse an occupied target database.'
Require-Match $runner 'OtherUserSessionDetails = @\(\$otherUserSessionDetails\)' `
    'The rehearsal receipt must identify every session that blocks target isolation.'
Require-Match $runner 'Microsoft\.Data\.SqlClient\.SqlConnection\]::ClearAllPools' `
    'The rehearsal runner must clear its own retained SQL client connections before isolation.'
Require-Match $runner 'runner will not delete evidence' `
    'The rehearsal runner must fail closed instead of deleting stale files.'
Require-Match $runner "ValidateSet\('C:\\discord_file_downloader\\downloads_test_phase5_rehearsal'\)" `
    'The rehearsal runner must pin its filesystem work to the approved test root.'
Require-Match $runner 'function New-TestBoundSqlFile' `
    'The rehearsal runner must materialize isolated SQL copies before deployment.'
Require-Match $runner 'ProductionRootAbsent = -not \$testBoundText\.Contains\(\$productionSqlRoot\)' `
    'The rehearsal receipt must prove derived SQL excludes the production root.'
Require-Match $runner 'DerivedSqlFiles = @\(\$script:derivedSqlEvidence\)' `
    'The rehearsal receipt must retain canonical-to-derived SQL hashes.'
Require-Match $runner '50AACFE4FA943377AA85924E6B2BD45248CEF3CE776DC09C2DA407903529801C' `
    'The runner must pin the exact one-final-LF minimal fixture.'
Require-Match $runner '1F8E655DAC887547138BD0D4F7AE6BE55EB8EF4FB1E6F7D9B57B0D6BB2D7A99E' `
    'The runner must pin the exact one-final-LF recovery fixture.'
Require-Order $runner "'materialize_test_bound_sql'" "'preflight_before_forward'" `
    'The rehearsal runner must bind SQL paths before preflight or migration execution.'
Require-Order $runner "'preflight_before_forward'" "'forward_migration'" `
    'The rehearsal runner must preflight before the forward migration.'
Require-Order $runner "'forward_migration'" "'protocol_smokes'" `
    'The rehearsal runner must apply the migration before protocol smokes.'
Require-Order $runner "'protocol_smokes'" "'rollback'" `
    'The rehearsal runner must finish protocol smokes before rollback.'
Require-Order $runner "'rollback'" "'clean_reapply'" `
    'The rehearsal runner must rollback before its clean reapply.'
Require-Order $runner "'clean_reapply'" "'final_verify'" `
    'The rehearsal runner must verify the clean reapply.'
Require-Match $runner "SchemaVersion = 'phase5-rehearsal/v1'" `
    'The rehearsal runner must emit a versioned machine-readable receipt.'
Require-Match $reset "ValidateSet\('ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'\)" `
    'The failed-attempt reset must remain pinned to the approved isolated database.'
Require-Match $reset 'ConfirmDiscardFailedAttempt' `
    'The failed-attempt reset must require explicit destructive-state confirmation.'
Require-Match $reset '\$failedReceipt\.InputFiles[\s\S]*MinimalFixture[\s\S]*RecoveryFixture' `
    'The failed-attempt reset must bind work-file validation to the failed receipt hashes.'
Require-Match $reset '\$isRollbackResumeState' `
    'The failed-attempt reset must resume safely after a rolled-back definition guard.'
Require-Match $reset 'Microsoft\.Data\.SqlClient\.SqlConnection\]::ClearAllPools' `
    'The failed-attempt reset must release its retained SQL client connections.'
Require-Order $reset 'Move-Item' 'DELETE dbo.KS4_ImportFileClaim' `
    'The failed-attempt reset must quarantine files before deleting the exact test claim.'
Require-Match $reset "SchemaVersion = 'phase5-failed-rehearsal-reset/v1'" `
    'The failed-attempt reset must emit a versioned machine-readable receipt.'
Require-Match $protocol 'must not modify, replace, delete or create files in' `
    'The immutable protocol is missing the claimed-directory ACL boundary.'
Require-Match $protocol 'same local NTFS volume' `
    'The immutable protocol is missing the same-volume rename requirement.'

foreach ($csv in @($fixture, $recoveryFixture)) {
    if (
        -not $csv.EndsWith("`n", [StringComparison]::Ordinal) -or
        ([regex]::Matches($csv, "`n")).Count -ne 2
    ) {
        $failures.Add(
            'Each sanitized Phase 5 fixture must contain exactly two CSV records and one final LF.'
        )
    }

    $lines = @($csv -split "\r?\n" | Where-Object { $_ -ne '' })
    if ($lines.Count -ne 2) {
        $failures.Add('Each sanitized Phase 5 fixture must contain one header and one data row.')
        continue
    }
    if (($lines[0] -split ',').Count -ne 36 -or ($lines[1] -split ',').Count -ne 36) {
        $failures.Add('Each sanitized Phase 5 fixture must preserve the exact 36-column bulk contract.')
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    throw "Phase 5.0 static contract validation failed with $($failures.Count) issue(s)."
}

Write-Host 'Phase 5.0 static contract validation passed.'
