SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10E reference snapshot. Deploy the reviewed migration, not this file.
-- Shape only. DAL owns immutable facts, monotonic CAS, fair admission, termination
-- proof and provider evidence. Never release by lease age or job state alone.
CREATE TABLE KVK.SourceOutputOperation
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
    CONSTRAINT CK_SourceOutputOperation_Source CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND OldKVK > 0 AND NewKVK > 0 AND OldKVK <> NewKVK),
    CONSTRAINT CK_SourceOutputOperation_Epoch CHECK (OldEpoch > 0 AND TargetEpoch > OldEpoch AND TargetEpoch - OldEpoch = 1),
    CONSTRAINT CK_SourceOutputOperation_State CHECK (State IN ('closing','ready','running','blocked','uncertain','completed') AND DATALENGTH(State) = LEN(State)),
    CONSTRAINT CK_SourceOutputOperation_Active CHECK ((State = 'completed' AND ActivePoolID IS NULL) OR (State <> 'completed' AND ActivePoolID IS NOT NULL AND ActivePoolID = PoolID)),
    CONSTRAINT CK_SourceOutputOperation_Owner CHECK ((OwnerID IS NULL AND Fence >= 0 AND State IN ('closing','ready','blocked','completed')) OR (OwnerID IS NOT NULL AND Fence > 0 AND State IN ('running','blocked','uncertain'))),
    CONSTRAINT CK_SourceOutputOperation_Counters CHECK (EnqueueSequence > 0 AND Version > 0 AND UpdatedUTC >= ConfirmedUTC),
    CONSTRAINT CK_SourceOutputOperation_Actor CHECK (LEN(ConfirmedBy) > 0 AND DATALENGTH(ConfirmedBy) = DATALENGTH(LTRIM(RTRIM(ConfirmedBy))) AND LEN(Reason) > 0 AND LEN(GuildID) > 0 AND GuildID NOT LIKE '%[^0-9]%' COLLATE Latin1_General_100_BIN2 AND LEN(ChannelID) > 0 AND ChannelID NOT LIKE '%[^0-9]%' COLLATE Latin1_General_100_BIN2),
    CONSTRAINT CK_SourceOutputOperation_Phase CHECK (Phase IN ('draining','ready','private_pending','private_verified','clear_pending','clear_verified','setup_pending','setup_verified','complete','uncertain') AND DATALENGTH(Phase) = LEN(Phase)),
    CONSTRAINT CK_SourceOutputOperation_FilePhase CHECK ((Phase IN ('private_pending','private_verified','clear_pending','clear_verified','setup_pending','setup_verified') AND CurrentFileID IS NOT NULL) OR (Phase IN ('draining','ready','complete','uncertain'))),
    CONSTRAINT CK_SourceOutputOperation_Plan CHECK (ISJSON(PlanJson) = 1 AND DATALENGTH(PlanJson) <= 65536),
    CONSTRAINT CK_SourceOutputOperation_Progress CHECK (ISJSON(ProgressJson) = 1 AND DATALENGTH(ProgressJson) <= 65536)
);
CREATE UNIQUE INDEX UX_SourceOutputOperation_ActivePool ON KVK.SourceOutputOperation (ActivePoolID) WHERE ActivePoolID IS NOT NULL;
CREATE INDEX IX_SourceOutputOperation_Queue ON KVK.SourceOutputOperation (AccountKey, State, EnqueueSequence, OperationID);
ALTER TABLE KVK.SourceOutputOperation WITH CHECK ADD CONSTRAINT FK_SourceOutputOperation_Pool FOREIGN KEY (PoolID, AccountKey) REFERENCES KVK.SourceOutputPool (PoolID, AccountKey);
ALTER TABLE KVK.SourceOutputOperation WITH CHECK ADD CONSTRAINT FK_SourceOutputOperation_OldChoice FOREIGN KEY (OldKVK, SourceKey, OldChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID);
ALTER TABLE KVK.SourceOutputOperation WITH CHECK ADD CONSTRAINT FK_SourceOutputOperation_NewChoice FOREIGN KEY (NewKVK, SourceKey, NewChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID);
ALTER TABLE KVK.SourceOutputOperation WITH CHECK ADD CONSTRAINT FK_SourceOutputOperation_CurrentFile FOREIGN KEY (OperationID, CurrentFileID) REFERENCES KVK.SourceOutputOperationResource (OperationID, FileID);
