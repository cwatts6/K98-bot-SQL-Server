param([Parameter(Mandatory=$true)][string]$EvidenceDirectory,[Parameter(Mandatory=$true)][string]$BeforeTrigger)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$database='K98_P02Options_'+[datetime]::UtcNow.ToString('yyyyMMddHHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
if($env:COMPUTERNAME -cne '9SX2VF4'){throw 'Local development host only'}
$connections=[Collections.Generic.List[Data.SqlClient.SqlConnection]]::new()
$result=[ordered]@{schema='p02-native-trigger-options/1';database=$database;server='9SX2VF4\K98DEV';started_utc=[datetime]::UtcNow.ToString('o');passed=$false;checks=@();first_failure=$null;connections_opened=0;connections_closed=0;production_operations=0;fixture_retained=$true}
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
 foreach($batch in [regex]::Split($Text,'(?im)^\s*GO\s*$')){if($batch.Trim()){Execute $Connection $batch}}
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
 Check ((Scalar $master "SELECT DB_ID(N'$database')") -is [DBNull]) 'New isolated database'
 Execute $master ("CREATE DATABASE ["+$database+"] COLLATE Latin1_General_CI_AS;")
 $c=Connect $database
 InstallBatches $c (Source (Join-Path $repo 'sql_schema\dbo.P02ObservationGeneration.Sequence.sql'))
 InstallBatches $c (Source (Join-Path $repo 'sql_schema\dbo.usp_P02BeginCatalogueMutation.StoredProcedure.sql'))
 InstallBatches $c (Source $BeforeTrigger)
 SqlFailure {Execute $c 'SET ANSI_WARNINGS OFF; CREATE TABLE dbo.BeforeFailure(Value int);'} 1934 'Original trigger reproduces actual ANSI_WARNINGS failure'
 Check ((Scalar $c "SELECT OBJECT_ID(N'dbo.BeforeFailure')") -is [DBNull]) 'Original refused DDL left no table'
 Check ((Scalar $c 'SELECT @@TRANCOUNT') -eq 0) 'Original refusal settled transaction'
 Execute $c 'SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;'
 InstallBatches $c (Source (Join-Path $repo 'sql_schema\tr_P02CatalogueObservation.DatabaseTrigger.sql'))
 Execute $c 'SET ANSI_WARNINGS OFF; SET ARITHABORT OFF; SET NUMERIC_ROUNDABORT ON; SET CONCAT_NULL_YIELDS_NULL OFF;'
 $options=Scalar $c 'SELECT @@OPTIONS'
 $generation=Scalar $c "SELECT CONVERT(bigint,current_value) FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration')"
 Execute $c 'CREATE TABLE dbo.OptionsWork(Value int); ALTER TABLE dbo.OptionsWork ADD Extra int NULL; DROP TABLE dbo.OptionsWork;'
 Check ((Scalar $c 'SELECT @@OPTIONS') -eq $options) 'All caller session options preserved after DDL'
 Check ((Scalar $c 'SELECT @@TRANCOUNT') -eq 0) 'Autocommit DDL nesting unchanged'
 Check ((Scalar $c "SELECT CONVERT(bigint,current_value) FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration')") -gt $generation) 'CREATE ALTER DROP advance observer generation'
 Execute $c "CREATE PROCEDURE dbo.CallerOptions AS BEGIN SET NOCOUNT ON; SET ANSI_WARNINGS OFF; DECLARE @before int=@@OPTIONS; CREATE TABLE dbo.NestedOptions(Value int); IF @@OPTIONS<>@before THROW 51979,'Caller options changed',1; DROP TABLE dbo.NestedOptions; END;"
 Execute $c 'EXEC dbo.CallerOptions;'
 Check ((Scalar $c 'SELECT @@OPTIONS') -eq $options) 'Nested stored procedure caller options preserved'
 Execute $c 'BEGIN TRANSACTION; CREATE TABLE dbo.RollbackOptions(Value int);'
 Check ((Scalar $c 'SELECT @@TRANCOUNT') -eq 1) 'Enclosing transaction nesting preserved'
 Check ((Scalar $c "SELECT APPLOCK_MODE('public','K98:catalogue-mutation:v1','Transaction')") -ceq 'Shared') 'Mutation marker held until enclosing transaction ends'
 $other=Connect $database
 Check ((Scalar $other "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'K98:catalogue-mutation:v1',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; SELECT @r;") -eq -1) 'Independent observer cannot pass active mutation'
 Execute $c 'ROLLBACK TRANSACTION;'
 Check ((Scalar $c "SELECT OBJECT_ID(N'dbo.RollbackOptions')") -is [DBNull]) 'Rollback removes fixture DDL'
 Check ((Scalar $c 'SELECT @@TRANCOUNT') -eq 0) 'Rollback closes transaction'
 Check ((Scalar $other "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'K98:catalogue-mutation:v1',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0; IF @r IN (0,1) EXEC sys.sp_releaseapplock @Resource=N'K98:catalogue-mutation:v1',@LockOwner='Session'; SELECT @r;") -in @(0,1)) 'Mutation marker released after rollback'
 SqlFailure {Execute $c 'ALTER SEQUENCE dbo.P02ObservationGeneration RESTART WITH 1;'} 51970 'Sequence reset remains refused under caller options'
 Check ((Scalar $c 'SELECT @@OPTIONS') -eq $options) 'Caller options preserved after guarded refusal'
 Check ((Scalar $c 'SELECT @@TRANCOUNT') -eq 0) 'Guarded refusal leaves no transaction'
 $result.passed=$true
}catch{
 $result.first_failure=@{type=$_.Exception.GetType().FullName;message=$_.Exception.Message;line=$_.InvocationInfo.ScriptLineNumber}
}finally{
 foreach($connection in $connections){try{$connection.Dispose();$result.connections_closed++}catch{if($null -eq $result.first_failure){$result.first_failure=@{type=$_.Exception.GetType().FullName;message=$_.Exception.Message}};$result.passed=$false}}
 $result.finished_utc=[datetime]::UtcNow.ToString('o')
 $result.before_trigger_sha256=(Get-FileHash -LiteralPath $BeforeTrigger -Algorithm SHA256).Hash.ToLowerInvariant()
 $result.after_trigger_sha256=(Get-FileHash -LiteralPath (Join-Path $repo 'sql_schema\tr_P02CatalogueObservation.DatabaseTrigger.sql') -Algorithm SHA256).Hash.ToLowerInvariant()
 $out=Join-Path $EvidenceDirectory ('native-options-'+$database+'.json')
 $stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($result|ConvertTo-Json -Depth 8));$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
 $result|ConvertTo-Json -Depth 8
}
if(-not $result.passed){exit 1}
