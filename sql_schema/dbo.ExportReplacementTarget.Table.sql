SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Preserve every proposal, including rejected files; this is not activation.
CREATE TABLE dbo.ExportReplacementTarget
(
 ReplacementID uniqueidentifier NOT NULL,
 OldFileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 NewFileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT PK_ExportReplacementTarget PRIMARY KEY (ReplacementID,OldFileID),
 CONSTRAINT UQ_ExportReplacementTarget_New UNIQUE (ReplacementID,NewFileID),
 CONSTRAINT FK_ExportReplacementTarget_Plan FOREIGN KEY (ReplacementID) REFERENCES dbo.ExportReplacementPlan(ReplacementID),
 CONSTRAINT FK_ExportReplacementTarget_Contained FOREIGN KEY (OldFileID) REFERENCES dbo.ExportContainedTarget(FileID),
 CONSTRAINT CK_ExportReplacementTarget_Identity CHECK (OldFileID<>NewFileID AND DATALENGTH(OldFileID)=LEN(OldFileID) AND DATALENGTH(NewFileID)=LEN(NewFileID) AND LEN(OldFileID) BETWEEN 6 AND 128 AND LEN(NewFileID) BETWEEN 6 AND 128 AND OldFileID NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2 AND NewFileID NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2)
);
