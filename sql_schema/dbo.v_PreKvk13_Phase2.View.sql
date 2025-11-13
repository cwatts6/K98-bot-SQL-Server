SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PreKvk13_Phase2]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PreKvk13_Phase2]  AS 
WITH W AS (
  SELECT StartUTC, EndUTC
  FROM dbo.PreKvk_Phases
  WHERE KVK_NO=13 AND Phase=2
),
B AS ( -- baseline = latest points strictly before phase start
  SELECT a.GovernorID,
         MAX(a.Points) AS Baseline
  FROM dbo.v_PreKvk13_All a
  CROSS JOIN W
  WHERE a.ScanTimestampUTC < W.StartUTC
  GROUP BY a.GovernorID
),
P AS ( -- in-window = max points achieved during the window
  SELECT a.GovernorID,
         MAX(a.Points) AS InWindow
  FROM dbo.v_PreKvk13_All a
  CROSS JOIN W
  WHERE a.ScanTimestampUTC BETWEEN W.StartUTC AND W.EndUTC
  GROUP BY a.GovernorID
)
SELECT COALESCE(p.GovernorID, b.GovernorID) AS GovernorID,
       MAX(COALESCE(p.InWindow, b.Baseline, 0)) - MAX(COALESCE(b.Baseline, 0)) AS DeltaPoints
FROM B b
FULL JOIN P p ON p.GovernorID = b.GovernorID
GROUP BY COALESCE(p.GovernorID, b.GovernorID);


'
