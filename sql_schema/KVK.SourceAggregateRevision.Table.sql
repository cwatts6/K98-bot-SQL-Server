SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceAggregateRevision
(
    RevisionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ReportID uniqueidentifier NOT NULL,
    PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RevisionNo int NOT NULL,
    ArtifactHash binary(32) NOT NULL,
    SemanticHash binary(32) NOT NULL,
    DigestVersion varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SchemaVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ScanStartUTC datetime2(0) NOT NULL,
    TimePrecision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CoverageStartUTC datetime2(0) NOT NULL,
    CoverageEndUTC datetime2(0) NOT NULL,
    AsOfUTC datetime2(0) NOT NULL,
    ReportState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SupersedesRevisionID uniqueidentifier NULL,
    AcceptedUTC datetime2(0) NOT NULL,
    AcceptedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    MappingDigest binary(32) NOT NULL,
    ScopeDigest binary(32) NOT NULL,
    MetadataJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceAggregateRevision PRIMARY KEY (RevisionID),
    CONSTRAINT UQ_SourceAggregateRevision_Mapping UNIQUE (SourceKey, KVK_NO, RevisionID, MappingDigest),
    CONSTRAINT UQ_SourceAggregateRevision_Number UNIQUE (ReportID, RevisionNo),
    CONSTRAINT UQ_SourceAggregateRevision_Scope UNIQUE (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT UQ_SourceAggregateRevision_Parent UNIQUE (SourceKey, KVK_NO, ReportID, RevisionID),
    CONSTRAINT FK_SourceAggregateRevision_Report FOREIGN KEY (SourceKey, KVK_NO, ReportID, PeriodKind) REFERENCES KVK.SourceAggregateReport (SourceKey, KVK_NO, ReportID, PeriodKind),
    CONSTRAINT FK_SourceAggregateRevision_Artifact FOREIGN KEY (ArtifactHash) REFERENCES KVK.SourceArtifact (ArtifactHash),
    CONSTRAINT FK_SourceAggregateRevision_Supersedes FOREIGN KEY (SourceKey, KVK_NO, ReportID, SupersedesRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, ReportID, RevisionID),
    CONSTRAINT CK_SourceAggregateRevision_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceAggregateRevision_Number CHECK (RevisionNo > 0),
    CONSTRAINT CK_SourceAggregateRevision_Time CHECK (TimePrecision IN ('minute','second') AND (TimePrecision <> 'minute' OR DATEPART(SECOND, ScanStartUTC) = 0) AND CoverageEndUTC >= CoverageStartUTC AND AsOfUTC >= CoverageEndUTC),
    CONSTRAINT CK_SourceAggregateRevision_State CHECK (ReportState IN ('live','final','corrected_final') AND (PeriodKind <> 'overall' OR ReportState IN ('final','corrected_final')) AND (ReportState <> 'corrected_final' OR SupersedesRevisionID IS NOT NULL)),
    CONSTRAINT CK_SourceAggregateRevision_Supersedes CHECK (SupersedesRevisionID IS NULL OR SupersedesRevisionID <> RevisionID),
    CONSTRAINT CK_SourceAggregateRevision_Metadata CHECK (LEN(AcceptedBy) > 0 AND LEN(Reason) > 0 AND LEN(DigestVersion) > 0 AND LEN(SchemaVersion) > 0 AND ISJSON(MetadataJson) = 1 AND DATALENGTH(MetadataJson) <= 65536)
);
CREATE INDEX IX_SourceAggregateRevision_AsOf ON KVK.SourceAggregateRevision (ReportID, AsOfUTC);
