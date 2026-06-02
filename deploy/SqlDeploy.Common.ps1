$ErrorActionPreference = "Stop"

function Get-K98RepoRoot {
    param([string]$StartPath = $PSScriptRoot)

    $current = (Resolve-Path $StartPath).ProviderPath
    while ($current) {
        if (Test-Path (Join-Path $current ".git")) {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) {
            break
        }
        $current = $parent
    }

    throw "Unable to locate repository root from $StartPath"
}

function Ensure-K98Directory {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Write-K98JsonLog {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$LogName,
        [Parameter(Mandatory=$true)][hashtable]$Event
    )

    $logDir = Join-Path $RepoRoot "logs"
    Ensure-K98Directory -Path $logDir
    $logPath = Join-Path $logDir $LogName

    if (-not $Event.ContainsKey("timestamp_utc")) {
        $Event["timestamp_utc"] = [DateTime]::UtcNow.ToString("o")
    }

    $line = $Event | ConvertTo-Json -Compress -Depth 8
    Add-Content -Path $logPath -Value $line -Encoding UTF8
}

function Invoke-K98Git {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $previous = Get-Location
    Set-Location -Path $RepoRoot
    try {
        $output = & git @Arguments 2>&1 | ForEach-Object { $_.ToString() }
        $exitCode = $LASTEXITCODE
    }
    finally {
        Set-Location -Path $previous
    }

    $text = ($output -join "`n").Trim()
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "git $($Arguments -join ' ') failed with exit $exitCode. $text"
    }

    return @{
        ExitCode = $exitCode
        Output = $text
    }
}

function Get-K98GitBranch {
    param([Parameter(Mandatory=$true)][string]$RepoRoot)

    $result = Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    return $result.Output.Split("`n")[0].Trim()
}

function Get-K98GitCommit {
    param([Parameter(Mandatory=$true)][string]$RepoRoot)

    $result = Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("rev-parse", "--short=12", "HEAD")
    return $result.Output.Split("`n")[0].Trim()
}

function Assert-K98CleanGitTree {
    param([Parameter(Mandatory=$true)][string]$RepoRoot)

    $result = Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("status", "--porcelain")
    if (-not [string]::IsNullOrWhiteSpace($result.Output)) {
        throw "Working tree is not clean. Commit, stash, or discard changes before deployment."
    }
}

function Assert-K98PathUnderRoot {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd("\", "/")
    $pathFull = [System.IO.Path]::GetFullPath($Path).TrimEnd("\", "/")
    $rootWithSeparator = $rootFull + [System.IO.Path]::DirectorySeparatorChar

    if (-not $pathFull.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $pathFull.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$Path' resolves outside repository root '$Root'."
    }
}

function Get-K98FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)

    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function ConvertTo-K98SqlLiteral {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return "NULL"
    }

    return "N'$($Value.Replace("'", "''"))'"
}

function Import-K98SqlServerModule {
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        throw "PowerShell SqlServer module is required for schema export tooling. Install it on the deployment machine before running live exports or drift checks."
    }

    Import-Module SqlServer -ErrorAction Stop
}

function New-K98SqlConnection {
    param(
        [Parameter(Mandatory=$true)][string]$ServerName,
        [Parameter(Mandatory=$true)][string]$DatabaseName
    )

    Add-Type -AssemblyName System.Data
    $connectionString = "Server=$ServerName;Database=$DatabaseName;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=15;"
    return New-Object System.Data.SqlClient.SqlConnection $connectionString
}

function Invoke-K98SqlQueryWithSqlClient {
    param(
        [Parameter(Mandatory=$true)][string]$ServerName,
        [Parameter(Mandatory=$true)][string]$DatabaseName,
        [Parameter(Mandatory=$true)][string]$Query,
        [int]$QueryTimeout = 120
    )

    $connection = New-K98SqlConnection -ServerName $ServerName -DatabaseName $DatabaseName
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = $QueryTimeout
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $table = New-Object System.Data.DataTable
        [void]$adapter.Fill($table)
        return $table.Rows
    }
    finally {
        $connection.Dispose()
    }
}

