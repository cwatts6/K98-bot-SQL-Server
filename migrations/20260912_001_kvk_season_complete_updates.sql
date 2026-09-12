/*
MigrationId: 20260912_001_kvk_season_complete_updates
Purpose: Add fixed season source, complete update selection and durable export intent
Author: cwatts
CreatedUtc: 2026-09-12
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: None
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: Exactly #S8AApproval.ExpectedNewChoices; reviewed historical allowlist only
PreValidationQuery: Preview history counts and classification using the exact predicates below; validate backup and explicit server/database
PostValidationQuery: Verify five object catalogs, exact inserted count and unchanged existing choices; no complete selection or intent backfill
RelatedBotPR: N/A
RelatedSQLPR: N/A
Dependencies: 20260909_001_kvk_source_observation_facts and 20260910_001_kvk_source_publication_state; authoritative KVK.KVK_Scan
*/
-- AUTHORED ONLY. No execution authorized by file approval. No default server/database.
-- One separately approved session must supply these temporary input tables BEFORE this
-- batch. They are an operation contract, not a template populated with real KVK guesses:
-- #S8AApproval (ServerName nvarchar(128), DatabaseName sysname, BackupEvidence nvarchar(1024),
--   PreviewEvidence nvarchar(1024), ExpectedNewChoices bigint, Mode varchar(8))
--   Exactly one non-null row. Mode='preview' rolls back; Mode='apply' commits.
-- #S8AClassification (KVK_NO int, SourceKey varchar(32) COLLATE Latin1_General_100_BIN2,
--   ChoiceID uniqueidentifier, ChosenBy nvarchar(128), ChosenUTC datetime2(0),
--   Reason nvarchar(1024), ProvenanceJson nvarchar(max), SeasonState varchar(32),
--   ExpectedLegacyRows bigint, ExpectedSourceRows bigint)
--   Exactly one reviewed row per historical season; no duplicate or invented scope.
-- Existing SeasonSource choices need not be reclassified, but any supplied row must
-- match the original immutable choice/provenance byte-for-byte; never rewrite history.
-- Missing inputs, unclassified history, mixed streams, changed counts or contradictory
-- choices fail closed. An empty allowlist works ONLY for empty or already classified history.
-- Preview returns metadata counts/choices, not player rows. An operator must review exact
-- classifications, row preview and backup/restore evidence before approving Mode='apply'.
-- BackupEvidence/PreviewEvidence are receipts, not automatic proof of a backup or approval.
-- RequiresBackup remains enforced by the operational approval; do not use runner defaults.
-- Existing runner skips applied migrations, so explicit rerun validation uses this exact
-- batch in a new approved session with the same inputs, not a force/rewrite of its ledger.
-- This batch owns its transaction and refuses an ambient transaction. DDL, catalog checks,
-- history inventory and inserts commit together; all failures rollback the owned transaction.
-- Take all importers/writers offline for this bounded later operation. History TABLOCKX /
-- HOLDLOCK inventory can block and scan metadata; measure time/locks in disposable testing.
-- Transaction app lock serializes S8A installers. Existing SeasonSource is locked before
-- history; fixed constant history table order starts with SourceRouting. No provider calls.
-- Later S8B lock order: SeasonSource -> SourceRouting -> sorted component/complete period
-- selections -> config/request/update -> intent/vector. S8B implements that writer contract.
-- No existing table/row is altered, deleted, enabled or automatically publicly selected.
-- Forward fix after retained data exists: preserve choices, revisions, receipts and inputs;
-- stop affected writers and propose a separate reviewed migration. Do not drop these tables.
-- Snapshot schema is deliberately inert: SQL static FKs do not enforce temporal immutability,
-- authorization, same-report PeriodKey/coverage, observation-to-scan revision identity,
-- confirmation validity against the base update, candidate tuple/finality/count/hash checks,
-- monotonic CAS, vector membership/hash, or atomic selection+intent. Those are S8B obligations.
-- Rejected tuples remain complete evidence; an incomplete attempted association is recorded
-- privately by existing acceptance/audit, not forced into a sealed/rejected tuple with holes.
-- B0 is private onboarding, no intent. No-fight uses equal exact player endpoints and no
-- aggregate; frozen-roster zero/member/rank rules remain in the accepted calculation service.
-- Independent overall aggregates, UTC starts, semantic aliases and daily SCANORDER unchanged.
-- Preserve 11-10, 12-10, 13-10 and authorized 14-10 without a second correction command.
-- SourceRouting.Enabled alone does not implement public routing. No S8B/queue activation.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 THROW 51800, 'S8A requires a dedicated session without an ambient transaction.', 1;
IF OBJECT_ID(N'tempdb..#S8AApproval',N'U') IS NULL OR OBJECT_ID(N'tempdb..#S8AClassification',N'U') IS NULL
    THROW 51800, 'S8A requires explicit target, backup, preview and reviewed classification inputs.', 1;
IF (SELECT COUNT_BIG(*) FROM #S8AApproval)<>1
    THROW 51800, 'S8A approval must contain exactly one row.', 1;
IF EXISTS (SELECT 1 FROM #S8AApproval WHERE ServerName IS NULL OR DatabaseName IS NULL
 OR ServerName COLLATE Latin1_General_100_BIN2<>CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) COLLATE Latin1_General_100_BIN2
 OR DatabaseName COLLATE Latin1_General_100_BIN2<>DB_NAME() COLLATE Latin1_General_100_BIN2
 OR DB_ID()<=4 OR BackupEvidence IS NULL OR LEN(BackupEvidence)=0
 OR PreviewEvidence IS NULL OR LEN(PreviewEvidence)=0 OR ExpectedNewChoices IS NULL OR ExpectedNewChoices<0
 OR Mode IS NULL OR Mode COLLATE Latin1_General_100_BIN2 NOT IN ('preview','apply') OR DATALENGTH(Mode)<>LEN(Mode))
    THROW 51800, 'S8A target, operation or evidence receipt is invalid.', 1;
IF SCHEMA_ID(N'KVK') IS NULL OR (SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID())<130
    THROW 51800, 'S8A requires KVK schema and JSON compatibility.', 1;
