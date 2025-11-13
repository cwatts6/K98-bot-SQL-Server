SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vDaily_RSSGathered]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vDaily_RSSGathered]  AS 
WITH DayEnd AS (
    SELECT
        ks.GovernorID,
        ks.GovernorName,
        ks.Alliance,
        ks.AsOfDate,
        ks.RSS_Gathered,
        ROW_NUMBER() OVER (
            PARTITION BY ks.GovernorID, ks.AsOfDate
            ORDER BY ks.SCANORDER DESC
        ) AS rn
    FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
),
Base AS (
    SELECT GovernorID, GovernorName, Alliance, AsOfDate, RSS_Gathered
    FROM DayEnd
    WHERE rn = 1
),
LatestDate AS (
    SELECT MAX(AsOfDate) AS LatestDate FROM Base
),
WithPrev AS (
    SELECT
        b.*,
        LAG(b.RSS_Gathered) OVER (PARTITION BY b.GovernorID ORDER BY b.AsOfDate) AS PrevRSS
    FROM Base b
)
SELECT
    wp.AsOfDate,
    wp.GovernorID,
    wp.GovernorName,
    wp.Alliance,
    (wp.RSS_Gathered - ISNULL(wp.PrevRSS, 0)) AS RSSGatheredDelta,
    wp.RSS_Gathered        AS RSS_Gathered_Current,
    NULLIF(wp.PrevRSS, 0)  AS RSS_Gathered_Prior -- note: prior date omitted to keep this scan-free
FROM WithPrev wp
CROSS JOIN LatestDate ld
WHERE wp.AsOfDate = ld.LatestDate
  AND (wp.RSS_Gathered - ISNULL(wp.PrevRSS, 0)) > 0;



'
