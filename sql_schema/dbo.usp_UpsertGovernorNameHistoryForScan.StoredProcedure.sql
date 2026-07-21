SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE OR ALTER PROCEDURE dbo.usp_UpsertGovernorNameHistoryForScan
    @ScanOrder bigint = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ScanOrder IS NULL
        SELECT @ScanOrder = MAX(TRY_CONVERT(bigint, SCANORDER)) FROM dbo.KingdomScanData4;
    IF @ScanOrder IS NULL OR @ScanOrder <= 0
        THROW 51201, 'Governor alias upsert requires a valid scan order.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.KingdomScanData4 WHERE SCANORDER = @ScanOrder)
        THROW 51202, 'Governor alias upsert scan order was not found.', 1;

    CREATE TABLE #AffectedAliases
    (
        GovernorID bigint NOT NULL,
        GovernorNameKey nvarchar(100) NOT NULL,
        PRIMARY KEY CLUSTERED (GovernorID, GovernorNameKey)
    );
    INSERT INTO #AffectedAliases
    SELECT DISTINCT TRY_CONVERT(bigint, GovernorID),
           dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), GovernorName))
    FROM dbo.KingdomScanData4
    WHERE SCANORDER = @ScanOrder AND TRY_CONVERT(bigint, GovernorID) > 0
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
        SELECT TRY_CONVERT(bigint, s.GovernorID) AS GovernorID,
               a.GovernorNameKey,
               LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), s.GovernorName))), 100) AS GovernorName,
               TRY_CONVERT(datetime2(0), s.ScanDate) AS ScanDate,
               TRY_CONVERT(bigint, s.SCANORDER) AS ScanOrder
        FROM dbo.KingdomScanData4 AS s
        JOIN #AffectedAliases AS a
          ON a.GovernorID = TRY_CONVERT(bigint, s.GovernorID)
         AND a.GovernorNameKey = dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), s.GovernorName))
    ),
    Aggregated AS
    (
        SELECT GovernorID, GovernorNameKey, MIN(ScanDate) AS FirstSeen,
               MAX(ScanDate) AS LastSeen, COUNT(DISTINCT ScanOrder) AS SeenScanCount
        FROM SourceRows
        WHERE GovernorName <> N'' AND ScanDate IS NOT NULL
        GROUP BY GovernorID, GovernorNameKey
    )
    INSERT INTO #ObservedAliases
    SELECT a.GovernorID, a.GovernorNameKey, latest.GovernorName,
           a.FirstSeen, a.LastSeen, a.SeenScanCount
    FROM Aggregated AS a
    CROSS APPLY
    (
        SELECT TOP (1) s.GovernorName
        FROM SourceRows AS s
        WHERE s.GovernorID = a.GovernorID AND s.GovernorNameKey = a.GovernorNameKey
        ORDER BY s.ScanDate DESC, s.ScanOrder DESC, s.GovernorName DESC
    ) AS latest;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE h
        SET FirstSeen = o.FirstSeen, LastSeen = o.LastSeen, SeenScanCount = o.SeenScanCount
        FROM dbo.GovernorNameHistory AS h
        JOIN #ObservedAliases AS o
          ON o.GovernorID = h.GovernorID
         AND o.GovernorNameKey = dbo.fn_NormalizeGovernorNameKey(h.GovernorName);
        INSERT INTO dbo.GovernorNameHistory
            (GovernorID, GovernorName, FirstSeen, LastSeen, SeenScanCount)
        SELECT o.GovernorID, o.GovernorName, o.FirstSeen, o.LastSeen, o.SeenScanCount
        FROM #ObservedAliases AS o
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.GovernorNameHistory AS h WITH (UPDLOCK, HOLDLOCK)
            WHERE h.GovernorID = o.GovernorID
              AND dbo.fn_NormalizeGovernorNameKey(h.GovernorName) = o.GovernorNameKey
        );
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
