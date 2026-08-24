/*
KingdomScanData4 Phase 5.2 combined post-Phase-5.1 verification.

This is a non-production release-gate verifier. It deliberately preserves the
canonical Phase 2 verifier and finalizer. Run only an in-memory or retained
execution copy in which the three refusal-by-default declarations below are
replaced with the exact frozen rehearsal database and Phase 2 run ID.

The script refreshes module metadata and, only after every combined check has
passed, refreshes VerifiedAtUtc on the exact existing VERIFIED Phase 2 row.
It never changes migration history, the Phase 2 inventories, module
definitions, or finalization state.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;

DECLARE @ConfirmTargetDatabase sysname = N'';
DECLARE @ConfirmPhase2RunId uniqueidentifier = NULL;
DECLARE @ExecuteCombinedVerification bit = 0;

DECLARE @StartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @PriorVerifiedAtUtc datetime2(7);
DECLARE @ExpectedKs4Rows bigint;
DECLARE @ExpectedKs5Rows bigint;
DECLARE @ExpectedStagingRows bigint;
DECLARE @BaselineKs4Digest varbinary(32);
DECLARE @BaselineKs5Digest varbinary(32);
DECLARE @BaselineStagingDigest varbinary(32);
DECLARE @ForwardKs4Digest varbinary(32);
DECLARE @ForwardKs5Digest varbinary(32);
DECLARE @ForwardStagingDigest varbinary(32);
DECLARE @Sql nvarchar(max);

IF @ExecuteCombinedVerification <> 1
    THROW 52600, 'Combined verification is disabled in the repository copy.', 1;

IF @ConfirmTargetDatabase = N'' OR DB_NAME() <> @ConfirmTargetDatabase
    THROW 52601, 'Set @ConfirmTargetDatabase to the exact connected rehearsal database.', 1;

IF @ConfirmPhase2RunId IS NULL
   OR @ConfirmPhase2RunId = '00000000-0000-0000-0000-000000000000'
    THROW 52602, 'Set @ConfirmPhase2RunId to the exact non-zero Phase 2 run ID.', 1;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 52603, 'Combined post-Phase-5.1 verification refuses production ROK_TRACKER.', 1;

DECLARE @TargetPrefix nvarchar(100) =
    N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_';
DECLARE @TargetTail nvarchar(128);
DECLARE @DateTail char(8);
DECLARE @RevisionTail nvarchar(119);
DECLARE @RevisionSeparator int;

IF LEFT(@ConfirmTargetDatabase, LEN(@TargetPrefix)) <> @TargetPrefix
    THROW 52604, 'Target is not a controlled Phase 5.2 reapply database.', 1;

SET @TargetTail = SUBSTRING(
    @ConfirmTargetDatabase,
    LEN(@TargetPrefix) + 1,
    128
);

IF LEN(@TargetTail) = 8
BEGIN
    SET @DateTail = @TargetTail;
END
ELSE
BEGIN
    IF LEFT(@TargetTail, 1) <> N'R'
        THROW 52604, 'Target is not a controlled Phase 5.2 reapply database.', 1;

    SET @RevisionSeparator = CHARINDEX(N'_', @TargetTail);
    IF @RevisionSeparator < 3
        THROW 52604, 'Target is not a controlled Phase 5.2 reapply database.', 1;

    SET @RevisionTail = SUBSTRING(
        @TargetTail,
        2,
        @RevisionSeparator - 2
    );
    SET @DateTail = SUBSTRING(
        @TargetTail,
        @RevisionSeparator + 1,
        8
    );

    IF LEN(@DateTail) <> 8
       OR LEN(@TargetTail) <> @RevisionSeparator + 8
       OR @RevisionTail COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
       OR LEFT(@RevisionTail, 1) = N'0'
        THROW 52604, 'Target is not a controlled Phase 5.2 reapply database.', 1;
END;

IF @DateTail COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
   OR TRY_CONVERT(date, @DateTail, 112) IS NULL
    THROW 52604, 'Target is not a controlled Phase 5.2 reapply database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52605, 'Combined verification requires no existing user transaction.', 1;

IF OBJECT_ID(N'dbo.KS4_Phase2_PreflightState', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KS4_Phase2_ModuleInventory', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KS4_Phase2_MigrationReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 52606, 'Required Phase 2 state, inventory, receipt, or migration-history object is absent.', 1;

SELECT
    @PriorVerifiedAtUtc = VerifiedAtUtc,
    @ExpectedKs4Rows = Ks4Rows,
    @ExpectedKs5Rows = Ks5Rows,
    @ExpectedStagingRows = StagingRows,
    @BaselineKs4Digest = BaselineKs4Digest,
    @BaselineKs5Digest = BaselineKs5Digest,
    @BaselineStagingDigest = BaselineStagingDigest,
    @ForwardKs4Digest = ForwardKs4Digest,
    @ForwardKs5Digest = ForwardKs5Digest,
    @ForwardStagingDigest = ForwardStagingDigest
FROM dbo.KS4_Phase2_PreflightState
WHERE RunId = @ConfirmPhase2RunId
  AND DatabaseName = DB_NAME()
  AND ServerName = @@SERVERNAME
  AND Status = 'VERIFIED'
  AND VerifiedAtUtc IS NOT NULL
  AND MigrationCompletedAtUtc IS NOT NULL
  AND RollbackCompletedAtUtc IS NULL
  AND FinalizedAtUtc IS NULL;

IF @PriorVerifiedAtUtc IS NULL
   OR (SELECT COUNT(*) FROM dbo.KS4_Phase2_PreflightState
       WHERE RunId = @ConfirmPhase2RunId) <> 1
    THROW 52607, 'The exact eligible VERIFIED Phase 2 state row is absent or duplicated.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.dm_exec_sessions AS session_info
    LEFT JOIN sys.dm_exec_requests AS request_info
      ON request_info.session_id = session_info.session_id
    WHERE session_info.is_user_process = 1
      AND session_info.session_id <> @@SPID
      AND COALESCE(request_info.database_id, session_info.database_id) = DB_ID()
      AND NOT
      (
          session_info.program_name LIKE N'Microsoft SQL Server Management Studio%IntelliSense%'
          AND request_info.session_id IS NULL
          AND session_info.open_transaction_count = 0
          AND session_info.status = N'sleeping'
      )
)
    THROW 52608, 'Unexpected external target session or request exists.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.dm_tran_database_transactions AS database_transaction
    JOIN sys.dm_tran_session_transactions AS session_transaction
      ON session_transaction.transaction_id = database_transaction.transaction_id
    WHERE database_transaction.database_id = DB_ID()
      AND session_transaction.session_id <> @@SPID
)
    THROW 52609, 'Unexpected external target transaction exists.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_New', N'U') IS NOT NULL
    THROW 52610, 'Canonical, retained, or failed Phase 2 table state is not exact.', 1;

DECLARE @ExpectedHistory table
(
    SequenceNo int NOT NULL PRIMARY KEY,
    MigrationId nvarchar(255) NOT NULL UNIQUE,
    ChecksumSha256 char(64) NOT NULL
);

INSERT @ExpectedHistory (SequenceNo, MigrationId, ChecksumSha256)
VALUES
    (10, N'20260725_001_kingdomscandata4_shadow_type_remediation',
        'AF9C9F96CF5AF8230224869E6A77BA486A1AB05A420E7FE5DA1C84F6F2A752F2'),
    (20, N'20260726_001_phase3_import_concurrency_and_direct_type_alignment',
        '2C0B0B2AC12DB9399CBE9B1BB8B6DBF1B14C376E399074DCB00EBF343A6369E2'),
    (30, N'20260727_000_retire_vAllianceActivity_WeeklyCumulative',
        '98A715E9FC83F78A76D2AEA7C59BB950FD33E53793E536CF0AFD6DF851FCD1AA'),
    (40, N'20260727_001_phase4_view_type_alignment',
        '8999ADDCFAF56B236A8A3AE42E0004BD9447C97E04F3C29B3C9518D4A780A611'),
    (50, N'20260728_001_phase5_immutable_import_file_handoff',
        '58ABBB25D3D266415BA260CC22A87A2BB1761B2321629C86BFBD955C68DB3693'),
    (60, N'20260816_001_phase5_1_claim_acl_hardening',
        '6129ABECE0B8D312971BBEA1BF6D059F7D4F5C08C4AA043D5323700D8081B0C7');

IF (SELECT COUNT(*) FROM @ExpectedHistory) <> 6
   OR EXISTS
(
    SELECT 1
    FROM @ExpectedHistory AS expected
    LEFT JOIN dbo.SchemaMigrationHistory AS actual
      ON actual.MigrationId = expected.MigrationId
    WHERE actual.MigrationId IS NULL
       OR actual.Status <> N'Applied'
       OR UPPER(actual.ChecksumSha256) <> expected.ChecksumSha256
       OR actual.GitCommit IS NULL
       OR actual.GitCommit COLLATE Latin1_General_100_BIN2
            LIKE N'%[^0-9a-f]%'
       OR LEN(actual.GitCommit) <> 12
       OR NULLIF(actual.BranchName, N'') IS NULL
       OR actual.ErrorMessage IS NULL
       OR DATALENGTH(actual.ErrorMessage) <> 0
)
   OR (SELECT COUNT(*) FROM dbo.SchemaMigrationHistory AS actual
       JOIN @ExpectedHistory AS expected
         ON expected.MigrationId = actual.MigrationId) <> 6
    THROW 52611, 'The exact six Applied migration-history contracts are not present.', 1;

DECLARE @AllowedChangedModules table
(
    SchemaName sysname NOT NULL,
    ObjectName sysname NOT NULL,
    PRIMARY KEY (SchemaName, ObjectName)
);

INSERT @AllowedChangedModules (SchemaName, ObjectName)
VALUES
    (N'dbo', N'CREATE_DELTA_TABLES'),
    (N'dbo', N'DEADSSUMMARY_PROC'),
    (N'dbo', N'FIX_IMPORT_STAGING'),
    (N'dbo', N'HEALEDSUMMARY_PROC'),
    (N'dbo', N'HEALEDSUMMARY_PROC_OPT'),
    (N'dbo', N'IMPORT_STAGING_PROC'),
    (N'dbo', N'KILLPOINTSSUMMARY_PROC'),
    (N'dbo', N'KILLSSUMMARY_PROC'),
    (N'dbo', N'KT4SUMMARY_PROC'),
    (N'dbo', N'KT5SUMMARY_PROC'),
    (N'dbo', N'POWERSUMMARY_PROC'),
    (N'dbo', N'RANGEDSUMMARY_PROC'),
    (N'dbo', N'Refresh_PlayerScanMeta'),
    (N'dbo', N'sp_ExcelOutput_ByKVK'),
    (N'dbo', N'sp_Rebuild_ExcelForDashboard'),
    (N'dbo', N'sp_TARGETS_MASTER'),
    (N'dbo', N'SUMMARY_PROC'),
    (N'dbo', N'TARGETS'),
    (N'dbo', N'TARGETS_NEW'),
    (N'dbo', N'TEST'),
    (N'dbo', N'UPDATE_ALL'),
    (N'dbo', N'UPDATE_ALL2'),
    (N'dbo', N'usp_BackfillKvkFinalReportCompletion'),
    (N'dbo', N'usp_GetLeadershipPlayerIdentityHistory'),
    (N'dbo', N'usp_GetLeadershipPlayerLastActive'),
    (N'dbo', N'usp_GetLeadershipPlayerLookupDirectory'),
    (N'dbo', N'usp_GetLeadershipPlayerReview'),
    (N'dbo', N'usp_LeadershipPlayerGovernorExists'),
    (N'dbo', N'usp_UpsertGovernorNameHistoryForScan'),
    (N'dbo', N'v_Active_Players'),
    (N'dbo', N'v_MGE_SignupReview'),
    (N'dbo', N'vDaily_PlayerExport'),
    (N'dbo', N'vw_Governor_KVK_Summary_GlobalLatest');

IF (SELECT COUNT(*) FROM @AllowedChangedModules) <> 33
   OR (SELECT COUNT(*) FROM dbo.KS4_Phase2_ModuleInventory
       WHERE RunId = @ConfirmPhase2RunId) <> 52
   OR EXISTS
(
    SELECT allowed.SchemaName, allowed.ObjectName
    FROM @AllowedChangedModules AS allowed
    EXCEPT
    SELECT inventory.SchemaName, inventory.ObjectName
    FROM dbo.KS4_Phase2_ModuleInventory AS inventory
    WHERE inventory.RunId = @ConfirmPhase2RunId
)
    THROW 52612, 'The exact Phase 2 inventory or 33-module supersession set drifted.', 1;

DECLARE
    @ModuleSchema sysname,
    @ModuleName sysname,
    @ModuleType char(2),
    @QualifiedModule nvarchar(517);

DECLARE module_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT SchemaName, ObjectName, ObjectType
FROM dbo.KS4_Phase2_ModuleInventory
WHERE RunId = @ConfirmPhase2RunId
ORDER BY CASE WHEN ObjectType = 'V' THEN 1 ELSE 2 END,
         SchemaName, ObjectName;

OPEN module_cursor;
FETCH NEXT FROM module_cursor INTO @ModuleSchema, @ModuleName, @ModuleType;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @QualifiedModule = QUOTENAME(@ModuleSchema) + N'.' + QUOTENAME(@ModuleName);
    IF @ModuleType = 'V'
        EXEC sys.sp_refreshview @QualifiedModule;
    ELSE
        EXEC sys.sp_refreshsqlmodule @QualifiedModule;

    FETCH NEXT FROM module_cursor INTO @ModuleSchema, @ModuleName, @ModuleType;
END;

CLOSE module_cursor;
DEALLOCATE module_cursor;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_Phase2_ModuleInventory AS expected
    LEFT JOIN @AllowedChangedModules AS allowed
      ON allowed.SchemaName = expected.SchemaName
     AND allowed.ObjectName = expected.ObjectName
    LEFT JOIN sys.objects AS object_info
      ON object_info.object_id =
         OBJECT_ID(QUOTENAME(expected.SchemaName) + N'.' + QUOTENAME(expected.ObjectName))
    LEFT JOIN sys.sql_modules AS actual
      ON actual.object_id = object_info.object_id
    WHERE expected.RunId = @ConfirmPhase2RunId
      AND
      (
          actual.object_id IS NULL
          OR object_info.type <> expected.ObjectType
          OR
          (
              allowed.ObjectName IS NULL
              AND
              (
                  HASHBYTES('SHA2_256', CONVERT(varbinary(max), actual.definition))
                        <> expected.DefinitionHash
                  OR actual.uses_ansi_nulls <> expected.UsesAnsiNulls
                  OR actual.uses_quoted_identifier <> expected.UsesQuotedIdentifier
              )
          )
          OR
          (
              allowed.ObjectName IS NOT NULL
              AND HASHBYTES('SHA2_256', CONVERT(varbinary(max), actual.definition))
                    = expected.DefinitionHash
          )
      )
)
    THROW 52613, 'A Phase 2 module is missing, unexpectedly changed, or not superseded as frozen.', 1;

/* Phase 3 direct-type, helper, grant, wrapper, lock and receipt contracts. */
IF EXISTS
(
    SELECT 1
    FROM
    (
        VALUES
            (OBJECT_ID(N'dbo.PlayerScanMeta'), N'GovernorID', TYPE_ID(N'bigint')),
            (OBJECT_ID(N'dbo.PlayerScanMeta'), N'FirstScanOrder', TYPE_ID(N'int')),
            (OBJECT_ID(N'dbo.PlayerScanMeta'), N'LastScanOrder', TYPE_ID(N'int')),
            (OBJECT_ID(N'dbo.SUMMARY_PROC_STATE'), N'LastScanOrder', TYPE_ID(N'int')),
            (OBJECT_ID(N'dbo.STAGING_STATS'), N'GovernorID', TYPE_ID(N'bigint')),
            (OBJECT_ID(N'dbo.STAGING_STATS'), N'PowerRank', TYPE_ID(N'int'))
    ) AS expected(object_id, column_name, type_id)
    LEFT JOIN sys.columns AS actual
      ON actual.object_id = expected.object_id
     AND actual.name = expected.column_name
     AND actual.system_type_id = expected.type_id
     AND actual.user_type_id = expected.type_id
    WHERE actual.column_id IS NULL
)
    THROW 52614, 'Phase 3 direct table type contract drifted.', 1;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
   OR OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR DATABASE_PRINCIPAL_ID(N'K98ImportLockPrincipal') IS NULL
    THROW 52615, 'Phase 3 receipt, helper, or principal contract is incomplete.', 1;

