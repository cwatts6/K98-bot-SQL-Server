SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_Stats_for_Upload]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[SP_Stats_for_Upload] AS' 
END
ALTER PROCEDURE [dbo].[SP_Stats_for_Upload]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @LatestKVK INT,
        @MaxScan FLOAT,
        @TableName NVARCHAR(100),
        @sql NVARCHAR(MAX);

    -- Step 1: Get max scan value
    SELECT @MaxScan = MAX(SCANORDER)
    FROM KingdomScanData4;

    -- Step 2: Get latest eligible KVKVersion
    SELECT TOP 1 @LatestKVK = KVKVersion
    FROM ProcConfig
    WHERE ConfigKey = 'MATCHMAKING_SCAN'
      AND TRY_CAST(ConfigValue AS FLOAT) <= @MaxScan
    ORDER BY KVKVersion DESC;

    -- Step 3: Build table name dynamically
    SET @TableName = QUOTENAME('EXCEL_FOR_KVK_' + CAST(@LatestKVK AS NVARCHAR(10)));

    -- Step 4: Build dynamic SQL for insert (explicit column list to avoid misalignment)
    SET @sql = '
    TRUNCATE TABLE STATS_FOR_UPLOAD;

    DECLARE @MaxScan AS FLOAT = (SELECT MAX(SCANORDER) FROM KingdomScanData4),
            @MAXDATE AS DATETIME = (SELECT MAX(ScanDate) FROM KingdomScanData4);

    DECLARE @X_KVK AS FLOAT = (
        SELECT TOP 1 TRY_CAST(KVKVersion AS FLOAT)
        FROM ProcConfig 
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CAST(ConfigValue AS FLOAT) <= @MaxScan
        ORDER BY KVKVersion DESC
    );

    INSERT INTO STATS_FOR_UPLOAD (
        [Rank],[KVK_RANK],[Governor ID],[Governor_Name],[Power],[Power Delta],
        [T4_Kills],[T5_Kills],[T4&T5_Kills],[OFF_SEASON_KILLS],[Kill Target],[% of Kill target],
        [Deads],[OFF_SEASON_DEADS],[T4_Deads],[T5_Deads],[Dead Target],[% of Dead Target],
        [Zeroed],[DKP_SCORE],[DKP Target],[% of DKP Target],[Helps],
        [RSS_Assist],[RSS_Gathered],[Pass 4 Kills],[Pass 6 Kills],[Pass7 Kills],[Pass 8 Kills],
        [Pass 4 Deads],[Pass 6 Deads],[Pass 7 Deads],[Pass 8 Deads],[KVK_NO],[LAST_REFRESH],[STATUS],
        [HealedTroops],[RangedPoints],[Civilization],[KvKPlayed],[MostKvKKill],[MostKvKDead],[MostKvKHeal],
        [Acclaim],[HighestAcclaim],[AOOJoined],[AOOWon],[AOOAvgKill],[AOOAvgDead],[AOOAvgHeal]
    )
    SELECT 
        [Rank],
        KVK_RANK,
        Gov_ID AS [Governor ID],
        RTRIM(Governor_Name) AS [Governor_Name],
        [Starting Power] AS [Power],
        ISNULL(Power_Delta, 0) AS [Power Delta],
        ISNULL(T4_KILLS, 0) AS [T4_Kills],
        ISNULL(T5_KILLS, 0) AS [T5_Kills],
        ISNULL([T4&T5_Kills], 0) AS [T4&T5_Kills],
        ISNULL(KILLS_OUTSIDE_KVK, 0) AS [OFF_SEASON_KILLS],
        ISNULL([Kill Target], 0) AS [Kill Target],
        ISNULL([% of Kill target], 0) AS [% of Kill target],
        ISNULL(Deads, 0) AS Deads,
        ISNULL(DEADS_OUTSIDE_KVK, 0) AS [OFF_SEASON_DEADS],
        ISNULL(T4_Deads, 0) AS T4_Deads,
        ISNULL(T5_Deads, 0) AS T5_Deads,
        ISNULL([Dead_Target], 0) AS [Dead Target],
        ISNULL([% of Dead Target], 0) AS [% of Dead Target],
        ISNULL(Zeroed, 0) AS Zeroed,
        ISNULL([DKP_Score], 0) AS [DKP_SCORE],
        ISNULL([DKP Target], 0) AS [DKP Target],
        ISNULL([% of DKP Target], 0) AS [% of DKP Target],
        ISNULL(HELPS, 0) AS Helps,
        ISNULL(RSS_Assist, 0) AS RSS_Assist,
        ISNULL(RSS_Gathered, 0) AS RSS_Gathered,
        ISNULL([Pass 4 Kills], 0) AS [Pass 4 Kills],
        ISNULL([Pass 6 Kills], 0) AS [Pass 6 Kills],
        ISNULL([Pass 7 Kills], 0) AS [Pass7 Kills],
        ISNULL([Pass 8 Kills], 0) AS [Pass 8 Kills],
        ISNULL([Pass 4 Deads], 0) AS [Pass 4 Deads],
        ISNULL([Pass 6 Deads], 0) AS [Pass 6 Deads],
        ISNULL([Pass 7 Deads], 0) AS [Pass 7 Deads],
        ISNULL([Pass 8 Deads], 0) AS [Pass 8 Deads],
        KVK_NO,
        CAST(@MAXDATE AS DATE) AS LAST_REFRESH,
        CASE 
            WHEN Gov_ID IN (
                SELECT GovernorID 
                FROM [ROK_TRACKER].[dbo].[EXEMPT_FROM_STATS] 
                WHERE KVK_NO IN (0, @X_KVK)
            ) THEN ''EXEMPT''
            ELSE ''INCLUDED''
        END AS STATUS,
        -- New metric columns (placed after STATUS)
        ISNULL([HealedTroops], 0) AS HealedTroops,
        ISNULL([RangedPoints], 0) AS RangedPoints,
        ISNULL([Civilization], '''') AS Civilization,
        ISNULL([KvKPlayed], 0) AS KvKPlayed,
        ISNULL([MostKvKKill], 0) AS MostKvKKill,
        ISNULL([MostKvKDead], 0) AS MostKvKDead,
        ISNULL([MostKvKHeal], 0) AS MostKvKHeal,
        ISNULL([Acclaim], 0) AS Acclaim,
        ISNULL([HighestAcclaim], 0) AS HighestAcclaim,
        ISNULL([AOOJoined], 0) AS AOOJoined,
        ISNULL([AOOWon], 0) AS AOOWon,
        ISNULL([AOOAvgKill], 0) AS AOOAvgKill,
        ISNULL([AOOAvgDead], 0) AS AOOAvgDead,
        ISNULL([AOOAvgHeal], 0) AS AOOAvgHeal
    FROM ' + @TableName + '
    ORDER BY [RANK] ASC;';

    -- Step 5: Execute the dynamic SQL
    EXEC sp_executesql @sql;
END;

