SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceSelection
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    PublicationID uniqueidentifier NOT NULL,
    SelectionVersion bigint NOT NULL,
    SelectedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceSelection PRIMARY KEY (SourceKey, KVK_NO, PeriodID),
    CONSTRAINT FK_SourceSelection_Publication FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT CK_SourceSelection_Version CHECK (SelectionVersion > 0),
    CONSTRAINT CK_SourceSelection_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
