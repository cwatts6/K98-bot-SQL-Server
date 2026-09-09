/*
MigrationId: 20260909_001_kvk_source_observation_facts
Purpose: Add isolated KVK source observation, roster and aggregate facts; no activation
Author: cwatts
CreatedUtc: 2026-09-09
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: 0 existing rows
PreValidationQuery: KVK schema exists; database compatibility >= 130; all twelve S2A names absent
PostValidationQuery: Twelve tables exist and all new FK/check constraints are enabled and trusted
RelatedBotPR: N/A
RelatedSQLPR: N/A
Dependencies: Accepted S1 typed schema and semantic_digest_v1; existing KVK schema
*/

-- S2A only. Source remains unwired. No legacy data, namespace or configuration changes.
-- Manual rollback: retain additive tables and accepted evidence with source disabled.
-- No DROP rollback; the deployment runner tracks repeat execution. Fail closed on any
-- pre-existing S2A name rather than blessing unknown/partial DDL as an idempotent success.
-- Source keys use Latin1_General_100_BIN2; deployment must verify collation availability.
-- Audit times are explicit UTC, never upload-time defaults. NULL selected pointers exist
-- only during later DAL-owned creation transactions; S2A cannot enforce commit-time policy.
-- S3B owns immutable writes, expected-version checks, row-set completeness and range locks.
-- LogicalScanID is supplied only for a newly accepted distinct player event; no allocator,
-- identity/default/trigger or aggregate dependency can advance the registry here.
-- Period FK and all publication/configuration/activation state belong to separately approved S2B.
-- Aggregate decimal values are supplied authority, never DKP or camp-sum calculations.
-- Writers must bind validated Decimal values exactly (reject scale loss before conversion);
-- SQL decimal conversion can round before a CHECK sees a value. Integration must verify this.
-- The runner may own an outer transaction. Commit only a transaction opened here; on failure
-- leave an outer transaction for the runner to roll back, and always propagate the error.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF SCHEMA_ID(N'KVK') IS NULL
    THROW 51000, 'S2A requires the existing KVK schema.', 1;
IF (SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID()) < 130
    THROW 51000, 'S2A requires SQL JSON support at compatibility level 130 or later.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.fn_helpcollations() WHERE name = N'Latin1_General_100_BIN2')
    THROW 51000, 'S2A requires its explicit source-key collation.', 1;
IF OBJECT_ID(N'KVK.SourceArtifact') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceImportAttempt') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceObservation') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceObservationRevision') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourcePlayerSnapshot') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceLogicalScan') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceRoster') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceRosterMember') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceAggregateReport') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceAggregateRevision') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceKingdomReportRow') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceCampReportRow') IS NOT NULL
    THROW 51000, 'S2A requires absent destination objects; inspect migration history and drift.', 1;

DECLARE @S2AOwnTransaction bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
BEGIN TRY
    IF @S2AOwnTransaction = 1 BEGIN TRANSACTION;

-- BEGIN TABLE SourceArtifact
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceArtifact
(
    ArtifactHash binary(32) NOT NULL,
    ByteCount bigint NOT NULL,
    StorageKey nvarchar(512) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceArtifact PRIMARY KEY (ArtifactHash),
    CONSTRAINT CK_SourceArtifact_Bytes CHECK (ByteCount > 0 AND ByteCount <= 20971520),
    CONSTRAINT CK_SourceArtifact_Storage CHECK (StorageKey = LOWER(CONVERT(varchar(64), ArtifactHash, 2)) + N'.xlsx' AND DATALENGTH(StorageKey) = 138)
);
-- END TABLE SourceArtifact

