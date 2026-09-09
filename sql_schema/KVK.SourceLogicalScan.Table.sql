SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceLogicalScan
(
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    LogicalScanID int NOT NULL,
    ObservationID uniqueidentifier NOT NULL,
    AllocatedUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceLogicalScan PRIMARY KEY (SourceKey, KVK_NO, LogicalScanID),
    CONSTRAINT UQ_SourceLogicalScan_Observation UNIQUE (SourceKey, KVK_NO, ObservationID),
    CONSTRAINT FK_SourceLogicalScan_Observation FOREIGN KEY (SourceKey, KVK_NO, ObservationID) REFERENCES KVK.SourceObservation (SourceKey, KVK_NO, ObservationID),
    CONSTRAINT CK_SourceLogicalScan_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceLogicalScan_ID CHECK (LogicalScanID > 0)
);
