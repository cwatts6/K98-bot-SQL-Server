SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceObservationRevision
(
    RevisionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ObservationID uniqueidentifier NOT NULL,
    RevisionNo int NOT NULL,
    SemanticHash binary(32) NOT NULL,
    DigestVersion varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SchemaVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ArtifactHash binary(32) NOT NULL,
    SupersedesRevisionID uniqueidentifier NULL,
    AcceptanceState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AcceptedUTC datetime2(0) NOT NULL,
    AcceptedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    MetadataJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceObservationRevision PRIMARY KEY (RevisionID),
    CONSTRAINT UQ_SourceObservationRevision_Number UNIQUE (ObservationID, RevisionNo),
    CONSTRAINT UQ_SourceObservationRevision_Scope UNIQUE (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT UQ_SourceObservationRevision_Parent UNIQUE (SourceKey, KVK_NO, ObservationID, RevisionID),
    CONSTRAINT UQ_SourceObservationRevision_Digest UNIQUE (ObservationID, DigestVersion, SchemaVersion, SemanticHash),
    CONSTRAINT FK_SourceObservationRevision_Observation FOREIGN KEY (SourceKey, KVK_NO, ObservationID) REFERENCES KVK.SourceObservation (SourceKey, KVK_NO, ObservationID),
    CONSTRAINT FK_SourceObservationRevision_Artifact FOREIGN KEY (ArtifactHash) REFERENCES KVK.SourceArtifact (ArtifactHash),
    CONSTRAINT FK_SourceObservationRevision_Supersedes FOREIGN KEY (SourceKey, KVK_NO, ObservationID, SupersedesRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, ObservationID, RevisionID),
    CONSTRAINT CK_SourceObservationRevision_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceObservationRevision_Number CHECK (RevisionNo > 0),
    CONSTRAINT CK_SourceObservationRevision_Supersedes CHECK (SupersedesRevisionID IS NULL OR SupersedesRevisionID <> RevisionID),
    CONSTRAINT CK_SourceObservationRevision_State CHECK (AcceptanceState IN ('accepted','corrected') AND LEN(AcceptedBy) > 0 AND LEN(Reason) > 0 AND LEN(DigestVersion) > 0 AND LEN(SchemaVersion) > 0),
    CONSTRAINT CK_SourceObservationRevision_Metadata CHECK (ISJSON(MetadataJson) = 1 AND DATALENGTH(MetadataJson) <= 65536)
);
