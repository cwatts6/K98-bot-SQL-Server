/*
MigrationId: 20260910_001_kvk_source_publication_state
Purpose: Add isolated source configuration, publication, routing and delivery state
Author: cwatts
CreatedUtc: 2026-09-10
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing rows
PreValidationQuery: Accepted S2A tables and trusted constraints; no S2B names or orphan aggregate families
PostValidationQuery: Thirteen S2B tables; trusted constraints; no source activation or existing data changes
RelatedBotPR: N/A
RelatedSQLPR: N/A
Dependencies: Accepted 20260909_001_kvk_source_observation_facts; SQL PR 78
*/
-- Additive S2B only. Retain disabled tables/history for manual rollback; no destructive downgrade.
-- Refuse existing/partial objects and orphan report families; never backfill or delete evidence.
-- Run before any S3B writer. The new Period table starts empty: existing aggregate families
-- therefore require separately reviewed reconciliation, not automatic inferred period creation.
-- DDL and trusted FK installation are atomic; outer deployment transactions remain caller-owned.
-- No procedures, grants, default activation, legacy config changes, imports or calculations.
-- SourceScanBinding resolves its observation through the exact SourceLogicalScan FK, avoiding
-- a redundant writable observation identity. S3B must match publication revisions to that scan.
-- S3B must also match aggregate report to period, pin approved config component digests, enforce
-- camp-key -> CampID/name consistency and complete scope, validate source coefficient round-trip
-- strings/Decimal scale BEFORE binding (SQL conversion can round), and validate exact endpoints.
-- These relational checks cannot prove those multi-row/semantic contracts without later DAL.
-- Configs/periods/inputs/results/actions remain immutable under S3B write policy; status flags and
-- counts alone do not prove completeness. SelectionVersion/Fence are positive storage foundations;
-- S3B/S4B implement CAS, monotonic updates, lock order, digest/count validation and receipt recovery.
-- Store UTC scan start through immutable observation references; never infer it from CreatedUTC.
-- Endpoint requests permit absent desired scans. 13 -> 14 -> 13 has a new base config identity.
-- Aggregate uploads and semantic re-exports cannot allocate scans here; daily SCANORDER is separate.
-- No selection or action rows are inserted by this migration. Destination IDs/receipts are opaque
-- identifiers, never credentials, paths or authority to send; S4B validates them before use.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;
IF SCHEMA_ID(N'KVK') IS NULL OR (SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID()) < 130
    THROW 51200, 'S2B requires KVK schema and SQL JSON compatibility.', 1;
IF OBJECT_ID(N'KVK.SourceArtifact', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceImportAttempt', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceObservation', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceObservationRevision', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourcePlayerSnapshot', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceLogicalScan', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceRoster', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceRosterMember', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceAggregateReport', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceAggregateRevision', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceKingdomReportRow', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceCampReportRow', N'U') IS NULL
    THROW 51200, 'S2B requires accepted S2A prerequisites.', 1;
IF OBJECT_ID(N'KVK.SourceConfigVersion') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourcePeriod') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceWindowConfig') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceCampConfig') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceWeightConfig') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceScanBinding') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceConfigRequest') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourcePublication') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourcePlayerResult') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceSelection') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceRouting') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceAction') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF OBJECT_ID(N'KVK.SourceDelivery') IS NOT NULL
    THROW 51200, 'S2B destination exists; inspect migration history and drift.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE schema_id = SCHEMA_ID(N'KVK') AND (is_disabled = 1 OR is_not_trusted = 1))
 OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE schema_id = SCHEMA_ID(N'KVK') AND (is_disabled = 1 OR is_not_trusted = 1))
    THROW 51200, 'S2B requires enabled trusted prerequisite constraints.', 1;
DECLARE @S2BOwnTransaction bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
BEGIN TRY
    IF @S2BOwnTransaction = 1 BEGIN TRANSACTION;
    -- Hold report-family range until FK installation. Empty new Period cannot match old reports.
    IF EXISTS (SELECT 1 FROM KVK.SourceAggregateReport WITH (TABLOCKX, HOLDLOCK))
        THROW 51200, 'Existing aggregate families have no S2B periods; explicit reconciliation required.', 1;
