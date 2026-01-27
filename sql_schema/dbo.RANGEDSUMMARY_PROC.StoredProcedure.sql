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
        -- 1) Insert new raw rows into RANGED_ALL (only new scans)
        ------------------------------------------------------------
        INSERT INTO dbo.RANGED_ALL (GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL)
        SELECT k.GovernorID, k.GovernorName, k.RangedPoints, k.ScanDate, NULL, NULL
        FROM dbo.KingdomScanData4 k
        INNER JOIN #AffectedGovs a ON k.GovernorID = a.GovernorID
        WHERE k.ScanOrder > @LastProcessed;

        ------------------------------------------------------------
        -- 2) Update RANGED_LATEST for affected governors (upsert)
        ------------------------------------------------------------
        ;WITH LatestPerGov AS (
            SELECT GovernorID, GovernorName, PowerRank, RangedPoints,
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
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
        ;WITH Latest AS (
            SELECT GovernorID, GovernorName, PowerRank, RangedPoints,
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        ),
        FirstScan AS (
            SELECT GovernorID, RangedPoints AS FirstRanged
            FROM (
                SELECT GovernorID, RangedPoints,
                       ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS rn
                FROM dbo.KingdomScanData4 k
                INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            ) t WHERE rn = 1
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.RangedPoints AS LatestRanged,
                F.FirstRanged,
                (L.RangedPoints - F.FirstRanged) AS OverallRangedDelta,
                ISNULL(R12.R12,0) AS RangedDelta12Months,
                ISNULL(R6.R6,0)  AS RangedDelta6Months,
                ISNULL(R3.R3,0)  AS RangedDelta3Months
            FROM (SELECT GovernorID, GovernorName, PowerRank, RangedPoints FROM Latest WHERE rn=1) L
            LEFT JOIN FirstScan F ON L.GovernorID = F.GovernorID
            LEFT JOIN (SELECT GovernorID, RangedPointsDelta12Months AS R12 FROM dbo.RANGED_D12D) R12 ON L.GovernorID = R12.GovernorID
            LEFT JOIN (SELECT GovernorID, RangedPointsDelta6Months AS R6 FROM dbo.RANGED_D6D) R6 ON L.GovernorID = R6.GovernorID
            LEFT JOIN (SELECT GovernorID, RangedPointsDelta3Months AS R3 FROM dbo.RANGED_D3D) R3 ON L.GovernorID = R3.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.RANGEDSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                RangedPoints = S.LatestRanged,
                StartingRanged = S.FirstRanged,
                OverallRangedDelta = S.OverallRangedDelta,
                RangedDelta12Months = S.RangedDelta12Months,
                RangedDelta6Months = S.RangedDelta6Months,
                RangedDelta3Months = S.RangedDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.LatestRanged, S.FirstRanged, S.OverallRangedDelta, S.RangedDelta12Months, S.RangedDelta6Months, S.RangedDelta3Months);

        ------------------------------------------------------------
        -- 6) Refresh Top50/Top100/Kingdom-Average rows
        ------------------------------------------------------------
        DELETE FROM dbo.RANGEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.RANGEDSUMMARY
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG(RangedPoints), 0),
               ROUND(AVG(StartingRanged), 0),
               ROUND(AVG(OverallRangedDelta), 0),
               ROUND(AVG(RangedDelta12Months), 0),
               ROUND(AVG(RangedDelta6Months), 0),
               ROUND(AVG(RangedDelta3Months), 0)
        FROM dbo.RANGEDSUMMARY WHERE PowerRank <= 50;

        INSERT INTO dbo.RANGEDSUMMARY
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG(RangedPoints), 0),
               ROUND(AVG(StartingRanged), 0),
               ROUND(AVG(OverallRangedDelta), 0),
               ROUND(AVG(RangedDelta12Months), 0),
               ROUND(AVG(RangedDelta6Months), 0),
               ROUND(AVG(RangedDelta3Months), 0)
        FROM dbo.RANGEDSUMMARY WHERE PowerRank <= 100;

        INSERT INTO dbo.RANGEDSUMMARY
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG(RangedPoints), 0),
               ROUND(AVG(StartingRanged), 0),
               ROUND(AVG(OverallRangedDelta), 0),
               ROUND(AVG(RangedDelta12Months), 0),
               ROUND(AVG(RangedDelta6Months), 0),
               ROUND(AVG(RangedDelta3Months), 0)
        FROM dbo.RANGEDSUMMARY WHERE PowerRank <= 150;

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

