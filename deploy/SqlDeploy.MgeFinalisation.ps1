# One fixed additive MGE schema family. No profile-supplied SQL or identifiers.
# Uses the existing module runner's transaction, exclusive lock and outcome ledger.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Read-K98MgeProfile($p) {
    Assert-K98ModuleFields $p @('version','profile','migration_id','database_collation','tempdb_collation','compatibility_level','requires')
    if($p.version -isnot [int] -or $p.version -ne 1 -or $p.profile -cne 'mge_finalisation_v1' -or
       $p.migration_id -isnot [string] -or $p.database_collation -isnot [string] -or $p.tempdb_collation -isnot [string] -or
       $p.migration_id -cnotmatch '^[0-9]{8}_[0-9]{3}_[a-z0-9_]+\z' -or
       $p.database_collation -cnotmatch '^[A-Za-z0-9_]{1,128}\z' -or
       $p.tempdb_collation -cnotmatch '^[A-Za-z0-9_]{1,128}\z' -or
       $p.compatibility_level -isnot [int] -or $p.compatibility_level -notin @(130,140,150,160) -or
       $p.requires -isnot [array] -or $p.requires.Count -gt 64){throw 'Exact bounded MGE profile required'}
    $seen=@{}
    foreach($r in $p.requires){
        Assert-K98ModuleFields $r @('migration_id','sha256','status')
        if($r.migration_id -cnotmatch '^[0-9]{8}_[0-9]{3}_[A-Za-z0-9_]+\z' -or
           $r.sha256 -cnotmatch '^[a-f0-9]{64}\z' -or $r.status -cnotin @('Applied','Failed') -or
           $seen.ContainsKey($r.migration_id)){throw 'Exact unique MGE predecessor history required'}
        $seen[$r.migration_id]=$true
    }
    $body=Get-K98MgeTableBody $p.database_collation
    $triggers=@(Get-K98MgeTriggers)
    $create='CREATE TABLE dbo.MGE_BoardFinalisation ('+$body+', CONSTRAINT FK_MGE_BoardFinalisation_Event FOREIGN KEY (EventId) REFERENCES dbo.MGE_Events(EventId));'
    $commands=@($create,(Get-K98MgeIndex 'dbo.MGE_BoardFinalisation'))+@($triggers|ForEach-Object {$_.Sql})
    return @{Profile=$p;Body=$body;Triggers=$triggers;Commands=$commands}
}

function Get-K98MgeTableBody([string]$Collation) {
    # Explicit column collation also makes the tempdb expected image comparable.
    if($Collation -cnotmatch '^[A-Za-z0-9_]{1,128}\z'){throw 'Exact collation required'}
    return @"
EventId bigint NOT NULL,
BoardKind varchar(16) COLLATE $Collation NOT NULL,
FinalisationId uniqueidentifier NOT NULL,
PublishVersion int NOT NULL,
ChannelId bigint NOT NULL,
MessageId bigint NOT NULL,
DeliveryState varchar(16) COLLATE $Collation NOT NULL,
PayloadJson nvarchar(max) COLLATE $Collation NULL,
Reason varchar(64) COLLATE $Collation NULL,
RetiredByDiscordId bigint NULL,
CreatedUtc datetime2(7) NOT NULL CONSTRAINT DF_MGE_BoardFinalisation_Created DEFAULT SYSUTCDATETIME(),
UpdatedUtc datetime2(7) NOT NULL CONSTRAINT DF_MGE_BoardFinalisation_Updated DEFAULT SYSUTCDATETIME(),
Revision rowversion NOT NULL,
CONSTRAINT PK_MGE_BoardFinalisation PRIMARY KEY (EventId, BoardKind),
CONSTRAINT CK_MGE_BoardFinalisation_Kind CHECK (BoardKind IN ('signup', 'leadership', 'awards')),
CONSTRAINT CK_MGE_BoardFinalisation_State CHECK (DeliveryState IN ('pending', 'confirmed', 'failed', 'unknown', 'held', 'retired')),
CONSTRAINT CK_MGE_BoardFinalisation_Identity CHECK (ChannelId > 0 AND MessageId > 0 AND PublishVersion >= 0),
CONSTRAINT CK_MGE_BoardFinalisation_Payload CHECK (PayloadJson IS NULL OR ISJSON(PayloadJson) = 1),
CONSTRAINT CK_MGE_BoardFinalisation_Retirement CHECK (DeliveryState <> 'retired' OR RetiredByDiscordId IS NOT NULL)
"@
}
function Get-K98MgeIndex([string]$Table) {
    if($Table -cnotin @('dbo.MGE_BoardFinalisation','#K98_MgeExpected')){throw 'Fixed MGE index target required'}
    return "CREATE INDEX IX_MGE_BoardFinalisation_Work ON $Table(DeliveryState, EventId) INCLUDE (BoardKind, FinalisationId, ChannelId, MessageId, PublishVersion);"
}
function Get-K98MgeTriggers {
    @{
        Name='dbo.tr_MGE_Events_Frozen';Parent='dbo.MGE_Events';Events='DELETE,UPDATE'
        Sql=@'
CREATE TRIGGER dbo.tr_MGE_Events_Frozen ON dbo.MGE_Events
AFTER UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted WHERE Status = 'completed')
        THROW 51830, 'Completed MGE events are immutable.', 1;
END;
'@
    }
    foreach($kind in @('Awards','Signups')){
        $noun=$kind.ToLowerInvariant()
        @{
            Name="dbo.tr_MGE_${kind}_Frozen";Parent="dbo.MGE_$kind";Events='DELETE,INSERT,UPDATE'
            Sql=@"
CREATE TRIGGER dbo.tr_MGE_${kind}_Frozen ON dbo.MGE_$kind
AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM dbo.MGE_Events E WITH (UPDLOCK, HOLDLOCK)
        JOIN (SELECT EventId FROM inserted UNION SELECT EventId FROM deleted) A ON A.EventId = E.EventId
        WHERE E.Status = 'completed'
    ) THROW 51830, 'Completed MGE $noun are immutable.', 1;
END;
"@
        }
    }
}

