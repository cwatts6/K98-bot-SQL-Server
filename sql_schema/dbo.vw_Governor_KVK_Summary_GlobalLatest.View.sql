SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_Governor_KVK_Summary_GlobalLatest]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vw_Governor_KVK_Summary_GlobalLatest]  AS 
WITH latest_scan AS (
    -- only rows from the single most-recent scan (global max SCANORDER)
    SELECT k.*
    FROM dbo.KingdomScanData4 k
    WHERE k.SCANORDER = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)
),
excel_ranked AS (
    -- rank EXCEL_FOR_DASHBOARD rows per governor by KVK_RANK desc:
    -- rn = 1 is Latest; rn = 2 is Last (previous)
    SELECT e.*,
           ROW_NUMBER() OVER (PARTITION BY e.Gov_ID ORDER BY e.KVK_NO DESC) AS rn
    FROM dbo.EXCEL_FOR_DASHBOARD e
),
kvk_latest AS (
    SELECT Gov_ID,
           KVK_RANK,
           [T4&T5_Kills],
           [% of Kill Target]
    FROM excel_ranked
    WHERE rn = 1
),
kvk_prev AS (
    SELECT Gov_ID,
           KVK_RANK,
           [T4&T5_Kills],
           [% of Kill Target]
    FROM excel_ranked
    WHERE rn = 2
)
SELECT
    CAST(ls.GovernorID AS BIGINT)            AS [GovernorId],         -- cast float -> bigint per your request
    ls.governorname AS [GovernorName],
    ls.Power,
    kvk_latest.KVK_RANK                     AS Latest_KVK_RANK,
    kvk_prev.KVK_RANK                       AS Last_KVK_RANK,
    kvk_latest.[T4&T5_Kills]                AS Latest_T4T5_Kills,
    kvk_prev.[T4&T5_Kills]                  AS Last_T4T5_Kills,
    kvk_latest.[% of Kill Target]           AS Latest_Percent_of_Kill_Target,
    kvk_prev.[% of Kill Target]             AS Last_Percent_of_Kill_Target
FROM latest_scan ls
LEFT JOIN kvk_latest
    ON kvk_latest.Gov_ID = CAST(ls.GovernorID AS BIGINT)
LEFT JOIN kvk_prev
    ON kvk_prev.Gov_ID   = CAST(ls.GovernorID AS BIGINT);


'
