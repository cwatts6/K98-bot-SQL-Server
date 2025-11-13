SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_RALLY_DATA]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_RALLY_DATA] AS' 
END
ALTER PROCEDURE [dbo].[UPDATE_RALLY_DATA]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

    DECLARE @FileExists INT;

    -- Check if file exists
    EXEC master.dbo.xp_fileexist 'C:\discord_file_downloader\downloads\rally_data.csv', @FileExists OUTPUT;

    IF @FileExists = 1
    BEGIN
        BEGIN TRY
            -- Step 1: Load data
            TRUNCATE TABLE RallyData_Raw;

            BULK INSERT RallyData_Raw
            FROM 'C:\discord_file_downloader\downloads\rally_data.csv'
            WITH (
                FORMAT = 'CSV',
                FIRSTROW = 2,
                FIELDTERMINATOR = ',',
                ROWTERMINATOR = '\n',
                TABLOCK
            );

            --PRINT 'Bulk insert completed.';

            -- Step 2: Clean and transform date
            TRUNCATE TABLE RallyData;

            SELECT *,
                   CAST(LEFT(start_time, CHARINDEX('@', start_time) - 1) AS nvarchar) AS extracted_date
            INTO #TEST1
            FROM RallyData_Raw
            WHERE start_time LIKE '%@%';

            SELECT *,
                   LTRIM(RTRIM(extracted_date)) AS fully_trimmed_value
            INTO #TEST2
            FROM #TEST1;

            SELECT *,
                   CAST(
                        RIGHT(fully_trimmed_value, 4) + '-' +
                        SUBSTRING(fully_trimmed_value, 4, 2) + '-' +
                        LEFT(fully_trimmed_value, 2) AS nvarchar
                   ) AS reformatted_date
            INTO #TEST3
            FROM #TEST2;

            INSERT INTO RallyData
            SELECT [id], [alliance_tag], [governor_id], [governor_name], [governor_location_x], [governor_location_y],
                   [target_location_x], [target_location_y], [target_type], [target_level], [primary_commander],
                   [secondary_commander], [launched], [cancelled], [start_time], [end_time], [hit_time], [hit_time_pretty],
                   [launch_time], [governors],
                   CAST(reformatted_date AS DATE) AS Start_Date,
                   DATEPART(WEEK, TRY_CAST(reformatted_date AS DATE)) AS Start_Week
            FROM #TEST3;

            -- Step 3: Process governor and rally stats
            TRUNCATE TABLE LATEST_GOVERNORNAME;
            TRUNCATE TABLE RALLY_STARTED_TABLE;

            SELECT DISTINCT GovernorID AS GOV_ID
            INTO #GOV
            FROM KingdomScanData4;

            SELECT GovernorID, GovernorName, SCANORDER
            INTO #GOVERNORNAME_LIST
            FROM KingdomScanData4
            GROUP BY GovernorID, GovernorName, scanorder;

            WITH RankedGovernors AS (
                SELECT GovernorID, GovernorName, SCANORDER,
                       ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER DESC) AS rn
                FROM #GOVERNORNAME_LIST
            )
            INSERT INTO LATEST_GOVERNORNAME (GovernorID, TRIM_NAME, GovernorName, SCANORDER)
            SELECT GovernorID,
                   RTRIM(GovernorName) AS TRIM_NAME,
                   GovernorName,
                   SCANORDER
            FROM RankedGovernors
            WHERE rn = 1 AND GovernorID <> 0;

            INSERT INTO RALLY_STARTED_TABLE (GovernorID, RALLY_STARTED)
            SELECT LG.GovernorID,
                   COUNT(RD.[id])
            FROM LATEST_GOVERNORNAME LG
            JOIN RallyData RD ON LG.GovernorID = RD.governor_ID
            WHERE RD.Launched = 'TRUE'
            GROUP BY LG.GovernorID;

            -- Step 4: Split joiners
            TRUNCATE TABLE RALLY_JOINERS;
            TRUNCATE TABLE RALLY_JOINED;

            SELECT *
            INTO #RD1
            FROM RallyData
            WHERE Cancelled = 'FALSE';

            WITH SplitValues AS (
                SELECT ID,
                       TRIM(value) AS value,
                       ROW_NUMBER() OVER (PARTITION BY ID ORDER BY (SELECT NULL)) AS rn
                FROM #RD1
                CROSS APPLY STRING_SPLIT(governors, ';')
            )
            INSERT INTO RALLY_JOINERS (ID, Col1, Col2, Col3, Col4, Col5, Col6, Col7, Col8,
                                       Col9, Col10, Col11, Col12, Col13, Col14, Col15, Col16)
            SELECT ID,
                   MAX(CASE WHEN rn = 1 THEN value END),
                   MAX(CASE WHEN rn = 2 THEN value END),
                   MAX(CASE WHEN rn = 3 THEN value END),
                   MAX(CASE WHEN rn = 4 THEN value END),
                   MAX(CASE WHEN rn = 5 THEN value END),
                   MAX(CASE WHEN rn = 6 THEN value END),
                   MAX(CASE WHEN rn = 7 THEN value END),
                   MAX(CASE WHEN rn = 8 THEN value END),
                   MAX(CASE WHEN rn = 9 THEN value END),
                   MAX(CASE WHEN rn = 10 THEN value END),
                   MAX(CASE WHEN rn = 11 THEN value END),
                   MAX(CASE WHEN rn = 12 THEN value END),
                   MAX(CASE WHEN rn = 13 THEN value END),
                   MAX(CASE WHEN rn = 14 THEN value END),
                   MAX(CASE WHEN rn = 15 THEN value END),
                   MAX(CASE WHEN rn = 16 THEN value END)
            FROM SplitValues
            GROUP BY ID;

            INSERT INTO RALLY_JOINED (GovernorID, TotalOccurrences)
            SELECT L.GovernorID,
                   ISNULL(SUM(CASE WHEN t.GovernorID = L.GovernorID THEN 1 ELSE 0 END), 0)
            FROM LATEST_GOVERNORNAME L
            LEFT JOIN (
                SELECT Col1 AS GovernorID FROM RALLY_JOINERS
                UNION ALL SELECT Col2 FROM RALLY_JOINERS
                UNION ALL SELECT Col3 FROM RALLY_JOINERS
                UNION ALL SELECT Col4 FROM RALLY_JOINERS
                UNION ALL SELECT Col5 FROM RALLY_JOINERS
                UNION ALL SELECT Col6 FROM RALLY_JOINERS
                UNION ALL SELECT Col7 FROM RALLY_JOINERS
                UNION ALL SELECT Col8 FROM RALLY_JOINERS
                UNION ALL SELECT Col9 FROM RALLY_JOINERS
                UNION ALL SELECT Col10 FROM RALLY_JOINERS
                UNION ALL SELECT Col11 FROM RALLY_JOINERS
                UNION ALL SELECT Col12 FROM RALLY_JOINERS
                UNION ALL SELECT Col13 FROM RALLY_JOINERS
                UNION ALL SELECT Col14 FROM RALLY_JOINERS
                UNION ALL SELECT Col15 FROM RALLY_JOINERS
            ) t ON t.GovernorID = L.GovernorID
            GROUP BY L.GovernorID;

            -- Step 5: Final summary
            TRUNCATE TABLE RALLY_EXPORT;

            INSERT INTO RALLY_EXPORT
            SELECT CONCAT(L.TRIM_NAME, ' (', FORMAT(L.GovernorID, 'F0'), ')') AS GOVENOR,
                   ISNULL(RST.RALLY_STARTED, 0) AS RALLY_LAUNCHED,
                   SUM(
                       CASE
                           WHEN RST.RALLY_STARTED IS NULL THEN RJ.TotalOccurrences
                           ELSE RJ.TotalOccurrences - RST.RALLY_STARTED
                       END
                   ) AS RALLY_JOINED,
                   RJ.TotalOccurrences AS TOTAL_RALLIES_COMPLETED
            FROM LATEST_GOVERNORNAME L
            LEFT JOIN RALLY_STARTED_TABLE RST ON L.GovernorID = RST.GovernorID
            LEFT JOIN RALLY_JOINED RJ ON L.GovernorID = RJ.GovernorID
            WHERE RJ.TotalOccurrences > 0
            GROUP BY L.GovernorID, L.TRIM_NAME, RST.RALLY_STARTED, RJ.TotalOccurrences;

            -- Step 6: Clean up
            DROP TABLE IF EXISTS #RD1, #GOV, #GOVERNORNAME_LIST, #TEST1, #TEST2, #TEST3;

            -- Optional: Delete the CSV file
           CREATE TABLE #dummy_output (output NVARCHAR(4000));
		   
		   -- Suppress output from xp_cmdshell
			INSERT INTO #dummy_output
			EXEC xp_cmdshell 'DEL C:\discord_file_downloader\downloads\rally_data.csv';

			-- Drop the dummy output table afterward
			DROP TABLE IF EXISTS #dummy_output;
			
			--PRINT 'Update complete and file deleted';

			SET ANSI_WARNINGS ON;

        END TRY
        BEGIN CATCH
            PRINT '❌ Error occurred: ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
    BEGIN
        PRINT '⚠️ File not found. Import skipped.';
    END
END;

