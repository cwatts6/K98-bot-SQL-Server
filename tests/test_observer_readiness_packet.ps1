param([Parameter(Mandatory=$true)][string]$CensusPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$entry=Join-Path $root 'qualification/p02_observer/release_readiness_read.ps1'
. $entry -Action Library
$passed=0
function Check([bool]$Value,[string]$Message){if(-not $Value){throw $Message};$script:passed++}
$source=Get-Content -LiteralPath $CensusPath -Raw -Encoding UTF8|ConvertFrom-Json
$script:receipt=@{}
$script:calls=0;$script:failAt=0
function Read-P02Rows([string]$Sql,[int]$Bound,[hashtable]$Parameters=@{},[int]$Timeout=5){
 $script:calls++
 if($script:failAt -eq $script:calls){throw 'first census failure'}
 if($Sql -like '*FROM KVK.KVK_AllPlayers_Raw WHERE KVK_NO>@after_kvk*'){return ,@([pscustomobject]@{KVK_NO=($Parameters.after_kvk+1)})}
 if($Sql -like '*FROM KVK.SeasonSource WHERE KVK_NO>0*'){return ,@(1..17|ForEach-Object {[pscustomobject]@{KVK_NO=$_}})}
 if($Sql -like '*FROM KVK.KVK_Scan*' -or $Sql -like '*FROM KVK.KVK_Windows*'){return ,@(1..65|ForEach-Object {[pscustomobject]@{KVK_NO=$Parameters.kvk_no;row=$_}})}
 return ,@()
}
$result=Invoke-P02LegacyCensus $source
Check ($script:calls -eq 98 -and $result.data_statements -eq 98) 'Census did not honour the exact finite query bound'
Check ($result.raw_seasons.Count -eq 16 -and $result.seasons.Count -eq 16) 'Candidate limit differs'
Check ($result.raw_truncated -and $result.source_truncated -and -not $result.complete) 'Truncation incorrectly reported complete'
Check (@($result.seasons|Where-Object {$_.scan_truncated -and $_.window_truncated}).Count -eq 16) 'Scan/window sentinels lost'
$script:calls=0;$script:failAt=3
try{$null=Invoke-P02LegacyCensus $source;throw 'failure was not raised'}catch{Check ($_.Exception.Message -ceq 'first census failure') 'First census error replaced'}
Check ($script:calls -eq 3 -and -not $script:receipt.census.complete -and $script:receipt.census.raw_seasons.Count -eq 2) 'Dispatch continued after failure or partial evidence lost'
# Exercise actual result-owner cleanup, with explicit external reader substitutes.
. $entry -Action Library
$script:receipt=@{statement_count=0;readers_closed=0;cleanup_failures=[Collections.Generic.List[string]]::new();physical_custody_retained=$false}
$script:testReader=[pscustomobject]@{FieldCount=0}
$script:testReader|Add-Member ScriptMethod Read {throw 'original reader failure'}
$script:testReader|Add-Member ScriptMethod Close {throw 'reader close failure'}
$script:testReader|Add-Member ScriptMethod Dispose {}
$script:testCommand=[pscustomobject]@{CommandText='';CommandTimeout=0}
$script:testCommand|Add-Member ScriptMethod ExecuteReader {return $script:testReader}
$script:commandDisposed=0
$script:testCommand|Add-Member ScriptMethod Dispose {$script:commandDisposed++}
$script:connection=[pscustomobject]@{}
$script:connection|Add-Member ScriptMethod CreateCommand {return $script:testCommand}
try{$null=Read-P02Rows 'SELECT 1;' 1;throw 'reader failure was not raised'}catch{Check ($_.Exception.Message -like '*original reader failure*') 'Cleanup replaced original read failure'}
Check ($script:receipt.physical_custody_retained -and $script:receipt.cleanup_failures.Count -eq 1 -and $script:receipt.statement_count -eq 1) 'Unconfirmed reader custody lost'
# Exercise the actual outer cleanup after unknown reader closure.
$script:connectionClosed=0;$script:connectionDisposed=0
$script:connection|Add-Member ScriptMethod Close {$script:connectionClosed++}
$script:connection|Add-Member ScriptMethod Dispose {$script:connectionDisposed++}
$global:P02ReadinessConnection=$script:connection
$script:receipt.connection_closed=$false;$script:receipt.outcome='failed'
Close-P02ReadinessConnection
Check ($script:commandDisposed -eq 0 -and $script:connectionClosed -eq 0 -and $script:connectionDisposed -eq 0) 'Cleanup released an uncertain physical owner'
Check ($null -ne $global:P02ReadinessReader -and $null -ne $global:P02ReadinessCommand -and $null -ne $global:P02ReadinessConnection -and -not $script:receipt.connection_closed) 'Physical handles were not retained'
# A settled owner may close; a failed connection close must remain held.
$script:receipt.physical_custody_retained=$false
Close-P02ReadinessConnection
Check ($script:connectionClosed -eq 1 -and $script:connectionDisposed -eq 1 -and $script:receipt.connection_closed -and $null -eq $global:P02ReadinessConnection) 'Settled owner did not close'
$script:connection|Add-Member ScriptMethod Close {throw 'connection close failure'} -Force
$global:P02ReadinessConnection=$script:connection
$script:receipt.connection_closed=$false
Close-P02ReadinessConnection
Check ($script:receipt.physical_custody_retained -and -not $script:receipt.connection_closed -and $null -ne $global:P02ReadinessConnection -and $script:connectionDisposed -eq 1) 'Failed connection closure was released'
Write-Output ('PASS: '+$passed+' bounded census and owner checks; external SQL substituted; no VM connection')
