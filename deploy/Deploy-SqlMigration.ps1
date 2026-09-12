param(
    [string]$ServerName = "MINI_AMD",
    [string]$DatabaseName = "ROK_TRACKER",
    [string]$RepoPath,
    [string]$MigrationId,
    [string]$S8AInputFile,
    [string]$S8AInputSha256,
    [switch]$ValidationOnly,
    [switch]$SkipBackupCheck,
    [switch]$AllowNonMainBranch,
    [string]$Reason
)

. "$PSScriptRoot\SqlDeploy.Common.ps1"

# S8A input is a separately reviewed SQL prelude, not arbitrary automatic discovery.
# Require explicit destination and exact migration selection; never use runner defaults.
if ($S8AInputFile -or $S8AInputSha256) {
    if ($MigrationId -cne '20260912_001_kvk_season_complete_updates' -or
        -not $PSBoundParameters.ContainsKey('ServerName') -or [string]::IsNullOrWhiteSpace($ServerName) -or
        -not $PSBoundParameters.ContainsKey('DatabaseName') -or [string]::IsNullOrWhiteSpace($DatabaseName) -or
        [string]::IsNullOrWhiteSpace($S8AInputFile) -or $S8AInputSha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'S8A inputs require exact -MigrationId, explicit -ServerName/-DatabaseName, -S8AInputFile and its -S8AInputSha256.'
    }
}

function Invoke-K98S8AMigration {
    param([string]$ServerName, [string]$DatabaseName, [string]$InputFile,
        [string]$ApprovalFile, [string]$ApprovalSha256)
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ApprovalFile).ProviderPath)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try { $actualHash = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
    if ($actualHash -cne $ApprovalSha256.ToLowerInvariant()) { throw 'S8A input hash mismatch; no SQL executed.' }
    $prelude = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes).TrimStart([char]0xFEFF)
    $migration = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $InputFile).ProviderPath)
    if ($prelude -match '(?m)^\s*:' -or $migration -match '(?m)^\s*:') {
        throw 'S8A same-session execution accepts plain SQL only, not SQLCMD directives.'
    }
    $guard = @"
IF @@TRANCOUNT<>0 THROW 51800, 'S8A input must not open a transaction.', 1;
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL
    THROW 51800, 'S8A runner requires SchemaMigrationHistory before apply.', 1;
IF OBJECT_ID(N'tempdb..#S8AApproval',N'U') IS NULL OR OBJECT_ID(N'tempdb..#S8AClassification',N'U') IS NULL
    THROW 51800, 'S8A input must supply both reviewed temporary tables.', 1;
IF (SELECT COUNT_BIG(*) FROM #S8AApproval)<>1 OR EXISTS
 (SELECT 1 FROM #S8AApproval WHERE Mode IS NULL OR Mode COLLATE Latin1_General_100_BIN2<>'apply' OR DATALENGTH(Mode)<>5)
    THROW 51800, 'S8A runner is apply-only; preview must not be recorded as Applied.', 1;
"@
    # Reuse the existing connection/batch helpers. One connection retains temporary
    # tables across prelude, guard and migration; do not use separate Invoke-Sqlcmd calls.
    $connection = New-K98SqlConnection -ServerName $ServerName -DatabaseName $DatabaseName
    try {
        $connection.Open()
        foreach ($text in @($prelude, $guard, $migration)) {
            foreach ($batch in (Split-K98SqlBatches -SqlText $text)) {
                $command = $connection.CreateCommand()
                try {
                    $command.CommandText = $batch
                    $command.CommandTimeout = 120
                    [void]$command.ExecuteNonQuery()
                }
                finally { $command.Dispose() }
            }
        }
    }
    finally { $connection.Dispose() }
}


if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Get-K98RepoRoot
}

$repoRoot = (Resolve-Path $RepoPath).ProviderPath
$started = Get-Date
$deploymentId = [guid]::NewGuid()
$branch = Get-K98GitBranch -RepoRoot $repoRoot
$commit = Get-K98GitCommit -RepoRoot $repoRoot
$operator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$machine = $env:COMPUTERNAME

