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
