/*
MigrationId: 20260924_001_export_execution_evidence
Purpose: Independent export execution evidence and narrowly privileged transition APIs
Author: cwatts
CreatedUtc: 2026-09-24
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact S10A/C/E ownership metadata and explicit backup/actual restore/lock plan
PostValidationQuery: Exact evidence metadata, procedures and effective principal permissions
RelatedBotPR:
RelatedSQLPR:
*/
-- AUTHORING ONLY: no invocation, installation or role membership is approved here.
-- Additive evidence. Never reconstruct historical certainty, rewrite receipts,
-- release claims or activate admission. Retain populated objects on rollback.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @S11OwnTransaction bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
IF @S11OwnTransaction=1 BEGIN TRANSACTION;
BEGIN TRY
DECLARE @S11LockResult int;
EXEC @S11LockResult=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @S11LockResult<0 THROW 51700,'S11 schema installation busy.',1;
DECLARE @S11Existing int=(SELECT COUNT(*) FROM sys.objects WHERE schema_id=SCHEMA_ID(N'dbo') AND name IN (N'ExportExecutionSession',N'ExportExecutionStream',N'ExportProviderRequest',N'ExportProviderRequestEvent',N'ExportReconciliationProof',N'ExportManagedFileOrigin',N'usp_ExportExecutionSessionTransition',N'usp_ExportExecutionStreamTransition',N'usp_ExportProviderRequestEventAppend',N'usp_ExportReconciliationProofIssue',N'usp_ExportOutputEnrollmentTransition'));
IF @S11Existing NOT IN (0,11) THROW 51700,'Partial S11 schema; preserve and forward-fix.',1;
CREATE TABLE #S11_dbo_ExportJob
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
CREATE INDEX IX_ExportJob_Queue ON #S11_dbo_ExportJob (AccountKey, State, EnqueueSequence, JobID);
CREATE INDEX IX_ExportJob_Intent ON #S11_dbo_ExportJob (IntentID) WHERE IntentID IS NOT NULL;
CREATE INDEX IX_ExportJob_Superseded ON #S11_dbo_ExportJob (SupersededByJobID) WHERE SupersededByJobID IS NOT NULL;
CREATE TABLE #S11_dbo_ExportResource
(
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActiveJobID uniqueidentifier NULL,
    ActivePreparationID uniqueidentifier NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    BlockedReason nvarchar(1024) COLLATE DATABASE_DEFAULT NULL,
    Version bigint NOT NULL,
    ActiveOutputOperationID uniqueidentifier NULL,
    PRIMARY KEY (ResourceKey),
    CHECK (LEN(ResourceKey) > 0 AND DATALENGTH(ResourceKey) = DATALENGTH(LTRIM(RTRIM(ResourceKey)))),
    CHECK (DATALENGTH(ResourceKind) = LEN(ResourceKind) AND ResourceKind IN ('account','destination','sql_snapshot')),
    CHECK ((ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL AND Fence >= 0) OR (ActiveJobID IS NOT NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NOT NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NOT NULL AND OwnerID IS NOT NULL AND Fence > 0)),
    CHECK (BlockedReason IS NULL OR LEN(BlockedReason) > 0),
    CHECK (Version > 0)
);
CREATE INDEX IX_ExportResource_ActiveJob ON #S11_dbo_ExportResource (ActiveJobID) WHERE ActiveJobID IS NOT NULL;
CREATE INDEX IX_ExportResource_ActiveOutputOperation ON #S11_dbo_ExportResource (ActiveOutputOperationID) WHERE ActiveOutputOperationID IS NOT NULL;
CREATE TABLE #S11_dbo_ExportJobResource
(
    JobID uniqueidentifier NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PRIMARY KEY (JobID, ResourceKey)
);
CREATE INDEX IX_ExportJobResource_Resource ON #S11_dbo_ExportJobResource (ResourceKey, JobID);
CREATE TABLE #S11_dbo_ExportAttempt
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
    UNIQUE (AttemptID, JobID, Epoch),
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
CREATE INDEX IX_ExportAttempt_Phase ON #S11_dbo_ExportAttempt (Phase, UpdatedUTC, JobID);
CREATE TABLE #S11_dbo_ExportPreparation
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
CREATE INDEX IX_ExportPreparation_Queue ON #S11_dbo_ExportPreparation(AccountKey,State,EnqueueSequence,PreparationID);
CREATE UNIQUE INDEX UX_ExportPreparation_Job ON #S11_dbo_ExportPreparation(JobID) WHERE JobID IS NOT NULL;
CREATE TABLE #S11_dbo_ExportPreparationResource
(
 PreparationID uniqueidentifier NOT NULL,
 ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
 PRIMARY KEY (PreparationID,ResourceKey)
);
CREATE INDEX IX_ExportPreparationResource_Resource ON #S11_dbo_ExportPreparationResource(ResourceKey);
CREATE TABLE #S11_KVK_SourceOutputPool
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
CREATE INDEX IX_SourceOutputPool_State ON #S11_KVK_SourceOutputPool (AccountKey, PoolState, PoolID);
CREATE TABLE #S11_KVK_SourceOutputOperation
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
CREATE UNIQUE INDEX UX_SourceOutputOperation_ActivePool ON #S11_KVK_SourceOutputOperation (ActivePoolID) WHERE ActivePoolID IS NOT NULL;
CREATE INDEX IX_SourceOutputOperation_Queue ON #S11_KVK_SourceOutputOperation (AccountKey, State, EnqueueSequence, OperationID);
CREATE TABLE #S11_KVK_SourceOutputOperationResource
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
CREATE TABLE #S11_dbo_ExportExecutionSession
(
SessionID uniqueidentifier NOT NULL,
 AuthorityPrincipal nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 HostIdentity varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 BootID uniqueidentifier NOT NULL,
 ExecutableHash binary(32) NOT NULL,
 ManifestHash binary(32) NOT NULL,
 ProtocolVersion int NOT NULL,
 State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 ClosedUTC datetime2(3) NULL,
 PRIMARY KEY (SessionID),
 CHECK (LEN(AuthorityPrincipal)>0 AND LEN(HostIdentity)>0 AND DATALENGTH(HostIdentity)=LEN(HostIdentity) AND HostIdentity NOT LIKE '%[^A-Za-z0-9_.:-]%' COLLATE Latin1_General_100_BIN2),
 CHECK (ProtocolVersion=1 AND Version>0),
 CHECK (DATALENGTH(State)=LEN(State) AND ((State='open' AND ClosedUTC IS NULL) OR (State='closed' AND ClosedUTC>=CreatedUTC)))
);
CREATE TABLE #S11_dbo_ExportExecutionStream
(
StreamID uniqueidentifier NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ActiveAccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NULL,
 JobID uniqueidentifier NULL,
 PreparationID uniqueidentifier NULL,
 OutputOperationID uniqueidentifier NULL,
 OwnerID uniqueidentifier NULL,
 Fence bigint NOT NULL,
 ClaimVersion bigint NOT NULL,
 NestedToken uniqueidentifier NULL,
 RegistrationHash binary(32) NOT NULL,
 Epoch bigint NULL,
 SnapshotHash binary(32) NOT NULL,
 ScopeJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
 Purpose varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 LastSequence bigint NOT NULL,
 ChildIdentity uniqueidentifier NOT NULL,
 ClosureHash binary(32) NULL,
 ClosureReference uniqueidentifier NULL,
 EventDigest binary(32) NULL,
 CreatedUTC datetime2(3) NOT NULL,
 ClosedUTC datetime2(3) NULL,
 PRIMARY KEY (StreamID),
 UNIQUE (StreamID,SessionID),
 CHECK ((CASE WHEN JobID IS NULL THEN 0 ELSE 1 END + CASE WHEN PreparationID IS NULL THEN 0 ELSE 1 END + CASE WHEN OutputOperationID IS NULL THEN 0 ELSE 1 END)=1 AND (NestedToken IS NULL OR JobID IS NOT NULL)),
 CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=LEN(AccountKey) AND AccountKey NOT LIKE '%[^A-Za-z0-9_.@:-]%' COLLATE Latin1_General_100_BIN2),
 CHECK (ClaimVersion>0 AND Version>0 AND LastSequence>=0 AND (Epoch IS NULL OR Epoch>0) AND ((OwnerID IS NOT NULL AND Fence>0) OR (OwnerID IS NULL AND Fence=0 AND OutputOperationID IS NOT NULL AND Purpose='probe' AND NestedToken IS NULL))),
 CHECK (Purpose IN ('mutation','probe','enrollment') AND DATALENGTH(Purpose)=LEN(Purpose)),
 CHECK (DATALENGTH(State)=LEN(State) AND ((State IN ('open','frozen') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR (State='closed' AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL))),
 CHECK (ISJSON(ScopeJson)=1 AND DATALENGTH(ScopeJson)<=65536)
);
CREATE UNIQUE INDEX UX_ExportExecutionStream_ActiveAccount ON #S11_dbo_ExportExecutionStream(ActiveAccountKey) WHERE ActiveAccountKey IS NOT NULL;
CREATE INDEX IX_ExportExecutionStream_Owner ON #S11_dbo_ExportExecutionStream(AccountKey,JobID,PreparationID,OutputOperationID,State);
CREATE INDEX IX_ExportExecutionStream_Session ON #S11_dbo_ExportExecutionStream(SessionID,State);
CREATE TABLE #S11_dbo_ExportProviderRequest
(
RequestID uniqueidentifier NOT NULL,
 StreamID uniqueidentifier NOT NULL,
 Sequence bigint NOT NULL,
 Operation varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
 RequestKind varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 TargetID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 PayloadHash binary(32) NOT NULL,
 PayloadReference uniqueidentifier NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 PRIMARY KEY (RequestID),
 UNIQUE (StreamID,Sequence),
 CHECK (Sequence>0),
 CHECK (LEN(TargetID)>0 AND DATALENGTH(TargetID)=LEN(TargetID) AND TargetID NOT LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2),
 CHECK (DATALENGTH(Operation)=LEN(Operation) AND DATALENGTH(RequestKind)=LEN(RequestKind) AND ((RequestKind='read' AND Operation IN ('sheets.get','sheets.values.get','sheets.values.batchGet','drive.files.get','drive.permissions.list')) OR (RequestKind='mutation' AND Operation IN ('sheets.batchUpdate','sheets.values.update','sheets.values.clear','drive.files.update','drive.permissions.create','drive.permissions.delete','sheets.create'))))
);
CREATE TABLE #S11_dbo_ExportProviderRequestEvent
(
EventID uniqueidentifier NOT NULL,
 RequestID uniqueidentifier NOT NULL,
 EventSequence int NOT NULL,
 State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 EvidenceHash binary(32) NOT NULL,
 EvidenceReference uniqueidentifier NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 PRIMARY KEY (EventID),
 UNIQUE (RequestID,EventSequence),
 CHECK (DATALENGTH(State)=LEN(State) AND ((EventSequence=1 AND State='prepared') OR (EventSequence=2 AND State IN ('dispatch_intent','not_sent')) OR (EventSequence=3 AND State IN ('succeeded','unknown'))))
);
CREATE TABLE #S11_dbo_ExportReconciliationProof
(
ProofID uniqueidentifier NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 SnapshotHash binary(32) NOT NULL,
 RegistrationHash binary(32) NOT NULL,
 ProofKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Outcome varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 MembershipHash binary(32) NOT NULL,
 MembershipJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
 EvidenceJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 PRIMARY KEY (ProofID),
 CHECK (DATALENGTH(ProofKind)=LEN(ProofKind) AND ProofKind IN ('publication','retirement','retirement_recovery','rollover_drain','rollover_complete')),
 CHECK (DATALENGTH(Outcome)=LEN(Outcome) AND ((ProofKind='publication' AND Outcome IN ('confirmed','absent','damaged')) OR (ProofKind IN ('retirement','retirement_recovery','rollover_drain') AND Outcome='confirmed') OR (ProofKind='rollover_complete' AND Outcome='completed'))),
 CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=LEN(AccountKey) AND AccountKey NOT LIKE '%[^A-Za-z0-9_.@:-]%' COLLATE Latin1_General_100_BIN2),
 CHECK (ISJSON(MembershipJson)=1 AND DATALENGTH(MembershipJson)<=65536 AND ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=65536)
);
CREATE INDEX IX_ExportReconciliationProof_Snapshot ON #S11_dbo_ExportReconciliationProof(AccountKey,SnapshotHash,ProofKind);
CREATE TABLE #S11_dbo_ExportManagedFileOrigin
(
 FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Stage varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ParentStage varchar(16) COLLATE Latin1_General_100_BIN2 NULL,
 PreparationID uniqueidentifier NOT NULL,
 Ordinal int NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 CreationStreamID uniqueidentifier NOT NULL,
 CreationRequestID uniqueidentifier NOT NULL,
 ResponseEventID uniqueidentifier NOT NULL,
 PlanHash binary(32) NOT NULL,
 ProfileHash binary(32) NOT NULL,
 ResponseHash binary(32) NOT NULL,
 CreationClosureHash binary(32) NOT NULL,
 OriginHash binary(32) NOT NULL,
 OriginReference uniqueidentifier NOT NULL,
 VerificationStreamID uniqueidentifier NULL,
 VerificationClosureHash binary(32) NULL,
 EligibilityHash binary(32) NULL,
 EligibilityReference uniqueidentifier NULL,
 CreatedUTC datetime2(3) NOT NULL,
 PRIMARY KEY (FileID,Stage),
 UNIQUE (PreparationID,Ordinal,Stage),
 UNIQUE (CreationRequestID,Stage),
 CHECK (DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16),
 CHECK (DATALENGTH(Stage)=LEN(Stage) AND ((Stage='created' AND ParentStage IS NULL AND VerificationStreamID IS NULL AND VerificationClosureHash IS NULL AND EligibilityHash IS NULL AND EligibilityReference IS NULL) OR (Stage='eligible' AND ParentStage IS NOT NULL AND ParentStage='created' AND DATALENGTH(ParentStage)=7 AND VerificationStreamID IS NOT NULL AND VerificationClosureHash IS NOT NULL AND EligibilityHash IS NOT NULL AND EligibilityReference IS NOT NULL)))
);
CREATE INDEX IX_ExportManagedFileOrigin_Preparation ON #S11_dbo_ExportManagedFileOrigin(PreparationID,Stage,Ordinal);
DECLARE @S11Map TABLE (Name nvarchar(256),ActualID int,ExpectedID int);
INSERT @S11Map VALUES
(N'dbo.ExportJob',OBJECT_ID(N'dbo.ExportJob',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportJob')),
(N'dbo.ExportResource',OBJECT_ID(N'dbo.ExportResource',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportResource')),
(N'dbo.ExportJobResource',OBJECT_ID(N'dbo.ExportJobResource',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportJobResource')),
(N'dbo.ExportAttempt',OBJECT_ID(N'dbo.ExportAttempt',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportAttempt')),
(N'dbo.ExportPreparation',OBJECT_ID(N'dbo.ExportPreparation',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportPreparation')),
(N'dbo.ExportPreparationResource',OBJECT_ID(N'dbo.ExportPreparationResource',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportPreparationResource')),
(N'KVK.SourceOutputPool',OBJECT_ID(N'KVK.SourceOutputPool',N'U'),OBJECT_ID(N'tempdb..#S11_KVK_SourceOutputPool')),
(N'KVK.SourceOutputOperation',OBJECT_ID(N'KVK.SourceOutputOperation',N'U'),OBJECT_ID(N'tempdb..#S11_KVK_SourceOutputOperation')),
(N'KVK.SourceOutputOperationResource',OBJECT_ID(N'KVK.SourceOutputOperationResource',N'U'),OBJECT_ID(N'tempdb..#S11_KVK_SourceOutputOperationResource'));
IF EXISTS(SELECT 1 FROM @S11Map WHERE ActualID IS NULL) THROW 51700,'Missing ownership prerequisites; no predecessor rerun.',1;
DECLARE @S11FK TABLE(ParentName nvarchar(256),ConstraintName sysname,Ordinal int,ParentColumn sysname,TargetName nvarchar(256),TargetColumn sysname);
INSERT @S11FK VALUES
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
(N'dbo.ExportResource',N'FK_ExportResource_OutputOperationMembership',1,N'ActiveOutputOperationID',N'KVK.SourceOutputOperationResource',N'OperationID'),
(N'dbo.ExportResource',N'FK_ExportResource_OutputOperationMembership',2,N'ResourceKey',N'KVK.SourceOutputOperationResource',N'ResourceKey'),
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
(N'dbo.ExportPreparation',N'FK_ExportPreparation_Job',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'dbo.ExportPreparationResource',N'FK_ExportPreparationResource_Preparation',1,N'PreparationID',N'dbo.ExportPreparation',N'PreparationID'),
(N'dbo.ExportPreparationResource',N'FK_ExportPreparationResource_Resource',1,N'ResourceKey',N'dbo.ExportResource',N'ResourceKey'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Index',1,N'IndexFileID',N'KVK.SourceOutputFile',N'FileID'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Index',2,N'IndexFileKind',N'KVK.SourceOutputFile',N'FileKind'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Account',1,N'AccountResourceKey',N'dbo.ExportResource',N'ResourceKey'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Choice',1,N'ActiveKVK',N'KVK.SeasonSource',N'KVK_NO'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Choice',2,N'SourceKey',N'KVK.SeasonSource',N'SourceKey'),
(N'KVK.SourceOutputPool',N'FK_SourceOutputPool_Choice',3,N'ChoiceID',N'KVK.SeasonSource',N'ChoiceID'),
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
(N'dbo.ExportExecutionStream',N'FK_ExportExecutionStream_Session',1,N'SessionID',N'dbo.ExportExecutionSession',N'SessionID'),
(N'dbo.ExportExecutionStream',N'FK_ExportExecutionStream_Job',1,N'JobID',N'dbo.ExportJob',N'JobID'),
(N'dbo.ExportExecutionStream',N'FK_ExportExecutionStream_Preparation',1,N'PreparationID',N'dbo.ExportPreparation',N'PreparationID'),
(N'dbo.ExportExecutionStream',N'FK_ExportExecutionStream_Operation',1,N'OutputOperationID',N'KVK.SourceOutputOperation',N'OperationID'),
(N'dbo.ExportProviderRequest',N'FK_ExportProviderRequest_Stream',1,N'StreamID',N'dbo.ExportExecutionStream',N'StreamID'),
(N'dbo.ExportProviderRequestEvent',N'FK_ExportProviderRequestEvent_Request',1,N'RequestID',N'dbo.ExportProviderRequest',N'RequestID'),
(N'dbo.ExportReconciliationProof',N'FK_ExportReconciliationProof_Session',1,N'SessionID',N'dbo.ExportExecutionSession',N'SessionID'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Parent',1,N'FileID',N'dbo.ExportManagedFileOrigin',N'FileID'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Parent',2,N'ParentStage',N'dbo.ExportManagedFileOrigin',N'Stage'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Preparation',1,N'PreparationID',N'dbo.ExportPreparation',N'PreparationID'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Creation',1,N'CreationStreamID',N'dbo.ExportExecutionStream',N'StreamID'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Creation',2,N'SessionID',N'dbo.ExportExecutionStream',N'SessionID'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Request',1,N'CreationRequestID',N'dbo.ExportProviderRequest',N'RequestID'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Response',1,N'ResponseEventID',N'dbo.ExportProviderRequestEvent',N'EventID'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Verification',1,N'VerificationStreamID',N'dbo.ExportExecutionStream',N'StreamID'),
(N'dbo.ExportManagedFileOrigin',N'FK_ExportManagedFileOrigin_Verification',2,N'SessionID',N'dbo.ExportExecutionStream',N'SessionID');
-- EXCEPT in both directions rejects missing, extra, disabled, untrusted or altered shape.
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S11Map m JOIN sys.columns c ON c.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S11Map m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S11Map m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S11Map m JOIN sys.columns c ON c.object_id=m.ActualID)
    THROW 51700, 'S11 column shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S11Map m JOIN sys.columns c ON c.object_id=m.ActualID WHERE c.user_type_id<>c.system_type_id) THROW 51700, 'S11 alias type conflict.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S11Map m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S11Map m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S11Map m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S11Map m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID)
    THROW 51700, 'S11 check constraint shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN sys.indexes i ON i.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN sys.indexes i ON i.object_id=m.ActualID)
    THROW 51700, 'S11 index shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name)
    THROW 51700, 'S11 index count shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S11Map m JOIN sys.triggers t ON t.parent_id=m.ActualID)
OR EXISTS (SELECT 1 FROM @S11Map m JOIN sys.tables t ON t.object_id=m.ActualID WHERE t.temporal_type<>0 OR t.is_memory_optimized<>0)
    THROW 51700, 'S11 unexpected default, trigger or table mode.', 1;
-- Defaults are part of the inherited contract (SourceRouting has Enabled=0).
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID)
    THROW 51700, 'S11 default shape conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name)
    THROW 51700, 'S11 check count conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S11Map m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
EXCEPT
SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S11FK e WHERE EXISTS (SELECT 1 FROM @S11Map m WHERE m.Name=e.ParentName))
OR EXISTS (SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S11FK e WHERE EXISTS (SELECT 1 FROM @S11Map m WHERE m.Name=e.ParentName)
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S11Map m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id)
    THROW 51700, 'S11 foreign key shape conflict; preserve history and forward-fix.', 1;
IF @S11Existing=0
BEGIN
 EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportExecutionSession
(
SessionID uniqueidentifier NOT NULL,
 AuthorityPrincipal nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 HostIdentity varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 BootID uniqueidentifier NOT NULL,
 ExecutableHash binary(32) NOT NULL,
 ManifestHash binary(32) NOT NULL,
 ProtocolVersion int NOT NULL,
 State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 ClosedUTC datetime2(3) NULL,
 CONSTRAINT PK_ExportExecutionSession PRIMARY KEY (SessionID),
 CONSTRAINT CK_ExportExecutionSession_Identity CHECK (LEN(AuthorityPrincipal)>0 AND LEN(HostIdentity)>0 AND DATALENGTH(HostIdentity)=LEN(HostIdentity) AND HostIdentity NOT LIKE ''%[^A-Za-z0-9_.:-]%'' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportExecutionSession_Version CHECK (ProtocolVersion=1 AND Version>0),
 CONSTRAINT CK_ExportExecutionSession_State CHECK (DATALENGTH(State)=LEN(State) AND ((State=''open'' AND ClosedUTC IS NULL) OR (State=''closed'' AND ClosedUTC>=CreatedUTC)))
);
';
 EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportExecutionStream
(
StreamID uniqueidentifier NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ActiveAccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NULL,
 JobID uniqueidentifier NULL,
 PreparationID uniqueidentifier NULL,
 OutputOperationID uniqueidentifier NULL,
 OwnerID uniqueidentifier NULL,
 Fence bigint NOT NULL,
 ClaimVersion bigint NOT NULL,
 NestedToken uniqueidentifier NULL,
 RegistrationHash binary(32) NOT NULL,
 Epoch bigint NULL,
 SnapshotHash binary(32) NOT NULL,
 ScopeJson nvarchar(max) NOT NULL,
 Purpose varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 LastSequence bigint NOT NULL,
 ChildIdentity uniqueidentifier NOT NULL,
 ClosureHash binary(32) NULL,
 ClosureReference uniqueidentifier NULL,
 EventDigest binary(32) NULL,
 CreatedUTC datetime2(3) NOT NULL,
 ClosedUTC datetime2(3) NULL,
 CONSTRAINT PK_ExportExecutionStream PRIMARY KEY (StreamID),
 CONSTRAINT UQ_ExportExecutionStream_Session UNIQUE (StreamID,SessionID),
 CONSTRAINT FK_ExportExecutionStream_Session FOREIGN KEY (SessionID) REFERENCES dbo.ExportExecutionSession(SessionID),
 CONSTRAINT FK_ExportExecutionStream_Job FOREIGN KEY (JobID) REFERENCES dbo.ExportJob(JobID),
 CONSTRAINT FK_ExportExecutionStream_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportExecutionStream_Operation FOREIGN KEY (OutputOperationID) REFERENCES KVK.SourceOutputOperation(OperationID),
 CONSTRAINT CK_ExportExecutionStream_Owner CHECK ((CASE WHEN JobID IS NULL THEN 0 ELSE 1 END + CASE WHEN PreparationID IS NULL THEN 0 ELSE 1 END + CASE WHEN OutputOperationID IS NULL THEN 0 ELSE 1 END)=1 AND (NestedToken IS NULL OR JobID IS NOT NULL)),
 CONSTRAINT CK_ExportExecutionStream_Account CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=LEN(AccountKey) AND AccountKey NOT LIKE ''%[^A-Za-z0-9_.@:-]%'' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportExecutionStream_Counters CHECK (ClaimVersion>0 AND Version>0 AND LastSequence>=0 AND (Epoch IS NULL OR Epoch>0) AND ((OwnerID IS NOT NULL AND Fence>0) OR (OwnerID IS NULL AND Fence=0 AND OutputOperationID IS NOT NULL AND Purpose=''probe'' AND NestedToken IS NULL))),
 CONSTRAINT CK_ExportExecutionStream_Purpose CHECK (Purpose IN (''mutation'',''probe'',''enrollment'') AND DATALENGTH(Purpose)=LEN(Purpose)),
 CONSTRAINT CK_ExportExecutionStream_State CHECK (DATALENGTH(State)=LEN(State) AND ((State IN (''open'',''frozen'') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR (State=''closed'' AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL))),
 CONSTRAINT CK_ExportExecutionStream_Scope CHECK (ISJSON(ScopeJson)=1 AND DATALENGTH(ScopeJson)<=65536)
);
CREATE UNIQUE INDEX UX_ExportExecutionStream_ActiveAccount ON dbo.ExportExecutionStream(ActiveAccountKey) WHERE ActiveAccountKey IS NOT NULL;
CREATE INDEX IX_ExportExecutionStream_Owner ON dbo.ExportExecutionStream(AccountKey,JobID,PreparationID,OutputOperationID,State);
CREATE INDEX IX_ExportExecutionStream_Session ON dbo.ExportExecutionStream(SessionID,State);
';
 EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportProviderRequest
(
RequestID uniqueidentifier NOT NULL,
 StreamID uniqueidentifier NOT NULL,
 Sequence bigint NOT NULL,
 Operation varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
 RequestKind varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 TargetID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 PayloadHash binary(32) NOT NULL,
 PayloadReference uniqueidentifier NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportProviderRequest PRIMARY KEY (RequestID),
 CONSTRAINT UQ_ExportProviderRequest_Sequence UNIQUE (StreamID,Sequence),
 CONSTRAINT FK_ExportProviderRequest_Stream FOREIGN KEY (StreamID) REFERENCES dbo.ExportExecutionStream(StreamID),
 CONSTRAINT CK_ExportProviderRequest_Sequence CHECK (Sequence>0),
 CONSTRAINT CK_ExportProviderRequest_Target CHECK (LEN(TargetID)>0 AND DATALENGTH(TargetID)=LEN(TargetID) AND TargetID NOT LIKE ''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportProviderRequest_Operation CHECK (DATALENGTH(Operation)=LEN(Operation) AND DATALENGTH(RequestKind)=LEN(RequestKind) AND ((RequestKind=''read'' AND Operation IN (''sheets.get'',''sheets.values.get'',''sheets.values.batchGet'',''drive.files.get'',''drive.permissions.list'')) OR (RequestKind=''mutation'' AND Operation IN (''sheets.batchUpdate'',''sheets.values.update'',''sheets.values.clear'',''drive.files.update'',''drive.permissions.create'',''drive.permissions.delete'',''sheets.create''))))
);
';
 EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportProviderRequestEvent
(
EventID uniqueidentifier NOT NULL,
 RequestID uniqueidentifier NOT NULL,
 EventSequence int NOT NULL,
 State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 EvidenceHash binary(32) NOT NULL,
 EvidenceReference uniqueidentifier NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportProviderRequestEvent PRIMARY KEY (EventID),
 CONSTRAINT UQ_ExportProviderRequestEvent_Sequence UNIQUE (RequestID,EventSequence),
 CONSTRAINT FK_ExportProviderRequestEvent_Request FOREIGN KEY (RequestID) REFERENCES dbo.ExportProviderRequest(RequestID),
 CONSTRAINT CK_ExportProviderRequestEvent_State CHECK (DATALENGTH(State)=LEN(State) AND ((EventSequence=1 AND State=''prepared'') OR (EventSequence=2 AND State IN (''dispatch_intent'',''not_sent'')) OR (EventSequence=3 AND State IN (''succeeded'',''unknown''))))
);
';
 EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportReconciliationProof
(
ProofID uniqueidentifier NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 SnapshotHash binary(32) NOT NULL,
 RegistrationHash binary(32) NOT NULL,
 ProofKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Outcome varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 MembershipHash binary(32) NOT NULL,
 MembershipJson nvarchar(max) NOT NULL,
 EvidenceJson nvarchar(max) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportReconciliationProof PRIMARY KEY (ProofID),
 CONSTRAINT FK_ExportReconciliationProof_Session FOREIGN KEY (SessionID) REFERENCES dbo.ExportExecutionSession(SessionID),
 CONSTRAINT CK_ExportReconciliationProof_Kind CHECK (DATALENGTH(ProofKind)=LEN(ProofKind) AND ProofKind IN (''publication'',''retirement'',''retirement_recovery'',''rollover_drain'',''rollover_complete'')),
 CONSTRAINT CK_ExportReconciliationProof_Outcome CHECK (DATALENGTH(Outcome)=LEN(Outcome) AND ((ProofKind=''publication'' AND Outcome IN (''confirmed'',''absent'',''damaged'')) OR (ProofKind IN (''retirement'',''retirement_recovery'',''rollover_drain'') AND Outcome=''confirmed'') OR (ProofKind=''rollover_complete'' AND Outcome=''completed''))),
 CONSTRAINT CK_ExportReconciliationProof_Account CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=LEN(AccountKey) AND AccountKey NOT LIKE ''%[^A-Za-z0-9_.@:-]%'' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportReconciliationProof_Evidence CHECK (ISJSON(MembershipJson)=1 AND DATALENGTH(MembershipJson)<=65536 AND ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=65536)
);
CREATE INDEX IX_ExportReconciliationProof_Snapshot ON dbo.ExportReconciliationProof(AccountKey,SnapshotHash,ProofKind);
';
 EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportManagedFileOrigin
(
 FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Stage varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ParentStage varchar(16) COLLATE Latin1_General_100_BIN2 NULL,
 PreparationID uniqueidentifier NOT NULL,
 Ordinal int NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 CreationStreamID uniqueidentifier NOT NULL,
 CreationRequestID uniqueidentifier NOT NULL,
 ResponseEventID uniqueidentifier NOT NULL,
 PlanHash binary(32) NOT NULL,
 ProfileHash binary(32) NOT NULL,
 ResponseHash binary(32) NOT NULL,
 CreationClosureHash binary(32) NOT NULL,
 OriginHash binary(32) NOT NULL,
 OriginReference uniqueidentifier NOT NULL,
 VerificationStreamID uniqueidentifier NULL,
 VerificationClosureHash binary(32) NULL,
 EligibilityHash binary(32) NULL,
 EligibilityReference uniqueidentifier NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportManagedFileOrigin PRIMARY KEY (FileID,Stage),
 CONSTRAINT UQ_ExportManagedFileOrigin_Ordinal UNIQUE (PreparationID,Ordinal,Stage),
 CONSTRAINT UQ_ExportManagedFileOrigin_Request UNIQUE (CreationRequestID,Stage),
 CONSTRAINT FK_ExportManagedFileOrigin_Parent FOREIGN KEY (FileID,ParentStage) REFERENCES dbo.ExportManagedFileOrigin(FileID,Stage),
 CONSTRAINT FK_ExportManagedFileOrigin_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportManagedFileOrigin_Creation FOREIGN KEY (CreationStreamID,SessionID) REFERENCES dbo.ExportExecutionStream(StreamID,SessionID),
 CONSTRAINT FK_ExportManagedFileOrigin_Request FOREIGN KEY (CreationRequestID) REFERENCES dbo.ExportProviderRequest(RequestID),
 CONSTRAINT FK_ExportManagedFileOrigin_Response FOREIGN KEY (ResponseEventID) REFERENCES dbo.ExportProviderRequestEvent(EventID),
 CONSTRAINT FK_ExportManagedFileOrigin_Verification FOREIGN KEY (VerificationStreamID,SessionID) REFERENCES dbo.ExportExecutionStream(StreamID,SessionID),
 CONSTRAINT CK_ExportManagedFileOrigin_Identity CHECK (DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE ''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16),
 CONSTRAINT CK_ExportManagedFileOrigin_Stage CHECK (DATALENGTH(Stage)=LEN(Stage) AND ((Stage=''created'' AND ParentStage IS NULL AND VerificationStreamID IS NULL AND VerificationClosureHash IS NULL AND EligibilityHash IS NULL AND EligibilityReference IS NULL) OR (Stage=''eligible'' AND ParentStage IS NOT NULL AND ParentStage=''created'' AND DATALENGTH(ParentStage)=7 AND VerificationStreamID IS NOT NULL AND VerificationClosureHash IS NOT NULL AND EligibilityHash IS NOT NULL AND EligibilityReference IS NOT NULL)))
);
CREATE INDEX IX_ExportManagedFileOrigin_Preparation ON dbo.ExportManagedFileOrigin(PreparationID,Stage,Ordinal);
';
 EXEC sys.sp_executesql N'CREATE PROCEDURE dbo.usp_ExportExecutionSessionTransition
 @SessionID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @HostIdentity varchar(128)=NULL,
 @BootID uniqueidentifier=NULL,
 @ExecutableHash binary(32)=NULL,
 @ManifestHash binary(32)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY

 DECLARE @Existing bigint;
 SELECT @Existing=Version FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK) WHERE SessionID=@SessionID;
 IF @Action=''open'' AND DATALENGTH(@Action)=4 AND @ExpectedVersion=0 AND @Existing IS NULL
 BEGIN
  INSERT dbo.ExportExecutionSession VALUES (@SessionID,USER_NAME(),@HostIdentity,@BootID,@ExecutableHash,@ManifestHash,1,''open'',1,SYSUTCDATETIME(),NULL);
 END
 ELSE IF @Action=''close'' AND DATALENGTH(@Action)=5 AND @ExpectedVersion=@Existing
 BEGIN
  IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE SessionID=@SessionID AND State<>''closed'')
    THROW 51700,''Provider stream closure is unproven.'',1;
  UPDATE dbo.ExportExecutionSession SET State=''closed'',Version=Version+1,ClosedUTC=SYSUTCDATETIME()
  WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'' AND Version=@ExpectedVersion;
  IF @@ROWCOUNT<>1 THROW 51700,''Session CAS lost.'',1;
 END
 ELSE THROW 51700,''Session action/CAS conflict; read exact identity before retry.'',1;
 SELECT * FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
 EXEC sys.sp_executesql N'CREATE PROCEDURE dbo.usp_ExportExecutionStreamTransition
 @SessionID uniqueidentifier,
 @StreamID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @AccountKey varchar(128),
 @OwnerKind varchar(16)=NULL,
 @ObjectID uniqueidentifier=NULL,
 @OwnerID uniqueidentifier=NULL,
 @Fence bigint=NULL,
 @ClaimVersion bigint=NULL,
 @NestedToken uniqueidentifier=NULL,
 @RegistrationHash binary(32)=NULL,
 @Epoch bigint=NULL,
 @SnapshotHash binary(32)=NULL,
 @ScopeJson nvarchar(max)=NULL,
 @Purpose varchar(16)=NULL,
 @ChildIdentity uniqueidentifier=NULL,
 @ClosureHash binary(32)=NULL,
 @ClosureReference uniqueidentifier=NULL,
 @EventDigest binary(32)=NULL,
 @LastSequence bigint=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;

 IF @Action=''open'' AND DATALENGTH(@Action)=4 AND @ExpectedVersion=0
 BEGIN

 -- Account lock precedes sorted resource locks; stream row is locked last.
 IF @AccountKey IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL OR @ClaimVersion<=0
 OR (@OwnerID IS NULL AND NOT (@OwnerKind=''operation'' AND @Purpose=''probe'' AND @Fence=0 AND @NestedToken IS NULL))
 OR (@OwnerID IS NOT NULL AND @Fence<=0)
 OR @OwnerKind NOT IN (''job'',''preparation'',''operation'') OR @OwnerKind IS NULL
 OR DATALENGTH(@OwnerKind)<>LEN(@OwnerKind) OR @ObjectID IS NULL
 OR @Purpose NOT IN (''mutation'',''probe'',''enrollment'') OR @Purpose IS NULL OR DATALENGTH(@Purpose)<>LEN(@Purpose)
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>65536
 THROW 51700,''Complete typed stream scope required.'',1;
 DECLARE @Resources TABLE (ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF JSON_QUERY(@ScopeJson,''$.resources'') IS NULL THROW 51700,''Complete resource membership required.'',1;
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ScopeJson,''$.resources'')
 WITH (ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
 IF NOT EXISTS (SELECT 1 FROM @Resources WHERE ResourceKey=''account:''+@AccountKey)
 OR (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 1 AND 1025 OR EXISTS (SELECT 1 FROM @Resources WHERE Version<=0)
 THROW 51700,''Invalid resource membership.'',1;
 IF @Purpose=''probe'' AND EXISTS (SELECT 1 FROM dbo.ExportResource r JOIN dbo.ExportPreparation p ON p.PreparationID=r.ActivePreparationID
    WHERE p.AccountKey=@AccountKey AND r.ResourceKind=''sql_snapshot'' AND r.OwnerID IS NOT NULL)
  THROW 51700,''Owned SQL producer must drain before observational probe.'',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint,@ResourceLock nvarchar(255),@ResourceResult int;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @ResourceLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @ResourceResult=sys.sp_getapplock @Resource=@ResourceLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @ResourceResult<0 THROW 51700,''Resource admission busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK)
    WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion
    AND (@Purpose=''probe'' OR BlockedReason IS NULL)
    AND ((@Purpose=''probe'' AND OwnerID IS NULL AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
     OR (OwnerID=@OwnerID AND Fence=@Fence AND ((@OwnerKind=''job'' AND ActiveJobID=@ObjectID AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''preparation'' AND ActivePreparationID=@ObjectID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''operation'' AND ActiveOutputOperationID=@ObjectID AND ActiveJobID IS NULL AND ActivePreparationID IS NULL)))))
   THROW 51700,''Resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;
 IF @Purpose=''enrollment'' AND @OwnerKind<>''preparation'' THROW 51700,''Enrollment requires its preparation owner.'',1;
 IF @OwnerKind=''job''
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
   AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'')))
   AND ((PoolEpoch IS NULL AND @Epoch IS NULL) OR PoolEpoch=@Epoch)
   AND ((@NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'') IS NULL)
      OR (@NestedToken IS NOT NULL AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.token''))=@NestedToken
       AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''owned''
       AND (TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion
        OR (@Purpose=''probe'' AND State=''uncertain'' AND @ClaimVersion>1
         AND TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion-1)))
      OR (@Purpose=''probe'' AND @NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''complete'')))
   THROW 51700,''Job/nested owner CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID)
   THROW 51700,''Job membership conflict.'',1;
 END
 ELSE IF @OwnerKind=''preparation''
 BEGIN
  IF @NestedToken IS NOT NULL OR @Epoch IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion AND (@Purpose=''probe'' OR State=''preflight''))
   THROW 51700,''Preparation CAS conflict.'',1;

  DECLARE @EnrollmentPlan nvarchar(max),@EnrollmentProgress nvarchar(max),@EnrollmentHash binary(32);
  SELECT @EnrollmentPlan=RequestJson,@EnrollmentProgress=GenerationJson,@EnrollmentHash=RequestHash
   FROM dbo.ExportPreparation WHERE PreparationID=@ObjectID;
  IF @Purpose=''enrollment''
  BEGIN
   IF JSON_VALUE(@EnrollmentPlan,''$.purpose'') IS NULL OR JSON_VALUE(@EnrollmentPlan,''$.purpose'')<>''output_enrollment''
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id'')) IS NULL
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id''))<>@SessionID
    OR @RegistrationHash<>@EnrollmentHash OR @SnapshotHash<>@EnrollmentHash
    OR @EnrollmentHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@EnrollmentPlan))
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson))<>2
    OR JSON_QUERY(@ScopeJson,''$.enrollment'') IS NULL
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'') IS NULL
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') IS NULL
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>JSON_VALUE(@EnrollmentProgress,''$.phase'')
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal''))<>TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal''))
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') NOT IN (''create'',''verify'')
    THROW 51700,''Exact authority-side enrollment phase required.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    THROW 51700,''Enrollment phase already has a stream; never replay.'',1;
  END
  ELSE IF JSON_VALUE(@EnrollmentPlan,''$.purpose'')=''output_enrollment''
   THROW 51700,''Enrollment cannot become ordinary configuration authority.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID)
   THROW 51700,''Preparation membership conflict.'',1;
 END
 ELSE
 BEGIN
  -- Pool lock follows resource locks, matching the Bot''s operation DAL.
  DECLARE @PoolID uniqueidentifier,@PoolLock nvarchar(255),@PoolLockResult int;
  SELECT @PoolID=PoolID FROM KVK.SourceOutputOperation WHERE OperationID=@ObjectID AND AccountKey=@AccountKey;
  IF @PoolID IS NULL THROW 51700,''Output operation pool is unavailable.'',1;
  SET @PoolLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @PoolLockResult=sys.sp_getapplock @Resource=@PoolLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @PoolLockResult<0 THROW 51700,''Output operation pool busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM KVK.SourceOutputPool WITH (UPDLOCK,HOLDLOCK)
   WHERE PoolID=@PoolID AND AccountKey=@AccountKey AND PoolState=''closing''
    AND OwnerID=@ObjectID AND Epoch=@Epoch AND RegistrationHash=@RegistrationHash)
   THROW 51700,''Output operation registration/epoch changed.'',1;
  IF @NestedToken IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM KVK.SourceOutputOperation WITH (UPDLOCK,HOLDLOCK) WHERE OperationID=@ObjectID AND AccountKey=@AccountKey
    AND PoolID=@PoolID AND Fence=@Fence AND Version=@ClaimVersion AND OldEpoch=@Epoch
    AND ((OwnerID=@OwnerID AND (@Purpose=''probe'' OR State=''running''))
      OR (@Purpose=''probe'' AND @OwnerID IS NULL AND OwnerID IS NULL AND Fence=0 AND State=''closing'' AND Phase=''draining'')))
   THROW 51700,''Output operation CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID)
   THROW 51700,''Output operation membership conflict.'',1;
 END;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

  IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK) WHERE StreamID=@StreamID OR ActiveAccountKey=@AccountKey)
   THROW 51700,''Stream/account already registered; no automatic adoption.'',1;
  INSERT dbo.ExportExecutionStream VALUES (@StreamID,@SessionID,@AccountKey,@AccountKey,
   CASE WHEN @OwnerKind=''job'' THEN @ObjectID END,CASE WHEN @OwnerKind=''preparation'' THEN @ObjectID END,
   CASE WHEN @OwnerKind=''operation'' THEN @ObjectID END,@OwnerID,@Fence,@ClaimVersion,@NestedToken,@RegistrationHash,
   @Epoch,@SnapshotHash,@ScopeJson,@Purpose,''open'',1,0,@ChildIdentity,NULL,NULL,NULL,SYSUTCDATETIME(),NULL);
 END
 ELSE
 BEGIN
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

  IF @Action=''freeze'' AND DATALENGTH(@Action)=6
  BEGIN
   UPDATE dbo.ExportExecutionStream SET State=''frozen'',Version=Version+1
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion AND State=''open'';
   IF @@ROWCOUNT<>1 THROW 51700,''Stream freeze CAS lost.'',1;
  END
  ELSE IF @Action=''close'' AND DATALENGTH(@Action)=5 AND @ClosureHash IS NOT NULL AND @ChildIdentity IS NOT NULL
    AND @ClosureReference IS NOT NULL AND @EventDigest IS NOT NULL AND @LastSequence IS NOT NULL
  BEGIN
   -- Trusted parent supplies OS-handle closure evidence, not a caller Boolean.
   UPDATE dbo.ExportExecutionStream SET State=''closed'',ActiveAccountKey=NULL,Version=Version+1,ClosureHash=@ClosureHash,ClosureReference=@ClosureReference,EventDigest=@EventDigest,ClosedUTC=SYSUTCDATETIME()
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion
    AND ChildIdentity=@ChildIdentity AND State=''frozen'' AND LastSequence=@LastSequence;
   IF @@ROWCOUNT<>1 THROW 51700,''Stream close CAS lost.'',1;
  END
  ELSE THROW 51700,''Unsupported stream action.'',1;
 END;
 SELECT * FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
 EXEC sys.sp_executesql N'CREATE PROCEDURE dbo.usp_ExportProviderRequestEventAppend
 @SessionID uniqueidentifier,
 @StreamID uniqueidentifier,
 @AccountKey varchar(128),
 @ExpectedVersion bigint,
 @RequestID uniqueidentifier,
 @EventID uniqueidentifier,
 @State varchar(32),
 @EvidenceHash binary(32),
 @EvidenceReference uniqueidentifier,
 @Operation varchar(64)=NULL,
 @RequestKind varchar(16)=NULL,
 @TargetID varchar(128)=NULL,
 @PayloadHash binary(32)=NULL,
 @PayloadReference uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;

 DECLARE @OwnerKind varchar(16),@ObjectID uniqueidentifier,@OwnerID uniqueidentifier,@Fence bigint,@ClaimVersion bigint,
 @NestedToken uniqueidentifier,@Epoch bigint,@ScopeJson nvarchar(max),@Purpose varchar(16),@RegistrationHash binary(32),@SnapshotHash binary(32);
 SELECT @OwnerKind=CASE WHEN JobID IS NOT NULL THEN ''job'' WHEN PreparationID IS NOT NULL THEN ''preparation'' ELSE ''operation'' END,
 @ObjectID=COALESCE(JobID,PreparationID,OutputOperationID),@OwnerID=OwnerID,@Fence=Fence,@ClaimVersion=ClaimVersion,
 @NestedToken=NestedToken,@Epoch=Epoch,@ScopeJson=ScopeJson,@Purpose=Purpose,@RegistrationHash=RegistrationHash,@SnapshotHash=SnapshotHash
 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND AccountKey=@AccountKey AND SessionID=@SessionID;

 IF @State IN (''prepared'',''dispatch_intent'')
 BEGIN

 -- Account lock precedes sorted resource locks; stream row is locked last.
 IF @AccountKey IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL OR @ClaimVersion<=0
 OR (@OwnerID IS NULL AND NOT (@OwnerKind=''operation'' AND @Purpose=''probe'' AND @Fence=0 AND @NestedToken IS NULL))
 OR (@OwnerID IS NOT NULL AND @Fence<=0)
 OR @OwnerKind NOT IN (''job'',''preparation'',''operation'') OR @OwnerKind IS NULL
 OR DATALENGTH(@OwnerKind)<>LEN(@OwnerKind) OR @ObjectID IS NULL
 OR @Purpose NOT IN (''mutation'',''probe'',''enrollment'') OR @Purpose IS NULL OR DATALENGTH(@Purpose)<>LEN(@Purpose)
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>65536
 THROW 51700,''Complete typed stream scope required.'',1;
 DECLARE @Resources TABLE (ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF JSON_QUERY(@ScopeJson,''$.resources'') IS NULL THROW 51700,''Complete resource membership required.'',1;
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ScopeJson,''$.resources'')
 WITH (ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
 IF NOT EXISTS (SELECT 1 FROM @Resources WHERE ResourceKey=''account:''+@AccountKey)
 OR (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 1 AND 1025 OR EXISTS (SELECT 1 FROM @Resources WHERE Version<=0)
 THROW 51700,''Invalid resource membership.'',1;
 IF @Purpose=''probe'' AND EXISTS (SELECT 1 FROM dbo.ExportResource r JOIN dbo.ExportPreparation p ON p.PreparationID=r.ActivePreparationID
    WHERE p.AccountKey=@AccountKey AND r.ResourceKind=''sql_snapshot'' AND r.OwnerID IS NOT NULL)
  THROW 51700,''Owned SQL producer must drain before observational probe.'',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint,@ResourceLock nvarchar(255),@ResourceResult int;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @ResourceLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @ResourceResult=sys.sp_getapplock @Resource=@ResourceLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @ResourceResult<0 THROW 51700,''Resource admission busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK)
    WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion
    AND (@Purpose=''probe'' OR BlockedReason IS NULL)
    AND ((@Purpose=''probe'' AND OwnerID IS NULL AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
     OR (OwnerID=@OwnerID AND Fence=@Fence AND ((@OwnerKind=''job'' AND ActiveJobID=@ObjectID AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''preparation'' AND ActivePreparationID=@ObjectID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''operation'' AND ActiveOutputOperationID=@ObjectID AND ActiveJobID IS NULL AND ActivePreparationID IS NULL)))))
   THROW 51700,''Resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;
 IF @Purpose=''enrollment'' AND @OwnerKind<>''preparation'' THROW 51700,''Enrollment requires its preparation owner.'',1;
 IF @OwnerKind=''job''
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
   AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'')))
   AND ((PoolEpoch IS NULL AND @Epoch IS NULL) OR PoolEpoch=@Epoch)
   AND ((@NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'') IS NULL)
      OR (@NestedToken IS NOT NULL AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.token''))=@NestedToken
       AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''owned''
       AND (TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion
        OR (@Purpose=''probe'' AND State=''uncertain'' AND @ClaimVersion>1
         AND TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion-1)))
      OR (@Purpose=''probe'' AND @NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''complete'')))
   THROW 51700,''Job/nested owner CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID)
   THROW 51700,''Job membership conflict.'',1;
 END
 ELSE IF @OwnerKind=''preparation''
 BEGIN
  IF @NestedToken IS NOT NULL OR @Epoch IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion AND (@Purpose=''probe'' OR State=''preflight''))
   THROW 51700,''Preparation CAS conflict.'',1;

  DECLARE @EnrollmentPlan nvarchar(max),@EnrollmentProgress nvarchar(max),@EnrollmentHash binary(32);
  SELECT @EnrollmentPlan=RequestJson,@EnrollmentProgress=GenerationJson,@EnrollmentHash=RequestHash
   FROM dbo.ExportPreparation WHERE PreparationID=@ObjectID;
  IF @Purpose=''enrollment''
  BEGIN
   IF JSON_VALUE(@EnrollmentPlan,''$.purpose'') IS NULL OR JSON_VALUE(@EnrollmentPlan,''$.purpose'')<>''output_enrollment''
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id'')) IS NULL
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id''))<>@SessionID
    OR @RegistrationHash<>@EnrollmentHash OR @SnapshotHash<>@EnrollmentHash
    OR @EnrollmentHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@EnrollmentPlan))
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson))<>2
    OR JSON_QUERY(@ScopeJson,''$.enrollment'') IS NULL
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'') IS NULL
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') IS NULL
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>JSON_VALUE(@EnrollmentProgress,''$.phase'')
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal''))<>TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal''))
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') NOT IN (''create'',''verify'')
    THROW 51700,''Exact authority-side enrollment phase required.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    THROW 51700,''Enrollment phase already has a stream; never replay.'',1;
  END
  ELSE IF JSON_VALUE(@EnrollmentPlan,''$.purpose'')=''output_enrollment''
   THROW 51700,''Enrollment cannot become ordinary configuration authority.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID)
   THROW 51700,''Preparation membership conflict.'',1;
 END
 ELSE
 BEGIN
  -- Pool lock follows resource locks, matching the Bot''s operation DAL.
  DECLARE @PoolID uniqueidentifier,@PoolLock nvarchar(255),@PoolLockResult int;
  SELECT @PoolID=PoolID FROM KVK.SourceOutputOperation WHERE OperationID=@ObjectID AND AccountKey=@AccountKey;
  IF @PoolID IS NULL THROW 51700,''Output operation pool is unavailable.'',1;
  SET @PoolLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @PoolLockResult=sys.sp_getapplock @Resource=@PoolLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @PoolLockResult<0 THROW 51700,''Output operation pool busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM KVK.SourceOutputPool WITH (UPDLOCK,HOLDLOCK)
   WHERE PoolID=@PoolID AND AccountKey=@AccountKey AND PoolState=''closing''
    AND OwnerID=@ObjectID AND Epoch=@Epoch AND RegistrationHash=@RegistrationHash)
   THROW 51700,''Output operation registration/epoch changed.'',1;
  IF @NestedToken IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM KVK.SourceOutputOperation WITH (UPDLOCK,HOLDLOCK) WHERE OperationID=@ObjectID AND AccountKey=@AccountKey
    AND PoolID=@PoolID AND Fence=@Fence AND Version=@ClaimVersion AND OldEpoch=@Epoch
    AND ((OwnerID=@OwnerID AND (@Purpose=''probe'' OR State=''running''))
      OR (@Purpose=''probe'' AND @OwnerID IS NULL AND OwnerID IS NULL AND Fence=0 AND State=''closing'' AND Phase=''draining'')))
   THROW 51700,''Output operation CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID)
   THROW 51700,''Output operation membership conflict.'',1;
 END;

 END;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

 DECLARE @StreamState varchar(16),@LastSequence bigint,@Version bigint;
 SELECT @StreamState=State,@LastSequence=LastSequence,@Version=Version
 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK)
 WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey;
 IF @ExpectedVersion IS NULL OR @Version IS NULL OR @Version<>@ExpectedVersion OR @StreamState=''closed''
  THROW 51700,''Request stream CAS lost or closed.'',1;
 IF @State IS NULL OR DATALENGTH(@State)<>LEN(@State) THROW 51700,''Canonical event state required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE EventID=@EventID)
  THROW 51700,''Event already exists; read immutable event before retry.'',1;
 DECLARE @Previous varchar(32),@EventSequence int;
 IF @State=''prepared''
 BEGIN
  IF @StreamState<>''open'' OR (@Purpose=''probe'' AND @RequestKind<>''read'')
   THROW 51700,''Stream cannot prepare this request.'',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID AND NOT EXISTS
    (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'',''unknown'')))
   THROW 51700,''Only one outstanding request per stream.'',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
   WHERE r.StreamID=@StreamID AND r.RequestKind=''mutation'' AND e.State=''unknown'')
   THROW 51700,''Unknown mutation requires reconciliation.'',1;
  IF @Operation=''sheets.create''
  BEGIN
   IF @Purpose<>''enrollment'' OR @RequestKind<>''mutation'' OR @OwnerKind<>''preparation''
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>''create''
    OR @TargetID<>LOWER(CONVERT(varchar(36),@ObjectID)) OR DATALENGTH(@TargetID)<>36
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID)
    THROW 51700,''Only one fixed create per fresh enrollment phase.'',1;
  END
  ELSE
  BEGIN
   IF NOT EXISTS (SELECT 1 FROM OPENJSON(@ScopeJson,''$.resources'') WITH (ResourceKey varchar(256) ''$.key'') WHERE ResourceKey=''destination:''+@TargetID)
    THROW 51700,''Request target is outside owned resources.'',1;
   IF @Purpose=''enrollment'' AND (JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>''verify''
    OR @Operation NOT IN (''drive.permissions.create'',''drive.files.get'',''drive.permissions.list'',''sheets.get'',''sheets.values.batchGet''))
    THROW 51700,''Enrollment permits only Editor grant and fixed readback.'',1;
   IF @Purpose=''enrollment'' AND @Operation=''drive.permissions.create''
    AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID AND TargetID=@TargetID AND Operation=@Operation)
    THROW 51700,''Editor grant cannot be replayed.'',1;
  END;
  INSERT dbo.ExportProviderRequest VALUES (@RequestID,@StreamID,@LastSequence+1,@Operation,@RequestKind,@TargetID,@PayloadHash,@PayloadReference,SYSUTCDATETIME());
  SET @EventSequence=1;
  UPDATE dbo.ExportExecutionStream SET LastSequence=LastSequence+1 WHERE StreamID=@StreamID;
 END
 ELSE
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequest WHERE RequestID=@RequestID AND StreamID=@StreamID)
   THROW 51700,''Request identity differs.'',1;
  IF @State=''dispatch_intent'' AND @OwnerKind=''job''
   AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE RequestID=@RequestID AND RequestKind=''mutation'')
   AND NOT EXISTS(SELECT 1 FROM dbo.ExportAttempt WHERE JobID=@ObjectID AND OwnerID=@OwnerID AND Fence=@Fence AND Phase IN (''private_started'',''verified'',''publication_pending''))
   THROW 51700,''A durable owned attempt must precede mutation dispatch.'',1;
  SELECT TOP(1) @Previous=State,@EventSequence=EventSequence+1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=@RequestID ORDER BY EventSequence DESC;
  IF NOT ((@Previous=''prepared'' AND @State=''not_sent'') OR (@Previous=''prepared'' AND @State=''dispatch_intent'' AND @StreamState=''open'')
    OR (@Previous=''dispatch_intent'' AND @State IN (''succeeded'',''unknown'')))
   OR @Previous IS NULL THROW 51700,''Invalid or terminal request transition; never replay.'',1;
 END;
 INSERT dbo.ExportProviderRequestEvent VALUES (@EventID,@RequestID,@EventSequence,@State,@EvidenceHash,@EvidenceReference,SYSUTCDATETIME());
 UPDATE dbo.ExportExecutionStream SET Version=Version+1 WHERE StreamID=@StreamID;
 SELECT * FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
 EXEC sys.sp_executesql N'CREATE PROCEDURE dbo.usp_ExportReconciliationProofIssue
 @SessionID uniqueidentifier,
 @ProofID uniqueidentifier,
 @AccountKey varchar(128),
 @SnapshotHash binary(32),
 @RegistrationHash binary(32),
 @ProofKind varchar(32),
 @Outcome varchar(16),
 @MembershipJson nvarchar(max),
 @EvidenceJson nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

 IF @MembershipJson IS NULL OR ISJSON(@MembershipJson)<>1 OR DATALENGTH(@MembershipJson)>65536
 OR @EvidenceJson IS NULL OR ISJSON(@EvidenceJson)<>1 OR DATALENGTH(@EvidenceJson)>65536
  THROW 51700,''Bounded proof evidence required.'',1;
 IF JSON_VALUE(@EvidenceJson,''$.state'') IS NULL OR JSON_VALUE(@EvidenceJson,''$.snapshot_hash'') IS NULL
 OR JSON_VALUE(@EvidenceJson,''$.state'') COLLATE Latin1_General_100_BIN2<>@Outcome COLLATE Latin1_General_100_BIN2
 OR JSON_VALUE(@EvidenceJson,''$.snapshot_hash'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(64),@SnapshotHash,2)) COLLATE Latin1_General_100_BIN2
  THROW 51700,''Proof body differs from immutable outcome/snapshot.'',1;
 -- v2 seals the complete registered-file catalogue without truncating retained
 -- history into a bounded stream-ID list. Parent verifies each private journal.
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson))<>4
 OR EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key] NOT IN (''version'',''targets'',''history'',''probe''))
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson))<>4
 OR JSON_VALUE(@MembershipJson,''$.version'') IS NULL OR JSON_VALUE(@MembershipJson,''$.version'')<>''2''
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''version'' AND type=2)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''targets'' AND type=4)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''history'' AND type=5)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''probe'' AND type=5)
  THROW 51700,''Versioned complete catalogue membership required.'',1;
 DECLARE @Targets TABLE (FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY);
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.targets'')) NOT BETWEEN 1 AND 17
 OR EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.targets'') WHERE type<>1 OR DATALENGTH(value) NOT BETWEEN 6 AND 256
  OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_-]%'')
  THROW 51700,''Bounded exact registered targets required.'',1;
 IF EXISTS (SELECT 1 FROM (SELECT value,LAG(value) OVER (ORDER BY CONVERT(int,[key])) AS Previous
  FROM OPENJSON(@MembershipJson,''$.targets'')) q WHERE Previous COLLATE Latin1_General_100_BIN2>=value COLLATE Latin1_General_100_BIN2)
  THROW 51700,''Targets must be unique and canonically ordered.'',1;
 INSERT @Targets SELECT CONVERT(varchar(128),value) FROM OPENJSON(@MembershipJson,''$.targets'');
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.history''))<>2
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson,''$.history''))<>2
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.history'') WHERE [key]=''count'' AND type=2)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.history'') WHERE [key]=''sha256'' AND type=1)
 OR (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.probe''))<>2
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson,''$.probe''))<>2
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.probe'') WHERE [key]=''stream_id'' AND type=1)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.probe'') WHERE [key]=''version'' AND type=2)
  THROW 51700,''Exact history seal and fresh probe identity required.'',1;
 DECLARE @ExpectedCount bigint=TRY_CONVERT(bigint,JSON_VALUE(@MembershipJson,''$.history.count'')),
  @HistoryHashText nvarchar(4000)=JSON_VALUE(@MembershipJson,''$.history.sha256''),
  @ProbeID uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@MembershipJson,''$.probe.stream_id'')),
  @ProbeVersion bigint=TRY_CONVERT(bigint,JSON_VALUE(@MembershipJson,''$.probe.version''));
 IF @ExpectedCount IS NULL OR @ExpectedCount<0 OR @ProbeID IS NULL OR @ProbeVersion IS NULL OR @ProbeVersion<=0
 OR @HistoryHashText IS NULL OR DATALENGTH(@HistoryHashText)<>128 OR @HistoryHashText COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
 OR DATALENGTH(JSON_VALUE(@MembershipJson,''$.probe.stream_id''))<>72
 OR JSON_VALUE(@MembershipJson,''$.probe.stream_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),@ProbeID)) COLLATE Latin1_General_100_BIN2
  THROW 51700,''Canonical historical count/hash and probe identity required.'',1;
 -- A blank current file is not a creation history. Only sealed managed origins
 -- can enter automatic finality. Old/unproven files remain operator reconciliation.
 IF EXISTS(SELECT 1 FROM @Targets t WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o
   JOIN dbo.ExportPreparation p ON p.PreparationID=o.PreparationID
   WHERE o.FileID=t.FileID AND o.Stage=''eligible'' AND p.AccountKey=@AccountKey AND p.State=''completed''))
  THROW 51700,''Complete authenticated managed-file origins required.'',1;
 DECLARE @Members TABLE (StreamID uniqueidentifier NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 INSERT @Members SELECT s.StreamID,s.Version FROM dbo.ExportExecutionStream s WITH (UPDLOCK,HOLDLOCK)
 WHERE s.AccountKey=@AccountKey AND (EXISTS (SELECT 1 FROM OPENJSON(s.ScopeJson,''$.resources'')
  WITH (ResourceKey varchar(256) ''$.key'') r JOIN @Targets t
  ON r.ResourceKey COLLATE Latin1_General_100_BIN2=(''destination:''+t.FileID) COLLATE Latin1_General_100_BIN2)
 OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o JOIN @Targets t ON t.FileID=o.FileID
  WHERE o.PreparationID=s.PreparationID AND o.Stage=''created''));
 IF NOT EXISTS (SELECT 1 FROM @Members) THROW 51700,''Empty evidence is not proof of historical coverage.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.State<>''closed'' OR s.ActiveAccountKey IS NOT NULL OR s.ClosureHash IS NULL OR s.EventDigest IS NULL)
  THROW 51700,''Exact closed request-stream membership required.'',1;
 DECLARE @CatalogueHash binary(32)=HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),''K98-S11-CATALOGUE-1'')),
  @CatalogueCount bigint=0,@CatalogueID uniqueidentifier,@CatalogueVersion bigint,@CatalogueEvents binary(32);
 DECLARE CatalogueRows CURSOR LOCAL FAST_FORWARD FOR
 SELECT s.StreamID,s.Version,s.EventDigest FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
 WHERE s.StreamID<>@ProbeID ORDER BY LOWER(CONVERT(varchar(36),s.StreamID)) COLLATE Latin1_General_100_BIN2;
 OPEN CatalogueRows;
 FETCH NEXT FROM CatalogueRows INTO @CatalogueID,@CatalogueVersion,@CatalogueEvents;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @CatalogueHash=HASHBYTES(''SHA2_256'',@CatalogueHash+CONVERT(varbinary(max),LOWER(CONVERT(varchar(36),@CatalogueID)))
   +CONVERT(varbinary(max),'':''+CONVERT(varchar(20),@CatalogueVersion)+'':'')+@CatalogueEvents);
  SET @CatalogueCount=@CatalogueCount+1;
  FETCH NEXT FROM CatalogueRows INTO @CatalogueID,@CatalogueVersion,@CatalogueEvents;
 END;
 CLOSE CatalogueRows;
 DEALLOCATE CatalogueRows;
 IF @CatalogueCount<>@ExpectedCount OR @CatalogueHash<>CONVERT(binary(32),@HistoryHashText,2)
  THROW 51700,''Historical writer catalogue changed around the fresh probe.'',1;
 IF NOT EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.StreamID=@ProbeID AND s.Version=@ProbeVersion AND s.Purpose=''probe''
   AND s.SnapshotHash=@SnapshotHash AND s.RegistrationHash=@RegistrationHash
   AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
     WHERE r.StreamID=s.StreamID AND r.RequestKind=''read'' AND e.State=''succeeded''))
  THROW 51700,''Fresh snapshot-bound closed probe required.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportProviderRequest r ON r.StreamID=m.StreamID
   WHERE NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'')))
  THROW 51700,''Request gaps or unknown outcomes cannot become proof.'',1;
 -- Older successful jobs stay in the complete catalogue, but do not imply that
 -- this publication dispatched a mutation. Cover every stream of its exact job,
 -- including former nested owners, even outside the current registered target set.
 DECLARE @SubjectJob uniqueidentifier=(SELECT JobID FROM dbo.ExportExecutionStream WHERE StreamID=@ProbeID);
 IF @Outcome=''absent'' AND (@ProofKind<>''publication'' OR @SubjectJob IS NULL)
  THROW 51700,''Absence requires an exact publication-job probe.'',1;
 IF @Outcome=''absent'' AND EXISTS (SELECT 1 FROM dbo.ExportExecutionStream s
   JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
   JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
   WHERE s.AccountKey=@AccountKey AND s.JobID=@SubjectJob AND r.RequestKind=''mutation'' AND e.State=''dispatch_intent'')
  THROW 51700,''Dispatched mutation cannot support absence proof.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  THROW 51700,''A live provider writer/probe prevents proof issue.'',1;
 -- Parent authority must attest COMPLETE historical writer coverage and exact
 -- method-specific readback; SQL does not infer provider truth from row presence.
 INSERT dbo.ExportReconciliationProof VALUES (@ProofID,@SessionID,@AccountKey,@SnapshotHash,@RegistrationHash,@ProofKind,@Outcome,
  HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@MembershipJson)),@MembershipJson,@EvidenceJson,SYSUTCDATETIME());
 SELECT * FROM dbo.ExportReconciliationProof WHERE ProofID=@ProofID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
 EXEC sys.sp_executesql N'CREATE PROCEDURE dbo.usp_ExportOutputEnrollmentTransition
 @SessionID uniqueidentifier,
 @PreparationID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @AccountKey varchar(128),
 @OwnerID uniqueidentifier,
 @Fence bigint=NULL,
 @ResourcesJson nvarchar(max)=NULL,
 @PlanJson nvarchar(max)=NULL,
 @Actor nvarchar(128)=NULL,
 @Reason nvarchar(1024)=NULL,
 @Ordinal int=NULL,
 @FileID varchar(128)=NULL,
 @CreationStreamID uniqueidentifier=NULL,
 @CreationRequestID uniqueidentifier=NULL,
 @ResponseEventID uniqueidentifier=NULL,
 @OriginHash binary(32)=NULL,
 @OriginReference uniqueidentifier=NULL,
 @VerificationStreamID uniqueidentifier=NULL,
 @EligibilityHash binary(32)=NULL,
 @EligibilityReference uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Enrollment requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51700,''Evidence authority role required.'',1;
 IF @AccountKey IS NULL OR DATALENGTH(@AccountKey) NOT BETWEEN 1 AND 128
 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey) OR @AccountKey LIKE ''%[^A-Za-z0-9_.@:-]%'' COLLATE Latin1_General_100_BIN2
 OR @OwnerID IS NULL OR @PreparationID IS NULL OR @ExpectedVersion IS NULL
 OR @Action IS NULL OR DATALENGTH(@Action)<>LEN(@Action) OR @Action NOT IN (''begin'',''bind'',''complete'')
  THROW 51700,''Canonical enrollment identity required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255),@AccountResource varchar(256)=''account:''+@AccountKey;
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@AccountResource),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
  THROW 51700,''Exact open authority session required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  THROW 51700,''Enrollment requires closed owned children.'',1;

 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF @Action=''begin''
 BEGIN
  IF @ExpectedVersion<>0 OR @Fence IS NOT NULL OR @ResourcesJson IS NOT NULL
   OR @PlanJson IS NULL OR ISJSON(@PlanJson)<>1 OR DATALENGTH(@PlanJson)>65536
   OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
   THROW 51700,''Fresh protected enrollment plan required.'',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@PlanJson))<>11 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@PlanJson))<>11
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''purpose'',''account'',''storage_owner'',''owner_email'',''editor_email'',''project_id'',''credential_profile_sha256'',''manifest_sha256'',''file_count'',''plan_id''))
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''version'' AND type=2 AND value=''1'')
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''file_count'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 3 AND 17 AND value=CONVERT(varchar(2),TRY_CONVERT(int,value)))
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''file_count'') AND (type<>1 OR LEN(value)=0))
   OR JSON_VALUE(@PlanJson,''$.purpose'') COLLATE Latin1_General_100_BIN2<>''output_enrollment''
   OR JSON_VALUE(@PlanJson,''$.account'') COLLATE Latin1_General_100_BIN2<>@AccountKey COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.account''))<>2*DATALENGTH(@AccountKey)
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.purpose''))<>34
   OR JSON_VALUE(@PlanJson,''$.storage_owner'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_.@:-]%''
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.storage_owner'')) NOT BETWEEN 2 AND 256
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id'')) IS NULL
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.plan_id''))<>72
   OR JSON_VALUE(@PlanJson,''$.plan_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id'')))) COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.credential_profile_sha256''))<>128
   OR JSON_VALUE(@PlanJson,''$.credential_profile_sha256'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.manifest_sha256''))<>128
   OR JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
   OR NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID AND LOWER(CONVERT(varchar(64),ManifestHash,2)) COLLATE Latin1_General_100_BIN2=JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2)
   THROW 51700,''Exact typed enrollment plan differs.'',1;
  -- New enrollment never overtakes existing ready work or bypasses uncertainty.
  IF EXISTS (SELECT 1 FROM dbo.ExportJob WHERE AccountKey=@AccountKey AND State IN (''ready'',''running'',''uncertain''))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN (''pending'',''preflight'',''sql_pending'',''writing'',''committed'',''uncertain''))
   OR EXISTS (SELECT 1 FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey AND State IN (''closing'',''ready'',''running'',''uncertain''))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE PreparationID=@PreparationID OR (AccountKey=@AccountKey AND RequestHash=HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson))))
   THROW 51700,''Existing work or enrollment prevents fresh admission.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK) WHERE ResourceKey=@AccountResource)
   INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version) VALUES(@AccountResource,''account'',0,1);
  INSERT @Resources SELECT ResourceKey,Version FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
 END
 ELSE
 BEGIN
  IF @PlanJson IS NOT NULL OR @ResourcesJson IS NULL OR ISJSON(@ResourcesJson)<>1 OR DATALENGTH(@ResourcesJson)>65536
   OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion<=0
   THROW 51700,''Exact enrollment CAS resources required.'',1;
  IF LEFT(LTRIM(@ResourcesJson),1)<>''['' OR (SELECT COUNT(*) FROM OPENJSON(@ResourcesJson)) NOT BETWEEN 1 AND 18
   OR EXISTS(SELECT 1 FROM OPENJSON(@ResourcesJson) j WHERE j.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>2
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''key'' AND type=1)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''version'' AND type=2))
   THROW 51700,''Exact resource-version list required.'',1;
  INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ResourcesJson) WITH(ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
  IF EXISTS(SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID)
   OR NOT EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey=@AccountResource)
   THROW 51700,''Enrollment resource membership changed.'',1;
 END;
 -- A newly returned identity must have no resource/origin/registration history.
 IF @Action=''bind''
 BEGIN
  IF @FileID IS NULL OR DATALENGTH(@FileID) NOT BETWEEN 3 AND 128 OR DATALENGTH(@FileID)<>LEN(@FileID)
   OR @FileID LIKE ''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2
   OR @Ordinal IS NULL OR @Ordinal NOT BETWEEN 0 AND 16 OR @OriginHash IS NULL OR @OriginReference IS NULL
   THROW 51700,''Exact newly returned file and origin receipt required.'',1;
  INSERT @Resources VALUES(''destination:''+@FileID,0);
 END;
 DECLARE @Key varchar(256),@ResourceVersion bigint;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @Key,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@Key),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51700,''Enrollment resource busy.'',1;
  IF @ResourceVersion=0
  BEGIN
   IF EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key)
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=@FileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=@FileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=@FileID)
    THROW 51700,''Returned identity has existing history; never adopt.'',1;
  END
  ELSE IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key AND Version=@ResourceVersion AND BlockedReason IS NULL
   AND ((@Action=''begin'' AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL)
    OR (@Action<>''begin'' AND ActivePreparationID=@PreparationID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID=@OwnerID AND Fence=@Fence)))
   THROW 51700,''Enrollment resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @Key,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;

 DECLARE @Plan nvarchar(max),@Progress nvarchar(max),@PlanHash binary(32),@Count int,@Next int;
 IF @Action=''begin''
 BEGIN
  -- Count registered pools and still-unregistered enrollment plans once each.
  -- Range locks prevent concurrent enrollment/registration from overbooking eight.
  IF (SELECT COUNT_BIG(*) FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK))+
   (SELECT COUNT_BIG(*) FROM dbo.ExportPreparation p WITH(UPDLOCK,HOLDLOCK)
    WHERE JSON_VALUE(p.RequestJson,''$.purpose'')=''output_enrollment''
     AND NOT EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o JOIN KVK.SourceOutputPool pool ON pool.IndexFileID=o.FileID
      WHERE o.PreparationID=p.PreparationID AND o.Stage=''eligible'' AND o.Ordinal=0))>=8
   THROW 51700,''Eight-pool enrollment capacity is exhausted.'',1;
  SELECT @Fence=Fence+1 FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
  DECLARE @Ticket bigint=(SELECT ISNULL(MAX(Ticket),0)+1 FROM
   (SELECT EnqueueSequence Ticket FROM dbo.ExportJob WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey) q);
  SET @Progress=N''{"session_id":"''+LOWER(CONVERT(nvarchar(36),@SessionID))+N''","phase":"create","next_ordinal":0}'';
  INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,KVK_NO,RequestHash,EnqueueSequence,State,OwnerID,Fence,Version,StorageOwner,RequestJson,GenerationJson,Actor,Reason,CreatedUTC,UpdatedUTC)
   VALUES(@PreparationID,@AccountKey,''config'',NULL,HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson)),@Ticket,''preflight'',@OwnerID,@Fence,1,JSON_VALUE(@PlanJson,''$.storage_owner''),@PlanJson,@Progress,@Actor,@Reason,SYSUTCDATETIME(),SYSUTCDATETIME());
  INSERT dbo.ExportPreparationResource VALUES(@PreparationID,@AccountResource);
  UPDATE dbo.ExportResource SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=Version+1 WHERE ResourceKey=@AccountResource;
 END
 ELSE
 BEGIN
  SELECT @Plan=RequestJson,@PlanHash=RequestHash,@Progress=GenerationJson FROM dbo.ExportPreparation WITH(UPDLOCK,HOLDLOCK)
   WHERE PreparationID=@PreparationID AND AccountKey=@AccountKey AND ConsumerKind=''config'' AND State=''preflight''
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ExpectedVersion AND JobID IS NULL AND SpoolKey IS NULL
    AND JSON_VALUE(RequestJson,''$.purpose'')=''output_enrollment''
    AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(GenerationJson,''$.session_id''))=@SessionID;
  IF @Plan IS NULL OR @PlanHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@Plan))
   THROW 51700,''Enrollment preparation identity/CAS differs; no adoption.'',1;
  SET @Count=TRY_CONVERT(int,JSON_VALUE(@Plan,''$.file_count''));
  SET @Next=TRY_CONVERT(int,JSON_VALUE(@Progress,''$.next_ordinal''));
  IF @Count IS NULL OR @Count NOT BETWEEN 3 AND 17 OR @Next IS NULL
   THROW 51700,''Enrollment plan/progress differs.'',1;
  IF @Action=''bind''
  BEGIN
   IF @Next<>@Ordinal OR @Next>=@Count OR JSON_VALUE(@Progress,''$.phase'')<>''create''
    OR (SELECT COUNT(*) FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'')<>@Ordinal
    THROW 51700,''Creation ordinal is not the next fresh identity.'',1;
   DECLARE @ResponseHash binary(32),@ClosureHash binary(32);
   SELECT @ResponseHash=e.EvidenceHash,@ClosureHash=s.ClosureHash
    FROM dbo.ExportExecutionStream s JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
    JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
    WHERE s.StreamID=@CreationStreamID AND s.SessionID=@SessionID AND s.PreparationID=@PreparationID
     AND s.AccountKey=@AccountKey AND s.OwnerID=@OwnerID AND s.Fence=@Fence AND s.ClaimVersion=@ExpectedVersion
     AND s.Purpose=''enrollment'' AND s.State=''closed'' AND s.ActiveAccountKey IS NULL AND s.LastSequence=1
     AND s.RegistrationHash=@PlanHash AND s.SnapshotHash=@PlanHash AND s.EventDigest IS NOT NULL
     AND JSON_VALUE(s.ScopeJson,''$.enrollment.phase'')=''create''
     AND TRY_CONVERT(int,JSON_VALUE(s.ScopeJson,''$.enrollment.ordinal''))=@Ordinal
     AND r.RequestID=@CreationRequestID AND r.Sequence=1 AND r.Operation=''sheets.create'' AND r.RequestKind=''mutation''
     AND r.TargetID=LOWER(CONVERT(varchar(36),@PreparationID))
     AND e.EventID=@ResponseEventID AND e.State=''succeeded'' AND e.EventSequence=3;
   IF @ResponseHash IS NULL OR @ClosureHash IS NULL THROW 51700,''Exact successful closed creation required.'',1;
   INSERT dbo.ExportManagedFileOrigin(FileID,Stage,PreparationID,Ordinal,SessionID,CreationStreamID,CreationRequestID,ResponseEventID,PlanHash,ProfileHash,ResponseHash,CreationClosureHash,OriginHash,OriginReference,CreatedUTC)
    VALUES(@FileID,''created'',@PreparationID,@Ordinal,@SessionID,@CreationStreamID,@CreationRequestID,@ResponseEventID,@PlanHash,CONVERT(binary(32),JSON_VALUE(@Plan,''$.credential_profile_sha256''),2),@ResponseHash,@ClosureHash,@OriginHash,@OriginReference,SYSUTCDATETIME());
   INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version) VALUES(''destination:''+@FileID,''destination'',0,1);
   INSERT dbo.ExportPreparationResource VALUES(@PreparationID,''destination:''+@FileID);
   UPDATE dbo.ExportResource SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=2 WHERE ResourceKey=''destination:''+@FileID;
   SET @Progress=JSON_MODIFY(JSON_MODIFY(@Progress,''$.next_ordinal'',@Next+1),''$.phase'',CASE WHEN @Next+1=@Count THEN ''verify'' ELSE ''create'' END);
  END
  ELSE
  BEGIN
   IF @Next<>@Count OR JSON_VALUE(@Progress,''$.phase'')<>''verify'' OR @EligibilityHash IS NULL OR @EligibilityReference IS NULL
    OR (SELECT COUNT(*) FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'')<>@Count
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''eligible'')
    THROW 51700,''Complete unsealed origin set required.'',1;
   DECLARE @VerificationClosure binary(32);
   SELECT @VerificationClosure=ClosureHash FROM dbo.ExportExecutionStream
    WHERE StreamID=@VerificationStreamID AND SessionID=@SessionID AND PreparationID=@PreparationID
     AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND ClaimVersion=@ExpectedVersion
     AND Purpose=''enrollment'' AND State=''closed'' AND ActiveAccountKey IS NULL AND EventDigest IS NOT NULL
     AND RegistrationHash=@PlanHash AND SnapshotHash=@PlanHash AND JSON_VALUE(ScopeJson,''$.enrollment.phase'')=''verify'';
   IF @VerificationClosure IS NULL OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s
     WHERE s.PreparationID=@PreparationID AND (s.State<>''closed'' OR s.ClosureHash IS NULL OR s.EventDigest IS NULL))
    OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
     WHERE s.PreparationID=@PreparationID AND NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State=''succeeded''))
    THROW 51700,''Enrollment history contains unclosed or uncertain requests.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o CROSS JOIN
     (VALUES(''drive.permissions.create''),(''drive.files.get''),(''drive.permissions.list''),(''sheets.get''),(''sheets.values.batchGet'')) m(Operation)
     WHERE o.PreparationID=@PreparationID AND o.Stage=''created'' AND NOT EXISTS
      (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@VerificationStreamID AND r.TargetID=o.FileID AND r.Operation=m.Operation))
    THROW 51700,''Every origin requires grant and complete fixed readback.'',1;
   -- Parent verifies private response bytes, exact owner/editor and all blank cells.
   -- SQL seals that receipt only after the complete request history has terminated.
   INSERT dbo.ExportManagedFileOrigin
    SELECT FileID,''eligible'',''created'',PreparationID,Ordinal,SessionID,CreationStreamID,CreationRequestID,ResponseEventID,PlanHash,ProfileHash,ResponseHash,CreationClosureHash,OriginHash,OriginReference,@VerificationStreamID,@VerificationClosure,@EligibilityHash,@EligibilityReference,SYSUTCDATETIME()
    FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'';
   SET @Progress=JSON_MODIFY(@Progress,''$.phase'',''complete'');
   UPDATE r SET ActivePreparationID=NULL,OwnerID=NULL,Version=r.Version+1
    FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey;
  END;
  UPDATE dbo.ExportPreparation SET GenerationJson=@Progress,State=CASE WHEN @Action=''complete'' THEN ''completed'' ELSE ''preflight'' END,Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PreparationID=@PreparationID AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ExpectedVersion;
  IF @@ROWCOUNT<>1 THROW 51700,''Enrollment preparation CAS lost.'',1;
 END;
 SELECT p.*,(SELECT r.ResourceKey AS [key],r.Version AS [version] FROM dbo.ExportPreparationResource m
  JOIN dbo.ExportResource r ON r.ResourceKey=m.ResourceKey WHERE m.PreparationID=p.PreparationID ORDER BY r.ResourceKey FOR JSON PATH) AS ResourcesJson
 FROM dbo.ExportPreparation p WHERE p.PreparationID=@PreparationID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
