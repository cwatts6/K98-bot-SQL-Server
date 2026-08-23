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
if ('AppliedSha256' -cnotin @($schema.'$defs'.migration.required)) {
    throw 'The combined receipt schema does not require the applied migration digest.'
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
Assert-Contains -Pattern 'ReadAllBytes\(\$finalizerPath\)' `
    -Message 'The reviewed finalizer must be captured through one immutable byte read.'
Assert-Contains -Pattern 'Get-Sha256ForBytes\s+-Bytes\s+\$finalizerBytes' `
    -Message 'The exact captured finalizer bytes must supply the receipt digest check.'
Assert-Contains -Pattern 'ConvertFrom-StrictUtf8Bytes\s+-Bytes\s+\$finalizerBytes' `
    -Message 'The exact captured finalizer bytes must supply the executed source text.'
Assert-Contains -Pattern 'Assert-LiveStateMatchesReceipt' `
    -Message 'The adapter must revalidate live Phase 2 state and migration history.'
Assert-Contains -Pattern 'ChecksumSha256\s+-cne\s+\(\[string\]\$migration\.AppliedSha256\)' `
    -Message 'Live migration history must bind the separately frozen applied digest.'
Assert-Contains -Pattern 'Invoke-K98SqlQuery[\s\S]*-Query\s+\$authorizedSql' `
    -Message 'The exact in-memory authorized finalizer must be executed.'
Assert-Contains -Pattern "Status\s+-cne\s+'FINALIZED'" `
    -Message 'The adapter must verify the durable finalized state.'
Assert-Contains -Pattern 'GetFinalPathNameByHandle' `
    -Message 'Evidence output handles must be resolved to their final paths.'
Assert-Contains -Pattern '\[IO\.FileMode\]::CreateNew' `
    -Message 'Evidence outputs must never overwrite an existing path.'
Assert-Contains -Pattern '\[IO\.FileShare\]::None' `
    -Message 'Evidence output handles must remain exclusively bound.'
Assert-Contains -Pattern '\$authorizedOutput\.Stream\.Write' `
    -Message 'Authorized SQL must be written through its validated handle.'
Assert-Contains -Pattern '\$executionReceiptOutput\.Stream\.Write' `
    -Message 'The execution receipt must be written through its validated handle.'

if ($adapterSource -match '(?i)Invoke-Expression|\biex\b') {
    throw 'The guarded finalizer must not use expression evaluation.'
}
if ($adapterSource -match '(?im)^\s*(Remove-Item|rm|del)\b') {
    throw 'The guarded finalizer must not delete evidence or database files.'
}
if ($adapterSource -match 'Get-Content\s+-Raw\s+-LiteralPath\s+\$finalizerPath') {
    throw 'The guarded finalizer must not independently re-read reviewed SQL.'
}
if ($adapterSource -match '\[IO\.File\]::Write(AllBytes|AllText)\(\$(authorizedPath|executionReceiptPath)') {
    throw 'Finalizer evidence must not be written through mutable path lookups.'
}

$adapterTokens = $null
$adapterParseErrors = $null
$adapterAst = [Management.Automation.Language.Parser]::ParseFile(
    $adapterPath,
    [ref]$adapterTokens,
    [ref]$adapterParseErrors
)
if ($adapterParseErrors.Count -ne 0) {
    throw 'The guarded finalizer did not parse for helper regression tests.'
}
$requiredHelperNames = @(
    'Initialize-K98FinalPathNative',
    'Get-K98FinalPathForStream',
    'New-K98BoundEvidenceStream'
)
foreach ($helperName in $requiredHelperNames) {
    $helperNode = $adapterAst.Find(
        {
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -ceq $helperName
        },
        $true
    )
    if ($null -eq $helperNode) {
        throw "Missing finalizer evidence helper: $helperName"
    }
    . ([scriptblock]::Create($helperNode.Extent.Text))
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$tempRoot = Join-Path $tempBase (
    'k98_phase52_finalizer_test_' + [Guid]::NewGuid().ToString('N')
)
$outsideRoot = Join-Path $tempBase (
    'k98_phase52_finalizer_outside_' + [Guid]::NewGuid().ToString('N')
)
$junctionTargetRoot = Join-Path $tempRoot 'junction_target'
$junctionLinkRoot = Join-Path $tempRoot 'junction_link'
$writeJunctionLinkRoot = Join-Path $tempRoot 'write_junction'
New-Item -ItemType Directory -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Path $outsideRoot | Out-Null

try {
    $normalBoundPath = Join-Path $tempRoot (
        'bound_' + [Guid]::NewGuid().ToString('N') + '.bin'
    )
    $normalBoundOutput = New-K98BoundEvidenceStream -Path $normalBoundPath
    try {
        $probeBytes = [Text.UTF8Encoding]::new($false).GetBytes('probe')
        $normalBoundOutput.Stream.Write($probeBytes, 0, $probeBytes.Length)
        $normalBoundOutput.Stream.Flush($true)
    }
    finally {
        $normalBoundOutput.Stream.Dispose()
    }
    if ([Text.Encoding]::UTF8.GetString(
            [IO.File]::ReadAllBytes($normalBoundPath)
        ) -cne 'probe') {
        throw 'A valid bound evidence stream did not persist exact bytes.'
    }

    New-Item -ItemType Junction -Path $writeJunctionLinkRoot `
        -Target $outsideRoot | Out-Null
    $escapedLeaf = 'escaped_' + [Guid]::NewGuid().ToString('N') + '.bin'
    $escapedPath = Join-Path $writeJunctionLinkRoot $escapedLeaf
    Assert-Throws -ExpectedMessage 'resolved outside the intended evidence path' -Action {
        New-K98BoundEvidenceStream -Path $escapedPath
    }
    $escapedPhysicalPath = Join-Path $outsideRoot $escapedLeaf
    if (-not (Test-Path -LiteralPath $escapedPhysicalPath -PathType Leaf) -or
        (Get-Item -LiteralPath $escapedPhysicalPath).Length -ne 0) {
        throw 'A rejected link-swapped evidence path received content.'
    }
    Remove-Item -LiteralPath $writeJunctionLinkRoot -Force

    $sqlCommit = 'a' * 40 -join ''
    $botMirrorCommit = 'b' * 40 -join ''
    $productionBotCommit = 'c' * 40 -join ''
    $digestA = 'A' * 64 -join ''
    $digestB = 'B' * 64 -join ''
    $digestC = 'C' * 64 -join ''
    $digestD = 'D' * 64 -join ''
    $digestE = 'E' * 64 -join ''
    $digestF = 'F' * 64 -join ''
    $manifestDirectory = Join-Path $tempRoot 'manifests'
    New-Item -ItemType Directory -Path $manifestDirectory | Out-Null
    $sqlModulesRelativePath = 'manifests\sql_modules.json'
    $changedFilesRelativePath = 'manifests\changed_files.json'
    $validationEvidenceRelativePath = 'manifests\validation_evidence.json'
    $sqlModulesPath = Join-Path $tempRoot $sqlModulesRelativePath
    $changedFilesPath = Join-Path $tempRoot $changedFilesRelativePath
    $validationEvidencePath = Join-Path $tempRoot $validationEvidenceRelativePath
    $sqlModulesContent = '{"modules":[]}'
    $changedFilesContent = '{"files":[]}'
    $validationEvidenceContent = '{"validations":[]}'
    [IO.File]::WriteAllText(
        $sqlModulesPath,
        $sqlModulesContent,
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $changedFilesPath,
        $changedFilesContent,
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $validationEvidencePath,
        $validationEvidenceContent,
        [Text.UTF8Encoding]::new($false)
    )
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
                AppliedSha256 = (
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
            SqlModulesSha256 = [ordered]@{
                RelativePath = $sqlModulesRelativePath
                Sha256 = (
                    Get-FileHash -LiteralPath $sqlModulesPath -Algorithm SHA256
                ).Hash
            }
            ChangedFilesSha256 = [ordered]@{
                RelativePath = $changedFilesRelativePath
                Sha256 = (
                    Get-FileHash -LiteralPath $changedFilesPath -Algorithm SHA256
                ).Hash
            }
            ValidationEvidenceSha256 = [ordered]@{
                RelativePath = $validationEvidenceRelativePath
                Sha256 = (
                    Get-FileHash -LiteralPath $validationEvidencePath -Algorithm SHA256
                ).Hash
            }
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

    $phase5Migration = $receipt.Migrations[4]
    $canonicalPhase5AppliedSha256 = $phase5Migration.AppliedSha256
    $phase5Migration.AppliedSha256 = '0' * 64 -join ''
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $derivedRehearsalArguments = $commonArguments.Clone()
    $derivedRehearsalArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    $derivedRehearsalResult = & $adapterPath @derivedRehearsalArguments
    if ($derivedRehearsalResult.Result -cne 'PASS' -or
        $derivedRehearsalResult.DerivedAppliedMigrationCount -ne 1) {
        throw 'A receipt-bound Phase 5 rehearsal derivation did not pass offline validation.'
    }
    $phase5Migration.AppliedSha256 = $canonicalPhase5AppliedSha256

    $phase3Migration = $receipt.Migrations[1]
    $canonicalPhase3AppliedSha256 = $phase3Migration.AppliedSha256
    $phase3Migration.AppliedSha256 = '0' * 64 -join ''
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $unexpectedDerivedArguments = $commonArguments.Clone()
    $unexpectedDerivedArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    Assert-Throws -ExpectedMessage 'only for the Phase 5 migration' -Action {
        & $adapterPath @unexpectedDerivedArguments
    }
    $phase3Migration.AppliedSha256 = $canonicalPhase3AppliedSha256
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )

    [IO.File]::WriteAllText(
        $sqlModulesPath,
        '{"modules":["tampered"]}',
        [Text.UTF8Encoding]::new($false)
    )
    Assert-Throws -ExpectedMessage 'evidence digest drift' -Action {
        & $adapterPath @commonArguments
    }
    [IO.File]::WriteAllText(
        $sqlModulesPath,
        $sqlModulesContent,
        [Text.UTF8Encoding]::new($false)
    )

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

    $receipt.EvidenceVersion = $null
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $nullTypeArguments = $commonArguments.Clone()
    $nullTypeArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    Assert-Throws -ExpectedMessage 'must be a JSON integer' -Action {
        & $adapterPath @nullTypeArguments
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

    $junctionPhysicalEvidenceRoot = Join-Path $junctionTargetRoot 'evidence'
    $junctionPhysicalManifestDirectory = Join-Path `
        $junctionPhysicalEvidenceRoot 'manifests'
    New-Item -ItemType Directory -Path $junctionPhysicalManifestDirectory `
        -Force | Out-Null
    Copy-Item -LiteralPath $sqlModulesPath `
        -Destination (Join-Path $junctionPhysicalEvidenceRoot $sqlModulesRelativePath)
    Copy-Item -LiteralPath $changedFilesPath `
        -Destination (Join-Path $junctionPhysicalEvidenceRoot $changedFilesRelativePath)
    Copy-Item -LiteralPath $validationEvidencePath `
        -Destination (Join-Path $junctionPhysicalEvidenceRoot $validationEvidenceRelativePath)
    New-Item -ItemType Junction -Path $junctionLinkRoot `
        -Target $junctionTargetRoot | Out-Null
    $junctionEvidenceRoot = Join-Path $junctionLinkRoot 'evidence'
    $junctionReceiptPath = Join-Path $junctionEvidenceRoot 'receipt.json'
    $receipt.EvidenceRoot = $junctionEvidenceRoot
    [IO.File]::WriteAllText(
        $junctionReceiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $junctionArguments = $commonArguments.Clone()
    $junctionArguments.EvidenceRoot = $junctionEvidenceRoot
    $junctionArguments.ReceiptPath = $junctionReceiptPath
    $junctionArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $junctionReceiptPath -Algorithm SHA256
    ).Hash
    Assert-Throws -ExpectedMessage 'contains a reparse point' -Action {
        & $adapterPath @junctionArguments
    }
    $receipt.EvidenceRoot = $tempRoot

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

    $receipt.Migrations[4].AppliedSha256 = '0' * 64 -join ''
    [IO.File]::WriteAllText(
        $receiptPath,
        (($receipt | ConvertTo-Json -Depth 10) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    $productionDerivedArguments = $productionArguments.Clone()
    $productionDerivedArguments.ConfirmProductionTarget = $true
    $productionDerivedArguments.ExpectedReceiptSha256 = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash
    Assert-Throws -ExpectedMessage 'only for the Phase 5 migration on a rehearsal target' -Action {
        & $adapterPath @productionDerivedArguments
    }
}
finally {
    if (Test-Path -LiteralPath $writeJunctionLinkRoot) {
        Remove-Item -LiteralPath $writeJunctionLinkRoot -Force
    }
    if (Test-Path -LiteralPath $junctionLinkRoot) {
        Remove-Item -LiteralPath $junctionLinkRoot -Force
    }
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
    OfflinePositiveCases = 3
    OfflineNegativeCases = 12
    Result = 'PASS'
}
