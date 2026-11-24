#requires -Version 5.1
# Sealed read-only qualification. Never invokes the release Apply/Status entry.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packet=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifest=Get-Content -LiteralPath (Join-Path $packet 'manifest.json') -Raw|ConvertFrom-Json
if($env:COMPUTERNAME -cne 'MINI_AMD' -or $manifest.stage -cne 'observer-release-preflight-read' -or $manifest.production_eligible -ne $false -or $manifest.database_id -ne 12){throw 'Exact read-only lab packet required'}
foreach($property in $manifest.files.PSObject.Properties) {
 $file=[IO.Path]::GetFullPath((Join-Path $packet $property.Name))
 if(-not $file.StartsWith($packet+'\',[StringComparison]::OrdinalIgnoreCase) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -cne $property.Value){throw 'Sealed read-only member differs'}
}
. "$packet/sql/deploy/SqlDeploy.ModuleRelease.ps1"
. "$packet/sql/deploy/SqlDeploy.P02ObserverRelease.ps1"
$started=[DateTime]::UtcNow
$receipt=[ordered]@{schema='p02-observer-release-native-read/1';started=$started.ToString('o');outcome='running';production_operations=0;business_operations=0;installation_replayed=$false;connections_closed=0;dispatches=0;timings=@();checks=@();first_failure=$null}
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
 $builder['Data Source']='lpc:localhost';$builder['Initial Catalog']='ROK_TRACKER';$builder['Integrated Security']=$true
 $builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=3;$builder['Pooling']=$false;$builder['Application Name']='P02ObserverReleaseReadOnly'
 $connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString);$connection.Open()
 $target=Invoke-K98ModuleQuery $connection $null @'
SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,DB_NAME() AS database_name,
 database_id,create_date AS created,state_desc,is_read_only,snapshot_isolation_state,is_read_committed_snapshot_on
FROM sys.databases WHERE database_id=DB_ID();
'@
 $receipt.target_rows=$target
 if($target.Count -eq 1){$receipt.created_driver_raw=$target[0].created.ToString('o');$target[0].created=ConvertTo-K98ObserverStamp $target[0].created}
 Save-Receipt
 if($target.Count -ne 1 -or $target[0].server_name -cne 'MINI_AMD' -or $target[0].database_name -cne 'ROK_TRACKER' -or $target[0].database_id -ne 12 -or $target[0].created -cne '2026-11-17T17:34:47.357000' -or $target[0].snapshot_isolation_state -ne 1 -or $target[0].is_read_committed_snapshot_on){throw 'Preserved ROK_TRACKER fixture identity differs'}
 $receipt.target=$target[0]
 $id='20261120_001_p02_catalogue_observer'
 $loaded=Read-K98ModuleProfile (Join-Path $packet ('sql/migrations/'+$id+'.release.json')) $manifest.profile_sha256 $id
 $identity=Get-K98ObserverIncarnation $connection $null $loaded
 if($identity.database_id -ne 12 -or $identity.sequence_object_id -ne 1221344607 -or $identity.sequence_created -cne '2026-11-20T13:14:27.063000'){throw 'Retained committed lab sequence differs'}
 $receipt.incarnation=$identity
 Assert-K98ObserverImages $connection $null $loaded $true
 $receipt.checks+=@([ordered]@{name='source-derived-native-postcheck';passed=$true})
 $receipt.history=Invoke-K98ModuleQuery $connection $null 'SELECT TOP (129) MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM dbo.SchemaMigrationHistory ORDER BY MigrationId;'
 $receipt.observer_attempts=Invoke-K98ModuleQuery $connection $null "SELECT DeploymentId,Status,GitCommit,BranchName FROM dbo.DeploymentRunHistory WHERE BranchName=N'p02_catalogue_observer_v1';"
 $receipt.databases=Invoke-K98ModuleQuery $connection $null 'SELECT TOP (100) name,database_id,create_date,state_desc,is_read_only,source_database_id FROM sys.databases WHERE database_id>4 ORDER BY database_id;'
 $receipt.backups=Invoke-K98ModuleQuery $connection $null @'
SELECT TOP (20) b.database_name,b.backup_start_date,b.backup_finish_date,b.type,b.is_damaged,b.is_copy_only,b.database_creation_date,m.physical_device_name
FROM msdb.dbo.backupset b JOIN msdb.dbo.backupmediafamily m ON m.media_set_id=b.media_set_id
WHERE b.database_name IN (N'ROK_TRACKER',N'K98_P025_D5e_Cost_20261115') ORDER BY b.backup_finish_date DESC;
'@
 $receipt.login=Invoke-K98ModuleQuery $connection $null "SELECT name,is_disabled FROM sys.sql_logins WHERE name=N'S11_ExportApplication_P02ObserverQual';"
 if($receipt.login.Count -ne 1 -or -not $receipt.login[0].is_disabled){throw 'Lab application login was expected to remain disabled'}
 $after=Get-K98ObserverIncarnation $connection $null $loaded
 if(($after|ConvertTo-Json -Compress) -cne ($identity|ConvertTo-Json -Compress)){throw 'Read-only observation incarnation changed'}
 $receipt.checks+=@([ordered]@{name='retained-fixture-and-disabled-login';passed=$true})
 $receipt.maximum_batch_ms=0.0
 foreach($timing in $receipt.timings){$receipt.maximum_batch_ms=[Math]::Max($receipt.maximum_batch_ms,[double]$timing['milliseconds'])}
 if($receipt.maximum_batch_ms -gt 250){throw 'Read-only native batch exceeds the 250 ms target; retain timings and diagnose'}
 $receipt.outcome='passed'
}catch{
 $receipt.outcome='failed';$receipt.first_failure=[ordered]@{type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}
}finally{
 if($null -ne $connection){
  try{$connection.Close();$connection.Dispose();$receipt.connections_closed++}catch{$receipt.cleanup_unknown=$true;$receipt.outcome='failed';if($null -eq $receipt.first_failure){$receipt.first_failure=[ordered]@{type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}}}
 }
 Save-Receipt
}
Write-Output ($receipt|Select-Object outcome,dispatches,connections_closed,maximum_batch_ms,production_operations,business_operations|ConvertTo-Json -Compress)
if($receipt.outcome -cne 'passed'){exit 1}
