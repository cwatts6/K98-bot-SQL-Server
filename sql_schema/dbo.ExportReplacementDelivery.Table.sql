CREATE TABLE dbo.ExportReplacementDelivery (
 ActionID uniqueidentifier NOT NULL CONSTRAINT PK_ExportReplacementDelivery PRIMARY KEY,
 OriginalJobID uniqueidentifier NOT NULL,
 ActivationID uniqueidentifier NOT NULL,
 ReplacementJobID uniqueidentifier NOT NULL,
 AccountKey varchar(128) NOT NULL,
 OriginalInputHash binary(32) NOT NULL,
 ReplacementInputHash binary(32) NOT NULL,
 Actor nvarchar(128) NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT UQ_ExportReplacementDelivery_Original UNIQUE(OriginalJobID,ActivationID),
 CONSTRAINT UQ_ExportReplacementDelivery_Job UNIQUE(ReplacementJobID),
 CONSTRAINT CK_ExportReplacementDelivery_Distinct CHECK(OriginalJobID<>ReplacementJobID),
 CONSTRAINT FK_ExportReplacementDelivery_Original FOREIGN KEY(OriginalJobID) REFERENCES dbo.ExportJob(JobID),
 CONSTRAINT FK_ExportReplacementDelivery_Activation FOREIGN KEY(ActivationID) REFERENCES dbo.ExportReplacementActivation(ActivationID),
 CONSTRAINT FK_ExportReplacementDelivery_Replacement FOREIGN KEY(ReplacementJobID) REFERENCES dbo.ExportJob(JobID)
);