END;
INSERT @S11Map VALUES
(N'dbo.ExportExecutionSession',OBJECT_ID(N'dbo.ExportExecutionSession',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportExecutionSession')),
(N'dbo.ExportExecutionStream',OBJECT_ID(N'dbo.ExportExecutionStream',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportExecutionStream')),
(N'dbo.ExportProviderRequest',OBJECT_ID(N'dbo.ExportProviderRequest',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportProviderRequest')),
(N'dbo.ExportProviderRequestEvent',OBJECT_ID(N'dbo.ExportProviderRequestEvent',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportProviderRequestEvent')),
(N'dbo.ExportReconciliationProof',OBJECT_ID(N'dbo.ExportReconciliationProof',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportReconciliationProof')),
(N'dbo.ExportManagedFileOrigin',OBJECT_ID(N'dbo.ExportManagedFileOrigin',N'U'),OBJECT_ID(N'tempdb..#S11_dbo_ExportManagedFileOrigin'));
IF EXISTS(SELECT 1 FROM @S11Map WHERE ActualID IS NULL) THROW 51700,'S11 object type conflict.',1;
-- EXCEPT in both directions rejects missing, extra, disabled, untrusted or altered shape.
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S11Map m JOIN sys.columns c ON c.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S11Map m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S11Map m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @S11Map m JOIN sys.columns c ON c.object_id=m.ActualID)
    THROW 51700, 'S11 column shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S11Map m JOIN sys.columns c ON c.object_id=m.ActualID WHERE c.user_type_id<>c.system_type_id) THROW 51700, 'S11 alias type conflict.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S11Map m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S11Map m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S11Map m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @S11Map m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID)
    THROW 51700, 'S11 check constraint shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN sys.indexes i ON i.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN sys.indexes i ON i.object_id=m.ActualID)
    THROW 51700, 'S11 index shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name)
    THROW 51700, 'S11 index count shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @S11Map m JOIN sys.triggers t ON t.parent_id=m.ActualID)
OR EXISTS (SELECT 1 FROM @S11Map m JOIN sys.tables t ON t.object_id=m.ActualID WHERE t.temporal_type<>0 OR t.is_memory_optimized<>0)
    THROW 51700, 'S11 unexpected default, trigger or table mode.', 1;
-- Defaults are part of the inherited contract (SourceRouting has Enabled=0).
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @S11Map m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID)
    THROW 51700, 'S11 default shape conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @S11Map m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name)
    THROW 51700, 'S11 check count conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S11Map m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
EXCEPT
SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S11FK e WHERE EXISTS (SELECT 1 FROM @S11Map m WHERE m.Name=e.ParentName))
OR EXISTS (SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @S11FK e WHERE EXISTS (SELECT 1 FROM @S11Map m WHERE m.Name=e.ParentName)
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @S11Map m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id)
    THROW 51700, 'S11 foreign key shape conflict; preserve history and forward-fix.', 1;
IF OBJECT_ID(N'dbo.usp_ExportExecutionSessionTransition',N'P') IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportExecutionSessionTransition')) IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportExecutionSessionTransition')) COLLATE Latin1_General_100_BIN2 <> N'CREATE PROCEDURE dbo.usp_ExportExecutionSessionTransition
 @SessionID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @HostIdentity varchar(128)=NULL,
 @BootID uniqueidentifier=NULL,
 @ExecutableHash binary(32)=NULL,
 @ManifestHash binary(32)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY

 DECLARE @Existing bigint;
 SELECT @Existing=Version FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK) WHERE SessionID=@SessionID;
 IF @Action=''open'' AND DATALENGTH(@Action)=4 AND @ExpectedVersion=0 AND @Existing IS NULL
 BEGIN
  INSERT dbo.ExportExecutionSession VALUES (@SessionID,USER_NAME(),@HostIdentity,@BootID,@ExecutableHash,@ManifestHash,1,''open'',1,SYSUTCDATETIME(),NULL);
 END
 ELSE IF @Action=''close'' AND DATALENGTH(@Action)=5 AND @ExpectedVersion=@Existing
 BEGIN
  IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE SessionID=@SessionID AND State<>''closed'')
    THROW 51700,''Provider stream closure is unproven.'',1;
  UPDATE dbo.ExportExecutionSession SET State=''closed'',Version=Version+1,ClosedUTC=SYSUTCDATETIME()
  WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'' AND Version=@ExpectedVersion;
  IF @@ROWCOUNT<>1 THROW 51700,''Session CAS lost.'',1;
 END
 ELSE THROW 51700,''Session action/CAS conflict; read exact identity before retry.'',1;
 SELECT * FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
' COLLATE Latin1_General_100_BIN2
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportExecutionSessionTransition') AND uses_ansi_nulls=1 AND uses_quoted_identifier=1 AND execute_as_principal_id IS NULL)
 THROW 51700,'Evidence procedure differs; forward-fix only.',1;
IF OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition',N'P') IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition')) IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition')) COLLATE Latin1_General_100_BIN2 <> N'CREATE PROCEDURE dbo.usp_ExportExecutionStreamTransition
 @SessionID uniqueidentifier,
 @StreamID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @AccountKey varchar(128),
 @OwnerKind varchar(16)=NULL,
 @ObjectID uniqueidentifier=NULL,
 @OwnerID uniqueidentifier=NULL,
 @Fence bigint=NULL,
 @ClaimVersion bigint=NULL,
 @NestedToken uniqueidentifier=NULL,
 @RegistrationHash binary(32)=NULL,
 @Epoch bigint=NULL,
 @SnapshotHash binary(32)=NULL,
 @ScopeJson nvarchar(max)=NULL,
 @Purpose varchar(16)=NULL,
 @ChildIdentity uniqueidentifier=NULL,
 @ClosureHash binary(32)=NULL,
 @ClosureReference uniqueidentifier=NULL,
 @EventDigest binary(32)=NULL,
 @LastSequence bigint=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;

 IF @Action=''open'' AND DATALENGTH(@Action)=4 AND @ExpectedVersion=0
 BEGIN

 -- Account lock precedes sorted resource locks; stream row is locked last.
 IF @AccountKey IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL OR @ClaimVersion<=0
 OR (@OwnerID IS NULL AND NOT (@OwnerKind=''operation'' AND @Purpose=''probe'' AND @Fence=0 AND @NestedToken IS NULL))
 OR (@OwnerID IS NOT NULL AND @Fence<=0)
 OR @OwnerKind NOT IN (''job'',''preparation'',''operation'') OR @OwnerKind IS NULL
 OR DATALENGTH(@OwnerKind)<>LEN(@OwnerKind) OR @ObjectID IS NULL
 OR @Purpose NOT IN (''mutation'',''probe'',''enrollment'') OR @Purpose IS NULL OR DATALENGTH(@Purpose)<>LEN(@Purpose)
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>65536
 THROW 51700,''Complete typed stream scope required.'',1;
 DECLARE @Resources TABLE (ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF JSON_QUERY(@ScopeJson,''$.resources'') IS NULL THROW 51700,''Complete resource membership required.'',1;
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ScopeJson,''$.resources'')
 WITH (ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
 IF NOT EXISTS (SELECT 1 FROM @Resources WHERE ResourceKey=''account:''+@AccountKey)
 OR (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 1 AND 1025 OR EXISTS (SELECT 1 FROM @Resources WHERE Version<=0)
 THROW 51700,''Invalid resource membership.'',1;
 IF @Purpose=''probe'' AND EXISTS (SELECT 1 FROM dbo.ExportResource r JOIN dbo.ExportPreparation p ON p.PreparationID=r.ActivePreparationID
    WHERE p.AccountKey=@AccountKey AND r.ResourceKind=''sql_snapshot'' AND r.OwnerID IS NOT NULL)
  THROW 51700,''Owned SQL producer must drain before observational probe.'',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint,@ResourceLock nvarchar(255),@ResourceResult int;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @ResourceLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @ResourceResult=sys.sp_getapplock @Resource=@ResourceLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @ResourceResult<0 THROW 51700,''Resource admission busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK)
    WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion
    AND (@Purpose=''probe'' OR BlockedReason IS NULL)
    AND ((@Purpose=''probe'' AND OwnerID IS NULL AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
     OR (OwnerID=@OwnerID AND Fence=@Fence AND ((@OwnerKind=''job'' AND ActiveJobID=@ObjectID AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''preparation'' AND ActivePreparationID=@ObjectID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''operation'' AND ActiveOutputOperationID=@ObjectID AND ActiveJobID IS NULL AND ActivePreparationID IS NULL)))))
   THROW 51700,''Resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;
 IF @Purpose=''enrollment'' AND @OwnerKind<>''preparation'' THROW 51700,''Enrollment requires its preparation owner.'',1;
 IF @OwnerKind=''job''
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
   AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'')))
   AND ((PoolEpoch IS NULL AND @Epoch IS NULL) OR PoolEpoch=@Epoch)
   AND ((@NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'') IS NULL)
      OR (@NestedToken IS NOT NULL AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.token''))=@NestedToken
       AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''owned''
       AND (TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion
        OR (@Purpose=''probe'' AND State=''uncertain'' AND @ClaimVersion>1
         AND TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion-1)))
      OR (@Purpose=''probe'' AND @NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''complete'')))
   THROW 51700,''Job/nested owner CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID)
   THROW 51700,''Job membership conflict.'',1;
 END
 ELSE IF @OwnerKind=''preparation''
 BEGIN
  IF @NestedToken IS NOT NULL OR @Epoch IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion AND (@Purpose=''probe'' OR State=''preflight''))
   THROW 51700,''Preparation CAS conflict.'',1;

  DECLARE @EnrollmentPlan nvarchar(max),@EnrollmentProgress nvarchar(max),@EnrollmentHash binary(32);
  SELECT @EnrollmentPlan=RequestJson,@EnrollmentProgress=GenerationJson,@EnrollmentHash=RequestHash
   FROM dbo.ExportPreparation WHERE PreparationID=@ObjectID;
  IF @Purpose=''enrollment''
  BEGIN
   IF JSON_VALUE(@EnrollmentPlan,''$.purpose'') IS NULL OR JSON_VALUE(@EnrollmentPlan,''$.purpose'')<>''output_enrollment''
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id'')) IS NULL
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id''))<>@SessionID
    OR @RegistrationHash<>@EnrollmentHash OR @SnapshotHash<>@EnrollmentHash
    OR @EnrollmentHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@EnrollmentPlan))
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson))<>2
    OR JSON_QUERY(@ScopeJson,''$.enrollment'') IS NULL
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'') IS NULL
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') IS NULL
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>JSON_VALUE(@EnrollmentProgress,''$.phase'')
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal''))<>TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal''))
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') NOT IN (''create'',''verify'')
    THROW 51700,''Exact authority-side enrollment phase required.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    THROW 51700,''Enrollment phase already has a stream; never replay.'',1;
  END
  ELSE IF JSON_VALUE(@EnrollmentPlan,''$.purpose'')=''output_enrollment''
   THROW 51700,''Enrollment cannot become ordinary configuration authority.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID)
   THROW 51700,''Preparation membership conflict.'',1;
 END
 ELSE
 BEGIN
  -- Pool lock follows resource locks, matching the Bot''s operation DAL.
  DECLARE @PoolID uniqueidentifier,@PoolLock nvarchar(255),@PoolLockResult int;
  SELECT @PoolID=PoolID FROM KVK.SourceOutputOperation WHERE OperationID=@ObjectID AND AccountKey=@AccountKey;
  IF @PoolID IS NULL THROW 51700,''Output operation pool is unavailable.'',1;
  SET @PoolLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @PoolLockResult=sys.sp_getapplock @Resource=@PoolLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @PoolLockResult<0 THROW 51700,''Output operation pool busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM KVK.SourceOutputPool WITH (UPDLOCK,HOLDLOCK)
   WHERE PoolID=@PoolID AND AccountKey=@AccountKey AND PoolState=''closing''
    AND OwnerID=@ObjectID AND Epoch=@Epoch AND RegistrationHash=@RegistrationHash)
   THROW 51700,''Output operation registration/epoch changed.'',1;
  IF @NestedToken IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM KVK.SourceOutputOperation WITH (UPDLOCK,HOLDLOCK) WHERE OperationID=@ObjectID AND AccountKey=@AccountKey
    AND PoolID=@PoolID AND Fence=@Fence AND Version=@ClaimVersion AND OldEpoch=@Epoch
    AND ((OwnerID=@OwnerID AND (@Purpose=''probe'' OR State=''running''))
      OR (@Purpose=''probe'' AND @OwnerID IS NULL AND OwnerID IS NULL AND Fence=0 AND State=''closing'' AND Phase=''draining'')))
   THROW 51700,''Output operation CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID)
   THROW 51700,''Output operation membership conflict.'',1;
 END;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

  IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK) WHERE StreamID=@StreamID OR ActiveAccountKey=@AccountKey)
   THROW 51700,''Stream/account already registered; no automatic adoption.'',1;
  INSERT dbo.ExportExecutionStream VALUES (@StreamID,@SessionID,@AccountKey,@AccountKey,
   CASE WHEN @OwnerKind=''job'' THEN @ObjectID END,CASE WHEN @OwnerKind=''preparation'' THEN @ObjectID END,
   CASE WHEN @OwnerKind=''operation'' THEN @ObjectID END,@OwnerID,@Fence,@ClaimVersion,@NestedToken,@RegistrationHash,
   @Epoch,@SnapshotHash,@ScopeJson,@Purpose,''open'',1,0,@ChildIdentity,NULL,NULL,NULL,SYSUTCDATETIME(),NULL);
 END
 ELSE
 BEGIN
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

  IF @Action=''freeze'' AND DATALENGTH(@Action)=6
  BEGIN
   UPDATE dbo.ExportExecutionStream SET State=''frozen'',Version=Version+1
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion AND State=''open'';
   IF @@ROWCOUNT<>1 THROW 51700,''Stream freeze CAS lost.'',1;
  END
  ELSE IF @Action=''close'' AND DATALENGTH(@Action)=5 AND @ClosureHash IS NOT NULL AND @ChildIdentity IS NOT NULL
    AND @ClosureReference IS NOT NULL AND @EventDigest IS NOT NULL AND @LastSequence IS NOT NULL
  BEGIN
   -- Trusted parent supplies OS-handle closure evidence, not a caller Boolean.
   UPDATE dbo.ExportExecutionStream SET State=''closed'',ActiveAccountKey=NULL,Version=Version+1,ClosureHash=@ClosureHash,ClosureReference=@ClosureReference,EventDigest=@EventDigest,ClosedUTC=SYSUTCDATETIME()
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion
    AND ChildIdentity=@ChildIdentity AND State=''frozen'' AND LastSequence=@LastSequence;
   IF @@ROWCOUNT<>1 THROW 51700,''Stream close CAS lost.'',1;
  END
  ELSE THROW 51700,''Unsupported stream action.'',1;
 END;
 SELECT * FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
