/*
Purpose:
    Prove every externally executable Phase 3 import entry point refuses a
    caller-owned transaction before lock acquisition or data mutation.

Safety:
    - Refuses production and any database except the isolated rehearsal copy.
    - Each call is made inside a transaction that is immediately rolled back.
    - Expected guards run before file, staging, or canonical work.
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 52230, 'Phase 3 ambient-transaction verification refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52231, 'Phase 3 ambient-transaction verification is connected to the wrong database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52232, 'Phase 3 ambient-transaction verification requires no existing transaction.', 1;

DECLARE @Results table
(
    EntryPoint sysname NOT NULL PRIMARY KEY,
    ExpectedError int NOT NULL,
    ObservedError int NULL,
    LockMode nvarchar(32) NULL,
    TranCountBeforeRollback int NULL,
    XactStateBeforeRollback int NULL
);

INSERT @Results (EntryPoint, ExpectedError)
VALUES
    (N'dbo.IMPORT_STAGING_PROC', 51807),
    (N'dbo.FIX_IMPORT_STAGING', 51833),
    (N'dbo.UPDATE_ALL', 51828),
    (N'dbo.UPDATE_ALL2', 51818),
    (N'dbo.ARCHIVE_IMPORT_STAGING_FILE', 51849);

DECLARE @ObservedError int;
DECLARE @LockMode nvarchar(32);
DECLARE @TranCountBeforeRollback int;
DECLARE @XactStateBeforeRollback int;
DECLARE @Digest binary(32);
DECLARE @ArchivePath nvarchar(4000);

BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.IMPORT_STAGING_PROC
        @ImportFileDigest = @Digest OUTPUT,
        @ArchivePath = @ArchivePath OUTPUT;
END TRY
BEGIN CATCH
    SET @ObservedError = ERROR_NUMBER();
END CATCH;
SET @LockMode = APPLOCK_MODE(
    N'K98ImportLockPrincipal',
    N'K98:KingdomScanData4:ImportPipeline:v1',
    N'Transaction'
);
SET @TranCountBeforeRollback = @@TRANCOUNT;
SET @XactStateBeforeRollback = XACT_STATE();
ROLLBACK TRANSACTION;
UPDATE @Results
SET ObservedError = @ObservedError,
    LockMode = @LockMode,
    TranCountBeforeRollback = @TranCountBeforeRollback,
    XactStateBeforeRollback = @XactStateBeforeRollback
WHERE EntryPoint = N'dbo.IMPORT_STAGING_PROC';

SET @ObservedError = NULL;
SET @LockMode = NULL;
SET @TranCountBeforeRollback = NULL;
SET @XactStateBeforeRollback = NULL;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.FIX_IMPORT_STAGING;
END TRY
BEGIN CATCH
    SET @ObservedError = ERROR_NUMBER();
END CATCH;
SET @LockMode = APPLOCK_MODE(
    N'K98ImportLockPrincipal',
    N'K98:KingdomScanData4:ImportPipeline:v1',
    N'Transaction'
);
SET @TranCountBeforeRollback = @@TRANCOUNT;
SET @XactStateBeforeRollback = XACT_STATE();
ROLLBACK TRANSACTION;
UPDATE @Results
SET ObservedError = @ObservedError,
    LockMode = @LockMode,
    TranCountBeforeRollback = @TranCountBeforeRollback,
    XactStateBeforeRollback = @XactStateBeforeRollback
WHERE EntryPoint = N'dbo.FIX_IMPORT_STAGING';

SET @ObservedError = NULL;
SET @LockMode = NULL;
SET @TranCountBeforeRollback = NULL;
SET @XactStateBeforeRollback = NULL;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.UPDATE_ALL;
END TRY
BEGIN CATCH
    SET @ObservedError = ERROR_NUMBER();
END CATCH;
SET @LockMode = APPLOCK_MODE(
    N'K98ImportLockPrincipal',
    N'K98:KingdomScanData4:ImportPipeline:v1',
    N'Transaction'
);
SET @TranCountBeforeRollback = @@TRANCOUNT;
SET @XactStateBeforeRollback = XACT_STATE();
ROLLBACK TRANSACTION;
UPDATE @Results
SET ObservedError = @ObservedError,
    LockMode = @LockMode,
    TranCountBeforeRollback = @TranCountBeforeRollback,
    XactStateBeforeRollback = @XactStateBeforeRollback
WHERE EntryPoint = N'dbo.UPDATE_ALL';

SET @ObservedError = NULL;
SET @LockMode = NULL;
SET @TranCountBeforeRollback = NULL;
SET @XactStateBeforeRollback = NULL;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.UPDATE_ALL2;
END TRY
BEGIN CATCH
    SET @ObservedError = ERROR_NUMBER();
END CATCH;
SET @LockMode = APPLOCK_MODE(
    N'K98ImportLockPrincipal',
    N'K98:KingdomScanData4:ImportPipeline:v1',
    N'Transaction'
);
SET @TranCountBeforeRollback = @@TRANCOUNT;
SET @XactStateBeforeRollback = XACT_STATE();
ROLLBACK TRANSACTION;
UPDATE @Results
SET ObservedError = @ObservedError,
    LockMode = @LockMode,
    TranCountBeforeRollback = @TranCountBeforeRollback,
    XactStateBeforeRollback = @XactStateBeforeRollback
WHERE EntryPoint = N'dbo.UPDATE_ALL2';

SET @ObservedError = NULL;
SET @LockMode = NULL;
SET @TranCountBeforeRollback = NULL;
SET @XactStateBeforeRollback = NULL;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
        @FileDigest =
            0x0000000000000000000000000000000000000000000000000000000000000000;
END TRY
BEGIN CATCH
    SET @ObservedError = ERROR_NUMBER();
END CATCH;
SET @LockMode = APPLOCK_MODE(
    N'K98ImportLockPrincipal',
    N'K98:KingdomScanData4:ImportPipeline:v1',
    N'Transaction'
);
SET @TranCountBeforeRollback = @@TRANCOUNT;
SET @XactStateBeforeRollback = XACT_STATE();
ROLLBACK TRANSACTION;
UPDATE @Results
SET ObservedError = @ObservedError,
    LockMode = @LockMode,
    TranCountBeforeRollback = @TranCountBeforeRollback,
    XactStateBeforeRollback = @XactStateBeforeRollback
WHERE EntryPoint = N'dbo.ARCHIVE_IMPORT_STAGING_FILE';

IF EXISTS
(
    SELECT 1
    FROM @Results
    WHERE ObservedError <> ExpectedError
       OR TranCountBeforeRollback <> 1
       OR XactStateBeforeRollback <> 1
       OR ISNULL(LockMode, N'NoLock') <> N'NoLock'
)
BEGIN
    SELECT * FROM @Results ORDER BY EntryPoint;
    THROW 52233, 'A public import entry point did not fail closed before lock acquisition.', 1;
END;

IF @@TRANCOUNT <> 0 OR XACT_STATE() <> 0
    THROW 52234, 'Phase 3 ambient-transaction verification leaked a transaction.', 1;

SELECT
    N'phase3_public_entrypoint_ambient_transactions' AS EvidenceSection,
    EntryPoint,
    ExpectedError,
    ObservedError,
    LockMode,
    TranCountBeforeRollback,
    XactStateBeforeRollback,
    N'PASS' AS VerificationStatus
FROM @Results
ORDER BY EntryPoint;
