[CmdletBinding()]
param([string]$RepoPath = (Split-Path -Parent $PSScriptRoot))

# Static text contract only: no SQL connections, deployment, SQL evaluation or log writes.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
$failures = [System.Collections.Generic.List[string]]::new()
$checks = 0
function Get-SqlSource {
    param([string]$RelativePath)
    return (Get-Content -Raw -LiteralPath (Join-Path $repoRoot $RelativePath)).Replace("`r`n", "`n")
}
function Assert-Contract {
    param([bool]$Condition, [string]$Message)
    $script:checks++
    if (-not $Condition) { $failures.Add($Message) }
}
function Assert-Contains {
    param([string]$Source, [string]$Pattern, [string]$Message)
    Assert-Contract ($Source -match $Pattern) $Message
}
function Get-ExecutableText {
    param([string]$Source)
    return (($Source -replace '(?s)/\*.*?\*/', '') -replace '(?m)--[^\n]*', '')
}

$names = @(
    'SourceArtifact', 'SourceImportAttempt', 'SourceObservation', 'SourceObservationRevision',
    'SourcePlayerSnapshot', 'SourceLogicalScan', 'SourceRoster', 'SourceRosterMember',
    'SourceAggregateReport', 'SourceAggregateRevision', 'SourceKingdomReportRow', 'SourceCampReportRow'
)
$migration = Get-SqlSource 'migrations/20260909_001_kvk_source_observation_facts.sql'
$fixture = Get-SqlSource 'validation/kvk_source/observation_constraints.sql'
$ddl = Get-ExecutableText $migration
$source = @{}
$creates = [regex]::Matches($ddl, '(?i)CREATE\s+TABLE\s+KVK\.(\w+)')
Assert-Contract ($creates.Count -eq 12) 'Migration must create exactly twelve tables.'
Assert-Contract ((@($creates | ForEach-Object { $_.Groups[1].Value } | Sort-Object) -join ',') -ceq (($names | Sort-Object) -join ',')) 'Migration table names differ from S2A manifest.'
foreach ($name in $names) {
    $snapshot = Get-SqlSource "sql_schema/KVK.$name.Table.sql"
    $source[$name] = $snapshot
    $createStart = $snapshot.IndexOf("CREATE TABLE KVK.$name`n", [StringComparison]::Ordinal)
    $createEnd = $snapshot.IndexOf("`n);", $createStart, [StringComparison]::Ordinal)
    Assert-Contract ($createStart -ge 0 -and $createEnd -gt $createStart) "$name has no canonical table body."
    if ($createStart -ge 0 -and $createEnd -gt $createStart) {
        $body = $snapshot.Substring($createStart, $createEnd + 3 - $createStart)
        Assert-Contract ($migration.Contains($body)) "$name migration/snapshot table body differs."
    }
    Assert-Contains $snapshot 'SET ANSI_NULLS ON;' "$name must set ANSI_NULLS."
    Assert-Contains $snapshot 'SET QUOTED_IDENTIFIER ON;' "$name must set QUOTED_IDENTIFIER."
    Assert-Contains $snapshot ("CONSTRAINT PK_{0} PRIMARY KEY" -f $name) "$name lacks primary uniqueness."
    foreach ($link in [regex]::Matches($snapshot, '(?m)^ALTER TABLE[^\n]+;|^CREATE INDEX[^\n]+;')) {
        Assert-Contract ($migration.Contains($link.Value)) "$name migration/snapshot link or index differs."
    }
    Assert-Contains $migration ("IF OBJECT_ID\(N'KVK\.{0}'\) IS NOT NULL" -f $name) "$name requires a fail-closed collision guard."
    Assert-Contains $fixture ("Synthetic rows survived rollback: {0}" -f $name) "$name needs rollback evidence."
    if ($name -ne 'SourceArtifact') {
        Assert-Contains $snapshot 'SourceKey varchar\(32\) COLLATE Latin1_General_100_BIN2 NOT NULL' "$name source key must use explicit case-sensitive collation."
        Assert-Contains $snapshot "SourceKey = 'snapshot_report_v1' AND DATALENGTH\(SourceKey\) = 18 AND KVK_NO > 0" "$name must enforce source and positive season."
    }
}
Assert-Contract ($ddl -notmatch '(?i)\b(FLOAT|REAL|IDENTITY|TRIGGER|PROCEDURE|FUNCTION|GRANT|TRUNCATE|DROP|DELETE|INSERT|UPDATE|ProcConfig|SCANORDER|KVK_Scan|KVK_AllPlayers_Raw|KVK_Player_Baseline|SourcePublication|SourcePeriod|SourceRouting)\b') 'S2A migration contains a forbidden runtime, legacy, allocator, permission or data-change surface.'
Assert-Contract ($ddl -notmatch '(?i)\b(DEFAULT|CASCADE|NOCHECK)\b') 'S2A must not introduce automatic allocation, cascade deletion or untrusted constraints.'
Assert-Contract ($ddl -notmatch '(?im)^\s*GO\s*$') 'The transaction must remain in one migration batch.'
foreach ($header in @('RequiresBackup: Yes','RiskLevel: Medium','TransactionMode: Auto','DataChange: No','Rollback: Manual','RollbackScript: N/A','CreatedUtc: 2026-09-09','MigrationId: 20260909_001_kvk_source_observation_facts')) {
    Assert-Contract ($migration.Contains($header)) "Missing migration metadata: $header"
}
Assert-Contains $ddl 'compatibility_level[\s\S]+< 130' 'Migration must check SQL JSON compatibility.'
Assert-Contains $ddl 'IF @S2AOwnTransaction = 1 BEGIN TRANSACTION;' 'Migration must own or join an explicit transaction.'
Assert-Contains $ddl 'IF @S2AOwnTransaction = 1 COMMIT TRANSACTION;' 'Migration may commit only its own transaction.'
Assert-Contains $ddl 'BEGIN CATCH[\s\S]+XACT_STATE\(\) <> 0 ROLLBACK TRANSACTION;[\s\S]+THROW;' 'Migration must propagate failure and roll back an owned transaction.'
Assert-Contains $ddl 'c.is_disabled = 1 OR c.is_not_trusted = 1' 'Migration must validate trusted constraints.'

