SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DEADSSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[DEADSSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[DEADSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN

 SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'Deads';
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

        DELETE d
        FROM dbo.DALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedAll AS (
            SELECT k.GovernorID,
                   k.GovernorName,
                   k.DEADS,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAscALL,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDescALL
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        INSERT INTO dbo.DALL (GovernorID, GovernorName, DEADS, ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, DEADS, ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        DELETE d
        FROM dbo.D12 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD12 AS (
            SELECT k.GovernorID,
                   k.DEADS,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc12,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc12
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.D12 (GovernorID, DEADS, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, DEADS, ScanDate, RowAsc12, RowDesc12
        FROM RankedD12;

        DELETE d
        FROM dbo.D6 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD6 AS (
            SELECT k.GovernorID,
                   k.DEADS,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc6,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc6
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.D6 (GovernorID, DEADS, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, DEADS, ScanDate, RowAsc6, RowDesc6
        FROM RankedD6;

        DELETE d
        FROM dbo.D3 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD3 AS (
            SELECT k.GovernorID,
                   k.DEADS,
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc3,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc3
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
            WHERE k.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.D3 (GovernorID, DEADS, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, DEADS, ScanDate, RowAsc3, RowDesc3
        FROM RankedD3;

        ;WITH LatestPerGov AS (
            SELECT GovernorID, GovernorName, PowerRank, DEADS,
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4 k
            INNER JOIN #AffectedGovs a ON a.GovernorID = k.GovernorID
        )
        MERGE dbo.LATEST AS tgt
        USING (SELECT GovernorID, GovernorName, PowerRank, DEADS FROM LatestPerGov WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, DEADS = src.DEADS
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, DEADS)
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.DEADS);

        DELETE d
        FROM dbo.D3D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.D3D (GovernorID, DEADSDelta3Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.DEADS END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.DEADS END)
        FROM dbo.LATEST L
        LEFT JOIN dbo.D3 D3 ON L.GovernorID = D3.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.D6D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.D6D (GovernorID, DEADSDelta6Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.DEADS END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.DEADS END)
        FROM dbo.LATEST L
        LEFT JOIN dbo.D6 D6 ON L.GovernorID = D6.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.D12D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;
        INSERT INTO dbo.D12D (GovernorID, DEADSDelta12Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.DEADS END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.DEADS END)
        FROM dbo.LATEST L
        LEFT JOIN dbo.D12 D12 ON L.GovernorID = D12.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT GovernorID,
                   MAX(CASE WHEN RowAscALL = 1 THEN DEADS END) AS StartingDEADS,
                   MAX(CASE WHEN RowDescALL = 1 THEN DEADS END) AS EndingDEADS
            FROM dbo.DALL d
            INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
            GROUP BY d.GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.DEADS,
                F.StartingDEADS,
                F.EndingDEADS - F.StartingDEADS AS OverallDEADSDelta,
                ISNULL(D12D.DEADSDelta12Months, 0) AS DEADSDelta12Months,
                ISNULL(D6D.DEADSDelta6Months, 0) AS DEADSDelta6Months,
                ISNULL(D3D.DEADSDelta3Months, 0) AS DEADSDelta3Months
            FROM dbo.LATEST L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.D12D D12D ON L.GovernorID = D12D.GovernorID
            LEFT JOIN dbo.D6D D6D ON L.GovernorID = D6D.GovernorID
            LEFT JOIN dbo.D3D D3D ON L.GovernorID = D3D.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.DEADSSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                DEADS = S.DEADS,
                StartingDEADS = S.StartingDEADS,
                OverallDEADSDelta = S.OverallDEADSDelta,
                DEADSDelta12Months = S.DEADSDelta12Months,
                DEADSDelta6Months = S.DEADSDelta6Months,
                DEADSDelta3Months = S.DEADSDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, DEADS, StartingDEADS, OverallDEADSDelta, DEADSDelta12Months, DEADSDelta6Months, DEADSDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.DEADS, S.StartingDEADS, S.OverallDEADSDelta, S.DEADSDelta12Months, S.DEADSDelta6Months, S.DEADSDelta3Months);

		DELETE FROM dbo.DEADSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

		INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, DEADS, StartingDEADS, OverallDEADSDelta, DEADSDelta12Months, DEADSDelta6Months, DEADSDelta3Months)
		SELECT 999999997, 'Top50', 50,
			   ROUND(AVG(D.DEADS), 0),
			   ROUND(AVG(D.StartingDEADS), 0),
			   ROUND(AVG(D.OverallDEADSDelta), 0),
			   ROUND(AVG(D.DEADSDelta12Months), 0),
			   ROUND(AVG(D.DEADSDelta6Months), 0),
			   ROUND(AVG(D.DEADSDelta3Months), 0)
		FROM dbo.DEADSSUMMARY AS D
		WHERE D.PowerRank <= 50 
		  AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

		INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, DEADS, StartingDEADS, OverallDEADSDelta, DEADSDelta12Months, DEADSDelta6Months, DEADSDelta3Months)
		SELECT 999999998, 'Top100', 100,
			   ROUND(AVG(D.DEADS), 0),
			   ROUND(AVG(D.StartingDEADS), 0),
			   ROUND(AVG(D.OverallDEADSDelta), 0),
			   ROUND(AVG(D.DEADSDelta12Months), 0),
			   ROUND(AVG(D.DEADSDelta6Months), 0),
			   ROUND(AVG(D.DEADSDelta3Months), 0)
		FROM dbo.DEADSSUMMARY AS D
		WHERE D.PowerRank <= 100
		  AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

		INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, DEADS, StartingDEADS, OverallDEADSDelta, DEADSDelta12Months, DEADSDelta6Months, DEADSDelta3Months)
		SELECT 999999999, 'Kingdom Average', 150,
			   ROUND(AVG(D.DEADS), 0),
			   ROUND(AVG(D.StartingDEADS), 0),
			   ROUND(AVG(D.OverallDEADSDelta), 0),
			   ROUND(AVG(D.DEADSDelta12Months), 0),
			   ROUND(AVG(D.DEADSDelta6Months), 0),
			   ROUND(AVG(D.DEADSDelta3Months), 0)
		FROM dbo.DEADSSUMMARY AS D
		WHERE D.PowerRank <= 150
		  AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

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
        RAISERROR('DEADSSUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;


