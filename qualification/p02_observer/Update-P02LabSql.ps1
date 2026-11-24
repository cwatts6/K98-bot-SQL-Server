#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$PacketRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$plan=Get-Content -LiteralPath (Join-Path $PacketRoot 'plan.json') -Raw|ConvertFrom-Json
if($env:COMPUTERNAME -cne 'MINI_AMD' -or $plan.schema -cne 'p02-lab-sql-update/1' -or $plan.production_eligible -ne $false -or $plan.vm_id -cne '2ac1b401-7076-4965-af71-de36ee0f9f9c' -or $PacketRoot -cne $plan.guest_directory -or $plan.from_version -cne '16.0.1210.3' -or $plan.to_version -cne '16.0.1220.3'){throw 'Exact isolated SQL update plan required'}
foreach($p in $plan.files.PSObject.Properties){if($p.Name -cnotin @('Invoke-P02LabSqlUpdate.ps1','Update-P02LabSql.ps1','preflight.zip','SQLServer2022-KB5132747-x64.exe') -or (Get-FileHash -LiteralPath (Join-Path $PacketRoot $p.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $p.Value){throw 'Sealed update member differs'}}
if(@($plan.files.PSObject.Properties).Count -ne 4 -or $plan.files.'SQLServer2022-KB5132747-x64.exe' -cne 'b566f09a461ae4a563a11ff65fd6385993088437a0f3243aa114a90af5b71a79'){throw 'Exact Microsoft update package required'}
$expected=Get-Content -LiteralPath (Join-Path $PacketRoot 'preflight/receipt.json') -Raw|ConvertFrom-Json
if($expected.outcome -cne 'passed' -or $expected.connections_closed -ne 1 -or -not $expected.checksum_verification_completed -or $expected.engine[0].product_version -cne $plan.from_version -or $expected.backup_engine_build -cne '16.0.1220' -or $expected.header[0].BackupSetGUID -cne 'f856bc33-a54a-4343-9650-527167ee2bf5' -or $expected.history.Count -ne 104 -or $expected.d4_attempts.Count){throw 'Completed source/predecessor inspection required'}
$receiptPath=Join-Path $PacketRoot 'guest-receipt.json'
if(Test-Path -LiteralPath $receiptPath){throw 'Existing update attempt retained; no replay'}
$r=[ordered]@{schema='p02-lab-sql-update-guest/1';outcome='running';stage='preflight';started=[datetime]::UtcNow.ToString('o');execution_settled=$true;connections_closed=0;builtin_telemetry_observations=@();installer_started=$false;installer_exit_code=$null;first_failure=$null;cleanup_failure=$null;production_operations=0;business_operations=0;database_restore_performed=$false;migrations_replayed=$false}
$owner=@{connection=$null;child=$null}
function Save-Receipt {[IO.File]::WriteAllText($receiptPath,($r|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))}
function Read-State([string]$Sql){
 $cmd=$owner.connection.CreateCommand();$cmd.CommandText=$Sql;$cmd.CommandTimeout=5;$reader=$null
 try{
  $reader=$cmd.ExecuteReader();$rows=[Collections.Generic.List[object]]::new()
  while($reader.Read()){
   if($rows.Count -ge 256){throw 'Bounded SQL update read exceeded'}
   $row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$row[$reader.GetName($i)]=if($reader.IsDBNull($i)){$null}else{$reader.GetValue($i)}}
   $rows.Add([pscustomobject]$row)
  }
  return ,$rows.ToArray()
 }finally{if($null -ne $reader){$reader.Dispose()};$cmd.Dispose()}
}
function Open-Lab {
 $owner.connection=[Data.SqlClient.SqlConnection]::new('Data Source=lpc:localhost;Initial Catalog=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=3;Pooling=False;Application Name=P02LabSqlVersionAlignment')
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
 if($Value -isnot [datetime]){
  if([string]$Value -cmatch '^/Date\((-?[0-9]+)\)/$'){$Value=([datetime]'1970-01-01T00:00:00').AddMilliseconds([double]$Matches[1])}else{throw 'Typed or retained native date required'}
 }
 $ticks=$Value.Ticks;$part=$ticks%10000;$ticks-=$part;if($part -ge 5000){$ticks+=10000}
 return ([datetime]::new($ticks)).ToString('yyyy-MM-ddTHH:mm:ss.fff')
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
function Assert-Fixtures {
 $databases=Read-State 'SELECT name,database_id,create_date,state_desc,user_access_desc,source_database_id,snapshot_isolation_state,is_read_committed_snapshot_on,is_broker_enabled FROM sys.databases WHERE database_id IN (11,12,14,15,16) ORDER BY database_id;'
 Assert-Rows $databases $expected.databases @('name','database_id','create_date','state_desc','user_access_desc','source_database_id','snapshot_isolation_state','is_read_committed_snapshot_on','is_broker_enabled') @('create_date')
 $files=Read-State 'SELECT database_id,file_id,physical_name FROM sys.master_files WHERE database_id IN (11,12,14,15,16) ORDER BY database_id,file_id;'
 Assert-Rows $files $expected.files @('database_id','file_id','physical_name')
 $history=Read-State 'SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM ROK_TRACKER.dbo.SchemaMigrationHistory ORDER BY MigrationId;'
 Assert-Rows $history $expected.history @('MigrationId','ChecksumSha256','GitCommit','DeploymentId','Status')
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
Save-Receipt
try{
 $r.agent_before=Assert-Agent $false
 $r.pending_reboot_before=Pending-Reboot
 if($r.pending_reboot_before.Count){throw 'Existing pending reboot must be reconciled before patching'}
 if((Get-PSDrive C).Free -lt 10GB -or (Get-PSDrive Q).Free -lt 50GB){throw 'Local update reserve unavailable'}
 $identity=Open-Lab
 if($identity.product_version -cne $plan.from_version){throw 'Predecessor SQL version changed'}
 $r.before=Assert-Fixtures
 Close-Lab
 $r.stage='disable stopped lab Agent';Save-Receipt
 Set-Service -Name SQLSERVERAGENT -StartupType Disabled
 $r.agent_contained=Assert-Agent $true
 $installer=Join-Path $PacketRoot 'SQLServer2022-KB5132747-x64.exe'
 $r.stage='patch exact lab SQL instance';$r.execution_settled=$false;Save-Receipt
 $child=Start-Process -FilePath $installer -ArgumentList '/quiet /IAcceptSQLServerLicenseTerms /Action=Patch /InstanceName=MSSQLSERVER' -WorkingDirectory $PacketRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PacketRoot 'installer.stdout.txt') -RedirectStandardError (Join-Path $PacketRoot 'installer.stderr.txt')
 $owner.child=$child;$null=$child.Handle;$r.installer_started=$true;$r.installer_pid=$child.Id
 $global:P02LabSqlUpdateHeld=@{process=$child;receipt=$r;settled=$false}
 Save-Receipt
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $child.WaitForExit(1000) -and $watch.Elapsed.TotalSeconds -lt 900){}
 if(-not $child.HasExited){throw 'Installer remains unresolved; retain its handle and do not rerun'}
 $child.WaitForExit();$r.execution_settled=$true;$global:P02LabSqlUpdateHeld.settled=$true
 $r.installer_exit_code=$child.ExitCode;$r.installer_seconds=$watch.Elapsed.TotalSeconds;Save-Receipt
 $child.Dispose();$owner.child=$null
 if($r.installer_exit_code -notin @(0,3010)){throw 'Installer failed; preserve checkpoint and setup logs'}
 $r.agent_after=Assert-Agent $true
 $r.pending_reboot_after=Pending-Reboot
 $r.stage='verify updated SQL and retained fixtures';Save-Receipt
 $identity=Open-Lab;$r.engine_after=$identity.product_version
 if($identity.product_version -cne $plan.to_version){throw 'Expected SQL update version is not running'}
 $r.after=Assert-Fixtures
 $r.restart_required=($r.installer_exit_code -eq 3010 -or $r.pending_reboot_after.Count -gt 0)
 $r.outcome=if($r.restart_required){'passed_restart_required'}else{'passed'}
 $r.stage=if($r.restart_required){'updated; VM restart pending'}else{'updated and verified'}
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message;line=$_.InvocationInfo.ScriptLineNumber;position=$_.InvocationInfo.PositionMessage}}
finally{
 try{Close-Lab}catch{$r.cleanup_failure=$_.Exception.Message;$r.outcome='failed'}
 $global:P02LabSqlUpdateHeld=@{settled=($r.execution_settled -and -not $r.cleanup_failure);process=$owner.child;connection=$owner.connection;receipt=$r}
 $r.finished=[datetime]::UtcNow.ToString('o');Save-Receipt
}
return ($r|ConvertTo-Json -Depth 20 -Compress)
