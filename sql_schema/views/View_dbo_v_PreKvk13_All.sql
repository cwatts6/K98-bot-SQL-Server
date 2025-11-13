SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PreKvk13_All]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PreKvk13_All]  AS 
SELECT sc.GovernorID,
       sc.GovernorName,
       s.ScanTimestampUTC,
       sc.Points
FROM dbo.PreKvk_Scores sc
JOIN dbo.PreKvk_Scan s
  ON s.KVK_NO = sc.KVK_NO AND s.ScanID = sc.ScanID
WHERE sc.KVK_NO = 13;

'
