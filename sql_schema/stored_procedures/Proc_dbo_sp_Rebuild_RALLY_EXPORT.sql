SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Rebuild_RALLY_EXPORT]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Rebuild_RALLY_EXPORT] AS' 
END
ALTER PROCEDURE [dbo].[sp_Rebuild_RALLY_EXPORT]
WITH EXECUTE AS CALLER
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;

  DECLARE @Baseline date =
  ( SELECT CAST(MAX(SnapshotAt) AS date) FROM dbo.cur_RallyTotals_Base );

  BEGIN TRAN;

  DELETE FROM dbo.RALLY_EXPORT;

  ;WITH DailyAgg AS
  (
    SELECT GovernorID,
           MAX(GovernorName) AS GovernorName,
           SUM(TotalRallies) AS TotalRallies,
           SUM(RalliesLaunched) AS RalliesLaunched,
           SUM(RalliesJoined) AS RalliesJoined
    FROM dbo.cur_RallyDaily
    WHERE (@Baseline IS NULL OR AsOfDate > @Baseline)
    GROUP BY GovernorID
  ),
  Base AS
  (
    SELECT GovernorID, GovernorName, TotalRallies, RalliesLaunched, RalliesJoined
    FROM dbo.cur_RallyTotals_Base
  ),
  Final AS
  (
    SELECT
      COALESCE(d.GovernorID, b.GovernorID) AS GovernorID,
      COALESCE(d.GovernorName, b.GovernorName) AS GovernorName,
      COALESCE(b.TotalRallies, 0)    + COALESCE(d.TotalRallies, 0)    AS TotalRallies,
      COALESCE(b.RalliesLaunched, 0) + COALESCE(d.RalliesLaunched, 0) AS RalliesLaunched,
      COALESCE(b.RalliesJoined, 0)   + COALESCE(d.RalliesJoined, 0)   AS RalliesJoined
    FROM DailyAgg d
    FULL OUTER JOIN Base b ON b.GovernorID = d.GovernorID
  )
  INSERT dbo.RALLY_EXPORT (GOVENOR, RALLY_LAUNCHED, RALLY_JOINED, TOTAL_RALLIES_COMPLETED)
  SELECT
    CONCAT(RTRIM(f.GovernorName), ' (', CONVERT(varchar(20), f.GovernorID), ')') AS GOVENOR,
    f.RalliesLaunched,
    f.RalliesJoined,
    f.TotalRallies
  FROM Final f
  WHERE f.GovernorID <> 0;

  COMMIT;
END;

