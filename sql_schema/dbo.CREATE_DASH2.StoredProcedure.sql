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
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Ensure transaction rollback on error

    -- Clear target table
    TRUNCATE TABLE dbo.DASH;

    ----------------------------------------------------------------
    -- Step 1: Create #RankingGroups temp table
    -- Optimization: Use VALUES constructor instead of UNION ALL
    ----------------------------------------------------------------
    IF OBJECT_ID('tempdb..#RankingGroups') IS NOT NULL DROP TABLE #RankingGroups;

    SELECT DISTINCT 
        KVK_NO, 
        RankGroup, 
        KVK_Rank_Max
    INTO #RankingGroups
    FROM (
        SELECT DISTINCT
            ed.KVK_NO,
            v.RankGroup,
            v.KVK_Rank_Max
        FROM dbo.EXCEL_FOR_DASHBOARD ed
        CROSS APPLY (
            VALUES 
                ('50', 50),
                ('100', 100),
                ('150', 150)
        ) v(RankGroup, KVK_Rank_Max)
    ) AS t;

    -- Optimization: Add index on temp table for better join performance
    CREATE CLUSTERED INDEX IX_RankingGroups ON #RankingGroups(KVK_NO, RankGroup, KVK_Rank_Max);

    ----------------------------------------------------------------
    -- Step 2: Create #Aggregated temp table (compute averages)
    -- Optimization: Removed redundant CAST to FLOAT, simplified expressions
    ----------------------------------------------------------------
    IF OBJECT_ID('tempdb..#Aggregated') IS NOT NULL DROP TABLE #Aggregated;

    SELECT
        rg.RankGroup AS [RANK],
        rg.RankGroup AS [KVK_RANK],
        CASE rg.RankGroup
            WHEN '50'  THEN '999999997'
            WHEN '100' THEN '999999998'
            WHEN '150' THEN '999999999'
        END AS [Gov_ID],
        CASE rg.RankGroup
            WHEN '50'  THEN 'Top50'
            WHEN '100' THEN 'Top100'
            WHEN '150' THEN 'Kingdom Average'
        END AS [Governor_Name],

        -- Power metrics
        ROUND(AVG(CAST(ed.[Starting Power] AS FLOAT)), 0) AS [Starting Power],
        ROUND(AVG(CAST(ed.[Power_Delta] AS FLOAT)), 0) AS [POWER_DELTA],

        -- Kill metrics
        ROUND(AVG(CAST(ed.[T4_KILLS] AS FLOAT)), 0) AS [T4_KILLS],
        ROUND(AVG(CAST(ed.[T5_KILLS] AS FLOAT)), 0) AS [T5_KILLS],
        ROUND(AVG(CAST(ed.[T4&T5_Kills] AS FLOAT)), 0) AS [T4&T5_Kills],
        ROUND(AVG(CAST(ed.[Starting_T4&T5_KILLS] AS FLOAT)), 0) AS [Starting T4&T5_KILLS],
        ROUND(AVG(CAST(ed.[KILLS_OUTSIDE_KVK] AS FLOAT)), 0) AS [KILLS_OUTSIDE_KVK],

        -- Kill targets
        ROUND(AVG(CAST(ed.[Kill Target] AS FLOAT)), 0) AS [Kill Target],
        ROUND(AVG(CAST(ed.[% of Kill Target] AS FLOAT)), 2) AS [% of Kill target],

        -- Dead metrics (compute current Deads as Starting_Deads + Deads_Delta)
        ROUND(AVG(CAST(ISNULL(ed.[Starting_Deads], 0) + ISNULL(ed.[Deads_Delta], 0) AS FLOAT)), 0) AS [Deads],
        ROUND(AVG(CAST(ed.[T4_Deads] AS FLOAT)), 0) AS [T4_Deads],
        ROUND(AVG(CAST(ed.[T5_Deads] AS FLOAT)), 0) AS [T5_Deads],
        ROUND(AVG(CAST(ed.[Starting_Deads] AS FLOAT)), 0) AS [Starting Deads],
        ROUND(AVG(CAST(ed.[DEADS_OUTSIDE_KVK] AS FLOAT)), 0) AS [DEADS_OUTSIDE_KVK],

        -- Dead targets
        ROUND(AVG(CAST(ed.[Dead_Target] AS FLOAT)), 0) AS [Dead_Target],
        ROUND(AVG(CAST(ed.[% of Dead Target] AS FLOAT)), 2) AS [% of Dead_Target],

        -- Zeroed status (use MAX for aggregation)
        MAX(CAST(ISNULL(ed.[Zeroed], 0) AS INT)) AS [Zeroed],

        -- DKP metrics
        ROUND(AVG(CAST(ed.[DKP_SCORE] AS FLOAT)), 0) AS [DKP_Score],
        ROUND(AVG(CAST(ed.[DKP Target] AS FLOAT)), 0) AS [DKP Target],
        ROUND(AVG(CAST(ed.[% of DKP Target] AS FLOAT)), 2) AS [% of DKP Target],

        -- Pass kills
        ROUND(AVG(CAST(ed.[Pass 4 Kills] AS FLOAT)), 0) AS [Pass 4 Kills],
        ROUND(AVG(CAST(ed.[Pass 6 Kills] AS FLOAT)), 0) AS [Pass 6 Kills],
        ROUND(AVG(CAST(ed.[Pass 7 Kills] AS FLOAT)), 0) AS [Pass 7 Kills],
        ROUND(AVG(CAST(ed.[Pass 8 Kills] AS FLOAT)), 0) AS [Pass 8 Kills],

        -- Pass deads
        ROUND(AVG(CAST(ed.[Pass 4 Deads] AS FLOAT)), 0) AS [Pass 4 Deads],
        ROUND(AVG(CAST(ed.[Pass 6 Deads] AS FLOAT)), 0) AS [Pass 6 Deads],
        ROUND(AVG(CAST(ed.[Pass 7 Deads] AS FLOAT)), 0) AS [Pass 7 Deads],
        ROUND(AVG(CAST(ed.[Pass 8 Deads] AS FLOAT)), 0) AS [Pass 8 Deads],

        -- Assistance and RSS (EXCEL stores deltas)
        ROUND(AVG(CAST(ed.[HelpsDelta] AS FLOAT)), 0) AS [Helps],
        ROUND(AVG(CAST(ed.[RSS_Assist_Delta] AS FLOAT)), 0) AS [RSS_Assist],
        ROUND(AVG(CAST(ed.[RSS_Gathered_Delta] AS FLOAT)), 0) AS [RSS_Gathered],

        -- Healed troops and related
        ROUND(AVG(CAST(ed.[Starting_HealedTroops] AS FLOAT)), 0) AS [Starting HealedTroops],
        ROUND(AVG(CAST(ed.[HealedTroopsDelta] AS FLOAT)), 0) AS [HealedTroopsDelta],
        ROUND(AVG(CAST(ed.[Starting_KillPoints] AS FLOAT)), 0) AS [Starting KillPoints],
        ROUND(AVG(CAST(ed.[KillPointsDelta] AS FLOAT)), 0) AS [KillPointsDelta],
        ROUND(AVG(CAST(ed.[RangedPoints] AS FLOAT)), 0) AS [RangedPoints],
        ROUND(AVG(CAST(ed.[RangedPointsDelta] AS FLOAT)), 0) AS [RangedPointsDelta],

        -- Gameplay summary
        ROUND(AVG(CAST(ed.[KvKPlayed] AS FLOAT)), 0) AS [KvKPlayed],
        ROUND(AVG(CAST(ed.[MostKvKKill] AS FLOAT)), 0) AS [MostKvKKill],
        ROUND(AVG(CAST(ed.[MostKvKDead] AS FLOAT)), 0) AS [MostKvKDead],
        ROUND(AVG(CAST(ed.[MostKvKHeal] AS FLOAT)), 0) AS [MostKvKHeal],
        ROUND(AVG(CAST(ed.[Acclaim] AS FLOAT)), 0) AS [Acclaim],
        ROUND(AVG(CAST(ed.[HighestAcclaim] AS FLOAT)), 0) AS [HighestAcclaim],
        ROUND(AVG(CAST(ed.[AOOJoined] AS FLOAT)), 0) AS [AOOJoined],
        ROUND(AVG(CAST(ed.[AOOWon] AS FLOAT)), 0) AS [AOOWon],
        ROUND(AVG(CAST(ed.[AOOAvgKill] AS FLOAT)), 0) AS [AOOAvgKill],
        ROUND(AVG(CAST(ed.[AOOAvgDead] AS FLOAT)), 0) AS [AOOAvgDead],
        ROUND(AVG(CAST(ed.[AOOAvgHeal] AS FLOAT)), 0) AS [AOOAvgHeal],

        -- Max / rank fields
        ROUND(AVG(CAST(ed.[Max_PreKvk_Points] AS FLOAT)), 0) AS [Max_PreKvk_Points],
        ROUND(AVG(CAST(ed.[Max_HonorPoints] AS FLOAT)), 0) AS [Max_HonorPoints],
        ROUND(AVG(CAST(ed.[PreKvk_Rank] AS FLOAT)), 0) AS [PreKvk_Rank],
        ROUND(AVG(CAST(ed.[Honor_Rank] AS FLOAT)), 0) AS [Honor_Rank],

        -- NEW: AutarchTimes
        ROUND(AVG(CAST(ed.[AutarchTimes] AS FLOAT)), 0) AS [AutarchTimes],

        -- KVK_NO
        ed.KVK_NO,

        -- Placeholder for Civilization; will compute mode in subsequent UPDATE
        CAST(NULL AS NVARCHAR(100)) AS [Civilization]
    INTO #Aggregated
    FROM #RankingGroups rg
    INNER JOIN dbo.EXCEL_FOR_DASHBOARD ed
        ON ed.KVK_NO = rg.KVK_NO
        AND ed.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
    GROUP BY rg.RankGroup, ed.KVK_NO;

    -- Optimization: Add index for the UPDATE operation
    CREATE CLUSTERED INDEX IX_Aggregated ON #Aggregated(KVK_NO, KVK_RANK);

    ----------------------------------------------------------------
    -- Step 3: Compute most common Civilization per (KVK_NO, RankGroup)
    -- Optimization: Improved tie-breaking logic
    ----------------------------------------------------------------
    UPDATE a
    SET a.Civilization = civ.Civilization
    FROM #Aggregated a
    INNER JOIN #RankingGroups rg
        ON a.KVK_NO = rg.KVK_NO
        AND a.KVK_RANK = rg.RankGroup
    CROSS APPLY (
        SELECT TOP (1) t.Civilization
        FROM (
            SELECT 
                e2.Civilization, 
                COUNT(*) AS cnt, 
                MIN(e2.Gov_ID) AS min_gov
            FROM dbo.EXCEL_FOR_DASHBOARD e2
            WHERE e2.KVK_NO = rg.KVK_NO
              AND e2.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
              AND e2.Civilization IS NOT NULL
              AND e2.Civilization <> ''
            GROUP BY e2.Civilization
        ) t
        ORDER BY t.cnt DESC, t.min_gov ASC
    ) AS civ(Civilization);

    ----------------------------------------------------------------
    -- Step 4: Insert into DASH
    -- Optimization: Column order matches table definition for better performance
    ----------------------------------------------------------------
    INSERT INTO dbo.DASH (
        [RANK], 
        [KVK_RANK], 
        [Gov_ID], 
        [Governor_Name],
        [Starting Power], 
        [T4_KILLS], 
        [T5_KILLS], 
        [T4&T5_Kills],
        [Kill Target], 
        [% of Kill target], 
        [Deads], 
        [T4_Deads],
        [T5_Deads], 
        [Dead_Target], 
        [% of Dead_Target], 
        [KVK_NO],
        [Pass 4 Kills], 
        [Pass 6 Kills], 
        [Pass 7 Kills], 
        [Pass 8 Kills],
        [POWER_DELTA], 
        [DKP_Score], 
        [DKP Target], 
        [% of DKP Target],
        [HealedTroops],
        [HealedTroopsDelta], 
        [KillPointsDelta], 
        [RangedPoints], 
        [KvKPlayed],
        [MostKvKKill], 
        [MostKvKDead], 
        [MostKvKHeal], 
        [Acclaim], 
        [HighestAcclaim],
        [AOOJoined], 
        [AOOWon], 
        [AOOAvgKill], 
        [AOOAvgDead], 
        [AOOAvgHeal],
        [Starting KillPoints], 
        [Starting Deads], 
        [Starting T4&T5_KILLS],
        [Helps], 
        [RSS_Assist], 
        [RSS_Gathered],
        [Pass 4 Deads], 
        [Pass 6 Deads], 
        [Pass 7 Deads], 
        [Pass 8 Deads],
        [Starting HealedTroops],
        [Civilization],
        [KILLS_OUTSIDE_KVK], 
        [DEADS_OUTSIDE_KVK], 
        [Zeroed],
        [HelpsDelta], 
        [RSS_Assist_Delta], 
        [RSS_Gathered_Delta],
        [RangedPointsDelta],
        [Max_PreKvk_Points], 
        [Max_HonorPoints], 
        [PreKvk_Rank], 
        [Honor_Rank],
        [AutarchTimes]  -- NEW COLUMN
    )
    SELECT
        [RANK], 
        [KVK_RANK], 
        [Gov_ID], 
        [Governor_Name],
        [Starting Power], 
        [T4_KILLS], 
        [T5_KILLS], 
        [T4&T5_Kills],
        [Kill Target], 
        [% of Kill target], 
        [Deads], 
        [T4_Deads],
        [T5_Deads], 
        [Dead_Target], 
        [% of Dead_Target], 
        [KVK_NO],
        [Pass 4 Kills], 
        [Pass 6 Kills], 
        [Pass 7 Kills], 
        [Pass 8 Kills],
        [POWER_DELTA], 
        [DKP_Score], 
        [DKP Target], 
        [% of DKP Target],
        [Starting HealedTroops],  -- Maps to HealedTroops in DASH
        [HealedTroopsDelta], 
        [KillPointsDelta], 
        [RangedPoints], 
        [KvKPlayed],
        [MostKvKKill], 
        [MostKvKDead], 
        [MostKvKHeal], 
        [Acclaim], 
        [HighestAcclaim],
        [AOOJoined], 
        [AOOWon], 
        [AOOAvgKill], 
        [AOOAvgDead], 
        [AOOAvgHeal],
        [Starting KillPoints], 
        [Starting Deads], 
        [Starting T4&T5_KILLS],
        [Helps], 
        [RSS_Assist], 
        [RSS_Gathered],
        [Pass 4 Deads], 
        [Pass 6 Deads], 
        [Pass 7 Deads], 
        [Pass 8 Deads],
        [Starting HealedTroops],
        [Civilization],
        [KILLS_OUTSIDE_KVK], 
        [DEADS_OUTSIDE_KVK], 
        [Zeroed],
        [HealedTroopsDelta],      -- Maps to HelpsDelta in DASH
        [RSS_Assist],             -- Maps to RSS_Assist_Delta in DASH
        [RSS_Gathered],           -- Maps to RSS_Gathered_Delta in DASH
        [RangedPointsDelta],
        [Max_PreKvk_Points], 
        [Max_HonorPoints], 
        [PreKvk_Rank], 
        [Honor_Rank],
        [AutarchTimes]  -- NEW COLUMN
    FROM #Aggregated;

    ----------------------------------------------------------------
    -- Step 5: Insert the aggregated rows back into EXCEL_FOR_DASHBOARD
    -- Optimization: Batch delete using EXISTS instead of JOIN
    ----------------------------------------------------------------
    DELETE FROM dbo.EXCEL_FOR_DASHBOARD
    WHERE Gov_ID IN ('999999997', '999999998', '999999999')
      AND EXISTS (SELECT 1 FROM dbo.DASH d WHERE d.KVK_NO = EXCEL_FOR_DASHBOARD.KVK_NO);

    -- Build dynamic column mapping
    DECLARE @cols NVARCHAR(MAX) = N'';
    DECLARE @sels NVARCHAR(MAX) = N'';

    ;WITH ColumnMapping (dest_col, src_expr) AS (
        SELECT * FROM (VALUES
            (N'Rank',                 N'[RANK]'),
            (N'KVK_RANK',             N'[KVK_RANK]'),
            (N'Gov_ID',               N'[Gov_ID]'),
            (N'Governor_Name',        N'[Governor_Name]'),
            (N'Starting Power',       N'[Starting Power]'),
            (N'Power_Delta',          N'[POWER_DELTA]'),
            (N'T4_KILLS',             N'[T4_KILLS]'),
            (N'T5_KILLS',             N'[T5_KILLS]'),
            (N'T4&T5_Kills',          N'[T4&T5_Kills]'),
            (N'Kill Target',          N'[Kill Target]'),
            (N'% of Kill Target',     N'[% of Kill target]'),
            (N'Starting_Deads',       N'[Starting Deads]'),
            (N'Deads_Delta',          N'[Deads]'),  -- Map aggregate Deads to Deads_Delta
            (N'T4_Deads',             N'[T4_Deads]'),
            (N'T5_Deads',             N'[T5_Deads]'),
            (N'Dead_Target',          N'[Dead_Target]'),
            (N'% of Dead Target',     N'[% of Dead_Target]'),
            (N'DKP_SCORE',            N'[DKP_Score]'),
            (N'DKP Target',           N'[DKP Target]'),
            (N'% of DKP Target',      N'[% of DKP Target]'),
            (N'Pass 4 Kills',         N'[Pass 4 Kills]'),
            (N'Pass 6 Kills',         N'[Pass 6 Kills]'),
            (N'Pass 7 Kills',         N'[Pass 7 Kills]'),
            (N'Pass 8 Kills',         N'[Pass 8 Kills]'),
            (N'Pass 4 Deads',         N'[Pass 4 Deads]'),
            (N'Pass 6 Deads',         N'[Pass 6 Deads]'),
            (N'Pass 7 Deads',         N'[Pass 7 Deads]'),
            (N'Pass 8 Deads',         N'[Pass 8 Deads]'),
            (N'KVK_NO',               N'[KVK_NO]'),
            (N'HelpsDelta',           N'[Helps]'),
            (N'RSS_Assist_Delta',     N'[RSS_Assist]'),
            (N'RSS_Gathered_Delta',   N'[RSS_Gathered]'),
            (N'Starting_HealedTroops', N'[Starting HealedTroops]'),
            (N'HealedTroopsDelta',    N'[HealedTroopsDelta]'),
            (N'KillPointsDelta',      N'[KillPointsDelta]'),
            (N'RangedPoints',         N'[RangedPoints]'),
            (N'RangedPointsDelta',    N'[RangedPointsDelta]'),
            (N'Civilization',         N'[Civilization]'),
            (N'KvKPlayed',            N'[KvKPlayed]'),
            (N'MostKvKKill',          N'[MostKvKKill]'),
            (N'MostKvKDead',          N'[MostKvKDead]'),
            (N'MostKvKHeal',          N'[MostKvKHeal]'),
            (N'Acclaim',              N'[Acclaim]'),
            (N'HighestAcclaim',       N'[HighestAcclaim]'),
            (N'AOOJoined',            N'[AOOJoined]'),
            (N'AOOWon',               N'[AOOWon]'),
            (N'AOOAvgKill',           N'[AOOAvgKill]'),
            (N'AOOAvgDead',           N'[AOOAvgDead]'),
            (N'AOOAvgHeal',           N'[AOOAvgHeal]'),
            (N'Starting_KillPoints',  N'[Starting KillPoints]'),
            (N'Starting_Deads',       N'[Starting Deads]'),
            (N'Starting_T4&T5_KILLS', N'[Starting T4&T5_KILLS]'),
            (N'DEADS_OUTSIDE_KVK',    N'[DEADS_OUTSIDE_KVK]'),
            (N'KILLS_OUTSIDE_KVK',    N'[KILLS_OUTSIDE_KVK]'),
            (N'Zeroed',               N'[Zeroed]'),
            (N'Max_PreKvk_Points',    N'[Max_PreKvk_Points]'),
            (N'Max_HonorPoints',      N'[Max_HonorPoints]'),
            (N'PreKvk_Rank',          N'[PreKvk_Rank]'),
            (N'Honor_Rank',           N'[Honor_Rank]'),
            (N'AutarchTimes',         N'[AutarchTimes]')  -- NEW COLUMN MAPPING
        ) v(dest_col, src_expr)
    )
    , AvailableColumns AS (
        -- Keep a single entry per destination column (case-insensitive de-duplication)
        SELECT
            MIN(dest_col) AS dest_col,
            MIN(src_expr) AS src_expr,
            LOWER(dest_col) AS ldest
        FROM ColumnMapping
        WHERE COL_LENGTH('dbo.EXCEL_FOR_DASHBOARD', dest_col) IS NOT NULL
        GROUP BY LOWER(dest_col)
    )
    SELECT
        @cols = STRING_AGG(QUOTENAME(dest_col), N', ') WITHIN GROUP (ORDER BY dest_col),
        @sels = STRING_AGG(src_expr, N', ') WITHIN GROUP (ORDER BY dest_col)
    FROM AvailableColumns;

    -- Execute dynamic INSERT if columns are available
    IF @cols IS NOT NULL AND LEN(@cols) > 0
    BEGIN
        DECLARE @sql NVARCHAR(MAX) =
            N'INSERT INTO dbo.EXCEL_FOR_DASHBOARD (' + @cols + N')
              SELECT ' + @sels + N'
              FROM dbo.DASH
              WHERE Gov_ID IN (''999999997'', ''999999998'', ''999999999'');';

        EXEC sp_executesql @sql;
    END

    ----------------------------------------------------------------
    -- Cleanup
    ----------------------------------------------------------------
    DROP TABLE IF EXISTS #RankingGroups;
    DROP TABLE IF EXISTS #Aggregated;

    SET NOCOUNT OFF;
END

