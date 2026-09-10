SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceConfigRequest
(
    RequestID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BaseConfigVersionID uniqueidentifier NOT NULL,
    DesiredConfigVersionID uniqueidentifier NOT NULL,
    ConfigContentHash binary(32) NOT NULL,
    OldStartScanID int NULL,
    OldEndScanID int NULL,
    NewStartScanID int NULL,
    NewEndScanID int NULL,
    Origin varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RequestedUTC datetime2(0) NOT NULL,
    RequestState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AppliedPublicationID uniqueidentifier NULL,
    CompletedUTC datetime2(0) NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    CONSTRAINT PK_SourceConfigRequest PRIMARY KEY (RequestID),
    CONSTRAINT UQ_SourceConfigRequest_Replay UNIQUE (SourceKey, KVK_NO, PeriodID, ConfigContentHash, BaseConfigVersionID),
    CONSTRAINT UQ_SourceConfigRequest_Scope UNIQUE (SourceKey, KVK_NO, PeriodID, RequestID),
    CONSTRAINT FK_SourceConfigRequest_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PeriodKey) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodID, PeriodKey),
    CONSTRAINT FK_SourceConfigRequest_Base FOREIGN KEY (SourceKey, KVK_NO, BaseConfigVersionID, PeriodKey) REFERENCES KVK.SourceWindowConfig (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT FK_SourceConfigRequest_Desired FOREIGN KEY (SourceKey, KVK_NO, DesiredConfigVersionID, PeriodKey) REFERENCES KVK.SourceWindowConfig (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT CK_SourceConfigRequest_Versions CHECK (BaseConfigVersionID <> DesiredConfigVersionID),
    CONSTRAINT CK_SourceConfigRequest_Endpoints CHECK ((OldStartScanID IS NULL OR OldStartScanID > 0) AND (OldEndScanID IS NULL OR OldEndScanID > 0) AND (NewStartScanID IS NULL OR NewStartScanID > 0) AND (NewEndScanID IS NULL OR NewEndScanID > 0) AND (OldEndScanID IS NULL OR OldStartScanID IS NULL OR OldEndScanID >= OldStartScanID) AND (NewEndScanID IS NULL OR NewStartScanID IS NULL OR NewEndScanID >= NewStartScanID)),
    CONSTRAINT CK_SourceConfigRequest_State CHECK (DATALENGTH(RequestState) = LEN(RequestState) AND ((RequestState IN ('requested','pending') AND AppliedPublicationID IS NULL AND CompletedUTC IS NULL) OR (RequestState = 'applied' AND AppliedPublicationID IS NOT NULL AND CompletedUTC IS NOT NULL) OR (RequestState = 'rejected' AND AppliedPublicationID IS NULL AND CompletedUTC IS NOT NULL)) AND (CompletedUTC IS NULL OR CompletedUTC >= RequestedUTC)),
    CONSTRAINT CK_SourceConfigRequest_Provenance CHECK (Origin IN ('authorized_import','admin','system') AND DATALENGTH(Origin) = LEN(Origin) AND LEN(Actor) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536),
    CONSTRAINT CK_SourceConfigRequest_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
CREATE INDEX IX_SourceConfigRequest_State ON KVK.SourceConfigRequest (RequestState, RequestedUTC);
ALTER TABLE KVK.SourceConfigRequest WITH CHECK ADD CONSTRAINT FK_SourceConfigRequest_Applied FOREIGN KEY (SourceKey, KVK_NO, PeriodID, DesiredConfigVersionID, AppliedPublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID);
