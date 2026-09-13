# Offline S8A/S8B runner regression tests. No SQL connection, SQL execution or operational logs.
param([string]$RepoPath = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$runner = Join-Path $RepoPath 'deploy/Deploy-SqlMigration.ps1'
$common = Join-Path $RepoPath 'deploy/SqlDeploy.Common.ps1'
function Import-TestFunction([string]$Path, [string]$Name) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "PowerShell parse failed: $Path" }
    $function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name }, $true)
    if (-not $function) { throw "Missing function: $Name" }
    return $function.Extent.Text
}
. ([scriptblock]::Create((Import-TestFunction $common 'Split-K98SqlBatches')))
. ([scriptblock]::Create((Import-TestFunction $runner 'Invoke-K98ReviewedMigration')))
. ([scriptblock]::Create((Import-TestFunction $runner 'Invoke-K98S8AMigration')))
$script:connections = @()
$script:failAt = 0
function New-K98SqlConnection {
    param([string]$ServerName, [string]$DatabaseName)
    if ($ServerName -ne 'synthetic' -or $DatabaseName -ne 'synthetic') { throw 'Unexpected mock target' }
    $c = [pscustomobject]@{ Opened = $false; Disposed = $false; Commands = [System.Collections.Generic.List[object]]::new() }
    $c | Add-Member ScriptMethod Open { $this.Opened = $true }
    $c | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
    $c | Add-Member ScriptMethod CreateCommand {
        $command = [pscustomobject]@{ Owner = $this; CommandText = ''; CommandTimeout = 0; Disposed = $false }
        $command | Add-Member ScriptMethod ExecuteNonQuery {
            if (-not $this.Owner.Opened -or $this.Owner.Disposed) { throw 'Invalid connection lifetime' }
            $this.Owner.Commands.Add($this)
            if ($script:failAt -gt 0 -and $this.Owner.Commands.Count -eq $script:failAt) { throw 'synthetic SQL failure' }
            return 0
        }
        $command | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
        return $command
    }
    $script:connections += $c
    return $c
}
function Assert-Test([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('k98-s8a-runner-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
$inputPath = Join-Path $temp 'input.sql'; $migrationPath = Join-Path $temp 'migration.sql'
[System.IO.File]::WriteAllText($inputPath, "SELECT 'prelude-1';`nGO`nSELECT 'prelude-2';")
[System.IO.File]::WriteAllText($migrationPath, "SELECT 'migration';")
$hash = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
$argsForTest = @{ ServerName = 'synthetic'; DatabaseName = 'synthetic'; InputFile = $migrationPath; ApprovalFile = $inputPath; ApprovalSha256 = $hash }
Invoke-K98S8AMigration @argsForTest
Assert-Test ($script:connections.Count -eq 1) 'Expected exactly one connection'
$c = $script:connections[0]
Assert-Test ($c.Commands.Count -eq 4 -and $c.Disposed) 'Batch count or disposal wrong'
Assert-Test ($c.Commands[0].CommandText -match 'prelude-1' -and $c.Commands[1].CommandText -match 'prelude-2' -and $c.Commands[3].CommandText -match 'migration') 'Input/migration order wrong'
Assert-Test ($c.Commands[2].CommandText -match 'SchemaMigrationHistory' -and $c.Commands[2].CommandText -match 'apply-only') 'Ledger/apply guard missing'
Assert-Test (@($c.Commands | Where-Object { -not $_.Disposed -or $_.CommandTimeout -ne 120 }).Count -eq 0) 'Commands not disposed or unbounded timeout'
$script:connections = @(); $script:failAt = 3
try { Invoke-K98S8AMigration @argsForTest; throw 'Expected propagated error' }
catch { if ($_.Exception.Message -notmatch 'synthetic SQL failure') { throw } }
Assert-Test ($script:connections[0].Commands.Count -eq 3 -and $script:connections[0].Disposed) 'Guard failure reached migration or leaked session'
$script:connections = @(); $script:failAt = 0
$argsForTest.ApprovalSha256 = ('0' * 64)
try { Invoke-K98S8AMigration @argsForTest; throw 'Expected hash rejection' }
catch { if ($_.Exception.Message -notmatch 'hash mismatch') { throw } }
Assert-Test ($script:connections.Count -eq 0) 'Hash mismatch connected'
[System.IO.File]::WriteAllText($inputPath, ':r unsafe.sql')
$argsForTest.ApprovalSha256 = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
try { Invoke-K98S8AMigration @argsForTest; throw 'Expected directive rejection' }
catch { if ($_.Exception.Message -notmatch 'SQLCMD directives') { throw } }
Assert-Test ($script:connections.Count -eq 0) 'Directive rejection connected'
# Retain tiny synthetic input files as local test evidence. Do not remove any database/file history.
Write-Host 'PASS: same connection and batch order; apply/history guard placement; timeout/disposal; guard failure propagation; hash and directive rejection before connection.'
Write-Host "Synthetic local evidence: $temp"


# S8B exercises the shared session executor with its own approval contract.
[System.IO.File]::WriteAllText($inputPath, "SELECT 's8b-prelude';")
$argsForTest.ApprovalSha256 = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
$script:connections = @(); $script:failAt = 0
Invoke-K98ReviewedMigration @argsForTest -ApprovalKind S8B
$c = $script:connections[0]
Assert-Test ($script:connections.Count -eq 1 -and $c.Commands.Count -eq 3 -and $c.Disposed) 'S8B did not retain one bounded session'
Assert-Test ($c.Commands[0].CommandText -match 's8b-prelude' -and $c.Commands[2].CommandText -match 'migration') 'S8B batch order differs'
Assert-Test ($c.Commands[1].CommandText -match '#S8BNoFightApproval' -and $c.Commands[1].CommandText -notmatch '#S8AApproval' -and $c.Commands[1].CommandText -match 'SchemaMigrationHistory' -and $c.Commands[1].CommandText -match 'apply-only' -and $c.Commands[1].CommandText -match 'DATALENGTH\(Mode\)<>5') 'S8B apply/history contract is missing'
foreach ($failure in @(2,3)) {
    $script:connections = @(); $script:failAt = $failure
    try { Invoke-K98ReviewedMigration @argsForTest -ApprovalKind S8B; throw 'Expected S8B execution failure' }
    catch { if ($_.Exception.Message -notmatch 'synthetic SQL failure') { throw } }
    Assert-Test ($script:connections[0].Disposed -and $script:connections[0].Commands.Count -eq $failure) 'S8B failure continued or leaked session'
}
$script:connections = @(); $script:failAt = 0
$argsForTest.ApprovalSha256 = ('0' * 64)
try { Invoke-K98ReviewedMigration @argsForTest -ApprovalKind S8B; throw 'Expected S8B hash rejection' }
catch { if ($_.Exception.Message -notmatch 'hash mismatch') { throw } }
Assert-Test ($script:connections.Count -eq 0) 'S8B hash mismatch connected'
[System.IO.File]::WriteAllText($inputPath, ':r unsafe.sql')
$argsForTest.ApprovalSha256 = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant()
try { Invoke-K98ReviewedMigration @argsForTest -ApprovalKind S8B; throw 'Expected S8B directive rejection' }
catch { if ($_.Exception.Message -notmatch 'SQLCMD directives') { throw } }
Assert-Test ($script:connections.Count -eq 0) 'S8B directive rejection connected'

# Execute the actual runner parameter gates without its operational body.
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$errors)
$gates = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.IfStatementAst] -and $_.Extent.Text -match '^if \(\$S8[AB]InputFile -or' })
$gateScript = [scriptblock]::Create($ast.ParamBlock.Extent.Text + "`n" + (($gates | ForEach-Object { $_.Extent.Text }) -join "`n"))
$valid = @{ ServerName='synthetic'; DatabaseName='synthetic'; MigrationId='20260913_001_kvk_source_update_no_fight_context'; S8BInputFile=$inputPath; S8BInputSha256=('a' * 64) }
& $gateScript @valid
foreach ($field in @('ServerName','DatabaseName','MigrationId','S8BInputFile','S8BInputSha256')) {
    $invalid = $valid.Clone(); $invalid.Remove($field)
    try { & $gateScript @invalid; throw 'Expected exact-input rejection' }
    catch { if ($_.Exception.Message -notmatch 'S8B inputs require exact') { throw } }
}
$invalid=$valid.Clone(); $invalid.MigrationId='20260912_001_kvk_season_complete_updates'
try { & $gateScript @invalid; throw 'Expected cross-migration rejection' }
catch { if ($_.Exception.Message -notmatch 'S8B inputs require exact') { throw } }