IF EXISTS
(
    SELECT expected.ObjectName
    FROM
    (
        VALUES
            (N'dbo.ACQUIRE_KS4_IMPORT_LOCK'),
            (N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE'),
            (N'dbo.IMPORT_STAGING_PROC_CORE')
    ) AS expected(ObjectName)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.database_permissions
        WHERE grantee_principal_id = DATABASE_PRINCIPAL_ID(N'public')
          AND major_id = OBJECT_ID(expected.ObjectName, N'P')
          AND permission_name = N'EXECUTE'
          AND state = N'D'
    )
)
   OR NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U')
      AND type = N'UQ'
      AND name = N'UQ_KS4_ImportFileReceipt_ScanOrder'
)
   OR EXISTS
(
    SELECT ScanOrder
    FROM dbo.KS4_ImportFileReceipt
    GROUP BY ScanOrder
    HAVING COUNT_BIG(*) > 1
)
    THROW 52616, 'Phase 3 authorization or receipt uniqueness contract drifted.', 1;

IF EXISTS
(
    SELECT expected.ModuleName
    FROM
    (
        VALUES
            (N'dbo.IMPORT_STAGING_PROC_CORE'),
            (N'dbo.FIX_IMPORT_STAGING'),
            (N'dbo.UPDATE_ALL'),
            (N'dbo.UPDATE_ALL2'),
            (N'dbo.ARCHIVE_IMPORT_STAGING_FILE')
    ) AS expected(ModuleName)
    WHERE OBJECT_DEFINITION(OBJECT_ID(expected.ModuleName, N'P'))
          NOT LIKE N'%EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK%'
)
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'))
        NOT LIKE N'%EXEC @ReturnCode = dbo.IMPORT_STAGING_PROC_CORE%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'))
        NOT LIKE N'%IF @@TRANCOUNT <> 0%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
        NOT LIKE N'%dbo.HASH_KS4_IMPORT_ARCHIVE_FILE%'
    THROW 52617, 'Phase 3 lock, wrapper, or archive ownership contract drifted.', 1;

