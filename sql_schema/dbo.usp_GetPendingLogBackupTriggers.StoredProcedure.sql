SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_GetPendingLogBackupTriggers]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_GetPendingLogBackupTriggers] AS' 
END
ALTER PROCEDURE [dbo].[usp_GetPendingLogBackupTriggers]
	@MaxAge [int] = 60
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ID,
        TriggerTime,
        ProcedureName,
        Reason,
        LogUsedPctBefore,
        DATEDIFF(SECOND, TriggerTime, SYSDATETIME()) AS AgeSeconds
    FROM dbo.LogBackupTriggerQueue
    WHERE Processed = 0
      AND TriggerTime >= DATEADD(MINUTE, -@MaxAge, SYSDATETIME())
    ORDER BY TriggerTime ASC;
END

