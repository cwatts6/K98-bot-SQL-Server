SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vDaily_PlayerExport]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vDaily_PlayerExport]  AS 
WITH KSDay AS
(
    SELECT
        ks.GovernorID,
        ks.AsOfDate,
        MAX(LTRIM(RTRIM(ks.GovernorName))) AS GovernorName,
        MAX(LTRIM(RTRIM(ks.Alliance))) AS Alliance,
        MAX(ks.Power) AS Power,
        MAX(TRY_CONVERT(bigint, ks.[Troops Power])) AS TroopPower,
        MAX(ks.KillPoints) AS KillPoints,
        MAX(ks.Deads) AS Deads,
        MAX(ks.RSS_Gathered) AS RSS_Gathered,
        MAX(ks.RSSAssistance) AS RSSAssist,
        MAX(ks.Helps) AS Helps,
        MAX(TRY_CONVERT(bigint, ks.[Tech Power])) AS TechPower,
        MAX(TRY_CONVERT(int, ks.AOOJoined)) AS AOOJoined,
        MAX(TRY_CONVERT(int, ks.AOOWon)) AS AOOWon,
        MAX(TRY_CONVERT(bigint, ks.AOOAvgKill)) AS AOOAvgKill,
        MAX(TRY_CONVERT(bigint, ks.AOOAvgDead)) AS AOOAvgDead,
        MAX(TRY_CONVERT(bigint, ks.AOOAvgHeal)) AS AOOAvgHeal,
        MAX(ks.T4_Kills) AS T4_Kills,
        MAX(ks.T5_Kills) AS T5_Kills,
        MAX(ks.[T4&T5_KILLS]) AS T4T5_Kills,
        MAX(TRY_CONVERT(bigint, ks.HealedTroops)) AS HealedTroops,
        MAX(TRY_CONVERT(bigint, ks.RangedPoints)) AS RangedPoints,
        MAX(TRY_CONVERT(bigint, ks.HighestAcclaim)) AS HighestAcclaim,
        MAX(TRY_CONVERT(int, ks.AutarchTimes)) AS AutarchTimes
    FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
    GROUP BY ks.GovernorID, ks.AsOfDate
),
KSDeltas AS
(
    SELECT
        d.*,
        d.Power - LAG(d.Power) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS PowerDelta,
        TRY_CONVERT(bigint, d.TroopPower - LAG(d.TroopPower) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS TroopPowerDelta,
        d.KillPoints - LAG(d.KillPoints) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS KillPointsDelta,
        d.Deads - LAG(d.Deads) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS DeadsDelta,
        d.RSS_Gathered - LAG(d.RSS_Gathered) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS RSS_GatheredDelta,
        d.RSSAssist - LAG(d.RSSAssist) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS RSSAssistDelta,
        d.Helps - LAG(d.Helps) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS HelpsDelta,
        TRY_CONVERT(bigint, d.TechPower - LAG(d.TechPower) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS TechPowerDelta,
        TRY_CONVERT(int, d.AOOJoined - LAG(d.AOOJoined) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOJoinedDelta,
        TRY_CONVERT(int, d.AOOWon - LAG(d.AOOWon) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOWonDelta,
        TRY_CONVERT(bigint, d.AOOAvgKill - LAG(d.AOOAvgKill) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOAvgKillDelta,
        TRY_CONVERT(bigint, d.AOOAvgDead - LAG(d.AOOAvgDead) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOAvgDeadDelta,
        TRY_CONVERT(bigint, d.AOOAvgHeal - LAG(d.AOOAvgHeal) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOAvgHealDelta,
        d.T4_Kills - LAG(d.T4_Kills) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS T4_KillsDelta,
        d.T5_Kills - LAG(d.T5_Kills) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS T5_KillsDelta,
        d.T4T5_Kills - LAG(d.T4T5_Kills) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate) AS T4T5_KillsDelta,
        TRY_CONVERT(bigint, d.HealedTroops - LAG(d.HealedTroops) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS HealedTroopsDelta,
        TRY_CONVERT(bigint, d.RangedPoints - LAG(d.RangedPoints) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS RangedPointsDelta,
        TRY_CONVERT(bigint, d.HighestAcclaim - LAG(d.HighestAcclaim) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS HighestAcclaimDelta,
        TRY_CONVERT(int, d.AutarchTimes - LAG(d.AutarchTimes) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AutarchTimesDelta
    FROM KSDay AS d
),
AA AS
(
    SELECT
        CONVERT(date, a.DeltaDateUtc) AS AsOfDate,
        a.GovernorID,
        MAX(LTRIM(RTRIM(a.GovernorName))) AS GovernorName_AA,
        MAX(LTRIM(RTRIM(a.AllianceTag))) AS AllianceTag,
        SUM(TRY_CONVERT(bigint, a.BuildingDelta)) AS BuildingMinutes,
        SUM(TRY_CONVERT(bigint, a.TechDonationDelta)) AS TechDonations
    FROM dbo.vDaily_AllianceActivity AS a WITH (NOLOCK)
    GROUP BY CONVERT(date, a.DeltaDateUtc), a.GovernorID
),
FD AS
(
    SELECT
        r.AsOfDate,
        r.GovernorID,
        SUM(TRY_CONVERT(int, r.TotalRallies)) AS FortsTotal,
        SUM(TRY_CONVERT(int, r.RalliesLaunched)) AS FortsLaunched,
        SUM(TRY_CONVERT(int, r.RalliesJoined)) AS FortsJoined
    FROM dbo.cur_RallyDaily AS r WITH (NOLOCK)
    GROUP BY r.AsOfDate, r.GovernorID
)
SELECT
    x.GovernorID,
    x.GovernorName,
    COALESCE(x.Alliance, AA.AllianceTag) AS Alliance,
    x.AsOfDate,
    x.Power, x.TroopPower, x.KillPoints, x.Deads,
    x.RSS_Gathered, x.RSSAssist, x.Helps, x.TechPower,
    x.PowerDelta, x.TroopPowerDelta, x.KillPointsDelta, x.DeadsDelta,
    x.RSS_GatheredDelta, x.RSSAssistDelta, x.HelpsDelta, x.TechPowerDelta,
    AA.BuildingMinutes, AA.TechDonations,
    FD.FortsTotal, FD.FortsLaunched, FD.FortsJoined,
    x.AOOJoined, x.AOOWon, x.AOOAvgKill, x.AOOAvgDead, x.AOOAvgHeal,
    x.AOOJoinedDelta, x.AOOWonDelta, x.AOOAvgKillDelta, x.AOOAvgDeadDelta, x.AOOAvgHealDelta,
    x.T4_Kills, x.T5_Kills, x.T4T5_Kills, x.HealedTroops, x.RangedPoints,
    x.HighestAcclaim, x.AutarchTimes,
    x.T4_KillsDelta, x.T5_KillsDelta, x.T4T5_KillsDelta, x.HealedTroopsDelta,
    x.RangedPointsDelta, x.HighestAcclaimDelta, x.AutarchTimesDelta
FROM KSDeltas AS x
LEFT JOIN AA
  ON AA.GovernorID = x.GovernorID
 AND AA.AsOfDate = x.AsOfDate
LEFT JOIN FD
  ON FD.GovernorID = x.GovernorID
 AND FD.AsOfDate = x.AsOfDate;

'