/* Phase 4 retirement and typed-consumer contracts. */
IF OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative') IS NOT NULL
    THROW 52618, 'The deliberately retired Phase 4 view is present.', 1;

IF OBJECT_ID(N'dbo.v_PlayerProfile', N'V') IS NULL
   OR OBJECT_ID(N'dbo.v_PlayerAccounts_Migrate', N'V') IS NULL
   OR OBJECT_ID(N'dbo.fn_StatsWindowDeltas', N'IF') IS NULL
   OR OBJECT_ID(N'dbo.fn_StatsWindowDeltas_GovCsv', N'IF') IS NULL
   OR OBJECT_ID(N'dbo.usp_GetPlayerStatsWindows', N'P') IS NULL
    THROW 52619, 'A mandatory Phase 4 consumer is absent.', 1;

DECLARE @DailyDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.vDaily_PlayerExport', N'V'));

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.v_MGE_SignupReview', N'V'))
       LIKE N'%CAST(ls.GovernorID AS BIGINT)%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V'))
       LIKE N'%kvk_latest.Gov_ID = CAST(ls.GovernorID AS bigint)%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.vw_Governor_KVK_Summary_GlobalLatest', N'V'))
       LIKE N'%kvk_prev.Gov_ID = CAST(ls.GovernorID AS bigint)%'
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.Power)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.KillPoints)', @DailyDefinition) > 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.[Troops Power])', @DailyDefinition) = 0
   OR CHARINDEX(N'TRY_CONVERT(bigint, ks.[Tech Power])', @DailyDefinition) = 0
   OR CHARINDEX(N'LTRIM(RTRIM(ks.GovernorName))', @DailyDefinition) = 0
   OR CHARINDEX(N'LTRIM(RTRIM(ks.Alliance))', @DailyDefinition) = 0
    THROW 52620, 'Phase 4 typed-consumer definition contract drifted.', 1;

