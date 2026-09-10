SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceWindowConfig
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    WindowName nvarchar(40) COLLATE Latin1_General_CI_AS NOT NULL,
    WindowSeq tinyint NULL,
    StartScanID int NULL,
    EndScanID int NULL,
    Notes nvarchar(200) NULL,
    UpdatedAtUTC datetime2(0) NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CONSTRAINT PK_SourceWindowConfig PRIMARY KEY (ConfigVersionID, WindowName),
    CONSTRAINT UQ_SourceWindowConfig_Period UNIQUE (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT FK_SourceWindowConfig_Config FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT FK_SourceWindowConfig_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodKey) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodKey),
    CONSTRAINT CK_SourceWindowConfig_Bounds CHECK ((StartScanID IS NULL OR StartScanID > 0) AND (EndScanID IS NULL OR EndScanID > 0) AND (EndScanID IS NULL OR StartScanID IS NULL OR EndScanID >= StartScanID)),
    CONSTRAINT CK_SourceWindowConfig_Name CHECK (LEN(WindowName) > 0),
    CONSTRAINT CK_SourceWindowConfig_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
