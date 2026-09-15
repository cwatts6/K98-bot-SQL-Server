/*
MigrationId: 20260915_001_kvk_output_pool_rollover
Purpose: Add typed physical output identity, scoped pool slots and retained rollover evidence
Author: cwatts
CreatedUtc: 2026-09-15
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Verify exact accepted S10A/S10C prerequisites and absent or exact S10D; preview attempt/part row counts and index locking
PostValidationQuery: Compare all expected columns, checks, indexes and non-cascading trusted FKs; confirm prior receipt bytes and claims unchanged
RelatedBotPR:
RelatedSQLPR:
*/
-- AUTHORING ONLY. Additive installation is not activation or proof of S10C installation.
-- Requires separately authorized exact target, backup/actual restore and index-lock plan.
-- No backfill, receipt mapping, budget seed, claim release or existing application DML.
-- S10E owns owner/fence/version CAS, monotonic transitions, append-only workflow APIs,
-- capacity and registration validation, and provider ACL/clear/readback/termination proof.
-- P/Q/R capacity and the 9,000,000-cell ceiling are preflight policy, not remote SQL truth.
-- All legacy/daily/new-source writers keep S10C job/preparation admission and UTC pacing.
-- Preserve every uncertain publication, historical receipt, retained database and file.
-- Forward fix only after history exists. Never rerun or rename predecessor migrations.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @S10DOwnTransaction bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
IF @S10DOwnTransaction=1 BEGIN TRANSACTION;
BEGIN TRY
DECLARE @S10DLockResult int;
EXEC @S10DLockResult=sys.sp_getapplock @Resource=N'K98:S10D:schema', @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=0;
IF @S10DLockResult<0 THROW 51500, 'S10D schema installation is already running.', 1;
IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID(N'KVK') AND name IN ('SourceOutputFile','SourceOutputPool','SourceOutputSlot','SourceOutputDisposition') AND type<>'U')
    THROW 51500, 'S10D object type conflict; preserve and forward-fix.', 1;
DECLARE @S10DExisting int=(SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'KVK') AND name IN ('SourceOutputFile','SourceOutputPool','SourceOutputSlot','SourceOutputDisposition'));
IF @S10DExisting NOT IN (0,4) THROW 51500, 'Partial S10D schema; preserve and forward-fix.', 1;
CREATE TABLE #S10D_KVK_SeasonSource
(
    KVK_NO int NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    ChosenBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChosenUTC datetime2(0) NOT NULL,
    Reason nvarchar(1024) COLLATE DATABASE_DEFAULT NOT NULL,
    ProvenanceJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    SeasonState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SeasonVersion bigint NOT NULL,
    PRIMARY KEY (KVK_NO),
    UNIQUE (KVK_NO, SourceKey, ChoiceID),
    CHECK (KVK_NO > 0 AND ((SourceKey = 'legacy_full_data' AND DATALENGTH(SourceKey) = 16) OR (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18))),
    CHECK (DATALENGTH(SeasonState) = LEN(SeasonState) AND SeasonState IN ('planned','open','closing','closed') AND SeasonVersion > 0),
    CHECK (LEN(ChosenBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);


CREATE TABLE #S10D_KVK_SourceRouting
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    DisplayPeriodID uniqueidentifier NULL,
    Enabled bit NOT NULL DEFAULT (0),
    RoutingVersion bigint NOT NULL,
    CapabilitiesVersion varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
    ApprovedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    ApprovedUTC datetime2(0) NULL,
    PRIMARY KEY (KVK_NO),
    CHECK (RoutingVersion > 0),
    CHECK (Enabled = 0 OR (DisplayPeriodID IS NOT NULL AND CapabilitiesVersion IS NOT NULL AND LEN(CapabilitiesVersion) > 0 AND ApprovedBy IS NOT NULL AND LEN(ApprovedBy) > 0 AND ApprovedUTC IS NOT NULL)),
    CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);


CREATE TABLE #S10D_KVK_SourceDelivery
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
    Receipt nvarchar(1024) COLLATE DATABASE_DEFAULT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    ClaimedUTC datetime2(0) NULL,
    ConfirmedUTC datetime2(0) NULL,
    PRIMARY KEY (PublicationID, DestinationKind, DestinationID),
    CHECK (DestinationKind IN ('discord','sheets','file') AND DATALENGTH(DestinationKind) = LEN(DestinationKind) AND LEN(DestinationID) > 0 AND DATALENGTH(DestinationID) = DATALENGTH(LTRIM(RTRIM(DestinationID)))),
    CHECK (DATALENGTH(DeliveryState) = LEN(DeliveryState) AND ((DeliveryState = 'pending' AND AttemptCount = 0 AND Fence = 0 AND OwnerID IS NULL AND ClaimedUTC IS NULL AND ConfirmedUTC IS NULL AND Receipt IS NULL) OR (DeliveryState IN ('claimed','failed','uncertain') AND AttemptCount > 0 AND Fence > 0 AND OwnerID IS NOT NULL AND ClaimedUTC IS NOT NULL AND ConfirmedUTC IS NULL) OR (DeliveryState = 'confirmed' AND AttemptCount > 0 AND Fence > 0 AND OwnerID IS NOT NULL AND ClaimedUTC IS NOT NULL AND ConfirmedUTC IS NOT NULL AND Receipt IS NOT NULL AND LEN(Receipt) > 0))),
    CHECK (UpdatedUTC >= CreatedUTC AND (ClaimedUTC IS NULL OR (ClaimedUTC >= CreatedUTC AND ClaimedUTC <= UpdatedUTC)) AND (ConfirmedUTC IS NULL OR (ConfirmedUTC >= ClaimedUTC AND ConfirmedUTC <= UpdatedUTC))),
    CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
CREATE INDEX IX_SourceDelivery_State ON #S10D_KVK_SourceDelivery (DeliveryState, UpdatedUTC);

CREATE TABLE #S10D_KVK_SourcePublication
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
    FinalUnavailableReason nvarchar(1024) COLLATE DATABASE_DEFAULT NULL,
    PRIMARY KEY (PublicationID),
    UNIQUE (SourceKey, KVK_NO, PeriodID, Generation),
    UNIQUE (SourceKey, KVK_NO, PeriodID, PublicationID),
    UNIQUE (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID),
    UNIQUE (SourceKey, KVK_NO, PublicationID, ConfigVersionID, RosterID),
    CHECK (Generation > 0 AND EligibleCount BETWEEN 1 AND 50000 AND ResultCount BETWEEN 0 AND EligibleCount AND KingdomCount BETWEEN 0 AND 512 AND CampCount BETWEEN 0 AND 8 AND LEN(CalculationVersion) > 0),
    CHECK (((StartScanID IS NULL AND StartRevisionID IS NULL) OR (StartScanID IS NOT NULL AND StartRevisionID IS NOT NULL)) AND ((EndScanID IS NULL AND EndRevisionID IS NULL) OR (EndScanID IS NOT NULL AND EndRevisionID IS NOT NULL)) AND ((AggregateReportID IS NULL AND AggregateRevisionID IS NULL) OR (AggregateReportID IS NOT NULL AND AggregateRevisionID IS NOT NULL))),
    CHECK (DATALENGTH(PlayerState) = LEN(PlayerState) AND ((PlayerState IN ('live','final','corrected_final','not_applicable') AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL) OR PlayerState IN ('missing_start','missing_end','missing_configuration','validation_failed','not_received','final_unavailable'))),
    CHECK (DATALENGTH(AggregateState) = LEN(AggregateState) AND ((AggregateState IN ('live','final','corrected_final') AND AggregateRevisionID IS NOT NULL) OR (AggregateState IN ('not_received','validation_failed','not_applicable','final_unavailable') AND AggregateRevisionID IS NULL))),
    -- An unavailable reason cannot finalize a live or merely missing component.
    -- Authorization of the explicit terminal designation is enforced by the later S3B writer.
    CHECK (
        DATALENGTH(PeriodState) = LEN(PeriodState) AND PeriodState IN ('live','final','corrected_final')
        AND ((PlayerState <> 'final_unavailable' AND AggregateState <> 'final_unavailable')
             OR (FinalUnavailableReason IS NOT NULL AND LEN(FinalUnavailableReason) > 0))
        AND (PeriodState = 'live'
             OR (PlayerState IN ('final','corrected_final','not_applicable','final_unavailable')
                 AND AggregateState IN ('final','corrected_final','not_applicable','final_unavailable')))),
    CHECK (DATALENGTH(BuildState) = LEN(BuildState) AND ((BuildState = 'building' AND CompletedUTC IS NULL) OR (BuildState = 'complete' AND CompletedUTC IS NOT NULL AND ManifestHash IS NOT NULL AND ResultCount = EligibleCount)) AND (CompletedUTC IS NULL OR CompletedUTC >= CreatedUTC)),
    CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);


