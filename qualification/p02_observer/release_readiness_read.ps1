#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Run','Library')][string]$Action='Run',[string]$PlanSHA256,[string]$PacketRoot=$PSScriptRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Read-P02Rows([string]$Sql,[int]$Bound,[hashtable]$Parameters=@{},[int]$Timeout=5) {
 $command=$script:connection.CreateCommand()
 $global:P02ReadinessCommand=$command
 $command.CommandText=$Sql;$command.CommandTimeout=$Timeout
 foreach($name in $Parameters.Keys){$p=$command.Parameters.Add('@'+$name,[Data.SqlDbType]::Int);$p.Value=[int]$Parameters[$name]}
 $reader=$null;$failure=$null;$rows=[Collections.Generic.List[object]]::new()
 try {
  $script:receipt.statement_count++
  $reader=$command.ExecuteReader()
  $global:P02ReadinessReader=$reader
  while($reader.Read()){
   if($rows.Count -ge $Bound){throw 'Bounded result exceeded'}
   $row=[ordered]@{}
   for($i=0;$i -lt $reader.FieldCount;$i++){
    $name=$reader.GetName($i);if($row.Contains($name)){throw 'Duplicate result column'}
    $value=$reader.GetValue($i)
    if($value -is [DBNull]){$value=$null}
    elseif($value -is [byte[]]){$value=([BitConverter]::ToString($value)).Replace('-','').ToLowerInvariant()}
    elseif($value -is [datetime]){$value=$value.ToString('yyyy-MM-dd HH:mm:ss.ffffff',[Globalization.CultureInfo]::InvariantCulture)}
    $row[$name]=$value
   }
   $rows.Add([pscustomobject]$row)
  }
  if($reader.NextResult()){throw 'Unexpected additional result'}
 }catch{$failure=$_}
 finally {
  if($null -ne $reader){try{$reader.Close();$reader.Dispose();$global:P02ReadinessReader=$null;$script:receipt.readers_closed++}catch{$script:receipt.cleanup_failures.Add('reader closure unconfirmed');$script:receipt.physical_custody_retained=$true;if($null -eq $failure){$failure=$_}}}
  if(-not $script:receipt.physical_custody_retained){try{$command.Dispose();$global:P02ReadinessCommand=$null}catch{$script:receipt.cleanup_failures.Add('command disposal unconfirmed');$script:receipt.physical_custody_retained=$true;if($null -eq $failure){$failure=$_}}}
 }
 if($null -ne $failure){throw $failure}
 return ,$rows.ToArray()
}
function Close-P02ReadinessConnection {
 if($null -eq $script:connection){return}
 if($script:receipt.physical_custody_retained){$script:receipt.outcome='failed';return}
 try{$script:connection.Close();$script:connection.Dispose();$script:receipt.connection_closed=$true;$global:P02ReadinessConnection=$null}
 catch{$script:receipt.cleanup_failures.Add('connection closure unconfirmed');$script:receipt.physical_custody_retained=$true;$script:receipt.outcome='failed'}
}
function Invoke-P02LegacyCensus($Census) {
 $queries=@{};foreach($item in $Census.statements){$queries[$item.id]=$item}
 $clock=[Diagnostics.Stopwatch]::StartNew()
 $answer=[ordered]@{raw_seasons=@();source_page=@();seasons=@();omitted=@();raw_truncated=$false;source_truncated=$false;complete=$false;data_statements=0}
 function CensusRead([string]$Id,[hashtable]$Values=@{}) {
  if($clock.Elapsed.TotalSeconds -ge 180 -or $answer.data_statements -ge 98){throw 'Census limit reached; coverage remains partial'}
  $q=$queries[$Id];$answer.data_statements++
  Read-P02Rows $q.sql $q.max_rows $Values
 }
 $script:receipt.census=$answer
 $after=0
 for($i=0;$i -lt 17;$i++){
  $rows=CensusRead 'raw_next_season' @{after_kvk=$after}
  if(-not $rows.Count){break}
  if($rows[0].KVK_NO -le $after){throw 'Nonincreasing raw season'}
  $after=[int]$rows[0].KVK_NO
  if($i -eq 16){$answer.raw_truncated=$true;break}
  $answer.raw_seasons+=,$after
 }
 $rows=CensusRead 'source_page'
 $answer.source_truncated=$rows.Count -gt 16
 $answer.source_page=@($rows|Select-Object -First 16)
 $selected=@(@($answer.raw_seasons)+@($answer.source_page|ForEach-Object {[int]$_.KVK_NO})|Sort-Object -Unique)
 $answer.omitted=@($selected|Select-Object -Skip 16)
 foreach($number in @($selected|Select-Object -First 16)){
  $row=[ordered]@{kvk_no=$number}
  foreach($id in @('season_source','scan_metadata','window_metadata','latest_weights','season_presence')){$row[$id]=CensusRead $id @{kvk_no=$number}}
  $row.scan_truncated=$row.scan_metadata.Count -gt 64;$row.window_truncated=$row.window_metadata.Count -gt 64
  $answer.seasons+=,[pscustomobject]$row
 }
 $answer.complete=-not($answer.raw_truncated -or $answer.source_truncated -or $answer.omitted.Count -or @($answer.seasons|Where-Object {$_.scan_truncated -or $_.window_truncated}).Count)
 return $answer
}
function Get-P02FileFact([string]$Path,[long]$Maximum=32MB,[switch]$MetadataOnly) {
 if(-not(Test-Path -LiteralPath $Path)){return @{path=$Path;exists=$false}}
 $file=Get-Item -LiteralPath $Path -Force
 if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Ordinary bounded file required'}
 $result=[ordered]@{path=$file.FullName;exists=$true;bytes=$file.Length;modified_ticks=$file.LastWriteTimeUtc.Ticks}
 if(-not $MetadataOnly){
  if($file.Length -gt $Maximum){throw 'File read bound exceeded'}
  $result.sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
 }
 return $result
}
if($Action -ceq 'Library'){return}
if($env:COMPUTERNAME -cne 'MINI_AMD' -or $PSVersionTable.PSEdition -cne 'Desktop'){throw 'Exact isolated Windows guest required'}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if($identity.Name -cne 'MINI_AMD\K98LabAdmin' -or -not([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Exact lab administrative identity required'}
$planPath=Join-Path $PacketRoot 'plan.json'
if((Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $PlanSHA256){throw 'Sealed guest plan differs'}
$plan=Get-Content -LiteralPath $planPath -Raw -Encoding UTF8|ConvertFrom-Json
if($plan.schema -cne 'p02-release-readiness-read/2' -or $plan.vm_id -cne '2ac1b401-7076-4965-af71-de36ee0f9f9c' -or $PacketRoot -cne $plan.guest_directory -or $plan.production_eligible -ne $false){throw 'Exact read-only lab packet required'}
foreach($item in $plan.files.PSObject.Properties){
 if($item.Name -cnotmatch '^[A-Za-z0-9_.-]+$' -or (Get-P02FileFact (Join-Path $PacketRoot $item.Name)).sha256 -cne $item.Value){throw 'Guest packet member differs'}
}
if($PacketRoot -cnotmatch '^C:\\Program Files\\K98-P02-Readiness-[0-9]{17}$'){throw 'Protected Program Files evidence leaf required'}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PacketRoot 'K98-SourceUpdate.ps1'),[ref]$tokens,[ref]$errors)
$functions=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Assert-Protected'},$true))
if($errors.Count -or $functions.Count -ne 1){throw 'Exact existing custody primitive required'}
. ([scriptblock]::Create($functions[0].Extent.Text))
Assert-Protected $PacketRoot
Assert-Protected $planPath
foreach($item in $plan.files.PSObject.Properties){Assert-Protected (Join-Path $PacketRoot $item.Name)}
$receiptPath=Join-Path $PacketRoot 'receipt.json'
if(Test-Path -LiteralPath $receiptPath){throw 'Executed packet may not run again'}
$script:receipt=[ordered]@{schema=$plan.schema;outcome='running';stage='identity';first_failure=$null;cleanup_failures=[Collections.Generic.List[string]]::new();statement_count=0;readers_closed=0;connection_closed=$false;physical_custody_retained=$false;native_mutations=0;business_dispatches=0;census=$null}
$script:connection=$null
$intent=Join-Path $PacketRoot 'guest-intent.json'
$stream=[IO.FileStream]::new($intent,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try{$raw=[Text.Encoding]::UTF8.GetBytes($PlanSHA256);$stream.Write($raw,0,$raw.Length);$stream.Flush($true)}finally{$stream.Dispose()}
try {
 $agent=Get-CimInstance Win32_Service -Filter "Name='SQLSERVERAGENT'"
 if($agent.State -cne 'Stopped' -or $agent.StartMode -cne 'Disabled'){throw 'SQL Agent must remain stopped and disabled'}
 $builder=[Data.SqlClient.SqlConnectionStringBuilder]::new()
 $builder['Data Source']='lpc:localhost';$builder['Initial Catalog']='K98_P02CaptureChain_20261123150616134';$builder['Integrated Security']=$true;$builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=10;$builder['Application Name']='P02_ReleaseReadiness_ReadOnly'
 $script:connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
 $global:P02ReadinessConnection=$script:connection
 $script:connection.Open()
 $id=Read-P02Rows "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS product_version,ORIGINAL_LOGIN() AS login_name,DB_ID() AS database_id;" 1
 if($id.Count -ne 1 -or $id[0].server_name -cne 'MINI_AMD' -or $id[0].product_version -cne '16.0.1220.3' -or $id[0].login_name -cne 'MINI_AMD\K98LabAdmin' -or $id[0].database_id -ne 27){throw 'SQL target differs'}
 $inventorySql="SELECT d.database_id,d.name,d.create_date,d.user_access_desc,CONVERT(varchar(36),r.database_guid) AS database_guid FROM sys.databases d JOIN sys.database_recovery_status r ON r.database_id=d.database_id WHERE d.database_id IN (18,27) ORDER BY d.database_id;"
 $before=Read-P02Rows $inventorySql 2
 if(($before|ConvertTo-Json -Compress) -cne ($plan.databases|ConvertTo-Json -Compress)){throw 'Retained database identity differs'}
 $script:receipt.databases_before=$before
 $stateSql="SELECT CONVERT(bigint,current_value) AS generation,(SELECT COUNT(*) FROM dbo.ExportResource WHERE OwnerID IS NOT NULL OR ActiveJobID IS NOT NULL OR ActivePreparationID IS NOT NULL OR ActiveOutputOperationID IS NOT NULL OR BlockedReason IS NOT NULL) AS active_resources FROM sys.sequences WHERE schema_id=SCHEMA_ID(N'dbo') AND name=N'P02ObservationGeneration';"
 $stateBefore=Read-P02Rows $stateSql 1
 if($stateBefore.Count -ne 1 -or $stateBefore[0].generation -ne 19 -or $stateBefore[0].active_resources -ne 0){throw 'Accepted fixture generation or ownership changed'}
 $script:receipt.state_before=$stateBefore
 $script:receipt.stage='candidate SQL preconditions'
 $check=[IO.File]::ReadAllText((Join-Path $PacketRoot 'return.before.sql'),[Text.Encoding]::UTF8)
 $null=Read-P02Rows $check 0 @{} 60
 $script:receipt.return_preimage_passed=$true
 $script:receipt.return_eligible=$false # DB27 has acknowledged business; never a return target.
 $script:receipt.stage='bounded legacy source census'
 $census=Get-Content -LiteralPath (Join-Path $PacketRoot 'legacy-kvk-census.json') -Raw -Encoding UTF8|ConvertFrom-Json
 $script:receipt.census=Invoke-P02LegacyCensus $census
 $script:receipt.stage='installed updater and startup facts'
 $tool='C:\ProgramData\K98\S11\updater'
 $manifestFact=Get-P02FileFact (Join-Path $tool 'update-tool.json') 1MB
 $script:receipt.tool_manifest=$manifestFact
 $script:receipt.tool_members=@()
 if($manifestFact.exists){
  $m=Get-Content -LiteralPath $manifestFact.path -Raw -Encoding UTF8|ConvertFrom-Json
  if($m.version -ne 1 -or @($m.files.PSObject.Properties).Count -gt 32){throw 'Updater inventory shape differs'}
  foreach($item in $m.files.PSObject.Properties){
   if($item.Name -cnotmatch '^[A-Za-z][A-Za-z0-9_.-]+$'){throw 'Unsafe installed tool member'}
   $fact=Get-P02FileFact (Join-Path $tool $item.Name)
   $fact.matches_manifest=$fact.exists -and $fact.sha256 -ceq $item.Value
   $script:receipt.tool_members+=,[pscustomobject]$fact
  }
 }
 $task=Get-ScheduledTask -TaskPath '\' -TaskName 'StartDLBotAfterSQL' -ErrorAction SilentlyContinue
 $script:receipt.startup_task=@{exists=$null -ne $task}
 if($null -ne $task){
  $xml=Export-ScheduledTask -TaskPath '\' -TaskName 'StartDLBotAfterSQL'
  $h=[Security.Cryptography.SHA256]::Create();try{$xmlHash=([BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($xml)))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}
  $script:receipt.startup_task=@{exists=$true;state=[string]$task.State;enabled=$task.Settings.Enabled;xml_sha256=$xmlHash;actions=@($task.Actions).Count;principal_sid=([Security.Principal.NTAccount]::new($task.Principal.UserId).Translate([Security.Principal.SecurityIdentifier]).Value)}
  if(@($task.Actions).Count -eq 1 -and $task.Actions[0].Arguments -cmatch '-File "(C:\\ProgramData\\K98\\S11\\runtime\\[0-9a-f-]{36}\\Start-ReviewedAutomaticStartup.ps1)"$'){
   $script:receipt.startup_gate=Get-P02FileFact $Matches[1] 1MB
   $script:receipt.startup_policy=Get-P02FileFact (Join-Path (Split-Path -Parent $Matches[1]) 'AutomaticStartupPolicy.json') 1MB
  }
 }
 $script:receipt.active_update=Get-P02FileFact 'C:\ProgramData\K98\S11\updates\active.json' 1MB
 $script:receipt.interpreter=Get-P02FileFact 'C:\Program Files\Python311\python.exe' 16MB
 $script:receipt.backups=@()
 foreach($item in $plan.backups){
  $fact=Get-P02FileFact $item.path -MetadataOnly
  $fact.matches_retained_metadata=$fact.exists -and $fact.bytes -eq $item.bytes -and $fact.modified_ticks -eq $item.modified_ticks
  $script:receipt.backups+=,[pscustomobject]$fact
 }
 $script:receipt.stage='final preservation'
 $after=Read-P02Rows $inventorySql 2
 if(($after|ConvertTo-Json -Compress) -cne ($before|ConvertTo-Json -Compress)){throw 'Database identity changed during read group'}
 $script:receipt.databases_after=$after
 $stateAfter=Read-P02Rows $stateSql 1
 if(($stateAfter|ConvertTo-Json -Compress) -cne ($stateBefore|ConvertTo-Json -Compress)){throw 'Fixture generation or ownership changed during reads'}
 $script:receipt.state_after=$stateAfter
 $script:receipt.qualifies_installed_transition=$false
 $script:receipt.qualifies_configured_startup=$false
 $script:receipt.qualifies_return=$false
 $script:receipt.outcome='passed'
}catch{
 $script:receipt.outcome='failed';$script:receipt.first_failure=@{stage=$script:receipt.stage;type=$_.Exception.GetType().FullName;message=$_.Exception.Message}
}finally{
 Close-P02ReadinessConnection
 $stream=[IO.FileStream]::new($receiptPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$raw=[Text.UTF8Encoding]::new($false).GetBytes(($script:receipt|ConvertTo-Json -Depth 25));$stream.Write($raw,0,$raw.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
[pscustomobject]@{outcome=$script:receipt.outcome;receipt_sha256=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant();connection_closed=$script:receipt.connection_closed;physical_custody_retained=$script:receipt.physical_custody_retained}