' COLLATE Latin1_General_100_BIN2
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition') AND uses_ansi_nulls=1 AND uses_quoted_identifier=1 AND execute_as_principal_id IS NULL)
 THROW 51700,'Evidence procedure differs; forward-fix only.',1;
IF OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend',N'P') IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend')) IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend')) COLLATE Latin1_General_100_BIN2 <> N'CREATE PROCEDURE dbo.usp_ExportProviderRequestEventAppend
 @SessionID uniqueidentifier,
 @StreamID uniqueidentifier,
 @AccountKey varchar(128),
 @ExpectedVersion bigint,
 @RequestID uniqueidentifier,
 @EventID uniqueidentifier,
 @State varchar(32),
 @EvidenceHash binary(32),
 @EvidenceReference uniqueidentifier,
 @Operation varchar(64)=NULL,
 @RequestKind varchar(16)=NULL,
 @TargetID varchar(128)=NULL,
 @PayloadHash binary(32)=NULL,
 @PayloadReference uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;

 DECLARE @OwnerKind varchar(16),@ObjectID uniqueidentifier,@OwnerID uniqueidentifier,@Fence bigint,@ClaimVersion bigint,
 @NestedToken uniqueidentifier,@Epoch bigint,@ScopeJson nvarchar(max),@Purpose varchar(16),@RegistrationHash binary(32),@SnapshotHash binary(32);
 SELECT @OwnerKind=CASE WHEN JobID IS NOT NULL THEN ''job'' WHEN PreparationID IS NOT NULL THEN ''preparation'' ELSE ''operation'' END,
 @ObjectID=COALESCE(JobID,PreparationID,OutputOperationID),@OwnerID=OwnerID,@Fence=Fence,@ClaimVersion=ClaimVersion,
 @NestedToken=NestedToken,@Epoch=Epoch,@ScopeJson=ScopeJson,@Purpose=Purpose,@RegistrationHash=RegistrationHash,@SnapshotHash=SnapshotHash
 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND AccountKey=@AccountKey AND SessionID=@SessionID;

 IF @State IN (''prepared'',''dispatch_intent'')
 BEGIN

 -- Account lock precedes sorted resource locks; stream row is locked last.
 IF @AccountKey IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL OR @ClaimVersion<=0
 OR (@OwnerID IS NULL AND NOT (@OwnerKind=''operation'' AND @Purpose=''probe'' AND @Fence=0 AND @NestedToken IS NULL))
 OR (@OwnerID IS NOT NULL AND @Fence<=0)
 OR @OwnerKind NOT IN (''job'',''preparation'',''operation'') OR @OwnerKind IS NULL
 OR DATALENGTH(@OwnerKind)<>LEN(@OwnerKind) OR @ObjectID IS NULL
 OR @Purpose NOT IN (''mutation'',''probe'',''enrollment'') OR @Purpose IS NULL OR DATALENGTH(@Purpose)<>LEN(@Purpose)
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>65536
 THROW 51700,''Complete typed stream scope required.'',1;
 DECLARE @Resources TABLE (ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF JSON_QUERY(@ScopeJson,''$.resources'') IS NULL THROW 51700,''Complete resource membership required.'',1;
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ScopeJson,''$.resources'')
 WITH (ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
 IF NOT EXISTS (SELECT 1 FROM @Resources WHERE ResourceKey=''account:''+@AccountKey)
 OR (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 1 AND 1025 OR EXISTS (SELECT 1 FROM @Resources WHERE Version<=0)
 THROW 51700,''Invalid resource membership.'',1;
 IF @Purpose=''probe'' AND EXISTS (SELECT 1 FROM dbo.ExportResource r JOIN dbo.ExportPreparation p ON p.PreparationID=r.ActivePreparationID
    WHERE p.AccountKey=@AccountKey AND r.ResourceKind=''sql_snapshot'' AND r.OwnerID IS NOT NULL)
  THROW 51700,''Owned SQL producer must drain before observational probe.'',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint,@ResourceLock nvarchar(255),@ResourceResult int;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @ResourceLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @ResourceResult=sys.sp_getapplock @Resource=@ResourceLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @ResourceResult<0 THROW 51700,''Resource admission busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK)
    WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion
    AND (@Purpose=''probe'' OR BlockedReason IS NULL)
    AND ((@Purpose=''probe'' AND OwnerID IS NULL AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
     OR (OwnerID=@OwnerID AND Fence=@Fence AND ((@OwnerKind=''job'' AND ActiveJobID=@ObjectID AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''preparation'' AND ActivePreparationID=@ObjectID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''operation'' AND ActiveOutputOperationID=@ObjectID AND ActiveJobID IS NULL AND ActivePreparationID IS NULL)))))
   THROW 51700,''Resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;
 IF @Purpose=''enrollment'' AND @OwnerKind<>''preparation'' THROW 51700,''Enrollment requires its preparation owner.'',1;
 IF @OwnerKind=''job''
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
   AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'')))
   AND ((PoolEpoch IS NULL AND @Epoch IS NULL) OR PoolEpoch=@Epoch)
   AND ((@NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'') IS NULL)
      OR (@NestedToken IS NOT NULL AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.token''))=@NestedToken
       AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''owned''
       AND (TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion
        OR (@Purpose=''probe'' AND State=''uncertain'' AND @ClaimVersion>1
         AND TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion-1)))
      OR (@Purpose=''probe'' AND @NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''complete'')))
   THROW 51700,''Job/nested owner CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID)
   THROW 51700,''Job membership conflict.'',1;
 END
 ELSE IF @OwnerKind=''preparation''
 BEGIN
  IF @NestedToken IS NOT NULL OR @Epoch IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion AND (@Purpose=''probe'' OR State=''preflight''))
   THROW 51700,''Preparation CAS conflict.'',1;

  DECLARE @EnrollmentPlan nvarchar(max),@EnrollmentProgress nvarchar(max),@EnrollmentHash binary(32);
  SELECT @EnrollmentPlan=RequestJson,@EnrollmentProgress=GenerationJson,@EnrollmentHash=RequestHash
   FROM dbo.ExportPreparation WHERE PreparationID=@ObjectID;
  IF @Purpose=''enrollment''
  BEGIN
   IF JSON_VALUE(@EnrollmentPlan,''$.purpose'') IS NULL OR JSON_VALUE(@EnrollmentPlan,''$.purpose'')<>''output_enrollment''
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id'')) IS NULL
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id''))<>@SessionID
    OR @RegistrationHash<>@EnrollmentHash OR @SnapshotHash<>@EnrollmentHash
    OR @EnrollmentHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@EnrollmentPlan))
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson))<>2
    OR JSON_QUERY(@ScopeJson,''$.enrollment'') IS NULL
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'') IS NULL
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') IS NULL
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>JSON_VALUE(@EnrollmentProgress,''$.phase'')
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal''))<>TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal''))
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') NOT IN (''create'',''verify'')
    THROW 51700,''Exact authority-side enrollment phase required.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    THROW 51700,''Enrollment phase already has a stream; never replay.'',1;
  END
  ELSE IF JSON_VALUE(@EnrollmentPlan,''$.purpose'')=''output_enrollment''
   THROW 51700,''Enrollment cannot become ordinary configuration authority.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID)
   THROW 51700,''Preparation membership conflict.'',1;
 END
 ELSE
 BEGIN
  -- Pool lock follows resource locks, matching the Bot''s operation DAL.
  DECLARE @PoolID uniqueidentifier,@PoolLock nvarchar(255),@PoolLockResult int;
  SELECT @PoolID=PoolID FROM KVK.SourceOutputOperation WHERE OperationID=@ObjectID AND AccountKey=@AccountKey;
  IF @PoolID IS NULL THROW 51700,''Output operation pool is unavailable.'',1;
  SET @PoolLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @PoolLockResult=sys.sp_getapplock @Resource=@PoolLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @PoolLockResult<0 THROW 51700,''Output operation pool busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM KVK.SourceOutputPool WITH (UPDLOCK,HOLDLOCK)
   WHERE PoolID=@PoolID AND AccountKey=@AccountKey AND PoolState=''closing''
    AND OwnerID=@ObjectID AND Epoch=@Epoch AND RegistrationHash=@RegistrationHash)
   THROW 51700,''Output operation registration/epoch changed.'',1;
  IF @NestedToken IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM KVK.SourceOutputOperation WITH (UPDLOCK,HOLDLOCK) WHERE OperationID=@ObjectID AND AccountKey=@AccountKey
    AND PoolID=@PoolID AND Fence=@Fence AND Version=@ClaimVersion AND OldEpoch=@Epoch
    AND ((OwnerID=@OwnerID AND (@Purpose=''probe'' OR State=''running''))
      OR (@Purpose=''probe'' AND @OwnerID IS NULL AND OwnerID IS NULL AND Fence=0 AND State=''closing'' AND Phase=''draining'')))
   THROW 51700,''Output operation CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID)
   THROW 51700,''Output operation membership conflict.'',1;
 END;

 END;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

 DECLARE @StreamState varchar(16),@LastSequence bigint,@Version bigint;
 SELECT @StreamState=State,@LastSequence=LastSequence,@Version=Version
 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK)
 WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey;
 IF @ExpectedVersion IS NULL OR @Version IS NULL OR @Version<>@ExpectedVersion OR @StreamState=''closed''
  THROW 51700,''Request stream CAS lost or closed.'',1;
 IF @State IS NULL OR DATALENGTH(@State)<>LEN(@State) THROW 51700,''Canonical event state required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE EventID=@EventID)
  THROW 51700,''Event already exists; read immutable event before retry.'',1;
 DECLARE @Previous varchar(32),@EventSequence int;
 IF @State=''prepared''
 BEGIN
  IF @StreamState<>''open'' OR (@Purpose=''probe'' AND @RequestKind<>''read'')
   THROW 51700,''Stream cannot prepare this request.'',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID AND NOT EXISTS
    (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'',''unknown'')))
   THROW 51700,''Only one outstanding request per stream.'',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
   WHERE r.StreamID=@StreamID AND r.RequestKind=''mutation'' AND e.State=''unknown'')
   THROW 51700,''Unknown mutation requires reconciliation.'',1;
  IF @Operation=''sheets.create''
  BEGIN
   IF @Purpose<>''enrollment'' OR @RequestKind<>''mutation'' OR @OwnerKind<>''preparation''
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>''create''
    OR @TargetID<>LOWER(CONVERT(varchar(36),@ObjectID)) OR DATALENGTH(@TargetID)<>36
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID)
    THROW 51700,''Only one fixed create per fresh enrollment phase.'',1;
  END
  ELSE
  BEGIN
   IF NOT EXISTS (SELECT 1 FROM OPENJSON(@ScopeJson,''$.resources'') WITH (ResourceKey varchar(256) ''$.key'') WHERE ResourceKey=''destination:''+@TargetID)
    THROW 51700,''Request target is outside owned resources.'',1;
   IF @Purpose=''enrollment'' AND (JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>''verify''
    OR @Operation NOT IN (''drive.permissions.create'',''drive.files.get'',''drive.permissions.list'',''sheets.get'',''sheets.values.batchGet''))
    THROW 51700,''Enrollment permits only Editor grant and fixed readback.'',1;
   IF @Purpose=''enrollment'' AND @Operation=''drive.permissions.create''
    AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID AND TargetID=@TargetID AND Operation=@Operation)
    THROW 51700,''Editor grant cannot be replayed.'',1;
  END;
  INSERT dbo.ExportProviderRequest VALUES (@RequestID,@StreamID,@LastSequence+1,@Operation,@RequestKind,@TargetID,@PayloadHash,@PayloadReference,SYSUTCDATETIME());
  SET @EventSequence=1;
  UPDATE dbo.ExportExecutionStream SET LastSequence=LastSequence+1 WHERE StreamID=@StreamID;
 END
 ELSE
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequest WHERE RequestID=@RequestID AND StreamID=@StreamID)
   THROW 51700,''Request identity differs.'',1;
  IF @State=''dispatch_intent'' AND @OwnerKind=''job''
   AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE RequestID=@RequestID AND RequestKind=''mutation'')
   AND NOT EXISTS(SELECT 1 FROM dbo.ExportAttempt WHERE JobID=@ObjectID AND OwnerID=@OwnerID AND Fence=@Fence AND Phase IN (''private_started'',''verified'',''publication_pending''))
   THROW 51700,''A durable owned attempt must precede mutation dispatch.'',1;
  SELECT TOP(1) @Previous=State,@EventSequence=EventSequence+1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=@RequestID ORDER BY EventSequence DESC;
  IF NOT ((@Previous=''prepared'' AND @State=''not_sent'') OR (@Previous=''prepared'' AND @State=''dispatch_intent'' AND @StreamState=''open'')
    OR (@Previous=''dispatch_intent'' AND @State IN (''succeeded'',''unknown'')))
   OR @Previous IS NULL THROW 51700,''Invalid or terminal request transition; never replay.'',1;
 END;
 INSERT dbo.ExportProviderRequestEvent VALUES (@EventID,@RequestID,@EventSequence,@State,@EvidenceHash,@EvidenceReference,SYSUTCDATETIME());
 UPDATE dbo.ExportExecutionStream SET Version=Version+1 WHERE StreamID=@StreamID;
 SELECT * FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
