/*
Purpose:
    Collect the deterministic material-value digest for a completed committed
    UPDATE_ALL2 benchmark run. SCAN_UNO is excluded from the digest because
    NEXT VALUE FOR assignment follows an unordered insert source and can map
    different surrogate values to otherwise identical governor rows.

Safety:
    - Read-only.
    - Refuses production and any database except the dedicated benchmark copy.
    - Requires exact final rows and scan 1021.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK';
DECLARE @ExpectedRows bigint = 394917;
DECLARE @ExpectedMaxScan bigint = 1021;
DECLARE @ExpectedLatestScanRows bigint = 411;

IF DB_NAME() <> @ExpectedDatabase
BEGIN
    THROW 51340,
        'Safety stop: connect to the exact committed-import benchmark database.',
        1;
END;

IF DB_NAME() = N'ROK_TRACKER'
BEGIN
    THROW 51341,
        'Safety stop: this collector refuses production ROK_TRACKER.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51342,
        'Run the material digest collector with no existing user transaction.',
        1;
END;

DECLARE
    @Rows bigint,
    @MaxScan bigint,
    @LatestRows bigint,
    @LatestDistinctGovernors bigint,
    @LatestDuplicateRows bigint,
    @LatestScanUnoMin int,
    @LatestScanUnoMax int,
    @LatestDistinctScanUno bigint,
    @CanonicalRows nvarchar(max),
    @MaterialDigest varbinary(32);

SELECT
    @Rows = COUNT_BIG(*),
    @MaxScan = MAX(TRY_CONVERT(bigint, SCANORDER))
FROM dbo.KingdomScanData4;

SELECT
    @LatestRows = COUNT_BIG(*),
    @LatestDistinctGovernors =
        COUNT_BIG(DISTINCT TRY_CONVERT(bigint, GovernorID)),
    @LatestScanUnoMin = MIN(SCAN_UNO),
    @LatestScanUnoMax = MAX(SCAN_UNO),
    @LatestDistinctScanUno = COUNT_BIG(DISTINCT SCAN_UNO)
FROM dbo.KingdomScanData4
WHERE TRY_CONVERT(bigint, SCANORDER) = @MaxScan;

SELECT
    @LatestDuplicateRows =
        COALESCE(SUM(duplicate_group.RowCount - 1), 0)
FROM
(
    SELECT COUNT_BIG(*) AS RowCount
    FROM dbo.KingdomScanData4
    WHERE TRY_CONVERT(bigint, SCANORDER) = @MaxScan
    GROUP BY TRY_CONVERT(bigint, GovernorID)
    HAVING COUNT_BIG(*) > 1
) AS duplicate_group;

IF @Rows <> @ExpectedRows
   OR @MaxScan <> @ExpectedMaxScan
   OR @LatestRows <> @ExpectedLatestScanRows
   OR @LatestDistinctGovernors <> @ExpectedLatestScanRows
   OR @LatestDuplicateRows <> 0
   OR @LatestDistinctScanUno <> @ExpectedLatestScanRows
BEGIN
    THROW 51343,
        'The completed benchmark state failed exact row/scan/surrogate preflight.',
        1;
END;

SELECT @CanonicalRows =
(
    SELECT row_hashes.RowDigest
    FROM
    (
        SELECT
            CONVERT(
                char(64),
                HASHBYTES(
                    'SHA2_256',
                    (
                        SELECT
                            source.PowerRank,
                            source.GovernorName,
                            source.GovernorID,
                            source.Alliance,
                            source.[Power],
                            source.KillPoints,
                            source.Deads,
                            source.T1_Kills,
                            source.T2_Kills,
                            source.T3_Kills,
                            source.T4_Kills,
                            source.T5_Kills,
                            source.[T4&T5_KILLS],
                            source.TOTAL_KILLS,
                            source.RSS_Gathered,
                            source.RSSAssistance,
                            source.Helps,
                            source.ScanDate,
                            source.SCANORDER,
                            source.[Troops Power],
                            source.[City Hall],
                            source.[Tech Power],
                            source.[Building Power],
                            source.[Commander Power],
                            source.AsOfDate,
                            source.HealedTroops,
                            source.RangedPoints,
                            source.Civilization,
                            source.KvKPlayed,
                            source.MostKvKKill,
                            source.MostKvKDead,
                            source.MostKvKHeal,
                            source.Acclaim,
                            source.HighestAcclaim,
                            source.AOOJoined,
                            source.AOOWon,
                            source.AOOAvgKill,
                            source.AOOAvgDead,
                            source.AOOAvgHeal,
                            source.Conduct,
                            source.AutarchTimes
                        FOR JSON PATH,
                            WITHOUT_ARRAY_WRAPPER,
                            INCLUDE_NULL_VALUES
                    )
                ),
                2
            ) AS RowDigest
        FROM dbo.KingdomScanData4 AS source
    ) AS row_hashes
    ORDER BY row_hashes.RowDigest
    FOR JSON PATH
);

SET @MaterialDigest =
    HASHBYTES('SHA2_256', COALESCE(@CanonicalRows, N'[]'));

SELECT
    N'committed_import_material_digest' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @Rows AS Ks4Rows,
    @MaxScan AS Ks4MaxScan,
    @LatestRows AS LatestScanRows,
    @LatestDistinctGovernors AS LatestScanDistinctGovernors,
    @LatestDuplicateRows AS LatestScanDuplicateRows,
    @LatestScanUnoMin AS LatestScanUnoMin,
    @LatestScanUnoMax AS LatestScanUnoMax,
    @LatestDistinctScanUno AS LatestScanDistinctScanUno,
    CONVERT(char(64), @MaterialDigest, 2)
        AS Ks4MaterialDigestExcludingScanUnoSha256,
    SYSUTCDATETIME() AS CollectedAtUtc;