function Test-K98SqlTableExists {
    param(
        [string]$ServerName,
        [string]$DatabaseName,
        [string]$TableName
    )

    $tableLiteral = ConvertTo-K98SqlLiteral -Value $TableName
    $query = "SELECT object_id = OBJECT_ID($tableLiteral, N'U');"
    $rows = @(Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName $DatabaseName -Query $query)
    if (-not $rows) {
        return $false
    }
    return $null -ne $rows[0].object_id -and $rows[0].object_id -ne [DBNull]::Value
}

function Test-K98MigrationApplied {
    param(
        [string]$ServerName,
        [string]$DatabaseName,
        [string]$MigrationId
    )

    if (-not (Test-K98SqlTableExists -ServerName $ServerName -DatabaseName $DatabaseName -TableName "dbo.SchemaMigrationHistory")) {
        return $false
    }

    $migrationLiteral = ConvertTo-K98SqlLiteral -Value $MigrationId
    $query = "SELECT AppliedCount = COUNT(1) FROM dbo.SchemaMigrationHistory WHERE MigrationId = $migrationLiteral AND Status = N'Applied';"
    $rows = @(Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName $DatabaseName -Query $query)
    return $rows -and [int]$rows[0].AppliedCount -gt 0
}

function Write-K98DeploymentRun {
    param(
        [string]$Status,
        [string]$ErrorMessage,
        [int]$MigrationCount
    )

    if (-not (Test-K98SqlTableExists -ServerName $ServerName -DatabaseName $DatabaseName -TableName "dbo.DeploymentRunHistory")) {
        return
    }

    $finished = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss")
    $duration = [int]((Get-Date) - $started).TotalSeconds
    $query = @"
IF EXISTS (SELECT 1 FROM dbo.DeploymentRunHistory WHERE DeploymentId = '$deploymentId')
BEGIN
    UPDATE dbo.DeploymentRunHistory
    SET FinishedAtUtc = '$finished',
        Status = $(ConvertTo-K98SqlLiteral -Value $Status),
        ErrorMessage = $(ConvertTo-K98SqlLiteral -Value $ErrorMessage),
        DurationSeconds = $duration,
        MigrationCount = $MigrationCount
    WHERE DeploymentId = '$deploymentId';
END
ELSE
BEGIN
    INSERT INTO dbo.DeploymentRunHistory
    (
        DeploymentId, StartedAtUtc, FinishedAtUtc, StartedBy, MachineName, DatabaseName,
        GitCommit, BranchName, MigrationCount, Status, ErrorMessage, DurationSeconds
    )
    VALUES
    (
        '$deploymentId', '$($started.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss"))', '$finished',
        $(ConvertTo-K98SqlLiteral -Value $operator), $(ConvertTo-K98SqlLiteral -Value $machine),
        $(ConvertTo-K98SqlLiteral -Value $DatabaseName), $(ConvertTo-K98SqlLiteral -Value $commit),
        $(ConvertTo-K98SqlLiteral -Value $branch), $MigrationCount, $(ConvertTo-K98SqlLiteral -Value $Status),
        $(ConvertTo-K98SqlLiteral -Value $ErrorMessage), $duration
    );
END
"@
    Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName $DatabaseName -Query $query | Out-Null
}

