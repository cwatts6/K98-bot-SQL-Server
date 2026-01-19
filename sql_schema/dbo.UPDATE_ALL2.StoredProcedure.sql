SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL2] AS' 
END
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

	DECLARE @rc INT, @rowsKS5 INT;

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
            -- RAISERROR will jump to CATCH; no explicit rollback here
        END

        -- 2) Insert into KingdomScanData5
        -- Add deterministic tiebreaker to ROW_NUMBER to ensure stable ranks for ties
        INSERT INTO dbo.KingdomScanData5 (
              PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
            , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
            , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , HealedTroops, RangedPoints, Civilization, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
            , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal
        )
        SELECT
              ROW_NUMBER() OVER (ORDER BY [Power] DESC, [Governor ID] ASC)
            , RTRIM([Name])
            , [Governor ID]
            , [Alliance]
            , [Power]
            , [Total Kill Points]
            , [Dead Troops]
            , [T1-Kills], [T2-Kills], [T3-Kills], [T4-Kills], [T5-Kills]
            , [Kills (T4+)]
            , [KILLS]
            , [RSS Gathered], [RSS Assistance], [Alliance Helps]
            , [ScanDate], [SCANORDER]
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , [HealedTroops], [RangedPoints], [Civilization], [KvKPlayed], [MostKvKKill], [MostKvKDead], [MostKvKHeal]
            , [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon], [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal]
        FROM dbo.IMPORT_STAGING WITH (TABLOCK);

        SET @rowsKS5 = @@ROWCOUNT;

        IF @rowsKS5 = 0
        BEGIN
            RAISERROR('No rows inserted into KingdomScanData5 (IMPORT_STAGING was empty).', 16, 1);
        END

		-- Cache MAX(SCANORDER) values to avoid repeated scans
        DECLARE @MaxScanOrder5 BIGINT = (SELECT ISNULL(MAX(SCANORDER), 0) FROM dbo.KingdomScanData5);
        DECLARE @MaxScanOrder4 BIGINT = (SELECT ISNULL(MAX(SCANORDER), 0) FROM dbo.KingdomScanData4);

        -- 3) Promote to KS4 if newer (AsOfDate is computed in KS4; do not include it)
        IF @MaxScanOrder5 > @MaxScanOrder4
        BEGIN
            INSERT INTO dbo.KingdomScanData4 (
                  PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , RSS_Gathered, RSSAssistance, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal
            )
            SELECT
                  PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @MaxScanOrder5;
        END

        -- 4) Truncate staging (safe post-insert)
        TRUNCATE TABLE dbo.IMPORT_STAGING;

        COMMIT;  -- ✅ Import is now durable even if later steps fail

        -- Return / Log Phase A summary values using cached variables
        SELECT
            @MaxScanOrder5    AS Ks5_MaxScanOrder,
            @rowsKS5          AS Ks5_RowsInserted,
            (SELECT COUNT(*) FROM dbo.IMPORT_STAGING)                       AS ImportStaging_RowsAfterPhaseA,
            (SELECT COUNT(*) FROM dbo.KingdomScanData4 WHERE SCANORDER = @MaxScanOrder4) AS Ks4_RowsInLatest;

        ----------------------------------------------------------------
        -- Phase B: Downstream builds (non-critical) - separate transaction
        ----------------------------------------------------------------
        BEGIN TRANSACTION;

        EXEC dbo.CREATE_THE_AVERAGES;

        -- Safe drop / rebuild
        IF OBJECT_ID('dbo.EXCEL_FOR_DASHBOARD','U') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        EXEC dbo.sp_Rebuild_ExcelForDashboard;
        EXEC dbo.CREATE_DASH2;

        EXEC dbo.SP_Stats_for_Upload;

        TRUNCATE TABLE dbo.ALL_STATS_FOR_DASHBAORD;

        INSERT INTO dbo.ALL_STATS_FOR_DASHBAORD (
            [Rank],[KVK_RANK],[Gov_ID],[Governor_Name],[Starting Power],
            [Power_Delta], T4_Kills, T5_Kills, [T4&T5_Kills], [Kill Target], [% of Kill target], [Deads],
            T4_Deads, T5_Deads, [Dead Target], [% of Dead Target], [Zeroed], [DKP_SCORE], [DKP Target],
            [% of DKP Target], [Helps], [RSS_Assist], [RSS_Gathered],
            [Pass 4 Kills],[Pass 6 Kills],[Pass 7 Kills],[Pass 8 Kills],
            [Pass 4 Deads],[Pass 6 Deads],[Pass 7 Deads],[Pass 8 Deads],
            [RangedPoints], [HealedTroops], [Civilization], [KvKPlayed],
            [MostKvKKill], [MostKvKDead], [MostKvKHeal], [Acclaim], [HighestAcclaim],
            [AOOJoined], [AOOWon], [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal],
            [KVK_NO]
        )
        SELECT
            [Rank],[KVK_RANK],[Gov_ID], ISNULL(RTRIM(Governor_Name), ''),
            [Starting Power],
            ISNULL([Power_Delta],0),
            ISNULL(T4_Kills,0), ISNULL(T5_Kills,0), ISNULL([T4&T5_Kills],0),
            ISNULL([Kill Target],0), ISNULL([% of Kill target],0),
            ISNULL([Deads],0), ISNULL(T4_Deads,0), ISNULL(T5_Deads,0),
            ISNULL([Dead_Target],0), ISNULL([% of Dead_Target],0),
            ISNULL([Zeroed],0), ISNULL([DKP_SCORE],0), ISNULL([DKP Target],0),
            ISNULL([% of DKP Target],0), ISNULL([Helps],0), ISNULL([RSS_Assist],0),
            ISNULL([RSS_Gathered],0),
            ISNULL([Pass 4 Kills],0), ISNULL([Pass 6 Kills],0), ISNULL([Pass 7 Kills],0), ISNULL([Pass 8 Kills],0),
            ISNULL([Pass 4 Deads],0), ISNULL([Pass 6 Deads],0), ISNULL([Pass 7 Deads],0), ISNULL([Pass 8 Deads],0),
            ISNULL([RangedPoints],0), 
            ISNULL([HealedTroops],0),
            ISNULL([Civilization], N''),
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
            [KVK_NO]
        FROM dbo.EXCEL_FOR_DASHBOARD
        WHERE Gov_ID <> 12025033;

        TRUNCATE TABLE dbo.POWER_BY_MONTH;
 
 
        INSERT INTO dbo.POWER_BY_MONTH (GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS], DEADS, [MONTH], HealedTroops, RangedPoints)
        SELECT TOP (5000000) GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS], DEADS, [MONTH], HealedTroops, RangedPoints
        FROM (
            SELECT GovernorID, RTRIM(GovernorName) AS GovernorName,
                   MAX([Power]) AS [POWER], 
				   MAX(KillPoints) AS KILLPOINTS,
                   MAX([T4&T5_KILLS]) AS [T4&T5KILLS],
                   MAX(Deads) AS DEADS, 
				   MAX(HealedTroops) AS HealedTroops, 
				   MAX(RangedPoints) AS RangedPoints, 
				   EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.KingdomScanData4
            WHERE GovernorID NOT IN (0, 12025033)
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

            UNION ALL

            SELECT GovernorID, RTRIM(GovernorName) AS GovernorName,
                   MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                   MAX([T4&T5_KILLS]) AS [T4&T5KILLS],
                   MAX(Deads) AS DEADS, MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.THE_AVERAGES
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)
        ) AS T
        ORDER BY GovernorID, [MONTH];

        EXEC dbo.sp_RefreshInactiveGovernors;

        --TRUNCATE TABLE dbo.KS;

        DECLARE @MAXDATE DATETIME = (SELECT MAX(ScanDate) FROM dbo.KingdomScanData4);
		--DECLARE @actual_param1 FLOAT = 912;
		--DECLARE @actual_param2 NVARCHAR(100) = 'C';

        INSERT INTO dbo.KS (KINGDOM_POWER, Governors, KP, [KILL], [DEAD], [CH25], HealedTroops, RangedPoints, [Last Update], KINGDOM_RANK, KINGDOM_SEED)
        SELECT
            SUM(CAST([Power] AS BIGINT)),
            COUNT(GovernorID),
            SUM([KillPoints]),
            SUM([TOTAL_KILLS]),
            SUM([DEADS]),
			CAST(SUM(CASE WHEN [City Hall] = 25 THEN 1 ELSE 0 END) AS INT) AS CH25,
			SUM(ISNULL([HealedTroops],0)),
            SUM(ISNULL([RangedPoints],0)),
            @MAXDATE,
            @actual_param1,
            @actual_param2
        FROM dbo.KingdomScanData4
        WHERE ScanDate = @MAXDATE;

        EXEC dbo.SUMMARY_PROC;
        EXEC dbo.GOVERNOR_NAMES_PROC;

        TRUNCATE TABLE dbo.SCAN_LIST;

        INSERT INTO dbo.SCAN_LIST (SCANORDER, ScanDate)
        SELECT SCANORDER, ScanDate
        FROM dbo.KingdomScanData4
        GROUP BY SCANORDER, ScanDate;
 
        -- status/log
        DECLARE @EndTime DATETIME = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);

        INSERT INTO dbo.SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
        VALUES (
            'UPDATE_ALL2', 'Complete', @EndTime,
            ISNULL((SELECT MAX(LastRunCounter) FROM dbo.SP_TaskStatus WHERE TaskName='UPDATE_ALL2'),0) + 1,
            @DurationSeconds
        );

        COMMIT;

        INSERT INTO dbo.Update_ALL_Complete (CompletionTime) VALUES (GETDATE());

    END TRY
    BEGIN CATCH
		        -- Capture error details (insert into an error audit table if available)
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrProc NVARCHAR(200) = ERROR_PROCEDURE();

        -- Optional: store in error log table (uncomment if you have ErrorAudit table)
   
        INSERT INTO dbo.ErrorAudit (ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo)
        VALUES (GETDATE(), ISNULL(@ErrProc, 'UPDATE_ALL2'), @ErrNum, @ErrMsg, @ErrLine, N'Phase info: ' + COALESCE(CONVERT(NVARCHAR(100), @MaxScanOrder5), N''));
        
        IF XACT_STATE() <> 0 ROLLBACK;
		-- Re-throw preserving original error context
        THROW;
    END CATCH
END

