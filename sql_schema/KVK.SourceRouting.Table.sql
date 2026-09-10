SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceRouting
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    DisplayPeriodID uniqueidentifier NULL,
    Enabled bit NOT NULL CONSTRAINT DF_SourceRouting_Enabled DEFAULT (0),
    RoutingVersion bigint NOT NULL,
    CapabilitiesVersion varchar(64) COLLATE Latin1_General_100_BIN2 NULL,
    ApprovedBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    ApprovedUTC datetime2(0) NULL,
    CONSTRAINT PK_SourceRouting PRIMARY KEY (KVK_NO),
    CONSTRAINT FK_SourceRouting_Period FOREIGN KEY (SourceKey, KVK_NO, DisplayPeriodID) REFERENCES KVK.SourceSelection (SourceKey, KVK_NO, PeriodID),
    CONSTRAINT CK_SourceRouting_Version CHECK (RoutingVersion > 0),
    CONSTRAINT CK_SourceRouting_Approval CHECK (Enabled = 0 OR (DisplayPeriodID IS NOT NULL AND CapabilitiesVersion IS NOT NULL AND LEN(CapabilitiesVersion) > 0 AND ApprovedBy IS NOT NULL AND LEN(ApprovedBy) > 0 AND ApprovedUTC IS NOT NULL)),
    CONSTRAINT CK_SourceRouting_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
