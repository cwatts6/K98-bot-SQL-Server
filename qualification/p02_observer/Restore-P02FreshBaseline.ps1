param([string]$DatabaseName)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:COMPUTERNAME -cne 'MINI_AMD' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ine 'MINI_AMD\K98LabAdmin' -or $DatabaseName -cnotmatch '^K98_P02Release_[0-9]{17}$'){throw 'Exact isolated guest and fresh database required'}
if($null -ne (Get-Variable P02FreshBaselineHeld -Scope Global -ErrorAction SilentlyContinue)){throw 'Prior baseline custody retained; no replay'}
$r=[ordered]@{schema='p02-fresh-baseline-guest/1';database=$DatabaseName;started=[DateTime]::UtcNow.ToString('o');outcome='running';stage='preflight';actions=@();first_failure=$null;cleanup_failure=$null;execution_settled=$true;connections_closed=0;production_operations=0;business_operations=0;migration_history_fabricated=$false;release_accepted=$false}
$connection=$null;$command=$null;$pending=$null
$backup='C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\P021_PreImport_20261107_inputs\ROK_TRACKER_full_20261103.bak'
$directory='Q:\P02Release\'+$DatabaseName
$data=$directory+'\baseline.mdf';$log=$directory+'\baseline_log.ldf'
function Read-Baseline([string]$Sql,[hashtable]$Values=@{}) {
 $cmd=$connection.CreateCommand();$cmd.CommandText=$Sql;$cmd.CommandTimeout=3;$reader=$null;$first=$null
 foreach($key in $Values.Keys){[void]$cmd.Parameters.AddWithValue('@'+$key,$Values[$key])}
 try {
  $reader=$cmd.ExecuteReader();$rows=[Collections.Generic.List[object]]::new()
  do{while($reader.Read()){
   if($rows.Count -ge 256){throw 'Baseline observation row limit'}
   $row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$row[$reader.GetName($i)]=if($reader.IsDBNull($i)){$null}else{$reader.GetValue($i)}}
   $rows.Add([pscustomobject]$row)
  }}while($reader.NextResult())
  return ,$rows.ToArray()
 }catch{$first=$_;throw}
 finally{try{if($null -ne $reader){$reader.Dispose()};$cmd.Dispose()}catch{if($null -ne $first){$r.cleanup_failure=$_.Exception.GetType().FullName}else{throw}}}
}
function Invoke-LongBaseline([string]$Label,[string]$Sql,[hashtable]$Values,[int]$Seconds) {
 $r.stage=$Label;$r.actions+=@([ordered]@{action=$Label;acknowledged=$false})
 $script:command=$connection.CreateCommand();$command.CommandText=$Sql;$command.CommandTimeout=0
 foreach($key in $Values.Keys){[void]$command.Parameters.AddWithValue('@'+$key,$Values[$key])}
 $r.execution_settled=$false
 $script:pending=$command.BeginExecuteNonQuery()
 $global:P02FreshBaselineHeld=@{connection=$connection;command=$command;pending=$pending;receipt=$r}
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $pending.IsCompleted -and $watch.Elapsed.TotalSeconds -lt $Seconds){$null=$pending.AsyncWaitHandle.WaitOne(1000)}
 if(-not $pending.IsCompleted){throw 'Native baseline operation still pending; retain original handles; no cancel or replay'}
 try{$null=$command.EndExecuteNonQuery($pending)}finally{$r.execution_settled=$true}
 $r.actions[-1].acknowledged=$true;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds
 $command.Dispose();$script:command=$null;$script:pending=$null
}
try {
 $p=@(Get-Partition -DriveLetter Q);if($p.Count -ne 1){throw 'One qualification partition required'};$d=Get-Disk -Number $p[0].DiskNumber;$v=Get-Volume -DriveLetter Q
 if($p[0].DiskNumber -ne 1 -or $p[0].PartitionNumber -ne 2 -or $p[0].Guid -ine '{47cc6080-9e5f-447c-a9e2-dcc007b1e297}' -or $d.UniqueId -ine '60022480F18852E666A58D834543C4BC' -or $d.Size -ne 416GB -or $d.IsOffline -or $d.IsReadOnly -or $v.SizeRemaining -lt 105GB){throw 'Expanded qualification storage/reserve differs'}
 $r.storage=[ordered]@{disk_id=$d.UniqueId;disk_bytes=$d.Size;partition_id=$p[0].Guid;free_before=$v.SizeRemaining}
 foreach($path in @('Q:\','Q:\P02Release')){if(Test-Path -LiteralPath $path){$item=Get-Item -LiteralPath $path -Force;if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Ordinary qualification directories required'}}}
 if((Test-Path -LiteralPath $directory) -or (Test-Path -LiteralPath $data) -or (Test-Path -LiteralPath $log)){throw 'Fresh file paths required; preserve existing attempt'}
 $file=Get-Item -LiteralPath $backup -Force
 if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -ne 1458380800 -or $file.LastWriteTimeUtc.ToString('o') -cne '2026-11-07T11:21:20.2605388Z'){throw 'Retained backup file binding changed'}
 $connection=[Data.SqlClient.SqlConnection]::new('Data Source=lpc:localhost;Initial Catalog=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=3;Pooling=False;Asynchronous Processing=True;Application Name=P02FreshBaseline')
 $connection.Open()
 $identity=Read-Baseline "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,DB_NAME() AS database_name,ORIGINAL_LOGIN() AS login_name,IS_SRVROLEMEMBER('sysadmin') AS administrator;"
 if($identity.Count -ne 1 -or $identity[0].server_name -cne 'MINI_AMD' -or $identity[0].database_name -cne 'master' -or $identity[0].login_name -ine 'MINI_AMD\K98LabAdmin' -or $identity[0].administrator -ne 1){throw 'Exact lab SQL identity required'}
 if((Read-Baseline 'SELECT database_id FROM sys.databases WHERE name=@name' @{name=$DatabaseName}).Count){throw 'Fresh database name required; no replacement'}
 $retainedSql='SELECT name,database_id,create_date,state_desc,source_database_id FROM sys.databases WHERE database_id IN (11,12,14,15) ORDER BY database_id;'
 $r.retained_before=Read-Baseline $retainedSql
 if($r.retained_before.Count -ne 4 -or $r.retained_before[0].name -cne 'K98_P025_D5e_Cost_20261115' -or $r.retained_before[1].name -cne 'ROK_TRACKER' -or $r.retained_before[2].source_database_id -ne 11 -or $r.retained_before[3].source_database_id -ne 12){throw 'Preserved fixtures/snapshots differ'}
 $header=Read-Baseline 'RESTORE HEADERONLY FROM DISK=@backup;' @{backup=$backup}
 if($header.Count -ne 1 -or [string]$header[0].BackupSetGUID -cne '29230229-d4fa-4a70-9227-176ae2fe8155' -or $header[0].DatabaseName -cne 'ROK_TRACKER' -or $header[0].BackupType -ne 1 -or $header[0].IsDamaged -or -not $header[0].HasBackupChecksums){throw 'Exact genuine full backup header required'}
 $r.backup=[ordered]@{path=$backup;bytes=$file.Length;backup_set_guid=[string]$header[0].BackupSetGUID;checksums=$header[0].HasBackupChecksums}
 Invoke-LongBaseline 'verify existing backup checksums' 'RESTORE VERIFYONLY FROM DISK=@backup WITH FILE=1,CHECKSUM,STOP_ON_ERROR;' @{backup=$backup} 90
 if($null -ne $r.cleanup_failure){throw 'Observation cleanup remains unconfirmed'}
 [void][IO.Directory]::CreateDirectory($directory)
 # Only this fresh name and two vacant paths can be written; no REPLACE, rename,
 # source fixture mutation, migration fabrication, login enable or business replay.
 Invoke-LongBaseline 'restore fresh restricted baseline' ("RESTORE DATABASE ["+$DatabaseName+"] FROM DISK=@backup WITH FILE=1,MOVE N'ROK_TRACKER' TO @data,MOVE N'ROK_TRACKER_log' TO @log,RECOVERY,RESTRICTED_USER,CHECKSUM,STOP_ON_ERROR;") @{backup=$backup;data=$data;log=$log} 480
 $r.stage='observe genuine baseline history'
 $r.database_rows=Read-Baseline 'SELECT name,database_id,create_date,state_desc,user_access_desc,is_broker_enabled FROM sys.databases WHERE name=@name;' @{name=$DatabaseName}
 if($r.database_rows.Count -ne 1 -or $r.database_rows[0].database_id -le 15 -or $r.database_rows[0].state_desc -cne 'ONLINE' -or $r.database_rows[0].user_access_desc -cne 'RESTRICTED_USER' -or $r.database_rows[0].is_broker_enabled){throw 'Fresh restored isolation differs'}
 $r.files=Read-Baseline 'SELECT file_id,name,physical_name,CONVERT(bigint,size)*8192 AS bytes FROM sys.master_files WHERE database_id=DB_ID(@name) ORDER BY file_id;' @{name=$DatabaseName}
 if($r.files.Count -ne 2 -or $r.files[0].physical_name -cne $data -or $r.files[1].physical_name -cne $log -or $r.files[0].bytes -ne 18239979520 -or $r.files[1].bytes -ne 68719476736){throw 'Fresh file ownership differs'}
 $r.history=Read-Baseline ('SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM ['+$DatabaseName+'].dbo.SchemaMigrationHistory ORDER BY MigrationId;')
 $r.observer_objects=Read-Baseline ('SELECT name,type_desc FROM ['+$DatabaseName+'].sys.objects WHERE name LIKE N''%P02%Observation%'' OR name=N''P02ObservationGeneration'';')
 if($r.observer_objects.Count){throw 'Genuine predecessor unexpectedly contains observer installation'}
 $r.retained_after=Read-Baseline $retainedSql
 if(($r.retained_after|ConvertTo-Json -Compress) -cne ($r.retained_before|ConvertTo-Json -Compress)){throw 'Retained fixture identity changed'}
 $r.lab_login=Read-Baseline "SELECT name,is_disabled FROM sys.sql_logins WHERE name=N'S11_ExportApplication_P02ObserverQual';"
 if($r.lab_login.Count -ne 1 -or -not $r.lab_login[0].is_disabled){throw 'Retained lab login must remain disabled'}
 $r.storage.free_after=(Get-Volume -DriveLetter Q).SizeRemaining
 $r.outcome='passed'
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}}
finally{
 if($r.execution_settled -and $null -ne $connection){try{if($null -ne $command){$command.Dispose()};$connection.Close();$connection.Dispose();$r.connections_closed++}catch{$r.cleanup_failure=$_.Exception.GetType().FullName;$r.outcome='failed'}}
 if(-not $r.execution_settled -or $null -ne $r.cleanup_failure){$global:P02FreshBaselineHeld=@{connection=$connection;command=$command;pending=$pending;receipt=$r}}else{$global:P02FreshBaselineHeld=@{settled=$true;receipt=$r}}
 $r.finished=[DateTime]::UtcNow.ToString('o')
}
$r|ConvertTo-Json -Depth 24 -Compress
