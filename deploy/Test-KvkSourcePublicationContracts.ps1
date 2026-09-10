[CmdletBinding()]
param([string]$RepoPath = (Split-Path -Parent $PSScriptRoot))
# Offline text contract only. No SQL connection, script evaluation or log writes.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
$failures = [System.Collections.Generic.List[string]]::new()
$checks = 0
function Read-Source([string]$Path) {
    return (Get-Content -Raw -LiteralPath (Join-Path $repoRoot $Path)).Replace("`r`n", "`n")
}
function Assert-Contract([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { $failures.Add($Message) }
}
function Executable-Text([string]$Source) {
    return (($Source -replace '(?s)/\*.*?\*/', '') -replace '(?m)--[^\n]*', '')
}
$migration = Read-Source 'migrations/20260910_001_kvk_source_publication_state.sql'
$fixture = Read-Source 'validation/kvk_source/publication_constraints.sql'
$ddl = Executable-Text $migration
$names = @('SourceConfigVersion','SourcePeriod','SourceWindowConfig','SourceCampConfig','SourceWeightConfig','SourceScanBinding','SourceConfigRequest','SourcePublication','SourcePlayerResult','SourceSelection','SourceRouting','SourceAction','SourceDelivery')
$creates = [regex]::Matches($ddl, '(?i)CREATE\s+TABLE\s+KVK\.(\w+)')
Assert-Contract ($creates.Count -eq 13) 'Exactly thirteen state tables are required.'
Assert-Contract ((@($creates | ForEach-Object { $_.Groups[1].Value } | Sort-Object) -join ',') -ceq (($names | Sort-Object) -join ',')) 'Table manifest mismatch.'
foreach ($name in $names) {
    $snapshot = Read-Source "sql_schema/KVK.$name.Table.sql"
    $start = $snapshot.IndexOf("CREATE TABLE KVK.$name`n", [StringComparison]::Ordinal)
    $end = $snapshot.IndexOf("`n);", $start, [StringComparison]::Ordinal)
    Assert-Contract ($start -ge 0 -and $end -gt $start) "$name lacks table body."
    if ($start -ge 0 -and $end -gt $start) {
        Assert-Contract ($migration.Contains($snapshot.Substring($start, $end + 3 - $start))) "$name snapshot/migration differs."
    }
    foreach ($token in @('SET ANSI_NULLS ON;', 'SET QUOTED_IDENTIFIER ON;', "CONSTRAINT PK_$name PRIMARY KEY", 'SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL', "SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0")) {
        Assert-Contract ($snapshot.Contains($token)) "$name missing $token"
    }
    foreach ($link in [regex]::Matches($snapshot, '(?m)^ALTER TABLE[^\n]+;|^CREATE INDEX[^\n]+;')) {
        Assert-Contract ($migration.Contains($link.Value)) "$name link/index differs."
    }
    Assert-Contract ($migration.Contains("IF OBJECT_ID(N'KVK.$name') IS NOT NULL")) "$name collision guard missing."
    Assert-Contract ($fixture.Contains("Synthetic rows survived rollback: $name")) "$name rollback check missing."
}
Assert-Contract ($ddl -notmatch '(?i)\b(FLOAT|REAL|IDENTITY|TRIGGER|PROCEDURE|FUNCTION|GRANT|TRUNCATE|DROP|DELETE|INSERT|UPDATE|ProcConfig|SCANORDER|KVK_Scan|CASCADE|NOCHECK)\b') 'Migration crosses forbidden runtime/legacy/data/permission boundary.'
Assert-Contract ([regex]::Matches($ddl, '(?i)\bDEFAULT\b').Count -eq 1) 'Only disabled routing may have a default.'
Assert-Contract ($ddl.Contains('CONSTRAINT DF_SourceRouting_Enabled DEFAULT (0)')) 'Routing must default disabled.'
Assert-Contract ($ddl -notmatch '(?im)^\s*GO\s*$') 'Migration must remain one atomic batch.'
Assert-Contract ($ddl.Contains('IF @S2BOwnTransaction = 1 BEGIN TRANSACTION;')) 'Explicit transaction required.'
Assert-Contract ($ddl.Contains('IF @S2BOwnTransaction = 1 COMMIT TRANSACTION;')) 'Outer transaction must not be committed.'
Assert-Contract ($ddl.Contains('IF @S2BOwnTransaction = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;')) 'Owned failure rollback required.'
Assert-Contract ($ddl.Contains('KVK.SourceAggregateReport WITH (TABLOCKX, HOLDLOCK)')) 'Orphan gate must prevent concurrent family insertion.'
$aggregate = Read-Source 'sql_schema/KVK.SourceAggregateReport.Table.sql'
$periodLink = [regex]::Match($aggregate, '(?m)^ALTER TABLE KVK.SourceAggregateReport WITH CHECK ADD CONSTRAINT FK_SourceAggregateReport_Period[^\n]+;').Value
Assert-Contract ($periodLink.Length -gt 0 -and $ddl.Contains($periodLink)) 'Trusted same-source/KVK/period/kind FK missing.'
Assert-Contract ($periodLink.Contains('(SourceKey, KVK_NO, PeriodKey, PeriodKind)')) 'Aggregate period scope mismatch.'
$source = Read-Source 'sql_schema/KVK.SourceConfigVersion.Table.sql'
Assert-Contract ($source.Contains('RosterID')) 'SourceConfigVersion: required contract missing'
Assert-Contract ($source.Contains('WindowDigest binary(32)')) 'SourceConfigVersion: required contract missing'
Assert-Contract ($source.Contains('MappingDigest binary(32)')) 'SourceConfigVersion: required contract missing'
Assert-Contract ($source.Contains('WeightDigest binary(32)')) 'SourceConfigVersion: required contract missing'
Assert-Contract ($source.Contains('ProvenanceJson')) 'SourceConfigVersion: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourceWindowConfig.Table.sql'
Assert-Contract ($source.Contains('WindowName nvarchar(40)')) 'SourceWindowConfig: required contract missing'
Assert-Contract ($source.Contains('WindowSeq tinyint NULL')) 'SourceWindowConfig: required contract missing'
Assert-Contract ($source.Contains('StartScanID int NULL')) 'SourceWindowConfig: required contract missing'
Assert-Contract ($source.Contains('EndScanID int NULL')) 'SourceWindowConfig: required contract missing'
Assert-Contract ($source.Contains('Notes nvarchar(200)')) 'SourceWindowConfig: required contract missing'
Assert-Contract ($source.Contains('UpdatedAtUTC datetime2(0)')) 'SourceWindowConfig: required contract missing'
Assert-Contract ($source.Contains('FK_SourceWindowConfig_Period')) 'SourceWindowConfig: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourceCampConfig.Table.sql'
Assert-Contract ($source.Contains('Kingdom int NOT NULL')) 'SourceCampConfig: required contract missing'
Assert-Contract ($source.Contains('CampID tinyint NOT NULL')) 'SourceCampConfig: required contract missing'
Assert-Contract ($source.Contains('CampName nvarchar(40)')) 'SourceCampConfig: required contract missing'
Assert-Contract ($source.Contains('CampKey nvarchar(128)')) 'SourceCampConfig: required contract missing'
Assert-Contract ($source.Contains('CampID BETWEEN 1 AND 8')) 'SourceCampConfig: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourceWeightConfig.Table.sql'
Assert-Contract ($source.Contains('WeightT4X decimal(38,12)')) 'SourceWeightConfig: required contract missing'
Assert-Contract ($source.Contains('WeightT5Y decimal(38,12)')) 'SourceWeightConfig: required contract missing'
Assert-Contract ($source.Contains('WeightDeadsZ decimal(38,12)')) 'SourceWeightConfig: required contract missing'
Assert-Contract ($source.Contains('WeightT4XSource varchar(128)')) 'SourceWeightConfig: required contract missing'
Assert-Contract ($source.Contains('WeightT5YSource varchar(128)')) 'SourceWeightConfig: required contract missing'
Assert-Contract ($source.Contains('WeightDeadsZSource varchar(128)')) 'SourceWeightConfig: required contract missing'
Assert-Contract ($source.Contains('EffectiveFromUTC datetime2(0)')) 'SourceWeightConfig: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourceScanBinding.Table.sql'
Assert-Contract ($source.Contains('PRIMARY KEY (ConfigVersionID, LogicalScanID)')) 'SourceScanBinding: required contract missing'
Assert-Contract ($source.Contains('FOREIGN KEY (SourceKey, KVK_NO, LogicalScanID) REFERENCES KVK.SourceLogicalScan')) 'SourceScanBinding: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourceConfigRequest.Table.sql'
Assert-Contract ($source.Contains('UNIQUE (SourceKey, KVK_NO, ConfigContentHash, BaseConfigVersionID)')) 'SourceConfigRequest: required contract missing'
Assert-Contract ($source.Contains('OldEndScanID int NULL')) 'SourceConfigRequest: required contract missing'
Assert-Contract ($source.Contains('NewEndScanID int NULL')) 'SourceConfigRequest: required contract missing'
Assert-Contract ($source.Contains('DesiredConfigVersionID')) 'SourceConfigRequest: required contract missing'
Assert-Contract ($source.Contains('FK_SourceConfigRequest_Applied')) 'SourceConfigRequest: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourcePublication.Table.sql'
Assert-Contract ($source.Contains('UNIQUE (SourceKey, KVK_NO, PeriodID, Generation)')) 'SourcePublication: required contract missing'
Assert-Contract ($source.Contains('FK_SourcePublication_ConfigRoster')) 'SourcePublication: required contract missing'
Assert-Contract ($source.Contains('FK_SourcePublication_StartRevision')) 'SourcePublication: required contract missing'
Assert-Contract ($source.Contains('FK_SourcePublication_EndRevision')) 'SourcePublication: required contract missing'
Assert-Contract ($source.Contains('FK_SourcePublication_Aggregate')) 'SourcePublication: required contract missing'
Assert-Contract ($source.Contains('ManifestHash IS NOT NULL')) 'SourcePublication: required contract missing'
Assert-Contract ($source.Contains('ResultCount = EligibleCount')) 'SourcePublication: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourcePlayerResult.Table.sql'
Assert-Contract ($source.Contains('FK_SourcePlayerResult_Eligible')) 'SourcePlayerResult: required contract missing'
Assert-Contract ($source.Contains('FK_SourcePlayerResult_Camp')) 'SourcePlayerResult: required contract missing'
Assert-Contract ($source.Contains('dkp decimal(38,6) NULL')) 'SourcePlayerResult: required contract missing'
Assert-Contract ($source.Contains('FieldStatusJson nvarchar(4000) COLLATE Latin1_General_100_BIN2')) 'SourcePlayerResult: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourceSelection.Table.sql'
Assert-Contract ($source.Contains('PRIMARY KEY (SourceKey, KVK_NO, PeriodID)')) 'SourceSelection: required contract missing'
Assert-Contract ($source.Contains('FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PublicationID)')) 'SourceSelection: required contract missing'
Assert-Contract ($source.Contains('SelectionVersion > 0')) 'SourceSelection: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourceAction.Table.sql'
Assert-Contract ($source.Contains('NewSelectionVersion > ExpectedSelectionVersion')) 'SourceAction: required contract missing'
Assert-Contract ($source.Contains('FK_SourceAction_Old')) 'SourceAction: required contract missing'
Assert-Contract ($source.Contains('FK_SourceAction_New')) 'SourceAction: required contract missing'
Assert-Contract ($source.Contains('ProvenanceJson')) 'SourceAction: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourceDelivery.Table.sql'
Assert-Contract ($source.Contains('PRIMARY KEY (PublicationID, DestinationKind, DestinationID)')) 'SourceDelivery: required contract missing'
Assert-Contract ($source.Contains('OwnerID uniqueidentifier NULL')) 'SourceDelivery: required contract missing'
Assert-Contract ($source.Contains('Fence bigint NOT NULL')) 'SourceDelivery: required contract missing'
Assert-Contract ($source.Contains('Receipt nvarchar(1024) NULL')) 'SourceDelivery: required contract missing'
Assert-Contract ($source.Contains('''uncertain''')) 'SourceDelivery: required contract missing'
Assert-Contract ($source.Contains('ConfirmedUTC IS NOT NULL')) 'SourceDelivery: required contract missing'
$source = Read-Source 'sql_schema/KVK.SourcePlayerResult.Table.sql'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.starting_power'') IS NOT NULL')) 'starting_power: status/rank contract missing'
Assert-Contract ($source.Contains('starting_power_rank <= starting_power_cohort')) 'starting_power: status/rank contract missing'
Assert-Contract ($source.Contains('starting_power_cohort <= 50000')) 'starting_power: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.power'') IS NOT NULL')) 'power: status/rank contract missing'
Assert-Contract ($source.Contains('power_rank <= power_cohort')) 'power: status/rank contract missing'
Assert-Contract ($source.Contains('power_cohort <= 50000')) 'power: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.troops_power'') IS NOT NULL')) 'troops_power: status/rank contract missing'
Assert-Contract ($source.Contains('troops_power_rank <= troops_power_cohort')) 'troops_power: status/rank contract missing'
Assert-Contract ($source.Contains('troops_power_cohort <= 50000')) 'troops_power: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.t1_kills'') IS NOT NULL')) 't1_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t1_kills_rank <= t1_kills_cohort')) 't1_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t1_kills_cohort <= 50000')) 't1_kills: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.t2_kills'') IS NOT NULL')) 't2_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t2_kills_rank <= t2_kills_cohort')) 't2_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t2_kills_cohort <= 50000')) 't2_kills: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.t3_kills'') IS NOT NULL')) 't3_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t3_kills_rank <= t3_kills_cohort')) 't3_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t3_kills_cohort <= 50000')) 't3_kills: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.t4_kills'') IS NOT NULL')) 't4_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t4_kills_rank <= t4_kills_cohort')) 't4_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t4_kills_cohort <= 50000')) 't4_kills: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.t5_kills'') IS NOT NULL')) 't5_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t5_kills_rank <= t5_kills_cohort')) 't5_kills: status/rank contract missing'
Assert-Contract ($source.Contains('t5_kills_cohort <= 50000')) 't5_kills: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.total_kill_points'') IS NOT NULL')) 'total_kill_points: status/rank contract missing'
Assert-Contract ($source.Contains('total_kill_points_rank <= total_kill_points_cohort')) 'total_kill_points: status/rank contract missing'
Assert-Contract ($source.Contains('total_kill_points_cohort <= 50000')) 'total_kill_points: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.dead'') IS NOT NULL')) 'dead: status/rank contract missing'
Assert-Contract ($source.Contains('dead_rank <= dead_cohort')) 'dead: status/rank contract missing'
Assert-Contract ($source.Contains('dead_cohort <= 50000')) 'dead: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.healed'') IS NOT NULL')) 'healed: status/rank contract missing'
Assert-Contract ($source.Contains('healed_rank <= healed_cohort')) 'healed: status/rank contract missing'
Assert-Contract ($source.Contains('healed_cohort <= 50000')) 'healed: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.acclaim'') IS NOT NULL')) 'acclaim: status/rank contract missing'
Assert-Contract ($source.Contains('acclaim_rank <= acclaim_cohort')) 'acclaim: status/rank contract missing'
Assert-Contract ($source.Contains('acclaim_cohort <= 50000')) 'acclaim: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.highest_acclaim'') IS NOT NULL')) 'highest_acclaim: status/rank contract missing'
Assert-Contract ($source.Contains('highest_acclaim_rank <= highest_acclaim_cohort')) 'highest_acclaim: status/rank contract missing'
Assert-Contract ($source.Contains('highest_acclaim_cohort <= 50000')) 'highest_acclaim: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.kp_t4_t5'') IS NOT NULL')) 'kp_t4_t5: status/rank contract missing'
Assert-Contract ($source.Contains('kp_t4_t5_rank <= kp_t4_t5_cohort')) 'kp_t4_t5: status/rank contract missing'
Assert-Contract ($source.Contains('kp_t4_t5_cohort <= 50000')) 'kp_t4_t5: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.dkp'') IS NOT NULL')) 'dkp: status/rank contract missing'
Assert-Contract ($source.Contains('dkp_rank <= dkp_cohort')) 'dkp: status/rank contract missing'
Assert-Contract ($source.Contains('dkp_cohort <= 50000')) 'dkp: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.healed_points'') IS NOT NULL')) 'healed_points: status/rank contract missing'
Assert-Contract ($source.Contains('healed_points_rank <= healed_points_cohort')) 'healed_points: status/rank contract missing'
Assert-Contract ($source.Contains('healed_points_cohort <= 50000')) 'healed_points: status/rank contract missing'
Assert-Contract ($source.Contains('JSON_VALUE(FieldStatusJson, ''$.dkp_power_ratio'') IS NOT NULL')) 'dkp_power_ratio: status/rank contract missing'
Assert-Contract ($source.Contains('dkp_power_ratio_rank <= dkp_power_ratio_cohort')) 'dkp_power_ratio: status/rank contract missing'
Assert-Contract ($source.Contains('dkp_power_ratio_cohort <= 50000')) 'dkp_power_ratio: status/rank contract missing'
Assert-Contract ($migration.Contains('CreatedUtc: 2026-09-10')) 'Migration metadata missing: CreatedUtc: 2026-09-10'
Assert-Contract ($migration.Contains('MigrationId: 20260910_001_kvk_source_publication_state')) 'Migration metadata missing: MigrationId: 20260910_001_kvk_source_publication_state'
Assert-Contract ($migration.Contains('RequiresBackup: Yes')) 'Migration metadata missing: RequiresBackup: Yes'
Assert-Contract ($migration.Contains('RiskLevel: Medium')) 'Migration metadata missing: RiskLevel: Medium'
Assert-Contract ($migration.Contains('TransactionMode: Auto')) 'Migration metadata missing: TransactionMode: Auto'
Assert-Contract ($migration.Contains('DataChange: No')) 'Migration metadata missing: DataChange: No'
Assert-Contract ($migration.Contains('Rollback: Manual')) 'Migration metadata missing: Rollback: Manual'
Assert-Contract ($migration.Contains('RollbackScript: N/A')) 'Migration metadata missing: RollbackScript: N/A'
Assert-Contract ($fixture.Contains('KVK_S2B_DISPOSABLE_AUTHORIZED')) 'Fixture guard/scenario missing'
Assert-Contract ($fixture.Contains('KVK_S2B_AUTHORIZED_SERVER')) 'Fixture guard/scenario missing'
Assert-Contract ($fixture.Contains('KVK_S2B_AUTHORIZED_DATABASE')) 'Fixture guard/scenario missing'
Assert-Contract ($fixture.Contains('DB_ID() <= 4')) 'Fixture guard/scenario missing'
Assert-Contract ($fixture.Contains('K98[_]S2B[_]Disposable[_]%')) 'Fixture guard/scenario missing'
Assert-Contract ($fixture.Contains('ROLLBACK TRANSACTION;')) 'Fixture guard/scenario missing'
Assert-Contract ($fixture.Contains('13-14-13')) 'Fixture guard/scenario missing'
Assert-Contract ($fixture.Contains('Absent endpoint')) 'Fixture guard/scenario missing'
Assert-Contract ($fixture.Contains('Uncertain receipt')) 'Fixture guard/scenario missing'
Assert-Contract ([regex]::Matches($fixture, 'Accepted invalid case:').Count -eq 131) 'Negative coverage manifest drift.'
if ($failures.Count) {
    $failures | ForEach-Object { Write-Output "FAIL: $_" }
    throw "$($failures.Count) of $checks S2B static assertions failed."
}
Write-Output "S2B static contracts: $checks assertions passed. Runtime transactions and concurrency require separate evidence."
