# Offline S8A runner regression test. No SQL connection, SQL execution or operational logs.
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
