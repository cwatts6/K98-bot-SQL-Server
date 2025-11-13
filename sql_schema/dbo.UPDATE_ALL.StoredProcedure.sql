SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL] AS' 
END
ALTER PROCEDURE [dbo].[UPDATE_ALL]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;

    BEGIN TRY
        BEGIN TRANSACTION;

		DECLARE @actual_param1 FLOAT = ISNULL(@param1, (SELECT TOP 1 KINGDOM_RANK FROM KS));
		DECLARE @actual_param2 NVARCHAR(100) = ISNULL(@param2, (SELECT TOP 1 KINGDOM_SEED FROM KS));
		DECLARE @StartTime DATETIME = GETDATE();

		

        DECLARE 
            @MATHCHMAKING_SCAN FLOAT = 148,
            @MAXSCAN FLOAT = (SELECT MAX(SCANORDER) FROM KingdomScanData4),
            @PRE_PASS_4_SCAN FLOAT = 156,
            @KVK_END_SCAN FLOAT = 171,
            @PASS4END FLOAT = 161,
            @PASS6END FLOAT = 167,
            @PASS7END FLOAT = 170,
            @LASTKVKEND FLOAT = 146,
            @CURRENTKVK3 FLOAT = 11;
            --@KINGDOMRANK FLOAT = 1099,
            --@KINGDOMSEED NVARCHAR(20) = 'C Seed';
       

        -- Step 1: Refresh latest data
        EXEC UPDATE_RALLY_DATA;
        EXEC IMPORT_STAGING_PROC;

        -- Step 2: Insert into KingdomScanData5
        INSERT INTO KingdomScanData5 (PowerRank, GovernorName, GovernorID, Alliance, Power, KillPoints, Deads,
                                      T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS,
                                      Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER, [Troops Power], 
                                      [City Hall], [Tech Power], [Building Power], [Commander Power])
        SELECT ROW_NUMBER() OVER (ORDER BY [Power] DESC),
               RTRIM([Name]), [Governor ID], [Alliance], [Power], [Total Kill Points], [Dead Troops],
               [T1-Kills], [T2-Kills], [T3-Kills], [T4-Kills], [T5-Kills], [Kills (T4+)], [KILLS],
               [RSS Gathered], [RSS Assistance], [Alliance Helps], [ScanDate], [SCANORDER],
               [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
        FROM IMPORT_STAGING;

     
		-- Step 3: Copy to KingdomScanData4 only if SCANORDER is greater
		IF (
			SELECT MAX(SCANORDER) FROM KingdomScanData5
		) > (
			SELECT ISNULL(MAX(SCANORDER), 0) FROM KingdomScanData4
		)
		BEGIN
			INSERT INTO KingdomScanData4
			SELECT *
			FROM KingdomScanData5 
			WHERE SCANORDER = (SELECT MAX(SCANORDER) FROM KingdomScanData5);
		END

		

        -- Step 4: Truncate staging
        TRUNCATE TABLE IMPORT_STAGING;

		-- Step 4a: Creat Target Table--
		EXEC dbo.TARGETS;
		--EXEC dbo.TARGETS @InputScanOrder = @MATHCHMAKING_SCAN;

        -- Step 5: Create delta tables
        EXEC CREATE_DELTA_TABLES;

		-- Drop final staging table if it exists
		TRUNCATE TABLE STAGING_STATS;

		-----------------------------------------------
-- 1. Consolidated Deads Delta
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN DeadsDelta ELSE 0 END) AS DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @LASTKVKEND AND DeltaOrder <= @PRE_PASS_4_SCAN THEN DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN DeadsDelta ELSE 0 END) AS P4DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS4END AND DeltaOrder <= @PASS6END THEN DeadsDelta ELSE 0 END) AS P6DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS6END AND DeltaOrder <= @PASS7END THEN DeadsDelta ELSE 0 END) AS P7DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS7END AND DeltaOrder <= @KVK_END_SCAN THEN DeadsDelta ELSE 0 END) AS P8DeadsDelta
INTO #Deads
FROM ROK_TRACKER.dbo.DeadsDelta
WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 2. Consolidated Kills Delta (T4&T5)
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
    SUM(CASE WHEN DeltaOrder > @LASTKVKEND AND DeltaOrder <= @PRE_PASS_4_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
    SUM(CASE WHEN DeltaOrder > @PASS4END AND DeltaOrder <= @PASS6END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
    SUM(CASE WHEN DeltaOrder > @PASS6END AND DeltaOrder <= @PASS7END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
    SUM(CASE WHEN DeltaOrder > @PASS7END AND DeltaOrder <= @KVK_END_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
INTO #Kills
FROM ROK_TRACKER.dbo.T4T5KillDelta
WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 3. Consolidated T4/T5 Kills
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(COALESCE(T4KILLSDelta, 0)) AS T4KillsDelta
INTO #KillsT4
FROM ROK_TRACKER.dbo.T4KillDelta
WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(T5KILLSDelta, 0)) AS T5KillsDelta
INTO #KillsT5
FROM ROK_TRACKER.dbo.T5KillDelta
WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 4. Other Delta Metrics (RSS, Helps, Power)
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(COALESCE(HelpsDelta, 0)) AS HelpsDelta
INTO #Helps
FROM ROK_TRACKER.dbo.HelpsDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(RSSASSISTDelta, 0)) AS RSSAssistDelta
INTO #RSSAssist
FROM ROK_TRACKER.dbo.RSSASSISTDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(RSSGatheredDelta, 0)) AS RSSGatheredDelta
INTO #RSSGathered
FROM ROK_TRACKER.dbo.RSSGatheredDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(Power_Delta, 0)) AS PowerDelta
INTO #Power
FROM ROK_TRACKER.dbo.PowerDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 5. Latest Snapshot of Governors
-----------------------------------------------
SELECT 
    GovernorID,
    GovernorName,
    PowerRank,
    [Power]
