SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10D reference snapshot. Deploy the reviewed migration, not this file.
-- Static identity/shape/scope only. S10E owns monotonic CAS, append-only writer APIs,
-- registration/capacity preflight and provider evidence. No lease/job-state release.
-- Create all four output tables before adding cyclic disposition/slot foreign keys.
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
    CONSTRAINT CK_SourceOutputPool_Index CHECK (IndexFileKind = 'index' AND DATALENGTH(IndexFileKind) = 5),
    CONSTRAINT CK_SourceOutputPool_Registration CHECK (RegistrationNo BETWEEN 1 AND 8),
    CONSTRAINT CK_SourceOutputPool_Account CHECK (LEN(AccountKey) > 0 AND AccountKey NOT LIKE '%[^A-Za-z0-9_.@:-]%' COLLATE Latin1_General_100_BIN2 AND AccountResourceKey = 'account:' + AccountKey AND DATALENGTH(AccountResourceKey) = 8 + DATALENGTH(AccountKey)),
    CONSTRAINT CK_SourceOutputPool_OwnerIdentity CHECK (LEN(ExpectedOwner) > 0 AND DATALENGTH(ExpectedOwner) = DATALENGTH(LTRIM(RTRIM(ExpectedOwner)))),
    CONSTRAINT CK_SourceOutputPool_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND ((ActiveKVK IS NULL AND ChoiceID IS NULL AND PoolState IN ('setup','blocked')) OR (ActiveKVK IS NOT NULL AND ActiveKVK > 0 AND ChoiceID IS NOT NULL))),
    CONSTRAINT CK_SourceOutputPool_State CHECK (PoolState IN ('active','closing','closed','setup','blocked') AND DATALENGTH(PoolState) = LEN(PoolState)),
    CONSTRAINT CK_SourceOutputPool_Ownership CHECK ((OwnerID IS NULL AND Fence >= 0 AND PoolState <> 'closing') OR (OwnerID IS NOT NULL AND Fence > 0 AND PoolState <> 'closed')),
    CONSTRAINT CK_SourceOutputPool_Blocked CHECK ((PoolState = 'blocked' AND BlockedReason IS NOT NULL AND LEN(BlockedReason) > 0) OR (PoolState <> 'blocked' AND BlockedReason IS NULL)),
    CONSTRAINT CK_SourceOutputPool_Counters CHECK (Epoch > 0 AND Version > 0 AND UpdatedUTC >= CreatedUTC),
    CONSTRAINT CK_SourceOutputPool_Audience CHECK (ISJSON(AudienceJson) = 1 AND DATALENGTH(AudienceJson) <= 65536),
    CONSTRAINT CK_SourceOutputPool_Evidence CHECK (ISJSON(RegistrationJson) = 1 AND DATALENGTH(RegistrationJson) <= 65536)
);
CREATE INDEX IX_SourceOutputPool_State ON KVK.SourceOutputPool (AccountKey, PoolState, PoolID);
ALTER TABLE KVK.SourceOutputPool WITH CHECK ADD CONSTRAINT FK_SourceOutputPool_Index FOREIGN KEY (IndexFileID, IndexFileKind) REFERENCES KVK.SourceOutputFile (FileID, FileKind);
ALTER TABLE KVK.SourceOutputPool WITH CHECK ADD CONSTRAINT FK_SourceOutputPool_Account FOREIGN KEY (AccountResourceKey) REFERENCES dbo.ExportResource (ResourceKey);
ALTER TABLE KVK.SourceOutputPool WITH CHECK ADD CONSTRAINT FK_SourceOutputPool_Choice FOREIGN KEY (ActiveKVK, SourceKey, ChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID);
