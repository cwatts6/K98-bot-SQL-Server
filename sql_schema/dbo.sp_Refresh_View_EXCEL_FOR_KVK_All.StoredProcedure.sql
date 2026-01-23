SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Refresh_View_EXCEL_FOR_KVK_All]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Refresh_View_EXCEL_FOR_KVK_All] AS' 
END
ALTER PROCEDURE [dbo].[sp_Refresh_View_EXCEL_FOR_KVK_All]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#kvks') IS NOT NULL DROP TABLE #kvks;
    CREATE TABLE #kvks (
        ord   INT IDENTITY(1,1) PRIMARY KEY,
        name  SYSNAME NOT NULL,
        kvk_no INT NOT NULL,
        obj_id INT NOT NULL
    );

    INSERT INTO #kvks(name, kvk_no, obj_id)
    SELECT t.name,
           TRY_CONVERT(int, REPLACE(t.name, 'EXCEL_FOR_KVK_', '')) AS kvk_no,
           t.object_id
    FROM sys.tables AS t
    WHERE t.name LIKE 'EXCEL_FOR_KVK[_]%'
      AND TRY_CONVERT(int, REPLACE(t.name, 'EXCEL_FOR_KVK_', '')) IS NOT NULL
    ORDER BY TRY_CONVERT(int, REPLACE(t.name, 'EXCEL_FOR_KVK_', ''));

    IF NOT EXISTS (SELECT 1 FROM #kvks)
    BEGIN
        EXEC('
        CREATE OR ALTER VIEW dbo.v_EXCEL_FOR_KVK_All AS
        SELECT
            CAST(NULL AS int)            AS [Rank],
            CAST(NULL AS int)            AS [KVK_RANK],
            CAST(NULL AS bigint)         AS [Gov_ID],
            CAST(NULL AS nvarchar(200))  AS [Governor_Name],
            CAST(NULL AS bigint)         AS [Starting Power],
            CAST(NULL AS bigint)         AS [Power_Delta],

            CAST(NULL AS nvarchar(100))  AS [Civilization],
            CAST(NULL AS int)            AS [KvKPlayed],
            CAST(NULL AS nvarchar(200))  AS [MostKvKKill],
            CAST(NULL AS nvarchar(200))  AS [MostKvKDead],
            CAST(NULL AS nvarchar(200))  AS [MostKvKHeal],
            CAST(NULL AS float)          AS [Acclaim],
            CAST(NULL AS float)          AS [HighestAcclaim],
            CAST(NULL AS int)            AS [AOOJoined],
            CAST(NULL AS int)            AS [AOOWon],
            CAST(NULL AS float)          AS [AOOAvgKill],
            CAST(NULL AS float)          AS [AOOAvgDead],
            CAST(NULL AS float)          AS [AOOAvgHeal],

            CAST(NULL AS float)          AS [Starting_T4&T5_KILLS],
            CAST(NULL AS bigint)         AS [T4_KILLS],
            CAST(NULL AS bigint)         AS [T5_KILLS],
            CAST(NULL AS bigint)         AS [T4&T5_Kills],
            CAST(NULL AS bigint)         AS [KILLS_OUTSIDE_KVK],
            CAST(NULL AS bigint)         AS [Kill Target],
            CAST(NULL AS decimal(9,2))   AS [% of Kill Target],

            CAST(NULL AS float)          AS [Starting_Deads],
            CAST(NULL AS bigint)         AS [Deads_Delta],
            CAST(NULL AS bigint)         AS [DEADS_OUTSIDE_KVK],
            CAST(NULL AS bigint)         AS [T4_Deads],
            CAST(NULL AS bigint)         AS [T5_Deads],
            CAST(NULL AS bigint)         AS [Dead_Target],
            CAST(NULL AS decimal(9,2))   AS [% of Dead Target],

            CAST(NULL AS bit)            AS [Zeroed],
            CAST(NULL AS bigint)         AS [DKP_SCORE],
            CAST(NULL AS bigint)         AS [DKP Target],
            CAST(NULL AS decimal(9,2))   AS [% of DKP Target],

            CAST(NULL AS bigint)         AS [HelpsDelta],
            CAST(NULL AS bigint)         AS [RSS_Assist_Delta],
            CAST(NULL AS bigint)         AS [RSS_Gathered_Delta],

            CAST(NULL AS bigint)         AS [Pass 4 Kills],
            CAST(NULL AS bigint)         AS [Pass 6 Kills],
            CAST(NULL AS bigint)         AS [Pass 7 Kills],
            CAST(NULL AS bigint)         AS [Pass 8 Kills],
            CAST(NULL AS bigint)         AS [Pass 4 Deads],
            CAST(NULL AS bigint)         AS [Pass 6 Deads],
            CAST(NULL AS bigint)         AS [Pass 7 Deads],
            CAST(NULL AS bigint)         AS [Pass 8 Deads],

            CAST(NULL AS bigint)         AS [Starting_HealedTroops],
            CAST(NULL AS bigint)         AS [HealedTroopsDelta],
            CAST(NULL AS float)          AS [Starting_KillPoints],
            CAST(NULL AS float)          AS [KillPointsDelta],

            CAST(NULL AS bigint)         AS [RangedPoints],
            CAST(NULL AS bigint)         AS [RangedPointsDelta],

            CAST(NULL AS float)          AS [Max_PreKvk_Points],
            CAST(NULL AS float)          AS [Max_HonorPoints],
            CAST(NULL AS int)            AS [PreKvk_Rank],
            CAST(NULL AS int)            AS [Honor_Rank],

            CAST(NULL AS int)            AS [KVK_NO]
        WHERE 1=0;');

        EXEC('CREATE OR ALTER VIEW dbo.v_EXCEL_FOR_KVK_Started AS SELECT * FROM dbo.v_EXCEL_FOR_KVK_All WHERE 1=0;');
        RETURN;
    END

    DECLARE @view NVARCHAR(MAX) = N'CREATE OR ALTER VIEW dbo.v_EXCEL_FOR_KVK_All AS' + CHAR(10);
    DECLARE @first BIT = 1;

    DECLARE
        @name SYSNAME, @obj_id INT,

        @PctKillSrc NVARCHAR(200),
        @DeadTargetSrc NVARCHAR(200),
        @PctDeadTargetSrc NVARCHAR(200),
        @DKPSrc NVARCHAR(200),
        @PctDKPSrc NVARCHAR(200),
	 @CivilizationSrc NVARCHAR(200),

        @StartKillSrc NVARCHAR(200),
        @StartDeadsSrc NVARCHAR(200),
        @StartT4T5Src NVARCHAR(200),
        @StartHealedSrc NVARCHAR(200),

        @DeadsDeltaSrc NVARCHAR(200),
        @HelpsSrc NVARCHAR(200),
        @RSSAssistSrc NVARCHAR(200),
        @RSSGatheredSrc NVARCHAR(200),

        @HealedDeltaSrc NVARCHAR(200),
        @KillPointsDeltaSrc NVARCHAR(200),

        @RangedSrc NVARCHAR(200),
        @RangedDeltaSrc NVARCHAR(200),

        @MaxPreKvkSrc NVARCHAR(200),
        @MaxHonorSrc NVARCHAR(200),
        @PreKvkRankSrc NVARCHAR(200),
        @HonorRankSrc NVARCHAR(200);

    DECLARE c CURSOR FAST_FORWARD FOR
        SELECT name, obj_id FROM #kvks ORDER BY ord;

    OPEN c;
    FETCH NEXT FROM c INTO @name, @obj_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- % of Kill Target
        SET @PctKillSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of Kill Target')
                    THEN '[% of Kill Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Pct_of_Kill_Target')
                    THEN '[Pct_of_Kill_Target]'
                ELSE 'CAST(0.00 AS decimal(9,2))'
            END;

		SET @CivilizationSrc =
    CASE
        WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Civilization')
            THEN '[Civilization]'
        WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting Civilization')
            THEN '[Starting Civilization]'
        ELSE 'CAST(NULL AS nvarchar(100))'
    END;

        -- Dead target
        SET @DeadTargetSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Dead_Target')
                    THEN '[Dead_Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Dead Target')
                    THEN '[Dead Target]'
                ELSE 'CAST(0 AS bigint)'
            END;

        -- % of Dead target
        SET @PctDeadTargetSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of Dead Target')
                    THEN '[% of Dead Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Pct_of_Dead_Target')
                    THEN '[Pct_of_Dead_Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of Dead_Target')
                    THEN '[% of Dead_Target]'
                ELSE 'CAST(0.00 AS decimal(9,2))'
            END;

        -- DKP score
        SET @DKPSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='DKP_SCORE')
                    THEN '[DKP_SCORE]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='DKP Score')
                    THEN '[DKP Score]'
                ELSE 'CAST(0 AS bigint)'
            END;

        -- % of DKP target
        SET @PctDKPSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of DKP Target')
                    THEN '[% of DKP Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Pct_of_DKP_Target')
                    THEN '[Pct_of_DKP_Target]'
                ELSE 'CAST(0.00 AS decimal(9,2))'
            END;

        -- Starting snapshots (prefer new underscore names)
        SET @StartKillSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting_KillPoints')
                    THEN '[Starting_KillPoints]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting KillPoints')
                    THEN '[Starting KillPoints]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting_KillPoints')
                    THEN '[Starting_KillPoints]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting_KillPoints')
                    THEN '[Starting_KillPoints]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='KillPoints')
                    THEN '[KillPoints]'
                ELSE 'CAST(0.0 AS float)'
            END;

        SET @StartDeadsSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting_Deads')
                    THEN '[Starting_Deads]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting Deads')
                    THEN '[Starting Deads]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Deads')
                    THEN '[Deads]'
                ELSE 'CAST(0.0 AS float)'
            END;

        SET @StartT4T5Src =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting_T4&T5_KILLS')
                    THEN '[Starting_T4&T5_KILLS]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting T4&T5_KILLS')
                    THEN '[Starting T4&T5_KILLS]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting T4&T5_KILLS')
                    THEN '[Starting T4&T5_KILLS]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='T4&T5_KILLS')
                    THEN '[T4&T5_KILLS]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='T4&T5_Kills')
                    THEN '[T4&T5_Kills]'
                ELSE 'CAST(0.0 AS float)'
            END;

        SET @StartHealedSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting_HealedTroops')
                    THEN '[Starting_HealedTroops]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting HealedTroops')
                    THEN '[Starting HealedTroops]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Starting_HealedTroops')
                    THEN '[Starting_HealedTroops]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='HealedTroops')
                    THEN '[HealedTroops]'
                ELSE 'CAST(0 AS bigint)'
            END;

        -- New naming: Deads_Delta / HelpsDelta / RSS_*_Delta
        SET @DeadsDeltaSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Deads_Delta')
                    THEN '[Deads_Delta]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='DeadsDelta')
                    THEN '[DeadsDelta]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Deads')
                    THEN '[Deads]'
                ELSE 'CAST(0 AS bigint)'
            END;

        SET @HelpsSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='HelpsDelta')
                    THEN '[HelpsDelta]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Helps')
                    THEN '[Helps]'
                ELSE 'CAST(0 AS bigint)'
            END;

        SET @RSSAssistSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='RSS_Assist_Delta')
                    THEN '[RSS_Assist_Delta]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='RSS_Assist')
                    THEN '[RSS_Assist]'
                ELSE 'CAST(0 AS bigint)'
            END;

        SET @RSSGatheredSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='RSS_Gathered_Delta')
                    THEN '[RSS_Gathered_Delta]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='RSS_Gathered')
                    THEN '[RSS_Gathered]'
                ELSE 'CAST(0 AS bigint)'
            END;

        SET @HealedDeltaSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='HealedTroopsDelta')
                    THEN '[HealedTroopsDelta]'
                ELSE 'CAST(0 AS bigint)'
            END;

        SET @KillPointsDeltaSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='KillPointsDelta')
                    THEN '[KillPointsDelta]'
                ELSE 'CAST(0.0 AS float)'
            END;

        -- Ranged
        SET @RangedSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='RangedPoints')
                    THEN '[RangedPoints]'
                ELSE 'CAST(0 AS bigint)'
            END;

        SET @RangedDeltaSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='RangedPointsDelta')
                    THEN '[RangedPointsDelta]'
                ELSE 'CAST(0 AS bigint)'
            END;

        -- Optional new columns (default if old tables don’t have them)
        SET @MaxPreKvkSrc =
            CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Max_PreKvk_Points')
                THEN '[Max_PreKvk_Points]' ELSE 'CAST(0.0 AS float)' END;

        SET @MaxHonorSrc =
            CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Max_HonorPoints')
                THEN '[Max_HonorPoints]' ELSE 'CAST(0.0 AS float)' END;

        SET @PreKvkRankSrc =
            CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='PreKvk_Rank')
                THEN '[PreKvk_Rank]' ELSE 'CAST(0 AS int)' END;

        SET @HonorRankSrc =
            CASE WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Honor_Rank')
                THEN '[Honor_Rank]' ELSE 'CAST(0 AS int)' END;

        DECLARE @select NVARCHAR(MAX) = N'
SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   ' + @CivilizationSrc + ' AS [Civilization],
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

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    ' + @PctKillSrc + '        AS [% of Kill Target],

    ' + @StartDeadsSrc + '     AS [Starting_Deads],
    ' + @DeadsDeltaSrc + '     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    ' + @DeadTargetSrc + '     AS [Dead_Target],
    ' + @PctDeadTargetSrc + '  AS [% of Dead Target],

    [Zeroed],
    ' + @DKPSrc + '            AS [DKP_SCORE],
    [DKP Target],
    ' + @PctDKPSrc + '         AS [% of DKP Target],

    ' + @HelpsSrc + '          AS [HelpsDelta],
    ' + @RSSAssistSrc + '      AS [RSS_Assist_Delta],
    ' + @RSSGatheredSrc + '    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    ' + @StartHealedSrc + '    AS [Starting_HealedTroops],
    ' + @HealedDeltaSrc + '    AS [HealedTroopsDelta],
    ' + @StartKillSrc + '      AS [Starting_KillPoints],
    ' + @KillPointsDeltaSrc + ' AS [KillPointsDelta],

    ' + @RangedSrc + '         AS [RangedPoints],
    ' + @RangedDeltaSrc + '    AS [RangedPointsDelta],

    ' + @MaxPreKvkSrc + '      AS [Max_PreKvk_Points],
    ' + @MaxHonorSrc + '       AS [Max_HonorPoints],
    ' + @PreKvkRankSrc + '     AS [PreKvk_Rank],
    ' + @HonorRankSrc + '      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.' + QUOTENAME(@name);

        IF @first = 1
        BEGIN
            SET @view += @select;
            SET @first = 0;
        END
        ELSE
        BEGIN
            SET @view += CHAR(10) + N'UNION ALL' + CHAR(10) + @select;
        END

        FETCH NEXT FROM c INTO @name, @obj_id;
    END
    CLOSE c; DEALLOCATE c;

    EXEC sys.sp_executesql @view;

    DECLARE @sql2 NVARCHAR(MAX) = N'
    CREATE OR ALTER VIEW dbo.v_EXCEL_FOR_KVK_Started AS
    WITH MaxStarted AS (
        SELECT MAX(KVK_NO) AS MaxKVK
        FROM dbo.KVK_Details
        WHERE KVK_START_DATE IS NOT NULL
          AND KVK_START_DATE <= SYSUTCDATETIME()
    )
    SELECT a.*
    FROM dbo.v_EXCEL_FOR_KVK_All AS a
    CROSS JOIN MaxStarted ms
    WHERE a.[KVK_NO] <= ms.MaxKVK;';
    EXEC sys.sp_executesql @sql2;
END

