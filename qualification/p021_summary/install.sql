-- LOCAL QUALIFICATION ONLY. Not a production migration or signed release.
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 51060, 'Summary qualification requires its own transaction.', 1;
IF CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) <> N'9SX2VF4\K98DEV'
 OR LEFT(DB_NAME(),21) <> N'K98_P021_SummaryTest_'
 OR LEN(DB_NAME()) <> 53
 OR RIGHT(DB_NAME(),32) COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%'
 THROW 51061, 'Summary qualification target is not an owned local fixture.', 1;
DECLARE @owner nvarchar(32) = CONVERT(nvarchar(32),SESSION_CONTEXT(N'P021SummaryFixtureOwner'));
IF @owner IS NULL OR @owner COLLATE Latin1_General_100_BIN2 <> RIGHT(DB_NAME(),32) COLLATE Latin1_General_100_BIN2
 OR NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'P021SummaryFixtureOwner'
                AND CONVERT(nvarchar(32),value) COLLATE Latin1_General_100_BIN2 = @owner COLLATE Latin1_General_100_BIN2)
 THROW 51062, 'Summary fixture ownership token missing or different.', 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @images TABLE (name sysname PRIMARY KEY, beforeBody nvarchar(max), afterBody nvarchar(max));
    INSERT @images VALUES (N'DEADSSUMMARY_PROC',N'ALTER PROCEDURE [dbo].[DEADSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''Deads'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.Deads
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE d
    FROM dbo.DALL d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.DALL (GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE d
    FROM dbo.D12 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.D12 (GovernorID, Deads, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, Deads, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12;

    DELETE d
    FROM dbo.D6 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.D6 (GovernorID, Deads, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, Deads, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6;

    DELETE d
    FROM dbo.D3 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.D3 (GovernorID, Deads, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, Deads, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.Deads
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, Deads = src.Deads
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.Deads);

    DELETE d
    FROM dbo.D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D3D (GovernorID, DeadsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.Deads END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN dbo.D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D6D (GovernorID, DeadsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.Deads END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN dbo.D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D12D (GovernorID, DeadsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.Deads END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN dbo.D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT d.GovernorID,
               MAX(CASE WHEN d.RowAscALL = 1 THEN d.Deads END) AS StartingDeads,
               MAX(CASE WHEN d.RowDescALL = 1 THEN d.Deads END) AS EndingDeads
        FROM dbo.DALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
        GROUP BY d.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.Deads,
            F.StartingDeads,
            F.EndingDeads - F.StartingDeads AS OverallDeadsDelta,
            ISNULL(D12D.DeadsDelta12Months, 0) AS DeadsDelta12Months,
            ISNULL(D6D.DeadsDelta6Months, 0) AS DeadsDelta6Months,
            ISNULL(D3D.DeadsDelta3Months, 0) AS DeadsDelta3Months
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
            Deads = S.Deads,
            StartingDeads = S.StartingDeads,
            OverallDeadsDelta = S.OverallDeadsDelta,
            DeadsDelta12Months = S.DeadsDelta12Months,
            DeadsDelta6Months = S.DeadsDelta6Months,
            DeadsDelta3Months = S.DeadsDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.Deads, S.StartingDeads, S.OverallDeadsDelta, S.DeadsDelta12Months, S.DeadsDelta6Months, S.DeadsDelta3Months);

    DELETE FROM dbo.DEADSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 50
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 100
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 150
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END',N'ALTER PROCEDURE [dbo].[DEADSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''Deads'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.Deads
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_DALL(
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[DEADS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_DALL (GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_D12(
	[GovernorID] [float] NOT NULL,
	[DEADS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_D12 (GovernorID, Deads, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, Deads, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_D6(
	[GovernorID] [float] NOT NULL,
	[DEADS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_D6 (GovernorID, Deads, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, Deads, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_D3(
	[GovernorID] [float] NOT NULL,
	[DEADS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_D3 (GovernorID, Deads, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, Deads, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.Deads
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, Deads = src.Deads
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.Deads);

    DELETE d
    FROM dbo.D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D3D (GovernorID, DeadsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.Deads END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN #P021_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D6D (GovernorID, DeadsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.Deads END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN #P021_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D12D (GovernorID, DeadsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.Deads END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN #P021_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT d.GovernorID,
               MAX(CASE WHEN d.RowAscALL = 1 THEN d.Deads END) AS StartingDeads,
               MAX(CASE WHEN d.RowDescALL = 1 THEN d.Deads END) AS EndingDeads
        FROM #P021_DALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
        GROUP BY d.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.Deads,
            F.StartingDeads,
            F.EndingDeads - F.StartingDeads AS OverallDeadsDelta,
            ISNULL(D12D.DeadsDelta12Months, 0) AS DeadsDelta12Months,
            ISNULL(D6D.DeadsDelta6Months, 0) AS DeadsDelta6Months,
            ISNULL(D3D.DeadsDelta3Months, 0) AS DeadsDelta3Months
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
            Deads = S.Deads,
            StartingDeads = S.StartingDeads,
            OverallDeadsDelta = S.OverallDeadsDelta,
            DeadsDelta12Months = S.DeadsDelta12Months,
            DeadsDelta6Months = S.DeadsDelta6Months,
            DeadsDelta3Months = S.DeadsDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.Deads, S.StartingDeads, S.OverallDeadsDelta, S.DeadsDelta12Months, S.DeadsDelta6Months, S.DeadsDelta3Months);

    DELETE FROM dbo.DEADSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 50
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 100
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 150
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END');
    INSERT @images VALUES (N'POWERSUMMARY_PROC',N'ALTER PROCEDURE [dbo].[POWERSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''Power'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[POWER]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE pa
    FROM dbo.PALL pa
    INNER JOIN #AffectedGovs a ON a.GovernorID = pa.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.PALL (GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE p12
    FROM dbo.P12 p12
    INNER JOIN #AffectedGovs a ON a.GovernorID = p12.GovernorID;

    ;WITH RankedP12 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.P12 (GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12
    FROM RankedP12;

    DELETE p6
    FROM dbo.P6 p6
    INNER JOIN #AffectedGovs a ON a.GovernorID = p6.GovernorID;

    ;WITH RankedP6 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.P6 (GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6
    FROM RankedP6;

    DELETE p3
    FROM dbo.P3 p3
    INNER JOIN #AffectedGovs a ON a.GovernorID = p3.GovernorID;

    ;WITH RankedP3 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.P3 (GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3
    FROM RankedP3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_POWER AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[POWER]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, [POWER] = src.[POWER]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, [POWER])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[POWER]);

    DELETE p3d
    FROM dbo.P3D p3d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p3d.GovernorID;

    INSERT INTO dbo.P3D (GovernorID, POWERDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P3.RowDesc3 = 1 THEN P3.[POWER] END) - MAX(CASE WHEN P3.RowAsc3 = 1 THEN P3.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN dbo.P3 P3 ON L.GovernorID = P3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE p6d
    FROM dbo.P6D p6d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p6d.GovernorID;

    INSERT INTO dbo.P6D (GovernorID, POWERDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P6.RowDesc6 = 1 THEN P6.[POWER] END) - MAX(CASE WHEN P6.RowAsc6 = 1 THEN P6.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN dbo.P6 P6 ON L.GovernorID = P6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE p12d
    FROM dbo.P12D p12d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p12d.GovernorID;

    INSERT INTO dbo.P12D (GovernorID, POWERDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P12.RowDesc12 = 1 THEN P12.[POWER] END) - MAX(CASE WHEN P12.RowAsc12 = 1 THEN P12.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN dbo.P12 P12 ON L.GovernorID = P12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT pa.GovernorID,
               MAX(CASE WHEN pa.RowAscALL = 1 THEN pa.[POWER] END) AS StartingPower,
               MAX(CASE WHEN pa.RowDescALL = 1 THEN pa.[POWER] END) AS EndingPower
        FROM dbo.PALL pa
        INNER JOIN #AffectedGovs a ON a.GovernorID = pa.GovernorID
        GROUP BY pa.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.[POWER],
            F.StartingPower,
            F.EndingPower - F.StartingPower AS OverallPowerDelta,
            ISNULL(P12D.PowerDelta12Months, 0) AS PowerDelta12Months,
            ISNULL(P6D.PowerDelta6Months, 0) AS PowerDelta6Months,
            ISNULL(P3D.PowerDelta3Months, 0) AS PowerDelta3Months
        FROM dbo.LATEST_POWER L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.P12D P12D ON L.GovernorID = P12D.GovernorID
        LEFT JOIN dbo.P6D P6D ON L.GovernorID = P6D.GovernorID
        LEFT JOIN dbo.P3D P3D ON L.GovernorID = P3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.POWERSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            [POWER] = S.[POWER],
            StartingPower = S.StartingPower,
            OverallPowerDelta = S.OverallPowerDelta,
            PowerDelta12Months = S.PowerDelta12Months,
            PowerDelta6Months = S.PowerDelta6Months,
            PowerDelta3Months = S.PowerDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.[POWER], S.StartingPower, S.OverallPowerDelta, S.PowerDelta12Months, S.PowerDelta6Months, S.PowerDelta3Months);

    DELETE FROM dbo.POWERSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 50
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 100
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 150
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END',N'ALTER PROCEDURE [dbo].[POWERSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''Power'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[POWER]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_PALL(
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[POWER] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_PALL (GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_P12(
	[GovernorID] [float] NOT NULL,
	[POWER] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedP12 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_P12 (GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12
    FROM RankedP12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_P6(
	[GovernorID] [float] NOT NULL,
	[POWER] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedP6 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_P6 (GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6
    FROM RankedP6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_P3(
	[GovernorID] [float] NOT NULL,
	[POWER] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedP3 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_P3 (GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3
    FROM RankedP3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_POWER AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[POWER]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, [POWER] = src.[POWER]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, [POWER])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[POWER]);

    DELETE p3d
    FROM dbo.P3D p3d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p3d.GovernorID;

    INSERT INTO dbo.P3D (GovernorID, POWERDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P3.RowDesc3 = 1 THEN P3.[POWER] END) - MAX(CASE WHEN P3.RowAsc3 = 1 THEN P3.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN #P021_P3 P3 ON L.GovernorID = P3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE p6d
    FROM dbo.P6D p6d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p6d.GovernorID;

    INSERT INTO dbo.P6D (GovernorID, POWERDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P6.RowDesc6 = 1 THEN P6.[POWER] END) - MAX(CASE WHEN P6.RowAsc6 = 1 THEN P6.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN #P021_P6 P6 ON L.GovernorID = P6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE p12d
    FROM dbo.P12D p12d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p12d.GovernorID;

    INSERT INTO dbo.P12D (GovernorID, POWERDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P12.RowDesc12 = 1 THEN P12.[POWER] END) - MAX(CASE WHEN P12.RowAsc12 = 1 THEN P12.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN #P021_P12 P12 ON L.GovernorID = P12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT pa.GovernorID,
               MAX(CASE WHEN pa.RowAscALL = 1 THEN pa.[POWER] END) AS StartingPower,
               MAX(CASE WHEN pa.RowDescALL = 1 THEN pa.[POWER] END) AS EndingPower
        FROM #P021_PALL pa
        INNER JOIN #AffectedGovs a ON a.GovernorID = pa.GovernorID
        GROUP BY pa.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.[POWER],
            F.StartingPower,
            F.EndingPower - F.StartingPower AS OverallPowerDelta,
            ISNULL(P12D.PowerDelta12Months, 0) AS PowerDelta12Months,
            ISNULL(P6D.PowerDelta6Months, 0) AS PowerDelta6Months,
            ISNULL(P3D.PowerDelta3Months, 0) AS PowerDelta3Months
        FROM dbo.LATEST_POWER L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.P12D P12D ON L.GovernorID = P12D.GovernorID
        LEFT JOIN dbo.P6D P6D ON L.GovernorID = P6D.GovernorID
        LEFT JOIN dbo.P3D P3D ON L.GovernorID = P3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.POWERSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            [POWER] = S.[POWER],
            StartingPower = S.StartingPower,
            OverallPowerDelta = S.OverallPowerDelta,
            PowerDelta12Months = S.PowerDelta12Months,
            PowerDelta6Months = S.PowerDelta6Months,
            PowerDelta3Months = S.PowerDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.[POWER], S.StartingPower, S.OverallPowerDelta, S.PowerDelta12Months, S.PowerDelta6Months, S.PowerDelta3Months);

    DELETE FROM dbo.POWERSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 50
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 100
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 150
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END');
    INSERT @images VALUES (N'KILLSSUMMARY_PROC',N'ALTER PROCEDURE [dbo].[KILLSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''T4T5Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T4&T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

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
    SELECT 999999997, ''Top50'', 50,
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
    SELECT 999999998, ''Top100'', 100,
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
    SELECT 999999999, ''Kingdom Average'', 150,
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
END',N'ALTER PROCEDURE [dbo].[KILLSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''T4T5Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T4&T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_KALL(
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T4&T5_KILLS] [float] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_KALL (GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K12(
	[GovernorID] [float] NOT NULL,
	[T4&T5_KILLS] [float] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_K12 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K6(
	[GovernorID] [float] NOT NULL,
	[T4&T5_KILLS] [float] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_K6 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K3(
	[GovernorID] [float] NOT NULL,
	[T4&T5_KILLS] [float] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_K3 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

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
    LEFT JOIN #P021_K3 K3 ON L.GovernorID = K3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE kd6
    FROM dbo.K6D kd6
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd6.GovernorID;

    INSERT INTO dbo.K6D (GovernorID, [T4&T5_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K6.RowDesc6 = 1 THEN K6.[T4&T5_KILLS] END) - MAX(CASE WHEN K6.RowAsc6 = 1 THEN K6.[T4&T5_KILLS] END)
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN #P021_K6 K6 ON L.GovernorID = K6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE kd12
    FROM dbo.K12D kd12
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd12.GovernorID;

    INSERT INTO dbo.K12D (GovernorID, [T4&T5_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K12.RowDesc12 = 1 THEN K12.[T4&T5_KILLS] END) - MAX(CASE WHEN K12.RowAsc12 = 1 THEN K12.[T4&T5_KILLS] END)
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN #P021_K12 K12 ON L.GovernorID = K12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ka.GovernorID,
               MAX(CASE WHEN ka.RowAscALL = 1 THEN ka.[T4&T5_KILLS] END) AS StartingKills,
               MAX(CASE WHEN ka.RowDescALL = 1 THEN ka.[T4&T5_KILLS] END) AS EndingKills
        FROM #P021_KALL ka
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
    SELECT 999999997, ''Top50'', 50,
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
    SELECT 999999998, ''Top100'', 100,
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
    SELECT 999999999, ''Kingdom Average'', 150,
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
END');
    INSERT @images VALUES (N'KT4SUMMARY_PROC',N'ALTER PROCEDURE [dbo].[KT4SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''T4Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T4_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE k4a
    FROM dbo.K4ALL k4a
    INNER JOIN #AffectedGovs a ON a.GovernorID = k4a.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.K4ALL (GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE k412
    FROM dbo.K412 k412
    INNER JOIN #AffectedGovs a ON a.GovernorID = k412.GovernorID;

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.K412 (GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12;

    DELETE k46
    FROM dbo.K46 k46
    INNER JOIN #AffectedGovs a ON a.GovernorID = k46.GovernorID;

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.K46 (GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6;

    DELETE k43
    FROM dbo.K43 k43
    INNER JOIN #AffectedGovs a ON a.GovernorID = k43.GovernorID;

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.K43 (GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_T4_KILLS AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T4_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4_KILLS] = src.[T4_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4_KILLS]);

    DELETE k43d
    FROM dbo.K43D k43d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k43d.GovernorID;

    INSERT INTO dbo.K43D (GovernorID, [T4_KILLSDelta3Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K43.RowDesc3 = 1 THEN K43.[T4_KILLS] END) - MAX(CASE WHEN K43.RowAsc3 = 1 THEN K43.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN dbo.K43 K43 ON L.GovernorID = K43.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k46d
    FROM dbo.K46D k46d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k46d.GovernorID;

    INSERT INTO dbo.K46D (GovernorID, [T4_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K46.RowDesc6 = 1 THEN K46.[T4_KILLS] END) - MAX(CASE WHEN K46.RowAsc6 = 1 THEN K46.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN dbo.K46 K46 ON L.GovernorID = K46.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k412d
    FROM dbo.K412D k412d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k412d.GovernorID;

    INSERT INTO dbo.K412D (GovernorID, [T4_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K412.RowDesc12 = 1 THEN K412.[T4_KILLS] END) - MAX(CASE WHEN K412.RowAsc12 = 1 THEN K412.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN dbo.K412 K412 ON L.GovernorID = K412.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT k4a.GovernorID,
               MAX(CASE WHEN k4a.RowAscALL = 1 THEN k4a.[T4_KILLS] END) AS StartingKills,
               MAX(CASE WHEN k4a.RowDescALL = 1 THEN k4a.[T4_KILLS] END) AS EndingKills
        FROM dbo.K4ALL k4a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k4a.GovernorID
        GROUP BY k4a.GovernorID
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

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 50
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 100
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 150
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END',N'ALTER PROCEDURE [dbo].[KT4SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''T4Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T4_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K4ALL(
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T4_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_K4ALL (GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K412(
	[GovernorID] [float] NOT NULL,
	[T4_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_K412 (GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K46(
	[GovernorID] [float] NOT NULL,
	[T4_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_K46 (GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K43(
	[GovernorID] [float] NOT NULL,
	[T4_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_K43 (GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_T4_KILLS AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T4_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4_KILLS] = src.[T4_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4_KILLS]);

    DELETE k43d
    FROM dbo.K43D k43d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k43d.GovernorID;

    INSERT INTO dbo.K43D (GovernorID, [T4_KILLSDelta3Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K43.RowDesc3 = 1 THEN K43.[T4_KILLS] END) - MAX(CASE WHEN K43.RowAsc3 = 1 THEN K43.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN #P021_K43 K43 ON L.GovernorID = K43.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k46d
    FROM dbo.K46D k46d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k46d.GovernorID;

    INSERT INTO dbo.K46D (GovernorID, [T4_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K46.RowDesc6 = 1 THEN K46.[T4_KILLS] END) - MAX(CASE WHEN K46.RowAsc6 = 1 THEN K46.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN #P021_K46 K46 ON L.GovernorID = K46.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k412d
    FROM dbo.K412D k412d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k412d.GovernorID;

    INSERT INTO dbo.K412D (GovernorID, [T4_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K412.RowDesc12 = 1 THEN K412.[T4_KILLS] END) - MAX(CASE WHEN K412.RowAsc12 = 1 THEN K412.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN #P021_K412 K412 ON L.GovernorID = K412.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT k4a.GovernorID,
               MAX(CASE WHEN k4a.RowAscALL = 1 THEN k4a.[T4_KILLS] END) AS StartingKills,
               MAX(CASE WHEN k4a.RowDescALL = 1 THEN k4a.[T4_KILLS] END) AS EndingKills
        FROM #P021_K4ALL k4a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k4a.GovernorID
        GROUP BY k4a.GovernorID
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

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 50
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 100
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 150
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END');
    INSERT @images VALUES (N'KT5SUMMARY_PROC',N'ALTER PROCEDURE [dbo].[KT5SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''T5Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE k5a
    FROM dbo.K5ALL k5a
    INNER JOIN #AffectedGovs a ON a.GovernorID = k5a.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.K5ALL (GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE k512
    FROM dbo.K512 k512
    INNER JOIN #AffectedGovs a ON a.GovernorID = k512.GovernorID;

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.K512 (GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12;

    DELETE k56
    FROM dbo.K56 k56
    INNER JOIN #AffectedGovs a ON a.GovernorID = k56.GovernorID;

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.K56 (GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6;

    DELETE k53
    FROM dbo.K53 k53
    INNER JOIN #AffectedGovs a ON a.GovernorID = k53.GovernorID;

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.K53 (GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_T5_KILLS AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T5_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T5_KILLS] = src.[T5_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T5_KILLS]);

    DELETE k53d
    FROM dbo.K53D k53d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k53d.GovernorID;

    INSERT INTO dbo.K53D (GovernorID, [T5_KILLSDelta3Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K53.RowDesc3 = 1 THEN K53.[T5_KILLS] END) - MAX(CASE WHEN K53.RowAsc3 = 1 THEN K53.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN dbo.K53 K53 ON L.GovernorID = K53.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k56d
    FROM dbo.K56D k56d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k56d.GovernorID;

    INSERT INTO dbo.K56D (GovernorID, [T5_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K56.RowDesc6 = 1 THEN K56.[T5_KILLS] END) - MAX(CASE WHEN K56.RowAsc6 = 1 THEN K56.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN dbo.K56 K56 ON L.GovernorID = K56.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k512d
    FROM dbo.K512D k512d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k512d.GovernorID;

    INSERT INTO dbo.K512D (GovernorID, [T5_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K512.RowDesc12 = 1 THEN K512.[T5_KILLS] END) - MAX(CASE WHEN K512.RowAsc12 = 1 THEN K512.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN dbo.K512 K512 ON L.GovernorID = K512.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT k5a.GovernorID,
               MAX(CASE WHEN k5a.RowAscALL = 1 THEN k5a.[T5_KILLS] END) AS StartingKills,
               MAX(CASE WHEN k5a.RowDescALL = 1 THEN k5a.[T5_KILLS] END) AS EndingKills
        FROM dbo.K5ALL k5a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k5a.GovernorID
        GROUP BY k5a.GovernorID
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

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 50
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 100
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 150
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END',N'ALTER PROCEDURE [dbo].[KT5SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''T5Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K5ALL(
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T5_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_K5ALL (GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K512(
	[GovernorID] [float] NOT NULL,
	[T5_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_K512 (GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K56(
	[GovernorID] [float] NOT NULL,
	[T5_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_K56 (GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_K53(
	[GovernorID] [float] NOT NULL,
	[T5_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_K53 (GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_T5_KILLS AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T5_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T5_KILLS] = src.[T5_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T5_KILLS]);

    DELETE k53d
    FROM dbo.K53D k53d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k53d.GovernorID;

    INSERT INTO dbo.K53D (GovernorID, [T5_KILLSDelta3Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K53.RowDesc3 = 1 THEN K53.[T5_KILLS] END) - MAX(CASE WHEN K53.RowAsc3 = 1 THEN K53.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN #P021_K53 K53 ON L.GovernorID = K53.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k56d
    FROM dbo.K56D k56d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k56d.GovernorID;

    INSERT INTO dbo.K56D (GovernorID, [T5_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K56.RowDesc6 = 1 THEN K56.[T5_KILLS] END) - MAX(CASE WHEN K56.RowAsc6 = 1 THEN K56.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN #P021_K56 K56 ON L.GovernorID = K56.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k512d
    FROM dbo.K512D k512d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k512d.GovernorID;

    INSERT INTO dbo.K512D (GovernorID, [T5_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K512.RowDesc12 = 1 THEN K512.[T5_KILLS] END) - MAX(CASE WHEN K512.RowAsc12 = 1 THEN K512.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN #P021_K512 K512 ON L.GovernorID = K512.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT k5a.GovernorID,
               MAX(CASE WHEN k5a.RowAscALL = 1 THEN k5a.[T5_KILLS] END) AS StartingKills,
               MAX(CASE WHEN k5a.RowDescALL = 1 THEN k5a.[T5_KILLS] END) AS EndingKills
        FROM #P021_K5ALL k5a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k5a.GovernorID
        GROUP BY k5a.GovernorID
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

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 50
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 100
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 150
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END');
    INSERT @images VALUES (N'KILLPOINTSSUMMARY_PROC',N'ALTER PROCEDURE [dbo].[KILLPOINTSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''KillPoints'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.KillPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE kp
    FROM dbo.KILLPOINTS_ALL kp
    INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.KILLPOINTS_ALL (GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE kp
    FROM dbo.KILLPOINTS_D12 kp
    INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.KILLPOINTS_D12 (GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12;

    DELETE kp
    FROM dbo.KILLPOINTS_D6 kp
    INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID;

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.KILLPOINTS_D6 (GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6;

    DELETE kp
    FROM dbo.KILLPOINTS_D3 kp
    INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID;

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.KILLPOINTS_D3 (GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.KILLPOINTS_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.KillPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, KillPoints = src.KillPoints
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, KillPoints)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.KillPoints);

    DELETE d
    FROM dbo.KILLPOINTS_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D3D (GovernorID, KillPointsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.KillPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN dbo.KILLPOINTS_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.KILLPOINTS_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D6D (GovernorID, KillPointsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.KillPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN dbo.KILLPOINTS_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.KILLPOINTS_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D12D (GovernorID, KillPointsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.KillPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN dbo.KILLPOINTS_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT kp.GovernorID,
               MAX(CASE WHEN kp.RowAscALL = 1 THEN kp.KillPoints END) AS StartingKillPoints,
               MAX(CASE WHEN kp.RowDescALL = 1 THEN kp.KillPoints END) AS EndingKillPoints
        FROM dbo.KILLPOINTS_ALL kp
        INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID
        GROUP BY kp.GovernorID
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
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
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

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 50
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 100
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 150
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END',N'ALTER PROCEDURE [dbo].[KILLPOINTSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''KillPoints'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.KillPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_KILLPOINTS_ALL(
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_KILLPOINTS_ALL (GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_KILLPOINTS_D12(
	[GovernorID] [float] NOT NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_KILLPOINTS_D12 (GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_KILLPOINTS_D6(
	[GovernorID] [float] NOT NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_KILLPOINTS_D6 (GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_KILLPOINTS_D3(
	[GovernorID] [float] NOT NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc3] [int] NULL,
	[RowDesc3] [int] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_KILLPOINTS_D3 (GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.KILLPOINTS_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.KillPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, KillPoints = src.KillPoints
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, KillPoints)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.KillPoints);

    DELETE d
    FROM dbo.KILLPOINTS_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D3D (GovernorID, KillPointsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.KillPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN #P021_KILLPOINTS_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.KILLPOINTS_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D6D (GovernorID, KillPointsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.KillPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN #P021_KILLPOINTS_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.KILLPOINTS_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D12D (GovernorID, KillPointsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.KillPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN #P021_KILLPOINTS_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT kp.GovernorID,
               MAX(CASE WHEN kp.RowAscALL = 1 THEN kp.KillPoints END) AS StartingKillPoints,
               MAX(CASE WHEN kp.RowDescALL = 1 THEN kp.KillPoints END) AS EndingKillPoints
        FROM #P021_KILLPOINTS_ALL kp
        INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID
        GROUP BY kp.GovernorID
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
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
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

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 50
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 100
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 150
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END');
    INSERT @images VALUES (N'HEALEDSUMMARY_PROC',N'ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''HealedTroops'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    /* Optional independent mode */
    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE d
    FROM dbo.HEALED_ALL d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
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

    DELETE d
    FROM dbo.HEALED_D12 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
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
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
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
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
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
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
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
    SELECT 999999997, ''Top50'', 50,
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
    SELECT 999999998, ''Top100'', 100,
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
    SELECT 999999999, ''Kingdom Average'', 150,
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
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END',N'ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''HealedTroops'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    /* Optional independent mode */
    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_HEALED_ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_HEALED_D12(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_HEALED_D6(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_HEALED_D3(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc3] [int] NULL,
	[RowDesc3] [int] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

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

    DELETE d
    FROM dbo.HEALED_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D3D (GovernorID, HealedTroopsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.HealedTroops END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.HealedTroops END)
    FROM dbo.HEALED_LATEST L
    LEFT JOIN #P021_HEALED_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.HEALED_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D6D (GovernorID, HealedTroopsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.HealedTroops END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.HealedTroops END)
    FROM dbo.HEALED_LATEST L
    LEFT JOIN #P021_HEALED_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.HEALED_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D12D (GovernorID, HealedTroopsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.HealedTroops END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.HealedTroops END)
    FROM dbo.HEALED_LATEST L
    LEFT JOIN #P021_HEALED_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT d.GovernorID,
               MAX(CASE WHEN d.RowAscALL = 1 THEN d.HealedTroops END) AS StartingHealed,
               MAX(CASE WHEN d.RowDescALL = 1 THEN d.HealedTroops END) AS EndingHealed
        FROM #P021_HEALED_ALL d
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
    SELECT 999999997, ''Top50'', 50,
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
    SELECT 999999998, ''Top100'', 100,
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
    SELECT 999999999, ''Kingdom Average'', 150,
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
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END');
    INSERT @images VALUES (N'RANGEDSUMMARY_PROC',N'ALTER PROCEDURE [dbo].[RANGEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''RangedPoints'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.RangedPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE ra
    FROM dbo.RANGED_ALL ra
    INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.RANGED_ALL (GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.RANGED_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.RangedPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, RangedPoints = src.RangedPoints
    WHEN NOT MATCHED THEN INSERT (GovernorID, GovernorName, PowerRank, RangedPoints)
    VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.RangedPoints);

    DELETE d
    FROM dbo.RANGED_D3 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.RANGED_D3 (GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3;

    DELETE d
    FROM dbo.RANGED_D6 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.RANGED_D6 (GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6;

    DELETE d
    FROM dbo.RANGED_D12 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.RANGED_D12 (GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12;

    DELETE d
    FROM dbo.RANGED_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D3D (GovernorID, RangedPointsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.RangedPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D6D (GovernorID, RangedPointsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.RangedPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D12D (GovernorID, RangedPointsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.RangedPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ra.GovernorID,
               MAX(CASE WHEN ra.RowAscALL = 1 THEN ra.RangedPoints END) AS StartingRanged,
               MAX(CASE WHEN ra.RowDescALL = 1 THEN ra.RangedPoints END) AS EndingRanged
        FROM dbo.RANGED_ALL ra
        INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID
        GROUP BY ra.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.RangedPoints,
            F.StartingRanged,
            F.EndingRanged - F.StartingRanged AS OverallRangedDelta,
            ISNULL(R12D.RangedPointsDelta12Months, 0) AS RangedDelta12Months,
            ISNULL(R6D.RangedPointsDelta6Months, 0) AS RangedDelta6Months,
            ISNULL(R3D.RangedPointsDelta3Months, 0) AS RangedDelta3Months
        FROM dbo.RANGED_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.RANGED_D12D R12D ON L.GovernorID = R12D.GovernorID
        LEFT JOIN dbo.RANGED_D6D R6D ON L.GovernorID = R6D.GovernorID
        LEFT JOIN dbo.RANGED_D3D R3D ON L.GovernorID = R3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.RANGEDSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            RangedPoints = S.RangedPoints,
            StartingRanged = S.StartingRanged,
            OverallRangedDelta = S.OverallRangedDelta,
            RangedDelta12Months = S.RangedDelta12Months,
            RangedDelta6Months = S.RangedDelta6Months,
            RangedDelta3Months = S.RangedDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.RangedPoints, S.StartingRanged, S.OverallRangedDelta, S.RangedDelta12Months, S.RangedDelta6Months, S.RangedDelta3Months);

    DELETE FROM dbo.RANGEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 50
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 100
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 150
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END',N'ALTER PROCEDURE [dbo].[RANGEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''RangedPoints'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
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

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.RangedPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_RANGED_ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[RangedPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_RANGED_ALL (GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.RANGED_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.RangedPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, RangedPoints = src.RangedPoints
    WHEN NOT MATCHED THEN INSERT (GovernorID, GovernorName, PowerRank, RangedPoints)
    VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.RangedPoints);

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_RANGED_D3(
	[GovernorID] [bigint] NOT NULL,
	[RangedPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc3] [int] NULL,
	[RowDesc3] [int] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_RANGED_D3 (GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_RANGED_D6(
	[GovernorID] [bigint] NOT NULL,
	[RangedPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_RANGED_D6 (GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; preserve legacy cache types and ranking.
    CREATE TABLE #P021_RANGED_D12(
	[GovernorID] [bigint] NOT NULL,
	[RangedPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_RANGED_D12 (GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    DELETE d
    FROM dbo.RANGED_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D3D (GovernorID, RangedPointsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.RangedPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN #P021_RANGED_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D6D (GovernorID, RangedPointsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.RangedPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN #P021_RANGED_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D12D (GovernorID, RangedPointsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.RangedPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN #P021_RANGED_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ra.GovernorID,
               MAX(CASE WHEN ra.RowAscALL = 1 THEN ra.RangedPoints END) AS StartingRanged,
               MAX(CASE WHEN ra.RowDescALL = 1 THEN ra.RangedPoints END) AS EndingRanged
        FROM #P021_RANGED_ALL ra
        INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID
        GROUP BY ra.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.RangedPoints,
            F.StartingRanged,
            F.EndingRanged - F.StartingRanged AS OverallRangedDelta,
            ISNULL(R12D.RangedPointsDelta12Months, 0) AS RangedDelta12Months,
            ISNULL(R6D.RangedPointsDelta6Months, 0) AS RangedDelta6Months,
            ISNULL(R3D.RangedPointsDelta3Months, 0) AS RangedDelta3Months
        FROM dbo.RANGED_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.RANGED_D12D R12D ON L.GovernorID = R12D.GovernorID
        LEFT JOIN dbo.RANGED_D6D R6D ON L.GovernorID = R6D.GovernorID
        LEFT JOIN dbo.RANGED_D3D R3D ON L.GovernorID = R3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.RANGEDSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            RangedPoints = S.RangedPoints,
            StartingRanged = S.StartingRanged,
            OverallRangedDelta = S.OverallRangedDelta,
            RangedDelta12Months = S.RangedDelta12Months,
            RangedDelta6Months = S.RangedDelta6Months,
            RangedDelta3Months = S.RangedDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.RangedPoints, S.StartingRanged, S.OverallRangedDelta, S.RangedDelta12Months, S.RangedDelta6Months, S.RangedDelta3Months);

    DELETE FROM dbo.RANGEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 50
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 100
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 150
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END');
    INSERT @images VALUES (N'HEALEDSUMMARY_PROC_OPT',N'ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC_OPT]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''HealedTroops'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

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
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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
            ScanOrder    INT           NOT NULL,
            ScanDate     DATETIME      NULL,
            HealedTroops BIGINT        NULL
        );

        INSERT INTO #GovScan (GovernorID, GovernorName, PowerRank, ScanOrder, ScanDate, HealedTroops)
        SELECT
            ks4.GovernorID,
            CONVERT(NVARCHAR(400), ks4.GovernorName) AS GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        FROM dbo.KingdomScanData4 ks4
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
        SELECT 999999997, ''Top50'', 50,
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
        SELECT 999999998, ''Top100'', 100,
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
        SELECT 999999999, ''Kingdom Average'', 150,
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
        RAISERROR(''HEALEDSUMMARY_PROC_OPT failed: %s'', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END',N'ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC_OPT]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''HealedTroops'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

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
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

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
            ScanOrder    INT           NOT NULL,
            ScanDate     DATETIME      NULL,
            HealedTroops BIGINT        NULL
        );

        INSERT INTO #GovScan (GovernorID, GovernorName, PowerRank, ScanOrder, ScanDate, HealedTroops)
        SELECT
            ks4.GovernorID,
            CONVERT(NVARCHAR(400), ks4.GovernorName) AS GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        ------------------------------------------------------------
        -- 1) HEALED_ALL: Delete and rebuild for affected governors
        ------------------------------------------------------------
        -- Retain only first/last rows; preserve legacy cache types and ranking.
        CREATE TABLE #P021_HEALED_ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
        );

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
        INSERT INTO #P021_HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL
        FROM RankedAll
        WHERE RowAscALL = 1 OR RowDescALL = 1;

        ------------------------------------------------------------
        -- Remaining sections unchanged (D12/D6/D3/etc.)
        ------------------------------------------------------------
        -- Retain only first/last rows; preserve legacy cache types and ranking.
        CREATE TABLE #P021_HEALED_D12(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
        );

        ;WITH RankedD12 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc12,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc12
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff12
        )
        INSERT INTO #P021_HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12
        FROM RankedD12
        WHERE RowAsc12 = 1 OR RowDesc12 = 1;

        -- Retain only first/last rows; preserve legacy cache types and ranking.
        CREATE TABLE #P021_HEALED_D6(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
        );

        ;WITH RankedD6 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc6,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc6
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff6
        )
        INSERT INTO #P021_HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6
        FROM RankedD6
        WHERE RowAsc6 = 1 OR RowDesc6 = 1;

        -- Retain only first/last rows; preserve legacy cache types and ranking.
        CREATE TABLE #P021_HEALED_D3(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc3] [int] NULL,
	[RowDesc3] [int] NULL
        );

        ;WITH RankedD3 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc3,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc3
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff3
        )
        INSERT INTO #P021_HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3
        FROM RankedD3
        WHERE RowAsc3 = 1 OR RowDesc3 = 1;

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
        LEFT JOIN #P021_HEALED_D3 D3 ON L.GovernorID = D3.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.HEALED_D6D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D6D (GovernorID, HealedTroopsDelta6Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.HealedTroops END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN #P021_HEALED_D6 D6 ON L.GovernorID = D6.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.HEALED_D12D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D12D (GovernorID, HealedTroopsDelta12Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.HealedTroops END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN #P021_HEALED_D12 D12 ON L.GovernorID = D12.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT d.GovernorID,
                   MAX(CASE WHEN d.RowAscALL = 1 THEN d.HealedTroops END) AS StartingHealed,
                   MAX(CASE WHEN d.RowDescALL = 1 THEN d.HealedTroops END) AS EndingHealed
            FROM #P021_HEALED_ALL d
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
        SELECT 999999997, ''Top50'', 50,
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
        SELECT 999999998, ''Top100'', 100,
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
        SELECT 999999999, ''Kingdom Average'', 150,
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
        RAISERROR(''HEALEDSUMMARY_PROC_OPT failed: %s'', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END');
    DECLARE @name sysname,@before nvarchar(max),@after nvarchar(max),@current nvarchar(max),@id int,@changed bit=0;
    DECLARE verifyModules CURSOR LOCAL FAST_FORWARD FOR SELECT name,beforeBody,afterBody FROM @images ORDER BY name;
    OPEN verifyModules;
    FETCH NEXT FROM verifyModules INTO @name,@before,@after;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @id=OBJECT_ID(N'dbo.'+QUOTENAME(@name),N'P');
        IF @id IS NULL THROW 51063, 'Summary prerequisite module missing.', 1;
        IF EXISTS (SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
            THROW 51064, 'Signed summary module needs a reviewed signing release.', 1;
        IF NOT EXISTS (SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1
                       AND uses_quoted_identifier=1 AND execute_as_principal_id IS NULL)
            THROW 51065, 'Summary module execution context or options differ.', 1;
        SET @current=OBJECT_DEFINITION(@id);
        SET @current=TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(@current,NCHAR(13)+NCHAR(10),NCHAR(10)));
        IF LEFT(@current,25) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE'
            SET @current=N'ALTER PROCEDURE'+SUBSTRING(@current,26,LEN(@current));
        ELSE IF LEFT(@current,16) COLLATE Latin1_General_100_BIN2=N'CREATE PROCEDURE'
            SET @current=N'ALTER PROCEDURE'+SUBSTRING(@current,17,LEN(@current));
        SET @before=TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(@before,NCHAR(13)+NCHAR(10),NCHAR(10)));
        IF LEFT(@before,25) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE'
            SET @before=N'ALTER PROCEDURE'+SUBSTRING(@before,26,LEN(@before));
        ELSE IF LEFT(@before,16) COLLATE Latin1_General_100_BIN2=N'CREATE PROCEDURE'
            SET @before=N'ALTER PROCEDURE'+SUBSTRING(@before,17,LEN(@before));
        SET @after=TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(@after,NCHAR(13)+NCHAR(10),NCHAR(10)));
        IF LEFT(@after,25) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE'
            SET @after=N'ALTER PROCEDURE'+SUBSTRING(@after,26,LEN(@after));
        ELSE IF LEFT(@after,16) COLLATE Latin1_General_100_BIN2=N'CREATE PROCEDURE'
            SET @after=N'ALTER PROCEDURE'+SUBSTRING(@after,17,LEN(@after));
        IF @current IS NULL OR (CONVERT(varbinary(max),@current)<>CONVERT(varbinary(max),@before)
                           AND CONVERT(varbinary(max),@current)<>CONVERT(varbinary(max),@after))
            THROW 51066, 'Unrecognized summary definition; preserve evidence.', 1;
        IF CONVERT(varbinary(max),@current)<>CONVERT(varbinary(max),@after) SET @changed=1;
        FETCH NEXT FROM verifyModules INTO @name,@before,@after;
    END;
    CLOSE verifyModules;
    DEALLOCATE verifyModules;
    DECLARE applyModules CURSOR LOCAL FAST_FORWARD FOR SELECT name,afterBody FROM @images ORDER BY name;
    OPEN applyModules;
    FETCH NEXT FROM applyModules INTO @name,@after;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC sys.sp_executesql @after;
        SET @current=OBJECT_DEFINITION(OBJECT_ID(N'dbo.'+QUOTENAME(@name),N'P'));
        SET @current=TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(@current,NCHAR(13)+NCHAR(10),NCHAR(10)));
        IF LEFT(@current,25) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE'
            SET @current=N'ALTER PROCEDURE'+SUBSTRING(@current,26,LEN(@current));
        ELSE IF LEFT(@current,16) COLLATE Latin1_General_100_BIN2=N'CREATE PROCEDURE'
            SET @current=N'ALTER PROCEDURE'+SUBSTRING(@current,17,LEN(@current));
        SET @after=TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(@after,NCHAR(13)+NCHAR(10),NCHAR(10)));
        IF LEFT(@after,25) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE'
            SET @after=N'ALTER PROCEDURE'+SUBSTRING(@after,26,LEN(@after));
        ELSE IF LEFT(@after,16) COLLATE Latin1_General_100_BIN2=N'CREATE PROCEDURE'
            SET @after=N'ALTER PROCEDURE'+SUBSTRING(@after,17,LEN(@after));
        IF @current IS NULL OR CONVERT(varbinary(max),@current)<>CONVERT(varbinary(max),@after)
            THROW 51067, 'Summary postimage verification failed.', 1;
        FETCH NEXT FROM applyModules INTO @name,@after;
    END;
    CLOSE applyModules;
    DEALLOCATE applyModules;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
