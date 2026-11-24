#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Offline regression only. Extract pure guards; never execute the lab entry.
# Synthetic prior records below do not supply native continuation authority.
$root=Split-Path -Parent $PSScriptRoot
$source=Join-Path $root 'qualification/p02_observer/Restore-P02MsdbD4.ps1'
$tokens=$null;$errors=$null;$tree=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Date-Text','Assert-Rows','Assert-PriorMsdbAttempt')){
 $fn=@($tree.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name},$true))
 if($fn.Count -ne 1){throw 'Missing actual function'}
 . ([scriptblock]::Create($fn[0].Extent.Text))
}
$checks=[Collections.Generic.List[object]]::new()
$expectedStamp=[DateTimeOffset]::FromUnixTimeMilliseconds(1665207117550).UtcDateTime
$priorText=@'
{
 "schema": "p02-authentic-msdb-d4-guest/1",
 "outcome": "failed",
 "stage": "restore authenticated original msdb",
 "actions": [
  {
   "action": "preserve current patched lab msdb",
   "acknowledged": true
  },
  {
   "action": "verify preserved lab msdb backup",
   "acknowledged": true
  },
  {
   "action": "restore authenticated original msdb",
   "acknowledged": true
  }
 ],
 "execution_settled": true,
 "connections_closed": 1,
 "cleanup_failure": null,
 "restored": true,
 "d4_committed": false,
 "production_operations": 0,
 "business_operations": 0,
 "first_failure": {
  "type": "System.Management.Automation.PSSecurityException",
  "detail": "File Q:\\P02Release\\prerequisites-20261120161533206\\committed-sql\\deploy\\SqlDeploy.ModuleRelease.ps1 cannot be loaded because running scripts is disabled on this system. Retained test case."
 },
 "lab_msdb_backup": "Q:\\P02Release\\msdb-d4-20261120184110328\\lab-msdb-before-authentic-restore.bak",
 "msdb_before": {
  "state": [
   {
    "create_date": "\/Date(1665207117550)\/"
   }
  ]
 },
 "msdb_after": {
  "state": [
   {
    "database_guid": "C9048AE7-D724-41B4-A1A6-5C3A7A1E26B9",
    "is_broker_enabled": false
   }
  ]
 }
}
'@
$nativeStamp=[datetime]::SpecifyKind($expectedStamp.ToLocalTime(),[DateTimeKind]::Unspecified)
foreach($case in @(
 @('native-october',$nativeStamp),
 @('utc-october',$expectedStamp),
 @('local-october',$expectedStamp.ToLocalTime()),
 @('retained-microsoft-string','/Date(1665207117550)/')
)){
 if((Date-Text $case[1]) -cne '2022-10-08T05:31:57.550'){throw ('Date case failed: '+$case[0])}
 $checks.Add([pscustomobject]@{area='dates';case=$case[0];accepted=$true})
}
foreach($stamp in @('2026-11-20T13:14:27.0633333','2026-11-17T17:34:47.3566667','2026-11-20T23:59:59.9996667')){
 $utc=[datetime]::SpecifyKind([datetime]$stamp,[DateTimeKind]::Utc)
 $native=[datetime]::SpecifyKind($utc.ToLocalTime(),[DateTimeKind]::Unspecified)
 $target=if($stamp.Contains('0633333')){'2026-11-20T13:14:27.063'}elseif($stamp.Contains('3566667')){'2026-11-17T17:34:47.357'}else{'2026-11-21T00:00:00.000'}
 if((Date-Text $native) -cne $target){throw 'Native tick rounding regressed'}
 $checks.Add([pscustomobject]@{area='dates';case=$stamp;accepted=$true})
}
foreach($delta in @(1,3600000)){
 $refused=$false
 try{Assert-Rows @([pscustomobject]@{create_date=$nativeStamp.AddMilliseconds($delta)}) @([pscustomobject]@{create_date=$expectedStamp}) @('create_date') @('create_date')}catch{if($_.Exception.Message -cne 'Retained date changed: create_date'){throw};$refused=$true}
 if(-not $refused){throw 'Genuine timestamp drift accepted'}
 $checks.Add([pscustomobject]@{area='dates';case=('drift-'+$delta);accepted=$false})
}
foreach($value in @('2022-10-08T05:31:57.550Z',$null,123)){
 $refused=$false
 try{Date-Text $value}catch{if($_.Exception.Message -cne 'Typed or retained native date required'){throw};$refused=$true}
 if(-not $refused){throw 'Unsupported timestamp accepted'}
 $checks.Add([pscustomobject]@{area='dates';case=('invalid-'+[string]$value);accepted=$false})
}
foreach($case in @('pass','typed-native-summer','not-settled','connection','command','pending','process','missing-handle','changed-native','not-restored','d4-committed','prior-action','cleanup','different-refusal','restore-id','delivery-on','backup-path','unacknowledged-restore','reordered-actions')){
 $previous=$priorText|ConvertFrom-Json
 $native=$priorText|ConvertFrom-Json
 $held=@{settled=$true;connection=$null;command=$null;pending=$null;process=$null;receipt=$native}
 switch($case){
  'typed-native-summer' {$native.msdb_before.state[0].create_date=[datetime]::SpecifyKind($native.msdb_before.state[0].create_date.ToLocalTime(),[DateTimeKind]::Unspecified)}
  'not-settled' {$held.settled=$false}
  'connection' {$held.connection=[object]::new()}
  'command' {$held.command=[object]::new()}
  'pending' {$held.pending=[object]::new()}
  'process' {$held.process=[object]::new()}
  'missing-handle' {$held.Remove('command')}
  'changed-native' {$native.connections_closed=2}
  'not-restored' {$previous.restored=$false}
  'd4-committed' {$previous.d4_committed=$true}
  'prior-action' {$previous.actions=@([pscustomobject]@{acknowledged=$true})}
  'cleanup' {$previous.cleanup_failure='unknown'}
  'different-refusal' {$previous.first_failure.detail='different'}
  'restore-id' {$previous.msdb_after.state[0].database_guid='00000000-0000-0000-0000-000000000000'}
  'delivery-on' {$previous.msdb_after.state[0].is_broker_enabled=$true}
  'backup-path' {$previous.lab_msdb_backup='Q:\other.bak'}
  'unacknowledged-restore' {$previous.actions[2].acknowledged=$false}
  'reordered-actions' {$previous.actions=@($previous.actions[2],$previous.actions[1],$previous.actions[0])}
 }
 $accepted=$false
 try{Assert-PriorMsdbAttempt $held $previous;$accepted=$true}catch{
  if($case -in @('pass','typed-native-summer')){throw}
  if($_.Exception.Message -notmatch 'Previous|Only the exact|All three|Exact acknowledged'){throw}
 }
 if($accepted -ne ($case -in @('pass','typed-native-summer'))){throw ('Custody case failed: '+$case)}
 $checks.Add([pscustomobject]@{area='continuation';case=$case;accepted=$accepted})
}
Write-Output ('PASS: '+$checks.Count+' msdb date/custody checks; no SQL or VM connection.')
