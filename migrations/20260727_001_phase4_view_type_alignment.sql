/*
MigrationId: 20260727_001_phase4_view_type_alignment
Purpose: Remove obsolete KingdomScanData4 type compensation from four views while preserving every retained result contract
Author: cwatts
CreatedUtc: 2026-07-27
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Included
RollbackScript: migrations/rollback/20260727_001_phase4_view_type_alignment_rollback.sql
TransactionMode: Required
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0
PreValidationQuery: Run performance_remediation/kingdomscandata4/phase4/01_preflight.sql
PostValidationQuery: Run performance_remediation/kingdomscandata4/phase4/02_verify.sql
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety plan:
    - Deploy only after the Phase 2 and Phase 3 migrations pass their exact
      verification gates.
    - Run 20260727_000_retire_vAllianceActivity_WeeklyCumulative first.
    - Stop every bot/import/scheduler/admin writer before deployment.
    - Hold both the KS4 migration mutex and the Phase 3 import-pipeline mutex.
    - Refuse source-schema or prior-definition drift.
    - Materialize every changed view once before and once after alteration,
      then require exact row counts and bidirectional EXCEPT equivalence
      between those snapshots before commit.
    - Snapshot and compare exact result metadata before commit.
    - Refresh every mandatory and transitive SQL consumer in dependency order.
    - Keep all definition and validation work in one transaction across batches.
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
    THROW 52000, 'Phase 4 migration could not acquire the KingdomScanData4 migration mutex within 60000 ms.', 1;

DECLARE @ImportLockResult int;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
    @LockTimeout = 60000,
    @LockResult = @ImportLockResult OUTPUT;

IF @ImportLockResult < 0
    THROW 52001, 'Phase 4 migration could not acquire the Phase 3 import-pipeline mutex within 60000 ms.', 1;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
    THROW 52002, 'Phase 4 requires the verified Phase 3 import and rollback contracts.', 1;

IF OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative') IS NOT NULL
    THROW 52013, 'Phase 4 requires the approved obsolete-view retirement migration first.', 1;

IF EXISTS
(
    SELECT expected.ColumnName
    FROM
    (
        VALUES
            (N'GovernorID', TYPE_ID(N'bigint')),
            (N'PowerRank', TYPE_ID(N'int')),
            (N'Power', TYPE_ID(N'bigint')),
            (N'KillPoints', TYPE_ID(N'bigint')),
            (N'Deads', TYPE_ID(N'bigint')),
            (N'T4_Kills', TYPE_ID(N'bigint')),
            (N'T5_Kills', TYPE_ID(N'bigint')),
            (N'T4&T5_KILLS', TYPE_ID(N'bigint')),
            (N'RSS_Gathered', TYPE_ID(N'bigint')),
            (N'RSSAssistance', TYPE_ID(N'bigint')),
            (N'Helps', TYPE_ID(N'bigint')),
            (N'SCANORDER', TYPE_ID(N'int'))
    ) AS expected(ColumnName, TypeId)
    LEFT JOIN sys.columns AS actual
      ON actual.object_id = OBJECT_ID(N'dbo.KingdomScanData4')
     AND actual.name = expected.ColumnName
     AND actual.system_type_id = expected.TypeId
     AND actual.user_type_id = expected.TypeId
    WHERE actual.column_id IS NULL
)
    THROW 52003, 'Phase 4 requires the verified Phase 2/3 KingdomScanData4 integer contracts.', 1;

IF EXISTS
(
    SELECT expected.ObjectName
    FROM
    (
        VALUES
            (N'dbo.v_Active_Players'),
            (N'dbo.v_GovernorNames'),
            (N'dbo.v_KVK_Under50_Last3_WithLatest'),
            (N'dbo.v_MGE_SignupReview'),
            (N'dbo.v_PlayerLatestStats'),
            (N'dbo.vDaily_Helps'),
            (N'dbo.vDaily_PlayerExport'),
            (N'dbo.vDaily_RSSAssisted'),
            (N'dbo.vDaily_RSSGathered'),
            (N'dbo.vWTD_Helps'),
            (N'dbo.vWTD_RSSAssisted'),
            (N'dbo.vWTD_RSSGathered'),
            (N'dbo.vw_Governor_KVK_Summary_GlobalLatest')
    ) AS expected(ObjectName)
    WHERE OBJECT_ID(expected.ObjectName, N'V') IS NULL
)
    THROW 52004, 'Phase 4 found a missing mandatory view.', 1;

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
    THROW 52012, 'Phase 4 found a signed module; preserve or re-apply its signature explicitly before refresh.', 1;

DECLARE @ExpectedDefinitions TABLE
(
    ObjectName sysname NOT NULL PRIMARY KEY,
    OriginalDefinitionSha256 char(64) NOT NULL,
    RehearsedRollbackSha256 char(64) NOT NULL
);

INSERT @ExpectedDefinitions
(
    ObjectName,
    OriginalDefinitionSha256,
    RehearsedRollbackSha256
)
VALUES
    (
        N'dbo.v_Active_Players',
        N'41F2E83E2EC702CA226347C6ED29DC2CB3EB9298681BD3F26AE51CD0CAF89A24',
        N'A6AB97DCA84D77938BB704C16EF2068D4068F984BBE16387F86AD0EC83A277D9'
    ),
    (
        N'dbo.v_MGE_SignupReview',
        N'61EE372A5C89F0BC283470AF1D580C4376073BD4D97D79DC2F21E0908414E8B2',
        N'904735C5FC29F71B11FB6D1CA25D2E31CA555DD0549CB9249897F67A44715F5C'
    ),
    (
        N'dbo.vDaily_PlayerExport',
        N'DC7421B4AD6AAD56182737696561814C58B9AD16ED72145DD4AB6B47606FD3E1',
        N'216FBC7C284ACB2BE8BDC8CDE402BA79193C787B010BF99EB05C37AAF88C198B'
    ),
    (
        N'dbo.vw_Governor_KVK_Summary_GlobalLatest',
        N'2D3C0D412623FB783482C53AEA94639AFD6910CD515662F98CCABFC6203644D7',
        N'6E1D7145D479A9E32B9D175A3FCC4C45CF37986C4ACD1F6B76148FC0530F2BCF'
    );

IF EXISTS
(
    SELECT expected.ObjectName
    FROM @ExpectedDefinitions AS expected
    LEFT JOIN sys.sql_modules AS actual
      ON actual.object_id = OBJECT_ID(expected.ObjectName, N'V')
     AND CONVERT(
             char(64),
             HASHBYTES('SHA2_256', CONVERT(varbinary(max), actual.definition)),
             2
         ) IN
         (
             expected.OriginalDefinitionSha256,
             expected.RehearsedRollbackSha256
         )
    WHERE actual.object_id IS NULL
)
    THROW 52005, 'Phase 4 refused unexpected prior view-definition drift.', 1;

DROP TABLE IF EXISTS #Phase4BeforeActivePlayers;
DROP TABLE IF EXISTS #Phase4BeforeMgeSignupReview;
DROP TABLE IF EXISTS #Phase4BeforeDailyPlayerExport;
DROP TABLE IF EXISTS #Phase4BeforeGlobalLatest;
DROP TABLE IF EXISTS #Phase4AfterActivePlayers;
DROP TABLE IF EXISTS #Phase4AfterMgeSignupReview;
DROP TABLE IF EXISTS #Phase4AfterDailyPlayerExport;
DROP TABLE IF EXISTS #Phase4AfterGlobalLatest;

SELECT *
INTO #Phase4BeforeActivePlayers
FROM dbo.v_Active_Players;

SELECT *
INTO #Phase4BeforeMgeSignupReview
FROM dbo.v_MGE_SignupReview;

SELECT *
INTO #Phase4BeforeDailyPlayerExport
FROM dbo.vDaily_PlayerExport;

SELECT *
INTO #Phase4BeforeGlobalLatest
FROM dbo.vw_Governor_KVK_Summary_GlobalLatest;

DROP TABLE IF EXISTS #Phase4MetadataBefore;

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
INTO #Phase4MetadataBefore
FROM sys.columns AS c
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.v_Active_Players', N'V'),
    OBJECT_ID(N'dbo.v_MGE_SignupReview', N'V'),
    OBJECT_ID(N'dbo.vDaily_PlayerExport', N'V'),
    OBJECT_ID(N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V')
);
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF @@TRANCOUNT = 0
BEGIN
    THROW 52014, 'Phase 4 stopped because its guarded transaction is no longer active.', 1;
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

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF @@TRANCOUNT = 0
BEGIN
    THROW 52014, 'Phase 4 stopped because its guarded transaction is no longer active.', 1;
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
  ON ls.GovernorID = s.GovernorId
LEFT JOIN kvk_latest
  ON kvk_latest.Gov_ID = s.GovernorId
LEFT JOIN kvk_prev
  ON kvk_prev.Gov_ID = s.GovernorId
LEFT JOIN award_counts AS ac
  ON ac.SignupId = s.SignupId
WHERE s.IsActive = 1;';
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF @@TRANCOUNT = 0
BEGIN
    THROW 52014, 'Phase 4 stopped because its guarded transaction is no longer active.', 1;
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
 AND FD.AsOfDate = x.AsOfDate;';
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF @@TRANCOUNT = 0
BEGIN
    THROW 52014, 'Phase 4 stopped because its guarded transaction is no longer active.', 1;
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
  ON kvk_latest.Gov_ID = ls.GovernorID
LEFT JOIN kvk_prev
  ON kvk_prev.Gov_ID = ls.GovernorID;';
GO

IF @@TRANCOUNT = 0
BEGIN
    THROW 52014, 'Phase 4 stopped because its guarded transaction is no longer active.', 1;
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
INTO #Phase4AfterActivePlayers
FROM dbo.v_Active_Players;

SELECT *
INTO #Phase4AfterMgeSignupReview
FROM dbo.v_MGE_SignupReview;

SELECT *
INTO #Phase4AfterDailyPlayerExport
FROM dbo.vDaily_PlayerExport;

SELECT *
INTO #Phase4AfterGlobalLatest
FROM dbo.vw_Governor_KVK_Summary_GlobalLatest;

IF (SELECT COUNT_BIG(*) FROM #Phase4BeforeActivePlayers)
     <> (SELECT COUNT_BIG(*) FROM #Phase4AfterActivePlayers)
   OR EXISTS
      (
          SELECT * FROM #Phase4BeforeActivePlayers
          EXCEPT
          SELECT * FROM #Phase4AfterActivePlayers
      )
   OR EXISTS
      (
          SELECT * FROM #Phase4AfterActivePlayers
          EXCEPT
          SELECT * FROM #Phase4BeforeActivePlayers
      )
    THROW 52006, 'Phase 4 changed the v_Active_Players value contract.', 1;

IF (SELECT COUNT_BIG(*) FROM #Phase4BeforeMgeSignupReview)
     <> (SELECT COUNT_BIG(*) FROM #Phase4AfterMgeSignupReview)
   OR EXISTS
      (
          SELECT * FROM #Phase4BeforeMgeSignupReview
          EXCEPT
          SELECT * FROM #Phase4AfterMgeSignupReview
      )
   OR EXISTS
      (
          SELECT * FROM #Phase4AfterMgeSignupReview
          EXCEPT
          SELECT * FROM #Phase4BeforeMgeSignupReview
      )
    THROW 52007, 'Phase 4 changed the v_MGE_SignupReview value contract.', 1;

IF (SELECT COUNT_BIG(*) FROM #Phase4BeforeDailyPlayerExport)
     <> (SELECT COUNT_BIG(*) FROM #Phase4AfterDailyPlayerExport)
   OR EXISTS
      (
          SELECT * FROM #Phase4BeforeDailyPlayerExport
          EXCEPT
          SELECT * FROM #Phase4AfterDailyPlayerExport
      )
   OR EXISTS
      (
          SELECT * FROM #Phase4AfterDailyPlayerExport
          EXCEPT
          SELECT * FROM #Phase4BeforeDailyPlayerExport
      )
    THROW 52008, 'Phase 4 changed the vDaily_PlayerExport value contract.', 1;

IF (SELECT COUNT_BIG(*) FROM #Phase4BeforeGlobalLatest)
     <> (SELECT COUNT_BIG(*) FROM #Phase4AfterGlobalLatest)
   OR EXISTS
      (
          SELECT * FROM #Phase4BeforeGlobalLatest
          EXCEPT
          SELECT * FROM #Phase4AfterGlobalLatest
      )
   OR EXISTS
      (
          SELECT * FROM #Phase4AfterGlobalLatest
          EXCEPT
          SELECT * FROM #Phase4BeforeGlobalLatest
      )
    THROW 52009, 'Phase 4 changed the global-latest value contract.', 1;

DROP TABLE IF EXISTS #Phase4MetadataAfter;

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
INTO #Phase4MetadataAfter
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
    SELECT * FROM #Phase4MetadataBefore
    EXCEPT
    SELECT * FROM #Phase4MetadataAfter
)
OR EXISTS
(
    SELECT * FROM #Phase4MetadataAfter
    EXCEPT
    SELECT * FROM #Phase4MetadataBefore
)
    THROW 52010, 'Phase 4 changed view aliases, types, nullability, collation, or column order.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.sql_modules
    WHERE object_id = OBJECT_ID(N'dbo.v_MGE_SignupReview', N'V')
      AND definition LIKE N'%CAST(ls.GovernorID AS BIGINT)%'
)
OR EXISTS
(
    SELECT 1
    FROM sys.sql_modules
    WHERE object_id = OBJECT_ID(N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V')
      AND
      (
          definition LIKE N'%kvk_latest.Gov_ID = CAST(ls.GovernorID AS bigint)%'
          OR definition LIKE N'%kvk_prev.Gov_ID = CAST(ls.GovernorID AS bigint)%'
      )
)
    THROW 52011, 'Phase 4 retained an obsolete GovernorID join conversion.', 1;

COMMIT TRANSACTION;
GO

IF OBJECT_ID(N'tempdb..#Phase4BeforeActivePlayers') IS NULL
BEGIN
    THROW 52015, 'Phase 4 did not reach its committed receipt boundary.', 1;
END;

SELECT
    N'phase4_view_type_alignment' AS EvidenceSection,
    (SELECT COUNT_BIG(*) FROM #Phase4BeforeActivePlayers) AS ActivePlayerRows,
    (SELECT COUNT_BIG(*) FROM #Phase4BeforeMgeSignupReview) AS MgeSignupReviewRows,
    (SELECT COUNT_BIG(*) FROM #Phase4BeforeDailyPlayerExport) AS DailyPlayerExportRows,
    (SELECT COUNT_BIG(*) FROM #Phase4BeforeGlobalLatest) AS GlobalLatestRows,
    N'PASS' AS MigrationStatus;
