SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vFortsCompleted_WeekToDate]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vFortsCompleted_WeekToDate]  AS 
WITH Latest AS (
    SELECT MAX(AsOfDate) AS LatestDate
    FROM dbo.cur_RallyDaily
),
Bounds AS (
    SELECT
        LatestDate,
        -- Correct, DATEFIRST-independent Monday-of-week
        DATEADD(DAY, - (DATEDIFF(DAY, 0, LatestDate) % 7), LatestDate) AS WeekStartMonday
    FROM Latest
),
ActualStart AS (
    -- If Monday is missing, start from the earliest available day in this week
    SELECT MIN(d.AsOfDate) AS StartDate
    FROM dbo.cur_RallyDaily d
    CROSS JOIN Bounds b
    WHERE d.AsOfDate BETWEEN b.WeekStartMonday AND b.LatestDate
),
WTD AS (
    SELECT
        d.GovernorID,
        MAX(d.GovernorName)    AS GovernorName,
        SUM(d.TotalRallies)    AS TotalRallies,
        SUM(d.RalliesLaunched) AS RalliesLaunched,
        SUM(d.RalliesJoined)   AS RalliesJoined,
        MIN(d.AsOfDate)        AS FirstDateIncluded,
        MAX(d.AsOfDate)        AS LastDateIncluded
    FROM dbo.cur_RallyDaily d
    CROSS JOIN Bounds b
    CROSS JOIN ActualStart s
    WHERE d.AsOfDate BETWEEN s.StartDate AND b.LatestDate
    GROUP BY d.GovernorID
)
SELECT
    GovernorID,
    GovernorName,
    TotalRallies,
    RalliesLaunched,
    RalliesJoined,
    CAST(FirstDateIncluded AS date) AS WTD_FromDate,
    CAST(LastDateIncluded  AS date) AS WTD_ToDate
FROM WTD;


'
