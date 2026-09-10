SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceCampConfig
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    Kingdom int NOT NULL,
    CampID tinyint NOT NULL,
    CampName nvarchar(40) COLLATE Latin1_General_CI_AS NOT NULL,
    CampKey nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CONSTRAINT PK_SourceCampConfig PRIMARY KEY (ConfigVersionID, Kingdom),
    CONSTRAINT UQ_SourceCampConfig_Attribution UNIQUE (ConfigVersionID, Kingdom, CampID),
    CONSTRAINT FK_SourceCampConfig_Config FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT CK_SourceCampConfig_Identity CHECK (Kingdom > 0 AND CampID BETWEEN 1 AND 8 AND LEN(CampName) > 0 AND LEN(CampKey) > 0 AND DATALENGTH(CampKey) = DATALENGTH(LTRIM(RTRIM(CampKey)))),
    CONSTRAINT CK_SourceCampConfig_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
CREATE INDEX IX_SourceCampConfig_Camp ON KVK.SourceCampConfig (ConfigVersionID, CampID);
