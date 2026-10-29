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
