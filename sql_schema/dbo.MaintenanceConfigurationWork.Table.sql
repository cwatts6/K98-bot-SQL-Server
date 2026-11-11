SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.MaintenanceConfigurationWork (
    ID int NOT NULL CONSTRAINT PK_MaintenanceConfigurationWork PRIMARY KEY CONSTRAINT CK_MaintenanceConfigurationWork_ID CHECK(ID=1),
    DueRows bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_DueRows DEFAULT 0,
    CompletedRows bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_CompletedRows DEFAULT 0,
    LastBatchRows int NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_LastBatchRows DEFAULT 0,
    LastScan int NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_LastScan DEFAULT 0,
    LargeBatchGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_LargeBatchGeneration DEFAULT 0,
    CompletedLargeBatchGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_CompletedLargeBatchGeneration DEFAULT 0,
    UpkeepCompletedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_UpkeepCompletedGeneration DEFAULT 0,
    UpkeepDisposition varchar(12) NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_UpkeepDisposition DEFAULT 'not_run' CONSTRAINT CK_MaintenanceConfigurationWork_Disposition CHECK(UpkeepDisposition IN ('not_run','ineligible','complete')),
    FirstLogErrorNumber int NULL,
    CONSTRAINT CK_MaintenanceConfigurationWork_Rows CHECK
      (DueRows>=CompletedRows AND CompletedRows>=0 AND LastBatchRows>=0),
    CONSTRAINT CK_MaintenanceConfigurationWork_Generation CHECK
      (LargeBatchGeneration>=CompletedLargeBatchGeneration AND CompletedLargeBatchGeneration>=0
       AND UpkeepCompletedGeneration>=0)
);
INSERT dbo.MaintenanceConfigurationWork(ID) VALUES(1);
