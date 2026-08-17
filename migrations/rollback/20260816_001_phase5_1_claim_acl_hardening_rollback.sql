/*
RollbackForMigrationId: 20260816_001_phase5_1_claim_acl_hardening
Purpose: Restore the accepted Phase 5.0 claim procedure and remove unused ACL evidence columns
Author: cwatts
CreatedUtc: 2026-08-16
RiskLevel: High
DataLossRisk: None when the early-rollback guards pass
RollbackType: Full
RequiresBackup: Yes
PreRollbackValidation: Bot and direct writers stopped; no row has ACL-hardening evidence; no nonterminal claim exists
PostRollbackValidation: ACL evidence columns absent and the Phase 5.0 claim procedure restored
RelatedSQLPR:
*/

/*
Early rollback only:
    - This rollback deliberately refuses after any claim has used the hardened contract.
    - If AclHardenedAtUtc is populated, retain the evidence and use a reviewed forward fix.
    - Directory ACL rollback is not performed here. Do not weaken filesystem ACLs automatically.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 60000;

BEGIN TRANSACTION;

DECLARE @MigrationLockResult int;
EXEC @MigrationLockResult = sys.sp_getapplock
    @Resource = N'K98:KingdomScanData4:Migration',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 60000,
    @DbPrincipal = N'public';

IF @MigrationLockResult < 0
    THROW 52530, 'Phase 5.1 ACL rollback could not acquire the migration mutex.', 1;

DECLARE @ImportLockResult int;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
    @LockTimeout = 60000,
    @LockResult = @ImportLockResult OUTPUT;

IF @ImportLockResult < 0
    THROW 52531, 'Phase 5.1 ACL rollback could not acquire the import mutex.', 1;

IF COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclHardenedAtUtc') IS NULL
   OR COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclOwnerIdentity') IS NULL
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P')) NOT LIKE N'%ICACLS%'
    THROW 52532, 'Phase 5.1 ACL rollback refused a missing or drifted deployment.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim
    WHERE AclHardenedAtUtc IS NOT NULL
       OR AclOwnerIdentity IS NOT NULL
       OR ClaimStatus NOT IN (N'archived', N'duplicate_archived')
)
    THROW 52533, 'Phase 5.1 ACL rollback refuses used ACL evidence or a nonterminal claim; use a forward fix.', 1;
GO

-- Restores the exact accepted Phase 5.0 procedure from SQL commit 2e0f228f.
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CLAIM_KS4_IMPORT_FILE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CLAIM_KS4_IMPORT_FILE] AS'
END
ALTER PROCEDURE [dbo].[CLAIM_KS4_IMPORT_FILE]
    @CompletedFileName [nvarchar](260),
    @FileDigest [binary](32) OUTPUT,
    @ClaimedPath [nvarchar](4000) OUTPUT,
    @ArchivePath [nvarchar](4000) OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0
        THROW 51874, 'CLAIM_KS4_IMPORT_FILE refuses caller-owned transactions.', 1;

    IF @CompletedFileName IS NULL
       OR DATALENGTH(@CompletedFileName) <> 96
       OR LEFT(@CompletedFileName, 6) <> N'stats_'
       OR RIGHT(@CompletedFileName, 10) <> N'.ready.csv'
       OR SUBSTRING(@CompletedFileName, 7, 32)
            COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%'
        THROW 51875, 'CLAIM_KS4_IMPORT_FILE requires stats_<32 lowercase hex>.ready.csv.', 1;

    DECLARE @ReadyPath nvarchar(4000) =
        N'C:\discord_file_downloader\downloads\Import_Ready\' + @CompletedFileName;
    DECLARE @ExpectedClaimedPath nvarchar(4000) =
        N'C:\discord_file_downloader\downloads\Import_Claimed\' + @CompletedFileName;
    DECLARE @ExpectedArchivePath nvarchar(4000) =
        N'C:\discord_file_downloader\downloads\Import_Archive\' + @CompletedFileName;
    DECLARE @ClaimStatus nvarchar(24);
    DECLARE @ReadyExists int;
    DECLARE @ClaimedExists int;
    DECLARE @ArchiveExists int;
    DECLARE @MoveCommand nvarchar(4000);
    DECLARE @MoveExitCode int;
    DECLARE @ImportLockResult int;
    DECLARE @Duplicate bit = 0;

    SET @FileDigest = NULL;
    SET @ClaimedPath = @ExpectedClaimedPath;
    SET @ArchivePath = @ExpectedArchivePath;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51876, 'CLAIM_KS4_IMPORT_FILE could not acquire the KingdomScanData4 import mutex.', 1;

        SELECT
            @ClaimStatus = ClaimStatus,
            @FileDigest = FileDigest,
            @ClaimedPath = ClaimedPath,
            @ArchivePath = ArchivePath
        FROM dbo.KS4_ImportFileClaim WITH (UPDLOCK, HOLDLOCK)
        WHERE CompletedFileName = @CompletedFileName;

        IF @ClaimStatus IS NULL
        BEGIN
            INSERT dbo.KS4_ImportFileClaim
            (
                CompletedFileName,
                ReadyPath,
                ClaimedPath,
                ArchivePath,
                FileDigest,
                ClaimStatus,
                ClaimRequestedAtUtc,
                ClaimedAtUtc,
                ImportCommittedAtUtc,
                ArchivedAtUtc,
                LastError
            )
            VALUES
            (
                @CompletedFileName,
                @ReadyPath,
                @ExpectedClaimedPath,
                @ExpectedArchivePath,
                NULL,
                N'claiming',
                SYSUTCDATETIME(),
                NULL,
                NULL,
                NULL,
                NULL
            );

            SET @ClaimStatus = N'claiming';
            SET @ClaimedPath = @ExpectedClaimedPath;
            SET @ArchivePath = @ExpectedArchivePath;
        END
        ELSE IF @ClaimedPath <> @ExpectedClaimedPath
             OR @ArchivePath <> @ExpectedArchivePath
        BEGIN
            THROW 51877, 'CLAIM_KS4_IMPORT_FILE found claim-path definition drift.', 1;
        END;

        COMMIT TRANSACTION;

        IF @ClaimStatus IN (N'archived', N'duplicate_archived')
            THROW 51878, 'CLAIM_KS4_IMPORT_FILE refused a completed filename that was already handled.', 1;

        IF @ClaimStatus IN (N'imported', N'duplicate')
        BEGIN
            EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
                @CompletedFileName = @CompletedFileName;

            THROW 51879, 'CLAIM_KS4_IMPORT_FILE reconciled an already committed or duplicate claim; no new scan was allocated.', 1;
        END;

        EXEC master.dbo.xp_fileexist @ReadyPath, @ReadyExists OUTPUT;
        EXEC master.dbo.xp_fileexist @ClaimedPath, @ClaimedExists OUTPUT;
        EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

        IF ISNULL(@ArchiveExists, 0) = 1
            THROW 51880, 'CLAIM_KS4_IMPORT_FILE refused an unexpected pre-existing archive destination.', 1;

        IF ISNULL(@ReadyExists, 0) = 1 AND ISNULL(@ClaimedExists, 0) = 1
            THROW 51881, 'CLAIM_KS4_IMPORT_FILE found both ready and claimed copies for one identity.', 1;

        IF ISNULL(@ReadyExists, 0) <> 1 AND ISNULL(@ClaimedExists, 0) <> 1
            THROW 51882, 'CLAIM_KS4_IMPORT_FILE found neither the ready file nor a recoverable claimed file.', 1;

        IF ISNULL(@ReadyExists, 0) = 1
        BEGIN
            SET @MoveCommand =
                N'CMD /D /C MOVE "'
                + @ReadyPath
                + N'" "'
                + @ClaimedPath
                + N'"';

            EXEC @MoveExitCode = master.dbo.xp_cmdshell @MoveCommand, NO_OUTPUT;

            SET @ReadyExists = 0;
            SET @ClaimedExists = 0;
            EXEC master.dbo.xp_fileexist @ReadyPath, @ReadyExists OUTPUT;
            EXEC master.dbo.xp_fileexist @ClaimedPath, @ClaimedExists OUTPUT;

            IF ISNULL(@MoveExitCode, 1) <> 0
               OR ISNULL(@ReadyExists, 0) = 1
               OR ISNULL(@ClaimedExists, 0) <> 1
                THROW 51883, 'CLAIM_KS4_IMPORT_FILE could not verify the ready-to-claimed move.', 1;
        END;

        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath = @ClaimedPath,
            @FileDigest = @FileDigest OUTPUT;

        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51884, 'CLAIM_KS4_IMPORT_FILE could not reacquire the import mutex after the filesystem claim.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
            WHERE FileDigest = @FileDigest
        )
            SET @Duplicate = 1;

        UPDATE dbo.KS4_ImportFileClaim
        SET FileDigest = @FileDigest,
            ClaimStatus = CASE WHEN @Duplicate = 1 THEN N'duplicate' ELSE N'claimed' END,
            ClaimedAtUtc = COALESCE(ClaimedAtUtc, SYSUTCDATETIME()),
            LastError = NULL
        WHERE CompletedFileName = @CompletedFileName
          AND ClaimStatus IN (N'claiming', N'claimed', N'failed', N'duplicate');

        IF @@ROWCOUNT <> 1
            THROW 51885, 'CLAIM_KS4_IMPORT_FILE could not advance exactly one durable claim.', 1;

        COMMIT TRANSACTION;

        IF @Duplicate = 1
        BEGIN
            EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
                @CompletedFileName = @CompletedFileName;

            THROW 51803, 'IMPORT_STAGING_PROC refused bytes that already have a committed receipt; the duplicate claim was archived without allocating another scan.', 1;
        END;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage nvarchar(2000) = ERROR_MESSAGE();

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        BEGIN TRY
            UPDATE dbo.KS4_ImportFileClaim
            SET ClaimStatus =
                    CASE
                        WHEN ClaimStatus IN (N'claimed', N'archived', N'duplicate_archived', N'imported', N'duplicate')
                            THEN ClaimStatus
                        ELSE N'failed'
                    END,
                LastError =
                    CASE
                        WHEN ClaimStatus IN (N'claimed', N'archived', N'duplicate_archived')
                            THEN LastError
                        ELSE @ErrorMessage
                    END
            WHERE CompletedFileName = @CompletedFileName;
        END TRY
        BEGIN CATCH
            -- Preserve the original claim failure.
        END CATCH;

        THROW;
    END CATCH;
END
GO

ALTER TABLE dbo.KS4_ImportFileClaim
DROP CONSTRAINT CK_KS4_ImportFileClaim_AclEvidence;

ALTER TABLE dbo.KS4_ImportFileClaim
DROP COLUMN AclHardenedAtUtc, AclOwnerIdentity;

IF COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclHardenedAtUtc') IS NOT NULL
   OR COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclOwnerIdentity') IS NOT NULL
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P')) LIKE N'%ICACLS%'
    THROW 52534, 'Phase 5.1 ACL rollback post-validation failed.', 1;

EXEC sys.sp_refreshsqlmodule N'dbo.CLAIM_KS4_IMPORT_FILE';

COMMIT TRANSACTION;
GO
