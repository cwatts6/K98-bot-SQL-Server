[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Get-SqlSource {
    param([Parameter(Mandatory)][string]$RelativePath)
    return (Get-Content -Raw -LiteralPath (Join-Path $repoRoot $RelativePath)).Replace("`r`n", "`n")
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )
    if ($Source -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )
    if ($Source -match $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-Before {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$First,
        [Parameter(Mandatory)][string]$Second,
        [Parameter(Mandatory)][string]$Message
    )
    $firstIndex = $Source.IndexOf($First, [StringComparison]::Ordinal)
    $secondIndex = $Source.IndexOf($Second, [StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
        $failures.Add($Message)
    }
}

$header = Get-SqlSource 'sql_schema\dbo.KVK_Target_Publication.Table.sql'
$rows = Get-SqlSource 'sql_schema\dbo.KVK_Target_Publication_Row.Table.sql'
$view = Get-SqlSource 'sql_schema\dbo.v_KVK_TARGETS_FOR_BOT.View.sql'
$master = Get-SqlSource 'sql_schema\dbo.sp_TARGETS_MASTER.StoredProcedure.sql'
$delta = Get-SqlSource 'sql_schema\dbo.CREATE_DELTA_TABLES.StoredProcedure.sql'
$updateAll = Get-SqlSource 'sql_schema\dbo.UPDATE_ALL.StoredProcedure.sql'
$loop = Get-SqlSource 'sql_schema\dbo.sp_Loop_ExcelOutput_ByKVK.StoredProcedure.sql'
$migration = Get-SqlSource 'migrations\20260825_001_kvk_target_publication_provenance.sql'
$deltaMigration = Get-SqlSource 'migrations\20260826_001_serialize_delta_preprocessing.sql'

foreach ($column in @(
    'PublicationState',
    'SourceScanOrder',
    'SourceScanType',
    'ConfiguredDraftScan',
    'ConfiguredMatchmakingScan',
    'PublishedAtUtc',
    'TargetRowCount',
    'OutputObjectName',
    'PublicationVersion',
    'PublicationSignature'
)) {
    Assert-Contains $header ([regex]::Escape($column)) "Publication header must contain $column."
    Assert-Contains $view ([regex]::Escape($column)) "Bot view must expose $column."
}

Assert-Contains $header 'UX_KVK_Target_Publication_Current' 'Publication header must enforce one current publication per KVK.'
Assert-Contains $header "PublicationState\s*=\s*N'OFFICIAL'[\s\S]+SourceScanType\s*=\s*N'MATCHMAKING_SCAN'[\s\S]+SourceScanOrder\s*=\s*ConfiguredMatchmakingScan" 'Official metadata must prove the exact configured matchmaking scan.'
Assert-Contains $header "OutputObjectName\s*=\s*[\s\r\n]*N'dbo\.EXCEL_EXPORT_KVK_TARGETS_'\s*\+\s*CONVERT\(nvarchar\(20\),\s*KVK_NO\)" 'Publication output identity must match its KVK.'
Assert-Contains $rows 'FOREIGN KEY\s*\(PublicationId\)[\s\S]+REFERENCES dbo\.KVK_Target_Publication' 'Publication rows must be bound to a durable header.'
Assert-Contains $rows 'PRIMARY KEY CLUSTERED\s*\(PublicationId, GovernorID\)' 'Publication rows must reject duplicate Governor IDs.'
foreach ($column in @('KillTarget', 'MinimumKillTarget', 'DeadTarget', 'DKPTarget')) {
    Assert-Contains $rows ("{0}\s+int\s+NULL" -f $column) "Publication rows must preserve nullable $column values."
}
Assert-Contains $view 'WHERE p\.IsCurrent = 1' 'Bot view must expose current publications only.'
Assert-Contains $view 'CREATE OR ALTER VIEW dbo\.v_KVK_TARGETS_FOR_BOT' 'Canonical bot view must be safely re-runnable.'
Assert-NotContains $view 'IF OBJECT_ID|sp_executesql' 'Canonical bot view must not retain first-deployment-only creation guards.'
Assert-NotContains $view 'v_TARGETS_FOR_UPLOAD' 'Bot view must not depend on the mutable legacy pointer.'
Assert-NotContains $view 'ForcedRepublish|RepublishReason|PublishedBy' 'Bot view must not expose operator-only publication audit fields.'

Assert-Contains $master '@ForceRepublish\s+\[bit\]\s*=\s*0' 'Force-republish must default off.'
Assert-Contains $master '@RepublishReason\s+\[nvarchar\]\(400\)\s*=\s*NULL' 'Force-republish must carry an operator reason.'
Assert-Contains $master '@ForceRepublish = 1 AND @RequestedKVK IS NULL' 'Force-republish must require one explicit KVK.'
Assert-Contains $master '@ForceRepublish = 1 AND @MatchedKVKCount <> 1' 'Force-republish must fail if the requested KVK is not configured.'
Assert-Contains $master "@ForceRepublish = 1[\s\S]+NOT EXISTS[\s\S]+FROM dbo\.ProcConfig[\s\S]+KVKVersion = @RequestedKVK" 'Invalid forced KVKs must fail before target helper processing.'
Assert-Before $master 'could not resolve the requested KVK before force-republish processing' 'EXEC dbo.CREATE_DELTA_TABLES' 'Force-republish KVK validation must occur before shared helper work.'
Assert-Contains $master '@CurrentKVK IS NULL OR @CurrentKVK <= 0' 'Full refresh must reject invalid configured KVK identities.'
Assert-Contains $master 'IF @@TRANCOUNT <> 0[\s\S]+must own its publication transaction[\s\S]+RETURN' 'Publication must reject an ambient caller transaction without retaining a transaction-owned applock.'
Assert-Before $master 'IF @@TRANCOUNT <> 0' 'EXEC dbo.CREATE_DELTA_TABLES' 'Ambient transaction rejection must occur before shared helper work.'
Assert-NotContains $master 'SAVE TRANSACTION KVKTargetPublicationSave|@StartedTransaction|@InitialTranCount' 'Publication must not retain a transaction-owned applock in a caller transaction.'
Assert-Contains $master 'sys\.sp_getapplock' 'Publication must use a cross-session KVK mutex.'
Assert-Contains $master "K98:TargetPublication:DeltaPreprocessing[\s\S]+@LockOwner = N'Session'" 'Shared delta preprocessing must use a global session-owned mutex.'
Assert-Before $master 'K98:TargetPublication:DeltaPreprocessing' 'EXEC dbo.CREATE_DELTA_TABLES' 'Shared delta preprocessing must acquire its mutex before helper execution.'
Assert-Contains $master "EXEC dbo\.CREATE_DELTA_TABLES;[\s\S]+sys\.sp_releaseapplock[\s\S]+@LockOwner = N'Session'" 'Shared delta preprocessing must release its session mutex after helper execution.'
Assert-Contains $delta "K98:TargetPublication:DeltaPreprocessing[\s\S]+@LockOwner = N'Session'" 'The shared delta helper must own the global session mutex used by every caller.'
Assert-Before $delta 'K98:TargetPublication:DeltaPreprocessing' 'SELECT @LastProcessedScan' 'The shared delta helper must acquire its mutex before reading the shared high-water mark.'
Assert-Contains $delta "COMMIT TRANSACTION;[\s\S]+sys\.sp_releaseapplock[\s\S]+@LockOwner = N'Session'" 'The shared delta helper must retain the mutex through its delta-table commit.'
Assert-Contains $delta "BEGIN CATCH[\s\S]+@DeltaPreprocessingLockHeld = 1[\s\S]+sys\.sp_releaseapplock[\s\S]+THROW" 'The shared delta helper must release its mutex and rethrow catchable failures.'
Assert-Before $delta 'sys.sp_releaseapplock' '-- Step 6: LIGHTWEIGHT MAINTENANCE' 'The shared delta helper must release its mutex before optional maintenance.'
foreach ($caller in @(
    @{ Source = $master; Name = 'sp_TARGETS_MASTER' },
    @{ Source = $updateAll; Name = 'UPDATE_ALL' },
    @{ Source = $loop; Name = 'sp_Loop_ExcelOutput_ByKVK' }
)) {
    Assert-Contains $caller.Source '(?i)EXEC\s+(?:dbo\.)?CREATE_DELTA_TABLES' "$($caller.Name) must continue to route delta preprocessing through the mutex-owning helper."
}
Assert-Contains $master "SET @SourceScanType = N'MATCHMAKING_SCAN'" 'The master procedure must persist the matchmaking source branch.'
Assert-Contains $master "SET @SourceScanType = N'DRAFTSCAN'" 'The master procedure must persist the draft source branch.'
Assert-Contains $master 'WHERE ScanOrder = @Scan' 'The master procedure must validate the exact selected scan.'
Assert-Before $master 'WHERE ScanOrder = @Scan' 'EXEC dbo.sp_Prep_TargetTable' 'Exact source rows must be proved before destructive target generation.'
Assert-Contains $master "@CurrentPublicationState = N'OFFICIAL'[\s\S]+@ForceRepublish = 0" 'Routine processing must detect an existing Official publication.'
Assert-Contains $master "Official targets already published[\s\S]+EXEC dbo\.sp_ExcelOutput_ByKVK[\s\S]+SET @ShouldProcess = 0" 'Routine processing must preserve combat output refreshes while skipping target publication.'
Assert-Contains $master 'ISNULL\(@TargetRowCount, 0\) <= 0' 'Publication must reject an empty output.'
Assert-NotContains $master 'OR \[Kill Target\] IS NULL|OR \[Minimum Kill Target\] IS NULL|OR \[Dead Target\] IS NULL|OR \[DKP Target\] IS NULL' 'Publication must preserve rows whose target amounts are not set.'
Assert-Contains $master "refused target rows with invalid identity or target values[\s\S]+SET ANSI_WARNINGS ON;[\s\S]+SET ANSI_PADDING ON;[\s\S]+SET ARITHABORT ON;[\s\S]+SET CONCAT_NULL_YIELDS_NULL ON;[\s\S]+SET NUMERIC_ROUNDABORT OFF;[\s\S]+INSERT dbo\.KVK_Target_Publication" 'Filtered-index-safe SET options must be enabled before publication writes.'
Assert-Contains $master 'INSERT dbo\.KVK_Target_Publication_Row' 'Publication must copy immutable bot-facing rows.'
Assert-Before $master 'INSERT dbo.KVK_Target_Publication_Row' 'SET IsCurrent = 1' 'Rows must be copied before a publication becomes current.'
Assert-Contains $master 'CREATE OR ALTER VIEW dbo\.v_TARGETS_FOR_UPLOAD' 'The legacy pointer must be replaced without a drop/create gap.'
Assert-NotContains $master 'DROP VIEW dbo\.v_TARGETS_FOR_UPLOAD' 'The master procedure must not drop the legacy pointer.'
Assert-NotContains $master 'SELECT @LatestKVK = MAX' 'The legacy pointer must not be selected from the highest table suffix.'
Assert-Contains $master 'dbo\.v_KVK_TARGETS_FOR_BOT[\s\S]+PublicationSignature = @PublicationSignature' 'The committed bot view must be validated against the new publication identity.'

$procedureMarker = 'ALTER PROCEDURE'
$procedureStart = $master.IndexOf($procedureMarker, [StringComparison]::Ordinal)
if ($procedureStart -lt 0) {
    $failures.Add('Canonical master procedure has no ALTER PROCEDURE marker.')
}
else {
    $expectedMigrationProcedure = $master.Substring($procedureStart)
    $expectedMigrationProcedure =
        'CREATE OR ALTER PROCEDURE' + $expectedMigrationProcedure.Substring($procedureMarker.Length)
    if (-not $migration.Contains($expectedMigrationProcedure)) {
        $failures.Add('Migration copy of sp_TARGETS_MASTER is not identical to the canonical schema snapshot.')
    }
}

$deltaProcedureMarker = 'ALTER PROCEDURE'
$deltaProcedureStart = $delta.IndexOf($deltaProcedureMarker, [StringComparison]::Ordinal)
if ($deltaProcedureStart -lt 0) {
    $failures.Add('Canonical delta procedure has no ALTER PROCEDURE marker.')
}
else {
    $expectedDeltaMigrationProcedure = $delta.Substring($deltaProcedureStart)
    $expectedDeltaMigrationProcedure =
        'CREATE OR ALTER PROCEDURE' + $expectedDeltaMigrationProcedure.Substring($deltaProcedureMarker.Length)
    if (-not $deltaMigration.Contains($expectedDeltaMigrationProcedure)) {
        $failures.Add('Delta mutex migration copy is not identical to the canonical CREATE_DELTA_TABLES schema snapshot.')
    }
}

Assert-Contains $migration 'Rollback:\s+Manual' 'Migration must retain the approved manual rollback posture.'
Assert-Contains $migration 'DataChange:\s+No' 'Schema deployment must not silently publish or backfill a KVK.'
Assert-Contains $migration 'BEGIN TRANSACTION' 'Migration must deploy the contract transactionally.'
Assert-Contains $migration 'Current-KVK publication is a separate' 'Migration must document the SQL-first explicit publication step.'
Assert-Contains $migration 'is_not_trusted = 0' 'Migration post-validation must prove its integrity constraints are trusted.'
Assert-Contains $migration "COUNT\(\*\)[\s\S]+dbo\.v_KVK_TARGETS_FOR_BOT[\s\S]+<> 20" 'Migration post-validation must prove the exact bot-view column count.'
Assert-Contains $deltaMigration 'Rollback:\s+Manual' 'Delta mutex migration must retain a manual rollback posture.'
Assert-Contains $deltaMigration 'DataChange:\s+No' 'Delta mutex deployment must not modify existing rows.'
Assert-Contains $deltaMigration 'Do not run delta processing or target publication between the two KVK publication migrations' 'Delta mutex migration must document the no-processing deployment boundary.'
Assert-Contains $deltaMigration "OBJECT_DEFINITION[\s\S]+K98:TargetPublication:DeltaPreprocessing" 'Delta mutex migration must verify the deployed helper owns the shared lock.'
foreach ($setOption in @(
    'SET ANSI_NULLS ON;',
    'SET QUOTED_IDENTIFIER ON;',
    'SET ANSI_WARNINGS ON;',
    'SET ANSI_PADDING ON;',
    'SET ARITHABORT ON;',
    'SET CONCAT_NULL_YIELDS_NULL ON;',
    'SET NUMERIC_ROUNDABORT OFF;'
)) {
    Assert-Before $header $setOption 'CREATE UNIQUE NONCLUSTERED INDEX UX_KVK_Target_Publication_Current' "Canonical publication table must set $setOption before creating the filtered index."
    Assert-Before $migration $setOption 'CREATE UNIQUE NONCLUSTERED INDEX UX_KVK_Target_Publication_Current' "Migration must set $setOption before creating the filtered index."
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'KVK target publication contract checks passed.'
