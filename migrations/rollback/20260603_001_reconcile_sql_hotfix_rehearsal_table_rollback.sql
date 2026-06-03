/*
RollbackForMigrationId: 20260603_001_reconcile_sql_hotfix_rehearsal_table
Purpose: Drop the controlled emergency hotfix rehearsal table
Author: cwatts
CreatedUtc: 2026-06-03
RiskLevel: Low
DataLossRisk: None
RollbackType: Full
RequiresBackup: Yes
PreRollbackValidation: SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;
PostRollbackValidation: SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;
RelatedSQLPR:
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.SqlHotfixRehearsal;
END
GO