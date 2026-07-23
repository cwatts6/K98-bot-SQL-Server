/*
RollbackForMigrationId: 20260723_002_add_leadership_governor_exists
Purpose: Remove the leadership exact-ID existence procedure
Author: cwatts
CreatedUtc: 2026-07-23
DataChange: No
*/
DROP PROCEDURE IF EXISTS dbo.usp_LeadershipPlayerGovernorExists;
GO
