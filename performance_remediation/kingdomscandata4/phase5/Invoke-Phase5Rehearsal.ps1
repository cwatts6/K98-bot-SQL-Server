[CmdletBinding()]
param(
    [ValidateSet('localhost', '.', '(local)')]
    [string]$ServerName = 'localhost',

    [ValidateSet('ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL')]
    [string]$DatabaseName =
        'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL',

    [ValidateSet('C:\discord_file_downloader')]
    [string]$BotRoot = 'C:\discord_file_downloader',

    [ValidateSet('C:\discord_file_downloader\downloads_test_phase5_rehearsal')]
    [string]$TestRoot =
        'C:\discord_file_downloader\downloads_test_phase5_rehearsal',

    [Parameter(Mandatory = $true)]
    [switch]$ConfirmIsolatedTarget,

    [Parameter(Mandatory = $true)]
    [switch]$ConfirmWritersStopped
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedComputerName = 'MINI_AMD'
$expectedDatabaseName =
    'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
$repoRoot = (
    Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
).ProviderPath
$sqlCommonPath = Join-Path $repoRoot 'deploy\SqlDeploy.Common.ps1'

if (-not (Test-Path -LiteralPath $sqlCommonPath -PathType Leaf)) {
    throw "Missing SQL deployment helper: $sqlCommonPath"
}

. $sqlCommonPath

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

if (-not $ConfirmIsolatedTarget.IsPresent) {
    throw 'Pass -ConfirmIsolatedTarget after confirming this is an isolated restored copy.'
}

if (-not $ConfirmWritersStopped.IsPresent) {
    throw 'Pass -ConfirmWritersStopped after confirming import and scheduler writers are stopped.'
}

if ($env:COMPUTERNAME -ine $expectedComputerName) {
    throw "Run this rehearsal locally on $expectedComputerName. Current host: $env:COMPUTERNAME"
}

if ($DatabaseName -cne $expectedDatabaseName) {
    throw "The Phase 5.0 runner is pinned to $expectedDatabaseName."
}

$resolvedBotRoot = [IO.Path]::GetFullPath($BotRoot).TrimEnd('\')
$resolvedTestRoot = [IO.Path]::GetFullPath($TestRoot).TrimEnd('\')
$botPrefix = $resolvedBotRoot + '\'

if (-not $resolvedTestRoot.StartsWith(
        $botPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'TestRoot must remain below BotRoot.'
}

$paths = [ordered]@{
    Preflight = Join-Path $PSScriptRoot '01_preflight.sql'
    Verify = Join-Path $PSScriptRoot '02_verify.sql'
    TestPathOverride = Join-Path $PSScriptRoot '03_apply_test_path_override.sql'
    ProtocolSmokes = Join-Path $PSScriptRoot '04_run_protocol_smokes.sql'
    Initializer = Join-Path $PSScriptRoot 'Initialize-Phase5RehearsalFile.ps1'
    MinimalFixture = Join-Path $PSScriptRoot 'fixtures\valid_minimal.csv'
    RecoveryFixture = Join-Path $PSScriptRoot 'fixtures\valid_recovery.csv'
    ForwardMigration = Join-Path $repoRoot (
        'migrations\20260728_001_phase5_immutable_import_file_handoff.sql'
    )
    Rollback = Join-Path $repoRoot (
        'migrations\rollback\' +
        '20260728_001_phase5_immutable_import_file_handoff_rollback.sql'
    )
}

foreach ($entry in $paths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
        throw "Missing Phase 5.0 input $($entry.Key): $($entry.Value)"
    }
}

$expectedFixtureContract = @{
    MinimalFixture = @{
        LengthBytes = 584
        Sha256 = '50AACFE4FA943377AA85924E6B2BD45248CEF3CE776DC09C2DA407903529801C'
    }
    RecoveryFixture = @{
        LengthBytes = 586
        Sha256 = '1F8E655DAC887547138BD0D4F7AE6BE55EB8EF4FB1E6F7D9B57B0D6BB2D7A99E'
    }
}

foreach ($fixtureKey in @('MinimalFixture', 'RecoveryFixture')) {
    $fixtureItem = Get-Item -LiteralPath $paths[$fixtureKey]
    $fixtureHash = (
        Get-FileHash -LiteralPath $fixtureItem.FullName -Algorithm SHA256
    ).Hash
    $expectedFixture = $expectedFixtureContract[$fixtureKey]

    if (
        $fixtureItem.Length -ne $expectedFixture.LengthBytes -or
        $fixtureHash -cne $expectedFixture.Sha256
    ) {
        throw (
            "$fixtureKey does not match its reviewed one-final-LF byte contract. " +
            "Expected $($expectedFixture.LengthBytes) bytes and " +
            "$($expectedFixture.Sha256); found $($fixtureItem.Length) bytes and " +
            "$fixtureHash."
        )
    }
}

$readyRoot = Join-Path $resolvedTestRoot 'Import_Ready'
$claimedRoot = Join-Path $resolvedTestRoot 'Import_Claimed'
$archiveRoot = Join-Path $resolvedTestRoot 'Import_Archive'
$evidenceRoot = Join-Path $resolvedTestRoot 'evidence'
$runId = 'phase5_0_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$runEvidenceRoot = Join-Path $evidenceRoot $runId
$transcriptPath = Join-Path $runEvidenceRoot 'transcript.log'
$receiptPath = Join-Path $runEvidenceRoot 'receipt.json'
$derivedPaths = [ordered]@{
    Preflight = Join-Path $runEvidenceRoot '01_preflight.test-root.sql'
    ForwardMigration = Join-Path $runEvidenceRoot 'forward_migration.test-root.sql'
    Rollback = Join-Path $runEvidenceRoot 'rollback.test-root.sql'
}
$productionSqlRoot = 'C:\discord_file_downloader\downloads\'
$testSqlRoot = $resolvedTestRoot + '\'

foreach ($directory in @(
    $resolvedTestRoot,
    $readyRoot,
    $claimedRoot,
    $archiveRoot,
    $evidenceRoot
)) {
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}

foreach ($workRoot in @($readyRoot, $claimedRoot, $archiveRoot)) {
    $existingFiles = @(
        Get-ChildItem -LiteralPath $workRoot -File -Recurse -ErrorAction Stop
    )
    if ($existingFiles.Count -gt 0) {
        throw (
            "Rehearsal work directory is not empty: $workRoot. " +
            'Inspect and reconcile it; the runner will not delete evidence.'
        )
    }
}

if (Test-Path -LiteralPath $runEvidenceRoot) {
    throw "Evidence directory already exists: $runEvidenceRoot"
}

New-Item -ItemType Directory -Path $runEvidenceRoot | Out-Null

$script:stepReceipts = [System.Collections.Generic.List[object]]::new()
$script:runStatus = 'running'
$script:runError = $null
$script:targetEvidence = $null
$script:finalEvidence = $null
$script:derivedSqlEvidence = @()
$script:transcriptStarted = $false

$inputEvidence = @(
    foreach ($entry in $paths.GetEnumerator()) {
        $item = Get-Item -LiteralPath $entry.Value
        [pscustomobject]@{
            Name = $entry.Key
            Path = $item.FullName
            LengthBytes = $item.Length
            Sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        }
    }
)

function ConvertTo-EvidenceValue {
    param($Value)

    if ($null -eq $Value -or $Value -is [DBNull]) {
        return $null
    }
    return $Value
}

function Invoke-RehearsalStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    $startedAt = [DateTime]::UtcNow
    Write-Host "START $Name"

    try {
        & $Action
        $completedAt = [DateTime]::UtcNow
        $script:stepReceipts.Add([pscustomobject]@{
            Name = $Name
            Status = 'passed'
            StartedAtUtc = $startedAt.ToString('o')
            CompletedAtUtc = $completedAt.ToString('o')
            DurationSeconds = [math]::Round(
                ($completedAt - $startedAt).TotalSeconds,
                3
            )
            Error = $null
        })
        Write-Host "PASS  $Name"
    }
    catch {
        $completedAt = [DateTime]::UtcNow
        $script:stepReceipts.Add([pscustomobject]@{
            Name = $Name
            Status = 'failed'
            StartedAtUtc = $startedAt.ToString('o')
            CompletedAtUtc = $completedAt.ToString('o')
            DurationSeconds = [math]::Round(
                ($completedAt - $startedAt).TotalSeconds,
                3
            )
            Error = $_.Exception.Message
        })
        Write-Host "FAIL  $Name"
        throw
    }
}

function Invoke-RehearsalSqlFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $result = @(
        Invoke-K98SqlFile `
            -ServerName $ServerName `
            -DatabaseName $DatabaseName `
            -InputFile $Path `
            -QueryTimeout 0
    )

    if ($result.Count -gt 0) {
        Write-Host ($result | Format-Table -AutoSize | Out-String)
    }
}

function New-TestBoundSqlFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $sourceText = [IO.File]::ReadAllText($SourcePath)
    $replacementCount = (
        [regex]::Matches(
            $sourceText,
            [regex]::Escape($productionSqlRoot)
        )
    ).Count

    if ($replacementCount -lt 1) {
        throw "Expected the canonical production root in $SourcePath."
    }

    $testBoundText = $sourceText.Replace($productionSqlRoot, $testSqlRoot)

    if (
        $testBoundText.Contains($productionSqlRoot) -or
        -not $testBoundText.Contains($testSqlRoot)
    ) {
        throw "Could not bind every filesystem path in $SourcePath to the rehearsal root."
    }

    [IO.File]::WriteAllText(
        $DestinationPath,
        $testBoundText,
        [Text.UTF8Encoding]::new($false)
    )

    $sourceItem = Get-Item -LiteralPath $SourcePath
    $destinationItem = Get-Item -LiteralPath $DestinationPath

    return [pscustomobject]@{
        SourcePath = $sourceItem.FullName
        SourceSha256 = (
            Get-FileHash -LiteralPath $sourceItem.FullName -Algorithm SHA256
        ).Hash
        DerivedPath = $destinationItem.FullName
        DerivedSha256 = (
            Get-FileHash -LiteralPath $destinationItem.FullName -Algorithm SHA256
        ).Hash
        ReplacementCount = $replacementCount
        ProductionRootAbsent = -not $testBoundText.Contains($productionSqlRoot)
        TestRootPresent = $testBoundText.Contains($testSqlRoot)
    }
}

