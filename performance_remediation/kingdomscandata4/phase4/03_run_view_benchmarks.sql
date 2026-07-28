/*
KingdomScanData4 Phase 4 controlled view benchmark.

Runs one warm-up plus five measured complete materializations for the mandatory
13-view set. It does not clear caches or mutate persistent data.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;

DECLARE @Views TABLE
(
    SequenceNo int NOT NULL PRIMARY KEY,
    ViewName sysname NOT NULL UNIQUE
);

INSERT @Views (SequenceNo, ViewName)
VALUES
    (10, N'v_Active_Players'),
    (20, N'v_GovernorNames'),
    (30, N'v_KVK_Under50_Last3_WithLatest'),
    (40, N'v_MGE_SignupReview'),
    (50, N'v_PlayerLatestStats'),
    (60, N'vDaily_Helps'),
    (70, N'vDaily_PlayerExport'),
    (80, N'vDaily_RSSAssisted'),
    (90, N'vDaily_RSSGathered'),
    (100, N'vWTD_Helps'),
    (110, N'vWTD_RSSAssisted'),
    (120, N'vWTD_RSSGathered'),
    (130, N'vw_Governor_KVK_Summary_GlobalLatest');

IF EXISTS
(
    SELECT 1
    FROM @Views
    WHERE OBJECT_ID(N'dbo.' + ViewName, N'V') IS NULL
)
    THROW 52200, 'Phase 4 benchmark found a missing mandatory view.', 1;

CREATE TABLE #Results
(
    SequenceNo int NOT NULL,
    ViewName sysname NOT NULL,
    RunKind nvarchar(16) NOT NULL,
    RunNumber tinyint NOT NULL,
    StartedAtUtc datetime2(7) NOT NULL,
    DurationMs decimal(19,3) NOT NULL,
    CpuMs bigint NOT NULL,
    LogicalReads bigint NOT NULL,
    Writes bigint NOT NULL,
    [RowCount] bigint NOT NULL,
    ResultDigest char(64) NOT NULL
);

DECLARE
    @SequenceNo int,
    @ViewName sysname,
    @RunNumber tinyint,
    @Sql nvarchar(max),
    @StartedAtUtc datetime2(7),
    @FinishedAtUtc datetime2(7),
    @CpuStart bigint,
    @CpuEnd bigint,
    @ReadsStart bigint,
    @ReadsEnd bigint,
    @WritesStart bigint,
    @WritesEnd bigint,
    @RowCount bigint,
    @Digest varbinary(32);

DECLARE ViewCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT SequenceNo, ViewName
    FROM @Views
    ORDER BY SequenceNo;

OPEN ViewCursor;
FETCH NEXT FROM ViewCursor INTO @SequenceNo, @ViewName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @RunNumber = 0;

    WHILE @RunNumber <= 5
    BEGIN
        SELECT
            @CpuStart = cpu_time,
            @ReadsStart = logical_reads,
            @WritesStart = writes
        FROM sys.dm_exec_requests
        WHERE session_id = @@SPID;

        SET @StartedAtUtc = SYSUTCDATETIME();
        SET @Sql =
            N'SELECT materialized.* INTO #Phase4Materialized'
            + N' FROM dbo.' + QUOTENAME(@ViewName) + N' AS materialized;'
            + N'
SELECT @RowCount = COUNT_BIG(*) FROM #Phase4Materialized;
DECLARE @CanonicalRows nvarchar(max);
SELECT @CanonicalRows =
(
    SELECT row_hashes.RowDigest
    FROM
    (
        SELECT
            CONVERT(
                char(64),
                HASHBYTES(
                    ''SHA2_256'',
                    (
                        SELECT materialized.*
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                    )
                ),
                2
            ) AS RowDigest
        FROM #Phase4Materialized AS materialized
    ) AS row_hashes
    ORDER BY row_hashes.RowDigest
    FOR JSON PATH
);
SET @Digest = HASHBYTES(''SHA2_256'', COALESCE(@CanonicalRows, N''[]''));
DROP TABLE #Phase4Materialized;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RowCount bigint OUTPUT, @Digest varbinary(32) OUTPUT',
            @RowCount = @RowCount OUTPUT,
            @Digest = @Digest OUTPUT;

        SET @FinishedAtUtc = SYSUTCDATETIME();

        SELECT
            @CpuEnd = cpu_time,
            @ReadsEnd = logical_reads,
            @WritesEnd = writes
        FROM sys.dm_exec_requests
        WHERE session_id = @@SPID;

        INSERT #Results
        (
            SequenceNo,
            ViewName,
            RunKind,
            RunNumber,
            StartedAtUtc,
            DurationMs,
            CpuMs,
            LogicalReads,
            Writes,
            [RowCount],
            ResultDigest
        )
        VALUES
        (
            @SequenceNo,
            @ViewName,
            CASE WHEN @RunNumber = 0 THEN N'warmup' ELSE N'measured' END,
            @RunNumber,
            @StartedAtUtc,
            CONVERT(
                decimal(19,3),
                DATEDIFF_BIG(MICROSECOND, @StartedAtUtc, @FinishedAtUtc) / 1000.0
            ),
            @CpuEnd - @CpuStart,
            @ReadsEnd - @ReadsStart,
            @WritesEnd - @WritesStart,
            @RowCount,
            CONVERT(char(64), @Digest, 2)
        );

        SET @RunNumber += 1;
    END;

    FETCH NEXT FROM ViewCursor INTO @SequenceNo, @ViewName;
END;

CLOSE ViewCursor;
DEALLOCATE ViewCursor;

SELECT
    N'benchmark_result' AS EvidenceSection,
    ViewName,
    RunKind,
    RunNumber,
    StartedAtUtc,
    DurationMs,
    CpuMs,
    LogicalReads,
    Writes,
    [RowCount],
    ResultDigest
FROM #Results
ORDER BY SequenceNo, RunNumber;

;WITH Measured AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY ViewName
            ORDER BY DurationMs
        ) AS DurationRank
    FROM #Results
    WHERE RunKind = N'measured'
)
SELECT
    N'benchmark_summary' AS EvidenceSection,
    ViewName,
    MAX(CASE WHEN DurationRank = 3 THEN DurationMs END) AS MedianDurationMs,
    AVG(DurationMs) AS AverageDurationMs,
    AVG(CONVERT(decimal(19,3), CpuMs)) AS AverageCpuMs,
    AVG(CONVERT(decimal(19,3), LogicalReads)) AS AverageLogicalReads,
    AVG(CONVERT(decimal(19,3), Writes)) AS AverageWrites,
    MIN([RowCount]) AS MinRows,
    MAX([RowCount]) AS MaxRows,
    COUNT(DISTINCT ResultDigest) AS DistinctDigests,
    CASE
        WHEN MIN([RowCount]) = MAX([RowCount])
         AND COUNT(DISTINCT ResultDigest) = 1
        THEN N'STABLE'
        ELSE N'UNSTABLE'
    END AS Stability
FROM Measured
GROUP BY ViewName
ORDER BY MIN(SequenceNo);

IF EXISTS
(
    SELECT 1
    FROM #Results
    WHERE RunKind = N'measured'
    GROUP BY ViewName
    HAVING MIN([RowCount]) <> MAX([RowCount])
        OR COUNT(DISTINCT ResultDigest) <> 1
)
    THROW 52201, 'Phase 4 benchmark found unstable rows or normalized digests.', 1;
