SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vDaily_PlayerExport]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vDaily_PlayerExport]  AS 
WITH KSDay AS (
    SELECT
        ks.GovernorID,
        ks.AsOfDate,
        MAX(LTRIM(RTRIM(ks.GovernorName)))           AS GovernorName,
        MAX(LTRIM(RTRIM(ks.Alliance)))               AS Alliance,
        MAX(TRY_CONVERT(bigint, ks.Power))           AS Power,
        MAX(TRY_CONVERT(bigint, ks.[Troops Power]))  AS TroopPower,
        MAX(TRY_CONVERT(bigint, ks.KillPoints))      AS KillPoints,
        MAX(TRY_CONVERT(bigint, ks.Deads))           AS Deads,
        MAX(TRY_CONVERT(bigint, ks.RSS_Gathered))    AS RSS_Gathered,
        MAX(TRY_CONVERT(bigint, ks.RSSAssistance))   AS RSSAssist,      -- ← camel-case, no underscore
        MAX(TRY_CONVERT(bigint, ks.Helps))           AS Helps,
        MAX(TRY_CONVERT(bigint, ks.[Tech Power]))    AS TechPower
    FROM dbo.KingdomScanData4 ks WITH (NOLOCK)
    GROUP BY ks.GovernorID, ks.AsOfDate
),
KSDeltas AS (
    SELECT
        d.*,
        TRY_CONVERT(bigint, d.Power       - LAG(d.Power)       OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS PowerDelta,
        TRY_CONVERT(bigint, d.TroopPower  - LAG(d.TroopPower)  OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS TroopPowerDelta,
        TRY_CONVERT(bigint, d.KillPoints  - LAG(d.KillPoints)  OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS KillPointsDelta,
        TRY_CONVERT(bigint, d.Deads       - LAG(d.Deads)       OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS DeadsDelta,
        TRY_CONVERT(bigint, d.RSS_Gathered- LAG(d.RSS_Gathered)OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS RSS_GatheredDelta,
        TRY_CONVERT(bigint, d.RSSAssist   - LAG(d.RSSAssist)   OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS RSSAssistDelta, -- ← new
        TRY_CONVERT(bigint, d.Helps       - LAG(d.Helps)       OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS HelpsDelta,
        TRY_CONVERT(bigint, d.TechPower   - LAG(d.TechPower)   OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS TechPowerDelta
    FROM KSDay d
),
AA AS (
    SELECT
        CONVERT(date, a.DeltaDateUtc) AS AsOfDate,
        a.GovernorID,
        MAX(LTRIM(RTRIM(a.GovernorName))) AS GovernorName_AA,
        MAX(LTRIM(RTRIM(a.AllianceTag)))  AS AllianceTag,
        SUM(TRY_CONVERT(bigint, a.BuildingDelta))      AS BuildingMinutes,
        SUM(TRY_CONVERT(bigint, a.TechDonationDelta))  AS TechDonations
    FROM dbo.vDaily_AllianceActivity a WITH (NOLOCK)
    GROUP BY CONVERT(date, a.DeltaDateUtc), a.GovernorID
),
FD AS ( -- Forts daily (cur_RallyDaily)
    SELECT
        r.AsOfDate,
        r.GovernorID,
        SUM(TRY_CONVERT(int, r.TotalRallies))    AS FortsTotal,
        SUM(TRY_CONVERT(int, r.RalliesLaunched)) AS FortsLaunched,
        SUM(TRY_CONVERT(int, r.RalliesJoined))   AS FortsJoined
    FROM dbo.cur_RallyDaily r WITH (NOLOCK)
    GROUP BY r.AsOfDate, r.GovernorID
)
SELECT
    x.GovernorID,
    x.GovernorName,
    COALESCE(x.Alliance, AA.AllianceTag) AS Alliance,
    x.AsOfDate,

    /* Base cumulative values */
    x.Power, x.TroopPower, x.KillPoints, x.Deads,
    x.RSS_Gathered, x.RSSAssist, x.Helps, x.TechPower,

    /* Day-over-day deltas */
    x.PowerDelta, x.TroopPowerDelta, x.KillPointsDelta, x.DeadsDelta,
    x.RSS_GatheredDelta, x.RSSAssistDelta, x.HelpsDelta, x.TechPowerDelta,

    /* Alliance activity (daily sums) */
    AA.BuildingMinutes, AA.TechDonations,

    /* Forts (daily sums) */
    FD.FortsTotal, FD.FortsLaunched, FD.FortsJoined
FROM KSDeltas x
LEFT JOIN AA ON AA.GovernorID = x.GovernorID AND AA.AsOfDate = x.AsOfDate
LEFT JOIN FD ON FD.GovernorID = x.GovernorID AND FD.AsOfDate = x.AsOfDate;


'