$requiredLinks = @(
    @('SourceObservationRevision','SourceObservation','SourceKey, KVK_NO, ObservationID'),
    @('SourcePlayerSnapshot','SourceObservationRevision','SourceKey, KVK_NO, RevisionID'),
    @('SourceLogicalScan','SourceObservation','SourceKey, KVK_NO, ObservationID'),
    @('SourceRoster','SourceObservationRevision','SourceKey, KVK_NO, B0RevisionID'),
    @('SourceRosterMember','SourceRoster','SourceKey, KVK_NO, RosterID'),
    @('SourceAggregateRevision','SourceAggregateReport','SourceKey, KVK_NO, ReportID, PeriodKind'),
    @('SourceKingdomReportRow','SourceAggregateRevision','SourceKey, KVK_NO, RevisionID, MappingDigest'),
    @('SourceCampReportRow','SourceAggregateRevision','SourceKey, KVK_NO, RevisionID, MappingDigest')
)
foreach ($link in $requiredLinks) {
    $pattern = 'FOREIGN KEY \(' + [regex]::Escape($link[2]) + '\) REFERENCES KVK\.' + $link[1]
    Assert-Contains $source[$link[0]] $pattern "$($link[0]) must enforce same-source/season parent identity."
}
$lastCreate = $migration.LastIndexOf('CREATE TABLE', [StringComparison]::Ordinal)
foreach ($pair in @(@('SourceObservation','ObservationID','SourceObservationRevision'), @('SourceAggregateReport','ReportID','SourceAggregateRevision'))) {
    $statement = "ALTER TABLE KVK.$($pair[0]) WITH CHECK ADD CONSTRAINT FK_$($pair[0])_SelectedRevision FOREIGN KEY (SourceKey, KVK_NO, $($pair[1]), SelectedRevisionID) REFERENCES KVK.$($pair[2]) (SourceKey, KVK_NO, $($pair[1]), RevisionID);"
    Assert-Contract ($migration.IndexOf($statement, [StringComparison]::Ordinal) -gt $lastCreate) "$($pair[0]) selected revision must use its own parent and be linked after all tables exist."
    Assert-Contains $source[$pair[0]] 'SelectedRevisionID uniqueidentifier NULL' 'Selected pointer may be null only during controlled DAL creation.'
    Assert-Contains $source[$pair[0]] 'SelectionVersion > 0' 'Selected pointer must carry a positive version.'
}
Assert-Contains $source.SourceLogicalScan 'PRIMARY KEY \(SourceKey, KVK_NO, LogicalScanID\)' 'Logical scan namespace must be source/season specific.'
Assert-Contains $source.SourceLogicalScan 'UNIQUE \(SourceKey, KVK_NO, ObservationID\)' 'One observation must bind only one logical scan.'
Assert-Contains $source.SourceLogicalScan 'LogicalScanID int NOT NULL' 'Logical scan must retain int bounds.'
Assert-Contains $source.SourceImportAttempt 'UNIQUE \(GuildID, MessageID, AttachmentID, ActionKey\)' 'Admission replay key must be unique.'
Assert-Contains $source.SourceImportAttempt 'FK_SourceImportAttempt_ObservationRevision' 'Player aliases must retain exact accepted revision.'
Assert-Contains $source.SourceImportAttempt 'FK_SourceImportAttempt_AggregateRevision' 'Aggregate aliases must retain exact accepted revision.'
Assert-Contains $source.SourceImportAttempt 'CK_SourceImportAttempt_Result CHECK' 'Completed attempt must bind exactly one stream.'
Assert-Contains $source.SourceObservation 'UNIQUE \(SourceKey, KVK_NO, ScanStartUTC, TimePrecision, EventDiscriminator\)' 'Event identity cannot come from upload time.'
Assert-Contains $source.SourceObservationRevision 'UNIQUE \(ObservationID, DigestVersion, SchemaVersion, SemanticHash\)' 'Equivalent player content must reuse its accepted revision.'
Assert-Contains $source.SourceArtifact "StorageKey = LOWER\(CONVERT\(varchar\(64\), ArtifactHash, 2\)\) \+ N'.xlsx'" 'Artifact location must be generated from its hash.'

