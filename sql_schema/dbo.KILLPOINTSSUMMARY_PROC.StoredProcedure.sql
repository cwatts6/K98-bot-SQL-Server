SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILLPOINTSSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[KILLPOINTSSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[KILLPOINTSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN

 SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'KillPoints';
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
        INTO #AffectedGovs_KP
        FROM dbo.KingdomScanData4
        WHERE ScanOrder > @LastProcessed
          AND GovernorID <> 0;

        CREATE CLUSTERED INDEX IX_AffectedGovs_KP_GovernorID ON #AffectedGovs_KP (GovernorID);

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs_KP)
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
        FROM dbo.KILLPOINTS_ALL k
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID;

        ;WITH RankedAll AS (
            SELECT k.GovernorID,
                   k.GovernorName,
                   k.KillPoints,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAscALL,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDescALL
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID
        )
        INSERT INTO dbo.KILLPOINTS_ALL (GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        DELETE k
        FROM dbo.KILLPOINTS_D12 k
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID;

        ;WITH RankedD12 AS (
            SELECT k.GovernorID,
                   k.KillPoints,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc12,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc12
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.KILLPOINTS_D12 (GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12
        FROM RankedD12;

        DELETE k
        FROM dbo.KILLPOINTS_D6 k
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID;

        ;WITH RankedD6 AS (
            SELECT k.GovernorID,
                   k.KillPoints,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc6,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc6
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.KILLPOINTS_D6 (GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6
        FROM RankedD6;

        DELETE k
        FROM dbo.KILLPOINTS_D3 k
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID;

        ;WITH RankedD3 AS (
            SELECT k.GovernorID,
                   k.KillPoints,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc3,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc3
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.KILLPOINTS_D3 (GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3
        FROM RankedD3;

        ;WITH LatestPerGov AS (
            SELECT GovernorID, GovernorName, PowerRank, KillPoints,
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID
        )
        MERGE dbo.KILLPOINTS_LATEST AS tgt
        USING (SELECT GovernorID, GovernorName, PowerRank, KillPoints FROM LatestPerGov WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, KillPoints = src.KillPoints
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, KillPoints)
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.KillPoints);

        DELETE d
        FROM dbo.KILLPOINTS_D3D d
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.KILLPOINTS_D3D (GovernorID, KillPointsDelta3Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.KillPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.KillPoints END)
        FROM dbo.KILLPOINTS_LATEST L
        LEFT JOIN dbo.KILLPOINTS_D3 D3 ON L.GovernorID = D3.GovernorID
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.KILLPOINTS_D6D d
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.KILLPOINTS_D6D (GovernorID, KillPointsDelta6Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.KillPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.KillPoints END)
        FROM dbo.KILLPOINTS_LATEST L
        LEFT JOIN dbo.KILLPOINTS_D6 D6 ON L.GovernorID = D6.GovernorID
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.KILLPOINTS_D12D d
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.KILLPOINTS_D12D (GovernorID, KillPointsDelta12Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.KillPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.KillPoints END)
        FROM dbo.KILLPOINTS_LATEST L
        LEFT JOIN dbo.KILLPOINTS_D12 D12 ON L.GovernorID = D12.GovernorID
        INNER JOIN #AffectedGovs_KP a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT GovernorID,
                   MAX(CASE WHEN RowAscALL = 1 THEN KillPoints END) AS StartingKillPoints,
                   MAX(CASE WHEN RowDescALL = 1 THEN KillPoints END) AS EndingKillPoints
            FROM dbo.KILLPOINTS_ALL k
            INNER JOIN #AffectedGovs_KP a ON a.GovernorID = k.GovernorID
            GROUP BY k.GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.KillPoints,
                F.StartingKillPoints,
                F.EndingKillPoints - F.StartingKillPoints AS OverallKillPointsDelta,
                ISNULL(D12D.KillPointsDelta12Months, 0) AS KillPointsDelta12Months,
                ISNULL(D6D.KillPointsDelta6Months, 0) AS KillPointsDelta6Months,
                ISNULL(D3D.KillPointsDelta3Months, 0) AS KillPointsDelta3Months
            FROM dbo.KILLPOINTS_LATEST L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.KILLPOINTS_D12D D12D ON L.GovernorID = D12D.GovernorID
            LEFT JOIN dbo.KILLPOINTS_D6D D6D ON L.GovernorID = D6D.GovernorID
            LEFT JOIN dbo.KILLPOINTS_D3D D3D ON L.GovernorID = D3D.GovernorID
            INNER JOIN #AffectedGovs_KP a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.KILLPOINTSSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                KillPoints = S.KillPoints,
                StartingKillPoints = S.StartingKillPoints,
                OverallKillPointsDelta = S.OverallKillPointsDelta,
                KillPointsDelta12Months = S.KillPointsDelta12Months,
                KillPointsDelta6Months = S.KillPointsDelta6Months,
                KillPointsDelta3Months = S.KillPointsDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.KillPoints, S.StartingKillPoints, S.OverallKillPointsDelta, S.KillPointsDelta12Months, S.KillPointsDelta6Months, S.KillPointsDelta3Months);

        DELETE FROM dbo.KILLPOINTSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.KILLPOINTSSUMMARY
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG(KillPoints), 0),
               ROUND(AVG(StartingKillPoints), 0),
               ROUND(AVG(OverallKillPointsDelta), 0),
               ROUND(AVG(KillPointsDelta12Months), 0),
               ROUND(AVG(KillPointsDelta6Months), 0),
               ROUND(AVG(KillPointsDelta3Months), 0)
        FROM dbo.KILLPOINTSSUMMARY WHERE PowerRank <= 50;

        INSERT INTO dbo.KILLPOINTSSUMMARY
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG(KillPoints), 0),
               ROUND(AVG(StartingKillPoints), 0),
               ROUND(AVG(OverallKillPointsDelta), 0),
               ROUND(AVG(KillPointsDelta12Months), 0),
               ROUND(AVG(KillPointsDelta6Months), 0),
               ROUND(AVG(KillPointsDelta3Months), 0)
        FROM dbo.KILLPOINTSSUMMARY WHERE PowerRank <= 100;

        INSERT INTO dbo.KILLPOINTSSUMMARY
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG(KillPoints), 0),
               ROUND(AVG(StartingKillPoints), 0),
               ROUND(AVG(OverallKillPointsDelta), 0),
               ROUND(AVG(KillPointsDelta12Months), 0),
               ROUND(AVG(KillPointsDelta6Months), 0),
               ROUND(AVG(KillPointsDelta3Months), 0)
        FROM dbo.KILLPOINTSSUMMARY WHERE PowerRank <= 150;

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
        RAISERROR('KILLPOINTSSUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;