' COLLATE Latin1_General_100_BIN2
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend') AND uses_ansi_nulls=1 AND uses_quoted_identifier=1 AND execute_as_principal_id IS NULL)
 THROW 51700,'Evidence procedure differs; forward-fix only.',1;
IF OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue',N'P') IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue')) IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue')) COLLATE Latin1_General_100_BIN2 <> N'CREATE PROCEDURE dbo.usp_ExportReconciliationProofIssue
 @SessionID uniqueidentifier,
 @ProofID uniqueidentifier,
 @AccountKey varchar(128),
 @SnapshotHash binary(32),
 @RegistrationHash binary(32),
 @ProofKind varchar(32),
 @Outcome varchar(16),
 @MembershipJson nvarchar(max),
 @EvidenceJson nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

 IF @MembershipJson IS NULL OR ISJSON(@MembershipJson)<>1 OR DATALENGTH(@MembershipJson)>65536
 OR @EvidenceJson IS NULL OR ISJSON(@EvidenceJson)<>1 OR DATALENGTH(@EvidenceJson)>65536
  THROW 51700,''Bounded proof evidence required.'',1;
 IF JSON_VALUE(@EvidenceJson,''$.state'') IS NULL OR JSON_VALUE(@EvidenceJson,''$.snapshot_hash'') IS NULL
 OR JSON_VALUE(@EvidenceJson,''$.state'') COLLATE Latin1_General_100_BIN2<>@Outcome COLLATE Latin1_General_100_BIN2
 OR JSON_VALUE(@EvidenceJson,''$.snapshot_hash'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(64),@SnapshotHash,2)) COLLATE Latin1_General_100_BIN2
  THROW 51700,''Proof body differs from immutable outcome/snapshot.'',1;
 -- v2 seals the complete registered-file catalogue without truncating retained
 -- history into a bounded stream-ID list. Parent verifies each private journal.
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson))<>4
 OR EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key] NOT IN (''version'',''targets'',''history'',''probe''))
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson))<>4
 OR JSON_VALUE(@MembershipJson,''$.version'') IS NULL OR JSON_VALUE(@MembershipJson,''$.version'')<>''2''
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''version'' AND type=2)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''targets'' AND type=4)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''history'' AND type=5)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''probe'' AND type=5)
  THROW 51700,''Versioned complete catalogue membership required.'',1;
 DECLARE @Targets TABLE (FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY);
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.targets'')) NOT BETWEEN 1 AND 17
 OR EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.targets'') WHERE type<>1 OR DATALENGTH(value) NOT BETWEEN 6 AND 256
  OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_-]%'')
  THROW 51700,''Bounded exact registered targets required.'',1;
 IF EXISTS (SELECT 1 FROM (SELECT value,LAG(value) OVER (ORDER BY CONVERT(int,[key])) AS Previous
  FROM OPENJSON(@MembershipJson,''$.targets'')) q WHERE Previous COLLATE Latin1_General_100_BIN2>=value COLLATE Latin1_General_100_BIN2)
  THROW 51700,''Targets must be unique and canonically ordered.'',1;
 INSERT @Targets SELECT CONVERT(varchar(128),value) FROM OPENJSON(@MembershipJson,''$.targets'');
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.history''))<>2
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson,''$.history''))<>2
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.history'') WHERE [key]=''count'' AND type=2)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.history'') WHERE [key]=''sha256'' AND type=1)
 OR (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.probe''))<>2
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson,''$.probe''))<>2
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.probe'') WHERE [key]=''stream_id'' AND type=1)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.probe'') WHERE [key]=''version'' AND type=2)
  THROW 51700,''Exact history seal and fresh probe identity required.'',1;
 DECLARE @ExpectedCount bigint=TRY_CONVERT(bigint,JSON_VALUE(@MembershipJson,''$.history.count'')),
  @HistoryHashText nvarchar(4000)=JSON_VALUE(@MembershipJson,''$.history.sha256''),
  @ProbeID uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@MembershipJson,''$.probe.stream_id'')),
  @ProbeVersion bigint=TRY_CONVERT(bigint,JSON_VALUE(@MembershipJson,''$.probe.version''));
 IF @ExpectedCount IS NULL OR @ExpectedCount<0 OR @ProbeID IS NULL OR @ProbeVersion IS NULL OR @ProbeVersion<=0
 OR @HistoryHashText IS NULL OR DATALENGTH(@HistoryHashText)<>128 OR @HistoryHashText COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
 OR DATALENGTH(JSON_VALUE(@MembershipJson,''$.probe.stream_id''))<>72
 OR JSON_VALUE(@MembershipJson,''$.probe.stream_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),@ProbeID)) COLLATE Latin1_General_100_BIN2
  THROW 51700,''Canonical historical count/hash and probe identity required.'',1;
 -- A blank current file is not a creation history. Only sealed managed origins
 -- can enter automatic finality. Old/unproven files remain operator reconciliation.
 IF EXISTS(SELECT 1 FROM @Targets t WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o
   JOIN dbo.ExportPreparation p ON p.PreparationID=o.PreparationID
   WHERE o.FileID=t.FileID AND o.Stage=''eligible'' AND p.AccountKey=@AccountKey AND p.State=''completed''))
  THROW 51700,''Complete authenticated managed-file origins required.'',1;
 DECLARE @Members TABLE (StreamID uniqueidentifier NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 INSERT @Members SELECT s.StreamID,s.Version FROM dbo.ExportExecutionStream s WITH (UPDLOCK,HOLDLOCK)
 WHERE s.AccountKey=@AccountKey AND (EXISTS (SELECT 1 FROM OPENJSON(s.ScopeJson,''$.resources'')
  WITH (ResourceKey varchar(256) ''$.key'') r JOIN @Targets t
  ON r.ResourceKey COLLATE Latin1_General_100_BIN2=(''destination:''+t.FileID) COLLATE Latin1_General_100_BIN2)
 OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o JOIN @Targets t ON t.FileID=o.FileID
  WHERE o.PreparationID=s.PreparationID AND o.Stage=''created''));
 IF NOT EXISTS (SELECT 1 FROM @Members) THROW 51700,''Empty evidence is not proof of historical coverage.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.State<>''closed'' OR s.ActiveAccountKey IS NOT NULL OR s.ClosureHash IS NULL OR s.EventDigest IS NULL)
  THROW 51700,''Exact closed request-stream membership required.'',1;
 DECLARE @CatalogueHash binary(32)=HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),''K98-S11-CATALOGUE-1'')),
  @CatalogueCount bigint=0,@CatalogueID uniqueidentifier,@CatalogueVersion bigint,@CatalogueEvents binary(32);
 DECLARE CatalogueRows CURSOR LOCAL FAST_FORWARD FOR
 SELECT s.StreamID,s.Version,s.EventDigest FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
 WHERE s.StreamID<>@ProbeID ORDER BY LOWER(CONVERT(varchar(36),s.StreamID)) COLLATE Latin1_General_100_BIN2;
 OPEN CatalogueRows;
 FETCH NEXT FROM CatalogueRows INTO @CatalogueID,@CatalogueVersion,@CatalogueEvents;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @CatalogueHash=HASHBYTES(''SHA2_256'',@CatalogueHash+CONVERT(varbinary(max),LOWER(CONVERT(varchar(36),@CatalogueID)))
   +CONVERT(varbinary(max),'':''+CONVERT(varchar(20),@CatalogueVersion)+'':'')+@CatalogueEvents);
  SET @CatalogueCount=@CatalogueCount+1;
  FETCH NEXT FROM CatalogueRows INTO @CatalogueID,@CatalogueVersion,@CatalogueEvents;
 END;
 CLOSE CatalogueRows;
 DEALLOCATE CatalogueRows;
 IF @CatalogueCount<>@ExpectedCount OR @CatalogueHash<>CONVERT(binary(32),@HistoryHashText,2)
  THROW 51700,''Historical writer catalogue changed around the fresh probe.'',1;
 IF NOT EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.StreamID=@ProbeID AND s.Version=@ProbeVersion AND s.Purpose=''probe''
   AND s.SnapshotHash=@SnapshotHash AND s.RegistrationHash=@RegistrationHash
   AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
     WHERE r.StreamID=s.StreamID AND r.RequestKind=''read'' AND e.State=''succeeded''))
  THROW 51700,''Fresh snapshot-bound closed probe required.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportProviderRequest r ON r.StreamID=m.StreamID
   WHERE NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'')))
  THROW 51700,''Request gaps or unknown outcomes cannot become proof.'',1;
 -- Older successful jobs stay in the complete catalogue, but do not imply that
 -- this publication dispatched a mutation. Cover every stream of its exact job,
 -- including former nested owners, even outside the current registered target set.
 DECLARE @SubjectJob uniqueidentifier=(SELECT JobID FROM dbo.ExportExecutionStream WHERE StreamID=@ProbeID);
 IF @Outcome=''absent'' AND (@ProofKind<>''publication'' OR @SubjectJob IS NULL)
  THROW 51700,''Absence requires an exact publication-job probe.'',1;
 IF @Outcome=''absent'' AND EXISTS (SELECT 1 FROM dbo.ExportExecutionStream s
   JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
   JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
   WHERE s.AccountKey=@AccountKey AND s.JobID=@SubjectJob AND r.RequestKind=''mutation'' AND e.State=''dispatch_intent'')
  THROW 51700,''Dispatched mutation cannot support absence proof.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  THROW 51700,''A live provider writer/probe prevents proof issue.'',1;
 -- Parent authority must attest COMPLETE historical writer coverage and exact
 -- method-specific readback; SQL does not infer provider truth from row presence.
 INSERT dbo.ExportReconciliationProof VALUES (@ProofID,@SessionID,@AccountKey,@SnapshotHash,@RegistrationHash,@ProofKind,@Outcome,
  HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@MembershipJson)),@MembershipJson,@EvidenceJson,SYSUTCDATETIME());
 SELECT * FROM dbo.ExportReconciliationProof WHERE ProofID=@ProofID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
