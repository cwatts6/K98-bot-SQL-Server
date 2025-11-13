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

	TRUNCATE TABLE IMPORT_STAGING_CSV;

	DECLARE @FileExists INT;

	EXEC master.dbo.xp_fileexist 'C:\discord_file_downloader\downloads\stats.csv', @FileExists OUTPUT;

    IF @FileExists = 1

    BEGIN TRY
        DECLARE @NextScanOrder INT = (SELECT ISNULL(MAX(SCANORDER), 0) + 1 FROM KingdomScanData4);
        DECLARE @InsertedRows INT;
        DECLARE @LatestDate DATETIME;
        DECLARE @FormattedDate VARCHAR(50);
        DECLARE @MoveCommand NVARCHAR(4000);
		

         -- Step 2: Bulk insert from CSV
        BULK INSERT IMPORT_STAGING_CSV
        FROM 'C:\discord_file_downloader\downloads\stats.csv'
        WITH (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',  
            ROWTERMINATOR = '\n',  
            CODEPAGE = '65001',
            TABLOCK
        );

        -- Step 3: Truncate target staging table
        TRUNCATE TABLE IMPORT_STAGING;

        -- Step 4: Insert into IMPORT_STAGING with inline ScanDate parsing
        INSERT INTO IMPORT_STAGING (
            [Name], [Governor ID], [Alliance], [Power],
            [Total Kill Points], [Dead Troops], [T1-Kills], [T2-Kills], [T3-Kills],
            [T4-Kills], [T5-Kills], [Kills (T4+)], [KILLS], [RSS Gathered],
            [RSS Assistance], [Alliance Helps], [ScanDate], [SCANORDER],
            [Troops Power], [City Hall], [Tech Power], [Building Power],
            [Commander Power], [Updated_on]
        )
        SELECT
            [Name], [GovernorID], [Alliance], [Power],
            [TotalKillPoints], [DeadTroops], [T1_Kills], [T2_Kills], [T3_Kills],
            [T4_Kills], [T5_Kills],
            ([T4_Kills] + [T5_Kills]),
            ([T1_Kills] + [T2_KILLS] + [T3_KILLS] + [T4_Kills] + [T5_Kills]),
            [RssGathered], [RssAssistance], [AllianceHelps],
            TRY_CAST(
                CONCAT(
                    '20', SUBSTRING(updated_on, 6, 2), '-',        
                    CASE SUBSTRING(updated_on, 3, 3)
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
                    SUBSTRING(updated_on, 1, 2), ' ',
                    SUBSTRING(updated_on, 9, 2), ':',
                    SUBSTRING(updated_on, 12, 2), ':00'
                ) AS DATETIME
            ) AS ScanDate,
            @NextScanOrder,
            [TroopsPower], [CityHall], [TechPower], [BuildingPower], [CommanderPower],
            [updated_on]
        FROM IMPORT_STAGING_CSV;

        SET @InsertedRows = @@ROWCOUNT;

        -- Step 5: Clean up known alliance typos
        UPDATE IMPORT_STAGING
        SET ALLIANCE = '[k98A]SparTanS'
        WHERE ALLIANCE = '[k98A]SparTanS$S';

        UPDATE IMPORT_STAGING
        SET ALLIANCE = '[K98B]TrojanS'
        WHERE ALLIANCE = '[K98B]Trojan$S';

        -- Step 6: Delta update from latest scan
        WITH LatestScan AS (
            SELECT GovernorID,
                   KillPoints, Deads, T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills,
                   [T4&T5_KILLS], [TOTAL_KILLS], RSS_Gathered, RSSAssistance, Helps
            FROM KingdomScanData4
            WHERE SCANORDER = (SELECT MAX(SCANORDER) FROM KingdomScanData4)
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
        FROM IMPORT_STAGING AS I
        JOIN LatestScan AS K ON I.[Governor ID] = K.GovernorID;



        -- Step 7: Move the CSV file to archive with formatted name
        SELECT TOP 1 @LatestDate = [ScanDate]
        FROM IMPORT_STAGING
        ORDER BY [Updated_on] DESC;

        SET @FormattedDate = FORMAT(@LatestDate, 'yyyyMMdd_HHmm');
        SET @MoveCommand = 'CMD /C MOVE "C:\discord_file_downloader\downloads\stats.csv" "C:\discord_file_downloader\downloads\Import_Archive\Stats_' + @FormattedDate + '.csv"';

        CREATE TABLE #dummy_output (output NVARCHAR(4000));
        INSERT INTO #dummy_output
        EXEC xp_cmdshell @MoveCommand;

        -- Step 8: Output summary
        PRINT '--- IMPORT STAGING SUMMARY ---';
        PRINT 'Rows Inserted: ' + CAST(@InsertedRows AS VARCHAR);
        PRINT 'ScanOrder Used: ' + CAST(@NextScanOrder AS VARCHAR);
        PRINT 'File Moved To: C:\discord_file_downloader\downloads\Import_Archive\Stats_' + @FormattedDate + '.csv';
        PRINT 'File Move Output:';
        PRINT 'File Move Output:';

SELECT output 
FROM #dummy_output 
WHERE output IS NOT NULL AND LTRIM(RTRIM(output)) <> '';

        DROP TABLE #dummy_output;

        RETURN 0; -- Success

    END TRY
    BEGIN CATCH
        PRINT 'Error occurred: ' + ERROR_MESSAGE();
        RETURN 1; -- Failure
    END CATCH
 ELSE
    BEGIN
        PRINT '⚠️ File not found. Import skipped.';
END
END;

