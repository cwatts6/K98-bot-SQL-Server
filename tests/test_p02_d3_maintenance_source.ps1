param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$check=Join-Path $RepositoryRoot 'deploy/Test-P02D3MaintenanceSource.ps1'
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('k98-d3-source-'+[guid]::NewGuid().ToString('N'))
$source=Join-Path $fixture 'sql_schema'
$null=[IO.Directory]::CreateDirectory($source)
$names=@('dbo.MaintenanceWork.Table.sql','dbo.usp_MaintenanceDue.StoredProcedure.sql','dbo.usp_MaintenancePostImport.StoredProcedure.sql','dbo.usp_RunMaintenance.StoredProcedure.sql','dbo.usp_update_stats.StoredProcedure.sql','dbo.UPDATE_ALL2.StoredProcedure.sql','dbo.usp_MaintenanceImport.StoredProcedure.sql','dbo.CREATE_DELTA_TABLES.StoredProcedure.sql','dbo.MaintenanceConfigurationWork.Table.sql','dbo.usp_MaintenanceConfigurationDue.StoredProcedure.sql','dbo.usp_MaintenanceConfiguration.StoredProcedure.sql')
foreach($name in $names){Copy-Item -LiteralPath (Join-Path $RepositoryRoot "sql_schema/$name") -Destination $source}
& $check -RepositoryRoot $fixture
foreach($name in $names){
    $path=Join-Path $source $name
    $original=[IO.File]::ReadAllText($path)
    [IO.File]::WriteAllText($path,$original+"`n-- unreviewed fixture mutation`n")
    $refused=$false
    try { & $check -RepositoryRoot $fixture }
    catch { if($_.Exception.Message -like 'Unreviewed D3 maintenance source:*'){$refused=$true}else{throw} }
    finally { [IO.File]::WriteAllText($path,$original) }
    if(-not $refused){throw "D3 source mutation was admitted: $name"}
}
& $check -RepositoryRoot $fixture
Write-Output "PASS: all eleven D3 source mutations rejected; fixture retained at $fixture"
