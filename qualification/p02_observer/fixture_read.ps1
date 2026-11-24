#requires -Version 5.1
# Sealed read-only qualification. Never invokes the release Apply/Status entry.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packet=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifest=Get-Content -LiteralPath (Join-Path $packet 'manifest.json') -Raw|ConvertFrom-Json
if($env:COMPUTERNAME -cne 'MINI_AMD' -or $manifest.stage -cne 'observer-release-fixture-read' -or $manifest.production_eligible -ne $false -or $manifest.database_id -ne 12){throw 'Exact read-only lab packet required'}
foreach($property in $manifest.files.PSObject.Properties) {
 $file=[IO.Path]::GetFullPath((Join-Path $packet $property.Name))
 if(-not $file.StartsWith($packet+'\',[StringComparison]::OrdinalIgnoreCase) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -cne $property.Value){throw 'Sealed read-only member differs'}
}
$started=[DateTime]::UtcNow
$receipt=[ordered]@{schema='p02-observer-release-fixture-read/1';started=$started.ToString('o');outcome='running';production_operations=0;business_operations=0;installation_replayed=$false;connections_closed=0;dispatches=0;timings=@();checks=@();first_failure=$null}
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
 $backup='C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\P021_PreImport_20261107_inputs\ROK_TRACKER_full_20261103.bak'
 if($manifest.backup_path -cne $backup){throw 'Exact retained backup input required'}
 $info=Get-Item -LiteralPath $backup -Force
 if($info.PSIsContainer -or ($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $info.Length -le 0){throw 'Ordinary retained backup file required'}
 $receipt.backup_file=[ordered]@{path=$backup;bytes=$info.Length;last_write_utc=$info.LastWriteTimeUtc.ToString('o')}
 $receipt.volumes=@(Get-PSDrive C,Q|ForEach-Object {[pscustomobject]@{name=$_.Name;free=$_.Free;used=$_.Used}})
 $builder=[Data.SqlClient.SqlConnectionStringBuilder]::new()
 $builder['Data Source']='lpc:localhost';$builder['Initial Catalog']='ROK_TRACKER';$builder['Integrated Security']=$true
 $builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=3;$builder['Pooling']=$false;$builder['Application Name']='P02ObserverFixtureReadOnly'
 $connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString);$connection.Open()
 $identitySql=@'
SELECT DB_NAME() AS database_name,DB_ID() AS database_id,s.object_id AS sequence_object_id,
 CONVERT(bigint,s.current_value) AS generation,s.create_date AS sequence_created,
 d.create_date AS database_created,d.snapshot_isolation_state,d.is_read_committed_snapshot_on
FROM sys.sequences s CROSS JOIN sys.databases d
WHERE s.object_id=OBJECT_ID(N'dbo.P02ObservationGeneration') AND DB_ID()=12
 AND d.database_id=12 AND d.name=N'ROK_TRACKER' AND d.state=0 AND d.is_read_only=0
 AND d.create_date=CONVERT(datetime,'2026-11-17T17:34:47.357',126)
 AND s.object_id=1221344607 AND s.create_date=CONVERT(datetime,'2026-11-20T13:14:27.063',126);
'@
 $before=Invoke-K98ModuleQuery $connection $null $identitySql
 if($before.Count -ne 1 -or $before[0].generation -ne 127 -or $before[0].snapshot_isolation_state -ne 1 -or $before[0].is_read_committed_snapshot_on){throw 'Exact preserved observer fixture required'}
 $receipt.target=$before[0]
 $receipt.header=Invoke-K98ModuleQuery $connection $null @'
RESTORE HEADERONLY FROM DISK=N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\P021_PreImport_20261107_inputs\ROK_TRACKER_full_20261103.bak';
'@
 if($receipt.header.Count -ne 1 -or $receipt.header[0].DatabaseName -cne 'ROK_TRACKER' -or $receipt.header[0].BackupType -ne 1 -or $receipt.header[0].IsDamaged -or $receipt.header[0].BackupStartDate -isnot [datetime] -or $receipt.header[0].BackupStartDate.ToString('yyyy-MM-dd') -cne '2026-11-03'){throw 'Expected genuine pre-P02 full backup header differs'}
 $receipt.files=Invoke-K98ModuleQuery $connection $null @'
RESTORE FILELISTONLY FROM DISK=N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\P021_PreImport_20261107_inputs\ROK_TRACKER_full_20261103.bak';
'@
 if($receipt.files.Count -lt 2){throw 'Full backup file list is incomplete'}
 $receipt.allocated_bytes=0L
 foreach($file in $receipt.files){if(-not $file.IsPresent -or $file.Size -le 0){throw 'Backup member missing or invalid'};$receipt.allocated_bytes+=[long]$file.Size}
 $receipt.database_files=Invoke-K98ModuleQuery $connection $null 'SELECT database_id,name,type_desc,size,physical_name FROM sys.master_files WHERE database_id>4 ORDER BY database_id,file_id;'
 $receipt.login=Invoke-K98ModuleQuery $connection $null "SELECT name,is_disabled FROM sys.sql_logins WHERE name=N'S11_ExportApplication_P02ObserverQual';"
 if($receipt.login.Count -ne 1 -or -not $receipt.login[0].is_disabled){throw 'Retained lab login must remain disabled'}
 $after=Invoke-K98ModuleQuery $connection $null $identitySql
 if(($after|ConvertTo-Json -Compress) -cne ($before|ConvertTo-Json -Compress)){throw 'Preserved fixture changed during header inspection'}
 $receipt.checks+=@([ordered]@{name='genuine-backup-header-and-file-list';passed=$true;restore_performed=$false;backup_integrity_verified=$false;migration_history_in_backup_verified=$false})
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
Write-Output ($receipt|Select-Object outcome,dispatches,connections_closed,maximum_batch_ms,production_operations,business_operations|ConvertTo-Json -Compress)
if($receipt.outcome -cne 'passed'){exit 1}
