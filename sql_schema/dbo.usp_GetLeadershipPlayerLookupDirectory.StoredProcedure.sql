SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerLookupDirectory
    @HistoryDays smallint = 720
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @HistoryDays < 1 OR @HistoryDays > 720
        THROW 51541, 'Leadership lookup history is bounded to 1 through 720 days.', 1;

    DECLARE @AnchorDate date = (SELECT MAX(AsOfDate) FROM dbo.KingdomScanData4);
    DECLARE @HistoryStart date = DATEADD(DAY, 1 - @HistoryDays, @AnchorDate);
    DECLARE @LatestScanOrder bigint =
        (SELECT MAX(TRY_CONVERT(bigint, SCANORDER))
         FROM dbo.KingdomScanData4 WHERE AsOfDate = @AnchorDate);

    ;WITH AliasGroups AS
    (
        SELECT h.GovernorID,
               dbo.fn_NormalizeGovernorNameKey(h.GovernorName) AS GovernorNameKey,
               MIN(h.FirstSeen) AS FirstSeen, MAX(h.LastSeen) AS LastSeen,
               MAX(h.SeenScanCount) AS SeenScanCount
        FROM dbo.GovernorNameHistory AS h
        WHERE h.LastSeen >= @HistoryStart
        GROUP BY h.GovernorID, dbo.fn_NormalizeGovernorNameKey(h.GovernorName)
    ),
    RelevantGovernors AS
    (
        SELECT DISTINCT GovernorID FROM AliasGroups
    ),
    RankedLatest AS
    (
        SELECT TRY_CONVERT(bigint, s.GovernorID) AS GovernorID,
               LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), s.GovernorName))), 100) AS CurrentGovernorName,
               LEFT(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), s.Alliance))), N''), 100) AS CurrentAlliance,
               TRY_CONVERT(datetime2(0), s.ScanDate) AS LastGovernorScanAtUtc,
               TRY_CONVERT(bigint, s.SCANORDER) AS LastGovernorScanOrder,
               ROW_NUMBER() OVER
               (PARTITION BY TRY_CONVERT(bigint, s.GovernorID)
                ORDER BY s.SCANORDER DESC, s.ScanDate DESC, s.SCAN_UNO DESC) AS RowNumber
        FROM dbo.KingdomScanData4 AS s
        JOIN RelevantGovernors AS r
          ON r.GovernorID = TRY_CONVERT(bigint, s.GovernorID)
        WHERE s.AsOfDate >= @HistoryStart
    ),
    Latest AS
    (
        SELECT * FROM RankedLatest WHERE RowNumber = 1
    )
    SELECT a.GovernorID, d.GovernorName, a.GovernorNameKey,
           a.FirstSeen, a.LastSeen, a.SeenScanCount,
           l.CurrentGovernorName, l.CurrentAlliance, l.LastGovernorScanAtUtc,
           CONVERT(bit, CASE WHEN l.LastGovernorScanOrder = @LatestScanOrder THEN 1 ELSE 0 END)
               AS PresentInLatestCompleteScan,
           CONVERT(bit, CASE WHEN a.GovernorNameKey =
                                  dbo.fn_NormalizeGovernorNameKey(l.CurrentGovernorName)
                             THEN 1 ELSE 0 END) AS IsCurrentName
    FROM AliasGroups AS a
    JOIN Latest AS l ON l.GovernorID = a.GovernorID
    CROSS APPLY
    (
        SELECT TOP (1) LEFT(LTRIM(RTRIM(h.GovernorName)), 100) AS GovernorName
        FROM dbo.GovernorNameHistory AS h
        WHERE h.GovernorID = a.GovernorID
          AND dbo.fn_NormalizeGovernorNameKey(h.GovernorName) = a.GovernorNameKey
        ORDER BY h.LastSeen DESC, h.GovernorName DESC
    ) AS d
    ORDER BY a.GovernorID, IsCurrentName DESC, a.LastSeen DESC, d.GovernorName;
END
GO
