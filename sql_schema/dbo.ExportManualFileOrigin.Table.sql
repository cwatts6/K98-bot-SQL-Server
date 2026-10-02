CREATE TABLE dbo.ExportManualFileOrigin
(
 FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Stage varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ParentStage varchar(16) COLLATE Latin1_General_100_BIN2 NULL,
 PreparationID uniqueidentifier NOT NULL,
 Ordinal int NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 PlanHash binary(32) NOT NULL,
 ProfileHash binary(32) NOT NULL,
 VerificationStreamID uniqueidentifier NULL,
 VerificationClosureHash binary(32) NULL,
 EligibilityHash binary(32) NULL,
 EligibilityReference uniqueidentifier NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportManualFileOrigin PRIMARY KEY(FileID,Stage),
 CONSTRAINT UQ_ExportManualFileOrigin_Ordinal UNIQUE(PreparationID,Ordinal,Stage),
 CONSTRAINT FK_ExportManualFileOrigin_Parent FOREIGN KEY(FileID,ParentStage) REFERENCES dbo.ExportManualFileOrigin(FileID,Stage),
 CONSTRAINT FK_ExportManualFileOrigin_Preparation FOREIGN KEY(PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportManualFileOrigin_Session FOREIGN KEY(SessionID) REFERENCES dbo.ExportExecutionSession(SessionID),
 CONSTRAINT FK_ExportManualFileOrigin_Verification FOREIGN KEY(VerificationStreamID,SessionID) REFERENCES dbo.ExportExecutionStream(StreamID,SessionID),
 CONSTRAINT CK_ExportManualFileOrigin_Identity CHECK(DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16),
 CONSTRAINT CK_ExportManualFileOrigin_Stage CHECK(DATALENGTH(Stage)=LEN(Stage) AND
  ((Stage='registered' AND ParentStage IS NULL AND VerificationStreamID IS NULL AND VerificationClosureHash IS NULL AND EligibilityHash IS NULL AND EligibilityReference IS NULL)
   OR (Stage='eligible' AND ParentStage IS NOT NULL AND ParentStage='registered' AND DATALENGTH(ParentStage)=10 AND VerificationStreamID IS NOT NULL AND VerificationClosureHash IS NOT NULL AND EligibilityHash IS NOT NULL AND EligibilityReference IS NOT NULL)))
);
CREATE INDEX IX_ExportManualFileOrigin_Preparation ON dbo.ExportManualFileOrigin(PreparationID,Stage,Ordinal);
