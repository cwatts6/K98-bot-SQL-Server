SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CREATE_DELTA_TABLES]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CREATE_DELTA_TABLES] AS' 
END
ALTER PROCEDURE [dbo].[CREATE_DELTA_TABLES]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
    DECLARE @RowsProcessed INT = 0;
    
    -- For low-volume processing (500-2000/day), run maintenance weekly
    DECLARE @MaintenanceRowThreshold INT = 5000; -- ~3-10 days worth
    DECLARE @MaintenanceHourThreshold INT = 168; -- 7 days

    ----------------------------------------------------------------
    -- Step 1: Determine what's already been processed
    ----------------------------------------------------------------
    DECLARE @LastProcessedScan FLOAT;
    
    -- Find the highest scan order we've already processed across all delta tables
    SELECT @LastProcessedScan = ISNULL(MAX(MaxDelta), 0)
    FROM (
        SELECT MAX(DeltaOrder) AS MaxDelta FROM T4T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM DeadsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HelpsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSASSISTDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSGatheredDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM POWERDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM KillPointsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HealedTroopsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RangedPointsDelta
    ) AS AllDeltas;

    -- Safety check: if no data exists, start from scan 0
    IF @LastProcessedScan IS NULL SET @LastProcessedScan = 0;

    ----------------------------------------------------------------
    -- Step 2: Build base data for NEW scans only
    ----------------------------------------------------------------
    SELECT 
        GovernorID,
        SCANORDER,
        SUM(T4_Kills) AS T4_Kills,
        SUM(T5_Kills) AS T5_Kills,
        SUM([T4&T5_Kills]) AS T4T5_Kills,
        SUM([Power]) AS Power,
        SUM([KillPoints]) AS KillPoints,
        SUM([Deads]) AS Deads,
        SUM([Helps]) AS Helps,
        SUM([RSSAssistance]) AS RSSAssist,
        SUM([RSS_Gathered]) AS RSSGathered,
        SUM([HealedTroops]) AS HealedTroops,
        SUM([RangedPoints]) AS RangedPoints
    INTO #NewScans
    FROM dbo.kingdomscandata4
    WHERE SCANORDER > @LastProcessedScan  -- ONLY new scans
    GROUP BY GovernorID, SCANORDER;

    -- Track rows for maintenance decision
    SELECT @RowsProcessed = COUNT(*) FROM #NewScans;

    -- Exit early if no new data
    IF @RowsProcessed = 0
    BEGIN
        PRINT 'No new scans to process.';
        DROP TABLE #NewScans;
        RETURN;
    END

    PRINT 'Processing ' + CAST(@RowsProcessed AS VARCHAR(10)) + ' new scan records...';

    -- Create index for performance
    CREATE CLUSTERED INDEX IX_NewScans ON #NewScans (GovernorID, SCANORDER);

    ----------------------------------------------------------------
    -- Step 3: Get the LAST KNOWN VALUE for each governor (from existing deltas)
    -- This avoids the OUTER APPLY anti-pattern
    ----------------------------------------------------------------
    
    -- Get cumulative values up to @LastProcessedScan
    -- We reconstruct the last known cumulative value from the delta tables
    SELECT 
        GovernorID,
        @LastProcessedScan AS SCANORDER,
        SUM(CASE WHEN DeltaType = 'T4' THEN DeltaValue ELSE 0 END) AS T4_Kills_Cumulative,
        SUM(CASE WHEN DeltaType = 'T5' THEN DeltaValue ELSE 0 END) AS T5_Kills_Cumulative,
        SUM(CASE WHEN DeltaType = 'T4T5' THEN DeltaValue ELSE 0 END) AS T4T5_Kills_Cumulative,
        SUM(CASE WHEN DeltaType = 'Power' THEN DeltaValue ELSE 0 END) AS Power_Cumulative,
        SUM(CASE WHEN DeltaType = 'KillPoints' THEN DeltaValue ELSE 0 END) AS KillPoints_Cumulative,
        SUM(CASE WHEN DeltaType = 'Deads' THEN DeltaValue ELSE 0 END) AS Deads_Cumulative,
        SUM(CASE WHEN DeltaType = 'Helps' THEN DeltaValue ELSE 0 END) AS Helps_Cumulative,
        SUM(CASE WHEN DeltaType = 'RSSAssist' THEN DeltaValue ELSE 0 END) AS RSSAssist_Cumulative,
        SUM(CASE WHEN DeltaType = 'RSSGathered' THEN DeltaValue ELSE 0 END) AS RSSGathered_Cumulative,
        SUM(CASE WHEN DeltaType = 'HealedTroops' THEN DeltaValue ELSE 0 END) AS HealedTroops_Cumulative,
        SUM(CASE WHEN DeltaType = 'RangedPoints' THEN DeltaValue ELSE 0 END) AS RangedPoints_Cumulative
    INTO #LastKnownValues
    FROM (
        SELECT GovernorID, 'T4' AS DeltaType, CAST(T4KILLSDelta AS FLOAT) AS DeltaValue FROM T4KillDelta
        UNION ALL
        SELECT GovernorID, 'T5', CAST(T5KILLSDelta AS FLOAT) FROM T5KillDelta
        UNION ALL
        SELECT GovernorID, 'T4T5', CAST([T4&T5_KILLSDelta] AS FLOAT) FROM T4T5KillDelta
        UNION ALL
        SELECT GovernorID, 'Power', CAST([Power_Delta] AS FLOAT) FROM POWERDelta
        UNION ALL
        SELECT GovernorID, 'KillPoints', CAST(KillPointsDelta AS FLOAT) FROM KillPointsDelta
        UNION ALL
        SELECT GovernorID, 'Deads', CAST(DeadsDelta AS FLOAT) FROM DeadsDelta
        UNION ALL
        SELECT GovernorID, 'Helps', CAST(HelpsDelta AS FLOAT) FROM HelpsDelta
        UNION ALL
        SELECT GovernorID, 'RSSAssist', CAST(RSSAssistDelta AS FLOAT) FROM RSSASSISTDelta
        UNION ALL
        SELECT GovernorID, 'RSSGathered', CAST(RSSGatheredDelta AS FLOAT) FROM RSSGatheredDelta
        UNION ALL
        SELECT GovernorID, 'HealedTroops', CAST(HealedTroopsDelta AS FLOAT) FROM HealedTroopsDelta
        UNION ALL
        SELECT GovernorID, 'RangedPoints', CAST(RangedPointsDelta AS FLOAT) FROM RangedPointsDelta
    ) AS AllDeltas
    GROUP BY GovernorID;

    CREATE CLUSTERED INDEX IX_LastKnown ON #LastKnownValues (GovernorID);

    ----------------------------------------------------------------
    -- Step 4: Calculate deltas using LAG() window function
    -- This is O(n log n) instead of O(n²)
    ----------------------------------------------------------------
    
    ;WITH CumulativeValues AS (
        SELECT
            ns.GovernorID,
            ns.SCANORDER,
            -- Add last known cumulative to current value to get true cumulative
            ISNULL(lk.T4_Kills_Cumulative, 0) + 
                SUM(ISNULL(ns.T4_Kills, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS T4_Kills_Cum,
            
            ISNULL(lk.T5_Kills_Cumulative, 0) + 
                SUM(ISNULL(ns.T5_Kills, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS T5_Kills_Cum,
            
            ISNULL(lk.T4T5_Kills_Cumulative, 0) + 
                SUM(ISNULL(ns.T4T5_Kills, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS T4T5_Kills_Cum,
            
            ISNULL(lk.Power_Cumulative, 0) + 
                SUM(ISNULL(ns.Power, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS Power_Cum,
            
            ISNULL(lk.KillPoints_Cumulative, 0) + 
                SUM(ISNULL(ns.KillPoints, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS KillPoints_Cum,
            
            ISNULL(lk.Deads_Cumulative, 0) + 
                SUM(ISNULL(ns.Deads, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS Deads_Cum,
            
            ISNULL(lk.Helps_Cumulative, 0) + 
                SUM(ISNULL(ns.Helps, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS Helps_Cum,
            
            ISNULL(lk.RSSAssist_Cumulative, 0) + 
                SUM(ISNULL(ns.RSSAssist, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS RSSAssist_Cum,
            
            ISNULL(lk.RSSGathered_Cumulative, 0) + 
                SUM(ISNULL(ns.RSSGathered, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS RSSGathered_Cum,
            
            ISNULL(lk.HealedTroops_Cumulative, 0) + 
                SUM(ISNULL(ns.HealedTroops, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS HealedTroops_Cum,
            
            ISNULL(lk.RangedPoints_Cumulative, 0) + 
                SUM(ISNULL(ns.RangedPoints, 0)) OVER (
                    PARTITION BY ns.GovernorID 
                    ORDER BY ns.SCANORDER 
                    ROWS UNBOUNDED PRECEDING
                ) AS RangedPoints_Cum
        FROM #NewScans ns
        LEFT JOIN #LastKnownValues lk ON ns.GovernorID = lk.GovernorID
    ),
    DeltaCalculations AS (
        SELECT
            GovernorID,
            SCANORDER,
            CAST(T4_Kills_Cum - LAG(T4_Kills_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS FLOAT) AS T4_Delta,
            CAST(T5_Kills_Cum - LAG(T5_Kills_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS FLOAT) AS T5_Delta,
            CAST(T4T5_Kills_Cum - LAG(T4T5_Kills_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS FLOAT) AS T4T5_Delta,
            CAST(Power_Cum - LAG(Power_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS FLOAT) AS Power_Delta,
            CAST(KillPoints_Cum - LAG(KillPoints_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS BIGINT) AS KillPoints_Delta,
            CAST(Deads_Cum - LAG(Deads_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS FLOAT) AS Deads_Delta,
            CAST(Helps_Cum - LAG(Helps_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS FLOAT) AS Helps_Delta,
            CAST(RSSAssist_Cum - LAG(RSSAssist_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS FLOAT) AS RSSAssist_Delta,
            CAST(RSSGathered_Cum - LAG(RSSGathered_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS FLOAT) AS RSSGathered_Delta,
            CAST(HealedTroops_Cum - LAG(HealedTroops_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS BIGINT) AS HealedTroops_Delta,
            CAST(RangedPoints_Cum - LAG(RangedPoints_Cum, 1, 0) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS BIGINT) AS RangedPoints_Delta
        FROM CumulativeValues
    )
    
    ----------------------------------------------------------------
    -- Step 5: INSERT only new deltas (append mode)
    ----------------------------------------------------------------
    INSERT INTO T4KillDelta (GovernorID, DeltaOrder, T4KILLSDelta)
    SELECT GovernorID, SCANORDER, T4_Delta FROM DeltaCalculations;

    INSERT INTO T5KillDelta (GovernorID, DeltaOrder, T5KILLSDelta)
    SELECT GovernorID, SCANORDER, T5_Delta FROM DeltaCalculations;

    INSERT INTO T4T5KillDelta (GovernorID, DeltaOrder, [T4&T5_KILLSDelta])
    SELECT GovernorID, SCANORDER, T4T5_Delta FROM DeltaCalculations;

    INSERT INTO POWERDelta (GovernorID, DeltaOrder, [Power_Delta])
    SELECT GovernorID, SCANORDER, Power_Delta FROM DeltaCalculations;

    INSERT INTO KillPointsDelta (GovernorID, DeltaOrder, KillPointsDelta)
    SELECT GovernorID, SCANORDER, KillPoints_Delta FROM DeltaCalculations;

    INSERT INTO DeadsDelta (GovernorID, DeltaOrder, DeadsDelta)
    SELECT GovernorID, SCANORDER, Deads_Delta FROM DeltaCalculations;

    INSERT INTO HelpsDelta (GovernorID, DeltaOrder, HelpsDelta)
    SELECT GovernorID, SCANORDER, Helps_Delta FROM DeltaCalculations;

    INSERT INTO RSSASSISTDelta (GovernorID, DeltaOrder, RSSAssistDelta)
    SELECT GovernorID, SCANORDER, RSSAssist_Delta FROM DeltaCalculations;

    INSERT INTO RSSGatheredDelta (GovernorID, DeltaOrder, RSSGatheredDelta)
    SELECT GovernorID, SCANORDER, RSSGathered_Delta FROM DeltaCalculations;

    INSERT INTO HealedTroopsDelta (GovernorID, DeltaOrder, HealedTroopsDelta)
    SELECT GovernorID, SCANORDER, HealedTroops_Delta FROM DeltaCalculations;

    INSERT INTO RangedPointsDelta (GovernorID, DeltaOrder, RangedPointsDelta)
    SELECT GovernorID, SCANORDER, RangedPoints_Delta FROM DeltaCalculations;

    -- Cleanup temp tables
    DROP TABLE #NewScans;
    DROP TABLE #LastKnownValues;

    ----------------------------------------------------------------
    -- Step 6: LIGHTWEIGHT MAINTENANCE (Time or Volume Based)
    -- For low-volume environments: weekly maintenance OR after 5000 rows
    ----------------------------------------------------------------
    
    DECLARE @ShouldRunMaintenance BIT = 0;
    DECLARE @LastMaintenanceTime DATETIME2;
    DECLARE @TotalRowsSinceLastMaintenance INT;
    
    -- Check if maintenance log table exists
    IF OBJECT_ID('dbo.DeltaProcessingLog', 'U') IS NOT NULL
    BEGIN
        -- Get last maintenance run time and rows processed since then
        SELECT TOP 1
            @LastMaintenanceTime = ExecutionTime,
            @TotalRowsSinceLastMaintenance = 
                (SELECT SUM(RowsProcessed) 
                 FROM dbo.DeltaProcessingLog 
                 WHERE ExecutionTime > ISNULL((SELECT TOP 1 ExecutionTime 
                                               FROM dbo.DeltaProcessingLog 
                                               WHERE MaintenanceRan = 1 
                                               ORDER BY ExecutionTime DESC), '1900-01-01'))
        FROM dbo.DeltaProcessingLog
        WHERE MaintenanceRan = 1
        ORDER BY ExecutionTime DESC;
        
        -- Determine if maintenance should run
        IF @LastMaintenanceTime IS NULL
            OR DATEDIFF(HOUR, @LastMaintenanceTime, SYSUTCDATETIME()) >= @MaintenanceHourThreshold
            OR @TotalRowsSinceLastMaintenance >= @MaintenanceRowThreshold
        BEGIN
            SET @ShouldRunMaintenance = 1;
        END
    END
    ELSE
    BEGIN
        -- If no log table, use simple row threshold
        IF @RowsProcessed >= @MaintenanceRowThreshold
            SET @ShouldRunMaintenance = 1;
    END
    
    IF @ShouldRunMaintenance = 1
    BEGIN
        PRINT 'Running weekly maintenance...';
        PRINT 'Days since last maintenance: ' + CAST(DATEDIFF(DAY, ISNULL(@LastMaintenanceTime, '1900-01-01'), SYSUTCDATETIME()) AS VARCHAR(10));
        PRINT 'Rows since last maintenance: ' + CAST(ISNULL(@TotalRowsSinceLastMaintenance, @RowsProcessed) AS VARCHAR(10));
        
        -- Update statistics with SAMPLE (faster than FULLSCAN for low-volume changes)
        -- For low-volume environments, sampling is sufficient and much faster
        UPDATE STATISTICS T4KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS T5KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS T4T5KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS POWERDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS KillPointsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS DeadsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS HelpsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RSSASSISTDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RSSGatheredDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS HealedTroopsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RangedPointsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS dbo.kingdomscandata4 WITH SAMPLE 25 PERCENT;
        
        PRINT 'Statistics updated (25% sample).';
        
        -- Lightweight index maintenance (only reorganize, no rebuild unless critical)
        -- For low-volume environments, reorganize is usually sufficient
        DECLARE @TableName NVARCHAR(128);
        DECLARE @IndexName NVARCHAR(128);
        DECLARE @Fragmentation FLOAT;
        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @IndexesChecked INT = 0;
        DECLARE @IndexesMaintained INT = 0;
        
        -- Create temp table to hold fragmentation info
        CREATE TABLE #IndexFragmentation (
            TableName NVARCHAR(128),
            IndexName NVARCHAR(128),
            FragmentationPercent FLOAT,
            PageCount BIGINT
        );
        
        -- Get fragmentation info (LIMITED mode is fastest)
        INSERT INTO #IndexFragmentation
        SELECT 
            OBJECT_NAME(ips.object_id) AS TableName,
            i.name AS IndexName,
            ips.avg_fragmentation_in_percent AS FragmentationPercent,
            ips.page_count AS PageCount
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE OBJECT_NAME(ips.object_id) IN (
            'T4KillDelta', 'T5KillDelta', 'T4T5KillDelta', 'POWERDelta', 
            'KillPointsDelta', 'DeadsDelta', 'HelpsDelta', 'RSSASSISTDelta', 
            'RSSGatheredDelta', 'HealedTroopsDelta', 'RangedPointsDelta',
            'kingdomscandata4'
        )
        AND i.name IS NOT NULL  -- Exclude heaps
        AND ips.page_count > 1000;  -- Only care about indexes with 1000+ pages (8MB+)
        
        SELECT @IndexesChecked = COUNT(*) FROM #IndexFragmentation;
        
        -- Cursor to process each fragmented index
        DECLARE index_cursor CURSOR FOR
        SELECT TableName, IndexName, FragmentationPercent
        FROM #IndexFragmentation
        WHERE FragmentationPercent > 15  -- Higher threshold for low-volume
        ORDER BY FragmentationPercent DESC;
        
        OPEN index_cursor;
        FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @Fragmentation;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Only rebuild if SEVERELY fragmented (>50%), otherwise reorganize
            IF @Fragmentation > 50
            BEGIN
                SET @SQL = N'ALTER INDEX [' + @IndexName + N'] ON [dbo].[' + @TableName + N'] REBUILD WITH (ONLINE = OFF, SORT_IN_TEMPDB = ON, MAXDOP = 2);';
                PRINT 'Rebuilding: ' + @IndexName + ' on ' + @TableName + ' (' + CAST(CAST(@Fragmentation AS DECIMAL(5,2)) AS VARCHAR(10)) + '% fragmented)';
            END
            ELSE
            BEGIN
                SET @SQL = N'ALTER INDEX [' + @IndexName + N'] ON [dbo].[' + @TableName + N'] REORGANIZE;';
                PRINT 'Reorganizing: ' + @IndexName + ' on ' + @TableName + ' (' + CAST(CAST(@Fragmentation AS DECIMAL(5,2)) AS VARCHAR(10)) + '% fragmented)';
            END
            
            -- Execute the maintenance
            BEGIN TRY
                EXEC sp_executesql @SQL;
                SET @IndexesMaintained = @IndexesMaintained + 1;
            END TRY
            BEGIN CATCH
                PRINT 'Warning: Index maintenance failed for ' + @IndexName + ' - ' + ERROR_MESSAGE();
            END CATCH
            
            FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @Fragmentation;
        END
        
        CLOSE index_cursor;
        DEALLOCATE index_cursor;
        DROP TABLE #IndexFragmentation;
        
        PRINT 'Index maintenance: ' + CAST(@IndexesMaintained AS VARCHAR(10)) + ' of ' + CAST(@IndexesChecked AS VARCHAR(10)) + ' indexes maintained.';
    END
    ELSE
    BEGIN
        PRINT 'Skipping maintenance - next scheduled in ' + 
              CAST(@MaintenanceHourThreshold - DATEDIFF(HOUR, ISNULL(@LastMaintenanceTime, SYSUTCDATETIME()), SYSUTCDATETIME()) AS VARCHAR(10)) + 
              ' hours or after ' + 
              CAST(@MaintenanceRowThreshold - ISNULL(@TotalRowsSinceLastMaintenance, 0) AS VARCHAR(10)) + 
              ' more rows.';
    END

    ----------------------------------------------------------------
    -- Step 7: Performance Logging
    ----------------------------------------------------------------
    DECLARE @ElapsedMS INT = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME());
    
    -- Log this execution
    IF OBJECT_ID('dbo.DeltaProcessingLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.DeltaProcessingLog (RowsProcessed, LastScanProcessed, ElapsedMS, MaintenanceRan, Notes)
        VALUES (
            @RowsProcessed, 
            @LastProcessedScan, 
            @ElapsedMS,
            @ShouldRunMaintenance,
            CASE 
                WHEN @ShouldRunMaintenance = 1 THEN 'Weekly maintenance completed'
                ELSE 'Incremental processing (no maintenance)'
            END
        );
    END
    
    PRINT '----------------------------------------';
    PRINT 'Processing completed in ' + CAST(@ElapsedMS AS VARCHAR(10)) + 'ms';
    PRINT 'Rows processed: ' + CAST(@RowsProcessed AS VARCHAR(10));
    IF @RowsProcessed > 0
        PRINT 'Performance: ' + CAST(CAST(@ElapsedMS * 1.0 / @RowsProcessed AS DECIMAL(10,2)) AS VARCHAR(10)) + ' ms/row';
    PRINT '----------------------------------------';

    SET NOCOUNT OFF;
END

