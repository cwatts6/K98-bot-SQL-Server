SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Permanent isolation decisions. No expiry, undo or target-reuse transition exists.
CREATE TABLE dbo.ExportTargetContainment
(
 ContainmentID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 JobID uniqueidentifier NULL,
 OutputOperationID uniqueidentifier NULL,
 PreparationID uniqueidentifier NULL,
 OwnerVersion bigint NOT NULL,
 OwnerID uniqueidentifier NOT NULL,
 Fence bigint NOT NULL,
 SnapshotHash binary(32) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportTargetContainment PRIMARY KEY (ContainmentID),
 CONSTRAINT CK_ExportTargetContainment_Owner CHECK ((CASE WHEN JobID IS NULL THEN 0 ELSE 1 END + CASE WHEN OutputOperationID IS NULL THEN 0 ELSE 1 END + CASE WHEN PreparationID IS NULL THEN 0 ELSE 1 END)=1),
 CONSTRAINT CK_ExportTargetContainment_Counters CHECK (OwnerVersion>0 AND Fence>0),
 CONSTRAINT CK_ExportTargetContainment_Text CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=LEN(AccountKey) AND AccountKey NOT LIKE '%[^A-Za-z0-9_.@:-]%' COLLATE Latin1_General_100_BIN2 AND LEN(Actor)>0 AND LEN(Reason)>0),
 CONSTRAINT FK_ExportTargetContainment_Job FOREIGN KEY (JobID) REFERENCES dbo.ExportJob(JobID),
 CONSTRAINT FK_ExportTargetContainment_Operation FOREIGN KEY (OutputOperationID) REFERENCES KVK.SourceOutputOperation(OperationID),
 CONSTRAINT FK_ExportTargetContainment_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID)
);
CREATE INDEX IX_ExportTargetContainment_Account ON dbo.ExportTargetContainment(AccountKey,CreatedUTC,ContainmentID);
CREATE UNIQUE INDEX UX_ExportTargetContainment_Job ON dbo.ExportTargetContainment(JobID) WHERE JobID IS NOT NULL;
CREATE UNIQUE INDEX UX_ExportTargetContainment_Operation ON dbo.ExportTargetContainment(OutputOperationID) WHERE OutputOperationID IS NOT NULL;
CREATE UNIQUE INDEX UX_ExportTargetContainment_Preparation ON dbo.ExportTargetContainment(PreparationID) WHERE PreparationID IS NOT NULL;
