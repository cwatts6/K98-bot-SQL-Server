SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RANGEDSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[RANGEDSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[RANGEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'RangedPoints';
    DECLARE @LastProcessed FLOAT = 0;
    DECLARE @MaxScan FLOAT = 0;

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
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT conv.GovernorID
        FROM dbo.KingdomScanData4 ks4
        CROSS APPLY (SELECT TRY_CONVERT(BIGINT, ks4.GovernorID) AS GovernorID) conv
        WHERE ks4.ScanOrder > @LastProcessed
          AND conv.GovernorID IS NOT NULL
          AND conv.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            conv.GovernorID AS GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.RangedPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        CROSS APPLY (SELECT TRY_CONVERT(BIGINT, ks4.GovernorID) AS GovernorID) conv
        INNER JOIN #AffectedGovs a ON a.GovernorID = conv.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE ra
    FROM dbo.RANGED_ALL ra
    INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.RANGED_ALL (GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.RANGED_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.RangedPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, RangedPoints = src.RangedPoints
    WHEN NOT MATCHED THEN INSERT (GovernorID, GovernorName, PowerRank, RangedPoints)
    VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.RangedPoints);

    DELETE d
    FROM dbo.RANGED_D3 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.RANGED_D3 (GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3;

    DELETE d
    FROM dbo.RANGED_D6 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.RANGED_D6 (GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6;

    DELETE d
    FROM dbo.RANGED_D12 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.RANGED_D12 (GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12;

    DELETE d
    FROM dbo.RANGED_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D3D (GovernorID, RangedPointsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.RangedPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D6D (GovernorID, RangedPointsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.RangedPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D12D (GovernorID, RangedPointsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.RangedPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ra.GovernorID,
               MAX(CASE WHEN ra.RowAscALL = 1 THEN ra.RangedPoints END) AS StartingRanged,
               MAX(CASE WHEN ra.RowDescALL = 1 THEN ra.RangedPoints END) AS EndingRanged
        FROM dbo.RANGED_ALL ra
        INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID
        GROUP BY ra.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.RangedPoints,
            F.StartingRanged,
            F.EndingRanged - F.StartingRanged AS OverallRangedDelta,
            ISNULL(R12D.RangedPointsDelta12Months, 0) AS RangedDelta12Months,
            ISNULL(R6D.RangedPointsDelta6Months, 0) AS RangedDelta6Months,
            ISNULL(R3D.RangedPointsDelta3Months, 0) AS RangedDelta3Months
        FROM dbo.RANGED_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.RANGED_D12D R12D ON L.GovernorID = R12D.GovernorID
        LEFT JOIN dbo.RANGED_D6D R6D ON L.GovernorID = R6D.GovernorID
        LEFT JOIN dbo.RANGED_D3D R3D ON L.GovernorID = R3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.RANGEDSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            RangedPoints = S.RangedPoints,
            StartingRanged = S.StartingRanged,
            OverallRangedDelta = S.OverallRangedDelta,
            RangedDelta12Months = S.RangedDelta12Months,
            RangedDelta6Months = S.RangedDelta6Months,
            RangedDelta3Months = S.RangedDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.RangedPoints, S.StartingRanged, S.OverallRangedDelta, S.RangedDelta12Months, S.RangedDelta6Months, S.RangedDelta3Months);

    DELETE FROM dbo.RANGEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 50
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 100
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 150
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END

