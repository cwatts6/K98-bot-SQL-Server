#requires -Version 5.1
# Sealed read-only qualification. Never invokes the release Apply/Status entry.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packet=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifest=Get-Content -LiteralPath (Join-Path $packet 'manifest.json') -Raw|ConvertFrom-Json
if($env:COMPUTERNAME -cne 'MINI_AMD' -or $manifest.stage -cne 'observer-release-prerequisite-read' -or $manifest.production_eligible -ne $false -or $manifest.database_id -ne 16){throw 'Exact read-only lab packet required'}
foreach($property in $manifest.files.PSObject.Properties) {
 $file=[IO.Path]::GetFullPath((Join-Path $packet $property.Name))
 if(-not $file.StartsWith($packet+'\',[StringComparison]::OrdinalIgnoreCase) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -cne $property.Value){throw 'Sealed read-only member differs'}
}
$started=[DateTime]::UtcNow
$receipt=[ordered]@{schema='p02-observer-release-prerequisite-read/1';started=$started.ToString('o');outcome='running';production_operations=0;business_operations=0;installation_replayed=$false;connections_closed=0;dispatches=0;timings=@();checks=@();first_failure=$null}
$connection=$null
function Save-Receipt {
 $receipt.elapsed_seconds=([DateTime]::UtcNow-$started).TotalSeconds
 $text=$receipt|ConvertTo-Json -Depth 14
 [IO.File]::WriteAllText((Join-Path $packet 'receipt.json'),$text,[Text.UTF8Encoding]::new($false))
}
function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {
 if($null -ne $Transaction){throw 'Read-only packet cannot accept a transaction'}
 if(([DateTime]::UtcNow-$started).TotalSeconds -ge 45 -or $receipt.dispatches -ge 256){throw 'Read-only owner budget exhausted'}
 $receipt.dispatches++
 $command=$Connection.CreateCommand();$command.CommandText=$Sql;$command.CommandTimeout=3
 foreach($key in $Values.Keys){[void]$command.Parameters.AddWithValue('@'+$key,$Values[$key])}
 $reader=$null;$rows=[Collections.Generic.List[object]]::new();$clock=[Diagnostics.Stopwatch]::StartNew()
 try {
  $reader=$command.ExecuteReader()
  do {while($reader.Read()) {
   if($rows.Count -ge 256){throw 'Bounded read-only result exceeded'}
   $row=[ordered]@{}
   for($i=0;$i -lt $reader.FieldCount;$i++){$value=$reader.GetValue($i);if($value -is [DBNull]){$value=$null};$row[$reader.GetName($i)]=$value}
   $rows.Add([pscustomobject]$row)
  }}while($reader.NextResult())
  return ,$rows.ToArray()
 }finally{
  if($null -ne $reader){$reader.Dispose()};$command.Dispose();$clock.Stop()
  $receipt.timings+=@([ordered]@{dispatch=$receipt.dispatches;milliseconds=$clock.Elapsed.TotalMilliseconds})
  Save-Receipt
 }
}
try {
 $builder=[Data.SqlClient.SqlConnectionStringBuilder]::new()
 $builder['Data Source']='lpc:localhost';$builder['Initial Catalog']='master';$builder['Integrated Security']=$true
 $builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=3;$builder['Pooling']=$false;$builder['Application Name']='P02PrerequisiteReadOnly'
 $connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString);$connection.Open()
 $identity=Invoke-K98ModuleQuery $connection $null "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,ORIGINAL_LOGIN() AS login_name,IS_SRVROLEMEMBER('sysadmin') AS administrator;"
 if($identity.Count -ne 1 -or $identity[0].server_name -cne 'MINI_AMD' -or $identity[0].login_name -ine 'MINI_AMD\K98LabAdmin' -or $identity[0].administrator -ne 1){throw 'Exact isolated SQL identity required'}
 $databaseSql='SELECT name,database_id,create_date,state_desc,user_access_desc,source_database_id,snapshot_isolation_state,is_read_committed_snapshot_on,is_broker_enabled FROM sys.databases WHERE database_id IN (11,12,14,15,16) ORDER BY database_id;'
 $receipt.databases=Invoke-K98ModuleQuery $connection $null $databaseSql
 if($receipt.databases.Count -ne 5 -or $receipt.databases[0].name -cne 'K98_P025_D5e_Cost_20261115' -or $receipt.databases[1].name -cne 'K98_P02Observer_Retained_20261120153927686' -or $receipt.databases[2].source_database_id -ne 11 -or $receipt.databases[3].source_database_id -ne 12 -or $receipt.databases[4].name -cne 'ROK_TRACKER' -or $receipt.databases[4].snapshot_isolation_state -ne 1 -or $receipt.databases[4].is_read_committed_snapshot_on -or $receipt.databases[4].is_broker_enabled){throw 'Exact acknowledged renamed fixtures and snapshot mode required'}
 $receipt.files=Invoke-K98ModuleQuery $connection $null 'SELECT database_id,file_id,physical_name FROM sys.master_files WHERE database_id IN (11,12,14,15,16) ORDER BY database_id,file_id;'
 if($receipt.files.Count -ne $manifest.expected_files.Count){throw 'Physical fixture inventory differs'}
 for($i=0;$i -lt $receipt.files.Count;$i++){foreach($key in @('database_id','file_id','physical_name')){if([string]$receipt.files[$i].$key -cne [string]$manifest.expected_files[$i].$key){throw 'Retained physical ownership changed'}}}
 $receipt.observer=Invoke-K98ModuleQuery $connection $null "SELECT object_id,create_date,modify_date,CONVERT(bigint,current_value) AS generation FROM [K98_P02Observer_Retained_20261120153927686].sys.sequences WHERE name=N'P02ObservationGeneration';"
 if($receipt.observer.Count -ne 1 -or $receipt.observer[0].object_id -ne 1221344607 -or $receipt.observer[0].generation -ne 127){throw 'Retained observer identity/generation differs'}
 $receipt.history=Invoke-K98ModuleQuery $connection $null 'SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM ROK_TRACKER.dbo.SchemaMigrationHistory ORDER BY MigrationId;'
 if($receipt.history.Count -ne $manifest.expected_history.Count){throw 'Expected genuine history count differs'}
 for($i=0;$i -lt $receipt.history.Count;$i++){foreach($key in @('MigrationId','ChecksumSha256','GitCommit','DeploymentId','Status')){if([string]$receipt.history[$i].$key -cne [string]$manifest.expected_history[$i].$key){throw ('Genuine history differs: '+$receipt.history[$i].MigrationId)}}}
 $receipt.d4_attempts=Invoke-K98ModuleQuery $connection $null @'
SELECT DeploymentId,Status,GitCommit,BranchName,ErrorMessage FROM ROK_TRACKER.dbo.DeploymentRunHistory
WHERE BranchName=N'p02_d4_v1' OR JSON_VALUE(CASE WHEN ISJSON(ErrorMessage)=1 THEN ErrorMessage ELSE NULL END,'$.migration_id')=N'20261111_001_p02_d4_combined';
'@
 if($receipt.d4_attempts.Count){throw 'Unexpected D4 attempt requires separate reconciliation'}
 $receipt.wrapper=Invoke-K98ModuleQuery $connection $null @'
SELECT p.object_id,s.name AS schema_name,p.name,o.name AS owner_name,m.execute_as_principal_id,m.uses_ansi_nulls,m.uses_quoted_identifier,
 m.definition,CONVERT(varchar(64),HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10))),2) AS definition_sha256,
 (SELECT COUNT(*) FROM msdb.sys.crypt_properties c WHERE c.class=1 AND c.major_id=p.object_id) AS signature_count