CREATE TABLE #S10D_dbo_ExportJob
(
    JobID uniqueidentifier NOT NULL,
    ConsumerKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    IntentID uniqueidentifier NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    DestinationSetHash binary(32) NOT NULL,
    InputHash binary(32) NOT NULL,
    SpoolKey varchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    SpoolBytes bigint NULL,
    StorageOwner varchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    KVK_NO int NULL,
    PoolEpoch bigint NULL,
    RepairID uniqueidentifier NULL,
    EnqueueSequence bigint NOT NULL,
    State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Version bigint NOT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    SupersededByJobID uniqueidentifier NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) COLLATE DATABASE_DEFAULT NOT NULL,
    ProvenanceJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    PRIMARY KEY (JobID),
    UNIQUE (ConsumerKind, AccountKey, KVK_NO, InputHash, DestinationSetHash, PoolEpoch, RepairID),
    UNIQUE (JobID, ConsumerKind),
    UNIQUE (JobID, PoolEpoch),
    UNIQUE (JobID, KVK_NO),
    UNIQUE (JobID, ConsumerKind, AccountKey, KVK_NO, DestinationSetHash, PoolEpoch),
    CHECK (DATALENGTH(ConsumerKind) = LEN(ConsumerKind) AND ConsumerKind IN ('new_source','all_kvk','scan_data')),
    CHECK ((ConsumerKind = 'new_source' AND SourceKey IS NOT NULL AND SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND IntentID IS NOT NULL AND KVK_NO IS NOT NULL AND KVK_NO > 0 AND PoolEpoch IS NOT NULL AND PoolEpoch > 0) OR (ConsumerKind = 'all_kvk' AND SourceKey IS NULL AND IntentID IS NULL AND KVK_NO IS NOT NULL AND KVK_NO > 0 AND PoolEpoch IS NULL) OR (ConsumerKind = 'scan_data' AND SourceKey IS NULL AND IntentID IS NULL AND KVK_NO IS NULL AND PoolEpoch IS NULL)),
    CHECK (LEN(AccountKey) > 0 AND DATALENGTH(AccountKey) = DATALENGTH(LTRIM(RTRIM(AccountKey))) AND LEN(Actor) > 0 AND DATALENGTH(Actor) = DATALENGTH(LTRIM(RTRIM(Actor))) AND LEN(Reason) > 0),
    CHECK (((SpoolKey IS NULL AND SpoolBytes IS NULL AND StorageOwner IS NULL AND ConsumerKind = 'new_source') OR (SpoolKey IS NOT NULL AND SpoolBytes IS NOT NULL AND StorageOwner IS NOT NULL AND SpoolBytes > 0 AND LEN(SpoolKey) > 0 AND DATALENGTH(SpoolKey) = DATALENGTH(LTRIM(RTRIM(SpoolKey))) AND LEN(StorageOwner) > 0 AND DATALENGTH(StorageOwner) = DATALENGTH(LTRIM(RTRIM(StorageOwner))) AND SpoolKey NOT LIKE '%[^a-zA-Z0-9_-]%' COLLATE Latin1_General_100_BIN2))),
    CHECK (DATALENGTH(State) = LEN(State) AND State IN ('waiting','ready','running','confirmed','failed','uncertain','coalesced','cancelled')),
    CHECK (Fence >= 0 AND ((OwnerID IS NULL AND Fence = 0 AND State IN ('waiting','ready','coalesced','cancelled')) OR (OwnerID IS NOT NULL AND Fence > 0 AND State IN ('running','confirmed','failed','uncertain')))),
    CHECK ((State = 'coalesced' AND ConsumerKind = 'new_source' AND SupersededByJobID IS NOT NULL AND SupersededByJobID <> JobID) OR (State <> 'coalesced' AND SupersededByJobID IS NULL)),
    CHECK (EnqueueSequence > 0 AND Version > 0),
    CHECK (UpdatedUTC >= CreatedUTC),
    CHECK (ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);
CREATE INDEX IX_ExportJob_Queue ON #S10D_dbo_ExportJob (AccountKey, State, EnqueueSequence, JobID);
CREATE INDEX IX_ExportJob_Intent ON #S10D_dbo_ExportJob (IntentID) WHERE IntentID IS NOT NULL;
CREATE INDEX IX_ExportJob_Superseded ON #S10D_dbo_ExportJob (SupersededByJobID) WHERE SupersededByJobID IS NOT NULL;

CREATE TABLE #S10D_dbo_ExportResource
(
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActiveJobID uniqueidentifier NULL,
    ActivePreparationID uniqueidentifier NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    BlockedReason nvarchar(1024) COLLATE DATABASE_DEFAULT NULL,
    Version bigint NOT NULL,
    PRIMARY KEY (ResourceKey),
    CHECK (LEN(ResourceKey) > 0 AND DATALENGTH(ResourceKey) = DATALENGTH(LTRIM(RTRIM(ResourceKey)))),
    CHECK (DATALENGTH(ResourceKind) = LEN(ResourceKind) AND ResourceKind IN ('account','destination','sql_snapshot')),
    CHECK ((ActiveJobID IS NULL AND ActivePreparationID IS NULL AND OwnerID IS NULL AND Fence >= 0) OR (ActiveJobID IS NOT NULL AND ActivePreparationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NOT NULL AND OwnerID IS NOT NULL AND Fence > 0)),
    CHECK (BlockedReason IS NULL OR LEN(BlockedReason) > 0),
    CHECK (Version > 0)
);
CREATE INDEX IX_ExportResource_ActiveJob ON #S10D_dbo_ExportResource (ActiveJobID) WHERE ActiveJobID IS NOT NULL;

CREATE TABLE #S10D_dbo_ExportJobResource
(
    JobID uniqueidentifier NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PRIMARY KEY (JobID, ResourceKey)
);
CREATE INDEX IX_ExportJobResource_Resource ON #S10D_dbo_ExportJobResource (ResourceKey, JobID);

CREATE TABLE #S10D_dbo_ExportRequestBudget
(
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BudgetKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    NextAllowedUTC datetime2(3) NOT NULL,
    CooldownUntilUTC datetime2(3) NULL,
    IntervalMilliseconds int NOT NULL,
    PolicyVersion bigint NOT NULL,
    Version bigint NOT NULL,
    PRIMARY KEY (AccountKey, BudgetKind),
    CHECK (LEN(AccountKey) > 0 AND DATALENGTH(AccountKey) = DATALENGTH(LTRIM(RTRIM(AccountKey)))),
    CHECK (BudgetKind = 'google_request' AND DATALENGTH(BudgetKind) = 14),
    CHECK (IntervalMilliseconds BETWEEN 1 AND 86400000 AND PolicyVersion > 0 AND Version > 0)
);


CREATE TABLE #S10D_dbo_ExportAttempt
(
    AttemptID uniqueidentifier NOT NULL,
    JobID uniqueidentifier NOT NULL,
    ConsumerKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AttemptNo bigint NOT NULL,
    OwnerID uniqueidentifier NOT NULL,
    Fence bigint NOT NULL,
    Epoch bigint NULL,
    Phase varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RemoteSequence bigint NOT NULL,
    Version bigint NOT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    VerifiedUTC datetime2(0) NULL,
    PublishedUTC datetime2(0) NULL,
    ManifestHash binary(32) NOT NULL,
    ManifestJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    ReceiptJson nvarchar(max) COLLATE DATABASE_DEFAULT NULL,
    PartCount int NOT NULL,
    LegacyPublicationID uniqueidentifier NULL,
    LegacySourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LegacyKVK_NO int NULL,
    LegacyPeriodID uniqueidentifier NULL,
    LegacyDestinationKind varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LegacyDestinationID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    PRIMARY KEY (AttemptID),
    UNIQUE (JobID, AttemptNo),
    UNIQUE (AttemptID, PartCount),
    CHECK (DATALENGTH(ConsumerKind) = LEN(ConsumerKind) AND ConsumerKind IN ('new_source','all_kvk','scan_data')),
    CHECK ((ConsumerKind = 'new_source' AND Epoch IS NOT NULL AND Epoch > 0) OR (ConsumerKind IN ('all_kvk','scan_data') AND Epoch IS NULL)),
    CHECK (DATALENGTH(Phase) = LEN(Phase) AND Phase IN ('private_started','verified','publication_pending','published','failed','uncertain','retired')),
    CHECK (AttemptNo > 0 AND Fence > 0 AND RemoteSequence > 0 AND Version > 0 AND PartCount BETWEEN 1 AND 1024),
    CHECK (ISJSON(ManifestJson) = 1 AND DATALENGTH(ManifestJson) <= 65536),
    CHECK (ReceiptJson IS NULL OR (ISJSON(ReceiptJson) = 1 AND DATALENGTH(ReceiptJson) <= 65536)),
    CHECK (UpdatedUTC >= CreatedUTC AND (VerifiedUTC IS NULL OR VerifiedUTC BETWEEN CreatedUTC AND UpdatedUTC) AND (PublishedUTC IS NULL OR (VerifiedUTC IS NOT NULL AND PublishedUTC BETWEEN VerifiedUTC AND UpdatedUTC))),
    CHECK ((Phase NOT IN ('verified','publication_pending','published','retired') OR VerifiedUTC IS NOT NULL) AND (Phase NOT IN ('published','retired') OR (PublishedUTC IS NOT NULL AND ReceiptJson IS NOT NULL)) AND (Phase <> 'private_started' OR (VerifiedUTC IS NULL AND PublishedUTC IS NULL))),
    CHECK ((LegacyPublicationID IS NULL AND LegacySourceKey IS NULL AND LegacyKVK_NO IS NULL AND LegacyPeriodID IS NULL AND LegacyDestinationKind IS NULL AND LegacyDestinationID IS NULL) OR (ConsumerKind = 'new_source' AND LegacyPublicationID IS NOT NULL AND LegacySourceKey IS NOT NULL AND LegacySourceKey = 'snapshot_report_v1' AND DATALENGTH(LegacySourceKey) = 18 AND LegacyKVK_NO IS NOT NULL AND LegacyKVK_NO > 0 AND LegacyPeriodID IS NOT NULL AND LegacyDestinationKind IS NOT NULL AND DATALENGTH(LegacyDestinationKind) = LEN(LegacyDestinationKind) AND LegacyDestinationKind IN ('discord','sheets','file') AND LegacyDestinationID IS NOT NULL AND LEN(LegacyDestinationID) > 0 AND DATALENGTH(LegacyDestinationID) = DATALENGTH(LTRIM(RTRIM(LegacyDestinationID)))))
);
CREATE INDEX IX_ExportAttempt_Phase ON #S10D_dbo_ExportAttempt (Phase, UpdatedUTC, JobID);

