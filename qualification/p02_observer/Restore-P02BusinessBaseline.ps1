#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$PacketRoot,[Parameter(Mandatory=$true)][string]$StorageSHA256)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$m=Get-Content -LiteralPath (Join-Path $PacketRoot 'manifest.json') -Raw|ConvertFrom-Json
if($env:COMPUTERNAME -cne 'MINI_AMD' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ine 'MINI_AMD\K98LabAdmin' -or $m.purpose -cne 'fresh-business-baseline-restore' -or $m.production_eligible -ne $false -or $m.vm_id -cne '2ac1b401-7076-4965-af71-de36ee0f9f9c' -or $PacketRoot -cne $m.guest_directory -or $m.fresh_database -cnotmatch '^K98_P02Business_[0-9]{17}$'){throw 'Exact isolated restore packet required'}
foreach($item in $m.files.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $PacketRoot $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.Value){throw 'Sealed restore member differs'}}
if($StorageSHA256 -cnotmatch '^[0-9a-f]{64}$' -or (Get-FileHash -LiteralPath (Join-Path $PacketRoot 'storage-receipt.json') -Algorithm SHA256).Hash.ToLowerInvariant() -cne $StorageSHA256){throw 'Exact acknowledged new storage required'}
$storage=Get-Content -LiteralPath (Join-Path $PacketRoot 'storage-receipt.json') -Raw|ConvertFrom-Json
if($storage.outcome -cne 'passed' -or $storage.first_failure -or $storage.new_disk.bytes -ne 128GB -or $storage.directory -cne $m.data_directory -or $m.data_directory -cne ('R:\'+$m.fresh_database)){throw 'Fresh private storage binding differs'}
$priorPath=Join-Path $PacketRoot 'evidence\business-preflight.json'
if((Get-FileHash -LiteralPath $priorPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne 'd5b01fe1a785fdb8b47cde510a16a252cfeb62120b63783e234f0889ee3c5f59'){throw 'Exact completed preflight required'}
$prior=Get-Content -LiteralPath $priorPath -Raw|ConvertFrom-Json
$installation=Get-Content -LiteralPath (Join-Path $PacketRoot 'evidence\observer-installation.json') -Raw|ConvertFrom-Json
$receiptPath=Join-Path $PacketRoot 'guest-receipt.json'
if((Test-Path -LiteralPath $receiptPath) -or (Get-Variable P02BusinessRestoreHeld -Scope Global -ErrorAction SilentlyContinue)){throw 'Prior restore custody or receipt exists; do not replay'}
$r=[ordered]@{schema='p02-business-baseline-restore/1';outcome='running';stage='preserve original state before restore';started=[datetime]::UtcNow.ToString('o');database=$m.fresh_database;storage_sha256=$StorageSHA256;actions=@();first_failure=$null;cleanup_failure=$null;execution_settled=$true;connections_closed=0;preservation_connections_closed=0;restore_committed=$false;fresh_owner_committed=$false;production_operations=0;business_operations=0;claim_releases=0;migrations=0;original_setup_replayed=$false;release_accepted=$false}
$owner=@{connection=$null;command=$null;pending=$null;process=$null;reader=$null;read_command=$null}
$journal=@{number=0}
$backup='Q:\P02Release\observer-release-20261120194240117\db16-before-observer.bak'
$data=Join-Path $m.data_directory 'baseline.mdf'
$log=Join-Path $m.data_directory 'baseline_log.ldf'
function Write-NewRestore([string]$Path,[object]$Value){
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 24));$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function Save-Restore {$journal.number++;if($journal.number -gt 20){throw 'Restore stage limit'};Write-NewRestore (Join-Path $PacketRoot ('restore-stage-'+$journal.number+'.json')) $r}
function Assert-BackupFile {
 $file=Get-Item -LiteralPath $backup -Force
 $epoch=[datetime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)
 $modified=([long]$file.LastWriteTimeUtc.Ticks-$epoch.Ticks)*100
 if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -ne $prior.fixture_preflight.file_before.bytes -or $modified -ne [long]$prior.fixture_preflight.file_before.modified_ns){throw 'Exact retained backup file changed'}
}
function Assert-Agent {
 $agent=@(Get-CimInstance Win32_Service -Filter "Name='SQLSERVERAGENT'")
 if($agent.Count -ne 1 -or $agent[0].State -cne 'Stopped' -or $agent[0].StartMode -cne 'Disabled'){throw 'SQL Agent must remain stopped and disabled'}
}
function Invoke-Preservation([string]$Phase){
 if($Phase -cnotin @('before','after')){throw 'Exact preservation phase required'}
 $r.stage='preserve original state '+$Phase;Save-Restore
 $entry=Join-Path $PacketRoot 'qualification\p02_observer\business_restore_read.py'
 $arguments='-I -S -B "'+$entry+'" '+$Phase
 $owner.process=Start-Process -FilePath 'C:\Program Files\Python311\python.exe' -ArgumentList $arguments -WorkingDirectory $PacketRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PacketRoot ($Phase+'.stdout.txt')) -RedirectStandardError (Join-Path $PacketRoot ($Phase+'.stderr.txt'))
 $handle=$owner.process.Handle;$r.execution_settled=$false
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $owner.process.WaitForExit(1000) -and $watch.Elapsed.TotalSeconds -lt 150){}
 if(-not $owner.process.HasExited){throw 'Preservation child remains owned; retain original process'}
 $owner.process.WaitForExit();$code=$owner.process.ExitCode;$owner.process.Dispose();$owner.process=$null;$r.execution_settled=$true
 $file=Join-Path (Join-Path $PacketRoot $Phase) 'receipt.json'
 if($code -ne 0 -or -not (Test-Path -LiteralPath $file)){throw 'Preservation reader failed; retain its original evidence'}
 $result=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
 if($result.outcome -cne 'passed' -or $result.first_failure -or $result.cleanup_failures.Count -ne 0 -or $result.connections_closed -ne 1 -or $result.physical_custody_retained){throw 'Original-state reader did not settle successfully'}
 $r.preservation_connections_closed++
 $r[$Phase+'_preservation']=[ordered]@{path=$file;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant();outcome=$result.outcome}
 Save-Restore
}
function Read-Restore([string]$Sql,[hashtable]$Values=@{}){
 if($null -ne $owner.reader -or $null -ne $owner.read_command){throw 'Prior read cleanup remains unconfirmed'}
 $cmd=$owner.connection.CreateCommand();$owner.read_command=$cmd;$cmd.CommandText=$Sql;$cmd.CommandTimeout=5;$reader=$null;$first=$null
 try{
  foreach($key in $Values.Keys){[void]$cmd.Parameters.AddWithValue('@'+$key,$Values[$key])}
  $reader=$cmd.ExecuteReader();$owner.reader=$reader;$rows=[Collections.Generic.List[object]]::new()
  do{while($reader.Read()){
   if($rows.Count -ge 256){throw 'Restore observation row limit'}
   $row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$row[$reader.GetName($i)]=if($reader.IsDBNull($i)){$null}else{$reader.GetValue($i)}}
   $rows.Add([pscustomobject]$row)
  }}while($reader.NextResult())
  return ,$rows.ToArray()
 }catch{$first=$_;throw}
 finally{try{if($null -ne $reader){$reader.Dispose();$owner.reader=$null};$cmd.Dispose();$owner.read_command=$null}catch{$r.cleanup_failure=$_.Exception.GetType().FullName;if($null -eq $first){throw}}}
}
function Invoke-OwnedRestore([string]$Label,[string]$Sql,[hashtable]$Values,[int]$Seconds){
 if($null -ne $r.cleanup_failure -or -not $r.execution_settled -or $null -ne $owner.command -or $null -ne $owner.pending){throw 'Prior physical command has not settled'}
 $r.stage=$Label;$r.actions+=@([ordered]@{operation=$Label;acknowledged=$false});Save-Restore
 $owner.command=$owner.connection.CreateCommand();$owner.command.CommandText=$Sql;$owner.command.CommandTimeout=0
 foreach($key in $Values.Keys){[void]$owner.command.Parameters.AddWithValue('@'+$key,$Values[$key])}
 $r.execution_settled=$false
 $owner.pending=$owner.command.BeginExecuteNonQuery()
 $global:P02BusinessRestoreHeld=@{owner=$owner;receipt=$r}
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $owner.pending.IsCompleted -and $watch.Elapsed.TotalSeconds -lt $Seconds){$null=$owner.pending.AsyncWaitHandle.WaitOne(1000)}
 if(-not $owner.pending.IsCompleted){throw 'Native operation still pending; retain original handles without cancellation or replay'}
 try{$null=$owner.command.EndExecuteNonQuery($owner.pending)}finally{$r.execution_settled=$true}
 $r.actions[-1].acknowledged=$true;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds
 $owner.pending.AsyncWaitHandle.Dispose();$owner.command.Dispose();$owner.command=$null;$owner.pending=$null
 Save-Restore
}
function Close-Restore {
 if($null -ne $owner.reader){$owner.reader.Dispose();$owner.reader=$null}
 if($null -ne $owner.read_command){$owner.read_command.Dispose();$owner.read_command=$null}
 if($null -ne $owner.connection){$owner.connection.Close();$owner.connection.Dispose();$owner.connection=$null;$r.connections_closed++}
}
function Assert-History($Actual,$Expected){
 if(@($Actual).Count -ne 105 -or @($Expected).Count -ne 105){throw 'Exact 105 genuine predecessor migrations required'}
 for($i=0;$i -lt 105;$i++){
  foreach($key in @('MigrationId','ChecksumSha256','GitCommit','Status')){if([string]$Actual[$i].$key -cne [string]$Expected[$i].$key){throw ('Genuine history changed: '+$key)}}
  if(([guid]$Actual[$i].DeploymentId).ToString() -cne ([guid]$Expected[$i].DeploymentId).ToString()){throw 'Genuine deployment identity changed'}
 }
}
Save-Restore
try{
 Assert-Agent
 $partition=Get-Partition -DriveLetter R;$disk=Get-Disk -Number $partition.DiskNumber;$volume=Get-Volume -DriveLetter R
 if($disk.UniqueId -cne $storage.new_disk.unique_id -or [string]$partition.Guid -cne $storage.partition.guid -or $volume.UniqueId -cne $storage.volume.unique_id -or $volume.FileSystemLabel -cne $m.volume_label -or $volume.SizeRemaining -lt ($prior.fixture_preflight.assessment.required_allocated_bytes+20GB)){throw 'Exact new storage or restore headroom differs'}
 foreach($path in @($m.data_directory,$data,$log)){
  if($path -eq $m.data_directory){$item=Get-Item -LiteralPath $path -Force;if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Ordinary fresh directory required'}}
  elseif(Test-Path -LiteralPath $path){throw 'Fresh SQL file path already exists'}
 }
 Assert-BackupFile
 Invoke-Preservation 'before'
 $owner.connection=[Data.SqlClient.SqlConnection]::new('Data Source=lpc:localhost;Initial Catalog=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=3;Pooling=False;Asynchronous Processing=True;Application Name=P02BusinessBaseline')
 $owner.connection.Open()
 $identity=Read-Restore "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS product_version,ORIGINAL_LOGIN() AS login_name,IS_SRVROLEMEMBER('sysadmin') AS administrator,DB_NAME() AS database_name;"
 if($identity.Count -ne 1 -or $identity[0].server_name -cne 'MINI_AMD' -or $identity[0].product_version -cne '16.0.1220.3' -or $identity[0].login_name -ine 'MINI_AMD\K98LabAdmin' -or $identity[0].administrator -ne 1 -or $identity[0].database_name -cne 'master'){throw 'Exact isolated SQL restore identity required'}
 if((Read-Restore 'SELECT database_id FROM sys.databases WHERE name=@name;' @{name=$m.fresh_database}).Count){throw 'Fresh database name already exists'}
 $databasesSql='SELECT database_id,name,create_date,state_desc,source_database_id,user_access_desc,is_read_only FROM sys.databases ORDER BY database_id;'
 $r.databases_before=Read-Restore $databasesSql
 $header=Read-Restore 'RESTORE HEADERONLY FROM DISK=@backup;' @{backup=$backup}
 if($header.Count -ne 1 -or ([guid]$header[0].BackupSetGUID).ToString() -cne '3ca90f9e-200b-4100-bfcb-d2edf7b09a87' -or $header[0].DatabaseName -cne 'ROK_TRACKER' -or $header[0].BackupType -ne 1 -or $header[0].IsDamaged -or -not $header[0].HasBackupChecksums){throw 'Exact retained full backup required'}
 Invoke-OwnedRestore 'verify genuine backup checksums' 'RESTORE VERIFYONLY FROM DISK=@backup WITH FILE=1,CHECKSUM,STOP_ON_ERROR;' @{backup=$backup} 120
 Assert-BackupFile
 $r.restore_committed=$null
 Invoke-OwnedRestore 'restore one fresh restricted database' ("RESTORE DATABASE ["+$m.fresh_database+"] FROM DISK=@backup WITH FILE=1,MOVE N'ROK_TRACKER' TO @data,MOVE N'ROK_TRACKER_log' TO @log,RECOVERY,RESTRICTED_USER,CHECKSUM,STOP_ON_ERROR;") @{backup=$backup;data=$data;log=$log} 600
 $r.restore_committed=$true;Save-Restore
 $r.stage='verify fresh restored database and history'
 $r.database=Read-Restore 'SELECT name,database_id,create_date,state_desc,user_access_desc,is_broker_enabled,source_database_id FROM sys.databases WHERE name=@name;' @{name=$m.fresh_database}
 if($r.database.Count -ne 1 -or $r.database[0].database_id -le 4 -or $r.database[0].database_id -in @($r.databases_before.database_id) -or $r.database[0].state_desc -cne 'ONLINE' -or $r.database[0].user_access_desc -cne 'RESTRICTED_USER' -or $r.database[0].is_broker_enabled -or $null -ne $r.database[0].source_database_id){throw 'Fresh restricted database acknowledgement differs'}
 $r.files=Read-Restore 'SELECT file_id,name,physical_name,CONVERT(bigint,size)*8192 AS bytes FROM sys.master_files WHERE database_id=DB_ID(@name) ORDER BY file_id;' @{name=$m.fresh_database}
 if($r.files.Count -ne 2 -or $r.files[0].physical_name -cne $data -or $r.files[1].physical_name -cne $log -or $r.files[0].bytes -ne 18239979520 -or $r.files[1].bytes -ne 68719476736){throw 'Fresh restored files differ'}
 $db='['+$m.fresh_database+']'
 $r.history=Read-Restore ('SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM '+$db+'.dbo.SchemaMigrationHistory ORDER BY MigrationId;')
 Assert-History $r.history $installation.before.history
 $r.observer_objects=Read-Restore ('SELECT name,type_desc FROM '+$db+'.sys.objects WHERE name LIKE N''%P02%Observation%'' OR name=N''P02ObservationGeneration'';')
 if($r.observer_objects.Count){throw 'Pre-observer baseline unexpectedly contains observer objects'}
 $r.resource=Read-Restore ('SELECT ResourceKey,ActiveJobID,ActivePreparationID,ActiveOutputOperationID,OwnerID,BlockedReason FROM '+$db+'.dbo.ExportResource WHERE ResourceKey=N''sql_snapshot:legacy_outputs'';')
 if($r.resource.Count -ne 1){throw 'Fresh global resource missing'}
 foreach($key in @('ActiveJobID','ActivePreparationID','ActiveOutputOperationID','OwnerID','BlockedReason')){if($null -ne $r.resource[0].$key){throw 'Fresh baseline has existing ownership; preserve it without release'}}
 $claim=Read-Restore ('SELECT COUNT_BIG(*) AS matches FROM '+$db+'.dbo.ExportPreparation WHERE PreparationID=''6eafa515-0655-4091-a168-27cfe498cd8d'';')
 if($claim.Count -ne 1 -or $claim[0].matches -ne 0){throw 'Original failed preparation was copied; preserve it'}
 $r.fresh_owner_committed=$null
 Invoke-OwnedRestore 'bind only fresh database dbo owner' ('ALTER AUTHORIZATION ON DATABASE::'+$db+' TO [MINI_AMD\K98LabAdmin];') @{} 15
 $r.fresh_owner_committed=$true
 $r.owner=Read-Restore ('SELECT SUSER_SNAME(d.owner_sid) AS owner_login,LOWER(CONVERT(varchar(170),d.owner_sid,2)) AS owner_sid,LOWER(CONVERT(varchar(170),p.sid,2)) AS dbo_sid FROM sys.databases d CROSS JOIN '+$db+'.sys.database_principals p WHERE d.name=@name AND p.principal_id=1;') @{name=$m.fresh_database}
 if($r.owner.Count -ne 1 -or $r.owner[0].owner_login -ine 'MINI_AMD\K98LabAdmin' -or $r.owner[0].owner_sid -cne '010500000000000515000000cfc07a55bb14094237a8f0cfe9030000' -or $r.owner[0].dbo_sid -cne $r.owner[0].owner_sid){throw 'Fresh owner mapping differs'}
 $r.databases_after=Read-Restore $databasesSql
 $retained=@($r.databases_after|Where-Object {$_.name -cne $m.fresh_database})
 if(($retained|ConvertTo-Json -Depth 8 -Compress) -cne ($r.databases_before|ConvertTo-Json -Depth 8 -Compress)){throw 'Existing database identities changed'}
 Assert-BackupFile
 Close-Restore
 Invoke-Preservation 'after'
 Assert-Agent
 $r.free_after=(Get-Volume -DriveLetter R).SizeRemaining
 if($r.free_after -lt 20GB){throw 'Fresh fixture recovery headroom insufficient'}
 $r.outcome='passed';$r.stage='fresh restricted baseline restored; completed original setup and claim preserved';Save-Restore
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}}
finally{
 if($r.execution_settled){try{if($null -ne $owner.pending){$owner.pending.AsyncWaitHandle.Dispose();$owner.pending=$null};if($null -ne $owner.command){$owner.command.Dispose();$owner.command=$null};Close-Restore}catch{$r.cleanup_failure=$_.Exception.GetType().FullName;$r.outcome='failed'}}
 $global:P02BusinessRestoreHeld=@{owner=$owner;receipt=$r;settled=($r.execution_settled -and -not $r.cleanup_failure -and $null -eq $owner.process)}
 $r.finished=[datetime]::UtcNow.ToString('o')
 Write-NewRestore $receiptPath $r
}
[pscustomobject]@{outcome=$r.outcome;receipt=$receiptPath;sha256=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()}
