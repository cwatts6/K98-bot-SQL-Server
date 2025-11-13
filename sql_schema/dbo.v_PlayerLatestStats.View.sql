SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PlayerLatestStats]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PlayerLatestStats]  AS 
WITH MaxScan AS (
    SELECT GovernorID, MAX(SCANORDER) AS MaxScan
    FROM dbo.KingdomScanData4 WITH (NOLOCK)
    GROUP BY GovernorID
)
SELECT
    s.GovernorID,
    s.GovernorName AS Governor_Name,
    s.Alliance,
    s.[City Hall]   AS CityHallLevel,
    s.Power,
    s.[Troops Power],
    ISNULL(s.[T4&T5_KILLS], ISNULL(s.T4_Kills, 0) + ISNULL(s.T5_Kills, 0)) AS Kills,
    s.Deads,
    s.RSS_Gathered,
    s.Helps,
    s.SCANORDER,
    -- NEW:
    s.PowerRank
FROM dbo.KingdomScanData4 AS s WITH (NOLOCK)
JOIN MaxScan AS m
  ON m.GovernorID = s.GovernorID
 AND m.MaxScan    = s.SCANORDER;


'
