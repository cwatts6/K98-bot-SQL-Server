#requires -Version 5.1
# Local observer coordinator qualification after the genuine D4 commit.
param([Parameter(Mandatory=$true)][string]$PacketRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$plan=Get-Content -LiteralPath (Join-Path $PacketRoot 'plan.json') -Raw|ConvertFrom-Json
$sourceCommit='2075ca6eb367af53fdae6ecd92b23efa69018f5a'
$profile='cd3bcb8c1f7303b8b45d5dc2b3d118aad70002f684ae847ffaf400c056bc1692'
$migration='20261120_001_p02_catalogue_observer'
$names=@('Invoke-P02ObserverCoordinator.ps1','Test-P02ObserverCoordinator.ps1','prior-guest-receipt.json','candidate-source.json','sql-package.zip')
if($env:COMPUTERNAME -cne 'MINI_AMD' -or $plan.schema -cne 'p02-observer-coordinator/1' -or $plan.production_eligible -ne $false -or $plan.vm_id -cne '2ac1b401-7076-4965-af71-de36ee0f9f9c' -or $PacketRoot -cne $plan.guest_directory -or $PacketRoot -cnotmatch '^Q:\\P02Release\\observer-release-[0-9]{17}$' -or $plan.sql_commit -cne $sourceCommit -or ([guid]$plan.release_id).ToString() -cne $plan.release_id){throw 'Exact isolated observer qualification plan required'}
if(@($plan.files.PSObject.Properties).Count -ne $names.Count){throw 'Exact observer packet inventory required'}
foreach($item in $plan.files.PSObject.Properties){if($item.Name -cnotin $names -or (Get-FileHash -LiteralPath (Join-Path $PacketRoot $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.Value){throw 'Sealed observer member differs'}}
if($plan.prior_directory -cne 'Q:\P02Release\msdb-d4-20261120191217339' -or $plan.files.'prior-guest-receipt.json' -cne '871434e20edf52807a3ac662f6bba2116a477dc6cbcae2cf1e804aa257117637'){throw 'Exact successful D4 receipt required'}
$previous=Get-Content -LiteralPath (Join-Path $PacketRoot 'prior-guest-receipt.json') -Raw|ConvertFrom-Json
function Assert-PriorD4($Held,$Previous) {
 if($Previous.schema -cne 'p02-authentic-msdb-d4-guest/1' -or $Previous.outcome -cne 'passed' -or -not $Previous.d4_committed -or -not $Previous.authentic_dependency_verified -or -not $Previous.restored -or $Previous.restore_replayed -or -not $Previous.execution_settled -or $Previous.connections_closed -ne 2 -or $Previous.first_failure -or $Previous.cleanup_failure -or $Previous.after.history.Count -ne 105){throw 'Completed authentic restore and genuine D4 required'}
 if($Previous.d4_receipt.DeploymentId -cne '3261c5f8-4b3f-41b2-9144-11bb561df4a0' -or $Previous.d4_receipt.Status -cne 'Applied' -or $Previous.d4_receipt.deployment_status -cne 'Succeeded'){throw 'Exact committed D4 identity required'}
 if($null -eq $Held -or $Held -isnot [hashtable] -or -not $Held.settled){throw 'Previous D4 custody is unresolved'}
 foreach($name in @('connection','command','pending','process')){if(-not $Held.ContainsKey($name) -or $null -ne $Held[$name]){throw 'Previous D4 physical handles remain'}}
 $native=$Held.receipt|ConvertTo-Json -Depth 24 -Compress|ConvertFrom-Json|ConvertTo-Json -Depth 24 -Compress
 if($native -cne ($Previous|ConvertTo-Json -Depth 24 -Compress)){throw 'Previous native D4 receipt differs'}
}
$held=Get-Variable P02MsdbD4Held -Scope Global -ErrorAction SilentlyContinue
if($null -eq $held){throw 'Completed D4 native owner missing'}
Assert-PriorD4 $held.Value $previous
$disk=Get-Content -LiteralPath (Join-Path $plan.prior_directory 'guest-receipt.json') -Raw|ConvertFrom-Json
if(($disk|ConvertTo-Json -Depth 24 -Compress) -cne ($previous|ConvertTo-Json -Depth 24 -Compress)){throw 'Previous guest D4 receipt differs'}
if(Get-Variable P02ObserverReleaseHeld -Scope Global -ErrorAction SilentlyContinue){throw 'Observer attempt already retained; inspect it without replay'}
$expected=$previous.after
$receiptPath=Join-Path $PacketRoot 'guest-receipt.json'
if(Test-Path -LiteralPath $receiptPath){throw 'Observer attempt already exists; preserve evidence'}
$r=[ordered]@{schema='p02-observer-coordinator-guest/1';outcome='running';stage='preflight';started=[datetime]::UtcNow.ToString('o');actions=@();execution_settled=$true;connections_closed=0;builtin_telemetry_observations=@();first_failure=$null;cleanup_failure=$null;production_operations=0;business_operations=0;restore_replayed=$false;d4_replayed=$false;observer_committed=$false;sql_commit=$sourceCommit;release_id=$plan.release_id;prior_directory=$plan.prior_directory}
$owner=@{connection=$null;command=$null;pending=$null;child=$null}
$repo=Join-Path $PacketRoot 'sql-package'
function Save-Receipt {[IO.File]::WriteAllText($receiptPath,($r|ConvertTo-Json -Depth 24),[Text.UTF8Encoding]::new($false))}

function Read-State([string]$Sql,[hashtable]$Values=@{}){
 $cmd=$owner.connection.CreateCommand();$cmd.CommandText=$Sql;$cmd.CommandTimeout=5;$reader=$null;$first=$null
 foreach($key in $Values.Keys){[void]$cmd.Parameters.AddWithValue('@'+$key,$Values[$key])}
 try{
  $reader=$cmd.ExecuteReader();$rows=[Collections.Generic.List[object]]::new()
  do{while($reader.Read()){
   if($rows.Count -ge 256){throw 'Bounded SQL update read exceeded'}
   $row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$row[$reader.GetName($i)]=if($reader.IsDBNull($i)){$null}else{$reader.GetValue($i)}}
   $rows.Add([pscustomobject]$row)
  }}while($reader.NextResult())
  return ,$rows.ToArray()
 }catch{$first=$_;throw}finally{try{if($null -ne $reader){$reader.Dispose()};$cmd.Dispose()}catch{$r.cleanup_failure=$_.Exception.Message;if($null -eq $first){throw}}}
}


function Open-Lab {
 $owner.connection=[Data.SqlClient.SqlConnection]::new('Data Source=lpc:localhost;Initial Catalog=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=3;Pooling=False;Asynchronous Processing=True;Application Name=P02ObserverCoordinator')
 $owner.connection.Open()
 $id=Read-State "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS product_version,ORIGINAL_LOGIN() AS login_name,IS_SRVROLEMEMBER('sysadmin') AS administrator;"
 if($id.Count -ne 1 -or $id[0].server_name -cne 'MINI_AMD' -or $id[0].login_name -ine 'MINI_AMD\K98LabAdmin' -or $id[0].administrator -ne 1){throw 'Exact isolated SQL identity required'}
 return $id[0]
}


function Close-Lab {
 if($null -ne $owner.connection){$owner.connection.Close();$owner.connection.Dispose();$owner.connection=$null;$r.connections_closed++}
}


function Read-Agent {return @(Get-CimInstance Win32_Service -Filter "Name='SQLSERVERAGENT'"|Select-Object Name,State,StartMode)}


function Assert-Agent([bool]$Disabled) {
 $agent=@(Read-Agent)
 if($agent.Count -ne 1 -or $agent[0].State -cne 'Stopped' -or ($Disabled -and $agent[0].StartMode -cne 'Disabled')){throw 'SQL Agent must remain stopped with the required start mode'}
 return $agent[0]
}


function Pending-Reboot {
 $paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
 $pending=@($paths|Where-Object {Test-Path -LiteralPath $_})
 $rename=Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
 if($null -ne $rename -and @($rename.PendingFileRenameOperations|Where-Object {$_}).Count){$pending+=@('PendingFileRenameOperations')}
 return ,$pending
}


function Date-Text($Value) {
 # SqlClient's catalogue datetime is Unspecified (local clock). Windows
 # PowerShell JSON persists it as UTC milliseconds and reads it back as Utc.
 # Compare that same UTC identity before rounding; October's daylight-saving
 # offset must not be mistaken for an actual database incarnation change.
 if($Value -is [datetime]){$Value=$Value.ToUniversalTime()}
 elseif([string]$Value -cmatch '^/Date\((-?[0-9]+)\)/$'){
  $Value=[DateTimeOffset]::FromUnixTimeMilliseconds([long]$Matches[1]).UtcDateTime
 }else{throw 'Typed or retained native date required'}
 $ticks=$Value.Ticks;$part=$ticks%10000;$ticks-=$part;if($part -ge 5000){$ticks+=10000}
 return ([datetime]::new($ticks,[DateTimeKind]::Utc)).ToString('yyyy-MM-ddTHH:mm:ss.fff',[Globalization.CultureInfo]::InvariantCulture)
}


function Assert-Rows($Actual,$Expected,[string[]]$Keys,[string[]]$Dates=@()) {
 if(@($Actual).Count -ne @($Expected).Count){throw 'Retained row count changed'}
 for($i=0;$i -lt @($Actual).Count;$i++){foreach($key in $Keys){
  if($key -cin $Dates){if((Date-Text $Actual[$i].$key) -cne (Date-Text $Expected[$i].$key)){throw ('Retained date changed: '+$key)}}
  elseif([string]$Actual[$i].$key -cne [string]$Expected[$i].$key){throw ('Retained value changed: '+$key)}
 }}
}


function Assert-NoBusinessSessions([object[]]$Sessions) {
 if($Sessions.Count -eq 0){return}
 # SQL's built-in CEIP connection is not an application owner. Bind its Windows
 # service process and original SQL identity; a program-name match is insufficient.
 $service=@(Get-CimInstance Win32_Service -Filter "Name='SQLTELEMETRY'"|Select-Object Name,State,StartName,ProcessId)
 $valid=$service.Count -eq 1 -and $service[0].Name -ceq 'SQLTELEMETRY' -and $service[0].State -ceq 'Running' -and $service[0].StartName -ieq 'NT SERVICE\SQLTELEMETRY' -and $service[0].ProcessId -gt 0
 if($Sessions.Count -eq 1 -and $valid){
  $item=$Sessions[0]
  $valid=$item.login_name -ieq 'NT SERVICE\SQLTELEMETRY' -and $item.original_login_name -ieq 'NT SERVICE\SQLTELEMETRY' -and $item.program_name -ceq 'SQLServerCEIP' -and $item.host_process_id -eq $service[0].ProcessId -and $item.status -ceq 'sleeping' -and $item.database_id -eq 1 -and $item.open_transaction_count -eq 0 -and $item.active_requests -eq 0 -and $item.non_master_locks -eq 0
 }else{$valid=$false}
 if(-not $valid){$r.other_sessions=$Sessions;throw 'Other SQL user sessions remain; no forced drain'}
 $r.builtin_telemetry_observations+=@([ordered]@{stage=$r.stage;service=$service[0];session=$Sessions[0]})
}


function Assert-Fixtures([bool]$AfterObserver=$false) {
 $databases=Read-State 'SELECT name,database_id,create_date,state_desc,user_access_desc,source_database_id,snapshot_isolation_state,is_read_committed_snapshot_on,is_broker_enabled FROM sys.databases WHERE database_id IN (11,12,14,15,16) ORDER BY database_id;'
 Assert-Rows $databases $expected.databases @('name','database_id','create_date','state_desc','user_access_desc','source_database_id','snapshot_isolation_state','is_read_committed_snapshot_on','is_broker_enabled') @('create_date')
 $files=Read-State 'SELECT database_id,file_id,physical_name FROM sys.master_files WHERE database_id IN (11,12,14,15,16) ORDER BY database_id,file_id;'
 Assert-Rows $files $expected.files @('database_id','file_id','physical_name')
 $history=Read-State 'SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM ROK_TRACKER.dbo.SchemaMigrationHistory ORDER BY MigrationId;'
 Assert-Rows $history $(if($AfterObserver){$r.expected_history_after}else{$expected.history}) @('MigrationId','ChecksumSha256','GitCommit','DeploymentId','Status')
 $observer=Read-State "SELECT object_id,create_date,modify_date,CONVERT(bigint,current_value) AS generation FROM [K98_P02Observer_Retained_20261120153927686].sys.sequences WHERE name=N'P02ObservationGeneration';"
 Assert-Rows $observer $expected.observer @('object_id','create_date','modify_date','generation') @('create_date','modify_date')
 $login=Read-State "SELECT name,is_disabled FROM sys.sql_logins WHERE name=N'S11_ExportApplication_P02ObserverQual';"
 if($login.Count -ne 1 -or -not $login[0].is_disabled){throw 'Retained lab login must stay disabled'}
 $busy=Read-State @'
SELECT s.session_id,s.login_name,s.original_login_name,s.program_name,s.status,s.database_id,s.open_transaction_count,s.host_process_id,
 (SELECT COUNT(*) FROM sys.dm_exec_requests q WHERE q.session_id=s.session_id) AS active_requests,
 (SELECT COUNT(*) FROM sys.dm_tran_locks l WHERE l.request_session_id=s.session_id AND l.resource_database_id<>1) AS non_master_locks
FROM sys.dm_exec_sessions s WHERE s.is_user_process=1 AND s.session_id<>@@SPID ORDER BY s.session_id;
'@
 Assert-NoBusinessSessions $busy
 return [pscustomobject]@{databases=$databases;files=$files;history=$history;observer=$observer;login=$login}
}



function Invoke-Native([string]$Label,[string]$Sql,[hashtable]$Values=@{},[int]$Seconds=60) {
 if(-not $r.execution_settled -or $r.cleanup_failure){throw 'Prior physical SQL custody unresolved'}
 $r.stage=$Label;$r.actions+=@([ordered]@{action=$Label;acknowledged=$false});Save-Receipt
 $command=$owner.connection.CreateCommand();$owner.command=$command;$command.CommandText=$Sql;$command.CommandTimeout=0
 foreach($key in $Values.Keys){[void]$command.Parameters.AddWithValue('@'+$key,$Values[$key])}
 $r.execution_settled=$false
 $global:P02ObserverReleaseHeld=@{connection=$owner.connection;command=$command;receipt=$r;settled=$false}
 $pending=$command.BeginExecuteNonQuery();$owner.pending=$pending;$global:P02ObserverReleaseHeld.pending=$pending
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $pending.IsCompleted -and $watch.Elapsed.TotalSeconds -lt $Seconds){$null=$pending.AsyncWaitHandle.WaitOne(1000)}
 if(-not $pending.IsCompleted){throw 'Native SQL operation unresolved; retain command and connection; no cancel or replay'}
 try{$null=$command.EndExecuteNonQuery($pending)}finally{$r.execution_settled=$true}
 $r.actions[-1].acknowledged=$true;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds;Save-Receipt
 $command.Dispose();$owner.command=$null;$owner.pending=$null
}

function Prepare-Package {
 $manifest=Get-Content -LiteralPath (Join-Path $PacketRoot 'candidate-source.json') -Raw|ConvertFrom-Json
 $allowed=@('Deploy-SqlMigration.ps1','SqlDeploy.ModuleRelease.ps1','SqlDeploy.P02D4Release.ps1','SqlDeploy.Phase1Release.ps1','SqlDeploy.P02ObserverRelease.ps1',($migration+'.sql'),($migration+'.release.json'),($migration+'.before.sql'),($migration+'.after.sql'))
 if($manifest.commit -cne $sourceCommit -or $manifest.parent -cne '73b004d4a834f87fe3e559480d99dd597995fd91' -or $manifest.tree -cne 'b1a31a511da7e79f6604d8df65c033250bfc5851' -or @($manifest.members).Count -ne 9){throw 'Exact qualification source snapshot required'}
 if(Test-Path -LiteralPath $repo){throw 'New package destination required'}
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $PacketRoot 'sql-package.zip'))
 try {
  if($zip.Entries.Count -ne 9){throw 'Exact flat SQL package required'}
  $seen=@{}
  foreach($entry in $zip.Entries){
   if($entry.FullName -cnotin $allowed -or $seen.ContainsKey($entry.FullName) -or $entry.Length -le 0 -or $entry.Length -gt 2MB){throw 'Invalid SQL package member'}
   $seen[$entry.FullName]=$true
   $pins=@($manifest.members|Where-Object {$_.name -ceq $entry.FullName})
   if($pins.Count -ne 1){throw 'Unique SQL package pin required'}
   $stream=$entry.Open();$memory=[IO.MemoryStream]::new()
   try{$stream.CopyTo($memory);$raw=$memory.ToArray()}finally{$stream.Dispose();$memory.Dispose()}
   $hash=[Security.Cryptography.SHA256]::Create()
   try{$digest=([BitConverter]::ToString($hash.ComputeHash($raw))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose()}
   if($digest -cne $pins[0].sha256){throw 'SQL package bytes changed'}
  }
  [void][IO.Directory]::CreateDirectory($repo)
  foreach($entry in $zip.Entries){[IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $repo $entry.FullName),$false)}
 }finally{$zip.Dispose()}
 Assert-Package
}
function Assert-Package {
 $manifest=Get-Content -LiteralPath (Join-Path $PacketRoot 'candidate-source.json') -Raw|ConvertFrom-Json
 foreach($item in $manifest.members){
  $file=Get-Item -LiteralPath (Join-Path $repo $item.name) -Force
  if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.sha256){throw 'Packaged coordinator source changed'}
 }
}
function Assert-RestoredMsdb {
 $state=Read-State "SELECT d.name,d.database_id,d.create_date,d.state_desc,d.user_access_desc,d.is_broker_enabled,d.is_trustworthy_on,CONVERT(varchar(36),r.database_guid) AS database_guid,CONVERT(varchar(36),r.family_guid) AS family_guid FROM sys.databases d JOIN sys.database_recovery_status r ON r.database_id=d.database_id WHERE d.name=N'msdb';"
 $files=Read-State "SELECT database_id,file_id,name,type_desc,size,physical_name FROM sys.master_files WHERE database_id=DB_ID(N'msdb') ORDER BY file_id;"
 Assert-Rows $state $previous.msdb_final.state @('name','database_id','create_date','state_desc','user_access_desc','is_broker_enabled','is_trustworthy_on','database_guid','family_guid') @('create_date')
 Assert-Rows $files $previous.msdb_final.files @('database_id','file_id','name','type_desc','physical_name')
 if($state.Count -ne 1 -or $state[0].is_broker_enabled){throw 'Restored msdb containment changed'}
 return [pscustomobject]@{state=$state;files=$files}
}
function Assert-D4 {
 $rows=Read-State @'
SELECT m.MigrationId,m.Status,m.ChecksumSha256,m.GitCommit,m.DeploymentId,d.Status AS deployment_status,d.GitCommit AS deployment_commit,d.ErrorMessage
FROM ROK_TRACKER.dbo.SchemaMigrationHistory m JOIN ROK_TRACKER.dbo.DeploymentRunHistory d ON d.DeploymentId=m.DeploymentId
WHERE m.MigrationId=N'20261111_001_p02_d4_combined';
'@
 Assert-Rows $rows @($previous.d4_receipt) @('MigrationId','Status','ChecksumSha256','GitCommit','DeploymentId','deployment_status','deployment_commit','ErrorMessage')
}
function Assert-NoObserver {
 $rows=Read-State @'
SELECT DeploymentId,Status FROM ROK_TRACKER.dbo.DeploymentRunHistory
WHERE BranchName=N'p02_catalogue_observer_v1' OR JSON_VALUE(CASE WHEN ISJSON(ErrorMessage)=1 THEN ErrorMessage ELSE NULL END,'$.migration_id')=N'20261120_001_p02_catalogue_observer';
SELECT MigrationId,Status FROM ROK_TRACKER.dbo.SchemaMigrationHistory WHERE MigrationId=N'20261120_001_p02_catalogue_observer';
SELECT object_id FROM ROK_TRACKER.sys.sequences WHERE name=N'P02ObservationGeneration';
'@
 if($rows.Count){throw 'Observer attempt or installation exists; status reconciliation required, no replay'}
}
function Invoke-Coordinator([ValidateSet('Status','Preflight','Apply','Verify')][string]$Operation,[string]$State,[int]$ExitCode) {
 if(-not $r.execution_settled -or $r.cleanup_failure){throw 'Unsettled preceding stage'}
 Assert-Package
 $null=Assert-Agent $true
 Close-Lab
 $r.stage='observer '+$Operation;$r.actions+=@([ordered]@{action=$r.stage;acknowledged=$false});Save-Receipt
 $arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$repo+'\Deploy-SqlMigration.ps1" -ServerName MINI_AMD -DatabaseName ROK_TRACKER -MigrationId '+$migration+' -ProfilePath "'+$repo+'\'+$migration+'.release.json" -ProfileSHA256 '+$profile+' -ExpectedCommit '+$sourceCommit+' -ReleaseId '+$plan.release_id+' -Operation '+$Operation
 $stdout=Join-Path $PacketRoot ($Operation+'.stdout.txt');$stderr=Join-Path $PacketRoot ($Operation+'.stderr.txt')
 $r.execution_settled=$false
 $child=Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList $arguments -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
 $owner.child=$child;$null=$child.Handle;$global:P02ObserverReleaseHeld=@{process=$child;receipt=$r;settled=$false}
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $child.WaitForExit(1000) -and $watch.Elapsed.TotalSeconds -lt 240){}
 if(-not $child.HasExited){throw 'Coordinator child unresolved; preserve its handle and inspect status before continuation'}
 $child.WaitForExit();$r.execution_settled=$true;$code=$child.ExitCode
 $r.actions[-1].exit_code=$code;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds;Save-Receipt
 $child.Dispose();$owner.child=$null
 if($code -ne $ExitCode){throw ('Observer '+$Operation+' refused; preserve logs and completed stages')}
 $result=Get-Content -LiteralPath $stdout -Raw|ConvertFrom-Json
 if($result.migration_id -cne $migration -or $result.profile_sha256 -cne $profile -or $result.sql_commit -cne $sourceCommit -or $result.state -cne $State){throw 'Exact coordinator result required'}
 if($State -ceq 'committed' -and ($result.release_id -cne $plan.release_id -or $result.observation_installation.database_id -ne 16)){throw 'Exact committed observer result required'}
 $r.actions[-1].acknowledged=$true;$r.actions[-1].result=$result;Save-Receipt
 $id=Open-Lab
 if($id.product_version -cne '16.0.1220.3'){throw 'SQL version changed during observer stage'}
 return $result
}
function Read-ObserverCommit($Result) {
 $rows=Read-State @'
SELECT m.MigrationId,m.Status,m.ChecksumSha256,m.GitCommit,m.DeploymentId,d.Status AS deployment_status,d.GitCommit AS deployment_commit,d.ErrorMessage
FROM ROK_TRACKER.dbo.SchemaMigrationHistory m JOIN ROK_TRACKER.dbo.DeploymentRunHistory d ON d.DeploymentId=m.DeploymentId
WHERE m.MigrationId=N'20261120_001_p02_catalogue_observer';
'@
 if($rows.Count -ne 1 -or $rows[0].Status -cne 'Applied' -or $rows[0].deployment_status -cne 'Succeeded' -or $rows[0].ChecksumSha256 -cne $profile -or $rows[0].GitCommit -cne $sourceCommit -or $rows[0].deployment_commit -cne $sourceCommit -or [string]$rows[0].DeploymentId -cne $Result.deployment_id){throw 'Exact committed observer history required'}
 $binding=$rows[0].ErrorMessage|ConvertFrom-Json
 if($binding.release_id -cne $plan.release_id -or $binding.migration_id -cne $migration -or $binding.profile_sha256 -cne $profile -or $binding.sql_commit -cne $sourceCommit){throw 'Committed observer binding differs'}
 foreach($name in @('version','protocol_sha256','server','database','database_id','sequence_object_id','sequence_created','sequence_modified','bootstrap_generation')){
  if(($binding.observation_installation.$name|ConvertTo-Json -Compress) -cne ($Result.observation_installation.$name|ConvertTo-Json -Compress)){throw 'Committed incarnation differs from verified coordinator output'}
 }
 $r.observer_committed=$true;$r.observer_receipt=$rows[0];$r.observation_installation=$binding.observation_installation
 $r.expected_history_after=@($expected.history)+@([pscustomobject]@{MigrationId=$rows[0].MigrationId;ChecksumSha256=$rows[0].ChecksumSha256;GitCommit=$rows[0].GitCommit;DeploymentId=$rows[0].DeploymentId;Status=$rows[0].Status})
 $r.expected_history_after=@($r.expected_history_after|Sort-Object MigrationId)
 Save-Receipt
}

