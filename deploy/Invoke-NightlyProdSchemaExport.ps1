param(
    [string]$ServerName = "MINI_AMD",
    [string]$DatabaseName = "ROK_TRACKER",
    [string]$RepoPath = "C:\K98-bot-SQL-Server",
    [string]$BotRepoPath = "C:\discord_file_downloader",
    [string]$ExportBranchPrefix = "export/prod-schema",
    [switch]$NoGitCommitPush,
    [string]$DiscordAlertUrl = $env:SQL_SCHEMA_DISCORD_WEBHOOK_URL
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\SqlDeploy.Common.ps1"

function Import-K98BotDevEnvironment {
    param([Parameter(Mandatory=$true)][string]$Path)

    $activate = Join-Path $Path ".venv\Scripts\Activate.ps1"
    $devScript = Join-Path $Path "dev.ps1"

    if (Test-Path $activate) {
        . $activate
    }
    if (Test-Path $devScript) {
        . $devScript
    }
}

function ConvertTo-K98RedactedAlertError {
    param([AllowNull()][string]$Message)

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return $Message
    }

    $redacted = $Message -replace "https?://\S+", "[redacted-url]"
    $redacted = $redacted -replace "(?i)(discord(?:app)?\.com/api/webhooks/)[^\s'\""]+", '$1[redacted]'
    return $redacted
}

function Send-K98NightlyExportDiscordAlert {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$Status,
        [string]$RecommendedAction,
        [string]$ExportBranch
    )

    try {
        if ([string]::IsNullOrWhiteSpace($DiscordAlertUrl)) {
            Write-K98JsonLog -RepoRoot $RepoRoot -LogName "export.jsonl" -Event @{
                script = "Invoke-NightlyProdSchemaExport.ps1"
                operation = "discord_failure_alert"
                status = "Skipped"
                reason = "SQL_SCHEMA_DISCORD_WEBHOOK_URL is not configured."
                export_branch = $ExportBranch
            }
            return
        }

        $exportLogPath = Join-Path (Join-Path $RepoRoot "logs") "export.jsonl"
        $lines = @(
            "SQL nightly schema export $Status on $env:COMPUTERNAME",
            "Database: $DatabaseName",
            "Export branch: $ExportBranch",
            "Details: check $exportLogPath on the SQL operations machine."
        )
        if (-not [string]::IsNullOrWhiteSpace($RecommendedAction)) {
            $lines += "Action: $RecommendedAction"
        }

        $payload = @{ content = ($lines -join "`n") } | ConvertTo-Json -Compress

        try {
            Invoke-RestMethod `
                -Uri $DiscordAlertUrl `
                -Method Post `
                -Body $payload `
                -ContentType "application/json" `
                -ErrorAction Stop | Out-Null

            Write-K98JsonLog -RepoRoot $RepoRoot -LogName "export.jsonl" -Event @{
                script = "Invoke-NightlyProdSchemaExport.ps1"
                operation = "discord_failure_alert"
                status = "Succeeded"
                export_branch = $ExportBranch
            }
        }
        catch {
            Write-K98JsonLog -RepoRoot $RepoRoot -LogName "export.jsonl" -Event @{
                script = "Invoke-NightlyProdSchemaExport.ps1"
                operation = "discord_failure_alert"
                status = "Failed"
                export_branch = $ExportBranch
                error_message = ConvertTo-K98RedactedAlertError -Message $_.Exception.Message
            }
        }
    }
    catch {
        try {
            Write-Host "WARN: Discord failure alert could not be recorded: $(ConvertTo-K98RedactedAlertError -Message $_.Exception.Message)"
        }
        catch {
            Write-Host "WARN: Discord failure alert could not be recorded."
        }
    }
}

$repoRoot = (Resolve-Path $RepoPath).ProviderPath
$started = Get-Date
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$exportBranch = "$ExportBranchPrefix-$timestamp"
$originalBranch = $null

try {
    Import-K98BotDevEnvironment -Path $BotRepoPath

    $originalBranch = Get-K98GitBranch -RepoRoot $repoRoot

    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Invoke-NightlyProdSchemaExport.ps1"
        operation = "nightly_export_start"
        status = "Started"
        server = $ServerName
        database = $DatabaseName
        original_branch = $originalBranch
        export_branch = $exportBranch
        machine = $env:COMPUTERNAME
        operator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }

    Assert-K98CleanGitTree -RepoRoot $repoRoot
    Invoke-K98Git -RepoRoot $repoRoot -Arguments @("fetch", "origin", "--prune") | Out-Null
    Invoke-K98Git -RepoRoot $repoRoot -Arguments @("switch", "main") | Out-Null
    Invoke-K98Git -RepoRoot $repoRoot -Arguments @("pull", "--ff-only", "origin", "main") | Out-Null
    Assert-K98CleanGitTree -RepoRoot $repoRoot

    $exportArgs = @(
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "Export-ProdSchemaSnapshot.ps1"),
        "-RepoPath", $repoRoot,
        "-ServerName", $ServerName,
        "-DatabaseName", $DatabaseName,
        "-ExportBranch", $exportBranch
    )

    if ($NoGitCommitPush) {
        $exportArgs += "-NoGitCommitPush"
    }

    & powershell.exe -NoProfile @exportArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Export-ProdSchemaSnapshot.ps1 failed with exit code $LASTEXITCODE."
    }

    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Invoke-NightlyProdSchemaExport.ps1"
        operation = "nightly_export_finish"
        status = "Succeeded"
        server = $ServerName
        database = $DatabaseName
        export_branch = $exportBranch
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
        recommended_action = "Review the export branch if it was pushed. Reconcile expected drift through a SQL PR."
    }

    Write-Host "Nightly SQL schema export completed. Export branch: $exportBranch"
}
catch {
    $failureMessage = $_.Exception.Message
    $recommendedAction = "Fix the nightly export failure before relying on drift evidence."
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Invoke-NightlyProdSchemaExport.ps1"
        operation = "nightly_export_finish"
        status = "Failed"
        server = $ServerName
        database = $DatabaseName
        export_branch = $exportBranch
        error_message = $failureMessage
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
        recommended_action = $recommendedAction
    }
    Send-K98NightlyExportDiscordAlert `
        -RepoRoot $repoRoot `
        -Status "FAILED" `
        -RecommendedAction $recommendedAction `
        -ExportBranch $exportBranch
    throw
}
finally {
    try {
        Invoke-K98Git -RepoRoot $repoRoot -Arguments @("switch", "main") | Out-Null
        Invoke-K98Git -RepoRoot $repoRoot -Arguments @("pull", "--ff-only", "origin", "main") | Out-Null
    }
    catch {
        $cleanupMessage = $_.Exception.Message
        $cleanupAction = "Manually switch C:\K98-bot-SQL-Server back to main and check git status."
        Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
            script = "Invoke-NightlyProdSchemaExport.ps1"
            operation = "nightly_export_cleanup"
            status = "Failed"
            attempted_branch = "main"
            error_message = $cleanupMessage
            recommended_action = $cleanupAction
        }
        Send-K98NightlyExportDiscordAlert `
            -RepoRoot $repoRoot `
            -Status "CLEANUP FAILED" `
            -RecommendedAction $cleanupAction `
            -ExportBranch $exportBranch
    }
}
