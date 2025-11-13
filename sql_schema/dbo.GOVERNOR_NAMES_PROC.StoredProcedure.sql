SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GOVERNOR_NAMES_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[GOVERNOR_NAMES_PROC] AS' 
END
ALTER PROCEDURE [dbo].[GOVERNOR_NAMES_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
	SET ANSI_WARNINGS OFF;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Truncate main target table
        TRUNCATE TABLE ALL_GOVS;

        -- Step 2: CTEs to prepare scan data
        WITH RankedScans AS (
            SELECT 
                GovernorID,
                GovernorName,
                Alliance,
                ScanDate,
                Power,
                KillPoints,
                Deads,
                T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS],
                TOTAL_KILLS,
                RSS_Gathered, RSSAssistance, Helps,
                ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn,
                MIN(ScanDate) OVER (PARTITION BY GovernorID) AS FirstScan
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
                MAX(CASE WHEN rn = 1 THEN RSS_Gathered END) AS RSS_Gathered,
                MAX(CASE WHEN rn = 1 THEN RSSAssistance END) AS RSSAssistance,
                MAX(CASE WHEN rn = 1 THEN GovernorName END) AS GovernorName,
                MAX(CASE WHEN rn = 1 THEN Alliance END) AS Alliance,
                MAX(CASE WHEN rn = 1 THEN T1_Kills END) AS T1_Kills,
                MAX(CASE WHEN rn = 1 THEN T2_Kills END) AS T2_Kills,
                MAX(CASE WHEN rn = 1 THEN T3_Kills END) AS T3_Kills,
                MAX(CASE WHEN rn = 1 THEN T4_Kills END) AS T4_Kills,
                MAX(CASE WHEN rn = 1 THEN T5_Kills END) AS T5_Kills,
                MAX(CASE WHEN rn = 1 THEN [T4&T5_KILLS] END) AS [T4&T5_KILLS],
                MAX(CASE WHEN rn = 1 THEN TOTAL_KILLS END) AS TOTAL_KILLS,
                MAX(FirstScan) AS FirstScan
            FROM RankedScans
            WHERE rn <= 2
            GROUP BY GovernorID
        ),
        MaxPower AS (
            SELECT 
                GovernorID,
                MAX(Power) AS MaxPower
            FROM ROK_TRACKER.dbo.KingdomScanData4
            WHERE GovernorID <> 0
            GROUP BY GovernorID
        )

        -- Step 3: Insert into ALL_GOVS
        INSERT INTO ALL_GOVS (
            GovernorID, GovernorName, [Max Power], [Latest Power],
            KillPoints, T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS],
            TOTAL_KILLS, Deads, Helps, RSS_Gathered, RSSAssistance,
            [Last Scan], [Previous Scan], [First Scan]
        )
        SELECT 
            s.GovernorID, RTRIM(s.GovernorName), p.MaxPower, s.LatestPower,
            s.KillPoints, s.T1_Kills, s.T2_Kills, s.T3_Kills, s.T4_Kills, s.T5_Kills, s.[T4&T5_KILLS],
            s.TOTAL_KILLS, s.Deads, s.Helps, s.RSS_Gathered, s.RSSAssistance,
            s.LastScan, s.PreviousScan, s.FirstScan
        FROM ScanData s
        JOIN MaxPower p ON s.GovernorID = p.GovernorID;

        -- Step 4: Refresh Governor Names Table
        TRUNCATE TABLE ALL_GOVS_NAMES;

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

        -- Step 5: Refresh Alliance Table
        TRUNCATE TABLE ALL_GOVS_ALLIANCES;

        INSERT INTO ALL_GOVS_ALLIANCES (GovernorID, Alliance)
        SELECT DISTINCT
            GovernorID,
            REPLACE(REPLACE(Alliance, CHAR(13), ''), CHAR(10), '') AS Alliance
        FROM ROK_TRACKER.dbo.KingdomScanData4
        WHERE GovernorID <> 0;

        -- Optional: success log
        -- INSERT INTO ProcedureExecutionLog (ProcedureName, ExecutionTime, Status)
        -- VALUES ('GOVERNOR_NAMES_PROC2', GETDATE(), 'SUCCESS');

        COMMIT TRANSACTION;
		SET ANSI_WARNINGS ON;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE 
            @ErrorMessage NVARCHAR(4000),
            @ErrorSeverity INT,
            @ErrorState INT;

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        -- Optional: log the error
        -- INSERT INTO ErrorLog (ProcedureName, ErrorMessage, ErrorDate)
        -- VALUES ('GOVERNOR_NAMES_PROC2', @ErrorMessage, GETDATE());

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;

