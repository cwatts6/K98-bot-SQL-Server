/*
MigrationId: 20260915_002_kvk_output_operation_ownership
Purpose: Typed durable rollover ownership sharing existing account and file resources
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
PreValidationQuery: Exact accepted S10A/C/D metadata, absent or exact S10E, backup/restore and lock plan
PostValidationQuery: Exact inherited and amended metadata; unchanged existing receipt bytes and claims
RelatedBotPR:
RelatedSQLPR:
*/
-- AUTHORING ONLY. No predecessor execution, application DML, grants or activation.
-- Install only with separate target/backup/restore/lock approval. Upgrade every writer
-- before admitting operation ownership. Old readers do not understand the third owner.
-- Preserve historical receipt bytes, uncertain publications and all retained data.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @S10EOwnTransaction bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
IF @S10EOwnTransaction=1 BEGIN TRANSACTION;
BEGIN TRY
DECLARE @S10ELockResult int;
EXEC @S10ELockResult=sys.sp_getapplock @Resource=N'K98:S10E:schema', @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=0;
IF @S10ELockResult<0 THROW 51600, 'S10E schema installation is already running.', 1;
IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID(N'KVK') AND name IN ('SourceOutputOperation','SourceOutputOperationResource') AND type<>'U') THROW 51600, 'S10E object type conflict.', 1;
DECLARE @S10EExisting int=(SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'KVK') AND name IN ('SourceOutputOperation','SourceOutputOperationResource'));
IF @S10EExisting NOT IN (0,2) THROW 51600, 'Partial S10E schema; preserve and forward-fix.', 1;
CREATE TABLE #S10E_KVK_SeasonSource
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


CREATE TABLE #S10E_KVK_SourceRouting
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


CREATE TABLE #S10E_KVK_SourceDelivery
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
CREATE INDEX IX_SourceDelivery_State ON #S10E_KVK_SourceDelivery (DeliveryState, UpdatedUTC);

CREATE TABLE #S10E_KVK_SourcePublication
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


CREATE TABLE #S10E_dbo_ExportJob
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
CREATE INDEX IX_ExportJob_Queue ON #S10E_dbo_ExportJob (AccountKey, State, EnqueueSequence, JobID);
CREATE INDEX IX_ExportJob_Intent ON #S10E_dbo_ExportJob (IntentID) WHERE IntentID IS NOT NULL;
CREATE INDEX IX_ExportJob_Superseded ON #S10E_dbo_ExportJob (SupersededByJobID) WHERE SupersededByJobID IS NOT NULL;

CREATE TABLE #S10E_dbo_ExportResource
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
CREATE INDEX IX_ExportResource_ActiveJob ON #S10E_dbo_ExportResource (ActiveJobID) WHERE ActiveJobID IS NOT NULL;

CREATE TABLE #S10E_dbo_ExportJobResource
(
    JobID uniqueidentifier NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PRIMARY KEY (JobID, ResourceKey)
);
CREATE INDEX IX_ExportJobResource_Resource ON #S10E_dbo_ExportJobResource (ResourceKey, JobID);

CREATE TABLE #S10E_dbo_ExportRequestBudget
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


CREATE TABLE #S10E_dbo_ExportAttempt
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
CREATE INDEX IX_ExportAttempt_Phase ON #S10E_dbo_ExportAttempt (Phase, UpdatedUTC, JobID);

CREATE TABLE #S10E_dbo_ExportAttemptPart
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


CREATE TABLE #S10E_dbo_ExportPreparation
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
CREATE INDEX IX_ExportPreparation_Queue ON #S10E_dbo_ExportPreparation(AccountKey,State,EnqueueSequence,PreparationID);
CREATE UNIQUE INDEX UX_ExportPreparation_Job ON #S10E_dbo_ExportPreparation(JobID) WHERE JobID IS NOT NULL;

CREATE TABLE #S10E_dbo_ExportPreparationResource
(
 PreparationID uniqueidentifier NOT NULL,
 ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
 PRIMARY KEY (PreparationID,ResourceKey)
);
CREATE INDEX IX_ExportPreparationResource_Resource ON #S10E_dbo_ExportPreparationResource(ResourceKey);

CREATE TABLE #S10E_KVK_SourceOutputFile
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