CREATE TABLE #S10D_dbo_ExportAttemptPart
(
    AttemptID uniqueidentifier NOT NULL,
    PartNo int NOT NULL,
    PartCount int NOT NULL,
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    [Role] varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ManifestHash binary(32) NOT NULL,
    GridCount int NOT NULL,
    [RowCount] bigint NOT NULL,
    CellCount bigint NOT NULL,
    VerificationState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    VerifiedUTC datetime2(0) NULL,
    AclState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AclCheckedUTC datetime2(0) NULL,
    QuarantineState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    QuarantinedUTC datetime2(0) NULL,
    QuarantineReason nvarchar(1024) COLLATE DATABASE_DEFAULT NULL,
    EvidenceJson nvarchar(max) COLLATE DATABASE_DEFAULT NULL,
    Version bigint NOT NULL,
    PRIMARY KEY (AttemptID, PartNo),
    UNIQUE (AttemptID, FileID),
    CHECK (PartCount BETWEEN 1 AND 1024 AND PartNo BETWEEN 1 AND PartCount),
    CHECK (LEN(FileID) > 0 AND DATALENGTH(FileID) = DATALENGTH(LTRIM(RTRIM(FileID)))),
    CHECK (DATALENGTH([Role]) = LEN([Role]) AND [Role] IN ('index','generation','output')),
    CHECK (GridCount > 0 AND [RowCount] >= 0 AND CellCount > 0 AND CellCount >= [RowCount] AND Version > 0),
    CHECK (DATALENGTH(VerificationState) = LEN(VerificationState) AND VerificationState IN ('pending','verified','failed','uncertain') AND ((VerificationState = 'verified' AND VerifiedUTC IS NOT NULL) OR (VerificationState <> 'verified' AND VerifiedUTC IS NULL))),
    CHECK (DATALENGTH(AclState) = LEN(AclState) AND AclState IN ('pending','private','public_viewer','failed','uncertain') AND ((AclState = 'pending' AND AclCheckedUTC IS NULL) OR (AclState <> 'pending' AND AclCheckedUTC IS NOT NULL))),
    CHECK (DATALENGTH(QuarantineState) = LEN(QuarantineState) AND QuarantineState IN ('none','quarantined') AND ((QuarantineState = 'none' AND QuarantinedUTC IS NULL AND QuarantineReason IS NULL) OR (QuarantineState = 'quarantined' AND QuarantinedUTC IS NOT NULL AND QuarantineReason IS NOT NULL AND LEN(QuarantineReason) > 0))),
    CHECK (EvidenceJson IS NULL OR (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536))
);


CREATE TABLE #S10D_dbo_ExportPreparation
(
 PreparationID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ConsumerKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 KVK_NO int NULL,
 RequestHash binary(32) NOT NULL,
 EnqueueSequence bigint NOT NULL,
 State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 OwnerID uniqueidentifier NULL,
 Fence bigint NOT NULL,
 Version bigint NOT NULL,
 StorageOwner varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 RequestJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
 GenerationJson nvarchar(max) COLLATE DATABASE_DEFAULT NULL,
 SpoolKey varchar(128) COLLATE Latin1_General_100_BIN2 NULL,
 SpoolBytes bigint NULL,
 SpoolHash binary(32) NULL,
 JobID uniqueidentifier NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(1024) COLLATE DATABASE_DEFAULT NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 UpdatedUTC datetime2(3) NOT NULL,
 PRIMARY KEY (PreparationID),
 UNIQUE (AccountKey,RequestHash),
 CHECK (ConsumerKind IN ('all_kvk','scan_data','config') AND DATALENGTH(ConsumerKind)=LEN(ConsumerKind)),
 CHECK ((ConsumerKind='all_kvk' AND KVK_NO IS NOT NULL AND KVK_NO>0) OR (ConsumerKind IN ('scan_data','config') AND KVK_NO IS NULL)),
 CHECK (State IN ('pending','preflight','sql_pending','writing','committed','captured','materialized','completed','unavailable','uncertain') AND DATALENGTH(State)=LEN(State)),
 CHECK ((OwnerID IS NULL AND Fence=0 AND State='pending') OR (OwnerID IS NOT NULL AND Fence>0 AND State<>'pending')),
 CHECK (Version>0 AND EnqueueSequence>0 AND UpdatedUTC>=CreatedUTC),
 CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=DATALENGTH(LTRIM(RTRIM(AccountKey))) AND LEN(StorageOwner)>0 AND DATALENGTH(StorageOwner)=DATALENGTH(LTRIM(RTRIM(StorageOwner))) AND LEN(Actor)>0 AND LEN(Reason)>0),
 CHECK (ISJSON(RequestJson)=1 AND DATALENGTH(RequestJson)<=65536),
 CHECK ((GenerationJson IS NULL AND State NOT IN ('committed','captured','materialized')) OR (GenerationJson IS NOT NULL AND ISJSON(GenerationJson)=1 AND DATALENGTH(GenerationJson)<=65536)),
 CHECK ((SpoolKey IS NULL AND SpoolBytes IS NULL AND SpoolHash IS NULL AND State NOT IN ('captured','materialized')) OR (SpoolKey IS NOT NULL AND SpoolBytes IS NOT NULL AND SpoolHash IS NOT NULL AND SpoolBytes>0 AND LEN(SpoolKey)>0 AND DATALENGTH(SpoolKey)=DATALENGTH(LTRIM(RTRIM(SpoolKey))) AND SpoolKey NOT LIKE '%[^a-zA-Z0-9_-]%' COLLATE Latin1_General_100_BIN2)),
 CHECK ((JobID IS NULL AND State<>'materialized') OR (JobID IS NOT NULL AND State='materialized' AND ConsumerKind<>'config'))
);
CREATE INDEX IX_ExportPreparation_Queue ON #S10D_dbo_ExportPreparation(AccountKey,State,EnqueueSequence,PreparationID);
CREATE UNIQUE INDEX UX_ExportPreparation_Job ON #S10D_dbo_ExportPreparation(JobID) WHERE JobID IS NOT NULL;

CREATE TABLE #S10D_dbo_ExportPreparationResource
(
 PreparationID uniqueidentifier NOT NULL,
 ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
 PRIMARY KEY (PreparationID,ResourceKey)
);
CREATE INDEX IX_ExportPreparationResource_Resource ON #S10D_dbo_ExportPreparationResource(ResourceKey);

CREATE TABLE #S10D_KVK_SourceOutputFile
(
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegisteredBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegisteredUTC datetime2(0) NOT NULL,
    EvidenceHash binary(32) NOT NULL,
    EvidenceJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    PRIMARY KEY (FileID),
    UNIQUE (FileID, FileKind),
    UNIQUE (FileID, ResourceKey),
    UNIQUE (ResourceKey),
    CHECK (DATALENGTH(FileID) BETWEEN 6 AND 256 AND FileID NOT LIKE N'%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2),
    CHECK (FileKind IN ('index','slot') AND DATALENGTH(FileKind) = LEN(FileKind)),
    CHECK (ResourceKey = 'destination:' + CONVERT(varchar(128), FileID) AND DATALENGTH(ResourceKey) = 12 + DATALENGTH(FileID) / 2),
    CHECK (LEN(RegisteredBy) > 0 AND DATALENGTH(RegisteredBy) = DATALENGTH(LTRIM(RTRIM(RegisteredBy)))),
    CHECK (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536)
);


CREATE TABLE #S10D_KVK_SourceOutputPool
(
    PoolID uniqueidentifier NOT NULL,
    IndexFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    IndexFileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegistrationNo int NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AccountResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ExpectedOwner nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AudienceJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActiveKVK int NULL,
    ChoiceID uniqueidentifier NULL,
    Epoch bigint NOT NULL,
    PoolState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Version bigint NOT NULL,
    BlockedReason nvarchar(1024) COLLATE DATABASE_DEFAULT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    RegistrationHash binary(32) NOT NULL,
    RegistrationJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    PRIMARY KEY (PoolID),
    UNIQUE (IndexFileID),
    UNIQUE (RegistrationNo),
    UNIQUE (PoolID, AccountKey),
    UNIQUE (PoolID, IndexFileID),
    CHECK (IndexFileKind = 'index' AND DATALENGTH(IndexFileKind) = 5),
    CHECK (RegistrationNo BETWEEN 1 AND 8),
    CHECK (LEN(AccountKey) > 0 AND AccountKey NOT LIKE '%[^A-Za-z0-9_.@:-]%' COLLATE Latin1_General_100_BIN2 AND AccountResourceKey = 'account:' + AccountKey AND DATALENGTH(AccountResourceKey) = 8 + DATALENGTH(AccountKey)),
    CHECK (LEN(ExpectedOwner) > 0 AND DATALENGTH(ExpectedOwner) = DATALENGTH(LTRIM(RTRIM(ExpectedOwner)))),
    CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND ((ActiveKVK IS NULL AND ChoiceID IS NULL AND PoolState IN ('setup','blocked')) OR (ActiveKVK IS NOT NULL AND ActiveKVK > 0 AND ChoiceID IS NOT NULL))),
    CHECK (PoolState IN ('active','closing','closed','setup','blocked') AND DATALENGTH(PoolState) = LEN(PoolState)),
    CHECK ((OwnerID IS NULL AND Fence >= 0 AND PoolState <> 'closing') OR (OwnerID IS NOT NULL AND Fence > 0 AND PoolState <> 'closed')),
    CHECK ((PoolState = 'blocked' AND BlockedReason IS NOT NULL AND LEN(BlockedReason) > 0) OR (PoolState <> 'blocked' AND BlockedReason IS NULL)),
    CHECK (Epoch > 0 AND Version > 0 AND UpdatedUTC >= CreatedUTC),
    CHECK (ISJSON(AudienceJson) = 1 AND DATALENGTH(AudienceJson) <= 65536),
    CHECK (ISJSON(RegistrationJson) = 1 AND DATALENGTH(RegistrationJson) <= 65536)
);
CREATE INDEX IX_SourceOutputPool_State ON #S10D_KVK_SourceOutputPool (AccountKey, PoolState, PoolID);

