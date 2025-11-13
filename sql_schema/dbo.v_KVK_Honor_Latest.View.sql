SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_KVK_Honor_Latest]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_KVK_Honor_Latest]  AS 
SELECT a.KVK_NO, a.GovernorID, a.GovernorName, a.HonorPoints,
       s.ScanID, s.ScanTimestampUTC
FROM dbo.KVK_Honor_AllPlayers_Raw a
JOIN (
  SELECT KVK_NO, GovernorID,
         MAX(ScanID) AS LatestScanID
  FROM dbo.KVK_Honor_AllPlayers_Raw
  GROUP BY KVK_NO, GovernorID
) x ON x.KVK_NO = a.KVK_NO AND x.GovernorID = a.GovernorID AND x.LatestScanID = a.ScanID
JOIN dbo.KVK_Honor_Scan s ON s.KVK_NO = a.KVK_NO AND s.ScanID = a.ScanID;


'
