# Generated from reviewed SQL recovery sources. Windows PowerShell 5.1.
[CmdletBinding()]
param([switch]$Apply)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Apply) { throw 'Invoke with -Apply after review of this one-time recovery.' }
if ($env:COMPUTERNAME -cne 'MINI_AMD' -or $PSVersionTable.PSEdition -cne 'Desktop') { throw 'Use Windows PowerShell 5.1 on MINI_AMD.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if ($identity.User.Value -ne 'S-1-5-21-2970367362-111206357-3835881402-1001') { throw 'Use the existing MINI_AMD\cwatt operator account.' }
$policyPath = 'C:\ProgramData\K98\S11\runtime\61cb0acf-fb12-42da-9115-e5317952f190\AutomaticStartupPolicy.json'
if ((Get-Item -LiteralPath $policyPath).Length -gt 1MB -or
    (Get-FileHash -LiteralPath $policyPath).Hash -ne '7E9E29EF037F5E66443DE2872674D7363D58029F60532FBB73B935EAD51F34BE') { throw 'Installed policy differs. Do not change flags or restart.' }
$worker = @'
@@SQL@@
'@
function Convert-Hex([string]$Hex) {
    $bytes = New-Object byte[] ($Hex.Length / 2)
    for ($i=0; $i -lt $bytes.Length; $i++) { $bytes[$i]=[Convert]::ToByte($Hex.Substring($i*2,2),16) }
    return ,$bytes
}
$path = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('Downloads\S11-manual-stats-result-' + [guid]::NewGuid().ToString('N') + '.json')
$output = [IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
$result = [ordered]@{Stage='NOT_STARTED';RecoveryID='50a5b6e5-d1d0-49dc-bf04-ab566047e152';StartedUTC=[datetime]::UtcNow.ToString('o');Receipt=$null;Error=$null}
$connection=$null; $command=$null; $reader=$null; $failed=$false
try {
    $connection = [Data.SqlClient.SqlConnection]::new('Server=mini_AMD;Database=ROK_TRACKER;Integrated Security=True;Application Name=S11_ManualStats_Supersession;Connect Timeout=5;Encrypt=True;TrustServerCertificate=True')
    $connection.Open()
    $command=$connection.CreateCommand()
    $command.CommandTimeout=180
    $command.CommandText=$worker
    [void]$command.Parameters.Add('@ExpectedServer',[Data.SqlDbType]::NVarChar,128); $command.Parameters['@ExpectedServer'].Value='mini_AMD'
    [void]$command.Parameters.Add('@ExpectedDatabase',[Data.SqlDbType]::NVarChar,128); $command.Parameters['@ExpectedDatabase'].Value='ROK_TRACKER'
    [void]$command.Parameters.Add('@StatsHash',[Data.SqlDbType]::Binary,32); $command.Parameters['@StatsHash'].Value=Convert-Hex '@@STATS_HASH@@'
    [void]$command.Parameters.Add('@ImportLockHash',[Data.SqlDbType]::Binary,32); $command.Parameters['@ImportLockHash'].Value=Convert-Hex '@@LOCK_HASH@@'
    $result.Stage='OUTCOME_NOT_YET_CONFIRMED'
    $reader=$command.ExecuteReader()
    do {
        if ($reader.FieldCount -eq 3 -and $reader.GetName(0) -eq 'Status') {
            if (-not $reader.Read()) { throw 'Missing receipt row.' }
            $result.Stage=$reader.GetString(0)
            $result.Receipt=$reader.GetString(2) | ConvertFrom-Json
            if ($reader.Read()) { throw 'Unexpected multiple receipts.' }
        }
    } while ($reader.NextResult())
    if ($result.Stage -notin @('COMMITTED_MANUAL_SUPERSESSION','ALREADY_COMMITTED_NO_REPLAY')) { throw 'No authoritative commit receipt returned.' }
} catch {
    $failed=$true
    $result.Error=$_.Exception.Message
    # A timeout or disconnect does not prove rollback. Never automatically rerun.
    $result.Stage='STOPPED_REVIEW_DURABLE_RECEIPT'
} finally {
    if ($null -ne $reader) { $reader.Dispose() }
    if ($null -ne $command) { $command.Dispose() }
    if ($null -ne $connection) { $connection.Dispose() }
    $result['FinishedUTC']=[datetime]::UtcNow.ToString('o')
    try {
        $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($result | ConvertTo-Json -Depth 20))
        $output.Write($bytes,0,$bytes.Length); $output.Flush($true)
    } finally { $output.Dispose() }
}
Write-Host ('Evidence saved: ' + $path)
Write-Host ('Result: ' + $result.Stage)
if ($failed) { throw ('Recovery stopped: ' + $result.Error + '. Return the JSON; do not restart or perform a different recovery.') }
Write-Host 'Derived SQL stats refreshed and historical hold superseded. No restart, flag change, import or provider replay performed.'
Write-Host 'Return the JSON and next scheduled stats-refresh log for functional acceptance.'
