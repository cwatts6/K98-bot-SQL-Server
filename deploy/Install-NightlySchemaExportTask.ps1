param(
    [string]$TaskName = "K98 SQL Nightly Schema Export",
    [string]$OldTaskName,
    [string]$RepoPath = "C:\K98-bot-SQL-Server",
    [string]$BotRepoPath = "C:\discord_file_downloader",
    [string]$ServerName = "MINI_AMD",
    [string]$DatabaseName = "ROK_TRACKER",
    [string]$At = "01:30",
    [switch]$DisableOldTask,
    [switch]$RunWhetherLoggedOnOrNot,
    [System.Management.Automation.PSCredential]$Credential
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $RepoPath "deploy\Invoke-NightlyProdSchemaExport.ps1"
if (-not (Test-Path $scriptPath)) {
    throw "Nightly export script not found: $scriptPath"
}

if ($DisableOldTask -and -not [string]::IsNullOrWhiteSpace($OldTaskName)) {
    $oldTask = Get-ScheduledTask -TaskName $OldTaskName -ErrorAction SilentlyContinue
    if ($oldTask) {
        Disable-ScheduledTask -TaskName $OldTaskName | Out-Null
        Write-Host "Disabled old scheduled task: $OldTaskName"
    }
    else {
        Write-Host "Old scheduled task not found: $OldTaskName"
    }
}

$argument = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$scriptPath`"",
    "-RepoPath", "`"$RepoPath`"",
    "-BotRepoPath", "`"$BotRepoPath`"",
    "-ServerName", "`"$ServerName`"",
    "-DatabaseName", "`"$DatabaseName`""
) -join " "

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument -WorkingDirectory $RepoPath
$trigger = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Parse($At))
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

if ($RunWhetherLoggedOnOrNot) {
    if ($null -eq $Credential) {
        throw "-Credential is required with -RunWhetherLoggedOnOrNot."
    }
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -User $Credential.UserName `
        -Password $Credential.GetNetworkCredential().Password `
        -RunLevel Highest `
        -Force | Out-Null
}
else {
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}

Write-Host "Registered scheduled task: $TaskName"
Write-Host "Action: powershell.exe $argument"
Write-Host "Run once manually with:"
Write-Host "Start-ScheduledTask -TaskName `"$TaskName`""
