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
        d.Power         AS PowerEnd,
        d.TroopPower    AS TroopPowerEnd,
        d.KillPoints    AS KillPointsEnd,
        d.Deads         AS DeadsEnd,
        d.RSS_Gathered  AS RSSGatheredEnd,
        d.RSSAssist    AS RSSAssistEnd,
        d.Helps         AS HelpsEnd
    FROM dbo.vDaily_PlayerExport d WITH (NOLOCK)
    JOIN LastSnap ls
      ON ls.GovernorID = d.GovernorID AND ls.LastDate = d.AsOfDate
),
Agg AS (  -- sum deltas & daily counts across window
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
    lv.PowerEnd, lv.TroopPowerEnd, lv.KillPointsEnd, lv.DeadsEnd,
    lv.RSSGatheredEnd, lv.RSSAssistEnd, lv.HelpsEnd,
    a.PowerDelta, a.TroopPowerDelta, a.KillPointsDelta, a.DeadsDelta,
    a.RSSGatheredDelta, a.RSSAssistDelta, a.HelpsDelta,
    a.BuildingMinutesDelta, a.TechDonationsDelta,
    a.FortsTotal, a.FortsLaunched, a.FortsJoined
FROM Agg a
LEFT JOIN LastVals lv ON lv.GovernorID = a.GovernorID;
' 
END