$playerCounters = @('power','city_hall','vip','t1_kills','t2_kills','t3_kills','t4_kills','t5_kills','total_kill_points','ranged_points','dead','healed','rss_assistance','alliance_helps','rss_gathered','troops_power','tech_power','building_power','commander_power','kvk_played','autarch_times','most_kvk_kill','most_kvk_dead','most_kvk_heal','acclaim','highest_acclaim','aoo_joined','aoo_won','aoo_avg_kill','aoo_avg_dead','aoo_avg_heal')
foreach ($column in $playerCounters) {
    Assert-Contains $source.SourcePlayerSnapshot ("\b{0} bigint NULL" -f $column) "Player $column must preserve unavailable values."
    Assert-Contains $source.SourcePlayerSnapshot ("JSON_VALUE\(FieldStatusJson, '\$.{0}'\) IS NOT NULL" -f $column) "Player $column requires explicit availability."
    Assert-Contains $source.SourcePlayerSnapshot ("{0} IS NOT NULL AND {0} >= 0" -f $column) "Player $column must retain valid nonnegative counters."
    Assert-Contains $source.SourcePlayerSnapshot ("AND {0} IS NULL" -f $column) "Player $column must not store a zero fallback for unavailable data."
}
Assert-Contains $source.SourcePlayerSnapshot 'GovernorID bigint NOT NULL' 'Governor identity must retain bigint range.'
Assert-Contains $source.SourcePlayerSnapshot 'GovernorID > 0 AND kingdom > 0' 'Player identities must be positive.'
Assert-Contains $source.SourceRosterMember 'b0_power bigint NULL' 'B0 eligibility must not depend on usable power.'
Assert-Contains $source.SourceRoster 'ScopeDigest binary\(32\)' 'Frozen roster must retain approved scope provenance.'
Assert-Contains $source.SourceRoster 'MemberDigest binary\(32\)' 'Frozen roster must retain member provenance.'

