SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
CREATE TABLE dbo.ExportManagedFileOrigin
(
 FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Stage varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ParentStage varchar(16) COLLATE Latin1_General_100_BIN2 NULL,
 PreparationID uniqueidentifier NOT NULL,
 Ordinal int NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 CreationStreamID uniqueidentifier NOT NULL,
 CreationRequestID uniqueidentifier NOT NULL,
 ResponseEventID uniqueidentifier NOT NULL,
 PlanHash binary(32) NOT NULL,
 ProfileHash binary(32) NOT NULL,
 ResponseHash binary(32) NOT NULL,
 CreationClosureHash binary(32) NOT NULL,
 OriginHash binary(32) NOT NULL,
 OriginReference uniqueidentifier NOT NULL,
 VerificationStreamID uniqueidentifier NULL,
 VerificationClosureHash binary(32) NULL,
 EligibilityHash binary(32) NULL,
 EligibilityReference uniqueidentifier NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportManagedFileOrigin PRIMARY KEY (FileID,Stage),
 CONSTRAINT UQ_ExportManagedFileOrigin_Ordinal UNIQUE (PreparationID,Ordinal,Stage),
 CONSTRAINT UQ_ExportManagedFileOrigin_Request UNIQUE (CreationRequestID,Stage),
 CONSTRAINT FK_ExportManagedFileOrigin_Parent FOREIGN KEY (FileID,ParentStage) REFERENCES dbo.ExportManagedFileOrigin(FileID,Stage),
 CONSTRAINT FK_ExportManagedFileOrigin_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportManagedFileOrigin_Creation FOREIGN KEY (CreationStreamID,SessionID) REFERENCES dbo.ExportExecutionStream(StreamID,SessionID),
 CONSTRAINT FK_ExportManagedFileOrigin_Request FOREIGN KEY (CreationRequestID) REFERENCES dbo.ExportProviderRequest(RequestID),
 CONSTRAINT FK_ExportManagedFileOrigin_Response FOREIGN KEY (ResponseEventID) REFERENCES dbo.ExportProviderRequestEvent(EventID),
 CONSTRAINT FK_ExportManagedFileOrigin_Verification FOREIGN KEY (VerificationStreamID,SessionID) REFERENCES dbo.ExportExecutionStream(StreamID,SessionID),
 CONSTRAINT CK_ExportManagedFileOrigin_Identity CHECK (DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16),
 CONSTRAINT CK_ExportManagedFileOrigin_Stage CHECK (DATALENGTH(Stage)=LEN(Stage) AND ((Stage='created' AND ParentStage IS NULL AND VerificationStreamID IS NULL AND VerificationClosureHash IS NULL AND EligibilityHash IS NULL AND EligibilityReference IS NULL) OR (Stage='eligible' AND ParentStage IS NOT NULL AND ParentStage='created' AND DATALENGTH(ParentStage)=7 AND VerificationStreamID IS NOT NULL AND VerificationClosureHash IS NOT NULL AND EligibilityHash IS NOT NULL AND EligibilityReference IS NOT NULL)))
);
CREATE INDEX IX_ExportManagedFileOrigin_Preparation ON dbo.ExportManagedFileOrigin(PreparationID,Stage,Ordinal);
