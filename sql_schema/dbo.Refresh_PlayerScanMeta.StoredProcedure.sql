SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Refresh_PlayerScanMeta]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[Refresh_PlayerScanMeta] AS' 
END
ALTER PROCEDURE [dbo].[Refresh_PlayerScanMeta]
	@FullRebuild [bit] = 0,
	@MinScanOrder [float] = NULL,
	@FromScanDate [date] = NULL,
	@BatchSize [int] = NULL,
	@StartingGovernorID [float] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#ScanDays') IS NULL
    BEGIN
        CREATE TABLE #ScanDays (
            ScanDate date NOT NULL PRIMARY KEY,
            DayIndex int NOT NULL
        );
    END

    IF @FullRebuild = 0 AND @MinScanOrder IS NULL AND @FromScanDate IS NULL
    BEGIN
        SELECT @FromScanDate = MAX(LastScanDate)
        FROM dbo.PlayerScanMeta;
    END

    IF @FullRebuild = 1 AND (@BatchSize IS NULL OR @BatchSize <= 0)
    BEGIN
        TRUNCATE TABLE dbo.PlayerScanMeta;

        TRUNCATE TABLE #ScanDays;

        ;WITH scan_bounds AS (
            SELECT
                MIN(ks.AsOfDate) AS MinScanDate,
                MAX(ks.AsOfDate) AS MaxScanDate
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
        ),
        scan_days AS (
            SELECT DISTINCT ks.AsOfDate AS ScanDate
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            CROSS JOIN scan_bounds sb
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
              AND ks.AsOfDate >= sb.MinScanDate
              AND ks.AsOfDate <= sb.MaxScanDate
        ),
        ordered_scan_days AS (
            SELECT
                sd.ScanDate,
                ROW_NUMBER() OVER (ORDER BY sd.ScanDate) AS DayIndex
            FROM scan_days sd
        )
        INSERT INTO #ScanDays (ScanDate, DayIndex)
        SELECT ScanDate, DayIndex
        FROM ordered_scan_days;

        ;WITH d AS (
            SELECT DISTINCT
                ks.GovernorID,
                ks.AsOfDate AS ScanDate,
                sd.DayIndex
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            INNER JOIN #ScanDays sd
                ON sd.ScanDate = ks.AsOfDate
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
        ),
        ordered AS (
            SELECT
                GovernorID,
                ScanDate,
                LAG(DayIndex) OVER (PARTITION BY GovernorID ORDER BY ScanDate) AS PrevDayIndex,
                DayIndex
            FROM d
        ),
        gaps AS (
            SELECT
                o.GovernorID,
                o.ScanDate,
                o.PrevDayIndex,
                MissedScanDays = CASE
                    WHEN o.PrevDayIndex IS NULL THEN 0
                    ELSE (o.DayIndex - o.PrevDayIndex - 1)
                END
            FROM ordered o
        ),
        meta AS (
            SELECT
                GovernorID,
                MIN(ScanDate) AS FirstScanDate,
                MAX(ScanDate) AS LastScanDate,
                SUM(CASE WHEN MissedScanDays > 30 THEN MissedScanDays ELSE 0 END) AS OfflineDaysOver30
            FROM gaps
            GROUP BY GovernorID
        ),
        orders AS (
            SELECT
                ks.GovernorID,
                MIN(ks.SCANORDER) AS FirstScanOrder,
                MAX(ks.SCANORDER) AS LastScanOrder
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
            GROUP BY ks.GovernorID
        )
        INSERT INTO dbo.PlayerScanMeta
        (
            GovernorID,
            FirstScanDate,
            LastScanDate,
            FirstScanOrder,
            LastScanOrder,
            OfflineDaysOver30,
            LastRefreshedUTC
        )
        SELECT
            m.GovernorID,
            m.FirstScanDate,
            m.LastScanDate,
            o.FirstScanOrder,
            o.LastScanOrder,
            m.OfflineDaysOver30,
            SYSUTCDATETIME()
        FROM meta m
        INNER JOIN orders o
            ON o.GovernorID = m.GovernorID;

        RETURN;
    END

    IF @FullRebuild = 1 AND (@BatchSize IS NOT NULL AND @BatchSize > 0)
    BEGIN
        IF @StartingGovernorID IS NULL
        BEGIN
            TRUNCATE TABLE dbo.PlayerScanMeta;
            SET @StartingGovernorID = 0;
        END
    END

    DECLARE @Continue bit = 1;
    DECLARE @LastGovernorID float = ISNULL(@StartingGovernorID, 0);

    WHILE @Continue = 1
    BEGIN
        IF OBJECT_ID('tempdb..#Governors') IS NOT NULL
            DROP TABLE #Governors;

        CREATE TABLE #Governors (GovernorID float NOT NULL PRIMARY KEY);

        INSERT INTO #Governors (GovernorID)
        SELECT TOP (CASE WHEN @BatchSize IS NULL OR @BatchSize <= 0 THEN 2147483647 ELSE @BatchSize END)
            g.GovernorID
        FROM (
            SELECT DISTINCT ks.GovernorID
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            WHERE ks.GovernorID IS NOT NULL
              AND ks.GovernorID <> 0
              AND (
                    @FullRebuild = 1
                 OR (@MinScanOrder IS NOT NULL AND ks.SCANORDER >= @MinScanOrder)
                 OR (@FromScanDate IS NOT NULL AND ks.ScanDate >= @FromScanDate)
              )
        ) AS g
        WHERE g.GovernorID > @LastGovernorID
        ORDER BY g.GovernorID;

        IF NOT EXISTS (SELECT 1 FROM #Governors)
        BEGIN
            SET @Continue = 0;
            BREAK;
        END

        SELECT @LastGovernorID = MAX(GovernorID)
        FROM #Governors;

        TRUNCATE TABLE #ScanDays;

        ;WITH scan_bounds AS (
            SELECT
                MIN(ks.AsOfDate) AS MinScanDate,
                MAX(ks.AsOfDate) AS MaxScanDate
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            INNER JOIN #Governors g
                ON g.GovernorID = ks.GovernorID
        ),
        scan_days AS (
            SELECT DISTINCT ks.AsOfDate AS ScanDate
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            CROSS JOIN scan_bounds sb
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
              AND ks.AsOfDate >= sb.MinScanDate
              AND ks.AsOfDate <= sb.MaxScanDate
        ),
        ordered_scan_days AS (
            SELECT
                sd.ScanDate,
                ROW_NUMBER() OVER (ORDER BY sd.ScanDate) AS DayIndex
            FROM scan_days sd
        )
        INSERT INTO #ScanDays (ScanDate, DayIndex)
        SELECT ScanDate, DayIndex
        FROM ordered_scan_days;

        ;WITH d AS (
            SELECT DISTINCT
                ks.GovernorID,
                ks.AsOfDate AS ScanDate,
                sd.DayIndex
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            INNER JOIN #Governors g
                ON g.GovernorID = ks.GovernorID
            INNER JOIN #ScanDays sd
                ON sd.ScanDate = ks.AsOfDate
        ),
        ordered AS (
            SELECT
                GovernorID,
                ScanDate,
                LAG(DayIndex) OVER (PARTITION BY GovernorID ORDER BY ScanDate) AS PrevDayIndex,
                DayIndex
            FROM d
        ),
        gaps AS (
            SELECT
                o.GovernorID,
                o.ScanDate,
                o.PrevDayIndex,
                MissedScanDays = CASE
                    WHEN o.PrevDayIndex IS NULL THEN 0
                    ELSE (o.DayIndex - o.PrevDayIndex - 1)
                END
            FROM ordered o
        ),
        meta AS (
            SELECT
                GovernorID,
                MIN(ScanDate) AS FirstScanDate,
                MAX(ScanDate) AS LastScanDate,
                SUM(CASE WHEN MissedScanDays > 30 THEN MissedScanDays ELSE 0 END) AS OfflineDaysOver30
            FROM gaps
            GROUP BY GovernorID
        ),
        orders AS (
            SELECT
                ks.GovernorID,
                MIN(ks.SCANORDER) AS FirstScanOrder,
                MAX(ks.SCANORDER) AS LastScanOrder
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            INNER JOIN #Governors g
                ON g.GovernorID = ks.GovernorID
            GROUP BY ks.GovernorID
        )
        MERGE dbo.PlayerScanMeta AS target
        USING (
            SELECT
                m.GovernorID,
                m.FirstScanDate,
                m.LastScanDate,
                o.FirstScanOrder,
                o.LastScanOrder,
                m.OfflineDaysOver30
            FROM meta m
            INNER JOIN orders o
                ON o.GovernorID = m.GovernorID
        ) AS source
        ON target.GovernorID = source.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                FirstScanDate = source.FirstScanDate,
                LastScanDate = source.LastScanDate,
                FirstScanOrder = source.FirstScanOrder,
                LastScanOrder = source.LastScanOrder,
                OfflineDaysOver30 = source.OfflineDaysOver30,
                LastRefreshedUTC = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (
                GovernorID,
                FirstScanDate,
                LastScanDate,
                FirstScanOrder,
                LastScanOrder,
                OfflineDaysOver30,
                LastRefreshedUTC
            )
            VALUES (
                source.GovernorID,
                source.FirstScanDate,
                source.LastScanDate,
                source.FirstScanOrder,
                source.LastScanOrder,
                source.OfflineDaysOver30,
                SYSUTCDATETIME()
            );

        IF @BatchSize IS NULL OR @BatchSize <= 0
        BEGIN
            SET @Continue = 0;
        END
    END
END;

