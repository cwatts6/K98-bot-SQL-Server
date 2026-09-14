/*
MigrationId: 20260914_001_shared_export_coordination
Purpose: Add shared export job ownership budgets and normalized attempt evidence
Author: cwatts
CreatedUtc: 2026-09-14
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Verify S8A intent and publication receipt prerequisites and absent or exact S10A schema
PostValidationQuery: Verify six S10A table shapes and trusted foreign keys
RelatedBotPR:
RelatedSQLPR:
*/
-- Local authoring only. SQL execution, deployment and activation require separate approval.
-- Schema-only: no backfill, budget seed, receipt import, grant or existing-history mutation.
-- Requires an approved backup/restore plan before execution. Schema locks are held only
-- during this short installation. Disable admission and forward-fix on rollback; retain
-- all jobs, attempts, receipts, resources and fences. Never drop populated export tables.
-- Deploy after S8A/S8B prerequisites, before S10B/C coordinated writers. Old writers
-- bypassing admission must be excluded before activation; this script activates nothing.
-- Own the transaction in a direct session; participate in a caller transaction otherwise.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @S10AOwnTransaction bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
IF @S10AOwnTransaction = 1 BEGIN TRANSACTION;
BEGIN TRY
DECLARE @S10ALockResult int;
EXEC @S10ALockResult = sys.sp_getapplock @Resource = N'K98:S10A:schema',
    @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 0;
IF @S10ALockResult < 0 THROW 51000, 'S10A schema installation is already running.', 1;
IF OBJECT_ID(N'KVK.SourceExportIntent',N'U') IS NULL
   OR OBJECT_ID(N'KVK.SourceExportIntentPublication',N'U') IS NULL
   OR OBJECT_ID(N'KVK.SourceCompleteSelection',N'U') IS NULL
   OR OBJECT_ID(N'KVK.SourceUpdate',N'U') IS NULL
   OR COL_LENGTH(N'KVK.SourceUpdate',N'PeriodKind') IS NULL
   OR OBJECT_ID(N'KVK.SourceDelivery',N'U') IS NULL
   OR OBJECT_ID(N'KVK.SourcePublication',N'U') IS NULL
    THROW 51000, 'S10A requires the reviewed S8A/S8B intent, selection and receipt schema.', 1;
IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID(N'dbo') AND name IN ('ExportJob','ExportResource','ExportJobResource','ExportRequestBudget','ExportAttempt','ExportAttemptPart') AND type <> 'U')
    THROW 51000, 'S10A object type conflict; preserve the existing object and review a forward correction.', 1;