$metrics = @('t4_kills','t5_kills','kp_t4_t5','dead','t4_t5_dead','healed','acclaim','dkp')
foreach ($name in @('SourceKingdomReportRow','SourceCampReportRow')) {
    Assert-Contract ([regex]::Matches($source[$name], '\bdecimal\(38,6\) NOT NULL').Count -eq 16) "$name must contain exactly eight values and eight units."
    foreach ($metric in $metrics) {
        foreach ($shape in @("$metric decimal(38,6) NOT NULL", "${metric}_raw nvarchar(128) NOT NULL", "${metric}_unit decimal(38,6) NOT NULL", "${metric}_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL")) {
            Assert-Contract ($source[$name].Contains($shape)) "$name missing $shape."
        }
        Assert-Contains $source[$name] ("{0} >= 0 AND {0}_unit > 0" -f $metric) "$name $metric must enforce its numeric range."
    }
    Assert-Contains $source[$name] 'RawCellsJson nvarchar\(max\) NOT NULL' "$name must retain raw typed cells/formats."
}
Assert-Contract ($source.SourceAggregateRevision -notmatch 'UNIQUE \([^\n]+SemanticHash') 'Aggregate finalization must not be swallowed by content deduplication.'
Assert-Contains $source.SourceAggregateRevision "PeriodKind <> 'overall' OR ReportState IN \('final','corrected_final'\)" 'Overall aggregate cannot accept live fight data.'
Assert-Contains $source.SourceAggregateRevision 'CoverageEndUTC >= CoverageStartUTC AND AsOfUTC >= CoverageEndUTC' 'Aggregate coverage must remain explicit and ordered.'
Assert-Contains $source.SourceAggregateReport 'UNIQUE \(SourceKey, KVK_NO, PeriodKey\)' 'Fight and overall families must be separate.'

$testCode = Get-ExecutableText $fixture
foreach ($guard in @('KVK_S2A_AUTHORIZED_SERVER','KVK_S2A_AUTHORIZED_DATABASE','KVK_S2A_DISPOSABLE_AUTHORIZED',"SERVERPROPERTY('ServerName')",'DB_NAME()',"K98[_]S2A[_]Disposable[_]%")) {
    Assert-Contract ($testCode.Contains($guard)) "Fixture missing disposable target guard $guard."
}
Assert-Contract ($testCode.IndexOf('Explicit authorization for this exact disposable server/database is required.') -lt $testCode.IndexOf('BEGIN TRANSACTION;')) 'Authorization guard must precede writes.'
Assert-Contract ($testCode -notmatch '(?im)^\s*(COMMIT|USE|DROP|TRUNCATE)\b|\$\(') 'Fixture must have no commit, database switch, destructive cleanup or SQLCMD substitution.'
Assert-Contains $testCode 'IF @@TRANCOUNT <> 0' 'Fixture must refuse ambient transactions.'
Assert-Contains $testCode 'ROLLBACK TRANSACTION PartialAggregate' 'Fixture must verify half-aggregate rollback.'
Assert-Contains $testCode 'IF XACT_STATE\(\) <> 0 ROLLBACK TRANSACTION;' 'Fixture must roll back on failure.'
Assert-Contract ([regex]::Matches($fixture, 'INSERT @Cases \(Label, Statement, ExpectedError, ExpectedConstraint\)').Count -ge 90) 'Fixture must retain the complete rejection matrix.'
foreach ($label in @('cross-season','wrong source allowlist','source case sensitive','selected revision belongs to another observation','selected revision belongs to another report','aggregate mapping provenance','aggregate decimal overflow','scan int overflow','unavailable must not become zero','overall cannot accept live','no-fight aggregate rejects')) {
    Assert-Contract ($fixture.Contains($label)) "Fixture missing $label coverage."
}
if ($failures.Count -gt 0) {
    throw ("S2A static contract failures:`n" + ($failures -join "`n"))
}
Write-Output "S2A static contract checks passed: $checks assertions across twelve tables, migration and rollback fixture. SQL execution/concurrency not tested."
