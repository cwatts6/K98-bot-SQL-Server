[CmdletBinding()]
param(
    [ValidateSet('localhost', '.', '(local)')]
    [string]$ServerName = 'localhost',

    [ValidateSet('ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL')]
    [string]$DatabaseName =
        'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL',

    [ValidateSet('C:\discord_file_downloader\downloads_test_phase5_rehearsal')]
    [string]$TestRoot =
        'C:\discord_file_downloader\downloads_test_phase5_rehearsal',

    [Parameter(Mandatory = $true)]
    [switch]$ConfirmDiscardFailedAttempt,

    [Parameter(Mandatory = $true)]
    [switch]$ConfirmWritersStopped
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedComputerName = 'MINI_AMD'
$expectedDatabaseName =
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
$firstName = 'stats_00000000000000000000000000000001.ready.csv'
$duplicateName = 'stats_00000000000000000000000000000002.ready.csv'
$recoveryName = 'stats_00000000000000000000000000000003.ready.csv'
$productionSqlRoot = 'C:\discord_file_downloader\downloads\'

if (-not $ConfirmDiscardFailedAttempt.IsPresent) {
    throw (
        'Pass -ConfirmDiscardFailedAttempt only after accepting removal of the exact ' +
        'failed rehearsal claim. Its files will be quarantined, not deleted.'
    )
}
if (-not $ConfirmWritersStopped.IsPresent) {
    throw 'Pass -ConfirmWritersStopped after confirming import and scheduler writers are stopped.'
}
if ($env:COMPUTERNAME -ine $expectedComputerName) {
    throw "Run this reset locally on $expectedComputerName. Current host: $env:COMPUTERNAME"
}
if ($DatabaseName -cne $expectedDatabaseName) {
    throw "The reset is pinned to $expectedDatabaseName."
}

$repoRoot = (
    Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
).ProviderPath
$sqlCommonPath = Join-Path $repoRoot 'deploy\SqlDeploy.Common.ps1'
$rollbackPath = Join-Path $repoRoot (
    'migrations\rollback\' +
    '20260728_001_phase5_immutable_import_file_handoff_rollback.sql'
)
$minimalFixturePath = Join-Path $PSScriptRoot 'fixtures\valid_minimal.csv'
$recoveryFixturePath = Join-Path $PSScriptRoot 'fixtures\valid_recovery.csv'

foreach ($requiredPath in @(
    $sqlCommonPath,
    $rollbackPath,
    $minimalFixturePath,
    $recoveryFixturePath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing reset input: $requiredPath"
    }
}

. $sqlCommonPath

$resolvedTestRoot = [IO.Path]::GetFullPath($TestRoot).TrimEnd('\')
$readyRoot = Join-Path $resolvedTestRoot 'Import_Ready'
$claimedRoot = Join-Path $resolvedTestRoot 'Import_Claimed'
$archiveRoot = Join-Path $resolvedTestRoot 'Import_Archive'
$evidenceRoot = Join-Path $resolvedTestRoot 'evidence'

foreach ($workRoot in @($readyRoot, $claimedRoot, $archiveRoot, $evidenceRoot)) {
    if (-not (Test-Path -LiteralPath $workRoot -PathType Container)) {
        throw "Missing failed-rehearsal directory: $workRoot"
    }
}

$failedRun = $null
$failedReceipt = $null
foreach (
    $candidate in @(
        Get-ChildItem -LiteralPath $evidenceRoot -Directory |
            Where-Object { $_.Name -like 'phase5_0_*' } |
            Sort-Object LastWriteTimeUtc -Descending
    )
) {
    $candidateReceiptPath = Join-Path $candidate.FullName 'receipt.json'
    if (-not (Test-Path -LiteralPath $candidateReceiptPath -PathType Leaf)) {
        continue
    }

    $candidateReceipt = Get-Content -Raw -LiteralPath $candidateReceiptPath |
        ConvertFrom-Json
    $failedProtocolStep = @(
        $candidateReceipt.Steps |
            Where-Object {
                $_.Name -eq 'protocol_smokes' -and
                $_.Status -eq 'failed'
            }
    )
    if (
        $candidateReceipt.Status -eq 'failed' -and
        $failedProtocolStep.Count -eq 1
    ) {
        $failedRun = $candidate
        $failedReceipt = $candidateReceipt
        break
    }
}

if ($null -eq $failedRun) {
    throw 'Could not find a failed Phase 5.0 protocol-smoke receipt to quarantine against.'
}

$minimalReceiptInputs = @(
    $failedReceipt.InputFiles |
        Where-Object { $_.Name -eq 'MinimalFixture' }
)
$recoveryReceiptInputs = @(
    $failedReceipt.InputFiles |
        Where-Object { $_.Name -eq 'RecoveryFixture' }
)
if (
    $minimalReceiptInputs.Count -ne 1 -or
    $recoveryReceiptInputs.Count -ne 1 -or
    $minimalReceiptInputs[0].Sha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
    $recoveryReceiptInputs[0].Sha256 -notmatch '^[0-9A-Fa-f]{64}$'
) {
    throw 'The failed receipt does not contain one exact hash for each staged fixture.'
}

$expectedPaths = @(
    (Join-Path $claimedRoot $firstName),
    (Join-Path $readyRoot $duplicateName),
    (Join-Path $readyRoot $recoveryName)
)
$quarantineRoot = Join-Path $failedRun.FullName 'failed_work_files'
$quarantineReady = Join-Path $quarantineRoot 'Import_Ready'
$quarantineClaimed = Join-Path $quarantineRoot 'Import_Claimed'
$quarantinePaths = @(
    (Join-Path $quarantineClaimed $firstName),
    (Join-Path $quarantineReady $duplicateName),
    (Join-Path $quarantineReady $recoveryName)
)
$actualWorkFiles = @(
    foreach ($workRoot in @($readyRoot, $claimedRoot, $archiveRoot)) {
        Get-ChildItem -LiteralPath $workRoot -File -Recurse
    }
)
$quarantinedFixtureFiles = @(
    foreach ($quarantineDirectory in @($quarantineReady, $quarantineClaimed)) {
        if (Test-Path -LiteralPath $quarantineDirectory -PathType Container) {
            Get-ChildItem -LiteralPath $quarantineDirectory -File -Recurse
        }
    }
)
$isInitialState =
    $actualWorkFiles.Count -eq 3 -and
    -not (Compare-Object $expectedPaths @($actualWorkFiles.FullName)) -and
    $quarantinedFixtureFiles.Count -eq 0
$isRollbackResumeState =
    $actualWorkFiles.Count -eq 0 -and
    $quarantinedFixtureFiles.Count -eq 3 -and
    -not (Compare-Object $quarantinePaths @($quarantinedFixtureFiles.FullName))

if (-not $isInitialState -and -not $isRollbackResumeState) {
    throw (
        'Neither the initial failed attempt nor the exact quarantined rollback-resume ' +
        'filesystem state was found; ' +
        'no recovery action was taken.'
    )
}

$validationPaths = if ($isInitialState) {
    $expectedPaths
}
else {
    $quarantinePaths
}
$actualHashes = @(
    (Get-FileHash -LiteralPath $validationPaths[0] -Algorithm SHA256).Hash,
    (Get-FileHash -LiteralPath $validationPaths[1] -Algorithm SHA256).Hash,
    (Get-FileHash -LiteralPath $validationPaths[2] -Algorithm SHA256).Hash
)
$expectedHashes = @(
    [string]$minimalReceiptInputs[0].Sha256,
    [string]$minimalReceiptInputs[0].Sha256,
    [string]$recoveryReceiptInputs[0].Sha256
)

$hashMismatch = $false
for ($index = 0; $index -lt $expectedHashes.Count; $index++) {
    if ($actualHashes[$index] -ine $expectedHashes[$index]) {
        $hashMismatch = $true
    }
}

if ($hashMismatch) {
    throw (
        'At least one failed-attempt file differs from the exact failed-receipt fixture hash; ' +
        'no recovery action was taken.'
    )
}

$targetRows = @(
    Invoke-K98SqlQuery `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -Query @"
SELECT
    DB_NAME() AS DatabaseName,
    CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')) AS MachineName,
    (
        SELECT COUNT_BIG(*)
        FROM dbo.KS4_ImportFileClaim
    ) AS ClaimRows,
    (
        SELECT COUNT_BIG(*)
        FROM dbo.KS4_ImportFileReceipt
    ) AS ReceiptRows,
    (
        SELECT COUNT_BIG(*)
        FROM dbo.KS4_ImportFileClaim
        WHERE CompletedFileName = N'$firstName'
          AND ClaimStatus = N'claimed'
          AND ClaimedPath = N'$claimedRoot\$firstName'
          AND ReadyPath = N'$readyRoot\$firstName'
          AND ArchivePath = N'$archiveRoot\$firstName'
    ) AS ExactFailedClaimRows,
    CASE
        WHEN OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NOT NULL THEN 1
        ELSE 0
    END AS ClaimProcedurePresent;
"@ `
        -QueryTimeout 120
)

if (
    $targetRows.Count -ne 1 -or
    $targetRows[0].DatabaseName -cne $expectedDatabaseName -or
    $targetRows[0].MachineName -ine $expectedComputerName -or
    [long]$targetRows[0].ReceiptRows -ne 0 -or
    [int]$targetRows[0].ClaimProcedurePresent -ne 1
) {
    throw 'The database is not in the exact recoverable failed-attempt state.'
}
if (
    $isInitialState -and
    (
        [long]$targetRows[0].ClaimRows -ne 1 -or
        [long]$targetRows[0].ExactFailedClaimRows -ne 1
    )
) {
    throw 'The initial reset requires exactly one matching failed claim.'
}
if (
    $isRollbackResumeState -and
    (
        [long]$targetRows[0].ClaimRows -ne 0 -or
        [long]$targetRows[0].ExactFailedClaimRows -ne 0
    )
) {
    throw 'The rollback-resume reset requires the already-removed zero-claim state.'
}

$movedFiles = [System.Collections.Generic.List[object]]::new()
if ($isInitialState) {
    New-Item -ItemType Directory -Path $quarantineReady -Force | Out-Null
    New-Item -ItemType Directory -Path $quarantineClaimed -Force | Out-Null

    for ($index = 0; $index -lt $expectedPaths.Count; $index++) {
        $sourceItem = Get-Item -LiteralPath $expectedPaths[$index]
        $sourceHash = (
            Get-FileHash -LiteralPath $sourceItem.FullName -Algorithm SHA256
        ).Hash
        Move-Item `
            -LiteralPath $sourceItem.FullName `
            -Destination $quarantinePaths[$index]
        $movedFiles.Add([pscustomobject]@{
            SourcePath = $sourceItem.FullName
            QuarantinePath = $quarantinePaths[$index]
            LengthBytes = $sourceItem.Length
            Sha256 = $sourceHash
        })
    }

    Invoke-K98SqlQuery `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -Query @"
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileClaim) <> 1
       OR (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> 0
        THROW 52460, 'Failed-attempt reset detected database state drift.', 1;

    DELETE dbo.KS4_ImportFileClaim
    WHERE CompletedFileName = N'$firstName'
      AND ClaimStatus = N'claimed'
      AND ClaimedPath = N'$claimedRoot\$firstName'
      AND ReadyPath = N'$readyRoot\$firstName'
      AND ArchivePath = N'$archiveRoot\$firstName';

    IF @@ROWCOUNT <> 1
        THROW 52461, 'Failed-attempt reset did not remove exactly one test claim.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
"@ `
        -QueryTimeout 120 |
        Out-Null
}
else {
    for ($index = 0; $index -lt $quarantinePaths.Count; $index++) {
        $quarantinedItem = Get-Item -LiteralPath $quarantinePaths[$index]
        $movedFiles.Add([pscustomobject]@{
            SourcePath = $expectedPaths[$index]
            QuarantinePath = $quarantinedItem.FullName
            LengthBytes = $quarantinedItem.Length
            Sha256 = (
                Get-FileHash `
                    -LiteralPath $quarantinedItem.FullName `
                    -Algorithm SHA256
            ).Hash
        })
    }
}

$rollbackSource = [IO.File]::ReadAllText($rollbackPath)
$testSqlRoot = $resolvedTestRoot + '\'
$rollbackText = $rollbackSource.Replace($productionSqlRoot, $testSqlRoot)
if (
    $rollbackText.Contains($productionSqlRoot) -or
    -not $rollbackText.Contains($testSqlRoot)
) {
    throw 'Could not bind the rollback copy exclusively to the rehearsal root.'
}

$derivedRollbackPath = Join-Path $quarantineRoot 'rollback.test-root.sql'
[IO.File]::WriteAllText(
    $derivedRollbackPath,
    $rollbackText,
    [Text.UTF8Encoding]::new($false)
)

Invoke-K98SqlFile `
    -ServerName $ServerName `
    -DatabaseName $DatabaseName `
    -InputFile $derivedRollbackPath `
    -QueryTimeout 0 |
    Out-Host

$finalRows = @(
    Invoke-K98SqlQuery `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -Query @'
SELECT
    CASE
        WHEN OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NULL THEN 1
        ELSE 0
    END AS ClaimProcedureAbsent,
    CASE
        WHEN OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NULL THEN 1
        ELSE 0
    END AS ClaimTableAbsent,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS ReceiptRows;
'@ `
        -QueryTimeout 120
)
if (
    $finalRows.Count -ne 1 -or
    [int]$finalRows[0].ClaimProcedureAbsent -ne 1 -or
    [int]$finalRows[0].ClaimTableAbsent -ne 1 -or
    [long]$finalRows[0].ReceiptRows -ne 0
) {
    throw 'The failed-attempt rollback did not restore the clean pre-Phase-5 state.'
}

$resetReceiptPath = Join-Path $quarantineRoot 'reset_receipt.json'
[ordered]@{
    SchemaVersion = 'phase5-failed-rehearsal-reset/v1'
    CompletedAtUtc = [DateTime]::UtcNow.ToString('o')
    ComputerName = $env:COMPUTERNAME
    ServerName = $ServerName
    DatabaseName = $DatabaseName
    FailedRunEvidenceRoot = $failedRun.FullName
    QuarantineRoot = $quarantineRoot
    FailedReceiptFixtureHashes = @{
        MinimalFixture = [string]$minimalReceiptInputs[0].Sha256
        RecoveryFixture = [string]$recoveryReceiptInputs[0].Sha256
    }
    MovedFiles = @($movedFiles)
    RollbackSourcePath = $rollbackPath
    RollbackSourceSha256 = (
        Get-FileHash -LiteralPath $rollbackPath -Algorithm SHA256
    ).Hash
    DerivedRollbackPath = $derivedRollbackPath
    DerivedRollbackSha256 = (
        Get-FileHash -LiteralPath $derivedRollbackPath -Algorithm SHA256
    ).Hash
    FinalState = @{
        ClaimProcedureAbsent = $true
        ClaimTableAbsent = $true
        ReceiptRows = 0
    }
} |
    ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $resetReceiptPath -Encoding utf8

try {
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()
}
catch {
    # The SqlServer module can use Microsoft.Data.SqlClient instead.
}
try {
    [Microsoft.Data.SqlClient.SqlConnection]::ClearAllPools()
}
catch {
    # This provider is optional on older SqlServer module versions.
}

Write-Host 'PASS  failed Phase 5.0 attempt quarantined and rolled back'
Write-Host "Reset receipt: $resetReceiptPath"
