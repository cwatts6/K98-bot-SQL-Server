#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$PacketRoot,[Parameter(Mandatory=$true)][string]$StorageSHA256)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$m=Get-Content -LiteralPath (Join-Path $PacketRoot 'manifest.json') -Raw|ConvertFrom-Json
$stamp=Split-Path -Leaf $PacketRoot
if($env:COMPUTERNAME -cne 'MINI_AMD' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ine 'MINI_AMD\K98LabAdmin' -or $m.purpose -cne 'p02-matching-cost-fixtures' -or $m.production_eligible -ne $false -or $m.vm_id -cne '2ac1b401-7076-4965-af71-de36ee0f9f9c' -or $PacketRoot -cne $m.guest_directory -or $PacketRoot -cnotmatch '^Q:\\P02Observer\\[0-9]{17}$' -or $m.databases.Count -ne 2 -or $m.databases[0] -cne ('K98_P02Cost_OFF_'+$stamp) -or $m.databases[1] -cne ('K98_P02Cost_ON_'+$stamp) -or $m.data_directory -cne ('S:\P02Cost_'+$stamp)){throw 'Exact isolated matching-restore packet required'}
foreach($item in $m.files.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $PacketRoot $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.Value){throw 'Sealed restore member differs'}}
if($StorageSHA256 -cnotmatch '^[0-9a-f]{64}$' -or (Get-FileHash -LiteralPath (Join-Path $PacketRoot 'storage-receipt.json') -Algorithm SHA256).Hash.ToLowerInvariant() -cne $StorageSHA256){throw 'Exact acknowledged new storage required'}
$storage=Get-Content -LiteralPath (Join-Path $PacketRoot 'storage-receipt.json') -Raw|ConvertFrom-Json
if($storage.outcome -cne 'passed' -or $storage.first_failure -or $storage.new_disk.bytes -ne 256GB -or $storage.directory -cne $m.data_directory){throw 'New cost storage binding differs'}
$baseline=Get-Content -LiteralPath (Join-Path $PacketRoot 'evidence/backup-baseline.json') -Raw|ConvertFrom-Json
$source='Q:\P02Observer\20261121193756509\receipt.json'
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -cne '5585c9148dd2b950eeae2c02dac333b6bfd1005a03e6a829dd0a1a24ded1bbf7' -or $baseline.source_receipt_sha256 -cne '5585c9148dd2b950eeae2c02dac333b6bfd1005a03e6a829dd0a1a24ded1bbf7'){throw 'Genuine pre-observer backup source changed'}
$receiptPath=Join-Path $PacketRoot 'guest-receipt.json'
if((Test-Path -LiteralPath $receiptPath) -or (Test-Path -LiteralPath (Join-Path $PacketRoot 'restore-stage-1.json')) -or (Get-Variable P02CostRestoreHeld -Scope Global -ErrorAction SilentlyContinue)){throw 'Prior cost restore custody exists; do not replay'}
$r=[ordered]@{schema='p02-cost-restore/1';outcome='running';stage='preserve original state';started=[datetime]::UtcNow.ToString('o');storage_sha256=$StorageSHA256;actions=@();fixtures=@();first_failure=$null;cleanup_failure=$null;execution_settled=$true;connections_closed=0;preservation_connections_closed=0;production_operations=0;business_operations=0;claim_releases=0;migrations=0;original_setup_replayed=$false;release_accepted=$false}
$owner=@{connection=$null;command=$null;pending=$null;process=$null;reader=$null;read_command=$null}
$journal=@{number=0}
$backup='Q:\P02Observer\20261121193756509\db18-before-observer.bak'
function Write-NewRestore([string]$Path,[object]$Value){
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 24));$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function Save-Restore {$journal.number++;if($journal.number -gt 40){throw 'Restore stage limit'};Write-NewRestore (Join-Path $PacketRoot ('restore-stage-'+$journal.number+'.json')) $r}
function Assert-BackupFile {
 $file=Get-Item -LiteralPath $backup -Force
 $epoch=[datetime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)
 $modified=([long]$file.LastWriteTimeUtc.Ticks-$epoch.Ticks)*100
 if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -ne $baseline.backup.file_before_verify.bytes -or $modified -ne [long]$baseline.backup.file_before_verify.modified_ns){throw 'Exact retained backup file changed'}
}
function Assert-Agent {
 $agent=@(Get-CimInstance Win32_Service -Filter "Name='SQLSERVERAGENT'")
 if($agent.Count -ne 1 -or $agent[0].State -cne 'Stopped' -or $agent[0].StartMode -cne 'Disabled'){throw 'SQL Agent must remain stopped and disabled'}
}
function Invoke-Preservation([string]$Phase){
 if($Phase -cnotin @('before','after')){throw 'Exact preservation phase required'}
 $r.stage='preserve original state '+$Phase;Save-Restore
 $entry=Join-Path $PacketRoot 'qualification\p02_observer\cost_fixture_state.py'
 $arguments='-I -S -B "'+$entry+'" '+$Phase
 if($Phase -ceq 'after'){$arguments+=' '+(Get-FileHash -LiteralPath (Join-Path $PacketRoot 'restore-bindings.json') -Algorithm SHA256).Hash.ToLowerInvariant()}
 $owner.process=Start-Process -FilePath 'C:\Program Files\Python311\python.exe' -ArgumentList $arguments -WorkingDirectory $PacketRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PacketRoot ($Phase+'.stdout.txt')) -RedirectStandardError (Join-Path $PacketRoot ($Phase+'.stderr.txt'))
 $handle=$owner.process.Handle;$r.execution_settled=$false
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $owner.process.WaitForExit(1000) -and $watch.Elapsed.TotalSeconds -lt 150){}
 if(-not $owner.process.HasExited){throw 'Preservation child remains owned; retain original process'}
 $owner.process.WaitForExit();$code=$owner.process.ExitCode;$owner.process.Dispose();$owner.process=$null;$r.execution_settled=$true
 $file=Join-Path (Join-Path $PacketRoot $Phase) 'receipt.json'
 if($code -ne 0 -or -not (Test-Path -LiteralPath $file)){throw 'Preservation reader failed; retain its original evidence'}
 $result=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
 if($result.outcome -cne 'passed' -or $result.first_failure -or $result.cleanup_failures.Count -ne 0 -or $result.admin_connections_closed -ne 6 -or $result.physical_custody_retained){throw 'Original-state reader did not settle successfully'}
 $r.preservation_connections_closed+=$result.admin_connections_closed
 $r[$Phase+'_preservation']=[ordered]@{path=$file;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant();outcome=$result.outcome}
 Save-Restore
}
function Read-Restore([string]$Sql,[hashtable]$Values=@{}){
 if($null -ne $owner.reader -or $null -ne $owner.read_command){throw 'Prior read cleanup remains unconfirmed'}
 $cmd=$owner.connection.CreateCommand();$owner.read_command=$cmd;$cmd.CommandText=$Sql;$cmd.CommandTimeout=15;$reader=$null;$first=$null
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
 $global:P02CostRestoreHeld=@{owner=$owner;receipt=$r}
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $owner.pending.IsCompleted -and $watch.Elapsed.TotalSeconds -lt $Seconds){$null=$owner.pending.AsyncWaitHandle.WaitOne(1000)}
 if(-not $owner.pending.IsCompleted){throw 'Native operation still pending; retain original handles without cancellation or replay'}
 try{$null=$owner.command.EndExecuteNonQuery($owner.pending)}finally{$r.execution_settled=$true}
 $r.actions[-1].acknowledged=$true;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds
 try{$owner.pending.AsyncWaitHandle.Dispose();$owner.pending=$null;$owner.command.Dispose();$owner.command=$null}catch{$r.cleanup_failure=$_.Exception.GetType().FullName;throw}
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
function Get-CostContentSql([string]$Source){
 if($Source -cne '@P02CostProbe' -and $Source -cnotmatch '^\[K98_P02Cost_(OFF|ON)_[0-9]{17}\]\.dbo\.\[(STATS_FOR_UPLOAD|EXCEL_FOR_KVK_16|KVKFinalReportHeader|ProcConfig|MaintenanceWork|MaintenanceKvkWork)\]$'){throw 'Exact cost content source required'}
 return ('SET NOCOUNT ON; DECLARE @rows bigint=(SELECT COUNT_BIG(*) FROM '+$Source+'); DECLARE @content nvarchar(max)=(SELECT j.doc FROM '+$Source+' t CROSS APPLY (SELECT t.* FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER) j(doc) ORDER BY j.doc COLLATE Latin1_General_100_BIN2 FOR JSON PATH); IF @rows=0 AND @content IS NULL SET @content=N''[]''; SELECT @rows AS rows,(SELECT COUNT_BIG(*) FROM OPENJSON(@content)) AS json_rows,ISJSON(@content) AS valid_json,DATALENGTH(@content) AS json_bytes,LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@content),2)) AS content_sha256;')
}
function Assert-CostContent($Facts){
 if($Facts.Count -ne 1 -or $Facts[0].rows -lt 0 -or $Facts[0].rows -ne $Facts[0].json_rows -or $Facts[0].valid_json -ne 1 -or $Facts[0].content_sha256 -cnotmatch '^[0-9a-f]{64}$' -or ($Facts[0].rows -eq 0 -and ($Facts[0].json_bytes -ne 4 -or $Facts[0].content_sha256 -cne '5ee9173b1b564e61afd2359a897c180b5ea83875a91a28537df4202aad4b3aa7')) -or ($Facts[0].rows -gt 0 -and $Facts[0].json_bytes -le 4)){throw 'Complete baseline rows and content digest unavailable'}
}
Save-Restore
try{
 Assert-Agent
 $partition=Get-Partition -DriveLetter S;$disk=Get-Disk -Number $partition.DiskNumber;$volume=Get-Volume -DriveLetter S
 if($disk.UniqueId -cne $storage.new_disk.unique_id -or [string]$partition.Guid -cne $storage.partition.guid -or $volume.UniqueId -cne $storage.volume.unique_id -or $volume.FileSystemLabel -cne $m.volume_label -or $volume.SizeRemaining -lt (2*86959456256+40GB)){throw 'Exact new storage or matching-restore headroom differs'}
 $item=Get-Item -LiteralPath $m.data_directory -Force
 if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or @(Get-ChildItem -LiteralPath $item.FullName -Force).Count){throw 'Empty ordinary new SQL directory required'}
 Assert-BackupFile
 Invoke-Preservation 'before'
 $owner.connection=[Data.SqlClient.SqlConnection]::new('Data Source=lpc:localhost;Initial Catalog=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=3;Pooling=False;Asynchronous Processing=True;Application Name=P02CostFixtures')
 $owner.connection.Open()
 $identity=Read-Restore "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS product_version,ORIGINAL_LOGIN() AS login_name,IS_SRVROLEMEMBER('sysadmin') AS administrator,DB_NAME() AS database_name;"
 if($identity.Count -ne 1 -or $identity[0].server_name -cne 'MINI_AMD' -or $identity[0].product_version -cne '16.0.1220.3' -or $identity[0].login_name -ine 'MINI_AMD\K98LabAdmin' -or $identity[0].administrator -ne 1 -or $identity[0].database_name -cne 'master'){throw 'Exact isolated SQL restore identity required'}
 $databasesSql='SELECT database_id,name,create_date,state_desc,source_database_id,user_access_desc,is_read_only FROM sys.databases ORDER BY database_id;'
 $r.databases_before=Read-Restore $databasesSql
 foreach($name in $m.databases){if((Read-Restore 'SELECT database_id FROM sys.databases WHERE name=@name;' @{name=$name}).Count){throw 'New database name exists; no replacement permitted'}}
 $header=Read-Restore 'RESTORE HEADERONLY FROM DISK=@backup;' @{backup=$backup}
 if($header.Count -ne 1 -or ([guid]$header[0].BackupSetGUID).ToString() -cne '43bd2747-96a6-4e16-a7a3-c708eda1f613' -or ([guid]$header[0].FamilyGUID).ToString() -cne 'c4de892e-fd68-46e4-ab63-245e74bfc07b' -or $header[0].DatabaseName -cne 'ROK_TRACKER' -or $header[0].BackupType -ne 1 -or $header[0].Position -ne 1 -or $header[0].IsDamaged -or -not $header[0].HasBackupChecksums -or -not $header[0].IsCopyOnly -or [string]$header[0].FirstLSN -cne '20265000304470400002' -or [string]$header[0].LastLSN -cne '20265000304472800001'){throw 'Exact genuine pre-observer full backup required'}
 $r.backup_header=$header
 Invoke-OwnedRestore 'verify genuine backup checksums once' 'RESTORE VERIFYONLY FROM DISK=@backup WITH FILE=1,CHECKSUM,STOP_ON_ERROR;' @{backup=$backup} 120
 Assert-BackupFile
 $bindings=@()
 foreach($label in @('OFF','ON')){
  $name='K98_P02Cost_'+$label+'_'+$stamp;$db='['+$name+']'
  $data=Join-Path $m.data_directory ($label+'.mdf');$log=Join-Path $m.data_directory ($label+'.ldf')
  if((Test-Path -LiteralPath $data) -or (Test-Path -LiteralPath $log) -or (Read-Restore 'SELECT database_id FROM sys.databases WHERE name=@name;' @{name=$name}).Count){throw 'New restore target is occupied; do not replay'}
  $fixture=[ordered]@{name=$name;restore_committed=$null;owner_committed=$false};$r.fixtures+=@($fixture)
  Invoke-OwnedRestore ('restore new restricted '+$label+' database') ('RESTORE DATABASE '+$db+" FROM DISK=@backup WITH FILE=1,MOVE N'ROK_TRACKER' TO @data,MOVE N'ROK_TRACKER_log' TO @log,RECOVERY,RESTRICTED_USER,CHECKSUM,STOP_ON_ERROR;") @{backup=$backup;data=$data;log=$log} 600
  $fixture.restore_committed=$true;Save-Restore
  $r.stage='verify restored '+$label+' identity and genuine history'
  $fixture.identity=Read-Restore 'SELECT d.name,d.database_id,d.create_date,d.state_desc,d.user_access_desc,d.is_broker_enabled,d.source_database_id,s.database_guid,s.family_guid FROM sys.databases d JOIN sys.database_recovery_status s ON s.database_id=d.database_id WHERE d.name=@name;' @{name=$name}
  if($fixture.identity.Count -ne 1 -or $fixture.identity[0].database_id -le 24 -or $fixture.identity[0].database_id -in @($r.databases_before.database_id) -or $fixture.identity[0].state_desc -cne 'ONLINE' -or $fixture.identity[0].user_access_desc -cne 'RESTRICTED_USER' -or $fixture.identity[0].is_broker_enabled -or $null -ne $fixture.identity[0].source_database_id -or ([guid]$fixture.identity[0].family_guid).ToString() -cne 'c4de892e-fd68-46e4-ab63-245e74bfc07b'){throw 'New restricted database acknowledgement differs'}
  $fixture.files=Read-Restore 'SELECT file_id,name,physical_name,CONVERT(bigint,size)*8192 AS bytes FROM sys.master_files WHERE database_id=DB_ID(@name) ORDER BY file_id;' @{name=$name}
  if($fixture.files.Count -ne 2 -or $fixture.files[0].physical_name -cne $data -or $fixture.files[1].physical_name -cne $log -or $fixture.files[0].bytes -ne 18239979520 -or $fixture.files[1].bytes -ne 68719476736){throw 'Restored file identity differs'}
  $fixture.history=Read-Restore ('SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM '+$db+'.dbo.SchemaMigrationHistory ORDER BY MigrationId;')
  Assert-History $fixture.history $baseline.history
  $fixture.observer_objects=Read-Restore ('SELECT name,type_desc FROM '+$db+'.sys.objects WHERE name LIKE N''%P02%Observation%'' OR name=N''P02ObservationGeneration'';')
  if($fixture.observer_objects.Count){throw 'Pre-observer baseline contains observer objects'}
  $fixture.resource=Read-Restore ('SELECT ResourceKey,ActiveJobID,ActivePreparationID,ActiveOutputOperationID,OwnerID,BlockedReason FROM '+$db+'.dbo.ExportResource WHERE ResourceKey=N''sql_snapshot:legacy_outputs'';')
  if($fixture.resource.Count -ne 1){throw 'New global resource missing'}
  foreach($key in @('ActiveJobID','ActivePreparationID','ActiveOutputOperationID','OwnerID','BlockedReason')){if($null -ne $fixture.resource[0].$key){throw 'Baseline contains existing ownership; preserve without release'}}
  $claim=Read-Restore ('SELECT COUNT_BIG(*) AS matches FROM '+$db+'.dbo.ExportPreparation WHERE PreparationID=''6eafa515-0655-4091-a168-27cfe498cd8d'';')
  if($claim.Count -ne 1 -or $claim[0].matches -ne 0){throw 'Original uncertain claim was copied; preserve it'}
  $fixture.owner_committed=$null
  Invoke-OwnedRestore ('bind only new '+$label+' database owner') ('ALTER AUTHORIZATION ON DATABASE::'+$db+' TO [MINI_AMD\K98LabAdmin];') @{} 15
  $fixture.owner_committed=$true
  $fixture.owner=Read-Restore ('SELECT SUSER_SNAME(d.owner_sid) AS owner_login,LOWER(CONVERT(varchar(170),d.owner_sid,2)) AS owner_sid,LOWER(CONVERT(varchar(170),p.sid,2)) AS dbo_sid FROM sys.databases d CROSS JOIN '+$db+'.sys.database_principals p WHERE d.name=@name AND p.principal_id=1;') @{name=$name}
  if($fixture.owner.Count -ne 1 -or $fixture.owner[0].owner_login -ine 'MINI_AMD\K98LabAdmin' -or $fixture.owner[0].owner_sid -cne '010500000000000515000000cfc07a55bb14094237a8f0cfe9030000' -or $fixture.owner[0].dbo_sid -cne $fixture.owner[0].owner_sid){throw 'New owner mapping differs'}
  $fixture.content=@()
  foreach($table in @('STATS_FOR_UPLOAD','EXCEL_FOR_KVK_16','KVKFinalReportHeader','ProcConfig','MaintenanceWork','MaintenanceKvkWork')){
   $r.stage='read complete '+$label+' '+$table+' content'
   $sql=Get-CostContentSql ($db+'.dbo.['+$table+']')
   $facts=Read-Restore $sql
   $r.last_content_observation=[ordered]@{database=$name;table=$table;facts=$facts}
   Assert-CostContent $facts
   $fixture.content+=@([ordered]@{table=$table;rows=$facts[0].rows;content_sha256=$facts[0].content_sha256})
  }
  $bindings+=@([ordered]@{name=$name;database_id=$fixture.identity[0].database_id;database_guid=[string]$fixture.identity[0].database_guid;family_guid=[string]$fixture.identity[0].family_guid;data=$data;log=$log})
  Save-Restore
 }
 if(($r.fixtures[0].content|ConvertTo-Json -Depth 8 -Compress) -cne ($r.fixtures[1].content|ConvertTo-Json -Depth 8 -Compress)){throw 'The two complete baseline contents differ'}
 $r.matching_content=$true
 Write-NewRestore (Join-Path $PacketRoot 'restore-bindings.json') ([ordered]@{fixtures=$bindings})
 $r.databases_after=Read-Restore $databasesSql
 $retained=@($r.databases_after|Where-Object {$_.name -cnotin $m.databases})
 if(($retained|ConvertTo-Json -Depth 8 -Compress) -cne ($r.databases_before|ConvertTo-Json -Depth 8 -Compress)){throw 'Existing database identities changed'}
 Assert-BackupFile
 Close-Restore
 Invoke-Preservation 'after'
 Assert-Agent
 $r.free_after=(Get-Volume -DriveLetter S).SizeRemaining
 if($r.free_after -lt 40GB){throw 'Matching fixture recovery headroom insufficient'}
 $r.outcome='passed';$r.stage='two matching restricted baselines ready; original work and claim preserved';Save-Restore
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}}
finally{
 if($r.execution_settled -and -not $r.cleanup_failure){try{if($null -ne $owner.pending){$owner.pending.AsyncWaitHandle.Dispose();$owner.pending=$null};if($null -ne $owner.command){$owner.command.Dispose();$owner.command=$null};Close-Restore}catch{$r.cleanup_failure=$_.Exception.GetType().FullName;$r.outcome='failed'}}
 $global:P02CostRestoreHeld=@{owner=$owner;receipt=$r;settled=($r.execution_settled -and -not $r.cleanup_failure -and $null -eq $owner.process)}
 $r.finished=[datetime]::UtcNow.ToString('o')
 Write-NewRestore $receiptPath $r
}
[pscustomobject]@{outcome=$r.outcome;receipt=$receiptPath;sha256=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()}