' COLLATE Latin1_General_100_BIN2
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue') AND uses_ansi_nulls=1 AND uses_quoted_identifier=1 AND execute_as_principal_id IS NULL)
 THROW 51700,'Evidence procedure differs; forward-fix only.',1;
IF OBJECT_ID(N'dbo.usp_ExportOutputEnrollmentTransition',N'P') IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportOutputEnrollmentTransition')) IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportOutputEnrollmentTransition')) COLLATE Latin1_General_100_BIN2 <> N'CREATE PROCEDURE dbo.usp_ExportOutputEnrollmentTransition
 @SessionID uniqueidentifier,
 @PreparationID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @AccountKey varchar(128),
 @OwnerID uniqueidentifier,
 @Fence bigint=NULL,
 @ResourcesJson nvarchar(max)=NULL,
 @PlanJson nvarchar(max)=NULL,
 @Actor nvarchar(128)=NULL,
 @Reason nvarchar(1024)=NULL,
 @Ordinal int=NULL,
 @FileID varchar(128)=NULL,
 @CreationStreamID uniqueidentifier=NULL,
 @CreationRequestID uniqueidentifier=NULL,
 @ResponseEventID uniqueidentifier=NULL,
 @OriginHash binary(32)=NULL,
 @OriginReference uniqueidentifier=NULL,
 @VerificationStreamID uniqueidentifier=NULL,
 @EligibilityHash binary(32)=NULL,
 @EligibilityReference uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Enrollment requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51700,''Evidence authority role required.'',1;
 IF @AccountKey IS NULL OR DATALENGTH(@AccountKey) NOT BETWEEN 1 AND 128
 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey) OR @AccountKey LIKE ''%[^A-Za-z0-9_.@:-]%'' COLLATE Latin1_General_100_BIN2
 OR @OwnerID IS NULL OR @PreparationID IS NULL OR @ExpectedVersion IS NULL
 OR @Action IS NULL OR DATALENGTH(@Action)<>LEN(@Action) OR @Action NOT IN (''begin'',''bind'',''complete'')
  THROW 51700,''Canonical enrollment identity required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255),@AccountResource varchar(256)=''account:''+@AccountKey;
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@AccountResource),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
  THROW 51700,''Exact open authority session required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  THROW 51700,''Enrollment requires closed owned children.'',1;

 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF @Action=''begin''
 BEGIN
  IF @ExpectedVersion<>0 OR @Fence IS NOT NULL OR @ResourcesJson IS NOT NULL
   OR @PlanJson IS NULL OR ISJSON(@PlanJson)<>1 OR DATALENGTH(@PlanJson)>65536
   OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
   THROW 51700,''Fresh protected enrollment plan required.'',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@PlanJson))<>11 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@PlanJson))<>11
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''purpose'',''account'',''storage_owner'',''owner_email'',''editor_email'',''project_id'',''credential_profile_sha256'',''manifest_sha256'',''file_count'',''plan_id''))
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''version'' AND type=2 AND value=''1'')
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''file_count'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 3 AND 17 AND value=CONVERT(varchar(2),TRY_CONVERT(int,value)))
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''file_count'') AND (type<>1 OR LEN(value)=0))
   OR JSON_VALUE(@PlanJson,''$.purpose'') COLLATE Latin1_General_100_BIN2<>''output_enrollment''
   OR JSON_VALUE(@PlanJson,''$.account'') COLLATE Latin1_General_100_BIN2<>@AccountKey COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.account''))<>2*DATALENGTH(@AccountKey)
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.purpose''))<>34
   OR JSON_VALUE(@PlanJson,''$.storage_owner'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_.@:-]%''
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.storage_owner'')) NOT BETWEEN 2 AND 256
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id'')) IS NULL
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.plan_id''))<>72
   OR JSON_VALUE(@PlanJson,''$.plan_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id'')))) COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.credential_profile_sha256''))<>128
   OR JSON_VALUE(@PlanJson,''$.credential_profile_sha256'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.manifest_sha256''))<>128
   OR JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
   OR NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID AND LOWER(CONVERT(varchar(64),ManifestHash,2)) COLLATE Latin1_General_100_BIN2=JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2)
   THROW 51700,''Exact typed enrollment plan differs.'',1;
  -- New enrollment never overtakes existing ready work or bypasses uncertainty.
  IF EXISTS (SELECT 1 FROM dbo.ExportJob WHERE AccountKey=@AccountKey AND State IN (''ready'',''running'',''uncertain''))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN (''pending'',''preflight'',''sql_pending'',''writing'',''committed'',''uncertain''))
   OR EXISTS (SELECT 1 FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey AND State IN (''closing'',''ready'',''running'',''uncertain''))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE PreparationID=@PreparationID OR (AccountKey=@AccountKey AND RequestHash=HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson))))
   THROW 51700,''Existing work or enrollment prevents fresh admission.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK) WHERE ResourceKey=@AccountResource)
   INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version) VALUES(@AccountResource,''account'',0,1);
  INSERT @Resources SELECT ResourceKey,Version FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
 END
 ELSE
 BEGIN
  IF @PlanJson IS NOT NULL OR @ResourcesJson IS NULL OR ISJSON(@ResourcesJson)<>1 OR DATALENGTH(@ResourcesJson)>65536
   OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion<=0
   THROW 51700,''Exact enrollment CAS resources required.'',1;
  IF LEFT(LTRIM(@ResourcesJson),1)<>''['' OR (SELECT COUNT(*) FROM OPENJSON(@ResourcesJson)) NOT BETWEEN 1 AND 18
   OR EXISTS(SELECT 1 FROM OPENJSON(@ResourcesJson) j WHERE j.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>2
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''key'' AND type=1)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''version'' AND type=2))
   THROW 51700,''Exact resource-version list required.'',1;
  INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ResourcesJson) WITH(ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
  IF EXISTS(SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID)
   OR NOT EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey=@AccountResource)
   THROW 51700,''Enrollment resource membership changed.'',1;
 END;
 -- A newly returned identity must have no resource/origin/registration history.
 IF @Action=''bind''
 BEGIN
  IF @FileID IS NULL OR DATALENGTH(@FileID) NOT BETWEEN 3 AND 128 OR DATALENGTH(@FileID)<>LEN(@FileID)
   OR @FileID LIKE ''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2
   OR @Ordinal IS NULL OR @Ordinal NOT BETWEEN 0 AND 16 OR @OriginHash IS NULL OR @OriginReference IS NULL
   THROW 51700,''Exact newly returned file and origin receipt required.'',1;
  INSERT @Resources VALUES(''destination:''+@FileID,0);
 END;
 DECLARE @Key varchar(256),@ResourceVersion bigint;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @Key,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@Key),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51700,''Enrollment resource busy.'',1;
  IF @ResourceVersion=0
  BEGIN
   IF EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key)
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=@FileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=@FileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=@FileID)
    THROW 51700,''Returned identity has existing history; never adopt.'',1;
  END
  ELSE IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key AND Version=@ResourceVersion AND BlockedReason IS NULL
   AND ((@Action=''begin'' AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL)
    OR (@Action<>''begin'' AND ActivePreparationID=@PreparationID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID=@OwnerID AND Fence=@Fence)))
   THROW 51700,''Enrollment resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @Key,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;

 DECLARE @Plan nvarchar(max),@Progress nvarchar(max),@PlanHash binary(32),@Count int,@Next int;
 IF @Action=''begin''
 BEGIN
  -- Count registered pools and still-unregistered enrollment plans once each.
  -- Range locks prevent concurrent enrollment/registration from overbooking eight.
  IF (SELECT COUNT_BIG(*) FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK))+
   (SELECT COUNT_BIG(*) FROM dbo.ExportPreparation p WITH(UPDLOCK,HOLDLOCK)
    WHERE JSON_VALUE(p.RequestJson,''$.purpose'')=''output_enrollment''
     AND NOT EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o JOIN KVK.SourceOutputPool pool ON pool.IndexFileID=o.FileID
      WHERE o.PreparationID=p.PreparationID AND o.Stage=''eligible'' AND o.Ordinal=0))>=8
   THROW 51700,''Eight-pool enrollment capacity is exhausted.'',1;
  SELECT @Fence=Fence+1 FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
  DECLARE @Ticket bigint=(SELECT ISNULL(MAX(Ticket),0)+1 FROM
   (SELECT EnqueueSequence Ticket FROM dbo.ExportJob WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey) q);
  SET @Progress=N''{"session_id":"''+LOWER(CONVERT(nvarchar(36),@SessionID))+N''","phase":"create","next_ordinal":0}'';
  INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,KVK_NO,RequestHash,EnqueueSequence,State,OwnerID,Fence,Version,StorageOwner,RequestJson,GenerationJson,Actor,Reason,CreatedUTC,UpdatedUTC)
   VALUES(@PreparationID,@AccountKey,''config'',NULL,HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson)),@Ticket,''preflight'',@OwnerID,@Fence,1,JSON_VALUE(@PlanJson,''$.storage_owner''),@PlanJson,@Progress,@Actor,@Reason,SYSUTCDATETIME(),SYSUTCDATETIME());
  INSERT dbo.ExportPreparationResource VALUES(@PreparationID,@AccountResource);
  UPDATE dbo.ExportResource SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=Version+1 WHERE ResourceKey=@AccountResource;
 END
 ELSE
 BEGIN
  SELECT @Plan=RequestJson,@PlanHash=RequestHash,@Progress=GenerationJson FROM dbo.ExportPreparation WITH(UPDLOCK,HOLDLOCK)
   WHERE PreparationID=@PreparationID AND AccountKey=@AccountKey AND ConsumerKind=''config'' AND State=''preflight''
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ExpectedVersion AND JobID IS NULL AND SpoolKey IS NULL
    AND JSON_VALUE(RequestJson,''$.purpose'')=''output_enrollment''
    AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(GenerationJson,''$.session_id''))=@SessionID;
  IF @Plan IS NULL OR @PlanHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@Plan))
   THROW 51700,''Enrollment preparation identity/CAS differs; no adoption.'',1;
  SET @Count=TRY_CONVERT(int,JSON_VALUE(@Plan,''$.file_count''));
  SET @Next=TRY_CONVERT(int,JSON_VALUE(@Progress,''$.next_ordinal''));
  IF @Count IS NULL OR @Count NOT BETWEEN 3 AND 17 OR @Next IS NULL
   THROW 51700,''Enrollment plan/progress differs.'',1;
  IF @Action=''bind''
  BEGIN
   IF @Next<>@Ordinal OR @Next>=@Count OR JSON_VALUE(@Progress,''$.phase'')<>''create''
    OR (SELECT COUNT(*) FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'')<>@Ordinal
    THROW 51700,''Creation ordinal is not the next fresh identity.'',1;
   DECLARE @ResponseHash binary(32),@ClosureHash binary(32);
   SELECT @ResponseHash=e.EvidenceHash,@ClosureHash=s.ClosureHash
    FROM dbo.ExportExecutionStream s JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
    JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
    WHERE s.StreamID=@CreationStreamID AND s.SessionID=@SessionID AND s.PreparationID=@PreparationID
     AND s.AccountKey=@AccountKey AND s.OwnerID=@OwnerID AND s.Fence=@Fence AND s.ClaimVersion=@ExpectedVersion
     AND s.Purpose=''enrollment'' AND s.State=''closed'' AND s.ActiveAccountKey IS NULL AND s.LastSequence=1
     AND s.RegistrationHash=@PlanHash AND s.SnapshotHash=@PlanHash AND s.EventDigest IS NOT NULL
     AND JSON_VALUE(s.ScopeJson,''$.enrollment.phase'')=''create''
     AND TRY_CONVERT(int,JSON_VALUE(s.ScopeJson,''$.enrollment.ordinal''))=@Ordinal
     AND r.RequestID=@CreationRequestID AND r.Sequence=1 AND r.Operation=''sheets.create'' AND r.RequestKind=''mutation''
     AND r.TargetID=LOWER(CONVERT(varchar(36),@PreparationID))
     AND e.EventID=@ResponseEventID AND e.State=''succeeded'' AND e.EventSequence=3;
   IF @ResponseHash IS NULL OR @ClosureHash IS NULL THROW 51700,''Exact successful closed creation required.'',1;
   INSERT dbo.ExportManagedFileOrigin(FileID,Stage,PreparationID,Ordinal,SessionID,CreationStreamID,CreationRequestID,ResponseEventID,PlanHash,ProfileHash,ResponseHash,CreationClosureHash,OriginHash,OriginReference,CreatedUTC)
    VALUES(@FileID,''created'',@PreparationID,@Ordinal,@SessionID,@CreationStreamID,@CreationRequestID,@ResponseEventID,@PlanHash,CONVERT(binary(32),JSON_VALUE(@Plan,''$.credential_profile_sha256''),2),@ResponseHash,@ClosureHash,@OriginHash,@OriginReference,SYSUTCDATETIME());
   INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version) VALUES(''destination:''+@FileID,''destination'',0,1);
   INSERT dbo.ExportPreparationResource VALUES(@PreparationID,''destination:''+@FileID);
   UPDATE dbo.ExportResource SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=2 WHERE ResourceKey=''destination:''+@FileID;
   SET @Progress=JSON_MODIFY(JSON_MODIFY(@Progress,''$.next_ordinal'',@Next+1),''$.phase'',CASE WHEN @Next+1=@Count THEN ''verify'' ELSE ''create'' END);
  END
  ELSE
  BEGIN
   IF @Next<>@Count OR JSON_VALUE(@Progress,''$.phase'')<>''verify'' OR @EligibilityHash IS NULL OR @EligibilityReference IS NULL
    OR (SELECT COUNT(*) FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'')<>@Count
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''eligible'')
    THROW 51700,''Complete unsealed origin set required.'',1;
   DECLARE @VerificationClosure binary(32);
   SELECT @VerificationClosure=ClosureHash FROM dbo.ExportExecutionStream
    WHERE StreamID=@VerificationStreamID AND SessionID=@SessionID AND PreparationID=@PreparationID
     AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND ClaimVersion=@ExpectedVersion
     AND Purpose=''enrollment'' AND State=''closed'' AND ActiveAccountKey IS NULL AND EventDigest IS NOT NULL
     AND RegistrationHash=@PlanHash AND SnapshotHash=@PlanHash AND JSON_VALUE(ScopeJson,''$.enrollment.phase'')=''verify'';
   IF @VerificationClosure IS NULL OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s
     WHERE s.PreparationID=@PreparationID AND (s.State<>''closed'' OR s.ClosureHash IS NULL OR s.EventDigest IS NULL))
    OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
     WHERE s.PreparationID=@PreparationID AND NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State=''succeeded''))
    THROW 51700,''Enrollment history contains unclosed or uncertain requests.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o CROSS JOIN
     (VALUES(''drive.permissions.create''),(''drive.files.get''),(''drive.permissions.list''),(''sheets.get''),(''sheets.values.batchGet'')) m(Operation)
     WHERE o.PreparationID=@PreparationID AND o.Stage=''created'' AND NOT EXISTS
      (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@VerificationStreamID AND r.TargetID=o.FileID AND r.Operation=m.Operation))
    THROW 51700,''Every origin requires grant and complete fixed readback.'',1;
   -- Parent verifies private response bytes, exact owner/editor and all blank cells.
   -- SQL seals that receipt only after the complete request history has terminated.
   INSERT dbo.ExportManagedFileOrigin
    SELECT FileID,''eligible'',''created'',PreparationID,Ordinal,SessionID,CreationStreamID,CreationRequestID,ResponseEventID,PlanHash,ProfileHash,ResponseHash,CreationClosureHash,OriginHash,OriginReference,@VerificationStreamID,@VerificationClosure,@EligibilityHash,@EligibilityReference,SYSUTCDATETIME()
    FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'';
   SET @Progress=JSON_MODIFY(@Progress,''$.phase'',''complete'');
   UPDATE r SET ActivePreparationID=NULL,OwnerID=NULL,Version=r.Version+1
    FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey;
  END;
  UPDATE dbo.ExportPreparation SET GenerationJson=@Progress,State=CASE WHEN @Action=''complete'' THEN ''completed'' ELSE ''preflight'' END,Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PreparationID=@PreparationID AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ExpectedVersion;
  IF @@ROWCOUNT<>1 THROW 51700,''Enrollment preparation CAS lost.'',1;
 END;
 SELECT p.*,(SELECT r.ResourceKey AS [key],r.Version AS [version] FROM dbo.ExportPreparationResource m
  JOIN dbo.ExportResource r ON r.ResourceKey=m.ResourceKey WHERE m.PreparationID=p.PreparationID ORDER BY r.ResourceKey FOR JSON PATH) AS ResourcesJson
 FROM dbo.ExportPreparation p WHERE p.PreparationID=@PreparationID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