DECLARE @S10AExisting int = (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'dbo') AND name IN (N'ExportJob',N'ExportResource',N'ExportJobResource',N'ExportRequestBudget',N'ExportAttempt',N'ExportAttemptPart'));
IF @S10AExisting NOT IN (0,6) THROW 51000, 'Partial S10A installation: preserve state and review a forward correction.', 1;
IF @S10AExisting = 0
BEGIN
CREATE TABLE dbo.ExportJob
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
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_ExportJob PRIMARY KEY (JobID),
    CONSTRAINT UQ_ExportJob_Replay UNIQUE (ConsumerKind, AccountKey, KVK_NO, InputHash, DestinationSetHash, PoolEpoch, RepairID),
    CONSTRAINT UQ_ExportJob_Consumer UNIQUE (JobID, ConsumerKind),
    CONSTRAINT UQ_ExportJob_Epoch UNIQUE (JobID, PoolEpoch),
    CONSTRAINT UQ_ExportJob_Season UNIQUE (JobID, KVK_NO),
    CONSTRAINT UQ_ExportJob_SupersessionScope UNIQUE (JobID, ConsumerKind, AccountKey, KVK_NO, DestinationSetHash, PoolEpoch),
    CONSTRAINT CK_ExportJob_Consumer CHECK (DATALENGTH(ConsumerKind) = LEN(ConsumerKind) AND ConsumerKind IN ('new_source','all_kvk','scan_data')),
    CONSTRAINT CK_ExportJob_Scope CHECK ((ConsumerKind = 'new_source' AND SourceKey IS NOT NULL AND SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND IntentID IS NOT NULL AND KVK_NO IS NOT NULL AND KVK_NO > 0 AND PoolEpoch IS NOT NULL AND PoolEpoch > 0) OR (ConsumerKind = 'all_kvk' AND SourceKey IS NULL AND IntentID IS NULL AND KVK_NO IS NOT NULL AND KVK_NO > 0 AND PoolEpoch IS NULL) OR (ConsumerKind = 'scan_data' AND SourceKey IS NULL AND IntentID IS NULL AND KVK_NO IS NULL AND PoolEpoch IS NULL)),
    CONSTRAINT CK_ExportJob_Identity CHECK (LEN(AccountKey) > 0 AND DATALENGTH(AccountKey) = DATALENGTH(LTRIM(RTRIM(AccountKey))) AND LEN(Actor) > 0 AND DATALENGTH(Actor) = DATALENGTH(LTRIM(RTRIM(Actor))) AND LEN(Reason) > 0),
    CONSTRAINT CK_ExportJob_Spool CHECK (((SpoolKey IS NULL AND SpoolBytes IS NULL AND StorageOwner IS NULL AND ConsumerKind = 'new_source') OR (SpoolKey IS NOT NULL AND SpoolBytes IS NOT NULL AND StorageOwner IS NOT NULL AND SpoolBytes > 0 AND LEN(SpoolKey) > 0 AND DATALENGTH(SpoolKey) = DATALENGTH(LTRIM(RTRIM(SpoolKey))) AND LEN(StorageOwner) > 0 AND DATALENGTH(StorageOwner) = DATALENGTH(LTRIM(RTRIM(StorageOwner))) AND SpoolKey NOT LIKE '%[^a-zA-Z0-9_-]%' COLLATE Latin1_General_100_BIN2))),
    CONSTRAINT CK_ExportJob_State CHECK (DATALENGTH(State) = LEN(State) AND State IN ('waiting','ready','running','confirmed','failed','uncertain','coalesced','cancelled')),
    CONSTRAINT CK_ExportJob_Ownership CHECK (Fence >= 0 AND ((OwnerID IS NULL AND Fence = 0 AND State IN ('waiting','ready','coalesced','cancelled')) OR (OwnerID IS NOT NULL AND Fence > 0 AND State IN ('running','confirmed','failed','uncertain')))),
    CONSTRAINT CK_ExportJob_Supersession CHECK ((State = 'coalesced' AND ConsumerKind = 'new_source' AND SupersededByJobID IS NOT NULL AND SupersededByJobID <> JobID) OR (State <> 'coalesced' AND SupersededByJobID IS NULL)),
    CONSTRAINT CK_ExportJob_Counters CHECK (EnqueueSequence > 0 AND Version > 0),
    CONSTRAINT CK_ExportJob_Time CHECK (UpdatedUTC >= CreatedUTC),
    CONSTRAINT CK_ExportJob_Provenance CHECK (ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);
CREATE INDEX IX_ExportJob_Queue ON dbo.ExportJob (AccountKey, State, EnqueueSequence, JobID);
CREATE INDEX IX_ExportJob_Intent ON dbo.ExportJob (IntentID) WHERE IntentID IS NOT NULL;
CREATE INDEX IX_ExportJob_Superseded ON dbo.ExportJob (SupersededByJobID) WHERE SupersededByJobID IS NOT NULL;

CREATE TABLE dbo.ExportResource
(
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActiveJobID uniqueidentifier NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    BlockedReason nvarchar(1024) NULL,
    Version bigint NOT NULL,
    CONSTRAINT PK_ExportResource PRIMARY KEY (ResourceKey),
    CONSTRAINT CK_ExportResource_Key CHECK (LEN(ResourceKey) > 0 AND DATALENGTH(ResourceKey) = DATALENGTH(LTRIM(RTRIM(ResourceKey)))),
    CONSTRAINT CK_ExportResource_Kind CHECK (DATALENGTH(ResourceKind) = LEN(ResourceKind) AND ResourceKind IN ('account','destination','sql_snapshot')),
    CONSTRAINT CK_ExportResource_Ownership CHECK ((ActiveJobID IS NULL AND OwnerID IS NULL AND Fence >= 0) OR (ActiveJobID IS NOT NULL AND OwnerID IS NOT NULL AND Fence > 0)),
    CONSTRAINT CK_ExportResource_Blocked CHECK (BlockedReason IS NULL OR LEN(BlockedReason) > 0),
    CONSTRAINT CK_ExportResource_Version CHECK (Version > 0)
);
CREATE INDEX IX_ExportResource_ActiveJob ON dbo.ExportResource (ActiveJobID) WHERE ActiveJobID IS NOT NULL;

