[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Get-SqlSource {
    param([Parameter(Mandatory)][string]$RelativePath)
    return (Get-Content -Raw -LiteralPath (Join-Path $repoRoot $RelativePath)).Replace("`r`n", "`n")
}

function Get-ProcedureBody {
    param([Parameter(Mandatory)][string]$Source)
    $sourceNormalized = $Source.Replace("`r`n", "`n").TrimEnd()
    $marker = 'ALTER PROCEDURE'
    $start = $sourceNormalized.IndexOf($marker, [StringComparison]::Ordinal)
    if ($start -lt 0) {
        throw 'Canonical procedure has no ALTER PROCEDURE marker.'
    }
    $body = 'CREATE OR ALTER PROCEDURE' + $sourceNormalized.Substring($start + $marker.Length)
    return (($body -split "`n" | ForEach-Object { $_.TrimEnd() }) -join "`n").TrimEnd()
}

function Get-SpExecuteBodies {
    param([Parameter(Mandatory)][string]$Source)

    $marker = "EXEC sys.sp_executesql N'"
    $bodies = [System.Collections.Generic.List[string]]::new()
    $searchFrom = 0

    while ($true) {
        $start = $Source.IndexOf($marker, $searchFrom, [StringComparison]::Ordinal)
        if ($start -lt 0) {
            break
        }

        $position = $start + $marker.Length
        $builder = [System.Text.StringBuilder]::new()

        while ($position -lt $Source.Length) {
            $character = $Source[$position]
            if ($character -eq "'") {
                if ($position + 1 -lt $Source.Length -and $Source[$position + 1] -eq "'") {
                    [void]$builder.Append("'")
                    $position += 2
                    continue
                }
                break
            }

            [void]$builder.Append($character)
            $position += 1
        }

        if ($position -ge $Source.Length) {
            throw 'Unterminated sp_executesql string literal.'
        }

        $bodies.Add($builder.ToString().Replace("`r`n", "`n").TrimEnd())
        $searchFrom = $position + 1
    }

    return $bodies
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Value)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )
    if ($Source -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )
    if ($Source -match $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-Before {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$First,
        [Parameter(Mandatory)][string]$Second,
        [Parameter(Mandatory)][string]$Message
    )
    $firstIndex = $Source.IndexOf($First, [StringComparison]::Ordinal)
    $secondIndex = $Source.IndexOf($Second, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
        $failures.Add($Message)
    }
}

$excel = Get-SqlSource 'sql_schema\dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql'
$stats = Get-SqlSource 'sql_schema\dbo.SP_Stats_for_Upload.StoredProcedure.sql'
$migration = Get-SqlSource 'migrations\20260827_002_align_kvk_healed_window_and_stats_refresh_provenance.sql'
$rollback = Get-SqlSource 'migrations\rollback\20260827_002_align_kvk_healed_window_and_stats_refresh_provenance_rollback.sql'

Assert-Contains $excel 'WHERE ht\.DeltaOrder > @PRE_PASS_4_SCAN AND ht\.DeltaOrder <= @KVK_END_SCAN' 'Healed aggregation must start strictly after PRE_PASS_4_SCAN.'
Assert-NotContains $excel 'WHERE ht\.DeltaOrder > @Scan AND ht\.DeltaOrder <= @KVK_END_SCAN' 'Healed aggregation must not use the matchmaking snapshot lower bound.'
Assert-Contains $excel '@FinalScanOrder = @LatestScanToUse' 'Final-report provenance must retain the materialized final scan.'
Assert-Before $excel 'EXEC dbo.usp_RecordKvkFinalReportCompletion' 'COMMIT TRANSACTION' 'Output header must be recorded before the output transaction commits.'

