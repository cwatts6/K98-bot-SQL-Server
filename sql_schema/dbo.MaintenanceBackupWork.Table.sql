SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.MaintenanceBackupWork (
    ID tinyint NOT NULL CONSTRAINT PK_MaintenanceBackupWork PRIMARY KEY CONSTRAINT CK_MaintenanceBackupWork_ID CHECK (ID=1),
    DueGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceBackupWork_DueGeneration DEFAULT 0,
    RequestedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceBackupWork_RequestedGeneration DEFAULT 0,
    ClaimedGeneration bigint NULL,
    ClaimID uniqueidentifier NULL,
    State varchar(12) NOT NULL CONSTRAINT DF_MaintenanceBackupWork_State DEFAULT 'requested'
        CONSTRAINT CK_MaintenanceBackupWork_State CHECK (State IN ('pending','running','requested','failed','unknown')),
    DueUTC datetime2(3) NULL, StartedUTC datetime2(3) NULL, RequestedUTC datetime2(3) NULL,
    FirstFailure varchar(32) NULL, FirstFailureUTC datetime2(3) NULL, LastFailure varchar(32) NULL,
    CONSTRAINT CK_MaintenanceBackupWork_Generation CHECK (DueGeneration>=RequestedGeneration AND RequestedGeneration>=0
        AND (ClaimedGeneration IS NULL OR (ClaimedGeneration>0 AND ClaimedGeneration<=DueGeneration)))
);
INSERT dbo.MaintenanceBackupWork(ID) VALUES(1);
