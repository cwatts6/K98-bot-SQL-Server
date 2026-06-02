param(
    [string]$RepoPath,
    [string]$ExpectedSchemaPath,
    [Parameter(Mandatory=$true)][string]$ActualSchemaPath,
    [string]$ReportPath
)

. "$PSScriptRoot\SqlDeploy.Common.ps1"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Get-K98RepoRoot
}

$repoRoot = (Resolve-Path $RepoPath).ProviderPath
if ([string]::IsNullOrWhiteSpace($ExpectedSchemaPath)) {
    $ExpectedSchemaPath = Join-Path $repoRoot "sql_schema"
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportDir = Join-Path $repoRoot "reports"
    Ensure-K98Directory -Path $reportDir
    $ReportPath = Join-Path $reportDir ("drift_report_{0}.md" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
}

$started = Get-Date

function Get-SchemaFileMap {
    param([string]$Path)

    $map = @{}
    if (-not (Test-Path $Path)) {
        throw "Schema path not found: $Path"
    }

    foreach ($file in Get-ChildItem -Path $Path -Filter "*.sql" -File) {
        $map[$file.Name] = Get-K98FileSha256 -Path $file.FullName
    }
    return $map
}

try {
    $expected = Get-SchemaFileMap -Path $ExpectedSchemaPath
    $actual = Get-SchemaFileMap -Path $ActualSchemaPath

    $added = New-Object System.Collections.Generic.List[string]
    $removed = New-Object System.Collections.Generic.List[string]
    $modified = New-Object System.Collections.Generic.List[string]

    foreach ($name in $actual.Keys) {
        if (-not $expected.ContainsKey($name)) {
            $added.Add($name)
        }
        elseif ($expected[$name] -ne $actual[$name]) {
            $modified.Add($name)
        }
    }
    foreach ($name in $expected.Keys) {
        if (-not $actual.ContainsKey($name)) {
            $removed.Add($name)
        }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# SQL Drift Report")
    $lines.Add("")
    $lines.Add(("- Generated UTC: {0}" -f [DateTime]::UtcNow.ToString("o")))
    $lines.Add(('- Expected schema: `{0}`' -f $ExpectedSchemaPath))
    $lines.Add(('- Actual schema: `{0}`' -f $ActualSchemaPath))
    $lines.Add("- Added objects: $($added.Count)")
    $lines.Add("- Removed objects: $($removed.Count)")
    $lines.Add("- Modified objects: $($modified.Count)")
    $lines.Add("")
    if ($added.Count -eq 0 -and $removed.Count -eq 0 -and $modified.Count -eq 0) {
        $lines.Add("Verdict: no schema drift detected.")
    }
    else {
        $lines.Add("Verdict: schema drift detected. Review and reconcile through a SQL PR unless this is expected post-deployment drift.")
    }

    foreach ($section in @(
        @{ Name = "Added"; Items = $added },
        @{ Name = "Removed"; Items = $removed },
        @{ Name = "Modified"; Items = $modified }
    )) {
        $lines.Add("")
        $lines.Add("## $($section.Name) Objects")
        if ($section.Items.Count -eq 0) {
            $lines.Add("")
            $lines.Add("None.")
        }
        else {
            foreach ($item in ($section.Items | Sort-Object)) {
                $lines.Add(('- `{0}`' -f $item))
            }
        }
    }

    Set-Content -Path $ReportPath -Value $lines -Encoding UTF8

    $status = "Succeeded"
    if ($added.Count -gt 0 -or $removed.Count -gt 0 -or $modified.Count -gt 0) {
        $status = "DriftDetected"
    }

    Write-K98JsonLog -RepoRoot $repoRoot -LogName "drift.jsonl" -Event @{
        script = "Compare-ProdSchema.ps1"
        operation = "compare_schema"
        status = $status
        expected_schema_path = $ExpectedSchemaPath
        actual_schema_path = $ActualSchemaPath
        report_path = $ReportPath
        added_count = $added.Count
        removed_count = $removed.Count
        modified_count = $modified.Count
        duration_ms = [int]((Get-Date) - $started).TotalMilliseconds
    }

    Write-Host "Drift report written to $ReportPath"
    if ($status -eq "DriftDetected") {
        exit 2
    }
}
catch {
    Write-K98JsonLog -RepoRoot $repoRoot -LogName "drift.jsonl" -Event @{
        script = "Compare-ProdSchema.ps1"
        operation = "compare_schema"
        status = "Failed"
        error_message = $_.Exception.Message
    }
    throw
}
