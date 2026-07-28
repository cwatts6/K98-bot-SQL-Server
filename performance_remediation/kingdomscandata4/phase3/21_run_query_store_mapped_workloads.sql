/*
Purpose:
    Execute the two Phase 3 Query Store scenarios not covered by the standard
    controlled benchmark: pinned leadership review and accounts-DAL materialization.

Run:
    One warm-up plus five measured executions on the isolated rehearsal copy.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52240, 'Query Store workload rehearsal is restricted to the Phase 3 database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52241, 'Query Store workload rehearsal requires no open transaction.', 1;

DECLARE @Results table
(
    WorkloadName sysname NOT NULL,
    RunKind nvarchar(16) NOT NULL,
    RunNumber int NOT NULL,
    DurationMilliseconds bigint NOT NULL,
    ResultRowCount bigint NULL,
    ResultDigest char(64) NULL
);

DECLARE @RunNumber int = 0;
DECLARE @StartedAt datetime2(7);

WHILE @RunNumber <= 5
BEGIN
    SET @StartedAt = SYSUTCDATETIME();

    EXEC dbo.usp_GetLeadershipPlayerReview
        @GovernorID = 2441482,
        @PeriodDays = 90,
        @NowUtc = '2026-07-23T09:55:00';

    INSERT @Results
    (
        WorkloadName,
        RunKind,
        RunNumber,
        DurationMilliseconds
    )
    VALUES
    (
        N'usp_GetLeadershipPlayerReview',
        CASE WHEN @RunNumber = 0 THEN N'warmup' ELSE N'measured' END,
        @RunNumber,
        DATEDIFF_BIG(millisecond, @StartedAt, SYSUTCDATETIME())
    );

    SET @RunNumber += 1;
END;

SET @RunNumber = 0;

WHILE @RunNumber <= 5
BEGIN
    DROP TABLE IF EXISTS #AccountsResult;
    SET @StartedAt = SYSUTCDATETIME();

    ;WITH Requested(GovernorID) AS
    (
        SELECT CAST(v.GovernorID AS bigint)
        FROM
        (
            VALUES
                (2352446),
                (154112523),
                (2441482),
                (228689487),
                (583354)
        ) AS v(GovernorID)
    ),
    GlobalLatest AS
    (
        SELECT MAX(s.ScanDate) AS LatestScanDate
        FROM dbo.KingdomScanData4 AS s WITH (NOLOCK)
    ),
    Ranked AS
    (
        SELECT
            TRY_CONVERT(bigint, s.GovernorID) AS GovernorID,
            NULLIF(LTRIM(RTRIM(s.GovernorName)), '') AS GovernorName,
            NULLIF(LTRIM(RTRIM(s.Civilization)), '') AS RawCivilisation,
            TRY_CONVERT(int, s.[City Hall]) AS CityHall,
            TRY_CONVERT(bigint, s.Power) AS Power,
            TRY_CONVERT(bigint, s.[Troops Power]) AS TroopPower,
            TRY_CONVERT(bigint, s.KillPoints) AS KillPoints,
            TRY_CONVERT(bigint, s.T4_Kills) AS T4Kills,
            TRY_CONVERT(bigint, s.T5_Kills) AS T5Kills,
            TRY_CONVERT(bigint, s.Deads) AS Deads,
            TRY_CONVERT(bigint, s.HealedTroops) AS HealedTroops,
            TRY_CONVERT(bigint, s.HighestAcclaim) AS HighestAcclaim,
            TRY_CONVERT(bigint, s.Helps) AS Helps,
            TRY_CONVERT(bigint, s.RSS_Gathered) AS RSSGathered,
            TRY_CONVERT(bigint, s.RSSAssistance) AS RSSAssistance,
            s.Conduct,
            s.ScanDate,
            ROW_NUMBER() OVER
            (
                PARTITION BY TRY_CONVERT(bigint, s.GovernorID)
                ORDER BY s.ScanDate DESC, s.SCANORDER DESC, s.AsOfDate DESC
            ) AS rn
        FROM dbo.KingdomScanData4 AS s WITH (NOLOCK)
        INNER JOIN Requested AS r
          ON r.GovernorID = TRY_CONVERT(bigint, s.GovernorID)
    )
    SELECT
        r.GovernorID AS RequestedGovernorID,
        ranked.GovernorName,
        COALESCE(NULLIF(cm.Civilization_Name, ''), ranked.RawCivilisation)
            AS Civilisation,
        ranked.CityHall,
        profile.VipLevelCode,
        NULLIF(LTRIM(RTRIM(profile.VipLevelLabel)), '') AS VipLevelLabel,
        ranked.Power,
        ranked.TroopPower,
        ranked.KillPoints,
        ranked.T4Kills,
        ranked.T5Kills,
        ranked.Deads,
        ranked.HealedTroops,
        ranked.HighestAcclaim,
        ranked.Helps,
        ranked.RSSGathered,
        ranked.RSSAssistance,
        ranked.Conduct,
        pl.X AS LocationX,
        pl.Y AS LocationY,
        ranked.ScanDate,
        global_scan.LatestScanDate
    INTO #AccountsResult
    FROM Requested AS r
    CROSS JOIN GlobalLatest AS global_scan
    LEFT JOIN Ranked AS ranked
      ON ranked.GovernorID = r.GovernorID
     AND ranked.rn = 1
    LEFT JOIN dbo.Civilization_Mapping AS cm WITH (NOLOCK)
      ON cm.Civilization = TRY_CONVERT(int, NULLIF(ranked.RawCivilisation, ''))
    LEFT JOIN dbo.PlayerLocation AS pl WITH (NOLOCK)
      ON pl.GovernorID = r.GovernorID
    LEFT JOIN dbo.GovernorInventoryProfile AS profile WITH (NOLOCK)
      ON profile.GovernorID = r.GovernorID;

    DECLARE @AccountsJson nvarchar(max) =
    (
        SELECT *
        FROM #AccountsResult
        ORDER BY RequestedGovernorID
        FOR JSON PATH, INCLUDE_NULL_VALUES
    );

    INSERT @Results
    (
        WorkloadName,
        RunKind,
        RunNumber,
        DurationMilliseconds,
        ResultRowCount,
        ResultDigest
    )
    SELECT
        N'accounts_dal_latest_scan_rows',
        CASE WHEN @RunNumber = 0 THEN N'warmup' ELSE N'measured' END,
        @RunNumber,
        DATEDIFF_BIG(millisecond, @StartedAt, SYSUTCDATETIME()),
        COUNT_BIG(*),
        CONVERT(char(64), HASHBYTES('SHA2_256', @AccountsJson), 2)
    FROM #AccountsResult;

    SET @RunNumber += 1;
END;

IF (SELECT COUNT(*) FROM @Results WHERE WorkloadName = N'usp_GetLeadershipPlayerReview') <> 6
   OR (SELECT COUNT(*) FROM @Results WHERE WorkloadName = N'accounts_dal_latest_scan_rows') <> 6
   OR EXISTS
      (
          SELECT 1
          FROM @Results
          WHERE WorkloadName = N'accounts_dal_latest_scan_rows'
            AND ResultRowCount <> 5
      )
   OR
      (
          SELECT COUNT(DISTINCT ResultDigest)
          FROM @Results
          WHERE WorkloadName = N'accounts_dal_latest_scan_rows'
      ) <> 1
BEGIN
    THROW 52242, 'A Query Store mapped workload was incomplete or unstable.', 1;
END;

SELECT
    N'query_store_mapped_workload' AS EvidenceSection,
    WorkloadName,
    RunKind,
    RunNumber,
    DurationMilliseconds,
    ResultRowCount,
    ResultDigest,
    N'PASS' AS WorkloadStatus
FROM @Results
ORDER BY WorkloadName, RunNumber;
