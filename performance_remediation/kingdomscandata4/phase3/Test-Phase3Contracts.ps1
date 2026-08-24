[CmdletBinding()]
param(
    [string] $RepoPath = (
        Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
    ).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failures = New-Object System.Collections.Generic.List[string]

function Get-RepoText {
    param([Parameter(Mandatory = $true)][string] $RelativePath)

    $path = Join-Path $RepoPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing required file: $RelativePath")
        return ''
    }

    return [System.IO.File]::ReadAllText($path)
}

function Assert-Matches {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [Parameter(Mandatory = $true)][string] $Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-NotMatches {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [Parameter(Mandatory = $true)][string] $Message
    )

    if ($Text -match $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-Before {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $First,
        [Parameter(Mandatory = $true)][string] $Second,
        [Parameter(Mandatory = $true)][string] $Message
    )

    $firstIndex = $Text.IndexOf(
        $First,
        [System.StringComparison]::OrdinalIgnoreCase
    )
    $secondIndex = $Text.IndexOf(
        $Second,
        [System.StringComparison]::OrdinalIgnoreCase
    )

    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
        $failures.Add($Message)
    }
}

$migration = Get-RepoText (
    'migrations\20260726_001_phase3_import_concurrency_and_direct_type_alignment.sql'
)
$rollback = Get-RepoText (
    'migrations\rollback\20260726_001_phase3_import_concurrency_and_direct_type_alignment_rollback.sql'
)
$import = Get-RepoText (
    'sql_schema\dbo.IMPORT_STAGING_PROC.StoredProcedure.sql'
)
$importCore = Get-RepoText (
    'sql_schema\dbo.IMPORT_STAGING_PROC_CORE.StoredProcedure.sql'
)
$archive = Get-RepoText (
    'sql_schema\dbo.ARCHIVE_IMPORT_STAGING_FILE.StoredProcedure.sql'
)
$archiveHashHelper = Get-RepoText (
    'sql_schema\dbo.HASH_KS4_IMPORT_ARCHIVE_FILE.StoredProcedure.sql'
)
$fixImport = Get-RepoText (
    'sql_schema\dbo.FIX_IMPORT_STAGING.StoredProcedure.sql'
)
$lockHelper = Get-RepoText (
    'sql_schema\dbo.ACQUIRE_KS4_IMPORT_LOCK.StoredProcedure.sql'
)
$updateAll = Get-RepoText (
    'sql_schema\dbo.UPDATE_ALL.StoredProcedure.sql'
)
$updateAll2 = Get-RepoText (
    'sql_schema\dbo.UPDATE_ALL2.StoredProcedure.sql'
)
$createDash = Get-RepoText (
    'sql_schema\dbo.CREATE_DASH.StoredProcedure.sql'
)
$targets = Get-RepoText (
    'sql_schema\dbo.TARGETS.StoredProcedure.sql'
)
$receipt = Get-RepoText (
    'sql_schema\dbo.KS4_ImportFileReceipt.Table.sql'
)
$preflight = Get-RepoText (
    'performance_remediation\kingdomscandata4\phase3\01_preflight.sql'
)
$verify = Get-RepoText (
    'performance_remediation\kingdomscandata4\phase3\02_verify.sql'
)
$archiveReconciliationTest = Get-RepoText (
    'performance_remediation\kingdomscandata4\phase3\23_verify_archive_reconciliation_digest.sql'
)
$ambientTransactionTest = Get-RepoText (
    'performance_remediation\kingdomscandata4\phase3\24_verify_public_entrypoint_ambient_transactions.sql'
)

Assert-Matches $migration `
    'MigrationId:\s*20260726_001_phase3_import_concurrency_and_direct_type_alignment' `
    'The Phase 3 migration ID is missing or incorrect.'
Assert-Matches $migration 'Rollback:\s*Included' `
    'The Phase 3 migration must declare its reviewed rollback.'
Assert-Matches $migration 'TransactionMode:\s*Required' `
    'The Phase 3 migration must require one deployment connection/transaction.'
Assert-Matches $rollback `
    'RollbackForMigrationId:\s*20260726_001_phase3_import_concurrency_and_direct_type_alignment' `
    'The Phase 3 rollback does not target the exact migration.'
Assert-Matches $rollback `
    'IF EXISTS\s*\(\s*SELECT 1 FROM dbo\.KS4_ImportFileReceipt\s*\)' `
    'The Phase 3 rollback must refuse after a committed import receipt exists.'

