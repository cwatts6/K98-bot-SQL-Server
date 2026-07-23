/*
MigrationId: 20260723_001_add_leadership_power_and_acclaim_ranks
Purpose: Expose latest-scan Power rank and finalized-KVK Acclaim rank to leadership player review
Author: cwatts
CreatedUtc: 2026-07-23
RequiresBackup: No
RiskLevel: Medium
Rollback: Included
RollbackScript: migrations/rollback/20260723_001_add_leadership_power_and_acclaim_ranks_rollback.sql
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.usp_GetLeadershipPlayerReview', N'P') AS ReviewProcedure, OBJECT_ID(N'dbo.usp_GetLeadershipPlayerKvkHistory', N'P') AS KvkProcedure;
PostValidationQuery: EXEC dbo.usp_GetLeadershipPlayerReview @GovernorID = 2441482, @PeriodDays = 90; EXEC dbo.usp_GetLeadershipPlayerKvkHistory @GovernorID = 2441482, @CandidateLimit = 20;
RelatedBotPR: 538
RelatedSQLPR: 57
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerReview
    @GovernorID bigint,
    @PeriodDays smallint = 90,
    @NowUtc datetime2(0) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @GovernorID <= 0
        THROW 51501, 'Leadership player review requires a positive Governor ID.', 1;
    IF @PeriodDays NOT IN (30, 90, 180, 360)
        THROW 51502, 'Leadership player review period must be 30, 90, 180, or 360 days.', 1;

    DECLARE @EffectiveNow datetime2(0) = COALESCE(@NowUtc, SYSUTCDATETIME());
    DECLARE @AnchorDate date =
        (SELECT MAX(AsOfDate) FROM dbo.KingdomScanData4
         WHERE AsOfDate <= CONVERT(date, @EffectiveNow));
    DECLARE @CurrentStart date = DATEADD(DAY, 1 - @PeriodDays, @AnchorDate);
    DECLARE @PreviousEnd date = DATEADD(DAY, -1, @CurrentStart);
    DECLARE @PreviousStart date = DATEADD(DAY, 1 - @PeriodDays, @PreviousEnd);
    DECLARE @LatestScanOrder bigint =
        (SELECT MAX(TRY_CONVERT(bigint, SCANORDER))
         FROM dbo.KingdomScanData4 WHERE AsOfDate = @AnchorDate);
    DECLARE @LatestScanAtUtc datetime2(0) =
        (SELECT MAX(TRY_CONVERT(datetime2(0), ScanDate))
         FROM dbo.KingdomScanData4 WHERE SCANORDER = @LatestScanOrder);
    DECLARE @BaselineScanOrder bigint =
        (SELECT TOP (1) TRY_CONVERT(bigint, SCANORDER)
         FROM dbo.KingdomScanData4
         WHERE AsOfDate < @PreviousStart
         ORDER BY SCANORDER DESC);

    CREATE TABLE #Scans
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        ScanDateUtc datetime2(0) NOT NULL,
        AsOfDate date NOT NULL,
        ScanOrdinal int NULL
    );

    INSERT INTO #Scans (ScanOrder, ScanDateUtc, AsOfDate)
    SELECT TRY_CONVERT(bigint, SCANORDER),
           MAX(TRY_CONVERT(datetime2(0), ScanDate)),
           MAX(AsOfDate)
    FROM dbo.KingdomScanData4
    WHERE (@AnchorDate IS NOT NULL AND AsOfDate BETWEEN @PreviousStart AND @AnchorDate)
       OR SCANORDER = @BaselineScanOrder
    GROUP BY TRY_CONVERT(bigint, SCANORDER);

    ;WITH Ordered AS
    (
        SELECT ScanOrder, ROW_NUMBER() OVER (ORDER BY ScanOrder) AS ScanOrdinal
        FROM #Scans
    )
    UPDATE scans
    SET ScanOrdinal = ordered.ScanOrdinal
    FROM #Scans AS scans
    JOIN Ordered AS ordered ON ordered.ScanOrder = scans.ScanOrder;

    CREATE TABLE #Population
    (
        GovernorID bigint NOT NULL PRIMARY KEY,
        IsCurrentCohort bit NOT NULL,
        IsCurrentlyAllied bit NOT NULL
    );

    INSERT INTO #Population (GovernorID, IsCurrentCohort, IsCurrentlyAllied)
    SELECT TRY_CONVERT(bigint, GovernorID), 1,
           CONVERT(bit, MAX(CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), N'')
                                      IS NOT NULL THEN 1 ELSE 0 END))
    FROM dbo.KingdomScanData4
    WHERE SCANORDER = @LatestScanOrder
      AND TRY_CONVERT(bigint, GovernorID) > 0
    GROUP BY TRY_CONVERT(bigint, GovernorID);

    IF NOT EXISTS (SELECT 1 FROM #Population WHERE GovernorID = @GovernorID)
        INSERT INTO #Population (GovernorID, IsCurrentCohort, IsCurrentlyAllied)
        VALUES (@GovernorID, 0, 0);

    CREATE TABLE #StatsRows
    (
        GovernorID bigint NOT NULL,
        ScanOrder bigint NOT NULL,
        ScanOrdinal int NOT NULL,
        AsOfDate date NOT NULL,
        ScanDateUtc datetime2(0) NOT NULL,
        GovernorName nvarchar(100) NULL,
        Alliance nvarchar(100) NULL,
        PowerValue decimal(38,0) NULL,
        CityHall int NULL,
        HelpsValue decimal(38,0) NULL,
        RSSValue decimal(38,0) NULL,
        PRIMARY KEY CLUSTERED (GovernorID, ScanOrder)
    );

    ;WITH RankedRows AS
    (
        SELECT
            TRY_CONVERT(bigint, source.GovernorID) AS GovernorID,
            scans.ScanOrder,
            scans.ScanOrdinal,
            scans.AsOfDate,
            TRY_CONVERT(datetime2(0), source.ScanDate) AS ScanDateUtc,
            LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), source.GovernorName))), 100) AS GovernorName,
            LEFT(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), source.Alliance))), N''), 100) AS Alliance,
            TRY_CONVERT(decimal(38,0), source.Power) AS PowerValue,
            TRY_CONVERT(int, source.[City Hall]) AS CityHall,
            TRY_CONVERT(decimal(38,0), source.Helps) AS HelpsValue,
            TRY_CONVERT(decimal(38,0), source.RSS_Gathered) AS RSSValue,
            ROW_NUMBER() OVER
            (
                PARTITION BY TRY_CONVERT(bigint, source.GovernorID), scans.ScanOrder
                ORDER BY source.ScanDate DESC, source.SCAN_UNO DESC
            ) AS RowNumber
        FROM dbo.KingdomScanData4 AS source
        JOIN #Scans AS scans ON scans.ScanOrder = TRY_CONVERT(bigint, source.SCANORDER)
        JOIN #Population AS population
          ON population.GovernorID = TRY_CONVERT(bigint, source.GovernorID)
    )
    INSERT INTO #StatsRows
        (GovernorID, ScanOrder, ScanOrdinal, AsOfDate, ScanDateUtc,
         GovernorName, Alliance, PowerValue, CityHall, HelpsValue, RSSValue)
    SELECT GovernorID, ScanOrder, ScanOrdinal, AsOfDate, ScanDateUtc,
           GovernorName, Alliance, PowerValue, CityHall, HelpsValue, RSSValue
    FROM RankedRows
    WHERE RowNumber = 1;

    CREATE TABLE #StatsDeltas
    (
        GovernorID bigint NOT NULL,
        AsOfDate date NOT NULL,
        IsConsecutive bit NOT NULL,
        HelpsDelta decimal(38,0) NULL,
        HelpsReset bit NOT NULL,
        RSSDelta decimal(38,0) NULL,
        RSSReset bit NOT NULL,
        PowerDelta decimal(38,0) NULL
    );

    ;WITH WithPrevious AS
    (
        SELECT rows.*,
            LAG(ScanOrdinal) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousOrdinal,
            LAG(HelpsValue) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousHelps,
            LAG(RSSValue) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousRSS,
            LAG(PowerValue) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousPower
        FROM #StatsRows AS rows
    )
    INSERT INTO #StatsDeltas
        (GovernorID, AsOfDate, IsConsecutive, HelpsDelta, HelpsReset,
         RSSDelta, RSSReset, PowerDelta)
    SELECT
        GovernorID,
        AsOfDate,
        CONVERT(bit, CASE WHEN PreviousOrdinal = ScanOrdinal - 1 THEN 1 ELSE 0 END),
        CASE WHEN PreviousOrdinal = ScanOrdinal - 1 AND HelpsValue >= PreviousHelps
             THEN HelpsValue - PreviousHelps END,
        CONVERT(bit, CASE WHEN PreviousOrdinal = ScanOrdinal - 1 AND HelpsValue < PreviousHelps
                          THEN 1 ELSE 0 END),
        CASE WHEN PreviousOrdinal = ScanOrdinal - 1 AND RSSValue >= PreviousRSS
             THEN RSSValue - PreviousRSS END,
        CONVERT(bit, CASE WHEN PreviousOrdinal = ScanOrdinal - 1 AND RSSValue < PreviousRSS
                          THEN 1 ELSE 0 END),
        CASE WHEN PreviousOrdinal = ScanOrdinal - 1 THEN PowerValue - PreviousPower END
    FROM WithPrevious
    WHERE AsOfDate BETWEEN @PreviousStart AND @AnchorDate;

    CREATE TABLE #MetricValues
    (
        WindowCode nvarchar(8) NOT NULL,
        GovernorID bigint NOT NULL,
        MetricOrder tinyint NOT NULL,
        MetricCode nvarchar(24) NOT NULL,
        MetricTotal decimal(38,4) NULL,
        ValidReportingDays int NOT NULL,
        ExpectedUnits int NOT NULL,
        MissingUnits int NOT NULL,
        ResetCount int NOT NULL,
        IsAvailable bit NOT NULL,
        PRIMARY KEY CLUSTERED (WindowCode, GovernorID, MetricOrder)
    );

    CREATE TABLE #Windows
    (
        WindowCode nvarchar(8) NOT NULL PRIMARY KEY,
        StartDate date NULL,
        EndDate date NULL
    );
    INSERT INTO #Windows VALUES
        (N'CURRENT', @CurrentStart, @AnchorDate),
        (N'PREVIOUS', @PreviousStart, @PreviousEnd);

    CREATE TABLE #StatsMetricDaily
    (
        GovernorID bigint NOT NULL,
        AsOfDate date NOT NULL,
        MetricOrder tinyint NOT NULL,
        MetricCode nvarchar(24) NOT NULL,
        MetricValue decimal(38,4) NULL,
        WasReset bit NOT NULL
    );
    INSERT INTO #StatsMetricDaily
    SELECT GovernorID, AsOfDate, metric.MetricOrder, metric.MetricCode,
           metric.MetricValue, metric.WasReset
    FROM #StatsDeltas
    CROSS APPLY
    (
        VALUES
            (CONVERT(tinyint, 2), N'HELPS', CONVERT(decimal(38,4), HelpsDelta), HelpsReset),
            (CONVERT(tinyint, 4), N'RSS_GATHERED', CONVERT(decimal(38,4), RSSDelta), RSSReset),
            (CONVERT(tinyint, 6), N'POWER_CHANGE', CONVERT(decimal(38,4), PowerDelta), CONVERT(bit, 0))
    ) AS metric(MetricOrder, MetricCode, MetricValue, WasReset);

    CREATE CLUSTERED INDEX CX_StatsMetricDaily_GovernorMetricDate
        ON #StatsMetricDaily (GovernorID, MetricOrder, AsOfDate);

    INSERT INTO #MetricValues
        (WindowCode, GovernorID, MetricOrder, MetricCode, MetricTotal,
         ValidReportingDays, ExpectedUnits, MissingUnits, ResetCount, IsAvailable)
    SELECT windows.WindowCode, population.GovernorID,
           metric_list.MetricOrder, metric_list.MetricCode,
           (SELECT SUM(daily.MetricValue)
            FROM #StatsMetricDaily AS daily
            WHERE daily.GovernorID = population.GovernorID
              AND daily.MetricOrder = metric_list.MetricOrder
              AND daily.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
           (SELECT COUNT(DISTINCT daily.AsOfDate)
            FROM #StatsMetricDaily AS daily
            WHERE daily.GovernorID = population.GovernorID
              AND daily.MetricOrder = metric_list.MetricOrder
              AND daily.MetricValue IS NOT NULL
              AND daily.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
           (SELECT COUNT(*) FROM #Scans AS scans
            WHERE scans.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
            (SELECT COUNT(*) FROM #Scans AS scans
             WHERE scans.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
              - (SELECT COUNT(*) FROM #StatsRows AS rows
                 WHERE rows.GovernorID = population.GovernorID
                   AND CASE metric_list.MetricOrder
                           WHEN 2 THEN rows.HelpsValue
                           WHEN 4 THEN rows.RSSValue
                           WHEN 6 THEN rows.PowerValue
                       END IS NOT NULL
                   AND rows.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
           (SELECT COUNT(*) FROM #StatsMetricDaily AS daily
            WHERE daily.GovernorID = population.GovernorID
              AND daily.MetricOrder = metric_list.MetricOrder
              AND daily.WasReset = 1
              AND daily.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
            -- Missing observations remain visible in coverage but do not discard valid rates.
            CONVERT(bit, CASE WHEN EXISTS
            (
                SELECT 1 FROM #StatsMetricDaily AS daily
                WHERE daily.GovernorID = population.GovernorID
                 AND daily.MetricOrder = metric_list.MetricOrder
                  AND daily.MetricValue IS NOT NULL
                  AND daily.AsOfDate BETWEEN windows.StartDate AND windows.EndDate
            ) THEN 1 ELSE 0 END)
    FROM #Population AS population
    CROSS JOIN #Windows AS windows
    CROSS JOIN
        (VALUES (CONVERT(tinyint, 2), N'HELPS'),
                (CONVERT(tinyint, 4), N'RSS_GATHERED'),
                (CONVERT(tinyint, 6), N'POWER_CHANGE'))
        AS metric_list(MetricOrder, MetricCode);

    CREATE TABLE #RallyDates (AsOfDate date NOT NULL PRIMARY KEY);
    INSERT INTO #RallyDates
    SELECT AsOfDate FROM dbo.RallyDailySnapshotHeader
    WHERE AsOfDate BETWEEN @PreviousStart AND @AnchorDate;

    INSERT INTO #MetricValues
        (WindowCode, GovernorID, MetricOrder, MetricCode, MetricTotal,
         ValidReportingDays, ExpectedUnits, MissingUnits, ResetCount, IsAvailable)
    SELECT windows.WindowCode, population.GovernorID, 1, N'FORTS_TOTAL',
           SUM(CONVERT(decimal(38,4), COALESCE(rallies.TotalRallies, 0))),
           COUNT(DISTINCT report_dates.AsOfDate),
           @PeriodDays,
           @PeriodDays - COUNT(DISTINCT report_dates.AsOfDate),
           0,
           CONVERT(bit, CASE WHEN COUNT(DISTINCT report_dates.AsOfDate) > 0 THEN 1 ELSE 0 END)
    FROM #Population AS population
    CROSS JOIN #Windows AS windows
    LEFT JOIN #RallyDates AS report_dates
      ON report_dates.AsOfDate BETWEEN windows.StartDate AND windows.EndDate
    LEFT JOIN dbo.cur_RallyDaily AS rallies
      ON rallies.AsOfDate = report_dates.AsOfDate
     AND rallies.GovernorID = population.GovernorID
    GROUP BY windows.WindowCode, population.GovernorID;

    CREATE TABLE #ActivityHeaders
    (
        SnapshotID bigint NOT NULL PRIMARY KEY,
        SnapshotDate date NOT NULL,
        WeekStartDate date NOT NULL,
        WeekOrdinal int NOT NULL,
        CompletionState nvarchar(24) NOT NULL
    );
    ;WITH RankedHeaders AS
    (
        SELECT SnapshotId, CONVERT(date, SnapshotTsUtc) AS SnapshotDate,
               CONVERT(date, WeekStartUtc) AS WeekStartDate, CompletionState,
               ROW_NUMBER() OVER
               (PARTITION BY CONVERT(date, SnapshotTsUtc)
                ORDER BY SnapshotTsUtc DESC, SnapshotId DESC) AS DayRow
        FROM dbo.AllianceActivitySnapshotHeader
        WHERE SnapshotTsUtc >= DATEADD(DAY, -6, CONVERT(datetime2(0), @PreviousStart))
          AND SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate))
    ),
    Selected AS
    (
        SELECT SnapshotId, SnapshotDate, WeekStartDate, CompletionState,
               ROW_NUMBER() OVER
               (PARTITION BY WeekStartDate ORDER BY SnapshotDate, SnapshotId) AS WeekOrdinal
        FROM RankedHeaders WHERE DayRow = 1
    )
    INSERT INTO #ActivityHeaders
    SELECT SnapshotId, SnapshotDate, WeekStartDate, WeekOrdinal, CompletionState
    FROM Selected;

    CREATE TABLE #ActivityDaily
    (
        GovernorID bigint NOT NULL,
        SnapshotDate date NOT NULL,
        MetricOrder tinyint NOT NULL,
        MetricCode nvarchar(24) NOT NULL,
        MetricValue decimal(38,4) NULL,
        WasReset bit NOT NULL,
        IsComplete bit NOT NULL,
        PRIMARY KEY CLUSTERED (GovernorID, SnapshotDate, MetricOrder)
    );

    ;WITH Observed AS
    (
        SELECT population.GovernorID, headers.SnapshotID, headers.SnapshotDate,
               headers.WeekStartDate, headers.WeekOrdinal, headers.CompletionState,
               TRY_CONVERT(decimal(38,0), rows.BuildingTotal) AS BuildingValue,
               TRY_CONVERT(decimal(38,0), rows.TechDonationTotal) AS TechValue,
               LAG(headers.WeekOrdinal) OVER
                 (PARTITION BY population.GovernorID, headers.WeekStartDate
                  ORDER BY headers.WeekOrdinal) AS PreviousWeekOrdinal,
               LAG(headers.CompletionState) OVER
                 (PARTITION BY population.GovernorID, headers.WeekStartDate
                  ORDER BY headers.WeekOrdinal) AS PreviousCompletionState,
               LAG(TRY_CONVERT(decimal(38,0), rows.BuildingTotal)) OVER
                 (PARTITION BY population.GovernorID, headers.WeekStartDate
                  ORDER BY headers.WeekOrdinal) AS PreviousBuilding,
               LAG(TRY_CONVERT(decimal(38,0), rows.TechDonationTotal)) OVER
                 (PARTITION BY population.GovernorID, headers.WeekStartDate
                  ORDER BY headers.WeekOrdinal) AS PreviousTech
        FROM #Population AS population
        CROSS JOIN #ActivityHeaders AS headers
        LEFT JOIN dbo.AllianceActivitySnapshotRow AS rows
          ON rows.SnapshotId = headers.SnapshotID
         AND rows.GovernorID = population.GovernorID
    ),
    Deltas AS
    (
        SELECT *,
            CASE WHEN CompletionState = N'COMPLETE' AND BuildingValue IS NOT NULL
                       AND (WeekOrdinal = 1 OR (PreviousWeekOrdinal = WeekOrdinal - 1
                                               AND PreviousCompletionState = N'COMPLETE'
                                               AND PreviousBuilding IS NOT NULL))
                 THEN BuildingValue - COALESCE(PreviousBuilding, 0) END AS BuildingDelta,
            CASE WHEN CompletionState = N'COMPLETE' AND TechValue IS NOT NULL
                       AND (WeekOrdinal = 1 OR (PreviousWeekOrdinal = WeekOrdinal - 1
                                               AND PreviousCompletionState = N'COMPLETE'
                                               AND PreviousTech IS NOT NULL))
                 THEN TechValue - COALESCE(PreviousTech, 0) END AS TechDelta
        FROM Observed
    )
    INSERT INTO #ActivityDaily
        (GovernorID, SnapshotDate, MetricOrder, MetricCode,
         MetricValue, WasReset, IsComplete)
    SELECT GovernorID, SnapshotDate, metric.MetricOrder, metric.MetricCode,
           CASE WHEN metric.RawDelta >= 0 THEN metric.RawDelta END,
           CONVERT(bit, CASE WHEN metric.RawDelta < 0 THEN 1 ELSE 0 END),
           CONVERT(bit, CASE WHEN CompletionState = N'COMPLETE'
                                  AND metric.RawDelta IS NOT NULL THEN 1 ELSE 0 END)
    FROM Deltas
    CROSS APPLY
    (
        VALUES
            (CONVERT(tinyint, 3), N'TECH_DONATIONS', CONVERT(decimal(38,4), TechDelta)),
            (CONVERT(tinyint, 5), N'BUILDING_MINUTES', CONVERT(decimal(38,4), BuildingDelta))
    ) AS metric(MetricOrder, MetricCode, RawDelta)
    WHERE SnapshotDate BETWEEN @PreviousStart AND @AnchorDate;

    INSERT INTO #MetricValues
        (WindowCode, GovernorID, MetricOrder, MetricCode, MetricTotal,
         ValidReportingDays, ExpectedUnits, MissingUnits, ResetCount, IsAvailable)
    SELECT windows.WindowCode, population.GovernorID,
           metric_list.MetricOrder, metric_list.MetricCode,
           SUM(CASE WHEN daily.MetricValue IS NOT NULL THEN daily.MetricValue END),
           COUNT(DISTINCT CASE WHEN daily.MetricValue IS NOT NULL THEN daily.SnapshotDate END),
           COUNT(DISTINCT headers.SnapshotDate),
           COUNT(DISTINCT headers.SnapshotDate)
             - COUNT(DISTINCT CASE WHEN daily.IsComplete = 1 THEN daily.SnapshotDate END),
           COALESCE(SUM(CASE WHEN daily.WasReset = 1 THEN 1 ELSE 0 END), 0),
           -- Rank partial evidence by its valid-day rate; never impute a missing row as zero.
           CONVERT(bit, CASE
               WHEN population.IsCurrentlyAllied = 0 THEN 0
               WHEN COUNT(daily.MetricValue) = 0 THEN 0
               ELSE 1 END)
    FROM #Population AS population
    CROSS JOIN #Windows AS windows
    CROSS JOIN
        (VALUES (CONVERT(tinyint, 3), N'TECH_DONATIONS'),
                (CONVERT(tinyint, 5), N'BUILDING_MINUTES'))
        AS metric_list(MetricOrder, MetricCode)
    LEFT JOIN #ActivityHeaders AS headers
      ON headers.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate
    LEFT JOIN #ActivityDaily AS daily
      ON daily.GovernorID = population.GovernorID
     AND daily.SnapshotDate = headers.SnapshotDate
     AND daily.MetricOrder = metric_list.MetricOrder
    GROUP BY windows.WindowCode, population.GovernorID,
             population.IsCurrentlyAllied, metric_list.MetricOrder, metric_list.MetricCode;

    CREATE TABLE #MetricRanks
    (
        GovernorID bigint NOT NULL,
        MetricOrder tinyint NOT NULL,
        RankValue decimal(38,8) NOT NULL,
        CompetitionRank int NOT NULL,
        AverageRank decimal(18,4) NOT NULL,
        CohortCount int NOT NULL,
        PercentileScore decimal(9,4) NULL,
        PRIMARY KEY CLUSTERED (GovernorID, MetricOrder)
    );

    ;WITH RankBase AS
    (
        SELECT values_current.GovernorID, values_current.MetricOrder,
               CONVERT(decimal(38,8), values_current.MetricTotal
                   / NULLIF(values_current.ValidReportingDays, 0)) AS RankValue
        FROM #MetricValues AS values_current
        JOIN #Population AS population
          ON population.GovernorID = values_current.GovernorID
         AND population.IsCurrentCohort = 1
        WHERE values_current.WindowCode = N'CURRENT'
          AND values_current.IsAvailable = 1
          AND values_current.ValidReportingDays > 0
          AND values_current.MetricTotal IS NOT NULL
    ),
    Ranked AS
    (
        SELECT *,
            RANK() OVER (PARTITION BY MetricOrder ORDER BY RankValue DESC) AS CompetitionRank,
            COUNT(*) OVER (PARTITION BY MetricOrder, RankValue) AS TieCount,
            COUNT(*) OVER (PARTITION BY MetricOrder) AS CohortCount,
            MIN(RankValue) OVER (PARTITION BY MetricOrder) AS MinimumValue,
            MAX(RankValue) OVER (PARTITION BY MetricOrder) AS MaximumValue
        FROM RankBase
    )
    INSERT INTO #MetricRanks
    SELECT GovernorID, MetricOrder, RankValue, CompetitionRank,
           CONVERT(decimal(18,4), CompetitionRank + (TieCount - 1) / 2.0),
           CohortCount,
           CONVERT(decimal(9,4), CASE
               WHEN CohortCount < 2 THEN NULL
               WHEN MinimumValue = MaximumValue THEN 50.0
               ELSE (CohortCount - (CompetitionRank + (TieCount - 1) / 2.0))
                    / (CohortCount - 1.0) * 100.0 END)
    FROM Ranked;

    CREATE TABLE #ActivityIndex
    (
        GovernorID bigint NOT NULL PRIMARY KEY,
        ActivityIndex decimal(9,4) NOT NULL,
        ActivityRank int NULL,
        CohortCount int NULL
    );

    ;WITH Weighted AS
    (
        SELECT ranks.GovernorID, ranks.MetricOrder, ranks.PercentileScore,
               weights.WeightPercent
        FROM #MetricRanks AS ranks
        JOIN
            (VALUES (CONVERT(tinyint, 1), CONVERT(decimal(9,4), 30.0)),
                    (CONVERT(tinyint, 2), CONVERT(decimal(9,4), 22.0)),
                    (CONVERT(tinyint, 3), CONVERT(decimal(9,4), 18.0)),
                    (CONVERT(tinyint, 4), CONVERT(decimal(9,4), 14.0)),
                    (CONVERT(tinyint, 5), CONVERT(decimal(9,4), 10.0)),
                    (CONVERT(tinyint, 6), CONVERT(decimal(9,4), 6.0)))
            AS weights(MetricOrder, WeightPercent)
          ON weights.MetricOrder = ranks.MetricOrder
    ),
    IndexBase AS
    (
        SELECT GovernorID,
               CONVERT(decimal(9,4), SUM(PercentileScore * WeightPercent) / 100.0)
                   AS ActivityIndex
        FROM Weighted
        GROUP BY GovernorID
        HAVING COUNT(*) = 6 AND COUNT(PercentileScore) = 6
    ),
    RankedIndex AS
    (
        SELECT *, RANK() OVER (ORDER BY ActivityIndex DESC) AS ActivityRank,
               COUNT(*) OVER () AS CohortCount
        FROM IndexBase
    )
    INSERT INTO #ActivityIndex
    SELECT GovernorID, ActivityIndex, ActivityRank, CohortCount
    FROM RankedIndex;

    DECLARE @TargetLatestScanOrder bigint =
        (SELECT MAX(TRY_CONVERT(bigint, SCANORDER))
         FROM dbo.KingdomScanData4 WHERE GovernorID = @GovernorID);
    DECLARE @TargetFirstObservedDate date =
        (SELECT MIN(AsOfDate) FROM dbo.KingdomScanData4
         WHERE GovernorID = @GovernorID);

    /* Result set 1: header and source facts. */
    SELECT
        N'leadership_player_review_v1' AS ContractVersion,
        N'activity_index_v1|combat_metrics_v1' AS FormulaVersion,
        @GovernorID AS GovernorID,
        target.GovernorName,
        target.Alliance AS CurrentAlliance,
        target.PowerValue AS CurrentPower,
        target.PowerRank AS PowerRank,
        target.CityHall,
        @EffectiveNow AS EffectiveNowUtc,
        @AnchorDate AS AnchorDate,
        @CurrentStart AS CurrentStartDate,
        @AnchorDate AS CurrentEndDate,
        @PreviousStart AS PreviousStartDate,
        @PreviousEnd AS PreviousEndDate,
        @PeriodDays AS PeriodDays,
        @PreviousStart AS ReadStartDate,
        @LatestScanOrder AS LatestCompleteScanOrder,
        @LatestScanAtUtc AS LatestCompleteScanAtUtc,
        @TargetLatestScanOrder AS LatestGovernorScanOrder,
        target.ScanDateUtc AS LatestGovernorScanAtUtc,
        CONVERT(bit, CASE WHEN @TargetLatestScanOrder = @LatestScanOrder THEN 1 ELSE 0 END)
            AS PresentInLatestCompleteScan,
        @TargetFirstObservedDate AS FirstObservedDate,
        CASE WHEN @TargetFirstObservedDate BETWEEN @CurrentStart AND @AnchorDate
             THEN DATEDIFF(DAY, @CurrentStart, @TargetFirstObservedDate) END
            AS FirstObservedOffsetDays,
        location.X AS LocationX,
        location.Y AS LocationY,
        location.LastUpdated AS LocationUpdatedAtUtc,
        location.ShieldEndsAtUtc
    FROM (VALUES (1)) AS singleton(Value)
    OUTER APPLY
    (
        SELECT TOP (1)
            LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), GovernorName))), 100) AS GovernorName,
            LEFT(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), N''), 100) AS Alliance,
            TRY_CONVERT(decimal(38,0), Power) AS PowerValue,
            TRY_CONVERT(int, PowerRank) AS PowerRank,
            TRY_CONVERT(int, [City Hall]) AS CityHall,
            TRY_CONVERT(datetime2(0), ScanDate) AS ScanDateUtc
        FROM dbo.KingdomScanData4
        WHERE GovernorID = @GovernorID
        ORDER BY SCANORDER DESC, ScanDate DESC, SCAN_UNO DESC
    ) AS target
    LEFT JOIN dbo.PlayerLocation AS location ON location.GovernorID = @GovernorID;

    /* Result set 2: scan presence, separate from activity coverage/index. */
    SELECT windows.WindowCode,
           COUNT(DISTINCT scans.ScanOrder) AS CompleteScanCount,
           COUNT(DISTINCT CASE WHEN rows.GovernorID IS NOT NULL THEN scans.ScanOrder END)
               AS PresentScanCount,
           COUNT(DISTINCT scans.AsOfDate) AS ScannedDayCount,
           COUNT(DISTINCT CASE WHEN rows.GovernorID IS NOT NULL THEN scans.AsOfDate END)
               AS PresentScannedDayCount
    FROM #Windows AS windows
    LEFT JOIN #Scans AS scans
      ON scans.AsOfDate BETWEEN windows.StartDate AND windows.EndDate
    LEFT JOIN #StatsRows AS rows
      ON rows.ScanOrder = scans.ScanOrder AND rows.GovernorID = @GovernorID
    GROUP BY windows.WindowCode
    ORDER BY CASE windows.WindowCode WHEN N'CURRENT' THEN 1 ELSE 2 END;

    /* Result set 3: source coverage. */
    SELECT windows.WindowCode, coverage.SourceCode, coverage.RequiredSource,
           coverage.ExpectedUnits, coverage.ValidUnits,
           coverage.ExpectedUnits - coverage.ValidUnits AS MissingUnits,
           coverage.ResetCount, coverage.CoverageState
    FROM #Windows AS windows
    CROSS APPLY
    (
        SELECT N'STATS_SCANS' AS SourceCode, CONVERT(bit, 1) AS RequiredSource,
               (SELECT COUNT(*) FROM #Scans s
                WHERE s.AsOfDate BETWEEN windows.StartDate AND windows.EndDate) AS ExpectedUnits,
               (SELECT COUNT(*) FROM #StatsRows r
                WHERE r.GovernorID = @GovernorID
                  AND r.HelpsValue IS NOT NULL
                  AND r.RSSValue IS NOT NULL
                  AND r.PowerValue IS NOT NULL
                  AND r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate) AS ValidUnits,
               COALESCE((SELECT SUM(ResetCount) FROM #MetricValues m
                         WHERE m.GovernorID = @GovernorID
                           AND m.WindowCode = windows.WindowCode
                           AND m.MetricOrder IN (2, 4)), 0) AS ResetCount,
               CASE
                   WHEN NOT EXISTS (SELECT 1 FROM #StatsRows r WHERE r.GovernorID = @GovernorID
                                    AND r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'NO_DATA'
                   WHEN (SELECT COUNT(*) FROM #Scans s
                         WHERE s.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
                        = (SELECT COUNT(*) FROM #StatsRows r
                           WHERE r.GovernorID = @GovernorID
                             AND r.HelpsValue IS NOT NULL
                             AND r.RSSValue IS NOT NULL
                             AND r.PowerValue IS NOT NULL
                             AND r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'COMPLETE'
                   ELSE N'PARTIAL' END AS CoverageState
        UNION ALL
        SELECT N'ALLIANCE_ACTIVITY', population.IsCurrentlyAllied,
               (SELECT COUNT(*) FROM #ActivityHeaders h
                WHERE h.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate),
               (SELECT COUNT(DISTINCT d.SnapshotDate) FROM #ActivityDaily d
                WHERE d.GovernorID = @GovernorID AND d.IsComplete = 1
                  AND d.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate),
               COALESCE((SELECT SUM(ResetCount) FROM #MetricValues m
                         WHERE m.GovernorID = @GovernorID
                           AND m.WindowCode = windows.WindowCode
                           AND m.MetricOrder IN (3, 5)), 0),
               CASE
                   WHEN population.IsCurrentlyAllied = 0 THEN N'NOT_REQUIRED'
                   WHEN NOT EXISTS (SELECT 1 FROM #ActivityHeaders h
                                    WHERE h.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'NO_DATA'
                   WHEN EXISTS (SELECT 1 FROM #ActivityHeaders h
                                WHERE h.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate
                                  AND h.CompletionState <> N'COMPLETE')
                       THEN N'PARTIAL'
                   WHEN (SELECT COUNT(*) FROM #ActivityHeaders h
                         WHERE h.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate)
                        = (SELECT COUNT(DISTINCT d.SnapshotDate) FROM #ActivityDaily d
                           WHERE d.GovernorID = @GovernorID AND d.IsComplete = 1
                             AND d.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'COMPLETE'
                   ELSE N'PARTIAL' END
        FROM #Population AS population WHERE population.GovernorID = @GovernorID
        UNION ALL
        SELECT N'RALLY_COMPLETED_DATES', CONVERT(bit, 1), @PeriodDays,
               (SELECT COUNT(*) FROM #RallyDates r
                WHERE r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
               0,
               CASE
                   WHEN NOT EXISTS (SELECT 1 FROM #RallyDates r
                                    WHERE r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'NO_DATA'
                   WHEN (SELECT COUNT(*) FROM #RallyDates r
                         WHERE r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate) = @PeriodDays
                       THEN N'COMPLETE'
                   ELSE N'PARTIAL' END
    ) AS coverage(SourceCode, RequiredSource, ExpectedUnits, ValidUnits, ResetCount, CoverageState)
    ORDER BY CASE windows.WindowCode WHEN N'CURRENT' THEN 1 ELSE 2 END,
             CASE coverage.SourceCode WHEN N'STATS_SCANS' THEN 1
                  WHEN N'ALLIANCE_ACTIVITY' THEN 2 ELSE 3 END;

    /* Result set 4: the six ordered metrics and equal-period comparison. */
    SELECT current_values.MetricOrder, current_values.MetricCode,
           current_values.MetricTotal AS CurrentTotal,
           current_values.ValidReportingDays AS CurrentValidReportingDays,
           CONVERT(decimal(38,8), current_values.MetricTotal
               / NULLIF(current_values.ValidReportingDays, 0)) AS CurrentAveragePerValidDay,
           previous_values.MetricTotal AS PreviousTotal,
           previous_values.ValidReportingDays AS PreviousValidReportingDays,
           CONVERT(decimal(38,8), previous_values.MetricTotal
               / NULLIF(previous_values.ValidReportingDays, 0)) AS PreviousAveragePerValidDay,
           CASE
               WHEN current_values.IsAvailable = 0 OR previous_values.IsAvailable = 0
                   THEN N'UNAVAILABLE'
               WHEN previous_values.MetricTotal = 0 AND current_values.MetricTotal > 0
                   THEN N'NEW_VS_ZERO'
               WHEN current_values.ValidReportingDays = previous_values.ValidReportingDays
                   THEN N'TOTAL_PERCENT'
               ELSE N'RATE_PERCENT' END AS ComparisonMode,
           CONVERT(decimal(18,4), CASE
               WHEN current_values.IsAvailable = 0 OR previous_values.IsAvailable = 0 THEN NULL
               WHEN previous_values.MetricTotal = 0 AND current_values.MetricTotal = 0 THEN 0
               WHEN previous_values.MetricTotal = 0 THEN NULL
               WHEN current_values.ValidReportingDays = previous_values.ValidReportingDays
                   THEN (current_values.MetricTotal - previous_values.MetricTotal)
                        / NULLIF(ABS(previous_values.MetricTotal), 0) * 100.0
               WHEN previous_values.ValidReportingDays > 0
                   THEN ((current_values.MetricTotal
                            / NULLIF(current_values.ValidReportingDays, 0))
                         - (previous_values.MetricTotal
                            / NULLIF(previous_values.ValidReportingDays, 0)))
                        / NULLIF(ABS(previous_values.MetricTotal
                            / NULLIF(previous_values.ValidReportingDays, 0)), 0) * 100.0
               END) AS ComparisonPercent,
           current_values.ExpectedUnits AS CurrentExpectedUnits,
           current_values.MissingUnits AS CurrentMissingUnits,
           current_values.ResetCount AS CurrentResetCount,
           current_values.IsAvailable AS CurrentIsAvailable,
           ranks.CompetitionRank AS KingdomRank,
           ranks.CohortCount AS RankCohortCount,
           ranks.PercentileScore,
           CONVERT(decimal(9,4), 100.0 - ranks.PercentileScore) AS TopPercent
    FROM #MetricValues AS current_values
    LEFT JOIN #MetricValues AS previous_values
      ON previous_values.GovernorID = current_values.GovernorID
     AND previous_values.MetricOrder = current_values.MetricOrder
     AND previous_values.WindowCode = N'PREVIOUS'
    LEFT JOIN #MetricRanks AS ranks
      ON ranks.GovernorID = current_values.GovernorID
     AND ranks.MetricOrder = current_values.MetricOrder
    WHERE current_values.WindowCode = N'CURRENT'
      AND current_values.GovernorID = @GovernorID
    ORDER BY current_values.MetricOrder;

    /* Result set 5: Activity Index v1 and visible components. */
    SELECT index_values.ActivityIndex, index_values.ActivityRank,
           index_values.CohortCount AS ActivityRankCohortCount,
           MAX(CASE WHEN ranks.MetricOrder = 1 THEN ranks.PercentileScore END) AS FortsScore,
           MAX(CASE WHEN ranks.MetricOrder = 2 THEN ranks.PercentileScore END) AS HelpsScore,
           MAX(CASE WHEN ranks.MetricOrder = 3 THEN ranks.PercentileScore END) AS TechScore,
           MAX(CASE WHEN ranks.MetricOrder = 4 THEN ranks.PercentileScore END) AS RSSScore,
           MAX(CASE WHEN ranks.MetricOrder = 5 THEN ranks.PercentileScore END) AS BuildingScore,
           MAX(CASE WHEN ranks.MetricOrder = 6 THEN ranks.PercentileScore END) AS PowerScore,
           CASE WHEN index_values.GovernorID IS NULL THEN N'MISSING_COMPONENT'
                ELSE N'AVAILABLE' END AS Availability
    FROM (VALUES (@GovernorID)) AS requested(GovernorID)
    LEFT JOIN #ActivityIndex AS index_values
      ON index_values.GovernorID = requested.GovernorID
    LEFT JOIN #MetricRanks AS ranks
      ON ranks.GovernorID = requested.GovernorID
    GROUP BY index_values.GovernorID, index_values.ActivityIndex,
             index_values.ActivityRank, index_values.CohortCount;

    /* Result set 6: source history depth and gap type. */
    CREATE TABLE #HistoryDepth
    (
        SourceCode nvarchar(32) NOT NULL,
        HistoryKind nvarchar(32) NOT NULL,
        EarliestObservedDate date NULL,
        LatestObservedDate date NULL,
        ObservationCount int NOT NULL,
        GapCount int NULL,
        LongestGapDays int NULL,
        EvidenceBasis nvarchar(32) NOT NULL
    );

    DECLARE @HistoryReadStart date = DATEADD(DAY, -719, @AnchorDate);

    ;WITH StatsScans AS
    (
        SELECT TRY_CONVERT(bigint, SCANORDER) AS ScanOrder, MAX(AsOfDate) AS AsOfDate
        FROM dbo.KingdomScanData4
        WHERE AsOfDate BETWEEN @HistoryReadStart AND @AnchorDate
        GROUP BY TRY_CONVERT(bigint, SCANORDER)
    )
    INSERT INTO #HistoryDepth
    SELECT N'KINGDOM_SCANS', N'COMPLETE_SCANORDERS', MIN(AsOfDate), MAX(AsOfDate), COUNT(*),
           NULL, NULL, N'AUTHORITATIVE_SCANORDER'
    FROM StatsScans;

    ;WITH StatsDates AS
    (
        SELECT DISTINCT AsOfDate FROM dbo.KingdomScanData4
        WHERE AsOfDate BETWEEN @HistoryReadStart AND @AnchorDate
    ), StatsGaps AS
    (
        SELECT AsOfDate, DATEDIFF(DAY, LAG(AsOfDate) OVER (ORDER BY AsOfDate), AsOfDate) AS GapDays
        FROM StatsDates
    )
    INSERT INTO #HistoryDepth
    SELECT N'KINGDOM_SCANS', N'SCANNED_DAYS', MIN(AsOfDate), MAX(AsOfDate), COUNT(*),
           SUM(CASE WHEN GapDays > 1 THEN 1 ELSE 0 END),
           MAX(CASE WHEN GapDays > 1 THEN GapDays - 1 END), N'AUTHORITATIVE_SCANORDER'
    FROM StatsGaps;

    ;WITH ActivityDates AS
    (
        SELECT DISTINCT CONVERT(date, SnapshotTsUtc) AS AsOfDate
        FROM dbo.AllianceActivitySnapshotHeader
        WHERE SnapshotTsUtc >= @HistoryReadStart
          AND SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate))
    ), ActivityGaps AS
    (
        SELECT AsOfDate, DATEDIFF(DAY, LAG(AsOfDate) OVER (ORDER BY AsOfDate), AsOfDate) AS GapDays
        FROM ActivityDates
    )
    INSERT INTO #HistoryDepth
    SELECT N'ALLIANCE_ACTIVITY', N'SNAPSHOT_DATES', MIN(AsOfDate), MAX(AsOfDate), COUNT(*),
           SUM(CASE WHEN GapDays > 1 THEN 1 ELSE 0 END),
           MAX(CASE WHEN GapDays > 1 THEN GapDays - 1 END), N'HEADER_COMPLETION_STATE'
    FROM ActivityGaps;

    INSERT INTO #HistoryDepth
    SELECT N'ALLIANCE_ACTIVITY', N'SNAPSHOTS',
           MIN(CONVERT(date, SnapshotTsUtc)), MAX(CONVERT(date, SnapshotTsUtc)), COUNT(*),
           NULL, NULL, N'HEADER_ROWS'
    FROM dbo.AllianceActivitySnapshotHeader
    WHERE SnapshotTsUtc >= @HistoryReadStart
      AND SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate));

    INSERT INTO #HistoryDepth
    SELECT N'ALLIANCE_ACTIVITY', LEFT(N'STATE_' + CompletionState, 32),
           MIN(CONVERT(date, SnapshotTsUtc)), MAX(CONVERT(date, SnapshotTsUtc)), COUNT(*),
           NULL, NULL, CompletionState
    FROM dbo.AllianceActivitySnapshotHeader
    WHERE SnapshotTsUtc >= @HistoryReadStart
      AND SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate))
    GROUP BY CompletionState;

    ;WITH RallyGaps AS
    (
        SELECT AsOfDate, DATEDIFF(DAY, LAG(AsOfDate) OVER (ORDER BY AsOfDate), AsOfDate) AS GapDays
        FROM dbo.RallyDailySnapshotHeader
        WHERE AsOfDate BETWEEN @HistoryReadStart AND @AnchorDate
    )
    INSERT INTO #HistoryDepth
    SELECT N'RALLY', N'COMPLETED_REPORT_DATES', MIN(AsOfDate), MAX(AsOfDate), COUNT(*),
           SUM(CASE WHEN GapDays > 1 THEN 1 ELSE 0 END),
           MAX(CASE WHEN GapDays > 1 THEN GapDays - 1 END), N'COMPLETION_HEADER'
    FROM RallyGaps;

    INSERT INTO #HistoryDepth
    SELECT N'RALLY', LEFT(N'BASIS_' + CompletionBasis, 32), MIN(AsOfDate), MAX(AsOfDate),
           COUNT(*), NULL, NULL, CompletionBasis
    FROM dbo.RallyDailySnapshotHeader
    WHERE AsOfDate BETWEEN @HistoryReadStart AND @AnchorDate
    GROUP BY CompletionBasis;

    INSERT INTO #HistoryDepth
    SELECT N'ALIASES', N'OBSERVED_NAME_HISTORY',
           CONVERT(date, MIN(FirstSeen)), CONVERT(date, MAX(LastSeen)), COUNT(*),
           NULL, NULL, N'SCAN_BACKFILL'
    FROM dbo.GovernorNameHistory WHERE GovernorID = @GovernorID;

    INSERT INTO #HistoryDepth
    SELECT N'LOCATION', N'CURRENT_SNAPSHOT_ONLY', CONVERT(date, MIN(LastUpdated)),
           CONVERT(date, MAX(LastUpdated)), COUNT(*), NULL, NULL, N'NO_HISTORY_TABLE'
    FROM dbo.PlayerLocation WHERE GovernorID = @GovernorID;

    INSERT INTO #HistoryDepth
    SELECT N'FINAL_KVK', N'OUTPUT_COMPLETION', MIN(CONVERT(date, FinalDataAtUtc)),
           MAX(CONVERT(date, FinalDataAtUtc)), COUNT(*), NULL, NULL, N'FINAL_REPORT_HEADER'
    FROM dbo.KVKFinalReportHeader
    WHERE FinalDataAtUtc >= @HistoryReadStart
      AND FinalDataAtUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate));

    INSERT INTO #HistoryDepth
    SELECT N'FINAL_KVK', LEFT(N'BASIS_' + FinalizationBasis, 32),
           MIN(CONVERT(date, FinalDataAtUtc)), MAX(CONVERT(date, FinalDataAtUtc)),
           COUNT(*), NULL, NULL, FinalizationBasis
    FROM dbo.KVKFinalReportHeader
    WHERE FinalDataAtUtc >= @HistoryReadStart
      AND FinalDataAtUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate))
    GROUP BY FinalizationBasis;

    SELECT @HistoryReadStart AS ReadStartDate, @AnchorDate AS ReadEndDate,
           SourceCode, HistoryKind, EarliestObservedDate, LatestObservedDate,
           ObservationCount, GapCount, LongestGapDays, EvidenceBasis
    FROM #HistoryDepth
    ORDER BY CASE SourceCode WHEN N'KINGDOM_SCANS' THEN 1 WHEN N'ALLIANCE_ACTIVITY' THEN 2
             WHEN N'RALLY' THEN 3 WHEN N'ALIASES' THEN 4
             WHEN N'LOCATION' THEN 5 ELSE 6 END;