function Assert-K98MgeImages($Connection,$Transaction,$Loaded,[bool]$After) {
    . "$PSScriptRoot\SqlDeploy.TableRelease.ps1"
    $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF NOT EXISTS(SELECT 1 FROM sys.schemas WHERE name COLLATE Latin1_General_100_BIN2=N'dbo')
 OR EXISTS(SELECT 1 FROM (VALUES(N'dbo.MGE_Events'),(N'dbo.MGE_Awards'),(N'dbo.MGE_Signups')) n(name)
 WHERE OBJECT_ID(n.name,N'U') IS NULL
 OR (OBJECT_SCHEMA_NAME(OBJECT_ID(n.name))+N'.'+OBJECT_NAME(OBJECT_ID(n.name))) COLLATE Latin1_General_100_BIN2<>n.name COLLATE Latin1_General_100_BIN2
 OR NOT EXISTS(SELECT 1 FROM sys.columns c WHERE c.object_id=OBJECT_ID(n.name)
 AND c.name COLLATE Latin1_General_100_BIN2=N'EventId' AND c.system_type_id=127 AND c.user_type_id=127 AND c.is_nullable=0 AND c.is_computed=0))
 THROW 51950,'Exact MGE parent tables and bigint EventId columns required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.MGE_Events')
 AND name COLLATE Latin1_General_100_BIN2=N'Status' AND system_type_id=167 AND user_type_id=167 AND max_length=20 AND is_nullable=0)
 THROW 51950,'Exact MGE event Status required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID(N'dbo.MGE_Events') AND i.is_unique=1
 AND i.is_disabled=0 AND i.has_filter=0 AND i.is_hypothetical=0
 AND (SELECT COUNT(*) FROM sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)=1
 AND EXISTS(SELECT 1 FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id
 WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND c.name COLLATE Latin1_General_100_BIN2=N'EventId'))
 THROW 51950,'Exact enabled unique MGE EventId key required.',1;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id IN (OBJECT_ID(N'dbo.MGE_Events'),OBJECT_ID(N'dbo.MGE_Awards'),OBJECT_ID(N'dbo.MGE_Signups'))
 AND object_id NOT IN (ISNULL(OBJECT_ID(N'dbo.tr_MGE_Events_Frozen'),-1),ISNULL(OBJECT_ID(N'dbo.tr_MGE_Awards_Frozen'),-1),ISNULL(OBJECT_ID(N'dbo.tr_MGE_Signups_Frozen'),-1)))
 THROW 51950,'Unreviewed MGE parent trigger; no automatic adoption.',1;
