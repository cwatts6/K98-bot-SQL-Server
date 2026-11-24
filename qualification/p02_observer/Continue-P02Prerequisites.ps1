#requires -Version 5.1
# One-shot isolated-fixture continuation. Historical migrations run from their
# genuine committed Git checkout, through their original deployment entries.
param([Parameter(Mandatory=$true)][string]$PacketRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:COMPUTERNAME -cne 'MINI_AMD' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ine 'MINI_AMD\K98LabAdmin' -or $PacketRoot -cnotmatch '^Q:\\P02Release\\prerequisites-[0-9]{17}$'){throw 'Exact isolated lab entry required'}
$plan=Get-Content -LiteralPath (Join-Path $PacketRoot 'plan.json') -Raw|ConvertFrom-Json
if($plan.schema -cne 'p02-prerequisite-plan/1' -or $plan.production_eligible -ne $false -or $plan.sql_commit -cne '73b004d4a834f87fe3e559480d99dd597995fd91'){throw 'Exact committed prerequisite source required'}
foreach($member in $plan.files.PSObject.Properties){$file=Join-Path $PacketRoot $member.Name;if($member.Name -cnotin @('Continue-P02Prerequisites.ps1','Invoke-P02Prerequisites.ps1','source.bundle','baseline-receipt.json','prior-guest-receipt.json') -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -cne $member.Value){throw 'Sealed prerequisite member differs'}}
$priorFile=Join-Path $PacketRoot 'prior-guest-receipt.json'
if((Get-FileHash -LiteralPath $priorFile -Algorithm SHA256).Hash.ToLowerInvariant() -cne '372d0aaba182fb7a328e665131ca222a22bc0106a1642a6f807c348875c3b8d1'){throw 'Exact settled pre-dispatch failure receipt required'}
$previous=Get-Content -LiteralPath $priorFile -Raw|ConvertFrom-Json
if($previous.started -cne '2026-11-20T16:11:00.2911447Z' -or $previous.outcome -cne 'failed' -or -not $previous.execution_settled -or $previous.connections_closed -ne 1 -or $previous.cleanup_failure -or $previous.actions.Count -ne 1 -or $previous.actions[0].acknowledged -or $previous.stage -cne 'preserve original observer fixture name' -or $previous.first_failure.detail -cne "The property 'CommandText' cannot be found on this object. Verify that the property exists and can be set."){throw 'Previous stage is not the exact known pre-dispatch failure'}
$held=Get-Variable P02PrerequisiteHeld -Scope Global -ErrorAction SilentlyContinue
if($held){
 if(-not $held.Value.ContainsKey('settled') -or -not $held.Value.settled -or ($held.Value.receipt|ConvertTo-Json -Depth 24 -Compress) -cne ($previous|ConvertTo-Json -Depth 24 -Compress)){throw 'Different or unresolved native custody retained; no continuation'}
}
$receiptPath=Join-Path $PacketRoot 'guest-receipt.json'
if(Test-Path -LiteralPath $receiptPath){throw 'Original prerequisite attempt exists; no replay'}
$r=[ordered]@{schema='p02-prerequisite-guest/1';started=[DateTime]::UtcNow.ToString('o');outcome='running';stage='source preparation';actions=@();execution_settled=$true;connections_closed=0;first_failure=$null;cleanup_failure=$null;production_operations=0;business_operations=0;migration_history_fabricated=$false;observer_installed=$false;release_accepted=$false}
$connection=$null;$nativeOwner=@{command=$null;pending=$null;child=$null}
$repo=Join-Path $PacketRoot 'committed-sql'
function Save-Receipt {[IO.File]::WriteAllText($receiptPath,($r|ConvertTo-Json -Depth 24),[Text.UTF8Encoding]::new($false))}
function Invoke-SourceGit([string[]]$Arguments){$out=& git @Arguments 2>&1|ForEach-Object {$_.ToString()};if($LASTEXITCODE -ne 0){throw ('Sealed source Git command failed: '+($out -join ' '))};return ($out -join "`n").Trim()}
function Assert-Source {
 if((Invoke-SourceGit @('-C',$repo,'rev-parse','HEAD')) -cne $plan.sql_commit -or (Invoke-SourceGit @('-C',$repo,'status','--porcelain'))){throw 'Genuine committed clean prerequisite checkout required'}
 foreach($item in $plan.payload.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $repo $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.Value){throw ('Historical migration payload differs: '+$item.Name)}}
}
function Canonical-Date([datetime]$Value){$ticks=$Value.Ticks;$part=$ticks%10000;$ticks-=$part;if($part -ge 5000){$ticks+=10000};return ([datetime]::new($ticks)).ToString('yyyy-MM-ddTHH:mm:ss.fff')}
function Read-State([string]$Sql,[hashtable]$Values=@{}) {
 $cmd=$connection.CreateCommand();$cmd.CommandText=$Sql;$cmd.CommandTimeout=5;$reader=$null;$first=$null
 foreach($key in $Values.Keys){[void]$cmd.Parameters.AddWithValue('@'+$key,$Values[$key])}
 try{$reader=$cmd.ExecuteReader();$rows=[Collections.Generic.List[object]]::new();do{while($reader.Read()){if($rows.Count -ge 256){throw 'Bounded prerequisite row limit'};$row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$row[$reader.GetName($i)]=if($reader.IsDBNull($i)){$null}else{$reader.GetValue($i)}};$rows.Add([pscustomobject]$row)}}while($reader.NextResult());return ,$rows.ToArray()}
 catch{$first=$_;throw}
 finally{try{if($reader){$reader.Dispose()};$cmd.Dispose()}catch{$r.cleanup_failure=$_.Exception.GetType().FullName;if(-not $first){throw}}}
}
function Invoke-Native([string]$Label,[string]$Sql,[hashtable]$Values=@{},[int]$Seconds=30) {
 if($r.cleanup_failure -or -not $r.execution_settled){throw 'Prior native custody unresolved'}
 $r.stage=$Label;$r.actions+=@([ordered]@{action=$Label;acknowledged=$false});Save-Receipt
 $command=$connection.CreateCommand();$nativeOwner.command=$command;$command.CommandText=$Sql;$command.CommandTimeout=0
 foreach($key in $Values.Keys){[void]$command.Parameters.AddWithValue('@'+$key,$Values[$key])}
 $r.execution_settled=$false
 $global:P02PrerequisiteHeld=@{connection=$connection;command=$command;receipt=$r}
 $pending=$command.BeginExecuteNonQuery();$nativeOwner.pending=$pending;$global:P02PrerequisiteHeld.pending=$pending
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $pending.IsCompleted -and $watch.Elapsed.TotalSeconds -lt $Seconds){$null=$pending.AsyncWaitHandle.WaitOne(1000)}
 if(-not $pending.IsCompleted){throw 'Native stage unresolved; retain handles, no cancellation or replay'}
 try{$null=$command.EndExecuteNonQuery($pending)}finally{$r.execution_settled=$true}
 $r.actions[-1].acknowledged=$true;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds;Save-Receipt
 $command.Dispose();$nativeOwner.command=$null;$nativeOwner.pending=$null
}
function Assert-Drain {
 $busy=Read-State @'
SELECT session_id FROM sys.dm_exec_sessions WHERE is_user_process=1 AND session_id<>@@SPID
 AND (database_id IN (12,16) OR session_id IN (SELECT session_id FROM sys.dm_exec_requests WHERE database_id IN (12,16))
 OR session_id IN (SELECT request_session_id FROM sys.dm_tran_locks WHERE resource_database_id IN (12,16)));
'@
 if($busy.Count){throw 'Fixture has an active session; no forced drain authorized'}
}
function Invoke-Migration([string]$Id,[string]$ProfileHash='',[string]$ReleaseId='') {
 Assert-Source;Assert-Drain
 $target=Read-State "SELECT database_id,user_access_desc FROM sys.databases WHERE name=N'ROK_TRACKER';"
 if($target.Count -ne 1 -or $target[0].database_id -ne 16 -or $target[0].user_access_desc -cne 'MULTI_USER'){throw 'Fresh DB16 release binding changed'}
 if((Read-State 'SELECT MigrationId FROM ROK_TRACKER.dbo.SchemaMigrationHistory WHERE MigrationId=@id;' @{id=$Id}).Count){throw 'Migration attempt already exists; do not replay'}
 $r.stage='apply '+$Id;$r.actions+=@([ordered]@{action=$r.stage;acknowledged=$false});Save-Receipt
 $arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$repo+'\deploy\Deploy-SqlMigration.ps1" -ServerName MINI_AMD -DatabaseName ROK_TRACKER -MigrationId '+$Id
 if($ProfileHash){$arguments+=' -ProfilePath "'+$repo+'\migrations\'+$Id+'.release.json" -ProfileSHA256 '+$ProfileHash+' -ExpectedCommit '+$plan.sql_commit+' -ReleaseId '+$ReleaseId+' -Operation Apply'}
 else{$arguments+=' -RepoPath "'+$repo+'" -AllowNonMainBranch -Reason "Authorised isolated prerequisite fixture from exact committed source"'}
 $r.execution_settled=$false
 $child=Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList $arguments -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PacketRoot ($Id+'.stdout.txt')) -RedirectStandardError (Join-Path $PacketRoot ($Id+'.stderr.txt'))
 $nativeOwner.child=$child;$null=$child.Handle;$global:P02PrerequisiteHeld=@{connection=$connection;process=$child;receipt=$r}
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $child.WaitForExit(1000) -and $watch.Elapsed.TotalSeconds -lt 240){}
 if(-not $child.HasExited){throw 'Actual migration process unresolved; retain process/session and inspect, no replay'}
 $child.WaitForExit();$r.execution_settled=$true;$r.actions[-1].exit_code=$child.ExitCode;$r.actions[-1].seconds=$watch.Elapsed.TotalSeconds
 if($child.ExitCode -ne 0){throw ('Actual migration refused: '+$Id+'; original output and history retained')}
 $rows=Read-State @'
