SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_PreKvkPhaseDelta]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE FUNCTION [dbo].[fn_PreKvkPhaseDelta](@KVK_NO [int], @Phase [tinyint])
RETURNS TABLE AS 
RETURN
WITH L AS (
    SELECT TOP (1) ScanID
    FROM dbo.PreKvk_Scan
    WHERE KVK_NO = @KVK_NO
    ORDER BY ScanID DESC
),
StageValues AS (
    SELECT
        sc.GovernorID,
        CASE @Phase
            WHEN 1 THEN sc.Stage1Points
            WHEN 2 THEN sc.Stage2Points
            WHEN 3 THEN sc.Stage3Points
        END AS StagePoints
    FROM dbo.PreKvk_Scores sc
    JOIN L
      ON L.ScanID = sc.ScanID
    WHERE sc.KVK_NO = @KVK_NO
      AND @Phase IN (1, 2, 3)
)
SELECT GovernorID,
       CONVERT(int, StagePoints) AS DeltaPoints
FROM StageValues
WHERE StagePoints IS NOT NULL;
' 
END

