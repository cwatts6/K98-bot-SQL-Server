SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceConfigVersion
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ConfigVersion int NOT NULL,
    RosterID uniqueidentifier NOT NULL,
    ConfigContentHash binary(32) NOT NULL,
    WindowDigest binary(32) NOT NULL,
    MappingDigest binary(32) NOT NULL,
    WeightDigest binary(32) NOT NULL,
    ApprovedUTC datetime2(0) NOT NULL,
    ApprovedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceConfigVersion PRIMARY KEY (ConfigVersionID),
    CONSTRAINT UQ_SourceConfigVersion_Version UNIQUE (SourceKey, KVK_NO, ConfigVersion),
    CONSTRAINT UQ_SourceConfigVersion_Scope UNIQUE (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT UQ_SourceConfigVersion_Roster UNIQUE (SourceKey, KVK_NO, ConfigVersionID, RosterID),
    CONSTRAINT FK_SourceConfigVersion_Roster FOREIGN KEY (SourceKey, KVK_NO, RosterID) REFERENCES KVK.SourceRoster (SourceKey, KVK_NO, RosterID),
    CONSTRAINT CK_SourceConfigVersion_Version CHECK (ConfigVersion > 0),
    CONSTRAINT CK_SourceConfigVersion_Provenance CHECK (LEN(ApprovedBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536),
    CONSTRAINT CK_SourceConfigVersion_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