SELECT m.MigrationId,m.Status,m.ChecksumSha256,m.GitCommit,m.DeploymentId,d.Status AS deployment_status,d.GitCommit AS deployment_commit,d.ErrorMessage
FROM ROK_TRACKER.dbo.SchemaMigrationHistory m JOIN ROK_TRACKER.dbo.DeploymentRunHistory d ON d.DeploymentId=m.DeploymentId WHERE m.MigrationId=@id;
'@ @{id=$Id}
 $expected=if($ProfileHash){$ProfileHash}else{'bb0e3161d8c3df96452e2631dfcbb8bbb9e0637877631624716129e76d7129a8'}
 $commit=if($ProfileHash){$plan.sql_commit}else{$plan.sql_commit.Substring(0,12)}
 if($rows.Count -ne 1 -or $rows[0].Status -cne 'Applied' -or $rows[0].deployment_status -cne 'Succeeded' -or $rows[0].ChecksumSha256 -cne $expected -or $rows[0].GitCommit -cne $commit -or $rows[0].deployment_commit -cne $commit){throw 'Actual committed prerequisite receipt differs; preserve and inspect'}
 if($ProfileHash){$binding=$rows[0].ErrorMessage|ConvertFrom-Json;if($binding.release_id -cne $ReleaseId -or $binding.sql_commit -cne $plan.sql_commit -or $binding.profile_sha256 -cne $ProfileHash){throw 'Exact combined-release binding differs'}}
 $r.actions[-1].acknowledged=$true;$r.actions[-1].receipt=$rows[0];Save-Receipt;$child.Dispose();$nativeOwner.child=$null
}
Save-Receipt
try {
 if(Test-Path -LiteralPath $repo){throw 'Fresh qualification source path required'}
 if((Get-Volume -DriveLetter Q).SizeRemaining -lt 50GB){throw 'Fresh fixture backup capacity reserve unavailable'}
 $null=Invoke-SourceGit @('init','--quiet',$repo)
 $null=Invoke-SourceGit @('-C',$repo,'fetch','--quiet','--no-tags',(Join-Path $PacketRoot 'source.bundle'),'HEAD')
 $null=Invoke-SourceGit @('-C',$repo,'-c','core.autocrlf=false','checkout','--quiet','--detach','FETCH_HEAD')
 Assert-Source
 $r.sql_commit=$plan.sql_commit
 $agent=Get-Service -Name SQLSERVERAGENT
 if($agent.Status -ne 'Stopped'){throw 'Isolated fixture requires the existing SQL Agent to remain stopped; do not race scheduled work'}
 $connection=[Data.SqlClient.SqlConnection]::new('Data Source=lpc:localhost;Initial Catalog=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=3;Pooling=False;Asynchronous Processing=True;Application Name=P02PrerequisiteFixture')
 $connection.Open()
 $identity=Read-State "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,ORIGINAL_LOGIN() AS login_name,IS_SRVROLEMEMBER('sysadmin') AS administrator;"
 if($identity.Count -ne 1 -or $identity[0].server_name -cne 'MINI_AMD' -or $identity[0].login_name -ine 'MINI_AMD\K98LabAdmin' -or $identity[0].administrator -ne 1){throw 'Exact lab SQL identity required'}
 $databaseSql='SELECT name,database_id,create_date,state_desc,user_access_desc,source_database_id,is_broker_enabled FROM sys.databases WHERE database_id IN (11,12,14,15,16) ORDER BY database_id;'
 $r.before=Read-State $databaseSql
 if($r.before.Count -ne 5 -or $r.before[0].name -cne 'K98_P025_D5e_Cost_20261115' -or $r.before[1].name -cne 'ROK_TRACKER' -or (Canonical-Date $r.before[1].create_date) -cne '2026-11-17T17:34:47.357' -or $r.before[2].source_database_id -ne 11 -or $r.before[3].source_database_id -ne 12 -or $r.before[4].name -cne 'K98_P02Release_20261120153927686' -or (Canonical-Date $r.before[4].create_date) -cne '2026-11-20T15:43:29.040' -or $r.before[4].user_access_desc -cne 'RESTRICTED_USER' -or $r.before[4].is_broker_enabled){throw 'Exact retained/restored identities required'}
 if(@($r.before|Where-Object {$_.state_desc -cne 'ONLINE'}).Count){throw 'All retained databases must be online'}
 if((Read-State "SELECT database_id FROM sys.databases WHERE name=N'K98_P02Observer_Retained_20261120153927686';").Count){throw 'Preserved namespace already exists'}
 $filesSql='SELECT database_id,file_id,physical_name FROM sys.master_files WHERE database_id IN (11,12,14,15,16) ORDER BY database_id,file_id;'
 $r.files_before=Read-State $filesSql
 $freshFiles=@($r.files_before|Where-Object {$_.database_id -eq 16})
 if($freshFiles.Count -ne 2 -or $freshFiles[0].physical_name -cne 'Q:\P02Release\K98_P02Release_20261120153927686\baseline.mdf' -or $freshFiles[1].physical_name -cne 'Q:\P02Release\K98_P02Release_20261120153927686\baseline_log.ldf'){throw 'Exact restored physical ownership required'}
 $originalSql="SELECT object_id,create_date,modify_date,CONVERT(bigint,current_value) AS generation FROM [ROK_TRACKER].sys.sequences WHERE name=N'P02ObservationGeneration';"
 $r.observer_before=Read-State $originalSql
 if($r.observer_before.Count -ne 1 -or $r.observer_before[0].object_id -ne 1221344607 -or $r.observer_before[0].generation -ne 127 -or (Canonical-Date $r.observer_before[0].create_date) -cne '2026-11-20T13:14:27.063'){throw 'Retained observer incarnation differs'}
 $historySql='SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status FROM [K98_P02Release_20261120153927686].dbo.SchemaMigrationHistory ORDER BY MigrationId;'
 $r.history_before=Read-State $historySql
 $baseline=Get-Content -LiteralPath (Join-Path $PacketRoot 'baseline-receipt.json') -Raw|ConvertFrom-Json
 if(($r.history_before|ConvertTo-Json -Compress) -cne ($baseline.history|ConvertTo-Json -Compress)){throw 'Restored genuine history changed'}
 $loginSql="SELECT name,is_disabled FROM sys.sql_logins WHERE name=N'S11_ExportApplication_P02ObserverQual';"
 $r.lab_login=Read-State $loginSql
 if($r.lab_login.Count -ne 1 -or -not $r.lab_login[0].is_disabled){throw 'Lab login must remain disabled'}
 $backupSpace=Read-State "USE [K98_P02Release_20261120153927686]; SELECT (SELECT SUM(CONVERT(bigint,FILEPROPERTY(name,'SpaceUsed')))*8192 FROM sys.database_files WHERE type=0) AS used_data_bytes,used_log_space_in_bytes FROM sys.dm_db_log_space_usage; USE master;"
 if($backupSpace.Count -ne 1 -or $null -eq $backupSpace[0].used_data_bytes -or (Get-Volume -DriveLetter Q).SizeRemaining -lt ($backupSpace[0].used_data_bytes+$backupSpace[0].used_log_space_in_bytes+16GB)){throw 'Uncompressed backup sizes plus volume reserve must fit before rename'}
 $r.backup_space=$backupSpace[0]
 Assert-Drain
 Invoke-Native 'preserve original observer fixture name' 'SET LOCK_TIMEOUT 3000; ALTER DATABASE [ROK_TRACKER] MODIFY NAME=[K98_P02Observer_Retained_20261120153927686];'
 $renamed=Read-State "SELECT name FROM sys.databases WHERE database_id=12;"
 if($renamed.Count -ne 1 -or $renamed[0].name -cne 'K98_P02Observer_Retained_20261120153927686'){throw 'Original rename acknowledgement differs'}
 $preserved=Read-State ($originalSql.Replace('[ROK_TRACKER]','[K98_P02Observer_Retained_20261120153927686]'))
 if(($preserved|ConvertTo-Json -Compress) -cne ($r.observer_before|ConvertTo-Json -Compress)){throw 'Original observer changed during rename; preserve and inspect'}
 Assert-Drain
 Invoke-Native 'bind fresh DB16 to release target name' 'SET LOCK_TIMEOUT 3000; ALTER DATABASE [K98_P02Release_20261120153927686] MODIFY NAME=[ROK_TRACKER];'
 Invoke-Native 'enable fresh fixture release access' 'SET LOCK_TIMEOUT 3000; ALTER DATABASE [ROK_TRACKER] SET MULTI_USER WITH NO_WAIT;'
 $full=Join-Path $PacketRoot 'fresh-before-prerequisites.bak';$log=Join-Path $PacketRoot 'fresh-before-prerequisites.trn'
 foreach($path in @($full,$log)){if(Test-Path -LiteralPath $path){throw 'Fresh backup paths required'}}
 Invoke-Native 'backup genuine fresh baseline' 'BACKUP DATABASE [ROK_TRACKER] TO DISK=@file WITH COPY_ONLY,COMPRESSION,CHECKSUM,STOP_ON_ERROR;' @{file=$full} 180
 $recovery=Read-State "SELECT recovery_model_desc FROM sys.databases WHERE database_id=16;"
 if($recovery[0].recovery_model_desc -cne 'SIMPLE'){Invoke-Native 'backup fresh baseline log' 'BACKUP LOG [ROK_TRACKER] TO DISK=@file WITH COMPRESSION,CHECKSUM,STOP_ON_ERROR;' @{file=$log} 180}
 Invoke-Migration '20261106_001_personal_stats_daily_read_plan'
 Invoke-Migration '20261109_001_p02_phase1_sql_exports' '520b58c1b25d80bd28f32324d99b5fede0d6191ddab93ac93469ed5c1f6e4041' $plan.phase1_release_id
 Invoke-Migration '20261111_001_p02_d4_combined' '57944777e50b7dc9200220cfcc2ce767edb22a2e0972e02bc2cd6f04e23e8171' $plan.d4_release_id
 $r.stage='verify retained fixtures and genuine history'
 $r.after=Read-State $databaseSql
 if($r.after.Count -ne 5 -or $r.after[1].name -cne 'K98_P02Observer_Retained_20261120153927686' -or $r.after[4].name -cne 'ROK_TRACKER' -or $r.after[4].user_access_desc -cne 'MULTI_USER' -or $r.after[4].is_broker_enabled){throw 'Final fixture binding differs'}
 foreach($index in @(0,2,3)){if(($r.before[$index]|ConvertTo-Json -Compress) -cne ($r.after[$index]|ConvertTo-Json -Compress)){throw 'Unrelated fixture/snapshot changed'}}
 $r.files_after=Read-State $filesSql
 if(($r.files_after|ConvertTo-Json -Compress) -cne ($r.files_before|ConvertTo-Json -Compress)){throw 'Physical fixture file ownership changed'}
 $r.observer_after=Read-State ($originalSql.Replace('[ROK_TRACKER]','[K98_P02Observer_Retained_20261120153927686]'))
 if(($r.observer_after|ConvertTo-Json -Compress) -cne ($r.observer_before|ConvertTo-Json -Compress)){throw 'Retained observer incarnation/generation changed'}
 $r.history_after=Read-State ($historySql.Replace('[K98_P02Release_20261120153927686]','[ROK_TRACKER]'))
 if($r.history_after.Count -ne ($r.history_before.Count+3)){throw 'Exactly three genuine migration records required'}
 foreach($old in $r.history_before){$now=@($r.history_after|Where-Object {$_.MigrationId -ceq $old.MigrationId});if($now.Count -ne 1 -or ($now[0]|ConvertTo-Json -Compress) -cne ($old|ConvertTo-Json -Compress)){throw 'Historical migration receipt changed'}}
 $r.lab_login_after=Read-State $loginSql
 if(($r.lab_login_after|ConvertTo-Json -Compress) -cne ($r.lab_login|ConvertTo-Json -Compress)){throw 'Lab login changed'}
 $r.free_bytes=(Get-Volume -DriveLetter Q).SizeRemaining
 $r.outcome='passed'
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}}
finally {
 if($r.execution_settled -and $connection){try{if($nativeOwner.command){$nativeOwner.command.Dispose()};if($nativeOwner.child){$nativeOwner.child.Dispose()};$connection.Close();$connection.Dispose();$r.connections_closed++}catch{$r.cleanup_failure=$_.Exception.GetType().FullName;$r.outcome='failed'}}
 if($r.execution_settled -and -not $r.cleanup_failure){$global:P02PrerequisiteHeld=@{settled=$true;receipt=$r}}else{$global:P02PrerequisiteHeld=@{connection=$connection;command=$nativeOwner.command;pending=$nativeOwner.pending;process=$nativeOwner.child;receipt=$r}}
 $r.finished=[DateTime]::UtcNow.ToString('o');Save-Receipt
}
$r|ConvertTo-Json -Depth 24 -Compress
