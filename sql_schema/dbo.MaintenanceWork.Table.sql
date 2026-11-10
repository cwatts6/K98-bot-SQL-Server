SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.MaintenanceWork (
    Kind varchar(24) NOT NULL CONSTRAINT PK_MaintenanceWork PRIMARY KEY,
    DueGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_Due DEFAULT 0,
    CompletedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_Completed DEFAULT 0,
    ClaimedGeneration bigint NULL,
    ClaimID uniqueidentifier NULL,
    LastRequestID uniqueidentifier NULL,
    State varchar(12) NOT NULL CONSTRAINT DF_MaintenanceWork_State DEFAULT 'complete',
    DueUTC datetime2(3) NULL,
    StartedUTC datetime2(3) NULL,
    CompletedUTC datetime2(3) NULL,
    FirstErrorNumber int NULL,
    FirstErrorUTC datetime2(3) NULL,
    LastErrorNumber int NULL,
    CONSTRAINT CK_MaintenanceWork_Kind CHECK (Kind IN
        ('import','configuration','player_report','kvk_output','final_stats','post_import')),
    CONSTRAINT CK_MaintenanceWork_State CHECK (State IN
        ('pending','running','complete','failed','unknown')),
    CONSTRAINT CK_MaintenanceWork_Generation CHECK
        (DueGeneration>=CompletedGeneration AND CompletedGeneration>=0
         AND (ClaimedGeneration IS NULL OR
              (ClaimedGeneration>0 AND ClaimedGeneration<=DueGeneration)))
);
INSERT dbo.MaintenanceWork(Kind) VALUES ('import'),('configuration'),('player_report'),
    ('kvk_output'),('final_stats'),('post_import');