/* Phase 5 immutable-file contract. */
IF OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NULL
   OR OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL2', N'P') IS NULL
    THROW 52621, 'A Phase 5 claim or import object is absent.', 1;

IF EXISTS
(
    SELECT expected.ObjectName
    FROM
    (
        VALUES
            (N'dbo.IMPORT_STAGING_PROC_CORE'),
            (N'dbo.IMPORT_STAGING_PROC'),
            (N'dbo.UPDATE_ALL'),
            (N'dbo.UPDATE_ALL2'),
            (N'dbo.ARCHIVE_IMPORT_STAGING_FILE')
    ) AS expected(ObjectName)
    LEFT JOIN sys.parameters AS actual
      ON actual.object_id = OBJECT_ID(expected.ObjectName, N'P')
     AND actual.name = N'@CompletedFileName'
     AND actual.system_type_id = TYPE_ID(N'nvarchar')
     AND actual.max_length = 520
    WHERE actual.parameter_id IS NULL
)
   OR NOT EXISTS
(
    SELECT 1
    FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P')
      AND name = N'@ImportError'
      AND system_type_id = TYPE_ID(N'nvarchar')
      AND max_length = 4000
      AND is_output = 1
)
    THROW 52622, 'Phase 5 filename or error-handoff parameter contract drifted.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'))
       LIKE N'%downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P'))
       LIKE N'%downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       LIKE N'%downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
       NOT LIKE N'%stats_<32 lowercase hex>.ready.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
       NOT LIKE N'%Import_Ready%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
       NOT LIKE N'%Import_Claimed%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'))
       NOT LIKE N'%detected claimed-file mutation across BULK INSERT%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL', N'P'))
       NOT LIKE N'%SET LastError = @OuterPersistedError%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2', N'P'))
       NOT LIKE N'%SET LastError = @PersistedImportError%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       NOT LIKE N'%archive destination rehash changed%'
    THROW 52623, 'Phase 5 immutable-file definition contract drifted.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.KS4_ImportFileClaim')
      AND name = N'CK_KS4_ImportFileClaim_Status'
      AND is_disabled = 0
      AND is_not_trusted = 0
)
   OR EXISTS
