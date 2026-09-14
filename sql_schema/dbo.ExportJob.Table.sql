SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10A reference snapshot. Deploy the reviewed migration, not this file.
-- Static shape only: authorized later DAL owns CAS, transitions, immutable inputs,
-- fairness, resource acquisition/release and provider evidence validation.
-- For snapshot reconstruction create all six tables before adding the ownership FKs.
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
ALTER TABLE dbo.ExportJob WITH CHECK ADD CONSTRAINT FK_ExportJob_Intent FOREIGN KEY (SourceKey, KVK_NO, IntentID) REFERENCES KVK.SourceExportIntent (SourceKey, KVK_NO, IntentID);
ALTER TABLE dbo.ExportJob WITH CHECK ADD CONSTRAINT FK_ExportJob_Superseded FOREIGN KEY (SupersededByJobID, ConsumerKind, AccountKey, KVK_NO, DestinationSetHash, PoolEpoch) REFERENCES dbo.ExportJob (JobID, ConsumerKind, AccountKey, KVK_NO, DestinationSetHash, PoolEpoch);
