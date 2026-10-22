SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- New present-state attestations. Never overwrite a lost historical receipt.
CREATE TABLE dbo.ExportContainmentAttestation
(
    ActionID uniqueidentifier NOT NULL,
    ContainmentID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OriginalReference uniqueidentifier NOT NULL,
    OriginalHash binary(32) NOT NULL,
    ReviewHash binary(32) NOT NULL,
    ProjectionHash binary(32) NOT NULL,
    ReceiptReference uniqueidentifier NOT NULL,
    ReceiptHash binary(32) NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) NOT NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_ContainmentAttestation_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ExportContainmentAttestation PRIMARY KEY(ActionID),
    CONSTRAINT FK_ContainmentAttestation_Containment FOREIGN KEY(ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID),
    CONSTRAINT CK_ContainmentAttestation_Text CHECK(LEN(AccountKey)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    CONSTRAINT UQ_ContainmentAttestation_Receipt UNIQUE(ReceiptReference)
);
CREATE INDEX IX_ContainmentAttestation_Source ON dbo.ExportContainmentAttestation(AccountKey,ContainmentID,CreatedUTC,ActionID);
