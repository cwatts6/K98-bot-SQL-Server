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
    -- 4. Other deltas (use @Scan as lower bound)
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

    -----------------------------------------------
    -- 5. Latest snapshot at @Scan
    -----------------------------------------------
    SELECT GovernorID, GovernorName, PowerRank, [Power]
    INTO #Snapshot
    FROM dbo.KingdomScanData4
    WHERE ScanOrder = @Scan;

    -----------------------------------------------
    -- 5.1 Training power (Troops Power) positive deltas in window
    -----------------------------------------------
    IF OBJECT_ID('tempdb..#TrainPower') IS NOT NULL DROP TABLE #TrainPower;

    WITH KS AS (
        SELECT 
            k.GovernorID,
            k.ScanOrder,
            k.[Troops Power] AS TroopsPower
        FROM dbo.KingdomScanData4 AS k
        WHERE k.ScanOrder > @Scan AND k.ScanOrder <= @KVK_END_SCAN
    ),
    D AS (
        SELECT
            GovernorID,
            CASE 
                WHEN (TroopsPower - LAG(TroopsPower) OVER (PARTITION BY GovernorID ORDER BY ScanOrder)) > 0
                    THEN (TroopsPower - LAG(TroopsPower) OVER (PARTITION BY GovernorID ORDER BY ScanOrder))
                ELSE 0
            END AS TP_PositiveDelta
        FROM KS
    )
    SELECT
        GovernorID,
        CAST(SUM(TP_PositiveDelta) AS bigint) AS TrainingPower_Delta
    INTO #TrainPower
    FROM D
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 6. Stage
    -----------------------------------------------
    INSERT INTO dbo.STAGING_STATS (
        GovernorID,
        PowerRank,
        [Power],
        Power_Delta,
        GovernorName,
        T4KillsDelta,
        T5KillsDelta,
        [T4&T5_KILLSDelta],
        [KILLS_OUTSIDE_KVK],
        [P4T4&T5_KILLSDelta],
        [P6T4&T5_KillsDelta],
        [P7T4&T5_KillsDelta],
        [P8T4&T5_KillsDelta],
        DeadsDelta,
        [DEADS_OUTSIDE_KVK],
        P4DeadsDelta,
        P6DeadsDelta,
        P7DeadsDelta,
        P8DeadsDelta,
        HelpsDelta,
        RSSASSISTDelta,
        RSSGatheredDelta
    )
    SELECT 
        s.GovernorID,
        s.PowerRank,
        s.[Power],
        COALESCE(p.PowerDelta, 0)              AS Power_Delta,
        s.GovernorName,
        COALESCE(kt4.T4KillsDelta, 0),
        COALESCE(kt5.T5KillsDelta, 0),
        COALESCE(k.T4T5KillsDelta, 0)          AS [T4&T5_KILLSDelta],
        COALESCE(k.KillsOutsideKVK, 0)         AS [KILLS_OUTSIDE_KVK],
        COALESCE(k.P4Kills, 0)                 AS [P4T4&T5_KILLSDelta],
        COALESCE(k.P6Kills, 0)                 AS [P6T4&T5_KillsDelta],
        COALESCE(k.P7Kills, 0)                 AS [P7T4&T5_KillsDelta], 
        COALESCE(k.P8Kills, 0)                 AS [P8T4&T5_KillsDelta],
        COALESCE(d.DeadsDelta, 0),
        COALESCE(d.DeadsDeltaOutKVK, 0)        AS [DEADS_OUTSIDE_KVK],
        COALESCE(d.P4DeadsDelta, 0),
        COALESCE(d.P6DeadsDelta, 0),
        COALESCE(d.P7DeadsDelta, 0),
        COALESCE(d.P8DeadsDelta, 0),
        COALESCE(h.HelpsDelta, 0),
        COALESCE(ra.RSSAssistDelta, 0),
        COALESCE(rg.RSSGatheredDelta, 0)
    FROM #Snapshot s
    LEFT JOIN #Power       p   ON p.GovernorID  = s.GovernorID
    LEFT JOIN #KillsT4     kt4 ON kt4.GovernorID = s.GovernorID
    LEFT JOIN #KillsT5     kt5 ON kt5.GovernorID = s.GovernorID
    LEFT JOIN #Kills       k   ON k.GovernorID  = s.GovernorID
    LEFT JOIN #Deads       d   ON d.GovernorID  = s.GovernorID
    LEFT JOIN #Helps       h   ON h.GovernorID  = s.GovernorID
    LEFT JOIN #RSSAssist   ra  ON ra.GovernorID = s.GovernorID
    LEFT JOIN #RSSGathered rg  ON rg.GovernorID = s.GovernorID
    WHERE s.GovernorID IS NOT NULL
    ORDER BY s.PowerRank;

    -- Cleanup temps from stage step
    DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot;

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
    -- 9. Dynamic final table (revert % column names)
    -----------------------------------------------
    DECLARE @ExcelTbl       sysname      = N'EXCEL_FOR_KVK_' + CAST(@KVK AS nvarchar(10));
    DECLARE @TargetsTbl     sysname      = N'TARGETS_'       + CAST(@KVK AS nvarchar(10));
    DECLARE @ExcelTblFull   nvarchar(260)= QUOTENAME('dbo') + N'.' + QUOTENAME(@ExcelTbl);
    DECLARE @TargetsTblFull nvarchar(260)= QUOTENAME('dbo') + N'.' + QUOTENAME(@TargetsTbl);

    DECLARE @sql nvarchar(max) =
      N'DROP TABLE IF EXISTS ' + @ExcelTblFull + N';
        SELECT TOP (5000)
            S.[PowerRank]                                   AS [Rank],
            ROW_NUMBER() OVER (ORDER BY D.[DKP_SCORE] DESC) AS [KVK_RANK],
            S.[GovernorID]                                  AS [Gov_ID],
            S.[GovernorName]                                AS [Governor_Name],
            S.[Power]                                       AS [Starting Power],
            S.Power_Delta,
            S.[T4KillsDelta]                                AS [T4_KILLS],
            S.[T5KillsDelta]                                AS [T5_KILLS],
            S.[T4&T5_KILLSDelta]                            AS [T4&T5_Kills],
            S.KILLS_OUTSIDE_KVK,
            T.[Kill_Target]                                 AS [Kill Target],
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE ROUND(S.[T4&T5_KILLSDelta] * 1.0 / T.[Kill_Target] * 100, 2)
            END                                             AS [% of Kill Target],
            S.[DeadsDelta]                                  AS [Deads],
            S.DEADS_OUTSIDE_KVK,
            COALESCE(HD.[T4 Deads], 0)                      AS [T4_Deads],
            COALESCE(HD.[T5 Deads], 0)                      AS [T5_Deads],
            T.[Dead_Target]                                 AS [Dead_Target],
            CASE 
                WHEN T.[Dead_Target] = 0 THEN 0
                WHEN Z.GovernorID = S.GovernorID
                    THEN ROUND((S.DeadsDelta * 0.1) / T.[Dead_Target] * 100, 2)
                ELSE ROUND(S.DeadsDelta * 1.0 / T.[Dead_Target] * 100, 2)
            END                                             AS [% of Dead Target],
            Z.Zeroed,
            D.[DKP_SCORE],
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE (T.Kill_Target * 3 + T.Dead_Target * 8)
            END                                             AS [DKP Target],
            CASE 
                WHEN T.[Kill_Target] = 0 THEN 0
                WHEN Z.GovernorID = S.GovernorID
                    THEN ROUND(D.[DKP_SCORE] * 1.0 / (T.[Kill_Target] * 3 + T.[Dead_Target] * 8) * 100, 2)
                ELSE ROUND(D.[DKP_SCORE] * 1.0 / (T.[Kill_Target] * 3 + T.[Dead_Target] * 8) * 100, 2)
            END                                             AS [% of DKP Target],
            S.[HelpsDelta]                                  AS [Helps],
            S.[RSSASSISTDelta]                              AS [RSS_Assist],
            S.[RSSGatheredDelta]                            AS [RSS_Gathered],
            S.[P4T4&T5_KillsDelta]                          AS [Pass 4 Kills],
            S.[P6T4&T5_KillsDelta]                          AS [Pass 6 Kills],
            S.[P7T4&T5_KillsDelta]                          AS [Pass 7 Kills],
            S.[P8T4&T5_KillsDelta]                          AS [Pass 8 Kills],
            S.P4DeadsDelta                                  AS [Pass 4 Deads],
            S.P6DeadsDelta                                  AS [Pass 6 Deads],
            S.P7DeadsDelta                                  AS [Pass 7 Deads],
            S.P8DeadsDelta                                  AS [Pass 8 Deads],
            COALESCE(TP.TrainingPower_Delta, 0)             AS [TrainingPower_Delta],
            CASE 
                WHEN COALESCE(S.Power_Delta,0) + COALESCE(S.DeadsDelta,0) * 7.0 - COALESCE(TP.TrainingPower_Delta,0) > 0
                THEN CAST(COALESCE(S.Power_Delta,0) + COALESCE(S.DeadsDelta,0) * 7.0 - COALESCE(TP.TrainingPower_Delta,0) AS bigint)
                ELSE 0
            END                                             AS [HealedPower_Est],
            CASE 
                WHEN COALESCE(S.Power_Delta,0) + COALESCE(S.DeadsDelta,0) * 7.0 - COALESCE(TP.TrainingPower_Delta,0) > 0
                THEN CAST(ROUND( (COALESCE(S.Power_Delta,0) + COALESCE(S.DeadsDelta,0) * 7.0 - COALESCE(TP.TrainingPower_Delta,0)) / 7.0, 0) AS bigint)
                ELSE 0
            END                                             AS [HealedTroops_Est],
            ' + CAST(@KVK AS nvarchar(10)) + N'             AS [KVK_NO]
        INTO ' + @ExcelTblFull + N'
        FROM dbo.STAGING_STATS AS S
        LEFT JOIN #HD1  AS HD ON S.GovernorID = HD.GovernorID
        LEFT JOIN ' + @TargetsTblFull + N' AS T ON T.GovernorID = S.GovernorID
        LEFT JOIN #DKP  AS D  ON D.GovernorID = S.GovernorID
        LEFT JOIN dbo.ZEROED AS Z ON Z.GovernorID = S.GovernorID AND Z.ScanOrder = @pScan
        LEFT JOIN #TrainPower AS TP ON TP.GovernorID = S.GovernorID
        ORDER BY S.PowerRank ASC;';

    EXEC sp_executesql @sql, N'@pScan int', @pScan = @Scan;

    DROP TABLE IF EXISTS #DKP, #HD1, #TrainPower;

    EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;

    PRINT 'Completed KVK ' + CAST(@KVK AS varchar(10))
        + ' with ScanOrder=' + CAST(@Scan AS varchar(20))
        + ' at ' + CONVERT(varchar, GETDATE(), 120);
END

