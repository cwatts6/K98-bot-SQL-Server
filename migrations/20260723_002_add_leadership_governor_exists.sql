/*
MigrationId: 20260723_002_add_leadership_governor_exists
Purpose: Add a bounded exact-ID existence check before leadership player-review payload loading
Author: cwatts
CreatedUtc: 2026-07-23
RequiresBackup: No
RiskLevel: Low
Rollback: Included
RollbackScript: migrations/rollback/20260723_002_add_leadership_governor_exists_rollback.sql
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.usp_LeadershipPlayerGovernorExists', N'P') AS ExistingProcedure;
PostValidationQuery: EXEC dbo.usp_LeadershipPlayerGovernorExists @GovernorID = 2441482;
RelatedBotPR: 538
RelatedSQLPR: 58
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_LeadershipPlayerGovernorExists
    @GovernorID bigint
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @GovernorID IS NULL OR @GovernorID <= 0
        THROW 51561, 'Leadership Governor existence requires a positive Governor ID.', 1;

    SELECT
        @GovernorID AS GovernorID,
        CONVERT(bit, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.KingdomScanData4 AS source
            WHERE source.GovernorID = CONVERT(float, @GovernorID)
              AND TRY_CONVERT(bigint, source.GovernorID) = @GovernorID
        )
        THEN 1 ELSE 0 END) AS ExistsInDatabase;
END
GO
