function Assert-K98ExportBranchPrefix {
    param([Parameter(Mandatory=$true)][string]$ExportBranchPrefix)

    if (-not $ExportBranchPrefix.StartsWith("export/", [System.StringComparison]::Ordinal) -or
        $ExportBranchPrefix -notmatch '^export/[A-Za-z0-9][A-Za-z0-9._/-]*$' -or
        $ExportBranchPrefix.Contains("..") -or
        $ExportBranchPrefix.Contains("//") -or
        $ExportBranchPrefix.EndsWith("/", [System.StringComparison]::Ordinal)) {
        throw "Export branch prefix '$ExportBranchPrefix' must be a safe ref prefix below export/."
    }
}

function Get-K98ExpiredExportBranches {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$RemoteBranches,
        [Parameter(Mandatory=$true)][string]$ExportBranchPrefix,
        [Parameter(Mandatory=$true)][ValidateRange(1, 365)][int]$RetainCount
    )

    Assert-K98ExportBranchPrefix -ExportBranchPrefix $ExportBranchPrefix

    $remotePrefix = "origin/$ExportBranchPrefix-"
    $branchPattern = "^{0}[0-9]{{8}}-[0-9]{{6}}$" -f [regex]::Escape($remotePrefix)
    $matchingBranches = @(
        $RemoteBranches |
            ForEach-Object { $_.Trim() } |
            Where-Object {
                if ($_ -cnotmatch $branchPattern) {
                    return $false
                }

                $timestampText = $_.Substring($remotePrefix.Length)
                $parsedTimestamp = [DateTime]::MinValue
                return [DateTime]::TryParseExact(
                    $timestampText,
                    "yyyyMMdd-HHmmss",
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::None,
                    [ref]$parsedTimestamp
                )
            } |
            Sort-Object -Descending
    )

    return @(
        $matchingBranches |
            Select-Object -Skip $RetainCount |
            ForEach-Object { $_.Substring("origin/".Length) }
    )
}

function Invoke-K98NightlyExportRetention {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$ExportBranchPrefix,
        [Parameter(Mandatory=$true)][ValidateRange(1, 365)][int]$RetainCount
    )

    Assert-K98ExportBranchPrefix -ExportBranchPrefix $ExportBranchPrefix

    $currentBranch = Get-K98GitBranch -RepoRoot $RepoRoot
    if ($currentBranch -cne "main") {
        throw "Nightly export retention requires the repository to be on main; current branch is '$currentBranch'."
    }
    Assert-K98CleanGitTree -RepoRoot $RepoRoot

    try {
        Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("fetch", "origin", "--prune") | Out-Null
        $remoteRefResult = Invoke-K98Git `
            -RepoRoot $RepoRoot `
            -Arguments @("for-each-ref", "--format=%(refname:short)", "refs/remotes/origin")
        $remoteBranches = @(
            $remoteRefResult.Output -split "`r?`n" |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $expiredBranches = @(
            Get-K98ExpiredExportBranches `
                -RemoteBranches $remoteBranches `
                -ExportBranchPrefix $ExportBranchPrefix `
                -RetainCount $RetainCount
        )

        foreach ($branch in $expiredBranches) {
            Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("push", "origin", "--delete", $branch) | Out-Null
        }

        if ($expiredBranches.Count -gt 0) {
            Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("fetch", "origin", "--prune") | Out-Null
        }

        Write-K98JsonLog -RepoRoot $RepoRoot -LogName "export.jsonl" -Event @{
            script = "Invoke-NightlyProdSchemaExport.ps1"
            operation = "nightly_export_retention"
            status = "Succeeded"
            export_branch_prefix = $ExportBranchPrefix
            retained_branch_count = $RetainCount
            deleted_branch_count = $expiredBranches.Count
            deleted_branches = $expiredBranches
        }

        return $expiredBranches
    }
    catch {
        Write-K98JsonLog -RepoRoot $RepoRoot -LogName "export.jsonl" -Event @{
            script = "Invoke-NightlyProdSchemaExport.ps1"
            operation = "nightly_export_retention"
            status = "Failed"
            export_branch_prefix = $ExportBranchPrefix
            retained_branch_count = $RetainCount
            error_message = $_.Exception.Message
            recommended_action = "Review remote export branches and retry retention from a clean main checkout."
        }
        throw
    }
}

function Invoke-K98NightlyExportPostProcessing {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$ExportBranchPrefix,
        [Parameter(Mandatory=$true)][ValidateRange(1, 365)][int]$RetainCount,
        [switch]$NoGitCommitPush
    )

    if ($NoGitCommitPush) {
        $status = Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("status", "--porcelain")
        $preserveUncommittedChanges = -not [string]::IsNullOrWhiteSpace($status.Output)

        if (-not $preserveUncommittedChanges) {
            Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("switch", "main") | Out-Null
            Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("pull", "--ff-only", "origin", "main") | Out-Null
            Assert-K98CleanGitTree -RepoRoot $RepoRoot
        }

        $currentBranch = Get-K98GitBranch -RepoRoot $RepoRoot
        Write-K98JsonLog -RepoRoot $RepoRoot -LogName "export.jsonl" -Event @{
            script = "Invoke-NightlyProdSchemaExport.ps1"
            operation = "nightly_export_retention"
            status = "Skipped"
            reason = "NoGitCommitPush was specified."
            export_branch_prefix = $ExportBranchPrefix
            retained_branch_count = $RetainCount
            current_branch = $currentBranch
            preserved_uncommitted_changes = $preserveUncommittedChanges
        }

        return [pscustomobject]@{
            CurrentBranch = $currentBranch
            DeletedBranches = @()
            PreservedUncommittedChanges = $preserveUncommittedChanges
        }
    }

    Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("switch", "main") | Out-Null
    Invoke-K98Git -RepoRoot $RepoRoot -Arguments @("pull", "--ff-only", "origin", "main") | Out-Null
    Assert-K98CleanGitTree -RepoRoot $RepoRoot
    $deletedBranches = @(
        Invoke-K98NightlyExportRetention `
            -RepoRoot $RepoRoot `
            -ExportBranchPrefix $ExportBranchPrefix `
            -RetainCount $RetainCount
    )

    return [pscustomobject]@{
        CurrentBranch = "main"
        DeletedBranches = $deletedBranches
        PreservedUncommittedChanges = $false
    }
}
