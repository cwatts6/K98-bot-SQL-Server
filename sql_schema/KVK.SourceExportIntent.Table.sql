SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S8A reference snapshot; deploy the reviewed migration, not this file.
-- SQL enforces static scope, shape and uniqueness, not temporal immutability or eligibility.
-- S8B alone supplies authorized writer APIs, CAS, lock ordering and atomic public intent.
CREATE TABLE KVK.SourceExportIntent
(
    IntentID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    CommitSequence bigint NOT NULL,
    VectorHash binary(32) NOT NULL,
    ExportSchemaVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    IntentState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    SupersededByIntentID uniqueidentifier NULL,
    CONSTRAINT PK_SourceExportIntent PRIMARY KEY (IntentID),
    CONSTRAINT UQ_SourceExportIntent_Scope UNIQUE (SourceKey, KVK_NO, IntentID),
    CONSTRAINT UQ_SourceExportIntent_Sequence UNIQUE (SourceKey, KVK_NO, CommitSequence),
    CONSTRAINT UQ_SourceExportIntent_Vector UNIQUE (SourceKey, KVK_NO, VectorHash, ExportSchemaVersion),
    CONSTRAINT FK_SourceExportIntent_Choice FOREIGN KEY (KVK_NO, SourceKey, ChoiceID) REFERENCES KVK.SeasonSource (KVK_NO, SourceKey, ChoiceID),
    CONSTRAINT FK_SourceExportIntent_Superseded FOREIGN KEY (SourceKey, KVK_NO, SupersededByIntentID) REFERENCES KVK.SourceExportIntent (SourceKey, KVK_NO, IntentID),
    CONSTRAINT CK_SourceExportIntent_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceExportIntent_Version CHECK (CommitSequence > 0 AND LEN(ExportSchemaVersion) > 0 AND DATALENGTH(ExportSchemaVersion) = LEN(ExportSchemaVersion)),
    CONSTRAINT CK_SourceExportIntent_State CHECK (DATALENGTH(IntentState) = LEN(IntentState) AND IntentState IN ('pending','waiting_destination','materialized','coalesced','confirmed','blocked') AND ((IntentState = 'coalesced' AND SupersededByIntentID IS NOT NULL AND SupersededByIntentID <> IntentID) OR (IntentState <> 'coalesced' AND SupersededByIntentID IS NULL)))
);