CREATE TABLE KVK.SourceConfigVersion
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ConfigVersion int NOT NULL,
    RosterID uniqueidentifier NOT NULL,
    ConfigContentHash binary(32) NOT NULL,
    WindowDigest binary(32) NOT NULL,
    MappingDigest binary(32) NOT NULL,
    WeightDigest binary(32) NOT NULL,
    ApprovedUTC datetime2(0) NOT NULL,
    ApprovedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceConfigVersion PRIMARY KEY (ConfigVersionID),
    CONSTRAINT UQ_SourceConfigVersion_Version UNIQUE (SourceKey, KVK_NO, ConfigVersion),
    CONSTRAINT UQ_SourceConfigVersion_Scope UNIQUE (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT UQ_SourceConfigVersion_Roster UNIQUE (SourceKey, KVK_NO, ConfigVersionID, RosterID),
    CONSTRAINT FK_SourceConfigVersion_Roster FOREIGN KEY (SourceKey, KVK_NO, RosterID) REFERENCES KVK.SourceRoster (SourceKey, KVK_NO, RosterID),
    CONSTRAINT CK_SourceConfigVersion_Version CHECK (ConfigVersion > 0),
    CONSTRAINT CK_SourceConfigVersion_Provenance CHECK (LEN(ApprovedBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536),
    CONSTRAINT CK_SourceConfigVersion_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourcePeriod
(
    PeriodID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CoverageStartUTC datetime2(0) NOT NULL,
    CoverageEndUTC datetime2(0) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourcePeriod PRIMARY KEY (PeriodID),
    CONSTRAINT UQ_SourcePeriod_Key UNIQUE (SourceKey, KVK_NO, PeriodKey),
    CONSTRAINT UQ_SourcePeriod_Kind UNIQUE (SourceKey, KVK_NO, PeriodKey, PeriodKind),
    CONSTRAINT UQ_SourcePeriod_Scope UNIQUE (SourceKey, KVK_NO, PeriodID),
    CONSTRAINT UQ_SourcePeriod_Identity UNIQUE (SourceKey, KVK_NO, PeriodID, PeriodKey),
    CONSTRAINT CK_SourcePeriod_Kind CHECK (DATALENGTH(PeriodKind) = LEN(PeriodKind) AND DATALENGTH(PeriodKey) = LEN(PeriodKey) AND ((PeriodKind = 'fight' AND PeriodKey LIKE 'fight:%' AND LEN(PeriodKey) > 6) OR (PeriodKind = 'overall' AND PeriodKey = 'overall') OR (PeriodKind = 'no_fight' AND PeriodKey LIKE 'no_fight:%' AND LEN(PeriodKey) > 9))),
    CONSTRAINT CK_SourcePeriod_Time CHECK (CoverageEndUTC IS NULL OR CoverageEndUTC >= CoverageStartUTC),
    CONSTRAINT CK_SourcePeriod_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceWindowConfig
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    WindowName nvarchar(40) COLLATE Latin1_General_CI_AS NOT NULL,
    WindowSeq tinyint NULL,
    StartScanID int NULL,
    EndScanID int NULL,
    Notes nvarchar(200) NULL,
    UpdatedAtUTC datetime2(0) NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CONSTRAINT PK_SourceWindowConfig PRIMARY KEY (ConfigVersionID, WindowName),
    CONSTRAINT UQ_SourceWindowConfig_Period UNIQUE (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT FK_SourceWindowConfig_Config FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT FK_SourceWindowConfig_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodKey) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodKey),
    CONSTRAINT CK_SourceWindowConfig_Bounds CHECK ((StartScanID IS NULL OR StartScanID > 0) AND (EndScanID IS NULL OR EndScanID > 0) AND (EndScanID IS NULL OR StartScanID IS NULL OR EndScanID >= StartScanID)),
    CONSTRAINT CK_SourceWindowConfig_Name CHECK (LEN(WindowName) > 0),
    CONSTRAINT CK_SourceWindowConfig_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceCampConfig
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    Kingdom int NOT NULL,
    CampID tinyint NOT NULL,
    CampName nvarchar(40) COLLATE Latin1_General_CI_AS NOT NULL,
    CampKey nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CONSTRAINT PK_SourceCampConfig PRIMARY KEY (ConfigVersionID, Kingdom),
    CONSTRAINT UQ_SourceCampConfig_Attribution UNIQUE (ConfigVersionID, Kingdom, CampID),
    CONSTRAINT FK_SourceCampConfig_Config FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT CK_SourceCampConfig_Identity CHECK (Kingdom > 0 AND CampID BETWEEN 1 AND 8 AND LEN(CampName) > 0 AND LEN(CampKey) > 0 AND DATALENGTH(CampKey) = DATALENGTH(LTRIM(RTRIM(CampKey)))),
    CONSTRAINT CK_SourceCampConfig_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceWeightConfig
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    WeightT4X decimal(38,12) NOT NULL,
    WeightT5Y decimal(38,12) NOT NULL,
    WeightDeadsZ decimal(38,12) NOT NULL,
    WeightT4XSource varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    WeightT5YSource varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    WeightDeadsZSource varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EffectiveFromUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceWeightConfig PRIMARY KEY (ConfigVersionID),
    CONSTRAINT FK_SourceWeightConfig_Config FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT CK_SourceWeightConfig_Strings CHECK (LEN(WeightT4XSource) > 0 AND LEN(WeightT5YSource) > 0 AND LEN(WeightDeadsZSource) > 0),
    CONSTRAINT CK_SourceWeightConfig_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceScanBinding
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    LogicalScanID int NOT NULL,
    CONSTRAINT PK_SourceScanBinding PRIMARY KEY (ConfigVersionID, LogicalScanID),
    CONSTRAINT FK_SourceScanBinding_Config FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT FK_SourceScanBinding_Scan FOREIGN KEY (SourceKey, KVK_NO, LogicalScanID) REFERENCES KVK.SourceLogicalScan (SourceKey, KVK_NO, LogicalScanID),
    CONSTRAINT CK_SourceScanBinding_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceConfigRequest
(
    RequestID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BaseConfigVersionID uniqueidentifier NOT NULL,
    DesiredConfigVersionID uniqueidentifier NOT NULL,
    ConfigContentHash binary(32) NOT NULL,
    OldStartScanID int NULL,
    OldEndScanID int NULL,
    NewStartScanID int NULL,
    NewEndScanID int NULL,
    Origin varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RequestedUTC datetime2(0) NOT NULL,
    RequestState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AppliedPublicationID uniqueidentifier NULL,
    CompletedUTC datetime2(0) NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceConfigRequest PRIMARY KEY (RequestID),
    CONSTRAINT UQ_SourceConfigRequest_Replay UNIQUE (SourceKey, KVK_NO, ConfigContentHash, BaseConfigVersionID),
    CONSTRAINT UQ_SourceConfigRequest_Scope UNIQUE (SourceKey, KVK_NO, PeriodID, RequestID),
    CONSTRAINT FK_SourceConfigRequest_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PeriodKey) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodID, PeriodKey),
    CONSTRAINT FK_SourceConfigRequest_Base FOREIGN KEY (SourceKey, KVK_NO, BaseConfigVersionID, PeriodKey) REFERENCES KVK.SourceWindowConfig (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT FK_SourceConfigRequest_Desired FOREIGN KEY (SourceKey, KVK_NO, DesiredConfigVersionID, PeriodKey) REFERENCES KVK.SourceWindowConfig (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT CK_SourceConfigRequest_Versions CHECK (BaseConfigVersionID <> DesiredConfigVersionID),
    CONSTRAINT CK_SourceConfigRequest_Endpoints CHECK ((OldStartScanID IS NULL OR OldStartScanID > 0) AND (OldEndScanID IS NULL OR OldEndScanID > 0) AND (NewStartScanID IS NULL OR NewStartScanID > 0) AND (NewEndScanID IS NULL OR NewEndScanID > 0) AND (OldEndScanID IS NULL OR OldStartScanID IS NULL OR OldEndScanID >= OldStartScanID) AND (NewEndScanID IS NULL OR NewStartScanID IS NULL OR NewEndScanID >= NewStartScanID)),
    CONSTRAINT CK_SourceConfigRequest_State CHECK (DATALENGTH(RequestState) = LEN(RequestState) AND ((RequestState IN ('requested','pending') AND AppliedPublicationID IS NULL AND CompletedUTC IS NULL) OR (RequestState = 'applied' AND AppliedPublicationID IS NOT NULL AND CompletedUTC IS NOT NULL) OR (RequestState = 'rejected' AND AppliedPublicationID IS NULL AND CompletedUTC IS NOT NULL)) AND (CompletedUTC IS NULL OR CompletedUTC >= RequestedUTC)),
    CONSTRAINT CK_SourceConfigRequest_Provenance CHECK (Origin IN ('authorized_import','admin','system') AND DATALENGTH(Origin) = LEN(Origin) AND LEN(Actor) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536),
    CONSTRAINT CK_SourceConfigRequest_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourcePublication
(
    PublicationID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Generation bigint NOT NULL,
    ConfigVersionID uniqueidentifier NOT NULL,
    RosterID uniqueidentifier NOT NULL,
    CalculationVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    StartScanID int NULL,
    EndScanID int NULL,
    StartRevisionID uniqueidentifier NULL,
    EndRevisionID uniqueidentifier NULL,
    AggregateReportID uniqueidentifier NULL,
    AggregateRevisionID uniqueidentifier NULL,
    PlayerState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AggregateState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PeriodState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BuildState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EligibleCount int NOT NULL,
    ResultCount int NOT NULL,
    KingdomCount int NOT NULL,
    CampCount int NOT NULL,
    ManifestHash binary(32) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    CompletedUTC datetime2(0) NULL,
    FinalUnavailableReason nvarchar(1024) NULL,
    CONSTRAINT PK_SourcePublication PRIMARY KEY (PublicationID),
    CONSTRAINT UQ_SourcePublication_Generation UNIQUE (SourceKey, KVK_NO, PeriodID, Generation),
    CONSTRAINT UQ_SourcePublication_Scope UNIQUE (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT UQ_SourcePublication_Config UNIQUE (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID),
    CONSTRAINT UQ_SourcePublication_Result UNIQUE (SourceKey, KVK_NO, PublicationID, ConfigVersionID, RosterID),
    CONSTRAINT FK_SourcePublication_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PeriodKey) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodID, PeriodKey),
    CONSTRAINT FK_SourcePublication_Window FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID, PeriodKey) REFERENCES KVK.SourceWindowConfig (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT FK_SourcePublication_ConfigRoster FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID, RosterID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID, RosterID),
    CONSTRAINT FK_SourcePublication_StartBinding FOREIGN KEY (ConfigVersionID, StartScanID) REFERENCES KVK.SourceScanBinding (ConfigVersionID, LogicalScanID),
    CONSTRAINT FK_SourcePublication_EndBinding FOREIGN KEY (ConfigVersionID, EndScanID) REFERENCES KVK.SourceScanBinding (ConfigVersionID, LogicalScanID),
    CONSTRAINT FK_SourcePublication_StartRevision FOREIGN KEY (SourceKey, KVK_NO, StartRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT FK_SourcePublication_EndRevision FOREIGN KEY (SourceKey, KVK_NO, EndRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT FK_SourcePublication_Aggregate FOREIGN KEY (SourceKey, KVK_NO, AggregateReportID, AggregateRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, ReportID, RevisionID),
    CONSTRAINT CK_SourcePublication_Counts CHECK (Generation > 0 AND EligibleCount BETWEEN 1 AND 50000 AND ResultCount BETWEEN 0 AND EligibleCount AND KingdomCount BETWEEN 0 AND 512 AND CampCount BETWEEN 0 AND 8 AND LEN(CalculationVersion) > 0),
    CONSTRAINT CK_SourcePublication_Inputs CHECK (((StartScanID IS NULL AND StartRevisionID IS NULL) OR (StartScanID IS NOT NULL AND StartRevisionID IS NOT NULL)) AND ((EndScanID IS NULL AND EndRevisionID IS NULL) OR (EndScanID IS NOT NULL AND EndRevisionID IS NOT NULL)) AND ((AggregateReportID IS NULL AND AggregateRevisionID IS NULL) OR (AggregateReportID IS NOT NULL AND AggregateRevisionID IS NOT NULL))),
    CONSTRAINT CK_SourcePublication_Player CHECK (DATALENGTH(PlayerState) = LEN(PlayerState) AND ((PlayerState IN ('live','final','corrected_final','not_applicable') AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL) OR PlayerState IN ('missing_start','missing_end','missing_configuration','validation_failed','not_received'))),
    CONSTRAINT CK_SourcePublication_AggregateState CHECK (DATALENGTH(AggregateState) = LEN(AggregateState) AND ((AggregateState IN ('live','final','corrected_final') AND AggregateRevisionID IS NOT NULL) OR (AggregateState IN ('not_received','validation_failed','not_applicable') AND AggregateRevisionID IS NULL))),
    CONSTRAINT CK_SourcePublication_Final CHECK (DATALENGTH(PeriodState) = LEN(PeriodState) AND PeriodState IN ('live','final','corrected_final') AND (PeriodState = 'live' OR ((PlayerState IN ('final','corrected_final','not_applicable') AND AggregateState IN ('final','corrected_final','not_applicable')) OR (FinalUnavailableReason IS NOT NULL AND LEN(FinalUnavailableReason) > 0)))),
    CONSTRAINT CK_SourcePublication_Build CHECK (DATALENGTH(BuildState) = LEN(BuildState) AND ((BuildState = 'building' AND CompletedUTC IS NULL) OR (BuildState = 'complete' AND CompletedUTC IS NOT NULL AND ManifestHash IS NOT NULL AND ResultCount = EligibleCount)) AND (CompletedUTC IS NULL OR CompletedUTC >= CreatedUTC)),
    CONSTRAINT CK_SourcePublication_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourcePlayerResult
(
    PublicationID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ConfigVersionID uniqueidentifier NOT NULL,
    RosterID uniqueidentifier NOT NULL,
    GovernorID bigint NOT NULL,
    b0_kingdom int NOT NULL,
    CampID tinyint NOT NULL,
    name nvarchar(256) NULL,
    FieldStatusJson nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
    starting_power bigint NULL,
    starting_power_rank int NULL,
    starting_power_cohort int NULL,
    power bigint NULL,
    power_rank int NULL,
    power_cohort int NULL,
    troops_power bigint NULL,
    troops_power_rank int NULL,
    troops_power_cohort int NULL,
    t1_kills bigint NULL,
    t1_kills_rank int NULL,
    t1_kills_cohort int NULL,
    t2_kills bigint NULL,
    t2_kills_rank int NULL,
    t2_kills_cohort int NULL,
    t3_kills bigint NULL,
    t3_kills_rank int NULL,
    t3_kills_cohort int NULL,
    t4_kills bigint NULL,
    t4_kills_rank int NULL,
    t4_kills_cohort int NULL,
    t5_kills bigint NULL,
    t5_kills_rank int NULL,
    t5_kills_cohort int NULL,
    total_kill_points bigint NULL,
    total_kill_points_rank int NULL,
    total_kill_points_cohort int NULL,
    dead bigint NULL,
    dead_rank int NULL,
    dead_cohort int NULL,
    healed bigint NULL,
    healed_rank int NULL,
    healed_cohort int NULL,
    acclaim bigint NULL,
    acclaim_rank int NULL,
    acclaim_cohort int NULL,
    highest_acclaim bigint NULL,
    highest_acclaim_rank int NULL,
    highest_acclaim_cohort int NULL,
    kp_t4_t5 decimal(38,6) NULL,
    kp_t4_t5_rank int NULL,
    kp_t4_t5_cohort int NULL,
    dkp decimal(38,6) NULL,
    dkp_rank int NULL,
    dkp_cohort int NULL,
    healed_points decimal(38,6) NULL,
    healed_points_rank int NULL,
    healed_points_cohort int NULL,
    dkp_power_ratio decimal(38,12) NULL,
    dkp_power_ratio_rank int NULL,
    dkp_power_ratio_cohort int NULL,
    CONSTRAINT PK_SourcePlayerResult PRIMARY KEY (PublicationID, GovernorID),
    CONSTRAINT FK_SourcePlayerResult_Publication FOREIGN KEY (SourceKey, KVK_NO, PublicationID, ConfigVersionID, RosterID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PublicationID, ConfigVersionID, RosterID),
    CONSTRAINT FK_SourcePlayerResult_Eligible FOREIGN KEY (RosterID, GovernorID) REFERENCES KVK.SourceRosterMember (RosterID, GovernorID),
    CONSTRAINT FK_SourcePlayerResult_Camp FOREIGN KEY (ConfigVersionID, b0_kingdom, CampID) REFERENCES KVK.SourceCampConfig (ConfigVersionID, Kingdom, CampID),
    CONSTRAINT CK_SourcePlayerResult_StatusJson CHECK (ISJSON(FieldStatusJson) = 1),
    CONSTRAINT CK_SourcePlayerResult_Identity CHECK (GovernorID > 0 AND b0_kingdom > 0 AND CampID BETWEEN 1 AND 8),
    CONSTRAINT CK_SourcePlayerResult_starting_power CHECK (JSON_VALUE(FieldStatusJson, '$.starting_power') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.starting_power')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.starting_power')) AND ((JSON_VALUE(FieldStatusJson, '$.starting_power') = N'available' AND starting_power IS NOT NULL AND starting_power >= 0) OR (JSON_VALUE(FieldStatusJson, '$.starting_power') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND starting_power IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_starting_power_Rank CHECK ((starting_power_rank IS NULL AND starting_power_cohort IS NULL) OR (starting_power IS NOT NULL AND starting_power_rank IS NOT NULL AND starting_power_cohort IS NOT NULL AND starting_power_rank >= 1 AND starting_power_rank <= starting_power_cohort AND starting_power_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_power CHECK (JSON_VALUE(FieldStatusJson, '$.power') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.power')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.power')) AND ((JSON_VALUE(FieldStatusJson, '$.power') = N'available' AND power IS NOT NULL) OR (JSON_VALUE(FieldStatusJson, '$.power') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND power IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_power_Rank CHECK ((power_rank IS NULL AND power_cohort IS NULL) OR (power IS NOT NULL AND power_rank IS NOT NULL AND power_cohort IS NOT NULL AND power_rank >= 1 AND power_rank <= power_cohort AND power_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_troops_power CHECK (JSON_VALUE(FieldStatusJson, '$.troops_power') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.troops_power')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.troops_power')) AND ((JSON_VALUE(FieldStatusJson, '$.troops_power') = N'available' AND troops_power IS NOT NULL) OR (JSON_VALUE(FieldStatusJson, '$.troops_power') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND troops_power IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_troops_power_Rank CHECK ((troops_power_rank IS NULL AND troops_power_cohort IS NULL) OR (troops_power IS NOT NULL AND troops_power_rank IS NOT NULL AND troops_power_cohort IS NOT NULL AND troops_power_rank >= 1 AND troops_power_rank <= troops_power_cohort AND troops_power_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_t1_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t1_kills') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.t1_kills')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.t1_kills')) AND ((JSON_VALUE(FieldStatusJson, '$.t1_kills') = N'available' AND t1_kills IS NOT NULL AND t1_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t1_kills') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND t1_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_t1_kills_Rank CHECK ((t1_kills_rank IS NULL AND t1_kills_cohort IS NULL) OR (t1_kills IS NOT NULL AND t1_kills_rank IS NOT NULL AND t1_kills_cohort IS NOT NULL AND t1_kills_rank >= 1 AND t1_kills_rank <= t1_kills_cohort AND t1_kills_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_t2_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t2_kills') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.t2_kills')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.t2_kills')) AND ((JSON_VALUE(FieldStatusJson, '$.t2_kills') = N'available' AND t2_kills IS NOT NULL AND t2_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t2_kills') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND t2_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_t2_kills_Rank CHECK ((t2_kills_rank IS NULL AND t2_kills_cohort IS NULL) OR (t2_kills IS NOT NULL AND t2_kills_rank IS NOT NULL AND t2_kills_cohort IS NOT NULL AND t2_kills_rank >= 1 AND t2_kills_rank <= t2_kills_cohort AND t2_kills_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_t3_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t3_kills') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.t3_kills')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.t3_kills')) AND ((JSON_VALUE(FieldStatusJson, '$.t3_kills') = N'available' AND t3_kills IS NOT NULL AND t3_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t3_kills') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND t3_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_t3_kills_Rank CHECK ((t3_kills_rank IS NULL AND t3_kills_cohort IS NULL) OR (t3_kills IS NOT NULL AND t3_kills_rank IS NOT NULL AND t3_kills_cohort IS NOT NULL AND t3_kills_rank >= 1 AND t3_kills_rank <= t3_kills_cohort AND t3_kills_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_t4_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t4_kills') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.t4_kills')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.t4_kills')) AND ((JSON_VALUE(FieldStatusJson, '$.t4_kills') = N'available' AND t4_kills IS NOT NULL AND t4_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t4_kills') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND t4_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_t4_kills_Rank CHECK ((t4_kills_rank IS NULL AND t4_kills_cohort IS NULL) OR (t4_kills IS NOT NULL AND t4_kills_rank IS NOT NULL AND t4_kills_cohort IS NOT NULL AND t4_kills_rank >= 1 AND t4_kills_rank <= t4_kills_cohort AND t4_kills_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_t5_kills CHECK (JSON_VALUE(FieldStatusJson, '$.t5_kills') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.t5_kills')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.t5_kills')) AND ((JSON_VALUE(FieldStatusJson, '$.t5_kills') = N'available' AND t5_kills IS NOT NULL AND t5_kills >= 0) OR (JSON_VALUE(FieldStatusJson, '$.t5_kills') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND t5_kills IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_t5_kills_Rank CHECK ((t5_kills_rank IS NULL AND t5_kills_cohort IS NULL) OR (t5_kills IS NOT NULL AND t5_kills_rank IS NOT NULL AND t5_kills_cohort IS NOT NULL AND t5_kills_rank >= 1 AND t5_kills_rank <= t5_kills_cohort AND t5_kills_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_total_kill_points CHECK (JSON_VALUE(FieldStatusJson, '$.total_kill_points') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.total_kill_points')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.total_kill_points')) AND ((JSON_VALUE(FieldStatusJson, '$.total_kill_points') = N'available' AND total_kill_points IS NOT NULL AND total_kill_points >= 0) OR (JSON_VALUE(FieldStatusJson, '$.total_kill_points') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND total_kill_points IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_total_kill_points_Rank CHECK ((total_kill_points_rank IS NULL AND total_kill_points_cohort IS NULL) OR (total_kill_points IS NOT NULL AND total_kill_points_rank IS NOT NULL AND total_kill_points_cohort IS NOT NULL AND total_kill_points_rank >= 1 AND total_kill_points_rank <= total_kill_points_cohort AND total_kill_points_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_dead CHECK (JSON_VALUE(FieldStatusJson, '$.dead') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.dead')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.dead')) AND ((JSON_VALUE(FieldStatusJson, '$.dead') = N'available' AND dead IS NOT NULL AND dead >= 0) OR (JSON_VALUE(FieldStatusJson, '$.dead') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND dead IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_dead_Rank CHECK ((dead_rank IS NULL AND dead_cohort IS NULL) OR (dead IS NOT NULL AND dead_rank IS NOT NULL AND dead_cohort IS NOT NULL AND dead_rank >= 1 AND dead_rank <= dead_cohort AND dead_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_healed CHECK (JSON_VALUE(FieldStatusJson, '$.healed') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.healed')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.healed')) AND ((JSON_VALUE(FieldStatusJson, '$.healed') = N'available' AND healed IS NOT NULL AND healed >= 0) OR (JSON_VALUE(FieldStatusJson, '$.healed') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND healed IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_healed_Rank CHECK ((healed_rank IS NULL AND healed_cohort IS NULL) OR (healed IS NOT NULL AND healed_rank IS NOT NULL AND healed_cohort IS NOT NULL AND healed_rank >= 1 AND healed_rank <= healed_cohort AND healed_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_acclaim CHECK (JSON_VALUE(FieldStatusJson, '$.acclaim') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.acclaim')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.acclaim')) AND ((JSON_VALUE(FieldStatusJson, '$.acclaim') = N'available' AND acclaim IS NOT NULL AND acclaim >= 0) OR (JSON_VALUE(FieldStatusJson, '$.acclaim') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND acclaim IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_acclaim_Rank CHECK ((acclaim_rank IS NULL AND acclaim_cohort IS NULL) OR (acclaim IS NOT NULL AND acclaim_rank IS NOT NULL AND acclaim_cohort IS NOT NULL AND acclaim_rank >= 1 AND acclaim_rank <= acclaim_cohort AND acclaim_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_highest_acclaim CHECK (JSON_VALUE(FieldStatusJson, '$.highest_acclaim') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.highest_acclaim')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.highest_acclaim')) AND ((JSON_VALUE(FieldStatusJson, '$.highest_acclaim') = N'available' AND highest_acclaim IS NOT NULL AND highest_acclaim >= 0) OR (JSON_VALUE(FieldStatusJson, '$.highest_acclaim') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND highest_acclaim IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_highest_acclaim_Rank CHECK ((highest_acclaim_rank IS NULL AND highest_acclaim_cohort IS NULL) OR (highest_acclaim IS NOT NULL AND highest_acclaim_rank IS NOT NULL AND highest_acclaim_cohort IS NOT NULL AND highest_acclaim_rank >= 1 AND highest_acclaim_rank <= highest_acclaim_cohort AND highest_acclaim_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_kp_t4_t5 CHECK (JSON_VALUE(FieldStatusJson, '$.kp_t4_t5') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.kp_t4_t5')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.kp_t4_t5')) AND ((JSON_VALUE(FieldStatusJson, '$.kp_t4_t5') = N'available' AND kp_t4_t5 IS NOT NULL AND kp_t4_t5 >= 0) OR (JSON_VALUE(FieldStatusJson, '$.kp_t4_t5') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND kp_t4_t5 IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_kp_t4_t5_Rank CHECK ((kp_t4_t5_rank IS NULL AND kp_t4_t5_cohort IS NULL) OR (kp_t4_t5 IS NOT NULL AND kp_t4_t5_rank IS NOT NULL AND kp_t4_t5_cohort IS NOT NULL AND kp_t4_t5_rank >= 1 AND kp_t4_t5_rank <= kp_t4_t5_cohort AND kp_t4_t5_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_dkp CHECK (JSON_VALUE(FieldStatusJson, '$.dkp') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.dkp')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.dkp')) AND ((JSON_VALUE(FieldStatusJson, '$.dkp') = N'available' AND dkp IS NOT NULL) OR (JSON_VALUE(FieldStatusJson, '$.dkp') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND dkp IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_dkp_Rank CHECK ((dkp_rank IS NULL AND dkp_cohort IS NULL) OR (dkp IS NOT NULL AND dkp_rank IS NOT NULL AND dkp_cohort IS NOT NULL AND dkp_rank >= 1 AND dkp_rank <= dkp_cohort AND dkp_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_healed_points CHECK (JSON_VALUE(FieldStatusJson, '$.healed_points') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.healed_points')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.healed_points')) AND ((JSON_VALUE(FieldStatusJson, '$.healed_points') = N'available' AND healed_points IS NOT NULL AND healed_points >= 0) OR (JSON_VALUE(FieldStatusJson, '$.healed_points') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND healed_points IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_healed_points_Rank CHECK ((healed_points_rank IS NULL AND healed_points_cohort IS NULL) OR (healed_points IS NOT NULL AND healed_points_rank IS NOT NULL AND healed_points_cohort IS NOT NULL AND healed_points_rank >= 1 AND healed_points_rank <= healed_points_cohort AND healed_points_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_dkp_power_ratio CHECK (JSON_VALUE(FieldStatusJson, '$.dkp_power_ratio') IS NOT NULL AND DATALENGTH(JSON_VALUE(FieldStatusJson, '$.dkp_power_ratio')) = 2 * LEN(JSON_VALUE(FieldStatusJson, '$.dkp_power_ratio')) AND ((JSON_VALUE(FieldStatusJson, '$.dkp_power_ratio') = N'available' AND dkp_power_ratio IS NOT NULL) OR (JSON_VALUE(FieldStatusJson, '$.dkp_power_ratio') IN (N'missing_start',N'missing_end',N'invalid_source_value',N'counter_regression',N'unsupported',N'missing_configuration',N'not_applicable') AND dkp_power_ratio IS NULL))),
    CONSTRAINT CK_SourcePlayerResult_dkp_power_ratio_Rank CHECK ((dkp_power_ratio_rank IS NULL AND dkp_power_ratio_cohort IS NULL) OR (dkp_power_ratio IS NOT NULL AND dkp_power_ratio_rank IS NOT NULL AND dkp_power_ratio_cohort IS NOT NULL AND dkp_power_ratio_rank >= 1 AND dkp_power_ratio_rank <= dkp_power_ratio_cohort AND dkp_power_ratio_cohort <= 50000)),
    CONSTRAINT CK_SourcePlayerResult_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceSelection
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    PublicationID uniqueidentifier NOT NULL,
    SelectionVersion bigint NOT NULL,
    SelectedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceSelection PRIMARY KEY (SourceKey, KVK_NO, PeriodID),
    CONSTRAINT FK_SourceSelection_Publication FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT CK_SourceSelection_Version CHECK (SelectionVersion > 0),
    CONSTRAINT CK_SourceSelection_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceRouting
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    DisplayPeriodID uniqueidentifier NULL,
    Enabled bit NOT NULL CONSTRAINT DF_SourceRouting_Enabled DEFAULT (0),
    RoutingVersion bigint NOT NULL,
    CapabilitiesVersion varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
    ApprovedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    ApprovedUTC datetime2(0) NULL,
    CONSTRAINT PK_SourceRouting PRIMARY KEY (KVK_NO),
    CONSTRAINT FK_SourceRouting_Period FOREIGN KEY (SourceKey, KVK_NO, DisplayPeriodID) REFERENCES KVK.SourceSelection (SourceKey, KVK_NO, PeriodID),
    CONSTRAINT CK_SourceRouting_Version CHECK (RoutingVersion > 0),
    CONSTRAINT CK_SourceRouting_Approval CHECK (Enabled = 0 OR (DisplayPeriodID IS NOT NULL AND CapabilitiesVersion IS NOT NULL AND LEN(CapabilitiesVersion) > 0 AND ApprovedBy IS NOT NULL AND LEN(ApprovedBy) > 0 AND ApprovedUTC IS NOT NULL)),
    CONSTRAINT CK_SourceRouting_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceAction
(
    ActionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    ActionType varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ExpectedSelectionVersion bigint NOT NULL,
    NewSelectionVersion bigint NOT NULL,
    OldPublicationID uniqueidentifier NULL,
    NewPublicationID uniqueidentifier NOT NULL,
    RequestID uniqueidentifier NULL,
    Reason nvarchar(1024) NOT NULL,
    ActionUTC datetime2(0) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceAction PRIMARY KEY (ActionID),
    CONSTRAINT UQ_SourceAction_Version UNIQUE (SourceKey, KVK_NO, PeriodID, NewSelectionVersion),
    CONSTRAINT FK_SourceAction_Old FOREIGN KEY (SourceKey, KVK_NO, PeriodID, OldPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT FK_SourceAction_New FOREIGN KEY (SourceKey, KVK_NO, PeriodID, NewPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT FK_SourceAction_Request FOREIGN KEY (SourceKey, KVK_NO, PeriodID, RequestID) REFERENCES KVK.SourceConfigRequest (SourceKey, KVK_NO, PeriodID, RequestID),
    CONSTRAINT CK_SourceAction_Version CHECK (ExpectedSelectionVersion >= 0 AND NewSelectionVersion > ExpectedSelectionVersion AND ((ExpectedSelectionVersion = 0 AND OldPublicationID IS NULL) OR (ExpectedSelectionVersion > 0 AND OldPublicationID IS NOT NULL))),
    CONSTRAINT CK_SourceAction_Type CHECK (ActionType IN ('publish','finalize','correct','endpoint_update','rollback','configure') AND DATALENGTH(ActionType) = LEN(ActionType) AND (ActionType <> 'endpoint_update' OR RequestID IS NOT NULL)),
    CONSTRAINT CK_SourceAction_Provenance CHECK (LEN(Actor) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536),
    CONSTRAINT CK_SourceAction_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE TABLE KVK.SourceDelivery
(
    PublicationID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    DestinationKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    DestinationID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    DeliveryState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AttemptCount int NOT NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Receipt nvarchar(1024) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    ClaimedUTC datetime2(0) NULL,
    ConfirmedUTC datetime2(0) NULL,
    CONSTRAINT PK_SourceDelivery PRIMARY KEY (PublicationID, DestinationKind, DestinationID),
    CONSTRAINT FK_SourceDelivery_Publication FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT CK_SourceDelivery_Destination CHECK (DestinationKind IN ('discord','sheets','file') AND DATALENGTH(DestinationKind) = LEN(DestinationKind) AND LEN(DestinationID) > 0 AND DATALENGTH(DestinationID) = DATALENGTH(LTRIM(RTRIM(DestinationID)))),
    CONSTRAINT CK_SourceDelivery_State CHECK (DATALENGTH(DeliveryState) = LEN(DeliveryState) AND ((DeliveryState = 'pending' AND AttemptCount = 0 AND Fence = 0 AND OwnerID IS NULL AND ClaimedUTC IS NULL AND ConfirmedUTC IS NULL AND Receipt IS NULL) OR (DeliveryState IN ('claimed','failed','uncertain') AND AttemptCount > 0 AND Fence > 0 AND OwnerID IS NOT NULL AND ClaimedUTC IS NOT NULL AND ConfirmedUTC IS NULL) OR (DeliveryState = 'confirmed' AND AttemptCount > 0 AND Fence > 0 AND OwnerID IS NOT NULL AND ClaimedUTC IS NOT NULL AND ConfirmedUTC IS NOT NULL AND Receipt IS NOT NULL AND LEN(Receipt) > 0))),
    CONSTRAINT CK_SourceDelivery_Time CHECK (UpdatedUTC >= CreatedUTC AND (ClaimedUTC IS NULL OR (ClaimedUTC >= CreatedUTC AND ClaimedUTC <= UpdatedUTC)) AND (ConfirmedUTC IS NULL OR (ConfirmedUTC >= ClaimedUTC AND ConfirmedUTC <= UpdatedUTC))),
    CONSTRAINT CK_SourceDelivery_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);

CREATE INDEX IX_SourceCampConfig_Camp ON KVK.SourceCampConfig (ConfigVersionID, CampID);
CREATE INDEX IX_SourceConfigRequest_State ON KVK.SourceConfigRequest (RequestState, RequestedUTC);
CREATE INDEX IX_SourcePlayerResult_Kingdom ON KVK.SourcePlayerResult (PublicationID, b0_kingdom);
CREATE INDEX IX_SourcePlayerResult_Camp ON KVK.SourcePlayerResult (PublicationID, CampID);
CREATE INDEX IX_SourceDelivery_State ON KVK.SourceDelivery (DeliveryState, UpdatedUTC);
ALTER TABLE KVK.SourceConfigRequest WITH CHECK ADD CONSTRAINT FK_SourceConfigRequest_Applied FOREIGN KEY (SourceKey, KVK_NO, PeriodID, DesiredConfigVersionID, AppliedPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID);
ALTER TABLE KVK.SourceAggregateReport WITH CHECK ADD CONSTRAINT FK_SourceAggregateReport_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodKey, PeriodKind) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodKey, PeriodKind);

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE schema_id = SCHEMA_ID(N'KVK') AND (is_disabled = 1 OR is_not_trusted = 1))
     OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE schema_id = SCHEMA_ID(N'KVK') AND (is_disabled = 1 OR is_not_trusted = 1))
        THROW 51200, 'S2B constraint postvalidation failed.', 1;
    IF @S2BOwnTransaction = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @S2BOwnTransaction = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
