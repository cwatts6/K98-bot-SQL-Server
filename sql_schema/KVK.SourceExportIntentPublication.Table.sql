SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S8A reference snapshot; deploy the reviewed migration, not this file.
-- SQL enforces static scope, shape and uniqueness, not temporal immutability or eligibility.
-- S8B alone supplies authorized writer APIs, CAS, lock ordering and atomic public intent.
CREATE TABLE KVK.SourceExportIntentPublication
(
    IntentID uniqueidentifier NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    UpdateID uniqueidentifier NOT NULL,
    PublicationID uniqueidentifier NOT NULL,
    PublicSelectionVersion bigint NOT NULL,
    ConfigVersionID uniqueidentifier NOT NULL,
    CONSTRAINT PK_SourceExportIntentPublication PRIMARY KEY (IntentID, PeriodID),
    CONSTRAINT FK_SourceExportIntentPublication_Intent FOREIGN KEY (SourceKey, KVK_NO, IntentID) REFERENCES KVK.SourceExportIntent (SourceKey, KVK_NO, IntentID),
    CONSTRAINT FK_SourceExportIntentPublication_Update FOREIGN KEY (SourceKey, KVK_NO, PeriodID, UpdateID, ConfigVersionID) REFERENCES KVK.SourceUpdate (SourceKey, KVK_NO, PeriodID, UpdateID, ConfigVersionID),
    CONSTRAINT FK_SourceExportIntentPublication_Publication FOREIGN KEY (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID),
    CONSTRAINT CK_SourceExportIntentPublication_Version CHECK (PublicSelectionVersion > 0),
    CONSTRAINT CK_SourceExportIntentPublication_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
