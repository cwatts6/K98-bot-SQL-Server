#requires -Version 5.1
# Exact continuation after acknowledged msdb restore; only dependency/backups/D4 remain.
param([Parameter(Mandatory=$true)][string]$PacketRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$plan=Get-Content -LiteralPath (Join-Path $PacketRoot 'plan.json') -Raw|ConvertFrom-Json
if($env:COMPUTERNAME -cne 'MINI_AMD' -or $plan.schema -cne 'p02-authentic-msdb-d4/3' -or $plan.production_eligible -ne $false -or $plan.vm_id -cne '2ac1b401-7076-4965-af71-de36ee0f9f9c' -or $PacketRoot -cne $plan.guest_directory -or $PacketRoot -cnotmatch '^Q:\\P02Release\\msdb-d4-[0-9]{17}$' -or $plan.sql_commit -cne '73b004d4a834f87fe3e559480d99dd597995fd91' -or $plan.d4_release_id -cne '5381e7db-f50b-482e-8ae8-a933fcce9821'){throw 'Exact isolated authentic-msdb/D4 plan required'}
$members=@('Invoke-P02MsdbD4.ps1','Restore-P02MsdbD4.ps1','accepted-read.json','accepted-update.json','prior-guest-receipt.json')
if(@($plan.files.PSObject.Properties).Count -ne $members.Count){throw 'Exact sealed restore inventory required'}
foreach($item in $plan.files.PSObject.Properties){if($item.Name -cnotin $members -or (Get-FileHash -LiteralPath (Join-Path $PacketRoot $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.Value){throw 'Sealed restore member differs'}}
if($plan.files.'accepted-read.json' -cne 'e875a37ded4a80be3b298843b1b30bf5d4c1c59ff00b349ebefd0f737ad3026e' -or $plan.files.'accepted-update.json' -cne 'dcf00dd8a9ca78368a25f91927844271dfcc70455acb529b2090c66fccd6513c'){throw 'Exact accepted update and named-msdb inventory required'}
$expected=Get-Content -LiteralPath (Join-Path $PacketRoot 'accepted-read.json') -Raw|ConvertFrom-Json
$update=Get-Content -LiteralPath (Join-Path $PacketRoot 'accepted-update.json') -Raw|ConvertFrom-Json
if($expected.outcome -cne 'passed' -or -not $expected.engine_build_matches -or -not $expected.checksum_verification_completed -or $expected.connections_closed -ne 1 -or $update.outcome -cne 'passed' -or $update.engine_after -cne '16.0.1220.3' -or $update.restart_required -or -not $update.execution_settled -or $update.cleanup_failure){throw 'Accepted settled prerequisites required'}
$held=Get-Variable P02LabSqlUpdateHeld -Scope Global -ErrorAction SilentlyContinue
if($null -eq $held -or -not $held.Value.settled -or $null -ne $held.Value.process -or $null -ne $held.Value.connection -or ($held.Value.receipt|ConvertTo-Json -Depth 20 -Compress|ConvertFrom-Json|ConvertTo-Json -Depth 20 -Compress) -cne ($update|ConvertTo-Json -Depth 20 -Compress)){throw 'Exact successful update custody must remain settled'}
function Assert-PriorMsdbAttempt($Held,$Previous) {
 if($Previous.schema -cne 'p02-authentic-msdb-d4-guest/1' -or $Previous.outcome -cne 'failed' -or $Previous.stage -cne 'restore authenticated original msdb' -or @($Previous.actions).Count -ne 3 -or -not $Previous.restored -or $Previous.d4_committed -or -not $Previous.execution_settled -or $Previous.connections_closed -ne 1 -or $Previous.cleanup_failure -or $Previous.first_failure.type -cne 'System.Management.Automation.PSSecurityException' -or $Previous.first_failure.detail -cnotlike 'File Q:\P02Release\prerequisites-20261120161533206\committed-sql\deploy\SqlDeploy.ModuleRelease.ps1 cannot be loaded because running scripts is disabled on this system.*' -or $Previous.production_operations -ne 0 -or $Previous.business_operations -ne 0){throw 'Only the exact settled post-restore loading refusal may continue'}
 $stages=@('preserve current patched lab msdb','verify preserved lab msdb backup','restore authenticated original msdb')
 for($i=0;$i -lt 3;$i++){if($Previous.actions[$i].action -cne $stages[$i] -or $Previous.actions[$i].acknowledged -ne $true){throw 'All three completed original restore stages must remain acknowledged'}}
 if($Previous.lab_msdb_backup -cne 'Q:\P02Release\msdb-d4-20261120184110328\lab-msdb-before-authentic-restore.bak' -or $Previous.msdb_after.state.Count -ne 1 -or $Previous.msdb_after.state[0].database_guid -cne 'C9048AE7-D724-41B4-A1A6-5C3A7A1E26B9' -or $Previous.msdb_after.state[0].is_broker_enabled){throw 'Exact acknowledged restored msdb identity required'}
 if($null -eq $Held -or $Held -isnot [hashtable] -or -not $Held.settled){throw 'Previous restore custody is unresolved'}
 foreach($name in @('connection','command','pending','process')){if(-not $Held.ContainsKey($name) -or $null -ne $Held[$name]){throw 'Previous restore physical handles remain; no continuation'}}
 $native=$Held.receipt|ConvertTo-Json -Depth 24 -Compress|ConvertFrom-Json|ConvertTo-Json -Depth 24 -Compress
 $recorded=$Previous|ConvertTo-Json -Depth 24 -Compress
 if($native -cne $recorded){throw 'Previous native restore receipt differs'}
}
if($plan.prior_directory -cne 'Q:\P02Release\msdb-d4-20261120184110328' -or $plan.files.'prior-guest-receipt.json' -cne 'e0f4366896ca5f3e344c7e39ec084c437f1e5239485539c7b1af751f1666c63b'){throw 'Exact retained successful-restore packet required'}
$previous=Get-Content -LiteralPath (Join-Path $PacketRoot 'prior-guest-receipt.json') -Raw|ConvertFrom-Json
$previousHeld=Get-Variable P02MsdbD4Held -Scope Global -ErrorAction SilentlyContinue
if($null -eq $previousHeld){throw 'Previous native restore custody is missing'}
Assert-PriorMsdbAttempt $previousHeld.Value $previous
$previousDisk=Get-Content -LiteralPath (Join-Path $plan.prior_directory 'guest-receipt.json') -Raw|ConvertFrom-Json
if(($previousDisk|ConvertTo-Json -Depth 24 -Compress) -cne ($previous|ConvertTo-Json -Depth 24 -Compress)){throw 'Previous guest receipt on disk differs'}
$receiptPath=Join-Path $PacketRoot 'guest-receipt.json'
if(Test-Path -LiteralPath $receiptPath){throw 'Restore/D4 attempt already exists; preserve evidence'}
$r=[ordered]@{schema='p02-authentic-msdb-d4-guest/1';outcome='running';stage='preflight';started=[datetime]::UtcNow.ToString('o');actions=@();execution_settled=$true;connections_closed=0;builtin_telemetry_observations=@();first_failure=$null;cleanup_failure=$null;production_operations=0;business_operations=0;restored=$true;restore_replayed=$false;d4_committed=$false;inherited_actions=$previous.actions;msdb_after=$previous.msdb_after;lab_msdb_backup=$previous.lab_msdb_backup;prior_directory=$plan.prior_directory;local_timezone=[TimeZoneInfo]::Local.Id}
$owner=@{connection=$null;command=$null;pending=$null;child=$null}
$repo='Q:\P02Release\prerequisites-20261120161533206\committed-sql'
$profile='57944777e50b7dc9200220cfcc2ce767edb22a2e0972e02bc2cd6f04e23e8171'
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
 $owner.connection=[Data.SqlClient.SqlConnection]::new('Data Source=lpc:localhost;Initial Catalog=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=3;Pooling=False;Asynchronous Processing=True;Application Name=P02AuthenticMsdbD4')
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

function Assert-Fixtures([bool]$AfterD4=$false) {
 $databases=Read-State 'SELECT name,database_id,create_date,state_desc,user_access_desc,source_database_id,snapshot_isolation_state,is_read_committed_snapshot_on,is_broker_enabled FROM sys.databases WHERE database_id IN (11,12,14,15,16) ORDER BY database_id;'
 Assert-Rows $databases $expected.databases @('name','database_id','create_date','state_desc','user_access_desc','source_database_id','snapshot_isolation_state','is_read_committed_snapshot_on','is_broker_enabled') @('create_date')
 $files=Read-State 'SELECT database_id,file_id,physical_name FROM sys.master_files WHERE database_id IN (11,12,14,15,16) ORDER BY database_id,file_id;'
 Assert-Rows $files $expected.files @('database_id','file_id','physical_name')
 $history=Read-State 'SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM ROK_TRACKER.dbo.SchemaMigrationHistory ORDER BY MigrationId;'
 Assert-Rows $history $(if($AfterD4){$r.expected_history_after}else{$expected.history}) @('MigrationId','ChecksumSha256','GitCommit','DeploymentId','Status')
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


function Assert-Source {
 $head=(& git -C $repo rev-parse HEAD 2>&1|Out-String).Trim()
 if($LASTEXITCODE -ne 0 -or $head -cne $plan.sql_commit){throw 'Original committed prerequisite source changed'}
 $status=(& git -C $repo status --porcelain 2>&1|Out-String).Trim()
 if($LASTEXITCODE -ne 0 -or $status){throw 'Original committed source is not clean'}
 foreach($item in $plan.payload.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $repo $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.Value){throw ('Original source pin differs: '+$item.Name)}}
}
function Invoke-Native([string]$Label,[string]$Sql,[hashtable]$Values=@{},[int]$Seconds=60) {
 if(-not $r.execution_settled -or $r.cleanup_failure){throw 'Prior physical SQL custody unresolved'}
 $r.stage=$Label;$r.actions+=@([ordered]@{action=$Label;acknowledged=$false});Save-Receipt
 $command=$owner.connection.CreateCommand();$owner.command=$command;$command.CommandText=$Sql;$command.CommandTimeout=0
 foreach($key in $Values.Keys){[void]$command.Parameters.AddWithValue('@'+$key,$Values[$key])}
 $r.execution_settled=$false
 $global:P02MsdbD4Held=@{connection=$owner.connection;command=$command;receipt=$r;settled=$false}
 $pending=$command.BeginExecuteNonQuery();$owner.pending=$pending;$global:P02MsdbD4Held.pending=$pending
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $pending.IsCompleted -and $watch.Elapsed.TotalSeconds -lt $Seconds){$null=$pending.AsyncWaitHandle.WaitOne(1000)}
 if(-not $pending.IsCompleted){throw 'Native SQL operation unresolved; retain command and connection; no cancel or replay'}
 try{$null=$command.EndExecuteNonQuery($pending)}finally{$r.execution_settled=$true}
 $r.actions[-1].acknowledged=$true;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds;Save-Receipt
 $command.Dispose();$owner.command=$null;$owner.pending=$null
}
function Read-Msdb([bool]$AfterRestore=$false) {
 $state=Read-State "SELECT d.name,d.database_id,d.create_date,d.state_desc,d.user_access_desc,d.is_broker_enabled,d.is_trustworthy_on,CONVERT(varchar(36),r.database_guid) AS database_guid,CONVERT(varchar(36),r.family_guid) AS family_guid FROM sys.databases d JOIN sys.database_recovery_status r ON r.database_id=d.database_id WHERE d.name=N'msdb';"
 $files=Read-State "SELECT database_id,file_id,name,type_desc,size,physical_name FROM sys.master_files WHERE database_id=DB_ID(N'msdb') ORDER BY file_id;"
 if($state.Count -ne 1 -or $state[0].name -cne 'msdb' -or $state[0].database_id -ne 4 -or $state[0].state_desc -cne 'ONLINE' -or $state[0].user_access_desc -cne 'MULTI_USER' -or $files.Count -ne 2){throw 'Exact named msdb ownership required'}
 $databaseGuid=[guid]::Empty
 if(-not [guid]::TryParse([string]$state[0].database_guid,[ref]$databaseGuid) -or $databaseGuid -eq [guid]::Empty){throw 'Valid msdb file-binding identity required'}
 if($AfterRestore -and ($state[0].family_guid -ine [string]$expected.header[0].FamilyGUID -or -not $r.restored)){throw 'Acknowledged restore and exact source backup family required'}
 Assert-Rows $files $expected.msdb_files @('database_id','file_id','name','type_desc','physical_name')
 return [pscustomobject]@{state=$state;files=$files}
}
function Assert-NoD4 {
 $rows=Read-State @'
SELECT DeploymentId,Status FROM ROK_TRACKER.dbo.DeploymentRunHistory
WHERE BranchName=N'p02_d4_v1' OR JSON_VALUE(CASE WHEN ISJSON(ErrorMessage)=1 THEN ErrorMessage ELSE NULL END,'$.migration_id')=N'20261111_001_p02_d4_combined';
SELECT MigrationId,Status FROM ROK_TRACKER.dbo.SchemaMigrationHistory WHERE MigrationId=N'20261111_001_p02_d4_combined';
'@
 if($rows.Count){throw 'D4 has an existing attempt; no replay'}
}
function Assert-Dependency {
 Assert-Source
 # Load only the already hash-verified source in this existing sealed
 # invocation; do not change any machine, user or process execution policy.
 . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $repo 'deploy\SqlDeploy.ModuleRelease.ps1'))))
 . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $repo 'deploy\SqlDeploy.P02D4Release.ps1'))))
 $owner.connection.ChangeDatabase('ROK_TRACKER')
 try{Assert-K98D4Dependencies $owner.connection}finally{$owner.connection.ChangeDatabase('master')}
 $job=Read-State @'
