SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_KVK_Kingdom_Aggregated]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE FUNCTION [dbo].[fn_KVK_Kingdom_Aggregated](@kvk_no [int])
RETURNS TABLE AS 
RETURN
(
    WITH W AS (
        SELECT WindowName FROM KVK.KVK_Windows WHERE KVK_NO = @kvk_no AND StartScanID IS NOT NULL
    ), Agg AS (
        SELECT kw.Kingdom AS kingdom,
               SUM(ISNULL(kw.T4_Kills,0)) AS t4,
               SUM(ISNULL(kw.T5_Kills,0)) AS t5,
               SUM(ISNULL(kw.Deads,0)) AS deads
        FROM KVK.KVK_Kingdom_Windowed kw
        JOIN W ON W.WindowName = kw.WindowName
        WHERE kw.KVK_NO = @kvk_no
        GROUP BY kw.Kingdom
    ), Den AS (
        SELECT d.kingdom, SUM(d.sp) AS denom
        FROM (
            SELECT p.[governor_id], MAX(p.Kingdom) AS kingdom, MAX(ISNULL(p.Starting_Power,0)) AS sp
            FROM KVK.KVK_Player_Windowed p
            WHERE p.KVK_NO = @kvk_no
            GROUP BY p.[governor_id]
        ) d
        GROUP BY d.kingdom
    )
    SELECT a.kingdom, a.t4, a.t5, a.deads, ISNULL(d.denom,0) AS denom
    FROM Agg a
    LEFT JOIN Den d ON d.kingdom = a.kingdom
);

' 
END

