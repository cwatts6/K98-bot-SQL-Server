#requires -Version 5.1
param([string]$TestRoot = (Join-Path ([IO.Path]::GetTempPath()) ('k98-check-sidecars-' + [guid]::NewGuid().ToString('N'))))
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'deploy\Validate-SqlRepo.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Validator parse failed' }
$functions=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-K98ReleaseCheckSidecars'},$false))
if ($functions.Count -ne 1) { throw 'Exact sidecar validator missing' }
. ([scriptblock]::Create($functions[0].Extent.Text))
if (Test-Path -LiteralPath $TestRoot) { throw 'Fresh test root required' }
$null=New-Item -ItemType Directory -Path $TestRoot
$utf8=[Text.UTF8Encoding]::new($false)
$id='20261124_001_sidecar_fixture'
$passed=0
function Write-Text($path,$text) { [IO.File]::WriteAllText($path,$text,$utf8) }
function Hash-File($path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function New-Fixture($name) {
    $root=Join-Path $TestRoot $name
    $dir=Join-Path $root 'migrations'
    $null=New-Item -ItemType Directory -Path $dir
    foreach ($suffix in @('.sql','.before.sql','.after.sql')) { Write-Text (Join-Path $dir ($id+$suffix)) "SELECT 1;`n" }
    $profile=@{version=1;migration_id=$id;script=@{file=($id+'.sql');sha256=(Hash-File (Join-Path $dir ($id+'.sql')))};checks=@{}}
    foreach ($kind in @('before','after')) {
        $file=$id+'.'+$kind+'.sql'
        $profile.checks[$kind]=@{file=$file;sha256=(Hash-File (Join-Path $dir $file))}
    }
    Write-Text (Join-Path $dir ($id+'.release.json')) ($profile|ConvertTo-Json -Depth 8)
    return @{root=$root;directory=$dir;profile=$profile;profilePath=(Join-Path $dir ($id+'.release.json'))}
}
$f=New-Fixture 'valid'
$result=@(Get-K98ReleaseCheckSidecars $f.root)
if ($result.Count -ne 2 -or ($id+'.sql') -cin $result -or ($id+'.before.sql') -cnotin $result -or ($id+'.after.sql') -cnotin $result) { throw 'Valid pair not recognised precisely' }
$passed++
foreach ($case in @('orphan','profile_identity','main_name','main_drift','before_drift','missing_after','path_escape','bad_digest','missing_checks','extra_orphan','credential_pattern')) {
    $f=New-Fixture $case
    switch ($case) {
        'orphan' { $f.profilePath=Join-Path $f.directory 'unrelated.json'; Move-Item -LiteralPath (Join-Path $f.directory ($id+'.release.json')) -Destination $f.profilePath }
        'profile_identity' { $f.profile.migration_id='20261124_002_other' }
        'main_name' { $f.profile.script.file='other.sql' }
        'main_drift' { Write-Text (Join-Path $f.directory ($id+'.sql')) 'SELECT 2;' }
        'before_drift' { Write-Text (Join-Path $f.directory ($id+'.before.sql')) 'SELECT 2;' }
        'missing_after' { Move-Item -LiteralPath (Join-Path $f.directory ($id+'.after.sql')) -Destination (Join-Path $f.directory 'retained-after.txt') }
        'path_escape' { $f.profile.checks.before.file='..\outside.sql' }
        'bad_digest' { $f.profile.checks.after.sha256='invalid' }
        'missing_checks' { $f.profile.Remove('checks') }
        'extra_orphan' { Write-Text (Join-Path $f.directory '20261124_002_orphan.before.sql') 'SELECT 1;' }
        'credential_pattern' {
            $path=Join-Path $f.directory ($id+'.before.sql');Write-Text $path '-- Password=fixture-only'
            $f.profile.checks.before.sha256=Hash-File $path
        }
    }
    Write-Text $f.profilePath ($f.profile|ConvertTo-Json -Depth 8)
    $refused=$false
    try { $null=Get-K98ReleaseCheckSidecars $f.root } catch { $refused=$true }
    if (-not $refused) { throw "Invalid sidecar admitted: $case" }
    $passed++
}
Write-Output "PASS: $passed release-check cases; no SQL execution; fixtures retained at $TestRoot"
