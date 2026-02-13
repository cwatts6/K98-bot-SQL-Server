SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[POWERSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[POWERSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[POWERSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'Power';
    DECLARE @LastProcessed FLOAT = 0;
    DECLARE @MaxScan FLOAT = 0;

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

    BEGIN TRANSACTION;
    BEGIN TRY
        SELECT DISTINCT GovernorID
        INTO #AffectedGovs
        FROM dbo.KingdomScanData4
        WHERE ScanOrder > @LastProcessed
          AND GovernorID <> 0;

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

		SELECT KS4.GovernorID,
               ks4.GovernorName,
               ks4.PowerRank,
               ks4.ScanOrder,
               ks4.ScanDate,
               ks4.[POWER]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
		CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        DELETE pa
        FROM dbo.PALL pa
        INNER JOIN #AffectedGovs a ON a.GovernorID = pa.GovernorID;

        ;WITH RankedAll AS (
            SELECT g.GovernorID,
                   g.GovernorName,
                   g.[POWER],
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAscALL,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDescALL
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
        )
        INSERT INTO dbo.PALL (GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        DELETE p12
        FROM dbo.P12 p12
        INNER JOIN #AffectedGovs a ON a.GovernorID = p12.GovernorID;

        ;WITH RankedP12 AS (
            SELECT g.GovernorID,
                   g.[POWER],
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc12,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc12
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.P12 (GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12
        FROM RankedP12;

        DELETE p6
        FROM dbo.P6 p6
        INNER JOIN #AffectedGovs a ON a.GovernorID = p6.GovernorID;

        ;WITH RankedP6 AS (
            SELECT g.GovernorID,
                   g.[POWER],
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc6,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc6
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.P6 (GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6
        FROM RankedP6;

        DELETE p3
        FROM dbo.P3 p3
        INNER JOIN #AffectedGovs a ON a.GovernorID = p3.GovernorID;

        ;WITH RankedP3 AS (
            SELECT g.GovernorID,
                   g.[POWER],
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc3,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc3
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.P3 (GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3
        FROM RankedP3;

        ;WITH LatestScanOrder AS (
            SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
            FROM #GovScan g
            GROUP BY g.GovernorID
        )
        MERGE dbo.LATEST_POWER AS tgt
        USING (
            SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[POWER]
            FROM #GovScan g
            INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
        ) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, [POWER] = src.[POWER]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, [POWER])
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[POWER]);

        DELETE p3d
        FROM dbo.P3D p3d
        INNER JOIN #AffectedGovs a ON a.GovernorID = p3d.GovernorID;
        INSERT INTO dbo.P3D (GovernorID, POWERDelta3Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN P3.RowDesc3 = 1 THEN P3.[POWER] END) - MAX(CASE WHEN P3.RowAsc3 = 1 THEN P3.[POWER] END)
        FROM dbo.LATEST_POWER L
        LEFT JOIN dbo.P3 P3 ON L.GovernorID = P3.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE p6d
        FROM dbo.P6D p6d
        INNER JOIN #AffectedGovs a ON a.GovernorID = p6d.GovernorID;
        INSERT INTO dbo.P6D (GovernorID, POWERDelta6Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN P6.RowDesc6 = 1 THEN P6.[POWER] END) - MAX(CASE WHEN P6.RowAsc6 = 1 THEN P6.[POWER] END)
        FROM dbo.LATEST_POWER L
        LEFT JOIN dbo.P6 P6 ON L.GovernorID = P6.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE p12d
        FROM dbo.P12D p12d
        INNER JOIN #AffectedGovs a ON a.GovernorID = p12d.GovernorID;
        INSERT INTO dbo.P12D (GovernorID, POWERDelta12Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN P12.RowDesc12 = 1 THEN P12.[POWER] END) - MAX(CASE WHEN P12.RowAsc12 = 1 THEN P12.[POWER] END)
        FROM dbo.LATEST_POWER L
        LEFT JOIN dbo.P12 P12 ON L.GovernorID = P12.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT pa.GovernorID,
                   MAX(CASE WHEN pa.RowAscALL = 1 THEN pa.[POWER] END) AS StartingPOWER,
                   MAX(CASE WHEN pa.RowDescALL = 1 THEN pa.[POWER] END) AS EndingPOWER
            FROM dbo.PALL pa
            INNER JOIN #AffectedGovs a ON a.GovernorID = pa.GovernorID
            GROUP BY pa.GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.[POWER],
                F.StartingPOWER,
                F.EndingPOWER - F.StartingPOWER AS OverallPOWERDelta,
                ISNULL(P12D.POWERDelta12Months, 0) AS POWERDelta12Months,
                ISNULL(P6D.POWERDelta6Months, 0) AS POWERDelta6Months,
                ISNULL(P3D.POWERDelta3Months, 0) AS POWERDelta3Months
            FROM dbo.LATEST_POWER L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.P12D P12D ON L.GovernorID = P12D.GovernorID
            LEFT JOIN dbo.P6D P6D ON L.GovernorID = P6D.GovernorID
            LEFT JOIN dbo.P3D P3D ON L.GovernorID = P3D.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.POWERSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                [POWER] = S.[POWER],
                StartingPOWER = S.StartingPOWER,
                OverallPOWERDelta = S.OverallPOWERDelta,
                POWERDelta12Months = S.POWERDelta12Months,
                POWERDelta6Months = S.POWERDelta6Months,
                POWERDelta3Months = S.POWERDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, [POWER], StartingPOWER, OverallPOWERDelta, POWERDelta12Months, POWERDelta6Months, POWERDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.[POWER], S.StartingPOWER, S.OverallPOWERDelta, S.POWERDelta12Months, S.POWERDelta6Months, S.POWERDelta3Months);

        DELETE FROM dbo.POWERSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPOWER, OverallPOWERDelta, POWERDelta12Months, POWERDelta6Months, POWERDelta3Months)
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG(P.[POWER]), 0),
               ROUND(AVG(P.StartingPOWER), 0),
               ROUND(AVG(P.OverallPOWERDelta), 0),
               ROUND(AVG(P.POWERDelta12Months), 0),
               ROUND(AVG(P.POWERDelta6Months), 0),
               ROUND(AVG(P.POWERDelta3Months), 0)
        FROM dbo.POWERSUMMARY AS P 
        WHERE P.PowerRank <= 50
          AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPOWER, OverallPOWERDelta, POWERDelta12Months, POWERDelta6Months, POWERDelta3Months)
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG(P.[POWER]), 0),
               ROUND(AVG(P.StartingPOWER), 0),
               ROUND(AVG(P.OverallPOWERDelta), 0),
               ROUND(AVG(P.POWERDelta12Months), 0),
               ROUND(AVG(P.POWERDelta6Months), 0),
               ROUND(AVG(P.POWERDelta3Months), 0)
        FROM dbo.POWERSUMMARY AS P 
        WHERE P.PowerRank <= 100
          AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPOWER, OverallPOWERDelta, POWERDelta12Months, POWERDelta6Months, POWERDelta3Months)
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG(P.[POWER]), 0),
               ROUND(AVG(P.StartingPOWER), 0),
               ROUND(AVG(P.OverallPOWERDelta), 0),
               ROUND(AVG(P.POWERDelta12Months), 0),
               ROUND(AVG(P.POWERDelta6Months), 0),
               ROUND(AVG(P.POWERDelta3Months), 0)
        FROM dbo.POWERSUMMARY AS P 
        WHERE P.PowerRank <= 150
          AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

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
        RAISERROR('POWERSUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;
