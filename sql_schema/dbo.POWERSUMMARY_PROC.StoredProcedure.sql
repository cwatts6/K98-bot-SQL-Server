SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[POWERSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[POWERSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[POWERSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'Power';
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

        DELETE FROM dbo.PALL WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);

        ;WITH RankedAll AS (
            SELECT k.GovernorID,
                   k.GovernorName,
                   k.[POWER],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAscALL,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDescALL
            FROM dbo.KingdomScanData4 k
            WHERE k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        INSERT INTO dbo.PALL (GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        DELETE FROM dbo.P12 WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);

        ;WITH RankedP12 AS (
            SELECT k.GovernorID,
                   k.[POWER],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc12,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc12
            FROM dbo.KingdomScanData4 k
            WHERE k.ScanDate >= DATEADD(MONTH, -12, GETDATE())
              AND k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        INSERT INTO dbo.P12 (GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12
        FROM RankedP12;

        DELETE FROM dbo.P6 WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);

        ;WITH RankedP6 AS (
            SELECT k.GovernorID,
                   k.[POWER],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc6,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc6
            FROM dbo.KingdomScanData4 k
            WHERE k.ScanDate >= DATEADD(MONTH, -6, GETDATE())
              AND k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        INSERT INTO dbo.P6 (GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6
        FROM RankedP6;

        DELETE FROM dbo.P3 WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);

        ;WITH RankedP3 AS (
            SELECT k.GovernorID,
                   k.[POWER],
                   k.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder ASC) AS RowAsc3,
                   ROW_NUMBER() OVER (PARTITION BY k.GovernorID ORDER BY k.ScanOrder DESC) AS RowDesc3
            FROM dbo.KingdomScanData4 k
            WHERE k.ScanDate >= DATEADD(MONTH, -3, GETDATE())
              AND k.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        INSERT INTO dbo.P3 (GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3
        FROM RankedP3;

        ;WITH LatestPerGov AS (
            SELECT GovernorID, GovernorName, PowerRank, [POWER],
                   ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
            FROM dbo.KingdomScanData4
            WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        MERGE dbo.LATEST_POWER AS tgt
        USING (SELECT GovernorID, GovernorName, PowerRank, [POWER] FROM LatestPerGov WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, [POWER] = src.[POWER]
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, [POWER])
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[POWER]);

        DELETE FROM dbo.P3D WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);
        INSERT INTO dbo.P3D (GovernorID, POWERDelta3Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN P3.RowDesc3 = 1 THEN P3.[POWER] END) - MAX(CASE WHEN P3.RowAsc3 = 1 THEN P3.[POWER] END)
        FROM dbo.LATEST_POWER L
        LEFT JOIN dbo.P3 P3 ON L.GovernorID = P3.GovernorID
        WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        GROUP BY L.GovernorID;

        DELETE FROM dbo.P6D WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);
        INSERT INTO dbo.P6D (GovernorID, POWERDelta6Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN P6.RowDesc6 = 1 THEN P6.[POWER] END) - MAX(CASE WHEN P6.RowAsc6 = 1 THEN P6.[POWER] END)
        FROM dbo.LATEST_POWER L
        LEFT JOIN dbo.P6 P6 ON L.GovernorID = P6.GovernorID
        WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        GROUP BY L.GovernorID;

        DELETE FROM dbo.P12D WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs);
        INSERT INTO dbo.P12D (GovernorID, POWERDelta12Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN P12.RowDesc12 = 1 THEN P12.[POWER] END) - MAX(CASE WHEN P12.RowAsc12 = 1 THEN P12.[POWER] END)
        FROM dbo.LATEST_POWER L
        LEFT JOIN dbo.P12 P12 ON L.GovernorID = P12.GovernorID
        WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT GovernorID,
                   MAX(CASE WHEN RowAscALL = 1 THEN [POWER] END) AS StartingPOWER,
                   MAX(CASE WHEN RowDescALL = 1 THEN [POWER] END) AS EndingPOWER
            FROM dbo.PALL
            WHERE GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
            GROUP BY GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.[POWER],
                F.StartingPOWER,
                F.EndingPOWER - F.StartingPOWER AS OverallPOWERDelta,
                ISNULL(P12D.POWERDelta12Months, 0) AS POWERDelta12Months,
                ISNULL(P6D.POWERDelta6Months, 0) AS POWERDelta6Months,
                ISNULL(P3D.POWERDelta3Months, 0) AS POWERDelta3Months
            FROM dbo.LATEST_POWER L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.P12D P12D ON L.GovernorID = P12D.GovernorID
            LEFT JOIN dbo.P6D P6D ON L.GovernorID = P6D.GovernorID
            LEFT JOIN dbo.P3D P3D ON L.GovernorID = P3D.GovernorID
            WHERE L.GovernorID IN (SELECT GovernorID FROM #AffectedGovs)
        )
        MERGE dbo.POWERSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                [POWER] = S.[POWER],
                StartingPOWER = S.StartingPOWER,
                OverallPOWERDelta = S.OverallPOWERDelta,
                POWERDelta12Months = S.POWERDelta12Months,
                POWERDelta6Months = S.POWERDelta6Months,
                POWERDelta3Months = S.POWERDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, [POWER], StartingPOWER, OverallPOWERDelta, POWERDelta12Months, POWERDelta6Months, POWERDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.[POWER], S.StartingPOWER, S.OverallPOWERDelta, S.POWERDelta12Months, S.POWERDelta6Months, S.POWERDelta3Months);

        DELETE FROM dbo.POWERSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.POWERSUMMARY
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG([POWER]), 0),
               ROUND(AVG(StartingPOWER), 0),
               ROUND(AVG(OverallPOWERDelta), 0),
               ROUND(AVG(POWERDelta12Months), 0),
               ROUND(AVG(POWERDelta6Months), 0),
               ROUND(AVG(POWERDelta3Months), 0)
        FROM dbo.POWERSUMMARY WHERE PowerRank <= 50;

        INSERT INTO dbo.POWERSUMMARY
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG([POWER]), 0),
               ROUND(AVG(StartingPOWER), 0),
               ROUND(AVG(OverallPOWERDelta), 0),
               ROUND(AVG(POWERDelta12Months), 0),
               ROUND(AVG(POWERDelta6Months), 0),
               ROUND(AVG(POWERDelta3Months), 0)
        FROM dbo.POWERSUMMARY WHERE PowerRank <= 100;

        INSERT INTO dbo.POWERSUMMARY
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG([POWER]), 0),
               ROUND(AVG(StartingPOWER), 0),
               ROUND(AVG(OverallPOWERDelta), 0),
               ROUND(AVG(POWERDelta12Months), 0),
               ROUND(AVG(POWERDelta6Months), 0),
               ROUND(AVG(POWERDelta3Months), 0)
        FROM dbo.POWERSUMMARY WHERE PowerRank <= 150;

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
        RAISERROR('POWERSUMMARY_PROC failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END;