SELECT j.job_id,j.enabled,j.start_step_id,s.step_id,s.subsystem,s.database_name,s.proxy_id,
 CONVERT(varchar(64),HASHBYTES('SHA2_256',s.command),2) AS command_hash
FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobsteps s ON s.job_id=j.job_id
WHERE j.job_id='69BC82B2-2753-485A-A251-986E4D925012' ORDER BY s.step_id;
'@
 if($job.Count -ne 1 -or $job[0].enabled -ne 1 -or $job[0].start_step_id -ne 1 -or $job[0].step_id -ne 1 -or $job[0].subsystem -cne 'TSQL' -or $job[0].database_name -cne 'master' -or $job[0].proxy_id -notin @($null,0) -or $job[0].command_hash -cne '87CBDD451D55F17003796A65ED981EEB21EE8D202A7C325DE9348E187AB0E8CF'){throw 'Authenticated original backup job step differs'}
 $r.authentic_dependency_verified=$true;$r.original_job=$job
}
function Apply-D4 {
 Assert-Source;Assert-NoD4
 $null=Assert-Agent $true
 $r.stage='apply unfinished genuine D4';$r.actions+=@([ordered]@{action=$r.stage;acknowledged=$false});Save-Receipt
 # Release our read-only SQL connection before the original deployment owns SQL.
 Close-Lab
 $arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$repo+'\deploy\Deploy-SqlMigration.ps1" -ServerName MINI_AMD -DatabaseName ROK_TRACKER -MigrationId 20261111_001_p02_d4_combined -ProfilePath "'+$repo+'\migrations\20261111_001_p02_d4_combined.release.json" -ProfileSHA256 '+$profile+' -ExpectedCommit '+$plan.sql_commit+' -ReleaseId '+$plan.d4_release_id+' -Operation Apply'
 $r.execution_settled=$false
 $child=Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList $arguments -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PacketRoot 'd4.stdout.txt') -RedirectStandardError (Join-Path $PacketRoot 'd4.stderr.txt')
 $owner.child=$child;$null=$child.Handle;$global:P02MsdbD4Held=@{process=$child;receipt=$r;settled=$false}
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $child.WaitForExit(1000) -and $watch.Elapsed.TotalSeconds -lt 240){}
 if(-not $child.HasExited){throw 'D4 process unresolved; retain handle; do not replay restore or migration'}
 $child.WaitForExit();$r.execution_settled=$true;$r.actions[-1].exit_code=$child.ExitCode;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds;Save-Receipt
 $code=$child.ExitCode;$child.Dispose();$owner.child=$null
 if($code -ne 0){throw 'Original D4 deployment refused; restore and backups remain committed; do not replay'}
 $identity=Open-Lab
 if($identity.product_version -cne '16.0.1220.3'){throw 'SQL version changed during D4'}
 $rows=Read-State @'
