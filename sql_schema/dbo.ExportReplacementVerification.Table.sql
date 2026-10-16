SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Each explicit verification is a new read-only attempt. Old attempts remain auditable.
CREATE TABLE dbo.ExportReplacementVerification
(
 VerificationID uniqueidentifier NOT NULL,
 ReplacementID uniqueidentifier NOT NULL,
 PreparationID uniqueidentifier NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 PlanHash binary(32) NOT NULL,
 State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 ReceiptHash binary(32) NULL,
 ReceiptReference uniqueidentifier NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 UpdatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportReplacementVerification PRIMARY KEY(VerificationID),
 CONSTRAINT UQ_ExportReplacementVerification_Preparation UNIQUE(PreparationID),
 CONSTRAINT FK_ExportReplacementVerification_Plan FOREIGN KEY(ReplacementID) REFERENCES dbo.ExportReplacementPlan(ReplacementID),
 CONSTRAINT FK_ExportReplacementVerification_Preparation FOREIGN KEY(PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportReplacementVerification_Session FOREIGN KEY(SessionID) REFERENCES dbo.ExportExecutionSession(SessionID),
 CONSTRAINT CK_ExportReplacementVerification_State CHECK(DATALENGTH(State)=LEN(State) AND
  ((State='checking' AND Version=1 AND ReceiptHash IS NULL AND ReceiptReference IS NULL)
   OR (State IN ('verified','discarded') AND Version=2 AND ReceiptHash IS NOT NULL AND ReceiptReference IS NOT NULL))),
 CONSTRAINT CK_ExportReplacementVerification_Text CHECK(LEN(Actor)>0 AND LEN(Reason)>0 AND UpdatedUTC>=CreatedUTC)
);
CREATE UNIQUE INDEX UX_ExportReplacementVerification_Checking ON dbo.ExportReplacementVerification(ReplacementID) WHERE State='checking';
CREATE INDEX IX_ExportReplacementVerification_Plan ON dbo.ExportReplacementVerification(ReplacementID,CreatedUTC,VerificationID);
