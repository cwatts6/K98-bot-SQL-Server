SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_GetPersonalStatsDaily]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_GetPersonalStatsDaily] AS' 
END
ALTER PROCEDURE [dbo].[usp_GetPersonalStatsDaily]
	@GovernorIDs [dbo].[IntList] READONLY,
	@HistoryDays [smallint] = 180
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RequestedGovernorCount int = (SELECT COUNT(*) FROM @GovernorIDs);

    IF @RequestedGovernorCount < 1 OR @RequestedGovernorCount > 26
        THROW 50001, 'Personal stats requires between 1 and 26 governor IDs.', 1;

    IF EXISTS (SELECT 1 FROM @GovernorIDs WHERE ID <= 0)
        THROW 50002, 'Personal stats received an invalid governor ID.', 1;

    IF @HistoryDays IS NULL OR @HistoryDays < 1 OR @HistoryDays > 180
        THROW 50003, 'Personal stats history days must be between 1 and 180.', 1;

    DECLARE @StatsAnchorDate date = (
        SELECT MAX(ks.AsOfDate)
        FROM dbo.KingdomScanData4 AS ks
    );
    DECLARE @WindowStartDate date = DATEADD(DAY, 1 - @HistoryDays, @StatsAnchorDate);

    SELECT
        @StatsAnchorDate AS StatsAnchorDate,
        @WindowStartDate AS WindowStartDate,
        @StatsAnchorDate AS WindowEndDate,
        @RequestedGovernorCount AS RequestedGovernorCount;

    IF @StatsAnchorDate IS NULL
    BEGIN
        SELECT
            CAST(NULL AS int) AS GovernorID,
            CAST(NULL AS date) AS AsOfDate,
            CAST(NULL AS bit) AS HasStats,
            CAST(NULL AS date) AS PreviousStatsDate,
            CAST(NULL AS bigint) AS PowerValue,
            CAST(NULL AS bigint) AS TroopPowerValue,
            CAST(NULL AS bigint) AS PowerDelta,
            CAST(NULL AS bigint) AS TroopPowerDelta,
            CAST(NULL AS bigint) AS KillPointsDelta,
            CAST(NULL AS bigint) AS RSSGatheredDelta,
            CAST(NULL AS bigint) AS RSSAssistDelta,
            CAST(NULL AS bigint) AS HelpsDelta,
            CAST(NULL AS bigint) AS T4KillsDelta,
            CAST(NULL AS bigint) AS T5KillsDelta,
            CAST(NULL AS bigint) AS DeadsDelta,
            CAST(NULL AS bigint) AS HealedTroopsDelta,
            CAST(NULL AS bit) AS HasAllianceActivity,
            CAST(NULL AS date) AS PreviousActivityDate,
            CAST(NULL AS bigint) AS BuildActivityDelta,
            CAST(NULL AS bigint) AS TechDonationsDelta,
            CAST(NULL AS bit) AS HasForts,
            CAST(NULL AS bigint) AS FortsTotal,
            CAST(NULL AS bigint) AS FortsLaunched,
            CAST(NULL AS bigint) AS FortsJoined
        WHERE 1 = 0;
        RETURN;
    END;

    CREATE TABLE #StatsDaily
    (
        GovernorID int NOT NULL,
        AsOfDate date NOT NULL,
        PreviousStatsDate date NULL,
        PowerValue bigint NULL,
        TroopPowerValue bigint NULL,
        PowerDelta bigint NULL,
        TroopPowerDelta bigint NULL,
        KillPointsDelta bigint NULL,
        RSSGatheredDelta bigint NULL,
        RSSAssistDelta bigint NULL,
        HelpsDelta bigint NULL,
        T4KillsDelta bigint NULL,
        T5KillsDelta bigint NULL,
        DeadsDelta bigint NULL,
        HealedTroopsDelta bigint NULL,
        PRIMARY KEY CLUSTERED (GovernorID, AsOfDate)
    );

    ;WITH PreviousDates AS
    (
        SELECT ids.ID AS GovernorID, MAX(ks.AsOfDate) AS AsOfDate
        FROM @GovernorIDs AS ids
        LEFT JOIN dbo.KingdomScanData4 AS ks
          ON ks.GovernorID = ids.ID
         AND ks.AsOfDate < @WindowStartDate
        GROUP BY ids.ID
    ),
    RelevantDates AS
    (
        SELECT TRY_CONVERT(int, ks.GovernorID) AS GovernorID, ks.AsOfDate
        FROM dbo.KingdomScanData4 AS ks
        JOIN @GovernorIDs AS ids ON ks.GovernorID = ids.ID
        WHERE ks.AsOfDate BETWEEN @WindowStartDate AND @StatsAnchorDate
        GROUP BY TRY_CONVERT(int, ks.GovernorID), ks.AsOfDate
        UNION
        SELECT GovernorID, AsOfDate FROM PreviousDates WHERE AsOfDate IS NOT NULL
    ),
    RankedDayEnd AS
    (
        SELECT
            dates.GovernorID,
            dates.AsOfDate,
            TRY_CONVERT(bigint, ks.Power) AS PowerValue,
            TRY_CONVERT(bigint, ks.[Troops Power]) AS TroopPowerValue,
            TRY_CONVERT(bigint, ks.KillPoints) AS KillPointsValue,
            TRY_CONVERT(bigint, ks.RSS_Gathered) AS RSSGatheredValue,
            TRY_CONVERT(bigint, ks.RSSAssistance) AS RSSAssistValue,
            TRY_CONVERT(bigint, ks.Helps) AS HelpsValue,
            TRY_CONVERT(bigint, ks.T4_Kills) AS T4KillsValue,
            TRY_CONVERT(bigint, ks.T5_Kills) AS T5KillsValue,
            TRY_CONVERT(bigint, ks.Deads) AS DeadsValue,
            TRY_CONVERT(bigint, ks.HealedTroops) AS HealedTroopsValue,
            ROW_NUMBER() OVER (
                PARTITION BY dates.GovernorID, dates.AsOfDate
                ORDER BY ks.ScanDate DESC, ks.SCANORDER DESC, ks.SCAN_UNO DESC
            ) AS RowNumber
        FROM RelevantDates AS dates
        JOIN dbo.KingdomScanData4 AS ks
          ON ks.GovernorID = dates.GovernorID
         AND ks.AsOfDate = dates.AsOfDate
    ),
    DayValues AS
    (
        SELECT
            GovernorID,
            AsOfDate,
            PowerValue,
            TroopPowerValue,
            KillPointsValue,
            RSSGatheredValue,
            RSSAssistValue,
            HelpsValue,
            T4KillsValue,
            T5KillsValue,
            DeadsValue,
            HealedTroopsValue
        FROM RankedDayEnd
        WHERE RowNumber = 1
    ),
    WithPrevious AS
    (
        SELECT
            values_today.*,
            LAG(values_today.AsOfDate) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousStatsDate,
            LAG(values_today.PowerValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousPowerValue,
            LAG(values_today.TroopPowerValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousTroopPowerValue,
            LAG(values_today.KillPointsValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousKillPointsValue,
            LAG(values_today.RSSGatheredValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousRSSGatheredValue,
            LAG(values_today.RSSAssistValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousRSSAssistValue,
            LAG(values_today.HelpsValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousHelpsValue,
            LAG(values_today.T4KillsValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousT4KillsValue,
            LAG(values_today.T5KillsValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousT5KillsValue,
            LAG(values_today.DeadsValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousDeadsValue,
            LAG(values_today.HealedTroopsValue) OVER (PARTITION BY values_today.GovernorID ORDER BY values_today.AsOfDate) AS PreviousHealedTroopsValue
        FROM DayValues AS values_today
    )
    INSERT INTO #StatsDaily
    SELECT GovernorID, AsOfDate, PreviousStatsDate, PowerValue, TroopPowerValue,
        TRY_CONVERT(bigint, PowerValue - PreviousPowerValue),
        TRY_CONVERT(bigint, TroopPowerValue - PreviousTroopPowerValue),
        TRY_CONVERT(bigint, KillPointsValue - PreviousKillPointsValue),
        TRY_CONVERT(bigint, RSSGatheredValue - PreviousRSSGatheredValue),
        TRY_CONVERT(bigint, RSSAssistValue - PreviousRSSAssistValue),
        TRY_CONVERT(bigint, HelpsValue - PreviousHelpsValue),
        TRY_CONVERT(bigint, T4KillsValue - PreviousT4KillsValue),
        TRY_CONVERT(bigint, T5KillsValue - PreviousT5KillsValue),
        TRY_CONVERT(bigint, DeadsValue - PreviousDeadsValue),
        TRY_CONVERT(bigint, HealedTroopsValue - PreviousHealedTroopsValue)
    FROM WithPrevious
    WHERE AsOfDate >= @WindowStartDate;

    CREATE TABLE #ActivityDaily
    (
        GovernorID int NOT NULL,
        AsOfDate date NOT NULL,
        PreviousActivityDate date NULL,
        BuildActivityDelta bigint NULL,
        TechDonationsDelta bigint NULL,
        PRIMARY KEY CLUSTERED (GovernorID, AsOfDate)
    );

    ;WITH ActivitySource AS
    (
        SELECT TRY_CONVERT(int, rows.GovernorID) AS GovernorID,
            CONVERT(date, headers.SnapshotTsUtc) AS AsOfDate,
            CONVERT(date, headers.WeekStartUtc) AS WeekStartDate,
            headers.SnapshotTsUtc, rows.SnapshotId,
            TRY_CONVERT(bigint, rows.BuildingTotal) AS BuildActivityValue,
            TRY_CONVERT(bigint, rows.TechDonationTotal) AS TechDonationsValue
        FROM dbo.AllianceActivitySnapshotRow AS rows
        JOIN dbo.AllianceActivitySnapshotHeader AS headers ON headers.SnapshotId = rows.SnapshotId
        JOIN @GovernorIDs AS ids ON rows.GovernorID = ids.ID
        WHERE headers.SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @StatsAnchorDate))
          AND headers.WeekStartUtc >= CONVERT(datetime2(0), DATEADD(DAY, -6, @WindowStartDate))
    ),
    PreviousDates AS
    (
        SELECT GovernorID, WeekStartDate, MAX(AsOfDate) AS AsOfDate
        FROM ActivitySource WHERE AsOfDate < @WindowStartDate GROUP BY GovernorID, WeekStartDate
    ),
    RelevantDates AS
    (
        SELECT GovernorID, WeekStartDate, AsOfDate FROM ActivitySource
        WHERE AsOfDate BETWEEN @WindowStartDate AND @StatsAnchorDate GROUP BY GovernorID, WeekStartDate, AsOfDate
        UNION
        SELECT GovernorID, WeekStartDate, AsOfDate FROM PreviousDates
    ),
    RankedDayEnd AS
    (
        SELECT source.GovernorID, source.AsOfDate, source.WeekStartDate, source.BuildActivityValue, source.TechDonationsValue,
            ROW_NUMBER() OVER (PARTITION BY source.GovernorID, source.WeekStartDate, source.AsOfDate ORDER BY source.SnapshotTsUtc DESC, source.SnapshotId DESC) AS RowNumber
        FROM ActivitySource AS source
        JOIN RelevantDates AS dates ON dates.GovernorID = source.GovernorID AND dates.WeekStartDate = source.WeekStartDate AND dates.AsOfDate = source.AsOfDate
    ),
    DayEnd AS
    (
        SELECT GovernorID, AsOfDate, WeekStartDate, BuildActivityValue, TechDonationsValue
        FROM RankedDayEnd WHERE RowNumber = 1
    ),
    WithPrevious AS
    (
        SELECT values_today.*,
            LAG(values_today.AsOfDate) OVER (PARTITION BY values_today.GovernorID, values_today.WeekStartDate ORDER BY values_today.AsOfDate) AS PreviousActivityDate,
            LAG(values_today.BuildActivityValue) OVER (PARTITION BY values_today.GovernorID, values_today.WeekStartDate ORDER BY values_today.AsOfDate) AS PreviousBuildActivityValue,
            LAG(values_today.TechDonationsValue) OVER (PARTITION BY values_today.GovernorID, values_today.WeekStartDate ORDER BY values_today.AsOfDate) AS PreviousTechDonationsValue
        FROM DayEnd AS values_today
    ),
    ActivityDeltas AS
    (
        SELECT GovernorID, AsOfDate,
            COALESCE(PreviousActivityDate, DATEADD(DAY, -1, WeekStartDate)) AS PreviousActivityDate,
            TRY_CONVERT(bigint, BuildActivityValue - COALESCE(PreviousBuildActivityValue, 0)) AS BuildActivityDelta,
            TRY_CONVERT(bigint, TechDonationsValue - COALESCE(PreviousTechDonationsValue, 0)) AS TechDonationsDelta
        FROM WithPrevious
        WHERE AsOfDate >= @WindowStartDate
    )
    INSERT INTO #ActivityDaily
    SELECT GovernorID, AsOfDate, MAX(PreviousActivityDate),
        CASE WHEN COUNT(*) = COUNT(BuildActivityDelta) THEN SUM(BuildActivityDelta) END,
        CASE WHEN COUNT(*) = COUNT(TechDonationsDelta) THEN SUM(TechDonationsDelta) END
    FROM ActivityDeltas
    GROUP BY GovernorID, AsOfDate;

    CREATE TABLE #FortsDaily
    (
        GovernorID int NOT NULL,
        AsOfDate date NOT NULL,
        FortsTotal bigint NULL,
        FortsLaunched bigint NULL,
        FortsJoined bigint NULL,
        PRIMARY KEY CLUSTERED (GovernorID, AsOfDate)
    );

    INSERT INTO #FortsDaily
    SELECT TRY_CONVERT(int, forts.GovernorID), forts.AsOfDate,
        SUM(TRY_CONVERT(bigint, forts.TotalRallies)),
        SUM(TRY_CONVERT(bigint, forts.RalliesLaunched)),
        SUM(TRY_CONVERT(bigint, forts.RalliesJoined))
    FROM dbo.cur_RallyDaily AS forts
    JOIN @GovernorIDs AS ids ON forts.GovernorID = ids.ID
    WHERE forts.AsOfDate BETWEEN @WindowStartDate AND @StatsAnchorDate
    GROUP BY TRY_CONVERT(int, forts.GovernorID), forts.AsOfDate;

    CREATE TABLE #ReportDates
    (
        GovernorID int NOT NULL,
        AsOfDate date NOT NULL,
        PRIMARY KEY CLUSTERED (GovernorID, AsOfDate)
    );

    INSERT INTO #ReportDates (GovernorID, AsOfDate)
    SELECT GovernorID, AsOfDate FROM #StatsDaily
    UNION
    SELECT GovernorID, AsOfDate FROM #ActivityDaily
    UNION
    SELECT GovernorID, AsOfDate FROM #FortsDaily;

    SELECT dates.GovernorID, dates.AsOfDate,
        CONVERT(bit, CASE WHEN stats.GovernorID IS NULL THEN 0 ELSE 1 END) AS HasStats,
        stats.PreviousStatsDate, stats.PowerValue, stats.TroopPowerValue,
        stats.PowerDelta, stats.TroopPowerDelta, stats.KillPointsDelta,
        stats.RSSGatheredDelta, stats.RSSAssistDelta, stats.HelpsDelta,
        stats.T4KillsDelta, stats.T5KillsDelta, stats.DeadsDelta, stats.HealedTroopsDelta,
        CONVERT(bit, CASE WHEN activity.GovernorID IS NULL THEN 0 ELSE 1 END) AS HasAllianceActivity,
        activity.PreviousActivityDate, activity.BuildActivityDelta, activity.TechDonationsDelta,
        CONVERT(bit, CASE WHEN forts.GovernorID IS NULL THEN 0 ELSE 1 END) AS HasForts,
        forts.FortsTotal, forts.FortsLaunched, forts.FortsJoined
    FROM #ReportDates AS dates
    LEFT JOIN #StatsDaily AS stats ON stats.GovernorID = dates.GovernorID AND stats.AsOfDate = dates.AsOfDate
    LEFT JOIN #ActivityDaily AS activity ON activity.GovernorID = dates.GovernorID AND activity.AsOfDate = dates.AsOfDate
    LEFT JOIN #FortsDaily AS forts ON forts.GovernorID = dates.GovernorID AND forts.AsOfDate = dates.AsOfDate
    ORDER BY dates.GovernorID, dates.AsOfDate
    OPTION (RECOMPILE);
END;

