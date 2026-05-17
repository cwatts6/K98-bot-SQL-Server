SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
EXEC(N'CREATE OR ALTER FUNCTION [dbo].[fn_PreKvkPhaseDelta](@KVK_NO [int], @Phase [tinyint])
RETURNS TABLE AS
RETURN
WITH W AS (
    SELECT StartUTC, EndUTC
    FROM dbo.PreKvk_Phases
    WHERE KVK_NO=@KVK_NO AND Phase=@Phase
),
A AS (
    SELECT sc.GovernorID, sc.Points, s.ScanTimestampUTC
    FROM dbo.PreKvk_Scores sc
    JOIN dbo.PreKvk_Scan   s
      ON s.KVK_NO=sc.KVK_NO AND s.ScanID=sc.ScanID
    WHERE sc.KVK_NO=@KVK_NO
),
B AS (
    SELECT a.GovernorID, MAX(a.Points) AS Baseline
    FROM A a CROSS JOIN W
    WHERE a.ScanTimestampUTC < W.StartUTC
    GROUP BY a.GovernorID
),
P AS (
    SELECT a.GovernorID, MAX(a.Points) AS InWindow
    FROM A a CROSS JOIN W
    WHERE a.ScanTimestampUTC BETWEEN W.StartUTC AND W.EndUTC
    GROUP BY a.GovernorID
)
SELECT COALESCE(p.GovernorID, b.GovernorID) AS GovernorID,
       CONVERT(int, COALESCE(p.InWindow, COALESCE(b.Baseline,0)) - COALESCE(b.Baseline,0)) AS DeltaPoints
FROM B b
FULL OUTER JOIN P p ON p.GovernorID=b.GovernorID;
')
