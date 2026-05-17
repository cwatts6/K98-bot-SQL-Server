SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PreKvk13_Phase2]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PreKvk13_Phase2]  AS 
WITH Latest AS (
  SELECT TOP (1) ScanID
  FROM dbo.PreKvk_Scan
  WHERE KVK_NO = 13
  ORDER BY ScanID DESC
)
SELECT sc.GovernorID,
       CONVERT(int, sc.Stage2Points) AS DeltaPoints
FROM dbo.PreKvk_Scores sc
JOIN Latest l
  ON l.ScanID = sc.ScanID
WHERE sc.KVK_NO = 13
  AND sc.Stage2Points IS NOT NULL;


'
