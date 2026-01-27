SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KT4SUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[KT4SUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[KT4SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
   
SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'T4Kills';
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
        FROM dbo.K4ALL k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedAll AS (
            SELECT k.GovernorID,
                   k.GovernorName,
                   k.[T4_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAscALL,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDescALL
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        INSERT INTO dbo.K4ALL (GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        DELETE k
        FROM dbo.K412 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK12 AS (
            SELECT k.GovernorID,
                   k.[T4_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc12,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc12
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.K412 (GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12
        FROM RankedK12;

        DELETE k
        FROM dbo.K46 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK6 AS (
            SELECT k.GovernorID,
                   k.[T4_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc6,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc6
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.K46 (GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6
        FROM RankedK6;

        DELETE k
        FROM dbo.K43 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK3 AS (
            SELECT k.GovernorID,
                   k.[T4_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc3,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc3
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.K43 (GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3
        FROM RankedK3;

        ;WITH LatestPerGov AS (
            SELECT GovernorID, GovernorName, PowerRank, [T4_KILLS],
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        MERGE dbo.LATEST_T4_KILLS AS tgt
        USING (SELECT GovernorID, GovernorName, PowerRank, [T4_KILLS] FROM LatestPerGov WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4_KILLS] = src.[T4_KILLS]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, POWERRank, [T4_KILLS])
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4_KILLS]);

        DELETE k
        FROM dbo.K43D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K43D (GovernorID, [T4_KILLSDelta3Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K43.RowDesc3 = 1 THEN K43.[T4_KILLS] END) - MAX(CASE WHEN K43.RowAsc3 = 1 THEN K43.[T4_KILLS] END)
        FROM dbo.LATEST_T4_KILLS L
        LEFT JOIN dbo.K43 K43 ON L.GovernorID = K43.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE k
        FROM dbo.K46D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K46D (GovernorID, [T4_KILLSDelta6Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K46.RowDesc6 = 1 THEN K46.[T4_KILLS] END) - MAX(CASE WHEN K46.RowAsc6 = 1 THEN K46.[T4_KILLS] END)
        FROM dbo.LATEST_T4_KILLS L
        LEFT JOIN dbo.K46 K46 ON L.GovernorID = K46.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE k
        FROM dbo.K412D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K412D (GovernorID, [T4_KILLSDelta12Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K412.RowDesc12 = 1 THEN K412.[T4_KILLS] END) - MAX(CASE WHEN K412.RowAsc12 = 1 THEN K412.[T4_KILLS] END)
        FROM dbo.LATEST_T4_KILLS L
        LEFT JOIN dbo.K412 K412 ON L.GovernorID = K412.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT GovernorID,
                   MAX(CASE WHEN RowAscALL = 1 THEN [T4_KILLS] END) AS StartingKills,
                   MAX(CASE WHEN RowDescALL = 1 THEN [T4_KILLS] END) AS EndingKills
            FROM dbo.K4ALL k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            GROUP BY GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.POWERRank,
                L.[T4_KILLS],
                F.StartingKills,
                F.EndingKills - F.StartingKills AS OverallKillsDelta,
                ISNULL(K412D.[T4_KILLSDelta12Months], 0) AS [T4_KILLSDelta12Months],
                ISNULL(K46D.[T4_KILLSDelta6Months], 0) AS [T4_KILLSDelta6Months],
                ISNULL(K43D.[T4_KILLSDelta3Months], 0) AS [T4_KILLSDelta3Months]
            FROM dbo.LATEST_T4_KILLS L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.K412D K412D ON L.GovernorID = K412D.GovernorID
            LEFT JOIN dbo.K46D K46D ON L.GovernorID = K46D.GovernorID
            LEFT JOIN dbo.K43D K43D ON L.GovernorID = K43D.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.KILL4SUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                POWERRank = S.POWERRank,
                [T4_KILLS] = S.[T4_KILLS],
                [StartingT4_KILLS] = S.StartingKills,
                [OverallT4_KILLSDelta] = S.OverallKillsDelta,
                [T4_KILLSDelta12Months] = S.[T4_KILLSDelta12Months],
                [T4_KILLSDelta6Months] = S.[T4_KILLSDelta6Months],
                [T4_KILLSDelta3Months] = S.[T4_KILLSDelta3Months]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
            VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T4_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T4_KILLSDelta12Months], S.[T4_KILLSDelta6Months], S.[T4_KILLSDelta3Months]);

        DELETE FROM dbo.KILL4SUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.KILL4SUMMARY
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG([T4_KILLS]), 0),
               ROUND(AVG([StartingT4_KILLS]), 0),
               ROUND(AVG([OverallT4_KILLSDelta]), 0),
               ROUND(AVG([T4_KILLSDelta12Months]), 0),
               ROUND(AVG([T4_KILLSDelta6Months]), 0),
               ROUND(AVG([T4_KILLSDelta3Months]), 0)
        FROM dbo.KILL4SUMMARY WHERE POWERRank <= 50;

        INSERT INTO dbo.KILL4SUMMARY
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG([T4_KILLS]), 0),
               ROUND(AVG([StartingT4_KILLS]), 0),
               ROUND(AVG([OverallT4_KILLSDelta]), 0),
               ROUND(AVG([T4_KILLSDelta12Months]), 0),
               ROUND(AVG([T4_KILLSDelta6Months]), 0),
               ROUND(AVG([T4_KILLSDelta3Months]), 0)
        FROM dbo.KILL4SUMMARY WHERE POWERRank <= 100;

        INSERT INTO dbo.KILL4SUMMARY
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG([T4_KILLS]), 0),
               ROUND(AVG([StartingT4_KILLS]), 0),
               ROUND(AVG([OverallT4_KILLSDelta]), 0),
               ROUND(AVG([T4_KILLSDelta12Months]), 0),
               ROUND(AVG([T4_KILLSDelta6Months]), 0),
               ROUND(AVG([T4_KILLSDelta3Months]), 0)
        FROM dbo.KILL4SUMMARY WHERE POWERRank <= 150;

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
        RAISERROR('KT4SUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;

