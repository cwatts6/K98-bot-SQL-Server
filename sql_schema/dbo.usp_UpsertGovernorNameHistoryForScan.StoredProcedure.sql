SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_UpsertGovernorNameHistoryForScan]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_UpsertGovernorNameHistoryForScan] AS' 
END
ALTER PROCEDURE [dbo].[usp_UpsertGovernorNameHistoryForScan]
	@ScanOrder [bigint] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ScanOrder IS NULL
        SELECT @ScanOrder = MAX(TRY_CONVERT(bigint, SCANORDER))
        FROM dbo.KingdomScanData4;
    IF @ScanOrder IS NULL OR @ScanOrder <= 0
        THROW 51201, 'Governor alias upsert requires a valid scan order.', 1;
    IF NOT EXISTS
        (SELECT 1 FROM dbo.KingdomScanData4 WHERE SCANORDER = @ScanOrder)
        THROW 51202, 'Governor alias upsert scan order was not found.', 1;

    CREATE TABLE #AffectedAliases
    (
        GovernorID bigint NOT NULL,
        GovernorNameKey nvarchar(100) NOT NULL,
        PRIMARY KEY CLUSTERED (GovernorID, GovernorNameKey)
    );

    INSERT INTO #AffectedAliases (GovernorID, GovernorNameKey)
    SELECT DISTINCT
        TRY_CONVERT(bigint, GovernorID),
        dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), GovernorName))
    FROM dbo.KingdomScanData4
    WHERE SCANORDER = @ScanOrder
      AND TRY_CONVERT(bigint, GovernorID) > 0
      AND dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), GovernorName)) IS NOT NULL;

    CREATE TABLE #ObservedAliases
    (
        GovernorID bigint NOT NULL,
        GovernorNameKey nvarchar(100) NOT NULL,
        GovernorName nvarchar(100) NOT NULL,
        FirstSeen datetime2(0) NOT NULL,
        LastSeen datetime2(0) NOT NULL,
        SeenScanCount int NOT NULL,
        PRIMARY KEY CLUSTERED (GovernorID, GovernorNameKey)
    );

    ;WITH SourceRows AS
    (
        SELECT
            TRY_CONVERT(bigint, scan_rows.GovernorID) AS GovernorID,
            affected.GovernorNameKey,
            LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), scan_rows.GovernorName))), 100) AS GovernorName,
            TRY_CONVERT(datetime2(0), scan_rows.ScanDate) AS ScanDate,
            TRY_CONVERT(bigint, scan_rows.SCANORDER) AS ScanOrder
        FROM dbo.KingdomScanData4 AS scan_rows
        JOIN #AffectedAliases AS affected
          ON affected.GovernorID = TRY_CONVERT(bigint, scan_rows.GovernorID)
         AND affected.GovernorNameKey =
             dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), scan_rows.GovernorName))
    ),
    Aggregated AS
    (
        SELECT GovernorID, GovernorNameKey,
               MIN(ScanDate) AS FirstSeen,
               MAX(ScanDate) AS LastSeen,
               COUNT(DISTINCT ScanOrder) AS SeenScanCount
        FROM SourceRows
        WHERE GovernorName <> N'' AND ScanDate IS NOT NULL
        GROUP BY GovernorID, GovernorNameKey
    )
    INSERT INTO #ObservedAliases
        (GovernorID, GovernorNameKey, GovernorName, FirstSeen, LastSeen, SeenScanCount)
    SELECT aggregated.GovernorID, aggregated.GovernorNameKey,
           latest_name.GovernorName, aggregated.FirstSeen,
           aggregated.LastSeen, aggregated.SeenScanCount
    FROM Aggregated AS aggregated
    CROSS APPLY
    (
        SELECT TOP (1) source.GovernorName
        FROM SourceRows AS source
        WHERE source.GovernorID = aggregated.GovernorID
          AND source.GovernorNameKey = aggregated.GovernorNameKey
        ORDER BY source.ScanDate DESC, source.ScanOrder DESC, source.GovernorName DESC
    ) AS latest_name;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE history_rows
        SET FirstSeen = observed.FirstSeen,
            LastSeen = observed.LastSeen,
            SeenScanCount = observed.SeenScanCount
        FROM dbo.GovernorNameHistory AS history_rows
        JOIN #ObservedAliases AS observed
          ON observed.GovernorID = history_rows.GovernorID
         AND observed.GovernorNameKey =
             dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName);

        INSERT INTO dbo.GovernorNameHistory
            (GovernorID, GovernorName, FirstSeen, LastSeen, SeenScanCount)
        SELECT observed.GovernorID, observed.GovernorName,
               observed.FirstSeen, observed.LastSeen, observed.SeenScanCount
        FROM #ObservedAliases AS observed
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.GovernorNameHistory AS history_rows WITH (UPDLOCK, HOLDLOCK)
            WHERE history_rows.GovernorID = observed.GovernorID
              AND dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName) =
                  observed.GovernorNameKey
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

