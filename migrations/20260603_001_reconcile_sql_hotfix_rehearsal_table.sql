/*
MigrationId: 20260603_001_reconcile_sql_hotfix_rehearsal_table
Purpose: Reconcile controlled emergency hotfix rehearsal table
Author: cwatts
CreatedUtc: 2026-06-03
RequiresBackup: Yes
RiskLevel: Low
Rollback: Included
RollbackScript: migrations/rollback/20260603_001_reconcile_sql_hotfix_rehearsal_table_rollback.sql
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SqlHotfixRehearsal
    (
        RehearsalId INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SqlHotfixRehearsal PRIMARY KEY,
        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_SqlHotfixRehearsal_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        Notes NVARCHAR(4000) NULL
    );
END
GO