param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
# Offline tests only. Historical permission manifests are immutable installation
# evidence, not the allowlist for the separately qualified Phase 1 report bodies.
$baseline='dad628c7a353cc6391868d097a6ae5fb7a8d9e84'
$folder=Join-Path ([IO.Path]::GetTempPath()) ('k98-phase1-historical-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($folder)
$archive=Join-Path $folder 'baseline.zip'
$checkout=Join-Path $folder 'source'
& git -C $RepositoryRoot archive --format=zip --output=$archive $baseline
if($LASTEXITCODE -ne 0){throw 'Pinned historical SQL source is unavailable'}
Expand-Archive -LiteralPath $archive -DestinationPath $checkout
& (Join-Path $checkout 'deploy/Test-ExportLegacyDirectPermissionContracts.ps1') -RepositoryRoot $checkout
& (Join-Path $checkout 'deploy/Test-KvkTargetPublicationContract.ps1')
# The current package must still satisfy its independent fixed-byte admission.
& (Join-Path $RepositoryRoot 'tests/test_p02_phase1_release_runner.ps1')
Write-Output "PASS: immutable historical permission contracts at $baseline and current fixed Phase 1 package. No SQL or network connection. Fixture retained: $folder"
