SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10D reference snapshot. Deploy the reviewed migration, not this file.
-- Static identity/shape/scope only. S10E owns monotonic CAS, append-only writer APIs,
-- registration/capacity preflight and provider evidence. No lease/job-state release.
-- Create all four output tables before adding cyclic disposition/slot foreign keys.
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
    CONSTRAINT CK_SourceOutputSlot_Kind CHECK (FileKind = 'slot' AND DATALENGTH(FileKind) = 4),
    CONSTRAINT CK_SourceOutputSlot_Counters CHECK (SlotNo BETWEEN 1 AND 16 AND Epoch > 0 AND Version > 0 AND UpdatedUTC >= CreatedUTC),
    CONSTRAINT CK_SourceOutputSlot_State CHECK (State IN ('free','staging','active','quarantined','retired') AND DATALENGTH(State) = LEN(State)),
    CONSTRAINT CK_SourceOutputSlot_Ownership CHECK ((OwnerID IS NULL AND Fence >= 0 AND State <> 'staging') OR (OwnerID IS NOT NULL AND Fence > 0 AND State IN ('staging','active','quarantined'))),
    CONSTRAINT CK_SourceOutputSlot_Assignment CHECK ((AssignmentID IS NULL AND AssignmentAction IS NULL AND AttemptID IS NULL AND PartNo IS NULL AND AssignmentVersion IS NULL AND State IN ('free','quarantined','retired')) OR (AssignmentID IS NOT NULL AND AssignmentAction IS NOT NULL AND AssignmentAction = 'assign' AND DATALENGTH(AssignmentAction) = 6 AND AttemptID IS NOT NULL AND PartNo IS NOT NULL AND PartNo BETWEEN 1 AND 1024 AND AssignmentVersion IS NOT NULL AND AssignmentVersion > 0 AND AssignmentVersion <= Version AND State <> 'free')),
    CONSTRAINT CK_SourceOutputSlot_Disposition CHECK ((LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'quarantined' AND AssignmentID IS NULL) OR (LastDispositionID IS NOT NULL AND LastAction IS NOT NULL AND DATALENGTH(LastAction) = LEN(LastAction) AND LastDispositionVersion IS NOT NULL AND LastDispositionVersion > 0 AND LastDispositionVersion <= Version AND ((State = 'free' AND LastAction = 'clear') OR (State IN ('staging','active') AND LastAction = 'assign' AND LastDispositionID = AssignmentID) OR (State = 'quarantined' AND LastAction = 'quarantine') OR (State = 'retired' AND LastAction = 'retire')))),
    CONSTRAINT CK_SourceOutputSlot_Quarantine CHECK ((State = 'quarantined' AND QuarantineReason IS NOT NULL AND LEN(QuarantineReason) > 0) OR (State <> 'quarantined' AND QuarantineReason IS NULL))
);
CREATE INDEX IX_SourceOutputSlot_Availability ON KVK.SourceOutputSlot (PoolID, Epoch, State, SlotNo);
CREATE INDEX IX_SourceOutputSlot_Attempt ON KVK.SourceOutputSlot (AttemptID, PartNo) WHERE AttemptID IS NOT NULL;
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_File FOREIGN KEY (FileID, FileKind) REFERENCES KVK.SourceOutputFile (FileID, FileKind);
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_Pool FOREIGN KEY (PoolID) REFERENCES KVK.SourceOutputPool (PoolID);
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_Part FOREIGN KEY (AttemptID, PartNo, FileID) REFERENCES dbo.ExportAttemptPart (AttemptID, PartNo, FileID);
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_Assignment FOREIGN KEY (AssignmentID, PoolID, FileID, Epoch, AttemptID, PartNo, AssignmentVersion, AssignmentAction) REFERENCES KVK.SourceOutputDisposition (DispositionID, PoolID, FileID, NewEpoch, AttemptID, PartNo, ToSlotVersion, Action);
ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT FK_SourceOutputSlot_Disposition FOREIGN KEY (LastDispositionID, PoolID, FileID, Epoch, LastAction, LastDispositionVersion) REFERENCES KVK.SourceOutputDisposition (DispositionID, PoolID, FileID, NewEpoch, Action, ToSlotVersion);
