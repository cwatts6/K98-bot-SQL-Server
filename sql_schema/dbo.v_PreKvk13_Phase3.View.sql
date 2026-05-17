SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
EXEC(N'CREATE OR ALTER VIEW [dbo].[v_PreKvk13_Phase3] AS
WITH Latest AS (
  SELECT TOP (1) ScanID
  FROM dbo.PreKvk_Scan
  WHERE KVK_NO = 13
  ORDER BY ScanID DESC
)
SELECT sc.GovernorID,
       CONVERT(int, sc.Stage3Points) AS DeltaPoints
FROM dbo.PreKvk_Scores sc
JOIN Latest l
  ON l.ScanID = sc.ScanID
WHERE sc.KVK_NO = 13
  AND sc.Stage3Points IS NOT NULL;
')
