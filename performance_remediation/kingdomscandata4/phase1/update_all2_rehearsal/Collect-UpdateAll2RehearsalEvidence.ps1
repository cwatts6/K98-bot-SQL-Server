[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
    [string] $RunLabel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testRoot = [System.IO.Path]::GetFullPath(
    'C:\discord_file_downloader\downloads_test'
)
$archiveRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $testRoot 'Import_Archive')
)
$activeFixture = [System.IO.Path]::GetFullPath(
    (Join-Path $testRoot 'stats.csv')
)
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $testRoot 'evidence')
)
$runEvidence = [System.IO.Path]::GetFullPath(
    (Join-Path $evidenceRoot $RunLabel)
)
$evidencePrefix = $evidenceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar

if (-not $runEvidence.StartsWith(
    $evidencePrefix,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw 'Resolved evidence path escaped the configured evidence root.'
}

if (Test-Path -LiteralPath $runEvidence) {
    throw "Evidence directory already exists: $runEvidence"
}

New-Item -ItemType Directory -Path $runEvidence -Force | Out-Null

$collectedPaths = [System.Collections.Generic.List[string]]::new()

if (Test-Path -LiteralPath $activeFixture -PathType Leaf) {
    $unconsumedDestination = Join-Path $runEvidence 'unconsumed_stats.csv'
    Move-Item -LiteralPath $activeFixture -Destination $unconsumedDestination
    $collectedPaths.Add($unconsumedDestination)
}

if (Test-Path -LiteralPath $archiveRoot -PathType Container) {
    foreach ($archiveFile in Get-ChildItem -LiteralPath $archiveRoot -File) {
        $destination = Join-Path $runEvidence (
            'archive_' + $archiveFile.Name
        )
        Move-Item -LiteralPath $archiveFile.FullName -Destination $destination
        $collectedPaths.Add($destination)
    }
}

$fileEvidence = @(
    foreach ($path in $collectedPaths) {
        $item = Get-Item -LiteralPath $path
        $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
        [pscustomobject]@{
            Name = $item.Name
            LengthBytes = $item.Length
            Sha256 = $hash.Hash
        }
    }
)

$manifest = [pscustomobject]@{
    RunLabel = $RunLabel
    CollectedAtUtc = [DateTime]::UtcNow.ToString('o')
    Files = $fileEvidence
}

$manifestPath = Join-Path $runEvidence 'manifest.json'
$manifest |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $manifestPath -Encoding utf8

$manifest