INTO #Snapshot
FROM KingdomScanData4
WHERE SCANORDER = @MATHCHMAKING_SCAN;

-----------------------------------------------
-- 6. Final Join to Staging Table
-----------------------------------------------
INSERT INTO STAGING_STATS
SELECT 
    s.GovernorID,
    s.PowerRank,
    s.[Power],
    p.PowerDelta,
    s.GovernorName,
    kt4.T4KillsDelta,
    kt5.T5KillsDelta,
    k.T4T5KillsDelta AS [T4&T5_KILLSDelta],
    k.KillsOutsideKVK AS [KILLS_OUTSIDE_KVK],
    k.P4Kills AS [P4T4&T5_KILLSDelta],
	k.P6Kills AS [P6T4&T5_KillsDelta],
	k.P7Kills AS [P7T4&T5_KillsDelta], 
	k.P8Kills AS [P8T4&T5_KillsDelta],
    d.DeadsDelta,
    d.DeadsDeltaOutKVK AS [DEADS_OUTSIDE_KVK],
    d.P4DeadsDelta,
	d.P6DeadsDelta,
	d.P7DeadsDelta,
	d.P8DeadsDelta,
    h.HelpsDelta,
    ra.RSSAssistDelta,
    rg.RSSGatheredDelta
FROM #Snapshot s
LEFT JOIN #Power p ON p.GovernorID = s.GovernorID
LEFT JOIN #KillsT4 kt4 ON kt4.GovernorID = s.GovernorID
LEFT JOIN #KillsT5 kt5 ON kt5.GovernorID = s.GovernorID
LEFT JOIN #Kills k ON k.GovernorID = s.GovernorID
LEFT JOIN #Deads d ON d.GovernorID = s.GovernorID
LEFT JOIN #Helps h ON h.GovernorID = s.GovernorID
LEFT JOIN #RSSAssist ra ON ra.GovernorID = s.GovernorID
LEFT JOIN #RSSGathered rg ON rg.GovernorID = s.GovernorID
WHERE s.GovernorID IS NOT NULL
ORDER BY s.PowerRank;

-----------------------------------------------
-- 7. Cleanup
-----------------------------------------------
DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot;

SELECT  S1.[GovernorID],
		CASE WHEN z.GovernorID = s1.GovernorID
		THEN ROUND ((S1.[T4&T5_KILLSDelta]*3 + (S1.[DeadsDelta] * 0.1) *8) ,0)
		ELSE ROUND ((S1.[T4&T5_KILLSDelta]*3 + S1.[DeadsDelta] *8) ,0)
		END AS [DKP_Score]
		INTO #DKP
		FROM [ROK_TRACKER].[dbo].[STAGING_STATS] AS S1
	 LEFT JOIN ZEROED AS Z ON z.GovernorID=S1.GovernorID AND ScanOrder = @MATHCHMAKING_SCAN 

