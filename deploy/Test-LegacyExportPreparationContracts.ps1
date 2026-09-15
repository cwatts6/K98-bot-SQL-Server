param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
# Static file inspection only. This script never connects to SQL Server.
$files = @(
 'migrations/20260914_002_legacy_export_preparation.sql',
 'sql_schema/dbo.ExportPreparation.Table.sql',
 'sql_schema/dbo.ExportPreparationResource.Table.sql',
 'sql_schema/dbo.ExportResource.Table.sql',
 'validation/kvk_source/s10c_legacy_export_preparation.sql'
)
foreach ($file in $files) {
 if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot $file))) { throw "Missing $file" }
}
$migration = Get-Content -Raw -LiteralPath (Join-Path $RepositoryRoot $files[0])
$resource = Get-Content -Raw -LiteralPath (Join-Path $RepositoryRoot $files[3])
foreach ($required in @('RequiresBackup: Yes','DataChange: No','Partial S10C','object type conflict','Forward Fix Only','WITH CHECK','XACT_STATE','ActivePreparationID','GenerationJson','SpoolHash','RequestHash')) {
 if (-not $migration.Contains($required)) { throw "Missing migration contract: $required" }
}
foreach ($required in @('ActiveJobID IS NULL AND ActivePreparationID IS NULL','ActiveJobID IS NOT NULL AND ActivePreparationID IS NULL','ActiveJobID IS NULL AND ActivePreparationID IS NOT NULL','FK_ExportResource_PreparationMembership')) {
 if (-not $resource.Contains($required)) { throw "Missing ownership contract: $required" }
}
if ($migration -match '(?im)^\s*(DELETE|TRUNCATE|DROP TABLE(?! #S10CInherited_ExportResource;)|UPDATE dbo\.)') { throw 'Unexpected application data mutation' }
# Compare complete reference CREATE bodies with the constant migration payload.
foreach ($snapshotPath in $files[1..2]) {
 $snapshot = Get-Content -Raw -LiteralPath (Join-Path $RepositoryRoot $snapshotPath)
 $body = $snapshot.Substring($snapshot.IndexOf('CREATE TABLE')).Trim().Replace("'", "''")
 $normalizedBody = [regex]::Replace($body, '\s+', ' ')
 $normalizedMigration = [regex]::Replace($migration, '\s+', ' ')
 if (-not $normalizedMigration.Contains($normalizedBody)) { throw "Snapshot/migration drift: $snapshotPath" }
}
foreach ($required in @('S10CPreparationContractSHA256','sys.columns','sys.check_constraints','sys.foreign_key_columns','sys.index_columns','is_not_trusted','is_disabled','is_nullable','filter_definition','schema signature missing or drifted')) {
 if (-not $migration.Contains($required)) { throw "Missing metadata drift check: $required" }
}
# Pin the inherited resource validator to accepted S10A source, not observed metadata.
$accepted = Get-Content -Raw -LiteralPath (Join-Path $RepositoryRoot 'migrations/20260914_001_shared_export_coordination.sql')
$start = $accepted.IndexOf('CREATE TABLE #S10A_ExportResource')
$end = $accepted.IndexOf('CREATE TABLE #S10A_ExportJobResource')
$expected = $accepted.Substring($start, $end - $start).Replace('S10A', 'S10CInherited')
if (-not ([regex]::Replace($migration, '\s+', ' ')).Contains([regex]::Replace($expected, '\s+', ' ').Trim())) { throw 'Inherited S10A expected resource shape drifted' }
foreach ($pair in @(
 @('-- EXCEPT in both directions', 'DECLARE @S10AFK TABLE'),
 @('IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name', 'DROP TABLE #S10A_ExportAttemptPart;')
)) {
 $start = $accepted.IndexOf($pair[0]); $end = $accepted.IndexOf($pair[1], $start)
 $expected = $accepted.Substring($start, $end-$start).Replace('S10A','S10CInherited').Replace('THROW 51000','THROW 51420')
 if (-not ([regex]::Replace($migration, '\s+', ' ')).Contains([regex]::Replace($expected, '\s+', ' ').Trim())) { throw 'Inherited S10A metadata validator drifted' }
}
if ($migration.IndexOf('CREATE TABLE #S10CInherited_ExportResource') -gt $migration.IndexOf("EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportPreparation")) { throw 'Inherited validation must precede all S10C schema changes' }
if (-not $migration.Contains("State<>''pending''") -or -not $migration.Contains('Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL')) { throw 'Preparation ownership/Actor contract missing' }
Write-Output 'S10C static preparation contracts passed. SQL was not executed.'
