SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceScanBinding
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    LogicalScanID int NOT NULL,
    CONSTRAINT PK_SourceScanBinding PRIMARY KEY (ConfigVersionID, LogicalScanID),
    CONSTRAINT FK_SourceScanBinding_Config FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT FK_SourceScanBinding_Scan FOREIGN KEY (SourceKey, KVK_NO, LogicalScanID) REFERENCES KVK.SourceLogicalScan (SourceKey, KVK_NO, LogicalScanID),
    CONSTRAINT CK_SourceScanBinding_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
