param(
    [string]$ServerName = "MINI_AMD",
    [string]$DatabaseName = "ROK_TRACKER",
    [string]$RepoPath,
    [string]$ExportBranch,
    [string]$SqlSchemaFolder = "sql_schema",
    [string]$SnapshotOutputPath,
    [switch]$DriftOnly,
    [switch]$NoGitCommitPush,
    [switch]$AllowMain,
    [string]$Reason,
    [switch]$DryRun
)

. "$PSScriptRoot\SqlDeploy.Common.ps1"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Get-K98RepoRoot
}

$repoRoot = (Resolve-Path $RepoPath).ProviderPath
$started = Get-Date
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$branch = Get-K98GitBranch -RepoRoot $repoRoot
$commit = Get-K98GitCommit -RepoRoot $repoRoot

function Write-K98ObjectScript {
    param(
        [Microsoft.SqlServer.Management.Smo.SqlSmoObject]$Object,
        [string]$Folder,
        [Microsoft.SqlServer.Management.Smo.Scripter]$Scripter
    )

    if ($Object.IsSystemObject) {
        return
    }

    $typeSuffix = "Object"
    if ($Object -is [Microsoft.SqlServer.Management.Smo.Table]) { $typeSuffix = "Table" }
    elseif ($Object -is [Microsoft.SqlServer.Management.Smo.View]) { $typeSuffix = "View" }
    elseif ($Object -is [Microsoft.SqlServer.Management.Smo.StoredProcedure]) { $typeSuffix = "StoredProcedure" }
    elseif ($Object -is [Microsoft.SqlServer.Management.Smo.UserDefinedFunction]) { $typeSuffix = "UserDefinedFunction" }
    elseif ($Object -is [Microsoft.SqlServer.Management.Smo.UserDefinedTableType]) { $typeSuffix = "UserDefinedTableType" }

    $safeSchema = $Object.Schema -replace "[^\w-]", "_"
    $safeName = $Object.Name -replace "[^\w-]", "_"
    $filePath = Join-Path $Folder "$safeSchema.$safeName.$typeSuffix.sql"

    try { $Object.Refresh() } catch { }

    if ($Object -is [Microsoft.SqlServer.Management.Smo.StoredProcedure] -or
        $Object -is [Microsoft.SqlServer.Management.Smo.View] -or
        $Object -is [Microsoft.SqlServer.Management.Smo.UserDefinedFunction]) {
        $Object.TextMode = $false
        $Object.AnsiNullsStatus = $true
        $Object.QuotedIdentifierStatus = $true
    }

    $script = $Scripter.Script($Object.Urn)
    Set-Content -Path $filePath -Value ($script -join [Environment]::NewLine) -Encoding UTF8
}

