SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vDailyWithWTD_Activity]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vDailyWithWTD_Activity]  AS 
WITH X AS (
    SELECT
        GovernorID, AsOfDate, WeekStartUtc,
        BuildDonations, TechDonations,
        SUM(BuildDonations) OVER (
            PARTITION BY GovernorID, WeekStartUtc
            ORDER BY AsOfDate
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS WTD_Build,
        SUM(TechDonations) OVER (
            PARTITION BY GovernorID, WeekStartUtc
            ORDER BY AsOfDate
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS WTD_Tech
    FROM dbo.AllianceActivityDaily WITH (NOLOCK)
)
SELECT * FROM X;


'
