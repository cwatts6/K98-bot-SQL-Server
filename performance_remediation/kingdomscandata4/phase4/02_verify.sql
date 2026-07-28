/*
KingdomScanData4 Phase 4 post-migration verification.

Run after the Phase 4 migration on the isolated rehearsal database and again
during the separately approved production window.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
    THROW 52150, 'Phase 4 verification requires the Phase 3 contracts.', 1;

IF OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative') IS NOT NULL
    THROW 52156, 'Phase 4 verification found the retired obsolete view still present.', 1;

DECLARE @Views TABLE
(
    SequenceNo int NOT NULL PRIMARY KEY,
    ObjectName sysname NOT NULL,
    ObjectType varchar(2) NOT NULL
);

INSERT @Views (SequenceNo, ObjectName, ObjectType)
VALUES
    (10, N'dbo.v_Active_Players', N'V'),
    (20, N'dbo.v_GovernorNames', N'V'),
    (30, N'dbo.v_KVK_Under50_Last3_WithLatest', N'V'),
    (40, N'dbo.v_MGE_SignupReview', N'V'),
    (50, N'dbo.v_PlayerLatestStats', N'V'),
    (60, N'dbo.vDaily_Helps', N'V'),
    (70, N'dbo.vDaily_PlayerExport', N'V'),
    (80, N'dbo.vDaily_RSSAssisted', N'V'),
    (90, N'dbo.vDaily_RSSGathered', N'V'),
    (100, N'dbo.vWTD_Helps', N'V'),
    (110, N'dbo.vWTD_RSSAssisted', N'V'),
    (120, N'dbo.vWTD_RSSGathered', N'V'),
    (130, N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V'),
    (140, N'dbo.v_GovernorNames_Strict', N'V'),
    (150, N'dbo.vAllianceActivity_DailyDelta', N'V'),
    (160, N'dbo.vAllianceActivity_WeeklyDelta', N'V'),
    (180, N'dbo.v_PlayerProfile', N'V'),
    (190, N'dbo.v_PlayerAccounts_Migrate', N'V'),
    (200, N'dbo.fn_StatsWindowDeltas', N'IF'),
    (210, N'dbo.fn_StatsWindowDeltas_GovCsv', N'IF'),
    (220, N'dbo.usp_GetPlayerStatsWindows', N'P');

IF EXISTS
(
    SELECT ObjectName
    FROM @Views
    WHERE OBJECT_ID(ObjectName, ObjectType) IS NULL
)
    THROW 52151, 'Phase 4 verification found a missing mandatory or transitive SQL consumer.', 1;

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
    THROW 52155, 'Phase 4 verification found a signed module; preserve or re-apply its signature explicitly before refresh.', 1;

EXEC sys.sp_refreshview N'dbo.v_Active_Players';
EXEC sys.sp_refreshview N'dbo.v_GovernorNames';
EXEC sys.sp_refreshview N'dbo.v_GovernorNames_Strict';
EXEC sys.sp_refreshview N'dbo.v_KVK_Under50_Last3_WithLatest';
EXEC sys.sp_refreshview N'dbo.v_MGE_SignupReview';
EXEC sys.sp_refreshview N'dbo.v_PlayerLatestStats';
EXEC sys.sp_refreshview N'dbo.v_PlayerProfile';
EXEC sys.sp_refreshview N'dbo.v_PlayerAccounts_Migrate';
EXEC sys.sp_refreshview N'dbo.vDaily_Helps';
EXEC sys.sp_refreshview N'dbo.vDaily_PlayerExport';
EXEC sys.sp_refreshview N'dbo.vDaily_RSSAssisted';
EXEC sys.sp_refreshview N'dbo.vDaily_RSSGathered';
EXEC sys.sp_refreshview N'dbo.vWTD_Helps';
EXEC sys.sp_refreshview N'dbo.vWTD_RSSAssisted';
EXEC sys.sp_refreshview N'dbo.vWTD_RSSGathered';
EXEC sys.sp_refreshview N'dbo.vw_Governor_KVK_Summary_GlobalLatest';
EXEC sys.sp_refreshview N'dbo.vAllianceActivity_DailyDelta';
EXEC sys.sp_refreshview N'dbo.vAllianceActivity_WeeklyDelta';
EXEC sys.sp_refreshsqlmodule N'dbo.fn_StatsWindowDeltas';
EXEC sys.sp_refreshsqlmodule N'dbo.fn_StatsWindowDeltas_GovCsv';
EXEC sys.sp_refreshsqlmodule N'dbo.usp_GetPlayerStatsWindows';

IF EXISTS
(
    SELECT 1
    FROM sys.sql_modules
    WHERE object_id = OBJECT_ID(N'dbo.v_MGE_SignupReview', N'V')
      AND definition LIKE N'%CAST(ls.GovernorID AS BIGINT)%'
)
OR EXISTS
(
    SELECT 1
    FROM sys.sql_modules
    WHERE object_id = OBJECT_ID(N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V')
      AND
      (
          definition LIKE N'%kvk_latest.Gov_ID = CAST(ls.GovernorID AS bigint)%'
          OR definition LIKE N'%kvk_prev.Gov_ID = CAST(ls.GovernorID AS bigint)%'
      )
)
    THROW 52152, 'Phase 4 verification found an obsolete GovernorID join conversion.', 1;

DECLARE @DailyDefinition nvarchar(max) =
(
    SELECT definition
    FROM sys.sql_modules
    WHERE object_id = OBJECT_ID(N'dbo.vDaily_PlayerExport', N'V')
);

IF CHARINDEX(N'TRY_CONVERT(bigint, ks.Power)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.KillPoints)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.Deads)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.RSS_Gathered)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.RSSAssistance)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.Helps)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.T4_Kills)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.T5_Kills)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.[T4&T5_KILLS])', @DailyDefinition) > 0
    THROW 52153, 'Phase 4 verification found obsolete typed-metric conversion in vDaily_PlayerExport.', 1;

IF CHARINDEX(N'TRY_CONVERT(bigint, ks.[Troops Power])', @DailyDefinition) = 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.[Tech Power])', @DailyDefinition) = 0
   OR CHARINDEX(N'LTRIM(RTRIM(ks.GovernorName))', @DailyDefinition) = 0
   OR CHARINDEX(N'LTRIM(RTRIM(ks.Alliance))', @DailyDefinition) = 0
    THROW 52154, 'Phase 4 removed a required float target-width or display-trimming contract.', 1;

SELECT
    N'refreshed_module' AS EvidenceSection,
    v.SequenceNo,
    v.ObjectName,
    o.type_desc,
    o.modify_date,
    CONVERT(
        char(64),
        HASHBYTES('SHA2_256', CONVERT(varbinary(max), sm.definition)),
        2
    ) AS DefinitionSha256
FROM @Views AS v
JOIN sys.objects AS o
  ON o.object_id = OBJECT_ID(v.ObjectName)
JOIN sys.sql_modules AS sm
  ON sm.object_id = o.object_id
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
  ON c.object_id = OBJECT_ID(v.ObjectName, N'V')
WHERE v.ObjectType = N'V'
ORDER BY v.SequenceNo, c.column_id;

SELECT
    N'consumer_smoke' AS EvidenceSection,
    (SELECT COUNT_BIG(*) FROM dbo.v_Active_Players) AS ActivePlayerRows,
    (SELECT COUNT_BIG(*) FROM dbo.v_GovernorNames) AS GovernorNameRows,
    (SELECT COUNT_BIG(*) FROM dbo.v_KVK_Under50_Last3_WithLatest) AS Under50Last3Rows,
    (SELECT COUNT_BIG(*) FROM dbo.v_MGE_SignupReview) AS MgeSignupReviewRows,
    (SELECT COUNT_BIG(*) FROM dbo.v_PlayerLatestStats) AS PlayerLatestRows,
    (SELECT COUNT_BIG(*) FROM dbo.vDaily_Helps) AS DailyHelpRows,
    (SELECT COUNT_BIG(*) FROM dbo.vDaily_PlayerExport) AS DailyExportRows,
    (SELECT COUNT_BIG(*) FROM dbo.vDaily_RSSAssisted) AS DailyAssistRows,
    (SELECT COUNT_BIG(*) FROM dbo.vDaily_RSSGathered) AS DailyGatheredRows,
    (SELECT COUNT_BIG(*) FROM dbo.vWTD_Helps) AS WtdHelpRows,
    (SELECT COUNT_BIG(*) FROM dbo.vWTD_RSSAssisted) AS WtdAssistRows,
    (SELECT COUNT_BIG(*) FROM dbo.vWTD_RSSGathered) AS WtdGatheredRows,
    (SELECT COUNT_BIG(*) FROM dbo.vw_Governor_KVK_Summary_GlobalLatest) AS GlobalLatestRows,
    (SELECT COUNT_BIG(*) FROM dbo.v_PlayerProfile) AS PlayerProfileRows,
    (SELECT COUNT_BIG(*) FROM dbo.v_PlayerAccounts_Migrate) AS PlayerAccountMigrationRows;

SELECT
    N'phase4_verify' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @@TRANCOUNT AS OpenTransactionCount,
    CAST(
        CASE
            WHEN OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative') IS NULL
            THEN 1
            ELSE 0
        END
        AS bit
    ) AS RetiredViewAbsent,
    N'PASS' AS VerificationStatus;
