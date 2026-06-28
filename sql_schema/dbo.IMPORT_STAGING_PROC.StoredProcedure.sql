SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IMPORT_STAGING_PROC] AS' 
END
ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ----------------------------------------------------------------
    -- This procedure:
    -- 1) loads stats.csv into dbo.IMPORT_STAGING_CSV_RAW via BULK INSERT
    -- 2) converts raw text into typed dbo.IMPORT_STAGING_CSV
    -- 3) maps CSV columns into canonical dbo.IMPORT_STAGING
    -- 4) applies a few cleanup fixes, computes deltas against last scan,
    -- 5) archives the CSV file and returns summary info.
    --
    -- Assumptions:
    -- - dbo.IMPORT_STAGING_CSV physical column order and names match the CSV header.
    -- - SQL Server service account has read access to the CSV path.
    ----------------------------------------------------------------

    DECLARE @FileExists INT;
    DECLARE @NextScanOrder BIGINT;
    DECLARE @InsertedRows INT = 0;
    DECLARE @LatestDate DATETIME;
    DECLARE @FormattedDate VARCHAR(50);
    DECLARE @MoveCommand NVARCHAR(4000);
    DECLARE @CsvPath NVARCHAR(4000) = N'C:\discord_file_downloader\downloads\stats.csv';

    -- Check file exists
    EXEC master.dbo.xp_fileexist @CsvPath, @FileExists OUTPUT;

    IF @FileExists = 1
    BEGIN
        BEGIN TRY
            ----------------------------------------------------------------
            -- Step 1: truncate CSV staging tables (fresh load)
            ----------------------------------------------------------------
            TRUNCATE TABLE dbo.IMPORT_STAGING_CSV_RAW;
            TRUNCATE TABLE dbo.IMPORT_STAGING_CSV;

            ----------------------------------------------------------------
            -- Step 2: BULK INSERT CSV -> IMPORT_STAGING_CSV_RAW
            -- Raw text staging preserves Unicode and separates file decoding
            -- from typed conversion diagnostics.
            ----------------------------------------------------------------
            DECLARE @bulksql NVARCHAR(MAX) = N'
                BULK INSERT dbo.IMPORT_STAGING_CSV_RAW
                FROM ''' + REPLACE(@CsvPath, '''', '''''') + N'''
                WITH (
                    FORMAT = ''CSV'',
                    FIRSTROW = 2,
                    FIELDTERMINATOR = '','',
                    FIELDQUOTE = ''"'',
                    ROWTERMINATOR = ''0x0a'',
                    CODEPAGE = ''65001'',
                    TABLOCK
                );';

            EXEC sp_executesql @bulksql;

            ----------------------------------------------------------------
            -- Step 3: Convert raw text staging into typed CSV staging.
            ----------------------------------------------------------------
            INSERT INTO dbo.IMPORT_STAGING_CSV (
                [Governor ID], [Name], [Power], [Alliance], [T1-Kills], [T2-Kills], [T3-Kills],
                [T4-Kills], [T5-Kills], [Total Kill Points], [Dead Troops], [Healed Troops],
                [Rss Assistance], [Alliance Helps], [Rss Gathered], [City Hall], [Troops Power],
                [Tech Power], [Building Power], [Commander Power], [Civilization], [Autarch Times],
                [Ranged Points], [KvK Played], [Most KvK Kill], [Most KvK Dead], [Most KvK Heal],
                [Acclaim], [Highest Acclaim], [AOO Joined], [AOO Won], [AOO Avg Kill],
                [AOO Avg Dead], [AOO Avg Heal], [Credit], [updated_on]
            )
            SELECT
                TRY_CAST(NULLIF(REPLACE([Governor ID], ',', ''), '') AS bigint) AS [Governor ID],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Name]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 200) AS [Name],
                TRY_CAST(NULLIF(REPLACE([Power], ',', ''), '') AS bigint) AS [Power],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Alliance]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 100) AS [Alliance],
                TRY_CAST(NULLIF(REPLACE([T1-Kills], ',', ''), '') AS bigint) AS [T1-Kills],
                TRY_CAST(NULLIF(REPLACE([T2-Kills], ',', ''), '') AS bigint) AS [T2-Kills],
                TRY_CAST(NULLIF(REPLACE([T3-Kills], ',', ''), '') AS bigint) AS [T3-Kills],
                TRY_CAST(NULLIF(REPLACE([T4-Kills], ',', ''), '') AS bigint) AS [T4-Kills],
                TRY_CAST(NULLIF(REPLACE([T5-Kills], ',', ''), '') AS bigint) AS [T5-Kills],
                TRY_CAST(NULLIF(REPLACE([Total Kill Points], ',', ''), '') AS bigint) AS [Total Kill Points],
                TRY_CAST(NULLIF(REPLACE([Dead Troops], ',', ''), '') AS bigint) AS [Dead Troops],
                TRY_CAST(NULLIF(REPLACE([Healed Troops], ',', ''), '') AS bigint) AS [Healed Troops],
                TRY_CAST(NULLIF(REPLACE([Rss Assistance], ',', ''), '') AS bigint) AS [Rss Assistance],
                TRY_CAST(NULLIF(REPLACE([Alliance Helps], ',', ''), '') AS bigint) AS [Alliance Helps],
                TRY_CAST(NULLIF(REPLACE([Rss Gathered], ',', ''), '') AS bigint) AS [Rss Gathered],
                TRY_CAST(NULLIF(REPLACE([City Hall], ',', ''), '') AS int) AS [City Hall],
                TRY_CAST(NULLIF(REPLACE([Troops Power], ',', ''), '') AS bigint) AS [Troops Power],
                TRY_CAST(NULLIF(REPLACE([Tech Power], ',', ''), '') AS bigint) AS [Tech Power],
                TRY_CAST(NULLIF(REPLACE([Building Power], ',', ''), '') AS bigint) AS [Building Power],
                TRY_CAST(NULLIF(REPLACE([Commander Power], ',', ''), '') AS bigint) AS [Commander Power],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Civilization]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 100) AS [Civilization],
                TRY_CAST(NULLIF(REPLACE([Autarch Times], ',', ''), '') AS int) AS [Autarch Times],
                TRY_CAST(NULLIF(REPLACE([Ranged Points], ',', ''), '') AS bigint) AS [Ranged Points],
                TRY_CAST(NULLIF(REPLACE([KvK Played], ',', ''), '') AS int) AS [KvK Played],
                TRY_CAST(NULLIF(REPLACE([Most KvK Kill], ',', ''), '') AS bigint) AS [Most KvK Kill],
                TRY_CAST(NULLIF(REPLACE([Most KvK Dead], ',', ''), '') AS bigint) AS [Most KvK Dead],
                TRY_CAST(NULLIF(REPLACE([Most KvK Heal], ',', ''), '') AS bigint) AS [Most KvK Heal],
                TRY_CAST(NULLIF(REPLACE([Acclaim], ',', ''), '') AS bigint) AS [Acclaim],
                TRY_CAST(NULLIF(REPLACE([Highest Acclaim], ',', ''), '') AS bigint) AS [Highest Acclaim],
                TRY_CAST(NULLIF(REPLACE([AOO Joined], ',', ''), '') AS bigint) AS [AOO Joined],
                TRY_CAST(NULLIF(REPLACE([AOO Won], ',', ''), '') AS int) AS [AOO Won],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Kill], ',', ''), '') AS bigint) AS [AOO Avg Kill],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Dead], ',', ''), '') AS bigint) AS [AOO Avg Dead],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Heal], ',', ''), '') AS bigint) AS [AOO Avg Heal],
                TRY_CAST(NULLIF(REPLACE([Credit], ',', ''), '') AS decimal(5,2)) AS [Credit],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [updated_on]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 200) AS [updated_on]
            FROM dbo.IMPORT_STAGING_CSV_RAW;

            ----------------------------------------------------------------
            -- Step 4: Determine next scan order (preserve original behaviour)
            -- OPTIMIZATION: Use TOP 1 instead of MAX for better performance
            ----------------------------------------------------------------
            SELECT @NextScanOrder = ISNULL((SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData4 ORDER BY SCANORDER DESC), 0) + 1;

            ----------------------------------------------------------------
            -- Step 5: Truncate canonical staging and insert mapped values
            -- OPTIMIZATION: Added AutarchTimes mapping
            ----------------------------------------------------------------
            TRUNCATE TABLE dbo.IMPORT_STAGING;

            INSERT INTO dbo.IMPORT_STAGING (
                [Name], [Governor ID], [Alliance], [Power],
                [Total Kill Points], [Dead Troops], [T1-Kills], [T2-Kills], [T3-Kills],
                [T4-Kills], [T5-Kills], [Kills (T4+)], [KILLS], [Rss Gathered],
                [Rss Assistance], [Alliance Helps], [ScanDate], [SCANORDER],
                [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power],
                [Updated_on],
                -- existing new fields
                [HealedTroops], [RangedPoints], [Civilization], [KvKPlayed],
                [MostKvKKill], [MostKvKDead], [MostKvKHeal],
                [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon],
                [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct],
                -- NEW FIELD
                [AutarchTimes]
            )
            SELECT
                RTRIM(ISNULL([Name], '')) AS [Name],
                [Governor ID] AS [Governor ID],
                [Alliance],
                
                -- OPTIMIZATION: Simplified TRY_CAST (removed redundant CASE/CAST)
                TRY_CAST(REPLACE([Power], ',', '') AS BIGINT) AS [Power],
                TRY_CAST(REPLACE([Total Kill Points], ',', '') AS BIGINT) AS [Total Kill Points],
                TRY_CAST(REPLACE([Dead Troops], ',', '') AS BIGINT) AS [Dead Troops],
                TRY_CAST(REPLACE([T1-Kills], ',', '') AS BIGINT) AS [T1-Kills],
                TRY_CAST(REPLACE([T2-Kills], ',', '') AS BIGINT) AS [T2-Kills],
                TRY_CAST(REPLACE([T3-Kills], ',', '') AS BIGINT) AS [T3-Kills],
                TRY_CAST(REPLACE([T4-Kills], ',', '') AS BIGINT) AS [T4-Kills],
                TRY_CAST(REPLACE([T5-Kills], ',', '') AS BIGINT) AS [T5-Kills],

                -- derived fields - OPTIMIZATION: Use ISNULL to handle NULLs
                (ISNULL([T4-Kills], 0) + ISNULL([T5-Kills], 0)) AS [Kills (T4+)],
                (ISNULL([T1-Kills], 0) + ISNULL([T2-Kills], 0) + ISNULL([T3-Kills], 0) + ISNULL([T4-Kills], 0) + ISNULL([T5-Kills], 0)) AS [KILLS],

                TRY_CAST(REPLACE([Rss Gathered], ',', '') AS BIGINT) AS [RssGathered],
                TRY_CAST(REPLACE([Rss Assistance], ',', '') AS BIGINT) AS [RssAssistance],
                TRY_CAST(REPLACE([Alliance Helps], ',', '') AS BIGINT) AS [AllianceHelps],

                -- convert updated_on string like '19Jan26-15h57m' into DATETIME
                TRY_CAST(
                    CONCAT(
                        '20', SUBSTRING([updated_on], 6, 2), '-',        
                        CASE SUBSTRING([updated_on], 3, 3)
                            WHEN 'Jan' THEN '01'
                            WHEN 'Feb' THEN '02'
                            WHEN 'Mar' THEN '03'
                            WHEN 'Apr' THEN '04'
                            WHEN 'May' THEN '05'
                            WHEN 'Jun' THEN '06'
                            WHEN 'Jul' THEN '07'
                            WHEN 'Aug' THEN '08'
                            WHEN 'Sep' THEN '09'
                            WHEN 'Oct' THEN '10'
                            WHEN 'Nov' THEN '11'
                            WHEN 'Dec' THEN '12'
                        END, '-',
                        SUBSTRING([updated_on], 1, 2), ' ',
                        SUBSTRING([updated_on], 9, 2), ':',
                        SUBSTRING([updated_on], 12, 2), ':00'
                    ) AS DATETIME
                ) AS ScanDate,

                @NextScanOrder AS SCANORDER,

                TRY_CAST(REPLACE([Troops Power], ',', '') AS BIGINT) AS [TroopsPower],
                TRY_CAST([City Hall] AS INT) AS [CityHall],
                TRY_CAST(REPLACE([Tech Power], ',', '') AS BIGINT) AS [TechPower],
                TRY_CAST(REPLACE([Building Power], ',', '') AS BIGINT) AS [BuildingPower],
                TRY_CAST(REPLACE([Commander Power], ',', '') AS BIGINT) AS [CommanderPower],

                [updated_on],

                -- existing new fields mapping
                TRY_CAST(REPLACE([Healed Troops], ',', '') AS BIGINT) AS [HealedTroops],
                TRY_CAST(REPLACE([Ranged Points], ',', '') AS BIGINT) AS [RangedPoints],
                [Civilization] AS [Civilization],
                TRY_CAST([KvK Played] AS INT) AS [KvKPlayed],
                TRY_CAST(REPLACE([Most KvK Kill], ',', '') AS BIGINT) AS [MostKvKKill],
                TRY_CAST(REPLACE([Most KvK Dead], ',', '') AS BIGINT) AS [MostKvKDead],
                TRY_CAST(REPLACE([Most KvK Heal], ',', '') AS BIGINT) AS [MostKvKHeal],
                TRY_CAST(REPLACE([Acclaim], ',', '') AS BIGINT) AS [Acclaim],
                TRY_CAST(REPLACE([Highest Acclaim], ',', '') AS BIGINT) AS [HighestAcclaim],
                TRY_CAST(REPLACE([AOO Joined], ',', '') AS BIGINT) AS [AOOJoined],
                TRY_CAST([AOO Won] AS INT) AS [AOOWon],
                TRY_CAST(REPLACE([AOO Avg Kill], ',', '') AS BIGINT) AS [AOOAvgKill],
                TRY_CAST(REPLACE([AOO Avg Dead], ',', '') AS BIGINT) AS [AOOAvgDead],
                TRY_CAST(REPLACE([AOO Avg Heal], ',', '') AS BIGINT) AS [AOOAvgHeal],
                TRY_CAST(NULLIF(REPLACE(CONVERT(nvarchar(50), [Credit]), ',', ''), '') AS decimal(5,2)) AS [Conduct],
                
                -- NEW FIELD: Autarch Times
                TRY_CAST([Autarch Times] AS INT) AS [AutarchTimes]
                
            FROM dbo.IMPORT_STAGING_CSV;

            SET @InsertedRows = @@ROWCOUNT;

            ----------------------------------------------------------------
            -- Step 6: Clean up known alliance typos
            -- OPTIMIZATION: Batched into single UPDATE for better performance
            ----------------------------------------------------------------
            UPDATE dbo.IMPORT_STAGING
            SET ALLIANCE = CASE 
                WHEN ALLIANCE = '[k98A]SparTanS$S' THEN '[k98A]SparTanS'
                WHEN ALLIANCE = '[K98B]Trojan$S' THEN '[K98B]TrojanS'
                ELSE ALLIANCE
            END
            WHERE ALLIANCE IN ('[k98A]SparTanS$S', '[K98B]Trojan$S');

            ----------------------------------------------------------------
            -- Step 7: Delta update from latest scan (preserve original behaviour)
            ----------------------------------------------------------------
            WITH LatestScan AS (
                SELECT GovernorID,
                       KillPoints, Deads, T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills,
                       [T4&T5_KILLS], [TOTAL_KILLS], RSS_Gathered, RSSAssistance, Helps
                FROM dbo.KingdomScanData4
                WHERE SCANORDER = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)
            )
            UPDATE I
            SET 
                [Total Kill Points] = CASE WHEN I.[Total Kill Points] < K.KillPoints THEN K.KillPoints ELSE I.[Total Kill Points] END,
                [Dead Troops] = CASE WHEN I.[Dead Troops] < K.Deads THEN K.Deads ELSE I.[Dead Troops] END,
                [T1-Kills] = CASE WHEN I.[T1-Kills] < K.T1_Kills THEN K.T1_Kills ELSE I.[T1-Kills] END,
                [T2-Kills] = CASE WHEN I.[T2-Kills] < K.T2_Kills THEN K.T2_Kills ELSE I.[T2-Kills] END,
                [T3-Kills] = CASE WHEN I.[T3-Kills] < K.T3_Kills THEN K.T3_Kills ELSE I.[T3-Kills] END,
                [T4-Kills] = CASE WHEN I.[T4-Kills] < K.T4_Kills THEN K.T4_Kills ELSE I.[T4-Kills] END,
                [T5-Kills] = CASE WHEN I.[T5-Kills] < K.T5_Kills THEN K.T5_Kills ELSE I.[T5-Kills] END,
                [Kills (T4+)] = CASE WHEN I.[Kills (T4+)] < K.[T4&T5_KILLS] THEN K.[T4&T5_KILLS] ELSE I.[Kills (T4+)] END,
                [KILLS] = CASE WHEN I.[KILLS] < K.[TOTAL_KILLS] THEN K.[TOTAL_KILLS] ELSE I.[KILLS] END,
                [RSS Gathered] = CASE WHEN I.[RSS Gathered] < K.RSS_Gathered THEN K.RSS_Gathered ELSE I.[RSS Gathered] END,
                [RSS Assistance] = CASE WHEN I.[RSS Assistance] < K.RSSAssistance THEN K.RSSAssistance ELSE I.[RSS Assistance] END,
                [Alliance Helps] = CASE WHEN I.[Alliance Helps] < K.Helps THEN K.Helps ELSE I.[Alliance Helps] END
            FROM dbo.IMPORT_STAGING AS I
            INNER JOIN LatestScan AS K ON I.[Governor ID] = K.GovernorID;

            ----------------------------------------------------------------
            -- Step 8: Archive the CSV (move to Import_Archive folder with formatted name)
            ----------------------------------------------------------------
            SELECT TOP 1 @LatestDate = ScanDate
            FROM dbo.IMPORT_STAGING
            WHERE ScanDate IS NOT NULL
            ORDER BY ScanDate DESC;

            IF @LatestDate IS NULL
                SET @LatestDate = GETDATE();

            SET @FormattedDate = FORMAT(@LatestDate, 'yyyyMMdd_HHmm');
            SET @MoveCommand = 'CMD /C MOVE "' + @CsvPath + '" "C:\discord_file_downloader\downloads\Import_Archive\Stats_' + @FormattedDate + '.csv"';

            -- OPTIMIZATION: Use table variable instead of temp table for small result set
            DECLARE @dummy_output TABLE (output NVARCHAR(4000));
            INSERT INTO @dummy_output
            EXEC xp_cmdshell @MoveCommand;

            ----------------------------------------------------------------
            -- Step 9: Output summary & cleanup
            ----------------------------------------------------------------
            PRINT '--- IMPORT STAGING SUMMARY ---';
            PRINT 'Rows Inserted: ' + CAST(@InsertedRows AS VARCHAR(20));
            PRINT 'ScanOrder Used: ' + CAST(@NextScanOrder AS VARCHAR(20));
            PRINT 'File Moved To: C:\discord_file_downloader\downloads\Import_Archive\Stats_' + @FormattedDate + '.csv';
            PRINT 'File Move Output:';

            SELECT output 
            FROM @dummy_output 
            WHERE output IS NOT NULL AND LTRIM(RTRIM(output)) <> '';

            RETURN 0; -- Success
        END TRY
        BEGIN CATCH
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @ErrLine INT = ERROR_LINE();
            DECLARE @ErrProc NVARCHAR(128) = ERROR_PROCEDURE();
            
            -- OPTIMIZATION: Enhanced error reporting
            PRINT 'Error occurred in procedure: ' + ISNULL(@ErrProc, 'Ad-hoc');
            PRINT 'Error line: ' + CAST(@ErrLine AS VARCHAR(10));
            PRINT 'Error message: ' + COALESCE(@ErrMsg, N'(no message)');
            
            RETURN 1; -- Failure
        END CATCH
    END
    ELSE
    BEGIN
        PRINT 'Warning: File not found: ' + @CsvPath;
        PRINT 'Import skipped.';
        RETURN 1;
    END
END