function Write-K98MigrationHistory {
    param(
        [string]$MigrationId,
        [string]$MigrationFile,
        [string]$Checksum,
        [string]$Status,
        [string]$ErrorMessage,
        [int]$DurationMs
    )

    if (-not (Test-K98SqlTableExists -ServerName $ServerName -DatabaseName $DatabaseName -TableName "dbo.SchemaMigrationHistory")) {
        return
    }

    $query = @"
MERGE dbo.SchemaMigrationHistory AS target
USING (SELECT $(ConvertTo-K98SqlLiteral -Value $MigrationId) AS MigrationId) AS source
ON target.MigrationId = source.MigrationId
WHEN MATCHED THEN
    UPDATE SET
        MigrationFile = $(ConvertTo-K98SqlLiteral -Value $MigrationFile),
        ChecksumSha256 = $(ConvertTo-K98SqlLiteral -Value $Checksum),
        AppliedAtUtc = SYSUTCDATETIME(),
        AppliedBy = $(ConvertTo-K98SqlLiteral -Value $operator),
        MachineName = $(ConvertTo-K98SqlLiteral -Value $machine),
        GitCommit = $(ConvertTo-K98SqlLiteral -Value $commit),
        BranchName = $(ConvertTo-K98SqlLiteral -Value $branch),
        DeploymentId = '$deploymentId',
        Status = $(ConvertTo-K98SqlLiteral -Value $Status),
        ErrorMessage = $(ConvertTo-K98SqlLiteral -Value $ErrorMessage),
        DurationMs = $DurationMs
WHEN NOT MATCHED THEN
    INSERT
    (
        MigrationId, MigrationFile, ChecksumSha256, AppliedAtUtc, AppliedBy, MachineName,
        GitCommit, BranchName, DeploymentId, Status, ErrorMessage, DurationMs
    )
    VALUES
    (
        $(ConvertTo-K98SqlLiteral -Value $MigrationId), $(ConvertTo-K98SqlLiteral -Value $MigrationFile),
        $(ConvertTo-K98SqlLiteral -Value $Checksum), SYSUTCDATETIME(), $(ConvertTo-K98SqlLiteral -Value $operator),
        $(ConvertTo-K98SqlLiteral -Value $machine), $(ConvertTo-K98SqlLiteral -Value $commit),
        $(ConvertTo-K98SqlLiteral -Value $branch), '$deploymentId', $(ConvertTo-K98SqlLiteral -Value $Status),
        $(ConvertTo-K98SqlLiteral -Value $ErrorMessage), $DurationMs
    );
"@
    Invoke-K98SqlQuery -ServerName $ServerName -DatabaseName $DatabaseName -Query $query | Out-Null
}