SELECT GovernorID, MAX(T4_Deads) as [T4 Deads], MAX (T5_Deads) AS [T5 Deads], MAX(KVK_START_SCANORDER) AS SCANORDER 
INTO #HD1
FROM HoH_Deads 
GROUP BY GovernorID

  DROP TABLE EXCEL_FOR_CURRENT_KVK

SELECT	TOP (5000)
		S.[PowerRank] AS [Rank],
		ROW_NUMBER() OVER (ORDER BY D.[DKP_Score] DESC) AS [KVK_RANK]
		,S.[GovernorID] AS Gov_ID
		,S.[GovernorName] AS [Governor_Name]
		,S.[Power] AS [Starting Power]
		,S.Power_Delta
		,s.T4KillsDelta AS [T4_KILLS]
		,s.T5KillsDelta AS [T5_KILLS]
		,S.[T4&T5_KILLSDelta] AS [T4&T5_Kills]
		,S.KILLS_OUTSIDE_KVK
		,t.[Kill Target] AS [Kill Target]
		,CASE WHEN t.[Kill Target]  = 0
				THEN 0
				ELSE ROUND(s.[T4&T5_KILLSDelta]/t.[Kill Target]  * 100, 2) 
				END AS [% of Kill target]
		,s.[DeadsDelta] AS Deads
		,s.DEADS_OUTSIDE_KVK
		,COALESCE(HD.[T4 Deads],0) AS T4_Deads
		,COALESCE(HD.[T5 Deads],0) AS T5_Deads
		,t.[Dead Target] AS [Dead Target]
		
		,CASE WHEN t.[Dead Target] = 0
			THEN 0
			WHEN z.GovernorID = s.GovernorID
			THEN ROUND((s.DeadsDelta * 0.1)/t.[Dead Target] *100, 2) 
			ELSE ROUND(s.DeadsDelta/t.[Dead Target] *100, 2) 
			END AS [% of Dead Target]
			,z.Zeroed
		,D.[DKP_SCORE]
		,t.[DKP TARGET] AS [DKP Target]
		,CASE WHEN t.[Kill Target] = 0
				THEN 0
				WHEN z.GovernorID = s.GovernorID
				THEN ROUND( (D.[DKP_SCORE] / (t.[Kill Target]  * 3 + (t.[Dead Target] * 8)) *100) ,2)
				ELSE ROUND( (D.[DKP_SCORE] / (t.[Kill Target]  * 3 + (t.[Dead Target] * 8)) *100) ,2)
				END AS [% of DKP Target]
		,S.[HelpsDelta] AS Helps
		,S.[RSSASSISTDelta] AS RSS_Assist
		,S.[RSSGatheredDelta] AS RSS_Gathered
		,S.[P4T4&T5_KillsDelta] AS [Pass 4 Kills]
	  ,[P6T4&T5_KillsDelta] AS [Pass 6 Kills]
	  ,[P7T4&T5_KillsDelta] AS [Pass 7 Kills]
	  ,[P8T4&T5_KillsDelta] AS [Pass 8 Kills]
	  ,P4DeadsDelta AS [Pass 4 Deads]
	  ,P6DeadsDelta AS [Pass 6 Deads]
	  ,P7DeadsDelta AS [Pass 7 Deads]
	  ,P8DeadsDelta AS [Pass 8 Deads]
	  ,@CURRENTKVK3 AS [KVK_NO]
	  INTO EXCEL_FOR_CURRENT_KVK
	  --INTO EXCEL_FOR_JAN25_KVK
  FROM [ROK_TRACKER].[dbo].[STAGING_STATS] AS S
  LEFT JOIN #HD1 AS HD on S.GovernorID=HD.GovernorID
  JOIN EXCEL_OUTPUT_KVK_TARGETS_MAR25 AS T ON T.gov_id=S.Governorid
  LEFT JOIN #DKP AS D on D.GovernorID=S.Governorid
  LEFT JOIN ZEROED AS Z ON z.GovernorID=S.GovernorID AND Z.ScanOrder = @MATHCHMAKING_SCAN 
  ORDER BY PowerRank ASC

