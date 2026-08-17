[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).ProviderPath
$adapterPath = Join-Path $PSScriptRoot 'Invoke-Phase52GuardedFinalizer.ps1'
$schemaPath = Join-Path $PSScriptRoot 'combined_receipt.schema.json'
$finalizerRelativePath =
    'performance_remediation\kingdomscandata4\phase2\03_finalize.sql'
$finalizerPath = Join-Path $repoRoot $finalizerRelativePath

foreach ($requiredPath in @($adapterPath, $schemaPath, $finalizerPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing guarded-finalizer input: $requiredPath"
    }
}

$adapterSource = Get-Content -Raw -LiteralPath $adapterPath
$schema = Get-Content -Raw -LiteralPath $schemaPath | ConvertFrom-Json
if ($schema.title -cne
    'KingdomScanData4 Phase 5.2 combined pre-finalization receipt') {
    throw 'The combined receipt schema identity is missing or unexpected.'
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )

    if ($adapterSource -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-Throws {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$ExpectedMessage
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
            throw (
                "Expected failure containing '$ExpectedMessage'; received: " +
                $_.Exception.Message
            )
        }
        return
    }
    throw "Expected failure containing '$ExpectedMessage'."
}

Assert-Contains -Pattern "(?s)ParameterSetName -eq 'Execute'.+ConfirmReceiptAccepted\.IsPresent" `
    -Message 'Receipt acceptance must be explicitly enforced in execution mode.'
Assert-Contains -Pattern "(?s)ParameterSetName -eq 'Execute'.+ConfirmWritersStopped\.IsPresent" `
    -Message 'Writer-stop confirmation must be explicitly enforced in execution mode.'
Assert-Contains -Pattern "(?s)ParameterSetName -eq 'Execute'.+ConfirmIrreversibleFinalize\.IsPresent" `
    -Message 'Irreversible finalization must be explicitly enforced in execution mode.'
Assert-Contains -Pattern 'ReadAllBytes\(\$trustedPath\.Path\)' `
    -Message 'Receipt bytes must be read once across the trusted path boundary.'
Assert-Contains -Pattern 'Get-Sha256ForBytes\s+-Bytes\s+\$receiptBytes' `
    -Message 'Receipt authorization must use the exact bytes that are parsed.'
Assert-Contains -Pattern 'Assert-LiveStateMatchesReceipt' `
    -Message 'The adapter must revalidate live Phase 2 state and migration history.'
Assert-Contains -Pattern 'Invoke-K98SqlQuery[\s\S]*-Query\s+\$authorizedSql' `
    -Message 'The exact in-memory authorized finalizer must be executed.'
Assert-Contains -Pattern "Status\s+-cne\s+'FINALIZED'" `
    -Message 'The adapter must verify the durable finalized state.'