-- BEGIN TABLE SourceImportAttempt
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceImportAttempt
(
    AttemptID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    GuildID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    MessageID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AttachmentID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActionKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ArtifactHash binary(32) NOT NULL,
    ActorID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChannelID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OriginalFilename nvarchar(512) NOT NULL,
    ReceivedUTC datetime2(0) NOT NULL,
    Status varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    DiagnosticSummary nvarchar(512) NOT NULL,
    ObservationRevisionID uniqueidentifier NULL,
    AggregateRevisionID uniqueidentifier NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceImportAttempt PRIMARY KEY (AttemptID),
    CONSTRAINT UQ_SourceImportAttempt_Replay UNIQUE (GuildID, MessageID, AttachmentID, ActionKey),
    CONSTRAINT FK_SourceImportAttempt_Artifact FOREIGN KEY (ArtifactHash) REFERENCES KVK.SourceArtifact (ArtifactHash),
    CONSTRAINT CK_SourceImportAttempt_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceImportAttempt_Replay CHECK (LEN(GuildID) > 0 AND LEN(MessageID) > 0 AND LEN(AttachmentID) > 0 AND LEN(ActionKey) > 0 AND LEN(ChannelID) > 0 AND LEN(ActorID) > 0),
    CONSTRAINT CK_SourceImportAttempt_Result CHECK ((Status IN ('accepted','duplicate') AND ((ObservationRevisionID IS NOT NULL AND AggregateRevisionID IS NULL) OR (ObservationRevisionID IS NULL AND AggregateRevisionID IS NOT NULL))) OR (Status NOT IN ('accepted','duplicate') AND ObservationRevisionID IS NULL AND AggregateRevisionID IS NULL)),
    CONSTRAINT CK_SourceImportAttempt_Status CHECK (Status IN ('received','validated','rejected','accepted','duplicate','conflict')),
    CONSTRAINT CK_SourceImportAttempt_Provenance CHECK (ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);
-- END TABLE SourceImportAttempt

-- BEGIN TABLE SourceObservation
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceObservation
(
    ObservationID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ScanStartUTC datetime2(0) NOT NULL,
    TimePrecision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EventDiscriminator nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SelectedRevisionID uniqueidentifier NULL,
    SelectionVersion bigint NOT NULL,
    SupersedesObservationID uniqueidentifier NULL,
    CONSTRAINT PK_SourceObservation PRIMARY KEY (ObservationID),
    CONSTRAINT UQ_SourceObservation_Scope UNIQUE (SourceKey, KVK_NO, ObservationID),
    CONSTRAINT UQ_SourceObservation_Event UNIQUE (SourceKey, KVK_NO, ScanStartUTC, TimePrecision, EventDiscriminator),
    CONSTRAINT CK_SourceObservation_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceObservation_Time CHECK (TimePrecision IN ('minute','second') AND (TimePrecision <> 'minute' OR DATEPART(SECOND, ScanStartUTC) = 0)),
    CONSTRAINT CK_SourceObservation_Selection CHECK (SelectionVersion > 0),
    CONSTRAINT CK_SourceObservation_Event CHECK (LEN(EventDiscriminator) > 0),
    CONSTRAINT CK_SourceObservation_Supersedes CHECK (SupersedesObservationID IS NULL OR SupersedesObservationID <> ObservationID),
    CONSTRAINT FK_SourceObservation_Supersedes FOREIGN KEY (SourceKey, KVK_NO, SupersedesObservationID) REFERENCES KVK.SourceObservation (SourceKey, KVK_NO, ObservationID)
);
-- END TABLE SourceObservation

-- BEGIN TABLE SourceObservationRevision
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceObservationRevision
(
    RevisionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ObservationID uniqueidentifier NOT NULL,
    RevisionNo int NOT NULL,
    SemanticHash binary(32) NOT NULL,
    DigestVersion varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SchemaVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ArtifactHash binary(32) NOT NULL,
    SupersedesRevisionID uniqueidentifier NULL,
    AcceptanceState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AcceptedUTC datetime2(0) NOT NULL,
    AcceptedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    MetadataJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceObservationRevision PRIMARY KEY (RevisionID),
    CONSTRAINT UQ_SourceObservationRevision_Number UNIQUE (ObservationID, RevisionNo),
    CONSTRAINT UQ_SourceObservationRevision_Scope UNIQUE (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT UQ_SourceObservationRevision_Parent UNIQUE (SourceKey, KVK_NO, ObservationID, RevisionID),
    CONSTRAINT UQ_SourceObservationRevision_Digest UNIQUE (ObservationID, DigestVersion, SchemaVersion, SemanticHash),
    CONSTRAINT FK_SourceObservationRevision_Observation FOREIGN KEY (SourceKey, KVK_NO, ObservationID) REFERENCES KVK.SourceObservation (SourceKey, KVK_NO, ObservationID),
    CONSTRAINT FK_SourceObservationRevision_Artifact FOREIGN KEY (ArtifactHash) REFERENCES KVK.SourceArtifact (ArtifactHash),
    CONSTRAINT FK_SourceObservationRevision_Supersedes FOREIGN KEY (SourceKey, KVK_NO, ObservationID, SupersedesRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, ObservationID, RevisionID),
    CONSTRAINT CK_SourceObservationRevision_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceObservationRevision_Number CHECK (RevisionNo > 0),
    CONSTRAINT CK_SourceObservationRevision_Supersedes CHECK (SupersedesRevisionID IS NULL OR SupersedesRevisionID <> RevisionID),
    CONSTRAINT CK_SourceObservationRevision_State CHECK (AcceptanceState IN ('accepted','corrected') AND LEN(AcceptedBy) > 0 AND LEN(Reason) > 0 AND LEN(DigestVersion) > 0 AND LEN(SchemaVersion) > 0),
    CONSTRAINT CK_SourceObservationRevision_Metadata CHECK (ISJSON(MetadataJson) = 1 AND DATALENGTH(MetadataJson) <= 65536)
);
-- END TABLE SourceObservationRevision

-- BEGIN TABLE SourcePlayerSnapshot
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourcePlayerSnapshot
(
    RevisionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    GovernorID bigint NOT NULL,
    kingdom int NOT NULL,
    name nvarchar(256) NULL,
    alliance nvarchar(256) NULL,
    civilization nvarchar(256) NULL,
    power bigint NULL,
    city_hall bigint NULL,
    vip bigint NULL,
    t1_kills bigint NULL,
    t2_kills bigint NULL,
    t3_kills bigint NULL,
    t4_kills bigint NULL,
    t5_kills bigint NULL,
    total_kill_points bigint NULL,
    ranged_points bigint NULL,
    dead bigint NULL,
    healed bigint NULL,
    rss_assistance bigint NULL,
    alliance_helps bigint NULL,
    rss_gathered bigint NULL,
    troops_power bigint NULL,
    tech_power bigint NULL,
    building_power bigint NULL,
    commander_power bigint NULL,
    kvk_played bigint NULL,
    autarch_times bigint NULL,
    most_kvk_kill bigint NULL,
    most_kvk_dead bigint NULL,
    most_kvk_heal bigint NULL,
    acclaim bigint NULL,
    highest_acclaim bigint NULL,
    aoo_joined bigint NULL,
    aoo_won bigint NULL,
    aoo_avg_kill bigint NULL,
    aoo_avg_dead bigint NULL,
    aoo_avg_heal bigint NULL,
    FieldStatusJson nvarchar(4000) NOT NULL,
    RawProfileJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourcePlayerSnapshot PRIMARY KEY (RevisionID, GovernorID),
    CONSTRAINT FK_SourcePlayerSnapshot_Revision FOREIGN KEY (SourceKey, KVK_NO, RevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT CK_SourcePlayerSnapshot_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourcePlayerSnapshot_Identity CHECK (GovernorID > 0 AND kingdom > 0),
    CONSTRAINT CK_SourcePlayerSnapshot_Json CHECK (ISJSON(FieldStatusJson) = 1 AND ISJSON(RawProfileJson) = 1 AND DATALENGTH(RawProfileJson) <= 16777216),
    CONSTRAINT CK_SourcePlayerSnapshot_power CHECK (JSON_VALUE(FieldStatusJson, '$.power') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.power') = 'available' AND power IS NOT NULL AND power >= 0) OR (JSON_VALUE(FieldStatusJson, '$.power') IN ('invalid_source_value','unsupported','not_applicable') AND power IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_city_hall CHECK (JSON_VALUE(FieldStatusJson, '$.city_hall') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.city_hall') = 'available' AND city_hall IS NOT NULL AND city_hall >= 0) OR (JSON_VALUE(FieldStatusJson, '$.city_hall') IN ('invalid_source_value','unsupported','not_applicable') AND city_hall IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_vip CHECK (JSON_VALUE(FieldStatusJson, '$.vip') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.vip') = 'available' AND vip IS NOT NULL AND vip >= 0) OR (JSON_VALUE(FieldStatusJson, '$.vip') IN ('invalid_source_value','unsupported','not_applicable') AND vip IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_t1_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t1_kills') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.t1_kills') = 'available' AND t1_kills IS NOT NULL AND t1_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t1_kills') IN ('invalid_source_value','unsupported','not_applicable') AND t1_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_t2_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t2_kills') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.t2_kills') = 'available' AND t2_kills IS NOT NULL AND t2_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t2_kills') IN ('invalid_source_value','unsupported','not_applicable') AND t2_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_t3_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t3_kills') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.t3_kills') = 'available' AND t3_kills IS NOT NULL AND t3_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t3_kills') IN ('invalid_source_value','unsupported','not_applicable') AND t3_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_t4_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t4_kills') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.t4_kills') = 'available' AND t4_kills IS NOT NULL AND t4_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t4_kills') IN ('invalid_source_value','unsupported','not_applicable') AND t4_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_t5_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t5_kills') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.t5_kills') = 'available' AND t5_kills IS NOT NULL AND t5_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t5_kills') IN ('invalid_source_value','unsupported','not_applicable') AND t5_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_total_kill_points CHECK (JSON_VALUE(FieldStatusJson, '$.total_kill_points') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.total_kill_points') = 'available' AND total_kill_points IS NOT NULL AND total_kill_points >= 0) OR (JSON_VALUE(FieldStatusJson, '$.total_kill_points') IN ('invalid_source_value','unsupported','not_applicable') AND total_kill_points IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_ranged_points CHECK (JSON_VALUE(FieldStatusJson, '$.ranged_points') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.ranged_points') = 'available' AND ranged_points IS NOT NULL AND ranged_points >= 0) OR (JSON_VALUE(FieldStatusJson, '$.ranged_points') IN ('invalid_source_value','unsupported','not_applicable') AND ranged_points IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_dead CHECK (JSON_VALUE(FieldStatusJson, '$.dead') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.dead') = 'available' AND dead IS NOT NULL AND dead >= 0) OR (JSON_VALUE(FieldStatusJson, '$.dead') IN ('invalid_source_value','unsupported','not_applicable') AND dead IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_healed CHECK (JSON_VALUE(FieldStatusJson, '$.healed') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.healed') = 'available' AND healed IS NOT NULL AND healed >= 0) OR (JSON_VALUE(FieldStatusJson, '$.healed') IN ('invalid_source_value','unsupported','not_applicable') AND healed IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_rss_assistance CHECK (JSON_VALUE(FieldStatusJson, '$.rss_assistance') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.rss_assistance') = 'available' AND rss_assistance IS NOT NULL AND rss_assistance >= 0) OR (JSON_VALUE(FieldStatusJson, '$.rss_assistance') IN ('invalid_source_value','unsupported','not_applicable') AND rss_assistance IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_alliance_helps CHECK (JSON_VALUE(FieldStatusJson, '$.alliance_helps') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.alliance_helps') = 'available' AND alliance_helps IS NOT NULL AND alliance_helps >= 0) OR (JSON_VALUE(FieldStatusJson, '$.alliance_helps') IN ('invalid_source_value','unsupported','not_applicable') AND alliance_helps IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_rss_gathered CHECK (JSON_VALUE(FieldStatusJson, '$.rss_gathered') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.rss_gathered') = 'available' AND rss_gathered IS NOT NULL AND rss_gathered >= 0) OR (JSON_VALUE(FieldStatusJson, '$.rss_gathered') IN ('invalid_source_value','unsupported','not_applicable') AND rss_gathered IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_troops_power CHECK (JSON_VALUE(FieldStatusJson, '$.troops_power') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.troops_power') = 'available' AND troops_power IS NOT NULL AND troops_power >= 0) OR (JSON_VALUE(FieldStatusJson, '$.troops_power') IN ('invalid_source_value','unsupported','not_applicable') AND troops_power IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_tech_power CHECK (JSON_VALUE(FieldStatusJson, '$.tech_power') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.tech_power') = 'available' AND tech_power IS NOT NULL AND tech_power >= 0) OR (JSON_VALUE(FieldStatusJson, '$.tech_power') IN ('invalid_source_value','unsupported','not_applicable') AND tech_power IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_building_power CHECK (JSON_VALUE(FieldStatusJson, '$.building_power') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.building_power') = 'available' AND building_power IS NOT NULL AND building_power >= 0) OR (JSON_VALUE(FieldStatusJson, '$.building_power') IN ('invalid_source_value','unsupported','not_applicable') AND building_power IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_commander_power CHECK (JSON_VALUE(FieldStatusJson, '$.commander_power') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.commander_power') = 'available' AND commander_power IS NOT NULL AND commander_power >= 0) OR (JSON_VALUE(FieldStatusJson, '$.commander_power') IN ('invalid_source_value','unsupported','not_applicable') AND commander_power IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_kvk_played CHECK (JSON_VALUE(FieldStatusJson, '$.kvk_played') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.kvk_played') = 'available' AND kvk_played IS NOT NULL AND kvk_played >= 0) OR (JSON_VALUE(FieldStatusJson, '$.kvk_played') IN ('invalid_source_value','unsupported','not_applicable') AND kvk_played IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_autarch_times CHECK (JSON_VALUE(FieldStatusJson, '$.autarch_times') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.autarch_times') = 'available' AND autarch_times IS NOT NULL AND autarch_times >= 0) OR (JSON_VALUE(FieldStatusJson, '$.autarch_times') IN ('invalid_source_value','unsupported','not_applicable') AND autarch_times IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_most_kvk_kill CHECK (JSON_VALUE(FieldStatusJson, '$.most_kvk_kill') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.most_kvk_kill') = 'available' AND most_kvk_kill IS NOT NULL AND most_kvk_kill >= 0) OR (JSON_VALUE(FieldStatusJson, '$.most_kvk_kill') IN ('invalid_source_value','unsupported','not_applicable') AND most_kvk_kill IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_most_kvk_dead CHECK (JSON_VALUE(FieldStatusJson, '$.most_kvk_dead') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.most_kvk_dead') = 'available' AND most_kvk_dead IS NOT NULL AND most_kvk_dead >= 0) OR (JSON_VALUE(FieldStatusJson, '$.most_kvk_dead') IN ('invalid_source_value','unsupported','not_applicable') AND most_kvk_dead IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_most_kvk_heal CHECK (JSON_VALUE(FieldStatusJson, '$.most_kvk_heal') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.most_kvk_heal') = 'available' AND most_kvk_heal IS NOT NULL AND most_kvk_heal >= 0) OR (JSON_VALUE(FieldStatusJson, '$.most_kvk_heal') IN ('invalid_source_value','unsupported','not_applicable') AND most_kvk_heal IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_acclaim CHECK (JSON_VALUE(FieldStatusJson, '$.acclaim') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.acclaim') = 'available' AND acclaim IS NOT NULL AND acclaim >= 0) OR (JSON_VALUE(FieldStatusJson, '$.acclaim') IN ('invalid_source_value','unsupported','not_applicable') AND acclaim IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_highest_acclaim CHECK (JSON_VALUE(FieldStatusJson, '$.highest_acclaim') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.highest_acclaim') = 'available' AND highest_acclaim IS NOT NULL AND highest_acclaim >= 0) OR (JSON_VALUE(FieldStatusJson, '$.highest_acclaim') IN ('invalid_source_value','unsupported','not_applicable') AND highest_acclaim IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_aoo_joined CHECK (JSON_VALUE(FieldStatusJson, '$.aoo_joined') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.aoo_joined') = 'available' AND aoo_joined IS NOT NULL AND aoo_joined >= 0) OR (JSON_VALUE(FieldStatusJson, '$.aoo_joined') IN ('invalid_source_value','unsupported','not_applicable') AND aoo_joined IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_aoo_won CHECK (JSON_VALUE(FieldStatusJson, '$.aoo_won') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.aoo_won') = 'available' AND aoo_won IS NOT NULL AND aoo_won >= 0) OR (JSON_VALUE(FieldStatusJson, '$.aoo_won') IN ('invalid_source_value','unsupported','not_applicable') AND aoo_won IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_aoo_avg_kill CHECK (JSON_VALUE(FieldStatusJson, '$.aoo_avg_kill') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.aoo_avg_kill') = 'available' AND aoo_avg_kill IS NOT NULL AND aoo_avg_kill >= 0) OR (JSON_VALUE(FieldStatusJson, '$.aoo_avg_kill') IN ('invalid_source_value','unsupported','not_applicable') AND aoo_avg_kill IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_aoo_avg_dead CHECK (JSON_VALUE(FieldStatusJson, '$.aoo_avg_dead') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.aoo_avg_dead') = 'available' AND aoo_avg_dead IS NOT NULL AND aoo_avg_dead >= 0) OR (JSON_VALUE(FieldStatusJson, '$.aoo_avg_dead') IN ('invalid_source_value','unsupported','not_applicable') AND aoo_avg_dead IS NULL))),
    CONSTRAINT CK_SourcePlayerSnapshot_aoo_avg_heal CHECK (JSON_VALUE(FieldStatusJson, '$.aoo_avg_heal') IS NOT NULL AND ((JSON_VALUE(FieldStatusJson, '$.aoo_avg_heal') = 'available' AND aoo_avg_heal IS NOT NULL AND aoo_avg_heal >= 0) OR (JSON_VALUE(FieldStatusJson, '$.aoo_avg_heal') IN ('invalid_source_value','unsupported','not_applicable') AND aoo_avg_heal IS NULL)))
);
-- END TABLE SourcePlayerSnapshot

