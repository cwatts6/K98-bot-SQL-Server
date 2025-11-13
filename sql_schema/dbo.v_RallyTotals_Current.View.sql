SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_RallyTotals_Current]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_RallyTotals_Current]  AS 
WITH MaxBase AS (
  SELECT CONVERT(date, MAX(SnapshotAt)) AS Baseline
  FROM dbo.cur_RallyTotals_Base
),
DailyAgg AS (
  SELECT d.GovernorID,
         MAX(d.GovernorName) AS GovernorName,
         SUM(d.TotalRallies)   AS TotalRallies,
         SUM(d.RalliesLaunched) AS RalliesLaunched,
         SUM(d.RalliesJoined)   AS RalliesJoined
  FROM dbo.cur_RallyDaily d
  CROSS JOIN MaxBase mb
  WHERE mb.Baseline IS NULL OR d.AsOfDate > mb.Baseline
  GROUP BY d.GovernorID
),
Base AS (
  SELECT GovernorID, GovernorName, TotalRallies, RalliesLaunched, RalliesJoined
  FROM dbo.cur_RallyTotals_Base
)
SELECT
  COALESCE(d.GovernorID, b.GovernorID)     AS GovernorID,
  COALESCE(d.GovernorName, b.GovernorName) AS GovernorName,
  COALESCE(b.TotalRallies, 0)     + COALESCE(d.TotalRallies, 0)     AS TotalRallies,
  COALESCE(b.RalliesLaunched, 0)  + COALESCE(d.RalliesLaunched, 0)  AS RalliesLaunched,
  COALESCE(b.RalliesJoined, 0)    + COALESCE(d.RalliesJoined, 0)    AS RalliesJoined
FROM DailyAgg d
FULL JOIN Base b ON b.GovernorID = d.GovernorID;


'
