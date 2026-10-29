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
