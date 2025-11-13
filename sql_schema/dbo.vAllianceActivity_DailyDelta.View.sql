SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vAllianceActivity_DailyDelta]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vAllianceActivity_DailyDelta]  AS 
SELECT
    d.AsOfDate                      AS DeltaDateUtc,         -- <- embed uses this name
    d.GovernorID,
    g.GovernorName,
    d.BuildDonations                AS BuildingDelta,
    d.TechDonations                 AS TechDonationDelta
FROM dbo.AllianceActivityDaily AS d WITH (NOLOCK)
LEFT JOIN dbo.v_GovernorNames   AS g WITH (NOLOCK) ON g.GovernorID = d.GovernorID;


'
