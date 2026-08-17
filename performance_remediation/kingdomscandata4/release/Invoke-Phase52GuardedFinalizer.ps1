[CmdletBinding(DefaultParameterSetName = 'Execute')]
param(
    [Parameter(Mandatory)]
    [string]$ReceiptPath,

    [Parameter(Mandatory)]
    [string]$EvidenceRoot,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedReceiptSha256,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_.()\\-]+$')]
    [string]$ServerName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_]+$')]
    [string]$DatabaseName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-f0-9]{40}$')]
    [string]$ExpectedSqlCommit,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-f0-9]{40}$')]
    [string]$ExpectedBotMirrorCommit,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-f0-9]{40}$')]
    [string]$ExpectedProductionBotCommit,

    [switch]$ConfirmReceiptAccepted,

    [switch]$ConfirmWritersStopped,

    [switch]$ConfirmIrreversibleFinalize,

    [switch]$ConfirmProductionTarget,

    [Parameter(ParameterSetName = 'Offline')]
    [switch]$OfflineValidationOnly,

    [Parameter(ParameterSetName = 'Live')]
    [switch]$LiveValidationOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).ProviderPath
$sqlCommonPath = Join-Path $repoRoot 'deploy\SqlDeploy.Common.ps1'
$finalizerRelativePath =
    'performance_remediation\kingdomscandata4\phase2\03_finalize.sql'
$finalizerPath = Join-Path $repoRoot $finalizerRelativePath

if (-not (Test-Path -LiteralPath $sqlCommonPath -PathType Leaf)) {
    throw "Missing SQL deployment helper: $sqlCommonPath"
}
if (-not (Test-Path -LiteralPath $finalizerPath -PathType Leaf)) {
    throw "Missing Phase 2 finalizer: $finalizerPath"
}

. $sqlCommonPath

$requiredMigrationIds = @(
    '20260725_001_kingdomscandata4_shadow_type_remediation',
    '20260726_001_phase3_import_concurrency_and_direct_type_alignment',
    '20260727_000_retire_vAllianceActivity_WeeklyCumulative',
    '20260727_001_phase4_view_type_alignment',
    '20260728_001_phase5_immutable_import_file_handoff',
    '20260816_001_phase5_1_claim_acl_hardening'
)
$requiredGateNames = @(
    'Forward',
    'Rollback',
    'CleanReapply',
    'DatabaseIntegrity',
    'SqlContracts',
    'BotImmutableHandoff',
    'SourceUnchanged',
    'Workload',
    'Security'
)
$sha256Pattern = '^[A-F0-9]{64}$'
$gitCommitPattern = '^[a-f0-9]{40}$'

function Assert-ExactProperties {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$Expected,

        [Parameter(Mandatory)]
        [string]$Context
    )

    if ($null -eq $InputObject) {
        throw "$Context is missing."
    }

    $actual = @($InputObject.PSObject.Properties.Name | Sort-Object)
    $expectedSorted = @($Expected | Sort-Object)
    if (($actual -join "`n") -cne ($expectedSorted -join "`n")) {
        throw (
            "$Context has an unexpected property set. Expected: " +
            ($expectedSorted -join ', ') + '; found: ' + ($actual -join ', ')
        )
    }
}

function Assert-Sha256 {
    param(
        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Context
    )

    if ($Value -cnotmatch $sha256Pattern) {
        throw "$Context must be an uppercase SHA-256 digest."
    }
}

function Assert-JsonInteger {
    param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$Context
    )

    $integerTypes = @(
        [sbyte], [byte], [int16], [uint16], [int32], [uint32],
        [int64], [uint64]
    )
    if ($Value.GetType() -notin $integerTypes) {
        throw "$Context must be a JSON integer."
    }
}

function Get-Sha256ForBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString(
            $sha.ComputeHash($Bytes)
        ).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Test-DatabaseNull {
    param([AllowNull()][object]$Value)

    return $null -eq $Value -or [Convert]::IsDBNull($Value)
}