CREATE TABLE dbo.ExportJobResource
(
    JobID uniqueidentifier NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CONSTRAINT PK_ExportJobResource PRIMARY KEY (JobID, ResourceKey)
);
CREATE INDEX IX_ExportJobResource_Resource ON dbo.ExportJobResource (ResourceKey, JobID);

CREATE TABLE dbo.ExportRequestBudget
(
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BudgetKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    NextAllowedUTC datetime2(3) NOT NULL,
    CooldownUntilUTC datetime2(3) NULL,
    IntervalMilliseconds int NOT NULL,
    PolicyVersion bigint NOT NULL,
    Version bigint NOT NULL,
    CONSTRAINT PK_ExportRequestBudget PRIMARY KEY (AccountKey, BudgetKind),
    CONSTRAINT CK_ExportRequestBudget_Account CHECK (LEN(AccountKey) > 0 AND DATALENGTH(AccountKey) = DATALENGTH(LTRIM(RTRIM(AccountKey)))),
    CONSTRAINT CK_ExportRequestBudget_Kind CHECK (BudgetKind = 'google_request' AND DATALENGTH(BudgetKind) = 14),
    CONSTRAINT CK_ExportRequestBudget_Policy CHECK (IntervalMilliseconds BETWEEN 1 AND 86400000 AND PolicyVersion > 0 AND Version > 0)
);


CREATE TABLE dbo.ExportAttempt
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
    ManifestJson nvarchar(max) NOT NULL,
    ReceiptJson nvarchar(max) NULL,
    PartCount int NOT NULL,
    LegacyPublicationID uniqueidentifier NULL,
    LegacySourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LegacyKVK_NO int NULL,
    LegacyPeriodID uniqueidentifier NULL,
    LegacyDestinationKind varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LegacyDestinationID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    CONSTRAINT PK_ExportAttempt PRIMARY KEY (AttemptID),
    CONSTRAINT UQ_ExportAttempt_Sequence UNIQUE (JobID, AttemptNo),
    CONSTRAINT UQ_ExportAttempt_PartCount UNIQUE (AttemptID, PartCount),
    CONSTRAINT CK_ExportAttempt_Consumer CHECK (DATALENGTH(ConsumerKind) = LEN(ConsumerKind) AND ConsumerKind IN ('new_source','all_kvk','scan_data')),
    CONSTRAINT CK_ExportAttempt_Epoch CHECK ((ConsumerKind = 'new_source' AND Epoch IS NOT NULL AND Epoch > 0) OR (ConsumerKind IN ('all_kvk','scan_data') AND Epoch IS NULL)),
    CONSTRAINT CK_ExportAttempt_Phase CHECK (DATALENGTH(Phase) = LEN(Phase) AND Phase IN ('private_started','verified','publication_pending','published','failed','uncertain','retired')),
    CONSTRAINT CK_ExportAttempt_Counters CHECK (AttemptNo > 0 AND Fence > 0 AND RemoteSequence > 0 AND Version > 0 AND PartCount BETWEEN 1 AND 1024),
    CONSTRAINT CK_ExportAttempt_Manifest CHECK (ISJSON(ManifestJson) = 1 AND DATALENGTH(ManifestJson) <= 65536),
    CONSTRAINT CK_ExportAttempt_Receipt CHECK (ReceiptJson IS NULL OR (ISJSON(ReceiptJson) = 1 AND DATALENGTH(ReceiptJson) <= 65536)),
    CONSTRAINT CK_ExportAttempt_Time CHECK (UpdatedUTC >= CreatedUTC AND (VerifiedUTC IS NULL OR VerifiedUTC BETWEEN CreatedUTC AND UpdatedUTC) AND (PublishedUTC IS NULL OR (VerifiedUTC IS NOT NULL AND PublishedUTC BETWEEN VerifiedUTC AND UpdatedUTC))),
    CONSTRAINT CK_ExportAttempt_Evidence CHECK ((Phase NOT IN ('verified','publication_pending','published','retired') OR VerifiedUTC IS NOT NULL) AND (Phase NOT IN ('published','retired') OR (PublishedUTC IS NOT NULL AND ReceiptJson IS NOT NULL)) AND (Phase <> 'private_started' OR (VerifiedUTC IS NULL AND PublishedUTC IS NULL))),
    CONSTRAINT CK_ExportAttempt_Legacy CHECK ((LegacyPublicationID IS NULL AND LegacySourceKey IS NULL AND LegacyKVK_NO IS NULL AND LegacyPeriodID IS NULL AND LegacyDestinationKind IS NULL AND LegacyDestinationID IS NULL) OR (ConsumerKind = 'new_source' AND LegacyPublicationID IS NOT NULL AND LegacySourceKey IS NOT NULL AND LegacySourceKey = 'snapshot_report_v1' AND DATALENGTH(LegacySourceKey) = 18 AND LegacyKVK_NO IS NOT NULL AND LegacyKVK_NO > 0 AND LegacyPeriodID IS NOT NULL AND LegacyDestinationKind IS NOT NULL AND DATALENGTH(LegacyDestinationKind) = LEN(LegacyDestinationKind) AND LegacyDestinationKind IN ('discord','sheets','file') AND LegacyDestinationID IS NOT NULL AND LEN(LegacyDestinationID) > 0 AND DATALENGTH(LegacyDestinationID) = DATALENGTH(LTRIM(RTRIM(LegacyDestinationID)))))
);
CREATE INDEX IX_ExportAttempt_Phase ON dbo.ExportAttempt (Phase, UpdatedUTC, JobID);

