SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vWTD_RSSAssisted]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vWTD_RSSAssisted]  AS 
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
WeekBounds AS (
    SELECT
        LatestDate,
        -- Monday of the same week as LatestDate (ISO-like: Monday=week start)
        DATEADD(DAY, -((DATEDIFF(DAY, 0, LatestDate) + 6) % 7), LatestDate) AS WeekStartMonday
    FROM LatestDate
),
WeekEndPerGov AS (  -- value at the latest date (end of current week window)
    SELECT
        b.GovernorID,
        b.GovernorName,
        b.Alliance,
        b.RSSAssistance AS WeekEndAssist,
        wb.WeekStartMonday,
        wb.LatestDate
    FROM Base b
    CROSS JOIN WeekBounds wb
    WHERE b.AsOfDate = wb.LatestDate
),
PrevBeforeWeek AS (  -- last value BEFORE week start (per governor)
    SELECT
        x.GovernorID,
        x.AsOfDate AS PrevAsOfDate,
        x.RSSAssistance AS PrevBeforeWeekAssist
    FROM (
        SELECT
            b.GovernorID,
            b.AsOfDate,
            b.RSSAssistance,
            ROW_NUMBER() OVER (
                PARTITION BY b.GovernorID
                ORDER BY b.AsOfDate DESC
            ) AS rn
        FROM Base b
        CROSS JOIN WeekBounds wb
        WHERE b.AsOfDate < wb.WeekStartMonday
    ) AS x
    WHERE x.rn = 1
),
FirstInWeek AS (  -- first value WITHIN the week window (per governor)
    SELECT
        y.GovernorID,
        y.AsOfDate AS FirstWeekDate,
        y.RSSAssistance AS FirstWeekAssist
    FROM (
        SELECT
            b.GovernorID,
            b.AsOfDate,
            b.RSSAssistance,
            ROW_NUMBER() OVER (
                PARTITION BY b.GovernorID
                ORDER BY b.AsOfDate ASC
            ) AS rn
        FROM Base b
        CROSS JOIN WeekBounds wb
        WHERE b.AsOfDate >= wb.WeekStartMonday
          AND b.AsOfDate <= wb.LatestDate
    ) AS y
    WHERE y.rn = 1
)
SELECT
    we.WeekStartMonday,
    we.LatestDate AS WeekEndDate,
    we.GovernorID,
    we.GovernorName,
    we.Alliance,
    CASE
        WHEN COALESCE(pw.PrevBeforeWeekAssist, fw.FirstWeekAssist) IS NULL THEN 0
        WHEN we.WeekEndAssist - COALESCE(pw.PrevBeforeWeekAssist, fw.FirstWeekAssist) < 0 THEN 0
        ELSE we.WeekEndAssist - COALESCE(pw.PrevBeforeWeekAssist, fw.FirstWeekAssist)
    END AS WTD_RSSAssisted,
    we.WeekEndAssist AS RSS_Assisted_WeekEnd,
    COALESCE(pw.PrevAsOfDate, fw.FirstWeekDate) AS BaselineAsOfDate,
    COALESCE(pw.PrevBeforeWeekAssist, fw.FirstWeekAssist) AS RSS_Assisted_Baseline
FROM WeekEndPerGov we
LEFT JOIN PrevBeforeWeek pw ON pw.GovernorID = we.GovernorID
LEFT JOIN FirstInWeek  fw ON fw.GovernorID = we.GovernorID
WHERE CASE
          WHEN COALESCE(pw.PrevBeforeWeekAssist, fw.FirstWeekAssist) IS NULL THEN 0
          WHEN we.WeekEndAssist - COALESCE(pw.PrevBeforeWeekAssist, fw.FirstWeekAssist) < 0 THEN 0
          ELSE we.WeekEndAssist - COALESCE(pw.PrevBeforeWeekAssist, fw.FirstWeekAssist)
      END > 0;


'