function Assert-PathIsContainedAndNotReparse {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
    $pathItem = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not $rootItem.PSIsContainer) {
        throw "EvidenceRoot is not a directory: $Root"
    }
    if ($pathItem.PSIsContainer) {
        throw "ReceiptPath is not a file: $Path"
    }

    $rootFull = [IO.Path]::GetFullPath($rootItem.FullName).TrimEnd('\')
    $pathFull = [IO.Path]::GetFullPath($pathItem.FullName)
    $rootPrefix = $rootFull + '\'
    if (-not $pathFull.StartsWith(
            $rootPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'ReceiptPath must remain below EvidenceRoot.'
    }

    $repoFull = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
    $repoPrefix = $repoFull + '\'
    if ($rootFull.Equals($repoFull, [StringComparison]::OrdinalIgnoreCase) -or
        $rootFull.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'EvidenceRoot must be outside the Git repository.'
    }

    if (($pathItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Evidence path contains a reparse point: $($pathItem.FullName)"
    }
    $current = $pathItem.Directory
    while ($null -ne $current) {
        if (($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Evidence path contains a reparse point: $($current.FullName)"
        }
        if ($current.FullName.TrimEnd('\').Equals(
                $rootFull,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            return [pscustomobject]@{
                Root = $rootFull
                Path = $pathFull
            }
        }
        $current = $current.Parent
    }

    throw 'Could not establish the EvidenceRoot trust boundary.'
}

function ConvertTo-StrictReceipt {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    try {
        $text = $utf8.GetString($Bytes)
    }
    catch {
        throw 'The combined receipt is not valid UTF-8.'
    }

    try {
        return $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "The combined receipt is not valid JSON: $($_.Exception.Message)"
    }
}

function Assert-ReceiptContract {
    param(
        [Parameter(Mandatory)]
        [object]$Receipt,

        [Parameter(Mandatory)]
        [string]$ResolvedEvidenceRoot
    )

    Assert-ExactProperties -InputObject $Receipt -Context 'Receipt' -Expected @(
        'EvidenceVersion', 'ReceiptType', 'RunId', 'Status', 'Stage',
        'CapturedAtUtc', 'EvidenceRoot', 'TargetPurpose', 'ServerName',
        'DatabaseName', 'Phase2RunId', 'SqlCommit', 'BotMirrorCommit',
        'ProductionBotCommit', 'SourceBackup', 'Migrations',
        'Phase2Digests', 'ManifestDigests', 'Gates', 'SecurityScanIds',
        'Finalizer'
    )

    Assert-JsonInteger -Value $Receipt.EvidenceVersion `
        -Context 'EvidenceVersion'
    if ($Receipt.EvidenceVersion -ne 1) {
        throw 'Unsupported combined receipt EvidenceVersion.'
    }
    if ($Receipt.ReceiptType -cne 'KingdomScanData4Phase52Combined') {
        throw 'Unexpected combined receipt type.'
    }
    if ($Receipt.RunId -cnotmatch '^phase5_2_[0-9]{8}T[0-9]{9}Z$') {
        throw 'The combined receipt RunId is invalid.'
    }
    if ($Receipt.Status -cne 'PASS' -or
        $Receipt.Stage -cne 'clean_reapply_pre_finalization') {
        throw 'Only a PASS clean-reapply pre-finalization receipt is eligible.'
    }

    try {
        $capturedAtUtc = [DateTimeOffset]::Parse(
            [string]$Receipt.CapturedAtUtc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind
        ).ToUniversalTime()
    }
    catch {
        throw 'CapturedAtUtc is not a valid round-trip timestamp.'
    }
    if ($capturedAtUtc -gt [DateTimeOffset]::UtcNow.AddMinutes(1)) {
        throw 'CapturedAtUtc is unexpectedly in the future.'
    }

    $receiptEvidenceRoot = [IO.Path]::GetFullPath(
        [string]$Receipt.EvidenceRoot
    ).TrimEnd('\')
    if (-not $receiptEvidenceRoot.Equals(
            $ResolvedEvidenceRoot,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Receipt EvidenceRoot does not match the approved EvidenceRoot.'
    }
    if ($Receipt.ServerName -cne $ServerName -or
        $Receipt.DatabaseName -cne $DatabaseName) {
        throw 'Receipt server/database does not match the command target.'
    }

    $phase2RunId = [Guid]::Empty
    if (-not [Guid]::TryParse([string]$Receipt.Phase2RunId, [ref]$phase2RunId) -or
        $phase2RunId -eq [Guid]::Empty) {
        throw 'Phase2RunId must be a non-zero GUID.'
    }

    foreach ($commitProperty in @(
            'SqlCommit', 'BotMirrorCommit', 'ProductionBotCommit'
        )) {
        if ([string]$Receipt.$commitProperty -cnotmatch $gitCommitPattern) {
            throw "$commitProperty is not an exact 40-character Git commit."
        }
    }
    if ($Receipt.SqlCommit -cne $ExpectedSqlCommit -or
        $Receipt.BotMirrorCommit -cne $ExpectedBotMirrorCommit -or
        $Receipt.ProductionBotCommit -cne $ExpectedProductionBotCommit) {
        throw 'Receipt Git commits do not match the operator-frozen commits.'
    }

    if ($DatabaseName -ceq 'ROK_TRACKER') {
        if (-not $ConfirmProductionTarget.IsPresent -or
            $Receipt.TargetPurpose -cne 'production') {
            throw 'Production finalization requires the explicit production switch and receipt.'
        }
    }
    elseif ($DatabaseName -cnotmatch
        '^ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_[0-9]{8}$' -or
        $Receipt.TargetPurpose -cne 'rehearsal') {
        throw 'Non-production finalization is pinned to a Phase 5.2 reapply database.'
    }

    Assert-ExactProperties -InputObject $Receipt.SourceBackup -Context 'SourceBackup' -Expected @(
        'Path', 'BackupSetPosition', 'BackupFinishUtc',
        'BackupChecksumPresent', 'RestoreVerifyOnlyPassed'
    )
    Assert-JsonInteger -Value $Receipt.SourceBackup.BackupSetPosition `
        -Context 'SourceBackup.BackupSetPosition'
    if ([string]::IsNullOrWhiteSpace([string]$Receipt.SourceBackup.Path) -or
        [int64]$Receipt.SourceBackup.BackupSetPosition -lt 1 -or
        $Receipt.SourceBackup.BackupChecksumPresent -isnot [bool] -or
        $Receipt.SourceBackup.RestoreVerifyOnlyPassed -isnot [bool] -or
        $Receipt.SourceBackup.BackupChecksumPresent -ne $true -or
        $Receipt.SourceBackup.RestoreVerifyOnlyPassed -ne $true) {
        throw 'Source backup identity/checksum/VERIFYONLY evidence is incomplete.'
    }
    try {
        [void][DateTimeOffset]::Parse(
            [string]$Receipt.SourceBackup.BackupFinishUtc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind
        )
    }
    catch {
        throw 'SourceBackup.BackupFinishUtc is invalid.'
    }

    $migrations = @($Receipt.Migrations)
    if ($migrations.Count -ne $requiredMigrationIds.Count) {
        throw 'The receipt must contain exactly six Phase 2-5.1 migrations.'
    }
    for ($index = 0; $index -lt $requiredMigrationIds.Count; $index++) {
        $migration = $migrations[$index]
        Assert-ExactProperties -InputObject $migration -Context "Migration[$index]" -Expected @(
            'MigrationId', 'Sha256'
        )
        if ($migration.MigrationId -cne $requiredMigrationIds[$index]) {
            throw "Migration[$index] is out of order or unexpected."
        }
        Assert-Sha256 -Value ([string]$migration.Sha256) -Context "Migration[$index].Sha256"

        $migrationPath = Join-Path $repoRoot (
            'migrations\' + $migration.MigrationId + '.sql'
        )
        if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
            throw "Missing frozen migration file: $migrationPath"
        }
        $repoDigest = (Get-FileHash -LiteralPath $migrationPath -Algorithm SHA256).Hash
        if ($repoDigest -cne $migration.Sha256) {
            throw "Migration file digest drift: $($migration.MigrationId)"
        }
    }

    Assert-ExactProperties -InputObject $Receipt.Phase2Digests -Context 'Phase2Digests' -Expected @(
        'Ks4Rows', 'Ks5Rows', 'StagingRows', 'BaselineKs4Sha256',
        'BaselineKs5Sha256', 'BaselineStagingSha256', 'ForwardKs4Sha256',
        'ForwardKs5Sha256', 'ForwardStagingSha256'
    )
    foreach ($rowProperty in @('Ks4Rows', 'Ks5Rows', 'StagingRows')) {
        Assert-JsonInteger -Value $Receipt.Phase2Digests.$rowProperty `
            -Context "Phase2Digests.$rowProperty"
        if ([long]$Receipt.Phase2Digests.$rowProperty -lt 0) {
            throw "Phase2Digests.$rowProperty cannot be negative."
        }
    }
    foreach ($digestProperty in @(
            'BaselineKs4Sha256', 'BaselineKs5Sha256',
            'BaselineStagingSha256', 'ForwardKs4Sha256',
            'ForwardKs5Sha256', 'ForwardStagingSha256'
        )) {
        Assert-Sha256 -Value ([string]$Receipt.Phase2Digests.$digestProperty) `
            -Context "Phase2Digests.$digestProperty"
    }

    Assert-ExactProperties -InputObject $Receipt.ManifestDigests -Context 'ManifestDigests' -Expected @(
        'SqlModulesSha256', 'ChangedFilesSha256', 'ValidationEvidenceSha256'
    )
    foreach ($digestProperty in $Receipt.ManifestDigests.PSObject.Properties.Name) {
        Assert-Sha256 -Value ([string]$Receipt.ManifestDigests.$digestProperty) `
            -Context "ManifestDigests.$digestProperty"
    }

    Assert-ExactProperties -InputObject $Receipt.Gates -Context 'Gates' `
        -Expected $requiredGateNames
    foreach ($gateName in $requiredGateNames) {
        if ($Receipt.Gates.$gateName -cne 'PASS') {
            throw "Required gate did not pass: $gateName"
        }
    }

    $securityScanIds = @($Receipt.SecurityScanIds)
    if ($Receipt.SecurityScanIds -isnot [array] -or
        $securityScanIds.Count -lt 1 -or
        @($securityScanIds | Select-Object -Unique).Count -ne
        $securityScanIds.Count) {
        throw 'SecurityScanIds must contain at least one unique scan ID.'
    }
    foreach ($scanId in $securityScanIds) {
        $parsedScanId = [Guid]::Empty
        if (-not [Guid]::TryParse([string]$scanId, [ref]$parsedScanId) -or
            $parsedScanId -eq [Guid]::Empty) {
            throw 'SecurityScanIds contains an invalid GUID.'
        }
    }

    Assert-ExactProperties -InputObject $Receipt.Finalizer -Context 'Finalizer' -Expected @(
        'ScriptRelativePath', 'ScriptSha256'
    )
    if ($Receipt.Finalizer.ScriptRelativePath -cne $finalizerRelativePath) {
        throw 'Receipt points to an unexpected finalizer script.'
    }
    Assert-Sha256 -Value ([string]$Receipt.Finalizer.ScriptSha256) `
        -Context 'Finalizer.ScriptSha256'
    $actualFinalizerSha256 = (
        Get-FileHash -LiteralPath $finalizerPath -Algorithm SHA256
    ).Hash
    if ($actualFinalizerSha256 -cne $Receipt.Finalizer.ScriptSha256) {
        throw 'The Phase 2 finalizer digest does not match the receipt.'
    }

    return [pscustomobject]@{
        CapturedAtUtc = $capturedAtUtc
        Phase2RunId = $phase2RunId
        FinalizerSha256 = $actualFinalizerSha256
    }
}

function Assert-LiveStateMatchesReceipt {
    param(
        [Parameter(Mandatory)]
        [object]$Receipt,

        [Parameter(Mandatory)]
        [Guid]$Phase2RunId
    )

    $runIdLiteral = ConvertTo-K98SqlLiteral -Value $Phase2RunId.ToString()
    $stateQuery = @"
SELECT
    ServerName = CONVERT(nvarchar(128), @@SERVERNAME),
    DatabaseName = DB_NAME(),
    RunId,
    Status,
    VerifiedAtUtc,
    IsFresh = CONVERT(bit, CASE WHEN VerifiedAtUtc >= DATEADD(minute, -5, SYSUTCDATETIME()) THEN 1 ELSE 0 END),
    ProductionApproved,
    Ks4Rows,
    Ks5Rows,
    StagingRows,
    BaselineKs4Sha256 = CONVERT(varchar(64), BaselineKs4Digest, 2),
    BaselineKs5Sha256 = CONVERT(varchar(64), BaselineKs5Digest, 2),
    BaselineStagingSha256 = CONVERT(varchar(64), BaselineStagingDigest, 2),
    ForwardKs4Sha256 = CONVERT(varchar(64), ForwardKs4Digest, 2),
    ForwardKs5Sha256 = CONVERT(varchar(64), ForwardKs5Digest, 2),
    ForwardStagingSha256 = CONVERT(varchar(64), ForwardStagingDigest, 2),
    RollbackCompletedAtUtc,
    FinalizedAtUtc
FROM dbo.KS4_Phase2_PreflightState
WHERE RunId = CONVERT(uniqueidentifier, $runIdLiteral);
"@
    $stateRows = @(
        Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName $DatabaseName `
            -Query $stateQuery -QueryTimeout 120
    )
    if ($stateRows.Count -ne 1) {
        throw 'The exact Phase 2 preflight state row is absent or duplicated.'
    }
    $state = $stateRows[0]
    if ([string]$state.ServerName -cne $ServerName -or
        [string]$state.DatabaseName -cne $DatabaseName -or
        [string]$state.Status -cne 'VERIFIED' -or
        -not [bool]$state.IsFresh -or
        -not (Test-DatabaseNull -Value $state.RollbackCompletedAtUtc) -or
        -not (Test-DatabaseNull -Value $state.FinalizedAtUtc)) {
        throw 'The Phase 2 state is not a fresh, eligible VERIFIED run.'
    }
    if ($DatabaseName -ceq 'ROK_TRACKER' -and
        -not [bool]$state.ProductionApproved) {
        throw 'The Phase 2 state does not record separate production approval.'
    }

    foreach ($rowProperty in @('Ks4Rows', 'Ks5Rows', 'StagingRows')) {
        if ([long]$state.$rowProperty -ne
            [long]$Receipt.Phase2Digests.$rowProperty) {
            throw "Live Phase 2 row-count drift: $rowProperty"
        }
    }
    foreach ($digestProperty in @(
            'BaselineKs4Sha256', 'BaselineKs5Sha256',
            'BaselineStagingSha256', 'ForwardKs4Sha256',
            'ForwardKs5Sha256', 'ForwardStagingSha256'
        )) {
        if ([string]$state.$digestProperty -cne
            [string]$Receipt.Phase2Digests.$digestProperty) {
            throw "Live Phase 2 digest drift: $digestProperty"
        }
    }

    $migrationLiterals = @(
        foreach ($migrationId in $requiredMigrationIds) {
            ConvertTo-K98SqlLiteral -Value $migrationId
        }
    ) -join ', '
    $historyQuery = @"
SELECT MigrationId, ChecksumSha256, Status
FROM dbo.SchemaMigrationHistory
WHERE MigrationId IN ($migrationLiterals)
ORDER BY MigrationId;
"@
    $historyRows = @(
        Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName $DatabaseName `
            -Query $historyQuery -QueryTimeout 120
    )
    if ($historyRows.Count -ne $requiredMigrationIds.Count) {
        throw 'The live database does not contain all six migration-history rows.'
    }
    $historyById = @{}
    foreach ($historyRow in $historyRows) {
        $historyById[[string]$historyRow.MigrationId] = $historyRow
    }
    foreach ($migration in @($Receipt.Migrations)) {
        $historyRow = $historyById[[string]$migration.MigrationId]
        if ($null -eq $historyRow -or
            [string]$historyRow.Status -cne 'Applied' -or
            [string]$historyRow.ChecksumSha256 -cne
            ([string]$migration.Sha256).ToLowerInvariant()) {
            throw "Live migration-history drift: $($migration.MigrationId)"
        }
    }
}

if ($PSCmdlet.ParameterSetName -eq 'Execute') {
    if (-not $ConfirmReceiptAccepted.IsPresent) {
        throw 'Pass -ConfirmReceiptAccepted only after Checkpoint C accepts this receipt.'
    }
    if (-not $ConfirmWritersStopped.IsPresent) {
        throw 'Pass -ConfirmWritersStopped only after every writer is stopped.'
    }
    if (-not $ConfirmIrreversibleFinalize.IsPresent) {
        throw 'Pass -ConfirmIrreversibleFinalize to acknowledge loss of early rollback.'
    }
}

$trustedPath = Assert-PathIsContainedAndNotReparse `
    -Root $EvidenceRoot -Path $ReceiptPath
$receiptBytes = [IO.File]::ReadAllBytes($trustedPath.Path)
$receiptSha256 = Get-Sha256ForBytes -Bytes $receiptBytes
if ($receiptSha256 -cne $ExpectedReceiptSha256.ToUpperInvariant()) {
    throw 'The combined receipt SHA-256 does not match the operator-frozen digest.'
}
$receipt = ConvertTo-StrictReceipt -Bytes $receiptBytes
$validated = Assert-ReceiptContract -Receipt $receipt `
    -ResolvedEvidenceRoot $trustedPath.Root

if ($OfflineValidationOnly.IsPresent) {
    [pscustomobject]@{
        Result = 'PASS'
        Mode = 'OfflineValidationOnly'
        ReceiptSha256 = $receiptSha256
        Phase2RunId = $validated.Phase2RunId
        SqlCommit = $receipt.SqlCommit
    }
    return
}

$currentCommit = (
    Invoke-K98Git -RepoRoot $repoRoot -Arguments @('rev-parse', 'HEAD')
).Output.Trim()
if ($currentCommit -cne $ExpectedSqlCommit) {
    throw 'The checked-out SQL repository commit is not the frozen SQL commit.'
}
Assert-K98CleanGitTree -RepoRoot $repoRoot
if ($DatabaseName -ceq 'ROK_TRACKER') {
    $currentBranch = (
        Invoke-K98Git -RepoRoot $repoRoot `
            -Arguments @('branch', '--show-current')
    ).Output.Trim()
    $originMain = (
        Invoke-K98Git -RepoRoot $repoRoot `
            -Arguments @('rev-parse', 'origin/main')
    ).Output.Trim()
    if ($currentBranch -cne 'main' -or $originMain -cne $ExpectedSqlCommit) {
        throw 'Production finalization requires clean main equal to origin/main.'
    }
}

Assert-LiveStateMatchesReceipt -Receipt $receipt `
    -Phase2RunId $validated.Phase2RunId

if ($validated.CapturedAtUtc -lt [DateTimeOffset]::UtcNow.AddMinutes(-5)) {
    throw 'The combined receipt is older than the finalizer freshness window.'
}

if ($LiveValidationOnly.IsPresent) {
    [pscustomobject]@{
        Result = 'PASS'
        Mode = 'LiveValidationOnly'
        ReceiptSha256 = $receiptSha256
        Phase2RunId = $validated.Phase2RunId
        SqlCommit = $receipt.SqlCommit
    }
    return
}

$finalizerSource = Get-Content -Raw -LiteralPath $finalizerPath
$runDeclaration = 'DECLARE @ConfirmRunId uniqueidentifier = NULL;'
$confirmationDeclaration = 'DECLARE @ConfirmIrreversibleFinalize bit = 0;'
$runDeclarationIndex = $finalizerSource.IndexOf(
    $runDeclaration,
    [StringComparison]::Ordinal
)
$confirmationDeclarationIndex = $finalizerSource.IndexOf(
    $confirmationDeclaration,
    [StringComparison]::Ordinal
)
if ($runDeclarationIndex -lt 0 -or
    $finalizerSource.IndexOf(
        $runDeclaration,
        $runDeclarationIndex + $runDeclaration.Length,
        [StringComparison]::Ordinal
    ) -ge 0 -or
    $confirmationDeclarationIndex -lt 0 -or
    $finalizerSource.IndexOf(
        $confirmationDeclaration,
        $confirmationDeclarationIndex + $confirmationDeclaration.Length,
        [StringComparison]::Ordinal
    ) -ge 0) {
    throw 'The reviewed Phase 2 finalizer confirmation declarations drifted.'
}
$authorizedSql = $finalizerSource.Replace(
    $runDeclaration,
    "DECLARE @ConfirmRunId uniqueidentifier = '$($validated.Phase2RunId)';"
).Replace(
    $confirmationDeclaration,
    'DECLARE @ConfirmIrreversibleFinalize bit = 1;'
)
$authorizedBytes = [Text.UTF8Encoding]::new($false).GetBytes($authorizedSql)
$authorizedSha256 = Get-Sha256ForBytes -Bytes $authorizedBytes
$trustedPathBeforeWrite = Assert-PathIsContainedAndNotReparse `
    -Root $trustedPath.Root -Path $trustedPath.Path
if (-not $trustedPathBeforeWrite.Root.Equals(
        $trustedPath.Root,
        [StringComparison]::OrdinalIgnoreCase
    ) -or
    -not $trustedPathBeforeWrite.Path.Equals(
        $trustedPath.Path,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'The evidence trust boundary changed before finalizer evidence write.'
}
$executionRoot = Join-Path $trustedPath.Root (
    'finalizer_' + $receipt.RunId + '_' +
    [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
)
if (Test-Path -LiteralPath $executionRoot) {
    throw "Finalizer evidence directory already exists: $executionRoot"
}
New-Item -ItemType Directory -Path $executionRoot | Out-Null
$authorizedPath = Join-Path $executionRoot '03_finalize.authorized.sql'
[IO.File]::WriteAllBytes($authorizedPath, $authorizedBytes)

$startedAtUtc = [DateTime]::UtcNow
$executionStatus = 'FAIL'
$executionError = $null
try {
    [void](
        Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName $DatabaseName `
            -Query $authorizedSql -QueryTimeout 0
    )

    $postQuery = @"
SELECT RunId, Status, FinalizedAtUtc,
       FinalizeReceiptCount =
       (
           SELECT COUNT(*)
           FROM dbo.KS4_Phase2_MigrationReceipt
           WHERE RunId = state_info.RunId
             AND Direction = 'FINALIZE'
       )
FROM dbo.KS4_Phase2_PreflightState AS state_info
WHERE RunId = CONVERT(uniqueidentifier,
    $(ConvertTo-K98SqlLiteral -Value $validated.Phase2RunId.ToString()));
"@
    $postRows = @(
        Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName $DatabaseName `
            -Query $postQuery -QueryTimeout 120
    )
    if ($postRows.Count -ne 1 -or
        [string]$postRows[0].Status -cne 'FINALIZED' -or
        (Test-DatabaseNull -Value $postRows[0].FinalizedAtUtc) -or
        [int]$postRows[0].FinalizeReceiptCount -lt 1) {
        throw 'Post-finalization state/receipt verification failed.'
    }
    $executionStatus = 'PASS'
}
catch {
    $executionError = $_.Exception.Message
    throw
}
finally {
    $completedAtUtc = [DateTime]::UtcNow
    $executionReceipt = [ordered]@{
        EvidenceVersion = 1
        ReceiptType = 'KingdomScanData4Phase52FinalizerExecution'
        RunId = $receipt.RunId
        Phase2RunId = $validated.Phase2RunId.ToString()
        ServerName = $ServerName
        DatabaseName = $DatabaseName
        SqlCommit = $ExpectedSqlCommit
        CombinedReceiptSha256 = $receiptSha256
        ReviewedFinalizerSha256 = $validated.FinalizerSha256
        AuthorizedFinalizerSha256 = $authorizedSha256
        StartedAtUtc = $startedAtUtc.ToString('o')
        CompletedAtUtc = $completedAtUtc.ToString('o')
        Status = $executionStatus
        Error = $executionError
    }
    $executionReceiptPath = Join-Path $executionRoot 'receipt.json'
    [IO.File]::WriteAllText(
        $executionReceiptPath,
        (($executionReceipt | ConvertTo-Json -Depth 5) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
}

[pscustomobject]@{
    Result = 'PASS'
    Mode = 'Execute'
    ReceiptSha256 = $receiptSha256
    AuthorizedFinalizerSha256 = $authorizedSha256
    EvidenceRoot = $executionRoot
}
