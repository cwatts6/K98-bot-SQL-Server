SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceDelivery
(
    PublicationID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    DestinationKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    DestinationID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    DeliveryState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AttemptCount int NOT NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    Receipt nvarchar(1024) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    UpdatedUTC datetime2(0) NOT NULL,
    ClaimedUTC datetime2(0) NULL,
    ConfirmedUTC datetime2(0) NULL,
    CONSTRAINT PK_SourceDelivery PRIMARY KEY (PublicationID, DestinationKind, DestinationID),
    CONSTRAINT FK_SourceDelivery_Publication FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PublicationID) REFERENCES KVK.SourcePublication (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT CK_SourceDelivery_Destination CHECK (DestinationKind IN ('discord','sheets','file') AND DATALENGTH(DestinationKind) = LEN(DestinationKind) AND LEN(DestinationID) > 0 AND DATALENGTH(DestinationID) = DATALENGTH(LTRIM(RTRIM(DestinationID)))),
    CONSTRAINT CK_SourceDelivery_State CHECK (DATALENGTH(DeliveryState) = LEN(DeliveryState) AND ((DeliveryState = 'pending' AND AttemptCount = 0 AND Fence = 0 AND OwnerID IS NULL AND ClaimedUTC IS NULL AND ConfirmedUTC IS NULL AND Receipt IS NULL) OR (DeliveryState IN ('claimed','failed','uncertain') AND AttemptCount > 0 AND Fence > 0 AND OwnerID IS NOT NULL AND ClaimedUTC IS NOT NULL AND ConfirmedUTC IS NULL) OR (DeliveryState = 'confirmed' AND AttemptCount > 0 AND Fence > 0 AND OwnerID IS NOT NULL AND ClaimedUTC IS NOT NULL AND ConfirmedUTC IS NOT NULL AND Receipt IS NOT NULL AND LEN(Receipt) > 0))),
    CONSTRAINT CK_SourceDelivery_Time CHECK (UpdatedUTC >= CreatedUTC AND (ClaimedUTC IS NULL OR (ClaimedUTC >= CreatedUTC AND ClaimedUTC <= UpdatedUTC)) AND (ConfirmedUTC IS NULL OR (ConfirmedUTC >= ClaimedUTC AND ConfirmedUTC <= UpdatedUTC))),
    CONSTRAINT CK_SourceDelivery_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
CREATE INDEX IX_SourceDelivery_State ON KVK.SourceDelivery (DeliveryState, UpdatedUTC);