(
    SELECT 1
    FROM sys.database_permissions
    WHERE major_id IN
    (
        OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE'),
        OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE'),
        OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE')
    )
      AND grantee_principal_id = DATABASE_PRINCIPAL_ID(N'public')
      AND permission_name = N'EXECUTE'
      AND state_desc <> N'DENY'
)
    THROW 52624, 'Phase 5 constraint or helper grant contract drifted.', 1;

/* Phase 5.1 ACL evidence schema and ordering contracts. */
IF COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclHardenedAtUtc') IS NULL
   OR COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclOwnerIdentity') IS NULL
   OR NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.KS4_ImportFileClaim')
      AND name = N'CK_KS4_ImportFileClaim_AclEvidence'
      AND is_disabled = 0
      AND is_not_trusted = 0
)
    THROW 52625, 'Phase 5.1 ACL evidence schema contract drifted.', 1;

DECLARE @ClaimDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'));

IF @ClaimDefinition IS NULL
   OR @ClaimDefinition NOT LIKE N'%WHOAMI%'
   OR @ClaimDefinition NOT LIKE N'%ICACLS%'
   OR @ClaimDefinition NOT LIKE N'%/RESET /Q%'
   OR @ClaimDefinition NOT LIKE N'%/SETOWNER "%'
   OR @ClaimDefinition NOT LIKE N'%/VERIFY /Q%'
   OR @ClaimDefinition NOT LIKE N'%AclHardenedAtUtc = COALESCE(AclHardenedAtUtc, @AclHardenedAtUtc)%'
   OR @ClaimDefinition NOT LIKE N'%AclOwnerIdentity = COALESCE(AclOwnerIdentity, @AclOwnerIdentity)%'
   OR CHARINDEX(N'/SETOWNER "', @ClaimDefinition) >= CHARINDEX(N'/RESET /Q', @ClaimDefinition)
   OR CHARINDEX(N'/RESET /Q', @ClaimDefinition) >= CHARINDEX(N'/VERIFY /Q', @ClaimDefinition)
   OR CHARINDEX(N'/VERIFY /Q', @ClaimDefinition) >=
      CHARINDEX(N'EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', @ClaimDefinition)
    THROW 52626, 'Phase 5.1 claim-procedure definition or operation order drifted.', 1;

