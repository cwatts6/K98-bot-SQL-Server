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
    SET XACT_ABORT ON;  -- ✅ Ensures transaction rolls back on any error
    
    DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @NewMaxScan FLOAT = 0;
    
    -- For low-volume processing (500-2000/day), run maintenance weekly
    DECLARE @MaintenanceRowThreshold INT = 5000;
    DECLARE @MaintenanceHourThreshold INT = 168; -- 7 days

    ----------------------------------------------------------------
    -- Step 1: Determine what's already been processed
    ----------------------------------------------------------------
    DECLARE @LastProcessedScan FLOAT;
    
    PRINT '----------------------------------------';
    PRINT 'Starting delta processing at ' + CONVERT(VARCHAR(30), @StartTime, 120);
    
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

    -- ✅ Data integrity check: Verify all delta tables are in sync
    DECLARE @MinMaxDelta FLOAT, @MaxMaxDelta FLOAT;
    SELECT 
        @MinMaxDelta = MIN(MaxDelta),
        @MaxMaxDelta = MAX(MaxDelta)
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
    
    IF @MinMaxDelta <> @MaxMaxDelta
    BEGIN
        PRINT '❌ ERROR: Delta tables are out of sync!';
        PRINT '   Minimum MaxDeltaOrder: ' + CAST(@MinMaxDelta AS VARCHAR(20));
        PRINT '   Maximum MaxDeltaOrder: ' + CAST(@MaxMaxDelta AS VARCHAR(20));
        PRINT '';
        PRINT 'Detailed breakdown:';
        
        SELECT 
            'T4T5KillDelta' AS TableName, 
            MAX(DeltaOrder) AS MaxDeltaOrder, 
            COUNT(*) AS TotalRows 
        FROM T4T5KillDelta
        UNION ALL
        SELECT 'T4KillDelta', MAX(DeltaOrder), COUNT(*) FROM T4KillDelta
        UNION ALL
        SELECT 'T5KillDelta', MAX(DeltaOrder), COUNT(*) FROM T5KillDelta
        UNION ALL
        SELECT 'DeadsDelta', MAX(DeltaOrder), COUNT(*) FROM DeadsDelta
        UNION ALL
        SELECT 'HelpsDelta', MAX(DeltaOrder), COUNT(*) FROM HelpsDelta
        UNION ALL
        SELECT 'RSSASSISTDelta', MAX(DeltaOrder), COUNT(*) FROM RSSASSISTDelta
        UNION ALL
        SELECT 'RSSGatheredDelta', MAX(DeltaOrder), COUNT(*) FROM RSSGatheredDelta
        UNION ALL
        SELECT 'POWERDelta', MAX(DeltaOrder), COUNT(*) FROM POWERDelta
        UNION ALL
        SELECT 'KillPointsDelta', MAX(DeltaOrder), COUNT(*) FROM KillPointsDelta
        UNION ALL
        SELECT 'HealedTroopsDelta', MAX(DeltaOrder), COUNT(*) FROM HealedTroopsDelta
        UNION ALL
        SELECT 'RangedPointsDelta', MAX(DeltaOrder), COUNT(*) FROM RangedPointsDelta
        ORDER BY MaxDeltaOrder DESC;
        
        RAISERROR('Delta tables are out of sync. Please fix manually before proceeding.', 16, 1);
        RETURN;
    END

    IF @LastProcessedScan IS NULL SET @LastProcessedScan = 0;
    
    PRINT 'Last processed scan order: ' + CAST(@LastProcessedScan AS VARCHAR(20));

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
    WHERE SCANORDER > @LastProcessedScan
    GROUP BY GovernorID, SCANORDER;

    SELECT @RowsProcessed = COUNT(*) FROM #NewScans;
    SELECT @NewMaxScan = ISNULL(MAX(SCANORDER), @LastProcessedScan) FROM #NewScans;

    IF @RowsProcessed = 0
    BEGIN
        PRINT 'No new scans to process.';
        PRINT '----------------------------------------';
        DROP TABLE #NewScans;
        RETURN;
    END

    PRINT 'New scan orders found: ' + CAST(@LastProcessedScan AS VARCHAR(20)) + ' to ' + CAST(@NewMaxScan AS VARCHAR(20));
    PRINT 'Processing ' + CAST(@RowsProcessed AS VARCHAR(10)) + ' new scan records...';

    CREATE CLUSTERED INDEX IX_NewScans ON #NewScans (GovernorID, SCANORDER);

