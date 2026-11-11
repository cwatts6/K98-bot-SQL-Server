Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
foreach($path in @('deploy/SqlDeploy.ModuleRelease.ps1','deploy/SqlDeploy.P02D4Release.ps1','tests/native_d4_outcome.ps1')){
 $tokens=$null;$errors=$null
 $null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $path),[ref]$tokens,[ref]$errors)
 if(@($errors).Count){throw ($errors|Out-String)}
}
. "$root/deploy/SqlDeploy.ModuleRelease.ps1"
. "$root/deploy/SqlDeploy.P02D4Release.ps1"
$checks=[Collections.Generic.List[string]]::new()
function Require([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$checks.Add($Name)}
function Reject([scriptblock]$Action,[string]$Message,[string]$Name){
 $rejected=$false
 try{& $Action}catch{if($_.Exception.Message -notlike ('*'+$Message+'*')){throw};$rejected=$true}
 Require $rejected $Name
}
$id='20261111_001_p02_d4_combined'
$path=Join-Path $root ('migrations/'+$id+'.release.json')
$hash='57944777e50b7dc9200220cfcc2ce767edb22a2e0972e02bc2cd6f04e23e8171'
$loaded=Read-K98ModuleProfile $path $hash $id
Require (@($loaded.Commands).Count -eq 1 -and @($loaded.Profile.images).Count -eq 30) 'Exact complete D4 package accepted'
Reject {Read-K98ModuleProfile $path ('0'*64) $id} 'checksum' 'Wrong profile digest refused'
Reject {Read-K98ModuleProfile $path $hash '20261111_999_other'} 'identity' 'Wrong migration refused'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('K98-D4-reader-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($scratch)
$copy=Join-Path $scratch ($id+'.release.json')
[IO.File]::WriteAllBytes($copy,[IO.File]::ReadAllBytes($path))
$sql=Join-Path $scratch ($id+'.sql')
[IO.File]::WriteAllText($sql,'SELECT 1;',[Text.UTF8Encoding]::new($false))
Reject {Read-K98ModuleProfile $copy $hash $id} 'script bytes changed' 'Replacement SQL refused'
[IO.File]::WriteAllBytes($sql,[byte[]]::new(524289))
Reject {Read-K98ModuleProfile $copy $hash $id} 'Bounded ordinary' 'Oversized script refused before read'
$changed=[IO.File]::ReadAllText($path).Replace('"compatibility_level": 160','"compatibility_level": 150')
[IO.File]::WriteAllText($copy,$changed,[Text.UTF8Encoding]::new($false))
$newHash=Get-K98ModuleHash ([IO.File]::ReadAllBytes($copy))
Reject {Read-K98ModuleProfile $copy $newHash $id} 'Fixed qualified D4 profile' 'Caller-rehashed replacement refused'

# Query transport doubles exercise the production decision logic. The separate
# opt-in native suite exercises the real metadata SQL and durable receipt reads.
$script:state=[pscustomobject]@{server_name='mini_AMD';database_name='ROK_TRACKER';snapshot_isolation_state=1;is_read_committed_snapshot_on=$false;is_read_only=$false;user_access=0}
$script:dependencyCalls=0;$script:resourceCalls=0;$script:inject=$false
$script:tx=[object]::new()
function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {
 if(-not [object]::ReferenceEquals($Transaction,$script:tx)){throw 'Transaction propagation lost'}
 if($Sql -like '*snapshot_isolation_state*'){return ,@($script:state)}
 if($Sql -like '*sys.sequences*'){
  $script:dependencyCalls++
  if($script:inject){throw 'Injected native dependency refusal'}
  return ,@()
 }
 if($Sql -like '*sys.dm_db_log_space_usage*' -or $Sql -like '*sys.dm_os_sys_memory*'){
  $script:resourceCalls++
  if($script:inject){throw 'Injected resource refusal'}
  return ,@()
 }
 throw ('Unexpected SQL: '+$Sql)
}
Assert-K98D4Dependencies $null $script:tx
Require ($script:dependencyCalls -eq 1) 'Observed host spelling accepted with transaction propagated'
foreach($bad in @(
 @('server_name','OTHER'),@('database_name','other'),@('snapshot_isolation_state',0),
 @('snapshot_isolation_state',2),@('snapshot_isolation_state',3),
 @('is_read_committed_snapshot_on',$true),@('is_read_only',$true),@('user_access',1)
)){
 $key=$bad[0];$original=$script:state.$key;$script:state.$key=$bad[1]
 Reject {Assert-K98D4Dependencies $null $script:tx} 'exact installed target' ('Unsupported state refused: '+$key+'/'+$bad[1])
 $script:state.$key=$original
}
Require ($script:dependencyCalls -eq 1) 'Wrong target refused before dependency query'
$script:inject=$true
Reject {Assert-K98D4Dependencies $null $script:tx} 'Injected native dependency' 'Dependency refusal propagates'
$script:inject=$false
Assert-K98D4Resources $null $script:tx
Require ($script:resourceCalls -eq 2) 'Existing storage thresholds and added memory reserve both checked'
$script:inject=$true
Reject {Assert-K98D4Resources $null $script:tx} 'Injected resource' 'Resource refusal propagates'
Write-Output ('PASS: '+$checks.Count+' fixed D4 reader/target/transaction/refusal checks. No SQL connection. Fixture retained: '+$scratch)
