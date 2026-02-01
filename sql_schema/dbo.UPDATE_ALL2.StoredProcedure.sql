SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL2] AS' 
END
ALTER PROCEDURE [dbo].[UPDATE_ALL2]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    -- REQUIRED SET Options for DML against indexed views / persisted computed columns
    SET ANSI_NULLS ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET QUOTED_IDENTIFIER ON;
    SET NUMERIC_ROUNDABORT OFF;
    SET XACT_ABORT ON;

    DECLARE @rc INT, @rowsKS5 INT, @rowsKS4 INT = 0;

    BEGIN TRY
        ----------------------------------------------------------------
        -- Phase A: Import → KS5 → (maybe) KS4  [commit early]
        ----------------------------------------------------------------
        BEGIN TRANSACTION;

        -- Get deterministic defaults from KS. Choose "latest" row by [Last Update] if present.
        DECLARE @actual_param1 FLOAT = NULL,
                @actual_param2 NVARCHAR(100) = NULL;

        SELECT TOP (1)
            @actual_param1 = COALESCE(@param1, KINGDOM_RANK, 0),
            @actual_param2 = COALESCE(@param2, KINGDOM_SEED, N'')
        FROM dbo.KS
        WHERE KINGDOM_RANK IS NOT NULL OR KINGDOM_SEED IS NOT NULL
        ORDER BY [Last Update] DESC; 

        IF @actual_param1 IS NULL SET @actual_param1 = COALESCE(@param1, 0);
        IF @actual_param2 IS NULL SET @actual_param2 = COALESCE(@param2, N'');

        DECLARE @StartTime DATETIME = GETDATE();

        -- 1) Refresh latest data
        EXEC @rc = dbo.IMPORT_STAGING_PROC;
        IF @rc <> 0
        BEGIN
            RAISERROR('IMPORT_STAGING_PROC failed (rc=%d).', 16, 1, @rc);
        END

        -- 2) Insert into KingdomScanData5
        INSERT INTO dbo.KingdomScanData5 (
              PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
            , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
            , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
            , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal
        )
        SELECT
              ROW_NUMBER() OVER (ORDER BY [Power] DESC, [Governor ID] ASC) AS PowerRank
            , RTRIM([Name])
            , [Governor ID]
            , [Alliance]
            , [Power]
            , [Total Kill Points]
            , [Dead Troops]
            , [T1-Kills], [T2-Kills], [T3-Kills], [T4-Kills], [T5-Kills]
            , [Kills (T4+)]
            , [KILLS]
            , [RSS Gathered], [RSS Assistance], [Alliance Helps]
            , [ScanDate], [SCANORDER]
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , [HealedTroops], [RangedPoints], [Civilization], [AutarchTimes], [KvKPlayed], [MostKvKKill], [MostKvKDead], [MostKvKHeal]
            , [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon], [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal]
        FROM dbo.IMPORT_STAGING WITH (TABLOCK);

        SET @rowsKS5 = @@ROWCOUNT;

        IF @rowsKS5 = 0
        BEGIN
            RAISERROR('No rows inserted into KingdomScanData5 (IMPORT_STAGING was empty).', 16, 1);
        END

        -- SMART INDEX MAINTENANCE: Only update stats for KS5 (lightweight)
        -- Full index rebuild happens nightly via maintenance job
        PRINT 'Updating statistics for KingdomScanData5 (quick sample)...';
        UPDATE STATISTICS dbo.KingdomScanData5 WITH SAMPLE 20 PERCENT;
        PRINT 'KingdomScanData5 statistics refreshed.';

        -- Cache MAX(SCANORDER) values to avoid repeated scans
        DECLARE @MaxScanOrder5 BIGINT = (SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData5 ORDER BY SCANORDER DESC);
        DECLARE @MaxScanOrder4 BIGINT = (SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData4 ORDER BY SCANORDER DESC);

        -- 3) Promote to KS4 if newer
        IF @MaxScanOrder5 > @MaxScanOrder4
        BEGIN
            INSERT INTO dbo.KingdomScanData4 (
                  PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , RSS_Gathered, RSSAssistance, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal
            )
            SELECT
                  PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @MaxScanOrder5;

            SET @rowsKS4 = @@ROWCOUNT;

            ----------------------------------------------------------------
            -- SMART INDEX MAINTENANCE for KS4: Check fragmentation first
            -- Thresholds: 
            --   - Skip if < 10% fragmentation
            --   - REORGANIZE if 10-30% fragmentation (online, low impact)
            --   - REBUILD if > 30% fragmentation
            ----------------------------------------------------------------
            PRINT 'Checking KingdomScanData4 index fragmentation...';
            
            DECLARE @IndexMaintLog TABLE (
                IndexName NVARCHAR(128),
                FragmentationPercent DECIMAL(5,2),
                Action NVARCHAR(20)
            );

            -- Check fragmentation of critical indexes
            DECLARE @IndexName NVARCHAR(128);
            DECLARE @Fragmentation DECIMAL(5,2);
            DECLARE @SQL NVARCHAR(MAX);

            DECLARE idx_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT 
                    i.name AS IndexName,
                    ips.avg_fragmentation_in_percent AS Fragmentation
                FROM sys.dm_db_index_physical_stats(
                    DB_ID(), 
                    OBJECT_ID('dbo.KingdomScanData4'), 
                    NULL, NULL, 'LIMITED'
                ) AS ips
                INNER JOIN sys.indexes AS i 
                    ON ips.object_id = i.object_id 
                    AND ips.index_id = i.index_id
                WHERE 
                    i.name IN (
                        'CIX_KS4_ScanOrder_Governor',
                        'IX_KSD4_Governor_ScanOrder', 
                        'IX_KS4_Governor_ScanDate',
                        'IX_KSD4_Gov_ScanOrder'
                    )
                    AND ips.avg_fragmentation_in_percent IS NOT NULL;

            OPEN idx_cursor;
            FETCH NEXT FROM idx_cursor INTO @IndexName, @Fragmentation;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @Fragmentation < 10
                BEGIN
                    -- Skip - fragmentation is low
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, 'SKIPPED');
                    PRINT '  ' + @IndexName + ': ' + CAST(@Fragmentation AS VARCHAR(10)) + '% - Skipped';
                END
                ELSE IF @Fragmentation < 30
                BEGIN
                    -- REORGANIZE - medium fragmentation, online operation
                    SET @SQL = N'ALTER INDEX [' + @IndexName + N'] ON dbo.KingdomScanData4 REORGANIZE;';
                    EXEC sp_executesql @SQL;
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, 'REORGANIZED');
                    PRINT '  ' + @IndexName + ': ' + CAST(@Fragmentation AS VARCHAR(10)) + '% - Reorganized';
                END
                ELSE
                BEGIN
                    -- REBUILD - high fragmentation
                    SET @SQL = N'ALTER INDEX [' + @IndexName + N'] ON dbo.KingdomScanData4 REBUILD WITH (SORT_IN_TEMPDB = ON, MAXDOP = 0);';
                    EXEC sp_executesql @SQL;
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, 'REBUILT');
                    PRINT '  ' + @IndexName + ': ' + CAST(@Fragmentation AS VARCHAR(10)) + '% - Rebuilt';
                END

                FETCH NEXT FROM idx_cursor INTO @IndexName, @Fragmentation;
            END

            CLOSE idx_cursor;
            DEALLOCATE idx_cursor;

            -- Always update statistics after any index maintenance
            UPDATE STATISTICS dbo.KingdomScanData4 WITH SAMPLE 25 PERCENT;
            PRINT 'KingdomScanData4 statistics refreshed.';

            -- Log index maintenance actions
            SELECT * FROM @IndexMaintLog;
        END

        -- 4) Truncate staging (safe post-insert)
        TRUNCATE TABLE dbo.IMPORT_STAGING;

        COMMIT;  -- ✅ Import is now durable even if later steps fail

        -- Return / Log Phase A summary values
        SELECT
            @MaxScanOrder5    AS Ks5_MaxScanOrder,
            @rowsKS5          AS Ks5_RowsInserted,
            @rowsKS4          AS Ks4_RowsInserted,
            (SELECT COUNT(*) FROM dbo.IMPORT_STAGING) AS ImportStaging_RowsAfterPhaseA,
            (SELECT COUNT(*) FROM dbo.KingdomScanData4 WHERE SCANORDER = @MaxScanOrder4) AS Ks4_RowsInLatest;

        ----------------------------------------------------------------
        -- Phase B: Downstream builds (non-critical) - separate transaction
        -- ⚡ OPTIMIZED SECTION ⚡
        ----------------------------------------------------------------
        BEGIN TRANSACTION;

        -- Timing variables for performance monitoring
        DECLARE @PhaseBStart DATETIME2 = SYSDATETIME();
        DECLARE @StepStart DATETIME2;
        DECLARE @StepEnd DATETIME2;
        DECLARE @StepDuration INT;

        -- *** NEW: Check log space at Phase B start ***
        DECLARE @CurrentLogUsedPct DECIMAL(5,2) = NULL;
        DECLARE @LogReuse NVARCHAR(60) = NULL;

        BEGIN TRY
            SELECT @CurrentLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC if DMV not available
            BEGIN TRY
                CREATE TABLE #LogSpace (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpace EXEC('DBCC SQLPERF(LOGSPACE)');
                SELECT @CurrentLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpace 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpace;
            END TRY
            BEGIN CATCH
                SET @CurrentLogUsedPct = NULL;
            END CATCH
        END CATCH

        BEGIN TRY
            SELECT @LogReuse = log_reuse_wait_desc
            FROM sys.databases
            WHERE name = DB_NAME();
        END TRY
        BEGIN CATCH
            SET @LogReuse = NULL;
        END CATCH

        PRINT 'Phase B Start - Log Usage: ' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), 'unknown') + 
              '%, Reuse Wait: ' + ISNULL(@LogReuse, 'unknown');

        -- If log usage is high (>70%), force checkpoint before continuing
        IF @CurrentLogUsedPct IS NOT NULL AND @CurrentLogUsedPct > 70.0
        BEGIN
            PRINT 'Log usage elevated (' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                  '%); executing CHECKPOINT before Phase B operations...';
            CHECKPOINT;
            
            -- Log this event for monitoring
            INSERT INTO dbo.ErrorAudit (ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo)
            VALUES (
                GETDATE(), 'UPDATE_ALL2', 0, 
                'Elevated log usage detected at Phase B start', 0,
                'Log usage: ' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                '%, Reuse wait: ' + ISNULL(@LogReuse, 'unknown')
            );
        END

        -- Step 1: CREATE_THE_AVERAGES
        SET @StepStart = SYSDATETIME();
        EXEC dbo.CREATE_THE_AVERAGES;
        SET @StepEnd = SYSDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        PRINT 'CREATE_THE_AVERAGES: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

        -- Step 2: Rebuild EXCEL_FOR_DASHBOARD
        SET @StepStart = SYSDATETIME();
        IF OBJECT_ID('dbo.EXCEL_FOR_DASHBOARD','U') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        EXEC dbo.sp_Rebuild_ExcelForDashboard;
        
        -- ⚡ OPTIMIZATION: Update statistics on newly built table
        IF OBJECT_ID('dbo.EXCEL_FOR_DASHBOARD','U') IS NOT NULL
        BEGIN
            UPDATE STATISTICS dbo.EXCEL_FOR_DASHBOARD WITH SAMPLE 25 PERCENT;
            PRINT 'EXCEL_FOR_DASHBOARD statistics updated';
        END
        
        SET @StepEnd = SYSDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        PRINT 'sp_Rebuild_ExcelForDashboard: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

        -- Step 3: CREATE_DASH2
        SET @StepStart = SYSDATETIME();
        EXEC dbo.CREATE_DASH2;
        SET @StepEnd = SYSDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        PRINT 'CREATE_DASH2: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

        ----------------------------------------------------------------
        -- Step 4a: Refresh EXCEL_FOR_KVK table FIRST (lifted from SP_Stats_for_Upload)
        ----------------------------------------------------------------
        SET @StepStart = SYSDATETIME();
        
        -- Determine which KVK and Scan to use (same logic as SP_Stats_for_Upload)
        DECLARE @LatestKVK_Upload INT;
        DECLARE @MaxScan_Upload INT = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4);
        DECLARE @MatchmakingScan_Upload INT;
        DECLARE @DraftScan_Upload INT;
        DECLARE @ScanToUse_Upload INT;

        SELECT TOP 1 @LatestKVK_Upload = KVKVersion
        FROM dbo.ProcConfig
        WHERE ConfigKey = 'MATCHMAKING_SCAN'
          AND TRY_CAST(ConfigValue AS INT) <= @MaxScan_Upload
        ORDER BY KVKVersion DESC;

        IF @LatestKVK_Upload IS NOT NULL
        BEGIN
            SELECT
                @MatchmakingScan_Upload = MAX(CASE WHEN ConfigKey = 'MATCHMAKING_SCAN' THEN TRY_CAST(ConfigValue AS INT) END),
                @DraftScan_Upload       = MAX(CASE WHEN ConfigKey = 'DRAFTSCAN'        THEN TRY_CAST(ConfigValue AS INT) END)
            FROM dbo.ProcConfig
            WHERE KVKVersion = @LatestKVK_Upload
              AND ConfigKey IN ('MATCHMAKING_SCAN','DRAFTSCAN');

            -- Decide which scan to use
            SET @ScanToUse_Upload = NULL;
            IF @MatchmakingScan_Upload IS NOT NULL AND @MaxScan_Upload >= @MatchmakingScan_Upload
                SET @ScanToUse_Upload = @MatchmakingScan_Upload;
            ELSE IF @DraftScan_Upload IS NOT NULL AND @MaxScan_Upload >= @DraftScan_Upload
                SET @ScanToUse_Upload = @DraftScan_Upload;

            IF @ScanToUse_Upload IS NOT NULL
            BEGIN
                PRINT 'Step 4a: Refreshing EXCEL_FOR_KVK_' + CAST(@LatestKVK_Upload AS VARCHAR(10)) 
                    + ' with ScanOrder=' + CAST(@ScanToUse_Upload AS VARCHAR(10)) + '...';
                
                -- ✅ LIFT: Call sp_ExcelOutput_ByKVK directly here
                EXEC dbo.sp_ExcelOutput_ByKVK @KVK = @LatestKVK_Upload, @Scan = @ScanToUse_Upload;
                
                SET @StepEnd = SYSDATETIME();
                SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
                PRINT 'sp_ExcelOutput_ByKVK: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';
               	
				IF @@TRANCOUNT > 0
                BEGIN
                    COMMIT;
                    PRINT 'Committed EXCEL_FOR_KVK refresh before STATS_FOR_UPLOAD.';
                END

				-- ✅ CRITICAL: Force commit visibility before next step
                PRINT 'Forcing commit flush via CHECKPOINT...';
                CHECKPOINT;
                WAITFOR DELAY '00:00:00.100';  -- 100ms safety buffer

                ----------------------------------------------------------------
                -- Step 4b: Now populate STATS_FOR_UPLOAD (simplified SP)
                ----------------------------------------------------------------
                SET @StepStart = SYSDATETIME();
                EXEC dbo.SP_Stats_for_Upload;  -- Now just does INSERT, no refresh
                SET @StepEnd = SYSDATETIME();
                SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
                PRINT 'SP_Stats_for_Upload: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

				-- Resume Phase B work in a new transaction
                BEGIN TRANSACTION;
            END
            ELSE
            BEGIN
                PRINT 'Step 4: Skipping STATS_FOR_UPLOAD refresh (no valid scan available)';
            END
        END
        ELSE
        BEGIN
            PRINT 'Step 4: Skipping STATS_FOR_UPLOAD refresh (no eligible KVK found)';
        END

        CHECKPOINT;
        WAITFOR DELAY '00:00:00.100';  -- 100ms delay for commit propagation
        
        SET @StepEnd = SYSDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        PRINT 'SP_Stats_for_Upload: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms (includes checkpoint)';

        ----------------------------------------------------------------
        -- ⚡⚡⚡ OPTIMIZED INSERT INTO ALL_STATS_FOR_DASHBAORD ⚡⚡⚡
        ----------------------------------------------------------------
        SET @StepStart = SYSDATETIME();
        
        TRUNCATE TABLE dbo.ALL_STATS_FOR_DASHBAORD;

        INSERT INTO dbo.ALL_STATS_FOR_DASHBAORD WITH (TABLOCK) (
            [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
            [Starting Power], [Power_Delta], [Civilization], [KvKPlayed],
            [MostKvKKill], [MostKvKDead], [MostKvKHeal],
            [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon],
            [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal],
            [Starting T4&T5_KILLS], [T4_KILLS], [T5_KILLS], [T4&T5_Kills],
            [KILLS_OUTSIDE_KVK], [Kill Target], [% of Kill Target],
            [Starting Deads], Deads_Delta, [DEADS_OUTSIDE_KVK],
            [T4_Deads], [T5_Deads], [Dead Target], [% of Dead Target], [% of Dead_Target],
            [Zeroed], [DKP_SCORE], [DKP Target], [% of DKP Target],
            HelpsDelta, RSS_Assist_Delta, RSS_Gathered_Delta,
            [Pass 4 Kills], [Pass 6 Kills], [Pass 7 Kills], [Pass 8 Kills],
            [Pass 4 Deads], [Pass 6 Deads], [Pass 7 Deads], [Pass 8 Deads],
            [Starting HealedTroops], [HealedTroopsDelta],
            [Starting KillPoints], [KillPointsDelta],
            [RangedPoints], [RangedPointsDelta],
            [AutarchTimes],
            [Max_PreKvk_Points], [Max_HonorPoints],
            [PreKvk_Rank], [Honor_Rank], [KVK_NO]
        )
        SELECT
            ed.[Rank], 
            ed.[KVK_RANK], 
            ed.[Gov_ID],
            RTRIM(COALESCE(ed.[Governor_Name], '')) AS [Governor_Name],
            
            -- Numeric columns with COALESCE (handles NULL efficiently)
            COALESCE(ed.[Starting Power], 0),
            COALESCE(ed.[Power_Delta], 0),
            ed.[Civilization],  -- NULL allowed
            COALESCE(ed.[KvKPlayed], 0),
            
            COALESCE(ed.[MostKvKKill], 0),
            COALESCE(ed.[MostKvKDead], 0),
            COALESCE(ed.[MostKvKHeal], 0),
            COALESCE(ed.[Acclaim], 0),
            COALESCE(ed.[HighestAcclaim], 0),
            COALESCE(ed.[AOOJoined], 0),
            COALESCE(ed.[AOOWon], 0),
            COALESCE(ed.[AOOAvgKill], 0),
            COALESCE(ed.[AOOAvgDead], 0),
            COALESCE(ed.[AOOAvgHeal], 0),
            
            COALESCE(ed.[Starting_T4&T5_KILLS], 0),
            COALESCE(ed.[T4_KILLS], 0),
            COALESCE(ed.[T5_KILLS], 0),
            COALESCE(ed.[T4&T5_Kills], 0),
            COALESCE(ed.[KILLS_OUTSIDE_KVK], 0),
            COALESCE(ed.[Kill Target], 0),
            COALESCE(ed.[% of Kill Target], 0),
            
            COALESCE(ed.[Starting_Deads], 0),
            COALESCE(ed.[Deads_Delta], 0),
            COALESCE(ed.[DEADS_OUTSIDE_KVK], 0),
            COALESCE(ed.[T4_Deads], 0),
            COALESCE(ed.[T5_Deads], 0),
            COALESCE(ed.[Dead_Target], 0),
            COALESCE(ed.[% of Dead Target], 0),
            COALESCE(ed.[% of Dead Target], 0),  -- Duplicate column (fix in schema later)
            
            COALESCE(ed.[Zeroed], 0),
            COALESCE(ed.[DKP_SCORE], 0),
            COALESCE(ed.[DKP Target], 0),
            COALESCE(ed.[% of DKP Target], 0),
            
            COALESCE(ed.[HelpsDelta], 0),
            COALESCE(ed.[RSS_Assist_Delta], 0),
            COALESCE(ed.[RSS_Gathered_Delta], 0),
            
            COALESCE(ed.[Pass 4 Kills], 0),
            COALESCE(ed.[Pass 6 Kills], 0),
            COALESCE(ed.[Pass 7 Kills], 0),
            COALESCE(ed.[Pass 8 Kills], 0),
            COALESCE(ed.[Pass 4 Deads], 0),
            COALESCE(ed.[Pass 6 Deads], 0),
            COALESCE(ed.[Pass 7 Deads], 0),
            COALESCE(ed.[Pass 8 Deads], 0),
            
            COALESCE(ed.[Starting_HealedTroops], 0),
            COALESCE(ed.[HealedTroopsDelta], 0),
            COALESCE(ed.[Starting_KillPoints], 0),
            COALESCE(ed.[KillPointsDelta], 0),
            COALESCE(ed.[RangedPoints], 0),
            COALESCE(ed.[RangedPointsDelta], 0),
            COALESCE(ed.[AutarchTimes], 0),
            
            COALESCE(ed.[Max_PreKvk_Points], 0),
            COALESCE(ed.[Max_HonorPoints], 0),
            COALESCE(ed.[PreKvk_Rank], 0),
            COALESCE(ed.[Honor_Rank], 0),
            COALESCE(ed.[KVK_NO], 0)
        FROM dbo.EXCEL_FOR_DASHBOARD AS ed
        WHERE ed.Gov_ID <> 12025033
        OPTION (RECOMPILE);  -- Fresh execution plan with current statistics
        
        DECLARE @RowsInserted INT = @@ROWCOUNT;
        
        -- ⚡ OPTIMIZATION: Update statistics after bulk insert
        UPDATE STATISTICS dbo.ALL_STATS_FOR_DASHBAORD WITH FULLSCAN;
        
        SET @StepEnd = SYSDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        PRINT 'ALL_STATS_FOR_DASHBAORD insert: ' + CAST(@RowsInserted AS VARCHAR(10)) + ' rows, ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';
        
        ----------------------------------------------------------------
        -- Continue with POWER_BY_MONTH and remaining steps
        ----------------------------------------------------------------
        SET @StepStart = SYSDATETIME();
        
        TRUNCATE TABLE dbo.POWER_BY_MONTH;

        INSERT INTO dbo.POWER_BY_MONTH (
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS], 
            DEADS, [MONTH], HealedTroops, RangedPoints
        )
        SELECT 
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
            DEADS, [MONTH], HealedTroops, RangedPoints
        FROM (
            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.KingdomScanData4
            WHERE GovernorID NOT IN (0, 12025033)
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

            UNION ALL

            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.THE_AVERAGES
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)
        ) AS T
        ORDER BY GovernorID, [MONTH];
        
        SET @StepEnd = SYSDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        PRINT 'POWER_BY_MONTH: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

        EXEC dbo.sp_RefreshInactiveGovernors;

        DECLARE @MAXDATE DATETIME = (SELECT TOP 1 ScanDate FROM dbo.KingdomScanData4 ORDER BY ScanDate DESC);

        INSERT INTO dbo.KS (
            KINGDOM_POWER, Governors, KP, [KILL], [DEAD], [CH25], 
            HealedTroops, RangedPoints, [Last Update], KINGDOM_RANK, KINGDOM_SEED
        )
        SELECT
            SUM(CAST([Power] AS BIGINT)), COUNT(GovernorID), SUM([KillPoints]),
            SUM([TOTAL_KILLS]), SUM([DEADS]),
            CAST(SUM(CASE WHEN [City Hall] = 25 THEN 1 ELSE 0 END) AS INT),
            SUM(ISNULL([HealedTroops], 0)), SUM(ISNULL([RangedPoints], 0)),
            @MAXDATE, @actual_param1, @actual_param2
        FROM dbo.KingdomScanData4
        WHERE ScanDate = @MAXDATE;

        EXEC dbo.SUMMARY_PROC;
        EXEC dbo.GOVERNOR_NAMES_PROC;

        TRUNCATE TABLE dbo.SCAN_LIST;

        INSERT INTO dbo.SCAN_LIST (SCANORDER, ScanDate)
        SELECT SCANORDER, ScanDate
        FROM dbo.KingdomScanData4
        GROUP BY SCANORDER, ScanDate;

        ----------------------------------------------------------------
        -- *** NEW: Phase B Completion - Log Management ***
        ----------------------------------------------------------------
        
        -- Force checkpoint to write dirty pages and minimize recovery time
        PRINT 'Executing CHECKPOINT to flush dirty pages...';
        CHECKPOINT;
        PRINT 'CHECKPOINT complete.';

        -- Get final log usage
        DECLARE @FinalLogUsedPct DECIMAL(5,2) = NULL;
        BEGIN TRY
            SELECT @FinalLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC
            BEGIN TRY
                CREATE TABLE #LogSpaceFinal (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpaceFinal EXEC('DBCC SQLPERF(LOGSPACE)');
                SELECT @FinalLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpaceFinal 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpaceFinal;
            END TRY
            BEGIN CATCH
                SET @FinalLogUsedPct = NULL;
            END CATCH
        END CATCH

        -- Insert signal record for Python bot to detect
        IF OBJECT_ID('dbo.LogBackupTriggerQueue', 'U') IS NOT NULL
        BEGIN
            INSERT INTO dbo.LogBackupTriggerQueue (
                TriggerTime, 
                ProcedureName, 
                Reason, 
                LogUsedPctBefore
            )
            VALUES (
                SYSDATETIME(), 
                'UPDATE_ALL2', 
                'post_heavy_operation',
                @FinalLogUsedPct
            );
            PRINT 'Log backup trigger queued (log usage: ' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), 'unknown') + '%).';
        END

        -- Attempt to trigger log backup job (non-blocking, best effort)
        DECLARE @LogBackupTriggered BIT = 0;
        PRINT 'Log backup trigger queued for Python processing.';

        DECLARE @EndTime DATETIME = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
        DECLARE @PhaseBDuration INT = DATEDIFF(MILLISECOND, @PhaseBStart, SYSDATETIME());

        PRINT '========================================';
        PRINT 'Phase B Total: ' + CAST(@PhaseBDuration AS VARCHAR(10)) + 'ms';
        PRINT 'Log Usage: Initial=' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), 'unknown') + 
              '%, Final=' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), 'unknown') + '%';
        PRINT 'Log Backup Triggered: ' + CASE WHEN @LogBackupTriggered = 1 THEN 'Yes' ELSE 'No (queued for Python)' END;
        PRINT '========================================';

        INSERT INTO dbo.SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
        VALUES (
            'UPDATE_ALL2', 'Complete', @EndTime,
            ISNULL((SELECT MAX(LastRunCounter) FROM dbo.SP_TaskStatus WHERE TaskName='UPDATE_ALL2'), 0) + 1,
            @DurationSeconds
        );

        COMMIT;

        INSERT INTO dbo.Update_ALL_Complete (CompletionTime) VALUES (GETDATE());

        SELECT 
            @rowsKS5 AS RowsInsertedKS5,
            @rowsKS4 AS RowsInsertedKS4,
            @DurationSeconds AS DurationSeconds,
            @PhaseBDuration AS PhaseBDurationMS,
            @CurrentLogUsedPct AS LogUsedPctBefore,
            @FinalLogUsedPct AS LogUsedPctAfter,
            @LogBackupTriggered AS LogBackupTriggered,
            'SUCCESS' AS Status;

    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrProc NVARCHAR(200) = ERROR_PROCEDURE();

        INSERT INTO dbo.ErrorAudit (
            ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo
        )
        VALUES (
            GETDATE(), ISNULL(@ErrProc, 'UPDATE_ALL2'), @ErrNum, @ErrMsg, @ErrLine, 
            N'Phase info: KS5_Rows=' + ISNULL(CAST(@rowsKS5 AS NVARCHAR(20)), N'NULL') + 
            N', KS4_Rows=' + ISNULL(CAST(@rowsKS4 AS NVARCHAR(20)), N'NULL')
        );

        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END