/* Recompute exact normalized current and retained Phase 2 row digests. */
DECLARE @BigintMap table
(
    LogicalName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    PRIMARY KEY (LogicalName, ColumnName)
);
DECLARE @IntMap table
(
    LogicalName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    PRIMARY KEY (LogicalName, ColumnName)
);
DECLARE @StringMap table
(
    LogicalName sysname NOT NULL,
    ColumnName sysname NOT NULL,
    TargetLength int NOT NULL,
    TrimRight bit NOT NULL,
    PRIMARY KEY (LogicalName, ColumnName)
);

INSERT @BigintMap
VALUES
    (N'KS4', N'GovernorID'), (N'KS4', N'Power'),
    (N'KS4', N'KillPoints'), (N'KS4', N'Deads'),
    (N'KS4', N'T1_Kills'), (N'KS4', N'T2_Kills'),
    (N'KS4', N'T3_Kills'), (N'KS4', N'T4_Kills'),
    (N'KS4', N'T5_Kills'), (N'KS4', N'T4&T5_KILLS'),
    (N'KS4', N'TOTAL_KILLS'), (N'KS4', N'RSS_Gathered'),
    (N'KS4', N'RSSAssistance'), (N'KS4', N'Helps'),
    (N'KS5', N'GovernorID'), (N'KS5', N'Power'),
    (N'KS5', N'KillPoints'), (N'KS5', N'Deads'),
    (N'KS5', N'T1_Kills'), (N'KS5', N'T2_Kills'),
    (N'KS5', N'T3_Kills'), (N'KS5', N'T4_Kills'),
    (N'KS5', N'T5_Kills'), (N'KS5', N'T4&T5_KILLS'),
    (N'KS5', N'TOTAL_KILLS'), (N'KS5', N'RSS_Gathered'),
    (N'KS5', N'RSSAssistance'), (N'KS5', N'Helps'),
    (N'STAGING', N'Governor ID'), (N'STAGING', N'Power'),
    (N'STAGING', N'Total Kill Points'), (N'STAGING', N'Dead Troops'),
    (N'STAGING', N'T1-Kills'), (N'STAGING', N'T2-Kills'),
    (N'STAGING', N'T3-Kills'), (N'STAGING', N'T4-Kills'),
    (N'STAGING', N'T5-Kills'), (N'STAGING', N'Kills (T4+)'),
    (N'STAGING', N'KILLS'), (N'STAGING', N'RSS Gathered'),
    (N'STAGING', N'RSS Assistance'), (N'STAGING', N'Alliance Helps');

INSERT @IntMap
VALUES
    (N'KS4', N'PowerRank'), (N'KS4', N'SCANORDER'),
    (N'KS5', N'PowerRank'), (N'KS5', N'SCANORDER'),
    (N'STAGING', N'SCANORDER');

INSERT @StringMap
VALUES
    (N'KS4', N'GovernorName', 200, 1),
    (N'KS4', N'Alliance', 100, 1),
    (N'KS5', N'GovernorName', 200, 1),
    (N'KS5', N'Alliance', 100, 1),
    (N'STAGING', N'Name', 200, 1),
    (N'STAGING', N'Alliance', 100, 1),
    (N'STAGING', N'Updated_on', 200, 0);

DECLARE @DigestWork table
(
    SequenceNo int NOT NULL PRIMARY KEY,
    LogicalName sysname NOT NULL,
    MapName sysname NOT NULL,
    PhysicalName sysname NOT NULL,
    ExpectedRows bigint NOT NULL,
    ExpectedDigest varbinary(32) NOT NULL
);
DECLARE @Digests table
(
    SequenceNo int NOT NULL PRIMARY KEY,
    LogicalName sysname NOT NULL,
    RowCount bigint NOT NULL,
    Digest varbinary(32) NOT NULL
);

