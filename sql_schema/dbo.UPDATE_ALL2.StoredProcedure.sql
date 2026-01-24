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
        ----------------------------------------------------------------
        BEGIN TRANSACTION;

        EXEC dbo.CREATE_THE_AVERAGES;

        IF OBJECT_ID('dbo.EXCEL_FOR_DASHBOARD','U') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        EXEC dbo.sp_Rebuild_ExcelForDashboard;
        EXEC dbo.CREATE_DASH2;
        EXEC dbo.SP_Stats_for_Upload;

        TRUNCATE TABLE dbo.ALL_STATS_FOR_DASHBAORD;

        INSERT INTO dbo.ALL_STATS_FOR_DASHBAORD (
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
            [Max_PreKvk_Points], [Max_HonorPoints],
            [PreKvk_Rank], [Honor_Rank], [KVK_NO]
        )
        SELECT
            ed.[Rank], ed.[KVK_RANK], ed.[Gov_ID],
            ISNULL(RTRIM(ed.[Governor_Name]), ''),
            ISNULL(ed.[Starting Power], 0), ISNULL(ed.[Power_Delta], 0),
            ISNULL(ed.[Civilization], N''), ISNULL(ed.[KvKPlayed], 0),
            ISNULL(ed.[MostKvKKill], 0), ISNULL(ed.[MostKvKDead], 0), ISNULL(ed.[MostKvKHeal], 0),
            ISNULL(ed.[Acclaim], 0), ISNULL(ed.[HighestAcclaim], 0),
            ISNULL(ed.[AOOJoined], 0), ISNULL(ed.[AOOWon], 0),
            ISNULL(ed.[AOOAvgKill], 0), ISNULL(ed.[AOOAvgDead], 0), ISNULL(ed.[AOOAvgHeal], 0),
            ISNULL(ed.[Starting_T4&T5_KILLS], 0), ISNULL(ed.[T4_KILLS], 0),
            ISNULL(ed.[T5_KILLS], 0), ISNULL(ed.[T4&T5_Kills], 0),
            ISNULL(ed.[KILLS_OUTSIDE_KVK], 0), ISNULL(ed.[Kill Target], 0),
            ISNULL(ed.[% of Kill Target], 0),
            ISNULL(ed.[Starting_Deads], 0), ISNULL(ed.[Deads_Delta], 0),
            ISNULL(ed.[DEADS_OUTSIDE_KVK], 0), ISNULL(ed.[T4_Deads], 0), ISNULL(ed.[T5_Deads], 0),
            ISNULL(ed.[Dead_Target], 0), ISNULL(ed.[% of Dead Target], 0),
            ISNULL(ed.[% of Dead_Target], ISNULL(ed.[% of Dead Target], 0)),
            ISNULL(ed.[Zeroed], 0), ISNULL(ed.[DKP_SCORE], 0),
            ISNULL(ed.[DKP Target], 0), ISNULL(ed.[% of DKP Target], 0),
            ISNULL(ed.[HelpsDelta], 0), ISNULL(ed.[RSS_Assist_Delta], 0),
            ISNULL(ed.[RSS_Gathered_Delta], 0),
            ISNULL(ed.[Pass 4 Kills], 0), ISNULL(ed.[Pass 6 Kills], 0),
            ISNULL(ed.[Pass 7 Kills], 0), ISNULL(ed.[Pass 8 Kills], 0),
            ISNULL(ed.[Pass 4 Deads], 0), ISNULL(ed.[Pass 6 Deads], 0),
            ISNULL(ed.[Pass 7 Deads], 0), ISNULL(ed.[Pass 8 Deads], 0),
            ISNULL(ed.[Starting_HealedTroops], 0), ISNULL(ed.[HealedTroopsDelta], 0),
            ISNULL(ed.[Starting_KillPoints], 0), ISNULL(ed.[KillPointsDelta], 0),
            ISNULL(ed.[RangedPoints], 0), ISNULL(ed.[RangedPointsDelta], 0),
            ISNULL(ed.[Max_PreKvk_Points], 0), ISNULL(ed.[Max_HonorPoints], 0),
            ISNULL(ed.[PreKvk_Rank], 0), ISNULL(ed.[Honor_Rank], 0),
            ISNULL(ed.[KVK_NO], 0)
        FROM dbo.EXCEL_FOR_DASHBOARD AS ed
        WHERE ed.Gov_ID <> 12025033;

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

        DECLARE @EndTime DATETIME = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);

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