EXEC CREATE_THE_AVERAGES 

DROP TABLE #DKP, #HD1, EXCEL_FOR_DASHBOARD

SELECT TOP (5000000) * INTO EXCEL_FOR_DASHBOARD FROM

( SELECT * 
  FROM EXCEL_FOR_CURRENT_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_JAN25_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_SEPT24_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_MAY24_KVK
  UNION
  SELECT * 
  FROM  EXCEL_FOR_FEB24_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_OCT23_KVK
  UNION 
  SELECT * 
  FROM EXCEL_FOR_JUL23_KVK) AS T
ORDER BY KVK_NO, [RANK]

EXEC CREATE_DASH

---- OUTPUT NUMBER 1 = KVK STATS ----
DECLARE
@MAXDATE AS DATETIME = (SELECT MAX(ScanDate) FROM KingdomScanData4)

--DROP TABLE STATS_FOR_UPLOAD

TRUNCATE TABLE STATS_FOR_UPLOAD

INSERT INTO STATS_FOR_UPLOAD
SELECT 
[Rank], KVK_RANK, Gov_ID AS [Governor ID], RTRIM(Governor_Name) AS [Governor_Name], [Starting Power] AS [Power], ISNULL(Power_Delta, 0) AS [Power Delta] , ISNULL(T4_KILLS, 0) T4_Kills, ISNULL(T5_KILLS, 0) T5_Kills,
ISNULL([T4&T5_Kills],0) [T4&T5_Kills], KILLS_OUTSIDE_KVK AS [OFF_SEASON_KILLS], [Kill Target], ISNULL([% of Kill target], 0) [% of Kill target], ISNULL(Deads, 0) Deads, DEADS_OUTSIDE_KVK AS [OFF_SEASON_DEADS],
T4_Deads, T5_Deads, [Dead Target], ISNULL([% of Dead Target], 0) [% of Dead Target], ISNULL(Zeroed, 0) Zeroed, ISNULL([DKP_Score], 0) [DKP_SCORE], [DKP Target],
ISNULL([% of DKP Target], 0) [% of DKP Target], ISNULL(HELPS, 0) Helps, ISNULL(RSS_Assist, 0) RSS_Assist, ISNULL(RSS_Gathered, 0 ) RSS_Gathered, 
ISNULL([Pass 4 Kills], 0) [Pass 4 Kills], ISNULL([Pass 6 Kills], 0) [Pass 6 Kills], ISNULL([Pass 7 Kills], 0) [Pass7 Kills], ISNULL([Pass 8 Kills], 0) [Pass 8 Kills],
ISNULL([Pass 4 Deads], 0) [Pass 4 Deads], ISNULL([Pass 6 Deads], 0) [Pass 6 Deads], ISNULL([Pass 7 Deads], 0) [Pass 7 Deads], ISNULL([Pass 8 Deads], 0) [Pass 8 Deads], KVK_NO, CAST(@MAXDATE AS DATE) AS LAST_REFRESH
--INTO STATS_FOR_UPLOAD
FROM EXCEL_FOR_CURRENT_KVK 
WHERE Gov_ID <> 12025033
ORDER BY [RANK] ASC;

--SELECT * FROM STATS_FOR_UPLOAD

---- OUTPUT NUMBER 2 = ALL STATS FOR DASHBOARD ----

TRUNCATE TABLE ALL_STATS_FOR_DASHBAORD