INSERT @DigestWork
VALUES
    (10, N'KS4_CURRENT', N'KS4', N'KingdomScanData4',
        @ExpectedKs4Rows, @ForwardKs4Digest),
    (20, N'KS5_CURRENT', N'KS5', N'KingdomScanData5',
        @ExpectedKs5Rows, @ForwardKs5Digest),
    (30, N'STAGING_CURRENT', N'STAGING', N'IMPORT_STAGING',
        @ExpectedStagingRows, @ForwardStagingDigest),
    (40, N'KS4_RETAINED', N'KS4', N'KingdomScanData4_Phase2_Old',
        @ExpectedKs4Rows, @BaselineKs4Digest),
    (50, N'KS5_RETAINED', N'KS5', N'KingdomScanData5_Phase2_Old',
        @ExpectedKs5Rows, @BaselineKs5Digest),
    (60, N'STAGING_RETAINED', N'STAGING', N'IMPORT_STAGING_Phase2_Old',
        @ExpectedStagingRows, @BaselineStagingDigest);

DECLARE
    @DigestSequenceNo int,
    @LogicalName sysname,
    @MapName sysname,
    @PhysicalName sysname,
    @ExpectedRows bigint,
    @ExpectedDigest varbinary(32),
    @Projection nvarchar(max),
    @CanonicalRows nvarchar(max),
    @Digest varbinary(32),
    @DigestRows bigint;

DECLARE digest_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT SequenceNo, LogicalName, MapName, PhysicalName, ExpectedRows, ExpectedDigest
FROM @DigestWork
ORDER BY SequenceNo;

OPEN digest_cursor;
FETCH NEXT FROM digest_cursor
INTO @DigestSequenceNo, @LogicalName, @MapName, @PhysicalName,
     @ExpectedRows, @ExpectedDigest;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @Projection =
        STRING_AGG(
            CONVERT(nvarchar(max),
                CASE
                    WHEN bigint_map.ColumnName IS NOT NULL
                        THEN N'CONVERT(bigint, source.' + QUOTENAME(column_info.name)
                             + N') AS ' + QUOTENAME(column_info.name)
                    WHEN int_map.ColumnName IS NOT NULL
                        THEN N'CONVERT(int, source.' + QUOTENAME(column_info.name)
                             + N') AS ' + QUOTENAME(column_info.name)
                    WHEN string_map.ColumnName IS NOT NULL
                        THEN N'CONVERT(nvarchar('
                             + CONVERT(nvarchar(10), string_map.TargetLength)
                             + N'), '
                             + CASE WHEN string_map.TrimRight = 1
                                    THEN N'RTRIM(source.' + QUOTENAME(column_info.name) + N')'
                                    ELSE N'source.' + QUOTENAME(column_info.name) END
                             + N') COLLATE Latin1_General_CI_AS AS '
                             + QUOTENAME(column_info.name)
                    WHEN @MapName = N'KS4' AND column_info.name = N'AsOfDate'
                        THEN N'CONVERT(date, source.[ScanDate]) AS [AsOfDate]'
                    ELSE N'source.' + QUOTENAME(column_info.name)
                         + N' AS ' + QUOTENAME(column_info.name)
                END),
            N',') WITHIN GROUP (ORDER BY column_info.column_id)
    FROM sys.columns AS column_info
    LEFT JOIN @BigintMap AS bigint_map
      ON bigint_map.LogicalName = @MapName
     AND bigint_map.ColumnName = column_info.name
    LEFT JOIN @IntMap AS int_map
      ON int_map.LogicalName = @MapName
     AND int_map.ColumnName = column_info.name
    LEFT JOIN @StringMap AS string_map
      ON string_map.LogicalName = @MapName
     AND string_map.ColumnName = column_info.name
    WHERE column_info.object_id = OBJECT_ID(N'dbo.' + @PhysicalName);

    IF @Projection IS NULL
        THROW 52627, 'A combined digest projection could not be built.', 1;

    SET @Sql = N'
        SELECT @Rows = COUNT_BIG(*) FROM dbo.' + QUOTENAME(@PhysicalName) + N';
        SELECT @Canonical =
        (
            SELECT row_hashes.RowDigest
            FROM
            (
                SELECT CONVERT(char(64),
                    HASHBYTES(''SHA2_256'',
                        (SELECT ' + @Projection + N'
                         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER,
                             INCLUDE_NULL_VALUES)), 2) AS RowDigest
                FROM dbo.' + QUOTENAME(@PhysicalName) + N' AS source
            ) AS row_hashes
            ORDER BY row_hashes.RowDigest
            FOR JSON PATH
        );
        SET @OutputDigest =
            HASHBYTES(''SHA2_256'', COALESCE(@Canonical, N''[]''));';

    EXEC sys.sp_executesql
        @Sql,
        N'@Rows bigint OUTPUT, @Canonical nvarchar(max) OUTPUT,
          @OutputDigest varbinary(32) OUTPUT',
        @Rows = @DigestRows OUTPUT,
        @Canonical = @CanonicalRows OUTPUT,
        @OutputDigest = @Digest OUTPUT;

    IF @DigestRows <> @ExpectedRows OR @Digest <> @ExpectedDigest
        THROW 52628, 'A current or retained Phase 2 row count or digest drifted.', 1;

    INSERT @Digests VALUES
        (@DigestSequenceNo, @LogicalName, @DigestRows, @Digest);

    FETCH NEXT FROM digest_cursor
    INTO @DigestSequenceNo, @LogicalName, @MapName, @PhysicalName,
         @ExpectedRows, @ExpectedDigest;