IF OBJECT_ID(N'KVK.KVK_Scan',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.KVK_Scan.', 1;
IF OBJECT_ID(N'KVK.SourceAggregateReport',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceAggregateReport.', 1;
IF OBJECT_ID(N'KVK.SourceAggregateRevision',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceAggregateRevision.', 1;
IF OBJECT_ID(N'KVK.SourceConfigRequest',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceConfigRequest.', 1;
IF OBJECT_ID(N'KVK.SourceConfigVersion',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceConfigVersion.', 1;
IF OBJECT_ID(N'KVK.SourceImportAttempt',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceImportAttempt.', 1;
IF OBJECT_ID(N'KVK.SourceLogicalScan',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceLogicalScan.', 1;
IF OBJECT_ID(N'KVK.SourceObservation',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceObservation.', 1;
IF OBJECT_ID(N'KVK.SourceObservationRevision',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceObservationRevision.', 1;
IF OBJECT_ID(N'KVK.SourcePeriod',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourcePeriod.', 1;
IF OBJECT_ID(N'KVK.SourcePublication',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourcePublication.', 1;
IF OBJECT_ID(N'KVK.SourceRoster',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceRoster.', 1;
IF OBJECT_ID(N'KVK.SourceRouting',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceRouting.', 1;
IF OBJECT_ID(N'KVK.SourceScanBinding',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceScanBinding.', 1;
IF OBJECT_ID(N'KVK.SourceSelection',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceSelection.', 1;
IF OBJECT_ID(N'KVK.SourceWindowConfig',N'U') IS NULL THROW 51800, 'S8A missing prerequisite KVK.SourceWindowConfig.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE schema_id=SCHEMA_ID(N'KVK') AND (is_disabled=1 OR is_not_trusted=1))
 OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE schema_id=SCHEMA_ID(N'KVK') AND (is_disabled=1 OR is_not_trusted=1))
    THROW 51800, 'S8A requires trusted enabled prerequisite constraints.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @S8ALock int;
    EXEC @S8ALock=sys.sp_getapplock @Resource=N'KVK.S8A.SchemaClassification', @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
    IF @S8ALock<0 THROW 51800, 'S8A installer lock unavailable.', 1;
    DECLARE @S8AExisting int=0, @S8ALockCount bigint;
    IF OBJECT_ID(N'KVK.SeasonSource') IS NOT NULL SET @S8AExisting+=1;
    IF OBJECT_ID(N'KVK.SourceUpdate') IS NOT NULL SET @S8AExisting+=1;
    IF OBJECT_ID(N'KVK.SourceCompleteSelection') IS NOT NULL SET @S8AExisting+=1;
    IF OBJECT_ID(N'KVK.SourceExportIntent') IS NOT NULL SET @S8AExisting+=1;
    IF OBJECT_ID(N'KVK.SourceExportIntentPublication') IS NOT NULL SET @S8AExisting+=1;
    IF @S8AExisting NOT IN (0,5) THROW 51810, 'S8A partial installation; no automatic repair.', 1;
    IF @S8AExisting=5
    BEGIN
        IF OBJECT_ID(N'KVK.SeasonSource',N'U') IS NULL THROW 51810, 'S8A object collision.', 1;
        EXEC sys.sp_executesql N'SELECT @n=COUNT_BIG(*) FROM KVK.SeasonSource WITH (TABLOCKX,HOLDLOCK);', N'@n bigint OUTPUT', @n=@S8ALockCount OUTPUT;
    END;
    DECLARE @S8AHistory TABLE (KVK_NO int, HistoryObject sysname, HistoryRows bigint);
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceRouting',COUNT_BIG(*) FROM KVK.SourceRouting WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceSelection',COUNT_BIG(*) FROM KVK.SourceSelection WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourcePeriod',COUNT_BIG(*) FROM KVK.SourcePeriod WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceConfigRequest',COUNT_BIG(*) FROM KVK.SourceConfigRequest WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceConfigVersion',COUNT_BIG(*) FROM KVK.SourceConfigVersion WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceRoster',COUNT_BIG(*) FROM KVK.SourceRoster WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceObservation',COUNT_BIG(*) FROM KVK.SourceObservation WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceObservationRevision',COUNT_BIG(*) FROM KVK.SourceObservationRevision WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceLogicalScan',COUNT_BIG(*) FROM KVK.SourceLogicalScan WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceAggregateReport',COUNT_BIG(*) FROM KVK.SourceAggregateReport WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceAggregateRevision',COUNT_BIG(*) FROM KVK.SourceAggregateRevision WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourcePublication',COUNT_BIG(*) FROM KVK.SourcePublication WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'SourceImportAttempt',COUNT_BIG(*) FROM KVK.SourceImportAttempt WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    INSERT INTO @S8AHistory SELECT KVK_NO,N'KVK_Scan',COUNT_BIG(*) FROM KVK.KVK_Scan WITH (TABLOCKX,HOLDLOCK) GROUP BY KVK_NO;
    DECLARE @S8AScopes TABLE (KVK_NO int PRIMARY KEY, LegacyRows bigint, SourceRows bigint);
    INSERT INTO @S8AScopes SELECT KVK_NO,SUM(CASE WHEN HistoryObject=N'KVK_Scan' THEN HistoryRows ELSE 0 END),SUM(CASE WHEN HistoryObject<>N'KVK_Scan' THEN HistoryRows ELSE 0 END) FROM @S8AHistory GROUP BY KVK_NO;
    IF EXISTS (SELECT 1 FROM @S8AScopes WHERE KVK_NO IS NULL OR KVK_NO<=0 OR (LegacyRows>0 AND SourceRows>0))
        THROW 51801, 'S8A ambiguous or mixed historical source; classify outside this migration.', 1;
    IF EXISTS (SELECT KVK_NO FROM #S8AClassification GROUP BY KVK_NO HAVING COUNT_BIG(*)<>1)
     OR EXISTS (SELECT 1 FROM #S8AClassification c LEFT JOIN @S8AScopes h ON h.KVK_NO=c.KVK_NO
       WHERE h.KVK_NO IS NULL OR c.SourceKey IS NULL OR c.ChoiceID IS NULL OR c.ChosenBy IS NULL OR LEN(c.ChosenBy)=0
       OR c.ChosenUTC IS NULL OR c.Reason IS NULL OR LEN(c.Reason)=0 OR c.ProvenanceJson IS NULL OR ISJSON(c.ProvenanceJson)<>1 OR DATALENGTH(c.ProvenanceJson)>65536
       OR c.SeasonState IS NULL OR c.SeasonState COLLATE Latin1_General_100_BIN2 NOT IN ('planned','open','closing','closed') OR DATALENGTH(c.SeasonState)<>LEN(c.SeasonState)
       OR c.ExpectedLegacyRows IS NULL OR c.ExpectedSourceRows IS NULL OR c.ExpectedLegacyRows<>h.LegacyRows OR c.ExpectedSourceRows<>h.SourceRows
       OR (h.LegacyRows>0 AND (c.SourceKey COLLATE Latin1_General_100_BIN2<>'legacy_full_data' OR DATALENGTH(c.SourceKey)<>16))
       OR (h.SourceRows>0 AND (c.SourceKey COLLATE Latin1_General_100_BIN2<>'snapshot_report_v1' OR DATALENGTH(c.SourceKey)<>18)))
        THROW 51801, 'S8A classification scope, identity, provenance or preview counts conflict.', 1;
    -- Expose the exact locked inventory even on the approved preview operation.
    SELECT KVK_NO,HistoryObject,HistoryRows FROM @S8AHistory ORDER BY KVK_NO,HistoryObject;
    IF @S8AExisting=0
    BEGIN
        IF EXISTS (SELECT 1 FROM @S8AScopes h WHERE NOT EXISTS (SELECT 1 FROM #S8AClassification c WHERE c.KVK_NO=h.KVK_NO))
            THROW 51801, 'S8A unclassified history; an empty allowlist is not permission.', 1;
        EXEC sys.sp_executesql N'CREATE TABLE KVK.SeasonSource
(
    KVK_NO int NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    ChosenBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChosenUTC datetime2(0) NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    SeasonState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SeasonVersion bigint NOT NULL,
    CONSTRAINT PK_SeasonSource PRIMARY KEY (KVK_NO),
    CONSTRAINT UQ_SeasonSource_Choice UNIQUE (KVK_NO, SourceKey, ChoiceID),
    CONSTRAINT CK_SeasonSource_Scope CHECK (KVK_NO > 0 AND ((SourceKey = ''legacy_full_data'' AND DATALENGTH(SourceKey) = 16) OR (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18))),
    CONSTRAINT CK_SeasonSource_State CHECK (DATALENGTH(SeasonState) = LEN(SeasonState) AND SeasonState IN (''planned'',''open'',''closing'',''closed'') AND SeasonVersion > 0),
    CONSTRAINT CK_SeasonSource_Provenance CHECK (LEN(ChosenBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);
';
        EXEC sys.sp_executesql N'CREATE TABLE KVK.SourceUpdate
(
    UpdateID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    ConfigVersionID uniqueidentifier NOT NULL,
    RosterID uniqueidentifier NOT NULL,
    StartScanID int NULL,
    EndScanID int NULL,
    StartRevisionID uniqueidentifier NULL,
    EndRevisionID uniqueidentifier NULL,
    AggregateReportID uniqueidentifier NULL,
    AggregateRevisionID uniqueidentifier NULL,
    CoverageStartUTC datetime2(0) NOT NULL,
    CoverageEndUTC datetime2(0) NOT NULL,
    AsOfUTC datetime2(0) NOT NULL,
    UpdateKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    UpdateState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BaseUpdateID uniqueidentifier NULL,
    CounterpartRevisionID uniqueidentifier NULL,
    ConfirmedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ConfirmedUTC datetime2(0) NOT NULL,
    ConfirmationJson nvarchar(max) NOT NULL,
    RequestID uniqueidentifier NULL,
    ContentHash binary(32) NOT NULL,
    Version bigint NOT NULL,
    CONSTRAINT PK_SourceUpdate PRIMARY KEY (UpdateID),
    CONSTRAINT UQ_SourceUpdate_Scope UNIQUE (SourceKey, KVK_NO, PeriodID, UpdateID),
    CONSTRAINT UQ_SourceUpdate_Config UNIQUE (SourceKey, KVK_NO, PeriodID, UpdateID, ConfigVersionID),
    CONSTRAINT FK_SourceUpdate_Choice FOREIGN KEY (KVK_NO, SourceKey, ChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID),
    CONSTRAINT FK_SourceUpdate_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PeriodKey) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodID, PeriodKey),
    CONSTRAINT FK_SourceUpdate_Kind FOREIGN KEY (SourceKey, KVK_NO, PeriodKey, UpdateKind) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodKey, PeriodKind),
    CONSTRAINT FK_SourceUpdate_Window FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID, PeriodKey) REFERENCES KVK.SourceWindowConfig (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT FK_SourceUpdate_ConfigRoster FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID, RosterID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID, RosterID),
    CONSTRAINT FK_SourceUpdate_StartBinding FOREIGN KEY (ConfigVersionID, StartScanID) REFERENCES KVK.SourceScanBinding (ConfigVersionID, LogicalScanID),
    CONSTRAINT FK_SourceUpdate_EndBinding FOREIGN KEY (ConfigVersionID, EndScanID) REFERENCES KVK.SourceScanBinding (ConfigVersionID, LogicalScanID),
    CONSTRAINT FK_SourceUpdate_StartRevision FOREIGN KEY (SourceKey, KVK_NO, StartRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT FK_SourceUpdate_EndRevision FOREIGN KEY (SourceKey, KVK_NO, EndRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT FK_SourceUpdate_Aggregate FOREIGN KEY (SourceKey, KVK_NO, AggregateReportID, AggregateRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, ReportID, RevisionID),
    CONSTRAINT FK_SourceUpdate_AggregateKind FOREIGN KEY (SourceKey, KVK_NO, AggregateReportID, UpdateKind) REFERENCES KVK.SourceAggregateReport (SourceKey, KVK_NO, ReportID, PeriodKind),
    CONSTRAINT FK_SourceUpdate_Base FOREIGN KEY (SourceKey, KVK_NO, PeriodID, BaseUpdateID) REFERENCES KVK.SourceUpdate (SourceKey, KVK_NO, PeriodID, UpdateID),
    CONSTRAINT FK_SourceUpdate_Request FOREIGN KEY (SourceKey, KVK_NO, PeriodID, RequestID) REFERENCES KVK.SourceConfigRequest (SourceKey, KVK_NO, PeriodID, RequestID),
    CONSTRAINT CK_SourceUpdate_Scope CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceUpdate_Time CHECK (CoverageEndUTC >= CoverageStartUTC AND AsOfUTC >= CoverageEndUTC),
    CONSTRAINT CK_SourceUpdate_Inputs CHECK (((StartScanID IS NULL AND StartRevisionID IS NULL) OR (StartScanID IS NOT NULL AND StartRevisionID IS NOT NULL)) AND ((EndScanID IS NULL AND EndRevisionID IS NULL) OR (EndScanID IS NOT NULL AND EndRevisionID IS NOT NULL)) AND ((AggregateReportID IS NULL AND AggregateRevisionID IS NULL) OR (AggregateReportID IS NOT NULL AND AggregateRevisionID IS NOT NULL)) AND (StartScanID IS NULL OR EndScanID IS NULL OR EndScanID >= StartScanID)),
    CONSTRAINT CK_SourceUpdate_Kind CHECK (DATALENGTH(UpdateKind) = LEN(UpdateKind) AND UpdateKind IN (''fight'',''overall'',''no_fight'') AND (UpdateKind <> ''no_fight'' OR (AggregateReportID IS NULL AND AggregateRevisionID IS NULL AND (StartScanID IS NULL OR EndScanID IS NULL OR (StartScanID = EndScanID AND StartRevisionID = EndRevisionID))))),
    CONSTRAINT CK_SourceUpdate_State CHECK (DATALENGTH(UpdateState) = LEN(UpdateState) AND Version > 0 AND ((UpdateState = ''waiting_player'' AND (StartRevisionID IS NULL OR EndRevisionID IS NULL)) OR (UpdateState = ''waiting_aggregate'' AND UpdateKind <> ''no_fight'' AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL AND AggregateRevisionID IS NULL) OR (UpdateState IN (''ready'',''selected'',''superseded'',''rejected'') AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL AND (UpdateKind = ''no_fight'' OR AggregateRevisionID IS NOT NULL)))),
    CONSTRAINT CK_SourceUpdate_Confirmation CHECK (LEN(ConfirmedBy) > 0 AND ISJSON(ConfirmationJson) = 1 AND DATALENGTH(ConfirmationJson) <= 65536 AND (BaseUpdateID IS NULL OR BaseUpdateID <> UpdateID) AND (CounterpartRevisionID IS NULL OR (BaseUpdateID IS NOT NULL AND ((StartRevisionID IS NOT NULL AND CounterpartRevisionID = StartRevisionID) OR (EndRevisionID IS NOT NULL AND CounterpartRevisionID = EndRevisionID) OR (AggregateRevisionID IS NOT NULL AND CounterpartRevisionID = AggregateRevisionID)))))
);
';
        EXEC sys.sp_executesql N'CREATE TABLE KVK.SourceCompleteSelection
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    UpdateID uniqueidentifier NOT NULL,
    PublicationID uniqueidentifier NOT NULL,
    PublicSelectionVersion bigint NOT NULL,
    SelectedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceCompleteSelection PRIMARY KEY (SourceKey, KVK_NO, PeriodID),
    CONSTRAINT FK_SourceCompleteSelection_Update FOREIGN KEY (SourceKey, KVK_NO, PeriodID, UpdateID) REFERENCES KVK.SourceUpdate (SourceKey, KVK_NO, PeriodID, UpdateID),
    CONSTRAINT FK_SourceCompleteSelection_Publication FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT CK_SourceCompleteSelection_Version CHECK (PublicSelectionVersion > 0),
    CONSTRAINT CK_SourceCompleteSelection_Scope CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
';
        EXEC sys.sp_executesql N'CREATE TABLE KVK.SourceExportIntent
(
    IntentID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    CommitSequence bigint NOT NULL,
    VectorHash binary(32) NOT NULL,
    ExportSchemaVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    IntentState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    SupersededByIntentID uniqueidentifier NULL,
    CONSTRAINT PK_SourceExportIntent PRIMARY KEY (IntentID),
    CONSTRAINT UQ_SourceExportIntent_Scope UNIQUE (SourceKey, KVK_NO, IntentID),
    CONSTRAINT UQ_SourceExportIntent_Sequence UNIQUE (SourceKey, KVK_NO, CommitSequence),
    CONSTRAINT UQ_SourceExportIntent_Vector UNIQUE (SourceKey, KVK_NO, VectorHash, ExportSchemaVersion),
    CONSTRAINT FK_SourceExportIntent_Choice FOREIGN KEY (KVK_NO, SourceKey, ChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID),
    CONSTRAINT FK_SourceExportIntent_Superseded FOREIGN KEY (SourceKey, KVK_NO, SupersededByIntentID) REFERENCES KVK.SourceExportIntent (SourceKey, KVK_NO, IntentID),
    CONSTRAINT CK_SourceExportIntent_Scope CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceExportIntent_Version CHECK (CommitSequence > 0 AND LEN(ExportSchemaVersion) > 0 AND DATALENGTH(ExportSchemaVersion) = LEN(ExportSchemaVersion)),
    CONSTRAINT CK_SourceExportIntent_State CHECK (DATALENGTH(IntentState) = LEN(IntentState) AND IntentState IN (''pending'',''waiting_destination'',''materialized'',''coalesced'',''confirmed'',''blocked'') AND ((IntentState = ''coalesced'' AND SupersededByIntentID IS NOT NULL AND SupersededByIntentID <> IntentID) OR (IntentState <> ''coalesced'' AND SupersededByIntentID IS NULL)))
);
';
        EXEC sys.sp_executesql N'CREATE TABLE KVK.SourceExportIntentPublication
(
    IntentID uniqueidentifier NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    UpdateID uniqueidentifier NOT NULL,
    PublicationID uniqueidentifier NOT NULL,
    PublicSelectionVersion bigint NOT NULL,
    ConfigVersionID uniqueidentifier NOT NULL,
    CONSTRAINT PK_SourceExportIntentPublication PRIMARY KEY (IntentID, PeriodID),
    CONSTRAINT FK_SourceExportIntentPublication_Intent FOREIGN KEY (SourceKey, KVK_NO, IntentID) REFERENCES KVK.SourceExportIntent (SourceKey, KVK_NO, IntentID),
    CONSTRAINT FK_SourceExportIntentPublication_Update FOREIGN KEY (SourceKey, KVK_NO, PeriodID, UpdateID, ConfigVersionID) REFERENCES KVK.SourceUpdate (SourceKey, KVK_NO, PeriodID, UpdateID, ConfigVersionID),
    CONSTRAINT FK_SourceExportIntentPublication_Publication FOREIGN KEY (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID),
    CONSTRAINT CK_SourceExportIntentPublication_Version CHECK (PublicSelectionVersion > 0),
    CONSTRAINT CK_SourceExportIntentPublication_Scope CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
';
    END;
    EXEC sys.sp_executesql N'DECLARE @S8AColumns TABLE (TableName sysname, Ordinal int, ColumnName sysname, TypeName sysname, MaxLength int, Scale int, CollationName sysname NULL, IsNullable bit);
DECLARE @S8AKeys TABLE (TableName sysname, KeyName sysname, IsPrimary bit, Ordinal int, ColumnName sysname);
DECLARE @S8AForeign TABLE (TableName sysname, KeyName sysname, Ordinal int, ColumnName sysname, ParentTable sysname, ParentColumn sysname);
DECLARE @S8AChecks TABLE (TableName sysname, CheckName sysname, Definition nvarchar(max));
INSERT INTO @S8AColumns VALUES
(N''SeasonSource'', 1, N''KVK_NO'', N''int'', 4, 0, NULL, 0),
(N''SeasonSource'', 2, N''SourceKey'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SeasonSource'', 3, N''ChoiceID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SeasonSource'', 4, N''ChosenBy'', N''nvarchar'', 256, 0, N''Latin1_General_100_BIN2'', 0),
(N''SeasonSource'', 5, N''ChosenUTC'', N''datetime2'', 6, 0, NULL, 0),
(N''SeasonSource'', 6, N''Reason'', N''nvarchar'', 2048, 0, NULL, 0),
(N''SeasonSource'', 7, N''ProvenanceJson'', N''nvarchar'', -1, 0, NULL, 0),
(N''SeasonSource'', 8, N''SeasonState'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SeasonSource'', 9, N''SeasonVersion'', N''bigint'', 8, 0, NULL, 0),
(N''SourceUpdate'', 1, N''UpdateID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceUpdate'', 2, N''SourceKey'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceUpdate'', 3, N''KVK_NO'', N''int'', 4, 0, NULL, 0),
(N''SourceUpdate'', 4, N''PeriodID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceUpdate'', 5, N''PeriodKey'', N''varchar'', 128, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceUpdate'', 6, N''ChoiceID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceUpdate'', 7, N''ConfigVersionID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceUpdate'', 8, N''RosterID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceUpdate'', 9, N''StartScanID'', N''int'', 4, 0, NULL, 1),
(N''SourceUpdate'', 10, N''EndScanID'', N''int'', 4, 0, NULL, 1),
(N''SourceUpdate'', 11, N''StartRevisionID'', N''uniqueidentifier'', 16, 0, NULL, 1),
(N''SourceUpdate'', 12, N''EndRevisionID'', N''uniqueidentifier'', 16, 0, NULL, 1),
(N''SourceUpdate'', 13, N''AggregateReportID'', N''uniqueidentifier'', 16, 0, NULL, 1),
(N''SourceUpdate'', 14, N''AggregateRevisionID'', N''uniqueidentifier'', 16, 0, NULL, 1),
(N''SourceUpdate'', 15, N''CoverageStartUTC'', N''datetime2'', 6, 0, NULL, 0),
(N''SourceUpdate'', 16, N''CoverageEndUTC'', N''datetime2'', 6, 0, NULL, 0),
(N''SourceUpdate'', 17, N''AsOfUTC'', N''datetime2'', 6, 0, NULL, 0),
(N''SourceUpdate'', 18, N''UpdateKind'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceUpdate'', 19, N''UpdateState'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceUpdate'', 20, N''BaseUpdateID'', N''uniqueidentifier'', 16, 0, NULL, 1),
(N''SourceUpdate'', 21, N''CounterpartRevisionID'', N''uniqueidentifier'', 16, 0, NULL, 1),
(N''SourceUpdate'', 22, N''ConfirmedBy'', N''nvarchar'', 256, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceUpdate'', 23, N''ConfirmedUTC'', N''datetime2'', 6, 0, NULL, 0),
(N''SourceUpdate'', 24, N''ConfirmationJson'', N''nvarchar'', -1, 0, NULL, 0),
(N''SourceUpdate'', 25, N''RequestID'', N''uniqueidentifier'', 16, 0, NULL, 1),
(N''SourceUpdate'', 26, N''ContentHash'', N''binary'', 32, 0, NULL, 0),
(N''SourceUpdate'', 27, N''Version'', N''bigint'', 8, 0, NULL, 0),
(N''SourceCompleteSelection'', 1, N''SourceKey'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceCompleteSelection'', 2, N''KVK_NO'', N''int'', 4, 0, NULL, 0),
(N''SourceCompleteSelection'', 3, N''PeriodID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceCompleteSelection'', 4, N''UpdateID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceCompleteSelection'', 5, N''PublicationID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceCompleteSelection'', 6, N''PublicSelectionVersion'', N''bigint'', 8, 0, NULL, 0),
(N''SourceCompleteSelection'', 7, N''SelectedUTC'', N''datetime2'', 6, 0, NULL, 0),
(N''SourceExportIntent'', 1, N''IntentID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceExportIntent'', 2, N''SourceKey'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceExportIntent'', 3, N''KVK_NO'', N''int'', 4, 0, NULL, 0),
(N''SourceExportIntent'', 4, N''ChoiceID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceExportIntent'', 5, N''CommitSequence'', N''bigint'', 8, 0, NULL, 0),
(N''SourceExportIntent'', 6, N''VectorHash'', N''binary'', 32, 0, NULL, 0),
(N''SourceExportIntent'', 7, N''ExportSchemaVersion'', N''varchar'', 64, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceExportIntent'', 8, N''IntentState'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceExportIntent'', 9, N''CreatedUTC'', N''datetime2'', 6, 0, NULL, 0),
(N''SourceExportIntent'', 10, N''SupersededByIntentID'', N''uniqueidentifier'', 16, 0, NULL, 1),
(N''SourceExportIntentPublication'', 1, N''IntentID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceExportIntentPublication'', 2, N''PeriodID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceExportIntentPublication'', 3, N''SourceKey'', N''varchar'', 32, 0, N''Latin1_General_100_BIN2'', 0),
(N''SourceExportIntentPublication'', 4, N''KVK_NO'', N''int'', 4, 0, NULL, 0),
(N''SourceExportIntentPublication'', 5, N''UpdateID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceExportIntentPublication'', 6, N''PublicationID'', N''uniqueidentifier'', 16, 0, NULL, 0),
(N''SourceExportIntentPublication'', 7, N''PublicSelectionVersion'', N''bigint'', 8, 0, NULL, 0),
(N''SourceExportIntentPublication'', 8, N''ConfigVersionID'', N''uniqueidentifier'', 16, 0, NULL, 0);
INSERT INTO @S8AKeys VALUES
(N''SeasonSource'', N''PK_SeasonSource'', 1, 1, N''KVK_NO''),
(N''SeasonSource'', N''UQ_SeasonSource_Choice'', 0, 1, N''KVK_NO''),
(N''SeasonSource'', N''UQ_SeasonSource_Choice'', 0, 2, N''SourceKey''),
(N''SeasonSource'', N''UQ_SeasonSource_Choice'', 0, 3, N''ChoiceID''),
(N''SourceUpdate'', N''PK_SourceUpdate'', 1, 1, N''UpdateID''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Scope'', 0, 1, N''SourceKey''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Scope'', 0, 2, N''KVK_NO''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Scope'', 0, 3, N''PeriodID''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Scope'', 0, 4, N''UpdateID''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Config'', 0, 1, N''SourceKey''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Config'', 0, 2, N''KVK_NO''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Config'', 0, 3, N''PeriodID''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Config'', 0, 4, N''UpdateID''),
(N''SourceUpdate'', N''UQ_SourceUpdate_Config'', 0, 5, N''ConfigVersionID''),
(N''SourceCompleteSelection'', N''PK_SourceCompleteSelection'', 1, 1, N''SourceKey''),
(N''SourceCompleteSelection'', N''PK_SourceCompleteSelection'', 1, 2, N''KVK_NO''),
(N''SourceCompleteSelection'', N''PK_SourceCompleteSelection'', 1, 3, N''PeriodID''),
(N''SourceExportIntent'', N''PK_SourceExportIntent'', 1, 1, N''IntentID''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Scope'', 0, 1, N''SourceKey''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Scope'', 0, 2, N''KVK_NO''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Scope'', 0, 3, N''IntentID''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Sequence'', 0, 1, N''SourceKey''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Sequence'', 0, 2, N''KVK_NO''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Sequence'', 0, 3, N''CommitSequence''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Vector'', 0, 1, N''SourceKey''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Vector'', 0, 2, N''KVK_NO''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Vector'', 0, 3, N''VectorHash''),
(N''SourceExportIntent'', N''UQ_SourceExportIntent_Vector'', 0, 4, N''ExportSchemaVersion''),
(N''SourceExportIntentPublication'', N''PK_SourceExportIntentPublication'', 1, 1, N''IntentID''),
(N''SourceExportIntentPublication'', N''PK_SourceExportIntentPublication'', 1, 2, N''PeriodID'');
INSERT INTO @S8AForeign VALUES
(N''SourceUpdate'', N''FK_SourceUpdate_Choice'', 1, N''KVK_NO'', N''SeasonSource'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_Choice'', 2, N''SourceKey'', N''SeasonSource'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Choice'', 3, N''ChoiceID'', N''SeasonSource'', N''ChoiceID''),
(N''SourceUpdate'', N''FK_SourceUpdate_Period'', 1, N''SourceKey'', N''SourcePeriod'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Period'', 2, N''KVK_NO'', N''SourcePeriod'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_Period'', 3, N''PeriodID'', N''SourcePeriod'', N''PeriodID''),
(N''SourceUpdate'', N''FK_SourceUpdate_Period'', 4, N''PeriodKey'', N''SourcePeriod'', N''PeriodKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Kind'', 1, N''SourceKey'', N''SourcePeriod'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Kind'', 2, N''KVK_NO'', N''SourcePeriod'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_Kind'', 3, N''PeriodKey'', N''SourcePeriod'', N''PeriodKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Kind'', 4, N''UpdateKind'', N''SourcePeriod'', N''PeriodKind''),
(N''SourceUpdate'', N''FK_SourceUpdate_Window'', 1, N''SourceKey'', N''SourceWindowConfig'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Window'', 2, N''KVK_NO'', N''SourceWindowConfig'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_Window'', 3, N''ConfigVersionID'', N''SourceWindowConfig'', N''ConfigVersionID''),
(N''SourceUpdate'', N''FK_SourceUpdate_Window'', 4, N''PeriodKey'', N''SourceWindowConfig'', N''PeriodKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_ConfigRoster'', 1, N''SourceKey'', N''SourceConfigVersion'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_ConfigRoster'', 2, N''KVK_NO'', N''SourceConfigVersion'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_ConfigRoster'', 3, N''ConfigVersionID'', N''SourceConfigVersion'', N''ConfigVersionID''),
(N''SourceUpdate'', N''FK_SourceUpdate_ConfigRoster'', 4, N''RosterID'', N''SourceConfigVersion'', N''RosterID''),
(N''SourceUpdate'', N''FK_SourceUpdate_StartBinding'', 1, N''ConfigVersionID'', N''SourceScanBinding'', N''ConfigVersionID''),
(N''SourceUpdate'', N''FK_SourceUpdate_StartBinding'', 2, N''StartScanID'', N''SourceScanBinding'', N''LogicalScanID''),
(N''SourceUpdate'', N''FK_SourceUpdate_EndBinding'', 1, N''ConfigVersionID'', N''SourceScanBinding'', N''ConfigVersionID''),
(N''SourceUpdate'', N''FK_SourceUpdate_EndBinding'', 2, N''EndScanID'', N''SourceScanBinding'', N''LogicalScanID''),
(N''SourceUpdate'', N''FK_SourceUpdate_StartRevision'', 1, N''SourceKey'', N''SourceObservationRevision'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_StartRevision'', 2, N''KVK_NO'', N''SourceObservationRevision'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_StartRevision'', 3, N''StartRevisionID'', N''SourceObservationRevision'', N''RevisionID''),
(N''SourceUpdate'', N''FK_SourceUpdate_EndRevision'', 1, N''SourceKey'', N''SourceObservationRevision'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_EndRevision'', 2, N''KVK_NO'', N''SourceObservationRevision'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_EndRevision'', 3, N''EndRevisionID'', N''SourceObservationRevision'', N''RevisionID''),
(N''SourceUpdate'', N''FK_SourceUpdate_Aggregate'', 1, N''SourceKey'', N''SourceAggregateRevision'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Aggregate'', 2, N''KVK_NO'', N''SourceAggregateRevision'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_Aggregate'', 3, N''AggregateReportID'', N''SourceAggregateRevision'', N''ReportID''),
(N''SourceUpdate'', N''FK_SourceUpdate_Aggregate'', 4, N''AggregateRevisionID'', N''SourceAggregateRevision'', N''RevisionID''),
(N''SourceUpdate'', N''FK_SourceUpdate_AggregateKind'', 1, N''SourceKey'', N''SourceAggregateReport'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_AggregateKind'', 2, N''KVK_NO'', N''SourceAggregateReport'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_AggregateKind'', 3, N''AggregateReportID'', N''SourceAggregateReport'', N''ReportID''),
(N''SourceUpdate'', N''FK_SourceUpdate_AggregateKind'', 4, N''UpdateKind'', N''SourceAggregateReport'', N''PeriodKind''),
(N''SourceUpdate'', N''FK_SourceUpdate_Base'', 1, N''SourceKey'', N''SourceUpdate'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Base'', 2, N''KVK_NO'', N''SourceUpdate'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_Base'', 3, N''PeriodID'', N''SourceUpdate'', N''PeriodID''),
(N''SourceUpdate'', N''FK_SourceUpdate_Base'', 4, N''BaseUpdateID'', N''SourceUpdate'', N''UpdateID''),
(N''SourceUpdate'', N''FK_SourceUpdate_Request'', 1, N''SourceKey'', N''SourceConfigRequest'', N''SourceKey''),
(N''SourceUpdate'', N''FK_SourceUpdate_Request'', 2, N''KVK_NO'', N''SourceConfigRequest'', N''KVK_NO''),
(N''SourceUpdate'', N''FK_SourceUpdate_Request'', 3, N''PeriodID'', N''SourceConfigRequest'', N''PeriodID''),
(N''SourceUpdate'', N''FK_SourceUpdate_Request'', 4, N''RequestID'', N''SourceConfigRequest'', N''RequestID''),
(N''SourceCompleteSelection'', N''FK_SourceCompleteSelection_Update'', 1, N''SourceKey'', N''SourceUpdate'', N''SourceKey''),
(N''SourceCompleteSelection'', N''FK_SourceCompleteSelection_Update'', 2, N''KVK_NO'', N''SourceUpdate'', N''KVK_NO''),
(N''SourceCompleteSelection'', N''FK_SourceCompleteSelection_Update'', 3, N''PeriodID'', N''SourceUpdate'', N''PeriodID''),
(N''SourceCompleteSelection'', N''FK_SourceCompleteSelection_Update'', 4, N''UpdateID'', N''SourceUpdate'', N''UpdateID''),
(N''SourceCompleteSelection'', N''FK_SourceCompleteSelection_Publication'', 1, N''SourceKey'', N''SourcePublication'', N''SourceKey''),
(N''SourceCompleteSelection'', N''FK_SourceCompleteSelection_Publication'', 2, N''KVK_NO'', N''SourcePublication'', N''KVK_NO''),
(N''SourceCompleteSelection'', N''FK_SourceCompleteSelection_Publication'', 3, N''PeriodID'', N''SourcePublication'', N''PeriodID''),
(N''SourceCompleteSelection'', N''FK_SourceCompleteSelection_Publication'', 4, N''PublicationID'', N''SourcePublication'', N''PublicationID''),
(N''SourceExportIntent'', N''FK_SourceExportIntent_Choice'', 1, N''KVK_NO'', N''SeasonSource'', N''KVK_NO''),
(N''SourceExportIntent'', N''FK_SourceExportIntent_Choice'', 2, N''SourceKey'', N''SeasonSource'', N''SourceKey''),
(N''SourceExportIntent'', N''FK_SourceExportIntent_Choice'', 3, N''ChoiceID'', N''SeasonSource'', N''ChoiceID''),
(N''SourceExportIntent'', N''FK_SourceExportIntent_Superseded'', 1, N''SourceKey'', N''SourceExportIntent'', N''SourceKey''),
(N''SourceExportIntent'', N''FK_SourceExportIntent_Superseded'', 2, N''KVK_NO'', N''SourceExportIntent'', N''KVK_NO''),
(N''SourceExportIntent'', N''FK_SourceExportIntent_Superseded'', 3, N''SupersededByIntentID'', N''SourceExportIntent'', N''IntentID''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Intent'', 1, N''SourceKey'', N''SourceExportIntent'', N''SourceKey''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Intent'', 2, N''KVK_NO'', N''SourceExportIntent'', N''KVK_NO''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Intent'', 3, N''IntentID'', N''SourceExportIntent'', N''IntentID''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Update'', 1, N''SourceKey'', N''SourceUpdate'', N''SourceKey''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Update'', 2, N''KVK_NO'', N''SourceUpdate'', N''KVK_NO''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Update'', 3, N''PeriodID'', N''SourceUpdate'', N''PeriodID''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Update'', 4, N''UpdateID'', N''SourceUpdate'', N''UpdateID''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Update'', 5, N''ConfigVersionID'', N''SourceUpdate'', N''ConfigVersionID''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Publication'', 1, N''SourceKey'', N''SourcePublication'', N''SourceKey''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Publication'', 2, N''KVK_NO'', N''SourcePublication'', N''KVK_NO''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Publication'', 3, N''PeriodID'', N''SourcePublication'', N''PeriodID''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Publication'', 4, N''ConfigVersionID'', N''SourcePublication'', N''ConfigVersionID''),
(N''SourceExportIntentPublication'', N''FK_SourceExportIntentPublication_Publication'', 5, N''PublicationID'', N''SourcePublication'', N''PublicationID'');
INSERT INTO @S8AChecks VALUES
(N''SeasonSource'', N''CK_SeasonSource_Scope'', N''KVK_NO > 0 AND ((SourceKey = ''''legacy_full_data'''' AND DATALENGTH(SourceKey) = 16) OR (SourceKey = ''''snapshot_report_v1'''' AND DATALENGTH(SourceKey) = 18))''),
(N''SeasonSource'', N''CK_SeasonSource_State'', N''DATALENGTH(SeasonState) = LEN(SeasonState) AND SeasonState IN (''''planned'''',''''open'''',''''closing'''',''''closed'''') AND SeasonVersion > 0''),
(N''SeasonSource'', N''CK_SeasonSource_Provenance'', N''LEN(ChosenBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536''),
(N''SourceUpdate'', N''CK_SourceUpdate_Scope'', N''SourceKey = ''''snapshot_report_v1'''' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0''),
(N''SourceUpdate'', N''CK_SourceUpdate_Time'', N''CoverageEndUTC >= CoverageStartUTC AND AsOfUTC >= CoverageEndUTC''),
(N''SourceUpdate'', N''CK_SourceUpdate_Inputs'', N''((StartScanID IS NULL AND StartRevisionID IS NULL) OR (StartScanID IS NOT NULL AND StartRevisionID IS NOT NULL)) AND ((EndScanID IS NULL AND EndRevisionID IS NULL) OR (EndScanID IS NOT NULL AND EndRevisionID IS NOT NULL)) AND ((AggregateReportID IS NULL AND AggregateRevisionID IS NULL) OR (AggregateReportID IS NOT NULL AND AggregateRevisionID IS NOT NULL)) AND (StartScanID IS NULL OR EndScanID IS NULL OR EndScanID >= StartScanID)''),
(N''SourceUpdate'', N''CK_SourceUpdate_Kind'', N''DATALENGTH(UpdateKind) = LEN(UpdateKind) AND UpdateKind IN (''''fight'''',''''overall'''',''''no_fight'''') AND (UpdateKind <> ''''no_fight'''' OR (AggregateReportID IS NULL AND AggregateRevisionID IS NULL AND (StartScanID IS NULL OR EndScanID IS NULL OR (StartScanID = EndScanID AND StartRevisionID = EndRevisionID))))''),
(N''SourceUpdate'', N''CK_SourceUpdate_State'', N''DATALENGTH(UpdateState) = LEN(UpdateState) AND Version > 0 AND ((UpdateState = ''''waiting_player'''' AND (StartRevisionID IS NULL OR EndRevisionID IS NULL)) OR (UpdateState = ''''waiting_aggregate'''' AND UpdateKind <> ''''no_fight'''' AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL AND AggregateRevisionID IS NULL) OR (UpdateState IN (''''ready'''',''''selected'''',''''superseded'''',''''rejected'''') AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL AND (UpdateKind = ''''no_fight'''' OR AggregateRevisionID IS NOT NULL)))''),
(N''SourceUpdate'', N''CK_SourceUpdate_Confirmation'', N''LEN(ConfirmedBy) > 0 AND ISJSON(ConfirmationJson) = 1 AND DATALENGTH(ConfirmationJson) <= 65536 AND (BaseUpdateID IS NULL OR BaseUpdateID <> UpdateID) AND (CounterpartRevisionID IS NULL OR (BaseUpdateID IS NOT NULL AND ((StartRevisionID IS NOT NULL AND CounterpartRevisionID = StartRevisionID) OR (EndRevisionID IS NOT NULL AND CounterpartRevisionID = EndRevisionID) OR (AggregateRevisionID IS NOT NULL AND CounterpartRevisionID = AggregateRevisionID))))''),
(N''SourceCompleteSelection'', N''CK_SourceCompleteSelection_Version'', N''PublicSelectionVersion > 0''),
(N''SourceCompleteSelection'', N''CK_SourceCompleteSelection_Scope'', N''SourceKey = ''''snapshot_report_v1'''' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0''),
(N''SourceExportIntent'', N''CK_SourceExportIntent_Scope'', N''SourceKey = ''''snapshot_report_v1'''' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0''),
(N''SourceExportIntent'', N''CK_SourceExportIntent_Version'', N''CommitSequence > 0 AND LEN(ExportSchemaVersion) > 0 AND DATALENGTH(ExportSchemaVersion) = LEN(ExportSchemaVersion)''),
(N''SourceExportIntent'', N''CK_SourceExportIntent_State'', N''DATALENGTH(IntentState) = LEN(IntentState) AND IntentState IN (''''pending'''',''''waiting_destination'''',''''materialized'''',''''coalesced'''',''''confirmed'''',''''blocked'''') AND ((IntentState = ''''coalesced'''' AND SupersededByIntentID IS NOT NULL AND SupersededByIntentID <> IntentID) OR (IntentState <> ''''coalesced'''' AND SupersededByIntentID IS NULL))''),
(N''SourceExportIntentPublication'', N''CK_SourceExportIntentPublication_Version'', N''PublicSelectionVersion > 0''),
(N''SourceExportIntentPublication'', N''CK_SourceExportIntentPublication_Scope'', N''SourceKey = ''''snapshot_report_v1'''' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0'');

UPDATE @S8AColumns SET CollationName=CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),''Collation'')) WHERE CollationName IS NULL AND TypeName IN (''varchar'',''nvarchar'');
-- Compare both directions: extra/missing columns, keys, FKs or checks are incompatible.
DECLARE @S8AActualColumns TABLE (TableName sysname, Ordinal int, ColumnName sysname, TypeName sysname, MaxLength int, Scale int, CollationName sysname NULL, IsNullable bit);
INSERT INTO @S8AActualColumns
SELECT t.name,c.column_id,c.name,TYPE_NAME(c.user_type_id),c.max_length,c.scale,c.collation_name,c.is_nullable
FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id
WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns);
IF EXISTS (SELECT * FROM @S8AColumns EXCEPT SELECT * FROM @S8AActualColumns)
 OR EXISTS (SELECT * FROM @S8AActualColumns EXCEPT SELECT * FROM @S8AColumns)
    THROW 51810, ''S8A incompatible column shape.'', 1;
DECLARE @S8AActualKeys TABLE (TableName sysname, KeyName sysname, IsPrimary bit, Ordinal int, ColumnName sysname);
INSERT INTO @S8AActualKeys
SELECT t.name,i.name,i.is_primary_key,ic.key_ordinal,c.name
FROM sys.tables t JOIN sys.indexes i ON i.object_id=t.object_id
JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns);
IF EXISTS (SELECT * FROM @S8AKeys EXCEPT SELECT * FROM @S8AActualKeys)
 OR EXISTS (SELECT * FROM @S8AActualKeys EXCEPT SELECT * FROM @S8AKeys)
    THROW 51810, ''S8A incompatible key shape.'', 1;
IF EXISTS (SELECT 1 FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id
 WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns)
 AND (i.is_unique=0 OR i.is_disabled=1 OR i.has_filter=1 OR i.ignore_dup_key=1))
 OR EXISTS (SELECT 1 FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id
 WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns)
 AND (c.is_identity=1 OR c.is_computed=1 OR c.default_object_id<>0 OR c.rule_object_id<>0))
 OR EXISTS (SELECT 1 FROM sys.triggers tr JOIN sys.tables t ON t.object_id=tr.parent_id
 WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns))
    THROW 51810, ''S8A unexpected index, column behavior or trigger.'', 1;
DECLARE @S8AActualForeign TABLE (TableName sysname, KeyName sysname, Ordinal int, ColumnName sysname, ParentTable sysname, ParentColumn sysname);
INSERT INTO @S8AActualForeign
SELECT t.name,f.name,fc.constraint_column_id,c.name,pt.name,pc.name
FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id=f.parent_object_id
JOIN sys.tables pt ON pt.object_id=f.referenced_object_id
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns c ON c.object_id=fc.parent_object_id AND c.column_id=fc.parent_column_id
JOIN sys.columns pc ON pc.object_id=fc.referenced_object_id AND pc.column_id=fc.referenced_column_id
WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND pt.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns);
IF (SELECT COUNT(*) FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id=f.parent_object_id WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns))<>(SELECT COUNT(DISTINCT KeyName) FROM @S8AForeign)
 OR EXISTS (SELECT * FROM @S8AForeign EXCEPT SELECT * FROM @S8AActualForeign)
 OR EXISTS (SELECT * FROM @S8AActualForeign EXCEPT SELECT * FROM @S8AForeign)
 OR EXISTS (SELECT 1 FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id=f.parent_object_id
 WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns)
 AND (f.is_disabled=1 OR f.is_not_trusted=1 OR f.is_not_for_replication=1 OR f.delete_referential_action<>0 OR f.update_referential_action<>0))
    THROW 51810, ''S8A incompatible or untrusted foreign key.'', 1;
DECLARE @S8AActualChecks TABLE (TableName sysname, CheckName sysname, Definition nvarchar(max));
INSERT INTO @S8AActualChecks SELECT t.name,c.name,c.definition FROM sys.check_constraints c
JOIN sys.tables t ON t.object_id=c.parent_object_id
WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns);
DECLARE @S8AExpectedDefinitions TABLE (TableName sysname, Definition nvarchar(max));
CREATE TABLE #S8AShape1
(
    KVK_NO int NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    ChosenBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChosenUTC datetime2(0) NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    SeasonState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SeasonVersion bigint NOT NULL,
    CHECK (KVK_NO > 0 AND ((SourceKey = ''legacy_full_data'' AND DATALENGTH(SourceKey) = 16) OR (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18))),
    CHECK (DATALENGTH(SeasonState) = LEN(SeasonState) AND SeasonState IN (''planned'',''open'',''closing'',''closed'') AND SeasonVersion > 0),
    CHECK (LEN(ChosenBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);
INSERT INTO @S8AExpectedDefinitions SELECT N''SeasonSource'',definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N''tempdb..#S8AShape1'');
DROP TABLE #S8AShape1;
CREATE TABLE #S8AShape2
(
    UpdateID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    ConfigVersionID uniqueidentifier NOT NULL,
    RosterID uniqueidentifier NOT NULL,
    StartScanID int NULL,
    EndScanID int NULL,
    StartRevisionID uniqueidentifier NULL,
    EndRevisionID uniqueidentifier NULL,
    AggregateReportID uniqueidentifier NULL,
    AggregateRevisionID uniqueidentifier NULL,
    CoverageStartUTC datetime2(0) NOT NULL,
    CoverageEndUTC datetime2(0) NOT NULL,
    AsOfUTC datetime2(0) NOT NULL,
    UpdateKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    UpdateState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BaseUpdateID uniqueidentifier NULL,
    CounterpartRevisionID uniqueidentifier NULL,
    ConfirmedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ConfirmedUTC datetime2(0) NOT NULL,
    ConfirmationJson nvarchar(max) NOT NULL,
    RequestID uniqueidentifier NULL,
    ContentHash binary(32) NOT NULL,
    Version bigint NOT NULL,
    CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CHECK (CoverageEndUTC >= CoverageStartUTC AND AsOfUTC >= CoverageEndUTC),
    CHECK (((StartScanID IS NULL AND StartRevisionID IS NULL) OR (StartScanID IS NOT NULL AND StartRevisionID IS NOT NULL)) AND ((EndScanID IS NULL AND EndRevisionID IS NULL) OR (EndScanID IS NOT NULL AND EndRevisionID IS NOT NULL)) AND ((AggregateReportID IS NULL AND AggregateRevisionID IS NULL) OR (AggregateReportID IS NOT NULL AND AggregateRevisionID IS NOT NULL)) AND (StartScanID IS NULL OR EndScanID IS NULL OR EndScanID >= StartScanID)),
    CHECK (DATALENGTH(UpdateKind) = LEN(UpdateKind) AND UpdateKind IN (''fight'',''overall'',''no_fight'') AND (UpdateKind <> ''no_fight'' OR (AggregateReportID IS NULL AND AggregateRevisionID IS NULL AND (StartScanID IS NULL OR EndScanID IS NULL OR (StartScanID = EndScanID AND StartRevisionID = EndRevisionID))))),
    CHECK (DATALENGTH(UpdateState) = LEN(UpdateState) AND Version > 0 AND ((UpdateState = ''waiting_player'' AND (StartRevisionID IS NULL OR EndRevisionID IS NULL)) OR (UpdateState = ''waiting_aggregate'' AND UpdateKind <> ''no_fight'' AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL AND AggregateRevisionID IS NULL) OR (UpdateState IN (''ready'',''selected'',''superseded'',''rejected'') AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL AND (UpdateKind = ''no_fight'' OR AggregateRevisionID IS NOT NULL)))),
    CHECK (LEN(ConfirmedBy) > 0 AND ISJSON(ConfirmationJson) = 1 AND DATALENGTH(ConfirmationJson) <= 65536 AND (BaseUpdateID IS NULL OR BaseUpdateID <> UpdateID) AND (CounterpartRevisionID IS NULL OR (BaseUpdateID IS NOT NULL AND ((StartRevisionID IS NOT NULL AND CounterpartRevisionID = StartRevisionID) OR (EndRevisionID IS NOT NULL AND CounterpartRevisionID = EndRevisionID) OR (AggregateRevisionID IS NOT NULL AND CounterpartRevisionID = AggregateRevisionID)))))
);
INSERT INTO @S8AExpectedDefinitions SELECT N''SourceUpdate'',definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N''tempdb..#S8AShape2'');
DROP TABLE #S8AShape2;
CREATE TABLE #S8AShape3
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    UpdateID uniqueidentifier NOT NULL,
    PublicationID uniqueidentifier NOT NULL,
    PublicSelectionVersion bigint NOT NULL,
    SelectedUTC datetime2(0) NOT NULL,
    CHECK (PublicSelectionVersion > 0),
    CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
INSERT INTO @S8AExpectedDefinitions SELECT N''SourceCompleteSelection'',definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N''tempdb..#S8AShape3'');
DROP TABLE #S8AShape3;
CREATE TABLE #S8AShape4
(
    IntentID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    CommitSequence bigint NOT NULL,
    VectorHash binary(32) NOT NULL,
    ExportSchemaVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    IntentState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    SupersededByIntentID uniqueidentifier NULL,
    CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CHECK (CommitSequence > 0 AND LEN(ExportSchemaVersion) > 0 AND DATALENGTH(ExportSchemaVersion) = LEN(ExportSchemaVersion)),
    CHECK (DATALENGTH(IntentState) = LEN(IntentState) AND IntentState IN (''pending'',''waiting_destination'',''materialized'',''coalesced'',''confirmed'',''blocked'') AND ((IntentState = ''coalesced'' AND SupersededByIntentID IS NOT NULL AND SupersededByIntentID <> IntentID) OR (IntentState <> ''coalesced'' AND SupersededByIntentID IS NULL)))
);
INSERT INTO @S8AExpectedDefinitions SELECT N''SourceExportIntent'',definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N''tempdb..#S8AShape4'');
DROP TABLE #S8AShape4;
CREATE TABLE #S8AShape5
(
    IntentID uniqueidentifier NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    UpdateID uniqueidentifier NOT NULL,
    PublicationID uniqueidentifier NOT NULL,
    PublicSelectionVersion bigint NOT NULL,
    ConfigVersionID uniqueidentifier NOT NULL,
    CHECK (PublicSelectionVersion > 0),
    CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
INSERT INTO @S8AExpectedDefinitions SELECT N''SourceExportIntentPublication'',definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N''tempdb..#S8AShape5'');
DROP TABLE #S8AShape5;
IF EXISTS (SELECT TableName,CheckName FROM @S8AChecks EXCEPT SELECT TableName,CheckName FROM @S8AActualChecks)
 OR EXISTS (SELECT TableName,CheckName FROM @S8AActualChecks EXCEPT SELECT TableName,CheckName FROM @S8AChecks)
 OR EXISTS (SELECT TableName,Definition COLLATE Latin1_General_100_BIN2 FROM @S8AExpectedDefinitions EXCEPT SELECT TableName,Definition COLLATE Latin1_General_100_BIN2 FROM @S8AActualChecks)
 OR EXISTS (SELECT TableName,Definition COLLATE Latin1_General_100_BIN2 FROM @S8AActualChecks EXCEPT SELECT TableName,Definition COLLATE Latin1_General_100_BIN2 FROM @S8AExpectedDefinitions)
 OR EXISTS (SELECT 1 FROM sys.check_constraints c JOIN sys.tables t ON t.object_id=c.parent_object_id
 WHERE t.schema_id=SCHEMA_ID(N''KVK'') AND t.name IN (SELECT TableName FROM @S8AColumns)
 AND (c.is_disabled=1 OR c.is_not_trusted=1 OR c.is_not_for_replication=1))
    THROW 51810, ''S8A incompatible or untrusted CHECK.'', 1;
';
    CREATE TABLE #S8ALockedScopes (KVK_NO int NOT NULL PRIMARY KEY, LegacyRows bigint NOT NULL, SourceRows bigint NOT NULL);
    INSERT INTO #S8ALockedScopes SELECT * FROM @S8AScopes;
    EXEC sys.sp_executesql N'
IF EXISTS (SELECT 1 FROM KVK.SeasonSource s JOIN #S8AClassification c ON c.KVK_NO=s.KVK_NO
 WHERE s.SourceKey<>c.SourceKey COLLATE Latin1_General_100_BIN2 OR s.ChoiceID<>c.ChoiceID
 OR CONVERT(varbinary(max),s.ChosenBy)<>CONVERT(varbinary(max),c.ChosenBy) OR s.ChosenUTC<>c.ChosenUTC
 OR CONVERT(varbinary(max),s.Reason)<>CONVERT(varbinary(max),c.Reason)
 OR CONVERT(varbinary(max),s.ProvenanceJson)<>CONVERT(varbinary(max),c.ProvenanceJson))
    THROW 51801, ''S8A existing immutable choice/provenance conflict.'', 1;
IF EXISTS (SELECT 1 FROM #S8ALockedScopes h LEFT JOIN KVK.SeasonSource s ON s.KVK_NO=h.KVK_NO
 WHERE (s.KVK_NO IS NULL AND NOT EXISTS (SELECT 1 FROM #S8AClassification c WHERE c.KVK_NO=h.KVK_NO))
 OR (s.KVK_NO IS NOT NULL AND ((h.LegacyRows>0 AND s.SourceKey<>''legacy_full_data'') OR (h.SourceRows>0 AND s.SourceKey<>''snapshot_report_v1''))))
    THROW 51801, ''S8A unclassified or contradictory retained history.'', 1;
DECLARE @Expected bigint=(SELECT ExpectedNewChoices FROM #S8AApproval), @Actual bigint;
SELECT @Actual=COUNT_BIG(*) FROM #S8AClassification c WHERE NOT EXISTS (SELECT 1 FROM KVK.SeasonSource s WHERE s.KVK_NO=c.KVK_NO);
SELECT c.KVK_NO,c.SourceKey,c.ChoiceID,c.SeasonState,CASE WHEN s.KVK_NO IS NULL THEN ''insert'' ELSE ''verify_only'' END AS Operation
FROM #S8AClassification c LEFT JOIN KVK.SeasonSource s ON s.KVK_NO=c.KVK_NO ORDER BY c.KVK_NO;
IF @Expected<>@Actual THROW 51801, ''S8A expected new-choice count mismatch.'', 1;
INSERT INTO KVK.SeasonSource (KVK_NO,SourceKey,ChoiceID,ChosenBy,ChosenUTC,Reason,ProvenanceJson,SeasonState,SeasonVersion)
SELECT c.KVK_NO,c.SourceKey,c.ChoiceID,c.ChosenBy,c.ChosenUTC,c.Reason,c.ProvenanceJson,c.SeasonState,1
FROM #S8AClassification c WHERE NOT EXISTS (SELECT 1 FROM KVK.SeasonSource s WHERE s.KVK_NO=c.KVK_NO);
SET @Actual=@@ROWCOUNT;
IF @Actual<>@Expected THROW 51801, ''S8A actual new-choice count mismatch.'', 1;
IF EXISTS (SELECT 1 FROM #S8AClassification c LEFT JOIN KVK.SeasonSource s ON s.KVK_NO=c.KVK_NO AND s.ChoiceID=c.ChoiceID AND s.SourceKey=c.SourceKey COLLATE Latin1_General_100_BIN2 WHERE s.KVK_NO IS NULL)
    THROW 51801, ''S8A post-insert verification failed.'', 1;
SELECT @Actual AS NewChoices, COUNT_BIG(*) AS TotalChoices FROM KVK.SeasonSource;
';
    DROP TABLE #S8ALockedScopes;
    IF (SELECT Mode FROM #S8AApproval)='preview'
    BEGIN
        ROLLBACK TRANSACTION;
        SELECT 'preview_rolled_back' AS S8AOutcome;
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION;
        SELECT 'applied' AS S8AOutcome;
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
