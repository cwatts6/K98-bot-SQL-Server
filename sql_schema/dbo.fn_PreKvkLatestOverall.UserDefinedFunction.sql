SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_PreKvkLatestOverall]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE FUNCTION [dbo].[fn_PreKvkLatestOverall](@KVK_NO [int])
RETURNS TABLE AS 
RETURN
WITH L AS (
    SELECT TOP (1) ScanID
    FROM dbo.PreKvk_Scan
    WHERE KVK_NO = @KVK_NO
    ORDER BY ScanID DESC
)
SELECT s.GovernorID,
       MAX(s.GovernorName) AS GovernorName,
       MAX(s.Points)       AS Points
FROM dbo.PreKvk_Scores s
CROSS JOIN L
WHERE s.KVK_NO = @KVK_NO
  AND s.ScanID = L.ScanID
GROUP BY s.GovernorID;
' 
END

