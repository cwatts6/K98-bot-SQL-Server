/*
MigrationId: 20260719_003_add_governor_name_history_observations
Purpose: Add first/last/count alias evidence and an idempotent post-scan upsert contract
Author: cwatts
CreatedUtc: 2026-07-19
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Required
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: Existing GovernorNameHistory rows plus distinct observed aliases in KingdomScanData4
PreValidationQuery: SELECT COUNT(*) AS ExistingAliases FROM dbo.GovernorNameHistory; SELECT COUNT(DISTINCT TRY_CONVERT(bigint, GovernorID)) AS Governors FROM dbo.KingdomScanData4;
PostValidationQuery: SELECT COUNT(*) AS Aliases, MIN(FirstSeen) AS Earliest, MAX(LastSeen) AS Latest, MIN(SeenScanCount) AS MinimumSeenScanCount FROM dbo.GovernorNameHistory;
RelatedBotPR:
RelatedSQLPR:

Data safety:
- The backfill is derived only from authoritative KingdomScanData4 observations.
- Existing rows without a matching scan observation retain FirstSeen as LastSeen and count one.
- Existing duplicate normalized display rows are not destructively removed; read contracts group them.
- Rerunning the upsert recomputes MIN/MAX/COUNT DISTINCT rather than incrementing counters.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION dbo.fn_NormalizeGovernorNameKey
(
    @GovernorName nvarchar(255)
)
RETURNS nvarchar(100)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @Normalized nvarchar(255);
    SET @Normalized = REPLACE(REPLACE(REPLACE(REPLACE(
        COALESCE(@GovernorName, N''), NCHAR(9), N' '), NCHAR(10), N' '),
        NCHAR(13), N' '), NCHAR(160), N' ');
    SET @Normalized = LTRIM(RTRIM(@Normalized));
    WHILE CHARINDEX(N'  ', @Normalized) > 0
        SET @Normalized = REPLACE(@Normalized, N'  ', N' ');
    SET @Normalized = LOWER(@Normalized);
    RETURN NULLIF(LEFT(@Normalized, 100), N'');
END;
GO

IF COL_LENGTH(N'dbo.GovernorNameHistory', N'LastSeen') IS NULL
    ALTER TABLE dbo.GovernorNameHistory ADD LastSeen datetime2(0) NULL;
IF COL_LENGTH(N'dbo.GovernorNameHistory', N'SeenScanCount') IS NULL
    ALTER TABLE dbo.GovernorNameHistory ADD SeenScanCount int NULL;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.GovernorNameHistory
    SET LastSeen = COALESCE(LastSeen, FirstSeen),
        SeenScanCount = COALESCE(SeenScanCount, 1)
    WHERE LastSeen IS NULL OR SeenScanCount IS NULL;

    IF OBJECT_ID(N'tempdb..#ObservedAliases') IS NOT NULL DROP TABLE #ObservedAliases;
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
            TRY_CONVERT(bigint, GovernorID) AS GovernorID,
            dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), GovernorName)) AS GovernorNameKey,
            LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), GovernorName))), 100) AS GovernorName,
            TRY_CONVERT(datetime2(0), ScanDate) AS ScanDate,
            TRY_CONVERT(bigint, SCANORDER) AS ScanOrder
        FROM dbo.KingdomScanData4
        WHERE TRY_CONVERT(bigint, GovernorID) > 0
    ),
    ValidRows AS
    (
        SELECT * FROM SourceRows
        WHERE GovernorNameKey IS NOT NULL AND GovernorName <> N'' AND ScanDate IS NOT NULL
    ),
    Aggregated AS
    (
        SELECT GovernorID, GovernorNameKey,
               MIN(ScanDate) AS FirstSeen,
               MAX(ScanDate) AS LastSeen,
               COUNT(DISTINCT ScanOrder) AS SeenScanCount
        FROM ValidRows
        GROUP BY GovernorID, GovernorNameKey
    )
    INSERT INTO #ObservedAliases
        (GovernorID, GovernorNameKey, GovernorName, FirstSeen, LastSeen, SeenScanCount)
    SELECT
        aggregate_rows.GovernorID,
        aggregate_rows.GovernorNameKey,
        latest_name.GovernorName,
        aggregate_rows.FirstSeen,
        aggregate_rows.LastSeen,
        aggregate_rows.SeenScanCount
    FROM Aggregated AS aggregate_rows
    CROSS APPLY
    (
        SELECT TOP (1) source.GovernorName
        FROM ValidRows AS source
        WHERE source.GovernorID = aggregate_rows.GovernorID
          AND source.GovernorNameKey = aggregate_rows.GovernorNameKey
        ORDER BY source.ScanDate DESC, source.ScanOrder DESC, source.GovernorName DESC
    ) AS latest_name;

    UPDATE history_rows
    SET FirstSeen = CASE WHEN observed.FirstSeen < history_rows.FirstSeen
                         THEN observed.FirstSeen ELSE history_rows.FirstSeen END,
        LastSeen = CASE WHEN observed.LastSeen > history_rows.LastSeen
                       THEN observed.LastSeen ELSE history_rows.LastSeen END,
        SeenScanCount = CASE WHEN observed.SeenScanCount > history_rows.SeenScanCount
                             THEN observed.SeenScanCount ELSE history_rows.SeenScanCount END
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
        FROM dbo.GovernorNameHistory AS history_rows
        WHERE history_rows.GovernorID = observed.GovernorID
          AND dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName) =
              observed.GovernorNameKey
    );

    ALTER TABLE dbo.GovernorNameHistory ALTER COLUMN LastSeen datetime2(0) NOT NULL;
    ALTER TABLE dbo.GovernorNameHistory ALTER COLUMN SeenScanCount int NOT NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpsertGovernorNameHistoryForScan
    @ScanOrder bigint = NULL
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
GO