CREATE TABLE #S10E_KVK_SourceOutputPool
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
CREATE INDEX IX_SourceOutputPool_State ON #S10E_KVK_SourceOutputPool (AccountKey, PoolState, PoolID);

CREATE TABLE #S10E_KVK_SourceOutputSlot
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
CREATE INDEX IX_SourceOutputSlot_Availability ON #S10E_KVK_SourceOutputSlot (PoolID, Epoch, State, SlotNo);
CREATE INDEX IX_SourceOutputSlot_Attempt ON #S10E_KVK_SourceOutputSlot (AttemptID, PartNo) WHERE AttemptID IS NOT NULL;

CREATE TABLE #S10E_KVK_SourceOutputDisposition
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
CREATE INDEX IX_SourceOutputDisposition_FileHistory ON #S10E_KVK_SourceOutputDisposition (PoolID, FileID, SequenceNo);
CREATE INDEX IX_SourceOutputDisposition_Attempt ON #S10E_KVK_SourceOutputDisposition (AttemptID, PartNo) WHERE AttemptID IS NOT NULL;

CREATE TABLE #S10E_KVK_SourceOutputOperation
(
    OperationID uniqueidentifier NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OldKVK int NOT NULL,
    OldChoiceID uniqueidentifier NOT NULL,
    NewKVK int NOT NULL,
    NewChoiceID uniqueidentifier NOT NULL,
    OldEpoch bigint NOT NULL,
    TargetEpoch bigint NOT NULL,
    PlanHash binary(32) NOT NULL,
    PlanJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    ConfirmedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    GuildID varchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChannelID varchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) COLLATE DATABASE_DEFAULT NOT NULL,
    ConfirmedUTC datetime2(0) NOT NULL,
    EnqueueSequence bigint NOT NULL,
    State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActivePoolID uniqueidentifier NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Version bigint NOT NULL,
    Phase varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CurrentFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    ProgressJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    PRIMARY KEY (OperationID),
    UNIQUE (OperationID, PoolID, AccountKey),
    CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND OldKVK > 0 AND NewKVK > 0 AND OldKVK <> NewKVK),
    CHECK (OldEpoch > 0 AND TargetEpoch > OldEpoch AND TargetEpoch - OldEpoch = 1),
    CHECK (State IN ('closing','ready','running','blocked','uncertain','completed') AND DATALENGTH(State) = LEN(State)),
    CHECK ((State = 'completed' AND ActivePoolID IS NULL) OR (State <> 'completed' AND ActivePoolID IS NOT NULL AND ActivePoolID = PoolID)),
    CHECK ((OwnerID IS NULL AND Fence >= 0 AND State IN ('closing','ready','blocked','completed')) OR (OwnerID IS NOT NULL AND Fence > 0 AND State IN ('running','blocked','uncertain'))),
    CHECK (EnqueueSequence > 0 AND Version > 0 AND UpdatedUTC >= ConfirmedUTC),
    CHECK (LEN(ConfirmedBy) > 0 AND DATALENGTH(ConfirmedBy) = DATALENGTH(LTRIM(RTRIM(ConfirmedBy))) AND LEN(Reason) > 0 AND LEN(GuildID) > 0 AND GuildID NOT LIKE '%[^0-9]%' COLLATE Latin1_General_100_BIN2 AND LEN(ChannelID) > 0 AND ChannelID NOT LIKE '%[^0-9]%' COLLATE Latin1_General_100_BIN2),
    CHECK (Phase IN ('draining','ready','private_pending','private_verified','clear_pending','clear_verified','setup_pending','setup_verified','complete','uncertain') AND DATALENGTH(Phase) = LEN(Phase)),
    CHECK ((Phase IN ('private_pending','private_verified','clear_pending','clear_verified','setup_pending','setup_verified') AND CurrentFileID IS NOT NULL) OR (Phase IN ('draining','ready','complete','uncertain'))),
    CHECK (ISJSON(PlanJson) = 1 AND DATALENGTH(PlanJson) <= 65536),
    CHECK (ISJSON(ProgressJson) = 1 AND DATALENGTH(ProgressJson) <= 65536)
);
CREATE UNIQUE INDEX UX_SourceOutputOperation_ActivePool ON #S10E_KVK_SourceOutputOperation (ActivePoolID) WHERE ActivePoolID IS NOT NULL;
CREATE INDEX IX_SourceOutputOperation_Queue ON #S10E_KVK_SourceOutputOperation (AccountKey, State, EnqueueSequence, OperationID);
CREATE TABLE #S10E_KVK_SourceOutputOperationResource
(
    OperationID uniqueidentifier NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    IndexFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    SlotFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    PRIMARY KEY (OperationID, ResourceKey),
    UNIQUE (OperationID, FileID),
    CHECK ((ResourceKind = 'account' AND DATALENGTH(ResourceKind) = 7 AND ResourceKey = 'account:' + AccountKey AND DATALENGTH(ResourceKey) = 8 + DATALENGTH(AccountKey) AND FileID IS NULL AND IndexFileID IS NULL AND SlotFileID IS NULL) OR (ResourceKind = 'destination' AND DATALENGTH(ResourceKind) = 11 AND FileID IS NOT NULL AND ResourceKey = 'destination:' + CONVERT(varchar(128),FileID) AND DATALENGTH(ResourceKey) = 12 + DATALENGTH(FileID) / 2 AND ((IndexFileID IS NOT NULL AND IndexFileID = FileID AND SlotFileID IS NULL) OR (SlotFileID IS NOT NULL AND SlotFileID = FileID AND IndexFileID IS NULL))))
);
DECLARE @S10EMap TABLE (Name sysname NOT NULL, ActualID int NULL, ExpectedID int NOT NULL);
INSERT @S10EMap VALUES
(N'KVK.SeasonSource',OBJECT_ID(N'KVK.SeasonSource',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SeasonSource')),
(N'KVK.SourceRouting',OBJECT_ID(N'KVK.SourceRouting',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourceRouting')),
(N'KVK.SourceDelivery',OBJECT_ID(N'KVK.SourceDelivery',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourceDelivery')),
(N'KVK.SourcePublication',OBJECT_ID(N'KVK.SourcePublication',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourcePublication')),
(N'dbo.ExportJob',OBJECT_ID(N'dbo.ExportJob',N'U'),OBJECT_ID(N'tempdb..#S10E_dbo_ExportJob')),
(N'dbo.ExportResource',OBJECT_ID(N'dbo.ExportResource',N'U'),OBJECT_ID(N'tempdb..#S10E_dbo_ExportResource')),
(N'dbo.ExportJobResource',OBJECT_ID(N'dbo.ExportJobResource',N'U'),OBJECT_ID(N'tempdb..#S10E_dbo_ExportJobResource')),
(N'dbo.ExportRequestBudget',OBJECT_ID(N'dbo.ExportRequestBudget',N'U'),OBJECT_ID(N'tempdb..#S10E_dbo_ExportRequestBudget')),
(N'dbo.ExportAttempt',OBJECT_ID(N'dbo.ExportAttempt',N'U'),OBJECT_ID(N'tempdb..#S10E_dbo_ExportAttempt')),
(N'dbo.ExportAttemptPart',OBJECT_ID(N'dbo.ExportAttemptPart',N'U'),OBJECT_ID(N'tempdb..#S10E_dbo_ExportAttemptPart')),
(N'dbo.ExportPreparation',OBJECT_ID(N'dbo.ExportPreparation',N'U'),OBJECT_ID(N'tempdb..#S10E_dbo_ExportPreparation')),
(N'dbo.ExportPreparationResource',OBJECT_ID(N'dbo.ExportPreparationResource',N'U'),OBJECT_ID(N'tempdb..#S10E_dbo_ExportPreparationResource'));
DECLARE @S10EFK TABLE (ParentName sysname, ConstraintName sysname, Ordinal int, ParentColumn sysname, TargetName nvarchar(256), TargetColumn sysname);
INSERT @S10EFK VALUES
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
ALTER TABLE #S10E_dbo_ExportAttempt ADD UNIQUE (AttemptID, JobID, Epoch);
ALTER TABLE #S10E_dbo_ExportAttemptPart ADD UNIQUE (AttemptID, PartNo, FileID);
INSERT @S10EMap VALUES
(N'KVK.SourceOutputFile',OBJECT_ID(N'KVK.SourceOutputFile',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourceOutputFile')),
(N'KVK.SourceOutputPool',OBJECT_ID(N'KVK.SourceOutputPool',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourceOutputPool')),
(N'KVK.SourceOutputSlot',OBJECT_ID(N'KVK.SourceOutputSlot',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourceOutputSlot')),
(N'KVK.SourceOutputDisposition',OBJECT_ID(N'KVK.SourceOutputDisposition',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourceOutputDisposition'));
DECLARE @S10EPass int=0;
WHILE @S10EPass<2
BEGIN
IF (@S10EExisting=2 AND @S10EPass=0) OR (@S10EExisting=0 AND @S10EPass=1)
BEGIN
-- Expected post-amendment ExportResource shape, including append-only column order.
DECLARE @DropExpectedCheck nvarchar(1000)=(SELECT N'ALTER TABLE #S10E_dbo_ExportResource DROP CONSTRAINT '+QUOTENAME(name) FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#S10E_dbo_ExportResource') AND definition LIKE '%ActiveJobID%');
IF @DropExpectedCheck IS NULL THROW 51600, 'S10E authored ownership check missing.', 1;
EXEC sys.sp_executesql @DropExpectedCheck;
ALTER TABLE #S10E_dbo_ExportResource ADD ActiveOutputOperationID uniqueidentifier NULL;
ALTER TABLE #S10E_dbo_ExportResource ADD CHECK ((ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL AND Fence >= 0) OR (ActiveJobID IS NOT NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NOT NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NOT NULL AND OwnerID IS NOT NULL AND Fence > 0));
CREATE INDEX IX_ExportResource_ActiveOutputOperation ON #S10E_dbo_ExportResource (ActiveOutputOperationID) WHERE ActiveOutputOperationID IS NOT NULL;
INSERT @S10EMap VALUES
(N'KVK.SourceOutputOperation',OBJECT_ID(N'KVK.SourceOutputOperation',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourceOutputOperation')),
(N'KVK.SourceOutputOperationResource',OBJECT_ID(N'KVK.SourceOutputOperationResource',N'U'),OBJECT_ID(N'tempdb..#S10E_KVK_SourceOutputOperationResource'));
INSERT @S10EFK VALUES
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_Pool',1,N'PoolID',N'KVK.SourceOutputPool',N'PoolID'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_Pool',2,N'AccountKey',N'KVK.SourceOutputPool',N'AccountKey'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_OldChoice',1,N'OldKVK',N'KVK.SeasonSource',N'KVK_NO'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_OldChoice',2,N'SourceKey',N'KVK.SeasonSource',N'SourceKey'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_OldChoice',3,N'OldChoiceID',N'KVK.SeasonSource',N'ChoiceID'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_NewChoice',1,N'NewKVK',N'KVK.SeasonSource',N'KVK_NO'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_NewChoice',2,N'SourceKey',N'KVK.SeasonSource',N'SourceKey'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_NewChoice',3,N'NewChoiceID',N'KVK.SeasonSource',N'ChoiceID'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_CurrentFile',1,N'OperationID',N'KVK.SourceOutputOperationResource',N'OperationID'),
(N'KVK.SourceOutputOperation',N'FK_SourceOutputOperation_CurrentFile',2,N'CurrentFileID',N'KVK.SourceOutputOperationResource',N'FileID'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_Operation',1,N'OperationID',N'KVK.SourceOutputOperation',N'OperationID'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_Operation',2,N'PoolID',N'KVK.SourceOutputOperation',N'PoolID'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_Operation',3,N'AccountKey',N'KVK.SourceOutputOperation',N'AccountKey'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_Resource',1,N'ResourceKey',N'dbo.ExportResource',N'ResourceKey'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_File',1,N'FileID',N'KVK.SourceOutputFile',N'FileID'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_File',2,N'ResourceKey',N'KVK.SourceOutputFile',N'ResourceKey'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_Index',1,N'PoolID',N'KVK.SourceOutputPool',N'PoolID'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_Index',2,N'IndexFileID',N'KVK.SourceOutputPool',N'IndexFileID'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_Slot',1,N'PoolID',N'KVK.SourceOutputSlot',N'PoolID'),
(N'KVK.SourceOutputOperationResource',N'FK_SourceOutputOperationResource_Slot',2,N'SlotFileID',N'KVK.SourceOutputSlot',N'FileID'),
(N'dbo.ExportResource',N'FK_ExportResource_OutputOperationMembership',1,N'ActiveOutputOperationID',N'KVK.SourceOutputOperationResource',N'OperationID'),
(N'dbo.ExportResource',N'FK_ExportResource_OutputOperationMembership',2,N'ResourceKey',N'KVK.SourceOutputOperationResource',N'ResourceKey');
END;
IF EXISTS (SELECT 1 FROM @S10EMap WHERE ActualID IS NULL)
    THROW 51600, 'S10E prerequisite/object type conflict; no predecessor execution authorized.', 1;
-- EXCEPT in both directions rejects missing, extra, disabled, untrusted or altered shape.
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10EMap m JOIN sys.columns c ON c.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10EMap m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10EMap m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10EMap m JOIN sys.columns c ON c.object_id=m.ActualID)
    THROW 51600, 'S10E column shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S10EMap m JOIN sys.columns c ON c.object_id=m.ActualID WHERE c.user_type_id<>c.system_type_id) THROW 51600, 'S10E alias type conflict.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10EMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10EMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10EMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10EMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID)
    THROW 51600, 'S10E check constraint shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10EMap m JOIN sys.indexes i ON i.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10EMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10EMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10EMap m JOIN sys.indexes i ON i.object_id=m.ActualID)
    THROW 51600, 'S10E index shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10EMap m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10EMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10EMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10EMap m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name)
    THROW 51600, 'S10E index count shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S10EMap m JOIN sys.triggers t ON t.parent_id=m.ActualID)
OR EXISTS (SELECT 1 FROM @S10EMap m JOIN sys.tables t ON t.object_id=m.ActualID WHERE t.temporal_type<>0 OR t.is_memory_optimized<>0)
    THROW 51600, 'S10E unexpected default, trigger or table mode.', 1;
-- Defaults are part of the inherited contract (SourceRouting has Enabled=0).
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S10EMap m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S10EMap m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S10EMap m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S10EMap m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID)
    THROW 51600, 'S10E default shape conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10EMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10EMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10EMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10EMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name)
    THROW 51600, 'S10E check count conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S10EMap m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
EXCEPT
SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S10EFK e WHERE EXISTS (SELECT 1 FROM @S10EMap m WHERE m.Name=e.ParentName))
OR EXISTS (SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S10EFK e WHERE EXISTS (SELECT 1 FROM @S10EMap m WHERE m.Name=e.ParentName)
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S10EMap m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id)
    THROW 51600, 'S10E foreign key shape conflict; preserve history and forward-fix.', 1;
IF @S10EExisting=0 AND @S10EPass=0
BEGIN
-- S10E_INSTALL_PAYLOAD_BEGIN
EXEC sys.sp_executesql N'CREATE TABLE KVK.SourceOutputOperation
(
    OperationID uniqueidentifier NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OldKVK int NOT NULL,
    OldChoiceID uniqueidentifier NOT NULL,
    NewKVK int NOT NULL,
    NewChoiceID uniqueidentifier NOT NULL,
    OldEpoch bigint NOT NULL,
    TargetEpoch bigint NOT NULL,
    PlanHash binary(32) NOT NULL,
    PlanJson nvarchar(max) NOT NULL,
    ConfirmedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    GuildID varchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChannelID varchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    ConfirmedUTC datetime2(0) NOT NULL,
    EnqueueSequence bigint NOT NULL,
    State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActivePoolID uniqueidentifier NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Version bigint NOT NULL,
    Phase varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CurrentFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    ProgressJson nvarchar(max) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceOutputOperation PRIMARY KEY (OperationID),
    CONSTRAINT UQ_SourceOutputOperation_Scope UNIQUE (OperationID, PoolID, AccountKey),
    CONSTRAINT CK_SourceOutputOperation_Source CHECK (SourceKey = ''snapshot_report_v1'' AND DATALENGTH(SourceKey) = 18 AND OldKVK > 0 AND NewKVK > 0 AND OldKVK <> NewKVK),
    CONSTRAINT CK_SourceOutputOperation_Epoch CHECK (OldEpoch > 0 AND TargetEpoch > OldEpoch AND TargetEpoch - OldEpoch = 1),
    CONSTRAINT CK_SourceOutputOperation_State CHECK (State IN (''closing'',''ready'',''running'',''blocked'',''uncertain'',''completed'') AND DATALENGTH(State) = LEN(State)),
    CONSTRAINT CK_SourceOutputOperation_Active CHECK ((State = ''completed'' AND ActivePoolID IS NULL) OR (State <> ''completed'' AND ActivePoolID IS NOT NULL AND ActivePoolID = PoolID)),
    CONSTRAINT CK_SourceOutputOperation_Owner CHECK ((OwnerID IS NULL AND Fence >= 0 AND State IN (''closing'',''ready'',''blocked'',''completed'')) OR (OwnerID IS NOT NULL AND Fence > 0 AND State IN (''running'',''blocked'',''uncertain''))),
    CONSTRAINT CK_SourceOutputOperation_Counters CHECK (EnqueueSequence > 0 AND Version > 0 AND UpdatedUTC >= ConfirmedUTC),
    CONSTRAINT CK_SourceOutputOperation_Actor CHECK (LEN(ConfirmedBy) > 0 AND DATALENGTH(ConfirmedBy) = DATALENGTH(LTRIM(RTRIM(ConfirmedBy))) AND LEN(Reason) > 0 AND LEN(GuildID) > 0 AND GuildID NOT LIKE ''%[^0-9]%'' COLLATE Latin1_General_100_BIN2 AND LEN(ChannelID) > 0 AND ChannelID NOT LIKE ''%[^0-9]%'' COLLATE Latin1_General_100_BIN2),
    CONSTRAINT CK_SourceOutputOperation_Phase CHECK (Phase IN (''draining'',''ready'',''private_pending'',''private_verified'',''clear_pending'',''clear_verified'',''setup_pending'',''setup_verified'',''complete'',''uncertain'') AND DATALENGTH(Phase) = LEN(Phase)),
    CONSTRAINT CK_SourceOutputOperation_FilePhase CHECK ((Phase IN (''private_pending'',''private_verified'',''clear_pending'',''clear_verified'',''setup_pending'',''setup_verified'') AND CurrentFileID IS NOT NULL) OR (Phase IN (''draining'',''ready'',''complete'',''uncertain''))),
    CONSTRAINT CK_SourceOutputOperation_Plan CHECK (ISJSON(PlanJson) = 1 AND DATALENGTH(PlanJson) <= 65536),
    CONSTRAINT CK_SourceOutputOperation_Progress CHECK (ISJSON(ProgressJson) = 1 AND DATALENGTH(ProgressJson) <= 65536)
);
CREATE UNIQUE INDEX UX_SourceOutputOperation_ActivePool ON KVK.SourceOutputOperation (ActivePoolID) WHERE ActivePoolID IS NOT NULL;
CREATE INDEX IX_SourceOutputOperation_Queue ON KVK.SourceOutputOperation (AccountKey, State, EnqueueSequence, OperationID);
CREATE TABLE KVK.SourceOutputOperationResource
(
    OperationID uniqueidentifier NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    IndexFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    SlotFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    CONSTRAINT PK_SourceOutputOperationResource PRIMARY KEY (OperationID, ResourceKey),
    CONSTRAINT UQ_SourceOutputOperationResource_File UNIQUE (OperationID, FileID),
    CONSTRAINT CK_SourceOutputOperationResource_Scope CHECK ((ResourceKind = ''account'' AND DATALENGTH(ResourceKind) = 7 AND ResourceKey = ''account:'' + AccountKey AND DATALENGTH(ResourceKey) = 8 + DATALENGTH(AccountKey) AND FileID IS NULL AND IndexFileID IS NULL AND SlotFileID IS NULL) OR (ResourceKind = ''destination'' AND DATALENGTH(ResourceKind) = 11 AND FileID IS NOT NULL AND ResourceKey = ''destination:'' + CONVERT(varchar(128),FileID) AND DATALENGTH(ResourceKey) = 12 + DATALENGTH(FileID) / 2 AND ((IndexFileID IS NOT NULL AND IndexFileID = FileID AND SlotFileID IS NULL) OR (SlotFileID IS NOT NULL AND SlotFileID = FileID AND IndexFileID IS NULL))))
);
ALTER TABLE dbo.ExportResource ADD ActiveOutputOperationID uniqueidentifier NULL;
ALTER TABLE dbo.ExportResource DROP CONSTRAINT CK_ExportResource_Ownership;
ALTER TABLE dbo.ExportResource WITH CHECK ADD CONSTRAINT CK_ExportResource_Ownership CHECK ((ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL AND Fence >= 0) OR (ActiveJobID IS NOT NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NOT NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NOT NULL AND OwnerID IS NOT NULL AND Fence > 0));
CREATE INDEX IX_ExportResource_ActiveOutputOperation ON dbo.ExportResource (ActiveOutputOperationID) WHERE ActiveOutputOperationID IS NOT NULL;
ALTER TABLE dbo.ExportResource WITH CHECK ADD CONSTRAINT FK_ExportResource_OutputOperationMembership FOREIGN KEY (ActiveOutputOperationID, ResourceKey) REFERENCES KVK.SourceOutputOperationResource (OperationID, ResourceKey);
ALTER TABLE KVK.SourceOutputOperation WITH CHECK ADD CONSTRAINT FK_SourceOutputOperation_Pool FOREIGN KEY (PoolID, AccountKey) REFERENCES KVK.SourceOutputPool (PoolID, AccountKey);
ALTER TABLE KVK.SourceOutputOperation WITH CHECK ADD CONSTRAINT FK_SourceOutputOperation_OldChoice FOREIGN KEY (OldKVK, SourceKey, OldChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID);
ALTER TABLE KVK.SourceOutputOperation WITH CHECK ADD CONSTRAINT FK_SourceOutputOperation_NewChoice FOREIGN KEY (NewKVK, SourceKey, NewChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID);
ALTER TABLE KVK.SourceOutputOperation WITH CHECK ADD CONSTRAINT FK_SourceOutputOperation_CurrentFile FOREIGN KEY (OperationID, CurrentFileID) REFERENCES KVK.SourceOutputOperationResource (OperationID, FileID);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_Operation FOREIGN KEY (OperationID, PoolID, AccountKey) REFERENCES KVK.SourceOutputOperation (OperationID, PoolID, AccountKey);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_Resource FOREIGN KEY (ResourceKey) REFERENCES dbo.ExportResource (ResourceKey);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_File FOREIGN KEY (FileID, ResourceKey) REFERENCES KVK.SourceOutputFile (FileID, ResourceKey);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_Index FOREIGN KEY (PoolID, IndexFileID) REFERENCES KVK.SourceOutputPool (PoolID, IndexFileID);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_Slot FOREIGN KEY (PoolID, SlotFileID) REFERENCES KVK.SourceOutputSlot (PoolID, FileID);
';
-- S10E_INSTALL_PAYLOAD_END
END;
SET @S10EPass+=1;
END;
DROP TABLE #S10E_KVK_SeasonSource;
DROP TABLE #S10E_KVK_SourceRouting;
DROP TABLE #S10E_KVK_SourceDelivery;
DROP TABLE #S10E_KVK_SourcePublication;
DROP TABLE #S10E_dbo_ExportJob;
DROP TABLE #S10E_dbo_ExportResource;
DROP TABLE #S10E_dbo_ExportJobResource;
DROP TABLE #S10E_dbo_ExportRequestBudget;
DROP TABLE #S10E_dbo_ExportAttempt;
DROP TABLE #S10E_dbo_ExportAttemptPart;
DROP TABLE #S10E_dbo_ExportPreparation;
DROP TABLE #S10E_dbo_ExportPreparationResource;
DROP TABLE #S10E_KVK_SourceOutputFile;
DROP TABLE #S10E_KVK_SourceOutputPool;
DROP TABLE #S10E_KVK_SourceOutputSlot;
DROP TABLE #S10E_KVK_SourceOutputDisposition;
DROP TABLE #S10E_KVK_SourceOutputOperation;
DROP TABLE #S10E_KVK_SourceOutputOperationResource;
IF @S10EOwnTransaction=1 COMMIT;
END TRY
BEGIN CATCH
IF @S10EOwnTransaction=1 AND XACT_STATE()<>0 ROLLBACK;
THROW;
END CATCH;
