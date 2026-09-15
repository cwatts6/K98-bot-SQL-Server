SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10A reference snapshot. Deploy the reviewed migration, not this file.
-- Static shape only: authorized later DAL owns CAS, transitions, immutable inputs,
-- fairness, resource acquisition/release and provider evidence validation.
-- For snapshot reconstruction create all six tables before adding the ownership FKs.
CREATE TABLE dbo.ExportAttemptPart
(
    AttemptID uniqueidentifier NOT NULL,
    PartNo int NOT NULL,
    PartCount int NOT NULL,
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    [Role] varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ManifestHash binary(32) NOT NULL,
    GridCount int NOT NULL,
    [RowCount] bigint NOT NULL,
    CellCount bigint NOT NULL,
    VerificationState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    VerifiedUTC datetime2(0) NULL,
    AclState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AclCheckedUTC datetime2(0) NULL,
    QuarantineState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    QuarantinedUTC datetime2(0) NULL,
    QuarantineReason nvarchar(1024) NULL,
    EvidenceJson nvarchar(max) NULL,
    Version bigint NOT NULL,
    CONSTRAINT PK_ExportAttemptPart PRIMARY KEY (AttemptID, PartNo),
    CONSTRAINT UQ_ExportAttemptPart_File UNIQUE (AttemptID, FileID),
    CONSTRAINT UQ_ExportAttemptPart_NumberFile UNIQUE (AttemptID, PartNo, FileID),
    CONSTRAINT CK_ExportAttemptPart_Number CHECK (PartCount BETWEEN 1 AND 1024 AND PartNo BETWEEN 1 AND PartCount),
    CONSTRAINT CK_ExportAttemptPart_File CHECK (LEN(FileID) > 0 AND DATALENGTH(FileID) = DATALENGTH(LTRIM(RTRIM(FileID)))),
    CONSTRAINT CK_ExportAttemptPart_Role CHECK (DATALENGTH([Role]) = LEN([Role]) AND [Role] IN ('index','generation','output')),
    CONSTRAINT CK_ExportAttemptPart_Counts CHECK (GridCount > 0 AND [RowCount] >= 0 AND CellCount > 0 AND CellCount >= [RowCount] AND Version > 0),
    CONSTRAINT CK_ExportAttemptPart_Verification CHECK (DATALENGTH(VerificationState) = LEN(VerificationState) AND VerificationState IN ('pending','verified','failed','uncertain') AND ((VerificationState = 'verified' AND VerifiedUTC IS NOT NULL) OR (VerificationState <> 'verified' AND VerifiedUTC IS NULL))),
    CONSTRAINT CK_ExportAttemptPart_Acl CHECK (DATALENGTH(AclState) = LEN(AclState) AND AclState IN ('pending','private','public_viewer','failed','uncertain') AND ((AclState = 'pending' AND AclCheckedUTC IS NULL) OR (AclState <> 'pending' AND AclCheckedUTC IS NOT NULL))),
    CONSTRAINT CK_ExportAttemptPart_Quarantine CHECK (DATALENGTH(QuarantineState) = LEN(QuarantineState) AND QuarantineState IN ('none','quarantined') AND ((QuarantineState = 'none' AND QuarantinedUTC IS NULL AND QuarantineReason IS NULL) OR (QuarantineState = 'quarantined' AND QuarantinedUTC IS NOT NULL AND QuarantineReason IS NOT NULL AND LEN(QuarantineReason) > 0))),
    CONSTRAINT CK_ExportAttemptPart_Evidence CHECK (EvidenceJson IS NULL OR (ISJSON(EvidenceJson) = 1 AND DATALENGTH(EvidenceJson) <= 65536))
);

ALTER TABLE dbo.ExportAttemptPart WITH CHECK ADD CONSTRAINT FK_ExportAttemptPart_Attempt FOREIGN KEY (AttemptID, PartCount) REFERENCES dbo.ExportAttempt (AttemptID, PartCount);
