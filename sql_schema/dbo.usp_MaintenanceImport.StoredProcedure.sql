SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceImport @IncludeKS4 bit
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF COALESCE(APPLOCK_MODE('public','K98:TargetPublication:DeltaPreprocessing','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Maintenance delta guard required.',1;
    IF COALESCE(APPLOCK_MODE('public','K98:post-import-stats:v1','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','k98-legacy-output-snapshot','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','K98:maintenance-schema:v1','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Exact maintenance session guards required.',1;
        -- SMART INDEX MAINTENANCE: Only update stats for KS5 (lightweight)
        -- Full index rebuild happens nightly via maintenance job
        PRINT 'Updating statistics for KingdomScanData5 (quick sample)...';
        UPDATE STATISTICS dbo.KingdomScanData5 WITH SAMPLE 20 PERCENT;
        PRINT 'KingdomScanData5 statistics refreshed.';

    IF @IncludeKS4=1
    BEGIN
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

			UPDATE STATISTICS dbo.PlayerScanMeta WITH SAMPLE 25 PERCENT;

            -- Log index maintenance actions
            SELECT * FROM @IndexMaintLog;
    END;
END;
