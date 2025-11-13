SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vWTD_Activity]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vWTD_Activity]  AS 
SELECT
    a.WeekStartUtc,
    a.GovernorID,
    SUM(a.BuildDonations)     AS WTD_BuildDonations,
    SUM(a.TechDonations)      AS WTD_TechDonations
FROM dbo.AllianceActivityDaily AS a WITH (NOLOCK)
GROUP BY a.WeekStartUtc, a.GovernorID;



'
