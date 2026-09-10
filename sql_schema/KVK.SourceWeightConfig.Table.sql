SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceWeightConfig
(
    ConfigVersionID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    WeightT4X decimal(38,12) NOT NULL,
    WeightT5Y decimal(38,12) NOT NULL,
    WeightDeadsZ decimal(38,12) NOT NULL,
    WeightT4XSource varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    WeightT5YSource varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    WeightDeadsZSource varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EffectiveFromUTC datetime2(0) NOT NULL,
    CONSTRAINT PK_SourceWeightConfig PRIMARY KEY (ConfigVersionID),
    CONSTRAINT FK_SourceWeightConfig_Config FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID),
    CONSTRAINT CK_SourceWeightConfig_Strings CHECK (LEN(WeightT4XSource) > 0 AND LEN(WeightT5YSource) > 0 AND LEN(WeightDeadsZSource) > 0),
    CONSTRAINT CK_SourceWeightConfig_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
