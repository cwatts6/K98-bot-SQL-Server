/*
MigrationId: 20260607_001_preserve_stats_for_upload_last_refresh_time
Purpose: Preserve source scan time in STATS_FOR_UPLOAD.LAST_REFRESH
Author: cwatts
CreatedUtc: 2026-06-07
RequiresBackup: Yes
RiskLevel: Low
Rollback: Included
RollbackScript: migrations/rollback/20260607_001_preserve_stats_for_upload_last_refresh_time_rollback.sql
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT DATA_TYPE, DATETIME_PRECISION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'STATS_FOR_UPLOAD' AND COLUMN_NAME = 'LAST_REFRESH';
PostValidationQuery: SELECT DATA_TYPE, DATETIME_PRECISION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'STATS_FOR_UPLOAD' AND COLUMN_NAME = 'LAST_REFRESH';
RelatedBotPR:
RelatedSQLPR:
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
         AND system_type_id = TYPE_ID(N'date')
   )
BEGIN
    ALTER TABLE dbo.STATS_FOR_UPLOAD
    ALTER COLUMN LAST_REFRESH datetime2(0) NULL;
END
GO

IF OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P') IS NOT NULL
