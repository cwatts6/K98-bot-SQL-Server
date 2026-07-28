/*
RollbackForMigrationId: 20260727_001_phase4_view_type_alignment
Purpose: Restore the exact frozen Phase 3 view definitions before Phase 3 and Phase 2 rollback
Author: cwatts
CreatedUtc: 2026-07-27
TransactionMode: Required
DataChange: No
*/

/*
Rollback boundary:
    - Use only on the coordinated pre-restart rollback branch while all writers
      remain stopped.
    - Restore these Phase 4 views before restoring Phase 3 routines and before
      invoking the Phase 2 metadata-swap rollback.
    - This script holds both KS4 mutexes and proves value/metadata equivalence
      before commit.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 60000;

BEGIN TRANSACTION;

DECLARE @MigrationLockResult int;
EXEC @MigrationLockResult = sys.sp_getapplock
    @Resource = N'K98:KingdomScanData4:Migration',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 60000,
    @DbPrincipal = N'public';

IF @MigrationLockResult < 0
    THROW 52050, 'Phase 4 rollback could not acquire the KingdomScanData4 migration mutex within 60000 ms.', 1;

DECLARE @ImportLockResult int;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
    @LockTimeout = 60000,
    @LockResult = @ImportLockResult OUTPUT;

IF @ImportLockResult < 0
    THROW 52051, 'Phase 4 rollback could not acquire the Phase 3 import-pipeline mutex within 60000 ms.', 1;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
    THROW 52052, 'Phase 4 rollback requires the Phase 3 contracts to remain present until it completes.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.crypt_properties AS signature_info
    WHERE signature_info.class_desc = N'OBJECT_OR_COLUMN'
      AND signature_info.major_id IN
      (
          OBJECT_ID(N'dbo.fn_StatsWindowDeltas'),
          OBJECT_ID(N'dbo.fn_StatsWindowDeltas_GovCsv'),
          OBJECT_ID(N'dbo.usp_GetPlayerStatsWindows')
      )
)
    THROW 52059, 'Phase 4 rollback found a signed module; preserve or re-apply its signature explicitly before refresh.', 1;

DROP TABLE IF EXISTS #Phase4RollbackBeforeActivePlayers;
DROP TABLE IF EXISTS #Phase4RollbackBeforeMgeSignupReview;
DROP TABLE IF EXISTS #Phase4RollbackBeforeDailyPlayerExport;
DROP TABLE IF EXISTS #Phase4RollbackBeforeGlobalLatest;
DROP TABLE IF EXISTS #Phase4RollbackAfterActivePlayers;
DROP TABLE IF EXISTS #Phase4RollbackAfterMgeSignupReview;
DROP TABLE IF EXISTS #Phase4RollbackAfterDailyPlayerExport;
DROP TABLE IF EXISTS #Phase4RollbackAfterGlobalLatest;

SELECT *
INTO #Phase4RollbackBeforeActivePlayers
FROM dbo.v_Active_Players;

SELECT *
INTO #Phase4RollbackBeforeMgeSignupReview
FROM dbo.v_MGE_SignupReview;

SELECT *
INTO #Phase4RollbackBeforeDailyPlayerExport
FROM dbo.vDaily_PlayerExport;

SELECT *
INTO #Phase4RollbackBeforeGlobalLatest
FROM dbo.vw_Governor_KVK_Summary_GlobalLatest;

DROP TABLE IF EXISTS #Phase4RollbackMetadataBefore;

SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName,
    OBJECT_NAME(c.object_id) AS ObjectName,
    c.column_id,
    c.name AS ColumnName,
    c.system_type_id,
    c.user_type_id,
    c.max_length,
    c.precision,
    c.scale,
    c.collation_name,
    c.is_nullable
INTO #Phase4RollbackMetadataBefore
FROM sys.columns AS c
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.v_Active_Players', N'V'),
    OBJECT_ID(N'dbo.v_MGE_SignupReview', N'V'),
    OBJECT_ID(N'dbo.vDaily_PlayerExport', N'V'),
    OBJECT_ID(N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V')
);
GO

-- Exact prior definition: sql_schema/dbo.v_Active_Players.View.sql at 62cb739.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF @@TRANCOUNT = 0
BEGIN
    THROW 52063, 'Phase 4 rollback stopped because its guarded transaction is no longer active.', 1;
END;

EXEC sys.sp_executesql N'
CREATE OR ALTER VIEW dbo.v_Active_Players
AS
SELECT
    KS4.PowerRank,
    KS4.GovernorName,
    CAST(KS4.GovernorID AS bigint) AS GovernorID,
    KS4.Alliance,
    KS4.Power,
    KS4.KillPoints,
    KS4.Deads,
    KS4.T1_Kills,
    KS4.T2_Kills,
    KS4.T3_Kills,
    KS4.T4_Kills,
    KS4.T5_Kills,
    KS4.[T4&T5_KILLS],
    KS4.TOTAL_KILLS,
    KS4.RSS_Gathered,
    KS4.RSSAssistance,
    KS4.Helps,
    KS4.ScanDate,
    KS4.[Troops Power],
    KS4.[City Hall],
    KS4.[Tech Power],
    KS4.[Building Power],
    KS4.[Commander Power],
    CONCAT(PL.X, '' : '', PL.Y) AS LOCATION
FROM dbo.KingdomScanData4 AS KS4
LEFT JOIN dbo.PlayerLocation AS PL
  ON PL.GovernorID = KS4.GovernorID
WHERE KS4.SCANORDER =
(
    SELECT MAX(SCANORDER)
    FROM dbo.KingdomScanData4
);';
GO

-- Exact prior definition: sql_schema/dbo.v_MGE_SignupReview.View.sql at 62cb739.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF @@TRANCOUNT = 0
BEGIN
    THROW 52063, 'Phase 4 rollback stopped because its guarded transaction is no longer active.', 1;
END;

EXEC sys.sp_executesql N'
CREATE OR ALTER VIEW dbo.v_MGE_SignupReview
AS
WITH latest_scan AS
(
    SELECT k.*
    FROM dbo.KingdomScanData4 AS k
    WHERE k.SCANORDER = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)
),
excel_ranked AS
(
    SELECT
        e.*,
        ROW_NUMBER() OVER (PARTITION BY e.Gov_ID ORDER BY e.KVK_NO DESC) AS rn
    FROM dbo.EXCEL_FOR_DASHBOARD AS e
),
kvk_latest AS
(
    SELECT Gov_ID, KVK_RANK, [T4&T5_Kills], [% of Kill Target]
    FROM excel_ranked
    WHERE rn = 1
),
kvk_prev AS
(
    SELECT Gov_ID, KVK_RANK, [T4&T5_Kills], [% of Kill Target]
    FROM excel_ranked
    WHERE rn = 2
),
award_counts AS
(
    SELECT
        s.SignupId,
        SUM(CASE WHEN a.AwardId IS NOT NULL THEN 1 ELSE 0 END) AS PriorAwardsOverallCount,
        SUM(
            CASE
                WHEN a.AwardId IS NOT NULL
                 AND a.RequestedCommanderId = s.RequestedCommanderId
                THEN 1 ELSE 0
            END
        ) AS PriorAwardsRequestedCommanderCount,
        SUM(
            CASE
                WHEN a.AwardId IS NOT NULL
                 AND a.CreatedUtc >= DATEADD(YEAR, -2, SYSUTCDATETIME())
                THEN 1 ELSE 0
            END
        ) AS PriorAwardsOverallLast2YearsCount
    FROM dbo.MGE_Signups AS s
    LEFT JOIN dbo.MGE_Awards AS a
      ON a.GovernorId = s.GovernorId
     AND a.EventId <> s.EventId
    GROUP BY s.SignupId
)
SELECT
    s.EventId,
    s.SignupId,
    s.GovernorId,
    s.GovernorNameSnapshot,
    s.RequestedCommanderId,
    s.RequestedCommanderName,
    s.RequestPriority,
    s.PreferredRankBand,
    s.CurrentHeads,
    s.KingdomRole,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearText, ''''))), '''') IS NOT NULL THEN 1 ELSE 0 END AS bit) AS HasGearText,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentText, ''''))), '''') IS NOT NULL THEN 1 ELSE 0 END AS bit) AS HasArmamentText,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearText, ''''))), '''') IS NOT NULL
              OR NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentText, ''''))), '''') IS NOT NULL
            THEN 1 ELSE 0
        END AS bit
    ) AS HasGearOrArmamentText,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearAttachmentUrl, ''''))), '''') IS NOT NULL THEN 1 ELSE 0 END AS bit) AS HasGearAttachment,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentAttachmentUrl, ''''))), '''') IS NOT NULL THEN 1 ELSE 0 END AS bit) AS HasArmamentAttachment,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearAttachmentUrl, ''''))), '''') IS NOT NULL
              OR NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentAttachmentUrl, ''''))), '''') IS NOT NULL
            THEN 1 ELSE 0
        END AS bit
    ) AS HasAnyAttachment,
    s.CreatedUtc AS SignupCreatedUtc,
    s.Source,
    ls.Power AS LatestPower,
    kvk_latest.KVK_RANK AS LatestKVKRank,
    kvk_prev.KVK_RANK AS LastKVKRank,
    kvk_latest.[T4&T5_Kills] AS LatestT4T5Kills,
    kvk_prev.[T4&T5_Kills] AS LastT4T5Kills,
    kvk_latest.[% of Kill Target] AS LatestPercentOfKillTarget,
    kvk_prev.[% of Kill Target] AS LastPercentOfKillTarget,
    ISNULL(ac.PriorAwardsRequestedCommanderCount, 0) AS PriorAwardsRequestedCommanderCount,
    ISNULL(ac.PriorAwardsOverallCount, 0) AS PriorAwardsOverallCount,
    ISNULL(ac.PriorAwardsOverallLast2YearsCount, 0) AS PriorAwardsOverallLast2YearsCount,
    CAST(
        CASE
            WHEN ISNULL(kvk_latest.KVK_RANK, 0) = 0
             AND ISNULL(kvk_prev.KVK_RANK, 0) = 0
             AND ISNULL(kvk_latest.[T4&T5_Kills], 0) = 0
             AND ISNULL(kvk_prev.[T4&T5_Kills], 0) = 0
            THEN 1 ELSE 0
        END AS bit
    ) AS WarningMissingKVKData,
    CAST(CASE WHEN s.CurrentHeads < 0 OR s.CurrentHeads > 680 THEN 1 ELSE 0 END AS bit) AS WarningHeadsOutOfRange,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearAttachmentUrl, ''''))), '''') IS NULL
             AND NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentAttachmentUrl, ''''))), '''') IS NULL
            THEN 1 ELSE 0
        END AS bit
    ) AS WarningNoAttachments,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearText, ''''))), '''') IS NULL
             AND NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentText, ''''))), '''') IS NULL
            THEN 1 ELSE 0
        END AS bit
    ) AS WarningNoGearOrArmamentText
FROM dbo.MGE_Signups AS s
JOIN dbo.MGE_Events AS e
  ON e.EventId = s.EventId
LEFT JOIN latest_scan AS ls
  ON CAST(ls.GovernorID AS bigint) = s.GovernorId
LEFT JOIN kvk_latest
  ON kvk_latest.Gov_ID = s.GovernorId
LEFT JOIN kvk_prev
  ON kvk_prev.Gov_ID = s.GovernorId
LEFT JOIN award_counts AS ac
  ON ac.SignupId = s.SignupId
WHERE s.IsActive = 1;';
GO

-- Exact prior definition: sql_schema/dbo.vDaily_PlayerExport.View.sql at 62cb739.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF @@TRANCOUNT = 0
BEGIN
    THROW 52063, 'Phase 4 rollback stopped because its guarded transaction is no longer active.', 1;
END;

EXEC sys.sp_executesql N'
CREATE OR ALTER VIEW dbo.vDaily_PlayerExport
AS
WITH KSDay AS
(
    SELECT
        ks.GovernorID,
        ks.AsOfDate,
        MAX(LTRIM(RTRIM(ks.GovernorName))) AS GovernorName,
        MAX(LTRIM(RTRIM(ks.Alliance))) AS Alliance,
        MAX(TRY_CONVERT(bigint, ks.Power)) AS Power,
        MAX(TRY_CONVERT(bigint, ks.[Troops Power])) AS TroopPower,
        MAX(TRY_CONVERT(bigint, ks.KillPoints)) AS KillPoints,
        MAX(TRY_CONVERT(bigint, ks.Deads)) AS Deads,
        MAX(TRY_CONVERT(bigint, ks.RSS_Gathered)) AS RSS_Gathered,
        MAX(TRY_CONVERT(bigint, ks.RSSAssistance)) AS RSSAssist,
        MAX(TRY_CONVERT(bigint, ks.Helps)) AS Helps,
        MAX(TRY_CONVERT(bigint, ks.[Tech Power])) AS TechPower,
        MAX(TRY_CONVERT(int, ks.AOOJoined)) AS AOOJoined,
        MAX(TRY_CONVERT(int, ks.AOOWon)) AS AOOWon,
        MAX(TRY_CONVERT(bigint, ks.AOOAvgKill)) AS AOOAvgKill,
        MAX(TRY_CONVERT(bigint, ks.AOOAvgDead)) AS AOOAvgDead,
        MAX(TRY_CONVERT(bigint, ks.AOOAvgHeal)) AS AOOAvgHeal,
        MAX(TRY_CONVERT(bigint, ks.T4_Kills)) AS T4_Kills,
        MAX(TRY_CONVERT(bigint, ks.T5_Kills)) AS T5_Kills,
        MAX(TRY_CONVERT(bigint, ks.[T4&T5_KILLS])) AS T4T5_Kills,
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
        TRY_CONVERT(bigint, d.Power - LAG(d.Power) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS PowerDelta,
        TRY_CONVERT(bigint, d.TroopPower - LAG(d.TroopPower) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS TroopPowerDelta,
        TRY_CONVERT(bigint, d.KillPoints - LAG(d.KillPoints) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS KillPointsDelta,
        TRY_CONVERT(bigint, d.Deads - LAG(d.Deads) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS DeadsDelta,
        TRY_CONVERT(bigint, d.RSS_Gathered - LAG(d.RSS_Gathered) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS RSS_GatheredDelta,
        TRY_CONVERT(bigint, d.RSSAssist - LAG(d.RSSAssist) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS RSSAssistDelta,
        TRY_CONVERT(bigint, d.Helps - LAG(d.Helps) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS HelpsDelta,
        TRY_CONVERT(bigint, d.TechPower - LAG(d.TechPower) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS TechPowerDelta,
        TRY_CONVERT(int, d.AOOJoined - LAG(d.AOOJoined) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOJoinedDelta,
        TRY_CONVERT(int, d.AOOWon - LAG(d.AOOWon) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOWonDelta,
        TRY_CONVERT(bigint, d.AOOAvgKill - LAG(d.AOOAvgKill) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOAvgKillDelta,
        TRY_CONVERT(bigint, d.AOOAvgDead - LAG(d.AOOAvgDead) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOAvgDeadDelta,
        TRY_CONVERT(bigint, d.AOOAvgHeal - LAG(d.AOOAvgHeal) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS AOOAvgHealDelta,
        TRY_CONVERT(bigint, d.T4_Kills - LAG(d.T4_Kills) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS T4_KillsDelta,
        TRY_CONVERT(bigint, d.T5_Kills - LAG(d.T5_Kills) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS T5_KillsDelta,
        TRY_CONVERT(bigint, d.T4T5_Kills - LAG(d.T4T5_Kills) OVER (PARTITION BY d.GovernorID ORDER BY d.AsOfDate)) AS T4T5_KillsDelta,
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
 AND FD.AsOfDate = x.AsOfDate;';
GO

-- Exact prior definition: sql_schema/dbo.vw_Governor_KVK_Summary_GlobalLatest.View.sql at 62cb739.
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF @@TRANCOUNT = 0
BEGIN
    THROW 52063, 'Phase 4 rollback stopped because its guarded transaction is no longer active.', 1;
END;

EXEC sys.sp_executesql N'
CREATE OR ALTER VIEW dbo.vw_Governor_KVK_Summary_GlobalLatest
AS
WITH latest_scan AS
(
    SELECT k.*
    FROM dbo.KingdomScanData4 AS k
    WHERE k.SCANORDER = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)
),
excel_ranked AS
(
    SELECT
        e.*,
        ROW_NUMBER() OVER (PARTITION BY e.Gov_ID ORDER BY e.KVK_NO DESC) AS rn
    FROM dbo.EXCEL_FOR_DASHBOARD AS e
),
kvk_latest AS
(
    SELECT Gov_ID, KVK_RANK, [T4&T5_Kills], [% of Kill Target]
    FROM excel_ranked
    WHERE rn = 1
),
kvk_prev AS
(
    SELECT Gov_ID, KVK_RANK, [T4&T5_Kills], [% of Kill Target]
    FROM excel_ranked
    WHERE rn = 2
)
SELECT
    CAST(ls.GovernorID AS bigint) AS GovernorId,
    ls.GovernorName,
    ls.Power,
    kvk_latest.KVK_RANK AS Latest_KVK_RANK,
    kvk_prev.KVK_RANK AS Last_KVK_RANK,
    kvk_latest.[T4&T5_Kills] AS Latest_T4T5_Kills,
    kvk_prev.[T4&T5_Kills] AS Last_T4T5_Kills,
    kvk_latest.[% of Kill Target] AS Latest_Percent_of_Kill_Target,
    kvk_prev.[% of Kill Target] AS Last_Percent_of_Kill_Target
FROM latest_scan AS ls
LEFT JOIN kvk_latest
  ON kvk_latest.Gov_ID = CAST(ls.GovernorID AS bigint)
LEFT JOIN kvk_prev
  ON kvk_prev.Gov_ID = CAST(ls.GovernorID AS bigint);';
GO

IF @@TRANCOUNT = 0
BEGIN
    THROW 52063, 'Phase 4 rollback stopped because its guarded transaction is no longer active.', 1;
END;

EXEC sys.sp_refreshview N'dbo.v_Active_Players';
EXEC sys.sp_refreshview N'dbo.v_GovernorNames';
EXEC sys.sp_refreshview N'dbo.v_GovernorNames_Strict';
EXEC sys.sp_refreshview N'dbo.v_KVK_Under50_Last3_WithLatest';
EXEC sys.sp_refreshview N'dbo.v_MGE_SignupReview';
EXEC sys.sp_refreshview N'dbo.v_PlayerLatestStats';
EXEC sys.sp_refreshview N'dbo.v_PlayerProfile';
EXEC sys.sp_refreshview N'dbo.v_PlayerAccounts_Migrate';
EXEC sys.sp_refreshview N'dbo.vDaily_Helps';
EXEC sys.sp_refreshview N'dbo.vDaily_PlayerExport';
EXEC sys.sp_refreshview N'dbo.vDaily_RSSAssisted';
EXEC sys.sp_refreshview N'dbo.vDaily_RSSGathered';
EXEC sys.sp_refreshview N'dbo.vWTD_Helps';
EXEC sys.sp_refreshview N'dbo.vWTD_RSSAssisted';
EXEC sys.sp_refreshview N'dbo.vWTD_RSSGathered';
EXEC sys.sp_refreshview N'dbo.vw_Governor_KVK_Summary_GlobalLatest';
EXEC sys.sp_refreshview N'dbo.vAllianceActivity_DailyDelta';
EXEC sys.sp_refreshview N'dbo.vAllianceActivity_WeeklyDelta';
EXEC sys.sp_refreshsqlmodule N'dbo.fn_StatsWindowDeltas';
EXEC sys.sp_refreshsqlmodule N'dbo.fn_StatsWindowDeltas_GovCsv';
EXEC sys.sp_refreshsqlmodule N'dbo.usp_GetPlayerStatsWindows';

SELECT *
INTO #Phase4RollbackAfterActivePlayers
FROM dbo.v_Active_Players;

SELECT *
INTO #Phase4RollbackAfterMgeSignupReview
FROM dbo.v_MGE_SignupReview;

SELECT *
INTO #Phase4RollbackAfterDailyPlayerExport
FROM dbo.vDaily_PlayerExport;

SELECT *
INTO #Phase4RollbackAfterGlobalLatest
FROM dbo.vw_Governor_KVK_Summary_GlobalLatest;

IF (SELECT COUNT_BIG(*) FROM #Phase4RollbackBeforeActivePlayers)
     <> (SELECT COUNT_BIG(*) FROM #Phase4RollbackAfterActivePlayers)
   OR EXISTS
      (
          SELECT * FROM #Phase4RollbackBeforeActivePlayers
          EXCEPT
          SELECT * FROM #Phase4RollbackAfterActivePlayers
      )
   OR EXISTS
      (
          SELECT * FROM #Phase4RollbackAfterActivePlayers
          EXCEPT
          SELECT * FROM #Phase4RollbackBeforeActivePlayers
      )
    THROW 52053, 'Phase 4 rollback changed the v_Active_Players value contract.', 1;

IF (SELECT COUNT_BIG(*) FROM #Phase4RollbackBeforeMgeSignupReview)
     <> (SELECT COUNT_BIG(*) FROM #Phase4RollbackAfterMgeSignupReview)
   OR EXISTS
      (
          SELECT * FROM #Phase4RollbackBeforeMgeSignupReview
          EXCEPT
          SELECT * FROM #Phase4RollbackAfterMgeSignupReview
      )
   OR EXISTS
      (
          SELECT * FROM #Phase4RollbackAfterMgeSignupReview
          EXCEPT
          SELECT * FROM #Phase4RollbackBeforeMgeSignupReview
      )
    THROW 52054, 'Phase 4 rollback changed the v_MGE_SignupReview value contract.', 1;

IF (SELECT COUNT_BIG(*) FROM #Phase4RollbackBeforeDailyPlayerExport)
     <> (SELECT COUNT_BIG(*) FROM #Phase4RollbackAfterDailyPlayerExport)
   OR EXISTS
      (
          SELECT * FROM #Phase4RollbackBeforeDailyPlayerExport
          EXCEPT
          SELECT * FROM #Phase4RollbackAfterDailyPlayerExport
      )
   OR EXISTS
      (
          SELECT * FROM #Phase4RollbackAfterDailyPlayerExport
          EXCEPT
          SELECT * FROM #Phase4RollbackBeforeDailyPlayerExport
      )
    THROW 52055, 'Phase 4 rollback changed the vDaily_PlayerExport value contract.', 1;

IF (SELECT COUNT_BIG(*) FROM #Phase4RollbackBeforeGlobalLatest)
     <> (SELECT COUNT_BIG(*) FROM #Phase4RollbackAfterGlobalLatest)
   OR EXISTS
      (
          SELECT * FROM #Phase4RollbackBeforeGlobalLatest
          EXCEPT
          SELECT * FROM #Phase4RollbackAfterGlobalLatest
      )
   OR EXISTS
      (
          SELECT * FROM #Phase4RollbackAfterGlobalLatest
          EXCEPT
          SELECT * FROM #Phase4RollbackBeforeGlobalLatest
      )
    THROW 52056, 'Phase 4 rollback changed the global-latest value contract.', 1;

DROP TABLE IF EXISTS #Phase4RollbackMetadataAfter;

SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName,
    OBJECT_NAME(c.object_id) AS ObjectName,
    c.column_id,
    c.name AS ColumnName,
    c.system_type_id,
    c.user_type_id,
    c.max_length,
    c.precision,
    c.scale,
    c.collation_name,
    c.is_nullable
INTO #Phase4RollbackMetadataAfter
FROM sys.columns AS c
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.v_Active_Players', N'V'),
    OBJECT_ID(N'dbo.v_MGE_SignupReview', N'V'),
    OBJECT_ID(N'dbo.vDaily_PlayerExport', N'V'),
    OBJECT_ID(N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V')
);

IF EXISTS
(
    SELECT * FROM #Phase4RollbackMetadataBefore
    EXCEPT
    SELECT * FROM #Phase4RollbackMetadataAfter
)
OR EXISTS
(
    SELECT * FROM #Phase4RollbackMetadataAfter
    EXCEPT
    SELECT * FROM #Phase4RollbackMetadataBefore
)
    THROW 52057, 'Phase 4 rollback changed view aliases, types, nullability, collation, or column order.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.sql_modules
    WHERE object_id = OBJECT_ID(N'dbo.v_Active_Players', N'V')
      AND definition LIKE N'%CAST(KS4.GovernorID AS bigint)%'
)
OR NOT EXISTS
(
    SELECT 1
    FROM sys.sql_modules
    WHERE object_id = OBJECT_ID(N'dbo.v_MGE_SignupReview', N'V')
      AND definition LIKE N'%CAST(ls.GovernorID AS bigint)%'
)
OR NOT EXISTS
(
    SELECT 1
    FROM sys.sql_modules
    WHERE object_id = OBJECT_ID(N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V')
      AND definition LIKE N'%CAST(ls.GovernorID AS bigint)%'
)
    THROW 52058, 'Phase 4 rollback did not restore the frozen Phase 3 definitions.', 1;

COMMIT TRANSACTION;
GO

IF OBJECT_ID(N'tempdb..#Phase4RollbackBeforeActivePlayers') IS NULL
BEGIN
    THROW 52064, 'Phase 4 rollback did not reach its committed receipt boundary.', 1;
END;

SELECT
    N'phase4_view_type_alignment_rollback' AS EvidenceSection,
    (SELECT COUNT_BIG(*) FROM #Phase4RollbackBeforeActivePlayers) AS ActivePlayerRows,
    (SELECT COUNT_BIG(*) FROM #Phase4RollbackBeforeMgeSignupReview) AS MgeSignupReviewRows,
    (SELECT COUNT_BIG(*) FROM #Phase4RollbackBeforeDailyPlayerExport) AS DailyPlayerExportRows,
    (SELECT COUNT_BIG(*) FROM #Phase4RollbackBeforeGlobalLatest) AS GlobalLatestRows,
    N'PASS' AS RollbackStatus;
