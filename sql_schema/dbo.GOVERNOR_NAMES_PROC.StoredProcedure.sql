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
        -- Step 2: CTEs to prepare scan data (include new fields)
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
                MAX(CASE WHEN rn = 1 THEN AOOAvgHeal END)         AS AOOAvgHeal
            FROM RankedScans
            WHERE rn <= 2
            GROUP BY GovernorID
        )

        ----------------------------------------------------------------
        -- Step 3: Insert into ALL_GOVS including new fields
        ----------------------------------------------------------------
        INSERT INTO ALL_GOVS (
            GovernorID, GovernorName, [Max Power], [Latest Power],
            KillPoints, T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS],
            TOTAL_KILLS, Deads, Helps, RSS_Gathered, RSSAssistance,

            -- new fields (inserted before timestamps)
            HealedTroops, RangedPoints, Civilization, KvKPlayed,
            MostKvKKill, MostKvKDead, MostKvKHeal, Acclaim, HighestAcclaim,
            AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal,

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

