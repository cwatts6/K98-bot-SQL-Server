SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_StatsWindowDeltas]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE FUNCTION [dbo].[fn_StatsWindowDeltas](@WindowStartUtc [datetime2](7), @WindowEndUtc [datetime2](7))
RETURNS TABLE AS 
RETURN
WITH Params AS (
    SELECT
      CAST(@WindowStartUtc AS date) AS StartDate,
      CAST(@WindowEndUtc   AS date) AS EndDate
),
-- All daily rows inside the window across ALL governors
W AS (
    SELECT d.*
    FROM dbo.vDaily_PlayerExport d WITH (NOLOCK)
    CROSS JOIN Params p
    WHERE d.AsOfDate BETWEEN p.StartDate AND p.EndDate
),
-- Last snapshot at or before window end (per governor)
LastSnap AS (
    SELECT d.GovernorID, MAX(d.AsOfDate) AS LastDate
    FROM dbo.vDaily_PlayerExport d WITH (NOLOCK)
    CROSS JOIN Params p
    WHERE d.AsOfDate <= p.EndDate
    GROUP BY d.GovernorID
),
LastVals AS (
    SELECT
        d.GovernorID,
        d.Power         AS PowerEnd,
        d.TroopPower    AS TroopPowerEnd,
        d.KillPoints    AS KillPointsEnd,
        d.Deads         AS DeadsEnd,
        d.RSS_Gathered  AS RSSGatheredEnd,
        d.RSSAssist     AS RSSAssistEnd,
        d.Helps         AS HelpsEnd
    FROM dbo.vDaily_PlayerExport d WITH (NOLOCK)
    JOIN LastSnap ls
      ON ls.GovernorID = d.GovernorID AND ls.LastDate = d.AsOfDate
),
Agg AS (
    SELECT
        w.GovernorID,
        SUM(COALESCE(w.PowerDelta,0))          AS PowerDelta,
        SUM(COALESCE(w.TroopPowerDelta,0))     AS TroopPowerDelta,
        SUM(COALESCE(w.KillPointsDelta,0))     AS KillPointsDelta,
        SUM(COALESCE(w.DeadsDelta,0))          AS DeadsDelta,
        SUM(COALESCE(w.RSS_GatheredDelta,0))   AS RSSGatheredDelta,
        SUM(COALESCE(w.RSSAssistDelta,0))      AS RSSAssistDelta,
        SUM(COALESCE(w.HelpsDelta,0))          AS HelpsDelta,
        SUM(COALESCE(w.BuildingMinutes,0))     AS BuildingMinutesDelta,
        SUM(COALESCE(w.TechDonations,0))       AS TechDonationsDelta,
        SUM(COALESCE(w.FortsTotal,0))          AS FortsTotal,
        SUM(COALESCE(w.FortsLaunched,0))       AS FortsLaunched,
        SUM(COALESCE(w.FortsJoined,0))         AS FortsJoined
    FROM W w
    GROUP BY w.GovernorID
)
SELECT
    a.GovernorID,

    -- End snapshots at window end
    lv.PowerEnd, lv.TroopPowerEnd, lv.KillPointsEnd, lv.DeadsEnd,
    lv.RSSGatheredEnd, lv.RSSAssistEnd, lv.HelpsEnd,

    -- Window sums of deltas (consistent with vDaily_PlayerExport design)
    a.PowerDelta, a.TroopPowerDelta, a.KillPointsDelta, a.DeadsDelta,
    a.RSSGatheredDelta, a.RSSAssistDelta, a.HelpsDelta,

    -- Alliance Activity sums
    a.BuildingMinutesDelta, a.TechDonationsDelta,

    -- Forts (canonical)
    a.FortsTotal, a.FortsLaunched, a.FortsJoined,

    -- Deprecated aliases for backward compatibility (remove later)
    a.FortsTotal    AS RalliesTotal,
    a.FortsLaunched AS RalliesLaunched,
    a.FortsJoined   AS RalliesJoined

FROM Agg a
LEFT JOIN LastVals lv ON lv.GovernorID = a.GovernorID;
' 
END

