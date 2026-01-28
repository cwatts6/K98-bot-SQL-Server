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

    SELECT @LastProcessed = LastScanOrder FROM dbo.SUMMARY_PROC_STATE WHERE MetricName = @MetricName;
    IF @LastProcessed IS NULL SET @LastProcessed = 0;

    SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0) FROM dbo.KingdomScanData4;
    IF @MaxScan <= @LastProcessed
    BEGIN
        -- nothing to do
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        -- Affected governors (new scans)
        SELECT DISTINCT GovernorID
        INTO #AffectedGovs
        FROM dbo.KingdomScanData4
        WHERE ScanOrder > @LastProcessed AND GovernorID <> 0;

        CREATE CLUSTERED INDEX IX_AffectedGovs_GovernorID ON #AffectedGovs (GovernorID);

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime) VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

            COMMIT;
            RETURN;
        END

        DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
        DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
        DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
        DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

        ------------------------------------------------------------
        -- 1) RANGED_ALL: Delete and rebuild for affected governors
        ------------------------------------------------------------
        DELETE ra
        FROM dbo.RANGED_ALL ra
        INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID;

        ;WITH RankedAll AS (
            SELECT k.GovernorID,
                   k.GovernorName,
                   k.RangedPoints,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAscALL,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDescALL
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        INSERT INTO dbo.RANGED_ALL (GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        ------------------------------------------------------------
        -- 2) Update RANGED_LATEST for affected governors (upsert)
        ------------------------------------------------------------
        ;WITH LatestPerGov AS (
            SELECT k.GovernorID, k.GovernorName, k.PowerRank, k.RangedPoints,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        MERGE dbo.RANGED_LATEST AS tgt
        USING (SELECT GovernorID, GovernorName, PowerRank, RangedPoints FROM LatestPerGov WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, RangedPoints = src.RangedPoints
        WHEN NOT MATCHED THEN INSERT (GovernorID, GovernorName, PowerRank, RangedPoints) VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.RangedPoints);

        ------------------------------------------------------------
        -- 3) Recompute windowed helper tables (D3/D6/D12) only for affected governors
        ------------------------------------------------------------
        -- D3
        DELETE d
        FROM dbo.RANGED_D3 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD3 AS (
            SELECT k.GovernorID, k.RangedPoints, k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc3,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc3
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.RANGED_D3 (GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3 FROM RankedD3;

        -- D6
        DELETE d
        FROM dbo.RANGED_D6 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD6 AS (
            SELECT k.GovernorID, k.RangedPoints, k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc6,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc6
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.RANGED_D6 (GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6 FROM RankedD6;

        -- D12
        DELETE d
        FROM dbo.RANGED_D12 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD12 AS (
            SELECT k.GovernorID, k.RangedPoints, k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc12,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc12
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.RANGED_D12 (GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12 FROM RankedD12;

        ------------------------------------------------------------
        -- 4) Compute delta metrics (3/6/12 months)
        ------------------------------------------------------------
        DELETE d
        FROM dbo.RANGED_D3D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.RANGED_D3D (GovernorID, RangedPointsDelta3Months)
        SELECT 
            L.GovernorID,
            MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.RangedPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.RangedPoints END)
        FROM dbo.RANGED_LATEST L
        LEFT JOIN dbo.RANGED_D3 D3 ON L.GovernorID = D3.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.RANGED_D6D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.RANGED_D6D (GovernorID, RangedPointsDelta6Months)
        SELECT 
            L.GovernorID,
            MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.RangedPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.RangedPoints END)
        FROM dbo.RANGED_LATEST L
        LEFT JOIN dbo.RANGED_D6 D6 ON L.GovernorID = D6.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.RANGED_D12D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.RANGED_D12D (GovernorID, RangedPointsDelta12Months)
        SELECT 
            L.GovernorID,
            MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.RangedPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.RangedPoints END)
        FROM dbo.RANGED_LATEST L
        LEFT JOIN dbo.RANGED_D12 D12 ON L.GovernorID = D12.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ------------------------------------------------------------
        -- 5) Upsert RANGEDSUMMARY rows for affected governors
        ------------------------------------------------------------
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

        ------------------------------------------------------------
        -- 6) Refresh Top50/Top100/Kingdom-Average rows
        ------------------------------------------------------------
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

        ------------------------------------------------------------
        -- 7) Persist new LastScanOrder into control table
        ------------------------------------------------------------
        MERGE dbo.SUMMARY_PROC_STATE AS T
        USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
        ON T.MetricName = S.MetricName
        WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
        WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime) VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR('RANGEDSUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END