# Execute the actual pending guard and application loop with mock persistence.
# All dependencies here are fakes; neither the runner body nor SQL is invoked.
$guardNode=$ast.Find({param($node) $node -is [System.Management.Automation.Language.IfStatementAst] -and $node.Extent.Text -match "^if \(@\(\`$pending" -and $node.Extent.Text -match 'Pending S8B requires'},$true)
$applyNode=$ast.Find({param($node) $node -is [System.Management.Automation.Language.ForEachStatementAst] -and $node.Variable.VariablePath.UserPath -eq 'file' -and $node.Extent.Text -match 'Applying migration'},$true)
Assert-Test ($null -ne $guardNode -and $null -ne $applyNode) 'Runner pending/application blocks missing'
$pending=@([System.IO.FileInfo]::new((Join-Path $temp '20260913_001_kvk_source_update_no_fight_context.sql')))
$S8BInputFile=$null
try { . ([scriptblock]::Create($guardNode.Extent.Text)); throw 'Expected pending S8B gate' }
catch { if ($_.Exception.Message -notmatch 'Pending S8B requires') { throw } }
$S8BInputFile=$inputPath; $S8BInputSha256='synthetic-hash'; $ServerName='synthetic'; $DatabaseName='synthetic'
$repoRoot=$temp; $deploymentId=[guid]::NewGuid()
$script:events=@(); $script:migrationFails=$false
function Get-K98FileSha256 { param($Path) return 'synthetic-migration-hash' }
function Invoke-K98SqlFile { throw 'S8B must not use the ordinary independent-session path' }
function Invoke-K98ReviewedMigration {
    param($ApprovalKind,$ServerName,$DatabaseName,$InputFile,$ApprovalFile,$ApprovalSha256)
    Assert-Test ($ApprovalKind -ceq 'S8B' -and $ApprovalFile -eq $inputPath -and $ApprovalSha256 -eq 'synthetic-hash') 'Wrong S8B dispatch inputs'
    $script:events += 'execute'
    if ($script:migrationFails) { throw 'synthetic migration rejection' }
}
function Write-K98MigrationHistory { param($MigrationId,$MigrationFile,$Checksum,$Status,$ErrorMessage,$DurationMs) $script:events += $Status }
function Write-K98JsonLog { param($RepoRoot,$LogName,$Event) }
. ([scriptblock]::Create($guardNode.Extent.Text))
. ([scriptblock]::Create($applyNode.Extent.Text))
Assert-Test (($script:events -join ',') -eq 'execute,Applied') 'Successful S8B application not followed by Applied history'
$script:events=@(); $script:migrationFails=$true
try { . ([scriptblock]::Create($applyNode.Extent.Text)); throw 'Expected migration failure' }
catch { if ($_.Exception.Message -notmatch 'synthetic migration rejection') { throw } }
Assert-Test (($script:events -join ',') -eq 'execute,Failed') 'Failed S8B application incorrectly recorded Applied'
Write-Host 'PASS: S8B exact-input gates, session/guard/hash/directive rejection, pending gate, dispatch and Applied/Failed history ordering (offline mocks only).'
