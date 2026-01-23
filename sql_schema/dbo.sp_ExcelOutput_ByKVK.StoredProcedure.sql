SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ExcelOutput_ByKVK]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_ExcelOutput_ByKVK] AS' 
END
ALTER PROCEDURE [dbo].[sp_ExcelOutput_ByKVK]
	@KVK [int],
	@Scan [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @CURRENTKVK3      INT,
        @KVK_END_SCAN     INT,
        @LASTKVKEND       INT,
        @PASS4END         INT,
        @PASS6END         INT,
        @PASS7END         INT,
        @PRE_PASS_4_SCAN  INT,
        @MaxAvailableScan INT;

    -- Load KVK config
    SELECT
        @CURRENTKVK3     = CAST(MAX(CASE WHEN ConfigKey = 'CURRENTKVK3'     THEN ConfigValue END) AS INT),
        @KVK_END_SCAN    = CAST(MAX(CASE WHEN ConfigKey = 'KVK_END_SCAN'    THEN ConfigValue END) AS INT),
        @LASTKVKEND      = CAST(MAX(CASE WHEN ConfigKey = 'LASTKVKEND'      THEN ConfigValue END) AS INT),
        @PASS4END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS4END'        THEN ConfigValue END) AS INT),
        @PASS6END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS6END'        THEN ConfigValue END) AS INT),
        @PASS7END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS7END'        THEN ConfigValue END) AS INT),
        @PRE_PASS_4_SCAN = CAST(MAX(CASE WHEN ConfigKey = 'PRE_PASS_4_SCAN' THEN ConfigValue END) AS INT)
    FROM dbo.ProcConfig
    WHERE KVKVersion = @KVK;

    IF @KVK_END_SCAN IS NULL OR @LASTKVKEND IS NULL OR @PRE_PASS_4_SCAN IS NULL
    BEGIN
        RAISERROR('sp_ExcelOutput_ByKVK: Missing KVK window config for KVK=%d (one of KVK_END_SCAN/LASTKVKEND/PRE_PASS_4_SCAN is NULL).', 16, 1, @KVK);
        RETURN;
    END

    -- Cap @Scan to available data (safety if caller passed a future scan)
    SELECT @MaxAvailableScan = MAX(ScanOrder) FROM dbo.KingdomScanData4;
    IF @MaxAvailableScan IS NULL
    BEGIN
        RAISERROR('sp_ExcelOutput_ByKVK: No scan data available.', 16, 1);
        RETURN;
    END
    IF @Scan > @MaxAvailableScan SET @Scan = @MaxAvailableScan;

    -- Fresh staging
    TRUNCATE TABLE dbo.STAGING_STATS;

    -----------------------------------------------
    -- Build/refresh ranked PreKvk & Honor tables (so we can join ranks quickly)
    -----------------------------------------------
    EXEC dbo.sp_Build_Prekvk_And_Honor_Rankings;

    -----------------------------------------------
    -- 1. Consolidated Deads Delta
    -----------------------------------------------
    SELECT 
        GovernorID,
        SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN DeadsDelta ELSE 0 END) AS DeadsDelta,
        SUM(CASE WHEN DeltaOrder > @LASTKVKEND      AND DeltaOrder <= @PRE_PASS_4_SCAN THEN DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
        SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN DeadsDelta ELSE 0 END) AS P4DeadsDelta,
        SUM(CASE WHEN DeltaOrder > @PASS4END        AND DeltaOrder <= @PASS6END THEN DeadsDelta ELSE 0 END) AS P6DeadsDelta,
        SUM(CASE WHEN DeltaOrder > @PASS6END        AND DeltaOrder <= @PASS7END THEN DeadsDelta ELSE 0 END) AS P7DeadsDelta,
        SUM(CASE WHEN DeltaOrder > @PASS7END        AND DeltaOrder <= @KVK_END_SCAN THEN DeadsDelta ELSE 0 END) AS P8DeadsDelta
    INTO #Deads
    FROM dbo.DeadsDelta
    WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 2. Consolidated Kills Delta (T4&T5)
    -----------------------------------------------
    SELECT 
        GovernorID,
        SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
        SUM(CASE WHEN DeltaOrder > @LASTKVKEND      AND DeltaOrder <= @PRE_PASS_4_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
        SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
        SUM(CASE WHEN DeltaOrder > @PASS4END        AND DeltaOrder <= @PASS6END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
        SUM(CASE WHEN DeltaOrder > @PASS6END        AND DeltaOrder <= @PASS7END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
        SUM(CASE WHEN DeltaOrder > @PASS7END        AND DeltaOrder <= @KVK_END_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
    INTO #Kills
    FROM dbo.T4T5KillDelta
    WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 3. T4 / T5 splits
    -----------------------------------------------
    SELECT GovernorID, SUM(COALESCE(T4KILLSDelta, 0)) AS T4KillsDelta
    INTO #KillsT4
    FROM dbo.T4KillDelta
    WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

    SELECT GovernorID, SUM(COALESCE(T5KILLSDelta, 0)) AS T5KillsDelta
    INTO #KillsT5
    FROM dbo.T5KillDelta
    WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

	----------------------------------------------- 
	--4. KillPointsDelta aggregation (use same window as other deltas) 
	----------------------------------------------- 
	
	SELECT GovernorID, SUM(COALESCE(KillPointsDelta, 0)) AS KillPointsDelta 
	INTO #KillPoints 
	FROM dbo.KillPointsDelta 
	WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN 
	GROUP BY GovernorID;

    -----------------------------------------------
    -- 5. Other deltas (use @Scan as lower bound)
    -----------------------------------------------
    SELECT GovernorID, SUM(COALESCE(HelpsDelta, 0)) AS HelpsDelta
    INTO #Helps
    FROM dbo.HelpsDelta
    WHERE DeltaOrder > @Scan AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

    SELECT GovernorID, SUM(COALESCE(RSSASSISTDelta, 0)) AS RSSAssistDelta
    INTO #RSSAssist
    FROM dbo.RSSASSISTDelta
    WHERE DeltaOrder > @Scan AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

    SELECT GovernorID, SUM(COALESCE(RSSGatheredDelta, 0)) AS RSSGatheredDelta
    INTO #RSSGathered
    FROM dbo.RSSGatheredDelta
    WHERE DeltaOrder > @Scan AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

    SELECT GovernorID, SUM(COALESCE(Power_Delta, 0)) AS PowerDelta
    INTO #Power
    FROM dbo.PowerDelta
    WHERE DeltaOrder > @Scan AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

	SELECT GovernorID, SUM(COALESCE(HealedTroopsDelta, 0)) AS HealedTroopsDelta
    INTO #Healed
    FROM dbo.HealedTroopsDelta
    WHERE DeltaOrder > @Scan AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

	SELECT GovernorID, SUM(COALESCE(RangedPointsDelta, 0)) AS RangedPointsDelta
    INTO #Ranged
    FROM [dbo].[RangedPointsDelta]
    WHERE DeltaOrder > @Scan AND DeltaOrder <= @KVK_END_SCAN
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 5. Latest snapshot at @Scan (include Max PreKvk points, PreKvk rank, Max HonorPoints, Honor rank)
    -----------------------------------------------
    SELECT
        ksd.GovernorID,
        ksd.GovernorName,
        ksd.PowerRank,
        ksd.[Power],
        ksd.[Civilization],
        ksd.[KvKPlayed],
        ksd.[MostKvKKill],
        ksd.[MostKvKDead],
        ksd.[MostKvKHeal],
        ksd.[Acclaim],
        ksd.[HighestAcclaim],
        ksd.[AOOJoined],
        ksd.[AOOWon],
        ksd.[AOOAvgKill],
        ksd.[AOOAvgDead],
        ksd.[AOOAvgHeal],
		ksd.[Deads],
		ksd.[T4&T5_KILLS], 
		ksd.[HealedTroops], 
		ksd.[KillPoints],
		ksd.[RangedPoints],
        pk.MaxPreKvkPoints    AS MaxPreKvkPoints,
        pk.PreKvk_Rank        AS PreKvkRank,
        hn.MaxHonorPoints     AS MaxHonorPoints,
        hn.Honor_Rank         AS HonorRank
    INTO #Snapshot
    FROM dbo.KingdomScanData4 ksd
    LEFT JOIN dbo.PreKvk_Scores_Ranked pk
      ON pk.GovernorID = ksd.GovernorID AND pk.KVK_NO = @CURRENTKVK3
    LEFT JOIN dbo.KVK_Honor_Ranked hn
      ON hn.GovernorID = ksd.GovernorID AND hn.KVK_NO = @CURRENTKVK3
    WHERE ksd.ScanOrder = @Scan;


  -----------------------------------------------
    -- 6. Stage
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
		, COALESCE(s.RangedPoints, 0)               AS RangedPoints
		, COALESCE(ran.RangedPointsDelta, 0)    AS RangedPointsDelta   -- ✅ new
		, s.Civilization
		, COALESCE(s.KvKPlayed, 0)               AS KvKPlayed
		, s.MostKvKKill
		, s.MostKvKDead
		, s.MostKvKHeal
		, s.Acclaim
		, s.HighestAcclaim
		, s.AOOJoined
		, s.AOOWon
		, s.AOOAvgKill
		, s.AOOAvgDead
		, s.AOOAvgHeal
		, COALESCE(kp.KillPointsDelta, 0)            AS KillPointsDelta   -- adjust source if needed
		, COALESCE(s.KillPoints, 0)                 AS KillPoints
		, COALESCE(he.HealedTroopsDelta, 0)			 AS HealedTroopsDelta
		, COALESCE(s.Deads, 0)           AS [Starting_Deads]
		, COALESCE(s.[T4&T5_KILLS], 0)     AS [Starting_T4&T5_KILLS]
		, COALESCE(s.MaxPreKvkPoints, 0)            AS MaxPreKvkPoints
		, COALESCE(s.MaxHonorPoints, 0)             AS MaxHonorPoints
		, COALESCE(s.PreKvkRank, 0)                 AS PreKvkRank
		, COALESCE(s.HonorRank, 0)                  AS HonorRank
	FROM #Snapshot s
	LEFT JOIN #Power       p   ON p.GovernorID   = s.GovernorID
	LEFT JOIN #KillsT4     kt4 ON kt4.GovernorID = s.GovernorID
	LEFT JOIN #KillsT5     kt5 ON kt5.GovernorID = s.GovernorID
	LEFT JOIN #Kills       k   ON k.GovernorID   = s.GovernorID
	LEFT JOIN #KillPoints kp ON kp.GovernorID = s.GovernorID
	LEFT JOIN #Deads       d   ON d.GovernorID   = s.GovernorID
	LEFT JOIN #Helps       h   ON h.GovernorID   = s.GovernorID
	LEFT JOIN #RSSAssist   ra  ON ra.GovernorID  = s.GovernorID
	LEFT JOIN #RSSGathered rg  ON rg.GovernorID  = s.GovernorID
	LEFT JOIN #Healed      he  ON he.GovernorID  = s.GovernorID
	LEFT JOIN #Ranged      ran ON ran.GovernorID = s.GovernorID   
	WHERE s.GovernorID IS NOT NULL;


    -- Cleanup temps from stage step
    DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot, #Healed, #Ranged, #KillPoints;

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
    DECLARE @ExcelTbl       sysname       = N'EXCEL_FOR_KVK_' + CAST(@KVK AS nvarchar(10));
    DECLARE @TargetsTbl     sysname       = N'TARGETS_'       + CAST(@KVK AS nvarchar(10));
    DECLARE @ExcelTblFull   nvarchar(260) = QUOTENAME('dbo') + N'.' + QUOTENAME(@ExcelTbl);
    DECLARE @TargetsTblFull nvarchar(260) = QUOTENAME('dbo') + N'.' + QUOTENAME(@TargetsTbl);

    DECLARE @sql nvarchar(max) = N'';

    SET @sql += N'DROP TABLE IF EXISTS ' + @ExcelTblFull + N';' + CHAR(10);

    SET @sql += N'
    SELECT TOP (5000)
        CAST(S.[PowerRank] AS int)                                   AS [Rank],
        CAST(ROW_NUMBER() OVER (ORDER BY D.[DKP_SCORE] DESC) AS int) AS [KVK_RANK],
        CAST(S.[GovernorID] AS bigint)                               AS [Gov_ID],
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

        CAST(S.[MaxPreKvkPoints] AS bigint)                          AS [Max_PreKvk_Points],
        CAST(S.[MaxHonorPoints] AS bigint)                           AS [Max_HonorPoints],
        CAST(S.[PreKvkRank] AS bigint)                               AS [PreKvk_Rank],
        CAST(S.[HonorRank] AS bigint)                                AS [Honor_Rank],

        CAST(@pKVK AS int)                                           AS [KVK_NO]
    INTO ' + @ExcelTblFull + N'
    FROM dbo.STAGING_STATS AS S
    LEFT JOIN #HD1  AS HD ON S.GovernorID = HD.GovernorID
    LEFT JOIN ' + @TargetsTblFull + N' AS T ON T.GovernorID = S.GovernorID
    LEFT JOIN #DKP  AS D  ON D.GovernorID = S.GovernorID
    LEFT JOIN dbo.ZEROED AS Z ON Z.GovernorID = S.GovernorID AND Z.ScanOrder = @pScan
    ORDER BY S.PowerRank ASC;';

	IF CHARINDEX(N'COALESCE(HD.[T4 Deads]', @sql) = 0
	BEGIN
		RAISERROR('HD reference missing from SQL string (string likely broken).',16,1);
	END

    EXEC sp_executesql
        @sql,
        N'@pScan int, @pKVK int',
        @pScan = @Scan,
        @pKVK  = @KVK;

	EXEC dbo.sp_Create_Excel_For_Kvk_Indexes @ExcelTblFull, @ExcelTbl;

    DROP TABLE IF EXISTS #DKP, #HD1;

    EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;

    PRINT 'Completed KVK ' + CAST(@KVK AS varchar(10))
        + ' with ScanOrder=' + CAST(@Scan AS varchar(20))
        + ' at ' + CONVERT(varchar, GETDATE(), 120);
END