'@
    if(-not $After){
        $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CREATE TABLE')<>1
 OR HAS_PERMS_BY_NAME(N'dbo','SCHEMA','ALTER')<>1
 OR HAS_PERMS_BY_NAME(N'dbo.MGE_Events','OBJECT','ALTER')<>1
 OR HAS_PERMS_BY_NAME(N'dbo.MGE_Awards','OBJECT','ALTER')<>1
 OR HAS_PERMS_BY_NAME(N'dbo.MGE_Signups','OBJECT','ALTER')<>1
 THROW 51950,'MGE deployment permissions required before mutation.',1;
IF OBJECT_ID(N'dbo.MGE_BoardFinalisation') IS NOT NULL
 OR EXISTS(SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID(N'dbo') AND name IN
 (N'PK_MGE_BoardFinalisation',N'FK_MGE_BoardFinalisation_Event',N'DF_MGE_BoardFinalisation_Created',N'DF_MGE_BoardFinalisation_Updated',
 N'CK_MGE_BoardFinalisation_Kind',N'CK_MGE_BoardFinalisation_State',N'CK_MGE_BoardFinalisation_Identity',N'CK_MGE_BoardFinalisation_Payload',N'CK_MGE_BoardFinalisation_Retirement',
 N'tr_MGE_Events_Frozen',N'tr_MGE_Awards_Frozen',N'tr_MGE_Signups_Frozen'))
 THROW 51950,'MGE preimage must be absent; partial/manual installation is not adopted.',1;
'@
        # Parse the exact table/index shape in tempdb without persistent changes.
        $null=Invoke-K98ModuleQuery $Connection $Transaction ('CREATE TABLE #K98_MgeExpected ('+$Loaded.Body+');'+(Get-K98MgeIndex '#K98_MgeExpected')+' DROP TABLE #K98_MgeExpected;')
        return
    }
    $expected=Get-K98TableImageSql 'tempdb' "OBJECT_ID(N'tempdb..#K98_MgeExpected')"
    $actual=(Get-K98TableImageSql 'DB_NAME_UNUSED' "OBJECT_ID(N'dbo.MGE_BoardFinalisation')").Replace('DB_NAME_UNUSED.sys.','sys.')
    $query=@"
IF OBJECT_ID(N'dbo.MGE_BoardFinalisation',N'U') IS NULL
 THROW 51950,'MGE finalisation table missing.',1;
IF OBJECT_NAME(OBJECT_ID(N'dbo.MGE_BoardFinalisation')) COLLATE Latin1_General_100_BIN2<>N'MGE_BoardFinalisation'
 OR OBJECT_SCHEMA_NAME(OBJECT_ID(N'dbo.MGE_BoardFinalisation')) COLLATE Latin1_General_100_BIN2<>N'dbo'
 THROW 51950,'MGE finalisation identity differs.',1;
