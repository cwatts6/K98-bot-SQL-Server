SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceAggregateReport
(
    ReportID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SelectedRevisionID uniqueidentifier NULL,
    SelectionVersion bigint NOT NULL,
    CONSTRAINT PK_SourceAggregateReport PRIMARY KEY (ReportID),
    CONSTRAINT UQ_SourceAggregateReport_Period UNIQUE (SourceKey, KVK_NO, PeriodKey),
    CONSTRAINT UQ_SourceAggregateReport_Scope UNIQUE (SourceKey, KVK_NO, ReportID),
    CONSTRAINT UQ_SourceAggregateReport_Kind UNIQUE (SourceKey, KVK_NO, ReportID, PeriodKind),
    CONSTRAINT CK_SourceAggregateReport_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceAggregateReport_Period CHECK ((PeriodKind = 'fight' AND PeriodKey LIKE 'fight:%' AND LEN(PeriodKey) > 6) OR (PeriodKind = 'overall' AND PeriodKey = 'overall' AND DATALENGTH(PeriodKey) = 7)),
    CONSTRAINT CK_SourceAggregateReport_Selection CHECK (SelectionVersion > 0)
);

-- Added after all twelve tables exist. NULL is creation-only; S3B must fill it before commit.
ALTER TABLE KVK.SourceAggregateReport WITH CHECK ADD CONSTRAINT FK_SourceAggregateReport_SelectedRevision FOREIGN KEY (SourceKey, KVK_NO, ReportID, SelectedRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, ReportID, RevisionID);

-- S2B validates existing report families before adding this same-source/season/kind FK.
ALTER TABLE KVK.SourceAggregateReport WITH CHECK ADD CONSTRAINT FK_SourceAggregateReport_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodKey, PeriodKind) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodKey, PeriodKind);
