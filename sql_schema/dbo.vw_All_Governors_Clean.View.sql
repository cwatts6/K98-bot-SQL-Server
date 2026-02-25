SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_All_Governors_Clean]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vw_All_Governors_Clean]  AS 
SELECT 
    [GovernorID],
    LTRIM(RTRIM([GovernorName])) AS GovernorName,
    [CityHallLevel]
FROM 
    [dbo].[ALL_GOVS]
WHERE 
    GovernorName IS NOT NULL;


'
