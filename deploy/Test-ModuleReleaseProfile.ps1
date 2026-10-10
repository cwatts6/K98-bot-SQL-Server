# Offline profile admission tests using the production reader; no SQL connection.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot\SqlDeploy.ModuleRelease.ps1"
$root=Join-Path ([IO.Path]::GetTempPath()) ('k98-module-profile-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root)
$checks=0
$mid='20261010_901_fixture'
$good="CREATE OR ALTER PROCEDURE [dbo].[Fixture]`nAS SELECT N'example';`n"
foreach($damage in @('none','hash','go','sqlcmd','encryption','external','traversal','duplicate','force','profile','before','identifier')) {
 $text=$good
 $p=[ordered]@{version=1;profile='module_grants_v1';migration_id=$mid;database_collation='Latin1_General_CI_AS';tempdb_collation='SQL_Latin1_General_CP1_CI_AS';compatibility_level=160;modules=@([ordered]@{schema='dbo';name='Fixture';type='P';before_sha256=('a'*64);file='fixture.sql';sha256=''});grants=@();requires=@()}
 switch($damage){
  'go'{$text+="GO`nSELECT 1;"}
  'sqlcmd'{$text+="`n:r other.sql"}
  'encryption'{$text=$text.Replace('AS SELECT','WITH ENCRYPTION AS SELECT')}
  'external'{$text=$text.Replace('AS SELECT', 'AS EXTERNAL NAME')}
  'traversal'{$p.modules[0].file='../fixture.sql'}
  'duplicate'{$p.modules+= $p.modules[0]}
  'force'{$p.force=$true}
  'profile'{$p.profile='arbitrary_sql'}
  'before'{$p.modules[0].before_sha256='observed'}
  'identifier'{$p.modules[0].name='Fixture];SELECT 1;--'}
 }
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes($text)
 [IO.File]::WriteAllBytes((Join-Path $root 'fixture.sql'),$bytes)
 $p.modules[0].sha256=Get-K98ModuleHash $bytes
 if($damage -eq 'hash'){$p.modules[0].sha256='f'*64}
 $raw=[Text.UTF8Encoding]::new($false).GetBytes(($p|ConvertTo-Json -Depth 10 -Compress))
 $path=Join-Path $root ($mid+'.release.json');[IO.File]::WriteAllBytes($path,$raw)
 $failed=$false;try{$null=Read-K98ModuleProfile $path (Get-K98ModuleHash $raw) $mid}catch{$failed=$true}
 if($failed -ne ($damage -ne 'none')){throw ('Profile admission differs: '+$damage)}
 $checks++
}
@{status='PASS';checks=$checks;sql_connected=$false;fixture=$root}|ConvertTo-Json -Compress
