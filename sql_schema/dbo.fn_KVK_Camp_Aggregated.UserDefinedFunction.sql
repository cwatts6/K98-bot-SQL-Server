SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_KVK_Camp_Aggregated]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE FUNCTION [dbo].[fn_KVK_Camp_Aggregated](@kvk_no [int])
RETURNS TABLE AS 
RETURN
(
    WITH W AS (
        SELECT WindowName FROM KVK.KVK_Windows WHERE KVK_NO = @kvk_no AND StartScanID IS NOT NULL
    ), Agg AS (
        SELECT cw.CampID AS campid,
               MAX(cw.[camp_name]) AS camp_name,
               SUM(ISNULL(cw.T4_Kills,0)) AS t4,
               SUM(ISNULL(cw.T5_Kills,0)) AS t5,
               SUM(ISNULL(cw.Deads,0)) AS deads,
			   SUM(ISNULL(cw.kp_gain,0))AS KP,
			   SUM(ISNULL(cw.healed_troops,0)) AS healed_troops
        FROM KVK.KVK_Camp_Windowed cw
        JOIN W ON W.WindowName = cw.WindowName
        WHERE cw.KVK_NO = @kvk_no
        GROUP BY cw.CampID
    ), Den AS (
        SELECT d.campid, SUM(d.sp) AS denom
        FROM (
            SELECT p.[governor_id], MAX(ISNULL(p.CampID,0)) AS campid, MAX(ISNULL(p.Starting_Power,0)) AS sp
            FROM KVK.KVK_Player_Windowed p
            WHERE p.KVK_NO = @kvk_no
            GROUP BY p.[governor_id]
        ) d
        GROUP BY d.campid
    )
    SELECT a.campid, a.camp_name, a.t4, a.t5, a.deads, ISNULL(d.denom,0) AS denom
    FROM Agg a
    LEFT JOIN Den d ON d.campid = a.campid
);

' 
END