foreach ($typeContractSource in @($migration, $rollback, $preflight, $verify)) {
    Assert-NotMatches $typeContractSource `
        "SystemTypeId" `
        "Column type checks must use sys.columns; COLUMNPROPERTY does not support SystemTypeId."
    Assert-Matches $typeContractSource `
        'sys\.columns' `
        'Every Phase 3 migration boundary must validate column types through sys.columns.'
    Assert-Matches $typeContractSource `
        'system_type_id\s*=\s*(?:expected\.type_id|TYPE_ID)' `
        'Every Phase 3 migration boundary must validate the exact system type ID.'
}

$mutexPattern = [regex]::Escape(
    'K98:KingdomScanData4:ImportPipeline:v1'
)
$lockHelperPattern = 'EXEC\s+dbo\.ACQUIRE_KS4_IMPORT_LOCK'
Assert-Matches $lockHelper $mutexPattern `
    'The private lock helper must use the shared database mutex.'
Assert-Matches $lockHelper `
    "WITH\s+EXECUTE\s+AS\s+OWNER" `
    'The private lock helper must use its owner context only around lock acquisition.'
Assert-Matches $lockHelper `
    "@DbPrincipal\s*=\s*N'K98ImportLockPrincipal'" `
    'The private lock helper must use the dedicated database principal.'
Assert-Matches $migration `
    'CREATE\s+ROLE\s+K98ImportLockPrincipal\s+AUTHORIZATION\s+dbo' `
    'The Phase 3 migration must create the dedicated import-lock principal.'
Assert-Matches $migration `
    'DENY\s+EXECUTE\s+ON\s+OBJECT::dbo\.ACQUIRE_KS4_IMPORT_LOCK\s+TO\s+public' `
    'The Phase 3 migration must deny direct public execution of the lock helper.'
Assert-Matches $migration `
    'DENY\s+EXECUTE\s+ON\s+OBJECT::dbo\.HASH_KS4_IMPORT_ARCHIVE_FILE\s+TO\s+public' `
    'The Phase 3 migration must deny direct public execution of the archive-hash helper.'
Assert-Matches $migration `
    'DENY\s+EXECUTE\s+ON\s+OBJECT::dbo\.IMPORT_STAGING_PROC_CORE\s+TO\s+public' `
    'The Phase 3 migration must deny direct public execution of the nested import core.'
Assert-Matches $rollback `
    'DROP\s+ROLE\s+K98ImportLockPrincipal' `
    'The Phase 3 rollback must remove the dedicated import-lock principal.'
foreach ($source in @(
    $importCore,
    $archive,
    $updateAll,
    $updateAll2,
    $fixImport
)) {
    Assert-Matches $source $lockHelperPattern `
        'Every authoritative import path must use the private lock helper.'
    Assert-NotMatches $source "@DbPrincipal\s*=\s*N'public'" `
        'No authoritative import path may use the public application-lock namespace.'
}

Assert-Matches $import `
    'IF\s+@@TRANCOUNT\s+<>\s+0' `
    'The public importer must refuse caller-owned transactions.'
Assert-Matches $import `
    'EXEC\s+@ReturnCode\s*=\s*dbo\.IMPORT_STAGING_PROC_CORE' `
    'The public importer must delegate through the private nested core.'
Assert-NotMatches $import $lockHelperPattern `
    'The public importer must not acquire the private mutex outside its owned core transaction.'
Assert-Matches $updateAll `
    'IF\s+@@TRANCOUNT\s+<>\s+0' `
    'UPDATE_ALL must refuse caller-owned transactions.'
Assert-Matches $updateAll2 `
    'IF\s+@@TRANCOUNT\s+<>\s+0' `
    'UPDATE_ALL2 must refuse caller-owned transactions.'
Assert-Matches $fixImport `
    'IF\s+@@TRANCOUNT\s+<>\s+0' `
    'FIX_IMPORT_STAGING must refuse caller-owned transactions.'
Assert-Matches $fixImport `
    'BEGIN\s+TRANSACTION' `
    'FIX_IMPORT_STAGING must own one local transaction after rejecting ambient transactions.'
Assert-NotMatches $fixImport `
    'EntryTranCount|StartedLocalTransaction|SAVE\s+TRANSACTION|SAVEPOINT' `
    'FIX_IMPORT_STAGING must not retain unreachable ambient/savepoint transaction branches.'