' COLLATE Latin1_General_100_BIN2
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportOutputEnrollmentTransition') AND uses_ansi_nulls=1 AND uses_quoted_identifier=1 AND execute_as_principal_id IS NULL)
 THROW 51700,'Evidence procedure differs; forward-fix only.',1;
IF DATABASE_PRINCIPAL_ID(N'ExportExecutionAuthority') IS NULL EXEC(N'CREATE ROLE ExportExecutionAuthority AUTHORIZATION dbo');
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name=N'ExportExecutionAuthority' AND type='R' AND owning_principal_id=DATABASE_PRINCIPAL_ID(N'dbo')) THROW 51700,'Evidence role identity conflict.',1;
IF DATABASE_PRINCIPAL_ID(N'ExportExecutionReader') IS NULL EXEC(N'CREATE ROLE ExportExecutionReader AUTHORIZATION dbo');
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name=N'ExportExecutionReader' AND type='R' AND owning_principal_id=DATABASE_PRINCIPAL_ID(N'dbo')) THROW 51700,'Evidence role identity conflict.',1;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportExecutionSession TO public;
GRANT SELECT ON OBJECT::dbo.ExportExecutionSession TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportExecutionSession TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportExecutionSession TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportExecutionSession TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportExecutionStream TO public;
GRANT SELECT ON OBJECT::dbo.ExportExecutionStream TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportExecutionStream TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportExecutionStream TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportExecutionStream TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportProviderRequest TO public;
GRANT SELECT ON OBJECT::dbo.ExportProviderRequest TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportProviderRequest TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportProviderRequest TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportProviderRequest TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportProviderRequestEvent TO public;
GRANT SELECT ON OBJECT::dbo.ExportProviderRequestEvent TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportProviderRequestEvent TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportProviderRequestEvent TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportProviderRequestEvent TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportReconciliationProof TO public;
GRANT SELECT ON OBJECT::dbo.ExportReconciliationProof TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReconciliationProof TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportReconciliationProof TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReconciliationProof TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportManagedFileOrigin TO public;
GRANT SELECT ON OBJECT::dbo.ExportManagedFileOrigin TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportManagedFileOrigin TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportManagedFileOrigin TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportManagedFileOrigin TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportExecutionSessionTransition TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportExecutionSessionTransition TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportExecutionStreamTransition TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportExecutionStreamTransition TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportProviderRequestEventAppend TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportProviderRequestEventAppend TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportReconciliationProofIssue TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportReconciliationProofIssue TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportOutputEnrollmentTransition TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportOutputEnrollmentTransition TO ExportExecutionReader;
-- Never add application principals to roles here. G4 must verify effective
-- rights (including inherited/column-level grants) and exclude db_owner/sysadmin,
-- ALTER/CONTROL/IMPERSONATE/grant-capable Bot identities from this trust boundary.
IF @S11OwnTransaction=1 COMMIT;
END TRY
BEGIN CATCH
 IF @S11OwnTransaction=1 AND XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