SELECT m.MigrationId,m.Status,m.ChecksumSha256,m.GitCommit,m.DeploymentId,d.Status AS deployment_status,d.GitCommit AS deployment_commit,d.ErrorMessage
FROM ROK_TRACKER.dbo.SchemaMigrationHistory m JOIN ROK_TRACKER.dbo.DeploymentRunHistory d ON d.DeploymentId=m.DeploymentId
WHERE m.MigrationId=N'20261111_001_p02_d4_combined';
'@
 if($rows.Count -ne 1 -or $rows[0].Status -cne 'Applied' -or $rows[0].deployment_status -cne 'Succeeded' -or $rows[0].ChecksumSha256 -cne $profile -or $rows[0].GitCommit -cne $plan.sql_commit -or $rows[0].deployment_commit -cne $plan.sql_commit){throw 'Committed D4 receipt differs; retain evidence'}
 $binding=$rows[0].ErrorMessage|ConvertFrom-Json
 if($binding.release_id -cne $plan.d4_release_id -or $binding.sql_commit -cne $plan.sql_commit -or $binding.profile_sha256 -cne $profile){throw 'Committed D4 release binding differs'}
 $r.d4_committed=$true;$r.d4_receipt=$rows[0];$r.actions[-1].acknowledged=$true
 $r.expected_history_after=@($expected.history)+@([pscustomobject]@{MigrationId=$rows[0].MigrationId;ChecksumSha256=$rows[0].ChecksumSha256;GitCommit=$rows[0].GitCommit;DeploymentId=$rows[0].DeploymentId;Status=$rows[0].Status})
 $r.expected_history_after=@($r.expected_history_after|Sort-Object MigrationId)
 Save-Receipt
}