FROM msdb.sys.procedures p JOIN msdb.sys.schemas s ON s.schema_id=p.schema_id
JOIN msdb.sys.sql_modules m ON m.object_id=p.object_id
JOIN msdb.sys.database_principals o ON o.principal_id=COALESCE(p.principal_id,s.principal_id)
WHERE s.name=N'dbo' AND p.name=N'usp_start_rok_tracker_log_backup';
'@
 $receipt.wrapper_permissions=Invoke-K98ModuleQuery $connection $null @'
SELECT u.name AS grantee,g.name AS grantor,p.permission_name,p.state_desc,p.minor_id
FROM msdb.sys.database_permissions p JOIN msdb.sys.database_principals u ON u.principal_id=p.grantee_principal_id
JOIN msdb.sys.database_principals g ON g.principal_id=p.grantor_principal_id
WHERE p.class=1 AND p.major_id=(SELECT o.object_id FROM msdb.sys.procedures o JOIN msdb.sys.schemas s ON s.schema_id=o.schema_id WHERE s.name=N'dbo' AND o.name=N'usp_start_rok_tracker_log_backup')
ORDER BY u.name COLLATE Latin1_General_100_BIN2,g.name COLLATE Latin1_General_100_BIN2,p.permission_name COLLATE Latin1_General_100_BIN2,p.state_desc COLLATE Latin1_General_100_BIN2,p.minor_id;
'@
 $receipt.backup_jobs=Invoke-K98ModuleQuery $connection $null @'
