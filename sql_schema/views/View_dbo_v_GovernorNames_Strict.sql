SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_GovernorNames_Strict]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_GovernorNames_Strict]  AS 
SELECT *
FROM dbo.v_GovernorNames
WHERE GovernorName IS NOT NULL AND LTRIM(RTRIM(GovernorName)) <> '''';


'
