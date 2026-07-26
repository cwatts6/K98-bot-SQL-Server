[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$seedPath = Join-Path $PSScriptRoot "14_create_update_all2_benchmark_seed_backup.sql"
$restorePath = Join-Path $PSScriptRoot "15_restore_update_all2_benchmark_database.sql"

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Text.IndexOf($Expected, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw $Message
    }
}

function Assert-Before {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Earlier,
        [Parameter(Mandatory = $true)][string]$Later,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $earlierIndex = $Text.IndexOf($Earlier, [StringComparison]::OrdinalIgnoreCase)
    $laterIndex = $Text.IndexOf($Later, [StringComparison]::OrdinalIgnoreCase)
    if ($earlierIndex -lt 0 -or $laterIndex -lt 0 -or $earlierIndex -ge $laterIndex) {
        throw $Message
    }
}

function Assert-UniqueThrowCodes {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $codes = @(
        [regex]::Matches($Text, "(?im)\bTHROW\s+(?<code>51\d{3})\s*,") |
            ForEach-Object { $_.Groups["code"].Value }
    )
    $duplicates = @(
        $codes |
            Group-Object |
            Where-Object Count -gt 1 |
            ForEach-Object Name
    )
    if ($duplicates.Count -gt 0) {
        throw "$Label reuses THROW codes: $($duplicates -join ', ')."
    }
}

$seedSql = Get-Content -Raw -LiteralPath $seedPath
$restoreSql = Get-Content -Raw -LiteralPath $restorePath

Assert-Contains -Text $seedSql `
    -Expected "backup_set.backup_set_uuid" `
    -Message "Seed creation does not capture the trusted backup-set GUID from msdb."
Assert-Contains -Text $seedSql `
    -Expected "@BackupSetGuid AS BackupSetGUID" `
    -Message "Seed creation does not emit the backup-set GUID in its retained receipt."
Assert-Before -Text $seedSql `
    -Earlier "RESTORE VERIFYONLY" `
    -Later "SELECT TOP (1)" `
    -Message "Seed creation must verify the backup before recording its msdb identity."

Assert-Contains -Text $restoreSql `
    -Expected "DECLARE @ConfirmRestoreBenchmark bit = 0;" `
    -Message "Benchmark restore confirmation must default to refusal."
Assert-Contains -Text $restoreSql `
    -Expected "DECLARE @ApprovedBackupSetGuid uniqueidentifier = NULL;" `
    -Message "Benchmark restore must default to no approved seed receipt."
Assert-Before -Text $restoreSql `
    -Earlier "DROP TABLE IF EXISTS #SeedBackupHeader;" `
    -Later "CREATE TABLE #SeedBackupHeader" `
    -Message "Benchmark restore does not clear its own stale session-local header table before reuse."
Assert-Contains -Text $restoreSql `
    -Expected "backup_set.backup_set_uuid = @ApprovedBackupSetGuid" `
    -Message "Benchmark restore does not pin msdb lookup to the approved seed receipt."
Assert-Contains -Text $restoreSql `
    -Expected "N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK'" `
    -Message "Benchmark restore lost its exact non-production target."
Assert-Contains -Text $restoreSql `
    -Expected "actual.BackupSetGUID = @ExpectedBackupSetGuid" `
    -Message "Benchmark restore does not compare the file and msdb backup-set GUIDs."
Assert-Contains -Text $restoreSql `
    -Expected "actual.FamilyGUID = @ExpectedFamilyGuid" `
    -Message "Benchmark restore does not compare the database family GUID."
Assert-Contains -Text $restoreSql `
    -Expected "actual.FirstLSN = @ExpectedFirstLsn" `
    -Message "Benchmark restore does not compare the first LSN."
Assert-Contains -Text $restoreSql `
    -Expected "actual.LastLSN = @ExpectedLastLsn" `
    -Message "Benchmark restore does not compare the last LSN."
Assert-Contains -Text $restoreSql `
    -Expected "actual.BackupSize = @ExpectedBackupSize" `
    -Message "Benchmark restore does not compare the backup size."
Assert-Contains -Text $restoreSql `
    -Expected "actual.HasBackupChecksums = 1" `
    -Message "Benchmark restore does not require backup checksums in the file header."
Assert-Contains -Text $restoreSql `
    -Expected "actual.IsCopyOnly = 1" `
    -Message "Benchmark restore does not require a copy-only file header."

Assert-Before -Text $restoreSql `
    -Earlier "RESTORE HEADERONLY" `
    -Later "ALTER DATABASE " `
    -Message "Backup header validation must finish before target database mutation."
Assert-Before -Text $restoreSql `
    -Earlier "actual.BackupSetGUID = @ExpectedBackupSetGuid" `
    -Later "RESTORE VERIFYONLY" `
    -Message "Backup identity comparison must finish before the full verification pass."
Assert-Before -Text $restoreSql `
    -Earlier "RESTORE VERIFYONLY" `
    -Later "ALTER DATABASE " `
    -Message "RESTORE VERIFYONLY must finish before SINGLE_USER and WITH REPLACE."
Assert-Contains -Text $restoreSql `
    -Expected "FROM msdb.dbo.restorehistory AS restore_history" `
    -Message "Benchmark restore does not bind the completed restore to msdb restore history."
Assert-Contains -Text $restoreSql `
    -Expected "FROM sys.database_recovery_status AS recovery_status" `
    -Message "Benchmark restore does not inspect the restored target database and family GUIDs."
Assert-Contains -Text $restoreSql `
    -Expected "@ActualRestoredBackupSetId <> @ExpectedBackupSetId" `
    -Message "Benchmark restore does not compare the consumed and trusted backup-set IDs."
Assert-Contains -Text $restoreSql `
    -Expected "@ActualRestoredTargetDatabaseGuid IS NULL" `
    -Message "Benchmark restore does not require a materialized target database identity."
Assert-Contains -Text $restoreSql `
    -Expected "@ActualRestoredFamilyGuid <> @ExpectedFamilyGuid" `
    -Message "Benchmark restore does not bind the restored database family to the trusted seed."
if ($restoreSql.IndexOf(
        "@ActualRestoredTargetDatabaseGuid <> @ExpectedDatabaseGuid",
        [StringComparison]::OrdinalIgnoreCase) -ge 0) {
    throw "Benchmark restore incorrectly compares the target database GUID with the source backup BindingID."
}
Assert-Contains -Text $restoreSql `
    -Expected "restore_history.restore_history_id > @PriorRestoreHistoryId" `
    -Message "Benchmark restore does not exclude stale restore-history receipts."
Assert-Before -Text $restoreSql `
    -Earlier "EXEC sys.sp_executesql @RestoreSql;" `
    -Later "restore_history.restore_history_id > @PriorRestoreHistoryId" `
    -Message "Restore-history binding must inspect the completed restore."
Assert-Before -Text $restoreSql `
    -Earlier "restore_history.restore_history_id > @PriorRestoreHistoryId" `
    -Later "DECLARE @VerifySql" `
    -Message "Restore-history binding must finish before post-restore benchmark verification."

Assert-UniqueThrowCodes -Text $seedSql -Label "Seed creation"
Assert-UniqueThrowCodes -Text $restoreSql -Label "Benchmark restore"

[pscustomobject]@{
    Validation = "Passed"
    SeedScript = $seedPath
    RestoreScript = $restorePath
    IdentityControl = "Approved BackupSetGUID, source binding and family GUIDs, LSNs, size, finish time, position, restore history, materialized target database GUID"
    DestructiveOrder = "Header identity and VERIFYONLY precede mutation; restore history binds the consumed set before benchmark use"
}