END;

CLOSE digest_cursor;
DEALLOCATE digest_cursor;

DBCC CHECKTABLE (N'dbo.KingdomScanData4') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.KingdomScanData5') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.IMPORT_STAGING') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.KingdomScanData4_Phase2_Old') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.KingdomScanData5_Phase2_Old') WITH NO_INFOMSGS;
DBCC CHECKTABLE (N'dbo.IMPORT_STAGING_Phase2_Old') WITH NO_INFOMSGS;

DECLARE
    @LatestStatsRows bigint,
    @DailyExportRows bigint,
    @GlobalLatestRows bigint;

SELECT @LatestStatsRows = COUNT_BIG(*) FROM dbo.v_PlayerLatestStats;
SELECT @DailyExportRows = COUNT_BIG(*) FROM dbo.vDaily_PlayerExport;
SELECT @GlobalLatestRows = COUNT_BIG(*)
FROM dbo.vw_Governor_KVK_Summary_GlobalLatest;

IF @ExpectedKs4Rows = 394506
   AND
   (
       @LatestStatsRows <> 2371
       OR @DailyExportRows <> 223386
       OR @GlobalLatestRows <> 411
   )
    THROW 52629, 'Representative critical read-smoke row counts drifted.', 1;

IF @@TRANCOUNT <> 0
    THROW 52630, 'Combined verification leaked a transaction before timestamp refresh.', 1;

/* This is the only durable mutation in this verifier, and it is last. */
UPDATE dbo.KS4_Phase2_PreflightState
SET VerifiedAtUtc = SYSUTCDATETIME()
WHERE RunId = @ConfirmPhase2RunId
  AND DatabaseName = DB_NAME()
  AND ServerName = @@SERVERNAME
  AND Status = 'VERIFIED'
  AND VerifiedAtUtc = @PriorVerifiedAtUtc
  AND RollbackCompletedAtUtc IS NULL
  AND FinalizedAtUtc IS NULL;

IF @@ROWCOUNT <> 1
    THROW 52631, 'The exact Phase 2 verification timestamp was not refreshed once.', 1;

SELECT
    N'phase5_2_combined_post_phase5_1' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @ConfirmPhase2RunId AS Phase2RunId,
    @StartedAtUtc AS StartedAtUtc,
    SYSUTCDATETIME() AS CompletedAtUtc,
    @PriorVerifiedAtUtc AS PriorVerifiedAtUtc,
    (SELECT VerifiedAtUtc FROM dbo.KS4_Phase2_PreflightState
     WHERE RunId = @ConfirmPhase2RunId) AS RefreshedVerifiedAtUtc,
    (SELECT COUNT(*) FROM @AllowedChangedModules) AS SupersededPhase2ModuleCount,
    @LatestStatsRows AS LatestStatsRows,
    @DailyExportRows AS DailyExportRows,
    @GlobalLatestRows AS GlobalLatestRows,
    N'PASS' AS VerificationStatus;

SELECT
    N'phase5_2_combined_digest' AS EvidenceSection,
    LogicalName,
    RowCount,
    CONVERT(char(64), Digest, 2) AS NormalizedDigestSha256
FROM @Digests
ORDER BY SequenceNo;

SELECT
    N'phase5_2_combined_module_manifest' AS EvidenceSection,
    OBJECT_SCHEMA_NAME(object_info.object_id) AS SchemaName,
    object_info.name AS ObjectName,
    object_info.type AS ObjectType,
    CONVERT(char(64), HASHBYTES(
        'SHA2_256', CONVERT(varbinary(max), module_info.definition)), 2)
        AS DefinitionSha256,
    module_info.uses_ansi_nulls AS UsesAnsiNulls,
    module_info.uses_quoted_identifier AS UsesQuotedIdentifier
FROM sys.sql_modules AS module_info
JOIN sys.objects AS object_info
  ON object_info.object_id = module_info.object_id
WHERE object_info.is_ms_shipped = 0
ORDER BY OBJECT_SCHEMA_NAME(object_info.object_id), object_info.name;
