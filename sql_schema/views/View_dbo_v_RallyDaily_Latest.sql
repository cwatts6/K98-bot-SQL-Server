SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_RallyDaily_Latest]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_RallyDaily_Latest]  AS 
SELECT d.*
FROM dbo.cur_RallyDaily AS d
WHERE d.AsOfDate = (SELECT MAX(AsOfDate) FROM dbo.cur_RallyDaily);


'
