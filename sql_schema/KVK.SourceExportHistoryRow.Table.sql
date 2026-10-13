SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2 reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceExportHistoryRow
(
    IntentID uniqueidentifier NOT NULL,
    GuildID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    HistoryVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Ordinal bigint NOT NULL,
    AttemptID uniqueidentifier NOT NULL,
    PayloadJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RowHash binary(32) NOT NULL,
    CONSTRAINT PK_SourceExportHistoryRow PRIMARY KEY (IntentID,GuildID,HistoryVersion,Ordinal),
    CONSTRAINT UQ_SourceExportHistoryRow_Attempt UNIQUE (IntentID,GuildID,HistoryVersion,AttemptID),
    CONSTRAINT FK_SourceExportHistoryRow_History FOREIGN KEY (IntentID,GuildID,HistoryVersion) REFERENCES KVK.SourceExportHistory (IntentID,GuildID,HistoryVersion),
    CONSTRAINT CK_SourceExportHistoryRow_Ordinal CHECK (Ordinal>0),
    CONSTRAINT CK_SourceExportHistoryRow_Payload CHECK (ISJSON(PayloadJson)=1 AND DATALENGTH(PayloadJson)<=16384)
);
