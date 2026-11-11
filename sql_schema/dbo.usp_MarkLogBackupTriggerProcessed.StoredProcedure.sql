SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_MarkLogBackupTriggerProcessed]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_MarkLogBackupTriggerProcessed] AS' 
END
ALTER PROCEDURE [dbo].[usp_MarkLogBackupTriggerProcessed]
	@TriggerID [int],
	@ProcessedBy [nvarchar](128),
	@LogUsedPctAfter [decimal](5, 2) = NULL,
	@BackupResult [nvarchar](max) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    -- A drained, coordinated D4 transition preserves the historical queue.
    -- Observe only this fixed identity under dbo; caller metadata DENYs cannot
    -- disguise the new deployment. The queue operation retains caller context.
    DECLARE @P02LedgerPresent bit;
    EXEC dbo.usp_P02LegacyQueueState @LedgerPresent=@P02LedgerPresent OUTPUT;
    IF @P02LedgerPresent IS NULL
        THROW 52942, 'Legacy backup queue deployment state is unavailable; no queue work was performed.', 1;
    IF @P02LedgerPresent = 1
        THROW 52941, 'Legacy backup queue is held by P02 maintenance; historical rows must be preserved.', 1;

    
    UPDATE dbo.LogBackupTriggerQueue
    SET 
        Processed = 1,
        ProcessedTime = SYSDATETIME(),
        ProcessedBy = @ProcessedBy,
        LogUsedPctAfter = @LogUsedPctAfter,
        BackupResult = @BackupResult
    WHERE ID = @TriggerID
      AND Processed = 0;
    
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('Trigger ID %d not found or already processed.', 16, 1, @TriggerID);
        RETURN -1;
    END
    
    RETURN 0;
END