END;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerKvkHistory
    @GovernorID bigint,
    @CandidateLimit tinyint = 12
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @GovernorID <= 0
        THROW 51521, 'Leadership KVK history requires a positive Governor ID.', 1;
    IF @CandidateLimit < 3 OR @CandidateLimit > 20
        THROW 51522, 'Leadership KVK candidate limit must be between 3 and 20.', 1;

    DECLARE @PersonalCompletedKvkBestAcclaim bigint =
    (
        SELECT MAX(TRY_CONVERT(bigint, history.Acclaim))
        FROM dbo.v_EXCEL_FOR_KVK_All AS history
        JOIN dbo.KVKFinalReportHeader AS final_header
          ON final_header.KVK_NO = TRY_CONVERT(int, history.KVK_NO)
         AND final_header.State = N'OUTPUT_COMPLETE'
        WHERE TRY_CONVERT(bigint, history.Gov_ID) = @GovernorID
    );

    CREATE TABLE #Candidates
    (
        KVK_NO int NOT NULL PRIMARY KEY,
        KVK_NAME nvarchar(100) NULL,
        KVK_REGISTRATION_DATE date NULL,
        KVK_START_DATE date NULL,
        KVK_END_DATE date NULL,
        MATCHMAKING_SCAN int NULL,
        KVK_END_SCAN int NULL,
        MATCHMAKING_START_DATE date NULL,
        FIGHTING_START_DATE date NULL,
        PASS4_START_SCAN int NULL
    );
    INSERT INTO #Candidates
    SELECT TOP (@CandidateLimit)
           KVK_NO, KVK_NAME, KVK_REGISTRATION_DATE, KVK_START_DATE, KVK_END_DATE,
           MATCHMAKING_SCAN, KVK_END_SCAN, MATCHMAKING_START_DATE,
           FIGHTING_START_DATE, PASS4_START_SCAN
    FROM dbo.KVK_Details
    ORDER BY KVK_NO DESC;

    /* Result set 1: resolver inputs plus independent final-output evidence. */
    SELECT candidates.KVK_NO, candidates.KVK_NAME,
           candidates.KVK_REGISTRATION_DATE, candidates.KVK_START_DATE,
           candidates.KVK_END_DATE, candidates.MATCHMAKING_SCAN,
           candidates.KVK_END_SCAN, candidates.MATCHMAKING_START_DATE,
           candidates.FIGHTING_START_DATE, candidates.PASS4_START_SCAN,
           final_header.FinalDataAtUtc, final_header.FinalScanOrder,
           final_header.OutputRowCount, final_header.State AS FinalOutputState,
           final_header.FinalizationBasis
    FROM #Candidates AS candidates
    LEFT JOIN dbo.KVKFinalReportHeader AS final_header
      ON final_header.KVK_NO = candidates.KVK_NO
    ORDER BY candidates.KVK_NO DESC;

    CREATE TABLE #KvkIndexKvks
    (
        KVK_NO int NOT NULL PRIMARY KEY
    );
    INSERT INTO #KvkIndexKvks (KVK_NO)
    SELECT TOP (3) index_details.KVK_NO
    FROM dbo.KVK_Details AS index_details
    JOIN dbo.KVKFinalReportHeader AS final_header
      ON final_header.KVK_NO = index_details.KVK_NO
     AND final_header.State = N'OUTPUT_COMPLETE'
    ORDER BY index_details.KVK_NO DESC;

    DECLARE @KvkIndexCandidateCount int =
        (SELECT COUNT(*) FROM #KvkIndexKvks);

    CREATE TABLE #Calculated
    (
        KVK_NO int NOT NULL,
        GovernorID bigint NOT NULL,
        GovernorName nvarchar(255) NULL,
        KVKRank int NULL,
        T4T5Kills bigint NULL,
        KillTarget bigint NULL,
        KillTargetPercent decimal(18,4) NULL,
        KillPoints bigint NULL,
        Deads bigint NULL,
        DeadTarget bigint NULL,
        DeadTargetPercent decimal(18,4) NULL,
        Healed bigint NULL,
        KPLoss decimal(38,0) NULL,
        TankingScore decimal(38,8) NULL,
        Acclaim bigint NULL,
        DKP bigint NULL,
        DKPTarget bigint NULL,
        DKPTargetPercent decimal(18,4) NULL,
        PreKvkPoints bigint NULL,
        PreKvkRank int NULL,
        HonorPoints bigint NULL,
        HonorRank int NULL,
        IsExempt bit NOT NULL,
        IsEngaged bit NOT NULL,
        PRIMARY KEY CLUSTERED (KVK_NO, GovernorID)
    );

    ;WITH SourceRows AS
    (
        SELECT TRY_CONVERT(int, history.KVK_NO) AS KVK_NO,
               TRY_CONVERT(bigint, history.Gov_ID) AS GovernorID,
               CONVERT(nvarchar(255), history.Governor_Name) AS GovernorName,
               TRY_CONVERT(int, history.KVK_RANK) AS KVKRank,
               TRY_CONVERT(bigint, history.[T4&T5_Kills]) AS T4T5Kills,
               TRY_CONVERT(bigint, history.[Kill Target]) AS KillTarget,
               COALESCE(
                   TRY_CONVERT(decimal(18,4), history.[% of Kill Target]),
                   TRY_CONVERT(decimal(18,4),
                       TRY_CONVERT(decimal(38,8), history.[T4&T5_Kills])
                       / NULLIF(TRY_CONVERT(decimal(38,8), history.[Kill Target]), 0)
                       * 100.0)
               ) AS KillTargetPercent,
               TRY_CONVERT(bigint, history.KillPointsDelta) AS KillPoints,
               TRY_CONVERT(bigint, history.Deads_Delta) AS Deads,
               TRY_CONVERT(bigint, history.Dead_Target) AS DeadTarget,
               COALESCE(
                   TRY_CONVERT(decimal(18,4), history.[% of Dead Target]),
                   TRY_CONVERT(decimal(18,4),
                       TRY_CONVERT(decimal(38,8), history.Deads_Delta)
                       / NULLIF(TRY_CONVERT(decimal(38,8), history.Dead_Target), 0)
                       * 100.0)
               ) AS DeadTargetPercent,
               TRY_CONVERT(bigint, history.HealedTroopsDelta) AS Healed,
               TRY_CONVERT(bigint, history.Acclaim) AS Acclaim,
               TRY_CONVERT(bigint, history.DKP_SCORE) AS DKP,
               TRY_CONVERT(bigint, history.[DKP Target]) AS DKPTarget,
               COALESCE(
                   TRY_CONVERT(decimal(18,4), history.[% of DKP Target]),
                   TRY_CONVERT(decimal(18,4),
                       TRY_CONVERT(decimal(38,8), history.DKP_SCORE)
                       / NULLIF(TRY_CONVERT(decimal(38,8), history.[DKP Target]), 0)
                       * 100.0)
               ) AS DKPTargetPercent,
               TRY_CONVERT(bigint, history.Max_PreKvk_Points) AS PreKvkPoints,
               TRY_CONVERT(int, history.PreKvk_Rank) AS PreKvkRank,
               TRY_CONVERT(bigint, history.Max_HonorPoints) AS HonorPoints,
               TRY_CONVERT(int, history.Honor_Rank) AS HonorRank,
               CONVERT(bit, CASE WHEN EXISTS
                    (SELECT 1 FROM dbo.EXEMPT_FROM_STATS AS exemption
                     WHERE TRY_CONVERT(bigint, exemption.GovernorID) = history.Gov_ID
                       AND ISNULL(exemption.Exempt, 1) = 1
                       AND TRY_CONVERT(int, exemption.KVK_NO) IN (0, history.KVK_NO))
                    THEN 1 ELSE 0 END) AS IsExempt
        FROM dbo.v_EXCEL_FOR_KVK_All AS history
        JOIN
        (
            SELECT candidate.KVK_NO FROM #Candidates AS candidate
            UNION
            SELECT index_kvk.KVK_NO FROM #KvkIndexKvks AS index_kvk
        ) AS relevant_kvk
          ON relevant_kvk.KVK_NO = history.KVK_NO
        JOIN dbo.KVKFinalReportHeader AS final_header
          ON final_header.KVK_NO = history.KVK_NO
         AND final_header.State = N'OUTPUT_COMPLETE'
    )
    INSERT INTO #Calculated
    SELECT source.KVK_NO, source.GovernorID, source.GovernorName, source.KVKRank,
           source.T4T5Kills, source.KillTarget, source.KillTargetPercent,
           source.KillPoints, source.Deads, source.DeadTarget, source.DeadTargetPercent,
           source.Healed, combat.KPLoss, combat.TankingScore,
           source.Acclaim, source.DKP, source.DKPTarget, source.DKPTargetPercent,
           source.PreKvkPoints, source.PreKvkRank, source.HonorPoints, source.HonorRank,
           source.IsExempt, combat.IsEngaged
    FROM SourceRows AS source
    CROSS APPLY dbo.fn_KvkCombatMetrics
        (source.KillPoints, source.Healed, source.Deads, source.T4T5Kills) AS combat
    WHERE source.GovernorID > 0;

    CREATE TABLE #EngagedRanks
    (
        KVK_NO int NOT NULL,
        GovernorID bigint NOT NULL,
        KillPointsRank int NULL,
        DeadsRank int NULL,
        HealedRank int NULL,
        TankingRank int NULL,
        AcclaimRank int NULL,
        EngagedCohortCount int NOT NULL,
        TankingCohortCount int NOT NULL,
        PRIMARY KEY CLUSTERED (KVK_NO, GovernorID)
    );
    ;WITH Ranked AS
    (
        SELECT KVK_NO, GovernorID,
               CASE WHEN KillPoints > 0
                    THEN RANK() OVER
                        (PARTITION BY KVK_NO, CASE WHEN KillPoints > 0 THEN 0 ELSE 1 END
                         ORDER BY KillPoints DESC) END AS KillPointsRank,
               CASE WHEN Deads > 0
                    THEN RANK() OVER
                        (PARTITION BY KVK_NO, CASE WHEN Deads > 0 THEN 0 ELSE 1 END
                         ORDER BY Deads DESC) END AS DeadsRank,
               CASE WHEN IsEngaged = 1 AND Healed > 0
                    THEN RANK() OVER
                        (PARTITION BY KVK_NO,
                         CASE WHEN IsEngaged = 1 AND Healed > 0 THEN 0 ELSE 1 END
                         ORDER BY Healed ASC) END AS HealedRank,
               CASE WHEN IsEngaged = 1 AND TankingScore IS NOT NULL
                    THEN RANK() OVER
                        (PARTITION BY KVK_NO,
                         CASE WHEN IsEngaged = 1 AND TankingScore IS NOT NULL THEN 0 ELSE 1 END
                         ORDER BY TankingScore DESC) END AS TankingRank,
               CASE WHEN Acclaim > 0
                    THEN RANK() OVER
                        (PARTITION BY KVK_NO, CASE WHEN Acclaim > 0 THEN 0 ELSE 1 END
                         ORDER BY Acclaim DESC) END AS AcclaimRank,
               COUNT(CASE WHEN IsEngaged = 1 AND Healed > 0 THEN 1 END)
                   OVER (PARTITION BY KVK_NO) AS EngagedCohortCount,
               COUNT(CASE WHEN IsEngaged = 1 AND TankingScore IS NOT NULL THEN 1 END)
                   OVER (PARTITION BY KVK_NO) AS TankingCohortCount
        FROM #Calculated
    )
    INSERT INTO #EngagedRanks
    SELECT KVK_NO, GovernorID, KillPointsRank, DeadsRank, HealedRank, TankingRank,
           AcclaimRank, EngagedCohortCount, TankingCohortCount
    FROM Ranked;

    CREATE TABLE #HealedCoverage
    (
        KVK_NO int NOT NULL PRIMARY KEY
    );
    INSERT INTO #HealedCoverage (KVK_NO)
    SELECT calculated.KVK_NO
    FROM #Calculated AS calculated
    WHERE calculated.Healed > 0
    GROUP BY calculated.KVK_NO;

    CREATE TABLE #KvkIndexScores
    (
        KVK_NO int NOT NULL,
        GovernorID bigint NOT NULL,
        KvkScore decimal(36,8) NULL,
        PRIMARY KEY CLUSTERED (KVK_NO, GovernorID)
    );
    INSERT INTO #KvkIndexScores (KVK_NO, GovernorID, KvkScore)
    SELECT calculated.KVK_NO,
           calculated.GovernorID,
           CASE
               WHEN calculated.IsExempt = 1
                 OR calculated.T4T5Kills IS NULL
                 OR calculated.Deads IS NULL
                 OR calculated.Healed IS NULL
                   THEN NULL
               WHEN calculated.T4T5Kills = 0
                 OR calculated.Deads = 0
                 OR calculated.Healed = 0
                   THEN CONVERT(decimal(36,8), 0)
               WHEN calculated.KillTargetPercent IS NULL
                 OR calculated.DeadTargetPercent IS NULL
                 OR healed_coverage.KVK_NO IS NULL
                 OR calculated.TankingScore IS NULL
                   THEN NULL
               ELSE CONVERT(decimal(36,8),
                    CONVERT(decimal(31,8), calculated.KillTargetPercent)
                        * CONVERT(decimal(3,2), 0.60)
                  + CONVERT(decimal(31,8), calculated.DeadTargetPercent)
                        * CONVERT(decimal(3,2), 0.20)
                  + CONVERT(decimal(31,8), calculated.TankingScore)
                        * CONVERT(decimal(3,2), 0.20))
           END
    FROM #Calculated AS calculated
    JOIN #KvkIndexKvks AS index_kvk
      ON index_kvk.KVK_NO = calculated.KVK_NO
    LEFT JOIN #HealedCoverage AS healed_coverage
      ON healed_coverage.KVK_NO = calculated.KVK_NO;

    /* Result set 2: player final rows and canonical combat ranks. */
    SELECT calculated.KVK_NO, calculated.GovernorID, calculated.GovernorName,
           calculated.KVKRank, calculated.T4T5Kills, calculated.KillTarget,
           calculated.KillTargetPercent, calculated.KillPoints, calculated.Deads,
           calculated.DeadTarget, calculated.DeadTargetPercent, calculated.Healed,
           calculated.KPLoss, calculated.TankingScore, calculated.Acclaim,
           @PersonalCompletedKvkBestAcclaim AS PersonalCompletedKvkBestAcclaim,
           calculated.DKP, calculated.DKPTarget, calculated.DKPTargetPercent,
           calculated.PreKvkPoints, calculated.PreKvkRank,
           calculated.HonorPoints, calculated.HonorRank,
           calculated.IsExempt, calculated.IsEngaged,
           ranks.HealedRank, ranks.TankingRank, ranks.AcclaimRank,
           ranks.EngagedCohortCount, ranks.TankingCohortCount,
           final_header.FinalDataAtUtc, final_header.State AS FinalOutputState,
           final_header.FinalizationBasis,
           ranks.KillPointsRank, ranks.DeadsRank,
           CONVERT(bit, CASE WHEN healed_coverage.KVK_NO IS NOT NULL
               THEN 1 ELSE 0 END) AS HealedDataAvailable
    FROM #Calculated AS calculated
    JOIN #Candidates AS output_candidate
      ON output_candidate.KVK_NO = calculated.KVK_NO
    LEFT JOIN #EngagedRanks AS ranks
      ON ranks.KVK_NO = calculated.KVK_NO AND ranks.GovernorID = calculated.GovernorID
    LEFT JOIN dbo.KVKFinalReportHeader AS final_header
      ON final_header.KVK_NO = calculated.KVK_NO
    LEFT JOIN #HealedCoverage AS healed_coverage
      ON healed_coverage.KVK_NO = calculated.KVK_NO
    WHERE calculated.GovernorID = @GovernorID
    ORDER BY calculated.KVK_NO DESC;

    /* Result set 3: selected-governor uncapped KVK Index and kingdom rank. */
    ;WITH GovernorIndexes AS
    (
        SELECT scores.GovernorID,
               CONVERT(decimal(38,8), AVG(scores.KvkScore)) AS KvkIndexValue,
               COUNT(scores.KvkScore) AS ScoredKvkCount
        FROM #KvkIndexScores AS scores
        GROUP BY scores.GovernorID
        HAVING COUNT(scores.KvkScore) > 0
    ),
    RankedIndexes AS
    (
        SELECT indexes.GovernorID,
               indexes.KvkIndexValue,
               indexes.ScoredKvkCount,
               RANK() OVER (ORDER BY indexes.KvkIndexValue DESC) AS KvkIndexRank,
               COUNT(*) OVER () AS KvkIndexCohortCount
        FROM GovernorIndexes AS indexes
    )
    SELECT @GovernorID AS GovernorID,
           ranked.KvkIndexValue,
           ranked.KvkIndexRank,
           COALESCE(ranked.KvkIndexCohortCount, 0) AS KvkIndexCohortCount,
           COALESCE(ranked.ScoredKvkCount, 0) AS ScoredKvkCount,
           @KvkIndexCandidateCount AS CandidateKvkCount,
           CONVERT(varchar(16),
               CASE WHEN ranked.ScoredKvkCount IS NULL THEN 'NOT_RECORDED'
                    WHEN ranked.ScoredKvkCount = @KvkIndexCandidateCount THEN 'AVAILABLE'
                    ELSE 'PARTIAL' END) AS Availability
    FROM (VALUES (1)) AS seed(OneRow)
    LEFT JOIN RankedIndexes AS ranked
      ON ranked.GovernorID = @GovernorID;
END;
GO
