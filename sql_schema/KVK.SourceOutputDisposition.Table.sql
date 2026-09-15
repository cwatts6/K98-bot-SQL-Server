SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10D reference snapshot. Deploy the reviewed migration, not this file.
-- Static identity/shape/scope only. S10E owns monotonic CAS, append-only writer APIs,
-- registration/capacity preflight and provider evidence. No lease/job-state release.
-- Create all four output tables before adding cyclic disposition/slot foreign keys.
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
    CONSTRAINT CK_SourceOutputDisposition_File CHECK ((FileKind = 'slot' AND DATALENGTH(FileKind) = 4 AND SlotFileID IS NOT NULL AND SlotFileID = FileID AND DATALENGTH(SlotFileID) = DATALENGTH(FileID) AND IndexFileID IS NULL AND FromSlotVersion IS NOT NULL AND ToSlotVersion IS NOT NULL AND FromSlotVersion > 0 AND ToSlotVersion > FromSlotVersion AND ToSlotVersion - FromSlotVersion = 1) OR (FileKind = 'index' AND DATALENGTH(FileKind) = 5 AND IndexFileID IS NOT NULL AND IndexFileID = FileID AND DATALENGTH(IndexFileID) = DATALENGTH(FileID) AND SlotFileID IS NULL AND FromSlotVersion IS NULL AND ToSlotVersion IS NULL)),
    CONSTRAINT CK_SourceOutputDisposition_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0 AND NewKVK_NO > 0),
    CONSTRAINT CK_SourceOutputDisposition_Action CHECK (Action IN ('retire','quarantine','clear','assign') AND DATALENGTH(Action) = LEN(Action)),
    CONSTRAINT CK_SourceOutputDisposition_Epoch CHECK (OldEpoch > 0 AND NewEpoch >= OldEpoch AND NewEpoch - OldEpoch BETWEEN 0 AND 1 AND ((NewEpoch = OldEpoch AND NewKVK_NO = KVK_NO AND NewChoiceID = ChoiceID) OR (NewEpoch > OldEpoch AND Action = 'clear'))),
    CONSTRAINT CK_SourceOutputDisposition_Owner CHECK (Fence > 0 AND SequenceNo > 0 AND FromPoolVersion > 0 AND ToPoolVersion > FromPoolVersion AND ToPoolVersion - FromPoolVersion = 1),
    CONSTRAINT CK_SourceOutputDisposition_Attempt CHECK ((JobID IS NULL AND ConsumerKind IS NULL AND DestinationSetHash IS NULL AND AttemptID IS NULL AND PartNo IS NULL AND AttemptEpoch IS NULL AND Action <> 'assign') OR (JobID IS NOT NULL AND ConsumerKind IS NOT NULL AND ConsumerKind = 'new_source' AND DATALENGTH(ConsumerKind) = 10 AND DestinationSetHash IS NOT NULL AND AttemptID IS NOT NULL AND PartNo IS NOT NULL AND PartNo BETWEEN 1 AND 1024 AND AttemptEpoch IS NOT NULL AND AttemptEpoch = OldEpoch)),
    CONSTRAINT CK_SourceOutputDisposition_Legacy CHECK ((LegacyPublicationID IS NULL AND LegacyPeriodID IS NULL AND LegacyDestinationKind IS NULL AND LegacyDestinationID IS NULL) OR (LegacyPublicationID IS NOT NULL AND LegacyPeriodID IS NOT NULL AND LegacyDestinationKind IS NOT NULL AND LegacyDestinationKind = 'sheets' AND DATALENGTH(LegacyDestinationKind) = 6 AND LegacyDestinationID IS NOT NULL)),
    CONSTRAINT CK_SourceOutputDisposition_Actor CHECK (LEN(Actor) > 0 AND DATALENGTH(Actor) = DATALENGTH(LTRIM(RTRIM(Actor))) AND LEN(Reason) > 0),
    CONSTRAINT CK_SourceOutputDisposition_Evidence CHECK (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536)
);
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
ALTER TABLE KVK.SourceOutputDisposition WITH CHECK ADD CONSTRAINT FK_SourceOutputDisposition_LegacyIndex FOREIGN KEY (PoolID, LegacyDestinationID) REFERENCES KVK.SourceOutputPool (PoolID, IndexFileID);
