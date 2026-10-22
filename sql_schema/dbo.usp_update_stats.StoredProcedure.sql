SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_update_stats]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_update_stats] AS' 
END
ALTER PROCEDURE [dbo].[usp_update_stats]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Exclusion lives on the actual SQL worker session. A Python deadline or
    -- lost journal connection cannot permit a concurrent maintenance replay.
    DECLARE @LockResult int;
    EXEC @LockResult=sys.sp_getapplock @Resource=N'K98:post-import-stats:v1',
        @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
    IF @LockResult<0 THROW 51961, 'Post-import maintenance is still active.', 1;
    BEGIN TRY
        EXEC sp_updatestats;
        EXEC sys.sp_releaseapplock @Resource=N'K98:post-import-stats:v1',@LockOwner='Session';
    END TRY
    BEGIN CATCH
        EXEC sys.sp_releaseapplock @Resource=N'K98:post-import-stats:v1',@LockOwner='Session';
        THROW;
    END CATCH;
END

