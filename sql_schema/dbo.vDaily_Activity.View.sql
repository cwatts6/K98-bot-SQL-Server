SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vDaily_Activity]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vDaily_Activity]  AS 
SELECT
    a.AsOfDate,
    a.GovernorID,
    a.BuildDonations,
    a.TechDonations
FROM dbo.AllianceActivityDaily AS a WITH (NOLOCK);



'
