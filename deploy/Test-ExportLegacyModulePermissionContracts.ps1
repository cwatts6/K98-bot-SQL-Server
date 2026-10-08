param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
# Pure source validation. No SQL client, connection, signing key or live process.
$checks = 0
function Assert-Contract([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Read-Source([string]$Path) {
    return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $Path)).Replace("`r`n", "`n")
}
function Get-HexHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
$manifestPath = Join-Path $RepositoryRoot 'deploy/export_legacy_module_permission_manifest.json'
$manifestHash = Get-HexHash ([IO.File]::ReadAllBytes($manifestPath))
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$forward = Read-Source 'migrations/20260924_002_export_legacy_module_permissions.sql'
$reverse = Read-Source 'migrations/rollback/20260924_002_export_legacy_module_permissions_rollback.sql'
$validation = Read-Source 'validation/kvk_source/s11_export_legacy_module_permissions.sql'
Assert-Contract ($manifest.version -eq 1 -and $manifest.database -ceq 'ROK_TRACKER' -and $manifest.default_schema -ceq 'dbo') 'Target contract changed'
$expectedRoots = @('dbo.UPDATE_ALL2','dbo.SP_Stats_for_Upload','dbo.sp_TARGETS_MASTER','dbo.sp_Upsert_ProcConfig_From_Staging','KVK.sp_KVK_AllPlayers_Ingest','KVK.sp_KVK_Recompute_Windows','KVK.sp_KVK_Get_Exports')
Assert-Contract (($manifest.roots -join '|') -ceq ($expectedRoots -join '|')) 'Exact root identities/order differ'
Assert-Contract ($manifest.modules.Count -eq 38 -and $manifest.signatures.Count -eq 26) 'Module/signature inventory shape changed; re-review exact identities'
$formsPath = Join-Path $RepositoryRoot $manifest.compatibility_forms
Assert-Contract ((Get-HexHash ([IO.File]::ReadAllBytes($formsPath))) -ceq $manifest.compatibility_forms_sha256) 'Equivalent script edit recipe drift'
$forms = (Get-Content -Raw -LiteralPath $formsPath | ConvertFrom-Json).forms
Assert-Contract ($forms.Count -eq 27 -and @($forms.module | Select-Object -Unique).Count -eq 27) 'Exact 27 equivalent script recipes required'
foreach ($form in $forms) {
    Assert-Contract (@($manifest.modules | Where-Object name -CEQ $form.module).Count -eq 1) 'Unknown equivalent script module'
}
# These manifests intentionally describe the historical permission installation.
# Validate the independently guarded forward migration before reconstructing
# its exact historical source bytes for the three changed modules. This does
# not admit new definitions to the historical signing/install allowlists.
& (Join-Path $RepositoryRoot 'deploy/Test-SqlAuthImportFileVisibility.ps1') -RepositoryRoot $RepositoryRoot
$fileVisibilityModules = @('dbo.ARCHIVE_IMPORT_STAGING_FILE','dbo.CLAIM_KS4_IMPORT_FILE','dbo.IMPORT_STAGING_PROC_CORE')
foreach ($module in $manifest.modules) {
    $sourceBytes = [IO.File]::ReadAllBytes((Join-Path $RepositoryRoot $module.path))
    if ($module.name -cin $fileVisibilityModules) {
        $current = [Text.Encoding]::UTF8.GetString($sourceBytes).Replace("`r`n", "`n")
        $current = [regex]::Replace($current,
            'SET (@\w+) = COALESCE\(\(SELECT file_exists FROM sys\.dm_os_file_exists\((@\w+)\)\), 0\);',
            'EXEC master.dbo.xp_fileexist $2, $1 OUTPUT;')
        $sourceBytes = [Text.Encoding]::UTF8.GetBytes($current.Replace("`n", "`r`n"))
    }
    Assert-Contract ((Get-HexHash $sourceBytes) -ceq $module.source_sha256) "Source byte drift: $($module.name)"
    $raw = [Text.Encoding]::UTF8.GetString($sourceBytes).TrimStart([char]0xfeff).Replace("`r`n", "`n")
    $match = [regex]::Match($raw, '(?im)^(ALTER|CREATE OR ALTER)\s+(PROCEDURE|FUNCTION)\b')
    Assert-Contract $match.Success "Definition missing: $($module.name)"
    $definition = [regex]::Replace($raw.Substring($match.Index), '(?im)^GO\s*\z', '').Trim([char[]]" `t`r`n")
    $definition = [regex]::Replace($definition, '^(ALTER|CREATE OR ALTER)\b', 'CREATE')
    Assert-Contract ((Get-HexHash ([Text.Encoding]::Unicode.GetBytes($definition))) -ceq $module.definition_sha256) "Canonical definition drift: $($module.name)"
    $form = @($forms | Where-Object module -CEQ $module.name)
    Assert-Contract (@($module.compatible_definition_sha256 | Where-Object { $null -ne $_ }).Count -eq $form.Count) "Equivalent script count differs: $($module.name)"
    if ($form.Count -eq 1) {
        Assert-Contract ($form[0].source_definition_sha256 -ceq $module.definition_sha256) 'Equivalent script base source drift'
        $lines = [Collections.Generic.List[string]]::new()
        foreach ($line in [regex]::Matches($definition, '[^\n]*\n|[^\n]+$')) { $lines.Add($line.Value) }
        foreach ($edit in @($form[0].edits | Sort-Object start -Descending)) {
            $offset = [int]$edit.start
            Assert-Contract ($offset -ge 0 -and $offset + $edit.before.Count -le $lines.Count) 'Equivalent script edit outside source'
            for ($i=0; $i -lt $edit.before.Count; $i++) {
                Assert-Contract ($lines[$offset+$i] -ceq $edit.before[$i]) 'Equivalent script preimage differs'
            }
            $lines.RemoveRange($offset, $edit.before.Count)
            $lines.InsertRange($offset, [string[]]@($edit.after))
        }
        $variantHash = Get-HexHash ([Text.Encoding]::Unicode.GetBytes(($lines -join '')))
        Assert-Contract ($variantHash -ceq $module.compatible_definition_sha256[0]) 'Equivalent script source-derived hash differs'
        $variantRow = "(N'$($module.name)',0x$variantHash)"
        foreach ($script in @($forward,$reverse,$validation)) {
            Assert-Contract ($script.Contains($variantRow)) 'Equivalent script SQL allowlist differs'
            Assert-Contract ($script.Contains('AND NOT EXISTS(SELECT 1 FROM @CompatibleDefinitions WHERE ModuleName=@ModuleName')) 'Missing exact module-bound compatibility guard'
        }
    }
    $context = if ($null -eq $module.execute_as) { 'NULL' } else { [string]$module.execute_as }
    $row = "(N'$($module.name)',0x$($module.definition_sha256),'$($module.object_type)',$context)"
    foreach ($script in @($forward,$reverse,$validation)) {
        Assert-Contract ($script.Contains($row)) "Missing exact source row: $($module.name)"
    }
}
foreach ($s in $manifest.signatures) {
    $row = "(N'$($s.module)',N'$($s.certificate)','$($s.crypt_type)')"
    Assert-Contract (@($manifest.modules | Where-Object name -CEQ $s.module).Count -eq 1) "Unknown signature module: $($s.module)"
    Assert-Contract ($s.crypt_type -cin @('SPVC','CPVC')) 'Unknown signature type'
    Assert-Contract (($s.crypt_type -ceq 'SPVC') -eq ($s.module -cin @('dbo.UPDATE_ALL2','dbo.sp_TARGETS_MASTER','dbo.SP_Stats_for_Upload'))) "Only three roots may receive a privilege-granting signature: $($s.module)"
    foreach ($script in @($forward,$reverse,$validation)) { Assert-Contract ($script.Contains($row)) "Signature pair differs: $row" }
    $counter = if ($s.crypt_type -ceq 'CPVC') { 'COUNTER ' } else { '' }
    Assert-Contract ($reverse.Contains("DROP ${counter}SIGNATURE FROM OBJECT::$($s.module) BY CERTIFICATE $($s.certificate);")) 'Missing exact reverse signature'
}
foreach ($query in $manifest.scan_queries) {
    Assert-Contract ((Get-HexHash ([IO.File]::ReadAllBytes((Join-Path $RepositoryRoot $query.source)))) -ceq $query.sha256) "Capture source drift: $($query.object)"
}
foreach ($script in @($forward,$reverse,$validation)) {
    Assert-Contract ($script.Contains("DECLARE @ManifestHash char(64)='$manifestHash';")) 'Manifest content hash differs'
    foreach ($guard in @('Missing, extra, duplicate or invalid signature input.', 'Module definition differs from independently approved source; never sign installed drift.', 'sys.fn_check_object_signatures', 's.Signature=p.crypt_property', 'p.state<>''G''', 'p.minor_id<>0')) {
        Assert-Contract ($script.Contains($guard)) "Missing exact guard: $guard"
    }
    Assert-Contract (-not ($script -match '(?im)^\s*(CREATE\s+CERTIFICATE|ALTER\s+ROLE\s+\w+\s+ADD\s+MEMBER|GRANT\s+CONTROL\s+SERVER|EXEC\s+(?:master\.)?(?:dbo\.)?xp_cmdshell|TRUNCATE\s+TABLE|DROP\s+TABLE)\b')) 'Unapproved key, role membership, root execution, escalation or data deletion'
}
Assert-Contract ($reverse.Contains('Entry role still has members; approved drain and unmapping required.')) 'Rollback must refuse mapped application identities'
Assert-Contract (-not ($reverse -match '(?im)^\s*DROP\s+CERTIFICATE\b')) 'Signing evidence must be retained'
Assert-Contract (-not ($validation -match '(?im)^\s*(CREATE\s+(USER|LOGIN|ROLE)|GRANT|REVOKE|DENY|ADD\s+(COUNTER\s+)?SIGNATURE|DROP\s+)\b')) 'Metadata validation must not install/reverse privileges'
Write-Output "PASS: $checks offline legacy permission source checks. No installation, transaction, proxy or deployment proof."