function Get-ArchiveEvidence {
    return @(
        if (Test-Path -LiteralPath $archiveRoot -PathType Container) {
            foreach ($file in Get-ChildItem -LiteralPath $archiveRoot -File) {
                [pscustomobject]@{
                    Name = $file.Name
                    Path = $file.FullName
                    LengthBytes = $file.Length
                    Sha256 = (
                        Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
                    ).Hash
                }
            }
        }
    )
}

function Save-RehearsalReceipt {
    $receipt = [ordered]@{
        SchemaVersion = 'phase5-rehearsal/v1'
        RunId = $runId
        Status = $script:runStatus
        Error = $script:runError
        StartedAtUtc = $script:stepReceipts[0].StartedAtUtc
        CompletedAtUtc = [DateTime]::UtcNow.ToString('o')
        ComputerName = $env:COMPUTERNAME
        WindowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        ServerName = $ServerName
        DatabaseName = $DatabaseName
        TestRoot = $resolvedTestRoot
        TargetEvidence = $script:targetEvidence
        FinalEvidence = $script:finalEvidence
        InputFiles = $inputEvidence
        DerivedSqlFiles = @($script:derivedSqlEvidence)
        ArchiveFiles = @(Get-ArchiveEvidence)
        Steps = @($script:stepReceipts)
        TranscriptPath = $transcriptPath
    }

    $receipt |
        ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $receiptPath -Encoding utf8
}

