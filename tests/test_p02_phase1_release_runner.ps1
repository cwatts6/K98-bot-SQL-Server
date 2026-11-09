[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$stage=Split-Path -Parent $PSScriptRoot
$runner=Join-Path $stage 'deploy\SqlDeploy.ModuleRelease.ps1'
$helper=Join-Path $stage 'deploy\SqlDeploy.Phase1Release.ps1'
foreach($path in @($runner,$helper)){
 $tokens=$null;$errors=$null
 $null=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
 if(@($errors).Count){throw ($errors|Out-String)}
}
. $runner
. $helper
$checks=[Collections.Generic.List[string]]::new()
function Require([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$checks.Add($Name)}
function Reject([scriptblock]$Action,[string]$Message,[string]$Name){
 $rejected=$false
 try{& $Action}catch{if($_.Exception.Message -notlike ('*'+$Message+'*')){throw};$rejected=$true}
 Require $rejected $Name
}
$migration='20261109_001_p02_phase1_sql_exports'
$profile=Join-Path $stage ('migrations\'+$migration+'.release.json')
$hash='bbba8b92a0448535121b301c52ba28244693c10b1263f3d032c1dc79923b8e43'
$loaded=Read-K98ModuleProfile $profile $hash $migration
Require (@($loaded.Commands).Count -eq 1 -and @($loaded.Profile.images).Count -eq 57) 'Exact complete profile accepted'
Reject {Read-K98ModuleProfile $profile ('0'*64) $migration} 'checksum' 'Wrong profile checksum refused'
Reject {Read-K98ModuleProfile $profile $hash '20261109_999_unreviewed'} 'identity' 'Wrong migration identity refused'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('K98-phase1-runner-unit-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $scratch
$copy=Join-Path $scratch ($migration+'.release.json')
[IO.File]::WriteAllBytes($copy,[IO.File]::ReadAllBytes($profile))
$sql=Join-Path $scratch ($migration+'.sql')
[IO.File]::WriteAllText($sql,'SELECT 1;',[Text.UTF8Encoding]::new($false))
Reject {Read-K98ModuleProfile $copy $hash $migration} 'script bytes changed' 'Unreviewed SQL body refused'
$changed=[IO.File]::ReadAllText($profile).Replace('"compatibility_level": 160','"compatibility_level": 150')
[IO.File]::WriteAllText($copy,$changed,[Text.UTF8Encoding]::new($false))
$newHash=Get-K98ModuleHash ([IO.File]::ReadAllBytes($copy))
Reject {Read-K98ModuleProfile $copy $newHash $migration} 'qualified Phase 1 profile bytes' 'Caller-supplied replacement profile refused'

$script:state=0;$script:server='MINI_AMD';$script:database='ROK_TRACKER';$script:rcsi=$false
$script:readOnly=$false;$script:access=0;$script:alterCalls=0;$script:lostAck=$false
$script:ledger=$false;$script:attempts=@();$script:release='11111111-1111-4111-8111-111111111111';$script:commit='a'*40
$script:binding=@{migration_id=$migration;profile_sha256=$hash;sql_commit=$script:commit;release_id=$script:release}|ConvertTo-Json -Compress
function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {
 if($Sql -like '*snapshot_isolation_state*'){
  return ,@([pscustomobject]@{server_name=$script:server;database_name=$script:database;snapshot_isolation_state=$script:state;is_read_committed_snapshot_on=$script:rcsi;is_read_only=$script:readOnly;user_access=$script:access})
 }
 if($Sql -ceq 'ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;'){
  $script:alterCalls++;$script:state=1
  if($script:lostAck){throw 'Injected setting acknowledgement loss'}
  return ,@()
 }
 if($Sql -like 'SELECT Status,ChecksumSha256,GitCommit,DeploymentId*'){
  if($script:ledger){return ,@([pscustomobject]@{Status='Applied';ChecksumSha256=$hash;GitCommit=$script:commit;DeploymentId='22222222-2222-4222-8222-222222222222'})}
  return ,@()
 }
 if($Sql -like 'SELECT Status,GitCommit,ErrorMessage*'){
  return ,@([pscustomobject]@{Status='Succeeded';GitCommit=$script:commit;ErrorMessage=$script:binding})
 }
 if($Sql -like 'SELECT BranchName,Status,ErrorMessage*'){return ,$script:attempts}
 throw ('Unexpected test query: '+$Sql)
}
function Assert-K98ModuleImages($Connection,$Transaction,$Loaded,[bool]$After){}
Enable-K98Phase1Snapshot $null
Require ($script:state -eq 1 -and $script:alterCalls -eq 1) 'One setting change reaches stable ON'
Enable-K98Phase1Snapshot $null
Require ($script:alterCalls -eq 1) 'Stable ON is not altered again'
foreach($pending in @(2,3)){
 $script:state=$pending
 Reject {Enable-K98Phase1Snapshot $null} 'transitioning' ('Pending state '+$pending+' refused')
}
Require ($script:alterCalls -eq 1) 'Pending states cause no ALTER'
$script:state=0;$script:rcsi=$true
Reject {Enable-K98Phase1Snapshot $null} 'unchanged read-committed mode' 'Unexpected RCSI refused'
$script:rcsi=$false;$script:server='WRONG'
Reject {Enable-K98Phase1Snapshot $null} 'Exact Phase 1 target' 'Wrong server refused'
$script:server='MINI_AMD';$script:database='K98_TEST'
Reject {Enable-K98Phase1Snapshot $null} 'Exact Phase 1 target' 'Wrong database refused'
$script:database='ROK_TRACKER';$script:readOnly=$true
Reject {Enable-K98Phase1Snapshot $null} 'Exact Phase 1 target' 'Read-only target refused'
$script:readOnly=$false;$script:lostAck=$true
Reject {Enable-K98Phase1Snapshot $null} 'acknowledgement loss' 'Unknown setting acknowledgement is preserved'
Require ($script:state -eq 1 -and $script:alterCalls -eq 2) 'Setting completed before acknowledgement loss'
$script:lostAck=$false
Enable-K98Phase1Snapshot $null
Require ($script:alterCalls -eq 2) 'Resume reads completed setting without reapplying'

$script:state=0
Require ((Get-K98ModuleOutcome $null $loaded $hash $script:commit $script:release) -ceq 'unstarted') 'Exact unstarted state accepted'
$script:state=1
Reject {Get-K98ModuleOutcome $null $loaded $hash $script:commit $script:release} 'Unstarted Phase 1 snapshot setting differs' 'Unowned setting change refused'
$script:attempts=@([pscustomobject]@{BranchName='p02_phase1_v1';Status='Started';ErrorMessage=$script:binding})
Require ((Get-K98ModuleOutcome $null $loaded $hash $script:commit $script:release) -ceq 'rolled_back') 'Same-release schema rollback and retained setting distinguished'
Reject {Get-K98ModuleOutcome $null $loaded $hash $script:commit '33333333-3333-4333-8333-333333333333'} 'identity/outcome differs' 'Different release cannot adopt earlier attempt'
$script:ledger=$true
Require ((Get-K98ModuleOutcome $null $loaded $hash $script:commit $script:release) -ceq 'committed') 'Exact committed outcome accepted without SQL replay'
$script:state=0
Reject {Get-K98ModuleOutcome $null $loaded $hash $script:commit $script:release} 'Committed Phase 1 schema has changed snapshot settings' 'Committed setting drift stops without SQL replay'
$report=[ordered]@{status='Phase1ReleaseRunnerUnitChecksPassed';checks=$checks.ToArray();production_changed=$false;sql_workload_executed=$false;native_sql_evidence_separate=$true}
$output=Join-Path $scratch 'receipt.json'
[IO.File]::WriteAllText($output,($report|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
Write-Host ('PHASE 1 RUNNER TESTS: '+$output)
Write-Host ('Passed: '+$checks.Count)
