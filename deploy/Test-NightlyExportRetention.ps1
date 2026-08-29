$ErrorActionPreference = "Stop"

. "$PSScriptRoot\SqlDeploy.Common.ps1"
. "$PSScriptRoot\NightlyExportRetention.ps1"

function Assert-K98SequenceEqual {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$Expected,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$Actual,
        [Parameter(Mandatory=$true)][string]$Message
    )

    if (($Expected -join "`n") -ne ($Actual -join "`n")) {
        throw "$Message Expected: [$($Expected -join ', ')]. Actual: [$($Actual -join ', ')]."
    }
}

$remoteBranches = @(
    "origin/main",
    "origin/codex/keep-me",
    "origin/export/prod-schema-latest",
    "origin/export/prod-schema-20260815-013000-extra",
    "origin/export/prod-schema-2026081-013000",
    "origin/export/PROD-SCHEMA-20260815-013000",
    "origin/export/other-20260815-013000"
)
foreach ($day in 1..16) {
    $remoteBranches += "origin/export/prod-schema-202608{0:D2}-013000" -f $day
}

$expired = @(
    Get-K98ExpiredExportBranches `
        -RemoteBranches $remoteBranches `
        -ExportBranchPrefix "export/prod-schema" `
        -RetainCount 14
)
Assert-K98SequenceEqual `
    -Expected @(
        "export/prod-schema-20260802-013000",
        "export/prod-schema-20260801-013000"
    ) `
    -Actual $expired `
    -Message "Retention must select only the oldest correctly formatted snapshot branches."

$noneExpired = @(
    Get-K98ExpiredExportBranches `
        -RemoteBranches @("origin/main", "origin/export/prod-schema-latest") `
        -ExportBranchPrefix "export/prod-schema" `
        -RetainCount 14
)
Assert-K98SequenceEqual `
    -Expected @() `
    -Actual $noneExpired `
    -Message "Retention must ignore non-snapshot branches."

$invalidPrefixes = @("main", "export/../main", "export/prod-schema//unsafe", "export/prod-schema*")
foreach ($invalidPrefix in $invalidPrefixes) {
    $threw = $false
    try {
        Get-K98ExpiredExportBranches `
            -RemoteBranches @("origin/export/prod-schema-20260816-013000") `
            -ExportBranchPrefix $invalidPrefix `
            -RetainCount 14 | Out-Null
    }
    catch {
        $threw = $true
    }
    if (-not $threw) {
        throw "Unsafe export prefix '$invalidPrefix' was not rejected."
    }
}

function Invoke-K98RetentionTestGit {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)

    $output = & git @Arguments 2>&1 | ForEach-Object { $_.ToString() }
    if ($LASTEXITCODE -ne 0) {
        throw "Test git command failed: git $($Arguments -join ' '). $($output -join [Environment]::NewLine)"
    }
    return ($output -join "`n").Trim()
}

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd("\", "/")
$testRoot = Join-Path $tempBase ("k98-nightly-retention-test-" + [Guid]::NewGuid().ToString("N"))
$bareRepo = Join-Path $testRoot "origin.git"
$workRepo = Join-Path $testRoot "work"

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    Invoke-K98RetentionTestGit -Arguments @("init", "--bare", $bareRepo) | Out-Null
    Invoke-K98RetentionTestGit -Arguments @("init", "-b", "main", $workRepo) | Out-Null
    Invoke-K98RetentionTestGit -Arguments @("-C", $workRepo, "config", "user.name", "K98 Retention Test") | Out-Null
    Invoke-K98RetentionTestGit -Arguments @("-C", $workRepo, "config", "user.email", "retention-test@example.invalid") | Out-Null
    Invoke-K98RetentionTestGit -Arguments @("-C", $workRepo, "commit", "--allow-empty", "-m", "retention test seed") | Out-Null
    Invoke-K98RetentionTestGit -Arguments @("-C", $workRepo, "remote", "add", "origin", $bareRepo) | Out-Null
    Invoke-K98RetentionTestGit -Arguments @("-C", $workRepo, "push", "-u", "origin", "main") | Out-Null

    $seedCommit = Invoke-K98RetentionTestGit -Arguments @("-C", $workRepo, "rev-parse", "HEAD")
    foreach ($day in 1..16) {
        $branch = "export/prod-schema-202608{0:D2}-013000" -f $day
        Invoke-K98RetentionTestGit `
            -Arguments @("--git-dir=$bareRepo", "update-ref", "refs/heads/$branch", $seedCommit) | Out-Null
    }
    Invoke-K98RetentionTestGit `
        -Arguments @("--git-dir=$bareRepo", "update-ref", "refs/heads/export/prod-schema-latest", $seedCommit) | Out-Null
    Invoke-K98RetentionTestGit `
        -Arguments @("--git-dir=$bareRepo", "update-ref", "refs/heads/export/PROD-SCHEMA-20260815-013000", $seedCommit) | Out-Null
    Invoke-K98RetentionTestGit `
        -Arguments @("--git-dir=$bareRepo", "update-ref", "refs/heads/codex/keep-me", $seedCommit) | Out-Null

    $deleted = @(
        Invoke-K98NightlyExportRetention `
            -RepoRoot $workRepo `
            -ExportBranchPrefix "export/prod-schema" `
            -RetainCount 14
    )
    Assert-K98SequenceEqual `
        -Expected @(
            "export/prod-schema-20260802-013000",
            "export/prod-schema-20260801-013000"
        ) `
        -Actual $deleted `
        -Message "Integration retention deleted an unexpected branch set."

    $remainingHeads = @(
        (Invoke-K98RetentionTestGit -Arguments @("ls-remote", "--heads", $bareRepo)) -split "`r?`n" |
            ForEach-Object { ($_ -split "\s+")[-1] }
    )
    $remainingSnapshots = @(
        $remainingHeads |
            Where-Object { $_ -match '^refs/heads/export/prod-schema-[0-9]{8}-[0-9]{6}$' }
    )
    if ($remainingSnapshots.Count -ne 14) {
        throw "Integration retention kept $($remainingSnapshots.Count) timestamped snapshots instead of 14."
    }
    foreach ($protectedRef in @(
        "refs/heads/main",
        "refs/heads/codex/keep-me",
        "refs/heads/export/prod-schema-latest",
        "refs/heads/export/PROD-SCHEMA-20260815-013000"
    )) {
        if ($remainingHeads -notcontains $protectedRef) {
            throw "Integration retention removed protected decoy ref '$protectedRef'."
        }
    }
}
finally {
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $tempPrefix = $tempBase + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTestRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (Split-Path $resolvedTestRoot -Leaf).StartsWith("k98-nightly-retention-test-", [System.StringComparison]::Ordinal)) {
        throw "Refusing to remove unexpected retention test path '$resolvedTestRoot'."
    }
    if (Test-Path -LiteralPath $resolvedTestRoot) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

Write-Host "Nightly export retention tests passed."
