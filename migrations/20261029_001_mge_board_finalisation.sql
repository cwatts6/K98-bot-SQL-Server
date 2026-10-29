/*
MigrationId: 20261029_001_mge_board_finalisation
Purpose: Durable final board targets and guards for completed MGE history
Author: cwatts
CreatedUtc: 2026-10-29
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Approved drained combined release; exact parents and absent new objects
PostValidationQuery: Exact table, index and three trigger postimages; unchanged historical rows
*/
-- Coordinated drained rollout only. See docs/mge-board-finalisation.md.
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

GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.tr_MGE_Events_Frozen ON dbo.MGE_Events
AFTER UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    -- Completion is a terminal domain transition. Final delivery writes its own
    -- table, so neither an identity clear nor an old Reopen action can thaw it.
    IF EXISTS (SELECT 1 FROM deleted WHERE Status = 'completed')
        THROW 51830, 'Completed MGE events are immutable.', 1;
END;
GO

GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.tr_MGE_Awards_Frozen ON dbo.MGE_Awards
AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    -- Event locking serializes the freeze with every writer, including stale UI,
    -- placement and legacy DAL paths. Deadlock victims roll back; never retry an
    -- unknown business outcome. Final results and audit tables remain separate.
    IF EXISTS (
        SELECT 1 FROM dbo.MGE_Events E WITH (UPDLOCK, HOLDLOCK)
        JOIN (SELECT EventId FROM inserted UNION SELECT EventId FROM deleted) A ON A.EventId = E.EventId
        WHERE E.Status = 'completed'
    ) THROW 51830, 'Completed MGE awards are immutable.', 1;
END;
GO

GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.tr_MGE_Signups_Frozen ON dbo.MGE_Signups
AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM dbo.MGE_Events E WITH (UPDLOCK, HOLDLOCK)
        JOIN (SELECT EventId FROM inserted UNION SELECT EventId FROM deleted) S ON S.EventId = E.EventId
        WHERE E.Status = 'completed'
    ) THROW 51830, 'Completed MGE signups are immutable.', 1;
END;
GO