function Split-K98SqlBatches {
    param([Parameter(Mandatory=$true)][string]$SqlText)

    $batches = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    foreach ($line in ($SqlText -split "\r?\n")) {
        if ($line -match "^\s*GO\s*(?:--.*)?$") {
            $batch = $current.ToString().Trim()
            if (-not [string]::IsNullOrWhiteSpace($batch)) {
                $batches.Add($batch)
            }
            $current.Clear() | Out-Null
        }
        else {
            [void]$current.AppendLine($line)
        }
    }

    $finalBatch = $current.ToString().Trim()
    if (-not [string]::IsNullOrWhiteSpace($finalBatch)) {
        $batches.Add($finalBatch)
    }
    return $batches
}

function Invoke-K98SqlFileWithSqlClient {
    param(
        [Parameter(Mandatory=$true)][string]$ServerName,
        [Parameter(Mandatory=$true)][string]$DatabaseName,
        [Parameter(Mandatory=$true)][string]$InputFile,
        [int]$QueryTimeout = 0
    )

    $sqlText = Get-Content -Raw -Path $InputFile
    if ($sqlText -match "(?m)^\s*:") {
        throw "SQLCMD directives are not supported by the SqlClient fallback. Use plain migration SQL or install the SqlServer module."
    }

    $connection = New-K98SqlConnection -ServerName $ServerName -DatabaseName $DatabaseName
    try {
        $connection.Open()
        foreach ($batch in (Split-K98SqlBatches -SqlText $sqlText)) {
            $command = $connection.CreateCommand()
            $command.CommandText = $batch
            $command.CommandTimeout = $QueryTimeout
            [void]$command.ExecuteNonQuery()
        }
    }
    finally {
        $connection.Dispose()
    }
}

function Invoke-K98SqlQuery {
    param(
        [Parameter(Mandatory=$true)][string]$ServerName,
        [Parameter(Mandatory=$true)][string]$DatabaseName,
        [Parameter(Mandatory=$true)][string]$Query,
        [int]$QueryTimeout = 120
    )

    if (Get-Module -ListAvailable -Name SqlServer) {
        Import-Module SqlServer -ErrorAction Stop
        return Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -TrustServerCertificate -AbortOnError -Query $Query -QueryTimeout $QueryTimeout -ErrorAction Stop
    }

    return Invoke-K98SqlQueryWithSqlClient -ServerName $ServerName -DatabaseName $DatabaseName -Query $Query -QueryTimeout $QueryTimeout
}

function Invoke-K98SqlFile {
    param(
        [Parameter(Mandatory=$true)][string]$ServerName,
        [Parameter(Mandatory=$true)][string]$DatabaseName,
        [Parameter(Mandatory=$true)][string]$InputFile,
        [int]$QueryTimeout = 0
    )

    if (Get-Module -ListAvailable -Name SqlServer) {
        Import-Module SqlServer -ErrorAction Stop
        return Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -TrustServerCertificate -AbortOnError -InputFile $InputFile -QueryTimeout $QueryTimeout -ErrorAction Stop
    }

    return Invoke-K98SqlFileWithSqlClient -ServerName $ServerName -DatabaseName $DatabaseName -InputFile $InputFile -QueryTimeout $QueryTimeout
}

function Get-K98MigrationMetadata {
    param([Parameter(Mandatory=$true)][string]$Path)

    $metadata = @{}
    $lines = Get-Content -Path $Path -TotalCount 40
    foreach ($line in $lines) {
        if ($line -match "^\s*([A-Za-z][A-Za-z0-9]*):\s*(.*)\s*$") {
            $metadata[$matches[1]] = $matches[2].Trim()
        }
    }

    return $metadata
}