INSERT INTO ALL_STATS_FOR_DASHBAORD
SELECT  [Rank]
      ,[KVK_RANK]
      ,[Gov_ID]
      ,ISNULL(RTRIM(Governor_Name), '') [Governor_Name]
      ,[Starting Power]
      ,ISNULL([Power_Delta], 0) [Power_Delta]
	  ,ISNULL(T4_Kills, 0) T4_Kills
	  ,ISNULL(T5_Kills, 0) T5_Kills
      ,ISNULL([T4&T5_Kills], 0) [T4&T5_Kills]
      ,ISNULL([Kill Target], 0) [Kill Target]
      ,ISNULL([% of Kill target], 0) [% of Kill target]
      ,ISNULL([Deads], 0) [Deads]
	  ,ISNULL(T4_Deads, 0) T4_Deads
	  ,ISNULL(T5_Deads, 0) T5_Deads
      ,ISNULL([Dead Target], 0) [Dead Target]
      ,ISNULL([% of Dead Target], 0) [% of Dead Target]
      ,ISNULL([Zeroed], 0) [Zeroed]
      ,isnull([DKP_SCORE], 0) [DKP_SCORE]
      ,isnull([DKP Target], 0) [DKP Target]
      ,ISNULL([% of DKP Target], 0) [% of DKP Target]
      ,isnull([Helps], 0) [Helps]
      ,isnull([RSS_Assist], 0) [RSS_Assist]
      ,ISNULL([RSS_Gathered], 0) [RSS_Gathered]
      ,ISNULL([Pass 4 Kills], 0) [Pass 4 Kills]
	  ,ISNULL([Pass 6 Kills], 0) [Pass 6 Kills]
	  ,ISNULL([Pass 7 Kills], 0) [Pass 7 Kills]
	  ,ISNULL([Pass 8 Kills], 0) [Pass 8 Kills]
      ,ISNULL([Pass 4 Deads], 0) [Pass 4 Deads]
	  ,ISNULL([Pass 6 Deads], 0) [Pass 6 Deads]
	  ,ISNULL([Pass 7 Deads], 0) [Pass 7 Deads]
	  ,ISNULL([Pass 8 Deads], 0) [Pass 8 Deads]
      ,[KVK_NO]

  FROM [ROK_TRACKER].[dbo].[EXCEL_FOR_DASHBOARD]
  WHERE Gov_ID <> 12025033

  --SELECT * FROM ALL_STATS_FOR_DASHBAORD

 ---- OUTPUT NUMBER 3 = POWER BY MONTH ---- 
 TRUNCATE TABLE POWER_BY_MONTH
 
 INSERT INTO POWER_BY_MONTH
 SELECT TOP (5000000) * 

 FROM (
 
SELECT GovernorID, RTRIM(GovernorName) AS [GovernorName] ,MAX([Power]) AS 'POWER', MAX(KillPoints) AS KILLPOINTS, MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, EOMONTH(ScanDate) AS [MONTH]
FROM  KingdomScanData4
WHERE GovernorID NOT IN (0, 12025033)
GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

UNION

SELECT GovernorID, RTRIM(GovernorName) AS [GovernorName], MAX([Power]) AS 'POWER', MAX(KillPoints) AS KILLPOINTS, MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, EOMONTH(ScanDate) AS [MONTH]
FROM THE_AVERAGES
GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)) AS T
ORDER BY GovernorID, [MONTH];

--SELECT * FROM POWER_BY_MONTH

EXEC sp_RefreshInactiveGovernors

TRUNCATE TABLE [KS]

--DECLARE
--@MAXDATE AS DATETIME = (SELECT MAX(ScanDate) FROM KingdomScanData4)

--DROP TABLE IF EXISTS [KS]

INSERT INTO [KS]
SELECT SUM(CAST([Power] AS BIGINT)) AS KINGDOM_POWER, 
COUNT(GovernorID) AS Governors,
SUM([KillPoints]) AS KP,
SUM([TOTAL_KILLS]) as [KILL],
SUM([DEADS]) AS [DEAD],
@MAXDATE AS [Last Update],
--'1554' AS KINGDOM_RANK,
@actual_param1 AS KINGDOM_RANK,
--'C' AS KINGDOM_SEED
@actual_param2 AS KINGDOM_SEED
--INTO [KS]
FROM KingdomScanData4
WHERE ScanDate = @MAXDATE

--SELECT * FROM [KS]

EXEC SUMMARY_PROC

EXEC GOVERNOR_NAMES_PROC

DECLARE @EndTime DATETIME = GETDATE();
DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);

INSERT INTO SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
VALUES (
    'UPDATE_ALL',
    'Complete',
    @EndTime,
    ISNULL((SELECT MAX(LastRunCounter) FROM SP_TaskStatus WHERE TaskName = 'UPDATE_ALL'), 0) + 1,
    @DurationSeconds
);

SET ANSI_WARNINGS ON;

        COMMIT;

		INSERT INTO Update_ALL_Complete (CompletionTime)
		VALUES (GETDATE());


    END TRY
    BEGIN CATCH
        ROLLBACK;
        SET ANSI_WARNINGS ON;
        THROW;
    END CATCH
END;

