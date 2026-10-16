SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.RecoveryAction
(
    ActionID uniqueidentifier NOT NULL CONSTRAINT PK_RecoveryAction PRIMARY KEY,
    IncidentID uniqueidentifier NOT NULL,
    IncidentRevision bigint NOT NULL,
    ActionKind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Actor nvarchar(128) NOT NULL,
    Reason nvarchar(512) NOT NULL,
    State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResultJson nvarchar(max) NULL,
    InputJson nvarchar(max) NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_RecoveryAction_Created DEFAULT SYSUTCDATETIME(),
    UpdatedUTC datetime2(3) NOT NULL CONSTRAINT DF_RecoveryAction_Updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_RecoveryAction_Incident FOREIGN KEY (IncidentID) REFERENCES dbo.RecoveryIncident(IncidentID),
    CONSTRAINT UQ_RecoveryAction_Revision UNIQUE (IncidentID,IncidentRevision),
    CONSTRAINT CK_RecoveryAction_State CHECK (State IN ('dispatched','unknown','verified','not_applied')),
    CONSTRAINT CK_RecoveryAction_Revision CHECK (IncidentRevision>0),
    CONSTRAINT CK_RecoveryAction_Input CHECK (InputJson IS NULL OR (ISJSON(InputJson)=1 AND DATALENGTH(InputJson)<=1048576)),
    CONSTRAINT CK_RecoveryAction_Result CHECK (ResultJson IS NULL OR (ISJSON(ResultJson)=1 AND DATALENGTH(ResultJson)<=32768))
);
CREATE INDEX IX_RecoveryAction_Pending ON dbo.RecoveryAction(IncidentID,State,CreatedUTC);
