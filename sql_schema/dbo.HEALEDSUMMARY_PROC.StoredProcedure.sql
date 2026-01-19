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

        ------------------------------------------------------------
        -- 1) Insert new raw rows into HEALED_ALL (only new scans)
        ------------------------------------------------------------
        INSERT INTO dbo.HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
        SELECT k.GovernorID, k.GovernorName, k.HealedTroops, k.ScanDate, NULL, NULL
        FROM dbo.KingdomScanData4 k
        INNER JOIN #AffectedGovs a ON k.GovernorID = a.GovernorID
        WHERE k.ScanOrder > @LastProcessed;

        ------------------------------------------------------------
        -- 2) Update HEALED_LATEST for affected governors (upsert)
        ------------------------------------------------------------
        ;WITH LatestPerGov AS (
            SELECT GovernorID, GovernorName, PowerRank, HealedTroops,
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            WHERE k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        MERGE dbo.HEALED_LATEST AS tgt
        USING (SELECT GovernorID, GovernorName, PowerRank, HealedTroops FROM LatestPerGov WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, HealedTroops = src.HealedTroops
        WHEN NOT MATCHED THEN INSERT (GovernorID, GovernorName, PowerRank, HealedTroops) VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.HealedTroops);

        ------------------------------------------------------------
        -- 3) Recompute windowed helper tables (D3/D6/D12) only for affected governors
        --    We delete existing rows for affected governors and recompute from KingdomScanData4.
        ------------------------------------------------------------
        -- D3
        DELETE FROM dbo.HEALED_D3 WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);

        ;WITH RankedD3 AS (
            SELECT k.GovernorID, k.HealedTroops, k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc3,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc3
            FROM dbo.KingdomScanData4 k
            WHERE k.ScanDate >= DATEADD(MONTH, -3, SYSUTCDATETIME())
              AND k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        INSERT INTO dbo.HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3 FROM RankedD3;

        -- D6
        DELETE FROM dbo.HEALED_D6 WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);

        ;WITH RankedD6 AS (
            SELECT k.GovernorID, k.HealedTroops, k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc6,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc6
            FROM dbo.KingdomScanData4 k
            WHERE k.ScanDate >= DATEADD(MONTH, -6, SYSUTCDATETIME())
              AND k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        INSERT INTO dbo.HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6 FROM RankedD6;

        -- D12
        DELETE FROM dbo.HEALED_D12 WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);

        ;WITH RankedD12 AS (
            SELECT k.GovernorID, k.HealedTroops, k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc12,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc12
            FROM dbo.KingdomScanData4 k
            WHERE k.ScanDate >= DATEADD(MONTH, -12, SYSUTCDATETIME())
              AND k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        INSERT INTO dbo.HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12 FROM RankedD12;

        ------------------------------------------------------------
        -- 4) Compute delta metrics (3/6/12 months) for affected governors
        --    Delete previous delta rows for affected governors and recompute.
        ------------------------------------------------------------
        DELETE FROM dbo.HEALED_D3D WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);
        INSERT INTO dbo.HEALED_D3D (GovernorID, HealedTroopsDelta3Months)
        SELECT 
            L.GovernorID,
            MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.HealedTroops END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D3 D3 ON L.GovernorID = D3.GovernorID
        WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        GROUP BY L.GovernorID;

        DELETE FROM dbo.HEALED_D6D WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);
        INSERT INTO dbo.HEALED_D6D (GovernorID, HealedTroopsDelta6Months)
        SELECT 
            L.GovernorID,
            MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.HealedTroops END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D6 D6 ON L.GovernorID = D6.GovernorID
        WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        GROUP BY L.GovernorID;

        DELETE FROM dbo.HEALED_D12D WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);
        INSERT INTO dbo.HEALED_D12D (GovernorID, HealedTroopsDelta12Months)
        SELECT 
            L.GovernorID,
            MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.HealedTroops END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D12 D12 ON L.GovernorID = D12.GovernorID
        WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        GROUP BY L.GovernorID;

        ------------------------------------------------------------
        -- 5) Upsert HEALEDSUMMARY rows for affected governors
        ------------------------------------------------------------
        ;WITH Latest AS (
            SELECT GovernorID, GovernorName, PowerRank, HealedTroops,
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            WHERE k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        ),
        FirstScan AS (
            SELECT GovernorID, HealedTroops AS FirstHealed
            FROM (
                SELECT GovernorID, HealedTroops,
                       ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS rn
                FROM dbo.KingdomScanData4 k
                WHERE k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
            ) t WHERE rn = 1
        ),
        Delta3 AS (
            SELECT L.GovernorID, ISNULL(H3D.HealedTroopsDelta3Months,0) AS D3 FROM dbo.HEALED_LATEST L LEFT JOIN dbo.HEALED_D3D H3D ON L.GovernorID = H3D.GovernorID
            WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        ),
        Delta6 AS (
            SELECT L.GovernorID, ISNULL(H6D.HealedTroopsDelta6Months,0) AS D6 FROM dbo.HEALED_LATEST L LEFT JOIN dbo.HEALED_D6D H6D ON L.GovernorID = H6D.GovernorID
            WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        ),
        Delta12 AS (
            SELECT L.GovernorID, ISNULL(H12D.HealedTroopsDelta12Months,0) AS D12 FROM dbo.HEALED_LATEST L LEFT JOIN dbo.HEALED_D12D H12D ON L.GovernorID = H12D.GovernorID
            WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.HealedTroops AS LatestHealed,
                F.FirstHealed,
                (L.HealedTroops - F.FirstHealed) AS OverallHealedDelta,
                D12.D12 AS HealedDelta12Months,
                D6.D6  AS HealedDelta6Months,
                D3.D3  AS HealedDelta3Months
            FROM (SELECT GovernorID, GovernorName, PowerRank, HealedTroops FROM Latest WHERE rn = 1) L
            LEFT JOIN FirstScan F ON L.GovernorID = F.GovernorID
            LEFT JOIN Delta12 D12 ON L.GovernorID = D12.GovernorID
            LEFT JOIN Delta6 D6 ON L.GovernorID = D6.GovernorID
            LEFT JOIN Delta3 D3 ON L.GovernorID = D3.GovernorID
        )
        MERGE dbo.HEALEDSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                HealedTroops = S.LatestHealed,
                StartingHealed = S.FirstHealed,
                OverallHealedDelta = S.OverallHealedDelta,
                HealedDelta12Months = S.HealedDelta12Months,
                HealedDelta6Months = S.HealedDelta6Months,
                HealedDelta3Months = S.HealedDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.LatestHealed, S.FirstHealed, S.OverallHealedDelta, S.HealedDelta12Months, S.HealedDelta6Months, S.HealedDelta3Months);

        ------------------------------------------------------------
        -- 6) Refresh Top50/Top100/Kingdom-Average summary rows
        --    Remove existing aggregated sentinel rows and re-insert
        ------------------------------------------------------------
        DELETE FROM dbo.HEALEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG(HealedTroops), 0),
               ROUND(AVG(StartingHealed), 0),
               ROUND(AVG(OverallHealedDelta), 0),
               ROUND(AVG(HealedDelta12Months), 0),
               ROUND(AVG(HealedDelta6Months), 0),
               ROUND(AVG(HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY WHERE PowerRank <= 50;

        INSERT INTO dbo.HEALEDSUMMARY
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG(HealedTroops), 0),
               ROUND(AVG(StartingHealed), 0),
               ROUND(AVG(OverallHealedDelta), 0),
               ROUND(AVG(HealedDelta12Months), 0),
               ROUND(AVG(HealedDelta6Months), 0),
               ROUND(AVG(HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY WHERE PowerRank <= 100;

        INSERT INTO dbo.HEALEDSUMMARY
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG(HealedTroops), 0),
               ROUND(AVG(StartingHealed), 0),
               ROUND(AVG(OverallHealedDelta), 0),
               ROUND(AVG(HealedDelta12Months), 0),
               ROUND(AVG(HealedDelta6Months), 0),
               ROUND(AVG(HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY WHERE PowerRank <= 150;

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
        RAISERROR('HEALEDSUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END