CREATE TABLE dbo.ExportAttemptPart
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
    QuarantineReason nvarchar(1024) NULL,
    EvidenceJson nvarchar(max) NULL,
    Version bigint NOT NULL,
    CONSTRAINT PK_ExportAttemptPart PRIMARY KEY (AttemptID, PartNo),
    CONSTRAINT UQ_ExportAttemptPart_File UNIQUE (AttemptID, FileID),
    CONSTRAINT CK_ExportAttemptPart_Number CHECK (PartCount BETWEEN 1 AND 1024 AND PartNo BETWEEN 1 AND PartCount),
    CONSTRAINT CK_ExportAttemptPart_File CHECK (LEN(FileID) > 0 AND DATALENGTH(FileID) = DATALENGTH(LTRIM(RTRIM(FileID)))),
    CONSTRAINT CK_ExportAttemptPart_Role CHECK (DATALENGTH([Role]) = LEN([Role]) AND [Role] IN ('index','generation','output')),
    CONSTRAINT CK_ExportAttemptPart_Counts CHECK (GridCount > 0 AND [RowCount] >= 0 AND CellCount > 0 AND CellCount >= [RowCount] AND Version > 0),
    CONSTRAINT CK_ExportAttemptPart_Verification CHECK (DATALENGTH(VerificationState) = LEN(VerificationState) AND VerificationState IN ('pending','verified','failed','uncertain') AND ((VerificationState = 'verified' AND VerifiedUTC IS NOT NULL) OR (VerificationState <> 'verified' AND VerifiedUTC IS NULL))),
    CONSTRAINT CK_ExportAttemptPart_Acl CHECK (DATALENGTH(AclState) = LEN(AclState) AND AclState IN ('pending','private','public_viewer','failed','uncertain') AND ((AclState = 'pending' AND AclCheckedUTC IS NULL) OR (AclState <> 'pending' AND AclCheckedUTC IS NOT NULL))),
    CONSTRAINT CK_ExportAttemptPart_Quarantine CHECK (DATALENGTH(QuarantineState) = LEN(QuarantineState) AND QuarantineState IN ('none','quarantined') AND ((QuarantineState = 'none' AND QuarantinedUTC IS NULL AND QuarantineReason IS NULL) OR (QuarantineState = 'quarantined' AND QuarantinedUTC IS NOT NULL AND QuarantineReason IS NOT NULL AND LEN(QuarantineReason) > 0))),
    CONSTRAINT CK_ExportAttemptPart_Evidence CHECK (EvidenceJson IS NULL OR (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536))
);


