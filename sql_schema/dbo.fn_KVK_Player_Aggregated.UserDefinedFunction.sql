SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_KVK_Player_Aggregated]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE FUNCTION [dbo].[fn_KVK_Player_Aggregated](@kvk_no [int])
RETURNS TABLE AS 
RETURN
(
    WITH W AS (
        SELECT WindowName
        FROM KVK.KVK_Windows
        WHERE KVK_NO = @kvk_no AND StartScanID IS NOT NULL
    )
    SELECT p.[governor_id],
           COALESCE(MAX(p.Name), CONVERT(varchar(100), p.[governor_id])) AS name,
           MAX(p.Kingdom) AS kingdom,
           MAX(p.CampID) AS campid,
           SUM(ISNULL(p.T4_Kills,0)) AS t4,
           SUM(ISNULL(p.T5_Kills,0)) AS t5,
           SUM(ISNULL(p.Deads,0)) AS deads,
           MAX(ISNULL(p.Starting_Power,0)) AS sp
    FROM KVK.KVK_Player_Windowed p
    JOIN W ON W.WindowName = p.WindowName
    WHERE p.KVK_NO = @kvk_no
    GROUP BY p.[governor_id]
);

' 
END

