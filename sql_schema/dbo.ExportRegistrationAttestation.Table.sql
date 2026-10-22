SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Separate verified dependency witness; never replace the original activation.
CREATE TABLE dbo.ExportRegistrationAttestation
(
    ActionID uniqueidentifier NOT NULL,
    ActivationID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OriginalReference uniqueidentifier NOT NULL,
    OriginalHash binary(32) NOT NULL,
    ReviewHash binary(32) NOT NULL,
    ProjectionHash binary(32) NOT NULL,
    ReceiptReference uniqueidentifier NOT NULL,
    ReceiptHash binary(32) NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) NOT NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_RegistrationAttestation_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ExportRegistrationAttestation PRIMARY KEY(ActionID),
    CONSTRAINT FK_RegistrationAttestation_Activation FOREIGN KEY(ActivationID) REFERENCES dbo.ExportReplacementActivation(ActivationID),
    CONSTRAINT CK_RegistrationAttestation_Text CHECK(LEN(AccountKey)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    CONSTRAINT UQ_RegistrationAttestation_Receipt UNIQUE(ReceiptReference)
);
CREATE INDEX IX_RegistrationAttestation_Source ON dbo.ExportRegistrationAttestation(AccountKey,ActivationID,CreatedUTC,ActionID);
