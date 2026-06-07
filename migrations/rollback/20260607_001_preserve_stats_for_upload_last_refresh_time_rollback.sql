/*
RollbackForMigrationId: 20260607_001_preserve_stats_for_upload_last_refresh_time
Purpose: Revert STATS_FOR_UPLOAD.LAST_REFRESH to date
Author: cwatts
CreatedUtc: 2026-06-07
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.STATS_FOR_UPLOAD', N'U') IS NOT NULL
   AND EXISTS (
       SELECT 1
       FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.STATS_FOR_UPLOAD', N'U')
         AND name = N'LAST_REFRESH'
         AND system_type_id = TYPE_ID(N'datetime2')
   )
BEGIN
    ALTER TABLE dbo.STATS_FOR_UPLOAD
    ALTER COLUMN LAST_REFRESH date NULL;
END
GO

IF OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P') IS NOT NULL
BEGIN
    EXEC sys.sp_refreshsqlmodule N'dbo.SP_Stats_for_Upload';
