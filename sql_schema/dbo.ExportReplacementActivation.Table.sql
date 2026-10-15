SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Append-only effective-registration chain. A new binding never erases the old one.
CREATE TABLE dbo.ExportReplacementActivation
(
 ActivationID uniqueidentifier NOT NULL,
 ReplacementID uniqueidentifier NOT NULL,
 VerificationID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 BaseRegistrationHash binary(32) NOT NULL,
 RegistrationHash binary(32) NOT NULL,
 RegistrationJson nvarchar(max) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 OldPoolID uniqueidentifier NULL,
 NewPoolID uniqueidentifier NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportReplacementActivation PRIMARY KEY(ActivationID),
 CONSTRAINT UQ_ExportReplacementActivation_Plan UNIQUE(ReplacementID),
 CONSTRAINT UQ_ExportReplacementActivation_Read UNIQUE(VerificationID),
 CONSTRAINT UQ_ExportReplacementActivation_Base UNIQUE(AccountKey,BaseRegistrationHash),
 CONSTRAINT UQ_ExportReplacementActivation_Result UNIQUE(AccountKey,RegistrationHash),
 CONSTRAINT FK_ExportReplacementActivation_Plan FOREIGN KEY(ReplacementID) REFERENCES dbo.ExportReplacementPlan(ReplacementID),
 CONSTRAINT FK_ExportReplacementActivation_Read FOREIGN KEY(VerificationID) REFERENCES dbo.ExportReplacementVerification(VerificationID),
 CONSTRAINT CK_ExportReplacementActivation_Json CHECK(ISJSON(RegistrationJson)=1 AND DATALENGTH(RegistrationJson)<=65536),
 CONSTRAINT CK_ExportReplacementActivation_Hash CHECK(BaseRegistrationHash<>RegistrationHash),
 CONSTRAINT CK_ExportReplacementActivation_Pool CHECK((OldPoolID IS NULL AND NewPoolID IS NULL) OR (OldPoolID IS NOT NULL AND NewPoolID IS NOT NULL AND OldPoolID<>NewPoolID)),
 CONSTRAINT CK_ExportReplacementActivation_Text CHECK(LEN(Actor)>0 AND LEN(Reason)>0 AND LEN(AccountKey)>0)
);
CREATE UNIQUE INDEX UX_ExportReplacementActivation_OldPool ON dbo.ExportReplacementActivation(OldPoolID) WHERE OldPoolID IS NOT NULL;
CREATE UNIQUE INDEX UX_ExportReplacementActivation_NewPool ON dbo.ExportReplacementActivation(NewPoolID) WHERE NewPoolID IS NOT NULL;
