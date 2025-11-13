SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vAllianceActivity_WeeklyCumulative]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vAllianceActivity_WeeklyCumulative]  AS 
WITH W AS (
    SELECT
        WeekStartUtc,
        GovernorID,
        GovernorName,
        AllianceTag,
        BuildingDeltaWeek,
        TechDonationDeltaWeek
    FROM dbo.vAllianceActivity_WeeklyDelta
)
SELECT
    WeekStartUtc,
    GovernorID,
    GovernorName,        -- name/tag as of this week (from the weekly row)
    AllianceTag,
    SUM(BuildingDeltaWeek)     OVER (
        PARTITION BY GovernorID
        ORDER BY WeekStartUtc
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS BuildingCumulative,
    SUM(TechDonationDeltaWeek) OVER (
        PARTITION BY GovernorID
        ORDER BY WeekStartUtc
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS TechDonationCumulative
FROM W;


'
