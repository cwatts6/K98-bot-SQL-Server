[CmdletBinding()]
param(
    [string]$FixtureRoot = 'C:\discord_file_downloader\downloads_test\fixtures',
    [string]$GeneratedRoot = 'C:\discord_file_downloader\downloads_test_phase3_rehearsal\generated'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$variants = @(
    @{
        Name = 'corrected_boundary'
        Source = 'valid_representative.csv'
        Target = 'corrected_boundary.csv'
        HeaderMarker = 'upd_p3_301'
    },
    @{
        Name = 'direct_one'
        Source = 'valid_representative.csv'
        Target = 'direct_one.csv'
        HeaderMarker = 'upd_p3_302'
    },
    @{
        Name = 'direct_two'
        Source = 'valid_representative.csv'
        Target = 'direct_two.csv'
        HeaderMarker = 'upd_p3_303'
    },
    @{
        Name = 'legacy_update_all'
        Source = 'valid_representative.csv'
        Target = 'legacy_update_all.csv'
        HeaderMarker = 'upd_p3_304'
    },
    @{
        Name = 'phase_b_failure'
        Source = 'valid_representative.csv'
        Target = 'phase_b_failure.csv'
        HeaderMarker = 'upd_p3_305'
    }
)

New-Item -ItemType Directory -Path $GeneratedRoot -Force | Out-Null

$results = foreach ($variant in $variants) {
    $sourcePath = Join-Path $FixtureRoot $variant.Source
    $targetPath = Join-Path $GeneratedRoot $variant.Target

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Fixture source does not exist: $sourcePath"
    }

    # Preserve every data byte exactly. SQL Server ignores the header because
    # BULK INSERT uses FIRSTROW = 2, so a same-length header marker produces a
    # distinct digest without changing the parser-visible row shape.
    $sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
    $needle = [Text.Encoding]::ASCII.GetBytes('updated_on')
    $marker = [Text.Encoding]::ASCII.GetBytes($variant.HeaderMarker)
    if ($marker.Length -ne $needle.Length) {
        throw "Header marker $($variant.HeaderMarker) must be exactly $($needle.Length) bytes."
    }

    $firstLineFeed = [Array]::IndexOf($sourceBytes, [byte]0x0A)
    $needleIndex = -1
    for ($index = 0; $index -le $firstLineFeed - $needle.Length; $index++) {
        $matches = $true
        for ($offset = 0; $offset -lt $needle.Length; $offset++) {
            if ($sourceBytes[$index + $offset] -ne $needle[$offset]) {
                $matches = $false
                break
            }
        }

        if ($matches) {
            $needleIndex = $index
            break
        }
    }

    if ($needleIndex -lt 0) {
        throw "Fixture $sourcePath does not contain the expected updated_on header."
    }

    $targetBytes = [byte[]]$sourceBytes.Clone()
    [Array]::Copy($marker, 0, $targetBytes, $needleIndex, $marker.Length)
    [IO.File]::WriteAllBytes($targetPath, $targetBytes)

    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        throw "Generated fixture does not exist: $targetPath"
    }

    $rows = @(Import-Csv -LiteralPath $targetPath)
    if ($rows.Count -ne 411) {
        throw "Generated fixture $targetPath has $($rows.Count) data rows; expected 411."
    }
    if ($rows.Where({ [string]::IsNullOrWhiteSpace($_.'Governor ID') }).Count -ne 0) {
        throw "Generated fixture $targetPath contains a blank Governor ID."
    }
    if ($rows.Where({ [string]::IsNullOrWhiteSpace($_.Power) }).Count -ne 0) {
        throw "Generated fixture $targetPath contains a blank Power."
    }

    [pscustomobject]@{
        Variant = $variant.Name
        HeaderMarker = $variant.HeaderMarker
        SourcePath = $sourcePath
        TargetPath = $targetPath
        DataRows = $rows.Count
        Sha256 = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    }
}

$duplicateHashes = $results | Group-Object Sha256 | Where-Object Count -gt 1
if ($duplicateHashes) {
    throw 'Generated fixtures are not byte-distinct.'
}

$results | Format-Table -AutoSize
Write-Host 'Phase 3 extended fixture preparation passed.'
