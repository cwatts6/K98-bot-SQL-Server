SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceAction
(
    ActionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    ActionType varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ExpectedSelectionVersion bigint NOT NULL,
    NewSelectionVersion bigint NOT NULL,
    OldPublicationID uniqueidentifier NULL,
    NewPublicationID uniqueidentifier NOT NULL,
    RequestID uniqueidentifier NULL,
    Reason nvarchar(1024) NOT NULL,
    ActionUTC datetime2(0) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceAction PRIMARY KEY (ActionID),
    CONSTRAINT UQ_SourceAction_Version UNIQUE (SourceKey, KVK_NO, PeriodID, NewSelectionVersion),
    CONSTRAINT FK_SourceAction_Old FOREIGN KEY (SourceKey, KVK_NO, PeriodID, OldPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT FK_SourceAction_New FOREIGN KEY (SourceKey, KVK_NO, PeriodID, NewPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT FK_SourceAction_Request FOREIGN KEY (SourceKey, KVK_NO, PeriodID, RequestID) REFERENCES KVK.SourceConfigRequest (SourceKey, KVK_NO, PeriodID, RequestID),
    CONSTRAINT CK_SourceAction_Version CHECK (ExpectedSelectionVersion >= 0 AND NewSelectionVersion > ExpectedSelectionVersion AND ((ExpectedSelectionVersion = 0 AND OldPublicationID IS NULL) OR (ExpectedSelectionVersion > 0 AND OldPublicationID IS NOT NULL))),
    CONSTRAINT CK_SourceAction_Type CHECK (ActionType IN ('publish','finalize','correct','endpoint_update','rollback','configure') AND DATALENGTH(ActionType) = LEN(ActionType) AND (ActionType <> 'endpoint_update' OR RequestID IS NOT NULL)),
    CONSTRAINT CK_SourceAction_Provenance CHECK (LEN(Actor) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536),
    CONSTRAINT CK_SourceAction_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
