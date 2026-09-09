SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceObservation
(
    ObservationID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    ScanStartUTC datetime2(0) NOT NULL,
    TimePrecision varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EventDiscriminator nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SelectedRevisionID uniqueidentifier NULL,
    SelectionVersion bigint NOT NULL,
    SupersedesObservationID uniqueidentifier NULL,
    CONSTRAINT PK_SourceObservation PRIMARY KEY (ObservationID),
    CONSTRAINT UQ_SourceObservation_Scope UNIQUE (SourceKey, KVK_NO, ObservationID),
    CONSTRAINT UQ_SourceObservation_Event UNIQUE (SourceKey, KVK_NO, ScanStartUTC, TimePrecision, EventDiscriminator),
    CONSTRAINT CK_SourceObservation_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceObservation_Time CHECK (TimePrecision IN ('minute','second') AND (TimePrecision <> 'minute' OR DATEPART(SECOND, ScanStartUTC) = 0)),
    CONSTRAINT CK_SourceObservation_Selection CHECK (SelectionVersion > 0),
    CONSTRAINT CK_SourceObservation_Event CHECK (LEN(EventDiscriminator) > 0),
    CONSTRAINT CK_SourceObservation_Supersedes CHECK (SupersedesObservationID IS NULL OR SupersedesObservationID <> ObservationID),
    CONSTRAINT FK_SourceObservation_Supersedes FOREIGN KEY (SourceKey, KVK_NO, SupersedesObservationID) REFERENCES KVK.SourceObservation (SourceKey, KVK_NO, ObservationID)
);

-- Added after all twelve tables exist. NULL is creation-only; S3B must fill it before commit.
ALTER TABLE KVK.SourceObservation WITH CHECK ADD CONSTRAINT FK_SourceObservation_SelectedRevision FOREIGN KEY (SourceKey, KVK_NO, ObservationID, SelectedRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, ObservationID, RevisionID);
