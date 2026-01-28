SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CleanupLogBackupTriggerQueue]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_CleanupLogBackupTriggerQueue] AS' 
END
ALTER PROCEDURE [dbo].[usp_CleanupLogBackupTriggerQueue]
	@RetentionDays [int] = 30
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, SYSDATETIME());
    DECLARE @RowsDeleted INT;
    
    DELETE FROM dbo.LogBackupTriggerQueue
    WHERE Processed = 1
      AND ProcessedTime < @CutoffDate;
    
    SET @RowsDeleted = @@ROWCOUNT;
    
    PRINT 'Deleted ' + CAST(@RowsDeleted AS VARCHAR(10)) + ' processed records older than ' + 
          CAST(@RetentionDays AS VARCHAR(10)) + ' days.';
    
    RETURN @RowsDeleted;
END

