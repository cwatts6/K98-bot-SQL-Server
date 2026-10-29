# Offline PowerShell 5.1 parser/dispatch tests. Never opens a SQL connection.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
foreach($path in @('deploy/SqlDeploy.ModuleRelease.ps1','deploy/SqlDeploy.MgeFinalisation.ps1','validation/Test-MgeFinalisationImages.ps1','validation/Invoke-MgeInstallFaultChild.ps1')){
    $tokens=$null;$errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $path),[ref]$tokens,[ref]$errors)
    if($errors.Count){throw ($errors|Out-String)}
}
. "$root/deploy/SqlDeploy.ModuleRelease.ps1"
. "$root/deploy/SqlDeploy.MgeFinalisation.ps1"
$json='{"version":1,"profile":"mge_finalisation_v1","migration_id":"20261029_001_mge_board_finalisation","database_collation":"Latin1_General_CI_AS","tempdb_collation":"SQL_Latin1_General_CP1_CI_AS","compatibility_level":160,"requires":[]}'
$loaded=Read-K98MgeProfile ($json|ConvertFrom-Json)
if($loaded.Commands.Count -ne 5 -or $loaded.Triggers.Count -ne 3){throw 'Fixed five driver batches required'}
if($loaded.Commands[0] -notmatch 'Revision rowversion NOT NULL' -or $loaded.Commands[1] -notmatch 'CREATE INDEX IX_MGE_BoardFinalisation_Work'){throw 'Fixed table/index contract missing'}
foreach($t in $loaded.Triggers){if(-not $t.Sql.StartsWith('CREATE TRIGGER dbo.tr_MGE_') -or $t.Sql -match '(?im)^\s*GO\s*$'){throw 'Single trigger driver batch required'}}
foreach($mutate in @(
    {param($p) $p|Add-Member sql 'SELECT 1'},
    {param($p) $p.version=$true},
    {param($p) $p.compatibility_level='160'},
    {param($p) $p.database_collation='bad; SQL'},
    {param($p) $p.tempdb_collation=123},
    {param($p) $p.requires=@{}}
)){
    $p=$json|ConvertFrom-Json;& $mutate $p;$refused=$false
    try{$null=Read-K98MgeProfile $p}catch{$refused=$true}
    if(-not $refused){throw 'Malformed profile accepted'}
}
$temporary=[IO.Path]::GetTempFileName()
try{
    [IO.File]::WriteAllText($temporary,$json,[Text.UTF8Encoding]::new($false))
    $hash=Get-K98ModuleHash ([IO.File]::ReadAllBytes($temporary))
    $dispatched=Read-K98ModuleProfile $temporary $hash '20261029_001_mge_board_finalisation'
    if($dispatched.Commands.Count -ne 5){throw 'MGE dispatch failed'}
    $refused=$false
    try{$null=Read-K98ModuleProfile $temporary ('a'*64) '20261029_001_mge_board_finalisation'}catch{$refused=$true}
    if(-not $refused){throw 'Changed profile bytes accepted'}
}finally{Remove-Item -LiteralPath $temporary}
Write-Output 'PASS: native PowerShell 5.1 parser, fixed batch construction, profile dispatch, hash and negative schema checks; SQL not connected'
