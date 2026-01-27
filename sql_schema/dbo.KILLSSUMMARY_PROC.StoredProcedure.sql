SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILLSSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[KILLSSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[KILLSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
 SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'T4T5Kills';
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
        FROM dbo.KALL k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedAll AS (
            SELECT k.GovernorID,
                   k.GovernorName,
                   k.[T4&T5_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAscALL,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDescALL
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        INSERT INTO dbo.KALL (GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        DELETE k
        FROM dbo.K12 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK12 AS (
            SELECT k.GovernorID,
                   k.[T4&T5_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc12,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc12
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.K12 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12
        FROM RankedK12;

        DELETE k
        FROM dbo.K6 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK6 AS (
            SELECT k.GovernorID,
                   k.[T4&T5_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc6,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc6
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.K6 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6
        FROM RankedK6;

        DELETE k
        FROM dbo.K3 k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;

        ;WITH RankedK3 AS (
            SELECT k.GovernorID,
                   k.[T4&T5_KILLS],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc3,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc3
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.K3 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3
        FROM RankedK3;

        ;WITH LatestPerGov AS (
            SELECT GovernorID, GovernorName, PowerRank, [T4&T5_KILLS],
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        MERGE dbo.[LATEST_T4&T5_KILLS] AS tgt
        USING (SELECT GovernorID, GovernorName, PowerRank, [T4&T5_KILLS] FROM LatestPerGov WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4&T5_KILLS] = src.[T4&T5_KILLS]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, POWERRank, [T4&T5_KILLS])
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4&T5_KILLS]);

        DELETE k
        FROM dbo.K3D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K3D (GovernorID, [T4&T5_KILLSDelta3Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K3.RowDesc3 = 1 THEN K3.[T4&T5_KILLS] END) - MAX(CASE WHEN K3.RowAsc3 = 1 THEN K3.[T4&T5_KILLS] END)
        FROM dbo.[LATEST_T4&T5_KILLS] L
        LEFT JOIN dbo.K3 K3 ON L.GovernorID = K3.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE k
        FROM dbo.K6D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K6D (GovernorID, [T4&T5_KILLSDelta6Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K6.RowDesc6 = 1 THEN K6.[T4&T5_KILLS] END) - MAX(CASE WHEN K6.RowAsc6 = 1 THEN K6.[T4&T5_KILLS] END)
        FROM dbo.[LATEST_T4&T5_KILLS] L
        LEFT JOIN dbo.K6 K6 ON L.GovernorID = K6.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE k
        FROM dbo.K12D k
        INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID;
        INSERT INTO dbo.K12D (GovernorID, [T4&T5_KILLSDelta12Months])
        SELECT L.GovernorID,
               MAX(CASE WHEN K12.RowDesc12 = 1 THEN K12.[T4&T5_KILLS] END) - MAX(CASE WHEN K12.RowAsc12 = 1 THEN K12.[T4&T5_KILLS] END)
        FROM dbo.[LATEST_T4&T5_KILLS] L
        LEFT JOIN dbo.K12 K12 ON L.GovernorID = K12.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT GovernorID,
                   MAX(CASE WHEN RowAscALL = 1 THEN [T4&T5_KILLS] END) AS StartingKills,
                   MAX(CASE WHEN RowDescALL = 1 THEN [T4&T5_KILLS] END) AS EndingKills
            FROM dbo.KALL k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            GROUP BY GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.POWERRank,
                L.[T4&T5_KILLS],
                F.StartingKills,
                F.EndingKills - F.StartingKills AS OverallKillsDelta,
                ISNULL(K12D.[T4&T5_KILLSDelta12Months], 0) AS [T4&T5_KILLSDelta12Months],
                ISNULL(K6D.[T4&T5_KILLSDelta6Months], 0) AS [T4&T5_KILLSDelta6Months],
                ISNULL(K3D.[T4&T5_KILLSDelta3Months], 0) AS [T4&T5_KILLSDelta3Months]
            FROM dbo.[LATEST_T4&T5_KILLS] L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.K12D K12D ON L.GovernorID = K12D.GovernorID
            LEFT JOIN dbo.K6D K6D ON L.GovernorID = K6D.GovernorID
            LEFT JOIN dbo.K3D K3D ON L.GovernorID = K3D.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.KILLSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                POWERRank = S.POWERRank,
                [T4&T5_KILLS] = S.[T4&T5_KILLS],
                [StartingT4&T5_KILLS] = S.StartingKills,
                [OverallT4&T5_KILLSDelta] = S.OverallKillsDelta,
                [T4&T5_KILLSDelta12Months] = S.[T4&T5_KILLSDelta12Months],
                [T4&T5_KILLSDelta6Months] = S.[T4&T5_KILLSDelta6Months],
                [T4&T5_KILLSDelta3Months] = S.[T4&T5_KILLSDelta3Months]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, POWERRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
            VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T4&T5_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T4&T5_KILLSDelta12Months], S.[T4&T5_KILLSDelta6Months], S.[T4&T5_KILLSDelta3Months]);

        DELETE FROM dbo.KILLSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.KILLSUMMARY
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG([T4&T5_KILLS]), 0),
               ROUND(AVG([StartingT4&T5_KILLS]), 0),
               ROUND(AVG([OverallT4&T5_KILLSDelta]), 0),
               ROUND(AVG([T4&T5_KILLSDelta12Months]), 0),
               ROUND(AVG([T4&T5_KILLSDelta6Months]), 0),
               ROUND(AVG([T4&T5_KILLSDelta3Months]), 0)
        FROM dbo.KILLSUMMARY WHERE POWERRank <= 50;

        INSERT INTO dbo.KILLSUMMARY
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG([T4&T5_KILLS]), 0),
               ROUND(AVG([StartingT4&T5_KILLS]), 0),
               ROUND(AVG([OverallT4&T5_KILLSDelta]), 0),
               ROUND(AVG([T4&T5_KILLSDelta12Months]), 0),
               ROUND(AVG([T4&T5_KILLSDelta6Months]), 0),
               ROUND(AVG([T4&T5_KILLSDelta3Months]), 0)
        FROM dbo.KILLSUMMARY WHERE POWERRank <= 100;

        INSERT INTO dbo.KILLSUMMARY
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG([T4&T5_KILLS]), 0),
               ROUND(AVG([StartingT4&T5_KILLS]), 0),
               ROUND(AVG([OverallT4&T5_KILLSDelta]), 0),
               ROUND(AVG([T4&T5_KILLSDelta12Months]), 0),
               ROUND(AVG([T4&T5_KILLSDelta6Months]), 0),
               ROUND(AVG([T4&T5_KILLSDelta3Months]), 0)
        FROM dbo.KILLSUMMARY WHERE POWERRank <= 150;

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
        RAISERROR('KILLSSUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;