----------------------------------------------------------------
-- Step 3: Get ABSOLUTE VALUES at the last processed scan
----------------------------------------------------------------

PRINT 'Calculating absolute values at last processed scan...';

;WITH LastAbsoluteValues AS (
    SELECT 
        GovernorID,
        SUM(T4KILLSDelta) AS T4_Kills_Absolute,
        SUM(T5KILLSDelta) AS T5_Kills_Absolute,
        SUM([T4&T5_KILLSDelta]) AS T4T5_Kills_Absolute,
        SUM([Power_Delta]) AS Power_Absolute,
        SUM(KillPointsDelta) AS KillPoints_Absolute,
        SUM(DeadsDelta) AS Deads_Absolute,
        SUM(HelpsDelta) AS Helps_Absolute,
        SUM(RSSAssistDelta) AS RSSAssist_Absolute,
        SUM(RSSGatheredDelta) AS RSSGathered_Absolute,
        SUM(HealedTroopsDelta) AS HealedTroops_Absolute,
        SUM(RangedPointsDelta) AS RangedPoints_Absolute
    FROM (
        SELECT t4.GovernorID, t4.DeltaOrder, 
               t4.T4KILLSDelta, t5.T5KILLSDelta, t4t5.[T4&T5_KILLSDelta],
               pwr.[Power_Delta], kp.KillPointsDelta, dd.DeadsDelta, 
               hlp.HelpsDelta, rssa.RSSAssistDelta, rssg.RSSGatheredDelta,
               ht.HealedTroopsDelta, rp.RangedPointsDelta
        FROM T4KillDelta t4
        INNER JOIN T5KillDelta t5 ON t4.GovernorID = t5.GovernorID AND t4.DeltaOrder = t5.DeltaOrder
        INNER JOIN T4T5KillDelta t4t5 ON t4.GovernorID = t4t5.GovernorID AND t4.DeltaOrder = t4t5.DeltaOrder
        INNER JOIN POWERDelta pwr ON t4.GovernorID = pwr.GovernorID AND t4.DeltaOrder = pwr.DeltaOrder
        INNER JOIN KillPointsDelta kp ON t4.GovernorID = kp.GovernorID AND t4.DeltaOrder = kp.DeltaOrder
        INNER JOIN DeadsDelta dd ON t4.GovernorID = dd.GovernorID AND t4.DeltaOrder = dd.DeltaOrder
        INNER JOIN HelpsDelta hlp ON t4.GovernorID = hlp.GovernorID AND t4.DeltaOrder = hlp.DeltaOrder
        INNER JOIN RSSASSISTDelta rssa ON t4.GovernorID = rssa.GovernorID AND t4.DeltaOrder = rssa.DeltaOrder
        INNER JOIN RSSGatheredDelta rssg ON t4.GovernorID = rssg.GovernorID AND t4.DeltaOrder = rssg.DeltaOrder
        INNER JOIN HealedTroopsDelta ht ON t4.GovernorID = ht.GovernorID AND t4.DeltaOrder = ht.DeltaOrder
        INNER JOIN RangedPointsDelta rp ON t4.GovernorID = rp.GovernorID AND t4.DeltaOrder = rp.DeltaOrder
        WHERE t4.DeltaOrder <= @LastProcessedScan
    ) AllHistoricalDeltas
    GROUP BY GovernorID
)
SELECT * INTO #LastAbsoluteValues FROM LastAbsoluteValues;

CREATE CLUSTERED INDEX IX_LastAbsolute ON #LastAbsoluteValues (GovernorID);

