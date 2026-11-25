param([Parameter(Mandatory=$true)][string]$EvidenceDirectory,[Parameter(Mandatory=$true)][string]$BeforeTrigger,[switch]$ValidateOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$oldId='20261125_001_p02_observer_xml_options'
$newId='20261125_002_p02_observer_options_marker'
$oldRaw=[IO.File]::ReadAllBytes((Join-Path $repo ('migrations/'+$oldId+'.sql')))
$newRaw=[IO.File]::ReadAllBytes((Join-Path $repo ('migrations/'+$newId+'.sql')))
function Digest([byte[]]$Raw){$h=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($h.ComputeHash($Raw))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}}
if((Digest $oldRaw) -cne '3bf3472ad07214c1a2a0b2cea29a49621cf053305f891ebca38c3fb1056e29fc' -or (Digest $newRaw) -cne 'dd760a88926ebd0ad8c53b9a21f8de6cd6d619c747713c6dff0fe505186dc39e'){throw 'Exact reviewed migration batches required.'}
if($ValidateOnly){Write-Output 'VALIDATED OFFLINE: exact failed and corrected migration batch pins; no SQL connection.';return}
if($env:COMPUTERNAME -cne '9SX2VF4'){throw 'Local development host only.'}
$database='K98_P02Marker_'+[datetime]::UtcNow.ToString('yyyyMMddHHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$connections=[Collections.Generic.List[Data.SqlClient.SqlConnection]]::new()
$result=[ordered]@{schema='p02-native-migration-marker/1';database=$database;server='9SX2VF4\K98DEV';started_utc=[datetime]::UtcNow.ToString('o');passed=$false;checks=@();first_failure=$null;cleanup_failures=@();connections_opened=0;connections_closed=0;production_operations=0;fixture_retained=$true;old_batch_sha256=(Digest $oldRaw);new_batch_sha256=(Digest $newRaw);test_rebinding='Only the DB_NAME target literal is changed to this unique disposable database. Exact production lock/DDL batches and authoritative helper definitions are otherwise retained.'}
function Connect([string]$Name){
 $b=[Data.SqlClient.SqlConnectionStringBuilder]::new();$b['Data Source']='lpc:.\K98DEV';$b['Initial Catalog']=$Name;$b['Integrated Security']=$true;$b['Encrypt']=$false;$b['Pooling']=$false;$b['Connect Timeout']=5
 $c=[Data.SqlClient.SqlConnection]::new($b.ConnectionString);$connections.Add($c);$c.Open();$result.connections_opened++;return $c
}
function Query($Connection,[string]$Sql,$Transaction=$null,[switch]$Scalar){
 $cmd=$Connection.CreateCommand();$cmd.CommandTimeout=10;$cmd.CommandText=$Sql
 if($null -ne $Transaction){$cmd.Transaction=$Transaction}
 try{if($Scalar){return $cmd.ExecuteScalar()}else{$null=$cmd.ExecuteNonQuery()}}finally{$cmd.Dispose()}
}
function Check([bool]$Pass,[string]$Name){if(-not $Pass){throw ('Check failed: '+$Name)};$result.checks+=@{name=$Name;passed=$true}}
function Failure([scriptblock]$Action,[int]$Number,[string]$Name){
 $caught=$false
 try{& $Action}catch{
  $nativeException=$_.Exception;while($null -ne $nativeException.InnerException){$nativeException=$nativeException.InnerException}
  if($nativeException -isnot [Data.SqlClient.SqlException] -or $Number -notin @($nativeException.Errors|ForEach-Object {$_.Number})){throw}
  $caught=$true
 }
 Check $caught $Name
}
function Batches($Connection,[string]$Text){foreach($batch in [regex]::Split($Text,'(?im)^\s*GO\s*$')){if($batch.Trim()){Query $Connection $batch}}}
function TriggerText($Connection){return [string](Query $Connection "SELECT OBJECT_DEFINITION(object_id) FROM sys.triggers WHERE parent_class=0 AND name=N'tr_P02CatalogueObservation';" -Scalar)}
function Normalize([string]$Text){return ([regex]::Replace($Text.Replace("`r`n","`n"),'^(CREATE OR ALTER|CREATE   |CREATE|ALTER) TRIGGER ','TRIGGER '))}
function BindBatch([byte[]]$Raw){
 $text=[Text.Encoding]::UTF8.GetString($Raw);$needle="DB_NAME()<>N'ROK_TRACKER'"
 if(([regex]::Matches($text,[regex]::Escape($needle))).Count -ne 1){throw 'Only one fixture database binding is permitted.'}
 return $text.Replace($needle,("DB_NAME()<>N'"+$database+"'"))
}
$transaction=$null;$master=$null;$c=$null;$other=$null
try{
 $master=Connect 'master'
 Check ((Query $master "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'));" -Scalar) -ceq '9SX2VF4\K98DEV') 'Exact local engine'
 Check ((Query $master ("SELECT DB_ID(N'"+$database+"');") -Scalar) -is [DBNull]) 'Unique disposable database'
 Query $master ('CREATE DATABASE ['+$database+'] COLLATE Latin1_General_CI_AS;')
 $c=Connect $database;$other=Connect $database
 Query $c 'CREATE ROLE K98ImportLockPrincipal AUTHORIZATION dbo;'
 foreach($file in @('dbo.ACQUIRE_KS4_IMPORT_LOCK.StoredProcedure.sql','dbo.P02ObservationGeneration.Sequence.sql','dbo.usp_P02BeginCatalogueMutation.StoredProcedure.sql')){Batches $c ([IO.File]::ReadAllText((Join-Path $repo ('sql_schema/'+$file))))}
 Batches $c ([IO.File]::ReadAllText($BeforeTrigger))
 $before=TriggerText $c
 $sequence=Query $c "SELECT CONVERT(varchar(30),object_id)+':'+CONVERT(varchar(30),create_date,126) FROM sys.sequences WHERE name=N'P02ObservationGeneration';" -Scalar
 Query $c "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'K98_Module_Release_v1',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; IF @r NOT IN (0,1) THROW 51979,'Fixture release owner refused',1;"
 $old=BindBatch $oldRaw;$new=BindBatch $newRaw
 $transaction=$c.BeginTransaction()
 Failure {Query $c $old $transaction} 51970 'Exact original migration reproduces marker ownership failure'
 if($null -ne $transaction.Connection){$transaction.Rollback()};$transaction.Dispose();$transaction=$null
 Check ((Query $c 'SELECT @@TRANCOUNT;' -Scalar) -eq 0) 'Original failure leaves no transaction'
 Check ((TriggerText $other) -ceq $before) 'Original migration rollback retains exact trigger'
 Query $other "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'K98:catalogue-mutation:v1',@LockMode='Shared',@LockOwner='Session',@LockTimeout=0; IF @r NOT IN (0,1) THROW 51979,'Fixture foreign owner refused',1;"
 $transaction=$c.BeginTransaction()
 Failure {Query $c $new $transaction} 51974 'Corrected migration refuses an independently held mutation marker'
 if($null -ne $transaction.Connection){$transaction.Rollback()};$transaction.Dispose();$transaction=$null
 Check ((TriggerText $c) -ceq $before) 'Foreign-owner refusal leaves exact trigger'
 Query $other "DECLARE @r int; EXEC @r=sys.sp_releaseapplock @Resource=N'K98:catalogue-mutation:v1',@LockOwner='Session'; IF @r<>0 THROW 51979,'Fixture release failed',1;"
 $transaction=$c.BeginTransaction();Query $c $new $transaction
 Check ((Query $c "SELECT APPLOCK_MODE(N'public',N'K98:catalogue-mutation:v1',N'Transaction');" $transaction -Scalar) -ceq 'Shared') 'Corrected migration and DDL trigger share the acknowledged marker'
 Check ((Query $other "SELECT APPLOCK_TEST(N'public',N'K98:catalogue-mutation:v1',N'Exclusive',N'Session');" -Scalar) -eq 0) 'Independent observer cannot report quiet before transaction completion'
 Check ((Query $c 'SELECT @@TRANCOUNT;' $transaction -Scalar) -eq 1) 'DDL trigger preserves release transaction nesting'
 $transaction.Rollback();$transaction.Dispose();$transaction=$null
 Check ((TriggerText $other) -ceq $before) 'Explicit correction rollback restores exact predecessor trigger'
 Check ((Query $other "SELECT APPLOCK_TEST(N'public',N'K98:catalogue-mutation:v1',N'Exclusive',N'Session');" -Scalar) -eq 1) 'Rollback releases mutation marker'
 $transaction=$c.BeginTransaction();Query $c $new $transaction;$transaction.Commit();$transaction.Dispose();$transaction=$null
 $expected=[IO.File]::ReadAllText((Join-Path $repo 'sql_schema/tr_P02CatalogueObservation.DatabaseTrigger.sql'))
 $expected=@([regex]::Split($expected,'(?im)^\s*GO\s*$')|Where-Object {$_ -match 'CREATE OR ALTER TRIGGER'})[0].Trim()
 Check ((Normalize (TriggerText $other)).Trim() -ceq (Normalize $expected).Trim()) 'Committed full migration matches the exact corrected trigger body'
 Check ((Query $other "SELECT APPLOCK_TEST(N'public',N'K98:catalogue-mutation:v1',N'Exclusive',N'Session');" -Scalar) -eq 1) 'Commit releases mutation marker'
 Check ((Query $c 'SELECT @@TRANCOUNT;' -Scalar) -eq 0) 'Committed migration leaves no transaction'
 Check ((Query $c "SELECT CONVERT(varchar(30),object_id)+':'+CONVERT(varchar(30),create_date,126) FROM sys.sequences WHERE name=N'P02ObservationGeneration';" -Scalar) -ceq $sequence) 'Original sequence identity is preserved'
 $result.passed=$true
}catch{$result.first_failure=@{type=$_.Exception.GetType().FullName;message=$_.Exception.Message;line=$_.InvocationInfo.ScriptLineNumber}}
finally{
 if($null -ne $transaction){try{if($null -ne $transaction.Connection){$transaction.Rollback()};$transaction.Dispose()}catch{$result.cleanup_failures+=@{boundary='transaction';message=$_.Exception.Message}}}
 foreach($connection in $connections){try{$connection.Dispose();$result.connections_closed++}catch{$result.cleanup_failures+=@{boundary='connection';message=$_.Exception.Message}}}
 if($result.cleanup_failures.Count){$result.passed=$false}
 $result.finished_utc=[datetime]::UtcNow.ToString('o')
 $out=Join-Path $EvidenceDirectory ('native-marker-'+$database+'.json')
 $stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$raw=[Text.UTF8Encoding]::new($false).GetBytes(($result|ConvertTo-Json -Depth 10));$stream.Write($raw,0,$raw.Length)}finally{$stream.Dispose()}
 $result|ConvertTo-Json -Depth 10
}
if(-not $result.passed){exit 1}
