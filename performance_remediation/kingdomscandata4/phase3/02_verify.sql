/*
Purpose:
    Verify the Phase 3 direct table contracts, import objects, module refresh,
    row counts, and duplicate-prevention metadata on a representative copy.

Safety:
    - Refuses production ROK_TRACKER.
    - Refuses any database other than the named representative copy.
    - Refreshes module metadata but does not run import or business workloads.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL';

IF DB_NAME() = N'ROK_TRACKER'
    THROW 51980, 'Phase 3 verification refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> @ExpectedDatabase
    THROW 51981, 'Phase 3 verification is connected to the wrong database.', 1;

IF @@TRANCOUNT <> 0
    THROW 51982, 'Phase 3 verification requires no existing user transaction.', 1;

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
BEGIN
    THROW 51983, 'Phase 3 verification found an unexpected direct table type.', 1;
END;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
   OR OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
BEGIN
    THROW 51984, 'Phase 3 verification could not find the receipt/archive/private-helper objects.', 1;
END;

IF DATABASE_PRINCIPAL_ID(N'K98ImportLockPrincipal') IS NULL
   OR EXISTS
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
              WHERE grantee_principal_id =
                    DATABASE_PRINCIPAL_ID(N'public')
                AND major_id = OBJECT_ID(expected.ObjectName, N'P')
                AND permission_name = N'EXECUTE'
                AND state = N'D'
          )
      )
BEGIN
    THROW 51990, 'Phase 3 verification found an unprotected private import helper.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id =
        OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U')
      AND [type] = N'UQ'
      AND [name] = N'UQ_KS4_ImportFileReceipt_ScanOrder'
)
BEGIN
    THROW 51985, 'Phase 3 verification could not find the unique receipt scan-order guard.', 1;
END;

IF EXISTS
(
    SELECT ScanOrder
    FROM dbo.KS4_ImportFileReceipt
    GROUP BY ScanOrder
    HAVING COUNT_BIG(*) > 1
)
BEGIN
    THROW 51986, 'Phase 3 verification found duplicate receipt scan orders.', 1;
END;

DECLARE @Modules table
(
    ModuleName sysname NOT NULL PRIMARY KEY,
    ExpectedType char(2) NOT NULL
);

INSERT @Modules (ModuleName, ExpectedType)
VALUES
    (N'dbo.ACQUIRE_KS4_IMPORT_LOCK', 'P'),
    (N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', 'P'),
    (N'dbo.CREATE_DELTA_TABLES', 'P'),
    (N'dbo.CREATE_THE_AVERAGES', 'P'),
    (N'dbo.DEADSSUMMARY_PROC', 'P'),
    (N'dbo.FIX_IMPORT_STAGING', 'P'),
    (N'dbo.GOVERNOR_NAMES_PROC', 'P'),
    (N'dbo.HEALEDSUMMARY_PROC', 'P'),
    (N'dbo.HEALEDSUMMARY_PROC_OPT', 'P'),
    (N'dbo.IMPORT_STAGING_PROC', 'P'),
    (N'dbo.IMPORT_STAGING_PROC_CORE', 'P'),
    (N'dbo.KILLPOINTSSUMMARY_PROC', 'P'),
    (N'dbo.KILLSSUMMARY_PROC', 'P'),
    (N'dbo.KT4SUMMARY_PROC', 'P'),
    (N'dbo.KT5SUMMARY_PROC', 'P'),
    (N'dbo.POWERSUMMARY_PROC', 'P'),
    (N'dbo.RANGEDSUMMARY_PROC', 'P'),
    (N'dbo.Refresh_PlayerScanMeta', 'P'),
    (N'dbo.sp_ExcelOutput_ByKVK', 'P'),
    (N'dbo.sp_Loop_ExcelOutput_ByKVK', 'P'),
    (N'dbo.sp_Prep_ExcelOutputTable', 'P'),
    (N'dbo.sp_Prep_TargetTable', 'P'),
    (N'dbo.sp_Rebuild_ExcelForDashboard', 'P'),
    (N'dbo.sp_Rebuild_v_PlayerKVK_Last3', 'P'),
    (N'dbo.sp_RefreshInactiveGovernors', 'P'),
    (N'dbo.SP_Stats_for_Upload', 'P'),
    (N'dbo.sp_TARGETS_MASTER', 'P'),
    (N'dbo.SUMMARY_PROC', 'P'),
    (N'dbo.TARGETS', 'P'),
    (N'dbo.TARGETS_NEW', 'P'),
    (N'dbo.TEST', 'P'),
    (N'dbo.UPDATE_ALL', 'P'),
    (N'dbo.UPDATE_ALL2', 'P'),
    (N'dbo.UPDATE_RALLY_DATA', 'P'),
    (N'dbo.usp_BackfillKvkFinalReportCompletion', 'P'),
    (N'dbo.usp_GetLeadershipPlayerIdentityHistory', 'P'),
    (N'dbo.usp_GetLeadershipPlayerLastActive', 'P'),
    (N'dbo.usp_GetLeadershipPlayerLookupDirectory', 'P'),
    (N'dbo.usp_GetLeadershipPlayerReview', 'P'),
    (N'dbo.usp_GetPersonalStatsDaily', 'P'),
    (N'dbo.usp_LeadershipPlayerGovernorExists', 'P'),
    (N'dbo.usp_UpsertGovernorNameHistoryForScan', 'P'),
    (N'dbo.v_Active_Players', 'V'),
    (N'dbo.v_GovernorNames', 'V'),
    (N'dbo.v_KVK_Under50_Last3_WithLatest', 'V'),
    (N'dbo.v_MGE_SignupReview', 'V'),
    (N'dbo.v_PlayerLatestStats', 'V'),
    (N'dbo.vDaily_Helps', 'V'),
    (N'dbo.vDaily_PlayerExport', 'V'),
    (N'dbo.vDaily_RSSAssisted', 'V'),
    (N'dbo.vDaily_RSSGathered', 'V'),
    (N'dbo.vw_Governor_KVK_Summary_GlobalLatest', 'V'),
    (N'dbo.vWTD_Helps', 'V'),
    (N'dbo.vWTD_RSSAssisted', 'V'),
    (N'dbo.vWTD_RSSGathered', 'V');

IF EXISTS
(
    SELECT 1
    FROM @Modules AS expected
    LEFT JOIN sys.objects AS actual
      ON actual.object_id = OBJECT_ID(expected.ModuleName)
     AND CONVERT(binary(2), actual.[type]) =
         CONVERT(binary(2), expected.ExpectedType)
    WHERE actual.object_id IS NULL
)
BEGIN
    THROW 51987, 'Phase 3 verification could not resolve the 52 frozen modules plus the three private helpers.', 1;
END;

DECLARE @RefreshFailures table
(
    ModuleName sysname NOT NULL,
    ErrorNumber int NOT NULL,
    ErrorMessage nvarchar(2048) NOT NULL
);

DECLARE @ModuleName sysname;
DECLARE refresh_cursor CURSOR LOCAL FAST_FORWARD
FOR
    SELECT ModuleName
    FROM @Modules
    ORDER BY ModuleName;

OPEN refresh_cursor;
FETCH NEXT FROM refresh_cursor INTO @ModuleName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sys.sp_refreshsqlmodule @name = @ModuleName;
    END TRY
    BEGIN CATCH
        INSERT @RefreshFailures
        (
            ModuleName,
            ErrorNumber,
            ErrorMessage
        )
        VALUES
        (
            @ModuleName,
            ERROR_NUMBER(),
            ERROR_MESSAGE()
        );
    END CATCH;

    FETCH NEXT FROM refresh_cursor INTO @ModuleName;
END;

CLOSE refresh_cursor;
DEALLOCATE refresh_cursor;

IF EXISTS (SELECT 1 FROM @RefreshFailures)
BEGIN
    SELECT *
    FROM @RefreshFailures
    ORDER BY ModuleName;

    THROW 51988, 'Phase 3 verification found one or more module refresh failures.', 1;
END;

DECLARE @LockHelperCall nvarchar(200) =
    N'EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK';

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
          NOT LIKE N'%' + @LockHelperCall + N'%'
)
BEGIN
    THROW 51989, 'Phase 3 verification found an import entry point without the private lock helper.', 1;
END;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'))
       NOT LIKE N'%EXEC @ReturnCode = dbo.IMPORT_STAGING_PROC_CORE%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'))
       NOT LIKE N'%IF @@TRANCOUNT <> 0%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       NOT LIKE N'%dbo.HASH_KS4_IMPORT_ARCHIVE_FILE%'
BEGIN
    THROW 51991, 'Phase 3 verification found a broken public-wrapper or archive-hash ownership chain.', 1;
END;

SELECT
    N'phase3_verify' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    (SELECT COUNT_BIG(*) FROM dbo.PlayerScanMeta)
        AS PlayerScanMetaRows,
    (SELECT COUNT_BIG(*) FROM dbo.SUMMARY_PROC_STATE)
        AS SummaryStateRows,
    (SELECT COUNT_BIG(*) FROM dbo.STAGING_STATS)
        AS StagingStatsRows,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt)
        AS ImportReceiptRows,
    (SELECT COUNT_BIG(*) FROM @Modules) AS RefreshedModuleCount,
    XACT_STATE() AS XactState,
    @@TRANCOUNT AS TranCount,
    N'PASS' AS VerificationStatus;
