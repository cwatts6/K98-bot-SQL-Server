param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
. (Join-Path $RepositoryRoot 'deploy/ConfigurationPublication.Source.ps1')
$source=Get-Content -LiteralPath (Join-Path $RepositoryRoot 'deploy/export_stats_import_outcome_source.json') -Raw | ConvertFrom-Json
$modules=@($source.modules | Where-Object name -CEQ 'dbo.sp_TARGETS_MASTER')
if($modules.Count -ne 1){throw 'Exact atomic configuration module required'}
$module=$modules[0]
$text=[IO.File]::ReadAllText((Join-Path $RepositoryRoot $module.path)).Replace("`r`n","`n")
$null=Get-S11PreAtomicConfigurationSource $text
if($module.source_sha256 -cne '340bc1e888bec8638791b889d128a31c4028ae7546d6e8331093acd66a062b75' -or
 $module.definition_sha256 -cne '59f759eec2f7dd042e6f75ab235583d6addd0f9268ff290d8a517f4ca0ff85ff' -or
 @($module.compatible_definition_sha256).Count -ne 1 -or $module.compatible_definition_sha256[0] -cne '51e16f219eaf3967509bff8f730cce22783aab6838272595794af1e327667375') {throw 'Atomic configuration manifest differs'}
$start=$text.IndexOf('ALTER PROCEDURE [dbo].[sp_TARGETS_MASTER]',[StringComparison]::Ordinal)
if($start -lt 0){throw 'Atomic configuration declaration missing'}
$body=$text.Substring($start).Trim()+"`n"
$migration=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'migrations/20261016_002_atomic_configuration_publication.sql')).Replace("`r`n","`n")
if(-not $migration.Contains("DECLARE @Apply nvarchar(max)=N'"+$body.Replace("'","''")+"';")){throw 'Atomic configuration migration body differs'}
foreach($guard in @('sys.crypt_properties','IF XACT_STATE()<>0 ROLLBACK','52625','52626')) {
 if(-not $migration.Contains($guard)){throw ('Atomic configuration guard missing: '+$guard)}
}
Write-Output 'PASS: atomic configuration manifest, exact migration body and inverse historical source; no SQL connection.'
