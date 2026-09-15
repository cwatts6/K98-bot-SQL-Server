SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10D reference snapshot. Deploy the reviewed migration, not this file.
-- Static identity/shape/scope only. S10E owns monotonic CAS, append-only writer APIs,
-- registration/capacity preflight and provider evidence. No lease/job-state release.
-- Create all four output tables before adding cyclic disposition/slot foreign keys.
CREATE TABLE KVK.SourceOutputFile
(
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegisteredBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegisteredUTC datetime2(0) NOT NULL,
    EvidenceHash binary(32) NOT NULL,
    EvidenceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceOutputFile PRIMARY KEY (FileID),
    CONSTRAINT UQ_SourceOutputFile_Kind UNIQUE (FileID, FileKind),
    CONSTRAINT UQ_SourceOutputFile_Resource UNIQUE (FileID, ResourceKey),
    CONSTRAINT UQ_SourceOutputFile_ResourceKey UNIQUE (ResourceKey),
    CONSTRAINT CK_SourceOutputFile_Identity CHECK (DATALENGTH(FileID) BETWEEN 6 AND 256 AND FileID NOT LIKE N'%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2),
    CONSTRAINT CK_SourceOutputFile_Kind CHECK (FileKind IN ('index','slot') AND DATALENGTH(FileKind) = LEN(FileKind)),
    CONSTRAINT CK_SourceOutputFile_Resource CHECK (ResourceKey = 'destination:' + CONVERT(varchar(128), FileID) AND DATALENGTH(ResourceKey) = 12 + DATALENGTH(FileID) / 2),
    CONSTRAINT CK_SourceOutputFile_Actor CHECK (LEN(RegisteredBy) > 0 AND DATALENGTH(RegisteredBy) = DATALENGTH(LTRIM(RTRIM(RegisteredBy)))),
    CONSTRAINT CK_SourceOutputFile_Evidence CHECK (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536)
);
ALTER TABLE KVK.SourceOutputFile WITH CHECK ADD CONSTRAINT FK_SourceOutputFile_Resource FOREIGN KEY (ResourceKey) REFERENCES dbo.ExportResource (ResourceKey);
