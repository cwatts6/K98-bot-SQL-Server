SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.MaintenanceConfigurationWork (
    ID int NOT NULL CONSTRAINT PK_MaintenanceConfigurationWork PRIMARY KEY CHECK(ID=1),
    DueRows bigint NOT NULL DEFAULT 0,
    CompletedRows bigint NOT NULL DEFAULT 0,
    LastBatchRows int NOT NULL DEFAULT 0,
    LastScan int NOT NULL DEFAULT 0,
    LargeBatchGeneration bigint NOT NULL DEFAULT 0,
    CompletedLargeBatchGeneration bigint NOT NULL DEFAULT 0,
    UpkeepCompletedGeneration bigint NOT NULL DEFAULT 0,
    UpkeepDisposition varchar(12) NOT NULL DEFAULT 'not_run' CHECK(UpkeepDisposition IN ('not_run','ineligible','complete')),
    FirstLogErrorNumber int NULL,
    CONSTRAINT CK_MaintenanceConfigurationWork_Rows CHECK
      (DueRows>=CompletedRows AND CompletedRows>=0 AND LastBatchRows>=0),
    CONSTRAINT CK_MaintenanceConfigurationWork_Generation CHECK
      (LargeBatchGeneration>=CompletedLargeBatchGeneration AND CompletedLargeBatchGeneration>=0
       AND UpkeepCompletedGeneration>=0)
);
INSERT dbo.MaintenanceConfigurationWork(ID) VALUES(1);
