/*
RollbackForMigrationId: 20260717_001_add_personal_stats_daily_contract
Purpose: Remove the additive private personal-stats daily read procedure
Author: cwatts
CreatedUtc: 2026-07-17
RiskLevel: Low
DataLossRisk: None
RollbackType: Full
RequiresBackup: Yes
PreRollbackValidation: Confirm the deployed bot no longer calls dbo.usp_GetPersonalStatsDaily.
PostRollbackValidation: SELECT OBJECT_ID(N'dbo.usp_GetPersonalStatsDaily', N'P') AS PersonalStatsProcedure;
RelatedSQLPR:
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.usp_GetPersonalStatsDaily', N'P') IS NOT NULL
        DROP PROCEDURE dbo.usp_GetPersonalStatsDaily;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
