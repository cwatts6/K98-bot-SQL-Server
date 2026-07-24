SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_GetLeadershipPlayerLookupDirectory]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_GetLeadershipPlayerLookupDirectory] AS' 
END
ALTER PROCEDURE [dbo].[usp_GetLeadershipPlayerLookupDirectory]
	@HistoryDays [smallint] = 720
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
        SELECT history_rows.GovernorID,
               dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName) AS GovernorNameKey,
               MIN(history_rows.FirstSeen) AS FirstSeen,
               MAX(history_rows.LastSeen) AS LastSeen,
               MAX(history_rows.SeenScanCount) AS SeenScanCount
        FROM dbo.GovernorNameHistory AS history_rows
        WHERE history_rows.LastSeen >= @HistoryStart
        GROUP BY history_rows.GovernorID,
                 dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName)
    ),
    RelevantGovernors AS
    (
        SELECT DISTINCT GovernorID FROM AliasGroups
    ),
    RankedLatest AS
    (
        SELECT TRY_CONVERT(bigint, scan_rows.GovernorID) AS GovernorID,
               LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), scan_rows.GovernorName))), 100)
                   AS CurrentGovernorName,
               LEFT(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), scan_rows.Alliance))), N''), 100)
                   AS CurrentAlliance,
               TRY_CONVERT(datetime2(0), scan_rows.ScanDate) AS LastGovernorScanAtUtc,
               TRY_CONVERT(bigint, scan_rows.SCANORDER) AS LastGovernorScanOrder,
               ROW_NUMBER() OVER
               (
                   PARTITION BY TRY_CONVERT(bigint, scan_rows.GovernorID)
                   ORDER BY scan_rows.SCANORDER DESC, scan_rows.ScanDate DESC,
                            scan_rows.SCAN_UNO DESC
               ) AS RowNumber
        FROM dbo.KingdomScanData4 AS scan_rows
        JOIN RelevantGovernors AS relevant
          ON relevant.GovernorID = TRY_CONVERT(bigint, scan_rows.GovernorID)
        WHERE scan_rows.AsOfDate >= @HistoryStart
    ),
    Latest AS
    (
        SELECT * FROM RankedLatest WHERE RowNumber = 1
    )
    SELECT aliases.GovernorID,
           display_name.GovernorName,
           aliases.GovernorNameKey,
           aliases.FirstSeen,
           aliases.LastSeen,
           aliases.SeenScanCount,
           latest.CurrentGovernorName,
           latest.CurrentAlliance,
           latest.LastGovernorScanAtUtc,
           CONVERT(bit, CASE WHEN latest.LastGovernorScanOrder = @LatestScanOrder THEN 1 ELSE 0 END)
               AS PresentInLatestCompleteScan,
           CONVERT(bit, CASE WHEN aliases.GovernorNameKey =
                                  dbo.fn_NormalizeGovernorNameKey(latest.CurrentGovernorName)
                             THEN 1 ELSE 0 END) AS IsCurrentName
    FROM AliasGroups AS aliases
    JOIN Latest AS latest ON latest.GovernorID = aliases.GovernorID
    CROSS APPLY
    (
        SELECT TOP (1) LEFT(LTRIM(RTRIM(history_rows.GovernorName)), 100) AS GovernorName
        FROM dbo.GovernorNameHistory AS history_rows
        WHERE history_rows.GovernorID = aliases.GovernorID
          AND dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName) =
              aliases.GovernorNameKey
        ORDER BY history_rows.LastSeen DESC, history_rows.GovernorName DESC
    ) AS display_name
    ORDER BY aliases.GovernorID, IsCurrentName DESC, aliases.LastSeen DESC,
             display_name.GovernorName;
END;

