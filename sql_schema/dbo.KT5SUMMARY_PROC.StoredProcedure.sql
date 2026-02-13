SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KT5SUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[KT5SUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[KT5SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
  
SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'T5Kills';
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

		SELECT ks4.GovernorID,
               ks4.GovernorName,
               ks4.PowerRank,
               ks4.ScanOrder,
               ks4.ScanDate,
               ks4.[T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
		CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        DELETE k5a
        FROM dbo.K5ALL k5a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k5a.GovernorID;

        ;WITH RankedAll AS (
            SELECT g.GovernorID,
                   g.GovernorName,
                   g.[T5_KILLS],
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAscALL,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDescALL
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
        )
        INSERT INTO dbo.K5ALL (GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        DELETE k512
        FROM dbo.K512 k512
        INNER JOIN #AffectedGovs a ON a.GovernorID = k512.GovernorID;

        ;WITH RankedK12 AS (
            SELECT g.GovernorID,
                   g.[T5_KILLS],
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc12,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc12
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.K512 (GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12
        FROM RankedK12;

        DELETE k56
        FROM dbo.K56 k56
        INNER JOIN #AffectedGovs a ON a.GovernorID = k56.GovernorID;

        ;WITH RankedK6 AS (
            SELECT g.GovernorID,
                   g.[T5_KILLS],
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc6,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc6
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.K56 (GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6
        FROM RankedK6;

        DELETE k53
        FROM dbo.K53 k53
        INNER JOIN #AffectedGovs a ON a.GovernorID = k53.GovernorID;

        ;WITH RankedK3 AS (
            SELECT g.GovernorID,
                   g.[T5_KILLS],
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc3,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc3
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.K53 (GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3
        FROM RankedK3;

        ;WITH LatestScanOrder AS (
            SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
            FROM #GovScan g
            GROUP BY g.GovernorID
        )
        MERGE dbo.LATEST_T5_KILLS AS tgt
        USING (
            SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T5_KILLS]
            FROM #GovScan g
            INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
        ) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T5_KILLS] = src.[T5_KILLS]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS])
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T5_KILLS]);

        DELETE k53d
        FROM dbo.K53D k53d
        INNER JOIN #AffectedGovs a ON a.GovernorID = k53d.GovernorID;
        INSERT INTO dbo.K53D (GovernorID, [T5_KILLSDelta3Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K53.RowDesc3 = 1 THEN K53.[T5_KILLS] END) - MAX(CASE WHEN K53.RowAsc3 = 1 THEN K53.[T5_KILLS] END)
        FROM dbo.LATEST_T5_KILLS L
        LEFT JOIN dbo.K53 K53 ON L.GovernorID = K53.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE k56d
        FROM dbo.K56D k56d
        INNER JOIN #AffectedGovs a ON a.GovernorID = k56d.GovernorID;
        INSERT INTO dbo.K56D (GovernorID, [T5_KILLSDelta6Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K56.RowDesc6 = 1 THEN K56.[T5_KILLS] END) - MAX(CASE WHEN K56.RowAsc6 = 1 THEN K56.[T5_KILLS] END)
        FROM dbo.LATEST_T5_KILLS L
        LEFT JOIN dbo.K56 K56 ON L.GovernorID = K56.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE k512d
        FROM dbo.K512D k512d
        INNER JOIN #AffectedGovs a ON a.GovernorID = k512d.GovernorID;
        INSERT INTO dbo.K512D (GovernorID, [T5_KILLSDelta12Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K512.RowDesc12 = 1 THEN K512.[T5_KILLS] END) - MAX(CASE WHEN K512.RowAsc12 = 1 THEN K512.[T5_KILLS] END)
        FROM dbo.LATEST_T5_KILLS L
        LEFT JOIN dbo.K512 K512 ON L.GovernorID = K512.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT k5a.GovernorID,
                   MAX(CASE WHEN k5a.RowAscALL = 1 THEN k5a.[T5_KILLS] END) AS StartingKills,
                   MAX(CASE WHEN k5a.RowDescALL = 1 THEN k5a.[T5_KILLS] END) AS EndingKills
            FROM dbo.K5ALL k5a
            INNER JOIN #AffectedGovs a ON a.GovernorID = k5a.GovernorID
            GROUP BY k5a.GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.POWERRank,
                L.[T5_KILLS],
                F.StartingKills,
                F.EndingKills - F.StartingKills AS OverallKillsDelta,
                ISNULL(K512D.[T5_KILLSDelta12Months], 0) AS [T5_KILLSDelta12Months],
                ISNULL(K56D.[T5_KILLSDelta6Months], 0) AS [T5_KILLSDelta6Months],
                ISNULL(K53D.[T5_KILLSDelta3Months], 0) AS [T5_KILLSDelta3Months]
            FROM dbo.LATEST_T5_KILLS L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.K512D K512D ON L.GovernorID = K512D.GovernorID
            LEFT JOIN dbo.K56D K56D ON L.GovernorID = K56D.GovernorID
            LEFT JOIN dbo.K53D K53D ON L.GovernorID = K53D.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.KILL5SUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                POWERRank = S.POWERRank,
                [T5_KILLS] = S.[T5_KILLS],
                [StartingT5_KILLS] = S.StartingKills,
                [OverallT5_KILLSDelta] = S.OverallKillsDelta,
                [T5_KILLSDelta12Months] = S.[T5_KILLSDelta12Months],
                [T5_KILLSDelta6Months] = S.[T5_KILLSDelta6Months],
                [T5_KILLSDelta3Months] = S.[T5_KILLSDelta3Months]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
            VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T5_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T5_KILLSDelta12Months], S.[T5_KILLSDelta6Months], S.[T5_KILLSDelta3Months]);

        DELETE FROM dbo.KILL5SUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG(K5.[T5_KILLS]), 0),
               ROUND(AVG(K5.[StartingT5_KILLS]), 0),
               ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
        FROM dbo.KILL5SUMMARY AS K5 
        WHERE K5.POWERRank <= 50
          AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG(K5.[T5_KILLS]), 0),
               ROUND(AVG(K5.[StartingT5_KILLS]), 0),
               ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
        FROM dbo.KILL5SUMMARY AS K5 
        WHERE K5.POWERRank <= 100
          AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG(K5.[T5_KILLS]), 0),
               ROUND(AVG(K5.[StartingT5_KILLS]), 0),
               ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
               ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
        FROM dbo.KILL5SUMMARY AS K5 
        WHERE K5.POWERRank <= 150
          AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

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
        RAISERROR('KT5SUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;

