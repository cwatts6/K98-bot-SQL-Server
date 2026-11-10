SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceConfiguration
    @RowsProcessed bigint, @LastBatchRows int, @NewMaxScan int,
    @LargeBatchDue bit, @Generation bigint
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime datetime2=SYSUTCDATETIME();
    DECLARE @MaintenanceRowThreshold int=5000,@MaintenanceHourThreshold int=168;
    IF COALESCE(APPLOCK_MODE('public','K98:post-import-stats:v1','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','k98-legacy-output-snapshot','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','K98:TargetPublication:DeltaPreprocessing','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','K98:maintenance-schema:v1','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Exact maintenance session guards required.',1;
    ----------------------------------------------------------------
    -- Step 6: LIGHTWEIGHT MAINTENANCE
    ----------------------------------------------------------------

    DECLARE @ShouldRunMaintenance BIT = 0;
    DECLARE @LastMaintenanceTime DATETIME2;
    DECLARE @TotalRowsSinceLastMaintenance bigint;

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
            OR COALESCE(@TotalRowsSinceLastMaintenance,0)+(@RowsProcessed-@LastBatchRows) >= @MaintenanceRowThreshold
        BEGIN
            SET @ShouldRunMaintenance = 1;
        END
    END
    ELSE
    BEGIN
        IF @LargeBatchDue=1
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
		UPDATE STATISTICS DeltaMetrics WITH SAMPLE 25 PERCENT;
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
			'DeltaMetrics', 'kingdomscandata4'
        )
        AND OBJECT_SCHEMA_NAME(ips.object_id)=N'dbo'
        AND i.name IS NOT NULL
        AND ips.page_count > 1000;

        SELECT @IndexesChecked = COUNT(*) FROM #IndexFragmentation;

        DECLARE index_cursor CURSOR LOCAL FAST_FORWARD FOR
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
                SET @SQL = N'ALTER INDEX ' + QUOTENAME(@IndexName) + N' ON [dbo].' + QUOTENAME(@TableName) + N' REBUILD WITH (ONLINE = OFF, SORT_IN_TEMPDB = ON, MAXDOP = 2);';
                PRINT 'Rebuilding: ' + @IndexName + ' on ' + @TableName + ' (' + CAST(CAST(@Fragmentation AS DECIMAL(5,2)) AS VARCHAR(10)) + '% fragmented)';
            END
            ELSE
            BEGIN
                SET @SQL = N'ALTER INDEX ' + QUOTENAME(@IndexName) + N' ON [dbo].' + QUOTENAME(@TableName) + N' REORGANIZE;';
                PRINT 'Reorganizing: ' + @IndexName + ' on ' + @TableName + ' (' + CAST(CAST(@Fragmentation AS DECIMAL(5,2)) AS VARCHAR(10)) + '% fragmented)';
            END

            BEGIN TRY
                EXEC sp_executesql @SQL;
                SET @IndexesMaintained = @IndexesMaintained + 1;
            END TRY
            BEGIN CATCH
                THROW; -- Preserve the actual first child failure; never claim successful upkeep.
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
    UPDATE dbo.MaintenanceConfigurationWork SET UpkeepCompletedGeneration=@Generation,
        UpkeepDisposition=CASE WHEN @ShouldRunMaintenance=1 THEN 'complete' ELSE 'ineligible' END WHERE ID=1;
    DECLARE @ElapsedMS INT = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME());

    BEGIN TRY
    IF OBJECT_ID('dbo.DeltaProcessingLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.DeltaProcessingLog (RowsProcessed, LastScanProcessed, ElapsedMS, MaintenanceRan, Notes)
        VALUES (
            @RowsProcessed,
            @NewMaxScan,
            @ElapsedMS,
            @ShouldRunMaintenance,
            CASE
                WHEN @ShouldRunMaintenance = 1 THEN 'Deferred upkeep completed; coalesced rows; maintenance duration only'
                ELSE 'Deferred upkeep not eligible; coalesced rows; maintenance duration only'
            END
        );
    END

    END TRY
    BEGIN CATCH
        UPDATE dbo.MaintenanceConfigurationWork
           SET FirstLogErrorNumber=COALESCE(FirstLogErrorNumber,ERROR_NUMBER()) WHERE ID=1;
        -- The durable upkeep generation above remains independent. A failed
        -- packet cannot automatically replay completed upkeep for a timing log.
        THROW;
    END CATCH;
END;