Save-Receipt
try{
 Assert-Source
 $r.agent_before=Assert-Agent $true
 if((Pending-Reboot).Count){throw 'Pending reboot must be reconciled'}
 $partition=Get-Partition -DriveLetter Q;$disk=Get-Disk -Number $partition.DiskNumber
 if($partition.Guid -ine '{47cc6080-9e5f-447c-a9e2-dcc007b1e297}' -or $disk.UniqueId -ine '60022480F18852E666A58D834543C4BC' -or $disk.Size -ne 416GB -or (Get-PSDrive Q).Free -lt 50GB -or (Get-PSDrive C).Free -lt 2GB+$expected.allocated_bytes){throw 'Exact retained storage and restore reserve required'}
 $identity=Open-Lab
 if($identity.product_version -cne '16.0.1220.3'){throw 'Exact matching SQL build required'}
 $r.before=Assert-Fixtures
 Assert-NoD4
 $r.msdb_before=Read-Msdb $true
 Assert-Rows $r.msdb_before.state $previous.msdb_after.state @('name','database_id','create_date','state_desc','user_access_desc','is_broker_enabled','is_trustworthy_on','database_guid','family_guid') @('create_date')
 Assert-Rows $r.msdb_before.files $previous.msdb_after.files @('database_id','file_id','name','type_desc','physical_name')
 if($r.msdb_before.state[0].is_broker_enabled){throw 'Restored msdb delivery must remain disabled'}
 # The acknowledged restore and its verified recovery backup are retained.
 # This continuation contains no backup/restore dispatch for msdb.
 $saved=Get-Item -LiteralPath $previous.lab_msdb_backup -Force
 if($saved.PSIsContainer -or ($saved.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $saved.Length -le 0){throw 'Preserved lab msdb backup is missing or changed type'}
 $r.preserved_lab_msdb_backup=[ordered]@{path=$previous.lab_msdb_backup;length=$saved.Length;sha256=(Get-FileHash -LiteralPath $previous.lab_msdb_backup -Algorithm SHA256).Hash.ToLowerInvariant();checksum_verification='acknowledged in pinned prior receipt'}
 $full=Join-Path $PacketRoot 'fresh-db16-before-d4.bak'
 $log=Join-Path $PacketRoot 'fresh-db16-before-d4.trn'
 foreach($path in @($full,$log)){if(Test-Path -LiteralPath $path){throw 'New backup destinations required'}}
 $r.stage='verify authentic restored dependency';Save-Receipt
 Assert-Dependency
 $r.stage='fresh lab backup readiness';Save-Receipt
 $space=Read-State "USE ROK_TRACKER; SELECT (SELECT SUM(CONVERT(bigint,FILEPROPERTY(name,'SpaceUsed')))*8192 FROM sys.database_files WHERE type=0) AS used_data_bytes,used_log_space_in_bytes FROM sys.dm_db_log_space_usage; USE master;"
 if($space.Count -ne 1 -or $null -eq $space[0].used_data_bytes -or (Get-PSDrive Q).Free -lt ($space[0].used_data_bytes+$space[0].used_log_space_in_bytes+16GB)){throw 'Fresh lab backups lack measured reserve'}
 Invoke-Native 'backup fresh DB16 after msdb restore' 'BACKUP DATABASE [ROK_TRACKER] TO DISK=@file WITH COPY_ONLY,COMPRESSION,CHECKSUM,STOP_ON_ERROR;' @{file=$full} 240
 Invoke-Native 'backup fresh DB16 log after msdb restore' 'BACKUP LOG [ROK_TRACKER] TO DISK=@file WITH COMPRESSION,CHECKSUM,STOP_ON_ERROR;' @{file=$log} 120
 $r.fresh_database_backup=$full;$r.fresh_log_backup=$log
 Apply-D4
 $r.after=Assert-Fixtures $true
 $r.agent_after=Assert-Agent $true
 $r.msdb_final=Read-Msdb $true
 Assert-Rows $r.msdb_final.state $r.msdb_after.state @('name','database_id','create_date','state_desc','user_access_desc','is_broker_enabled','is_trustworthy_on','database_guid','family_guid') @('create_date')
 if($r.msdb_final.state[0].is_broker_enabled){throw 'Restored msdb delivery changed'}
 $r.outcome='passed';$r.stage='retained authentic dependency verified and genuine D4 committed'
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message;line=$_.InvocationInfo.ScriptLineNumber;position=$_.InvocationInfo.PositionMessage}}
finally{
 if($r.execution_settled){
  try{if($null -ne $owner.command){$owner.command.Dispose();$owner.command=$null;$owner.pending=$null};if($null -ne $owner.child){$owner.child.Dispose();$owner.child=$null};Close-Lab}catch{$r.cleanup_failure=$_.Exception.Message;$r.outcome='failed'}
 }
 $global:P02MsdbD4Held=@{settled=($r.execution_settled -and -not $r.cleanup_failure);connection=$owner.connection;command=$owner.command;pending=$owner.pending;process=$owner.child;receipt=$r}
 $r.finished=[datetime]::UtcNow.ToString('o');Save-Receipt
}
return ($r|ConvertTo-Json -Depth 24 -Compress)
