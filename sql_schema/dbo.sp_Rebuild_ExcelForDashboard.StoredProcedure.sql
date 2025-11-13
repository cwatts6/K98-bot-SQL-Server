SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Rebuild_ExcelForDashboard]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Rebuild_ExcelForDashboard] AS' 
END
ALTER PROCEDURE [dbo].[sp_Rebuild_ExcelForDashboard]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = '';
    DECLARE @unionSql NVARCHAR(MAX) = '';
    DECLARE @KVK INT;
    DECLARE @MaxScan FLOAT;

    -- Step 1: Get the max scan value
    SELECT @MaxScan = MAX(SCANORDER) FROM KingdomScanData4;

    -- Step 2: Build the dynamic UNION query
    DECLARE cur CURSOR FOR
    SELECT DISTINCT KVKVersion
    FROM ProcConfig
    WHERE ConfigKey = 'MATCHMAKING_SCAN'
      AND TRY_CAST(ConfigValue AS FLOAT) < @MaxScan
    ORDER BY KVKVersion DESC;

    OPEN cur;
    FETCH NEXT FROM cur INTO @KVK;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @unionSql += 
            CASE 
                WHEN LEN(@unionSql) = 0 
                    THEN 'SELECT * FROM EXCEL_FOR_KVK_' + CAST(@KVK AS NVARCHAR)
                ELSE ' UNION ALL SELECT * FROM EXCEL_FOR_KVK_' + CAST(@KVK AS NVARCHAR)
            END;

        FETCH NEXT FROM cur INTO @KVK;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -- Step 3: Only build final query if unionSql is not empty
    IF LEN(@unionSql) > 0
    BEGIN
        SET @sql = '
        IF OBJECT_ID(''EXCEL_FOR_DASHBOARD'', ''U'') IS NOT NULL
            DROP TABLE EXCEL_FOR_DASHBOARD;

        SELECT TOP (5000000)
               T.*,
               T.[% of Dead Target] AS [% of Dead_Target]  -- ✅ add alias so both names exist
        INTO EXCEL_FOR_DASHBOARD
        FROM (
            ' + @unionSql + '
        ) AS T
        ORDER BY KVK_NO, [RANK];
        ';

        EXEC sp_executesql @sql;

        ----------------------------------------------------------------
        -- 1) Build KVK windows (start/end scan ranges) from ProcConfig
        --    Start = MATCHMAKING_SCAN
        --    End   = KVK_END_SCAN (fallback to @MaxScan if missing)
        ----------------------------------------------------------------
        IF OBJECT_ID('tempdb..#KVKWindows') IS NOT NULL DROP TABLE #KVKWindows;

        SELECT
            pc.KVKVersion                  AS KVK_NO,
            TRY_CAST(MAX(CASE WHEN pc.ConfigKey = 'MATCHMAKING_SCAN' THEN pc.ConfigValue END) AS FLOAT) AS StartScan,
            COALESCE(
                TRY_CAST(MAX(CASE WHEN pc.ConfigKey IN ('KVK_END_SCAN','END_SCAN') THEN pc.ConfigValue END) AS FLOAT),
                @MaxScan
            ) AS EndScan
        INTO #KVKWindows
        FROM dbo.ProcConfig AS pc
        GROUP BY pc.KVKVersion;

        -- Keep only valid rows
        DELETE FROM #KVKWindows WHERE StartScan IS NULL OR EndScan IS NULL OR EndScan < StartScan;

        ----------------------------------------------------------------
        -- 2) Aggregate positive deltas of [Troops Power] within each KVK
        ----------------------------------------------------------------
        IF OBJECT_ID('tempdb..#TrainDelta') IS NOT NULL DROP TABLE #TrainDelta;

        WITH KS AS (
            SELECT
                k.GovernorID       AS Gov_ID,
                k.SCANORDER,
                k.[Troops Power]   AS TroopsPower,
                w.KVK_NO
            FROM dbo.KingdomScanData4 AS k
            INNER JOIN #KVKWindows AS w
                ON k.SCANORDER BETWEEN w.StartScan AND w.EndScan
        ),
        D AS (
            SELECT
                Gov_ID,
                KVK_NO,
                CASE 
                    WHEN (TroopsPower - LAG(TroopsPower) OVER (PARTITION BY Gov_ID, KVK_NO ORDER BY SCANORDER)) > 0
                        THEN (TroopsPower - LAG(TroopsPower) OVER (PARTITION BY Gov_ID, KVK_NO ORDER BY SCANORDER))
                    ELSE 0
                END AS TP_PositiveDelta
            FROM KS
        )
        SELECT
            Gov_ID,
            KVK_NO,
            CAST(SUM(TP_PositiveDelta) AS bigint) AS TrainingPower_Delta
        INTO #TrainDelta
        FROM D
        GROUP BY Gov_ID, KVK_NO;

        ----------------------------------------------------------------
        -- 3) Update EXCEL_FOR_DASHBOARD with TrainingPower_Delta
        --    (match on Gov_ID + KVK_NO)
        ----------------------------------------------------------------
        UPDATE ED
        SET ED.TrainingPower_Delta = X.TrainingPower_Delta
        FROM dbo.EXCEL_FOR_DASHBOARD AS ED
        INNER JOIN #TrainDelta AS X
            ON X.Gov_ID = ED.[Gov_ID]
           AND X.KVK_NO = ED.[KVK_NO];

        ----------------------------------------------------------------
        -- 4) Compute HealedPower_Est and HealedTroops_Est
        --    Choose AvgPowerPerTroop strategy:
        --      - Keep 7.0 as blended default
        --      - Or replace with a lookup (fn_AvgPowerPerTroop(ED.Gov_ID))
        ----------------------------------------------------------------
        ;WITH A AS (
            SELECT
                ED.[Gov_ID],
                ED.[KVK_NO],
                CAST(7.0 AS decimal(10,2)) AS AvgPowerPerTroop,
                CAST(COALESCE(TRY_CONVERT(bigint, ED.[Power_Delta]), 0) AS bigint) AS PowerDelta,
                CAST(COALESCE(TRY_CONVERT(bigint, ED.[Deads]), 0) AS bigint)       AS Deads,
                CAST(COALESCE(ED.TrainingPower_Delta, 0) AS bigint)                AS TrainDelta
            FROM dbo.EXCEL_FOR_DASHBOARD AS ED
        ),
        HP AS (
            SELECT
                Gov_ID,
                KVK_NO,
                AvgPowerPerTroop,
                CAST( (PowerDelta + (Deads * AvgPowerPerTroop)) - TrainDelta AS bigint ) AS HealedPowerCalc
            FROM A
        )
        UPDATE ED
        SET
            HealedPower_Est  = CASE WHEN HP.HealedPowerCalc > 0 THEN HP.HealedPowerCalc ELSE 0 END,
            HealedTroops_Est = CASE 
                                  WHEN HP.HealedPowerCalc > 0 AND HP.AvgPowerPerTroop > 0
                                      THEN CAST(ROUND(HP.HealedPowerCalc / HP.AvgPowerPerTroop, 0) AS bigint)
                                  ELSE 0
                               END
        FROM dbo.EXCEL_FOR_DASHBOARD AS ED
        INNER JOIN HP
           ON HP.Gov_ID = ED.[Gov_ID]
          AND HP.KVK_NO = ED.[KVK_NO];

    END
    ELSE
    BEGIN
        PRINT 'No eligible KVK tables found based on MATCHMAKING_SCAN and Max SCANORDER.';
    END
END

