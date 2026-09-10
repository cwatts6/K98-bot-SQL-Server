SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceRoster
(
    RosterID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    RosterVersion int NOT NULL,
    B0RevisionID uniqueidentifier NOT NULL,
    ScopeDigest binary(32) NOT NULL,
    MemberDigest binary(32) NOT NULL,
    MemberCount int NOT NULL,
    ApprovedUTC datetime2(0) NOT NULL,
    ApprovedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceRoster PRIMARY KEY (RosterID),
    CONSTRAINT UQ_SourceRoster_Version UNIQUE (SourceKey, KVK_NO, RosterVersion),
    CONSTRAINT UQ_SourceRoster_Scope UNIQUE (SourceKey, KVK_NO, RosterID),
    CONSTRAINT FK_SourceRoster_B0 FOREIGN KEY (SourceKey, KVK_NO, B0RevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT CK_SourceRoster_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceRoster_Version CHECK (RosterVersion > 0 AND MemberCount > 0 AND MemberCount <= 50000),
    CONSTRAINT CK_SourceRoster_Provenance CHECK (LEN(ApprovedBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);
