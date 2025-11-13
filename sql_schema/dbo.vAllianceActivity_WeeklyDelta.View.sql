SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vAllianceActivity_WeeklyDelta]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vAllianceActivity_WeeklyDelta]  AS 
WITH Weeks AS (
    -- Compute the most recent Monday (UTC) and the previous Monday (UTC)
    SELECT
        CAST(SYSUTCDATETIME() AS DATE)                                    AS today,
        DATEADD(DAY, -(((DATEPART(WEEKDAY, CAST(SYSUTCDATETIME() AS DATE))+5)%7)), CAST(SYSUTCDATETIME() AS DATE)) AS this_monday
), LastCompletedWeek AS (
    SELECT
        DATEADD(DAY, -7, this_monday) AS start_prev_week,
        this_monday                   AS start_this_week
    FROM Weeks
)
SELECT
    g.GovernorName,
    a.GovernorID,
    SUM(a.BuildDonations) AS BuildingDeltaWeek,
    SUM(a.TechDonations)  AS TechDonationDeltaWeek
FROM dbo.AllianceActivityDaily a WITH (NOLOCK)
CROSS JOIN LastCompletedWeek w
LEFT JOIN dbo.v_GovernorNames g WITH (NOLOCK) ON g.GovernorID = a.GovernorID
WHERE a.AsOfDate >= w.start_prev_week
  AND a.AsOfDate <  w.start_this_week
GROUP BY g.GovernorName, a.GovernorID;


'