ALTER TABLE dbo.ExportJob WITH CHECK ADD CONSTRAINT FK_ExportJob_Intent FOREIGN KEY (SourceKey, KVK_NO, IntentID) REFERENCES KVK.SourceExportIntent (SourceKey, KVK_NO, IntentID);
ALTER TABLE dbo.ExportJob WITH CHECK ADD CONSTRAINT FK_ExportJob_Superseded FOREIGN KEY (SupersededByJobID, ConsumerKind, AccountKey, KVK_NO, DestinationSetHash, PoolEpoch) REFERENCES dbo.ExportJob (JobID, ConsumerKind, AccountKey, KVK_NO, DestinationSetHash, PoolEpoch);
ALTER TABLE dbo.ExportJobResource WITH CHECK ADD CONSTRAINT FK_ExportJobResource_Job FOREIGN KEY (JobID) REFERENCES dbo.ExportJob (JobID);
ALTER TABLE dbo.ExportJobResource WITH CHECK ADD CONSTRAINT FK_ExportJobResource_Resource FOREIGN KEY (ResourceKey) REFERENCES dbo.ExportResource (ResourceKey);
ALTER TABLE dbo.ExportResource WITH CHECK ADD CONSTRAINT FK_ExportResource_ActiveMembership FOREIGN KEY (ActiveJobID, ResourceKey) REFERENCES dbo.ExportJobResource (JobID, ResourceKey);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_Job FOREIGN KEY (JobID, ConsumerKind) REFERENCES dbo.ExportJob (JobID, ConsumerKind);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_Epoch FOREIGN KEY (JobID, Epoch) REFERENCES dbo.ExportJob (JobID, PoolEpoch);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_LegacyDelivery FOREIGN KEY (LegacyPublicationID, LegacyDestinationKind, LegacyDestinationID) REFERENCES KVK.SourceDelivery (PublicationID, DestinationKind, DestinationID);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_LegacyPublication FOREIGN KEY (LegacySourceKey, LegacyKVK_NO, LegacyPeriodID, LegacyPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_LegacySeason FOREIGN KEY (JobID, LegacyKVK_NO) REFERENCES dbo.ExportJob (JobID, KVK_NO);
ALTER TABLE dbo.ExportAttemptPart WITH CHECK ADD CONSTRAINT FK_ExportAttemptPart_Attempt FOREIGN KEY (AttemptID, PartCount) REFERENCES dbo.ExportAttempt (AttemptID, PartCount);
END;
-- Exact rerun verification; temporary empty shapes never copy application data.
-- Database-default text must model the application database, not tempdb collation.
CREATE TABLE #S10A_ExportJob
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
CREATE INDEX IX_ExportJob_Queue ON #S10A_ExportJob (AccountKey, State, EnqueueSequence, JobID);
CREATE INDEX IX_ExportJob_Intent ON #S10A_ExportJob (IntentID) WHERE IntentID IS NOT NULL;
CREATE INDEX IX_ExportJob_Superseded ON #S10A_ExportJob (SupersededByJobID) WHERE SupersededByJobID IS NOT NULL;
CREATE TABLE #S10A_ExportResource
(
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActiveJobID uniqueidentifier NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    BlockedReason nvarchar(1024) COLLATE DATABASE_DEFAULT NULL,
    Version bigint NOT NULL,
    PRIMARY KEY (ResourceKey),
    CHECK (LEN(ResourceKey) > 0 AND DATALENGTH(ResourceKey) = DATALENGTH(LTRIM(RTRIM(ResourceKey)))),
    CHECK (DATALENGTH(ResourceKind) = LEN(ResourceKind) AND ResourceKind IN ('account','destination','sql_snapshot')),
    CHECK ((ActiveJobID IS NULL AND OwnerID IS NULL AND Fence >= 0) OR (ActiveJobID IS NOT NULL AND OwnerID IS NOT NULL AND Fence > 0)),
    CHECK (BlockedReason IS NULL OR LEN(BlockedReason) > 0),
    CHECK (Version > 0)
);
CREATE INDEX IX_ExportResource_ActiveJob ON #S10A_ExportResource (ActiveJobID) WHERE ActiveJobID IS NOT NULL;
CREATE TABLE #S10A_ExportJobResource
(
    JobID uniqueidentifier NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PRIMARY KEY (JobID, ResourceKey)
);
CREATE INDEX IX_ExportJobResource_Resource ON #S10A_ExportJobResource (ResourceKey, JobID);
CREATE TABLE #S10A_ExportRequestBudget
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

CREATE TABLE #S10A_ExportAttempt
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
CREATE INDEX IX_ExportAttempt_Phase ON #S10A_ExportAttempt (Phase, UpdatedUTC, JobID);
CREATE TABLE #S10A_ExportAttemptPart
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

DECLARE @S10AMap TABLE (Name sysname NOT NULL, ActualID int NULL, ExpectedID int NOT NULL);
INSERT @S10AMap VALUES
(N'ExportJob',OBJECT_ID(N'dbo.ExportJob',N'U'),OBJECT_ID(N'tempdb..#S10A_ExportJob')),
(N'ExportResource',OBJECT_ID(N'dbo.ExportResource',N'U'),OBJECT_ID(N'tempdb..#S10A_ExportResource')),
(N'ExportJobResource',OBJECT_ID(N'dbo.ExportJobResource',N'U'),OBJECT_ID(N'tempdb..#S10A_ExportJobResource')),
(N'ExportRequestBudget',OBJECT_ID(N'dbo.ExportRequestBudget',N'U'),OBJECT_ID(N'tempdb..#S10A_ExportRequestBudget')),
(N'ExportAttempt',OBJECT_ID(N'dbo.ExportAttempt',N'U'),OBJECT_ID(N'tempdb..#S10A_ExportAttempt')),
(N'ExportAttemptPart',OBJECT_ID(N'dbo.ExportAttemptPart',N'U'),OBJECT_ID(N'tempdb..#S10A_ExportAttemptPart'));
IF EXISTS (SELECT 1 FROM @S10AMap WHERE ActualID IS NULL)
    THROW 51000, 'S10A object type conflict.', 1;
-- EXCEPT in both directions rejects missing, extra, disabled, untrusted or altered shape.
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10AMap m JOIN sys.columns c ON c.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10AMap m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10AMap m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S10AMap m JOIN sys.columns c ON c.object_id=m.ActualID)
    THROW 51000, 'S10A column shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S10AMap m JOIN sys.columns c ON c.object_id=m.ActualID WHERE c.user_type_id<>c.system_type_id) THROW 51000, 'S10A alias type conflict.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10AMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10AMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10AMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S10AMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID)
    THROW 51000, 'S10A check constraint shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10AMap m JOIN sys.indexes i ON i.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10AMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10AMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S10AMap m JOIN sys.indexes i ON i.object_id=m.ActualID)
    THROW 51000, 'S10A index shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10AMap m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10AMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10AMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S10AMap m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name)
    THROW 51000, 'S10A index count shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S10AMap m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID)
