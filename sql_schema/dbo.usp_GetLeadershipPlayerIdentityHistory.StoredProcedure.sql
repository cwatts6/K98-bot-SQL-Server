SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerIdentityHistory
    @GovernorIDs dbo.IntList READONLY,
    @HistoryDays smallint = 720
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @GovernorCount int = (SELECT COUNT(*) FROM @GovernorIDs);
    IF @GovernorCount < 1 OR @GovernorCount > 26
        THROW 51511, 'Leadership identity history requires between 1 and 26 Governor IDs.', 1;
    IF EXISTS (SELECT 1 FROM @GovernorIDs WHERE ID <= 0)
        THROW 51512, 'Leadership identity history received an invalid Governor ID.', 1;
    IF @HistoryDays < 1 OR @HistoryDays > 720
        THROW 51513, 'Leadership identity history is bounded to 1 through 720 days.', 1;

    DECLARE @AnchorDate date = (SELECT MAX(AsOfDate) FROM dbo.KingdomScanData4);
    DECLARE @StartDate date = DATEADD(DAY, 1 - @HistoryDays, @AnchorDate);

    /* Result set 1: aliases, normalized and grouped per Governor ID. */
    ;WITH AliasGroups AS
    (
        SELECT history_rows.GovernorID,
               dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName) AS GovernorNameKey,
               MIN(history_rows.FirstSeen) AS FirstSeen,
               MAX(history_rows.LastSeen) AS LastSeen,
               MAX(history_rows.SeenScanCount) AS SeenScanCount
        FROM dbo.GovernorNameHistory AS history_rows
        JOIN @GovernorIDs AS requested ON requested.ID = history_rows.GovernorID
        WHERE history_rows.LastSeen >= @StartDate
        GROUP BY history_rows.GovernorID,
                 dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName)
    )
    SELECT groups.GovernorID, display_name.GovernorName,
           groups.FirstSeen, groups.LastSeen, groups.SeenScanCount
    FROM AliasGroups AS groups
    CROSS APPLY
    (
        SELECT TOP (1) LTRIM(RTRIM(history_rows.GovernorName)) AS GovernorName
        FROM dbo.GovernorNameHistory AS history_rows
        WHERE history_rows.GovernorID = groups.GovernorID
          AND dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName)
              = groups.GovernorNameKey
        ORDER BY history_rows.LastSeen DESC, history_rows.GovernorName DESC
    ) AS display_name
    ORDER BY groups.GovernorID, groups.LastSeen DESC, display_name.GovernorName;

    CREATE TABLE #IdentityScans
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        AsOfDate date NOT NULL,
        ScanOrdinal int NULL
    );
    INSERT INTO #IdentityScans (ScanOrder, AsOfDate)
    SELECT TRY_CONVERT(bigint, SCANORDER), MAX(AsOfDate)
    FROM dbo.KingdomScanData4
    WHERE AsOfDate BETWEEN @StartDate AND @AnchorDate
    GROUP BY TRY_CONVERT(bigint, SCANORDER);
    ;WITH Ordered AS
    (
        SELECT ScanOrder, ROW_NUMBER() OVER (ORDER BY ScanOrder) AS ScanOrdinal
        FROM #IdentityScans
    )
    UPDATE scans SET ScanOrdinal = ordered.ScanOrdinal
    FROM #IdentityScans AS scans
    JOIN Ordered AS ordered ON ordered.ScanOrder = scans.ScanOrder;

    /* Result set 2: consecutive complete-scan alliance episodes. */
    ;WITH RankedRows AS
    (
        SELECT TRY_CONVERT(bigint, source.GovernorID) AS GovernorID,
               scans.ScanOrder, scans.ScanOrdinal, scans.AsOfDate,
               COALESCE(NULLIF(LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), source.Alliance))), 100), N''),
                        N'Unallied') AS AllianceDisplay,
               LOWER(COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), source.Alliance))), N''),
                              N'Unallied')) AS AllianceKey,
               ROW_NUMBER() OVER
               (PARTITION BY TRY_CONVERT(bigint, source.GovernorID), scans.ScanOrder
                ORDER BY source.ScanDate DESC, source.SCAN_UNO DESC) AS RowNumber
        FROM dbo.KingdomScanData4 AS source
        JOIN #IdentityScans AS scans
          ON scans.ScanOrder = TRY_CONVERT(bigint, source.SCANORDER)
        JOIN @GovernorIDs AS requested
          ON requested.ID = TRY_CONVERT(bigint, source.GovernorID)
    ),
    SelectedRows AS
    (
        SELECT * FROM RankedRows WHERE RowNumber = 1
    ),
    WithPrevious AS
    (
        SELECT *,
               LAG(ScanOrdinal) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousOrdinal,
               LAG(AllianceKey) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousAllianceKey
        FROM SelectedRows
    ),
    WithBreaks AS
    (
        SELECT *, CASE WHEN PreviousOrdinal IS NULL
                             OR PreviousOrdinal <> ScanOrdinal - 1
                             OR PreviousAllianceKey <> AllianceKey
                        THEN 1 ELSE 0 END AS StartsEpisode
        FROM WithPrevious
    ),
    Grouped AS
    (
        SELECT *, SUM(StartsEpisode) OVER
            (PARTITION BY GovernorID ORDER BY ScanOrdinal ROWS UNBOUNDED PRECEDING)
            AS EpisodeGroup
        FROM WithBreaks
    ),
    Episodes AS
    (
        SELECT GovernorID, EpisodeGroup,
               MAX(AllianceDisplay) AS Alliance,
               MIN(AsOfDate) AS FirstObservedDate,
               MAX(AsOfDate) AS LastObservedDate,
               MIN(ScanOrder) AS FirstScanOrder,
               MAX(ScanOrder) AS LastScanOrder,
               COUNT(*) AS ObservedScanCount
        FROM Grouped
        GROUP BY GovernorID, EpisodeGroup
    )
    SELECT GovernorID,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY LastScanOrder DESC) AS EpisodeSequence,
           Alliance, FirstObservedDate, LastObservedDate, ObservedScanCount,
           CONVERT(bit, CASE WHEN LastScanOrder = (SELECT MAX(ScanOrder) FROM #IdentityScans)
                             THEN 1 ELSE 0 END) AS IsCurrentEpisode
    FROM Episodes
    ORDER BY GovernorID, EpisodeSequence;
END;
