SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.ExportLegacyCloseout
(
 ActionID uniqueidentifier NOT NULL,
 JobID uniqueidentifier NOT NULL,
 ContainmentID uniqueidentifier NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 OwnerVersion bigint NOT NULL,
 SnapshotHash binary(32) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportLegacyCloseout PRIMARY KEY(ActionID),
 CONSTRAINT UQ_ExportLegacyCloseout_Job UNIQUE(JobID),
 CONSTRAINT FK_ExportLegacyCloseout_Job FOREIGN KEY(JobID) REFERENCES dbo.ExportJob(JobID),
 CONSTRAINT FK_ExportLegacyCloseout_Containment FOREIGN KEY(ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID),
 CONSTRAINT CK_ExportLegacyCloseout_Version CHECK(OwnerVersion>0),
 CONSTRAINT CK_ExportLegacyCloseout_Actor CHECK(Actor=N'recovery:'+LOWER(CONVERT(nvarchar(36),ActionID)) AND LEN(Reason)>0)
);
