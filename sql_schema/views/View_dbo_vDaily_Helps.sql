SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vDaily_Helps]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vDaily_Helps]  AS 
WITH DayEnd AS (
    SELECT
        ks.GovernorID,
        ks.GovernorName,
        ks.Alliance,
        ks.AsOfDate,
        ks.Helps,
        ROW_NUMBER() OVER (
            PARTITION BY ks.GovernorID, ks.AsOfDate
            ORDER BY ks.SCANORDER DESC
        ) AS rn
    FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
),
Base AS (
    SELECT GovernorID, GovernorName, Alliance, AsOfDate, Helps
    FROM DayEnd
    WHERE rn = 1
),
LatestDate AS (
    SELECT MAX(AsOfDate) AS LatestDate FROM Base
),
WithPrev AS (
    SELECT
        b.*,
        LAG(b.Helps) OVER (PARTITION BY b.GovernorID ORDER BY b.AsOfDate) AS PrevHelps
    FROM Base b
)
SELECT
    wp.AsOfDate,
    wp.GovernorID,
    wp.GovernorName,
    wp.Alliance,
    (wp.Helps - ISNULL(wp.PrevHelps, 0)) AS HelpsDelta,
    wp.Helps                            AS Helps_Current,
    NULLIF(wp.PrevHelps, 0)             AS Helps_Prior
FROM WithPrev wp
CROSS JOIN LatestDate ld
WHERE wp.AsOfDate = ld.LatestDate
  AND (wp.Helps - ISNULL(wp.PrevHelps, 0)) > 0;



'
