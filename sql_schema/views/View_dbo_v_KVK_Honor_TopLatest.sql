SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_KVK_Honor_TopLatest]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_KVK_Honor_TopLatest]  AS 
WITH last_scan AS (
  SELECT KVK_NO, MAX(ScanID) AS ScanID
  FROM dbo.KVK_Honor_Scan
  GROUP BY KVK_NO
)
SELECT a.KVK_NO, a.ScanID, s.ScanTimestampUTC,
       a.GovernorID, a.GovernorName, a.HonorPoints,
       RANK() OVER (PARTITION BY a.KVK_NO, a.ScanID ORDER BY a.HonorPoints DESC, a.GovernorID ASC) AS Rank
FROM dbo.KVK_Honor_AllPlayers_Raw a
JOIN last_scan l ON l.KVK_NO = a.KVK_NO AND l.ScanID = a.ScanID
JOIN dbo.KVK_Honor_Scan s ON s.KVK_NO = a.KVK_NO AND s.ScanID = a.ScanID;


'