$databaseLiteral = ConvertTo-K98SqlLiteral -Value $DatabaseName

try {
    Start-Transcript -LiteralPath $transcriptPath -Force | Out-Null
    $script:transcriptStarted = $true

    Invoke-RehearsalStep -Name 'target_guard' -Action {
        $targetRows = @(
            Invoke-K98SqlQuery `
                -ServerName $ServerName `
                -DatabaseName 'master' `
                -Query @"
DECLARE @TargetDatabase sysname = $databaseLiteral;

SELECT
    @@SERVERNAME AS SqlServerName,
    CONVERT(nvarchar(128), SERVERPROPERTY('MachineName')) AS MachineName,
    target_db.name AS DatabaseName,
    target_db.state_desc AS DatabaseState,
    target_db.user_access_desc AS UserAccess,
    ORIGINAL_LOGIN() AS OriginalLogin,
    SUSER_SNAME() AS LoginName,
    IS_SRVROLEMEMBER(N'sysadmin') AS IsSysadmin,
    (
        SELECT COUNT_BIG(*)
        FROM sys.dm_exec_sessions AS session_info
        WHERE session_info.is_user_process = 1
          AND session_info.database_id = target_db.database_id
          AND session_info.session_id <> @@SPID
    ) AS OtherUserSessions,
    (
        SELECT
            session_info.session_id AS SessionId,
            session_info.host_name AS HostName,
            session_info.host_process_id AS HostProcessId,
            session_info.program_name AS ProgramName,
            session_info.client_interface_name AS ClientInterfaceName,
            session_info.login_name AS LoginName,
            session_info.status AS SessionStatus,
            session_info.open_transaction_count AS OpenTransactionCount,
            request_info.status AS RequestStatus,
            request_info.command AS RequestCommand,
            request_info.wait_type AS WaitType,
            request_info.blocking_session_id AS BlockingSessionId
        FROM sys.dm_exec_sessions AS session_info
        LEFT JOIN sys.dm_exec_requests AS request_info
          ON request_info.session_id = session_info.session_id
        WHERE session_info.is_user_process = 1
          AND session_info.database_id = target_db.database_id
          AND session_info.session_id <> @@SPID
        ORDER BY session_info.session_id
        FOR JSON PATH
    ) AS OtherUserSessionsJson,
    (
        SELECT value_in_use
        FROM sys.configurations
        WHERE name = N'xp_cmdshell'
    ) AS XpCmdShellEnabled,
    (
        SELECT TOP (1) service_account
        FROM sys.dm_server_services
        WHERE servicename LIKE N'SQL Server (%'
        ORDER BY servicename
    ) AS SqlServiceAccount
FROM sys.databases AS target_db
WHERE target_db.name = @TargetDatabase;
"@ `
                -QueryTimeout 120
        )

        if ($targetRows.Count -ne 1) {
            throw "Expected one online target database named $DatabaseName."
        }

        $target = $targetRows[0]
        $otherUserSessionDetails = @(
            if (
                $null -ne $target.OtherUserSessionsJson -and
                $target.OtherUserSessionsJson -isnot [DBNull] -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$target.OtherUserSessionsJson
                )
            ) {
                [string]$target.OtherUserSessionsJson |
                    ConvertFrom-Json
            }
        )
        $script:targetEvidence = [ordered]@{
            SqlServerName = ConvertTo-EvidenceValue $target.SqlServerName
            MachineName = ConvertTo-EvidenceValue $target.MachineName
            DatabaseName = ConvertTo-EvidenceValue $target.DatabaseName
            DatabaseState = ConvertTo-EvidenceValue $target.DatabaseState
            UserAccess = ConvertTo-EvidenceValue $target.UserAccess
            OriginalLogin = ConvertTo-EvidenceValue $target.OriginalLogin
            LoginName = ConvertTo-EvidenceValue $target.LoginName
            IsSysadmin = [int]$target.IsSysadmin
            OtherUserSessions = [long]$target.OtherUserSessions
            OtherUserSessionDetails = @($otherUserSessionDetails)
            XpCmdShellEnabled = [int]$target.XpCmdShellEnabled
            SqlServiceAccount = ConvertTo-EvidenceValue $target.SqlServiceAccount
        }

        if ($target.DatabaseName -ceq 'ROK_TRACKER') {
            throw 'The Phase 5.0 runner refuses production ROK_TRACKER.'
        }
        if ($target.DatabaseName -cne $expectedDatabaseName) {
            throw "Unexpected target database: $($target.DatabaseName)"
        }
        if ($target.MachineName -ine $expectedComputerName) {
            throw "Unexpected SQL host: $($target.MachineName)"
        }
        if ($target.DatabaseState -ne 'ONLINE' -or $target.UserAccess -ne 'MULTI_USER') {
            throw 'The isolated database must be ONLINE and MULTI_USER.'
        }
        if ([int]$target.IsSysadmin -ne 1) {
            throw 'The rehearsal identity must be sysadmin for the reviewed file protocol.'
        }
        if ([int]$target.XpCmdShellEnabled -ne 1) {
            throw 'The protocol smokes require the existing xp_cmdshell test capability.'
        }
        if ([long]$target.OtherUserSessions -ne 0) {
            $sessionSummary = @(
                foreach ($session in $otherUserSessionDetails) {
                    (
                        'SPID {0}: program={1}; host={2}; process={3}; ' +
                        'login={4}; session={5}; request={6}'
                    ) -f
                        $session.SessionId,
                        $session.ProgramName,
                        $session.HostName,
                        $session.HostProcessId,
                        $session.LoginName,
                        $session.SessionStatus,
                        $session.RequestCommand
                }
            ) -join ' | '
            throw (
                "The isolated database has $($target.OtherUserSessions) other user session(s). " +
                "Close them before retrying. $sessionSummary"
            )
        }

        $initialRows = @(
            Invoke-K98SqlQuery `
                -ServerName $ServerName `
                -DatabaseName $DatabaseName `
                -Query @'
DECLARE @ClaimRows bigint = 0;

IF OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql
        N'SELECT @Rows = COUNT_BIG(*) FROM dbo.KS4_ImportFileClaim;',
        N'@Rows bigint OUTPUT',
        @Rows = @ClaimRows OUTPUT;
END;

SELECT
    DB_NAME() AS DatabaseName,
    @ClaimRows AS ExistingClaimRows,
    (
        SELECT COUNT_BIG(*)
        FROM dbo.KS4_ImportFileReceipt
    ) AS ExistingReceiptRows;
'@ `
                -QueryTimeout 120
        )

        if ($initialRows.Count -ne 1) {
            throw 'Could not read the initial claim and receipt state.'
        }
        if ([long]$initialRows[0].ExistingClaimRows -ne 0) {
            throw 'The runner requires zero existing Phase 5 claim rows.'
        }
        if ([long]$initialRows[0].ExistingReceiptRows -ne 0) {
            throw 'The runner requires zero existing immutable-file receipt rows.'
        }
    }

    Invoke-RehearsalStep -Name 'materialize_test_bound_sql' -Action {
        $script:derivedSqlEvidence = @(
            New-TestBoundSqlFile `
                -SourcePath $paths.Preflight `
                -DestinationPath $derivedPaths.Preflight
            New-TestBoundSqlFile `
                -SourcePath $paths.ForwardMigration `
                -DestinationPath $derivedPaths.ForwardMigration
            New-TestBoundSqlFile `
                -SourcePath $paths.Rollback `
                -DestinationPath $derivedPaths.Rollback
        )
    }

    Invoke-RehearsalStep -Name 'preflight_before_forward' -Action {
        Invoke-RehearsalSqlFile -Path $derivedPaths.Preflight
    }

    Invoke-RehearsalStep -Name 'forward_migration' -Action {
        Invoke-RehearsalSqlFile -Path $derivedPaths.ForwardMigration
    }

    Invoke-RehearsalStep -Name 'verify_after_forward' -Action {
        Invoke-RehearsalSqlFile -Path $paths.Verify
    }

    Invoke-RehearsalStep -Name 'apply_test_path_override' -Action {
        Invoke-RehearsalSqlFile -Path $paths.TestPathOverride
    }

    Invoke-RehearsalStep -Name 'stage_protocol_fixtures' -Action {
        & $paths.Initializer `
            -BotRoot $resolvedBotRoot `
            -TestRoot $resolvedTestRoot `
            -FixturePath $paths.MinimalFixture `
            -CompletedFileName 'stats_00000000000000000000000000000001.ready.csv'

        & $paths.Initializer `
            -BotRoot $resolvedBotRoot `
            -TestRoot $resolvedTestRoot `
            -FixturePath $paths.MinimalFixture `
            -CompletedFileName 'stats_00000000000000000000000000000002.ready.csv'

        & $paths.Initializer `
            -BotRoot $resolvedBotRoot `
            -TestRoot $resolvedTestRoot `
            -FixturePath $paths.RecoveryFixture `
            -CompletedFileName 'stats_00000000000000000000000000000003.ready.csv'
    }

    Invoke-RehearsalStep -Name 'protocol_smokes' -Action {
        Invoke-RehearsalSqlFile -Path $paths.ProtocolSmokes
    }

    Invoke-RehearsalStep -Name 'verify_after_protocol_smokes' -Action {
        Invoke-RehearsalSqlFile -Path $paths.Verify

        $stateRows = @(
            Invoke-K98SqlQuery `
                -ServerName $ServerName `
                -DatabaseName $DatabaseName `
                -Query @'
IF (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileClaim) <> 3
    THROW 52420, 'The runner expected exactly three protocol-smoke claims.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) <> 2
    THROW 52421, 'The runner expected exactly two digest-distinct receipts.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim
    WHERE ClaimStatus NOT IN (N'archived', N'duplicate_archived')
)
    THROW 52422, 'The runner found an unreconciled protocol-smoke claim.', 1;

SELECT
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileClaim) AS ClaimRows,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS ReceiptRows,
    (
        SELECT COUNT_BIG(*)
        FROM dbo.KS4_ImportFileClaim
        WHERE ClaimStatus = N'archived'
    ) AS ArchivedClaims,
    (
        SELECT COUNT_BIG(*)
        FROM dbo.KS4_ImportFileClaim
        WHERE ClaimStatus = N'duplicate_archived'
    ) AS DuplicateArchivedClaims;
'@ `
                -QueryTimeout 120
        )

        if ($stateRows.Count -ne 1) {
            throw 'The runner could not retain the protocol-smoke state receipt.'
        }

        $remainingReady = @(
            Get-ChildItem -LiteralPath $readyRoot -File -Recurse
        )
        $remainingClaimed = @(
            Get-ChildItem -LiteralPath $claimedRoot -File -Recurse
        )
        $archivedFiles = @(
            Get-ChildItem -LiteralPath $archiveRoot -File
        )
        $expectedArchiveNames = @(
            'stats_00000000000000000000000000000001.ready.csv',
            'stats_00000000000000000000000000000002.ready.csv',
            'stats_00000000000000000000000000000003.ready.csv'
        )
        $actualArchiveNames = @(
            $archivedFiles.Name | Sort-Object
        )

        if ($remainingReady.Count -ne 0 -or $remainingClaimed.Count -ne 0) {
            throw 'Protocol smokes left a file in Ready or Claimed.'
        }
        if (
            $actualArchiveNames.Count -ne $expectedArchiveNames.Count -or
            (Compare-Object $expectedArchiveNames $actualArchiveNames)
        ) {
            throw 'Protocol smokes did not archive the exact three rehearsal identities.'
        }
    }

    Invoke-RehearsalStep -Name 'rollback' -Action {
        Invoke-RehearsalSqlFile -Path $derivedPaths.Rollback
    }

    Invoke-RehearsalStep -Name 'preflight_after_rollback' -Action {
        Invoke-RehearsalSqlFile -Path $derivedPaths.Preflight
    }

    Invoke-RehearsalStep -Name 'clean_reapply' -Action {
        Invoke-RehearsalSqlFile -Path $derivedPaths.ForwardMigration
    }

    Invoke-RehearsalStep -Name 'final_verify' -Action {
        Invoke-RehearsalSqlFile -Path $paths.Verify

        $finalRows = @(
            Invoke-K98SqlQuery `
                -ServerName $ServerName `
                -DatabaseName $DatabaseName `
                -Query @'
IF DB_NAME() = N'ROK_TRACKER'
    THROW 52430, 'Final Phase 5.0 evidence refuses production.', 1;

IF OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NULL
    THROW 52431, 'Clean reapply did not restore the immutable claim entry point.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim
    WHERE ClaimStatus NOT IN (N'archived', N'duplicate_archived')
)
    THROW 52432, 'Clean reapply found unreconciled retained claim evidence.', 1;

SELECT
    DB_NAME() AS DatabaseName,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileClaim) AS ClaimRows,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS ReceiptRows,
    CONVERT(
        char(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(
                varbinary(max),
                OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE'))
            )
        ),
        2
    ) AS ClaimDefinitionSha256,
    CONVERT(
        char(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(
                varbinary(max),
                OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE'))
            )
        ),
        2
    ) AS ImportCoreDefinitionSha256,
    CONVERT(
        char(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(
                varbinary(max),
                OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2'))
            )
        ),
        2
    ) AS UpdateAll2DefinitionSha256;
'@ `
                -QueryTimeout 120
        )

        if ($finalRows.Count -ne 1) {
            throw 'The runner could not retain final SQL evidence.'
        }

        $final = $finalRows[0]
        $script:finalEvidence = [ordered]@{
            DatabaseName = ConvertTo-EvidenceValue $final.DatabaseName
            ClaimRows = [long]$final.ClaimRows
            ReceiptRows = [long]$final.ReceiptRows
            ClaimDefinitionSha256 =
                ConvertTo-EvidenceValue $final.ClaimDefinitionSha256
            ImportCoreDefinitionSha256 =
                ConvertTo-EvidenceValue $final.ImportCoreDefinitionSha256
            UpdateAll2DefinitionSha256 =
                ConvertTo-EvidenceValue $final.UpdateAll2DefinitionSha256
        }
    }

    $script:runStatus = 'passed'
    Write-Host "Phase 5.0 rehearsal passed. Evidence: $runEvidenceRoot"
}
catch {
    $script:runStatus = 'failed'
    $script:runError = $_.Exception.Message
    Write-Host "Phase 5.0 rehearsal failed: $script:runError" -ForegroundColor Red
    throw
}
finally {
    if ($script:transcriptStarted) {
        Stop-Transcript | Out-Null
    }

    if ($script:stepReceipts.Count -gt 0) {
        Save-RehearsalReceipt
        Write-Host "Phase 5.0 receipt: $receiptPath"
    }
}