Assert-Contains $stats 'K98:StatsForUpload:Publish' 'Stats publication must use the scoped application lock.'
Assert-Contains $stats 'EXEC dbo\.ACQUIRE_KS4_IMPORT_LOCK' 'Stats publication must share the KS4 import mutex.'
Assert-Before $stats 'EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK' 'K98:StatsForUpload:Publish' 'The import mutex must be acquired before the publication lock.'
Assert-Before $stats 'EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK' 'SELECT @MaxScan = MAX(SCANORDER)' 'Eligibility must be sampled only after the import mutex is acquired.'
Assert-Contains $stats '@LockOwner = N''Transaction''' 'Stats publication lock must be transaction-owned.'
Assert-Contains $stats '@LockTimeout = 60000' 'Stats publication lock must use the approved 60-second timeout.'
Assert-Contains $stats 'SAVE TRANSACTION StatsForUploadPublishSave' 'Stats publication must support caller-owned transactions.'
Assert-Contains $stats '@ExpectedFinalScan = CASE[\s\S]+@MaxScan > @KvkEndScan' 'Expected final scan must be capped by KVK_END_SCAN.'
Assert-Contains $stats 'FROM dbo\.KingdomScanData4 WITH \(UPDLOCK, HOLDLOCK\)' 'The eligibility snapshot must be stable through publication.'
Assert-Contains $stats 'FROM dbo\.KVKFinalReportHeader' 'Stats publication must consume the existing final-report header.'
Assert-Contains $stats '@HeaderState <> N''OUTPUT_COMPLETE''' 'Stats publication must require OUTPUT_COMPLETE provenance.'
Assert-Contains $stats 'WITH \(HOLDLOCK\)' 'Source reads must be held through publication.'
Assert-Contains $stats 'WITH \(UPDLOCK, HOLDLOCK\)' 'Header provenance must be locked and rechecked before target mutation.'
Assert-Contains $stats '@pProvenScanDate' 'LAST_REFRESH must be supplied from the proven final scan date.'
Assert-Before $stats 'INTO #StatsForUploadCandidate' 'DELETE FROM dbo.STATS_FOR_UPLOAD' 'The validated candidate must be built before target mutation.'
Assert-Before $stats 'SET @FailureStage = N''header-recheck''' 'DELETE FROM dbo.STATS_FOR_UPLOAD' 'Provenance must be rechecked before target mutation.'
Assert-Contains $stats 'UPDATE STATISTICS dbo\.STATS_FOR_UPLOAD WITH FULLSCAN' 'Target statistics must be updated inside the protected publication path.'
Assert-NotContains $stats 'CHECKPOINT|WAITFOR DELAY|TRUNCATE TABLE dbo\.STATS_FOR_UPLOAD|SELECT MAX\(ScanDate\) FROM dbo\.KingdomScanData4' 'Unsafe legacy freshness and replacement behavior must be absent.'

$forwardBodies = @(Get-SpExecuteBodies $migration)
if ($forwardBodies.Count -ne 2) {
    $failures.Add('Forward migration must contain exactly two procedure deployments.')
}
else {
    if ($forwardBodies[0] -cne (Get-ProcedureBody $excel)) {
        $failures.Add('Forward migration copy of sp_ExcelOutput_ByKVK is not identical to the canonical schema snapshot.')
    }
    if ($forwardBodies[1] -cne (Get-ProcedureBody $stats)) {
        $failures.Add('Forward migration copy of SP_Stats_for_Upload is not identical to the canonical schema snapshot.')
    }
}

$rollbackBodies = @(Get-SpExecuteBodies $rollback)
$expectedRollbackHashes = @(
    '86244df4f803acb0c3eb9dc355f71730b37065506ddfc24f0b2d8f3ed6205b37',
    '26c40e9b721dc5baf0e8b988d29bcf00b82ed10327ea59031032986c1f5dd8f8'
)
if ($rollbackBodies.Count -ne 2) {
    $failures.Add('Rollback must contain exactly two prior procedure definitions.')
}
else {
    for ($index = 0; $index -lt $expectedRollbackHashes.Count; $index++) {
        if ((Get-Sha256 $rollbackBodies[$index]) -ne $expectedRollbackHashes[$index]) {
            $failures.Add("Rollback procedure definition $index does not match the exact pre-migration snapshot.")
        }
    }
}

Assert-Contains $migration 'DataChange:\s+No' 'Forward migration must not regenerate or publish data implicitly.'
Assert-Contains $migration 'OBJECT_ID\(N''dbo\.ACQUIRE_KS4_IMPORT_LOCK'', N''P''\)' 'Forward migration must preflight the shared import-lock helper.'
Assert-Contains $migration 'BEGIN TRANSACTION' 'Forward procedure deployment must be transactional.'
Assert-Contains $migration 'Required post-deployment repair' 'Forward migration must document the explicit current-output repair.'
Assert-Contains $rollback 'preserves all table data' 'Rollback must state its data-preservation contract.'
Assert-Contains $rollback 'regenerate the current KVK output, STATS_FOR_UPLOAD and bot cache' 'Rollback must require coordinated regeneration.'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'KVK healed-window and provenance-safe stats refresh contract checks passed.'
