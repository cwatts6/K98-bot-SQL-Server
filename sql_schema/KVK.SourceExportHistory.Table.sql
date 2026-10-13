SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Reference only; deploy reviewed migration.
CREATE TABLE KVK.SourceExportHistory
(
    IntentID uniqueidentifier NOT NULL,
    GuildID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    HistoryVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    VectorHash binary(32) NOT NULL,
    CapturedUTC datetime2(0) NOT NULL,
    AttemptCount bigint NOT NULL,
    ContentHash binary(32) NOT NULL,
    CONSTRAINT PK_SourceExportHistory PRIMARY KEY (IntentID,GuildID,HistoryVersion),
    CONSTRAINT FK_SourceExportHistory_Intent FOREIGN KEY (SourceKey,KVK_NO,IntentID) REFERENCES KVK.SourceExportIntent (SourceKey,KVK_NO,IntentID),
    CONSTRAINT CK_SourceExportHistory_Scope CHECK (SourceKey='snapshot_report_v1' AND DATALENGTH(SourceKey)=18 AND KVK_NO>0),
    CONSTRAINT CK_SourceExportHistory_Guild CHECK (DATALENGTH(GuildID) BETWEEN 1 AND 32 AND GuildID NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_SourceExportHistory_Version CHECK (HistoryVersion='source_export_history_v1' AND DATALENGTH(HistoryVersion)=24),
    CONSTRAINT CK_SourceExportHistory_Count CHECK (AttemptCount>=0)
);
