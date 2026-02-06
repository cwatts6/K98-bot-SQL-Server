SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_StatsWindowDeltas_GovCsv]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE FUNCTION [dbo].[fn_StatsWindowDeltas_GovCsv](@WindowStartUtc [datetime2](7), @WindowEndUtc [datetime2](7), @GovCsv [nvarchar](max))
RETURNS TABLE AS 
RETURN
WITH Ids AS (
    SELECT TRY_CAST(value AS int) AS GovernorID
    FROM STRING_SPLIT(@GovCsv, '','')
    WHERE value IS NOT NULL AND LTRIM(RTRIM(value)) <> ''''
),
W AS (  -- rows inside window
    SELECT d.*
    FROM dbo.vDaily_PlayerExport d WITH (NOLOCK)
    WHERE d.GovernorID IN (SELECT GovernorID FROM Ids)
      AND d.AsOfDate BETWEEN CAST(@WindowStartUtc AS date) AND CAST(@WindowEndUtc AS date)
),
LastSnap AS ( -- last snapshot at or before window end
    SELECT d.GovernorID, MAX(d.AsOfDate) AS LastDate
    FROM dbo.vDaily_PlayerExport d WITH (NOLOCK)
    WHERE d.GovernorID IN (SELECT GovernorID FROM Ids)
      AND d.AsOfDate <= CAST(@WindowEndUtc AS date)
    GROUP BY d.GovernorID
),
LastVals AS (
    SELECT
        d.GovernorID,
        -- Core metrics (USED BY /my_stats)
        d.Power         AS PowerEnd,
        d.TroopPower    AS TroopPowerEnd,
        d.KillPoints    AS KillPointsEnd,
        d.Deads         AS DeadsEnd,
        d.RSS_Gathered  AS RSSGatheredEnd,
        d.RSSAssist     AS RSSAssistEnd,
        d.Helps         AS HelpsEnd,
        -- AOO metrics (USED BY /my_stats for display)
        d.AOOJoined     AS AOOJoinedEnd,
        d.AOOWon        AS AOOWonEnd,
        d.AOOAvgKill    AS AOOAvgKillEnd,
        d.AOOAvgDead    AS AOOAvgDeadEnd,
        d.AOOAvgHeal    AS AOOAvgHealEnd,
        -- Forts snapshot (MISSING - THIS WAS THE BUG!)
        d.FortsTotal    AS FortsEnd,
        -- Detailed metrics (EXPORT-ONLY)
        d.T4_Kills      AS T4_KillsEnd,
        d.T5_Kills      AS T5_KillsEnd,
        d.T4T5_Kills    AS T4T5_KillsEnd,
        d.HealedTroops  AS HealedTroopsEnd,
        d.RangedPoints  AS RangedPointsEnd,
        d.HighestAcclaim AS HighestAcclaimEnd,
        d.AutarchTimes  AS AutarchTimesEnd
    FROM dbo.vDaily_PlayerExport d WITH (NOLOCK)
    JOIN LastSnap ls
      ON ls.GovernorID = d.GovernorID AND ls.LastDate = d.AsOfDate
),
Agg AS (  -- sum deltas & daily counts across window
    SELECT
        w.GovernorID,
        -- Core deltas (USED BY /my_stats)
        SUM(COALESCE(w.PowerDelta,0))          AS PowerDelta,
        SUM(COALESCE(w.TroopPowerDelta,0))     AS TroopPowerDelta,
        SUM(COALESCE(w.KillPointsDelta,0))     AS KillPointsDelta,
        SUM(COALESCE(w.DeadsDelta,0))          AS DeadsDelta,
        SUM(COALESCE(w.RSS_GatheredDelta,0))   AS RSSGatheredDelta,
        SUM(COALESCE(w.RSSAssistDelta,0))      AS RSSAssistDelta,
        SUM(COALESCE(w.HelpsDelta,0))          AS HelpsDelta,
        SUM(COALESCE(w.BuildingMinutes,0))     AS BuildingMinutesDelta,
        SUM(COALESCE(w.TechDonations,0))       AS TechDonationsDelta,
        -- Forts (USED BY /my_stats)
        SUM(COALESCE(w.FortsTotal,0))          AS FortsTotal,
        SUM(COALESCE(w.FortsLaunched,0))       AS FortsLaunched,
        SUM(COALESCE(w.FortsJoined,0))         AS FortsJoined,
        -- AOO deltas (EXPORT-ONLY, not used by /my_stats)
        SUM(COALESCE(w.AOOJoinedDelta,0))      AS AOOJoinedDelta,
        SUM(COALESCE(w.AOOWonDelta,0))         AS AOOWonDelta,
        SUM(COALESCE(w.AOOAvgKillDelta,0))     AS AOOAvgKillDelta,
        SUM(COALESCE(w.AOOAvgDeadDelta,0))     AS AOOAvgDeadDelta,
        SUM(COALESCE(w.AOOAvgHealDelta,0))     AS AOOAvgHealDelta,
        -- Detailed metric deltas (EXPORT-ONLY)
        SUM(COALESCE(w.T4_KillsDelta,0))       AS T4_KillsDelta,
        SUM(COALESCE(w.T5_KillsDelta,0))       AS T5_KillsDelta,
        SUM(COALESCE(w.T4T5_KillsDelta,0))     AS T4T5_KillsDelta,
        SUM(COALESCE(w.HealedTroopsDelta,0))   AS HealedTroopsDelta,
        SUM(COALESCE(w.RangedPointsDelta,0))   AS RangedPointsDelta
    FROM W w
    GROUP BY w.GovernorID
)
SELECT
    a.GovernorID,
    -- Core snapshots (USED BY /my_stats)
    lv.PowerEnd, lv.TroopPowerEnd, lv.KillPointsEnd, lv.DeadsEnd,
    lv.RSSGatheredEnd, lv.RSSAssistEnd, lv.HelpsEnd,
    -- Core deltas (USED BY /my_stats)
    a.PowerDelta, a.TroopPowerDelta, a.KillPointsDelta, a.DeadsDelta,
    a.RSSGatheredDelta, a.RSSAssistDelta, a.HelpsDelta,
    a.BuildingMinutesDelta, a.TechDonationsDelta,
    -- Forts (USED BY /my_stats) - FIXED: Added snapshot
    lv.FortsEnd, a.FortsTotal, a.FortsLaunched, a.FortsJoined,
    -- AOO snapshots (USED BY /my_stats for display)
    lv.AOOJoinedEnd, lv.AOOWonEnd, lv.AOOAvgKillEnd, lv.AOOAvgDeadEnd, lv.AOOAvgHealEnd,
    -- AOO deltas (EXPORT-ONLY)
    a.AOOJoinedDelta, a.AOOWonDelta, a.AOOAvgKillDelta, a.AOOAvgDeadDelta, a.AOOAvgHealDelta,
    -- Detailed metrics snapshots (EXPORT-ONLY)
    lv.T4_KillsEnd, lv.T5_KillsEnd, lv.T4T5_KillsEnd, lv.HealedTroopsEnd,
    lv.RangedPointsEnd, lv.HighestAcclaimEnd, lv.AutarchTimesEnd,
    -- Detailed metrics deltas (EXPORT-ONLY)
    a.T4_KillsDelta, a.T5_KillsDelta, a.T4T5_KillsDelta, a.HealedTroopsDelta, a.RangedPointsDelta
FROM Agg a
LEFT JOIN LastVals lv ON lv.GovernorID = a.GovernorID;
' 
END