-- BEGIN TABLE SourceLogicalScan
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceLogicalScan
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    LogicalScanID int NOT NULL,
    ObservationID uniqueidentifier NOT NULL,
    AllocatedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceLogicalScan PRIMARY KEY (SourceKey, KVK_NO, LogicalScanID),
    CONSTRAINT UQ_SourceLogicalScan_Observation UNIQUE (SourceKey, KVK_NO, ObservationID),
    CONSTRAINT FK_SourceLogicalScan_Observation FOREIGN KEY (SourceKey, KVK_NO, ObservationID) REFERENCES KVK.SourceObservation (SourceKey, KVK_NO, ObservationID),
    CONSTRAINT CK_SourceLogicalScan_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceLogicalScan_ID CHECK (LogicalScanID > 0)
);
-- END TABLE SourceLogicalScan

-- BEGIN TABLE SourceRoster
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceRoster
(
    RosterID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    RosterVersion int NOT NULL,
    B0RevisionID uniqueidentifier NOT NULL,
    ScopeDigest binary(32) NOT NULL,
    MemberDigest binary(32) NOT NULL,
    MemberCount int NOT NULL,
    ApprovedUTC datetime2(0) NOT NULL,
    ApprovedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceRoster PRIMARY KEY (RosterID),
    CONSTRAINT UQ_SourceRoster_Version UNIQUE (SourceKey, KVK_NO, RosterVersion),
    CONSTRAINT UQ_SourceRoster_Scope UNIQUE (SourceKey, KVK_NO, RosterID),
    CONSTRAINT FK_SourceRoster_B0 FOREIGN KEY (SourceKey, KVK_NO, B0RevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT CK_SourceRoster_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceRoster_Version CHECK (RosterVersion > 0 AND MemberCount > 0 AND MemberCount <= 50000),
    CONSTRAINT CK_SourceRoster_Provenance CHECK (LEN(ApprovedBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);
-- END TABLE SourceRoster

-- BEGIN TABLE SourceRosterMember
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceRosterMember
(
    RosterID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    GovernorID bigint NOT NULL,
    b0_kingdom int NOT NULL,
    b0_power bigint NULL,
    CONSTRAINT PK_SourceRosterMember PRIMARY KEY (RosterID, GovernorID),
    CONSTRAINT FK_SourceRosterMember_Roster FOREIGN KEY (SourceKey, KVK_NO, RosterID) REFERENCES KVK.SourceRoster (SourceKey, KVK_NO, RosterID),
    CONSTRAINT CK_SourceRosterMember_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceRosterMember_Identity CHECK (GovernorID > 0 AND b0_kingdom > 0 AND (b0_power IS NULL OR b0_power >= 0))
);
-- END TABLE SourceRosterMember

-- BEGIN TABLE SourceAggregateReport
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceAggregateReport
(
    ReportID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SelectedRevisionID uniqueidentifier NULL,
    SelectionVersion bigint NOT NULL,
    CONSTRAINT PK_SourceAggregateReport PRIMARY KEY (ReportID),
    CONSTRAINT UQ_SourceAggregateReport_Period UNIQUE (SourceKey, KVK_NO, PeriodKey),
    CONSTRAINT UQ_SourceAggregateReport_Scope UNIQUE (SourceKey, KVK_NO, ReportID),
    CONSTRAINT UQ_SourceAggregateReport_Kind UNIQUE (SourceKey, KVK_NO, ReportID, PeriodKind),
    CONSTRAINT CK_SourceAggregateReport_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceAggregateReport_Period CHECK ((PeriodKind = 'fight' AND PeriodKey LIKE 'fight:%' AND LEN(PeriodKey) > 6) OR (PeriodKind = 'overall' AND PeriodKey = 'overall' AND DATALENGTH(PeriodKey) = 7)),
    CONSTRAINT CK_SourceAggregateReport_Selection CHECK (SelectionVersion > 0)
);
-- END TABLE SourceAggregateReport

-- BEGIN TABLE SourceAggregateRevision
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceAggregateRevision
(
    RevisionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ReportID uniqueidentifier NOT NULL,
    PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RevisionNo int NOT NULL,
    ArtifactHash binary(32) NOT NULL,
    SemanticHash binary(32) NOT NULL,
    DigestVersion varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SchemaVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ScanStartUTC datetime2(0) NOT NULL,
    TimePrecision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CoverageStartUTC datetime2(0) NOT NULL,
    CoverageEndUTC datetime2(0) NOT NULL,
    AsOfUTC datetime2(0) NOT NULL,
    ReportState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SupersedesRevisionID uniqueidentifier NULL,
    AcceptedUTC datetime2(0) NOT NULL,
    AcceptedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    MappingDigest binary(32) NOT NULL,
    ScopeDigest binary(32) NOT NULL,
    MetadataJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceAggregateRevision PRIMARY KEY (RevisionID),
    CONSTRAINT UQ_SourceAggregateRevision_Mapping UNIQUE (SourceKey, KVK_NO, RevisionID, MappingDigest),
    CONSTRAINT UQ_SourceAggregateRevision_Number UNIQUE (ReportID, RevisionNo),
    CONSTRAINT UQ_SourceAggregateRevision_Scope UNIQUE (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT UQ_SourceAggregateRevision_Parent UNIQUE (SourceKey, KVK_NO, ReportID, RevisionID),
    CONSTRAINT FK_SourceAggregateRevision_Report FOREIGN KEY (SourceKey, KVK_NO, ReportID, PeriodKind) REFERENCES KVK.SourceAggregateReport (SourceKey, KVK_NO, ReportID, PeriodKind),
    CONSTRAINT FK_SourceAggregateRevision_Artifact FOREIGN KEY (ArtifactHash) REFERENCES KVK.SourceArtifact (ArtifactHash),
    CONSTRAINT FK_SourceAggregateRevision_Supersedes FOREIGN KEY (SourceKey, KVK_NO, ReportID, SupersedesRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, ReportID, RevisionID),
    CONSTRAINT CK_SourceAggregateRevision_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceAggregateRevision_Number CHECK (RevisionNo > 0),
    CONSTRAINT CK_SourceAggregateRevision_Time CHECK (TimePrecision IN ('minute','second') AND (TimePrecision <> 'minute' OR DATEPART(SECOND, ScanStartUTC) = 0) AND CoverageEndUTC >= CoverageStartUTC AND AsOfUTC >= CoverageEndUTC),
    CONSTRAINT CK_SourceAggregateRevision_State CHECK (ReportState IN ('live','final','corrected_final') AND (PeriodKind <> 'overall' OR ReportState IN ('final','corrected_final')) AND (ReportState <> 'corrected_final' OR SupersedesRevisionID IS NOT NULL)),
    CONSTRAINT CK_SourceAggregateRevision_Supersedes CHECK (SupersedesRevisionID IS NULL OR SupersedesRevisionID <> RevisionID),
    CONSTRAINT CK_SourceAggregateRevision_Metadata CHECK (LEN(AcceptedBy) > 0 AND LEN(Reason) > 0 AND LEN(DigestVersion) > 0 AND LEN(SchemaVersion) > 0 AND ISJSON(MetadataJson) = 1 AND DATALENGTH(MetadataJson) <= 65536)
);
CREATE INDEX IX_SourceAggregateRevision_AsOf ON KVK.SourceAggregateRevision (ReportID, AsOfUTC);
-- END TABLE SourceAggregateRevision

-- BEGIN TABLE SourceKingdomReportRow
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceKingdomReportRow
(
    RevisionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    Kingdom int NOT NULL,
    CampID tinyint NOT NULL,
    CampLabel nvarchar(256) NOT NULL,
    MappingDigest binary(32) NOT NULL,
    t4_kills decimal(38,6) NOT NULL,
    t4_kills_raw nvarchar(128) NOT NULL,
    t4_kills_unit decimal(38,6) NOT NULL,
    t4_kills_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    t5_kills decimal(38,6) NOT NULL,
    t5_kills_raw nvarchar(128) NOT NULL,
    t5_kills_unit decimal(38,6) NOT NULL,
    t5_kills_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    kp_t4_t5 decimal(38,6) NOT NULL,
    kp_t4_t5_raw nvarchar(128) NOT NULL,
    kp_t4_t5_unit decimal(38,6) NOT NULL,
    kp_t4_t5_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    dead decimal(38,6) NOT NULL,
    dead_raw nvarchar(128) NOT NULL,
    dead_unit decimal(38,6) NOT NULL,
    dead_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    t4_t5_dead decimal(38,6) NOT NULL,
    t4_t5_dead_raw nvarchar(128) NOT NULL,
    t4_t5_dead_unit decimal(38,6) NOT NULL,
    t4_t5_dead_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    healed decimal(38,6) NOT NULL,
    healed_raw nvarchar(128) NOT NULL,
    healed_unit decimal(38,6) NOT NULL,
    healed_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    acclaim decimal(38,6) NOT NULL,
    acclaim_raw nvarchar(128) NOT NULL,
    acclaim_unit decimal(38,6) NOT NULL,
    acclaim_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    dkp decimal(38,6) NOT NULL,
    dkp_raw nvarchar(128) NOT NULL,
    dkp_unit decimal(38,6) NOT NULL,
    dkp_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RawCellsJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceKingdomReportRow PRIMARY KEY (RevisionID, Kingdom),
    CONSTRAINT FK_SourceKingdomReportRow_Revision FOREIGN KEY (SourceKey, KVK_NO, RevisionID, MappingDigest) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, RevisionID, MappingDigest),
    CONSTRAINT CK_SourceKingdomReportRow_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceKingdomReportRow_Identity CHECK (Kingdom > 0 AND CampID BETWEEN 1 AND 8 AND LEN(CampLabel) > 0),
    CONSTRAINT CK_SourceKingdomReportRow_Raw CHECK (ISJSON(RawCellsJson) = 1 AND DATALENGTH(RawCellsJson) <= 1048576),
    CONSTRAINT CK_SourceKingdomReportRow_t4_kills CHECK (t4_kills >= 0 AND t4_kills_unit > 0 AND LEN(t4_kills_raw) > 0 AND t4_kills_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceKingdomReportRow_t5_kills CHECK (t5_kills >= 0 AND t5_kills_unit > 0 AND LEN(t5_kills_raw) > 0 AND t5_kills_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceKingdomReportRow_kp_t4_t5 CHECK (kp_t4_t5 >= 0 AND kp_t4_t5_unit > 0 AND LEN(kp_t4_t5_raw) > 0 AND kp_t4_t5_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceKingdomReportRow_dead CHECK (dead >= 0 AND dead_unit > 0 AND LEN(dead_raw) > 0 AND dead_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceKingdomReportRow_t4_t5_dead CHECK (t4_t5_dead >= 0 AND t4_t5_dead_unit > 0 AND LEN(t4_t5_dead_raw) > 0 AND t4_t5_dead_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceKingdomReportRow_healed CHECK (healed >= 0 AND healed_unit > 0 AND LEN(healed_raw) > 0 AND healed_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceKingdomReportRow_acclaim CHECK (acclaim >= 0 AND acclaim_unit > 0 AND LEN(acclaim_raw) > 0 AND acclaim_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceKingdomReportRow_dkp CHECK (dkp >= 0 AND dkp_unit > 0 AND LEN(dkp_raw) > 0 AND dkp_precision IN ('reported_numeric','reported_abbreviated'))
);
-- END TABLE SourceKingdomReportRow

-- BEGIN TABLE SourceCampReportRow
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceCampReportRow
(
    RevisionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    CampID tinyint NOT NULL,
    CampLabel nvarchar(256) NOT NULL,
    MappingDigest binary(32) NOT NULL,
    t4_kills decimal(38,6) NOT NULL,
    t4_kills_raw nvarchar(128) NOT NULL,
    t4_kills_unit decimal(38,6) NOT NULL,
    t4_kills_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    t5_kills decimal(38,6) NOT NULL,
    t5_kills_raw nvarchar(128) NOT NULL,
    t5_kills_unit decimal(38,6) NOT NULL,
    t5_kills_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    kp_t4_t5 decimal(38,6) NOT NULL,
    kp_t4_t5_raw nvarchar(128) NOT NULL,
    kp_t4_t5_unit decimal(38,6) NOT NULL,
    kp_t4_t5_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    dead decimal(38,6) NOT NULL,
    dead_raw nvarchar(128) NOT NULL,
    dead_unit decimal(38,6) NOT NULL,
    dead_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    t4_t5_dead decimal(38,6) NOT NULL,
    t4_t5_dead_raw nvarchar(128) NOT NULL,
    t4_t5_dead_unit decimal(38,6) NOT NULL,
    t4_t5_dead_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    healed decimal(38,6) NOT NULL,
    healed_raw nvarchar(128) NOT NULL,
    healed_unit decimal(38,6) NOT NULL,
    healed_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    acclaim decimal(38,6) NOT NULL,
    acclaim_raw nvarchar(128) NOT NULL,
    acclaim_unit decimal(38,6) NOT NULL,
    acclaim_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    dkp decimal(38,6) NOT NULL,
    dkp_raw nvarchar(128) NOT NULL,
    dkp_unit decimal(38,6) NOT NULL,
    dkp_precision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RawCellsJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceCampReportRow PRIMARY KEY (RevisionID, CampID),
    CONSTRAINT FK_SourceCampReportRow_Revision FOREIGN KEY (SourceKey, KVK_NO, RevisionID, MappingDigest) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, RevisionID, MappingDigest),
    CONSTRAINT CK_SourceCampReportRow_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceCampReportRow_Identity CHECK (CampID BETWEEN 1 AND 8 AND LEN(CampLabel) > 0),
    CONSTRAINT CK_SourceCampReportRow_Raw CHECK (ISJSON(RawCellsJson) = 1 AND DATALENGTH(RawCellsJson) <= 1048576),
    CONSTRAINT CK_SourceCampReportRow_t4_kills CHECK (t4_kills >= 0 AND t4_kills_unit > 0 AND LEN(t4_kills_raw) > 0 AND t4_kills_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceCampReportRow_t5_kills CHECK (t5_kills >= 0 AND t5_kills_unit > 0 AND LEN(t5_kills_raw) > 0 AND t5_kills_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceCampReportRow_kp_t4_t5 CHECK (kp_t4_t5 >= 0 AND kp_t4_t5_unit > 0 AND LEN(kp_t4_t5_raw) > 0 AND kp_t4_t5_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceCampReportRow_dead CHECK (dead >= 0 AND dead_unit > 0 AND LEN(dead_raw) > 0 AND dead_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceCampReportRow_t4_t5_dead CHECK (t4_t5_dead >= 0 AND t4_t5_dead_unit > 0 AND LEN(t4_t5_dead_raw) > 0 AND t4_t5_dead_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceCampReportRow_healed CHECK (healed >= 0 AND healed_unit > 0 AND LEN(healed_raw) > 0 AND healed_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceCampReportRow_acclaim CHECK (acclaim >= 0 AND acclaim_unit > 0 AND LEN(acclaim_raw) > 0 AND acclaim_precision IN ('reported_numeric','reported_abbreviated')),
    CONSTRAINT CK_SourceCampReportRow_dkp CHECK (dkp >= 0 AND dkp_unit > 0 AND LEN(dkp_raw) > 0 AND dkp_precision IN ('reported_numeric','reported_abbreviated'))
);
-- END TABLE SourceCampReportRow

-- Added after all twelve tables exist; an alias retains its exact accepted outcome.
ALTER TABLE KVK.SourceImportAttempt WITH CHECK ADD CONSTRAINT FK_SourceImportAttempt_ObservationRevision FOREIGN KEY (SourceKey, KVK_NO, ObservationRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID);
ALTER TABLE KVK.SourceImportAttempt WITH CHECK ADD CONSTRAINT FK_SourceImportAttempt_AggregateRevision FOREIGN KEY (SourceKey, KVK_NO, AggregateRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, RevisionID);

-- Circular selected-revision links: install after all twelve CREATE TABLE statements.
ALTER TABLE KVK.SourceObservation WITH CHECK ADD CONSTRAINT FK_SourceObservation_SelectedRevision FOREIGN KEY (SourceKey, KVK_NO, ObservationID, SelectedRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, ObservationID, RevisionID);
ALTER TABLE KVK.SourceAggregateReport WITH CHECK ADD CONSTRAINT FK_SourceAggregateReport_SelectedRevision FOREIGN KEY (SourceKey, KVK_NO, ReportID, SelectedRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, ReportID, RevisionID);

IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'KVK') AND name IN (N'SourceArtifact', N'SourceImportAttempt', N'SourceObservation', N'SourceObservationRevision', N'SourcePlayerSnapshot', N'SourceLogicalScan', N'SourceRoster', N'SourceRosterMember', N'SourceAggregateReport', N'SourceAggregateRevision', N'SourceKingdomReportRow', N'SourceCampReportRow')) <> 12
    THROW 51000, 'S2A table manifest post-validation failed.', 1;
IF EXISTS (
    SELECT 1 FROM sys.foreign_keys c JOIN sys.tables t ON t.object_id = c.parent_object_id
    WHERE t.schema_id = SCHEMA_ID(N'KVK') AND t.name IN (N'SourceArtifact', N'SourceImportAttempt', N'SourceObservation', N'SourceObservationRevision', N'SourcePlayerSnapshot', N'SourceLogicalScan', N'SourceRoster', N'SourceRosterMember', N'SourceAggregateReport', N'SourceAggregateRevision', N'SourceKingdomReportRow', N'SourceCampReportRow')
      AND (c.is_disabled = 1 OR c.is_not_trusted = 1)
    UNION ALL
    SELECT 1 FROM sys.check_constraints c JOIN sys.tables t ON t.object_id = c.parent_object_id
    WHERE t.schema_id = SCHEMA_ID(N'KVK') AND t.name IN (N'SourceArtifact', N'SourceImportAttempt', N'SourceObservation', N'SourceObservationRevision', N'SourcePlayerSnapshot', N'SourceLogicalScan', N'SourceRoster', N'SourceRosterMember', N'SourceAggregateReport', N'SourceAggregateRevision', N'SourceKingdomReportRow', N'SourceCampReportRow')
      AND (c.is_disabled = 1 OR c.is_not_trusted = 1)
)
    THROW 51000, 'S2A constraints must be enabled and trusted.', 1;
    IF @S2AOwnTransaction = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @S2AOwnTransaction = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
