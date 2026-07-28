[CmdletBinding()]
param(
    [string]$BotRoot = 'C:\discord_file_downloader',
    [string]$TestRoot = 'C:\discord_file_downloader\downloads_test_phase5_rehearsal',
    [string]$FixturePath,
    [ValidatePattern('^stats_[0-9a-f]{32}\.ready\.csv$')]
    [string]$CompletedFileName = 'stats_00000000000000000000000000000001.ready.csv'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($FixturePath)) {
    $FixturePath = Join-Path $PSScriptRoot 'fixtures\valid_minimal.csv'
}

$resolvedBotRoot = [IO.Path]::GetFullPath($BotRoot).TrimEnd('\')
$resolvedTestRoot = [IO.Path]::GetFullPath($TestRoot).TrimEnd('\')
$expectedPrefix = $resolvedBotRoot + '\'

if (-not $resolvedTestRoot.StartsWith(
        $expectedPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "TestRoot must remain below BotRoot."
}

$resolvedFixture = (Resolve-Path -LiteralPath $FixturePath).ProviderPath
$readyRoot = Join-Path $resolvedTestRoot 'Import_Ready'
$claimedRoot = Join-Path $resolvedTestRoot 'Import_Claimed'
$archiveRoot = Join-Path $resolvedTestRoot 'Import_Archive'

foreach ($directory in @($readyRoot, $claimedRoot, $archiveRoot)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$readyPath = Join-Path $readyRoot $CompletedFileName
$claimedPath = Join-Path $claimedRoot $CompletedFileName
$archivePath = Join-Path $archiveRoot $CompletedFileName
$temporaryPath = Join-Path $readyRoot ('.' + $CompletedFileName + '.tmp')

foreach ($path in @($readyPath, $claimedPath, $archivePath, $temporaryPath)) {
    if (Test-Path -LiteralPath $path) {
        throw "Rehearsal identity already exists: $path"
    }
}

Copy-Item -LiteralPath $resolvedFixture -Destination $temporaryPath
Move-Item -LiteralPath $temporaryPath -Destination $readyPath

$digest = (Get-FileHash -LiteralPath $readyPath -Algorithm SHA256).Hash

[pscustomobject]@{
    CompletedFileName = $CompletedFileName
    ReadyPath = $readyPath
    Sha256 = $digest
}
