SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HEALEDSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[HEALEDSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'HealedTroops';
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
            -- update last processed and exit
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
               ks4.HealedTroops
        INTO #GovScan
        FROM dbo.KingdomScanData4 kS4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
		CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        ------------------------------------------------------------
        -- 1) HEALED_ALL: Delete and rebuild for affected governors
        ------------------------------------------------------------
        DELETE d
        FROM dbo.HEALED_ALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedAll AS (
            SELECT g.GovernorID,
                   g.GovernorName,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAscALL,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDescALL
            FROM #GovScan g
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
        )
        INSERT INTO dbo.HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        ------------------------------------------------------------
        -- 2) HEALED_D12: Delete and rebuild for affected governors
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
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12
        FROM RankedD12;

        ------------------------------------------------------------
        -- 3) HEALED_D6: Delete and rebuild for affected governors
        ------------------------------------------------------------
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
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6
        FROM RankedD6;

        ------------------------------------------------------------
        -- 4) HEALED_D3: Delete and rebuild for affected governors
        ------------------------------------------------------------
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
            INNER JOIN #AffectedGovs a ON a.GovernorID = g.GovernorID
            WHERE g.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3
        FROM RankedD3;

        ------------------------------------------------------------
        -- 5) HEALED_LATEST: Upsert latest record for affected governors
        ------------------------------------------------------------
        ;WITH LatestScanOrder AS (
            SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
            FROM #GovScan g
			GROUP BY g.GovernorID
        )
        MERGE dbo.HEALED_LATEST AS tgt
        USING (
            SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.HealedTroops
            FROM #GovScan g
            INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
        ) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, HealedTroops = src.HealedTroops
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, HealedTroops)
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.HealedTroops);

        ------------------------------------------------------------
        -- 6) HEALED_D3D: Compute 3-month deltas for affected governors
        ------------------------------------------------------------
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

        ------------------------------------------------------------
        -- 7) HEALED_D6D: Compute 6-month deltas for affected governors
        ------------------------------------------------------------
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

        ------------------------------------------------------------
        -- 8) HEALED_D12D: Compute 12-month deltas for affected governors
        ------------------------------------------------------------
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

        ------------------------------------------------------------
        -- 9) HEALEDSUMMARY: Upsert final summary for affected governors
        ------------------------------------------------------------
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

        ------------------------------------------------------------
        -- 10) Refresh Top50/Top100/Kingdom-Average summary rows
        ------------------------------------------------------------
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

        ------------------------------------------------------------
        -- 11) Persist new LastScanOrder into control table
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
        RAISERROR('HEALEDSUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END

