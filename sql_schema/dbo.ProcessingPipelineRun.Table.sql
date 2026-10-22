SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.ProcessingPipelineRun
(
    RunID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    StorageOwner nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    InputsJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegistrationJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_ProcessingPipelineRun_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ProcessingPipelineRun PRIMARY KEY (RunID),
    CONSTRAINT CK_ProcessingPipelineRun_Json CHECK (
        ISJSON(InputsJson)=1 AND DATALENGTH(InputsJson)<=32768
        AND ISJSON(RegistrationJson)=1 AND DATALENGTH(RegistrationJson)<=1048576)
);
CREATE INDEX IX_ProcessingPipelineRun_Scope ON dbo.ProcessingPipelineRun(AccountKey,StorageOwner,RunID);
