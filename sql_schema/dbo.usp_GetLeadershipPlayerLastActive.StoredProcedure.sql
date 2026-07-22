SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerLastActive
    @GovernorID bigint,
    @HistoryDays smallint = 720,
    @NowUtc datetime2(0) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @GovernorID IS NULL OR @GovernorID <= 0
        THROW 51551, 'Leadership Last Active requires a positive Governor ID.', 1;
    IF @HistoryDays IS NULL OR @HistoryDays < 1 OR @HistoryDays > 720
        THROW 51552, 'Leadership Last Active history is bounded to 1 through 720 days.', 1;

    DECLARE @EffectiveNowUtc datetime2(0) = COALESCE(@NowUtc, SYSUTCDATETIME());
    DECLARE @EffectiveUtcDate date = CONVERT(date, @EffectiveNowUtc);
    DECLARE @HistoryStartDate date = DATEADD(DAY, 1 - @HistoryDays, @EffectiveUtcDate);

    CREATE TABLE #CompleteScans
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        ScanDateUtc datetime2(0) NOT NULL,
        AsOfDate date NOT NULL
    );

    INSERT INTO #CompleteScans (ScanOrder, ScanDateUtc, AsOfDate)
    SELECT TRY_CONVERT(bigint, source.SCANORDER),
           MAX(TRY_CONVERT(datetime2(0), source.ScanDate)),
           MAX(source.AsOfDate)
    FROM dbo.KingdomScanData4 AS source
    WHERE source.AsOfDate BETWEEN @HistoryStartDate AND @EffectiveUtcDate
      AND TRY_CONVERT(bigint, source.SCANORDER) IS NOT NULL
      AND TRY_CONVERT(datetime2(0), source.ScanDate) IS NOT NULL
    GROUP BY TRY_CONVERT(bigint, source.SCANORDER);

    CREATE TABLE #Observations
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        ScanDateUtc datetime2(0) NOT NULL,
        AsOfDate date NOT NULL,
        PowerValue decimal(38,0) NULL,
        HealedValue decimal(38,0) NULL,
        RssGatheredValue decimal(38,0) NULL,
        RssAssistedValue decimal(38,0) NULL,
        HelpsValue decimal(38,0) NULL,
        BuildingValue decimal(38,0) NULL,
        TechValue decimal(38,0) NULL
    );

    ;WITH RankedGovernorRows AS
    (
        SELECT scans.ScanOrder,
               scans.ScanDateUtc,
               scans.AsOfDate,
               TRY_CONVERT(decimal(38,0), source.Power) AS PowerValue,
               TRY_CONVERT(decimal(38,0), source.HealedTroops) AS HealedValue,
               TRY_CONVERT(decimal(38,0), source.RSS_Gathered) AS RssGatheredValue,
               TRY_CONVERT(decimal(38,0), source.RSSAssistance) AS RssAssistedValue,
               TRY_CONVERT(decimal(38,0), source.Helps) AS HelpsValue,
               ROW_NUMBER() OVER
               (
                   PARTITION BY scans.ScanOrder
                   ORDER BY source.ScanDate DESC, source.SCAN_UNO DESC
               ) AS RowNumber
        FROM #CompleteScans AS scans
        JOIN dbo.KingdomScanData4 AS source
          ON TRY_CONVERT(bigint, source.SCANORDER) = scans.ScanOrder
         AND TRY_CONVERT(bigint, source.GovernorID) = @GovernorID
    )
    INSERT INTO #Observations
        (ScanOrder, ScanDateUtc, AsOfDate, PowerValue, HealedValue,
         RssGatheredValue, RssAssistedValue, HelpsValue, BuildingValue, TechValue)
    SELECT selected.ScanOrder,
           selected.ScanDateUtc,
           selected.AsOfDate,
           selected.PowerValue,
           selected.HealedValue,
           selected.RssGatheredValue,
           selected.RssAssistedValue,
           selected.HelpsValue,
           TRY_CONVERT(decimal(38,0), activity_row.BuildingTotal),
           TRY_CONVERT(decimal(38,0), activity_row.TechDonationTotal)
    FROM RankedGovernorRows AS selected
    OUTER APPLY
    (
        SELECT TOP (1) header.SnapshotId
        FROM dbo.AllianceActivitySnapshotHeader AS header
        WHERE header.CompletionState = N'COMPLETE'
          AND header.SnapshotTsUtc <= selected.ScanDateUtc
        ORDER BY header.SnapshotTsUtc DESC, header.SnapshotId DESC
    ) AS activity_header
    LEFT JOIN dbo.AllianceActivitySnapshotRow AS activity_row
      ON activity_row.SnapshotId = activity_header.SnapshotId
     AND activity_row.GovernorID = @GovernorID
    WHERE selected.RowNumber = 1;

    CREATE TABLE #Comparisons
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        ScanDateUtc datetime2(0) NOT NULL,
        AsOfDate date NOT NULL,
        PreviousScanOrder bigint NULL,
        PreviousScanDateUtc datetime2(0) NULL,
        PowerValue decimal(38,0) NULL,
        PreviousPowerValue decimal(38,0) NULL,
        HealedValue decimal(38,0) NULL,
        PreviousHealedValue decimal(38,0) NULL,
        RssGatheredValue decimal(38,0) NULL,
        PreviousRssGatheredValue decimal(38,0) NULL,
        RssAssistedValue decimal(38,0) NULL,
        PreviousRssAssistedValue decimal(38,0) NULL,
        HelpsValue decimal(38,0) NULL,
        PreviousHelpsValue decimal(38,0) NULL,
        BuildingValue decimal(38,0) NULL,
        PreviousBuildingValue decimal(38,0) NULL,
        TechValue decimal(38,0) NULL,
        PreviousTechValue decimal(38,0) NULL
    );

    ;WITH WithPrevious AS
    (
        SELECT observations.*,
               LAG(ScanOrder) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousScanOrder,
               LAG(ScanDateUtc) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousScanDateUtc,
               LAG(PowerValue) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousPowerValue,
               LAG(HealedValue) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousHealedValue,
               LAG(RssGatheredValue) OVER (ORDER BY ScanDateUtc, ScanOrder)
                   AS PreviousRssGatheredValue,
               LAG(RssAssistedValue) OVER (ORDER BY ScanDateUtc, ScanOrder)
                   AS PreviousRssAssistedValue,
               LAG(HelpsValue) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousHelpsValue,
               LAG(BuildingValue) OVER (ORDER BY ScanDateUtc, ScanOrder)
                   AS PreviousBuildingValue,
               LAG(TechValue) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousTechValue
        FROM #Observations AS observations
    )
    INSERT INTO #Comparisons
        (ScanOrder, ScanDateUtc, AsOfDate, PreviousScanOrder, PreviousScanDateUtc,
         PowerValue, PreviousPowerValue, HealedValue, PreviousHealedValue,
         RssGatheredValue, PreviousRssGatheredValue,
         RssAssistedValue, PreviousRssAssistedValue,
         HelpsValue, PreviousHelpsValue, BuildingValue, PreviousBuildingValue,
         TechValue, PreviousTechValue)
    SELECT ScanOrder, ScanDateUtc, AsOfDate, PreviousScanOrder, PreviousScanDateUtc,
           PowerValue, PreviousPowerValue, HealedValue, PreviousHealedValue,
           RssGatheredValue, PreviousRssGatheredValue,
           RssAssistedValue, PreviousRssAssistedValue,
           HelpsValue, PreviousHelpsValue, BuildingValue, PreviousBuildingValue,
           TechValue, PreviousTechValue
    FROM WithPrevious;

    DECLARE @LastActiveDate date = NULL;
    DECLARE @QualifyingSourceCode nvarchar(32) = NULL;
    DECLARE @QualifyingScanOrder bigint = NULL;

    ;WITH Qualified AS
    (
        SELECT comparison.ScanOrder,
               comparison.ScanDateUtc,
               source_choice.SourceCode,
               source_choice.SourceOrder
        FROM #Comparisons AS comparison
        OUTER APPLY
        (
            SELECT COUNT_BIG(*) AS CompletedReportCount,
                   SUM(CONVERT(bigint, COALESCE(rally_row.TotalRallies, 0))) AS RallyTotal
            FROM dbo.RallyDailySnapshotHeader AS rally_header
            LEFT JOIN dbo.cur_RallyDaily AS rally_row
              ON rally_row.AsOfDate = rally_header.AsOfDate
             AND rally_row.GovernorID = @GovernorID
            WHERE comparison.PreviousScanDateUtc IS NOT NULL
              AND rally_header.AsOfDate > CONVERT(date, comparison.PreviousScanDateUtc)
              AND rally_header.AsOfDate <= CONVERT(date, comparison.ScanDateUtc)
        ) AS rally
        CROSS APPLY
        (
            SELECT TOP (1) candidates.SourceCode, candidates.SourceOrder
            FROM
            (
                VALUES
                    (N'POWER', 1, CASE WHEN comparison.PowerValue > comparison.PreviousPowerValue
                                      THEN 1 ELSE 0 END),
                    (N'HEALED', 2, CASE WHEN comparison.HealedValue > comparison.PreviousHealedValue
                                       THEN 1 ELSE 0 END),
                    (N'RSS_GATHERED', 3,
                        CASE WHEN comparison.RssGatheredValue
                                      > comparison.PreviousRssGatheredValue THEN 1 ELSE 0 END),
                    (N'RSS_ASSISTED', 4,
                        CASE WHEN comparison.RssAssistedValue
                                      > comparison.PreviousRssAssistedValue THEN 1 ELSE 0 END),
                    (N'HELPS', 5, CASE WHEN comparison.HelpsValue > comparison.PreviousHelpsValue
                                      THEN 1 ELSE 0 END),
                    (N'TECH_DONATIONS', 6,
                        CASE WHEN comparison.TechValue > comparison.PreviousTechValue
                             THEN 1 ELSE 0 END),
                    (N'BUILDING_MINUTES', 7,
                        CASE WHEN comparison.BuildingValue > comparison.PreviousBuildingValue
                             THEN 1 ELSE 0 END),
                    (N'FORT_RALLIES', 8,
                        CASE WHEN rally.CompletedReportCount > 0 AND rally.RallyTotal > 0
                             THEN 1 ELSE 0 END)
            ) AS candidates(SourceCode, SourceOrder, Qualified)
            WHERE candidates.Qualified = 1
            ORDER BY candidates.SourceOrder
        ) AS source_choice
        WHERE comparison.PreviousScanOrder IS NOT NULL
    )
    SELECT TOP (1)
           @LastActiveDate = CONVERT(date, ScanDateUtc),
           @QualifyingSourceCode = SourceCode,
           @QualifyingScanOrder = ScanOrder
    FROM Qualified
    ORDER BY ScanDateUtc DESC, ScanOrder DESC, SourceOrder;

    SELECT @GovernorID AS GovernorID,
           @EffectiveUtcDate AS EffectiveUtcDate,
           @HistoryStartDate AS HistoryStartDate,
           @EffectiveUtcDate AS HistoryEndDate,
           @LastActiveDate AS LastActiveDate,
           CONVERT(nvarchar(16),
               CASE WHEN @LastActiveDate IS NULL THEN N'NOT_RECORDED'
                    WHEN @LastActiveDate < DATEADD(DAY, -30, @EffectiveUtcDate) THEN N'INACTIVE'
                    ELSE N'ACTIVE' END) AS ActivityState,
           @QualifyingSourceCode AS QualifyingSourceCode,
           @QualifyingScanOrder AS QualifyingScanOrder,
           (SELECT COUNT(*) FROM #Comparisons WHERE PreviousScanOrder IS NOT NULL)
               AS ComparedCompleteScanCount,
           @HistoryDays AS HistoryDays;
END;
