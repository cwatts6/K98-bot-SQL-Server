SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.ProcessingPipelineStage
(
    RunID uniqueidentifier NOT NULL,
    Stage varchar(24) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OperationID uniqueidentifier NOT NULL,
    State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,
    DecisionJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,
    UpdatedUTC datetime2(3) NOT NULL CONSTRAINT DF_ProcessingPipelineStage_Updated DEFAULT SYSUTCDATETIME(),
    Version bigint NOT NULL CONSTRAINT DF_ProcessingPipelineStage_Version DEFAULT 1,
    CONSTRAINT PK_ProcessingPipelineStage PRIMARY KEY (RunID,Stage),
    CONSTRAINT FK_ProcessingPipelineStage_Run FOREIGN KEY (RunID) REFERENCES dbo.ProcessingPipelineRun(RunID),
    CONSTRAINT UQ_ProcessingPipelineStage_Operation UNIQUE (OperationID),
    CONSTRAINT CK_ProcessingPipelineStage_Stage CHECK (Stage IN ('import','player_cache','name_cache','maintenance','configuration','target_cache','export')),
    CONSTRAINT CK_ProcessingPipelineStage_State CHECK (State IN ('not_started','running','observed','unconfirmed','skipped') AND Version>0),
    CONSTRAINT CK_ProcessingPipelineStage_Evidence CHECK (
        (State IN ('not_started','running') AND EvidenceJson IS NULL)
        OR (State IN ('observed','unconfirmed','skipped') AND EvidenceJson IS NOT NULL
            AND ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=32768)),
    CONSTRAINT CK_ProcessingPipelineStage_Decision CHECK (DecisionJson IS NULL OR (ISJSON(DecisionJson)=1 AND DATALENGTH(DecisionJson)<=32768))
);
