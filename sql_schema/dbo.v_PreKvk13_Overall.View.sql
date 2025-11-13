SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PreKvk13_Overall]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PreKvk13_Overall]  AS 
WITH latest AS (
  SELECT s.KVK_NO, s.ScanID
  FROM dbo.PreKvk_Scan s
  WHERE s.KVK_NO = 13
    AND s.ScanID = (
      SELECT MAX(s2.ScanID) FROM dbo.PreKvk_Scan s2
      WHERE s2.KVK_NO = s.KVK_NO
    )
)
SELECT sc.GovernorID,
       MAX(sc.GovernorName) AS GovernorName,
       MAX(sc.Points)       AS Points
FROM dbo.PreKvk_Scores sc
JOIN latest l
  ON l.KVK_NO = sc.KVK_NO AND l.ScanID = sc.ScanID
GROUP BY sc.GovernorID;

'
