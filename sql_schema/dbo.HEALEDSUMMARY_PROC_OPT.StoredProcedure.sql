SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HEALEDSUMMARY_PROC_OPT]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[HEALEDSUMMARY_PROC_OPT] AS' 
END
ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC_OPT]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'HealedTroops';
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
        ------------------------------------------------------------
        -- Affected governors (typed as BIGINT to avoid implicit conversions)
        ------------------------------------------------------------
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
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime) VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

            COMMIT;
            RETURN;
        END

        DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
        DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
        DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
        DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

        ------------------------------------------------------------
        -- #GovScan with explicit types (avoid implicit conversions)
        ------------------------------------------------------------
        CREATE TABLE #GovScan
        (
            GovernorID   BIGINT       NOT NULL,
            GovernorName NVARCHAR(400) NULL,
            PowerRank    INT           NULL,
            ScanOrder    FLOAT         NOT NULL,
            ScanDate     DATETIME      NULL,
            HealedTroops BIGINT        NULL
        );

        INSERT INTO #GovScan (GovernorID, GovernorName, PowerRank, ScanOrder, ScanDate, HealedTroops)
        SELECT
            conv.GovernorID,
            CONVERT(NVARCHAR(400), ks4.GovernorName) AS GovernorName,
            TRY_CONVERT(INT, ks4.PowerRank) AS PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        FROM dbo.KingdomScanData4 ks4
        CROSS APPLY (SELECT TRY_CONVERT(BIGINT, ks4.GovernorID) AS GovernorID) conv
        INNER JOIN #AffectedGovs a ON a.GovernorID = conv.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        ------------------------------------------------------------
        -- 1) HEALED_ALL: Delete and rebuild for affected governors
        ------------------------------------------------------------
        DELETE d
        FROM dbo.HEALED_ALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedAll AS (
            SELECT
                g.GovernorID,
                g.GovernorName,
                g.HealedTroops,
                g.ScanDate,
                ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
                ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
            FROM #GovScan g
        )
        INSERT INTO dbo.HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        ------------------------------------------------------------
        -- Remaining sections unchanged (D12/D6/D3/etc.)
        ------------------------------------------------------------
        DELETE d
        FROM dbo.HEALED_D12 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD12 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc12,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc12
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12
        FROM RankedD12;

        DELETE d
        FROM dbo.HEALED_D6 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD6 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc6,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc6
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6
        FROM RankedD6;

        DELETE d
        FROM dbo.HEALED_D3 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD3 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc3,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc3
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3
        FROM RankedD3;

        ;WITH LatestScanOrder AS (
            SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
            FROM #GovScan g
            GROUP BY g.GovernorID
        )
        MERGE dbo.HEALED_LATEST AS tgt
        USING (
            SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.HealedTroops
            FROM #GovScan g
            INNER JOIN LatestScanOrder l
                ON l.GovernorID = g.GovernorID
               AND l.LatestScanOrder = g.ScanOrder
        ) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, HealedTroops = src.HealedTroops
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, HealedTroops)
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.HealedTroops);

        DELETE d
        FROM dbo.HEALED_D3D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D3D (GovernorID, HealedTroopsDelta3Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.HealedTroops END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D3 D3 ON L.GovernorID = D3.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.HEALED_D6D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D6D (GovernorID, HealedTroopsDelta6Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.HealedTroops END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D6 D6 ON L.GovernorID = D6.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.HEALED_D12D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D12D (GovernorID, HealedTroopsDelta12Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.HealedTroops END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D12 D12 ON L.GovernorID = D12.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT d.GovernorID,
                   MAX(CASE WHEN d.RowAscALL = 1 THEN d.HealedTroops END) AS StartingHealed,
                   MAX(CASE WHEN d.RowDescALL = 1 THEN d.HealedTroops END) AS EndingHealed
            FROM dbo.HEALED_ALL d
            INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
            GROUP BY d.GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.HealedTroops,
                F.StartingHealed,
                F.EndingHealed - F.StartingHealed AS OverallHealedDelta,
                ISNULL(D12D.HealedTroopsDelta12Months, 0) AS HealedDelta12Months,
                ISNULL(D6D.HealedTroopsDelta6Months, 0) AS HealedDelta6Months,
                ISNULL(D3D.HealedTroopsDelta3Months, 0) AS HealedDelta3Months
            FROM dbo.HEALED_LATEST L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.HEALED_D12D D12D ON L.GovernorID = D12D.GovernorID
            LEFT JOIN dbo.HEALED_D6D D6D ON L.GovernorID = D6D.GovernorID
            LEFT JOIN dbo.HEALED_D3D D3D ON L.GovernorID = D3D.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.HEALEDSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                HealedTroops = S.HealedTroops,
                StartingHealed = S.StartingHealed,
                OverallHealedDelta = S.OverallHealedDelta,
                HealedDelta12Months = S.HealedDelta12Months,
                HealedDelta6Months = S.HealedDelta6Months,
                HealedDelta3Months = S.HealedDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.HealedTroops, S.StartingHealed, S.OverallHealedDelta, S.HealedDelta12Months, S.HealedDelta6Months, S.HealedDelta3Months);

        DELETE FROM dbo.HEALEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG(H.HealedTroops), 0),
               ROUND(AVG(H.StartingHealed), 0),
               ROUND(AVG(H.OverallHealedDelta), 0),
               ROUND(AVG(H.HealedDelta12Months), 0),
               ROUND(AVG(H.HealedDelta6Months), 0),
               ROUND(AVG(H.HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 50
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG(H.HealedTroops), 0),
               ROUND(AVG(H.StartingHealed), 0),
               ROUND(AVG(H.OverallHealedDelta), 0),
               ROUND(AVG(H.HealedDelta12Months), 0),
               ROUND(AVG(H.HealedDelta6Months), 0),
               ROUND(AVG(H.HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 100
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG(H.HealedTroops), 0),
               ROUND(AVG(H.StartingHealed), 0),
               ROUND(AVG(H.OverallHealedDelta), 0),
               ROUND(AVG(H.HealedDelta12Months), 0),
               ROUND(AVG(H.HealedDelta6Months), 0),
               ROUND(AVG(H.HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 150
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

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
        RAISERROR('HEALEDSUMMARY_PROC_OPT failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END

