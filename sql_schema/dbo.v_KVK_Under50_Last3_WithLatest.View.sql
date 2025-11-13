SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_KVK_Under50_Last3_WithLatest]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_KVK_Under50_Last3_WithLatest]  AS 
WITH pkh_rn AS (
    SELECT
        pkh.GovernorID,
        pkh.KVK_NUMBER,
        TRY_CONVERT(decimal(9,2), pkh.KillPercent) AS KillPercent,
        ROW_NUMBER() OVER (
            PARTITION BY pkh.GovernorID
            ORDER BY pkh.KVK_NUMBER DESC
        ) AS rn
    FROM dbo.PlayerKVKHistory AS pkh
),
under30_or_null AS (
    SELECT
        r.GovernorID,
        MAX(CASE WHEN r.rn = 1 THEN r.KVK_NUMBER   END) AS KVK1_Number,
        MAX(CASE WHEN r.rn = 1 THEN r.KillPercent  END) AS KVK1_KillPercent,
        MAX(CASE WHEN r.rn = 2 THEN r.KVK_NUMBER   END) AS KVK2_Number,
        MAX(CASE WHEN r.rn = 2 THEN r.KillPercent  END) AS KVK2_KillPercent,
        MAX(CASE WHEN r.rn = 3 THEN r.KVK_NUMBER   END) AS KVK3_Number,
        MAX(CASE WHEN r.rn = 3 THEN r.KillPercent  END) AS KVK3_KillPercent
    FROM pkh_rn AS r
    WHERE r.rn <= 3
    GROUP BY r.GovernorID
    HAVING
        COUNT(*) = 3
        AND SUM(CASE
                    WHEN r.KillPercent < 30 OR r.KillPercent IS NULL THEN 1
                    ELSE 0
                END) = 3
)
SELECT
    u.GovernorID,
    ks.[GovernorName] AS [Governor_Name],
    ks.[Alliance]     AS [Alliance],
    ks.[City Hall]    AS [CityHallLevel],
    ks.[Power]        AS [Power],
    ks.[Troops Power] AS [Troop Power],
    ks.[TOTAL_KILLS]  AS [Kills],
    ks.[Deads]        AS [Deads],
    ks.[RSS_Gathered] AS [RSS_Gathered],
    ks.[Helps]        AS [Helps],
    u.KVK1_Number     AS [KVK1_Number],
    u.KVK1_KillPercent AS [KVK1_KILL_Percent],
    u.KVK2_Number     AS [KVK2_Number],
    u.KVK2_KillPercent AS [KVK2_KILL_Percent],
    u.KVK3_Number     AS [KVK3_Number],
    u.KVK3_KillPercent AS [KVK3_KILL_Percent],
    CONCAT(loc.X, '','', loc.Y) AS [Location]
FROM under30_or_null AS u
CROSS APPLY (
    /* latest valid (non-null, non-zero) location */
    SELECT TOP (1) pl.X, pl.Y
    FROM dbo.PlayerLocation pl
    WHERE pl.GovernorID = u.GovernorID
      AND pl.X IS NOT NULL AND pl.Y IS NOT NULL
      AND pl.X <> 0 AND pl.Y <> 0
    ORDER BY pl.[LastUpdated] DESC
) AS loc
CROSS APPLY (
    /* latest scan snapshot */
    SELECT TOP (1) *
    FROM dbo.KingdomScanData4 ks0
    WHERE ks0.GovernorID = u.GovernorID
    ORDER BY ks0.[SCANORDER] DESC
) AS ks
WHERE ks.[Power] > 40000000;


'
