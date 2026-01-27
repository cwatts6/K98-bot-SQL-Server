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

        DELETE k
        FROM dbo.K5ALL k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedAll AS (
            SELECT k.GovernorID,
                   k.GovernorName,
                   k.[T5_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAscALL,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDescALL
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        INSERT INTO dbo.K5ALL (GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        DELETE k
        FROM dbo.K512 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK12 AS (
            SELECT k.GovernorID,
                   k.[T5_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc12,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc12
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.K512 (GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12
        FROM RankedK12;

        DELETE k
        FROM dbo.K56 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK6 AS (
            SELECT k.GovernorID,
                   k.[T5_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc6,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc6
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.K56 (GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6
        FROM RankedK6;

        DELETE k
        FROM dbo.K53 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK3 AS (
            SELECT k.GovernorID,
                   k.[T5_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc3,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc3
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.K53 (GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3
        FROM RankedK3;

        ;WITH LatestPerGov AS (
            SELECT GovernorID, GovernorName, PowerRank, [T5_KILLS],
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        MERGE dbo.LATEST_T5_KILLS AS tgt
        USING (SELECT GovernorID, GovernorName, PowerRank, [T5_KILLS] FROM LatestPerGov WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T5_KILLS] = src.[T5_KILLS]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS])
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T5_KILLS]);

        DELETE k
        FROM dbo.K53D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K53D (GovernorID, [T5_KILLSDelta3Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K53.RowDesc3 = 1 THEN K53.[T5_KILLS] END) - MAX(CASE WHEN K53.RowAsc3 = 1 THEN K53.[T5_KILLS] END)
        FROM dbo.LATEST_T5_KILLS L
        LEFT JOIN dbo.K53 K53 ON L.GovernorID = K53.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE k
        FROM dbo.K56D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K56D (GovernorID, [T5_KILLSDelta6Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K56.RowDesc6 = 1 THEN K56.[T5_KILLS] END) - MAX(CASE WHEN K56.RowAsc6 = 1 THEN K56.[T5_KILLS] END)
        FROM dbo.LATEST_T5_KILLS L
        LEFT JOIN dbo.K56 K56 ON L.GovernorID = K56.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE k
        FROM dbo.K512D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K512D (GovernorID, [T5_KILLSDelta12Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K512.RowDesc12 = 1 THEN K512.[T5_KILLS] END) - MAX(CASE WHEN K512.RowAsc12 = 1 THEN K512.[T5_KILLS] END)
        FROM dbo.LATEST_T5_KILLS L
        LEFT JOIN dbo.K512 K512 ON L.GovernorID = K512.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT GovernorID,
                   MAX(CASE WHEN RowAscALL = 1 THEN [T5_KILLS] END) AS StartingKills,
                   MAX(CASE WHEN RowDescALL = 1 THEN [T5_KILLS] END) AS EndingKills
            FROM dbo.K5ALL k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            GROUP BY GovernorID
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

        INSERT INTO dbo.KILL5SUMMARY
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG([T5_KILLS]), 0),
               ROUND(AVG([StartingT5_KILLS]), 0),
               ROUND(AVG([OverallT5_KILLSDelta]), 0),
               ROUND(AVG([T5_KILLSDelta12Months]), 0),
               ROUND(AVG([T5_KILLSDelta6Months]), 0),
               ROUND(AVG([T5_KILLSDelta3Months]), 0)
        FROM dbo.KILL5SUMMARY WHERE POWERRank <= 50;

        INSERT INTO dbo.KILL5SUMMARY
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG([T5_KILLS]), 0),
               ROUND(AVG([StartingT5_KILLS]), 0),
               ROUND(AVG([OverallT5_KILLSDelta]), 0),
               ROUND(AVG([T5_KILLSDelta12Months]), 0),
               ROUND(AVG([T5_KILLSDelta6Months]), 0),
               ROUND(AVG([T5_KILLSDelta3Months]), 0)
        FROM dbo.KILL5SUMMARY WHERE POWERRank <= 100;

        INSERT INTO dbo.KILL5SUMMARY
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG([T5_KILLS]), 0),
               ROUND(AVG([StartingT5_KILLS]), 0),
               ROUND(AVG([OverallT5_KILLSDelta]), 0),
               ROUND(AVG([T5_KILLSDelta12Months]), 0),
               ROUND(AVG([T5_KILLSDelta6Months]), 0),
               ROUND(AVG([T5_KILLSDelta3Months]), 0)
        FROM dbo.KILL5SUMMARY WHERE POWERRank <= 150;

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

