SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF OBJECT_ID(N'dbo.MGE_BoardFinalisation', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MGE_BoardFinalisation (
        EventId bigint NOT NULL,
        BoardKind varchar(16) NOT NULL,
        FinalisationId uniqueidentifier NOT NULL,
        PublishVersion int NOT NULL,
        ChannelId bigint NOT NULL,
        MessageId bigint NOT NULL,
        DeliveryState varchar(16) NOT NULL,
        PayloadJson nvarchar(max) NULL,
        Reason varchar(64) NULL,
        RetiredByDiscordId bigint NULL,
        CreatedUtc datetime2(7) NOT NULL CONSTRAINT DF_MGE_BoardFinalisation_Created DEFAULT SYSUTCDATETIME(),
        UpdatedUtc datetime2(7) NOT NULL CONSTRAINT DF_MGE_BoardFinalisation_Updated DEFAULT SYSUTCDATETIME(),
        Revision rowversion NOT NULL,
        CONSTRAINT PK_MGE_BoardFinalisation PRIMARY KEY (EventId, BoardKind),
        CONSTRAINT FK_MGE_BoardFinalisation_Event FOREIGN KEY (EventId) REFERENCES dbo.MGE_Events(EventId),
        CONSTRAINT CK_MGE_BoardFinalisation_Kind CHECK (BoardKind IN ('signup', 'leadership', 'awards')),
        CONSTRAINT CK_MGE_BoardFinalisation_State CHECK (DeliveryState IN ('pending', 'confirmed', 'failed', 'unknown', 'held', 'retired')),
        CONSTRAINT CK_MGE_BoardFinalisation_Identity CHECK (ChannelId > 0 AND MessageId > 0 AND PublishVersion >= 0),
        CONSTRAINT CK_MGE_BoardFinalisation_Payload CHECK (PayloadJson IS NULL OR ISJSON(PayloadJson) = 1),
        CONSTRAINT CK_MGE_BoardFinalisation_Retirement CHECK (DeliveryState <> 'retired' OR RetiredByDiscordId IS NOT NULL)
    );
    CREATE INDEX IX_MGE_BoardFinalisation_Work ON dbo.MGE_BoardFinalisation(DeliveryState, EventId)
        INCLUDE (BoardKind, FinalisationId, ChannelId, MessageId, PublishVersion);
END;