Save-Receipt
try {
 Prepare-Package
 $r.agent_before=Assert-Agent $true
 if((Pending-Reboot).Count){throw 'Pending restart must be reconciled'}
 $partition=Get-Partition -DriveLetter Q;$disk=Get-Disk -Number $partition.DiskNumber
 if($partition.Guid -ine '{47cc6080-9e5f-447c-a9e2-dcc007b1e297}' -or $disk.UniqueId -ine '60022480F18852E666A58D834543C4BC' -or $disk.Size -ne 416GB -or (Get-PSDrive Q).Free -lt 20GB){throw 'Exact retained storage and recovery reserve required'}
 $identity=Open-Lab
 if($identity.product_version -cne '16.0.1220.3'){throw 'Exact SQL build required'}
 $r.before=Assert-Fixtures
 $r.msdb_before=Assert-RestoredMsdb
 Assert-D4;Assert-NoObserver
 $r.status_before=Invoke-Coordinator 'Status' 'unstarted' 10
 $null=Assert-Fixtures
 $full=Join-Path $PacketRoot 'db16-before-observer.bak';$log=Join-Path $PacketRoot 'db16-before-observer.trn'
 foreach($path in @($full,$log)){if(Test-Path -LiteralPath $path){throw 'Fresh backup paths required'}}
 $space=Read-State "USE ROK_TRACKER; SELECT (SELECT SUM(CONVERT(bigint,FILEPROPERTY(name,'SpaceUsed')))*8192 FROM sys.database_files WHERE type=0) AS used_data_bytes,used_log_space_in_bytes FROM sys.dm_db_log_space_usage; USE master;"
 if($space.Count -ne 1 -or $null -eq $space[0].used_data_bytes -or (Get-PSDrive Q).Free -lt ($space[0].used_data_bytes+$space[0].used_log_space_in_bytes+16GB)){throw 'Measured backup reserve required'}
 Invoke-Native 'backup DB16 before observer' 'BACKUP DATABASE [ROK_TRACKER] TO DISK=@file WITH COPY_ONLY,COMPRESSION,CHECKSUM,STOP_ON_ERROR;' @{file=$full} 240
 Invoke-Native 'backup DB16 log before observer' 'BACKUP LOG [ROK_TRACKER] TO DISK=@file WITH COMPRESSION,CHECKSUM,STOP_ON_ERROR;' @{file=$log} 120
 $r.database_backup=$full;$r.log_backup=$log
 $r.preflight=Invoke-Coordinator 'Preflight' 'unstarted' 0
 $null=Assert-Fixtures;Assert-D4;Assert-NoObserver
 $r.apply=Invoke-Coordinator 'Apply' 'committed' 0
 Read-ObserverCommit $r.apply
 $r.verify=Invoke-Coordinator 'Verify' 'committed' 0
 Read-ObserverCommit $r.verify
 $r.after=Assert-Fixtures $true
 Assert-D4
 $r.msdb_after=Assert-RestoredMsdb
 $r.agent_after=Assert-Agent $true
 $r.outcome='passed';$r.stage='packaged observer committed and verified; restore and D4 preserved'
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message;line=$_.InvocationInfo.ScriptLineNumber;position=$_.InvocationInfo.PositionMessage}}
finally{
 if($r.execution_settled){
  try{if($null -ne $owner.command){$owner.command.Dispose();$owner.command=$null;$owner.pending=$null};if($null -ne $owner.child){$owner.child.Dispose();$owner.child=$null};Close-Lab}catch{$r.cleanup_failure=$_.Exception.Message;$r.outcome='failed'}
 }
 $global:P02ObserverReleaseHeld=@{settled=($r.execution_settled -and -not $r.cleanup_failure);connection=$owner.connection;command=$owner.command;pending=$owner.pending;process=$owner.child;receipt=$r}
 $r.finished=[datetime]::UtcNow.ToString('o');Save-Receipt
}
return ($r|ConvertTo-Json -Depth 24 -Compress)
