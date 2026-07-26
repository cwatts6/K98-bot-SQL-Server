[CmdletBinding()]
param(
    [string] $FixtureSourceDirectory = (
        Join-Path $PSScriptRoot 'fixtures'
    ),

    [switch] $ReplaceExistingFixtures
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
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $testRoot 'evidence')
)
$activeFixture = [System.IO.Path]::GetFullPath(
    (Join-Path $testRoot 'stats.csv')
)
$sourceRoot = [System.IO.Path]::GetFullPath(
    $FixtureSourceDirectory
)

$fixtureNames = @(
    'valid_representative.csv'
    'valid_boundary_unicode_optional_blanks.csv'
    'invalid_required_numeric.csv'
    'fixtures_manifest.json'
)

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Fixture source directory does not exist: $sourceRoot"
}

foreach ($fixtureName in $fixtureNames) {
    $sourcePath = Join-Path $sourceRoot $fixtureName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required fixture package file is missing: $sourcePath"
    }
}

if (Test-Path -LiteralPath $activeFixture -PathType Leaf) {
    throw "Active stats.csv already exists. Collect it before initialization."
}

foreach ($directory in @(
    $testRoot
    $fixturesRoot
    $archiveRoot
    $evidenceRoot
)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$installed = foreach ($fixtureName in $fixtureNames) {
    $sourcePath = Join-Path $sourceRoot $fixtureName
    $destinationPath = Join-Path $fixturesRoot $fixtureName

    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        $sourceHash = (
            Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256
        ).Hash
        $destinationHash = (
            Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
        ).Hash

        if ($sourceHash -eq $destinationHash) {
            [pscustomobject]@{
                Fixture = $fixtureName
                Action = 'Unchanged'
                Sha256 = $destinationHash
            }
            continue
        }

        if (-not $ReplaceExistingFixtures) {
            throw (
                "Fixture already exists with different content: " +
                "$destinationPath. Re-run with " +
                '-ReplaceExistingFixtures only after reviewing it.'
            )
        }
    }

    Copy-Item `
        -LiteralPath $sourcePath `
        -Destination $destinationPath `
        -Force:$ReplaceExistingFixtures

    [pscustomobject]@{
        Fixture = $fixtureName
        Action = 'Installed'
        Sha256 = (
            Get-FileHash `
                -LiteralPath $destinationPath `
                -Algorithm SHA256
        ).Hash
    }
}

$installed
