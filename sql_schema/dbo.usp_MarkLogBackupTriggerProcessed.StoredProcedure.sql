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

