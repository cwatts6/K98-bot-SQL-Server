# Offline regression for the exact Windows PowerShell 5.1 SqlClient file route.
param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
. (Join-Path $RepositoryRoot 'deploy/SqlDeploy.Common.ps1')
$script:opened=0;$script:texts=@()
function New-K98SqlConnection {
    param([string]$ServerName,[string]$DatabaseName)
    $connection=New-Object PSObject
    $connection|Add-Member ScriptMethod Open {$script:opened++}
    $connection|Add-Member ScriptMethod Dispose {}
    $connection|Add-Member ScriptMethod CreateCommand {
        $command=[pscustomobject]@{CommandText='';CommandTimeout=0}
        $command|Add-Member ScriptMethod ExecuteNonQuery {$script:texts+=,$this.CommandText;return 0}
        return $command
    }
    return $connection
}
$directory=Join-Path ([IO.Path]::GetTempPath()) ('K98SqlEncoding-'+[guid]::NewGuid().ToString())
$null=[IO.Directory]::CreateDirectory($directory)
$file=Join-Path $directory 'unicode.sql'
$value=[char]0x2192+[string][char]0x2705+[string][char]0x26a1
$sql="SELECT N'$value';"
$utf8=[Text.UTF8Encoding]::new($false,$true)
foreach($encoding in @($utf8,[Text.UTF8Encoding]::new($true,$true),[Text.UnicodeEncoding]::new($false,$true,$true))) {
    [IO.File]::WriteAllText($file,$sql,$encoding)
    $script:texts=@()
    Invoke-K98SqlFileWithSqlClient -ServerName inert -DatabaseName inert -InputFile $file
    if($script:texts.Count -ne 1 -or $script:texts[0] -cne $sql){throw 'SQL characters changed during file loading'}
}
$before=$script:opened
foreach($ending in @("`n","`r`n")) {
    $body="CREATE PROCEDURE dbo.Test AS SELECT N'first${ending}second$value';"
    $body="-- source header${ending}$body"
    $script:texts=@()
    [IO.File]::WriteAllText($file,($body+$ending+'GO -- boundary'+$ending+'SELECT 2;'),$utf8)
    Invoke-K98SqlFileWithSqlClient -ServerName inert -DatabaseName inert -InputFile $file
    if($script:texts.Count -ne 2 -or $script:texts[0] -cne $body -or $script:texts[1] -cne 'SELECT 2;'){throw 'SQL batch splitting changed literal line endings'}
}
$mixed="SELECT N'one`ntwo`r`nthree';`nSELECT 3;"
$script:texts=@()
[IO.File]::WriteAllText($file,$mixed,$utf8)
Invoke-K98SqlFileWithSqlClient -ServerName inert -DatabaseName inert -InputFile $file
if($script:texts.Count -ne 1 -or $script:texts[0] -cne $mixed){throw 'Mixed source terminators changed'}
$before=$script:opened
[IO.File]::WriteAllBytes($file,[byte[]]@(0xc3,0x28))
$rejected=$false
try {Invoke-K98SqlFileWithSqlClient -ServerName inert -DatabaseName inert -InputFile $file} catch {$rejected=$true}
if(-not $rejected -or $script:opened -ne $before){throw 'Invalid UTF-8 must fail before opening SQL'}
[IO.File]::Delete($file);[IO.Directory]::Delete($directory)
Write-Host 'PASS: UTF-8 with/without BOM, UTF-16 BOM, LF/CRLF/mixed literal preservation, GO boundaries and invalid-byte refusal; no SQL connection.'
