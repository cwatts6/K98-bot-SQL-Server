SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_P02LegacyQueueState @LedgerPresent bit OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Only this fixed metadata observation crosses execution context. Queue DML
    -- remains in the caller-context APIs. A changed owner fails closed.
    IF USER_ID() <> 1
        THROW 52942, 'Legacy backup queue deployment state is unavailable; no queue work was performed.', 1;
    SET @LedgerPresent = CASE WHEN OBJECT_ID(N'dbo.MaintenanceBackupWork') IS NULL THEN 0 ELSE 1 END;
END;
