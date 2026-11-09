SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DEADSSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[DEADSSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[DEADSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N'Deads';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.Deads
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_DALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[DEADS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_DALL (GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_D12(
	[GovernorID] [bigint] NOT NULL,
	[DEADS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_D12 (GovernorID, Deads, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, Deads, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_D6(
	[GovernorID] [bigint] NOT NULL,
	[DEADS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_D6 (GovernorID, Deads, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, Deads, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_D3(
	[GovernorID] [bigint] NOT NULL,
	[DEADS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_D3 (GovernorID, Deads, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, Deads, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.Deads
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, Deads = src.Deads
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.Deads);

    DELETE d
    FROM dbo.D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D3D (GovernorID, DeadsDelta3Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.Deads END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.Deads END))
    FROM dbo.LATEST L
    LEFT JOIN #P021_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D6D (GovernorID, DeadsDelta6Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.Deads END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.Deads END))
    FROM dbo.LATEST L
    LEFT JOIN #P021_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D12D (GovernorID, DeadsDelta12Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.Deads END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.Deads END))
    FROM dbo.LATEST L
    LEFT JOIN #P021_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT d.GovernorID,
               MAX(CASE WHEN d.RowAscALL = 1 THEN d.Deads END) AS StartingDeads,
               MAX(CASE WHEN d.RowDescALL = 1 THEN d.Deads END) AS EndingDeads
        FROM #P021_DALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
        GROUP BY d.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.Deads,
            F.StartingDeads,
            CONVERT(decimal(38,0), F.EndingDeads) - CONVERT(decimal(38,0), F.StartingDeads) AS OverallDeadsDelta,
            ISNULL(D12D.DeadsDelta12Months, 0) AS DeadsDelta12Months,
            ISNULL(D6D.DeadsDelta6Months, 0) AS DeadsDelta6Months,
            ISNULL(D3D.DeadsDelta3Months, 0) AS DeadsDelta3Months
        FROM dbo.LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.D12D D12D ON L.GovernorID = D12D.GovernorID
        LEFT JOIN dbo.D6D D6D ON L.GovernorID = D6D.GovernorID
        LEFT JOIN dbo.D3D D3D ON L.GovernorID = D3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.DEADSSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            Deads = S.Deads,
            StartingDeads = S.StartingDeads,
            OverallDeadsDelta = S.OverallDeadsDelta,
            DeadsDelta12Months = S.DeadsDelta12Months,
            DeadsDelta6Months = S.DeadsDelta6Months,
            DeadsDelta3Months = S.DeadsDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.Deads, S.StartingDeads, S.OverallDeadsDelta, S.DeadsDelta12Months, S.DeadsDelta6Months, S.DeadsDelta3Months);

    DELETE FROM dbo.DEADSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(CONVERT(decimal(38,6), D.Deads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.StartingDeads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.OverallDeadsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta3Months)), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 50
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(CONVERT(decimal(38,6), D.Deads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.StartingDeads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.OverallDeadsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta3Months)), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 100
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(CONVERT(decimal(38,6), D.Deads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.StartingDeads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.OverallDeadsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta3Months)), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 150
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N'DEADSSUMMARY';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