if ($adapterSource -match '(?i)Invoke-Expression|\biex\b') {
    throw 'The guarded finalizer must not use expression evaluation.'
}
if ($adapterSource -match '(?im)^\s*(Remove-Item|rm|del)\b') {
    throw 'The guarded finalizer must not delete evidence or database files.'
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$tempRoot = Join-Path $tempBase (
    'k98_phase52_finalizer_test_' + [Guid]::NewGuid().ToString('N')
)
$outsideRoot = Join-Path $tempBase (
    'k98_phase52_finalizer_outside_' + [Guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Path $outsideRoot | Out-Null

try {
    $sqlCommit = 'a' * 40 -join ''
    $botMirrorCommit = 'b' * 40 -join ''
    $productionBotCommit = 'c' * 40 -join ''
    $digestA = 'A' * 64 -join ''
    $digestB = 'B' * 64 -join ''
    $digestC = 'C' * 64 -join ''
    $digestD = 'D' * 64 -join ''
    $digestE = 'E' * 64 -join ''
    $digestF = 'F' * 64 -join ''
    $migrationIds = @(
        '20260725_001_kingdomscandata4_shadow_type_remediation',
        '20260726_001_phase3_import_concurrency_and_direct_type_alignment',
        '20260727_000_retire_vAllianceActivity_WeeklyCumulative',
        '20260727_001_phase4_view_type_alignment',
        '20260728_001_phase5_immutable_import_file_handoff',
        '20260816_001_phase5_1_claim_acl_hardening'
    )
    $migrations = @(
        foreach ($migrationId in $migrationIds) {
            $migrationPath = Join-Path $repoRoot (
                'migrations\' + $migrationId + '.sql'
            )
            [ordered]@{
                MigrationId = $migrationId
                Sha256 = (
                    Get-FileHash -LiteralPath $migrationPath -Algorithm SHA256
                ).Hash
            }
        }
    )
    $databaseName =
        'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_20260817'
    $receipt = [ordered]@{
        EvidenceVersion = 1
        ReceiptType = 'KingdomScanData4Phase52Combined'
        RunId = 'phase5_2_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
        Status = 'PASS'
        Stage = 'clean_reapply_pre_finalization'
        CapturedAtUtc = [DateTime]::UtcNow.ToString('o')
        EvidenceRoot = $tempRoot
        TargetPurpose = 'rehearsal'
        ServerName = 'MINI_AMD'
        DatabaseName = $databaseName
        Phase2RunId = [Guid]::NewGuid().ToString()
        SqlCommit = $sqlCommit
        BotMirrorCommit = $botMirrorCommit
        ProductionBotCommit = $productionBotCommit
        SourceBackup = [ordered]@{
            Path = 'C:\sql_backup\approved_seed.bak'
            BackupSetPosition = 1
            BackupFinishUtc = [DateTime]::UtcNow.AddDays(-1).ToString('o')
            BackupChecksumPresent = $true
            RestoreVerifyOnlyPassed = $true
        }
        Migrations = $migrations
        Phase2Digests = [ordered]@{
            Ks4Rows = 10
            Ks5Rows = 10
            StagingRows = 10
            BaselineKs4Sha256 = $digestA
            BaselineKs5Sha256 = $digestB
            BaselineStagingSha256 = $digestC
            ForwardKs4Sha256 = $digestD
            ForwardKs5Sha256 = $digestE
            ForwardStagingSha256 = $digestF
        }
        ManifestDigests = [ordered]@{
            SqlModulesSha256 = $digestA
            ChangedFilesSha256 = $digestB
            ValidationEvidenceSha256 = $digestC
        }
        Gates = [ordered]@{
            Forward = 'PASS'
            Rollback = 'PASS'
            CleanReapply = 'PASS'
            DatabaseIntegrity = 'PASS'
            SqlContracts = 'PASS'
            BotImmutableHandoff = 'PASS'
            SourceUnchanged = 'PASS'
            Workload = 'PASS'
            Security = 'PASS'
        }
        SecurityScanIds = @([Guid]::NewGuid().ToString())
        Finalizer = [ordered]@{
            ScriptRelativePath = $finalizerRelativePath
            ScriptSha256 = (
                Get-FileHash -LiteralPath $finalizerPath -Algorithm SHA256
            ).Hash
        }
    }
    $receiptPath = Join-Path $tempRoot 'receipt.json'
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $receiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    $commonArguments = @{
        ReceiptPath = $receiptPath
        EvidenceRoot = $tempRoot
        ExpectedReceiptSha256 = $receiptSha256
        ServerName = 'MINI_AMD'
        DatabaseName = $databaseName
        ExpectedSqlCommit = $sqlCommit
        ExpectedBotMirrorCommit = $botMirrorCommit
        ExpectedProductionBotCommit = $productionBotCommit
        OfflineValidationOnly = $true
    }

    $validResult = & $adapterPath @commonArguments
    if ($validResult.Result -cne 'PASS' -or
        $validResult.Mode -cne 'OfflineValidationOnly') {
        throw 'A valid combined receipt did not pass offline validation.'
    }

    $wrongHashArguments = $commonArguments.Clone()
    $wrongHashArguments.ExpectedReceiptSha256 = '0' * 64 -join ''
    Assert-Throws -ExpectedMessage 'operator-frozen digest' -Action {
        & $adapterPath @wrongHashArguments
    }

    $receipt.EvidenceVersion = '1'
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $wrongTypeArguments = $commonArguments.Clone()
    $wrongTypeArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    Assert-Throws -ExpectedMessage 'must be a JSON integer' -Action {
        & $adapterPath @wrongTypeArguments
    }
    $receipt.EvidenceVersion = 1

    $receipt.Status = 'FAIL'
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $failedGateArguments = $commonArguments.Clone()
    $failedGateArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    Assert-Throws -ExpectedMessage 'Only a PASS' -Action {
        & $adapterPath @failedGateArguments
    }

    $receipt.Status = 'PASS'
    $firstMigration = $receipt.Migrations[0]
    $receipt.Migrations[0] = $receipt.Migrations[1]
    $receipt.Migrations[1] = $firstMigration
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $migrationOrderArguments = $commonArguments.Clone()
    $migrationOrderArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    Assert-Throws -ExpectedMessage 'out of order or unexpected' -Action {
        & $adapterPath @migrationOrderArguments
    }
    $receipt.Migrations[1] = $receipt.Migrations[0]
    $receipt.Migrations[0] = $firstMigration

    $outsideReceiptPath = Join-Path $outsideRoot 'receipt.json'
    Copy-Item -LiteralPath $receiptPath -Destination $outsideReceiptPath
    $outsideArguments = $failedGateArguments.Clone()
    $outsideArguments.ReceiptPath = $outsideReceiptPath
    Assert-Throws -ExpectedMessage 'below EvidenceRoot' -Action {
        & $adapterPath @outsideArguments
    }

    $receipt.Status = 'PASS'
    $receipt.TargetPurpose = 'production'
    $receipt.DatabaseName = 'ROK_TRACKER'
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $productionArguments = $commonArguments.Clone()
    $productionArguments.DatabaseName = 'ROK_TRACKER'
    $productionArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    Assert-Throws -ExpectedMessage 'explicit production switch' -Action {
        & $adapterPath @productionArguments
    }
}
finally {
    foreach ($candidate in @($tempRoot, $outsideRoot)) {
        $resolvedCandidate = [IO.Path]::GetFullPath($candidate)
        if (-not $resolvedCandidate.StartsWith(
                $tempBase + '\k98_phase52_finalizer_',
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Refusing to remove unexpected test path: $resolvedCandidate"
        }
        if (Test-Path -LiteralPath $resolvedCandidate) {
            Remove-Item -LiteralPath $resolvedCandidate -Recurse -Force
        }
    }
}

[pscustomobject]@{
    Test = 'Phase52GuardedFinalizer'
    OfflinePositiveCases = 1
    OfflineNegativeCases = 6
    Result = 'PASS'
}
