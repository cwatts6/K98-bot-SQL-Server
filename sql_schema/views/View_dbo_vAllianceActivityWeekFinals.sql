SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vAllianceActivityWeekFinals]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vAllianceActivityWeekFinals]  AS 
WITH Ranked AS (
  SELECT
      s.GovernorID,
      s.WeekStartUtc,
      s.SnapshotTsUtc,
      s.BuildingTotal,
      s.TechDonationTotal,
      ROW_NUMBER() OVER (
          PARTITION BY s.GovernorID, s.WeekStartUtc
          ORDER BY s.SnapshotTsUtc DESC
      ) AS rn
  FROM dbo.vAllianceActivitySnapshots s WITH (NOLOCK)
)
SELECT
    GovernorID,
    WeekStartUtc,
    SnapshotTsUtc AS WeekFinalTsUtc,
    BuildingTotal AS WeekFinalBuildingTotal,
    TechDonationTotal AS WeekFinalTechTotal
FROM Ranked
WHERE rn = 1;


'
