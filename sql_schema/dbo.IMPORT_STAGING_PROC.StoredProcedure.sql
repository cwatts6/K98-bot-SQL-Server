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
    ----------------------------------------------------------------

    DECLARE @FileExists INT;
    DECLARE @NextScanOrder BIGINT;
    DECLARE @InsertedRows INT = 0;
    DECLARE @LatestDate DATETIME;
    DECLARE @FormattedDate VARCHAR(50);
    DECLARE @MoveCommand NVARCHAR(4000);
    DECLARE @CsvPath NVARCHAR(4000) = N'C:\discord_file_downloader\downloads\stats.csv';

    EXEC master.dbo.xp_fileexist @CsvPath, @FileExists OUTPUT;

    IF @FileExists = 1
    BEGIN
        BEGIN TRY
            TRUNCATE TABLE dbo.IMPORT_STAGING_CSV_RAW;
            TRUNCATE TABLE dbo.IMPORT_STAGING_CSV;

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
                TRY_CAST(NULLIF(REPLACE([Governor ID], ',', ''), '') AS bigint),
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Name]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 200),
                TRY_CAST(NULLIF(REPLACE([Power], ',', ''), '') AS bigint),
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Alliance]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 100),
                TRY_CAST(NULLIF(REPLACE([T1-Kills], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([T2-Kills], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([T3-Kills], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([T4-Kills], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([T5-Kills], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Total Kill Points], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Dead Troops], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Healed Troops], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Rss Assistance], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Alliance Helps], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Rss Gathered], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([City Hall], ',', ''), '') AS int),
                TRY_CAST(NULLIF(REPLACE([Troops Power], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Tech Power], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Building Power], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Commander Power], ',', ''), '') AS bigint),
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Civilization]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 100),
                TRY_CAST(NULLIF(REPLACE([Autarch Times], ',', ''), '') AS int),
                TRY_CAST(NULLIF(REPLACE([Ranged Points], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([KvK Played], ',', ''), '') AS int),
                TRY_CAST(NULLIF(REPLACE([Most KvK Kill], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Most KvK Dead], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Most KvK Heal], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Acclaim], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Highest Acclaim], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([AOO Joined], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([AOO Won], ',', ''), '') AS int),
                TRY_CAST(NULLIF(REPLACE([AOO Avg Kill], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([AOO Avg Dead], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([AOO Avg Heal], ',', ''), '') AS bigint),
                TRY_CAST(NULLIF(REPLACE([Credit], ',', ''), '') AS decimal(5,2)),
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [updated_on]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 200)
            FROM dbo.IMPORT_STAGING_CSV_RAW;

            SELECT @NextScanOrder = ISNULL((SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData4 ORDER BY SCANORDER DESC), 0) + 1;

            TRUNCATE TABLE dbo.IMPORT_STAGING;

            INSERT INTO dbo.IMPORT_STAGING (
                [Name], [Governor ID], [Alliance], [Power],
                [Total Kill Points], [Dead Troops], [T1-Kills], [T2-Kills], [T3-Kills],
                [T4-Kills], [T5-Kills], [Kills (T4+)], [KILLS], [Rss Gathered],
                [Rss Assistance], [Alliance Helps], [ScanDate], [SCANORDER],
                [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power],
                [Updated_on],
                [HealedTroops], [RangedPoints], [Civilization], [KvKPlayed],
                [MostKvKKill], [MostKvKDead], [MostKvKHeal],
                [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon],
                [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct],
                [AutarchTimes]
            )
            SELECT
                RTRIM(ISNULL([Name], '')),
                [Governor ID],
                [Alliance],
                TRY_CAST(REPLACE([Power], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Total Kill Points], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Dead Troops], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([T1-Kills], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([T2-Kills], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([T3-Kills], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([T4-Kills], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([T5-Kills], ',', '') AS BIGINT),
                (ISNULL([T4-Kills], 0) + ISNULL([T5-Kills], 0)),
                (ISNULL([T1-Kills], 0) + ISNULL([T2-Kills], 0) + ISNULL([T3-Kills], 0) + ISNULL([T4-Kills], 0) + ISNULL([T5-Kills], 0)),
                TRY_CAST(REPLACE([Rss Gathered], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Rss Assistance], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Alliance Helps], ',', '') AS BIGINT),
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
                ),
                @NextScanOrder,
                TRY_CAST(REPLACE([Troops Power], ',', '') AS BIGINT),
                TRY_CAST([City Hall] AS INT),
                TRY_CAST(REPLACE([Tech Power], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Building Power], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Commander Power], ',', '') AS BIGINT),
                [updated_on],
                TRY_CAST(REPLACE([Healed Troops], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Ranged Points], ',', '') AS BIGINT),
                [Civilization],
                TRY_CAST([KvK Played] AS INT),
                TRY_CAST(REPLACE([Most KvK Kill], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Most KvK Dead], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Most KvK Heal], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Acclaim], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([Highest Acclaim], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([AOO Joined], ',', '') AS BIGINT),
                TRY_CAST([AOO Won] AS INT),
                TRY_CAST(REPLACE([AOO Avg Kill], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([AOO Avg Dead], ',', '') AS BIGINT),
                TRY_CAST(REPLACE([AOO Avg Heal], ',', '') AS BIGINT),
                TRY_CAST(NULLIF(REPLACE(CONVERT(nvarchar(50), [Credit]), ',', ''), '') AS decimal(5,2)),
                TRY_CAST([Autarch Times] AS INT)
            FROM dbo.IMPORT_STAGING_CSV;

            SET @InsertedRows = @@ROWCOUNT;

            UPDATE dbo.IMPORT_STAGING
            SET ALLIANCE = CASE
                WHEN ALLIANCE = '[k98A]SparTanS$S' THEN '[k98A]SparTanS'
                WHEN ALLIANCE = '[K98B]Trojan$S' THEN '[K98B]TrojanS'
                ELSE ALLIANCE
            END
            WHERE ALLIANCE IN ('[k98A]SparTanS$S', '[K98B]Trojan$S');

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

            SELECT TOP 1 @LatestDate = ScanDate
            FROM dbo.IMPORT_STAGING
            WHERE ScanDate IS NOT NULL
            ORDER BY ScanDate DESC;

            IF @LatestDate IS NULL
                SET @LatestDate = GETDATE();

            SET @FormattedDate = FORMAT(@LatestDate, 'yyyyMMdd_HHmm');
            SET @MoveCommand = 'CMD /C MOVE "' + @CsvPath + '" "C:\discord_file_downloader\downloads\Import_Archive\Stats_' + @FormattedDate + '.csv"';

            DECLARE @dummy_output TABLE (output NVARCHAR(4000));
            INSERT INTO @dummy_output
            EXEC xp_cmdshell @MoveCommand;

            PRINT '--- IMPORT STAGING SUMMARY ---';
            PRINT 'Rows Inserted: ' + CAST(@InsertedRows AS VARCHAR(20));
            PRINT 'ScanOrder Used: ' + CAST(@NextScanOrder AS VARCHAR(20));
            PRINT 'File Moved To: C:\discord_file_downloader\downloads\Import_Archive\Stats_' + @FormattedDate + '.csv';
            PRINT 'File Move Output:';

            SELECT output
            FROM @dummy_output
            WHERE output IS NOT NULL AND LTRIM(RTRIM(output)) <> '';

            RETURN 0;
        END TRY
        BEGIN CATCH
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @ErrLine INT = ERROR_LINE();
            DECLARE @ErrProc NVARCHAR(128) = ERROR_PROCEDURE();

            PRINT 'Error occurred in procedure: ' + ISNULL(@ErrProc, 'Ad-hoc');
            PRINT 'Error line: ' + CAST(@ErrLine AS VARCHAR(10));
            PRINT 'Error message: ' + COALESCE(@ErrMsg, N'(no message)');

            RETURN 1;
        END CATCH
    END
    ELSE
    BEGIN
        PRINT 'Warning: File not found: ' + @CsvPath;
        PRINT 'Import skipped.';
        RETURN 1;
    END
END

