SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CREATE_DASH2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CREATE_DASH2] AS' 
END
ALTER PROCEDURE [dbo].[CREATE_DASH2]
WITH EXECUTE AS CALLER
AS
BEGIN

-- Clear target table
TRUNCATE TABLE DASH;

-- Step 1: Create #RankingGroups temp table
IF OBJECT_ID('tempdb..#RankingGroups') IS NOT NULL DROP TABLE #RankingGroups;

SELECT DISTINCT KVK_NO, RankGroup, KVK_Rank_Max
INTO #RankingGroups
FROM (
    SELECT KVK_NO, '50' AS RankGroup, 50 AS KVK_Rank_Max FROM EXCEL_FOR_DASHBOARD
    UNION ALL
    SELECT KVK_NO, '100', 100 FROM EXCEL_FOR_DASHBOARD
    UNION ALL
    SELECT KVK_NO, '150', 150 FROM EXCEL_FOR_DASHBOARD
) AS t;

-- Step 2: Create #Aggregated temp table
IF OBJECT_ID('tempdb..#Aggregated') IS NOT NULL DROP TABLE #Aggregated;

SELECT
    rg.RankGroup AS [RANK],
    rg.RankGroup AS [KVK_RANK],
    CASE rg.RankGroup
        WHEN '50' THEN '999999997'
        WHEN '100' THEN '999999998'
        WHEN '150' THEN '999999999'
    END AS [Gov_ID],
    CASE rg.RankGroup
        WHEN '50' THEN 'Top50'
        WHEN '100' THEN 'Top100'
        WHEN '150' THEN 'Kingdom Average'
    END AS [Governor_Name],
    ROUND(AVG(CAST([Starting POWER] AS FLOAT)), 0) AS [Starting Power],
	ROUND(AVG(CAST([T4_Kills] AS FLOAT)), 0) AS [T4_Kills],
	ROUND(AVG(CAST([T5_Kills] AS FLOAT)), 0) AS [T5_Kills],
	ROUND(AVG(CAST([T4&T5_Kills] AS FLOAT)), 0) AS [T4&T5_Kills],
	ROUND(AVG(CAST([Kill Target] AS FLOAT)), 0) AS [Kill Target],
	ROUND(AVG(CAST([% of Kill target] AS FLOAT)), 0) AS [% of Kill target],
	ROUND(AVG(CAST([Deads] AS FLOAT)), 0) AS [Deads],
	ROUND(AVG(CAST([T4_Deads] AS FLOAT)), 0) AS [T4_Deads],
	ROUND(AVG(CAST([T5_Deads] AS FLOAT)), 0) AS [T5_Deads],
	ROUND(AVG(CAST([Dead_Target] AS FLOAT)), 0) AS [Dead_Target],
    ROUND(AVG(CAST([% of Dead_Target] AS FLOAT)), 0) AS [% of Dead_Target],
    ed.KVK_NO,
    ROUND(AVG(CAST([Pass 4 Kills] AS FLOAT)), 0) AS [Pass 4 Kills],
	ROUND(AVG(CAST([Pass 6 Kills] AS FLOAT)), 0) AS [Pass 6 Kills],
	ROUND(AVG(CAST([Pass 7 Kills] AS FLOAT)), 0) AS [Pass 7 Kills],
	ROUND(AVG(CAST([Pass 8 Kills] AS FLOAT)), 0) AS [Pass 8 Kills],
	ROUND(AVG(CAST([POWER_DELTA] AS FLOAT)), 0) AS [POWER_DELTA],
	ROUND(AVG(CAST([DKP_Score] AS FLOAT)), 0) AS [DKP_Score],
	ROUND(AVG(CAST([DKP Target] AS FLOAT)), 0) AS [DKP Target],
	ROUND(AVG(CAST([% of DKP Target] AS FLOAT)), 0) AS [% of DKP Target]
INTO #Aggregated
FROM #RankingGroups rg
JOIN EXCEL_FOR_DASHBOARD ed
    ON ed.KVK_NO = rg.KVK_NO
   AND ed.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
GROUP BY rg.RankGroup, ed.KVK_NO;

-- Step 3: Insert into DASH
INSERT INTO DASH (
    [RANK], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [T4_Kills], [T5_Kills], [T4&T5_Kills],
    [Kill Target], [% of Kill target], [Deads], [T4_Deads],
    [T5_Deads], [Dead_Target], [% of Dead_Target], [KVK_NO],
    [Pass 4 Kills], [Pass 6 Kills], [Pass 7 Kills], [Pass 8 Kills],
    [POWER_DELTA], [DKP_Score], [DKP Target], [% of DKP Target]
)
SELECT *
FROM #Aggregated;

-- Step 4: Insert into EXCEL_FOR_DASHBOARD from DASH
INSERT INTO EXCEL_FOR_DASHBOARD (
    [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [Power_Delta], [T4_KILLS], [T5_KILLS],
    [T4&T5_Kills], [Kill Target], [% of Kill target],
    [Deads], [T4_Deads], [T5_Deads], [Dead_Target],
    [% of Dead_Target], [DKP_Score], [DKP Target],
    [% of DKP Target], [Pass 4 Kills], [Pass 6 Kills],
    [Pass 7 Kills], [Pass 8 Kills], [KVK_NO]
)
SELECT 
    [RANK], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [POWER_DELTA], [T4_Kills], [T5_Kills],
    [T4&T5_Kills], [Kill Target], [% of Kill target],
    [Deads], [T4_Deads], [T5_Deads], [Dead_Target],
    [% of Dead_Target], [DKP_Score], [DKP Target],
    [% of DKP Target], [Pass 4 Kills], [Pass 6 Kills],
    [Pass 7 Kills], [Pass 8 Kills], [KVK_NO]
FROM DASH;

-- Cleanup temp tables
DROP TABLE IF EXISTS #RankingGroups;
DROP TABLE IF EXISTS #Aggregated;

 END;
 
