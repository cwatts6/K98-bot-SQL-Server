param(
    [string]$RepoPath,
    [string]$TaskName = "K98 SQL Nightly Schema Export",
    [int]$MaxExportAgeHours = 30,
    [switch]$SkipScheduledTaskCheck,
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

function Add-NightlyExportIssue {
    param([string]$Message)
    $issues.Add($Message)
}

function Add-NightlyExportWarning {
    param([string]$Message)
    $warnings.Add($Message)
}

function ConvertFrom-K98JsonLine {
    param([Parameter(Mandatory=$true)][string]$Line)

    try {
        return $Line | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Add-NightlyExportWarning "Ignoring malformed export log line: $($_.Exception.Message)"
        return $null
    }
}

try {
    $logPath = Join-Path (Join-Path $repoRoot "logs") "export.jsonl"
    $latestFinish = $null
    $latestCleanupFailure = $null

    if (-not (Test-Path $logPath)) {
        Add-NightlyExportIssue "Export log not found: $logPath"
    }
    else {
        $events = Get-Content -Path $logPath |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { ConvertFrom-K98JsonLine -Line $_ } |
            Where-Object { $null -ne $_ }

        $latestFinish = $events |
            Where-Object {
                $_.script -eq "Invoke-NightlyProdSchemaExport.ps1" -and
                $_.operation -eq "nightly_export_finish"
            } |
            Sort-Object { [DateTime]$_.timestamp_utc } -Descending |
            Select-Object -First 1

        $latestCleanupFailure = $events |
            Where-Object {
                $_.script -eq "Invoke-NightlyProdSchemaExport.ps1" -and
                $_.operation -eq "nightly_export_cleanup" -and
                $_.status -eq "Failed"
            } |
            Sort-Object { [DateTime]$_.timestamp_utc } -Descending |
            Select-Object -First 1

        if ($null -eq $latestFinish) {
            Add-NightlyExportIssue "No nightly_export_finish event found in export log."
        }
        else {
            $latestFinishUtc = ([DateTime]$latestFinish.timestamp_utc).ToUniversalTime()
            $ageHours = ([DateTime]::UtcNow - $latestFinishUtc).TotalHours
            if ($latestFinish.status -ne "Succeeded") {
                Add-NightlyExportIssue "Latest nightly export status is $($latestFinish.status): $($latestFinish.error_message)"
            }
            if ($ageHours -gt $MaxExportAgeHours) {
                Add-NightlyExportIssue ("Latest nightly export is older than {0} hour(s): {1:o}" -f $MaxExportAgeHours, $latestFinishUtc)
            }
        }

        if ($null -ne $latestCleanupFailure) {
            Add-NightlyExportWarning "Latest export cleanup failure requires manual branch/status review: $($latestCleanupFailure.error_message)"
        }
    }

    $taskState = $null
    $taskLastRunTime = $null
    $taskLastTaskResult = $null
    if (-not $SkipScheduledTaskCheck) {
        try {
            $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
            $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
            $taskState = $task.State
            $taskLastRunTime = $taskInfo.LastRunTime
            $taskLastTaskResult = $taskInfo.LastTaskResult

            if ($task.State -eq "Disabled") {
                Add-NightlyExportIssue "Scheduled task is disabled: $TaskName"
            }
            if ($taskInfo.LastTaskResult -ne 0) {
                Add-NightlyExportIssue "Scheduled task LastTaskResult is $($taskInfo.LastTaskResult) for $TaskName"
            }
        }
        catch {
            Add-NightlyExportWarning "Scheduled task check skipped or unavailable for '$TaskName': $($_.Exception.Message)"
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
    elseif ($warnings.Count -gt 0) {
        $status = "Warning"
    }

    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Test-NightlyExportHealth.ps1"
        operation = "nightly_export_health"
        status = $status
        task_name = $TaskName
        task_state = $taskState
        task_last_run_time = $taskLastRunTime
        task_last_task_result = $taskLastTaskResult
        max_export_age_hours = $MaxExportAgeHours
        latest_export_status = if ($latestFinish) { $latestFinish.status } else { $null }
        latest_export_timestamp_utc = if ($latestFinish) { $latestFinish.timestamp_utc } else { $null }
        issue_count = $issues.Count
        warning_count = $warnings.Count
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
        recommended_action = "If failed, inspect Task Scheduler, logs/export.jsonl, git branch/status, and the latest export branch."
    }

    Write-Host "Nightly export health: $status"
    if ($latestFinish) {
        Write-Host "Latest nightly export: $($latestFinish.status) at $($latestFinish.timestamp_utc)"
    }
    Write-Host "Scheduled task: $TaskName"
    if ($null -ne $taskLastTaskResult) {
        Write-Host "LastTaskResult: $taskLastTaskResult"
    }
    foreach ($issue in $issues) { Write-Host "ERROR: $issue" }
    foreach ($warning in $warnings) { Write-Host "WARN: $warning" }

    if ($issues.Count -gt 0 -and -not $WarnOnly) {
        exit 1
    }
}
catch {
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Test-NightlyExportHealth.ps1"
        operation = "nightly_export_health"
        status = "Failed"
        error_message = $_.Exception.Message
    }
    throw
}
