param(
    [string]$RepoPath,
    [switch]$Quiet
)

. "$PSScriptRoot\SqlDeploy.Common.ps1"

$repoRoot = $null
if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Get-K98RepoRoot
}

$started = Get-Date
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-ValidationError {
    param([string]$Message)
    $errors.Add($Message)
}

function Add-ValidationWarning {
    param([string]$Message)
    $warnings.Add($Message)
}

function Get-K98SqlBatchSummary {
    param([Parameter(Mandatory=$true)][string]$Batch)

    $firstMeaningfulLine = ($Batch -split "\r?\n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch "^\s*--" } |
        Select-Object -First 1)

    if ([string]::IsNullOrWhiteSpace($firstMeaningfulLine)) {
        return "<empty batch>"
    }

    $summary = $firstMeaningfulLine.Trim()
    if ($summary.Length -gt 120) {
        return $summary.Substring(0, 120) + "..."
    }

    return $summary
}

try {
    $repoRoot = (Resolve-Path $RepoPath).ProviderPath
    $requiredDirs = @("sql_schema", "migrations", "deploy", "docs", "logs", "reports", "exports")
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path (Join-Path $repoRoot $dir))) {
            Add-ValidationError "Missing required folder: $dir"
        }
    }

    $migrationDir = Join-Path $repoRoot "migrations"
    $migrationFiles = @()
    if (Test-Path $migrationDir) {
        $migrationFiles = Get-ChildItem -Path $migrationDir -Filter "*.sql" -File |
            Where-Object { $_.Name -notmatch "\.rollback\.sql$" } |
            Sort-Object Name
    }
    $rollbackDir = Join-Path $migrationDir "rollback"

    $idCounts = @{}
    foreach ($file in $migrationFiles) {
        if ($file.Name -notmatch "^\d{8}_\d{3}_[a-z0-9_]+\.sql$") {
            Add-ValidationError "Invalid migration filename: $($file.Name)"
        }

        $migrationId = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if (-not $idCounts.ContainsKey($migrationId)) {
            $idCounts[$migrationId] = 0
        }
        $idCounts[$migrationId] += 1

        $metadata = Get-K98MigrationMetadata -Path $file.FullName
        foreach ($field in @("MigrationId", "Purpose", "Author", "CreatedUtc", "RequiresBackup", "RiskLevel", "Rollback", "TransactionMode")) {
            if (-not $metadata.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($metadata[$field])) {
                Add-ValidationError "$($file.Name) missing required header field: $field"
            }
        }

        if ($metadata.ContainsKey("MigrationId") -and $metadata["MigrationId"] -ne $migrationId) {
            Add-ValidationError "$($file.Name) header MigrationId does not match filename"
        }

        if ($metadata.ContainsKey("RiskLevel") -and $metadata["RiskLevel"] -notin @("Low", "Medium", "High")) {
            Add-ValidationError "$($file.Name) RiskLevel must be Low, Medium, or High"
        }

        if ($metadata.ContainsKey("RequiresBackup") -and $metadata["RequiresBackup"] -notin @("Yes", "No")) {
            Add-ValidationError "$($file.Name) RequiresBackup must be Yes or No"
        }

        if ($metadata.ContainsKey("Rollback") -and $metadata["Rollback"] -notin @("Included", "Manual", "Forward Fix Only", "Not Possible", "NotPossible")) {
            Add-ValidationError "$($file.Name) Rollback must be Included, Manual, Forward Fix Only, or Not Possible"
        }
        if ($metadata.ContainsKey("Rollback") -and $metadata["Rollback"] -eq "NotPossible") {
            Add-ValidationWarning "$($file.Name) uses legacy Rollback value NotPossible; prefer Not Possible"
        }
        if ($metadata.ContainsKey("Rollback") -and $metadata["Rollback"] -eq "Included") {
            $rollbackScript = $null
            if ($metadata.ContainsKey("RollbackScript") -and -not [string]::IsNullOrWhiteSpace($metadata["RollbackScript"]) -and $metadata["RollbackScript"] -ne "N/A") {
                $rollbackScript = Join-Path $repoRoot ($metadata["RollbackScript"] -replace "/", [System.IO.Path]::DirectorySeparatorChar)
            }
            else {
                $rollbackScript = Join-Path $rollbackDir "$migrationId`_rollback.sql"
            }
            if (-not (Test-Path $rollbackScript)) {
                Add-ValidationError "$($file.Name) declares Rollback: Included but rollback script was not found: $rollbackScript"
            }
        }

        if ($metadata.ContainsKey("TransactionMode") -and $metadata["TransactionMode"] -notin @("Auto", "Required", "None")) {
            Add-ValidationError "$($file.Name) TransactionMode must be Auto, Required, or None"
        }
        if ($metadata.ContainsKey("DataChange") -and $metadata["DataChange"] -notin @("Yes", "No")) {
            Add-ValidationError "$($file.Name) DataChange must be Yes or No"
        }
        if ($metadata.ContainsKey("DataSafetyPlan") -and $metadata["DataSafetyPlan"] -notin @("Not Required", "Required", "Included")) {
            Add-ValidationError "$($file.Name) DataSafetyPlan must be Not Required, Required, or Included"
        }
        if ($metadata.ContainsKey("DataChange") -and $metadata["DataChange"] -eq "Yes") {
            if (-not $metadata.ContainsKey("DataSafetyPlan") -or $metadata["DataSafetyPlan"] -eq "Not Required" -or [string]::IsNullOrWhiteSpace($metadata["DataSafetyPlan"])) {
                Add-ValidationWarning "$($file.Name) declares DataChange: Yes without DataSafetyPlan: Required or Included"
            }
        }

        $content = Get-Content -Raw -Path $file.FullName
        $hasHighRiskOperation = $false
        if ($content -match "(?im)^\s*DROP\s+TABLE\s+(?!IF\s+EXISTS\s+#)(?!#)") {
            Add-ValidationWarning "$($file.Name) contains DROP TABLE; confirm rollback and data safety"
            $hasHighRiskOperation = $true
        }
        if ($content -match "(?im)^\s*TRUNCATE\s+TABLE\s+") {
            Add-ValidationWarning "$($file.Name) contains TRUNCATE TABLE; confirm data safety"
            $hasHighRiskOperation = $true
        }
        foreach ($batch in (Split-K98SqlBatches -SqlText $content)) {
            $batchSummary = Get-K98SqlBatchSummary -Batch $batch
            if ($batch -match "(?im)^\s*UPDATE\s+\S+\s+SET\s+" -and $batch -notmatch "(?im)\bWHERE\b") {
                Add-ValidationWarning "$($file.Name) may contain UPDATE without WHERE in batch: $batchSummary"
                $hasHighRiskOperation = $true
            }
            if ($batch -match "(?im)^\s*DELETE\s+FROM\s+" -and $batch -notmatch "(?im)\bWHERE\b") {
                Add-ValidationWarning "$($file.Name) may contain DELETE without WHERE in batch: $batchSummary"
                $hasHighRiskOperation = $true
            }
        }
        if ($hasHighRiskOperation) {
            if (-not $metadata.ContainsKey("DataSafetyPlan") -or $metadata["DataSafetyPlan"] -eq "Not Required") {
                Add-ValidationWarning "$($file.Name) contains high-risk SQL without DataSafetyPlan: Required or Included"
            }
        }
        if ($content -match "(?i)(Password\s*=|Pwd\s*=|User\s+ID\s*=|AccessToken|DiscordWebhook|ConnectionString)") {
            Add-ValidationError "$($file.Name) may contain a secret or connection string"
        }
    }

    if (Test-Path $rollbackDir) {
        $rollbackFiles = Get-ChildItem -Path $rollbackDir -Filter "*.sql" -File
        foreach ($rollbackFile in $rollbackFiles) {
            $rollbackContent = Get-Content -Raw -Path $rollbackFile.FullName
            if ($rollbackContent -notmatch "(?im)^\s*RollbackForMigrationId\s*:") {
                Add-ValidationError "$($rollbackFile.Name) missing required header field: RollbackForMigrationId"
            }
            if ($rollbackContent -match "(?i)(Password\s*=|Pwd\s*=|User\s+ID\s*=|AccessToken|DiscordWebhook|ConnectionString)") {
                Add-ValidationError "$($rollbackFile.Name) may contain a secret or connection string"
            }
        }
    }

    foreach ($key in $idCounts.Keys) {
        if ($idCounts[$key] -gt 1) {
            Add-ValidationError "Duplicate migration ID: $key"
        }
    }

    $schemaDir = Join-Path $repoRoot "sql_schema"
    if (Test-Path $schemaDir) {
        $objectFiles = Get-ChildItem -Path $schemaDir -Filter "*.sql" -File
        $duplicates = $objectFiles | Group-Object { $_.Name.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 }
        foreach ($duplicate in $duplicates) {
            Add-ValidationError "Duplicate schema object file: $($duplicate.Name)"
        }

        foreach ($schemaFile in $objectFiles) {
            $text = Get-Content -Raw -Path $schemaFile.FullName
            if ($schemaFile.Name -match "\.(Table|View|StoredProcedure|UserDefinedFunction)\.sql$") {
                if ($text -notmatch "SET ANSI_NULLS ON") {
                    Add-ValidationWarning "$($schemaFile.Name) does not include SET ANSI_NULLS ON"
                }
                if ($text -notmatch "SET QUOTED_IDENTIFIER ON") {
                    Add-ValidationWarning "$($schemaFile.Name) does not include SET QUOTED_IDENTIFIER ON"
                }
            }
        }
    }

    $status = "Succeeded"
    if ($errors.Count -gt 0) {
        $status = "Failed"
    }

    Write-K98JsonLog -RepoRoot $repoRoot -LogName "validation.jsonl" -Event @{
        script = "Validate-SqlRepo.ps1"
        operation = "validate_sql_repo"
        status = $status
        error_count = $errors.Count
        warning_count = $warnings.Count
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
    }

    if (-not $Quiet) {
        Write-Host "SQL repo validation: $status"
        foreach ($message in $errors) {
            Write-Host "ERROR: $message"
        }
        foreach ($message in $warnings) {
            Write-Host "WARN: $message"
        }
    }

    if ($errors.Count -gt 0) {
        exit 1
    }
}
catch {
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        $repoRoot = Get-K98RepoRoot
    }
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "validation.jsonl" -Event @{
        script = "Validate-SqlRepo.ps1"
        operation = "validate_sql_repo"
        status = "Failed"
        error_message = $_.Exception.Message
    }
    throw
}
