SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- File identity is global: changing account, job or registration cannot reuse it.
CREATE TABLE dbo.ExportContainedTarget
(
 FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ContainmentID uniqueidentifier NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportContainedTarget PRIMARY KEY (FileID),
 CONSTRAINT UQ_ExportContainedTarget_Decision UNIQUE (ContainmentID,FileID),
 CONSTRAINT CK_ExportContainedTarget_File CHECK (LEN(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT FK_ExportContainedTarget_Decision FOREIGN KEY (ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID)
);
