SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.MaintenanceKvkWork (
    KVKNo int NOT NULL PRIMARY KEY,
    DueGeneration bigint NOT NULL,
    CompletedGeneration bigint NOT NULL DEFAULT(0),
    DueObjectID int NOT NULL,
    DueObjectCreateDate datetime NOT NULL,
    DueHeaderRevision int NOT NULL,
    State varchar(12) NOT NULL DEFAULT('pending'),
    ClaimID uniqueidentifier NULL,
    ClaimedGeneration bigint NULL,
    ClaimedObjectID int NULL,
    ClaimedObjectCreateDate datetime NULL,
    ClaimedHeaderRevision int NULL,
    FirstErrorNumber int NULL,
    FirstErrorUTC datetime2(3) NULL,
    LastErrorNumber int NULL,
    CompletedUTC datetime2(3) NULL,
    CONSTRAINT CK_MaintenanceKvkWork_Generation CHECK
        (KVKNo>0 AND DueGeneration>0 AND CompletedGeneration>=0
         AND CompletedGeneration<=DueGeneration AND DueHeaderRevision>0),
    CONSTRAINT CK_MaintenanceKvkWork_State CHECK
        (State IN ('pending','running','complete','failed','unknown'))
);
GO
