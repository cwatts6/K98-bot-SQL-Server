param([Parameter(Mandatory)][string]$Database,[Parameter(Mandatory)][string]$Commit,[Parameter(Mandatory)][string]$Release)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:K98_D4_RELEASE_NATIVE -cne 'OWNED_LOCAL_METADATA_ONLY' -or $Database -cnotmatch '^K98_D4_ReleaseNative_[a-f0-9]{32}$'){throw 'Owned local fixture required'}
$root=Split-Path -Parent $PSScriptRoot
. "$root/deploy/SqlDeploy.ModuleRelease.ps1"
$id='20261111_001_p02_d4_combined'
$path=Join-Path $root ('migrations/'+$id+'.release.json')
$hash=Get-K98ModuleHash ([IO.File]::ReadAllBytes($path))
$loaded=Read-K98ModuleProfile $path $hash $id
$c=[Data.SqlClient.SqlConnection]::new(('Data Source=lpc:localhost\K98DEV;Initial Catalog='+$Database+';Integrated Security=true;Encrypt=true;TrustServerCertificate=true;Connect Timeout=5;Pooling=false'))
try {
 $c.Open()
 $rows=Invoke-K98ModuleQuery $c $null "SELECT @@SERVERNAME AS server_name,DB_NAME() AS db_name;"
 if($rows[0].server_name -cne '9SX2VF4\K98DEV' -or $rows[0].db_name -cne $Database){throw 'Wrong local fixture'}
 $null=Invoke-K98ModuleQuery $c $null @'
DECLARE @r int;
EXEC @r=sys.sp_getapplock @Resource=N'K98_Module_Release_v1',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
IF @r<0 THROW 51950,'Fixture release lock refused',1;
'@
 $state=Get-K98ModuleOutcome $c $loaded $hash $Commit $Release
 Write-Output ('OUTCOME:'+ $state)
}finally{$c.Dispose()}