try {
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "deployment.jsonl" -Event @{
        script = "Deploy-SqlMigration.ps1"
        operation = "deployment_start"
        status = "Started"
        deployment_id = $deploymentId
        server = $ServerName
        database = $DatabaseName
        branch = $branch
        git_commit = $commit
        operator = $operator
        machine = $machine
        validation_only = [bool]$ValidationOnly
        skip_backup_check = [bool]$SkipBackupCheck
        exception_reason = $Reason
    }

    $validator = Join-Path $PSScriptRoot "Validate-SqlRepo.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -RepoPath $repoRoot -Quiet
    if ($LASTEXITCODE -ne 0) {
        throw "SQL repo validation failed. Run deploy/Validate-SqlRepo.ps1 for details."
    }

    if (-not $ValidationOnly) {
        if ($branch -ne "main" -and -not $AllowNonMainBranch) {
            throw "Deployment is only allowed from main by default. Use -AllowNonMainBranch with -Reason for an explicitly logged exception."
        }
        if ($AllowNonMainBranch -and [string]::IsNullOrWhiteSpace($Reason)) {
            throw "-Reason is required when -AllowNonMainBranch is used."
        }
        if ($SkipBackupCheck -and [string]::IsNullOrWhiteSpace($Reason)) {
            throw "-Reason is required when -SkipBackupCheck is used."
        }
        Assert-K98CleanGitTree -RepoRoot $repoRoot
        if (-not $SkipBackupCheck) {
            $backupChecker = Join-Path $PSScriptRoot "Test-SqlBackupReadiness.ps1"
            & powershell -NoProfile -ExecutionPolicy Bypass -File $backupChecker -ServerName $ServerName -DatabaseName $DatabaseName -RepoPath $repoRoot
            if ($LASTEXITCODE -ne 0) {
                throw "Backup readiness check failed. Run deploy/Test-SqlBackupReadiness.ps1 for details."
            }
        }
    }

    $migrationDir = Join-Path $repoRoot "migrations"
    $migrationFiles = Get-ChildItem -Path $migrationDir -Filter "*.sql" -File |
        Where-Object { $_.Name -notmatch "\.rollback\.sql$" } |
        Sort-Object Name

    if (-not [string]::IsNullOrWhiteSpace($MigrationId)) {
        $migrationFiles = $migrationFiles | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $MigrationId }
        if (-not $migrationFiles) {
            throw "Migration not found: $MigrationId"
        }
    }

    $pending = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    foreach ($file in $migrationFiles) {
        $id = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if (-not (Test-K98MigrationApplied -ServerName $ServerName -DatabaseName $DatabaseName -MigrationId $id)) {
            $pending.Add($file)
        }
    }

    if ($ValidationOnly) {
        Write-K98DeploymentRun -Status "ValidationOnly" -ErrorMessage $null -MigrationCount $pending.Count
        Write-Host "Validation succeeded. Pending migration count: $($pending.Count)"
        foreach ($file in $pending) {
            Write-Host "PENDING: $($file.Name)"
        }
        exit 0
    }

    if (@($pending | Where-Object { $_.BaseName -ceq '20260912_001_kvk_season_complete_updates' }).Count -gt 0 -and
        [string]::IsNullOrWhiteSpace($S8AInputFile)) {
        throw 'Pending S8A requires a separately reviewed same-session input. Run exact -MigrationId 20260912_001_kvk_season_complete_updates with explicit target, -S8AInputFile and -S8AInputSha256 first.'
    }

    foreach ($file in $pending) {
        $id = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $checksum = Get-K98FileSha256 -Path $file.FullName
        $migrationStart = Get-Date
        try {
            Write-Host "Applying migration $id"
            if ($id -ceq '20260912_001_kvk_season_complete_updates') {
                Invoke-K98S8AMigration -ServerName $ServerName -DatabaseName $DatabaseName -InputFile $file.FullName -ApprovalFile $S8AInputFile -ApprovalSha256 $S8AInputSha256
            }
            else {
                Invoke-K98SqlFile -ServerName $ServerName -DatabaseName $DatabaseName -InputFile $file.FullName | Out-Null
            }
            $durationMs = [int]((Get-Date) - $migrationStart).TotalMilliseconds
            Write-K98MigrationHistory -MigrationId $id -MigrationFile $file.Name -Checksum $checksum -Status "Applied" -ErrorMessage $null -DurationMs $durationMs
            Write-K98JsonLog -RepoRoot $repoRoot -LogName "deployment.jsonl" -Event @{
                script = "Deploy-SqlMigration.ps1"
                operation = "migration_applied"
                status = "Applied"
                deployment_id = $deploymentId
                migration_id = $id
                checksum_sha256 = $checksum
                duration_ms = $durationMs
            }
        }
        catch {
            $durationMs = [int]((Get-Date) - $migrationStart).TotalMilliseconds
            Write-K98MigrationHistory -MigrationId $id -MigrationFile $file.Name -Checksum $checksum -Status "Failed" -ErrorMessage $_.Exception.Message -DurationMs $durationMs
            throw
        }
    }

    Write-K98DeploymentRun -Status "Succeeded" -ErrorMessage $null -MigrationCount $pending.Count
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "deployment.jsonl" -Event @{
        script = "Deploy-SqlMigration.ps1"
        operation = "deployment_finish"
        status = "Succeeded"
        deployment_id = $deploymentId
        migration_count = $pending.Count
        duration_seconds = [int]((Get-Date) - $started).TotalSeconds
    }

    Write-Host "Deployment succeeded. Applied migration count: $($pending.Count)"
}
catch {
    $message = $_.Exception.Message
    try {
        Write-K98DeploymentRun -Status "Failed" -ErrorMessage $message -MigrationCount 0
    }
    catch {
        Write-K98JsonLog -RepoRoot $repoRoot -LogName "deployment.jsonl" -Event @{
            script = "Deploy-SqlMigration.ps1"
            operation = "deployment_history_write"
            status = "Failed"
            deployment_id = $deploymentId
            error_message = $_.Exception.Message
            recommended_action = "Review SQL connectivity before relying on dbo.DeploymentRunHistory."
        }
    }
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "deployment.jsonl" -Event @{
        script = "Deploy-SqlMigration.ps1"
        operation = "deployment_finish"
        status = "Failed"
        deployment_id = $deploymentId
        error_message = $message
        duration_seconds = [int]((Get-Date) - $started).TotalSeconds
    }
    throw
}
