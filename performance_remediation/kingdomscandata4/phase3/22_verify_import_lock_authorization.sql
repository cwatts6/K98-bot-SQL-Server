/*
Purpose:
    Prove that private Phase 3 helpers are unavailable through public database
    membership, an authorized wrapper caller can reach the private ownership
    chain, and public entry points refuse caller-owned transactions before
    acquiring the mutex.

Safety:
    - Refuses production ROK_TRACKER.
    - Uses a contained WITHOUT LOGIN user with only a temporary wrapper grant.
    - Uses an unknown digest so the authorized wrapper performs no file move.
    - Drops the probe user and verifies zero leaked transactions or locks.
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 51940, 'Phase 3 lock authorization verification refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 51941, 'Phase 3 lock authorization verification is connected to the wrong database.', 1;

IF @@TRANCOUNT <> 0
    THROW 51942, 'Phase 3 lock authorization verification requires no existing transaction.', 1;

IF OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
   OR OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P') IS NULL
   OR DATABASE_PRINCIPAL_ID(N'K98ImportLockPrincipal') IS NULL
    THROW 51943, 'Phase 3 private authorization objects are missing.', 1;

DECLARE @ProbeUser sysname = N'Phase3ImportLockNoGrantProbe';
DECLARE @DirectRoleError int = NULL;
DECLARE @DirectLockHelperError int = NULL;
DECLARE @DirectHashHelperError int = NULL;
DECLARE @DirectCoreError int = NULL;
DECLARE @AuthorizedWrapperError int = NULL;
DECLARE @AuthorizedWrapperMessage nvarchar(4000) = NULL;
DECLARE @AmbientWrapperError int = NULL;
DECLARE @AuthorizedResult int = NULL;
DECLARE @ProbeResult int = NULL;
DECLARE @Impersonating bit = 0;
DECLARE @PostWrapperLockMode nvarchar(32) = NULL;
DECLARE @ProbeUserSql nvarchar(512);
DECLARE @UnknownDigest binary(32) =
    0x0000000000000000000000000000000000000000000000000000000000000000;
DECLARE @HashOutput binary(32);

IF DATABASE_PRINCIPAL_ID(@ProbeUser) IS NOT NULL
BEGIN
    SET @ProbeUserSql = N'DROP USER ' + QUOTENAME(@ProbeUser) + N';';
    EXEC sys.sp_executesql @ProbeUserSql;
END;

SET @ProbeUserSql = N'CREATE USER ' + QUOTENAME(@ProbeUser) + N' WITHOUT LOGIN;';
EXEC sys.sp_executesql @ProbeUserSql;

BEGIN TRY
    EXECUTE AS USER = N'Phase3ImportLockNoGrantProbe';
    SET @Impersonating = 1;

    BEGIN TRANSACTION;
    BEGIN TRY
        EXEC @ProbeResult = sys.sp_getapplock
            @Resource = N'K98:KingdomScanData4:ImportPipeline:v1',
            @LockMode = N'Exclusive',
            @LockOwner = N'Transaction',
            @LockTimeout = 0,
            @DbPrincipal = N'K98ImportLockPrincipal';
    END TRY
    BEGIN CATCH
        SET @DirectRoleError = ERROR_NUMBER();
    END CATCH;

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    BEGIN TRANSACTION;
    BEGIN TRY
        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 0,
            @LockResult = @ProbeResult OUTPUT;
    END TRY
    BEGIN CATCH
        SET @DirectLockHelperError = ERROR_NUMBER();
    END CATCH;

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    BEGIN TRY
        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath = N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\Import_Archive\Stats_direct_probe.csv',
            @FileDigest = @HashOutput OUTPUT;
    END TRY
    BEGIN CATCH
        SET @DirectHashHelperError = ERROR_NUMBER();
    END CATCH;

    BEGIN TRY
        EXEC dbo.IMPORT_STAGING_PROC_CORE;
    END TRY
    BEGIN CATCH
        SET @DirectCoreError = ERROR_NUMBER();
    END CATCH;

    REVERT;
    SET @Impersonating = 0;

    IF @DirectRoleError IS NULL
        THROW 51944, 'A no-grant user could acquire the dedicated import-lock namespace directly.', 1;

    IF @DirectLockHelperError IS NULL
        THROW 51945, 'A no-grant user could execute the private import-lock helper directly.', 1;

    IF @DirectHashHelperError IS NULL
        THROW 51948, 'A no-grant user could execute the private archive-hash helper directly.', 1;

    IF @DirectCoreError IS NULL
        THROW 51949, 'A no-grant user could execute the private import core directly.', 1;

    GRANT EXECUTE ON OBJECT::dbo.ARCHIVE_IMPORT_STAGING_FILE
        TO [Phase3ImportLockNoGrantProbe];

    EXECUTE AS USER = N'Phase3ImportLockNoGrantProbe';
    SET @Impersonating = 1;

    BEGIN TRY
        EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
            @FileDigest = @UnknownDigest;
    END TRY
    BEGIN CATCH
        SET @AuthorizedWrapperError = ERROR_NUMBER();
        SET @AuthorizedWrapperMessage = ERROR_MESSAGE();
    END CATCH;

    IF @AuthorizedWrapperError <> 51842
    BEGIN
        SELECT
            @AuthorizedWrapperError AS AuthorizedWrapperError,
            @AuthorizedWrapperMessage AS AuthorizedWrapperMessage;
        THROW 51950, 'The authorized archive wrapper did not reach its private ownership chain.', 1;
    END;

    BEGIN TRANSACTION;

    BEGIN TRY
        EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
            @FileDigest = @UnknownDigest;
    END TRY
    BEGIN CATCH
        SET @AmbientWrapperError = ERROR_NUMBER();
    END CATCH;

    REVERT;
    SET @Impersonating = 0;

    SET @PostWrapperLockMode = APPLOCK_MODE
    (
        N'K98ImportLockPrincipal',
        N'K98:KingdomScanData4:ImportPipeline:v1',
        N'Transaction'
    );

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    IF @AmbientWrapperError <> 51849
        THROW 51951, 'The public archive wrapper did not refuse the caller-owned transaction.', 1;

    IF ISNULL(@PostWrapperLockMode, N'NoLock') <> N'NoLock'
        THROW 51952, 'The refused ambient wrapper call retained the private import mutex.', 1;

    BEGIN TRANSACTION;

    EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
        @LockTimeout = 0,
        @LockResult = @AuthorizedResult OUTPUT;

    ROLLBACK TRANSACTION;

    IF @AuthorizedResult < 0
        THROW 51946, 'The authorized operator context could not acquire the private import mutex.', 1;

    SET @ProbeUserSql = N'DROP USER ' + QUOTENAME(@ProbeUser) + N';';
    EXEC sys.sp_executesql @ProbeUserSql;

    IF @@TRANCOUNT <> 0
        THROW 51947, 'Phase 3 lock authorization verification leaked a transaction.', 1;

    SELECT
        N'phase3_import_lock_authorization' AS EvidenceSection,
        @DirectRoleError AS DirectRoleError,
        @DirectLockHelperError AS DirectLockHelperError,
        @DirectHashHelperError AS DirectHashHelperError,
        @DirectCoreError AS DirectCoreError,
        @AuthorizedWrapperError AS AuthorizedWrapperError,
        @AmbientWrapperError AS AmbientWrapperError,
        @PostWrapperLockMode AS PostWrapperLockMode,
        @AuthorizedResult AS AuthorizedResult,
        XACT_STATE() AS FinalXactState,
        @@TRANCOUNT AS FinalTranCount,
        N'PASS' AS VerificationStatus;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    IF @Impersonating = 1
        REVERT;

    IF DATABASE_PRINCIPAL_ID(@ProbeUser) IS NOT NULL
    BEGIN
        SET @ProbeUserSql = N'DROP USER ' + QUOTENAME(@ProbeUser) + N';';
        EXEC sys.sp_executesql @ProbeUserSql;
    END;

    THROW;
END CATCH;
