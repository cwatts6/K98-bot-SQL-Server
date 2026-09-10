SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceArtifact
(
    ArtifactHash binary(32) NOT NULL,
    ByteCount bigint NOT NULL,
    StorageKey nvarchar(512) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceArtifact PRIMARY KEY (ArtifactHash),
    CONSTRAINT CK_SourceArtifact_Bytes CHECK (ByteCount > 0 AND ByteCount <= 20971520),
    CONSTRAINT CK_SourceArtifact_Storage CHECK (StorageKey = LOWER(CONVERT(varchar(64), ArtifactHash, 2)) + N'.xlsx' AND DATALENGTH(StorageKey) = 138)
);
