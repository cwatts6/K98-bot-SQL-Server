/*
MigrationId: 20260615_001_add_conduct_reporting_field
Purpose: Add Conduct reporting field sourced from main fallback upload Credit column
Author: cwatts
CreatedUtc: 2026-06-15
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND COLUMN_NAME IN ('Credit','Conduct') ORDER BY TABLE_NAME, COLUMN_NAME;
PostValidationQuery: SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION, NUMERIC_SCALE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND COLUMN_NAME IN ('Credit','Conduct') ORDER BY TABLE_NAME, COLUMN_NAME;
RelatedBotPR:
RelatedSQLPR:

DataSafetyPlanNotes:
- Adds nullable reporting-only columns; no existing data is modified or backfilled.
- Existing old fallback files remain safe because the bot import path now inserts a blank Credit column before updated_on when needed.
- Conduct is not included in KVK target, DKP, delta, or performance scoring calculations.
- Rollback is manual because dependent procedures/views must be reverted before dropping columns.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Add nullable schema columns.
IF OBJECT_ID(N'dbo.IMPORT_STAGING_CSV', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.IMPORT_STAGING_CSV', N'Credit') IS NULL
    ALTER TABLE dbo.IMPORT_STAGING_CSV ADD [Credit] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.IMPORT_STAGING', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.IMPORT_STAGING', N'Conduct') IS NULL
    ALTER TABLE dbo.IMPORT_STAGING ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.KingdomScanData5', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.KingdomScanData5', N'Conduct') IS NULL
    ALTER TABLE dbo.KingdomScanData5 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.KingdomScanData4', N'Conduct') IS NULL
    ALTER TABLE dbo.KingdomScanData4 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.STAGING_STATS', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.STAGING_STATS', N'Conduct') IS NULL
    ALTER TABLE dbo.STAGING_STATS ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.STATS_FOR_UPLOAD', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.STATS_FOR_UPLOAD', N'Conduct') IS NULL
    ALTER TABLE dbo.STATS_FOR_UPLOAD ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_DASHBOARD', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_DASHBOARD', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_DASHBOARD ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.ALL_STATS_FOR_DASHBOARD', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.ALL_STATS_FOR_DASHBOARD', N'Conduct') IS NULL
    ALTER TABLE dbo.ALL_STATS_FOR_DASHBOARD ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.ALL_STATS_FOR_DASHBAORD', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.ALL_STATS_FOR_DASHBAORD', N'Conduct') IS NULL
    ALTER TABLE dbo.ALL_STATS_FOR_DASHBAORD ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.DASH', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.DASH', N'Conduct') IS NULL
    ALTER TABLE dbo.DASH ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.ALL_GOVS', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.ALL_GOVS', N'Conduct') IS NULL
    ALTER TABLE dbo.ALL_GOVS ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_3', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_3', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_3 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_4', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_4', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_4 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_5', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_5', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_5 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_6', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_6', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_6 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_7', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_7', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_7 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_8', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_8', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_8 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_9', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_9', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_9 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_10', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_10', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_10 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_11', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_11', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_11 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_12', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_12', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_12 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_13', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_13', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_13 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_14', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_14', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_14 ADD [Conduct] decimal(5,2) NULL;
GO
IF OBJECT_ID(N'dbo.EXCEL_FOR_KVK_15', N'U') IS NOT NULL AND COL_LENGTH(N'dbo.EXCEL_FOR_KVK_15', N'Conduct') IS NULL
    ALTER TABLE dbo.EXCEL_FOR_KVK_15 ADD [Conduct] decimal(5,2) NULL;
GO

-- Redeploy dbo.IMPORT_STAGING_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IMPORT_STAGING_PROC] AS' 
END
GO
ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ----------------------------------------------------------------
    -- This procedure:
    -- 1) loads stats.csv into dbo.IMPORT_STAGING_CSV via BULK INSERT
    -- 2) maps CSV columns into canonical dbo.IMPORT_STAGING
    -- 3) applies a few cleanup fixes, computes deltas against last scan,
    -- 4) archives the CSV file and returns summary info.
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
            -- Step 1: truncate CSV staging table (fresh load)
            ----------------------------------------------------------------
            TRUNCATE TABLE dbo.IMPORT_STAGING_CSV;

            ----------------------------------------------------------------
            -- Step 2: BULK INSERT CSV -> IMPORT_STAGING_CSV
            -- Uses CSV-format options robust to quoted fields and UTF-8.
            ----------------------------------------------------------------
            DECLARE @bulksql NVARCHAR(MAX) = N'
                BULK INSERT dbo.IMPORT_STAGING_CSV
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
            -- Step 3: Determine next scan order (preserve original behaviour)
            -- OPTIMIZATION: Use TOP 1 instead of MAX for better performance
            ----------------------------------------------------------------
            SELECT @NextScanOrder = ISNULL((SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData4 ORDER BY SCANORDER DESC), 0) + 1;

            ----------------------------------------------------------------
            -- Step 4: Truncate canonical staging and insert mapped values
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
            -- Step 5: Clean up known alliance typos
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
            -- Step 6: Delta update from latest scan (preserve original behaviour)
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
            -- Step 7: Archive the CSV (move to Import_Archive folder with formatted name)
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
            -- Step 8: Output summary & cleanup
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
        PRINT '⚠️ File not found: ' + @CsvPath;
        PRINT 'Import skipped.';
        RETURN 1;
    END
END
GO

-- Redeploy dbo.UPDATE_ALL2.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL2] AS' 
END
GO
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
            , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
        )
        SELECT
              ROW_NUMBER() OVER (ORDER BY [Power] DESC, [Governor ID] ASC) AS PowerRank
            , RTRIM([Name])
            , [Governor ID]
            , NULLIF(
				  LTRIM(RTRIM(
					REPLACE(REPLACE(CONVERT(nvarchar(255), [Alliance]), CHAR(13), ''), CHAR(10), '')
				  )),
				  N''
			  ) AS Alliance
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
            , [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon], [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct]
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
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
            )
            SELECT
                  PowerRank, GovernorName, GovernorID,
                  NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), ''),
                  [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @MaxScanOrder5

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

			EXEC [dbo].[Refresh_PlayerScanMeta] @MinScanOrder = @MaxScanOrder5
			UPDATE STATISTICS dbo.PlayerScanMeta WITH SAMPLE 25 PERCENT;

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
            [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct],
            [Starting T4&T5_KILLS], [T4_KILLS], [T5_KILLS], [T4&T5_Kills],
            [KILLS_OUTSIDE_KVK], [Kill Target], [% of Kill target],
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
            ed.[Conduct],
            
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
		DECLARE @ErrNum  INT = ERROR_NUMBER();
		DECLARE @ErrMsg  NVARCHAR(MAX) = ERROR_MESSAGE();
		DECLARE @ErrLine INT = ERROR_LINE();
		DECLARE @ErrProc NVARCHAR(200) = ERROR_PROCEDURE();

		-- ✅ capture transaction state before doing anything
		DECLARE @XState INT = XACT_STATE();

		-- ✅ if a transaction exists, you MUST rollback first (especially if @XState = -1)
		IF @XState <> 0
			ROLLBACK;

		-- ✅ now you're in autocommit, logging is allowed
		BEGIN TRY
			INSERT INTO dbo.ErrorAudit (
				ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo
			)
			VALUES (
				GETDATE(), ISNULL(@ErrProc, 'UPDATE_ALL2'), @ErrNum, @ErrMsg, @ErrLine,
				N'XACT_STATE=' + CAST(@XState AS NVARCHAR(10)) +
				N'; Phase info: KS5_Rows=' + ISNULL(CAST(@rowsKS5 AS NVARCHAR(20)), N'NULL') +
				N', KS4_Rows=' + ISNULL(CAST(@rowsKS4 AS NVARCHAR(20)), N'NULL')
			);
		END TRY
		BEGIN CATCH
			-- If even logging fails, don't mask the original error
		END CATCH;

		THROW;
	END CATCH
END
GO

-- Redeploy dbo.SP_Stats_for_Upload.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_Stats_for_Upload]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[SP_Stats_for_Upload] AS' 
END
GO
ALTER PROCEDURE [dbo].[SP_Stats_for_Upload]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE 
        @LatestKVK       INT,
        @MaxScan         INT,
        @TableName       NVARCHAR(128),
        @TableNameFull   NVARCHAR(260),
        @sql             NVARCHAR(MAX);



    ------------------------------------------------------------
    -- Step 1: Get max scan available
    ------------------------------------------------------------
    SELECT @MaxScan = MAX(SCANORDER)
    FROM dbo.KingdomScanData4;

    IF @MaxScan IS NULL
    BEGIN
        RAISERROR('SP_Stats_for_Upload: No scan data available.',16,1);
        RETURN;
    END

    ------------------------------------------------------------
    -- Step 2: Get latest eligible KVKVersion
    ------------------------------------------------------------
    SELECT TOP 1 @LatestKVK = KVKVersion
    FROM dbo.ProcConfig
    WHERE ConfigKey = 'MATCHMAKING_SCAN'
      AND TRY_CAST(ConfigValue AS INT) <= @MaxScan
    ORDER BY KVKVersion DESC;

    IF @LatestKVK IS NULL
    BEGIN
        RAISERROR('SP_Stats_for_Upload: no eligible KVK found (MATCHMAKING_SCAN <= max scan).',16,1);
        RETURN;
    END

    ------------------------------------------------------------
    -- FIX: Ensure transaction commits are fully visible
    ------------------------------------------------------------
    PRINT 'SP_Stats_for_Upload: Forcing commit flush via CHECKPOINT...';
    CHECKPOINT;
    
    -- Small safety delay to ensure data visibility
    WAITFOR DELAY '00:00:00.100';  -- 100ms delay

	PRINT 'SP_Stats_for_Upload: Populating STATS_FOR_UPLOAD from EXCEL_FOR_KVK_' + CAST(@LatestKVK AS VARCHAR(10));
    
    ------------------------------------------------------------
    -- Step 5b: Verify statistics on source table
    ------------------------------------------------------------
    SET @TableName = 'EXCEL_FOR_KVK_' + CAST(@LatestKVK AS NVARCHAR(10));
    SET @TableNameFull = QUOTENAME('dbo') + N'.' + QUOTENAME(@TableName);

    -- Check if statistics exist; if not, create them
    IF NOT EXISTS (
        SELECT 1 
        FROM sys.stats s
        INNER JOIN sys.tables t ON s.object_id = t.object_id
        WHERE t.name = @TableName
          AND s.name LIKE '_WA_Sys%' -- Auto-created stats
           OR s.name LIKE 'IX_%'      -- Index stats
    )
    BEGIN
        PRINT 'SP_Stats_for_Upload: No statistics found on ' + @TableName + ', creating...';
        SET @sql = N'UPDATE STATISTICS ' + @TableNameFull + N' WITH FULLSCAN;';
        EXEC sp_executesql @sql;
    END
    ELSE
    BEGIN
        PRINT 'SP_Stats_for_Upload: Statistics already exist on ' + @TableName;
    END

    PRINT 'SP_Stats_for_Upload: Beginning STATS_FOR_UPLOAD population...';

    ------------------------------------------------------------
    -- Step 6: Build table name dynamically
    ------------------------------------------------------------
    -- Already set above in @TableNameFull


    ------------------------------------------------------------
    -- Step 7: Truncate + insert from refreshed table
    ------------------------------------------------------------
    SET @sql = N'TRUNCATE TABLE dbo.STATS_FOR_UPLOAD;';

    SET @sql += N'
    DECLARE @MAXDATE datetime2(0) = (SELECT MAX(ScanDate) FROM dbo.KingdomScanData4);

    DECLARE @X_KVK INT = (
        SELECT TOP 1 TRY_CAST(KVKVersion AS INT)
        FROM dbo.ProcConfig 
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CAST(ConfigValue AS INT) <= (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)
        ORDER BY KVKVersion DESC
    );

    INSERT INTO dbo.STATS_FOR_UPLOAD
    (
        [Rank],[KVK_RANK],[Gov_ID],[Governor_Name],
        [Starting Power],[Power_Delta],
        [Civilization],[KvKPlayed],[MostKvKKill],[MostKvKDead],[MostKvKHeal],
        [Acclaim],[HighestAcclaim],[AOOJoined],[AOOWon],[AOOAvgKill],[AOOAvgDead],[AOOAvgHeal],[Conduct],
        [Starting_T4&T5_KILLS],[T4_KILLS],[T5_KILLS],[T4&T5_Kills],[KILLS_OUTSIDE_KVK],[Kill Target],[% of Kill Target],
        [Starting_Deads],[Deads_Delta],[DEADS_OUTSIDE_KVK],[T4_Deads],[T5_Deads],[Dead_Target],[% of Dead Target],
        [Zeroed],
        [DKP_SCORE],[DKP Target],[% of DKP Target],
        [HelpsDelta],[RSS_Assist_Delta],[RSS_Gathered_Delta],
        [Pass 4 Kills],[Pass 6 Kills],[Pass 7 Kills],[Pass 8 Kills],
        [Pass 4 Deads],[Pass 6 Deads],[Pass 7 Deads],[Pass 8 Deads],
        [Starting_HealedTroops],[HealedTroopsDelta],
        [Starting_KillPoints],[KillPointsDelta],
        [RangedPoints],[RangedPointsDelta],
        [AutarchTimes],
        [Max_PreKvk_Points],[Max_HonorPoints],[PreKvk_Rank],[Honor_Rank],
        [KVK_NO],
        [LAST_REFRESH],[STATUS]
    )
    SELECT
        [Rank],
        [KVK_RANK],
        CAST([Gov_ID] AS bigint) AS [Gov_ID],
        RTRIM([Governor_Name]) AS [Governor_Name],
		[Starting Power],
        ISNULL([Power_Delta],0),
		[Civilization],
        ISNULL([KvKPlayed],0),
        ISNULL([MostKvKKill],0),
        ISNULL([MostKvKDead],0),
        ISNULL([MostKvKHeal],0),
		ISNULL([Acclaim],0),
        ISNULL([HighestAcclaim],0),
        ISNULL([AOOJoined],0),
        ISNULL([AOOWon],0),
        ISNULL([AOOAvgKill],0),
        ISNULL([AOOAvgDead],0),
        ISNULL([AOOAvgHeal],0),
        [Conduct],
		ISNULL([Starting_T4&T5_KILLS],0),
        ISNULL([T4_KILLS],0),
        ISNULL([T5_KILLS],0),
        ISNULL([T4&T5_Kills],0),
        ISNULL([KILLS_OUTSIDE_KVK],0),
        ISNULL([Kill Target],0),
        ISNULL([% of Kill Target],0),
		ISNULL([Starting_Deads],0),
        ISNULL([Deads_Delta],0),
        ISNULL([DEADS_OUTSIDE_KVK],0),
        ISNULL([T4_Deads],0),
        ISNULL([T5_Deads],0),
        ISNULL([Dead_Target],0),
        ISNULL([% of Dead Target],0),
		ISNULL([Zeroed],0),
		ISNULL([DKP_SCORE],0),
        ISNULL([DKP Target],0),
        ISNULL([% of DKP Target],0),
		ISNULL([HelpsDelta],0),
        ISNULL([RSS_Assist_Delta],0),
        ISNULL([RSS_Gathered_Delta],0),
        ISNULL([Pass 4 Kills],0),
        ISNULL([Pass 6 Kills],0),
        ISNULL([Pass 7 Kills],0),
        ISNULL([Pass 8 Kills],0),
        ISNULL([Pass 4 Deads],0),
        ISNULL([Pass 6 Deads],0),
        ISNULL([Pass 7 Deads],0),
        ISNULL([Pass 8 Deads],0),
        ISNULL([Starting_HealedTroops],0),
        ISNULL([HealedTroopsDelta],0),
        ISNULL([Starting_KillPoints],0),
        ISNULL([KillPointsDelta],0),
        ISNULL([RangedPoints],0),
        ISNULL([RangedPointsDelta],0),
        ISNULL([AutarchTimes],0),
        ISNULL([Max_PreKvk_Points],0),
        ISNULL([Max_HonorPoints],0),
        ISNULL([PreKvk_Rank],0),
        ISNULL([Honor_Rank],0),
        [KVK_NO],
        @MAXDATE AS [LAST_REFRESH],
        CASE 
            WHEN CAST([Gov_ID] AS bigint) IN (
                SELECT GovernorID 
                FROM dbo.EXEMPT_FROM_STATS
                WHERE KVK_NO IN (0, @X_KVK)
            ) THEN ''EXEMPT''
            ELSE ''INCLUDED''
        END AS [STATUS]
    FROM ' + @TableNameFull + N';';

    EXEC sp_executesql @sql;

    ------------------------------------------------------------
    -- Step 8: Rebuild/reorganize indexes for optimal performance
    ------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.STATS_FOR_UPLOAD') AND name = N'IX_STATS_FOR_UPLOAD_GovID')
    BEGIN
        ALTER INDEX [IX_STATS_FOR_UPLOAD_GovID] ON dbo.STATS_FOR_UPLOAD REBUILD WITH (ONLINE = OFF);
        PRINT 'SP_Stats_for_Upload: Rebuilt index IX_STATS_FOR_UPLOAD_GovID';
    END

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.STATS_FOR_UPLOAD') AND name = N'IX_STATS_FOR_UPLOAD_KVK_NO')
    BEGIN
        ALTER INDEX [IX_STATS_FOR_UPLOAD_KVK_NO] ON dbo.STATS_FOR_UPLOAD REBUILD WITH (ONLINE = OFF);
        PRINT 'SP_Stats_for_Upload: Rebuilt index IX_STATS_FOR_UPLOAD_KVK_NO';
    END

    UPDATE STATISTICS dbo.STATS_FOR_UPLOAD WITH FULLSCAN;
    PRINT 'SP_Stats_for_Upload: Updated statistics on STATS_FOR_UPLOAD';

    PRINT 'SP_Stats_for_Upload: Completed successfully for KVK ' + CAST(@LatestKVK AS VARCHAR(10)) 
        + ' using scan ' + CAST(@MaxScan AS VARCHAR(10)) 
        + ' at ' + CONVERT(VARCHAR, GETDATE(), 120);
END
GO

-- Redeploy dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ExcelOutput_ByKVK]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_ExcelOutput_ByKVK] AS' 
END
GO
ALTER PROCEDURE [dbo].[sp_ExcelOutput_ByKVK]
	@KVK [int],
	@Scan [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE 
        @CURRENTKVK3      INT,
        @KVK_END_SCAN     INT,
        @LASTKVKEND       INT,
        @PASS4END         INT,
        @PASS6END         INT,
        @PASS7END         INT,
        @PRE_PASS_4_SCAN  INT,
        @MaxAvailableScan INT,
        @LatestScanToUse  INT;

    -- Load KVK config
    SELECT
        @CURRENTKVK3     = CAST(MAX(CASE WHEN ConfigKey = 'CURRENTKVK3'     THEN ConfigValue END) AS INT),
        @KVK_END_SCAN    = CAST(MAX(CASE WHEN ConfigKey = 'KVK_END_SCAN'    THEN ConfigValue END) AS INT),
        @LASTKVKEND      = CAST(MAX(CASE WHEN ConfigKey = 'LASTKVKEND'      THEN ConfigValue END) AS INT),
        @PASS4END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS4END'        THEN ConfigValue END) AS INT),
        @PASS6END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS6END'        THEN ConfigValue END) AS INT),
        @PASS7END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS7END'        THEN ConfigValue END) AS INT),
        @PRE_PASS_4_SCAN = CAST(MAX(CASE WHEN ConfigKey = 'PRE_PASS_4_SCAN' THEN ConfigValue END) AS INT)
    FROM dbo.ProcConfig
    WHERE KVKVersion = @KVK;

    IF @KVK_END_SCAN IS NULL OR @LASTKVKEND IS NULL OR @PRE_PASS_4_SCAN IS NULL
    BEGIN
        RAISERROR('sp_ExcelOutput_ByKVK: Missing KVK window config for KVK=%d (one of KVK_END_SCAN/LASTKVKEND/PRE_PASS_4_SCAN is NULL).', 16, 1, @KVK);
        RETURN;
    END

    -- Cap @Scan to available data (safety if caller passed a future scan)
    SELECT @MaxAvailableScan = MAX(ScanOrder) FROM dbo.KingdomScanData4;
    IF @MaxAvailableScan IS NULL
    BEGIN
        RAISERROR('sp_ExcelOutput_ByKVK: No scan data available.', 16, 1);
        RETURN;
    END
    IF @Scan > @MaxAvailableScan SET @Scan = @MaxAvailableScan;

    -- Determine which scan to use for latest data
    -- For completed KVKs use KVK_END_SCAN, for current KVK use MaxAvailableScan
    SET @LatestScanToUse = CASE 
        WHEN @MaxAvailableScan > @KVK_END_SCAN THEN @KVK_END_SCAN
        ELSE @MaxAvailableScan
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Fresh staging
        TRUNCATE TABLE dbo.STAGING_STATS;

    -----------------------------------------------
    -- Build/refresh ranked PreKvk & Honor tables (so we can join ranks quickly)
    -----------------------------------------------
    EXEC dbo.sp_Build_Prekvk_And_Honor_Rankings;

    -----------------------------------------------
     -- 1. Snapshot (materialize once for reuse) - REDUCED COLUMNS
    -----------------------------------------------
    CREATE TABLE #Snapshot (
        GovernorID        bigint           NOT NULL PRIMARY KEY CLUSTERED,
        GovernorName      nvarchar(255)  NULL,
        PowerRank         int           NULL,
        [Power]           bigint        NULL,
        [Civilization]    nvarchar(100)  NULL,
        [KvKPlayed]       int           NULL,
        [Deads]           bigint        NULL,
        [T4&T5_KILLS]     bigint        NULL,
        [HealedTroops]    bigint        NULL,
        [KillPoints]      bigint        NULL,
        [AutarchTimes]    bigint        NULL,
        MaxPreKvkPoints   bigint        NULL,
        PreKvkRank        int           NULL,
        MaxHonorPoints    bigint        NULL,
        HonorRank         int           NULL,
		RangedPoints     bigint  NULL
    );

    INSERT INTO #Snapshot (
          GovernorID
        , GovernorName
        , PowerRank
        , [Power]
        , [Civilization]
        , [KvKPlayed]
        , [Deads]
        , [T4&T5_KILLS]
        , [HealedTroops]
        , [KillPoints]
        , [AutarchTimes]
        , MaxPreKvkPoints
        , PreKvkRank
        , MaxHonorPoints
        , HonorRank
		, RangedPoints
    )
    SELECT
        ksd.GovernorID,
        ksd.GovernorName,
        ksd.PowerRank,
        ksd.[Power],
        ksd.[Civilization],
        ksd.[KvKPlayed],
		ksd.[Deads],
		ksd.[T4&T5_KILLS], 
		ksd.[HealedTroops], 
		ksd.[KillPoints],
		ksd.[AutarchTimes],
        pk.MaxPreKvkPoints    AS MaxPreKvkPoints,
        pk.PreKvk_Rank        AS PreKvkRank,
        hn.MaxHonorPoints     AS MaxHonorPoints,
        hn.Honor_Rank         AS HonorRank,
		ksd.[RangedPoints]
    FROM dbo.KingdomScanData4 ksd
    LEFT JOIN dbo.PreKvk_Scores_Ranked pk
      ON pk.GovernorID = ksd.GovernorID AND pk.KVK_NO = @CURRENTKVK3
    LEFT JOIN dbo.KVK_Honor_Ranked hn
      ON hn.GovernorID = ksd.GovernorID AND hn.KVK_NO = @CURRENTKVK3
    WHERE ksd.ScanOrder = @Scan;

    -----------------------------------------------
    -- 1b. LATEST data (for completed/current KVK stats)
    -----------------------------------------------
    CREATE TABLE #LATEST (
        GovernorID       bigint  NOT NULL PRIMARY KEY CLUSTERED,
        MostKvKKill      bigint  NULL,
        MostKvKDead      bigint  NULL,
        MostKvKHeal      bigint  NULL,
        Acclaim          bigint  NULL,
        HighestAcclaim   bigint  NULL,
        AOOJoined        bigint  NULL,
        AOOWon           int     NULL,
        AOOAvgKill       bigint  NULL,
        AOOAvgDead       bigint  NULL,
        AOOAvgHeal       bigint  NULL,
        Conduct          decimal(5,2) NULL
    );

    INSERT INTO #LATEST (
          GovernorID
        , MostKvKKill
        , MostKvKDead
        , MostKvKHeal
        , Acclaim
        , HighestAcclaim
        , AOOJoined
        , AOOWon
        , AOOAvgKill
        , AOOAvgDead
        , AOOAvgHeal
        , Conduct
    )
    SELECT
        ksd.GovernorID,
        ksd.MostKvKKill,
        ksd.MostKvKDead,
        ksd.MostKvKHeal,
        ksd.Acclaim,
        ksd.HighestAcclaim,
        ksd.AOOJoined,
        ksd.AOOWon,
        ksd.AOOAvgKill,
        ksd.AOOAvgDead,
        ksd.AOOAvgHeal,
        ksd.Conduct
    FROM dbo.KingdomScanData4 ksd
    WHERE ksd.ScanOrder = @LatestScanToUse;

	CREATE TABLE #GovernorList (
        GovernorID int NOT NULL PRIMARY KEY CLUSTERED
    );

    INSERT INTO #GovernorList (GovernorID)
    SELECT s.GovernorID
    FROM #Snapshot s
    WHERE s.GovernorID IS NOT NULL;

    -----------------------------------------------
    -- 2. Consolidated Deads Delta (filtered to snapshot)
    -----------------------------------------------
    CREATE TABLE #Deads (
        GovernorID        int     NOT NULL PRIMARY KEY CLUSTERED,
        DeadsDelta        bigint  NOT NULL,
        DeadsDeltaOutKVK  bigint  NOT NULL,
        P4DeadsDelta      bigint  NOT NULL,
        P6DeadsDelta      bigint  NOT NULL,
        P7DeadsDelta      bigint  NOT NULL,
        P8DeadsDelta      bigint  NOT NULL
    );

    INSERT INTO #Deads (GovernorID, DeadsDelta, DeadsDeltaOutKVK, P4DeadsDelta, P6DeadsDelta, P7DeadsDelta, P8DeadsDelta)
    SELECT 
        d.GovernorID,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @LASTKVKEND      AND d.DeltaOrder <= @PRE_PASS_4_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @PASS4END THEN d.DeadsDelta ELSE 0 END) AS P4DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS4END        AND d.DeltaOrder <= @PASS6END THEN d.DeadsDelta ELSE 0 END) AS P6DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS6END        AND d.DeltaOrder <= @PASS7END THEN d.DeadsDelta ELSE 0 END) AS P7DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS7END        AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS P8DeadsDelta
    FROM dbo.DeadsDelta d
    INNER JOIN #GovernorList gl ON gl.GovernorID = d.GovernorID
    WHERE d.DeltaOrder > @LASTKVKEND AND d.DeltaOrder <= @KVK_END_SCAN
    GROUP BY d.GovernorID;

    -----------------------------------------------
    -- 3. Consolidated Kills Delta (T4&T5)
    -----------------------------------------------
    CREATE TABLE #Kills (
        GovernorID      int     NOT NULL PRIMARY KEY CLUSTERED,
        T4T5KillsDelta  bigint  NOT NULL,
        KillsOutsideKVK bigint  NOT NULL,
        P4Kills         bigint  NOT NULL,
        P6Kills         bigint  NOT NULL,
        P7Kills         bigint  NOT NULL,
        P8Kills         bigint  NOT NULL
    );

    INSERT INTO #Kills (GovernorID, T4T5KillsDelta, KillsOutsideKVK, P4Kills, P6Kills, P7Kills, P8Kills)
    SELECT 
        k.GovernorID,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
        SUM(CASE WHEN k.DeltaOrder > @LASTKVKEND      AND k.DeltaOrder <= @PRE_PASS_4_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @PASS4END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS4END        AND k.DeltaOrder <= @PASS6END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS6END        AND k.DeltaOrder <= @PASS7END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS7END        AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
    FROM dbo.T4T5KillDelta k
    INNER JOIN #GovernorList gl ON gl.GovernorID = k.GovernorID
    WHERE k.DeltaOrder > @LASTKVKEND AND k.DeltaOrder <= @KVK_END_SCAN
    GROUP BY k.GovernorID;

    -----------------------------------------------
    -- 4. T4 / T5 splits
    -----------------------------------------------
    CREATE TABLE #KillsT4 (
        GovernorID   int     NOT NULL PRIMARY KEY CLUSTERED,
        T4KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT4 (GovernorID, T4KillsDelta)
    SELECT t4.GovernorID, SUM(COALESCE(t4.T4KILLSDelta, 0)) AS T4KillsDelta
    FROM dbo.T4KillDelta t4
    INNER JOIN #GovernorList gl ON gl.GovernorID = t4.GovernorID
    WHERE t4.DeltaOrder > @PRE_PASS_4_SCAN AND t4.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t4.GovernorID;

    CREATE TABLE #KillsT5 (
        GovernorID   int     NOT NULL PRIMARY KEY CLUSTERED,
        T5KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT5 (GovernorID, T5KillsDelta)
    SELECT t5.GovernorID, SUM(COALESCE(t5.T5KILLSDelta, 0)) AS T5KillsDelta
    FROM dbo.T5KillDelta t5
    INNER JOIN #GovernorList gl ON gl.GovernorID = t5.GovernorID
    WHERE t5.DeltaOrder > @PRE_PASS_4_SCAN AND t5.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t5.GovernorID;

	----------------------------------------------- 
	-- 5. KillPointsDelta aggregation (use same window as other deltas) 
	----------------------------------------------- 
    CREATE TABLE #KillPoints (
        GovernorID      int     NOT NULL PRIMARY KEY CLUSTERED,
        KillPointsDelta bigint  NOT NULL
    );

	INSERT INTO #KillPoints (GovernorID, KillPointsDelta)
	SELECT kp.GovernorID, SUM(COALESCE(kp.KillPointsDelta, 0)) AS KillPointsDelta
	FROM dbo.KillPointsDelta kp
    INNER JOIN #GovernorList gl ON gl.GovernorID = kp.GovernorID
	WHERE kp.DeltaOrder > @PRE_PASS_4_SCAN AND kp.DeltaOrder <= @KVK_END_SCAN 
	GROUP BY kp.GovernorID;

    -----------------------------------------------
    -- 6. Other deltas (use @Scan as lower bound)
    -----------------------------------------------
    CREATE TABLE #Helps (
        GovernorID int    NOT NULL PRIMARY KEY CLUSTERED,
        HelpsDelta bigint NOT NULL
    );

    INSERT INTO #Helps (GovernorID, HelpsDelta)
    SELECT h.GovernorID, SUM(COALESCE(h.HelpsDelta, 0)) AS HelpsDelta
    FROM dbo.HelpsDelta h
    INNER JOIN #GovernorList gl ON gl.GovernorID = h.GovernorID
    WHERE h.DeltaOrder > @Scan AND h.DeltaOrder <= @KVK_END_SCAN
    GROUP BY h.GovernorID;

    CREATE TABLE #RSSAssist (
        GovernorID     int    NOT NULL PRIMARY KEY CLUSTERED,
        RSSAssistDelta bigint NOT NULL
    );

    INSERT INTO #RSSAssist (GovernorID, RSSAssistDelta)
    SELECT ra.GovernorID, SUM(COALESCE(ra.RSSASSISTDelta, 0)) AS RSSAssistDelta
    FROM dbo.RSSASSISTDelta ra
    INNER JOIN #GovernorList gl ON gl.GovernorID = ra.GovernorID
    WHERE ra.DeltaOrder > @Scan AND ra.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ra.GovernorID;

    CREATE TABLE #RSSGathered (
        GovernorID       int    NOT NULL PRIMARY KEY CLUSTERED,
        RSSGatheredDelta bigint NOT NULL
    );

    INSERT INTO #RSSGathered (GovernorID, RSSGatheredDelta)
    SELECT rg.GovernorID, SUM(COALESCE(rg.RSSGatheredDelta, 0)) AS RSSGatheredDelta
    FROM dbo.RSSGatheredDelta rg
    INNER JOIN #GovernorList gl ON gl.GovernorID = rg.GovernorID
    WHERE rg.DeltaOrder > @Scan AND rg.DeltaOrder <= @KVK_END_SCAN
    GROUP BY rg.GovernorID;

    CREATE TABLE #Power (
        GovernorID int    NOT NULL PRIMARY KEY CLUSTERED,
        PowerDelta bigint NOT NULL
    );

    INSERT INTO #Power (GovernorID, PowerDelta)
    SELECT p.GovernorID, SUM(COALESCE(p.Power_Delta, 0)) AS PowerDelta
    FROM dbo.PowerDelta p
    INNER JOIN #GovernorList gl ON gl.GovernorID = p.GovernorID
    WHERE p.DeltaOrder > @Scan AND p.DeltaOrder <= @KVK_END_SCAN
    GROUP BY p.GovernorID;

    CREATE TABLE #Healed (
        GovernorID        int    NOT NULL PRIMARY KEY CLUSTERED,
        HealedTroopsDelta bigint NOT NULL
    );

	INSERT INTO #Healed (GovernorID, HealedTroopsDelta)
    SELECT ht.GovernorID, SUM(COALESCE(ht.HealedTroopsDelta, 0)) AS HealedTroopsDelta
    FROM dbo.HealedTroopsDelta ht
    INNER JOIN #GovernorList gl ON gl.GovernorID = ht.GovernorID
    WHERE ht.DeltaOrder > @Scan AND ht.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ht.GovernorID;

    CREATE TABLE #Ranged (
        GovernorID        int    NOT NULL PRIMARY KEY CLUSTERED,
        RangedPointsDelta bigint NOT NULL
    );

	INSERT INTO #Ranged (GovernorID, RangedPointsDelta)
    SELECT r.GovernorID, SUM(COALESCE(r.RangedPointsDelta, 0)) AS RangedPointsDelta
    FROM dbo.RangedPointsDelta r
    INNER JOIN #GovernorList gl ON gl.GovernorID = r.GovernorID
    WHERE r.DeltaOrder > @Scan AND r.DeltaOrder <= @KVK_END_SCAN
    GROUP BY r.GovernorID;

    -----------------------------------------------
    -- 7. Stage - NOW USING #LATEST FOR MOVED COLUMNS
    -----------------------------------------------
	INSERT INTO dbo.STAGING_STATS (
		  GovernorID
		, PowerRank
		, [Power]
		, Power_Delta
		, GovernorName
		, T4KillsDelta
		, T5KillsDelta
		, [T4&T5_KILLSDelta]
		, [KILLS_OUTSIDE_KVK]
		, [P4T4&T5_KILLSDelta]
		, [P6T4&T5_KillsDelta]
		, [P7T4&T5_KillsDelta]
		, [P8T4&T5_KillsDelta]
		, DeadsDelta
		, [DEADS_OUTSIDE_KVK]
		, P4DeadsDelta
		, P6DeadsDelta
		, P7DeadsDelta
		, P8DeadsDelta
		, HelpsDelta
		, RSSASSISTDelta
		, RSSGatheredDelta
		, HealedTroops
		, RangedPoints
		, RangedPointsDelta
		, AutarchTimes
		, Civilization
		, KvKPlayed
		, MostKvKKill
		, MostKvKDead
		, MostKvKHeal
		, Acclaim
		, HighestAcclaim
		, AOOJoined
		, AOOWon
		, AOOAvgKill
		, AOOAvgDead
		, AOOAvgHeal
		, Conduct
		, KillPointsDelta
		, KillPoints
		, HealedTroopsDelta
		, [Starting_Deads]
		, [Starting_T4&T5_KILLS]
		, MaxPreKvkPoints
		, MaxHonorPoints
		, PreKvkRank
		, HonorRank
	)
	SELECT
		  s.GovernorID
		, s.PowerRank
		, s.[Power]
		, COALESCE(p.PowerDelta, 0)                 AS Power_Delta
		, s.GovernorName
		, COALESCE(kt4.T4KillsDelta, 0)             AS T4KillsDelta
		, COALESCE(kt5.T5KillsDelta, 0)             AS T5KillsDelta
		, COALESCE(k.T4T5KillsDelta, 0)             AS [T4&T5_KILLSDelta]
		, COALESCE(k.KillsOutsideKVK, 0)            AS [KILLS_OUTSIDE_KVK]
		, COALESCE(k.P4Kills, 0)                    AS [P4T4&T5_KILLSDelta]
		, COALESCE(k.P6Kills, 0)                    AS [P6T4&T5_KillsDelta]
		, COALESCE(k.P7Kills, 0)                    AS [P7T4&T5_KillsDelta]
		, COALESCE(k.P8Kills, 0)                    AS [P8T4&T5_KillsDelta]
		, COALESCE(d.DeadsDelta, 0)                 AS DeadsDelta
		, COALESCE(d.DeadsDeltaOutKVK, 0)           AS [DEADS_OUTSIDE_KVK]
		, COALESCE(d.P4DeadsDelta, 0)               AS P4DeadsDelta
		, COALESCE(d.P6DeadsDelta, 0)               AS P6DeadsDelta
		, COALESCE(d.P7DeadsDelta, 0)               AS P7DeadsDelta
		, COALESCE(d.P8DeadsDelta, 0)               AS P8DeadsDelta
		, COALESCE(h.HelpsDelta, 0)                 AS HelpsDelta
		, COALESCE(ra.RSSAssistDelta, 0)            AS RSSASSISTDelta
		, COALESCE(rg.RSSGatheredDelta, 0)          AS RSSGatheredDelta
		, COALESCE(s.HealedTroops, 0)               AS HealedTroops
		, COALESCE(s.RangedPoints, 0)             AS RangedPoints        
		, COALESCE(ran.RangedPointsDelta, 0)        AS RangedPointsDelta
		, COALESCE(s.AutarchTimes, 0)               AS AutarchTimes
		, s.Civilization
		, COALESCE(s.KvKPlayed, 0)                  AS KvKPlayed
		, COALESCE(lst.MostKvKKill, 0)              AS MostKvKKill        -- FROM #LATEST
		, COALESCE(lst.MostKvKDead, 0)              AS MostKvKDead        -- FROM #LATEST
		, COALESCE(lst.MostKvKHeal, 0)              AS MostKvKHeal        -- FROM #LATEST
		, COALESCE(lst.Acclaim, 0)                  AS Acclaim            -- FROM #LATEST
		, COALESCE(lst.HighestAcclaim, 0)           AS HighestAcclaim     -- FROM #LATEST
		, COALESCE(lst.AOOJoined, 0)                AS AOOJoined          -- FROM #LATEST
		, COALESCE(lst.AOOWon, 0)                   AS AOOWon             -- FROM #LATEST
		, COALESCE(lst.AOOAvgKill, 0)               AS AOOAvgKill         -- FROM #LATEST
		, COALESCE(lst.AOOAvgDead, 0)               AS AOOAvgDead         -- FROM #LATEST
		, COALESCE(lst.AOOAvgHeal, 0)               AS AOOAvgHeal         -- FROM #LATEST
		, lst.Conduct                                AS Conduct            -- FROM #LATEST
		, COALESCE(kp.KillPointsDelta, 0)           AS KillPointsDelta
		, COALESCE(s.KillPoints, 0)                 AS KillPoints
		, COALESCE(he.HealedTroopsDelta, 0)         AS HealedTroopsDelta
		, COALESCE(s.Deads, 0)                      AS [Starting_Deads]
		, COALESCE(s.[T4&T5_KILLS], 0)              AS [Starting_T4&T5_KILLS]
		, COALESCE(s.MaxPreKvkPoints, 0)            AS MaxPreKvkPoints
		, COALESCE(s.MaxHonorPoints, 0)             AS MaxHonorPoints
		, COALESCE(s.PreKvkRank, 0)                 AS PreKvkRank
		, COALESCE(s.HonorRank, 0)                  AS HonorRank
	FROM #Snapshot s
	LEFT JOIN #LATEST      lst ON lst.GovernorID = s.GovernorID  -- NEW JOIN
	LEFT JOIN #Power       p   ON p.GovernorID   = s.GovernorID
	LEFT JOIN #KillsT4     kt4 ON kt4.GovernorID = s.GovernorID
	LEFT JOIN #KillsT5     kt5 ON kt5.GovernorID = s.GovernorID
	LEFT JOIN #Kills       k   ON k.GovernorID   = s.GovernorID
	LEFT JOIN #KillPoints  kp  ON kp.GovernorID  = s.GovernorID
	LEFT JOIN #Deads       d   ON d.GovernorID   = s.GovernorID
	LEFT JOIN #Helps       h   ON h.GovernorID   = s.GovernorID
	LEFT JOIN #RSSAssist   ra  ON ra.GovernorID  = s.GovernorID
	LEFT JOIN #RSSGathered rg  ON rg.GovernorID  = s.GovernorID
	LEFT JOIN #Healed      he  ON he.GovernorID  = s.GovernorID
	LEFT JOIN #Ranged      ran ON ran.GovernorID = s.GovernorID   
	WHERE s.GovernorID IS NOT NULL;


    -- Cleanup temps from stage step
    DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot, #LATEST, #Healed, #Ranged, #KillPoints, #GovernorList;

    -----------------------------------------------
    -- 8. DKP + HoH (normalize DKP column name)
    -----------------------------------------------
    SELECT  S1.[GovernorID],
            CASE WHEN z.GovernorID = s1.GovernorID
                 THEN ROUND((S1.[T4&T5_KILLSDelta]*3 + (S1.[DeadsDelta] * 0.1) * 8), 0)
                 ELSE ROUND((S1.[T4&T5_KILLSDelta]*3 +  S1.[DeadsDelta]      * 8), 0)
            END AS [DKP_SCORE]
    INTO #DKP
    FROM dbo.STAGING_STATS AS S1
    LEFT JOIN dbo.ZEROED    AS Z ON Z.GovernorID = S1.GovernorID AND Z.ScanOrder = @Scan;

    SELECT GovernorID, MAX(T4_Deads) AS [T4 Deads], MAX(T5_Deads) AS [T5 Deads], MAX(KVK_START_SCANORDER) AS SCANORDER 
    INTO #HD1
    FROM dbo.HoH_Deads 
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 9. Dynamic final table (typed columns!)
    -----------------------------------------------
    DECLARE @ExcelTbl       sysname       = N'EXCEL_FOR_KVK_' + CAST(@KVK AS nvarchar(10));
    DECLARE @TargetsTbl     sysname       = N'TARGETS_'       + CAST(@KVK AS nvarchar(10));
    DECLARE @ExcelTblFull   nvarchar(260) = QUOTENAME('dbo') + N'.' + QUOTENAME(@ExcelTbl);
    DECLARE @TargetsTblFull nvarchar(260) = QUOTENAME('dbo') + N'.' + QUOTENAME(@TargetsTbl);

    DECLARE @sql nvarchar(max) = N'';

    SET @sql += N'DROP TABLE IF EXISTS ' + @ExcelTblFull + N';' + CHAR(10);

    SET @sql += N'
    SELECT TOP (5000)
        CAST(S.[PowerRank] AS int)                                   AS [Rank],
        CAST(ROW_NUMBER() OVER (ORDER BY D.[DKP_SCORE] DESC) AS int) AS [KVK_RANK],
        CAST(S.[GovernorID] AS bigint)                               AS [Gov_ID],
        CAST(S.[GovernorName] AS nvarchar(255))                      AS [Governor_Name],

        CAST(S.[Power] AS bigint)                                    AS [Starting Power],
        CAST(S.Power_Delta AS bigint)                                AS [Power_Delta],

        CAST(S.[Civilization] AS nvarchar(100))                      AS [Civilization],
        CAST(S.[KvKPlayed] AS int)                                   AS [KvKPlayed],
        CAST(S.[MostKvKKill] AS bigint)                              AS [MostKvKKill],
        CAST(S.[MostKvKDead] AS bigint)                              AS [MostKvKDead],
        CAST(S.[MostKvKHeal] AS bigint)                              AS [MostKvKHeal],
        CAST(S.[Acclaim] AS bigint)                                  AS [Acclaim],
        CAST(S.[HighestAcclaim] AS bigint)                           AS [HighestAcclaim],
        CAST(S.[AOOJoined] AS bigint)                                AS [AOOJoined],
        CAST(S.[AOOWon] AS int)                                      AS [AOOWon],
        CAST(S.[AOOAvgKill] AS bigint)                               AS [AOOAvgKill],
        CAST(S.[AOOAvgDead] AS bigint)                               AS [AOOAvgDead],
        CAST(S.[AOOAvgHeal] AS bigint)                               AS [AOOAvgHeal],
        CAST(S.[Conduct] AS decimal(5,2))                             AS [Conduct],

        CAST(S.[Starting_T4&T5_KILLS] AS bigint)                     AS [Starting_T4&T5_KILLS],
        CAST(S.[T4KillsDelta] AS bigint)                             AS [T4_KILLS],
        CAST(S.[T5KillsDelta] AS bigint)                             AS [T5_KILLS],
        CAST(S.[T4&T5_KILLSDelta] AS bigint)                         AS [T4&T5_Kills],
        CAST(S.KILLS_OUTSIDE_KVK AS bigint)                          AS [KILLS_OUTSIDE_KVK],

        CAST(T.[Kill_Target] AS bigint)                                 AS [Kill Target],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE ROUND( (CAST(S.[T4&T5_KILLSDelta] AS decimal(19,2)) / CAST(T.[Kill_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Kill Target],

        CAST(S.[Starting_Deads] AS bigint)                           AS [Starting_Deads],
        CAST(S.[DeadsDelta] AS bigint)                               AS [Deads_Delta],
        CAST(S.DEADS_OUTSIDE_KVK AS bigint)                          AS [DEADS_OUTSIDE_KVK],

        CAST(COALESCE(HD.[T4 Deads], 0) AS bigint)                   AS [T4_Deads],
        CAST(COALESCE(HD.[T5 Deads], 0) AS bigint)                   AS [T5_Deads],

        CAST(T.[Dead_Target] AS bigint)                                 AS [Dead_Target],
        CAST(
            CASE
                WHEN T.[Dead_Target] = 0 THEN 0
                WHEN Z.GovernorID = S.GovernorID
                    THEN ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) * 0.1 / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
                ELSE ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Dead Target],

        CAST(Z.Zeroed AS bit)                                        AS [Zeroed],

        CAST(D.[DKP_SCORE] AS bigint)                                AS [DKP_SCORE],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE (CAST(T.Kill_Target AS bigint) * 3 + CAST(T.Dead_Target AS bigint) * 8)
            END
            AS bigint
        )                                                            AS [DKP Target],

        CAST(
            CASE
                WHEN (CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) = 0 THEN 0
                ELSE ROUND(
                    (CAST(D.[DKP_SCORE] AS decimal(19,2)) /
                     CAST((CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) AS decimal(19,2))) * 100,
                    2
                )
            END
            AS decimal(9,2)
        )                                                            AS [% of DKP Target],

        CAST(S.[HelpsDelta] AS bigint)                               AS [HelpsDelta],
        CAST(S.[RSSASSISTDelta] AS bigint)                           AS [RSS_Assist_Delta],
        CAST(S.[RSSGatheredDelta] AS bigint)                         AS [RSS_Gathered_Delta],

        CAST(S.[P4T4&T5_KillsDelta] AS bigint)                       AS [Pass 4 Kills],
        CAST(S.[P6T4&T5_KillsDelta] AS bigint)                       AS [Pass 6 Kills],
        CAST(S.[P7T4&T5_KillsDelta] AS bigint)                       AS [Pass 7 Kills],
        CAST(S.[P8T4&T5_KillsDelta] AS bigint)                       AS [Pass 8 Kills],

        CAST(S.P4DeadsDelta AS bigint)                               AS [Pass 4 Deads],
        CAST(S.P6DeadsDelta AS bigint)                               AS [Pass 6 Deads],
        CAST(S.P7DeadsDelta AS bigint)                               AS [Pass 7 Deads],
        CAST(S.P8DeadsDelta AS bigint)                               AS [Pass 8 Deads],

        CAST(S.[HealedTroops] AS bigint)                             AS [Starting_HealedTroops],
        CAST(S.[HealedTroopsDelta] AS bigint)                        AS [HealedTroopsDelta],

        CAST(S.[KillPoints] AS bigint)                               AS [Starting_KillPoints],
        CAST(S.[KillPointsDelta] AS bigint)                          AS [KillPointsDelta],

        CAST(S.[RangedPoints] AS bigint)                             AS [RangedPoints],
        CAST(S.[RangedPointsDelta] AS bigint)                        AS [RangedPointsDelta],

        CAST(S.[AutarchTimes] AS bigint)                             AS [AutarchTimes],

        CAST(S.[MaxPreKvkPoints] AS bigint)                          AS [Max_PreKvk_Points],
        CAST(S.[MaxHonorPoints] AS bigint)                           AS [Max_HonorPoints],
        CAST(S.[PreKvkRank] AS bigint)                               AS [PreKvk_Rank],
        CAST(S.[HonorRank] AS bigint)                                AS [Honor_Rank],

        CAST(@pKVK AS int)                                           AS [KVK_NO]
    INTO ' + @ExcelTblFull + N'
    FROM dbo.STAGING_STATS AS S
    LEFT JOIN #HD1  AS HD ON S.GovernorID = HD.GovernorID
    LEFT JOIN ' + @TargetsTblFull + N' AS T ON T.GovernorID = S.GovernorID
    LEFT JOIN #DKP  AS D  ON D.GovernorID = S.GovernorID
    LEFT JOIN dbo.ZEROED AS Z ON Z.GovernorID = S.GovernorID AND Z.ScanOrder = @pScan
    ORDER BY S.PowerRank ASC;';

	IF CHARINDEX(N'COALESCE(HD.[T4 Deads]', @sql) = 0
	BEGIN
		RAISERROR('HD reference missing from SQL string (string likely broken).',16,1);
	END

    EXEC sp_executesql
        @sql,
        N'@pScan int, @pKVK int',
        @pScan = @Scan,
        @pKVK  = @KVK;

	-- Call index creation procedure with BOTH parameters
	EXEC dbo.sp_Create_Excel_For_Kvk_Indexes @FullTableName = @ExcelTblFull, @TableBase = @ExcelTbl;

	-- ✅ NEW: Update statistics for optimal query performance
    DECLARE @UpdateStatsSQL NVARCHAR(MAX) = N'UPDATE STATISTICS ' + @ExcelTblFull + N' WITH FULLSCAN;';
    EXEC sp_executesql @UpdateStatsSQL;
    PRINT 'Updated statistics on ' + @ExcelTblFull + ' with FULLSCAN';

    DROP TABLE IF EXISTS #DKP, #HD1;

    EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;

	        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    PRINT 'Completed KVK ' + CAST(@KVK AS varchar(10))
        + ' with ScanOrder=' + CAST(@Scan AS varchar(20))
        + ', LatestScanUsed=' + CAST(@LatestScanToUse AS varchar(20))
        + ' at ' + CONVERT(varchar, GETDATE(), 120);
END
GO

-- Redeploy dbo.sp_Refresh_View_EXCEL_FOR_KVK_All.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Refresh_View_EXCEL_FOR_KVK_All]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Refresh_View_EXCEL_FOR_KVK_All] AS' 
END
GO
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
            CAST(NULL AS decimal(5,2))   AS [Conduct],

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

            CAST(NULL AS bigint)         AS [AutarchTimes],

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

        @AutarchTimesSrc NVARCHAR(200),
        @ConductSrc NVARCHAR(200),

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

        -- AutarchTimes (new field with backward compatibility)
        SET @AutarchTimesSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='AutarchTimes')
                    THEN '[AutarchTimes]'
                ELSE 'CAST(0 AS bigint)'
            END;

        -- Conduct (reporting-only point-in-time value, backward-compatible)
        SET @ConductSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Conduct')
                    THEN '[Conduct]'
                ELSE 'CAST(NULL AS decimal(5,2))'
            END;

        -- Optional new columns (default if old tables don't have them)
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
    ' + @ConductSrc + ' AS [Conduct],

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

    ' + @AutarchTimesSrc + '   AS [AutarchTimes],

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
GO

-- Redeploy dbo.CREATE_DASH2.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CREATE_DASH2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CREATE_DASH2] AS' 
END
GO
ALTER PROCEDURE [dbo].[CREATE_DASH2]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Ensure transaction rollback on error

    -- Clear target table
    TRUNCATE TABLE dbo.DASH;

    ----------------------------------------------------------------
    -- Step 1: Create #RankingGroups temp table
    -- Optimization: Use VALUES constructor instead of UNION ALL
    ----------------------------------------------------------------
    IF OBJECT_ID('tempdb..#RankingGroups') IS NOT NULL DROP TABLE #RankingGroups;

    SELECT DISTINCT 
        KVK_NO, 
        RankGroup, 
        KVK_Rank_Max
    INTO #RankingGroups
    FROM (
        SELECT DISTINCT
            ed.KVK_NO,
            v.RankGroup,
            v.KVK_Rank_Max
        FROM dbo.EXCEL_FOR_DASHBOARD ed
        CROSS APPLY (
            VALUES 
                ('50', 50),
                ('100', 100),
                ('150', 150)
        ) v(RankGroup, KVK_Rank_Max)
    ) AS t;

    -- Optimization: Add index on temp table for better join performance
    CREATE CLUSTERED INDEX IX_RankingGroups ON #RankingGroups(KVK_NO, RankGroup, KVK_Rank_Max);

    ----------------------------------------------------------------
    -- Step 2: Create #Aggregated temp table (compute averages)
    -- Optimization: Removed redundant CAST to FLOAT, simplified expressions
    ----------------------------------------------------------------
    IF OBJECT_ID('tempdb..#Aggregated') IS NOT NULL DROP TABLE #Aggregated;

    SELECT
        rg.RankGroup AS [RANK],
        rg.RankGroup AS [KVK_RANK],
        CASE rg.RankGroup
            WHEN '50'  THEN '999999997'
            WHEN '100' THEN '999999998'
            WHEN '150' THEN '999999999'
        END AS [Gov_ID],
        CASE rg.RankGroup
            WHEN '50'  THEN 'Top50'
            WHEN '100' THEN 'Top100'
            WHEN '150' THEN 'Kingdom Average'
        END AS [Governor_Name],

        -- Power metrics
        ROUND(AVG(CAST(ed.[Starting Power] AS FLOAT)), 0) AS [Starting Power],
        ROUND(AVG(CAST(ed.[Power_Delta] AS FLOAT)), 0) AS [POWER_DELTA],

        -- Kill metrics
        ROUND(AVG(CAST(ed.[T4_KILLS] AS FLOAT)), 0) AS [T4_KILLS],
        ROUND(AVG(CAST(ed.[T5_KILLS] AS FLOAT)), 0) AS [T5_KILLS],
        ROUND(AVG(CAST(ed.[T4&T5_Kills] AS FLOAT)), 0) AS [T4&T5_Kills],
        ROUND(AVG(CAST(ed.[Starting_T4&T5_KILLS] AS FLOAT)), 0) AS [Starting T4&T5_KILLS],
        ROUND(AVG(CAST(ed.[KILLS_OUTSIDE_KVK] AS FLOAT)), 0) AS [KILLS_OUTSIDE_KVK],

        -- Kill targets
        ROUND(AVG(CAST(ed.[Kill Target] AS FLOAT)), 0) AS [Kill Target],
        ROUND(AVG(CAST(ed.[% of Kill Target] AS FLOAT)), 2) AS [% of Kill target],

        -- Dead metrics (compute current Deads as Starting_Deads + Deads_Delta)
        ROUND(AVG(CAST(ISNULL(ed.[Starting_Deads], 0) + ISNULL(ed.[Deads_Delta], 0) AS FLOAT)), 0) AS [Deads],
        ROUND(AVG(CAST(ed.[T4_Deads] AS FLOAT)), 0) AS [T4_Deads],
        ROUND(AVG(CAST(ed.[T5_Deads] AS FLOAT)), 0) AS [T5_Deads],
        ROUND(AVG(CAST(ed.[Starting_Deads] AS FLOAT)), 0) AS [Starting Deads],
        ROUND(AVG(CAST(ed.[DEADS_OUTSIDE_KVK] AS FLOAT)), 0) AS [DEADS_OUTSIDE_KVK],

        -- Dead targets
        ROUND(AVG(CAST(ed.[Dead_Target] AS FLOAT)), 0) AS [Dead_Target],
        ROUND(AVG(CAST(ed.[% of Dead Target] AS FLOAT)), 2) AS [% of Dead_Target],

        -- Zeroed status (use MAX for aggregation)
        MAX(CAST(ISNULL(ed.[Zeroed], 0) AS INT)) AS [Zeroed],

        -- DKP metrics
        ROUND(AVG(CAST(ed.[DKP_SCORE] AS FLOAT)), 0) AS [DKP_Score],
        ROUND(AVG(CAST(ed.[DKP Target] AS FLOAT)), 0) AS [DKP Target],
        ROUND(AVG(CAST(ed.[% of DKP Target] AS FLOAT)), 2) AS [% of DKP Target],

        -- Pass kills
        ROUND(AVG(CAST(ed.[Pass 4 Kills] AS FLOAT)), 0) AS [Pass 4 Kills],
        ROUND(AVG(CAST(ed.[Pass 6 Kills] AS FLOAT)), 0) AS [Pass 6 Kills],
        ROUND(AVG(CAST(ed.[Pass 7 Kills] AS FLOAT)), 0) AS [Pass 7 Kills],
        ROUND(AVG(CAST(ed.[Pass 8 Kills] AS FLOAT)), 0) AS [Pass 8 Kills],

        -- Pass deads
        ROUND(AVG(CAST(ed.[Pass 4 Deads] AS FLOAT)), 0) AS [Pass 4 Deads],
        ROUND(AVG(CAST(ed.[Pass 6 Deads] AS FLOAT)), 0) AS [Pass 6 Deads],
        ROUND(AVG(CAST(ed.[Pass 7 Deads] AS FLOAT)), 0) AS [Pass 7 Deads],
        ROUND(AVG(CAST(ed.[Pass 8 Deads] AS FLOAT)), 0) AS [Pass 8 Deads],

        -- Assistance and RSS (EXCEL stores deltas)
        ROUND(AVG(CAST(ed.[HelpsDelta] AS FLOAT)), 0) AS [Helps],
        ROUND(AVG(CAST(ed.[RSS_Assist_Delta] AS FLOAT)), 0) AS [RSS_Assist],
        ROUND(AVG(CAST(ed.[RSS_Gathered_Delta] AS FLOAT)), 0) AS [RSS_Gathered],

        -- Healed troops and related
        ROUND(AVG(CAST(ed.[Starting_HealedTroops] AS FLOAT)), 0) AS [Starting HealedTroops],
        ROUND(AVG(CAST(ed.[HealedTroopsDelta] AS FLOAT)), 0) AS [HealedTroopsDelta],
        ROUND(AVG(CAST(ed.[Starting_KillPoints] AS FLOAT)), 0) AS [Starting KillPoints],
        ROUND(AVG(CAST(ed.[KillPointsDelta] AS FLOAT)), 0) AS [KillPointsDelta],
        ROUND(AVG(CAST(ed.[RangedPoints] AS FLOAT)), 0) AS [RangedPoints],
        ROUND(AVG(CAST(ed.[RangedPointsDelta] AS FLOAT)), 0) AS [RangedPointsDelta],

        -- Gameplay summary
        ROUND(AVG(CAST(ed.[KvKPlayed] AS FLOAT)), 0) AS [KvKPlayed],
        ROUND(AVG(CAST(ed.[MostKvKKill] AS FLOAT)), 0) AS [MostKvKKill],
        ROUND(AVG(CAST(ed.[MostKvKDead] AS FLOAT)), 0) AS [MostKvKDead],
        ROUND(AVG(CAST(ed.[MostKvKHeal] AS FLOAT)), 0) AS [MostKvKHeal],
        ROUND(AVG(CAST(ed.[Acclaim] AS FLOAT)), 0) AS [Acclaim],
        ROUND(AVG(CAST(ed.[HighestAcclaim] AS FLOAT)), 0) AS [HighestAcclaim],
        ROUND(AVG(CAST(ed.[AOOJoined] AS FLOAT)), 0) AS [AOOJoined],
        ROUND(AVG(CAST(ed.[AOOWon] AS FLOAT)), 0) AS [AOOWon],
        ROUND(AVG(CAST(ed.[AOOAvgKill] AS FLOAT)), 0) AS [AOOAvgKill],
        ROUND(AVG(CAST(ed.[AOOAvgDead] AS FLOAT)), 0) AS [AOOAvgDead],
        ROUND(AVG(CAST(ed.[AOOAvgHeal] AS FLOAT)), 0) AS [AOOAvgHeal],
        CAST(NULL AS decimal(5,2)) AS [Conduct],

        -- Max / rank fields
        ROUND(AVG(CAST(ed.[Max_PreKvk_Points] AS FLOAT)), 0) AS [Max_PreKvk_Points],
        ROUND(AVG(CAST(ed.[Max_HonorPoints] AS FLOAT)), 0) AS [Max_HonorPoints],
        ROUND(AVG(CAST(ed.[PreKvk_Rank] AS FLOAT)), 0) AS [PreKvk_Rank],
        ROUND(AVG(CAST(ed.[Honor_Rank] AS FLOAT)), 0) AS [Honor_Rank],

        -- NEW: AutarchTimes
        ROUND(AVG(CAST(ed.[AutarchTimes] AS FLOAT)), 0) AS [AutarchTimes],

        -- KVK_NO
        ed.KVK_NO,

        -- Placeholder for Civilization; will compute mode in subsequent UPDATE
        CAST(NULL AS NVARCHAR(100)) AS [Civilization]
    INTO #Aggregated
    FROM #RankingGroups rg
    INNER JOIN dbo.EXCEL_FOR_DASHBOARD ed
        ON ed.KVK_NO = rg.KVK_NO
        AND ed.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
    GROUP BY rg.RankGroup, ed.KVK_NO;

    -- Optimization: Add index for the UPDATE operation
    CREATE CLUSTERED INDEX IX_Aggregated ON #Aggregated(KVK_NO, KVK_RANK);

    ----------------------------------------------------------------
    -- Step 3: Compute most common Civilization per (KVK_NO, RankGroup)
    -- Optimization: Improved tie-breaking logic
    ----------------------------------------------------------------
    UPDATE a
    SET a.Civilization = civ.Civilization
    FROM #Aggregated a
    INNER JOIN #RankingGroups rg
        ON a.KVK_NO = rg.KVK_NO
        AND a.KVK_RANK = rg.RankGroup
    CROSS APPLY (
        SELECT TOP (1) t.Civilization
        FROM (
            SELECT 
                e2.Civilization, 
                COUNT(*) AS cnt, 
                MIN(e2.Gov_ID) AS min_gov
            FROM dbo.EXCEL_FOR_DASHBOARD e2
            WHERE e2.KVK_NO = rg.KVK_NO
              AND e2.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
              AND e2.Civilization IS NOT NULL
              AND e2.Civilization <> ''
            GROUP BY e2.Civilization
        ) t
        ORDER BY t.cnt DESC, t.min_gov ASC
    ) AS civ(Civilization);

    ----------------------------------------------------------------
    -- Step 4: Insert into DASH
    -- Optimization: Column order matches table definition for better performance
    ----------------------------------------------------------------
    INSERT INTO dbo.DASH (
        [RANK], 
        [KVK_RANK], 
        [Gov_ID], 
        [Governor_Name],
        [Starting Power], 
        [T4_KILLS], 
        [T5_KILLS], 
        [T4&T5_Kills],
        [Kill Target], 
        [% of Kill target], 
        [Deads], 
        [T4_Deads],
        [T5_Deads], 
        [Dead_Target], 
        [% of Dead_Target], 
        [KVK_NO],
        [Pass 4 Kills], 
        [Pass 6 Kills], 
        [Pass 7 Kills], 
        [Pass 8 Kills],
        [POWER_DELTA], 
        [DKP_Score], 
        [DKP Target], 
        [% of DKP Target],
        [HealedTroops],
        [HealedTroopsDelta], 
        [KillPointsDelta], 
        [RangedPoints], 
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
        [Conduct],
        [Starting KillPoints], 
        [Starting Deads], 
        [Starting T4&T5_KILLS],
        [Helps], 
        [RSS_Assist], 
        [RSS_Gathered],
        [Pass 4 Deads], 
        [Pass 6 Deads], 
        [Pass 7 Deads], 
        [Pass 8 Deads],
        [Starting HealedTroops],
        [Civilization],
        [KILLS_OUTSIDE_KVK], 
        [DEADS_OUTSIDE_KVK], 
        [Zeroed],
        [HelpsDelta], 
        [RSS_Assist_Delta], 
        [RSS_Gathered_Delta],
        [RangedPointsDelta],
        [Max_PreKvk_Points], 
        [Max_HonorPoints], 
        [PreKvk_Rank], 
        [Honor_Rank],
        [AutarchTimes]  -- NEW COLUMN
    )
    SELECT
        [RANK], 
        [KVK_RANK], 
        [Gov_ID], 
        [Governor_Name],
        [Starting Power], 
        [T4_KILLS], 
        [T5_KILLS], 
        [T4&T5_Kills],
        [Kill Target], 
        [% of Kill target], 
        [Deads], 
        [T4_Deads],
        [T5_Deads], 
        [Dead_Target], 
        [% of Dead_Target], 
        [KVK_NO],
        [Pass 4 Kills], 
        [Pass 6 Kills], 
        [Pass 7 Kills], 
        [Pass 8 Kills],
        [POWER_DELTA], 
        [DKP_Score], 
        [DKP Target], 
        [% of DKP Target],
        [Starting HealedTroops],  -- Maps to HealedTroops in DASH
        [HealedTroopsDelta], 
        [KillPointsDelta], 
        [RangedPoints], 
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
        [Conduct],
        [Starting KillPoints], 
        [Starting Deads], 
        [Starting T4&T5_KILLS],
        [Helps], 
        [RSS_Assist], 
        [RSS_Gathered],
        [Pass 4 Deads], 
        [Pass 6 Deads], 
        [Pass 7 Deads], 
        [Pass 8 Deads],
        [Starting HealedTroops],
        [Civilization],
        [KILLS_OUTSIDE_KVK], 
        [DEADS_OUTSIDE_KVK], 
        [Zeroed],
        [HealedTroopsDelta],      -- Maps to HelpsDelta in DASH
        [RSS_Assist],             -- Maps to RSS_Assist_Delta in DASH
        [RSS_Gathered],           -- Maps to RSS_Gathered_Delta in DASH
        [RangedPointsDelta],
        [Max_PreKvk_Points], 
        [Max_HonorPoints], 
        [PreKvk_Rank], 
        [Honor_Rank],
        [AutarchTimes]  -- NEW COLUMN
    FROM #Aggregated;

    ----------------------------------------------------------------
    -- Step 5: Insert the aggregated rows back into EXCEL_FOR_DASHBOARD
    -- Optimization: Batch delete using EXISTS instead of JOIN
    ----------------------------------------------------------------
    DELETE FROM dbo.EXCEL_FOR_DASHBOARD
    WHERE Gov_ID IN ('999999997', '999999998', '999999999')
      AND EXISTS (SELECT 1 FROM dbo.DASH d WHERE d.KVK_NO = EXCEL_FOR_DASHBOARD.KVK_NO);

    -- Build dynamic column mapping
    DECLARE @cols NVARCHAR(MAX) = N'';
    DECLARE @sels NVARCHAR(MAX) = N'';

    ;WITH ColumnMapping (dest_col, src_expr) AS (
        SELECT * FROM (VALUES
            (N'Rank',                 N'[RANK]'),
            (N'KVK_RANK',             N'[KVK_RANK]'),
            (N'Gov_ID',               N'[Gov_ID]'),
            (N'Governor_Name',        N'[Governor_Name]'),
            (N'Starting Power',       N'[Starting Power]'),
            (N'Power_Delta',          N'[POWER_DELTA]'),
            (N'T4_KILLS',             N'[T4_KILLS]'),
            (N'T5_KILLS',             N'[T5_KILLS]'),
            (N'T4&T5_Kills',          N'[T4&T5_Kills]'),
            (N'Kill Target',          N'[Kill Target]'),
            (N'% of Kill Target',     N'[% of Kill target]'),
            (N'Starting_Deads',       N'[Starting Deads]'),
            (N'Deads_Delta',          N'[Deads]'),  -- Map aggregate Deads to Deads_Delta
            (N'T4_Deads',             N'[T4_Deads]'),
            (N'T5_Deads',             N'[T5_Deads]'),
            (N'Dead_Target',          N'[Dead_Target]'),
            (N'% of Dead Target',     N'[% of Dead_Target]'),
            (N'DKP_SCORE',            N'[DKP_Score]'),
            (N'DKP Target',           N'[DKP Target]'),
            (N'% of DKP Target',      N'[% of DKP Target]'),
            (N'Pass 4 Kills',         N'[Pass 4 Kills]'),
            (N'Pass 6 Kills',         N'[Pass 6 Kills]'),
            (N'Pass 7 Kills',         N'[Pass 7 Kills]'),
            (N'Pass 8 Kills',         N'[Pass 8 Kills]'),
            (N'Pass 4 Deads',         N'[Pass 4 Deads]'),
            (N'Pass 6 Deads',         N'[Pass 6 Deads]'),
            (N'Pass 7 Deads',         N'[Pass 7 Deads]'),
            (N'Pass 8 Deads',         N'[Pass 8 Deads]'),
            (N'KVK_NO',               N'[KVK_NO]'),
            (N'HelpsDelta',           N'[Helps]'),
            (N'RSS_Assist_Delta',     N'[RSS_Assist]'),
            (N'RSS_Gathered_Delta',   N'[RSS_Gathered]'),
            (N'Starting_HealedTroops', N'[Starting HealedTroops]'),
            (N'HealedTroopsDelta',    N'[HealedTroopsDelta]'),
            (N'KillPointsDelta',      N'[KillPointsDelta]'),
            (N'RangedPoints',         N'[RangedPoints]'),
            (N'RangedPointsDelta',    N'[RangedPointsDelta]'),
            (N'Civilization',         N'[Civilization]'),
            (N'KvKPlayed',            N'[KvKPlayed]'),
            (N'MostKvKKill',          N'[MostKvKKill]'),
            (N'MostKvKDead',          N'[MostKvKDead]'),
            (N'MostKvKHeal',          N'[MostKvKHeal]'),
            (N'Acclaim',              N'[Acclaim]'),
            (N'HighestAcclaim',       N'[HighestAcclaim]'),
            (N'AOOJoined',            N'[AOOJoined]'),
            (N'AOOWon',               N'[AOOWon]'),
            (N'AOOAvgKill',           N'[AOOAvgKill]'),
            (N'AOOAvgDead',           N'[AOOAvgDead]'),
            (N'AOOAvgHeal',           N'[AOOAvgHeal]'),
            (N'Conduct',              N'[Conduct]'),
            (N'Starting_KillPoints',  N'[Starting KillPoints]'),
            (N'Starting_Deads',       N'[Starting Deads]'),
            (N'Starting_T4&T5_KILLS', N'[Starting T4&T5_KILLS]'),
            (N'DEADS_OUTSIDE_KVK',    N'[DEADS_OUTSIDE_KVK]'),
            (N'KILLS_OUTSIDE_KVK',    N'[KILLS_OUTSIDE_KVK]'),
            (N'Zeroed',               N'[Zeroed]'),
            (N'Max_PreKvk_Points',    N'[Max_PreKvk_Points]'),
            (N'Max_HonorPoints',      N'[Max_HonorPoints]'),
            (N'PreKvk_Rank',          N'[PreKvk_Rank]'),
            (N'Honor_Rank',           N'[Honor_Rank]'),
            (N'AutarchTimes',         N'[AutarchTimes]')  -- NEW COLUMN MAPPING
        ) v(dest_col, src_expr)
    )
    , AvailableColumns AS (
        -- Keep a single entry per destination column (case-insensitive de-duplication)
        SELECT
            MIN(dest_col) AS dest_col,
            MIN(src_expr) AS src_expr,
            LOWER(dest_col) AS ldest
        FROM ColumnMapping
        WHERE COL_LENGTH('dbo.EXCEL_FOR_DASHBOARD', dest_col) IS NOT NULL
        GROUP BY LOWER(dest_col)
    )
    SELECT
        @cols = STRING_AGG(QUOTENAME(dest_col), N', ') WITHIN GROUP (ORDER BY dest_col),
        @sels = STRING_AGG(src_expr, N', ') WITHIN GROUP (ORDER BY dest_col)
    FROM AvailableColumns;

    -- Execute dynamic INSERT if columns are available
    IF @cols IS NOT NULL AND LEN(@cols) > 0
    BEGIN
        DECLARE @sql NVARCHAR(MAX) =
            N'INSERT INTO dbo.EXCEL_FOR_DASHBOARD (' + @cols + N')
              SELECT ' + @sels + N'
              FROM dbo.DASH
              WHERE Gov_ID IN (''999999997'', ''999999998'', ''999999999'');';

        EXEC sp_executesql @sql;
    END

    ----------------------------------------------------------------
    -- Cleanup
    ----------------------------------------------------------------
    DROP TABLE IF EXISTS #RankingGroups;
    DROP TABLE IF EXISTS #Aggregated;

    SET NOCOUNT OFF;
END
GO

-- Redeploy dbo.GOVERNOR_NAMES_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GOVERNOR_NAMES_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[GOVERNOR_NAMES_PROC] AS' 
END
GO
ALTER PROCEDURE [dbo].[GOVERNOR_NAMES_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	-- REQUIRED SET options for DML against indexed views / computed columns / filtered indexes
	SET ANSI_NULLS ON;
	SET ANSI_PADDING ON;
	SET ANSI_WARNINGS ON;
	SET ARITHABORT ON;
	SET CONCAT_NULL_YIELDS_NULL ON;
	SET QUOTED_IDENTIFIER ON;
	SET NUMERIC_ROUNDABORT OFF;


    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------------
        -- Step 1: Truncate main target table
        ----------------------------------------------------------------
        TRUNCATE TABLE dbo.ALL_GOVS;

        ----------------------------------------------------------------
        -- Step 2: CTEs to prepare scan data (include CityHallLevel)
        ----------------------------------------------------------------
        WITH RankedScans AS (
            SELECT 
                GovernorID,
                GovernorName,
                NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), N'') AS Alliance,
                ScanDate,
                [Power],
                KillPoints,
                Deads,
                T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS],
                TOTAL_KILLS,
                RSS_Gathered, RSSAssistance, Helps,

                -- new fields from KingdomScanData4 (point-in-time values)
                HealedTroops,
                RangedPoints,
                Civilization,
                KvKPlayed,
                MostKvKKill,
                MostKvKDead,
                MostKvKHeal,
                Acclaim,
                HighestAcclaim,
                AOOJoined,
                AOOWon,
                AOOAvgKill,
                AOOAvgDead,
                AOOAvgHeal,
                Conduct,

                -- ✅ City Hall level (confirm column name)
                [City Hall] AS CityHallLevel,

                ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn,
                MIN(ScanDate) OVER (PARTITION BY GovernorID) AS FirstScan,
                MAX([Power]) OVER (PARTITION BY GovernorID) AS MaxPower
            FROM ROK_TRACKER.dbo.KingdomScanData4
            WHERE GovernorID <> 0
        ),
        ScanData AS (
            SELECT 
                GovernorID,
                MAX(CASE WHEN rn = 1 THEN ScanDate END) AS LastScan,
                MAX(CASE WHEN rn = 2 THEN ScanDate END) AS PreviousScan,
                MAX(CASE WHEN rn = 1 THEN Power END) AS LatestPower,
                MAX(CASE WHEN rn = 1 THEN KillPoints END) AS KillPoints,
                MAX(CASE WHEN rn = 1 THEN Deads END) AS Deads,
                MAX(CASE WHEN rn = 1 THEN Helps END) AS Helps,
                MAX(CASE WHEN rn = 1 THEN RSS_Gathered END) AS RSS_GATHERED,
                MAX(CASE WHEN rn = 1 THEN RSSAssistance END) AS RSSASSISTANCE,
                MAX(CASE WHEN rn = 1 THEN GovernorName END) AS GovernorName,
                MAX(CASE WHEN rn = 1 THEN Alliance END) AS Alliance,
                MAX(CASE WHEN rn = 1 THEN T1_Kills END) AS T1_Kills,
                MAX(CASE WHEN rn = 1 THEN T2_Kills END) AS T2_Kills,
                MAX(CASE WHEN rn = 1 THEN T3_Kills END) AS T3_Kills,
                MAX(CASE WHEN rn = 1 THEN T4_Kills END) AS T4_Kills,
                MAX(CASE WHEN rn = 1 THEN T5_Kills END) AS T5_Kills,
                MAX(CASE WHEN rn = 1 THEN [T4&T5_KILLS] END) AS [T4&T5_KILLS],
                MAX(CASE WHEN rn = 1 THEN TOTAL_KILLS END) AS TOTAL_KILLS,
                MAX(FirstScan) AS FirstScan,
                MAX(MaxPower) AS MaxPower,

                -- new fields: take latest (rn = 1) values
                MAX(CASE WHEN rn = 1 THEN HealedTroops END)        AS HealedTroops,
                MAX(CASE WHEN rn = 1 THEN RangedPoints END)       AS RangedPoints,
                MAX(CASE WHEN rn = 1 THEN Civilization END)       AS Civilization,
                MAX(CASE WHEN rn = 1 THEN KvKPlayed END)          AS KvKPlayed,
                MAX(CASE WHEN rn = 1 THEN MostKvKKill END)        AS MostKvKKill,
                MAX(CASE WHEN rn = 1 THEN MostKvKDead END)        AS MostKvKDead,
                MAX(CASE WHEN rn = 1 THEN MostKvKHeal END)        AS MostKvKHeal,
                MAX(CASE WHEN rn = 1 THEN Acclaim END)            AS Acclaim,
                MAX(CASE WHEN rn = 1 THEN HighestAcclaim END)     AS HighestAcclaim,
                MAX(CASE WHEN rn = 1 THEN AOOJoined END)          AS AOOJoined,
                MAX(CASE WHEN rn = 1 THEN AOOWon END)             AS AOOWon,
                MAX(CASE WHEN rn = 1 THEN AOOAvgKill END)         AS AOOAvgKill,
                MAX(CASE WHEN rn = 1 THEN AOOAvgDead END)         AS AOOAvgDead,
                MAX(CASE WHEN rn = 1 THEN AOOAvgHeal END)         AS AOOAvgHeal,
                MAX(CASE WHEN rn = 1 THEN Conduct END)            AS Conduct,

                -- ✅ City Hall level
                MAX(CASE WHEN rn = 1 THEN CityHallLevel END)      AS CityHallLevel
            FROM RankedScans
            WHERE rn <= 2
            GROUP BY GovernorID
        )

        ----------------------------------------------------------------
        -- Step 3: Insert into ALL_GOVS including CityHallLevel
        ----------------------------------------------------------------
        INSERT INTO ALL_GOVS (
            GovernorID, GovernorName, [Max Power], [Latest Power],
            KillPoints, T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS],
            TOTAL_KILLS, Deads, Helps, RSS_Gathered, RSSAssistance,

            -- new fields (inserted before timestamps)
            HealedTroops, RangedPoints, Civilization, KvKPlayed,
            MostKvKKill, MostKvKDead, MostKvKHeal, Acclaim, HighestAcclaim,
            AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct,

            -- ✅ City Hall
            CityHallLevel,

            [Last Scan], [Previous Scan], [First Scan]
        )
        SELECT 
            s.GovernorID,
            RTRIM(s.GovernorName),
            s.MaxPower,
            s.LatestPower,
            s.KillPoints,
            s.T1_Kills, s.T2_Kills, s.T3_Kills, s.T4_Kills, s.T5_Kills, s.[T4&T5_KILLS],
            s.TOTAL_KILLS,
            s.Deads,
            s.Helps,
            s.RSS_GATHERED,
            s.RSSASSISTANCE,

            -- new fields selected from ScanData
            s.HealedTroops,
            s.RangedPoints,
            s.Civilization,
            s.KvKPlayed,
            s.MostKvKKill,
            s.MostKvKDead,
            s.MostKvKHeal,
            s.Acclaim,
            s.HighestAcclaim,
            s.AOOJoined,
            s.AOOWon,
            s.AOOAvgKill,
            s.AOOAvgDead,
            s.AOOAvgHeal,
            s.Conduct,

            -- ✅ City Hall
            s.CityHallLevel,

            s.LastScan,
            s.PreviousScan,
            s.FirstScan
        FROM ScanData s;

        ----------------------------------------------------------------
        -- Step 4: Refresh Governor Names Table (unchanged)
        ----------------------------------------------------------------
        TRUNCATE TABLE dbo.ALL_GOVS_NAMES;

        INSERT INTO ALL_GOVS_NAMES (GovernorID, GovernorName)
        SELECT 
            GovernorID, 
            RTRIM(GovernorName) AS GovernorName
        FROM (
            SELECT DISTINCT 
                GovernorID, 
                GovernorName
            FROM ROK_TRACKER.dbo.KingdomScanData4
            WHERE GovernorID <> 0 AND GovernorName IS NOT NULL
        ) AS UniqueNames;

        ----------------------------------------------------------------
        -- Step 5: Incremental refresh of Alliance history table
        -- Semantics retained: one row per unique (GovernorID, Alliance ever seen)
        ----------------------------------------------------------------

        IF NOT EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES_SYNC_STATE WHERE StateID = 1)
        BEGIN
            INSERT INTO dbo.ALL_GOVS_ALLIANCES_SYNC_STATE (StateID, LastProcessedScanOrder, LastProcessedScanDate, LastRunAt)
            SELECT
                1,
                CASE
                    WHEN EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES)
                        THEN ISNULL((SELECT MAX(kd4.SCANORDER) FROM ROK_TRACKER.dbo.KingdomScanData4 kd4 WHERE kd4.GovernorID <> 0), 0)
                    ELSE 0
                END,
                CASE
                    WHEN EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES)
                        THEN (SELECT MAX(kd4.ScanDate) FROM ROK_TRACKER.dbo.KingdomScanData4 kd4 WHERE kd4.GovernorID <> 0)
                    ELSE NULL
                END,
                CASE
                    WHEN EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES)
                        THEN GETDATE()
                    ELSE NULL
                END;
        END;

		DECLARE
            @LastProcessedScanOrder BIGINT,
            @CurrentMaxScanOrder BIGINT,
            @CurrentMaxScanDate DATETIME,
            @LastAllianceSyncRunAt DATETIME;

SELECT
            @LastProcessedScanOrder = LastProcessedScanOrder,
            @LastAllianceSyncRunAt = LastRunAt
        FROM dbo.ALL_GOVS_ALLIANCES_SYNC_STATE
        WHERE StateID = 1;

        SELECT
            @CurrentMaxScanOrder = MAX(kd4.SCANORDER),
            @CurrentMaxScanDate = MAX(kd4.ScanDate)
        FROM ROK_TRACKER.dbo.KingdomScanData4 kd4
        WHERE kd4.GovernorID <> 0;

        -- Migration safety: if state was seeded as 0 but alliance history already exists,
        -- fast-forward watermark once to avoid reprocessing full history.
        IF ISNULL(@LastProcessedScanOrder, 0) = 0
           AND @LastAllianceSyncRunAt IS NULL
           AND EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES)
           AND @CurrentMaxScanOrder IS NOT NULL
        BEGIN
            UPDATE dbo.ALL_GOVS_ALLIANCES_SYNC_STATE
            SET LastProcessedScanOrder = @CurrentMaxScanOrder,
                LastProcessedScanDate = @CurrentMaxScanDate,
                LastRunAt = GETDATE()
            WHERE StateID = 1;

            SET @LastProcessedScanOrder = @CurrentMaxScanOrder;
        END;

        IF @CurrentMaxScanOrder IS NOT NULL
           AND @CurrentMaxScanOrder > ISNULL(@LastProcessedScanOrder, 0)
        BEGIN
            ;WITH CandidatePairs AS (
                SELECT
                    kd4.GovernorID,
                    NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), kd4.Alliance))), N'') AS Alliance
                FROM ROK_TRACKER.dbo.KingdomScanData4 kd4
                WHERE kd4.GovernorID <> 0
                  AND kd4.SCANORDER > ISNULL(@LastProcessedScanOrder, 0)
                  AND kd4.SCANORDER <= @CurrentMaxScanOrder
            ),
            DistinctPairs AS (
                SELECT
                    cp.GovernorID,
                    cp.Alliance
                FROM CandidatePairs cp
                WHERE cp.Alliance IS NOT NULL
                GROUP BY cp.GovernorID, cp.Alliance
            )
            INSERT INTO dbo.ALL_GOVS_ALLIANCES (GovernorID, Alliance)
            SELECT
                dp.GovernorID,
                dp.Alliance
            FROM DistinctPairs dp
            WHERE NOT EXISTS (
                SELECT 1
                FROM dbo.ALL_GOVS_ALLIANCES aga
                WHERE aga.GovernorID = dp.GovernorID
                  AND aga.Alliance = dp.Alliance
            );

            UPDATE dbo.ALL_GOVS_ALLIANCES_SYNC_STATE
            SET LastProcessedScanOrder = @CurrentMaxScanOrder,
                LastProcessedScanDate = @CurrentMaxScanDate,
                LastRunAt = GETDATE()
            WHERE StateID = 1;
        END;


        COMMIT TRANSACTION;

    END TRY

	BEGIN CATCH
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;

		THROW;
	END CATCH
END;
GO

-- Redeploy lightweight player reporting views.
CREATE OR ALTER VIEW dbo.v_PlayerLatestStats AS
WITH MaxScan AS (
    SELECT GovernorID, MAX(SCANORDER) AS MaxScan
    FROM dbo.KingdomScanData4 WITH (NOLOCK)
    GROUP BY GovernorID
)
SELECT
    s.GovernorID,
    s.GovernorName AS Governor_Name,
    s.Alliance,
    s.[City Hall] AS CityHallLevel,
    s.Power,
    s.[Troops Power],
    ISNULL(s.[T4&T5_KILLS], ISNULL(s.T4_Kills, 0) + ISNULL(s.T5_Kills, 0)) AS Kills,
    s.Deads,
    s.RSS_Gathered,
    s.Helps,
    s.SCANORDER,
    s.PowerRank,
    s.HealedTroops,
    s.KillPoints,
    s.Conduct
FROM dbo.KingdomScanData4 AS s WITH (NOLOCK)
INNER JOIN MaxScan AS m ON m.GovernorID = s.GovernorID AND m.MaxScan = s.SCANORDER;
GO

CREATE OR ALTER VIEW dbo.v_PlayerProfile AS
SELECT
    s.GovernorID,
    s.Governor_Name,
    s.Alliance,
    s.CityHallLevel,
    s.Power,
    s.Kills,
    s.Deads,
    s.RSS_Gathered,
    s.Helps,
    loc.X,
    loc.Y,
    loc.LastUpdated AS LocationUpdated,
    acc.Status,
    acc.UpdatedAt   AS StatusUpdated,
    f.FortsRank,
    f.FortsStarted,
    f.FortsJoined,
    f.FortsTotal,
    f.SnapshotAt    AS FortsUpdated,
    s.PowerRank,
    s.Conduct
FROM dbo.v_PlayerLatestStats AS s
LEFT JOIN dbo.PlayerLocation              AS loc ON loc.GovernorID = s.GovernorID
LEFT JOIN dbo.PlayerAccountStatus         AS acc ON acc.GovernorID = s.GovernorID
LEFT JOIN dbo.v_PlayerFortsLatestWithRank AS f ON f.GovernorID = s.GovernorID;
GO

-- Refresh generated KVK union views after the procedure has been redeployed.
EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;
GO
