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
            ks4.[T4&T5_KILLS]
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

    DELETE ka
    FROM dbo.KALL ka
    INNER JOIN #AffectedGovs a ON a.GovernorID = ka.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.KALL (GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE k12
    FROM dbo.K12 k12
    INNER JOIN #AffectedGovs a ON a.GovernorID = k12.GovernorID;

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.K12 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12;

    DELETE k6
    FROM dbo.K6 k6
    INNER JOIN #AffectedGovs a ON a.GovernorID = k6.GovernorID;

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.K6 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6;

    DELETE k3
    FROM dbo.K3 k3
    INNER JOIN #AffectedGovs a ON a.GovernorID = k3.GovernorID;

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.K3 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.[LATEST_T4&T5_KILLS] AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T4&T5_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4&T5_KILLS] = src.[T4&T5_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4&T5_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4&T5_KILLS]);

    DELETE kd3
    FROM dbo.K3D kd3
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd3.GovernorID;

    INSERT INTO dbo.K3D (GovernorID, [T4&T5_KILLSDelta3Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K3.RowDesc3 = 1 THEN K3.[T4&T5_KILLS] END) - MAX(CASE WHEN K3.RowAsc3 = 1 THEN K3.[T4&T5_KILLS] END)
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN dbo.K3 K3 ON L.GovernorID = K3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE kd6
    FROM dbo.K6D kd6
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd6.GovernorID;

    INSERT INTO dbo.K6D (GovernorID, [T4&T5_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K6.RowDesc6 = 1 THEN K6.[T4&T5_KILLS] END) - MAX(CASE WHEN K6.RowAsc6 = 1 THEN K6.[T4&T5_KILLS] END)
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN dbo.K6 K6 ON L.GovernorID = K6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE kd12
    FROM dbo.K12D kd12
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd12.GovernorID;

    INSERT INTO dbo.K12D (GovernorID, [T4&T5_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K12.RowDesc12 = 1 THEN K12.[T4&T5_KILLS] END) - MAX(CASE WHEN K12.RowAsc12 = 1 THEN K12.[T4&T5_KILLS] END)
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN dbo.K12 K12 ON L.GovernorID = K12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ka.GovernorID,
               MAX(CASE WHEN ka.RowAscALL = 1 THEN ka.[T4&T5_KILLS] END) AS StartingKills,
               MAX(CASE WHEN ka.RowDescALL = 1 THEN ka.[T4&T5_KILLS] END) AS EndingKills
        FROM dbo.KALL ka
        INNER JOIN #AffectedGovs a ON a.GovernorID = ka.GovernorID
        GROUP BY ka.GovernorID
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

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(KS.[T4&T5_KILLS]), 0),
           ROUND(AVG(KS.[StartingT4&T5_KILLS]), 0),
           ROUND(AVG(KS.[OverallT4&T5_KILLSDelta]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta12Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta6Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta3Months]), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 50
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(KS.[T4&T5_KILLS]), 0),
           ROUND(AVG(KS.[StartingT4&T5_KILLS]), 0),
           ROUND(AVG(KS.[OverallT4&T5_KILLSDelta]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta12Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta6Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta3Months]), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 100
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(KS.[T4&T5_KILLS]), 0),
           ROUND(AVG(KS.[StartingT4&T5_KILLS]), 0),
           ROUND(AVG(KS.[OverallT4&T5_KILLSDelta]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta12Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta6Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta3Months]), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 150
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END

