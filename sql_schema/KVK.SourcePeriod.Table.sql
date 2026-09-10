SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourcePeriod
(
    PeriodID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CoverageStartUTC datetime2(0) NOT NULL,
    CoverageEndUTC datetime2(0) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourcePeriod PRIMARY KEY (PeriodID),
    CONSTRAINT UQ_SourcePeriod_Key UNIQUE (SourceKey, KVK_NO, PeriodKey),
    CONSTRAINT UQ_SourcePeriod_Kind UNIQUE (SourceKey, KVK_NO, PeriodKey, PeriodKind),
    CONSTRAINT UQ_SourcePeriod_Scope UNIQUE (SourceKey, KVK_NO, PeriodID),
    CONSTRAINT UQ_SourcePeriod_Identity UNIQUE (SourceKey, KVK_NO, PeriodID, PeriodKey),
    CONSTRAINT CK_SourcePeriod_Kind CHECK (DATALENGTH(PeriodKind) = LEN(PeriodKind) AND DATALENGTH(PeriodKey) = LEN(PeriodKey) AND ((PeriodKind = 'fight' AND PeriodKey LIKE 'fight:%' AND LEN(PeriodKey) > 6) OR (PeriodKind = 'overall' AND PeriodKey = 'overall') OR (PeriodKind = 'no_fight' AND PeriodKey LIKE 'no_fight:%' AND LEN(PeriodKey) > 9))),
    CONSTRAINT CK_SourcePeriod_Time CHECK (CoverageEndUTC IS NULL OR CoverageEndUTC >= CoverageStartUTC),
    CONSTRAINT CK_SourcePeriod_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