Assert-Matches $archive `
    'IF\s+@@TRANCOUNT\s+<>\s+0' `
    'ARCHIVE_IMPORT_STAGING_FILE must refuse caller-owned transactions.'
Assert-Matches $updateAll `
    'dbo\.IMPORT_STAGING_PROC_CORE' `
    'UPDATE_ALL must use the private nested import core.'
Assert-Matches $updateAll2 `
    'dbo\.IMPORT_STAGING_PROC_CORE' `
    'UPDATE_ALL2 must use the private nested import core.'
Assert-Matches $archive `
    'dbo\.HASH_KS4_IMPORT_ARCHIVE_FILE' `
    'Archive reconciliation must hash the exact destination through the private helper.'
Assert-Matches $archive `
    'refused to reconcile an archive destination whose digest differs' `
    'Archive reconciliation must fail closed on destination digest mismatch.'
Assert-Matches $archiveHashHelper `
    "WITH\s+EXECUTE\s+AS\s+CALLER" `
    'The archive-hash helper must retain the wrapper caller security context.'
Assert-Matches $archiveHashHelper `
    "master\.dbo\.xp_cmdshell\s+@HashCommand" `
    'The archive-hash helper must hash the exact archive destination.'
Assert-Matches $archiveHashHelper `
    "(?s)DATALENGTH\(@CompletedFileName\)\s*<>\s*96.+LIKE\s+N'%\[\^0-9a-f\]%'.+@ApprovedPath\s+NOT\s+IN" `
    'The archive-hash helper must enforce the exact completed-name and root allowlist.'
Assert-Before $archiveHashHelper `
    '@ApprovedPath NOT IN' `
    'DECLARE @HashCommand' `
    'The archive-hash helper must validate the exact path before building CMD text.'
Assert-Matches $archiveReconciliationTest `
    'WrongObservedError\s*<>\s*51850' `
    'The archive reconciliation regression must assert the wrong-digest failure.'
Assert-Matches $archiveReconciliationTest `
    "ArchiveStatus\s*=\s*N'archived'" `
    'The archive reconciliation regression must prove the matching-digest success path.'
Assert-Matches $archiveReconciliationTest `
    'QuotedPathError\s*<>\s*51872' `
    'The archive reconciliation regression must assert embedded double-quote rejection.'
foreach ($ambientError in @(51807, 51818, 51828, 51833, 51849)) {
    Assert-Matches $ambientTransactionTest `
        ([regex]::Escape([string] $ambientError)) `
        "The ambient-transaction regression must cover error $ambientError."
}
Assert-NotMatches (
    (Get-RepoText 'performance_remediation\kingdomscandata4\phase3\15_prepare_concurrent_retry_fixture.sql') +
    (Get-RepoText 'performance_remediation\kingdomscandata4\phase3\16_prepare_proven_concurrent_fixture.sql')
) `
    'downloads_test_phase3\\stats\.csv' `
    'Concurrency fixtures must hash the exact downloads_test_phase3_rehearsal active path.'

Assert-Before $importCore `
    'EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE' `
    'TRUNCATE TABLE dbo.IMPORT_STAGING_CSV_RAW' `
    'The source-file digest must be established before staging mutation.'
