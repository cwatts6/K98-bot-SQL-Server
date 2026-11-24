# Offline transport doubles; no SQL connection, migration or business operation.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
foreach($path in @('deploy/SqlDeploy.ModuleRelease.ps1','deploy/SqlDeploy.P02ObserverRelease.ps1')) {
 $tokens=$null;$errors=$null
 $null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $path),[ref]$tokens,[ref]$errors)
 if(@($errors).Count){throw ($errors|Out-String)}
}
. "$root/deploy/SqlDeploy.ModuleRelease.ps1"
. "$root/deploy/SqlDeploy.P02ObserverRelease.ps1"
$checks=[Collections.Generic.List[string]]::new()
function Require([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$checks.Add($Name)}
function Reject([scriptblock]$Action,[string]$Message,[string]$Name){
 $failed=$false
 try{& $Action}catch{if($_.Exception.Message -notlike ('*'+$Message+'*')){throw};$failed=$true}
 Require $failed $Name
}
$id='20261120_001_p02_catalogue_observer'
$hash='cd3bcb8c1f7303b8b45d5dc2b3d118aad70002f684ae847ffaf400c056bc1692'
$path=Join-Path $root ('migrations/'+$id+'.release.json')
$loaded=Read-K98ModuleProfile $path $hash $id
Require ($loaded.Commands.Count -eq 1 -and $loaded.BeforeCheck.Contains('Observer object already exists') -and $loaded.AfterCheck.Contains('Observer permission postimage differs')) 'Complete pinned install and source-derived checks accepted'
Reject {Read-K98ModuleProfile $path ('0'*64) $id} 'checksum' 'Wrong profile digest refused'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('K98-ObserverRelease-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($scratch)
foreach($name in @(($id+'.release.json'),($id+'.sql'),($id+'.before.sql'),($id+'.after.sql'))) {
 [IO.File]::WriteAllBytes((Join-Path $scratch $name),[IO.File]::ReadAllBytes((Join-Path $root ('migrations/'+$name))))
}
$copy=Join-Path $scratch ($id+'.release.json')
[IO.File]::WriteAllText((Join-Path $scratch ($id+'.after.sql')),'SELECT 1;',[Text.UTF8Encoding]::new($false))
Reject {Read-K98ModuleProfile $copy $hash $id} 'SQL bytes changed' 'Replaced postcheck refused'
$changed=[IO.File]::ReadAllText($copy).Replace('"bootstrap_generation": 1','"bootstrap_generation": 2')
[IO.File]::WriteAllText($copy,$changed,[Text.UTF8Encoding]::new($false))
Reject {Read-K98ModuleProfile $copy (Get-K98ModuleHash ([IO.File]::ReadAllBytes($copy))) $id} 'Fixed reviewed' 'Rehashed replacement profile refused'

$commit='a'*40;$release='11111111-2222-4333-8444-555555555555'
$script:identity=[pscustomobject]@{server='MINI_AMD';database='ROK_TRACKER';database_id=12;sequence_object_id=1234;sequence_created=[datetime]'2026-11-20T13:14:27.0633333';sequence_modified=[datetime]'2026-11-20T13:14:27.0633333';generation=[long]1}
$script:history=@();$script:attempts=@();$script:completed=@();$script:reads=[Collections.Generic.List[string]]::new();$script:badPre=$false
function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {
 if($Sql -ceq $loaded.BeforeCheck){$script:reads.Add('before');if($script:badPre){throw 'Injected wrong preimage'};return ,@()}
 if($Sql -ceq $loaded.AfterCheck){$script:reads.Add('after');return ,@()}
 if($Sql -like '*AS sequence_created*'){$script:reads.Add('incarnation');return ,@([pscustomobject]@{server=$script:identity.server;database=$script:identity.database;database_id=$script:identity.database_id;sequence_object_id=$script:identity.sequence_object_id;sequence_created=$script:identity.sequence_created;sequence_modified=$script:identity.sequence_modified;generation=$script:identity.generation})}
 if($Sql -like 'SELECT Status,ChecksumSha256*'){return ,$script:history}
 if($Sql -like 'SELECT Status,GitCommit,ErrorMessage*'){return ,$script:completed}
 if($Sql -like 'SELECT BranchName,Status,ErrorMessage*'){return ,$script:attempts}
 throw ('Unexpected SQL: '+$Sql)
}
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'unstarted') 'Absent receipt plus exact preimage is unstarted'
$base=@{migration_id=$id;profile_sha256=$hash;sql_commit=$commit;release_id=$release}
$script:attempts=@([pscustomobject]@{BranchName='p02_catalogue_observer_v1';Status='Started';ErrorMessage=($base|ConvertTo-Json -Compress)})
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'rolled_back') 'Interrupted Started attempt plus exact preimage is rolled back'
$script:attempts[0].Status='Failed'
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'rolled_back') 'Failed attempt retained and proved rolled back'
$script:badPre=$true
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'Injected wrong preimage' 'Missing receipt alone never proves rollback'
$script:badPre=$false
Require ((ConvertTo-K98ObserverStamp ([datetime]'2026-11-17T17:34:47.3566667')) -ceq '2026-11-17T17:34:47.357000') 'Catalogue fractional tick rounds to retained ODBC millisecond'
Require ((ConvertTo-K98ObserverStamp ([datetime]'2026-11-20T13:14:27.0633333')) -ceq '2026-11-20T13:14:27.063000') 'Sequence fractional tick matches retained ODBC identity'
Require ((ConvertTo-K98ObserverStamp ([datetime]'2026-11-20T23:59:59.9996667')) -ceq '2026-11-21T00:00:00.000000') 'Timestamp rounding carries through the day boundary'
Reject {ConvertTo-K98ObserverStamp '2026-11-20T13:14:27.063000'} 'Typed SQL' 'String timestamp cannot masquerade as typed native evidence'
$incarnation=Get-K98ObserverIncarnation $null ([object]::new()) $loaded -Bootstrap
$base.observation_installation=$incarnation
$script:history=@([pscustomobject]@{Status='Applied';ChecksumSha256=$hash;GitCommit=$commit;DeploymentId=$release})
$script:completed=@([pscustomobject]@{Status='Succeeded';GitCommit=$commit;ErrorMessage=($base|ConvertTo-Json -Depth 8 -Compress)})
$script:reads.Clear()
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'committed') 'Linked committed receipt and fresh incarnation match'
Require (($script:reads -join ',') -ceq 'after,incarnation') 'Committed state only verifies postimage and incarnation without install/preimage'
Require ($loaded.ObserverInstallation.sequence_object_id -eq 1234 -and $loaded.ObserverDeploymentId -ceq $release) 'Only confirmed committed binding made available'
$script:identity.generation=127
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'committed') 'Later generation preserves original incarnation without reinstall'
Reject {Get-K98ObserverIncarnation $null ([object]::new()) $loaded -Bootstrap} 'bootstrap' 'Noninitial generation cannot manufacture bootstrap'
$script:identity.sequence_object_id=1235
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'incarnation differs' 'Replaced sequence refused despite successful ledger'
$script:identity.sequence_object_id=1234
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'} 'release differs' 'Another release cannot adopt committed installation'
$base.observation_installation.database_id='12'
$script:completed[0].ErrorMessage=$base|ConvertTo-Json -Depth 8 -Compress
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'incarnation differs' 'Stringified integer receipt refused'
$base.Remove('observation_installation')
$script:completed[0].ErrorMessage=$base|ConvertTo-Json -Depth 8 -Compress
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'Exact module release fields' 'Precommit/provisional receipt cannot authorize incarnation'
$script:completed[0].Status='Started'
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'attempt differs' 'Applied row without linked success is refused'
Write-Output ('PASS: '+$checks.Count+' observer release checks; no SQL connection. Fixture retained: '+$scratch)
