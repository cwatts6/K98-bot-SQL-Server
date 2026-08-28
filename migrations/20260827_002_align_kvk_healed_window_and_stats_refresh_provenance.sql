/*
MigrationId: 20260827_002_align_kvk_healed_window_and_stats_refresh_provenance
Purpose: Align healed-troop combat aggregation to PRE_PASS_4_SCAN and publish STATS_FOR_UPLOAD only from proven KVK output
Author: cwatts
CreatedUtc: 2026-08-28
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Included
RollbackScript: migrations/rollback/20260827_002_align_kvk_healed_window_and_stats_refresh_provenance_rollback.sql
TransactionMode: Required
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 during migration; current output repair is a separate operator step
PreValidationQuery: Confirm required source, header, target, scan and configuration objects exist
PostValidationQuery: Confirm both procedure definitions contain the healed-window and provenance-safe publication contracts
RelatedBotPR:
RelatedSQLPR:
*/
/*
Data safety and deployment plan:
    - This migration changes procedure definitions only and does not regenerate or
      publish KVK data.
    - Deploy SQL before the coordinated bot cache contract.
    - The current KVK output, STATS_FOR_UPLOAD and bot cache must be rebuilt through
      the supported operator sequence after deployment using live ProcConfig values.
    - SP_Stats_for_Upload fails before target mutation when provenance is stale or
      inconsistent, and replaces the target only inside its publication transaction.
    - Run deploy/Test-KvkHealedWindowAndStatsRefreshProvenance.ps1 before deployment
      and again against the deployed repository revision.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 60000;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
    THROW 52850, 'Migration preflight: dbo.KingdomScanData4 is missing.', 1;
IF OBJECT_ID(N'dbo.ProcConfig', N'U') IS NULL
    THROW 52851, 'Migration preflight: dbo.ProcConfig is missing.', 1;
IF OBJECT_ID(N'dbo.KVKFinalReportHeader', N'U') IS NULL
    THROW 52852, 'Migration preflight: dbo.KVKFinalReportHeader is missing.', 1;
IF OBJECT_ID(N'dbo.STATS_FOR_UPLOAD', N'U') IS NULL
    THROW 52853, 'Migration preflight: dbo.STATS_FOR_UPLOAD is missing.', 1;
IF OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK', N'P') IS NULL
    THROW 52854, 'Migration preflight: dbo.sp_ExcelOutput_ByKVK is missing.', 1;
IF OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P') IS NULL
    THROW 52855, 'Migration preflight: dbo.SP_Stats_for_Upload is missing.', 1;
IF OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
    THROW 52860, 'Migration preflight: dbo.ACQUIRE_KS4_IMPORT_LOCK is missing.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[sp_ExcelOutput_ByKVK]
	@KVK [int],
	@Scan [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE
        @CURRENTKVK3      INT,
        @KVK_END_SCAN     INT,
        @LASTKVKEND       INT,
        @PASS4END         INT,
        @PASS6END         INT,
        @PASS7END         INT,
        @PRE_PASS_4_SCAN  INT,
        @MaxAvailableScan INT,
        @LatestScanToUse  INT;

    -- Load KVK config
    SELECT
        @CURRENTKVK3     = CAST(MAX(CASE WHEN ConfigKey = ''CURRENTKVK3''     THEN ConfigValue END) AS INT),
        @KVK_END_SCAN    = CAST(MAX(CASE WHEN ConfigKey = ''KVK_END_SCAN''    THEN ConfigValue END) AS INT),
        @LASTKVKEND      = CAST(MAX(CASE WHEN ConfigKey = ''LASTKVKEND''      THEN ConfigValue END) AS INT),
        @PASS4END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS4END''        THEN ConfigValue END) AS INT),
        @PASS6END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS6END''        THEN ConfigValue END) AS INT),
        @PASS7END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS7END''        THEN ConfigValue END) AS INT),
        @PRE_PASS_4_SCAN = CAST(MAX(CASE WHEN ConfigKey = ''PRE_PASS_4_SCAN'' THEN ConfigValue END) AS INT)
    FROM dbo.ProcConfig
    WHERE KVKVersion = @KVK;

    IF @KVK_END_SCAN IS NULL OR @LASTKVKEND IS NULL OR @PRE_PASS_4_SCAN IS NULL
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Missing KVK window config for KVK=%d (one of KVK_END_SCAN/LASTKVKEND/PRE_PASS_4_SCAN is NULL).'', 16, 1, @KVK);
        RETURN;
    END

    -- Cap @Scan to available data (safety if caller passed a future scan)
    SELECT @MaxAvailableScan = MAX(ScanOrder) FROM dbo.KingdomScanData4;
    IF @MaxAvailableScan IS NULL
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: No scan data available.'', 16, 1);
        RETURN;
    END
    IF @Scan > @MaxAvailableScan SET @Scan = @MaxAvailableScan;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @Scan
    )
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Requested final ScanOrder=%d has no source rows.'', 16, 1, @Scan);
        RETURN;
    END

    -- Determine which scan to use for latest data
    -- For completed KVKs use KVK_END_SCAN, for current KVK use MaxAvailableScan
    SET @LatestScanToUse = CASE
        WHEN @MaxAvailableScan > @KVK_END_SCAN THEN @KVK_END_SCAN
        ELSE @MaxAvailableScan
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @LatestScanToUse
    )
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Resolved final ScanOrder=%d has no source rows.'', 16, 1, @LatestScanToUse);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Fresh staging
        TRUNCATE TABLE dbo.STAGING_STATS;

    -----------------------------------------------
    -- Build/refresh ranked PreKvk & Honor tables (so we can join ranks quickly)
    -----------------------------------------------
    EXEC dbo.sp_Build_Prekvk_And_Honor_Rankings;

    -----------------------------------------------
     -- 1. Snapshot (materialize once for reuse) - REDUCED COLUMNS
    -----------------------------------------------
    CREATE TABLE #Snapshot (
        GovernorID        bigint           NOT NULL PRIMARY KEY CLUSTERED,
        GovernorName      nvarchar(255)  NULL,
        PowerRank         int           NULL,
        [Power]           bigint        NULL,
        [Civilization]    nvarchar(100)  NULL,
        [KvKPlayed]       int           NULL,
        [Deads]           bigint        NULL,
        [T4&T5_KILLS]     bigint        NULL,
        [HealedTroops]    bigint        NULL,
        [KillPoints]      bigint        NULL,
        [AutarchTimes]    bigint        NULL,
        MaxPreKvkPoints   bigint        NULL,
        PreKvkRank        int           NULL,
        MaxHonorPoints    bigint        NULL,
        HonorRank         int           NULL,
		RangedPoints     bigint  NULL
    );

    INSERT INTO #Snapshot (
          GovernorID
        , GovernorName
        , PowerRank
        , [Power]
        , [Civilization]
        , [KvKPlayed]
        , [Deads]
        , [T4&T5_KILLS]
        , [HealedTroops]
        , [KillPoints]
        , [AutarchTimes]
        , MaxPreKvkPoints
        , PreKvkRank
        , MaxHonorPoints
        , HonorRank
		, RangedPoints
    )
    SELECT
        ksd.GovernorID,
        ksd.GovernorName,
        ksd.PowerRank,
        ksd.[Power],
        ksd.[Civilization],
        ksd.[KvKPlayed],
		ksd.[Deads],
		ksd.[T4&T5_KILLS],
		ksd.[HealedTroops],
		ksd.[KillPoints],
		ksd.[AutarchTimes],
        pk.MaxPreKvkPoints    AS MaxPreKvkPoints,
        pk.PreKvk_Rank        AS PreKvkRank,
        hn.MaxHonorPoints     AS MaxHonorPoints,
        hn.Honor_Rank         AS HonorRank,
		ksd.[RangedPoints]
    FROM dbo.KingdomScanData4 ksd
    LEFT JOIN dbo.PreKvk_Scores_Ranked pk
      ON pk.GovernorID = ksd.GovernorID AND pk.KVK_NO = @CURRENTKVK3
    LEFT JOIN dbo.KVK_Honor_Ranked hn
      ON hn.GovernorID = ksd.GovernorID AND hn.KVK_NO = @CURRENTKVK3
    WHERE ksd.ScanOrder = @Scan;

    -----------------------------------------------
    -- 1b. LATEST data (for completed/current KVK stats)
    -----------------------------------------------
    CREATE TABLE #LATEST (
        GovernorID       bigint  NOT NULL PRIMARY KEY CLUSTERED,
        MostKvKKill      bigint  NULL,
        MostKvKDead      bigint  NULL,
        MostKvKHeal      bigint  NULL,
        Acclaim          bigint  NULL,
        HighestAcclaim   bigint  NULL,
        AOOJoined        bigint  NULL,
        AOOWon           int     NULL,
        AOOAvgKill       bigint  NULL,
        AOOAvgDead       bigint  NULL,
        AOOAvgHeal       bigint  NULL,
        Conduct          decimal(5,2) NULL
    );

    INSERT INTO #LATEST (
          GovernorID
        , MostKvKKill
        , MostKvKDead
        , MostKvKHeal
        , Acclaim
        , HighestAcclaim
        , AOOJoined
        , AOOWon
        , AOOAvgKill
        , AOOAvgDead
        , AOOAvgHeal
        , Conduct
    )
    SELECT
        ksd.GovernorID,
        ksd.MostKvKKill,
        ksd.MostKvKDead,
        ksd.MostKvKHeal,
        ksd.Acclaim,
        ksd.HighestAcclaim,
        ksd.AOOJoined,
        ksd.AOOWon,
        ksd.AOOAvgKill,
        ksd.AOOAvgDead,
        ksd.AOOAvgHeal,
        ksd.Conduct
    FROM dbo.KingdomScanData4 ksd
    WHERE ksd.ScanOrder = @LatestScanToUse;

	CREATE TABLE #GovernorList (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED
    );

    INSERT INTO #GovernorList (GovernorID)
    SELECT s.GovernorID
    FROM #Snapshot s
    WHERE s.GovernorID IS NOT NULL;

    -----------------------------------------------
    -- 2. Consolidated Deads Delta (filtered to snapshot)
    -----------------------------------------------
    CREATE TABLE #Deads (
        GovernorID        bigint  NOT NULL PRIMARY KEY CLUSTERED,
        DeadsDelta        bigint  NOT NULL,
        DeadsDeltaOutKVK  bigint  NOT NULL,
        P4DeadsDelta      bigint  NOT NULL,
        P6DeadsDelta      bigint  NOT NULL,
        P7DeadsDelta      bigint  NOT NULL,
        P8DeadsDelta      bigint  NOT NULL
    );

    INSERT INTO #Deads (GovernorID, DeadsDelta, DeadsDeltaOutKVK, P4DeadsDelta, P6DeadsDelta, P7DeadsDelta, P8DeadsDelta)
    SELECT
        d.GovernorID,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @LASTKVKEND      AND d.DeltaOrder <= @PRE_PASS_4_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @PASS4END THEN d.DeadsDelta ELSE 0 END) AS P4DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS4END        AND d.DeltaOrder <= @PASS6END THEN d.DeadsDelta ELSE 0 END) AS P6DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS6END        AND d.DeltaOrder <= @PASS7END THEN d.DeadsDelta ELSE 0 END) AS P7DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS7END        AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS P8DeadsDelta
    FROM dbo.DeadsDelta d
    INNER JOIN #GovernorList gl ON gl.GovernorID = d.GovernorID
    WHERE d.DeltaOrder > @LASTKVKEND AND d.DeltaOrder <= @KVK_END_SCAN
    GROUP BY d.GovernorID;

    -----------------------------------------------
    -- 3. Consolidated Kills Delta (T4&T5)
    -----------------------------------------------
    CREATE TABLE #Kills (
        GovernorID      bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T4T5KillsDelta  bigint  NOT NULL,
        KillsOutsideKVK bigint  NOT NULL,
        P4Kills         bigint  NOT NULL,
        P6Kills         bigint  NOT NULL,
        P7Kills         bigint  NOT NULL,
        P8Kills         bigint  NOT NULL
    );

    INSERT INTO #Kills (GovernorID, T4T5KillsDelta, KillsOutsideKVK, P4Kills, P6Kills, P7Kills, P8Kills)
    SELECT
        k.GovernorID,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
        SUM(CASE WHEN k.DeltaOrder > @LASTKVKEND      AND k.DeltaOrder <= @PRE_PASS_4_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @PASS4END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS4END        AND k.DeltaOrder <= @PASS6END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS6END        AND k.DeltaOrder <= @PASS7END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS7END        AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
    FROM dbo.T4T5KillDelta k
    INNER JOIN #GovernorList gl ON gl.GovernorID = k.GovernorID
    WHERE k.DeltaOrder > @LASTKVKEND AND k.DeltaOrder <= @KVK_END_SCAN
    GROUP BY k.GovernorID;

    -----------------------------------------------
    -- 4. T4 / T5 splits
    -----------------------------------------------
    CREATE TABLE #KillsT4 (
        GovernorID   bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T4KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT4 (GovernorID, T4KillsDelta)
    SELECT t4.GovernorID, SUM(COALESCE(t4.T4KILLSDelta, 0)) AS T4KillsDelta
    FROM dbo.T4KillDelta t4
    INNER JOIN #GovernorList gl ON gl.GovernorID = t4.GovernorID
    WHERE t4.DeltaOrder > @PRE_PASS_4_SCAN AND t4.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t4.GovernorID;

    CREATE TABLE #KillsT5 (
        GovernorID   bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T5KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT5 (GovernorID, T5KillsDelta)
    SELECT t5.GovernorID, SUM(COALESCE(t5.T5KILLSDelta, 0)) AS T5KillsDelta
    FROM dbo.T5KillDelta t5
    INNER JOIN #GovernorList gl ON gl.GovernorID = t5.GovernorID
    WHERE t5.DeltaOrder > @PRE_PASS_4_SCAN AND t5.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t5.GovernorID;

	-----------------------------------------------
	-- 5. KillPointsDelta aggregation (use same window as other deltas)
	-----------------------------------------------
    CREATE TABLE #KillPoints (
        GovernorID      bigint  NOT NULL PRIMARY KEY CLUSTERED,
        KillPointsDelta bigint  NOT NULL
    );

	INSERT INTO #KillPoints (GovernorID, KillPointsDelta)
	SELECT kp.GovernorID, SUM(COALESCE(kp.KillPointsDelta, 0)) AS KillPointsDelta
	FROM dbo.KillPointsDelta kp
    INNER JOIN #GovernorList gl ON gl.GovernorID = kp.GovernorID
	WHERE kp.DeltaOrder > @PRE_PASS_4_SCAN AND kp.DeltaOrder <= @KVK_END_SCAN
	GROUP BY kp.GovernorID;

    -----------------------------------------------
    -- 6. Other deltas (use @Scan as lower bound)
    -----------------------------------------------
    CREATE TABLE #Helps (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED,
        HelpsDelta bigint NOT NULL
    );

    INSERT INTO #Helps (GovernorID, HelpsDelta)
    SELECT h.GovernorID, SUM(COALESCE(h.HelpsDelta, 0)) AS HelpsDelta
    FROM dbo.HelpsDelta h
    INNER JOIN #GovernorList gl ON gl.GovernorID = h.GovernorID
    WHERE h.DeltaOrder > @Scan AND h.DeltaOrder <= @KVK_END_SCAN
    GROUP BY h.GovernorID;

    CREATE TABLE #RSSAssist (
        GovernorID     bigint NOT NULL PRIMARY KEY CLUSTERED,
        RSSAssistDelta bigint NOT NULL
    );

    INSERT INTO #RSSAssist (GovernorID, RSSAssistDelta)
    SELECT ra.GovernorID, SUM(COALESCE(ra.RSSASSISTDelta, 0)) AS RSSAssistDelta
    FROM dbo.RSSASSISTDelta ra
    INNER JOIN #GovernorList gl ON gl.GovernorID = ra.GovernorID
    WHERE ra.DeltaOrder > @Scan AND ra.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ra.GovernorID;

    CREATE TABLE #RSSGathered (
        GovernorID       bigint NOT NULL PRIMARY KEY CLUSTERED,
        RSSGatheredDelta bigint NOT NULL
    );

    INSERT INTO #RSSGathered (GovernorID, RSSGatheredDelta)
    SELECT rg.GovernorID, SUM(COALESCE(rg.RSSGatheredDelta, 0)) AS RSSGatheredDelta
    FROM dbo.RSSGatheredDelta rg
    INNER JOIN #GovernorList gl ON gl.GovernorID = rg.GovernorID
    WHERE rg.DeltaOrder > @Scan AND rg.DeltaOrder <= @KVK_END_SCAN
    GROUP BY rg.GovernorID;

    CREATE TABLE #Power (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED,
        PowerDelta bigint NOT NULL
    );

    INSERT INTO #Power (GovernorID, PowerDelta)
    SELECT p.GovernorID, SUM(COALESCE(p.Power_Delta, 0)) AS PowerDelta
    FROM dbo.PowerDelta p
    INNER JOIN #GovernorList gl ON gl.GovernorID = p.GovernorID
    WHERE p.DeltaOrder > @Scan AND p.DeltaOrder <= @KVK_END_SCAN
    GROUP BY p.GovernorID;

    CREATE TABLE #Healed (
        GovernorID        bigint NOT NULL PRIMARY KEY CLUSTERED,
        HealedTroopsDelta bigint NOT NULL
    );

	INSERT INTO #Healed (GovernorID, HealedTroopsDelta)
    SELECT ht.GovernorID, SUM(COALESCE(ht.HealedTroopsDelta, 0)) AS HealedTroopsDelta
    FROM dbo.HealedTroopsDelta ht
    INNER JOIN #GovernorList gl ON gl.GovernorID = ht.GovernorID
    WHERE ht.DeltaOrder > @PRE_PASS_4_SCAN AND ht.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ht.GovernorID;

    CREATE TABLE #Ranged (
        GovernorID        bigint NOT NULL PRIMARY KEY CLUSTERED,
        RangedPointsDelta bigint NOT NULL
    );

	INSERT INTO #Ranged (GovernorID, RangedPointsDelta)
    SELECT r.GovernorID, SUM(COALESCE(r.RangedPointsDelta, 0)) AS RangedPointsDelta
    FROM dbo.RangedPointsDelta r
    INNER JOIN #GovernorList gl ON gl.GovernorID = r.GovernorID
    WHERE r.DeltaOrder > @Scan AND r.DeltaOrder <= @KVK_END_SCAN
    GROUP BY r.GovernorID;

    -----------------------------------------------
    -- 7. Stage - NOW USING #LATEST FOR MOVED COLUMNS
    -----------------------------------------------
	INSERT INTO dbo.STAGING_STATS (
		  GovernorID
		, PowerRank
		, [Power]
		, Power_Delta
		, GovernorName
		, T4KillsDelta
		, T5KillsDelta
		, [T4&T5_KILLSDelta]
		, [KILLS_OUTSIDE_KVK]
		, [P4T4&T5_KILLSDelta]
		, [P6T4&T5_KillsDelta]
		, [P7T4&T5_KillsDelta]
		, [P8T4&T5_KillsDelta]
		, DeadsDelta
		, [DEADS_OUTSIDE_KVK]
		, P4DeadsDelta
		, P6DeadsDelta
		, P7DeadsDelta
		, P8DeadsDelta
		, HelpsDelta
		, RSSASSISTDelta
		, RSSGatheredDelta
		, HealedTroops
		, RangedPoints
		, RangedPointsDelta
		, AutarchTimes
		, Civilization
		, KvKPlayed
		, MostKvKKill
		, MostKvKDead
		, MostKvKHeal
		, Acclaim
		, HighestAcclaim
		, AOOJoined
		, AOOWon
		, AOOAvgKill
		, AOOAvgDead
		, AOOAvgHeal
		, Conduct
		, KillPointsDelta
		, KillPoints
		, HealedTroopsDelta
		, [Starting_Deads]
		, [Starting_T4&T5_KILLS]
		, MaxPreKvkPoints
		, MaxHonorPoints
		, PreKvkRank
		, HonorRank
	)
	SELECT
		  s.GovernorID
		, s.PowerRank
		, s.[Power]
		, COALESCE(p.PowerDelta, 0)                 AS Power_Delta
		, s.GovernorName
		, COALESCE(kt4.T4KillsDelta, 0)             AS T4KillsDelta
		, COALESCE(kt5.T5KillsDelta, 0)             AS T5KillsDelta
		, COALESCE(k.T4T5KillsDelta, 0)             AS [T4&T5_KILLSDelta]
		, COALESCE(k.KillsOutsideKVK, 0)            AS [KILLS_OUTSIDE_KVK]
		, COALESCE(k.P4Kills, 0)                    AS [P4T4&T5_KILLSDelta]
		, COALESCE(k.P6Kills, 0)                    AS [P6T4&T5_KillsDelta]
		, COALESCE(k.P7Kills, 0)                    AS [P7T4&T5_KillsDelta]
		, COALESCE(k.P8Kills, 0)                    AS [P8T4&T5_KillsDelta]
		, COALESCE(d.DeadsDelta, 0)                 AS DeadsDelta
		, COALESCE(d.DeadsDeltaOutKVK, 0)           AS [DEADS_OUTSIDE_KVK]
		, COALESCE(d.P4DeadsDelta, 0)               AS P4DeadsDelta
		, COALESCE(d.P6DeadsDelta, 0)               AS P6DeadsDelta
		, COALESCE(d.P7DeadsDelta, 0)               AS P7DeadsDelta
		, COALESCE(d.P8DeadsDelta, 0)               AS P8DeadsDelta
		, COALESCE(h.HelpsDelta, 0)                 AS HelpsDelta
		, COALESCE(ra.RSSAssistDelta, 0)            AS RSSASSISTDelta
		, COALESCE(rg.RSSGatheredDelta, 0)          AS RSSGatheredDelta
		, COALESCE(s.HealedTroops, 0)               AS HealedTroops
		, COALESCE(s.RangedPoints, 0)             AS RangedPoints
		, COALESCE(ran.RangedPointsDelta, 0)        AS RangedPointsDelta
		, COALESCE(s.AutarchTimes, 0)               AS AutarchTimes
		, s.Civilization
		, COALESCE(s.KvKPlayed, 0)                  AS KvKPlayed
		, COALESCE(lst.MostKvKKill, 0)              AS MostKvKKill        -- FROM #LATEST
		, COALESCE(lst.MostKvKDead, 0)              AS MostKvKDead        -- FROM #LATEST
		, COALESCE(lst.MostKvKHeal, 0)              AS MostKvKHeal        -- FROM #LATEST
		, COALESCE(lst.Acclaim, 0)                  AS Acclaim            -- FROM #LATEST
		, COALESCE(lst.HighestAcclaim, 0)           AS HighestAcclaim     -- FROM #LATEST
		, COALESCE(lst.AOOJoined, 0)                AS AOOJoined          -- FROM #LATEST
		, COALESCE(lst.AOOWon, 0)                   AS AOOWon             -- FROM #LATEST
		, COALESCE(lst.AOOAvgKill, 0)               AS AOOAvgKill         -- FROM #LATEST
		, COALESCE(lst.AOOAvgDead, 0)               AS AOOAvgDead         -- FROM #LATEST
		, COALESCE(lst.AOOAvgHeal, 0)               AS AOOAvgHeal         -- FROM #LATEST
		, lst.Conduct                                AS Conduct            -- FROM #LATEST
		, COALESCE(kp.KillPointsDelta, 0)           AS KillPointsDelta
		, COALESCE(s.KillPoints, 0)                 AS KillPoints
		, COALESCE(he.HealedTroopsDelta, 0)         AS HealedTroopsDelta
		, COALESCE(s.Deads, 0)                      AS [Starting_Deads]
		, COALESCE(s.[T4&T5_KILLS], 0)              AS [Starting_T4&T5_KILLS]
		, COALESCE(s.MaxPreKvkPoints, 0)            AS MaxPreKvkPoints
		, COALESCE(s.MaxHonorPoints, 0)             AS MaxHonorPoints
		, COALESCE(s.PreKvkRank, 0)                 AS PreKvkRank
		, COALESCE(s.HonorRank, 0)                  AS HonorRank
	FROM #Snapshot s
	LEFT JOIN #LATEST      lst ON lst.GovernorID = s.GovernorID  -- NEW JOIN
	LEFT JOIN #Power       p   ON p.GovernorID   = s.GovernorID
	LEFT JOIN #KillsT4     kt4 ON kt4.GovernorID = s.GovernorID
	LEFT JOIN #KillsT5     kt5 ON kt5.GovernorID = s.GovernorID
	LEFT JOIN #Kills       k   ON k.GovernorID   = s.GovernorID
	LEFT JOIN #KillPoints  kp  ON kp.GovernorID  = s.GovernorID
	LEFT JOIN #Deads       d   ON d.GovernorID   = s.GovernorID
	LEFT JOIN #Helps       h   ON h.GovernorID   = s.GovernorID
	LEFT JOIN #RSSAssist   ra  ON ra.GovernorID  = s.GovernorID
	LEFT JOIN #RSSGathered rg  ON rg.GovernorID  = s.GovernorID
	LEFT JOIN #Healed      he  ON he.GovernorID  = s.GovernorID
	LEFT JOIN #Ranged      ran ON ran.GovernorID = s.GovernorID
	WHERE s.GovernorID IS NOT NULL;


    -- Cleanup temps from stage step
    DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot, #LATEST, #Healed, #Ranged, #KillPoints, #GovernorList;

    -----------------------------------------------
    -- 8. DKP + HoH (normalize DKP column name)
    -----------------------------------------------
    SELECT  S1.[GovernorID],
            CASE WHEN z.GovernorID = s1.GovernorID
                 THEN ROUND((S1.[T4&T5_KILLSDelta]*3 + (S1.[DeadsDelta] * 0.1) * 8), 0)
                 ELSE ROUND((S1.[T4&T5_KILLSDelta]*3 +  S1.[DeadsDelta]      * 8), 0)
            END AS [DKP_SCORE]
    INTO #DKP
    FROM dbo.STAGING_STATS AS S1
    LEFT JOIN dbo.ZEROED    AS Z ON Z.GovernorID = S1.GovernorID AND Z.ScanOrder = @Scan;

    SELECT GovernorID, MAX(T4_Deads) AS [T4 Deads], MAX(T5_Deads) AS [T5 Deads], MAX(KVK_START_SCANORDER) AS SCANORDER
    INTO #HD1
    FROM dbo.HoH_Deads
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 9. Dynamic final table (typed columns!)
    -----------------------------------------------
    DECLARE @ExcelTbl       sysname       = N''EXCEL_FOR_KVK_'' + CAST(@KVK AS nvarchar(10));
    DECLARE @TargetsTbl     sysname       = N''TARGETS_''       + CAST(@KVK AS nvarchar(10));
    DECLARE @ExcelTblFull   nvarchar(260) = QUOTENAME(''dbo'') + N''.'' + QUOTENAME(@ExcelTbl);
    DECLARE @TargetsTblFull nvarchar(260) = QUOTENAME(''dbo'') + N''.'' + QUOTENAME(@TargetsTbl);

    DECLARE @sql nvarchar(max) = N'''';

    SET @sql += N''DROP TABLE IF EXISTS '' + @ExcelTblFull + N'';'' + CHAR(10);

    SET @sql += N''
    SELECT TOP (5000)
        S.[PowerRank]                                                AS [Rank],
        CAST(ROW_NUMBER() OVER (ORDER BY D.[DKP_SCORE] DESC) AS int) AS [KVK_RANK],
        S.[GovernorID]                                               AS [Gov_ID],
        CAST(S.[GovernorName] AS nvarchar(255))                      AS [Governor_Name],

        CAST(S.[Power] AS bigint)                                    AS [Starting Power],
        CAST(S.Power_Delta AS bigint)                                AS [Power_Delta],

        CAST(S.[Civilization] AS nvarchar(100))                      AS [Civilization],
        CAST(S.[KvKPlayed] AS int)                                   AS [KvKPlayed],
        CAST(S.[MostKvKKill] AS bigint)                              AS [MostKvKKill],
        CAST(S.[MostKvKDead] AS bigint)                              AS [MostKvKDead],
        CAST(S.[MostKvKHeal] AS bigint)                              AS [MostKvKHeal],
        CAST(S.[Acclaim] AS bigint)                                  AS [Acclaim],
        CAST(S.[HighestAcclaim] AS bigint)                           AS [HighestAcclaim],
        CAST(S.[AOOJoined] AS bigint)                                AS [AOOJoined],
        CAST(S.[AOOWon] AS int)                                      AS [AOOWon],
        CAST(S.[AOOAvgKill] AS bigint)                               AS [AOOAvgKill],
        CAST(S.[AOOAvgDead] AS bigint)                               AS [AOOAvgDead],
        CAST(S.[AOOAvgHeal] AS bigint)                               AS [AOOAvgHeal],
        CAST(S.[Conduct] AS decimal(5,2))                             AS [Conduct],

        CAST(S.[Starting_T4&T5_KILLS] AS bigint)                     AS [Starting_T4&T5_KILLS],
        CAST(S.[T4KillsDelta] AS bigint)                             AS [T4_KILLS],
        CAST(S.[T5KillsDelta] AS bigint)                             AS [T5_KILLS],
        CAST(S.[T4&T5_KILLSDelta] AS bigint)                         AS [T4&T5_Kills],
        CAST(S.KILLS_OUTSIDE_KVK AS bigint)                          AS [KILLS_OUTSIDE_KVK],

        CAST(T.[Kill_Target] AS bigint)                                 AS [Kill Target],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE ROUND( (CAST(S.[T4&T5_KILLSDelta] AS decimal(19,2)) / CAST(T.[Kill_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Kill Target],

        CAST(S.[Starting_Deads] AS bigint)                           AS [Starting_Deads],
        CAST(S.[DeadsDelta] AS bigint)                               AS [Deads_Delta],
        CAST(S.DEADS_OUTSIDE_KVK AS bigint)                          AS [DEADS_OUTSIDE_KVK],

        CAST(COALESCE(HD.[T4 Deads], 0) AS bigint)                   AS [T4_Deads],
        CAST(COALESCE(HD.[T5 Deads], 0) AS bigint)                   AS [T5_Deads],

        CAST(T.[Dead_Target] AS bigint)                                 AS [Dead_Target],
        CAST(
            CASE
                WHEN T.[Dead_Target] = 0 THEN 0
                WHEN Z.GovernorID = S.GovernorID
                    THEN ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) * 0.1 / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
                ELSE ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Dead Target],

        CAST(Z.Zeroed AS bit)                                        AS [Zeroed],

        CAST(D.[DKP_SCORE] AS bigint)                                AS [DKP_SCORE],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE (CAST(T.Kill_Target AS bigint) * 3 + CAST(T.Dead_Target AS bigint) * 8)
            END
            AS bigint
        )                                                            AS [DKP Target],

        CAST(
            CASE
                WHEN (CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) = 0 THEN 0
                ELSE ROUND(
                    (CAST(D.[DKP_SCORE] AS decimal(19,2)) /
                     CAST((CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) AS decimal(19,2))) * 100,
                    2
                )
            END
            AS decimal(9,2)
        )                                                            AS [% of DKP Target],

        CAST(S.[HelpsDelta] AS bigint)                               AS [HelpsDelta],
        CAST(S.[RSSASSISTDelta] AS bigint)                           AS [RSS_Assist_Delta],
        CAST(S.[RSSGatheredDelta] AS bigint)                         AS [RSS_Gathered_Delta],

        CAST(S.[P4T4&T5_KillsDelta] AS bigint)                       AS [Pass 4 Kills],
        CAST(S.[P6T4&T5_KillsDelta] AS bigint)                       AS [Pass 6 Kills],
        CAST(S.[P7T4&T5_KillsDelta] AS bigint)                       AS [Pass 7 Kills],
        CAST(S.[P8T4&T5_KillsDelta] AS bigint)                       AS [Pass 8 Kills],

        CAST(S.P4DeadsDelta AS bigint)                               AS [Pass 4 Deads],
        CAST(S.P6DeadsDelta AS bigint)                               AS [Pass 6 Deads],
        CAST(S.P7DeadsDelta AS bigint)                               AS [Pass 7 Deads],
        CAST(S.P8DeadsDelta AS bigint)                               AS [Pass 8 Deads],

        CAST(S.[HealedTroops] AS bigint)                             AS [Starting_HealedTroops],
        CAST(S.[HealedTroopsDelta] AS bigint)                        AS [HealedTroopsDelta],

        CAST(S.[KillPoints] AS bigint)                               AS [Starting_KillPoints],
        CAST(S.[KillPointsDelta] AS bigint)                          AS [KillPointsDelta],

        CAST(S.[RangedPoints] AS bigint)                             AS [RangedPoints],
        CAST(S.[RangedPointsDelta] AS bigint)                        AS [RangedPointsDelta],

        CAST(S.[AutarchTimes] AS bigint)                             AS [AutarchTimes],

        CAST(S.[MaxPreKvkPoints] AS bigint)                          AS [Max_PreKvk_Points],
        CAST(S.[MaxHonorPoints] AS bigint)                           AS [Max_HonorPoints],
        CAST(S.[PreKvkRank] AS bigint)                               AS [PreKvk_Rank],
        CAST(S.[HonorRank] AS bigint)                                AS [Honor_Rank],

        CAST(@pKVK AS int)                                           AS [KVK_NO]
    INTO '' + @ExcelTblFull + N''
    FROM dbo.STAGING_STATS AS S
    LEFT JOIN #HD1  AS HD ON S.GovernorID = HD.GovernorID
    LEFT JOIN '' + @TargetsTblFull + N'' AS T ON T.GovernorID = S.GovernorID
    LEFT JOIN #DKP  AS D  ON D.GovernorID = S.GovernorID
    LEFT JOIN dbo.ZEROED AS Z ON Z.GovernorID = S.GovernorID AND Z.ScanOrder = @pScan
    ORDER BY S.PowerRank ASC;'';

	IF CHARINDEX(N''COALESCE(HD.[T4 Deads]'', @sql) = 0
	BEGIN
		RAISERROR(''HD reference missing from SQL string (string likely broken).'',16,1);
	END

    EXEC sp_executesql
        @sql,
        N''@pScan int, @pKVK int'',
        @pScan = @Scan,
        @pKVK  = @KVK;

	-- Call index creation procedure with BOTH parameters
	EXEC dbo.sp_Create_Excel_For_Kvk_Indexes @FullTableName = @ExcelTblFull, @TableBase = @ExcelTbl;

	-- ✅ NEW: Update statistics for optimal query performance
    DECLARE @UpdateStatsSQL NVARCHAR(MAX) = N''UPDATE STATISTICS '' + @ExcelTblFull + N'' WITH FULLSCAN;'';
    EXEC sp_executesql @UpdateStatsSQL;
    PRINT ''Updated statistics on '' + @ExcelTblFull + '' with FULLSCAN'';

    DROP TABLE IF EXISTS #DKP, #HD1;

    EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;
    EXEC dbo.usp_RecordKvkFinalReportCompletion
        @KVKNo = @KVK,
        @FinalScanOrder = @LatestScanToUse,
        @FinalizationBasis = N''LIVE_OUTPUT'';

	        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    PRINT ''Completed KVK '' + CAST(@KVK AS varchar(10))
        + '' with ScanOrder='' + CAST(@Scan AS varchar(20))
        + '', LatestScanUsed='' + CAST(@LatestScanToUse AS varchar(20))
        + '' at '' + CONVERT(varchar, GETDATE(), 120);
END';

    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[SP_Stats_for_Upload]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @LatestKVK bigint,
        @MaxScan int,
        @KvkEndScanValue float,
        @KvkEndScan int,
        @ExpectedFinalScan int,
        @ProvenFinalScan int,
        @HeaderRowCount int,
        @HeaderRevision int,
        @HeaderState nvarchar(24),
        @FinalizationBasis nvarchar(24),
        @FinalDataAtUtc datetime2(0),
        @CurrentHeaderScan int,
        @CurrentHeaderRowCount int,
        @CurrentHeaderRevision int,
        @CurrentHeaderState nvarchar(24),
        @SourceRowCount bigint = 0,
        @InvalidGovernorRows bigint = 0,
        @DuplicateGovernorGroups bigint = 0,
        @WrongKvkRows bigint = 0,
        @CandidateRowCount bigint = 0,
        @PublishedRowCount bigint = 0,
        @ProvenScanDate datetime2(0),
        @ProvenScanDateMax datetime2(0),
        @ScanDateRowCount bigint = 0,
        @TableName sysname,
        @TableObjectName nvarchar(260),
        @TableNameFull nvarchar(260),
        @sql nvarchar(max),
        @Diagnostic nvarchar(2048),
        @FailureStage nvarchar(64) = N''preflight'',
        @ImportLockResult int,
        @LockResult int,
        @InitialTranCount int = @@TRANCOUNT,
        @StartedTransaction bit = 0,
        @SavepointCreated bit = 0;

    BEGIN TRY
        IF @InitialTranCount = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTransaction = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION StatsForUploadPublishSave;
            SET @SavepointCreated = 1;
        END;

        SET @FailureStage = N''import-lock'';
        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 52820, ''SP_Stats_for_Upload: KS4 import lock could not be acquired.'', 1;

        SET @FailureStage = N''publication-lock'';
        EXEC @LockResult = sys.sp_getapplock
            @Resource = N''K98:StatsForUpload:Publish'',
            @LockMode = N''Exclusive'',
            @LockOwner = N''Transaction'',
            @LockTimeout = 60000,
            @DbPrincipal = N''public'';

        IF @LockResult < 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: publication lock failed for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', lock result='', @LockResult, ''.''
            );
            THROW 52803, @Diagnostic, 1;
        END;

        SET @FailureStage = N''eligibility-snapshot'';
        SELECT @MaxScan = MAX(SCANORDER)
        FROM dbo.KingdomScanData4 WITH (UPDLOCK, HOLDLOCK);

        IF @MaxScan IS NULL
            THROW 52800, ''SP_Stats_for_Upload: no scan data is available.'', 1;

        SELECT TOP (1) @LatestKVK = KVKVersion
        FROM dbo.ProcConfig WITH (UPDLOCK, HOLDLOCK)
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CONVERT(int, ConfigValue) IS NOT NULL
          AND ConfigValue = CONVERT(float, TRY_CONVERT(int, ConfigValue))
          AND TRY_CONVERT(int, ConfigValue) <= @MaxScan
        ORDER BY KVKVersion DESC;

        IF @LatestKVK IS NULL OR @LatestKVK <= 0 OR @LatestKVK > 2147483647
            THROW 52801, ''SP_Stats_for_Upload: no valid eligible KVK was found.'', 1;

        SELECT @KvkEndScanValue = ConfigValue
        FROM dbo.ProcConfig WITH (UPDLOCK, HOLDLOCK)
        WHERE KVKVersion = CONVERT(int, @LatestKVK)
          AND ConfigKey = ''KVK_END_SCAN'';

        SET @KvkEndScan = TRY_CONVERT(int, @KvkEndScanValue);

        IF @KvkEndScan IS NULL
           OR @KvkEndScan <= 0
           OR @KvkEndScanValue <> CONVERT(float, @KvkEndScan)
            THROW 52802, ''SP_Stats_for_Upload: KVK_END_SCAN is missing or is not a positive integral scan.'', 1;

        SET @ExpectedFinalScan = CASE
            WHEN @MaxScan > @KvkEndScan THEN @KvkEndScan
            ELSE @MaxScan
        END;

        SET @FailureStage = N''header-preflight'';
        SELECT
            @ProvenFinalScan = FinalScanOrder,
            @HeaderRowCount = OutputRowCount,
            @HeaderRevision = Revision,
            @HeaderState = State,
            @FinalizationBasis = FinalizationBasis,
            @FinalDataAtUtc = FinalDataAtUtc
        FROM dbo.KVKFinalReportHeader
        WHERE KVK_NO = CONVERT(int, @LatestKVK);

        IF @ProvenFinalScan IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: missing output header for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan, ''.''
            );
            THROW 52804, @Diagnostic, 1;
        END;

        IF @HeaderState <> N''OUTPUT_COMPLETE''
           OR @HeaderRevision IS NULL OR @HeaderRevision <= 0
           OR @HeaderRowCount IS NULL OR @HeaderRowCount <= 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: invalid output header for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', proven scan='', COALESCE(CONVERT(varchar(20), @ProvenFinalScan), ''NULL''),
                '', revision='', COALESCE(CONVERT(varchar(20), @HeaderRevision), ''NULL''), ''.''
            );
            THROW 52805, @Diagnostic, 1;
        END;

        IF @ProvenFinalScan <> @ExpectedFinalScan
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: stale output for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', proven scan='', @ProvenFinalScan,
                '', revision='', @HeaderRevision, ''.''
            );
            THROW 52806, @Diagnostic, 1;
        END;

        SET @TableName = N''EXCEL_FOR_KVK_'' + CONVERT(nvarchar(20), @LatestKVK);
        SET @TableObjectName = N''dbo.'' + @TableName;
        SET @TableNameFull = QUOTENAME(N''dbo'') + N''.'' + QUOTENAME(@TableName);

        IF OBJECT_ID(@TableObjectName, N''U'') IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source object '', @TableObjectName,
                '' is missing for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan, ''.''
            );
            THROW 52807, @Diagnostic, 1;
        END;

        SET @FailureStage = N''scan-date'';
        SELECT
            @ScanDateRowCount = COUNT_BIG(*),
            @ProvenScanDate = MIN(CONVERT(datetime2(0), ScanDate)),
            @ProvenScanDateMax = MAX(CONVERT(datetime2(0), ScanDate))
        FROM dbo.KingdomScanData4
        WHERE SCANORDER = @ProvenFinalScan;

        IF @ScanDateRowCount <= 0 OR @ProvenScanDate IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source scan date is missing for KVK='', @LatestKVK,
                '', proven scan='', @ProvenFinalScan, ''.''
            );
            THROW 52808, @Diagnostic, 1;
        END;

        IF @ProvenScanDate <> @ProvenScanDateMax
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source scan date is inconsistent for KVK='', @LatestKVK,
                '', proven scan='', @ProvenFinalScan, ''.''
            );
            THROW 52809, @Diagnostic, 1;
        END;

        SET @FailureStage = N''source-shape'';
        SET @sql = N''
            SELECT
                @pSourceRowCount = COUNT_BIG(*),
                @pInvalidGovernorRows = COALESCE(SUM(CONVERT(bigint, CASE
                    WHEN TRY_CONVERT(bigint, [Gov_ID]) IS NULL
                      OR TRY_CONVERT(bigint, [Gov_ID]) <= 0 THEN 1 ELSE 0 END)), 0),
                @pWrongKvkRows = COALESCE(SUM(CONVERT(bigint, CASE
                    WHEN TRY_CONVERT(int, [KVK_NO]) <> @pLatestKVK
                      OR [KVK_NO] IS NULL THEN 1 ELSE 0 END)), 0)
            FROM '' + @TableNameFull + N'' WITH (HOLDLOCK);

            SELECT @pDuplicateGovernorGroups = COUNT_BIG(*)
            FROM
            (
                SELECT TRY_CONVERT(bigint, [Gov_ID]) AS GovernorID
                FROM '' + @TableNameFull + N'' WITH (HOLDLOCK)
                GROUP BY TRY_CONVERT(bigint, [Gov_ID])
                HAVING COUNT_BIG(*) > 1
            ) AS duplicates;'';

        EXEC sys.sp_executesql
            @sql,
            N''@pLatestKVK int, @pSourceRowCount bigint OUTPUT, @pInvalidGovernorRows bigint OUTPUT, @pWrongKvkRows bigint OUTPUT, @pDuplicateGovernorGroups bigint OUTPUT'',
            @pLatestKVK = CONVERT(int, @LatestKVK),
            @pSourceRowCount = @SourceRowCount OUTPUT,
            @pInvalidGovernorRows = @InvalidGovernorRows OUTPUT,
            @pWrongKvkRows = @WrongKvkRows OUTPUT,
            @pDuplicateGovernorGroups = @DuplicateGovernorGroups OUTPUT;

        IF @SourceRowCount <= 0
            THROW 52810, ''SP_Stats_for_Upload: proven source output contains no rows.'', 1;

        IF @SourceRowCount <> @HeaderRowCount
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source/header row-count mismatch for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', revision='', @HeaderRevision,
                '', header rows='', @HeaderRowCount,
                '', source rows='', @SourceRowCount, ''.''
            );
            THROW 52811, @Diagnostic, 1;
        END;

        IF @InvalidGovernorRows > 0 OR @DuplicateGovernorGroups > 0 OR @WrongKvkRows > 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: invalid source identity for KVK='', @LatestKVK,
                '', invalid governors='', @InvalidGovernorRows,
                '', duplicate governor groups='', @DuplicateGovernorGroups,
                '', wrong KVK rows='', @WrongKvkRows, ''.''
            );
            THROW 52812, @Diagnostic, 1;
        END;

        SET @FailureStage = N''candidate-build'';
        SELECT TOP (0) *
        INTO #StatsForUploadCandidate
        FROM dbo.STATS_FOR_UPLOAD;

        SET @sql = N''
            INSERT INTO #StatsForUploadCandidate
            (
                [Rank],[KVK_RANK],[Gov_ID],[Governor_Name],
                [Starting Power],[Power_Delta],
                [Civilization],[KvKPlayed],[MostKvKKill],[MostKvKDead],[MostKvKHeal],
                [Acclaim],[HighestAcclaim],[AOOJoined],[AOOWon],[AOOAvgKill],[AOOAvgDead],[AOOAvgHeal],[Conduct],
                [Starting_T4&T5_KILLS],[T4_KILLS],[T5_KILLS],[T4&T5_Kills],[KILLS_OUTSIDE_KVK],[Kill Target],[% of Kill Target],
                [Starting_Deads],[Deads_Delta],[DEADS_OUTSIDE_KVK],[T4_Deads],[T5_Deads],[Dead_Target],[% of Dead Target],
                [Zeroed],[DKP_SCORE],[DKP Target],[% of DKP Target],
                [HelpsDelta],[RSS_Assist_Delta],[RSS_Gathered_Delta],
                [Pass 4 Kills],[Pass 6 Kills],[Pass 7 Kills],[Pass 8 Kills],
                [Pass 4 Deads],[Pass 6 Deads],[Pass 7 Deads],[Pass 8 Deads],
                [Starting_HealedTroops],[HealedTroopsDelta],
                [Starting_KillPoints],[KillPointsDelta],
                [RangedPoints],[RangedPointsDelta],[AutarchTimes],
                [Max_PreKvk_Points],[Max_HonorPoints],[PreKvk_Rank],[Honor_Rank],
                [KVK_NO],[LAST_REFRESH],[STATUS]
            )
            SELECT
                [Rank], [KVK_RANK], CAST([Gov_ID] AS bigint), RTRIM([Governor_Name]),
                [Starting Power], ISNULL([Power_Delta], 0),
                [Civilization], ISNULL([KvKPlayed], 0), ISNULL([MostKvKKill], 0),
                ISNULL([MostKvKDead], 0), ISNULL([MostKvKHeal], 0),
                ISNULL([Acclaim], 0), ISNULL([HighestAcclaim], 0), ISNULL([AOOJoined], 0),
                ISNULL([AOOWon], 0), ISNULL([AOOAvgKill], 0), ISNULL([AOOAvgDead], 0),
                ISNULL([AOOAvgHeal], 0), [Conduct],
                ISNULL([Starting_T4&T5_KILLS], 0), ISNULL([T4_KILLS], 0),
                ISNULL([T5_KILLS], 0), ISNULL([T4&T5_Kills], 0), ISNULL([KILLS_OUTSIDE_KVK], 0),
                ISNULL([Kill Target], 0), ISNULL([% of Kill Target], 0),
                ISNULL([Starting_Deads], 0), ISNULL([Deads_Delta], 0),
                ISNULL([DEADS_OUTSIDE_KVK], 0), ISNULL([T4_Deads], 0), ISNULL([T5_Deads], 0),
                ISNULL([Dead_Target], 0), ISNULL([% of Dead Target], 0),
                ISNULL([Zeroed], 0), ISNULL([DKP_SCORE], 0), ISNULL([DKP Target], 0),
                ISNULL([% of DKP Target], 0), ISNULL([HelpsDelta], 0),
                ISNULL([RSS_Assist_Delta], 0), ISNULL([RSS_Gathered_Delta], 0),
                ISNULL([Pass 4 Kills], 0), ISNULL([Pass 6 Kills], 0),
                ISNULL([Pass 7 Kills], 0), ISNULL([Pass 8 Kills], 0),
                ISNULL([Pass 4 Deads], 0), ISNULL([Pass 6 Deads], 0),
                ISNULL([Pass 7 Deads], 0), ISNULL([Pass 8 Deads], 0),
                ISNULL([Starting_HealedTroops], 0), ISNULL([HealedTroopsDelta], 0),
                ISNULL([Starting_KillPoints], 0), ISNULL([KillPointsDelta], 0),
                ISNULL([RangedPoints], 0), ISNULL([RangedPointsDelta], 0), ISNULL([AutarchTimes], 0),
                ISNULL([Max_PreKvk_Points], 0), ISNULL([Max_HonorPoints], 0),
                ISNULL([PreKvk_Rank], 0), ISNULL([Honor_Rank], 0),
                [KVK_NO], @pProvenScanDate,
                CASE
                    WHEN CAST([Gov_ID] AS bigint) IN
                    (
                        SELECT GovernorID
                        FROM dbo.EXEMPT_FROM_STATS
                        WHERE KVK_NO IN (0, @pLatestKVK)
                    ) THEN N''''EXEMPT''''
                    ELSE N''''INCLUDED''''
                END
            FROM '' + @TableNameFull + N'' WITH (HOLDLOCK);'';

        EXEC sys.sp_executesql
            @sql,
            N''@pLatestKVK int, @pProvenScanDate datetime2(0)'',
            @pLatestKVK = CONVERT(int, @LatestKVK),
            @pProvenScanDate = @ProvenScanDate;

        SELECT
            @CandidateRowCount = COUNT_BIG(*),
            @InvalidGovernorRows = COALESCE(SUM(CONVERT(bigint, CASE
                WHEN Gov_ID IS NULL OR Gov_ID <= 0 THEN 1 ELSE 0 END)), 0),
            @WrongKvkRows = COALESCE(SUM(CONVERT(bigint, CASE
                WHEN KVK_NO <> CONVERT(int, @LatestKVK) OR KVK_NO IS NULL THEN 1 ELSE 0 END)), 0)
        FROM #StatsForUploadCandidate;

        SELECT @DuplicateGovernorGroups = COUNT_BIG(*)
        FROM
        (
            SELECT Gov_ID
            FROM #StatsForUploadCandidate
            GROUP BY Gov_ID
            HAVING COUNT_BIG(*) > 1
        ) AS duplicates;

        IF @CandidateRowCount <= 0 OR @CandidateRowCount <> @SourceRowCount
            THROW 52813, ''SP_Stats_for_Upload: candidate row count does not match the proven source.'', 1;

        IF @InvalidGovernorRows > 0 OR @DuplicateGovernorGroups > 0 OR @WrongKvkRows > 0
            THROW 52814, ''SP_Stats_for_Upload: candidate identity validation failed.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM #StatsForUploadCandidate
            WHERE LAST_REFRESH IS NULL OR LAST_REFRESH <> @ProvenScanDate
        )
            THROW 52815, ''SP_Stats_for_Upload: candidate LAST_REFRESH is not coherent with the proven scan.'', 1;

        SET @FailureStage = N''header-recheck'';
        SELECT
            @CurrentHeaderScan = FinalScanOrder,
            @CurrentHeaderRowCount = OutputRowCount,
            @CurrentHeaderRevision = Revision,
            @CurrentHeaderState = State
        FROM dbo.KVKFinalReportHeader WITH (UPDLOCK, HOLDLOCK)
        WHERE KVK_NO = CONVERT(int, @LatestKVK);

        IF @CurrentHeaderScan IS NULL
           OR @CurrentHeaderRowCount IS NULL
           OR @CurrentHeaderRevision IS NULL
           OR @CurrentHeaderState IS NULL
           OR @CurrentHeaderScan <> @ProvenFinalScan
           OR @CurrentHeaderRowCount <> @HeaderRowCount
           OR @CurrentHeaderRevision <> @HeaderRevision
           OR @CurrentHeaderState <> @HeaderState
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: output provenance changed during publication for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', initial revision='', @HeaderRevision,
                '', current revision='', COALESCE(CONVERT(varchar(20), @CurrentHeaderRevision), ''NULL''), ''.''
            );
            THROW 52816, @Diagnostic, 1;
        END;

        SET @FailureStage = N''target-replacement'';
        DELETE FROM dbo.STATS_FOR_UPLOAD;

        INSERT INTO dbo.STATS_FOR_UPLOAD
        SELECT *
        FROM #StatsForUploadCandidate;

        SET @PublishedRowCount = @@ROWCOUNT;

        IF @PublishedRowCount <> @CandidateRowCount
            THROW 52817, ''SP_Stats_for_Upload: published row count does not match the validated candidate.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.STATS_FOR_UPLOAD
            WHERE Gov_ID IS NULL OR Gov_ID <= 0
               OR KVK_NO IS NULL OR KVK_NO <> CONVERT(int, @LatestKVK)
               OR LAST_REFRESH IS NULL OR LAST_REFRESH <> @ProvenScanDate
        )
        OR EXISTS
        (
            SELECT Gov_ID
            FROM dbo.STATS_FOR_UPLOAD
            GROUP BY Gov_ID
            HAVING COUNT_BIG(*) > 1
        )
            THROW 52818, ''SP_Stats_for_Upload: post-publication row-shape validation failed.'', 1;

        SET @FailureStage = N''target-statistics'';
        UPDATE STATISTICS dbo.STATS_FOR_UPLOAD WITH FULLSCAN;

        IF @StartedTransaction = 1
            COMMIT TRANSACTION;

        PRINT CONCAT(
            ''SP_Stats_for_Upload: completed KVK='', @LatestKVK,
            '', expected scan='', @ExpectedFinalScan,
            '', proven scan='', @ProvenFinalScan,
            '', header revision='', @HeaderRevision,
            '', basis='', @FinalizationBasis,
            '', generated at='', CONVERT(varchar(19), @FinalDataAtUtc, 120),
            '', source rows='', @SourceRowCount,
            '', published rows='', @PublishedRowCount,
            '', source scan date='', CONVERT(varchar(19), @ProvenScanDate, 120), ''.''
        );
    END TRY
    BEGIN CATCH
        DECLARE @ErrorNumber int = ERROR_NUMBER();
        DECLARE @ErrorMessage nvarchar(2048) = ERROR_MESSAGE();

        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        ELSE IF @SavepointCreated = 1 AND XACT_STATE() = 1
            ROLLBACK TRANSACTION StatsForUploadPublishSave;

        IF @ErrorNumber BETWEEN 52800 AND 52820
            THROW;

        SET @Diagnostic = CONCAT(
            ''SP_Stats_for_Upload: failed at stage='', @FailureStage,
            '', KVK='', COALESCE(CONVERT(varchar(20), @LatestKVK), ''NULL''),
            '', expected scan='', COALESCE(CONVERT(varchar(20), @ExpectedFinalScan), ''NULL''),
            '', proven scan='', COALESCE(CONVERT(varchar(20), @ProvenFinalScan), ''NULL''),
            '', header revision='', COALESCE(CONVERT(varchar(20), @HeaderRevision), ''NULL''),
            '', source rows='', @SourceRowCount,
            '', published rows='', @PublishedRowCount,
            '', SQL error='', @ErrorNumber,
            '', detail='', LEFT(@ErrorMessage, 600), ''.''
        );
        THROW 52819, @Diagnostic, 1;
    END CATCH;
END';

    IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK', N'P'))
       NOT LIKE N'%WHERE ht.DeltaOrder > @PRE_PASS_4_SCAN AND ht.DeltaOrder <= @KVK_END_SCAN%'
        THROW 52856, 'Migration post-validation: healed aggregation is not aligned to PRE_PASS_4_SCAN.', 1;

    IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P'))
       NOT LIKE N'%K98:StatsForUpload:Publish%'
        THROW 52857, 'Migration post-validation: publication lock contract is missing.', 1;

    IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P'))
       NOT LIKE N'%KVKFinalReportHeader%'
       OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P'))
          NOT LIKE N'%@ExpectedFinalScan%'
       OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P'))
          NOT LIKE N'%@ProvenScanDate%'
        THROW 52858, 'Migration post-validation: output provenance contract is incomplete.', 1;

    IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P')) LIKE N'%CHECKPOINT%'
       OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P')) LIKE N'%WAITFOR DELAY%'
       OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_Stats_for_Upload', N'P')) LIKE N'%TRUNCATE TABLE dbo.STATS_FOR_UPLOAD%'
        THROW 52859, 'Migration post-validation: unsafe legacy publication behavior remains.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/*
Required post-deployment repair (resolve values from live ProcConfig first):
    EXEC dbo.sp_ExcelOutput_ByKVK @KVK = <LatestEligibleKVK>, @Scan = <MATCHMAKING_SCAN>;
    EXEC dbo.SP_Stats_for_Upload;
    Rebuild player_stats_cache.json through /kvk_admin refresh_stats_cache.
*/
