SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.StatsImportReportContinuation
(
    PreparationID uniqueidentifier NOT NULL,
    ContractVersion int NOT NULL CONSTRAINT DF_StatsReport_Contract DEFAULT 1,
    InputDigest binary(32) NOT NULL,
    ScanOrder int NOT NULL,
    LatestScanOrder int NOT NULL,
    KingdomRank float NOT NULL,
    KingdomSeed nvarchar(100) NOT NULL,
    ConfigurationJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RowsKS5 int NOT NULL,
    RowsKS4 int NOT NULL,
    ImportStartedUTC datetime NOT NULL,
    CompletedStage tinyint NOT NULL CONSTRAINT DF_StatsReport_Stage DEFAULT 0,
    ReportKVK int NULL,
    ReportScan int NULL,
    PrefixCompletedUTC datetime2(3) NULL,
    UploadCompletedUTC datetime2(3) NULL,
    SummaryCompletedUTC datetime2(3) NULL,
    RecoveryActionID uniqueidentifier NULL,
    RecoveryEvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NULL,
    RecoveryState varchar(12) COLLATE Latin1_General_100_BIN2 NULL,
    Version bigint NOT NULL CONSTRAINT DF_StatsReport_Version DEFAULT 1,
    CONSTRAINT PK_StatsImportReportContinuation PRIMARY KEY (PreparationID),
    CONSTRAINT FK_StatsReport_Execution FOREIGN KEY (PreparationID) REFERENCES dbo.StatsImportExecution(PreparationID),
    CONSTRAINT CK_StatsReport_Contract CHECK (ContractVersion=1 AND Version>0 AND RowsKS5>=0 AND RowsKS4>=0),
    CONSTRAINT CK_StatsReport_Config CHECK (ISJSON(ConfigurationJson)=1 AND DATALENGTH(ConfigurationJson)<=1048576),
    CONSTRAINT CK_StatsReport_Stage CHECK (
        (CompletedStage=0 AND PrefixCompletedUTC IS NULL AND UploadCompletedUTC IS NULL AND SummaryCompletedUTC IS NULL AND ReportKVK IS NULL AND ReportScan IS NULL)
        OR (CompletedStage=1 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NULL AND SummaryCompletedUTC IS NULL)
        OR (CompletedStage=2 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NOT NULL AND SummaryCompletedUTC IS NULL)
        OR (CompletedStage=3 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NOT NULL AND SummaryCompletedUTC IS NOT NULL)),
    CONSTRAINT CK_StatsReport_Action CHECK (
        (RecoveryActionID IS NULL AND RecoveryEvidenceHash IS NULL AND RecoveryState IS NULL)
        OR (RecoveryActionID IS NOT NULL AND RecoveryEvidenceHash IS NOT NULL
            AND RecoveryEvidenceHash NOT LIKE '%[^0-9a-f]%'
            AND RecoveryState IS NOT NULL AND RecoveryState IN ('running','failed','completed')))
);