SELECT j.job_id,j.name,j.enabled,j.start_step_id,SUSER_SNAME(j.owner_sid) AS owner_name,
 IS_SRVROLEMEMBER(N'sysadmin',SUSER_SNAME(j.owner_sid)) AS owner_sysadmin,
 s.step_id,s.subsystem,s.database_name,s.proxy_id,CONVERT(varchar(64),HASHBYTES('SHA2_256',s.command),2) AS command_hash
FROM msdb.dbo.sysjobs j LEFT JOIN msdb.dbo.sysjobsteps s ON s.job_id=j.job_id
WHERE CONVERT(varchar(64),HASHBYTES('SHA2_256',UPPER(CONVERT(nvarchar(36),j.job_id))),2)='DD0CBB684C3CEA798026CF11861FFA27CA76AA6447BAD43789962E6FDC90E6F0'
ORDER BY s.step_id;
'@
 $receipt.msdb_principals=Invoke-K98ModuleQuery $connection $null @'
SELECT name,type_desc,authentication_type_desc FROM msdb.sys.database_principals WHERE name IN (N'ImportProcUser',N'SHEETS_USER');
SELECT IS_SRVROLEMEMBER(N'sysadmin',SUSER_SNAME(owner_sid)) AS owner_sysadmin FROM sys.databases WHERE name=N'msdb';
'@
 $receipt.login=Invoke-K98ModuleQuery $connection $null "SELECT name,is_disabled FROM sys.sql_logins WHERE name=N'S11_ExportApplication_P02ObserverQual';"
 if($receipt.login.Count -ne 1 -or -not $receipt.login[0].is_disabled){throw 'Retained lab login must remain disabled'}
 $receipt.sql_agent=[string](Get-Service -Name SQLSERVERAGENT).Status
 $after=Invoke-K98ModuleQuery $connection $null $databaseSql
 if(($after|ConvertTo-Json -Compress) -cne ($receipt.databases|ConvertTo-Json -Compress)){throw 'Fixture identity changed during bounded read'}
 $receipt.checks+=@([ordered]@{name='acknowledged-fixture-and-history-reconciliation';passed=$true;D4_accepted=$false;dependency_installed=$false})
 $receipt.maximum_batch_ms=0.0
 foreach($timing in $receipt.timings){$receipt.maximum_batch_ms=[Math]::Max($receipt.maximum_batch_ms,[double]$timing['milliseconds'])}
 $receipt.outcome='passed'
}catch{
 $receipt.outcome='failed';$receipt.first_failure=[ordered]@{type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}
}finally{
 if($null -ne $connection){
  try{$connection.Close();$connection.Dispose();$receipt.connections_closed++}catch{$receipt.cleanup_unknown=$true;$receipt.outcome='failed';if($null -eq $receipt.first_failure){$receipt.first_failure=[ordered]@{type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}}}
 }
 Save-Receipt
}
[pscustomobject]$receipt|Select-Object outcome,dispatches,connections_closed,maximum_batch_ms|ConvertTo-Json -Compress
if($receipt.outcome -cne 'passed'){exit 1}
