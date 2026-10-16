SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Immutable proposal only. A plan does not admit provider work or activate files.
CREATE TABLE dbo.ExportReplacementPlan
(
 ReplacementID uniqueidentifier NOT NULL,
 ContainmentID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 BaseRegistrationHash binary(32) NOT NULL,
 ProjectedRegistrationHash binary(32) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 MappingJson nvarchar(max) NOT NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportReplacementPlan PRIMARY KEY (ReplacementID),
 CONSTRAINT FK_ExportReplacementPlan_Containment FOREIGN KEY (ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID),
 CONSTRAINT CK_ExportReplacementPlan_Account CHECK (DATALENGTH(AccountKey)=LEN(AccountKey) AND LEN(AccountKey)>0 AND AccountKey NOT LIKE '%[^-A-Za-z0-9_.@:]%' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportReplacementPlan_Hashes CHECK (BaseRegistrationHash<>ProjectedRegistrationHash),
 CONSTRAINT CK_ExportReplacementPlan_Mapping CHECK (ISJSON(MappingJson)=1 AND DATALENGTH(MappingJson)<=1048576),
 CONSTRAINT CK_ExportReplacementPlan_Text CHECK (LEN(Actor)>0 AND LEN(Reason)>0)
);
CREATE INDEX IX_ExportReplacementPlan_Containment ON dbo.ExportReplacementPlan(ContainmentID,CreatedUTC,ReplacementID);
