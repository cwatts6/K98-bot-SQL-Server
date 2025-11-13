SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CREATE_THE_AVERAGES]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CREATE_THE_AVERAGES] AS' 
END
ALTER PROCEDURE [dbo].[CREATE_THE_AVERAGES]
WITH EXECUTE AS CALLER
AS
BEGIN
  
TRUNCATE TABLE THE_AVERAGES;

-- Step 1: Create and populate the base aggregated data into a temp table
SELECT 
    PowerRank,
    ScanDate,
    SCANORDER,
    ROUND(AVG([Power]), 0) AS Power,
    ROUND(AVG([KillPoints]), 0) AS KillPoints,
    ROUND(AVG([Deads]), 0) AS Deads,
    ROUND(AVG([T1_Kills]), 0) AS T1_Kills,
    ROUND(AVG([T2_Kills]), 0) AS T2_Kills,
    ROUND(AVG([T3_Kills]), 0) AS T3_Kills,
    ROUND(AVG([T4_Kills]), 0) AS T4_Kills,
    ROUND(AVG([T5_Kills]), 0) AS T5_Kills,
    ROUND(AVG([T4&T5_KILLS]), 0) AS [T4&T5_Kills],
    ROUND(AVG([TOTAL_KILLS]), 0) AS TOTAL_KILLS,
    ROUND(AVG([RSS_Gathered]), 0) AS RSS_Gathered,
    ROUND(AVG([RSSAssistance]), 0) AS RSSAssistance,
    ROUND(AVG([Helps]), 0) AS Helps
INTO #BaseStats
FROM [ROK_TRACKER].[dbo].[KingdomScanData4]
GROUP BY PowerRank, ScanDate, SCANORDER;

-- Step 2: Insert Kingdom Average
INSERT INTO THE_AVERAGES
SELECT 
    '175' AS PowerRank,
    'Kingdom Average' AS GovernorName,
    '999999999' AS GovernorID,
    'TheAverages' AS Alliance,
ROUND(AVG([Power]), 0) AS [Power],
    ROUND(AVG([KillPoints]), 0) AS KillPoints,
    ROUND(AVG([Deads]), 0) AS Deads,
    ROUND(AVG([T1_Kills]), 0) AS T1_Kills,
    ROUND(AVG([T2_Kills]), 0) AS T2_Kills,
    ROUND(AVG([T3_Kills]), 0) AS T3_Kills,
    ROUND(AVG([T4_Kills]), 0) AS T4_Kills,
    ROUND(AVG([T5_Kills]), 0) AS T5_Kills,
    ROUND(AVG([T4&T5_KILLS]), 0) AS T4T5_Kills,
    ROUND(AVG([TOTAL_KILLS]), 0) AS TOTAL_KILLS,
    ROUND(AVG([RSS_Gathered]), 0) AS RSS_Gathered,
    ROUND(AVG([RSSAssistance]), 0) AS RSSAssistance,
    ROUND(AVG([Helps]), 0) AS Helps,
    ScanDate, SCANORDER,
    '999999999' AS SCAN_UNO
FROM #BaseStats
GROUP BY ScanDate, SCANORDER;

-- Step 3: Insert Top 50
INSERT INTO THE_AVERAGES
SELECT 
    '50' AS PowerRank,
    'Top50' AS GovernorName,
    '999999997' AS GovernorID,
    'TheAverages' AS Alliance,
ROUND(AVG([Power]), 0) AS [Power],
    ROUND(AVG([KillPoints]), 0) AS KillPoints,
    ROUND(AVG([Deads]), 0) AS Deads,
    ROUND(AVG([T1_Kills]), 0) AS T1_Kills,
    ROUND(AVG([T2_Kills]), 0) AS T2_Kills,
    ROUND(AVG([T3_Kills]), 0) AS T3_Kills,
    ROUND(AVG([T4_Kills]), 0) AS T4_Kills,
    ROUND(AVG([T5_Kills]), 0) AS T5_Kills,
    ROUND(AVG([T4&T5_KILLS]), 0) AS T4T5_Kills,
    ROUND(AVG([TOTAL_KILLS]), 0) AS TOTAL_KILLS,
    ROUND(AVG([RSS_Gathered]), 0) AS RSS_Gathered,
    ROUND(AVG([RSSAssistance]), 0) AS RSSAssistance,
    ROUND(AVG([Helps]), 0) AS Helps,
    ScanDate, SCANORDER,
    '999999999' AS SCAN_UNO
FROM #BaseStats
WHERE PowerRank <= 50
GROUP BY ScanDate, SCANORDER;

-- Step 4: Insert Top 100
INSERT INTO THE_AVERAGES
SELECT 
    '100' AS PowerRank,
    'Top100' AS GovernorName,
    '999999998' AS GovernorID,
    'TheAverages' AS Alliance,
ROUND(AVG([Power]), 0) AS [Power],
    ROUND(AVG([KillPoints]), 0) AS KillPoints,
    ROUND(AVG([Deads]), 0) AS Deads,
    ROUND(AVG([T1_Kills]), 0) AS T1_Kills,
    ROUND(AVG([T2_Kills]), 0) AS T2_Kills,
    ROUND(AVG([T3_Kills]), 0) AS T3_Kills,
    ROUND(AVG([T4_Kills]), 0) AS T4_Kills,
    ROUND(AVG([T5_Kills]), 0) AS T5_Kills,
    ROUND(AVG([T4&T5_KILLS]), 0) AS T4T5_Kills,
    ROUND(AVG([TOTAL_KILLS]), 0) AS TOTAL_KILLS,
    ROUND(AVG([RSS_Gathered]), 0) AS RSS_Gathered,
    ROUND(AVG([RSSAssistance]), 0) AS RSSAssistance,
    ROUND(AVG([Helps]), 0) AS Helps,
    ScanDate, SCANORDER,
    '999999999' AS SCAN_UNO
FROM #BaseStats
WHERE PowerRank <= 100
GROUP BY ScanDate, SCANORDER;

-- Step 5: Cleanup
DROP TABLE #BaseStats;



  END;