----------------------------------------------------------------
-- Step 4: Calculate deltas = CurrentValue - PreviousValue
----------------------------------------------------------------

PRINT 'Calculating deltas...';

;WITH AbsoluteValues AS (
    SELECT
        ns.GovernorID,
        ns.SCANORDER,
        ns.T4_Kills AS T4_Current,
        ns.T5_Kills AS T5_Current,
        ns.T4T5_Kills AS T4T5_Current,
        ns.Power AS Power_Current,
        ns.KillPoints AS KillPoints_Current,
        ns.Deads AS Deads_Current,
        ns.Helps AS Helps_Current,
        ns.RSSAssist AS RSSAssist_Current,
        ns.RSSGathered AS RSSGathered_Current,
        ns.HealedTroops AS HealedTroops_Current,
        ns.RangedPoints AS RangedPoints_Current
    FROM #NewScans ns
),
AbsoluteWithLag AS (
    SELECT
        GovernorID,
        SCANORDER,
        T4_Current,
        LAG(T4_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T4_Previous,
        T5_Current,
        LAG(T5_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T5_Previous,
        T4T5_Current,
        LAG(T4T5_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T4T5_Previous,
        Power_Current,
        LAG(Power_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Power_Previous,
        KillPoints_Current,
        LAG(KillPoints_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS KillPoints_Previous,
        Deads_Current,
        LAG(Deads_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Deads_Previous,
        Helps_Current,
        LAG(Helps_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Helps_Previous,
        RSSAssist_Current,
        LAG(RSSAssist_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RSSAssist_Previous,
        RSSGathered_Current,
        LAG(RSSGathered_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RSSGathered_Previous,
        HealedTroops_Current,
        LAG(HealedTroops_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS HealedTroops_Previous,
        RangedPoints_Current,
        LAG(RangedPoints_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RangedPoints_Previous
    FROM AbsoluteValues
),
DeltaCalculations AS (
    SELECT
        awl.GovernorID,
        awl.SCANORDER,
        CAST(ISNULL(awl.T4_Current - ISNULL(awl.T4_Previous, ISNULL(lav.T4_Kills_Absolute, 0)), awl.T4_Current) AS FLOAT) AS T4_Delta,
        CAST(ISNULL(awl.T5_Current - ISNULL(awl.T5_Previous, ISNULL(lav.T5_Kills_Absolute, 0)), awl.T5_Current) AS FLOAT) AS T5_Delta,
        CAST(ISNULL(awl.T4T5_Current - ISNULL(awl.T4T5_Previous, ISNULL(lav.T4T5_Kills_Absolute, 0)), awl.T4T5_Current) AS FLOAT) AS T4T5_Delta,
        CAST(ISNULL(awl.Power_Current - ISNULL(awl.Power_Previous, ISNULL(lav.Power_Absolute, 0)), awl.Power_Current) AS FLOAT) AS Power_Delta,
        CAST(ISNULL(awl.KillPoints_Current - ISNULL(awl.KillPoints_Previous, ISNULL(lav.KillPoints_Absolute, 0)), awl.KillPoints_Current) AS BIGINT) AS KillPoints_Delta,
        CAST(ISNULL(awl.Deads_Current - ISNULL(awl.Deads_Previous, ISNULL(lav.Deads_Absolute, 0)), awl.Deads_Current) AS FLOAT) AS Deads_Delta,
        CAST(ISNULL(awl.Helps_Current - ISNULL(awl.Helps_Previous, ISNULL(lav.Helps_Absolute, 0)), awl.Helps_Current) AS FLOAT) AS Helps_Delta,
        CAST(ISNULL(awl.RSSAssist_Current - ISNULL(awl.RSSAssist_Previous, ISNULL(lav.RSSAssist_Absolute, 0)), awl.RSSAssist_Current) AS FLOAT) AS RSSAssist_Delta,
        CAST(ISNULL(awl.RSSGathered_Current - ISNULL(awl.RSSGathered_Previous, ISNULL(lav.RSSGathered_Absolute, 0)), awl.RSSGathered_Current) AS FLOAT) AS RSSGathered_Delta,
        CAST(ISNULL(awl.HealedTroops_Current - ISNULL(awl.HealedTroops_Previous, ISNULL(lav.HealedTroops_Absolute, 0)), awl.HealedTroops_Current) AS BIGINT) AS HealedTroops_Delta,
        CAST(ISNULL(awl.RangedPoints_Current - ISNULL(awl.RangedPoints_Previous, ISNULL(lav.RangedPoints_Absolute, 0)), awl.RangedPoints_Current) AS BIGINT) AS RangedPoints_Delta
    FROM AbsoluteWithLag awl
    LEFT JOIN #LastAbsoluteValues lav ON awl.GovernorID = lav.GovernorID
)
SELECT * INTO #DeltaCalculations FROM DeltaCalculations;
    
    ----------------------------------------------------------------
    -- Step 5: INSERT with TRANSACTION (all-or-nothing)
    ----------------------------------------------------------------
    
    PRINT 'Inserting deltas into tables (transactional)...';
    
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @InsertedRows INT;
        
        INSERT INTO T4KillDelta (GovernorID, DeltaOrder, T4KILLSDelta)
        SELECT GovernorID, SCANORDER, T4_Delta FROM #DeltaCalculations;
        SET @InsertedRows = @@ROWCOUNT;
        PRINT '  T4KillDelta: ' + CAST(@InsertedRows AS VARCHAR(10)) + ' rows';

        INSERT INTO T5KillDelta (GovernorID, DeltaOrder, T5KILLSDelta)
        SELECT GovernorID, SCANORDER, T5_Delta FROM #DeltaCalculations;
        PRINT '  T5KillDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO T4T5KillDelta (GovernorID, DeltaOrder, [T4&T5_KILLSDelta])
        SELECT GovernorID, SCANORDER, T4T5_Delta FROM #DeltaCalculations;
        PRINT '  T4T5KillDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO POWERDelta (GovernorID, DeltaOrder, [Power_Delta])
        SELECT GovernorID, SCANORDER, Power_Delta FROM #DeltaCalculations;
        PRINT '  POWERDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO KillPointsDelta (GovernorID, DeltaOrder, KillPointsDelta)
        SELECT GovernorID, SCANORDER, KillPoints_Delta FROM #DeltaCalculations;
        PRINT '  KillPointsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO DeadsDelta (GovernorID, DeltaOrder, DeadsDelta)
        SELECT GovernorID, SCANORDER, Deads_Delta FROM #DeltaCalculations;
        PRINT '  DeadsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO HelpsDelta (GovernorID, DeltaOrder, HelpsDelta)
        SELECT GovernorID, SCANORDER, Helps_Delta FROM #DeltaCalculations;
        PRINT '  HelpsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO RSSASSISTDelta (GovernorID, DeltaOrder, RSSAssistDelta)
        SELECT GovernorID, SCANORDER, RSSAssist_Delta FROM #DeltaCalculations;
        PRINT '  RSSASSISTDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO RSSGatheredDelta (GovernorID, DeltaOrder, RSSGatheredDelta)
        SELECT GovernorID, SCANORDER, RSSGathered_Delta FROM #DeltaCalculations;
        PRINT '  RSSGatheredDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO HealedTroopsDelta (GovernorID, DeltaOrder, HealedTroopsDelta)
        SELECT GovernorID, SCANORDER, HealedTroops_Delta FROM #DeltaCalculations;
        PRINT '  HealedTroopsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO RangedPointsDelta (GovernorID, DeltaOrder, RangedPointsDelta)
        SELECT GovernorID, SCANORDER, RangedPoints_Delta FROM #DeltaCalculations;
        PRINT '  RangedPointsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
        
        COMMIT TRANSACTION;
        PRINT '✅ All delta inserts committed successfully.';
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        PRINT '❌ ERROR: Transaction rolled back!';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
        
        -- Cleanup
        DROP TABLE #NewScans;
        DROP TABLE #LastAbsoluteValues;
        DROP TABLE #DeltaCalculations;
        
        RETURN;
    END CATCH

    -- Cleanup temp tables
    DROP TABLE #NewScans;
    DROP TABLE #LastAbsoluteValues;
    DROP TABLE #DeltaCalculations;

    ----------------------------------------------------------------
    -- Step 6: LIGHTWEIGHT MAINTENANCE
    ----------------------------------------------------------------
    
    DECLARE @ShouldRunMaintenance BIT = 0;
    DECLARE @LastMaintenanceTime DATETIME2;
    DECLARE @TotalRowsSinceLastMaintenance INT;
    
    IF OBJECT_ID('dbo.DeltaProcessingLog', 'U') IS NOT NULL
    BEGIN
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
        
        IF @LastMaintenanceTime IS NULL
            OR DATEDIFF(HOUR, @LastMaintenanceTime, SYSUTCDATETIME()) >= @MaintenanceHourThreshold
            OR @TotalRowsSinceLastMaintenance >= @MaintenanceRowThreshold
        BEGIN
            SET @ShouldRunMaintenance = 1;
        END
    END
    ELSE
    BEGIN
        IF @RowsProcessed >= @MaintenanceRowThreshold
            SET @ShouldRunMaintenance = 1;
    END
    
    IF @ShouldRunMaintenance = 1
    BEGIN
        PRINT 'Running weekly maintenance...';
        PRINT 'Days since last maintenance: ' + CAST(DATEDIFF(DAY, ISNULL(@LastMaintenanceTime, '1900-01-01'), SYSUTCDATETIME()) AS VARCHAR(10));
        PRINT 'Rows since last maintenance: ' + CAST(ISNULL(@TotalRowsSinceLastMaintenance, @RowsProcessed) AS VARCHAR(10));
        
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
        
        -- Index maintenance code (same as before)
        DECLARE @TableName NVARCHAR(128);
        DECLARE @IndexName NVARCHAR(128);
        DECLARE @Fragmentation FLOAT;
        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @IndexesChecked INT = 0;
        DECLARE @IndexesMaintained INT = 0;
        
        CREATE TABLE #IndexFragmentation (
            TableName NVARCHAR(128),
            IndexName NVARCHAR(128),
            FragmentationPercent FLOAT,
            PageCount BIGINT
        );
        
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
        AND i.name IS NOT NULL
        AND ips.page_count > 1000;
        
        SELECT @IndexesChecked = COUNT(*) FROM #IndexFragmentation;
        
        DECLARE index_cursor CURSOR FOR
        SELECT TableName, IndexName, FragmentationPercent
        FROM #IndexFragmentation
        WHERE FragmentationPercent > 15
        ORDER BY FragmentationPercent DESC;
        
        OPEN index_cursor;
        FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @Fragmentation;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
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
    
    IF OBJECT_ID('dbo.DeltaProcessingLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.DeltaProcessingLog (RowsProcessed, LastScanProcessed, ElapsedMS, MaintenanceRan, Notes)
        VALUES (
            @RowsProcessed, 
            @NewMaxScan,
            @ElapsedMS,
            @ShouldRunMaintenance,
            CASE 
                WHEN @ShouldRunMaintenance = 1 THEN 'Weekly maintenance completed'
                ELSE 'Incremental processing (no maintenance)'
            END
        );
    END
    
    PRINT '----------------------------------------';
    PRINT '✅ Processing completed in ' + CAST(@ElapsedMS AS VARCHAR(10)) + 'ms';
    PRINT 'Rows processed: ' + CAST(@RowsProcessed AS VARCHAR(10));
    IF @RowsProcessed > 0
        PRINT 'Performance: ' + CAST(CAST(@ElapsedMS * 1.0 / @RowsProcessed AS DECIMAL(10,2)) AS VARCHAR(10)) + ' ms/row';
    PRINT 'New maximum scan order: ' + CAST(@NewMaxScan AS VARCHAR(20));
    PRINT '----------------------------------------';

    SET NOCOUNT OFF;
END

