param(
    [string]$ServerName = "MINI_AMD",
    [string]$DatabaseName = "ROK_TRACKER",
    [string]$RepoPath = "C:\K98-bot-SQL-Server",
    [string]$BotRepoPath = "C:\discord_file_downloader",
    [string]$ExportBranchPrefix = "export/prod-schema",
    [switch]$NoGitCommitPush
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
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Invoke-NightlyProdSchemaExport.ps1"
        operation = "nightly_export_finish"
        status = "Failed"
        server = $ServerName
        database = $DatabaseName
        export_branch = $exportBranch
        error_message = $_.Exception.Message
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
        recommended_action = "Fix the nightly export failure before relying on drift evidence."
    }
    throw
}
finally {
    try {
        Invoke-K98Git -RepoRoot $repoRoot -Arguments @("switch", "main") | Out-Null
        Invoke-K98Git -RepoRoot $repoRoot -Arguments @("pull", "--ff-only", "origin", "main") | Out-Null
    }
    catch {
        Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
            script = "Invoke-NightlyProdSchemaExport.ps1"
            operation = "nightly_export_cleanup"
            status = "Failed"
            attempted_branch = "main"
            error_message = $_.Exception.Message
            recommended_action = "Manually switch C:\K98-bot-SQL-Server back to main and check git status."
        }
    }
}
