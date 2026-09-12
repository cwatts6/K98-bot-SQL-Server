SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S8A reference snapshot; deploy the reviewed migration, not this file.
-- SQL enforces static scope, shape and uniqueness, not temporal immutability or eligibility.
-- S8B alone supplies authorized writer APIs, CAS, lock ordering and atomic public intent.
CREATE TABLE KVK.SourceCompleteSelection
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    UpdateID uniqueidentifier NOT NULL,
    PublicationID uniqueidentifier NOT NULL,
    PublicSelectionVersion bigint NOT NULL,
    SelectedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceCompleteSelection PRIMARY KEY (SourceKey, KVK_NO, PeriodID),
    CONSTRAINT FK_SourceCompleteSelection_Update FOREIGN KEY (SourceKey, KVK_NO, PeriodID, UpdateID) REFERENCES KVK.SourceUpdate (SourceKey, KVK_NO, PeriodID, UpdateID),
    CONSTRAINT FK_SourceCompleteSelection_Publication FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT CK_SourceCompleteSelection_Version CHECK (PublicSelectionVersion > 0),
    CONSTRAINT CK_SourceCompleteSelection_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
