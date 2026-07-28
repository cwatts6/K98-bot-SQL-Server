/*
KingdomScanData4 Phase 4 read-only preflight and baseline capture.

Run on the accepted Phase 3 representative database before the Phase 4
migration. Production execution is not authorized by this script.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
    THROW 52100, 'Phase 4 preflight requires the accepted Phase 3 contracts.', 1;

IF EXISTS
(
    SELECT expected.ColumnName
    FROM
    (
        VALUES
            (N'GovernorID', TYPE_ID(N'bigint')),
            (N'PowerRank', TYPE_ID(N'int')),
            (N'Power', TYPE_ID(N'bigint')),
            (N'KillPoints', TYPE_ID(N'bigint')),
            (N'Deads', TYPE_ID(N'bigint')),
            (N'T4_Kills', TYPE_ID(N'bigint')),
            (N'T5_Kills', TYPE_ID(N'bigint')),
            (N'T4&T5_KILLS', TYPE_ID(N'bigint')),
            (N'RSS_Gathered', TYPE_ID(N'bigint')),
            (N'RSSAssistance', TYPE_ID(N'bigint')),
            (N'Helps', TYPE_ID(N'bigint')),
            (N'SCANORDER', TYPE_ID(N'int'))
    ) AS expected(ColumnName, TypeId)
    LEFT JOIN sys.columns AS actual
      ON actual.object_id = OBJECT_ID(N'dbo.KingdomScanData4')
     AND actual.name = expected.ColumnName
     AND actual.system_type_id = expected.TypeId
     AND actual.user_type_id = expected.TypeId
    WHERE actual.column_id IS NULL
)
    THROW 52101, 'Phase 4 preflight found an unexpected KingdomScanData4 source type.', 1;

DECLARE @Views TABLE
(
    SequenceNo int NOT NULL PRIMARY KEY,
    ViewName sysname NOT NULL UNIQUE,
    ChangeDecision nvarchar(40) NOT NULL,
    OrderingContract nvarchar(400) NOT NULL
);

INSERT @Views (SequenceNo, ViewName, ChangeDecision, OrderingContract)
VALUES
    (10, N'v_Active_Players', N'change', N'No view order; consumers must order explicitly.'),
    (20, N'v_GovernorNames', N'validation_only', N'No view order; latest-row choice is SCANORDER, AsOfDate, ScanDate descending.'),
    (30, N'v_KVK_Under50_Last3_WithLatest', N'validation_only', N'No view order; latest location and scan are selected explicitly.'),
    (40, N'v_MGE_SignupReview', N'change', N'No view order; consumer ordering is external.'),
    (50, N'v_PlayerLatestStats', N'validation_only', N'No view order; maximum SCANORDER is selected per governor.'),
    (60, N'vDaily_Helps', N'validation_only', N'No view order; latest date and positive daily deltas only.'),
    (70, N'vDaily_PlayerExport', N'change', N'No view order; daily LAG windows order by AsOfDate per governor.'),
    (80, N'vDaily_RSSAssisted', N'validation_only', N'No view order; latest date and positive daily deltas only.'),
    (90, N'vDaily_RSSGathered', N'validation_only', N'No view order; latest date and positive daily deltas only.'),
    (100, N'vWTD_Helps', N'validation_only', N'No view order; Monday boundary and positive WTD deltas only.'),
    (110, N'vWTD_RSSAssisted', N'validation_only', N'No view order; Monday boundary and positive WTD deltas only.'),
    (120, N'vWTD_RSSGathered', N'validation_only', N'No view order; Monday boundary and positive WTD deltas only.'),
    (130, N'vw_Governor_KVK_Summary_GlobalLatest', N'change', N'No view order; global maximum SCANORDER and KVK_NO rank determine latest rows.');

DECLARE @CompileTargets TABLE
(
    SequenceNo int NOT NULL PRIMARY KEY,
    ObjectName nvarchar(517) NOT NULL UNIQUE,
    RefreshProcedure sysname NOT NULL
);

INSERT @CompileTargets (SequenceNo, ObjectName, RefreshProcedure)
VALUES
    (10, N'dbo.v_Active_Players', N'sp_refreshview'),
    (20, N'dbo.v_GovernorNames', N'sp_refreshview'),
    (30, N'dbo.v_GovernorNames_Strict', N'sp_refreshview'),
    (40, N'dbo.v_KVK_Under50_Last3_WithLatest', N'sp_refreshview'),
    (50, N'dbo.v_MGE_SignupReview', N'sp_refreshview'),
    (60, N'dbo.v_PlayerLatestStats', N'sp_refreshview'),
    (70, N'dbo.v_PlayerProfile', N'sp_refreshview'),
    (80, N'dbo.v_PlayerAccounts_Migrate', N'sp_refreshview'),
    (90, N'dbo.vDaily_Helps', N'sp_refreshview'),
    (100, N'dbo.vDaily_PlayerExport', N'sp_refreshview'),
    (110, N'dbo.vDaily_RSSAssisted', N'sp_refreshview'),
    (120, N'dbo.vDaily_RSSGathered', N'sp_refreshview'),
    (130, N'dbo.vWTD_Helps', N'sp_refreshview'),
    (140, N'dbo.vWTD_RSSAssisted', N'sp_refreshview'),
    (150, N'dbo.vWTD_RSSGathered', N'sp_refreshview'),
    (160, N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'sp_refreshview'),
    (170, N'dbo.vAllianceActivity_DailyDelta', N'sp_refreshview'),
    (180, N'dbo.vAllianceActivity_WeeklyDelta', N'sp_refreshview'),
    (200, N'dbo.fn_StatsWindowDeltas', N'sp_refreshsqlmodule'),
    (210, N'dbo.fn_StatsWindowDeltas_GovCsv', N'sp_refreshsqlmodule'),
    (220, N'dbo.usp_GetPlayerStatsWindows', N'sp_refreshsqlmodule');

DECLARE @RetiredViewId int =
    OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative', N'V');

IF @RetiredViewId IS NOT NULL
AND NOT EXISTS
(
    SELECT 1
    FROM sys.sql_modules AS module_info
    WHERE module_info.object_id = @RetiredViewId
      AND CONVERT(
              char(64),
              HASHBYTES(
                  'SHA2_256',
                  CONVERT(varbinary(max), module_info.definition)
              ),
              2
          ) = N'DD5C6AC7E3D179463AB22C2618026A0479BC8A0C0D9564D766F1553237465CF4'
)
    THROW 52107, 'Phase 4 preflight refused unexpected retirement-target definition drift.', 1;

IF @RetiredViewId IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM sys.sql_expression_dependencies AS dependency
    WHERE dependency.referenced_id = @RetiredViewId
      AND dependency.referencing_id <> @RetiredViewId
)
    THROW 52108, 'Phase 4 preflight found a SQL module that still depends on the retirement target.', 1;

IF @RetiredViewId IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM sys.database_permissions AS permission_info
    WHERE permission_info.class = 1
      AND permission_info.major_id = @RetiredViewId
)
    THROW 52109, 'Phase 4 preflight found explicit permissions on the retirement target.', 1;

IF @RetiredViewId IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM sys.crypt_properties AS signature_info
    WHERE signature_info.class_desc = N'OBJECT_OR_COLUMN'
      AND signature_info.major_id = @RetiredViewId
)
    THROW 52110, 'Phase 4 preflight found a signature on the retirement target.', 1;

IF @RetiredViewId IS NOT NULL
AND EXISTS
(
    SELECT 1
    FROM sys.extended_properties AS property_info
    WHERE property_info.class = 1
      AND property_info.major_id = @RetiredViewId
)
    THROW 52111, 'Phase 4 preflight found extended properties on the retirement target.', 1;

IF EXISTS
(
    SELECT v.ViewName
    FROM @Views AS v
    WHERE OBJECT_ID(N'dbo.' + v.ViewName, N'V') IS NULL
)
    THROW 52102, 'Phase 4 preflight found a missing mandatory view.', 1;

IF EXISTS
(
    SELECT target.ObjectName
    FROM @CompileTargets AS target
    WHERE OBJECT_ID(target.ObjectName) IS NULL
)
    THROW 52104, 'Phase 4 preflight found a missing transitive compile target.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.crypt_properties AS signature_info
    WHERE signature_info.class_desc = N'OBJECT_OR_COLUMN'
      AND signature_info.major_id IN
      (
          OBJECT_ID(N'dbo.fn_StatsWindowDeltas'),
          OBJECT_ID(N'dbo.fn_StatsWindowDeltas_GovCsv'),
          OBJECT_ID(N'dbo.usp_GetPlayerStatsWindows')
      )
)
    THROW 52103, 'Phase 4 preflight found a signed module; preserve or re-apply its signature explicitly before refresh.', 1;

SELECT
    N'environment' AS EvidenceSection,
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    SYSUTCDATETIME() AS CapturedAtUtc,
    (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4) AS MaxScanOrder,
    (SELECT MAX(AsOfDate) FROM dbo.KingdomScanData4) AS MaxAsOfDate,
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4) AS KingdomScanData4Rows,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS ImportReceiptRows;

SELECT
    N'view_inventory' AS EvidenceSection,
    v.SequenceNo,
    N'dbo.' + v.ViewName AS ObjectName,
    v.ChangeDecision,
    v.OrderingContract,
    CONVERT(
        char(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(varbinary(max), sm.definition)
        ),
        2
    ) AS DefinitionSha256
FROM @Views AS v
JOIN sys.sql_modules AS sm
  ON sm.object_id = OBJECT_ID(N'dbo.' + v.ViewName, N'V')
ORDER BY v.SequenceNo;

SELECT
    N'result_metadata' AS EvidenceSection,
    OBJECT_SCHEMA_NAME(c.object_id) + N'.' + OBJECT_NAME(c.object_id) AS ObjectName,
    c.column_id,
    c.name AS ColumnName,
    TYPE_NAME(c.user_type_id) AS TypeName,
    c.max_length,
    c.precision,
    c.scale,
    c.collation_name,
    c.is_nullable
FROM sys.columns AS c
JOIN @Views AS v
  ON c.object_id = OBJECT_ID(N'dbo.' + v.ViewName, N'V')
ORDER BY v.SequenceNo, c.column_id;

;WITH Seeds AS
(
    SELECT OBJECT_ID(N'dbo.' + ViewName, N'V') AS referenced_id
    FROM @Views
),
ConsumerClosure AS
(
    SELECT
        sed.referenced_id,
        sed.referencing_id,
        1 AS DependencyDepth
    FROM sys.sql_expression_dependencies AS sed
    JOIN Seeds AS seed
      ON seed.referenced_id = sed.referenced_id
    WHERE sed.referencing_id IS NOT NULL

    UNION ALL

    SELECT
        closure.referencing_id,
        sed.referencing_id,
        closure.DependencyDepth + 1
    FROM ConsumerClosure AS closure
    JOIN sys.sql_expression_dependencies AS sed
      ON sed.referenced_id = closure.referencing_id
    WHERE sed.referencing_id IS NOT NULL
      AND closure.DependencyDepth < 16
)
SELECT DISTINCT
    N'transitive_consumer' AS EvidenceSection,
    closure.DependencyDepth,
    OBJECT_SCHEMA_NAME(closure.referencing_id)
        + N'.' + OBJECT_NAME(closure.referencing_id) AS ConsumerName,
    o.type_desc AS ConsumerType
FROM ConsumerClosure AS closure
JOIN sys.objects AS o
  ON o.object_id = closure.referencing_id
ORDER BY closure.DependencyDepth, ConsumerName
OPTION (MAXRECURSION 16);

DROP TABLE IF EXISTS #CompileReceipts;

CREATE TABLE #CompileReceipts
(
    SequenceNo int NOT NULL,
    ObjectName nvarchar(517) NOT NULL,
    RefreshProcedure sysname NOT NULL,
    CompileStatus varchar(4) NOT NULL,
    ErrorNumber int NULL,
    ErrorMessage nvarchar(4000) NULL
);

DECLARE
    @CompileSequenceNo int,
    @CompileObjectName nvarchar(517),
    @RefreshProcedure sysname,
    @CompileSql nvarchar(1000);

DECLARE CompileCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT SequenceNo, ObjectName, RefreshProcedure
    FROM @CompileTargets
    ORDER BY SequenceNo;

OPEN CompileCursor;
FETCH NEXT FROM CompileCursor
INTO @CompileSequenceNo, @CompileObjectName, @RefreshProcedure;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        SET @CompileSql =
            N'EXEC sys.' + QUOTENAME(@RefreshProcedure)
            + N' N' + QUOTENAME(@CompileObjectName, N'''') + N';';

        EXEC sys.sp_executesql @CompileSql;
        ROLLBACK TRANSACTION;

        INSERT #CompileReceipts
            (SequenceNo, ObjectName, RefreshProcedure, CompileStatus)
        VALUES
            (@CompileSequenceNo, @CompileObjectName, @RefreshProcedure, 'PASS');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        INSERT #CompileReceipts
            (
                SequenceNo,
                ObjectName,
                RefreshProcedure,
                CompileStatus,
                ErrorNumber,
                ErrorMessage
            )
        VALUES
            (
                @CompileSequenceNo,
                @CompileObjectName,
                @RefreshProcedure,
                'FAIL',
                ERROR_NUMBER(),
                ERROR_MESSAGE()
            );
    END CATCH;

    FETCH NEXT FROM CompileCursor
    INTO @CompileSequenceNo, @CompileObjectName, @RefreshProcedure;
END;

CLOSE CompileCursor;
DEALLOCATE CompileCursor;

SELECT
    N'compile_receipt' AS EvidenceSection,
    SequenceNo,
    ObjectName,
    RefreshProcedure,
    CompileStatus,
    ErrorNumber,
    ErrorMessage
FROM #CompileReceipts
ORDER BY SequenceNo;

IF EXISTS
(
    SELECT 1
    FROM #CompileReceipts
    WHERE CompileStatus = 'FAIL'
)
    THROW 52105, 'Phase 4 preflight found a baseline compile failure; no Phase 4 definition was changed.', 1;

DROP TABLE IF EXISTS #Baseline;

CREATE TABLE #Baseline
(
    SequenceNo int NOT NULL,
    ViewName sysname NOT NULL,
    [RowCount] bigint NOT NULL,
    ResultDigest char(64) NOT NULL,
    CapturedAtUtc datetime2(3) NOT NULL
);

DECLARE
    @SequenceNo int,
    @ViewName sysname,
    @Sql nvarchar(max),
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

    INSERT #Baseline
        (SequenceNo, ViewName, [RowCount], ResultDigest, CapturedAtUtc)
    VALUES
        (
            @SequenceNo,
            @ViewName,
            @RowCount,
            CONVERT(char(64), @Digest, 2),
            SYSUTCDATETIME()
        );

    FETCH NEXT FROM ViewCursor INTO @SequenceNo, @ViewName;
END;

CLOSE ViewCursor;
DEALLOCATE ViewCursor;

SELECT
    N'baseline_digest' AS EvidenceSection,
    SequenceNo,
    N'dbo.' + ViewName AS ObjectName,
    [RowCount],
    ResultDigest,
    CapturedAtUtc
FROM #Baseline
ORDER BY SequenceNo;

SELECT
    N'phase4_preflight' AS EvidenceSection,
    COUNT(*) AS MandatoryViewCount,
    SUM(CASE WHEN ChangeDecision = N'change' THEN 1 ELSE 0 END) AS ChangedViewCount,
    N'PASS' AS PreflightStatus
FROM @Views;

SELECT
    N'retirement_eligibility' AS EvidenceSection,
    N'dbo.vAllianceActivity_WeeklyCumulative' AS ObjectName,
    CASE
        WHEN @RetiredViewId IS NULL THEN NULL
        ELSE CONVERT(
            char(64),
            HASHBYTES(
                'SHA2_256',
                CONVERT(
                    varbinary(max),
                    OBJECT_DEFINITION(@RetiredViewId)
                )
            ),
            2
        )
    END AS DefinitionSha256,
    CAST(0 AS int) AS ReferencingModuleCount,
    CAST(0 AS int) AS ExplicitPermissionCount,
    CAST(0 AS int) AS SignatureCount,
    CAST(0 AS int) AS ExtendedPropertyCount,
    CASE
        WHEN @RetiredViewId IS NULL THEN N'ALREADY_RETIRED'
        ELSE N'ELIGIBLE'
    END AS RetirementEligibilityStatus;