IF EXISTS(SELECT 1 FROM sys.objects WHERE object_id IN (OBJECT_ID(N'dbo.MGE_BoardFinalisation'),OBJECT_ID(N'dbo.tr_MGE_Events_Frozen'),OBJECT_ID(N'dbo.tr_MGE_Awards_Frozen'),OBJECT_ID(N'dbo.tr_MGE_Signups_Frozen')) AND principal_id IS NOT NULL)
 OR EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id IN (OBJECT_ID(N'dbo.MGE_BoardFinalisation'),OBJECT_ID(N'dbo.tr_MGE_Events_Frozen'),OBJECT_ID(N'dbo.tr_MGE_Awards_Frozen'),OBJECT_ID(N'dbo.tr_MGE_Signups_Frozen')))
 THROW 51950,'MGE explicit ownership/grants differ.',1;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation') AND (user_type_id<>system_type_id OR encryption_type IS NOT NULL))
 OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation'))
 OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation'))
 OR EXISTS(SELECT 1 FROM sys.masked_columns WHERE object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation') AND is_masked=1)
 OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation') AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_filetable<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_tracked_by_cdc<>0 OR filestream_data_space_id<>0))
 OR EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation'))
 OR EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation') AND (data_compression<>0 OR partition_number<>1))
 OR EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.data_spaces d ON d.data_space_id=i.data_space_id WHERE i.object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation') AND d.type<>'FG')
 THROW 51950,'Unsupported MGE table metadata.',1;
CREATE TABLE #K98_MgeExpected ($($Loaded.Body));
$(Get-K98MgeIndex '#K98_MgeExpected')
SELECT ($expected) AS expected_image,($actual) AS actual_image,
 (SELECT name,parent_column_id,definition FROM tempdb.sys.default_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#K98_MgeExpected') ORDER BY name COLLATE Latin1_General_100_BIN2 FOR JSON PATH) AS expected_defaults,
 (SELECT name,parent_column_id,definition FROM sys.default_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation') ORDER BY name COLLATE Latin1_General_100_BIN2 FOR JSON PATH) AS actual_defaults;
DROP TABLE #K98_MgeExpected;
"@
    $rows=Invoke-K98ModuleQuery $Connection $Transaction $query
    if($rows.Count -ne 1 -or $rows[0].actual_image -cne $rows[0].expected_image -or $rows[0].actual_defaults -cne $rows[0].expected_defaults){throw 'MGE table/index/check/default postimage differs'}
    $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation'))<>1
 OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN sys.foreign_key_columns k ON k.constraint_object_id=f.object_id
 JOIN sys.columns pc ON pc.object_id=k.parent_object_id AND pc.column_id=k.parent_column_id
 JOIN sys.columns rc ON rc.object_id=k.referenced_object_id AND rc.column_id=k.referenced_column_id
 WHERE f.parent_object_id=OBJECT_ID(N'dbo.MGE_BoardFinalisation') AND f.name COLLATE Latin1_General_100_BIN2=N'FK_MGE_BoardFinalisation_Event'
 AND f.referenced_object_id=OBJECT_ID(N'dbo.MGE_Events') AND f.is_disabled=0 AND f.is_not_trusted=0 AND f.is_not_for_replication=0
 AND f.delete_referential_action=0 AND f.update_referential_action=0 AND k.constraint_column_id=1
 AND pc.name COLLATE Latin1_General_100_BIN2=N'EventId' AND rc.name COLLATE Latin1_General_100_BIN2=N'EventId'
 AND (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE constraint_object_id=f.object_id)=1)
 THROW 51950,'MGE foreign key postimage differs.',1;
'@
    foreach($t in $Loaded.Triggers){
        $rows=Invoke-K98ModuleQuery $Connection $Transaction @'
SELECT m.definition,m.uses_ansi_nulls,m.uses_quoted_identifier,m.execute_as_principal_id,t.is_disabled,t.is_not_for_replication,t.is_instead_of_trigger,
 (SELECT COUNT(*) FROM sys.crypt_properties c WHERE c.class=1 AND c.major_id=t.object_id) AS signatures,
 (SELECT e.type_desc+',' FROM sys.trigger_events e WHERE e.object_id=t.object_id ORDER BY e.type_desc FOR XML PATH('')) AS events
FROM sys.triggers t JOIN sys.sql_modules m ON m.object_id=t.object_id
WHERE t.object_id=OBJECT_ID(@name,N'TR') AND t.parent_class=1 AND t.parent_id=OBJECT_ID(@parent,N'U')
 AND (OBJECT_SCHEMA_NAME(t.object_id)+N'.'+t.name) COLLATE Latin1_General_100_BIN2=@name COLLATE Latin1_General_100_BIN2;
'@ @{name=$t.Name;parent=$t.Parent}
        $hash=Get-K98ModuleHash ([Text.Encoding]::Unicode.GetBytes($t.Sql))
        if($rows.Count -ne 1 -or $null -eq $rows[0].definition){throw ('MGE trigger missing/invisible: '+$t.Name)}
        $r=$rows[0]
        if((Get-K98ModuleHash ([Text.Encoding]::Unicode.GetBytes($r.definition))) -cne $hash -or
           -not $r.uses_ansi_nulls -or -not $r.uses_quoted_identifier -or $null -ne $r.execute_as_principal_id -or
           $r.is_disabled -or $r.is_not_for_replication -or $r.is_instead_of_trigger -or $r.signatures -ne 0 -or
           $r.events -cne ($t.Events+',')){throw ('MGE trigger postimage differs: '+$t.Name)}
    }
}