CREATE TABLE #S10D_KVK_SourceOutputSlot
(
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    SlotNo int NOT NULL,
    Epoch bigint NOT NULL,
    State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Version bigint NOT NULL,
    AssignmentID uniqueidentifier NULL,
    AssignmentAction varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    AttemptID uniqueidentifier NULL,
    PartNo int NULL,
    AssignmentVersion bigint NULL,
    LastDispositionID uniqueidentifier NULL,
    LastAction varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LastDispositionVersion bigint NULL,
    QuarantineReason nvarchar(1024) COLLATE DATABASE_DEFAULT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    PRIMARY KEY (FileID),
    UNIQUE (PoolID, FileID),
    UNIQUE (PoolID, SlotNo),
    CHECK (FileKind = 'slot' AND DATALENGTH(FileKind) = 4),
    CHECK (SlotNo BETWEEN 1 AND 16 AND Epoch > 0 AND Version > 0 AND UpdatedUTC >= CreatedUTC),
    CHECK (State IN ('free','staging','active','quarantined','retired') AND DATALENGTH(State) = LEN(State)),
    CHECK ((OwnerID IS NULL AND Fence >= 0 AND State <> 'staging') OR (OwnerID IS NOT NULL AND Fence > 0 AND State IN ('staging','active','quarantined'))),
    CHECK ((AssignmentID IS NULL AND AssignmentAction IS NULL AND AttemptID IS NULL AND PartNo IS NULL AND AssignmentVersion IS NULL AND State IN ('free','quarantined','retired')) OR (AssignmentID IS NOT NULL AND AssignmentAction IS NOT NULL AND AssignmentAction = 'assign' AND DATALENGTH(AssignmentAction) = 6 AND AttemptID IS NOT NULL AND PartNo IS NOT NULL AND PartNo BETWEEN 1 AND 1024 AND AssignmentVersion IS NOT NULL AND AssignmentVersion > 0 AND AssignmentVersion <= Version AND State <> 'free')),
    CHECK ((LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'quarantined' AND AssignmentID IS NULL) OR (LastDispositionID IS NOT NULL AND LastAction IS NOT NULL AND DATALENGTH(LastAction) = LEN(LastAction) AND LastDispositionVersion IS NOT NULL AND LastDispositionVersion > 0 AND LastDispositionVersion <= Version AND ((State = 'free' AND LastAction = 'clear') OR (State IN ('staging','active') AND LastAction = 'assign' AND LastDispositionID = AssignmentID) OR (State = 'quarantined' AND LastAction = 'quarantine') OR (State = 'retired' AND LastAction = 'retire')))),
    CHECK ((State = 'quarantined' AND QuarantineReason IS NOT NULL AND LEN(QuarantineReason) > 0) OR (State <> 'quarantined' AND QuarantineReason IS NULL))
);
CREATE INDEX IX_SourceOutputSlot_Availability ON #S10D_KVK_SourceOutputSlot (PoolID, Epoch, State, SlotNo);
CREATE INDEX IX_SourceOutputSlot_Attempt ON #S10D_KVK_SourceOutputSlot (AttemptID, PartNo) WHERE AttemptID IS NOT NULL;

CREATE TABLE #S10D_KVK_SourceOutputDisposition
(
    DispositionID uniqueidentifier NOT NULL,
    OperationID uniqueidentifier NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    SequenceNo bigint NOT NULL,
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SlotFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    IndexFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    NewKVK_NO int NOT NULL,
    NewChoiceID uniqueidentifier NOT NULL,
    OldEpoch bigint NOT NULL,
    NewEpoch bigint NOT NULL,
    Action varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OwnerID uniqueidentifier NOT NULL,
    Fence bigint NOT NULL,
    FromPoolVersion bigint NOT NULL,
    ToPoolVersion bigint NOT NULL,
    FromSlotVersion bigint NULL,
    ToSlotVersion bigint NULL,
    JobID uniqueidentifier NULL,
    ConsumerKind varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    DestinationSetHash binary(32) NULL,
    AttemptID uniqueidentifier NULL,
    PartNo int NULL,
    AttemptEpoch bigint NULL,
    LegacyPublicationID uniqueidentifier NULL,
    LegacyPeriodID uniqueidentifier NULL,
    LegacyDestinationKind varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LegacyDestinationID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) COLLATE DATABASE_DEFAULT NOT NULL,
    OccurredUTC datetime2(0) NOT NULL,
    EvidenceHash binary(32) NOT NULL,
    EvidenceJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    PRIMARY KEY (DispositionID),
    UNIQUE (PoolID, SequenceNo),
    UNIQUE (PoolID, OperationID, FileID, Action),
    UNIQUE (DispositionID, PoolID, FileID, NewEpoch, AttemptID, PartNo, ToSlotVersion, Action),
    UNIQUE (DispositionID, PoolID, FileID, NewEpoch, Action, ToSlotVersion),
    CHECK ((FileKind = 'slot' AND DATALENGTH(FileKind) = 4 AND SlotFileID IS NOT NULL AND SlotFileID = FileID AND DATALENGTH(SlotFileID) = DATALENGTH(FileID) AND IndexFileID IS NULL AND FromSlotVersion IS NOT NULL AND ToSlotVersion IS NOT NULL AND FromSlotVersion > 0 AND ToSlotVersion > FromSlotVersion AND ToSlotVersion - FromSlotVersion = 1) OR (FileKind = 'index' AND DATALENGTH(FileKind) = 5 AND IndexFileID IS NOT NULL AND IndexFileID = FileID AND DATALENGTH(IndexFileID) = DATALENGTH(FileID) AND SlotFileID IS NULL AND FromSlotVersion IS NULL AND ToSlotVersion IS NULL)),
    CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0 AND NewKVK_NO > 0),
    CHECK (Action IN ('retire','quarantine','clear','assign') AND DATALENGTH(Action) = LEN(Action)),
    CHECK (OldEpoch > 0 AND NewEpoch >= OldEpoch AND NewEpoch - OldEpoch BETWEEN 0 AND 1 AND ((NewEpoch = OldEpoch AND NewKVK_NO = KVK_NO AND NewChoiceID = ChoiceID) OR (NewEpoch > OldEpoch AND Action = 'clear'))),
    CHECK (Fence > 0 AND SequenceNo > 0 AND FromPoolVersion > 0 AND ToPoolVersion > FromPoolVersion AND ToPoolVersion - FromPoolVersion = 1),
    CHECK ((JobID IS NULL AND ConsumerKind IS NULL AND DestinationSetHash IS NULL AND AttemptID IS NULL AND PartNo IS NULL AND AttemptEpoch IS NULL AND Action <> 'assign') OR (JobID IS NOT NULL AND ConsumerKind IS NOT NULL AND ConsumerKind = 'new_source' AND DATALENGTH(ConsumerKind) = 10 AND DestinationSetHash IS NOT NULL AND AttemptID IS NOT NULL AND PartNo IS NOT NULL AND PartNo BETWEEN 1 AND 1024 AND AttemptEpoch IS NOT NULL AND AttemptEpoch = OldEpoch)),
    CHECK ((LegacyPublicationID IS NULL AND LegacyPeriodID IS NULL AND LegacyDestinationKind IS NULL AND LegacyDestinationID IS NULL) OR (LegacyPublicationID IS NOT NULL AND LegacyPeriodID IS NOT NULL AND LegacyDestinationKind IS NOT NULL AND LegacyDestinationKind = 'sheets' AND DATALENGTH(LegacyDestinationKind) = 6 AND LegacyDestinationID IS NOT NULL)),
    CHECK (LEN(Actor) > 0 AND DATALENGTH(Actor) = DATALENGTH(LTRIM(RTRIM(Actor))) AND LEN(Reason) > 0),
    CHECK (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536)
);
CREATE INDEX IX_SourceOutputDisposition_FileHistory ON #S10D_KVK_SourceOutputDisposition (PoolID, FileID, SequenceNo);
CREATE INDEX IX_SourceOutputDisposition_Attempt ON #S10D_KVK_SourceOutputDisposition (AttemptID, PartNo) WHERE AttemptID IS NOT NULL;

