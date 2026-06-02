param(
    [string]$ServerName = "MINI_AMD",
    [string]$DatabaseName = "ROK_TRACKER",
    [string]$RepoPath,
    [string]$BackupPath = "C:\sql_backup",
    [int]$MaxFullBackupAgeHours = 24,
    [int]$MaxDiffBackupAgeHours = 8,
    [int]$MaxLogBackupAgeMinutes = 30,
    [switch]$WarnOnly
)

. "$PSScriptRoot\SqlDeploy.Common.ps1"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Get-K98RepoRoot
}

$repoRoot = (Resolve-Path $RepoPath).ProviderPath
$started = Get-Date
$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Get-BackupRowValue {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)][string]$Name
    )

    if ($Row -is [System.Data.DataRow]) {
        return $Row[$Name]
    }

    return $Row.$Name
}

function Add-BackupIssue {
    param([string]$Message)
    $issues.Add($Message)
}

function Add-BackupWarning {
    param([string]$Message)
    $warnings.Add($Message)
}

try {
    $databaseLiteral = ConvertTo-K98SqlLiteral -Value $DatabaseName
    $backupQuery = @"
SELECT
    backup_type = [type],
    last_backup_finish_date = MAX(backup_finish_date)
FROM msdb.dbo.backupset
WHERE database_name = $databaseLiteral
GROUP BY [type];
"@

    $recoveryQuery = @"
SELECT recovery_model_desc
FROM sys.databases
WHERE name = $databaseLiteral;
"@

    $backupRows = Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName "msdb" -Query $backupQuery
    $recoveryRows = Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName "master" -Query $recoveryQuery

    $nowUtc = [DateTime]::UtcNow
    $fullBackup = $null
    $diffBackup = $null
    $logBackup = $null

    foreach ($row in $backupRows) {
        $backupType = Get-BackupRowValue -Row $row -Name "backup_type"
        $backupFinishedAt = Get-BackupRowValue -Row $row -Name "last_backup_finish_date"
        if ($backupType -eq "D") { $fullBackup = [DateTime]$backupFinishedAt }
        if ($backupType -eq "I") { $diffBackup = [DateTime]$backupFinishedAt }
        if ($backupType -eq "L") { $logBackup = [DateTime]$backupFinishedAt }
    }

    if ($null -eq $fullBackup) {
        Add-BackupIssue "No full backup found in msdb for $DatabaseName"
    }
    elseif (($nowUtc - $fullBackup.ToUniversalTime()).TotalHours -gt $MaxFullBackupAgeHours) {
        Add-BackupIssue "Last full backup is older than $MaxFullBackupAgeHours hour(s): $fullBackup"
    }

    if ($null -eq $diffBackup) {
        Add-BackupWarning "No differential backup found in msdb for $DatabaseName"
    }
    elseif (($nowUtc - $diffBackup.ToUniversalTime()).TotalHours -gt $MaxDiffBackupAgeHours) {
        Add-BackupWarning "Last differential backup is older than $MaxDiffBackupAgeHours hour(s): $diffBackup"
    }

    $recoveryModel = $null
    $recoveryRowsArray = @($recoveryRows)
    if ($recoveryRowsArray.Count -gt 0) {
        $recoveryModel = [string](Get-BackupRowValue -Row $recoveryRowsArray[0] -Name "recovery_model_desc")
    }

    if ($recoveryModel -in @("FULL", "BULK_LOGGED")) {
        if ($null -eq $logBackup) {
            Add-BackupIssue "No log backup found in msdb for $DatabaseName while recovery model is $recoveryModel"
        }
        elseif (($nowUtc - $logBackup.ToUniversalTime()).TotalMinutes -gt $MaxLogBackupAgeMinutes) {
            Add-BackupIssue "Last log backup is older than $MaxLogBackupAgeMinutes minute(s): $logBackup"
        }
    }

    if (-not (Test-Path $BackupPath)) {
        Add-BackupWarning "Backup path not found: $BackupPath"
    }
    else {
        $recentFiles = Get-ChildItem -Path $BackupPath -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @(".bak", ".dif", ".trn", ".log") -and $_.LastWriteTimeUtc -gt $nowUtc.AddHours(-24) }
        if (-not $recentFiles) {
            Add-BackupWarning "No recent backup files found under $BackupPath in the last 24 hours"
        }
    }

    $status = "Succeeded"
    if ($issues.Count -gt 0) {
        if ($WarnOnly) {
            $status = "Warning"
        }
        else {
            $status = "Failed"
        }
    }

    Write-K98JsonLog -RepoRoot $repoRoot -LogName "deployment.jsonl" -Event @{
        script = "Test-SqlBackupReadiness.ps1"
        operation = "backup_readiness"
        status = $status
        server = $ServerName
        database = $DatabaseName
        backup_path = $BackupPath
        recovery_model = $recoveryModel
        full_backup = $fullBackup
        differential_backup = $diffBackup
        log_backup = $logBackup
        issue_count = $issues.Count
        warning_count = $warnings.Count
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
    }

    Write-Host "Backup readiness: $status"
    Write-Host "Recovery model: $recoveryModel"
    Write-Host "Full backup: $fullBackup"
    Write-Host "Differential backup: $diffBackup"
    Write-Host "Log backup: $logBackup"
    foreach ($issue in $issues) { Write-Host "ERROR: $issue" }
    foreach ($warning in $warnings) { Write-Host "WARN: $warning" }

    if ($issues.Count -gt 0 -and -not $WarnOnly) {
        exit 1
    }
}
catch {
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "deployment.jsonl" -Event @{
        script = "Test-SqlBackupReadiness.ps1"
        operation = "backup_readiness"
        status = "Failed"
        server = $ServerName
        database = $DatabaseName
        error_message = $_.Exception.Message
    }
    throw
}