foreach ($allocatorSource in @(
    'dbo.KingdomScanData4',
    'dbo.KingdomScanData5',
    'dbo.KS4_ImportFileReceipt'
)) {
    $lockedAllocatorSourcePattern =
        'FROM\s+' + [regex]::Escape($allocatorSource) + '\s+WITH\s*\(\s*UPDLOCK\s*,\s*HOLDLOCK\s*\)'
    Assert-Matches $importCore $lockedAllocatorSourcePattern `
        "The direct importer must lock $allocatorSource during atomic scan allocation."
    Assert-Matches (Get-RepoText 'sql_schema\dbo.FIX_IMPORT_STAGING.StoredProcedure.sql') `
        $lockedAllocatorSourcePattern `
        "FIX_IMPORT_STAGING must lock $allocatorSource during atomic scan allocation."
}
Assert-Before $importCore `
    'INSERT dbo.KS4_ImportFileReceipt' `
    'COMMIT TRANSACTION' `
    'The receipt must commit atomically with direct import staging.'
Assert-Before $importCore `
    'COMMIT TRANSACTION' `
    'dbo.ARCHIVE_IMPORT_STAGING_FILE' `
    'A direct import must commit database state before filesystem archival.'
Assert-Before $updateAll `
    'COMMIT;' `
    'dbo.ARCHIVE_IMPORT_STAGING_FILE' `
    'UPDATE_ALL must commit database state before filesystem archival.'
Assert-Before $updateAll2 `
    'COMMIT;  --' `
    'dbo.ARCHIVE_IMPORT_STAGING_FILE' `
    'UPDATE_ALL2 must commit Phase A before filesystem archival.'
Assert-Matches $updateAll `
    '\[Deads\]\s+AS\s+\[Deads_Delta\]' `
    'UPDATE_ALL must recreate EXCEL_FOR_DASHBOARD with the canonical Deads_Delta column.'
Assert-Matches $updateAll `
    '\[Dead Target\]\s+AS\s+\[Dead_Target\]' `
    'UPDATE_ALL must recreate EXCEL_FOR_DASHBOARD with the canonical Dead_Target column.'
Assert-Matches $createDash `
    'AVG\(\[Deads_Delta\]\)' `
    'CREATE_DASH must read the canonical EXCEL_FOR_DASHBOARD Deads_Delta column.'
Assert-Matches $createDash `
    '(?s)\[Deads_Delta\].+\[Dead_Target\]' `
    'CREATE_DASH must write the canonical EXCEL_FOR_DASHBOARD death columns.'
Assert-Matches $targets `
    'INSERT\s+INTO\s+EXCEL_OUTPUT_KVK_TARGETS_JUN25\s*\(\s*\[Rank\]' `
    'TARGETS must use an explicit target column list so nullable schema additions cannot shift values.'
Assert-Before $archive `
    'EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE' `
    'master.dbo.xp_cmdshell' `
    'The archive wrapper must verify the live file digest through the private helper before moving it.'
Assert-Matches $archiveHashHelper `
    "(?s)certutil\s+-hashfile.+SHA256.+TRY_CONVERT\(binary\(32\)" `
    'The private archive-hash helper must calculate and parse SHA-256 through its constrained command.'
Assert-Matches $archiveHashHelper `
    "(?s)@ClaimedRoot.+Import_Claimed.+@ArchiveRoot.+Import_Archive.+@ApprovedPath\s+NOT\s+IN" `
    'The private archive-hash helper must permit only the exact claimed or archive destination.'
Assert-Matches $archiveHashHelper `
    "(?s)SUBSTRING\(@CompletedFileName,\s*7,\s*32\).+LIKE\s+N'%\[\^0-9a-f\]%'" `
    'The private archive-hash helper must reject shell metacharacters through the canonical name allowlist.'
Assert-Matches $archive `
    "(?s)@SourcePath\s*<>.+Import_Claimed.+@ArchivePath\s*<>.+Import_Archive" `
    'The archive helper must bind source and destination to the exact claim roots.'
Assert-Matches $archive `
    'refused claim-path definition drift' `
    'The archive helper must fail closed when its persisted paths are not canonical.'

Assert-Matches $receipt `
    '\[FileDigest\]\s+\[binary\]\(32\)\s+NOT NULL' `
    'The receipt digest must be a required SHA-256 binary value.'
Assert-Matches $receipt `
    'UNIQUE NONCLUSTERED\s*\(\s*\[ScanOrder\]\s*ASC\s*\)' `
    'The receipt table must enforce one receipt per scan order.'
Assert-Matches $receipt `
    "CHECK\s*\(\s*\[ArchiveStatus\]\s+IN\s+\(N'pending',\s*N'archived'\)\s*\)" `
    'The receipt table must constrain archive status.'

$forwardSources = [regex]::Matches(
    $migration,
    '(?m)^-- Source: sql_schema/.+\.StoredProcedure\.sql\r?$'
)
$rollbackSources = [regex]::Matches(
    $rollback,
    '(?m)^-- Rollback source: sql_schema/.+\.StoredProcedure\.sql at '
)

if ($forwardSources.Count -ne 33) {
    $failures.Add(
        "Expected 33 generated Phase 3 procedure definitions; found $($forwardSources.Count)."
    )
}

if ($rollbackSources.Count -ne 30) {
    $failures.Add(
        "Expected 30 generated rollback procedure definitions; found $($rollbackSources.Count)."
    )
}

if ($failures.Count -ne 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    throw "Phase 3 contract validation failed with $($failures.Count) issue(s)."
}

Write-Host 'Phase 3 static contract validation passed.'
Write-Host "Forward procedure definitions: $($forwardSources.Count)"
Write-Host "Rollback procedure definitions: $($rollbackSources.Count)"