DECLARE @S10DMap TABLE (Name sysname NOT NULL, ActualID int NULL, ExpectedID int NOT NULL);
INSERT @S10DMap VALUES
(N'KVK.SeasonSource',OBJECT_ID(N'KVK.SeasonSource',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SeasonSource')),
(N'KVK.SourceRouting',OBJECT_ID(N'KVK.SourceRouting',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceRouting')),
(N'KVK.SourceDelivery',OBJECT_ID(N'KVK.SourceDelivery',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceDelivery')),
(N'KVK.SourcePublication',OBJECT_ID(N'KVK.SourcePublication',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourcePublication')),
(N'dbo.ExportJob',OBJECT_ID(N'dbo.ExportJob',N'U'),OBJECT_ID(N'tempdb..#S10D_dbo_ExportJob')),
(N'dbo.ExportResource',OBJECT_ID(N'dbo.ExportResource',N'U'),OBJECT_ID(N'tempdb..#S10D_dbo_ExportResource')),
(N'dbo.ExportJobResource',OBJECT_ID(N'dbo.ExportJobResource',N'U'),OBJECT_ID(N'tempdb..#S10D_dbo_ExportJobResource')),
(N'dbo.ExportRequestBudget',OBJECT_ID(N'dbo.ExportRequestBudget',N'U'),OBJECT_ID(N'tempdb..#S10D_dbo_ExportRequestBudget')),
(N'dbo.ExportAttempt',OBJECT_ID(N'dbo.ExportAttempt',N'U'),OBJECT_ID(N'tempdb..#S10D_dbo_ExportAttempt')),
(N'dbo.ExportAttemptPart',OBJECT_ID(N'dbo.ExportAttemptPart',N'U'),OBJECT_ID(N'tempdb..#S10D_dbo_ExportAttemptPart')),
(N'dbo.ExportPreparation',OBJECT_ID(N'dbo.ExportPreparation',N'U'),OBJECT_ID(N'tempdb..#S10D_dbo_ExportPreparation')),
(N'dbo.ExportPreparationResource',OBJECT_ID(N'dbo.ExportPreparationResource',N'U'),OBJECT_ID(N'tempdb..#S10D_dbo_ExportPreparationResource'));
DECLARE @S10DFK TABLE (ParentName sysname, ConstraintName sysname, Ordinal int, ParentColumn sysname, TargetName nvarchar(256), TargetColumn sysname);
INSERT @S10DFK VALUES
(N'KVK.SourceRouting',N'FK_SourceRouting_Period',1,N'SourceKey',N'KVK.SourceSelection',N'SourceKey'),
(N'KVK.SourceRouting',N'FK_SourceRouting_Period',2,N'KVK_NO',N'KVK.SourceSelection',N'KVK_NO'),
(N'KVK.SourceRouting',N'FK_SourceRouting_Period',3,N'DisplayPeriodID',N'KVK.SourceSelection',N'PeriodID'),
(N'KVK.SourceDelivery',N'FK_SourceDelivery_Publication',1,N'SourceKey',N'KVK.SourcePublication',N'SourceKey'),
(N'KVK.SourceDelivery',N'FK_SourceDelivery_Publication',2,N'KVK_NO',N'KVK.SourcePublication',N'KVK_NO'),
(N'KVK.SourceDelivery',N'FK_SourceDelivery_Publication',3,N'PeriodID',N'KVK.SourcePublication',N'PeriodID'),
(N'KVK.SourceDelivery',N'FK_SourceDelivery_Publication',4,N'PublicationID',N'KVK.SourcePublication',N'PublicationID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Period',1,N'SourceKey',N'KVK.SourcePeriod',N'SourceKey'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Period',2,N'KVK_NO',N'KVK.SourcePeriod',N'KVK_NO'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Period',3,N'PeriodID',N'KVK.SourcePeriod',N'PeriodID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Period',4,N'PeriodKey',N'KVK.SourcePeriod',N'PeriodKey'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Window',1,N'SourceKey',N'KVK.SourceWindowConfig',N'SourceKey'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Window',2,N'KVK_NO',N'KVK.SourceWindowConfig',N'KVK_NO'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Window',3,N'ConfigVersionID',N'KVK.SourceWindowConfig',N'ConfigVersionID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Window',4,N'PeriodKey',N'KVK.SourceWindowConfig',N'PeriodKey'),
(N'KVK.SourcePublication',N'FK_SourcePublication_ConfigRoster',1,N'SourceKey',N'KVK.SourceConfigVersion',N'SourceKey'),
(N'KVK.SourcePublication',N'FK_SourcePublication_ConfigRoster',2,N'KVK_NO',N'KVK.SourceConfigVersion',N'KVK_NO'),
(N'KVK.SourcePublication',N'FK_SourcePublication_ConfigRoster',3,N'ConfigVersionID',N'KVK.SourceConfigVersion',N'ConfigVersionID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_ConfigRoster',4,N'RosterID',N'KVK.SourceConfigVersion',N'RosterID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_StartBinding',1,N'ConfigVersionID',N'KVK.SourceScanBinding',N'ConfigVersionID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_StartBinding',2,N'StartScanID',N'KVK.SourceScanBinding',N'LogicalScanID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_EndBinding',1,N'ConfigVersionID',N'KVK.SourceScanBinding',N'ConfigVersionID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_EndBinding',2,N'EndScanID',N'KVK.SourceScanBinding',N'LogicalScanID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_StartRevision',1,N'SourceKey',N'KVK.SourceObservationRevision',N'SourceKey'),
(N'KVK.SourcePublication',N'FK_SourcePublication_StartRevision',2,N'KVK_NO',N'KVK.SourceObservationRevision',N'KVK_NO'),
(N'KVK.SourcePublication',N'FK_SourcePublication_StartRevision',3,N'StartRevisionID',N'KVK.SourceObservationRevision',N'RevisionID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_EndRevision',1,N'SourceKey',N'KVK.SourceObservationRevision',N'SourceKey'),
(N'KVK.SourcePublication',N'FK_SourcePublication_EndRevision',2,N'KVK_NO',N'KVK.SourceObservationRevision',N'KVK_NO'),
(N'KVK.SourcePublication',N'FK_SourcePublication_EndRevision',3,N'EndRevisionID',N'KVK.SourceObservationRevision',N'RevisionID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Aggregate',1,N'SourceKey',N'KVK.SourceAggregateRevision',N'SourceKey'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Aggregate',2,N'KVK_NO',N'KVK.SourceAggregateRevision',N'KVK_NO'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Aggregate',3,N'AggregateReportID',N'KVK.SourceAggregateRevision',N'ReportID'),
(N'KVK.SourcePublication',N'FK_SourcePublication_Aggregate',4,N'AggregateRevisionID',N'KVK.SourceAggregateRevision',N'RevisionID'),
(N'dbo.ExportJob',N'FK_ExportJob_Intent',1,N'SourceKey',N'KVK.SourceExportIntent',N'SourceKey'),
(N'dbo.ExportJob',N'FK_ExportJob_Intent',2,N'KVK_NO',N'KVK.SourceExportIntent',N'KVK_NO'),
(N'dbo.ExportJob',N'FK_ExportJob_Intent',3,N'IntentID',N'KVK.SourceExportIntent',N'IntentID'),
(N'dbo.ExportJob',N'FK_ExportJob_Superseded',1,N'SupersededByJobID',N'dbo.ExportJob',N'JobID'),
(N'dbo.ExportJob',N'FK_ExportJob_Superseded',2,N'ConsumerKind',N'dbo.ExportJob',N'ConsumerKind'),
(N'dbo.ExportJob',N'FK_ExportJob_Superseded',3,N'AccountKey',N'dbo.ExportJob',N'AccountKey'),
(N'dbo.ExportJob',N'FK_ExportJob_Superseded',4,N'KVK_NO',N'dbo.ExportJob',N'KVK_NO'),
(N'dbo.ExportJob',N'FK_ExportJob_Superseded',5,N'DestinationSetHash',N'dbo.ExportJob',N'DestinationSetHash'),
(N'dbo.ExportJob',N'FK_ExportJob_Superseded',6,N'PoolEpoch',N'dbo.ExportJob',N'PoolEpoch'),
(N'dbo.ExportResource',N'FK_ExportResource_ActiveMembership',1,N'ActiveJobID',N'dbo.ExportJobResource',N'JobID'),
(N'dbo.ExportResource',N'FK_ExportResource_ActiveMembership',2,N'ResourceKey',N'dbo.ExportJobResource',N'ResourceKey'),
(N'dbo.ExportResource',N'FK_ExportResource_PreparationMembership',1,N'ActivePreparationID',N'dbo.ExportPreparationResource',N'PreparationID'),
(N'dbo.ExportResource',N'FK_ExportResource_PreparationMembership',2,N'ResourceKey',N'dbo.ExportPreparationResource',N'ResourceKey'),
(N'dbo.ExportJobResource',N'FK_ExportJobResource_Job',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'dbo.ExportJobResource',N'FK_ExportJobResource_Resource',1,N'ResourceKey',N'dbo.ExportResource',N'ResourceKey'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_Job',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_Job',2,N'ConsumerKind',N'dbo.ExportJob',N'ConsumerKind'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_Epoch',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_Epoch',2,N'Epoch',N'dbo.ExportJob',N'PoolEpoch'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacyDelivery',1,N'LegacyPublicationID',N'KVK.SourceDelivery',N'PublicationID'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacyDelivery',2,N'LegacyDestinationKind',N'KVK.SourceDelivery',N'DestinationKind'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacyDelivery',3,N'LegacyDestinationID',N'KVK.SourceDelivery',N'DestinationID'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacyPublication',1,N'LegacySourceKey',N'KVK.SourcePublication',N'SourceKey'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacyPublication',2,N'LegacyKVK_NO',N'KVK.SourcePublication',N'KVK_NO'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacyPublication',3,N'LegacyPeriodID',N'KVK.SourcePublication',N'PeriodID'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacyPublication',4,N'LegacyPublicationID',N'KVK.SourcePublication',N'PublicationID'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacySeason',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'dbo.ExportAttempt',N'FK_ExportAttempt_LegacySeason',2,N'LegacyKVK_NO',N'dbo.ExportJob',N'KVK_NO'),
(N'dbo.ExportAttemptPart',N'FK_ExportAttemptPart_Attempt',1,N'AttemptID',N'dbo.ExportAttempt',N'AttemptID'),
(N'dbo.ExportAttemptPart',N'FK_ExportAttemptPart_Attempt',2,N'PartCount',N'dbo.ExportAttempt',N'PartCount'),
(N'dbo.ExportPreparation',N'FK_ExportPreparation_Job',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'dbo.ExportPreparationResource',N'FK_ExportPreparationResource_Preparation',1,N'PreparationID',N'dbo.ExportPreparation',N'PreparationID'),
(N'dbo.ExportPreparationResource',N'FK_ExportPreparationResource_Resource',1,N'ResourceKey',N'dbo.ExportResource',N'ResourceKey'),
(N'KVK.SourceOutputFile',N'FK_SourceOutputFile_Resource',1,N'ResourceKey',N'dbo.ExportResource',N'ResourceKey'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Index',1,N'IndexFileID',N'KVK.SourceOutputFile',N'FileID'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Index',2,N'IndexFileKind',N'KVK.SourceOutputFile',N'FileKind'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Account',1,N'AccountResourceKey',N'dbo.ExportResource',N'ResourceKey'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Choice',1,N'ActiveKVK',N'KVK.SeasonSource',N'KVK_NO'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Choice',2,N'SourceKey',N'KVK.SeasonSource',N'SourceKey'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Choice',3,N'ChoiceID',N'KVK.SeasonSource',N'ChoiceID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_File',1,N'FileID',N'KVK.SourceOutputFile',N'FileID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_File',2,N'FileKind',N'KVK.SourceOutputFile',N'FileKind'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Pool',1,N'PoolID',N'KVK.SourceOutputPool',N'PoolID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Part',1,N'AttemptID',N'dbo.ExportAttemptPart',N'AttemptID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Part',2,N'PartNo',N'dbo.ExportAttemptPart',N'PartNo'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Part',3,N'FileID',N'dbo.ExportAttemptPart',N'FileID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Assignment',1,N'AssignmentID',N'KVK.SourceOutputDisposition',N'DispositionID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Assignment',2,N'PoolID',N'KVK.SourceOutputDisposition',N'PoolID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Assignment',3,N'FileID',N'KVK.SourceOutputDisposition',N'FileID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Assignment',4,N'Epoch',N'KVK.SourceOutputDisposition',N'NewEpoch'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Assignment',5,N'AttemptID',N'KVK.SourceOutputDisposition',N'AttemptID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Assignment',6,N'PartNo',N'KVK.SourceOutputDisposition',N'PartNo'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Assignment',7,N'AssignmentVersion',N'KVK.SourceOutputDisposition',N'ToSlotVersion'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Assignment',8,N'AssignmentAction',N'KVK.SourceOutputDisposition',N'Action'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Disposition',1,N'LastDispositionID',N'KVK.SourceOutputDisposition',N'DispositionID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Disposition',2,N'PoolID',N'KVK.SourceOutputDisposition',N'PoolID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Disposition',3,N'FileID',N'KVK.SourceOutputDisposition',N'FileID'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Disposition',4,N'Epoch',N'KVK.SourceOutputDisposition',N'NewEpoch'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Disposition',5,N'LastAction',N'KVK.SourceOutputDisposition',N'Action'),
(N'KVK.SourceOutputSlot',N'FK_SourceOutputSlot_Disposition',6,N'LastDispositionVersion',N'KVK.SourceOutputDisposition',N'ToSlotVersion'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_File',1,N'FileID',N'KVK.SourceOutputFile',N'FileID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_File',2,N'FileKind',N'KVK.SourceOutputFile',N'FileKind'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Resource',1,N'FileID',N'KVK.SourceOutputFile',N'FileID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Resource',2,N'ResourceKey',N'KVK.SourceOutputFile',N'ResourceKey'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Pool',1,N'PoolID',N'KVK.SourceOutputPool',N'PoolID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Pool',2,N'AccountKey',N'KVK.SourceOutputPool',N'AccountKey'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Slot',1,N'PoolID',N'KVK.SourceOutputSlot',N'PoolID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Slot',2,N'SlotFileID',N'KVK.SourceOutputSlot',N'FileID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Index',1,N'PoolID',N'KVK.SourceOutputPool',N'PoolID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Index',2,N'IndexFileID',N'KVK.SourceOutputPool',N'IndexFileID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Choice',1,N'KVK_NO',N'KVK.SeasonSource',N'KVK_NO'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Choice',2,N'SourceKey',N'KVK.SeasonSource',N'SourceKey'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Choice',3,N'ChoiceID',N'KVK.SeasonSource',N'ChoiceID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_NewChoice',1,N'NewKVK_NO',N'KVK.SeasonSource',N'KVK_NO'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_NewChoice',2,N'SourceKey',N'KVK.SeasonSource',N'SourceKey'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_NewChoice',3,N'NewChoiceID',N'KVK.SeasonSource',N'ChoiceID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Job',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Job',2,N'ConsumerKind',N'dbo.ExportJob',N'ConsumerKind'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Job',3,N'AccountKey',N'dbo.ExportJob',N'AccountKey'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Job',4,N'KVK_NO',N'dbo.ExportJob',N'KVK_NO'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Job',5,N'DestinationSetHash',N'dbo.ExportJob',N'DestinationSetHash'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Job',6,N'AttemptEpoch',N'dbo.ExportJob',N'PoolEpoch'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Attempt',1,N'AttemptID',N'dbo.ExportAttempt',N'AttemptID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Attempt',2,N'JobID',N'dbo.ExportAttempt',N'JobID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Attempt',3,N'AttemptEpoch',N'dbo.ExportAttempt',N'Epoch'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Part',1,N'AttemptID',N'dbo.ExportAttemptPart',N'AttemptID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Part',2,N'PartNo',N'dbo.ExportAttemptPart',N'PartNo'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Part',3,N'FileID',N'dbo.ExportAttemptPart',N'FileID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Membership',1,N'JobID',N'dbo.ExportJobResource',N'JobID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_Membership',2,N'ResourceKey',N'dbo.ExportJobResource',N'ResourceKey'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyDelivery',1,N'LegacyPublicationID',N'KVK.SourceDelivery',N'PublicationID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyDelivery',2,N'LegacyDestinationKind',N'KVK.SourceDelivery',N'DestinationKind'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyDelivery',3,N'LegacyDestinationID',N'KVK.SourceDelivery',N'DestinationID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyPublication',1,N'SourceKey',N'KVK.SourcePublication',N'SourceKey'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyPublication',2,N'KVK_NO',N'KVK.SourcePublication',N'KVK_NO'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyPublication',3,N'LegacyPeriodID',N'KVK.SourcePublication',N'PeriodID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyPublication',4,N'LegacyPublicationID',N'KVK.SourcePublication',N'PublicationID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyIndex',1,N'PoolID',N'KVK.SourceOutputPool',N'PoolID'),
(N'KVK.SourceOutputDisposition',N'FK_SourceOutputDisposition_LegacyIndex',2,N'LegacyDestinationID',N'KVK.SourceOutputPool',N'IndexFileID');
IF @S10DExisting=4
BEGIN
ALTER TABLE #S10D_dbo_ExportAttempt ADD UNIQUE (AttemptID, JobID, Epoch);
ALTER TABLE #S10D_dbo_ExportAttemptPart ADD UNIQUE (AttemptID, PartNo, FileID);
INSERT @S10DMap VALUES
(N'KVK.SourceOutputFile',OBJECT_ID(N'KVK.SourceOutputFile',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceOutputFile')),
(N'KVK.SourceOutputPool',OBJECT_ID(N'KVK.SourceOutputPool',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceOutputPool')),
(N'KVK.SourceOutputSlot',OBJECT_ID(N'KVK.SourceOutputSlot',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceOutputSlot')),
(N'KVK.SourceOutputDisposition',OBJECT_ID(N'KVK.SourceOutputDisposition',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceOutputDisposition'));
END;
-- Verify inherited accepted shape before any permanent ALTER. Verify full expected shape
-- after install, or immediately on rerun. Never seal arbitrary observed metadata.
DECLARE @S10DPass int=0;
WHILE @S10DPass<2
BEGIN
IF EXISTS (SELECT 1 FROM @S10DMap WHERE ActualID IS NULL)
    THROW 51500, 'S10D prerequisite/object type conflict; no predecessor execution authorized.', 1;
-- EXCEPT in both directions rejects missing, extra, disabled, untrusted or altered shape.
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10DMap m JOIN sys.columns c ON c.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10DMap m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10DMap m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10DMap m JOIN sys.columns c ON c.object_id=m.ActualID)
    THROW 51500, 'S10D column shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S10DMap m JOIN sys.columns c ON c.object_id=m.ActualID WHERE c.user_type_id<>c.system_type_id) THROW 51500, 'S10D alias type conflict.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10DMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10DMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10DMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10DMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID)
    THROW 51500, 'S10D check constraint shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10DMap m JOIN sys.indexes i ON i.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10DMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10DMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10DMap m JOIN sys.indexes i ON i.object_id=m.ActualID)
    THROW 51500, 'S10D index shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10DMap m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10DMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10DMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10DMap m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name)
    THROW 51500, 'S10D index count shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S10DMap m JOIN sys.triggers t ON t.parent_id=m.ActualID)
OR EXISTS (SELECT 1 FROM @S10DMap m JOIN sys.tables t ON t.object_id=m.ActualID WHERE t.temporal_type<>0 OR t.is_memory_optimized<>0)
    THROW 51500, 'S10D unexpected default, trigger or table mode.', 1;
-- Defaults are part of the inherited contract (SourceRouting has Enabled=0).
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S10DMap m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S10DMap m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S10DMap m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S10DMap m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID)
    THROW 51500, 'S10D default shape conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10DMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10DMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10DMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10DMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name)
    THROW 51500, 'S10D check count conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S10DMap m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
EXCEPT
SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S10DFK e WHERE EXISTS (SELECT 1 FROM @S10DMap m WHERE m.Name=e.ParentName))
OR EXISTS (SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S10DFK e WHERE EXISTS (SELECT 1 FROM @S10DMap m WHERE m.Name=e.ParentName)
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S10DMap m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id)
    THROW 51500, 'S10D foreign key shape conflict; preserve history and forward-fix.', 1;
IF @S10DExisting=0 AND @S10DPass=0
BEGIN
ALTER TABLE #S10D_dbo_ExportAttempt ADD UNIQUE (AttemptID, JobID, Epoch);
ALTER TABLE #S10D_dbo_ExportAttemptPart ADD UNIQUE (AttemptID, PartNo, FileID);
-- S10D_INSTALL_PAYLOAD_BEGIN: constant DDL compiled only after all inherited guards.
EXEC sys.sp_executesql N'ALTER TABLE dbo.ExportAttempt ADD CONSTRAINT UQ_ExportAttempt_JobEpoch UNIQUE (AttemptID, JobID, Epoch);
ALTER TABLE dbo.ExportAttemptPart ADD CONSTRAINT UQ_ExportAttemptPart_NumberFile UNIQUE (AttemptID, PartNo, FileID);
CREATE TABLE KVK.SourceOutputFile
(
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegisteredBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegisteredUTC datetime2(0) NOT NULL,
    EvidenceHash binary(32) NOT NULL,
    EvidenceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceOutputFile PRIMARY KEY (FileID),
    CONSTRAINT UQ_SourceOutputFile_Kind UNIQUE (FileID, FileKind),
    CONSTRAINT UQ_SourceOutputFile_Resource UNIQUE (FileID, ResourceKey),
    CONSTRAINT UQ_SourceOutputFile_ResourceKey UNIQUE (ResourceKey),
    CONSTRAINT CK_SourceOutputFile_Identity CHECK (DATALENGTH(FileID) BETWEEN 6 AND 256 AND FileID NOT LIKE N''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2),
    CONSTRAINT CK_SourceOutputFile_Kind CHECK (FileKind IN (''index'',''slot'') AND DATALENGTH(FileKind) = LEN(FileKind)),
    CONSTRAINT CK_SourceOutputFile_Resource CHECK (ResourceKey = ''destination:'' + CONVERT(varchar(128), FileID) AND DATALENGTH(ResourceKey) = 12 + DATALENGTH(FileID) / 2),
    CONSTRAINT CK_SourceOutputFile_Actor CHECK (LEN(RegisteredBy) > 0 AND DATALENGTH(RegisteredBy) = DATALENGTH(LTRIM(RTRIM(RegisteredBy)))),
    CONSTRAINT CK_SourceOutputFile_Evidence CHECK (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536)
);
CREATE TABLE KVK.SourceOutputPool
(
    PoolID uniqueidentifier NOT NULL,
    IndexFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    IndexFileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegistrationNo int NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AccountResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ExpectedOwner nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AudienceJson nvarchar(max) NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActiveKVK int NULL,
    ChoiceID uniqueidentifier NULL,
    Epoch bigint NOT NULL,
    PoolState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Version bigint NOT NULL,
    BlockedReason nvarchar(1024) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    RegistrationHash binary(32) NOT NULL,
    RegistrationJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceOutputPool PRIMARY KEY (PoolID),
    CONSTRAINT UQ_SourceOutputPool_Index UNIQUE (IndexFileID),
    CONSTRAINT UQ_SourceOutputPool_Registration UNIQUE (RegistrationNo),
    CONSTRAINT UQ_SourceOutputPool_Account UNIQUE (PoolID, AccountKey),
    CONSTRAINT UQ_SourceOutputPool_File UNIQUE (PoolID, IndexFileID),
    CONSTRAINT CK_SourceOutputPool_Index CHECK (IndexFileKind = ''index'' AND DATALENGTH(IndexFileKind) = 5),
    CONSTRAINT CK_SourceOutputPool_Registration CHECK (RegistrationNo BETWEEN 1 AND 8),
    CONSTRAINT CK_SourceOutputPool_Account CHECK (LEN(AccountKey) > 0 AND AccountKey NOT LIKE ''%[^A-Za-z0-9_.@:-]%'' COLLATE Latin1_General_100_BIN2 AND AccountResourceKey = ''account:'' + AccountKey AND DATALENGTH(AccountResourceKey) = 8 + DATALENGTH(AccountKey)),
    CONSTRAINT CK_SourceOutputPool_OwnerIdentity CHECK (LEN(ExpectedOwner) > 0 AND DATALENGTH(ExpectedOwner) = DATALENGTH(LTRIM(RTRIM(ExpectedOwner)))),
    CONSTRAINT CK_SourceOutputPool_Scope CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND ((ActiveKVK IS NULL AND ChoiceID IS NULL AND PoolState IN (''setup'',''blocked'')) OR (ActiveKVK IS NOT NULL AND ActiveKVK > 0 AND ChoiceID IS NOT NULL))),
    CONSTRAINT CK_SourceOutputPool_State CHECK (PoolState IN (''active'',''closing'',''closed'',''setup'',''blocked'') AND DATALENGTH(PoolState) = LEN(PoolState)),
    CONSTRAINT CK_SourceOutputPool_Ownership CHECK ((OwnerID IS NULL AND Fence >= 0 AND PoolState <> ''closing'') OR (OwnerID IS NOT NULL AND Fence > 0 AND PoolState <> ''closed'')),
    CONSTRAINT CK_SourceOutputPool_Blocked CHECK ((PoolState = ''blocked'' AND BlockedReason IS NOT NULL AND LEN(BlockedReason) > 0) OR (PoolState <> ''blocked'' AND BlockedReason IS NULL)),
    CONSTRAINT CK_SourceOutputPool_Counters CHECK (Epoch > 0 AND Version > 0 AND UpdatedUTC >= CreatedUTC),
    CONSTRAINT CK_SourceOutputPool_Audience CHECK (ISJSON(AudienceJson) = 1 AND DATALENGTH(AudienceJson) <= 65536),
    CONSTRAINT CK_SourceOutputPool_Evidence CHECK (ISJSON(RegistrationJson) = 1 AND DATALENGTH(RegistrationJson) <= 65536)
);
CREATE TABLE KVK.SourceOutputSlot
(
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    SlotNo int NOT NULL,
    Epoch bigint NOT NULL,
    State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Version bigint NOT NULL,
    AssignmentID uniqueidentifier NULL,
    AssignmentAction varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    AttemptID uniqueidentifier NULL,
    PartNo int NULL,
    AssignmentVersion bigint NULL,
    LastDispositionID uniqueidentifier NULL,
    LastAction varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LastDispositionVersion bigint NULL,
    QuarantineReason nvarchar(1024) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceOutputSlot PRIMARY KEY (FileID),
    CONSTRAINT UQ_SourceOutputSlot_PoolFile UNIQUE (PoolID, FileID),
    CONSTRAINT UQ_SourceOutputSlot_Position UNIQUE (PoolID, SlotNo),
    CONSTRAINT CK_SourceOutputSlot_Kind CHECK (FileKind = ''slot'' AND DATALENGTH(FileKind) = 4),
    CONSTRAINT CK_SourceOutputSlot_Counters CHECK (SlotNo BETWEEN 1 AND 16 AND Epoch > 0 AND Version > 0 AND UpdatedUTC >= CreatedUTC),
    CONSTRAINT CK_SourceOutputSlot_State CHECK (State IN (''free'',''staging'',''active'',''quarantined'',''retired'') AND DATALENGTH(State) = LEN(State)),
    CONSTRAINT CK_SourceOutputSlot_Ownership CHECK ((OwnerID IS NULL AND Fence >= 0 AND State <> ''staging'') OR (OwnerID IS NOT NULL AND Fence > 0 AND State IN (''staging'',''active'',''quarantined''))),
    CONSTRAINT CK_SourceOutputSlot_Assignment CHECK ((AssignmentID IS NULL AND AssignmentAction IS NULL AND AttemptID IS NULL AND PartNo IS NULL AND AssignmentVersion IS NULL AND State IN (''free'',''quarantined'',''retired'')) OR (AssignmentID IS NOT NULL AND AssignmentAction IS NOT NULL AND AssignmentAction = ''assign'' AND DATALENGTH(AssignmentAction) = 6 AND AttemptID IS NOT NULL AND PartNo IS NOT NULL AND PartNo BETWEEN 1 AND 1024 AND AssignmentVersion IS NOT NULL AND AssignmentVersion > 0 AND AssignmentVersion <= Version AND State <> ''free'')),
    CONSTRAINT CK_SourceOutputSlot_Disposition CHECK ((LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = ''quarantined'' AND AssignmentID IS NULL) OR (LastDispositionID IS NOT NULL AND LastAction IS NOT NULL AND DATALENGTH(LastAction) = LEN(LastAction) AND LastDispositionVersion IS NOT NULL AND LastDispositionVersion > 0 AND LastDispositionVersion <= Version AND ((State = ''free'' AND LastAction = ''clear'') OR (State IN (''staging'',''active'') AND LastAction = ''assign'' AND LastDispositionID = AssignmentID) OR (State = ''quarantined'' AND LastAction = ''quarantine'') OR (State = ''retired'' AND LastAction = ''retire'')))),
    CONSTRAINT CK_SourceOutputSlot_Quarantine CHECK ((State = ''quarantined'' AND QuarantineReason IS NOT NULL AND LEN(QuarantineReason) > 0) OR (State <> ''quarantined'' AND QuarantineReason IS NULL))
);
CREATE TABLE KVK.SourceOutputDisposition
(
    DispositionID uniqueidentifier NOT NULL,
    OperationID uniqueidentifier NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    SequenceNo bigint NOT NULL,
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SlotFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    IndexFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    NewKVK_NO int NOT NULL,
    NewChoiceID uniqueidentifier NOT NULL,
    OldEpoch bigint NOT NULL,
    NewEpoch bigint NOT NULL,
    Action varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OwnerID uniqueidentifier NOT NULL,
    Fence bigint NOT NULL,
    FromPoolVersion bigint NOT NULL,
    ToPoolVersion bigint NOT NULL,
    FromSlotVersion bigint NULL,
    ToSlotVersion bigint NULL,
    JobID uniqueidentifier NULL,
    ConsumerKind varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    DestinationSetHash binary(32) NULL,
    AttemptID uniqueidentifier NULL,
    PartNo int NULL,
    AttemptEpoch bigint NULL,
    LegacyPublicationID uniqueidentifier NULL,
    LegacyPeriodID uniqueidentifier NULL,
    LegacyDestinationKind varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LegacyDestinationID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    OccurredUTC datetime2(0) NOT NULL,
    EvidenceHash binary(32) NOT NULL,
    EvidenceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceOutputDisposition PRIMARY KEY (DispositionID),
    CONSTRAINT UQ_SourceOutputDisposition_Sequence UNIQUE (PoolID, SequenceNo),
    CONSTRAINT UQ_SourceOutputDisposition_Replay UNIQUE (PoolID, OperationID, FileID, Action),
    CONSTRAINT UQ_SourceOutputDisposition_Assignment UNIQUE (DispositionID, PoolID, FileID, NewEpoch, AttemptID, PartNo, ToSlotVersion, Action),
    CONSTRAINT UQ_SourceOutputDisposition_Current UNIQUE (DispositionID, PoolID, FileID, NewEpoch, Action, ToSlotVersion),
    CONSTRAINT CK_SourceOutputDisposition_File CHECK ((FileKind = ''slot'' AND DATALENGTH(FileKind) = 4 AND SlotFileID IS NOT NULL AND SlotFileID = FileID AND DATALENGTH(SlotFileID) = DATALENGTH(FileID) AND IndexFileID IS NULL AND FromSlotVersion IS NOT NULL AND ToSlotVersion IS NOT NULL AND FromSlotVersion > 0 AND ToSlotVersion > FromSlotVersion AND ToSlotVersion - FromSlotVersion = 1) OR (FileKind = ''index'' AND DATALENGTH(FileKind) = 5 AND IndexFileID IS NOT NULL AND IndexFileID = FileID AND DATALENGTH(IndexFileID) = DATALENGTH(FileID) AND SlotFileID IS NULL AND FromSlotVersion IS NULL AND ToSlotVersion IS NULL)),
    CONSTRAINT CK_SourceOutputDisposition_Scope CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0 AND NewKVK_NO > 0),
    CONSTRAINT CK_SourceOutputDisposition_Action CHECK (Action IN (''retire'',''quarantine'',''clear'',''assign'') AND DATALENGTH(Action) = LEN(Action)),
    CONSTRAINT CK_SourceOutputDisposition_Epoch CHECK (OldEpoch > 0 AND NewEpoch >= OldEpoch AND NewEpoch - OldEpoch BETWEEN 0 AND 1 AND ((NewEpoch = OldEpoch AND NewKVK_NO = KVK_NO AND NewChoiceID = ChoiceID) OR (NewEpoch > OldEpoch AND Action = ''clear''))),
    CONSTRAINT CK_SourceOutputDisposition_Owner CHECK (Fence > 0 AND SequenceNo > 0 AND FromPoolVersion > 0 AND ToPoolVersion > FromPoolVersion AND ToPoolVersion - FromPoolVersion = 1),
    CONSTRAINT CK_SourceOutputDisposition_Attempt CHECK ((JobID IS NULL AND ConsumerKind IS NULL AND DestinationSetHash IS NULL AND AttemptID IS NULL AND PartNo IS NULL AND AttemptEpoch IS NULL AND Action <> ''assign'') OR (JobID IS NOT NULL AND ConsumerKind IS NOT NULL AND ConsumerKind = ''new_source'' AND DATALENGTH(ConsumerKind) = 10 AND DestinationSetHash IS NOT NULL AND AttemptID IS NOT NULL AND PartNo IS NOT NULL AND PartNo BETWEEN 1 AND 1024 AND AttemptEpoch IS NOT NULL AND AttemptEpoch = OldEpoch)),
    CONSTRAINT CK_SourceOutputDisposition_Legacy CHECK ((LegacyPublicationID IS NULL AND LegacyPeriodID IS NULL AND LegacyDestinationKind IS NULL AND LegacyDestinationID IS NULL) OR (LegacyPublicationID IS NOT NULL AND LegacyPeriodID IS NOT NULL AND LegacyDestinationKind IS NOT NULL AND LegacyDestinationKind = ''sheets'' AND DATALENGTH(LegacyDestinationKind) = 6 AND LegacyDestinationID IS NOT NULL)),
    CONSTRAINT CK_SourceOutputDisposition_Actor CHECK (LEN(Actor) > 0 AND DATALENGTH(Actor) = DATALENGTH(LTRIM(RTRIM(Actor))) AND LEN(Reason) > 0),
    CONSTRAINT CK_SourceOutputDisposition_Evidence CHECK (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536)
);
ALTER TABLE KVK.SourceOutputFile WITH CHECK ADD CONSTRAINT FK_SourceOutputFile_Resource FOREIGN KEY (ResourceKey) REFERENCES dbo.ExportResource (ResourceKey);
CREATE INDEX IX_SourceOutputPool_State ON KVK.SourceOutputPool (AccountKey, PoolState, PoolID);
ALTER TABLE KVK.SourceOutputPool WITH CHECK ADD CONSTRAINT FK_SourceOutputPool_Index FOREIGN KEY (IndexFileID, IndexFileKind) REFERENCES KVK.SourceOutputFile (FileID, FileKind);
ALTER TABLE KVK.SourceOutputPool WITH CHECK ADD CONSTRAINT FK_SourceOutputPool_Account FOREIGN KEY (AccountResourceKey) REFERENCES dbo.ExportResource (ResourceKey);
ALTER TABLE KVK.SourceOutputPool WITH CHECK ADD CONSTRAINT FK_SourceOutputPool_Choice FOREIGN KEY (ActiveKVK, SourceKey, ChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID);
CREATE INDEX IX_SourceOutputSlot_Availability ON KVK.SourceOutputSlot (PoolID, Epoch, State, SlotNo);
CREATE INDEX IX_SourceOutputSlot_Attempt ON KVK.SourceOutputSlot (AttemptID, PartNo) WHERE AttemptID IS NOT NULL;
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_File FOREIGN KEY (FileID, FileKind) REFERENCES KVK.SourceOutputFile (FileID, FileKind);
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_Pool FOREIGN KEY (PoolID) REFERENCES KVK.SourceOutputPool (PoolID);
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_Part FOREIGN KEY (AttemptID, PartNo, FileID) REFERENCES dbo.ExportAttemptPart (AttemptID, PartNo, FileID);
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_Assignment FOREIGN KEY (AssignmentID, PoolID, FileID, Epoch, AttemptID, PartNo, AssignmentVersion, AssignmentAction) REFERENCES KVK.SourceOutputDisposition (DispositionID, PoolID, FileID, NewEpoch, AttemptID, PartNo, ToSlotVersion, Action);
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_Disposition FOREIGN KEY (LastDispositionID, PoolID, FileID, Epoch, LastAction, LastDispositionVersion) REFERENCES KVK.SourceOutputDisposition (DispositionID, PoolID, FileID, NewEpoch, Action, ToSlotVersion);
CREATE INDEX IX_SourceOutputDisposition_FileHistory ON KVK.SourceOutputDisposition (PoolID, FileID, SequenceNo);
CREATE INDEX IX_SourceOutputDisposition_Attempt ON KVK.SourceOutputDisposition (AttemptID, PartNo) WHERE AttemptID IS NOT NULL;
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_File FOREIGN KEY (FileID, FileKind) REFERENCES KVK.SourceOutputFile (FileID, FileKind);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Resource FOREIGN KEY (FileID, ResourceKey) REFERENCES KVK.SourceOutputFile (FileID, ResourceKey);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Pool FOREIGN KEY (PoolID, AccountKey) REFERENCES KVK.SourceOutputPool (PoolID, AccountKey);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Slot FOREIGN KEY (PoolID, SlotFileID) REFERENCES KVK.SourceOutputSlot (PoolID, FileID);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Index FOREIGN KEY (PoolID, IndexFileID) REFERENCES KVK.SourceOutputPool (PoolID, IndexFileID);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Choice FOREIGN KEY (KVK_NO, SourceKey, ChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_NewChoice FOREIGN KEY (NewKVK_NO, SourceKey, NewChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Job FOREIGN KEY (JobID, ConsumerKind, AccountKey, KVK_NO, DestinationSetHash, AttemptEpoch) REFERENCES dbo.ExportJob (JobID, ConsumerKind, AccountKey, KVK_NO, DestinationSetHash, PoolEpoch);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Attempt FOREIGN KEY (AttemptID, JobID, AttemptEpoch) REFERENCES dbo.ExportAttempt (AttemptID, JobID, Epoch);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Part FOREIGN KEY (AttemptID, PartNo, FileID) REFERENCES dbo.ExportAttemptPart (AttemptID, PartNo, FileID);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_Membership FOREIGN KEY (JobID, ResourceKey) REFERENCES dbo.ExportJobResource (JobID, ResourceKey);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_LegacyDelivery FOREIGN KEY (LegacyPublicationID, LegacyDestinationKind, LegacyDestinationID) REFERENCES KVK.SourceDelivery (PublicationID, DestinationKind, DestinationID);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_LegacyPublication FOREIGN KEY (SourceKey, KVK_NO, LegacyPeriodID, LegacyPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID);
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_LegacyIndex FOREIGN KEY (PoolID, LegacyDestinationID) REFERENCES KVK.SourceOutputPool (PoolID, IndexFileID);';
-- S10D_INSTALL_PAYLOAD_END
INSERT @S10DMap VALUES
(N'KVK.SourceOutputFile',OBJECT_ID(N'KVK.SourceOutputFile',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceOutputFile')),
(N'KVK.SourceOutputPool',OBJECT_ID(N'KVK.SourceOutputPool',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceOutputPool')),
(N'KVK.SourceOutputSlot',OBJECT_ID(N'KVK.SourceOutputSlot',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceOutputSlot')),
(N'KVK.SourceOutputDisposition',OBJECT_ID(N'KVK.SourceOutputDisposition',N'U'),OBJECT_ID(N'tempdb..#S10D_KVK_SourceOutputDisposition'));
END
ELSE BREAK;
SET @S10DPass+=1;
END;
DROP TABLE #S10D_KVK_SourceOutputDisposition;
DROP TABLE #S10D_KVK_SourceOutputSlot;
DROP TABLE #S10D_KVK_SourceOutputPool;
DROP TABLE #S10D_KVK_SourceOutputFile;
DROP TABLE #S10D_dbo_ExportPreparationResource;
DROP TABLE #S10D_dbo_ExportPreparation;
DROP TABLE #S10D_dbo_ExportAttemptPart;
DROP TABLE #S10D_dbo_ExportAttempt;
DROP TABLE #S10D_dbo_ExportRequestBudget;
DROP TABLE #S10D_dbo_ExportJobResource;
DROP TABLE #S10D_dbo_ExportResource;
DROP TABLE #S10D_dbo_ExportJob;
DROP TABLE #S10D_KVK_SourcePublication;
DROP TABLE #S10D_KVK_SourceDelivery;
DROP TABLE #S10D_KVK_SourceRouting;
DROP TABLE #S10D_KVK_SeasonSource;
IF @S10DOwnTransaction=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @S10DOwnTransaction=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
    -- An ambient caller owns its transaction and must roll it back after failure.
    THROW;
END CATCH;
