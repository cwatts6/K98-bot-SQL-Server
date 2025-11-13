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
    -- Update only stats that need it (default behavior). Optionally use 'RESAMPLE'
    EXEC sp_updatestats;
END

