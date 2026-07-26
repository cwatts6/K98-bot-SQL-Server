[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $FixturePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testRoot = [System.IO.Path]::GetFullPath(
    'C:\discord_file_downloader\downloads_test'
)
$fixturesRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $testRoot 'fixtures')
)
$archiveRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $testRoot 'Import_Archive')
)
$activeFixture = [System.IO.Path]::GetFullPath(
    (Join-Path $testRoot 'stats.csv')
)
$resolvedFixture = [System.IO.Path]::GetFullPath($FixturePath)
$fixturesPrefix = $fixturesRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar

if (-not $resolvedFixture.StartsWith(
    $fixturesPrefix,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Fixture must be below $fixturesRoot."
}

if (-not (Test-Path -LiteralPath $resolvedFixture -PathType Leaf)) {
    throw "Fixture does not exist: $resolvedFixture"
}

if ([System.IO.Path]::GetExtension($resolvedFixture) -ne '.csv') {
    throw 'Fixture must have a .csv extension.'
}

New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null

if (Test-Path -LiteralPath $activeFixture) {
    throw "Active stats.csv already exists. Collect it before staging another fixture."
}

$archiveFiles = @(
    Get-ChildItem -LiteralPath $archiveRoot -File -ErrorAction Stop
)
if ($archiveFiles.Count -ne 0) {
    throw 'Import_Archive contains uncollected evidence. Collect it before staging another fixture.'
}

Copy-Item -LiteralPath $resolvedFixture -Destination $activeFixture

$hash = Get-FileHash -LiteralPath $activeFixture -Algorithm SHA256

[pscustomobject]@{
    FixtureSource = $resolvedFixture
    ActiveFixture = $activeFixture
    LengthBytes = (Get-Item -LiteralPath $activeFixture).Length
    Sha256 = $hash.Hash
    StagedAtUtc = [DateTime]::UtcNow.ToString('o')
}
