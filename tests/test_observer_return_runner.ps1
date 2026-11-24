$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. "$root\deploy\SqlDeploy.ModuleRelease.ps1"
. "$root\deploy\SqlDeploy.P02ObserverReturn.ps1"
$checks=[Collections.Generic.List[string]]::new()
function Require([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$checks.Add($Name)}
function Reject([scriptblock]$Action,[string]$Message,[string]$Name){
 $failed=$false
 try{& $Action}catch{if($_.Exception.Message -notlike ('*'+$Message+'*')){throw};$failed=$true}
 Require $failed $Name
}
$return='20261123_001_p02_observer_return'
$resume='20261123_002_p02_observer_reupgrade'
$hash='c7d24d3e25c3a3f62fba6484e993c26a19fcb8cefe1d55a607027907beced71c'
$resumeHash='4fb8a16cfd8a09420a4d8d11a40a1eb36496fa611e4c16bc6d290b7973f3d577'
$path=Join-Path $root ('migrations/'+$return+'.release.json')
$loaded=Read-K98ModuleProfile $path $hash $return
$next=Read-K98ModuleProfile (Join-Path $root ('migrations/'+$resume+'.release.json')) $resumeHash $resume
Require ($loaded.Profile.action -ceq 'return' -and $next.Profile.action -ceq 'reupgrade') 'Exact finite pair loaded'
Require ($loaded.AfterCheck -ceq $next.BeforeCheck -and $loaded.BeforeCheck -ceq $next.AfterCheck) 'Exact inverse source checks retained'
Require ($next.Profile.requires[1].migration_id -ceq $return -and $next.Profile.requires[1].sha256 -ceq $hash) 'Reupgrade requires committed return profile'
Reject {Read-K98ModuleProfile $path $hash $resume} 'migration identity' 'Caller migration cannot differ from profile'
Reject {Read-K98ModuleProfile $path ('0'*64) $return} 'checksum' 'Wrong profile refused'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('K98-P02Return-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($scratch)
foreach($name in @(($return+'.release.json'),($return+'.sql'),($return+'.before.sql'),($return+'.after.sql'))){
 [IO.File]::WriteAllBytes((Join-Path $scratch $name),[IO.File]::ReadAllBytes((Join-Path $root ('migrations/'+$name))))
}
$copy=Join-Path $scratch ($return+'.release.json')
$changed=[IO.File]::ReadAllText($copy).Replace('"action": "return"','"action": "reupgrade"')
[IO.File]::WriteAllText($copy,$changed,[Text.UTF8Encoding]::new($false))
Reject {Read-K98ModuleProfile $copy (Get-K98ModuleHash ([IO.File]::ReadAllBytes($copy))) $return} 'Fixed reviewed' 'Rehashed action substitution refused'
[IO.File]::WriteAllBytes($copy,[IO.File]::ReadAllBytes($path))
[IO.File]::WriteAllText((Join-Path $scratch ($return+'.after.sql')),'SELECT 1;',[Text.UTF8Encoding]::new($false))
Reject {Read-K98ModuleProfile $copy $hash $return} 'SQL bytes changed' 'Substituted return postcheck refused'

$commit='a'*40;$originalCommit='b'*40
$release='11111111-2222-4333-8444-555555555555'
$originRelease='66666666-7777-4888-8999-aaaaaaaaaaaa'
$script:identity=[pscustomobject]@{server='MINI_AMD';database='ROK_TRACKER';database_id=12;sequence_object_id=1234;sequence_created=[datetime]'2026-11-20T13:14:27.0633333';sequence_modified=[datetime]'2026-11-20T13:14:27.0633333';generation=[long]475}
$installation=[pscustomobject][ordered]@{version=1;protocol_sha256=$loaded.Profile.protocol_sha256;server='MINI_AMD';database='ROK_TRACKER';database_id=12;sequence_object_id=1234;sequence_created='2026-11-20T13:14:27.063000';sequence_modified='2026-11-20T13:14:27.063000';bootstrap_generation=1}
$originalBinding=@{migration_id='20261120_001_p02_catalogue_observer';profile_sha256='cd3bcb8c1f7303b8b45d5dc2b3d118aad70002f684ae847ffaf400c056bc1692';sql_commit=$originalCommit;release_id=$originRelease;observation_installation=$installation}
$script:original=[pscustomobject]@{migration_status='Applied';profile_sha256=$originalBinding.profile_sha256;sql_commit=$originalCommit;deployment_id=$originRelease;deployment_status='Succeeded';deployment_commit=$originalCommit;deployment_profile='p02_catalogue_observer_v1';deployment_database='ROK_TRACKER';binding=($originalBinding|ConvertTo-Json -Depth 8 -Compress)}
$script:history=@();$script:attempts=@();$script:completed=@();$script:reads=[Collections.Generic.List[string]]::new();$script:transactions=[Collections.Generic.List[object]]::new();$script:badPre=$false
function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {
 if($Sql -like 'SELECT m.Status AS migration_status*'){$script:reads.Add('original');$script:transactions.Add($Transaction);return ,@($script:original)}
 if($Sql -like '*AS sequence_created*'){$script:reads.Add('incarnation');$script:transactions.Add($Transaction);return ,@([pscustomobject]@{server=$script:identity.server;database=$script:identity.database;database_id=$script:identity.database_id;sequence_object_id=$script:identity.sequence_object_id;sequence_created=$script:identity.sequence_created;sequence_modified=$script:identity.sequence_modified;generation=$script:identity.generation})}
 if($Sql -ceq $loaded.BeforeCheck){$script:reads.Add('before');if($script:badPre){throw 'Injected changed preimage'};return ,@()}
 if($Sql -ceq $loaded.AfterCheck){$script:reads.Add('after');return ,@()}
 if($Sql -like 'SELECT Status,ChecksumSha256*'){return ,$script:history}
 if($Sql -like 'SELECT Status,GitCommit,ErrorMessage*'){return ,$script:completed}
 if($Sql -like 'SELECT BranchName,Status,ErrorMessage*'){return ,$script:attempts}
 throw ('Unexpected SQL: '+$Sql)
}
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'unstarted') 'Original commit plus return preimage is unstarted'
$base=@{migration_id=$return;profile_sha256=$hash;sql_commit=$commit;release_id=$release}
$script:attempts=@([pscustomobject]@{BranchName='p02_observer_return_v1';Status='Started';ErrorMessage=($base|ConvertTo-Json -Compress)})
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'rolled_back') 'Interrupted return proves preimage before continuation'
$script:badPre=$true
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'changed preimage' 'Unknown return outcome never replays'
$script:badPre=$false
$script:transactions.Clear();$transaction=[object]::new()
$null=Get-K98OriginalObserverBinding $null $transaction $loaded
Require ($script:transactions.Count -eq 2 -and [object]::ReferenceEquals($script:transactions[0],$transaction) -and [object]::ReferenceEquals($script:transactions[1],$transaction)) 'Original receipt and incarnation reads share caller transaction'
$base.observation_installation=$installation
$script:history=@([pscustomobject]@{Status='Applied';ChecksumSha256=$hash;GitCommit=$commit;DeploymentId=$release})
$script:completed=@([pscustomobject]@{Status='Succeeded';GitCommit=$commit;ErrorMessage=($base|ConvertTo-Json -Depth 8 -Compress)})
$script:reads.Clear()
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'committed') 'Committed return verifies without applying again'
Require (-not $script:reads.Contains('before') -and $script:reads.Contains('after')) 'Committed return uses only its postimage'
$script:identity.generation=800
Require ((Get-K98ModuleOutcome $null $loaded $hash $commit $release) -ceq 'committed') 'Generation advancement retains original incarnation'
$script:identity.sequence_object_id=1235
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'incarnation differs' 'Recreated sequence cannot be adopted'
$script:identity.sequence_object_id=1234
$script:original.deployment_status='Started'
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'commit/attempt differs' 'Incomplete original installation refused'
$script:original.deployment_status='Succeeded'
$bad=$base|ConvertTo-Json -Depth 8 -Compress|ConvertFrom-Json
$bad.observation_installation.sequence_object_id=1235
$script:completed[0].ErrorMessage=$bad|ConvertTo-Json -Depth 8 -Compress
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit $release} 'incarnation differs' 'New stage cannot replace original binding'
$script:completed[0].ErrorMessage=$base|ConvertTo-Json -Depth 8 -Compress
Reject {Get-K98ModuleOutcome $null $loaded $hash $commit 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff'} 'release differs' 'Foreign release cannot adopt completed return'
Write-Output ('PASS: '+$checks.Count+' return coordinator checks; no SQL connection. Fixture retained: '+$scratch)