OR EXISTS (SELECT 1 FROM @S10AMap m JOIN sys.triggers t ON t.parent_id=m.ActualID)
OR EXISTS (SELECT 1 FROM @S10AMap m JOIN sys.tables t ON t.object_id=m.ActualID WHERE t.temporal_type<>0 OR t.is_memory_optimized<>0)
    THROW 51000, 'S10A unexpected default, trigger or table mode.', 1;
DECLARE @S10AFK TABLE (ParentName sysname, ConstraintName sysname, Ordinal int, ParentColumn sysname, TargetName nvarchar(256), TargetColumn sysname);
INSERT @S10AFK VALUES
(N'ExportJob',N'FK_ExportJob_Intent',1,N'SourceKey',N'KVK.SourceExportIntent',N'SourceKey'),
(N'ExportJob',N'FK_ExportJob_Intent',2,N'KVK_NO',N'KVK.SourceExportIntent',N'KVK_NO'),
(N'ExportJob',N'FK_ExportJob_Intent',3,N'IntentID',N'KVK.SourceExportIntent',N'IntentID'),
(N'ExportJob',N'FK_ExportJob_Superseded',1,N'SupersededByJobID',N'dbo.ExportJob',N'JobID'),
(N'ExportJob',N'FK_ExportJob_Superseded',2,N'ConsumerKind',N'dbo.ExportJob',N'ConsumerKind'),
(N'ExportJob',N'FK_ExportJob_Superseded',3,N'AccountKey',N'dbo.ExportJob',N'AccountKey'),
(N'ExportJob',N'FK_ExportJob_Superseded',4,N'KVK_NO',N'dbo.ExportJob',N'KVK_NO'),
(N'ExportJob',N'FK_ExportJob_Superseded',5,N'DestinationSetHash',N'dbo.ExportJob',N'DestinationSetHash'),
(N'ExportJob',N'FK_ExportJob_Superseded',6,N'PoolEpoch',N'dbo.ExportJob',N'PoolEpoch'),
(N'ExportJobResource',N'FK_ExportJobResource_Job',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'ExportJobResource',N'FK_ExportJobResource_Resource',1,N'ResourceKey',N'dbo.ExportResource',N'ResourceKey'),
(N'ExportResource',N'FK_ExportResource_ActiveMembership',1,N'ActiveJobID',N'dbo.ExportJobResource',N'JobID'),
(N'ExportResource',N'FK_ExportResource_ActiveMembership',2,N'ResourceKey',N'dbo.ExportJobResource',N'ResourceKey'),
(N'ExportAttempt',N'FK_ExportAttempt_Job',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'ExportAttempt',N'FK_ExportAttempt_Job',2,N'ConsumerKind',N'dbo.ExportJob',N'ConsumerKind'),
(N'ExportAttempt',N'FK_ExportAttempt_Epoch',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'ExportAttempt',N'FK_ExportAttempt_Epoch',2,N'Epoch',N'dbo.ExportJob',N'PoolEpoch'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacyDelivery',1,N'LegacyPublicationID',N'KVK.SourceDelivery',N'PublicationID'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacyDelivery',2,N'LegacyDestinationKind',N'KVK.SourceDelivery',N'DestinationKind'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacyDelivery',3,N'LegacyDestinationID',N'KVK.SourceDelivery',N'DestinationID'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacyPublication',1,N'LegacySourceKey',N'KVK.SourcePublication',N'SourceKey'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacyPublication',2,N'LegacyKVK_NO',N'KVK.SourcePublication',N'KVK_NO'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacyPublication',3,N'LegacyPeriodID',N'KVK.SourcePublication',N'PeriodID'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacyPublication',4,N'LegacyPublicationID',N'KVK.SourcePublication',N'PublicationID'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacySeason',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'ExportAttempt',N'FK_ExportAttempt_LegacySeason',2,N'LegacyKVK_NO',N'dbo.ExportJob',N'KVK_NO'),
(N'ExportAttemptPart',N'FK_ExportAttemptPart_Attempt',1,N'AttemptID',N'dbo.ExportAttempt',N'AttemptID'),
(N'ExportAttemptPart',N'FK_ExportAttemptPart_Attempt',2,N'PartCount',N'dbo.ExportAttempt',N'PartCount');
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S10AMap m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
EXCEPT
SELECT ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S10AFK)
OR EXISTS (SELECT ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S10AFK
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S10AMap m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id)
    THROW 51000, 'S10A foreign key shape conflict; preserve history and forward-fix.', 1;
DROP TABLE #S10A_ExportAttemptPart;
DROP TABLE #S10A_ExportAttempt;
DROP TABLE #S10A_ExportRequestBudget;
DROP TABLE #S10A_ExportJobResource;
DROP TABLE #S10A_ExportResource;
DROP TABLE #S10A_ExportJob;
IF @S10AOwnTransaction = 1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @S10AOwnTransaction = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    -- With an ambient transaction, THROW returns failure to its owner; it must roll back.
    THROW;
END CATCH;
PRINT 'S10A schema verified; no existing application data or activation state changed.';
