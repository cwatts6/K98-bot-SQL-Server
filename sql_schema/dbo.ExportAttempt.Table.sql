SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10A reference snapshot. Deploy the reviewed migration, not this file.
-- Static shape only: authorized later DAL owns CAS, transitions, immutable inputs,
-- fairness, resource acquisition/release and provider evidence validation.
-- For snapshot reconstruction create all six tables before adding the ownership FKs.
CREATE TABLE dbo.ExportAttempt
(
    AttemptID uniqueidentifier NOT NULL,
    JobID uniqueidentifier NOT NULL,
    ConsumerKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AttemptNo bigint NOT NULL,
    OwnerID uniqueidentifier NOT NULL,
    Fence bigint NOT NULL,
    Epoch bigint NULL,
    Phase varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RemoteSequence bigint NOT NULL,
    Version bigint NOT NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    VerifiedUTC datetime2(0) NULL,
    PublishedUTC datetime2(0) NULL,
    ManifestHash binary(32) NOT NULL,
    ManifestJson nvarchar(max) NOT NULL,
    ReceiptJson nvarchar(max) NULL,
    PartCount int NOT NULL,
    LegacyPublicationID uniqueidentifier NULL,
    LegacySourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LegacyKVK_NO int NULL,
    LegacyPeriodID uniqueidentifier NULL,
    LegacyDestinationKind varchar(32) COLLATE Latin1_General_100_BIN2 NULL,
    LegacyDestinationID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    CONSTRAINT PK_ExportAttempt PRIMARY KEY (AttemptID),
    CONSTRAINT UQ_ExportAttempt_Sequence UNIQUE (JobID, AttemptNo),
    CONSTRAINT UQ_ExportAttempt_PartCount UNIQUE (AttemptID, PartCount),
    CONSTRAINT UQ_ExportAttempt_JobEpoch UNIQUE (AttemptID, JobID, Epoch),
    CONSTRAINT CK_ExportAttempt_Consumer CHECK (DATALENGTH(ConsumerKind) = LEN(ConsumerKind) AND ConsumerKind IN ('new_source','all_kvk','scan_data')),
    CONSTRAINT CK_ExportAttempt_Epoch CHECK ((ConsumerKind = 'new_source' AND Epoch IS NOT NULL AND Epoch > 0) OR (ConsumerKind IN ('all_kvk','scan_data') AND Epoch IS NULL)),
    CONSTRAINT CK_ExportAttempt_Phase CHECK (DATALENGTH(Phase) = LEN(Phase) AND Phase IN ('private_started','verified','publication_pending','published','failed','uncertain','retired')),
    CONSTRAINT CK_ExportAttempt_Counters CHECK (AttemptNo > 0 AND Fence > 0 AND RemoteSequence > 0 AND Version > 0 AND PartCount BETWEEN 1 AND 1024),
    CONSTRAINT CK_ExportAttempt_Manifest CHECK (ISJSON(ManifestJson) = 1 AND DATALENGTH(ManifestJson) <= 65536),
    CONSTRAINT CK_ExportAttempt_Receipt CHECK (ReceiptJson IS NULL OR (ISJSON(ReceiptJson) = 1 AND DATALENGTH(ReceiptJson) <= 65536)),
    CONSTRAINT CK_ExportAttempt_Time CHECK (UpdatedUTC >= CreatedUTC AND (VerifiedUTC IS NULL OR VerifiedUTC BETWEEN CreatedUTC AND UpdatedUTC) AND (PublishedUTC IS NULL OR (VerifiedUTC IS NOT NULL AND PublishedUTC BETWEEN VerifiedUTC AND UpdatedUTC))),
    CONSTRAINT CK_ExportAttempt_Evidence CHECK ((Phase NOT IN ('verified','publication_pending','published','retired') OR VerifiedUTC IS NOT NULL) AND (Phase NOT IN ('published','retired') OR (PublishedUTC IS NOT NULL AND ReceiptJson IS NOT NULL)) AND (Phase <> 'private_started' OR (VerifiedUTC IS NULL AND PublishedUTC IS NULL))),
    CONSTRAINT CK_ExportAttempt_Legacy CHECK ((LegacyPublicationID IS NULL AND LegacySourceKey IS NULL AND LegacyKVK_NO IS NULL AND LegacyPeriodID IS NULL AND LegacyDestinationKind IS NULL AND LegacyDestinationID IS NULL) OR (ConsumerKind = 'new_source' AND LegacyPublicationID IS NOT NULL AND LegacySourceKey IS NOT NULL AND LegacySourceKey = 'snapshot_report_v1' AND DATALENGTH(LegacySourceKey) = 18 AND LegacyKVK_NO IS NOT NULL AND LegacyKVK_NO > 0 AND LegacyPeriodID IS NOT NULL AND LegacyDestinationKind IS NOT NULL AND DATALENGTH(LegacyDestinationKind) = LEN(LegacyDestinationKind) AND LegacyDestinationKind IN ('discord','sheets','file') AND LegacyDestinationID IS NOT NULL AND LEN(LegacyDestinationID) > 0 AND DATALENGTH(LegacyDestinationID) = DATALENGTH(LTRIM(RTRIM(LegacyDestinationID)))))
);
CREATE INDEX IX_ExportAttempt_Phase ON dbo.ExportAttempt (Phase, UpdatedUTC, JobID);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_Job FOREIGN KEY (JobID, ConsumerKind) REFERENCES dbo.ExportJob (JobID, ConsumerKind);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_Epoch FOREIGN KEY (JobID, Epoch) REFERENCES dbo.ExportJob (JobID, PoolEpoch);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_LegacyDelivery FOREIGN KEY (LegacyPublicationID, LegacyDestinationKind, LegacyDestinationID) REFERENCES KVK.SourceDelivery (PublicationID, DestinationKind, DestinationID);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_LegacyPublication FOREIGN KEY (LegacySourceKey, LegacyKVK_NO, LegacyPeriodID, LegacyPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID);
ALTER TABLE dbo.ExportAttempt WITH CHECK ADD CONSTRAINT FK_ExportAttempt_LegacySeason FOREIGN KEY (JobID, LegacyKVK_NO) REFERENCES dbo.ExportJob (JobID, KVK_NO);
