SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [KVK].[vw_Player_Overall_KVK_Rank]
AS
WITH RankedPlayers AS
(
    SELECT
        p.KVK_NO,
        p.WindowName,
        p.governor_id,
        p.name,
        p.kingdom,
        p.campid,
        p.kp_gain_recalc,
        ROW_NUMBER() OVER (
            PARTITION BY p.KVK_NO, p.WindowName
            ORDER BY p.kp_gain_recalc DESC, p.governor_id ASC
        ) AS overall_kvk_rank,
        COUNT_BIG(*) OVER (
            PARTITION BY p.KVK_NO, p.WindowName
        ) AS overall_kvk_total_governors,
        p.last_scan_id,
        p.computed_at_utc
    FROM KVK.KVK_Player_Windowed AS p
    WHERE p.WindowName = N'Full'
)
SELECT
    KVK_NO,
    WindowName,
    governor_id,
    name,
    kingdom,
    campid,
    kp_gain_recalc,
    overall_kvk_rank,
    overall_kvk_total_governors,
    CAST(
        CASE
            WHEN overall_kvk_total_governors > 0
                THEN (overall_kvk_rank * 100.0) / overall_kvk_total_governors
            ELSE NULL
        END AS decimal(6, 2)
    ) AS overall_kvk_top_percent,
    last_scan_id,
    computed_at_utc
FROM RankedPlayers;
GO
