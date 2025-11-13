SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Loop_ExcelOutput_ByKVK]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Loop_ExcelOutput_ByKVK] AS' 
END
ALTER PROCEDURE [dbo].[sp_Loop_ExcelOutput_ByKVK]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @KVKVersion INT;

    DECLARE kvk_cursor_loop CURSOR FOR
        SELECT DISTINCT KVKVersion FROM dbo.ProcConfig ORDER BY KVKVersion;

    -- Step 0: Only once per run — create delta tables if needed
    EXEC dbo.CREATE_DELTA_TABLES;

    OPEN kvk_cursor_loop;
    FETCH NEXT FROM kvk_cursor_loop INTO @KVKVersion;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Load config for current KVK
        DECLARE
            @CURRENTKVK3 INT,
            @KVK_END_SCAN INT,
            @LASTKVKEND INT,
            @MATCHMAKING_SCAN INT,
            @PASS4END INT,
            @PASS6END INT,
            @PASS7END INT,
            @PRE_PASS_4_SCAN INT,
            @MaxAvailableScan INT;

        SELECT
            @CURRENTKVK3      = MAX(CASE WHEN ConfigKey='CURRENTKVK3'      THEN TRY_CAST(ConfigValue AS INT) END),
            @KVK_END_SCAN     = MAX(CASE WHEN ConfigKey='KVK_END_SCAN'     THEN TRY_CAST(ConfigValue AS INT) END),
            @LASTKVKEND       = MAX(CASE WHEN ConfigKey='LASTKVKEND'       THEN TRY_CAST(ConfigValue AS INT) END),
            @MATCHMAKING_SCAN = MAX(CASE WHEN ConfigKey='MATCHMAKING_SCAN' THEN TRY_CAST(ConfigValue AS INT) END),
            @PASS4END         = MAX(CASE WHEN ConfigKey='PASS4END'         THEN TRY_CAST(ConfigValue AS INT) END),
            @PASS6END         = MAX(CASE WHEN ConfigKey='PASS6END'         THEN TRY_CAST(ConfigValue AS INT) END),
            @PASS7END         = MAX(CASE WHEN ConfigKey='PASS7END'         THEN TRY_CAST(ConfigValue AS INT) END),
            @PRE_PASS_4_SCAN  = MAX(CASE WHEN ConfigKey='PRE_PASS_4_SCAN'  THEN TRY_CAST(ConfigValue AS INT) END)
        FROM dbo.ProcConfig
        WHERE KVKVersion = @KVKVersion;

        -- Reset staging
        TRUNCATE TABLE dbo.STAGING_STATS;

        -- Cap to latest available scan to avoid future scans
        SELECT @MaxAvailableScan = MAX(ScanOrder) FROM dbo.KingdomScanData4;
        IF @MATCHMAKING_SCAN > @MaxAvailableScan SET @MATCHMAKING_SCAN = @MaxAvailableScan;

        -----------------------------------------------
        -- 1. Deads delta
        -----------------------------------------------
        SELECT
            GovernorID,
            SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN COALESCE(DeadsDelta,0) ELSE 0 END) AS DeadsDelta,
            SUM(CASE WHEN DeltaOrder > @LASTKVKEND    AND DeltaOrder <= @PRE_PASS_4_SCAN THEN COALESCE(DeadsDelta,0) ELSE 0 END) AS DeadsDeltaOutKVK,
            SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN COALESCE(DeadsDelta,0) ELSE 0 END) AS P4DeadsDelta,
            SUM(CASE WHEN DeltaOrder > @PASS4END AND DeltaOrder <= @PASS6END THEN COALESCE(DeadsDelta,0) ELSE 0 END) AS P6DeadsDelta,
            SUM(CASE WHEN DeltaOrder > @PASS6END AND DeltaOrder <= @PASS7END THEN COALESCE(DeadsDelta,0) ELSE 0 END) AS P7DeadsDelta,
            SUM(CASE WHEN DeltaOrder > @PASS7END AND DeltaOrder <= @KVK_END_SCAN THEN COALESCE(DeadsDelta,0) ELSE 0 END) AS P8DeadsDelta
        INTO #Deads
        FROM dbo.DeadsDelta
        WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
        GROUP BY GovernorID;

        -----------------------------------------------
        -- 2. T4&T5 kills delta rollup
        -----------------------------------------------
        SELECT
            GovernorID,
            SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN COALESCE([T4&T5_KILLSDelta],0) ELSE 0 END) AS T4T5KillsDelta,
            SUM(CASE WHEN DeltaOrder > @LASTKVKEND    AND DeltaOrder <= @PRE_PASS_4_SCAN THEN COALESCE([T4&T5_KILLSDelta],0) ELSE 0 END) AS KillsOutsideKVK,
            SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN COALESCE([T4&T5_KILLSDelta],0) ELSE 0 END) AS P4Kills,
            SUM(CASE WHEN DeltaOrder > @PASS4END AND DeltaOrder <= @PASS6END THEN COALESCE([T4&T5_KILLSDelta],0) ELSE 0 END) AS P6Kills,
            SUM(CASE WHEN DeltaOrder > @PASS6END AND DeltaOrder <= @PASS7END THEN COALESCE([T4&T5_KILLSDelta],0) ELSE 0 END) AS P7Kills,
            SUM(CASE WHEN DeltaOrder > @PASS7END AND DeltaOrder <= @KVK_END_SCAN THEN COALESCE([T4&T5_KILLSDelta],0) ELSE 0 END) AS P8Kills
        INTO #Kills
        FROM dbo.T4T5KillDelta
        WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
        GROUP BY GovernorID;

        -----------------------------------------------
        -- 3. T4/T5 component kills
        -----------------------------------------------
        SELECT GovernorID, SUM(COALESCE(T4KILLSDelta,0)) AS T4KillsDelta
        INTO #KillsT4
        FROM dbo.T4KillDelta
        WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
        GROUP BY GovernorID;

        SELECT GovernorID, SUM(COALESCE(T5KILLSDelta,0)) AS T5KillsDelta
        INTO #KillsT5
        FROM dbo.T5KillDelta
        WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
        GROUP BY GovernorID;

        -----------------------------------------------
        -- 4. Other deltas
        -----------------------------------------------
        SELECT GovernorID, SUM(COALESCE(HelpsDelta,0)) AS HelpsDelta
        INTO #Helps
        FROM dbo.HelpsDelta
        WHERE DeltaOrder > @MATCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
        GROUP BY GovernorID;

        SELECT GovernorID, SUM(COALESCE(RSSASSISTDelta,0)) AS RSSAssistDelta
        INTO #RSSAssist
        FROM dbo.RSSASSISTDelta
        WHERE DeltaOrder > @MATCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
        GROUP BY GovernorID;

        SELECT GovernorID, SUM(COALESCE(RSSGatheredDelta,0)) AS RSSGatheredDelta
        INTO #RSSGathered
        FROM dbo.RSSGatheredDelta
        WHERE DeltaOrder > @MATCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
        GROUP BY GovernorID;

        SELECT GovernorID, SUM(COALESCE(Power_Delta,0)) AS PowerDelta
        INTO #Power
        FROM dbo.PowerDelta
        WHERE DeltaOrder > @MATCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
        GROUP BY GovernorID;

        -----------------------------------------------
        -- 5. Snapshot at matchmaking
        -----------------------------------------------
        SELECT GovernorID, GovernorName, PowerRank, [Power]
        INTO #Snapshot
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @MATCHMAKING_SCAN;

        -----------------------------------------------
        -- 6. Assemble staging
        -----------------------------------------------
        INSERT INTO dbo.STAGING_STATS
        SELECT
            s.GovernorID,
            s.PowerRank,
            s.[Power],
            p.PowerDelta,
            s.GovernorName,
            kt4.T4KillsDelta,
            kt5.T5KillsDelta,
            k.T4T5KillsDelta                  AS [T4&T5_KILLSDelta],
            k.KillsOutsideKVK                 AS [KILLS_OUTSIDE_KVK],
            k.P4Kills                         AS [P4T4&T5_KILLSDelta],
            k.P6Kills                         AS [P6T4&T5_KillsDelta],
            k.P7Kills                         AS [P7T4&T5_KillsDelta],
            k.P8Kills                         AS [P8T4&T5_KillsDelta],
            d.DeadsDelta,
            d.DeadsDeltaOutKVK                AS [DEADS_OUTSIDE_KVK],
            d.P4DeadsDelta,
            d.P6DeadsDelta,
            d.P7DeadsDelta,
            d.P8DeadsDelta,
            h.HelpsDelta,
            ra.RSSAssistDelta,
            rg.RSSGatheredDelta
        FROM #Snapshot s
        LEFT JOIN #Power      p  ON p.GovernorID  = s.GovernorID
        LEFT JOIN #KillsT4    kt4 ON kt4.GovernorID = s.GovernorID
        LEFT JOIN #KillsT5    kt5 ON kt5.GovernorID = s.GovernorID
        LEFT JOIN #Kills      k  ON k.GovernorID  = s.GovernorID
        LEFT JOIN #Deads      d  ON d.GovernorID  = s.GovernorID
        LEFT JOIN #Helps      h  ON h.GovernorID  = s.GovernorID
        LEFT JOIN #RSSAssist  ra ON ra.GovernorID = s.GovernorID
        LEFT JOIN #RSSGathered rg ON rg.GovernorID = s.GovernorID
        WHERE s.GovernorID IS NOT NULL
        ORDER BY s.PowerRank;

        -----------------------------------------------
        -- 7. Cleanup temps pre-export helpers
        -----------------------------------------------
        DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot;

        -- DKP calc (Zeroed penalty adjustment)
        SELECT
            S1.GovernorID,
            DKP_Score =
                CASE WHEN Z.GovernorID = S1.GovernorID
                     THEN ROUND( (S1.[T4&T5_KILLSDelta] * 3) + (S1.[DeadsDelta] * 0.1) * 8, 0)
                     ELSE ROUND( (S1.[T4&T5_KILLSDelta] * 3) + (S1.[DeadsDelta] * 8), 0)
                END
        INTO #DKP
        FROM dbo.STAGING_STATS AS S1
        LEFT JOIN dbo.ZEROED   AS Z
          ON Z.GovernorID = S1.GovernorID
         AND Z.ScanOrder  = @MATCHMAKING_SCAN;

        -- HoH snapshot
        SELECT GovernorID,
               MAX(T4_Deads) AS [T4 Deads],
               MAX(T5_Deads) AS [T5 Deads],
               MAX(KVK_START_SCANORDER) AS SCANORDER
        INTO #HD1
        FROM dbo.HoH_Deads
        GROUP BY GovernorID;

        -----------------------------------------------
        -- 8. Build EXCEL_FOR_KVK_{n}
        --    NOTE: expose safe aliases AND legacy headers (for now)
        -----------------------------------------------
        DECLARE @sql nvarchar(MAX) =
        N'DROP TABLE IF EXISTS EXCEL_FOR_KVK_' + CAST(@CURRENTKVK3 AS nvarchar(10)) + ';
          SELECT TOP (5000)
              S.[PowerRank]                                       AS [Rank],
              ROW_NUMBER() OVER (ORDER BY D.[DKP_Score] DESC)     AS [KVK_RANK],
              ROW_NUMBER() OVER (ORDER BY S.[T4&T5_KILLSDelta] DESC) AS [KVK_KILL_RANK],
              S.[GovernorID]                                      AS [Gov_ID],
              S.[GovernorName]                                    AS [Governor_Name],
              S.[Power]                                           AS [Starting Power],
              S.Power_Delta,
              S.[T4KillsDelta]                                    AS [T4_KILLS],
              S.[T5KillsDelta]                                    AS [T5_KILLS],
              S.[T4&T5_KILLSDelta]                                AS [T4&T5_Kills],
              S.KILLS_OUTSIDE_KVK,
              T.[Kill_Target]                                     AS [Kill Target],
              -- Safe %s
              Kill_Target_Pct = CASE WHEN COALESCE(T.[Kill_Target],0) = 0
                                      THEN 0
                                      ELSE ROUND(S.[T4&T5_KILLSDelta] * 1.0 / NULLIF(T.[Kill_Target],0) * 100, 2)
                                 END,
              [% of Kill target] = CASE WHEN COALESCE(T.[Kill_Target],0) = 0
                                      THEN 0
                                      ELSE ROUND(S.[T4&T5_KILLSDelta] * 1.0 / NULLIF(T.[Kill_Target],0) * 100, 2)
                                 END,
              S.[DeadsDelta]                                      AS [Deads],
              S.DEADS_OUTSIDE_KVK,
              COALESCE(HD.[T4 Deads],0)                           AS [T4_Deads],
              COALESCE(HD.[T5 Deads],0)                           AS [T5_Deads],
              T.[Dead_Target]                                     AS [Dead_Target],
              Dead_Target_Pct = CASE
                                  WHEN COALESCE(T.[Dead_Target],0) = 0 THEN 0
                                  WHEN Z.GovernorID = S.GovernorID THEN ROUND((S.DeadsDelta * 0.1) / NULLIF(T.[Dead_Target],0) * 100, 2)
                                  ELSE ROUND(S.DeadsDelta * 1.0 / NULLIF(T.[Dead_Target],0) * 100, 2)
                                END,
              [% of Dead_Target] = CASE
                                  WHEN COALESCE(T.[Dead_Target],0) = 0 THEN 0
                                  WHEN Z.GovernorID = S.GovernorID THEN ROUND((S.DeadsDelta * 0.1) / NULLIF(T.[Dead_Target],0) * 100, 2)
                                  ELSE ROUND(S.DeadsDelta * 1.0 / NULLIF(T.[Dead_Target],0) * 100, 2)
                                END,
				[% of Dead Target] = CASE 
									WHEN T.[Dead_Target] = 0 THEN 0
									WHEN Z.GovernorID = S.GovernorID THEN ROUND((S.DeadsDelta * 0.1) / T.[Dead_Target] * 100, 2)
									ELSE ROUND(S.DeadsDelta * 1.0 / T.[Dead_Target] * 100, 2)
								END,   
              Z.Zeroed,
              D.[DKP_Score],
              DKP_Target = CASE WHEN COALESCE(T.[Kill_Target],0) = 0 THEN 0
                                ELSE (T.Kill_Target * 3 + COALESCE(T.Dead_Target,0) * 8) END,
              DKP_Target_Pct = CASE
                                 WHEN COALESCE(T.[Kill_Target],0) = 0 THEN 0
                                 ELSE ROUND(D.[DKP_Score] * 1.0 / NULLIF(T.[Kill_Target] * 3 + COALESCE(T.[Dead_Target],0) * 8, 0) * 100, 2)
                               END,
              [% of DKP Target] = CASE
                                 WHEN COALESCE(T.[Kill_Target],0) = 0 THEN 0
                                 ELSE ROUND(D.[DKP_Score] * 1.0 / NULLIF(T.[Kill_Target] * 3 + COALESCE(T.[Dead_Target],0) * 8, 0) * 100, 2)
                               END,
              S.[HelpsDelta]                                      AS [Helps],
              S.[RSSASSISTDelta]                                  AS [RSS_Assist],
              S.[RSSGatheredDelta]                                AS [RSS_Gathered],
              S.[P4T4&T5_KillsDelta]                              AS [Pass 4 Kills],
              S.[P6T4&T5_KillsDelta]                              AS [Pass 6 Kills],
              S.[P7T4&T5_KillsDelta]                              AS [Pass 7 Kills],
              S.[P8T4&T5_KillsDelta]                              AS [Pass 8 Kills],
              S.P4DeadsDelta                                      AS [Pass 4 Deads],
              S.P6DeadsDelta                                      AS [Pass 6 Deads],
              S.P7DeadsDelta                                      AS [Pass 7 Deads],
              S.P8DeadsDelta                                      AS [Pass 8 Deads],
              ' + CAST(@CURRENTKVK3 AS nvarchar(10)) + N'          AS [KVK_NO]
          INTO EXCEL_FOR_KVK_' + CAST(@CURRENTKVK3 AS nvarchar(10)) + N'
          FROM dbo.STAGING_STATS AS S
          LEFT JOIN #HD1 AS HD
            ON S.GovernorID = HD.GovernorID
          LEFT JOIN TARGETS_' + CAST(@CURRENTKVK3 AS nvarchar(10)) + N' AS T
            ON T.GovernorID = S.GovernorID
          LEFT JOIN #DKP AS D
            ON D.GovernorID = S.GovernorID
          LEFT JOIN dbo.ZEROED AS Z
            ON Z.GovernorID = S.GovernorID
           AND Z.ScanOrder  = ' + CAST(@MATCHMAKING_SCAN AS nvarchar(20)) + N'
          ORDER BY [Rank] ASC;';

        EXEC sp_executesql @sql;

        EXEC dbo.sp_Maintain_PlayerKVKHistory @KVK_NO = @CURRENTKVK3;

        DROP TABLE IF EXISTS #DKP, #HD1;

        PRINT 'Completed KVK ' + CAST(@CURRENTKVK3 AS varchar(12)) + ' at ' + CONVERT(varchar(19), GETDATE(), 120);

        FETCH NEXT FROM kvk_cursor_loop INTO @KVKVersion;
    END

    CLOSE kvk_cursor_loop;
    DEALLOCATE kvk_cursor_loop;
END

