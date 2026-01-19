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
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    -- Rebuild THE_AVERAGES with explicit column mapping and safe handling
    ----------------------------------------------------------------

    TRUNCATE TABLE dbo.THE_AVERAGES;

    -- Build per-PowerRank, per-ScanDate base stats (exclude NULL ScanDate)
    SELECT 
        PowerRank,
        ScanDate,
        SCANORDER,
        ROUND(AVG([Power]), 0)       AS Power,
        ROUND(AVG([KillPoints]), 0)  AS KillPoints,
        ROUND(AVG([Deads]), 0)       AS Deads,
        ROUND(AVG([T1_Kills]), 0)    AS T1_Kills,
        ROUND(AVG([T2_Kills]), 0)    AS T2_Kills,
        ROUND(AVG([T3_Kills]), 0)    AS T3_Kills,
        ROUND(AVG([T4_Kills]), 0)    AS T4_Kills,
        ROUND(AVG([T5_Kills]), 0)    AS T5_Kills,
        ROUND(AVG([T4&T5_KILLS]), 0) AS [T4&T5_KILLS],
        ROUND(AVG([TOTAL_KILLS]), 0) AS TOTAL_KILLS,
        ROUND(AVG([RSS_Gathered]), 0)    AS RSS_Gathered,
        ROUND(AVG([RSSAssistance]), 0)   AS RSSAssistance,
        ROUND(AVG([Helps]), 0)           AS Helps,
        -- preserve raw AVG for Healed/Ranged so we can coalesce later
        AVG([HealedTroops])      AS Avg_HealedTroops,
        AVG([RangedPoints])      AS Avg_RangedPoints
    INTO #BaseStats
    FROM dbo.KingdomScanData4
    WHERE ScanDate IS NOT NULL
    GROUP BY PowerRank, ScanDate, SCANORDER;

    ----------------------------------------------------------------
    -- Insert Kingdom Average rows
    -- Map explicitly to THE_AVERAGES columns:
    -- [PowerRank],[GovernorName],[GovernorID],[Alliance],[Power],[KillPoints],[Deads],
    -- [T1_Kills],[T2_Kills],[T3_Kills],[T4_Kills],[T5_Kills],[T4&T5_KILLS],[TOTAL_KILLS],
    -- [RSS_Gathered],[RSSAssistance],[Helps],[ScanDate],[SCANORDER],[SCAN_UNO],[HealedTroops],[RangedPoints]
    ----------------------------------------------------------------
    INSERT INTO dbo.THE_AVERAGES (
        [PowerRank],[GovernorName],[GovernorID],[Alliance],
        [Power],[KillPoints],[Deads],
        [T1_Kills],[T2_Kills],[T3_Kills],[T4_Kills],[T5_Kills],[T4&T5_KILLS],[TOTAL_KILLS],
        [RSS_Gathered],[RSSAssistance],[Helps],
        [ScanDate],[SCANORDER],[SCAN_UNO],[HealedTroops],[RangedPoints]
    )
    SELECT
        175 AS PowerRank,
        'Kingdom Average' AS GovernorName,
        999999999 AS GovernorID,
        'TheAverages' AS Alliance,
        ROUND(AVG(Power),0)       AS Power,
        ROUND(AVG(KillPoints),0)  AS KillPoints,
        ROUND(AVG(Deads),0)       AS Deads,
        ROUND(AVG(T1_Kills),0)    AS T1_Kills,
        ROUND(AVG(T2_Kills),0)    AS T2_Kills,
        ROUND(AVG(T3_Kills),0)    AS T3_Kills,
        ROUND(AVG(T4_Kills),0)    AS T4_Kills,
        ROUND(AVG(T5_Kills),0)    AS T5_Kills,
        ROUND(AVG([T4&T5_KILLS]),0) AS [T4&T5_KILLS],
        ROUND(AVG(TOTAL_KILLS),0) AS TOTAL_KILLS,
        ROUND(AVG(RSS_Gathered),0) AS RSS_Gathered,
        ROUND(AVG(RSSAssistance),0) AS RSSAssistance,
        ROUND(AVG(Helps),0)       AS Helps,
        ScanDate,
        SCANORDER,
        999999999 AS SCAN_UNO,
        -- ensure numeric non-NULL: coalesce to 0
        ISNULL(ROUND(AVG(Avg_HealedTroops),0), 0)   AS HealedTroops,
        ISNULL(ROUND(AVG(Avg_RangedPoints),0), 0)   AS RangedPoints
    FROM #BaseStats
    GROUP BY ScanDate, SCANORDER;

    ----------------------------------------------------------------
    -- Insert Top50 aggregated rows
    ----------------------------------------------------------------
    INSERT INTO dbo.THE_AVERAGES (
        [PowerRank],[GovernorName],[GovernorID],[Alliance],
        [Power],[KillPoints],[Deads],
        [T1_Kills],[T2_Kills],[T3_Kills],[T4_Kills],[T5_Kills],[T4&T5_KILLS],[TOTAL_KILLS],
        [RSS_Gathered],[RSSAssistance],[Helps],
        [ScanDate],[SCANORDER],[SCAN_UNO],[HealedTroops],[RangedPoints]
    )
    SELECT
        50 AS PowerRank,
        'Top50' AS GovernorName,
        999999997 AS GovernorID,
        'TheAverages' AS Alliance,
        ROUND(AVG(Power),0)       AS Power,
        ROUND(AVG(KillPoints),0)  AS KillPoints,
        ROUND(AVG(Deads),0)       AS Deads,
        ROUND(AVG(T1_Kills),0)    AS T1_Kills,
        ROUND(AVG(T2_Kills),0)    AS T2_Kills,
        ROUND(AVG(T3_Kills),0)    AS T3_Kills,
        ROUND(AVG(T4_Kills),0)    AS T4_Kills,
        ROUND(AVG(T5_Kills),0)    AS T5_Kills,
        ROUND(AVG([T4&T5_KILLS]),0) AS [T4&T5_KILLS],
        ROUND(AVG(TOTAL_KILLS),0) AS TOTAL_KILLS,
        ROUND(AVG(RSS_Gathered),0) AS RSS_Gathered,
        ROUND(AVG(RSSAssistance),0) AS RSSAssistance,
        ROUND(AVG(Helps),0)       AS Helps,
        ScanDate,
        SCANORDER,
        999999997 AS SCAN_UNO,
        ISNULL(ROUND(AVG(Avg_HealedTroops),0), 0)   AS HealedTroops,
        ISNULL(ROUND(AVG(Avg_RangedPoints),0), 0)   AS RangedPoints
    FROM #BaseStats
    WHERE PowerRank <= 50
    GROUP BY ScanDate, SCANORDER;

    ----------------------------------------------------------------
    -- Insert Top100 aggregated rows
    ----------------------------------------------------------------
    INSERT INTO dbo.THE_AVERAGES (
        [PowerRank],[GovernorName],[GovernorID],[Alliance],
        [Power],[KillPoints],[Deads],
        [T1_Kills],[T2_Kills],[T3_Kills],[T4_Kills],[T5_Kills],[T4&T5_KILLS],[TOTAL_KILLS],
        [RSS_Gathered],[RSSAssistance],[Helps],
        [ScanDate],[SCANORDER],[SCAN_UNO],[HealedTroops],[RangedPoints]
    )
    SELECT
        100 AS PowerRank,
        'Top100' AS GovernorName,
        999999998 AS GovernorID,
        'TheAverages' AS Alliance,
        ROUND(AVG(Power),0)       AS Power,
        ROUND(AVG(KillPoints),0)  AS KillPoints,
        ROUND(AVG(Deads),0)       AS Deads,
        ROUND(AVG(T1_Kills),0)    AS T1_Kills,
        ROUND(AVG(T2_Kills),0)    AS T2_Kills,
        ROUND(AVG(T3_Kills),0)    AS T3_Kills,
        ROUND(AVG(T4_Kills),0)    AS T4_Kills,
        ROUND(AVG(T5_Kills),0)    AS T5_Kills,
        ROUND(AVG([T4&T5_KILLS]),0) AS [T4&T5_KILLS],
        ROUND(AVG(TOTAL_KILLS),0) AS TOTAL_KILLS,
        ROUND(AVG(RSS_Gathered),0) AS RSS_Gathered,
        ROUND(AVG(RSSAssistance),0) AS RSSAssistance,
        ROUND(AVG(Helps),0)       AS Helps,
        ScanDate,
        SCANORDER,
        999999998 AS SCAN_UNO,
        ISNULL(ROUND(AVG(Avg_HealedTroops),0), 0)   AS HealedTroops,
        ISNULL(ROUND(AVG(Avg_RangedPoints),0), 0)   AS RangedPoints
    FROM #BaseStats
    WHERE PowerRank <= 100
    GROUP BY ScanDate, SCANORDER;

    -- Cleanup
    DROP TABLE IF EXISTS #BaseStats;
END