function Export-K98SchemaToFolder {
    param([string]$OutputDir)

    Ensure-K98Directory -Path $OutputDir

    Import-K98SqlServerModule
    $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection $ServerName
    if ($connection.PSObject.Properties.Name -contains "TrustServerCertificate") {
        $connection.TrustServerCertificate = $true
    }
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $connection
    $db = $server.Databases[$DatabaseName]
    if (-not $db) {
        throw "Database '$DatabaseName' not found on server '$ServerName'."
    }

    $scripter = New-Object Microsoft.SqlServer.Management.Smo.Scripter($server)
    $scripter.Options.IncludeIfNotExists = $true
    $scripter.Options.SchemaQualify = $true
    $scripter.Options.ClusteredIndexes = $true
    $scripter.Options.Default = $true
    $scripter.Options.DriAll = $true
    $scripter.Options.Indexes = $true
    $scripter.Options.Triggers = $true
    $scripter.Options.Permissions = $false
    $scripter.Options.ScriptDrops = $false
    $scripter.Options.WithDependencies = $false
    $scripter.Options.AnsiFile = $true
    $scripter.Options.ToFileOnly = $false

    foreach ($tbl in $db.Tables | Where-Object { -not $_.IsSystemObject } | Sort-Object Schema, Name) {
        Write-K98ObjectScript -Object $tbl -Folder $OutputDir -Scripter $scripter
    }
    foreach ($tt in $db.UserDefinedTableTypes | Sort-Object Schema, Name) {
        Write-K98ObjectScript -Object $tt -Folder $OutputDir -Scripter $scripter
    }
    foreach ($vw in $db.Views | Where-Object { -not $_.IsSystemObject } | Sort-Object Schema, Name) {
        Write-K98ObjectScript -Object $vw -Folder $OutputDir -Scripter $scripter
    }
    foreach ($sp in $db.StoredProcedures | Where-Object { -not $_.IsSystemObject } | Sort-Object Schema, Name) {
        Write-K98ObjectScript -Object $sp -Folder $OutputDir -Scripter $scripter
    }
    foreach ($fn in $db.UserDefinedFunctions | Where-Object { -not $_.IsSystemObject } | Sort-Object Schema, Name) {
        Write-K98ObjectScript -Object $fn -Folder $OutputDir -Scripter $scripter
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($ExportBranch)) {
        $ExportBranch = "export/prod-schema-$timestamp"
    }

    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Export-ProdSchemaSnapshot.ps1"
        operation = "export_start"
        status = "Started"
        server = $ServerName
        database = $DatabaseName
        branch = $branch
        git_commit = $commit
        export_branch = $ExportBranch
        drift_only = [bool]$DriftOnly
        dry_run = [bool]$DryRun
        exception_reason = $Reason
    }

    if ($DryRun) {
        Write-Host "Dry run: export would use branch $ExportBranch"
        exit 0
    }

    Assert-K98CleanGitTree -RepoRoot $repoRoot

    if ($DriftOnly) {
        if ([string]::IsNullOrWhiteSpace($SnapshotOutputPath)) {
            $SnapshotOutputPath = Join-Path (Join-Path $repoRoot "exports") "prod-schema-$timestamp"
        }
        Export-K98SchemaToFolder -OutputDir $SnapshotOutputPath
        Write-Host "Exported drift snapshot to $SnapshotOutputPath"
    }
    else {
        if ($branch -eq "main" -and -not $AllowMain) {
            Invoke-K98Git -RepoRoot $repoRoot -Arguments @("switch", "-c", $ExportBranch) | Out-Null
            $branch = Get-K98GitBranch -RepoRoot $repoRoot
        }
        elseif ($branch -eq "main" -and $AllowMain) {
            if ([string]::IsNullOrWhiteSpace($Reason)) {
                throw "-Reason is required when -AllowMain is used."
            }
            Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
                script = "Export-ProdSchemaSnapshot.ps1"
                operation = "main_export_override"
                status = "Warning"
                branch = $branch
                reason = $Reason
                recommended_action = "Prefer export/prod-schema-* branches for normal exports."
            }
        }

        $tempDir = Join-Path (Join-Path $repoRoot "exports") "prod-schema-$timestamp"
        Export-K98SchemaToFolder -OutputDir $tempDir

        $targetDir = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SqlSchemaFolder))
        Assert-K98PathUnderRoot -Root $repoRoot -Path $targetDir
        Ensure-K98Directory -Path $targetDir
        Get-ChildItem -Path $targetDir -Filter "*.sql" -File -ErrorAction SilentlyContinue | Remove-Item -Force
        Copy-Item -Path (Join-Path $tempDir "*.sql") -Destination $targetDir -Force

        if (-not $NoGitCommitPush) {
            Invoke-K98Git -RepoRoot $repoRoot -Arguments @("add", "-A", "--", $SqlSchemaFolder) | Out-Null
            $status = Invoke-K98Git -RepoRoot $repoRoot -Arguments @("status", "--porcelain", "--", $SqlSchemaFolder)
            if (-not [string]::IsNullOrWhiteSpace($status.Output)) {
                Invoke-K98Git -RepoRoot $repoRoot -Arguments @("commit", "-m", "chore: export production SQL schema $timestamp") | Out-Null
                Invoke-K98Git -RepoRoot $repoRoot -Arguments @("push", "-u", "origin", $branch) | Out-Null
            }
        }

        Write-Host "Exported production schema to $SqlSchemaFolder on branch $branch"
    }

    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Export-ProdSchemaSnapshot.ps1"
        operation = "export_finish"
        status = "Succeeded"
        server = $ServerName
        database = $DatabaseName
        branch = $branch
        export_branch = $ExportBranch
        snapshot_output_path = $SnapshotOutputPath
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
    }
}
catch {
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "export.jsonl" -Event @{
        script = "Export-ProdSchemaSnapshot.ps1"
        operation = "export_finish"
        status = "Failed"
        server = $ServerName
        database = $DatabaseName
        error_message = $_.Exception.Message
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
    }
    throw
}
