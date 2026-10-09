SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.StatsImportExecution
(
    PreparationID uniqueidentifier NOT NULL,
    CompletedFileName nvarchar(260) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OwnerID uniqueidentifier NOT NULL,
    Fence bigint NOT NULL,
    State varchar(24) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ScanOrder int NULL,
    LastRunCounter int NULL,
    ErrorNumber int NULL,
    ErrorProcedure nvarchar(128) NULL,
    ErrorLine int NULL,
    Resolution varchar(24) COLLATE Latin1_General_100_BIN2 NULL,
    ResolvedBy nvarchar(128) NULL,
    ResolutionReason nvarchar(512) NULL,
    ResolvedUTC datetime2(3) NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_StatsImportExecution_Created DEFAULT SYSUTCDATETIME(),
    UpdatedUTC datetime2(3) NOT NULL CONSTRAINT DF_StatsImportExecution_Updated DEFAULT SYSUTCDATETIME(),
    Version bigint NOT NULL CONSTRAINT DF_StatsImportExecution_Version DEFAULT 1,
    CONSTRAINT PK_StatsImportExecution PRIMARY KEY (PreparationID),
    CONSTRAINT FK_StatsImportExecution_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
    CONSTRAINT UQ_StatsImportExecution_File UNIQUE (CompletedFileName),
    CONSTRAINT CK_StatsImportExecution_State CHECK (State IN ('prepared','running','import_committed','completed','rolled_back','partial')),
    CONSTRAINT CK_StatsImportExecution_Counters CHECK (Fence > 0 AND Version > 0 AND UpdatedUTC >= CreatedUTC),
    CONSTRAINT CK_StatsImportExecution_Receipt CHECK ((State NOT IN ('import_committed','completed','partial') OR ScanOrder IS NOT NULL) AND (State <> 'completed' OR LastRunCounter IS NOT NULL)),
    CONSTRAINT CK_StatsImportExecution_Resolution CHECK ((Resolution IS NULL AND ResolvedBy IS NULL AND ResolutionReason IS NULL AND ResolvedUTC IS NULL) OR (Resolution IN ('release_failure','supersede_partial') AND ResolvedBy IS NOT NULL AND ResolutionReason IS NOT NULL AND ResolvedUTC IS NOT NULL)),
    CONSTRAINT CK_StatsImportExecution_File CHECK (DATALENGTH(CompletedFileName)=96 AND CompletedFileName LIKE N'stats[_]%.ready.csv' AND SUBSTRING(CompletedFileName,7,32) NOT LIKE N'%[^0-9a-f]%')
);
CREATE INDEX IX_StatsImportExecution_State ON dbo.StatsImportExecution(State,UpdatedUTC,PreparationID);
