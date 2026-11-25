param([Parameter(Mandatory=$true)][string]$EvidenceDirectory,[Parameter(Mandatory=$true)][string]$BeforeTrigger)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$database='K98_P02Correction_'+[datetime]::UtcNow.ToString('yyyyMMddHHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
if($env:COMPUTERNAME -cne '9SX2VF4'){throw 'Local development host only'}
$connections=[Collections.Generic.List[Data.SqlClient.SqlConnection]]::new()
$result=[ordered]@{schema='p02-native-trigger-correction/1';database=$database;server='9SX2VF4\K98DEV';started_utc=[datetime]::UtcNow.ToString('o');passed=$false;checks=@();first_failure=$null;connections_opened=0;connections_closed=0;production_operations=0;fixture_retained=$true}
function Connect([string]$Database){
 $b=[Data.SqlClient.SqlConnectionStringBuilder]::new()
 $b['Data Source']='lpc:.\K98DEV';$b['Initial Catalog']=$Database;$b['Integrated Security']=$true;$b['Encrypt']=$false;$b['Pooling']=$false;$b['Connect Timeout']=5
 $c=[Data.SqlClient.SqlConnection]::new($b.ConnectionString);$connections.Add($c);$c.Open();$result.connections_opened++;return $c
}
function Execute($Connection,[string]$Sql){
 $command=$Connection.CreateCommand();$command.CommandText=$Sql;$command.CommandTimeout=10
 try{$null=$command.ExecuteNonQuery()}finally{$command.Dispose()}
}
function Scalar($Connection,[string]$Sql){
 $command=$Connection.CreateCommand();$command.CommandText=$Sql;$command.CommandTimeout=10
 try{return $command.ExecuteScalar()}finally{$command.Dispose()}
}
function Check([bool]$Value,[string]$Name){
 if(-not $Value){throw ('Check failed: '+$Name)}
 $result.checks+=@{name=$Name;passed=$true}
}
function Source([string]$Path){return [IO.File]::ReadAllText($Path)}
function InstallBatches($Connection,[string]$Text){
 foreach($batch in [regex]::Split($Text,'(?im)^\s*GO\s*$')){if($batch.Trim()){Execute $Connection $batch.TrimStart([char[]]"`r`n")}}
}
function SqlFailure([scriptblock]$Body,[int]$Number,[string]$Name){
 $caught=$null
 try{& $Body}catch{$caught=$_.Exception}
 if($null -eq $caught){throw ('Expected SQL failure absent: '+$Name)}
 while($caught.InnerException -and $caught -isnot [Data.SqlClient.SqlException]){$caught=$caught.InnerException}
 if($caught -isnot [Data.SqlClient.SqlException] -or $Number -notin @($caught.Errors|ForEach-Object Number)){throw $caught}
 $result.checks+=@{name=$Name;passed=$true;expected_sql_error=$Number}
}
try{
 $master=Connect 'master'
 Check ((Scalar $master "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))") -ceq '9SX2VF4\K98DEV') 'Exact local test engine'
 Check ((Scalar $master "SELECT DB_ID(N'$database')") -is [DBNull]) 'New isolated correction database'
 Execute $master ("CREATE DATABASE ["+$database+"] COLLATE Latin1_General_CI_AS;")
 $c=Connect $database
 InstallBatches $c (Source (Join-Path $repo 'sql_schema\dbo.P02ObservationGeneration.Sequence.sql'))
 InstallBatches $c (Source (Join-Path $repo 'sql_schema\dbo.usp_P02BeginCatalogueMutation.StoredProcedure.sql'))
 InstallBatches $c (Source $BeforeTrigger)
 $id='20261125_001_p02_observer_xml_options'
 $migration=Source (Join-Path $repo ('migrations\'+$id+'.sql'))
 SqlFailure {Execute $c $migration} 51974 'Production migration refuses local target without changes'
 # Exercise the exact reviewed ALTER statement and exact trigger image checks.
 # Production identity/outer drain/history are covered by guarded runner tests,
 # never bypassed or presented as a complete production release here.
 $statement=$migration.Substring($migration.IndexOf("EXEC sys.sp_executesql N'ALTER TRIGGER"))
 if(-not $statement.StartsWith("EXEC sys.sp_executesql N'ALTER TRIGGER")){throw 'Exact correction statement missing'}
 function TriggerCheck([string]$Phase){
  $text=Source (Join-Path $repo ('migrations\'+$id+'.'+$Phase+'.sql'))
  $start=$text.IndexOf("SET @id=(SELECT object_id FROM sys.triggers WHERE parent_class=0 AND name=N'tr_P02CatalogueObservation');")
  $end=$text.IndexOf("SET @id=OBJECT_ID(N'dbo.tr_P02HeaderObservation');",$start)
  if($start -lt 0 -or $end -le $start){throw 'Exact trigger image check missing'}
  return 'DECLARE @id int,@body nvarchar(max);'+$text.Substring($start,$end-$start)
 }
 $before=TriggerCheck 'before';$after=TriggerCheck 'after'
 Execute $c $before;Check $true 'Exact original trigger image admitted'
 $identity=Scalar $c "SELECT CONVERT(nvarchar(30),object_id)+N'|'+CONVERT(nvarchar(30),create_date,126)+N'|'+CONVERT(nvarchar(30),modify_date,126) FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration')"
 $triggerId=Scalar $c "SELECT object_id FROM sys.triggers WHERE parent_class=0 AND name=N'tr_P02CatalogueObservation'"
 Execute $c 'BEGIN TRANSACTION;'
 Execute $c $statement
 Execute $c $after;Check $true 'Exact corrected trigger image inside release transaction'
 Execute $c 'ROLLBACK TRANSACTION;'
 Execute $c $before;Check $true 'Interrupted uncommitted correction retains original trigger'
 Execute $c 'BEGIN TRANSACTION;'
 Execute $c $statement
 Execute $c $after
 Execute $c 'COMMIT TRANSACTION;'
 Execute $c $after;Check $true 'Committed correction retains exact reviewed trigger'
 SqlFailure {Execute $c $before} 51973 'Original preimage cannot admit already committed correction'
 Check ((Scalar $c "SELECT CONVERT(nvarchar(30),object_id)+N'|'+CONVERT(nvarchar(30),create_date,126)+N'|'+CONVERT(nvarchar(30),modify_date,126) FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration')") -ceq $identity) 'Original sequence identity and timestamps unchanged'
 Check ((Scalar $c "SELECT object_id FROM sys.triggers WHERE parent_class=0 AND name=N'tr_P02CatalogueObservation'") -eq $triggerId) 'ALTER preserves original trigger identity'
 Check ((Scalar $c 'SELECT @@TRANCOUNT') -eq 0) 'Correction transaction settled'
 $result.passed=$true
}catch{
 $result.first_failure=@{type=$_.Exception.GetType().FullName;message=$_.Exception.Message;line=$_.InvocationInfo.ScriptLineNumber}
}finally{
 foreach($connection in $connections){try{$connection.Dispose();$result.connections_closed++}catch{if($null -eq $result.first_failure){$result.first_failure=@{type=$_.Exception.GetType().FullName;message=$_.Exception.Message}};$result.passed=$false}}
 $result.finished_utc=[datetime]::UtcNow.ToString('o')
 $result.before_trigger_sha256=(Get-FileHash -LiteralPath $BeforeTrigger -Algorithm SHA256).Hash.ToLowerInvariant()
 $result.after_trigger_sha256=(Get-FileHash -LiteralPath (Join-Path $repo 'sql_schema\tr_P02CatalogueObservation.DatabaseTrigger.sql') -Algorithm SHA256).Hash.ToLowerInvariant()
 $out=Join-Path $EvidenceDirectory ('native-correction-'+$database+'.json')
 $stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($result|ConvertTo-Json -Depth 8));$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
 $result|ConvertTo-Json -Depth 8
}
if(-not $result.passed){exit 1}
