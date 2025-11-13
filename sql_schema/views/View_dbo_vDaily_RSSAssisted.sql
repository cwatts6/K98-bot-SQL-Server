SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vDaily_RSSAssisted]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vDaily_RSSAssisted]  AS 
WITH DayEnd AS (
    SELECT
        ks.GovernorID,
        ks.GovernorName,
        ks.Alliance,
        ks.AsOfDate,
        ks.RSSAssistance,
        ROW_NUMBER() OVER (
            PARTITION BY ks.GovernorID, ks.AsOfDate
            ORDER BY ks.SCANORDER DESC
        ) AS rn
    FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
),
Base AS (  -- 1 row per GovernorID + AsOfDate (day-end)
    SELECT GovernorID, GovernorName, Alliance, AsOfDate, RSSAssistance
    FROM DayEnd
    WHERE rn = 1
),
LatestDate AS (
    SELECT MAX(AsOfDate) AS LatestDate
    FROM Base
),
WithPrev AS (
    SELECT
        b.*,
        LAG(b.RSSAssistance) OVER (
            PARTITION BY b.GovernorID
            ORDER BY b.AsOfDate
        ) AS PrevAssist
    FROM Base b
)
SELECT
    wp.AsOfDate,
    wp.GovernorID,
    wp.GovernorName,
    wp.Alliance,
    (wp.RSSAssistance - ISNULL(wp.PrevAssist, 0)) AS RSSAssistedDelta,
    wp.RSSAssistance AS RSS_Assisted_Current,
    NULLIF(wp.PrevAssist, 0) AS RSS_Assisted_Prior
FROM WithPrev wp
CROSS JOIN LatestDate ld
WHERE wp.AsOfDate = ld.LatestDate
  AND (wp.RSSAssistance - ISNULL(wp.PrevAssist, 0)) > 0;


'
