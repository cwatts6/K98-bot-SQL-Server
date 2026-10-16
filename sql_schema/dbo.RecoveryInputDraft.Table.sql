SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.RecoveryInputDraft
(
 IncidentID uniqueidentifier NOT NULL,
 IncidentRevision bigint NOT NULL,
 ActionKind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
 EvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 InputJson nvarchar(max) NOT NULL,
 Actor nvarchar(128) NOT NULL,
 UpdatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_RecoveryInputDraft PRIMARY KEY(IncidentID,IncidentRevision,ActionKind),
 CONSTRAINT FK_RecoveryInputDraft_Incident FOREIGN KEY(IncidentID) REFERENCES dbo.RecoveryIncident(IncidentID),
 CONSTRAINT CK_RecoveryInputDraft_Json CHECK(ISJSON(InputJson)=1 AND DATALENGTH(InputJson)<=1048576),
 CONSTRAINT CK_RecoveryInputDraft_Version CHECK(Version>0 AND IncidentRevision>0 AND LEN(Actor)>0)
);
