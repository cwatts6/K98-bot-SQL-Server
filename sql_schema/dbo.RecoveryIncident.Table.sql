SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.RecoveryIncident
(
    IncidentID uniqueidentifier NOT NULL CONSTRAINT PK_RecoveryIncident PRIMARY KEY,
    ScopeKey char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceJson nvarchar(max) NOT NULL,
    Revision bigint NOT NULL CONSTRAINT DF_RecoveryIncident_Revision DEFAULT 1,
    FirstSeenUTC datetime2(3) NOT NULL CONSTRAINT DF_RecoveryIncident_First DEFAULT SYSUTCDATETIME(),
    LastSeenUTC datetime2(3) NOT NULL CONSTRAINT DF_RecoveryIncident_Last DEFAULT SYSUTCDATETIME(),
    AlertMessageID bigint NULL,
    AlertChannelID bigint NULL,
    AlertedRevision bigint NOT NULL CONSTRAINT DF_RecoveryIncident_AlertRevision DEFAULT 0,
    AlertCheckedUTC datetime2(3) NULL,
    AlertAttemptUTC datetime2(3) NULL,
    CONSTRAINT UQ_RecoveryIncident_Source UNIQUE (ScopeKey,SourceKind,SourceID),
    CONSTRAINT CK_RecoveryIncident_State CHECK (State IN ('open','resolved')),
    CONSTRAINT CK_RecoveryIncident_Evidence CHECK (ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=32768),
    CONSTRAINT CK_RecoveryIncident_Revision CHECK (Revision>0 AND AlertedRevision>=0 AND AlertedRevision<=Revision),
    CONSTRAINT CK_RecoveryIncident_Alert CHECK ((AlertMessageID IS NULL AND AlertChannelID IS NULL) OR (AlertMessageID IS NOT NULL AND AlertChannelID IS NOT NULL AND AlertMessageID>0 AND AlertChannelID>0))
);
CREATE INDEX IX_RecoveryIncident_Pending ON dbo.RecoveryIncident(ScopeKey,State,LastSeenUTC,IncidentID);
