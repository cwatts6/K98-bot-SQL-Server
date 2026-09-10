SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceImportAttempt
(
    AttemptID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    GuildID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    MessageID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AttachmentID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActionKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ArtifactHash binary(32) NOT NULL,
    ActorID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChannelID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OriginalFilename nvarchar(512) NOT NULL,
    ReceivedUTC datetime2(0) NOT NULL,
    Status varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    DiagnosticSummary nvarchar(512) NOT NULL,
    ObservationRevisionID uniqueidentifier NULL,
    AggregateRevisionID uniqueidentifier NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceImportAttempt PRIMARY KEY (AttemptID),
    CONSTRAINT UQ_SourceImportAttempt_Replay UNIQUE (GuildID, MessageID, AttachmentID, ActionKey),
    CONSTRAINT FK_SourceImportAttempt_Artifact FOREIGN KEY (ArtifactHash) REFERENCES KVK.SourceArtifact (ArtifactHash),
    CONSTRAINT CK_SourceImportAttempt_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceImportAttempt_Replay CHECK (LEN(GuildID) > 0 AND LEN(MessageID) > 0 AND LEN(AttachmentID) > 0 AND LEN(ActionKey) > 0 AND LEN(ChannelID) > 0 AND LEN(ActorID) > 0),
    CONSTRAINT CK_SourceImportAttempt_Result CHECK ((Status IN ('accepted','duplicate') AND ((ObservationRevisionID IS NOT NULL AND AggregateRevisionID IS NULL) OR (ObservationRevisionID IS NULL AND AggregateRevisionID IS NOT NULL))) OR (Status NOT IN ('accepted','duplicate') AND ObservationRevisionID IS NULL AND AggregateRevisionID IS NULL)),
    CONSTRAINT CK_SourceImportAttempt_Status CHECK (Status IN ('received','validated','rejected','accepted','duplicate','conflict')),
    CONSTRAINT CK_SourceImportAttempt_Provenance CHECK (ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);

-- Added after all twelve tables exist; an alias retains its exact accepted outcome.
ALTER TABLE KVK.SourceImportAttempt WITH CHECK ADD CONSTRAINT FK_SourceImportAttempt_ObservationRevision FOREIGN KEY (SourceKey, KVK_NO, ObservationRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID);
ALTER TABLE KVK.SourceImportAttempt WITH CHECK ADD CONSTRAINT FK_SourceImportAttempt_AggregateRevision FOREIGN KEY (SourceKey, KVK_NO, AggregateRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, RevisionID);
