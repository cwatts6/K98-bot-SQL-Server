SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[KVK].[vw_FightingDataset]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [KVK].[vw_FightingDataset]  AS 
WITH W AS (
  SELECT KVK_NO, WindowName
  FROM KVK.KVK_Windows
  WHERE StartScanID IS NOT NULL
)
SELECT p.*
FROM KVK.KVK_Player_Windowed p
JOIN W ON W.KVK_NO = p.KVK_NO
     AND W.WindowName = p.WindowName;


'
