SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[KVK].[vw_FightingDataset]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [KVK].[vw_FightingDataset]  AS 
WITH W AS (
    SELECT KVK_NO, WindowName
    FROM KVK.KVK_Windows
    WHERE StartScanID IS NOT NULL
)
SELECT
    p.KVK_NO,
    p.WindowName,
    p.governor_id,
    p.name,
    p.kingdom,
    p.campid,
    p.kp_gain,
    p.kp_gain_recalc,
    p.kills_gain,
    p.t4_kills,
    p.t5_kills,
    p.kp_loss,
    p.healed_troops,
    p.deads,
    p.starting_power,
    p.dkp,
    p.last_scan_id,
    p.computed_at_utc,
    p.cur_contribute_gain AS acclaim_gain
FROM KVK.KVK_Player_Windowed p
JOIN W ON W.KVK_NO = p.KVK_NO
     AND W.WindowName = p.WindowName;


'
