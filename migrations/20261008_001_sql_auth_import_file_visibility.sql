/*
MigrationId: 20261008_001_sql_auth_import_file_visibility
Purpose: Use authentication-independent file metadata for immutable scan imports
Author: cwatts
CreatedUtc: 2026-10-08
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
*/
-- Stop and drain the S11 execution pair before applying. Rebuild the accepted
-- SQL runtime contract before restarting. This migration performs no imports,
-- resource release, claim recovery, provider requests, or feature activation.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF DB_NAME() COLLATE Latin1_General_100_BIN2 <> N'ROK_TRACKER'
    THROW 51920, 'ROK_TRACKER required.', 1;
IF @@TRANCOUNT <> 0
    THROW 51920, 'Own migration transaction required.', 1;
IF TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) < 16
    THROW 51920, 'Validated SQL Server 2022 or newer required.', 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @Lock int;
    EXEC @Lock = sys.sp_getapplock @Resource=N'K98:S11:schema',
        @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=0;
    IF @Lock < 0 THROW 51920, 'Schema busy.', 1;
    IF EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WHERE State <> 'closed')
        THROW 51920, 'Execution sessions must be closed before module replacement.', 1;
    DECLARE @Modules table (
        Name sysname NOT NULL PRIMARY KEY,
        BeforeHash binary(32) NOT NULL,
        AfterHash binary(32) NOT NULL,
        Body nvarchar(max) NOT NULL,
        ObjectID int NULL
    );
    INSERT @Modules (Name, BeforeHash, AfterHash, Body) VALUES
        (N'dbo.ARCHIVE_IMPORT_STAGING_FILE', 0x0F1E7316586FA384D5CF0DFDFBD8C77D212119E5EE1B4FB7FB1ECD00099AF473, 0x70E61C64FB3F0BB514F7BECFABE57231D9DEE9610CEFAA3F47C69D81DAAEA80D, N'ALTER PROCEDURE [dbo].[ARCHIVE_IMPORT_STAGING_FILE]
    @CompletedFileName [nvarchar](260)
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ImportLockResult int;
    DECLARE @FileDigest binary(32);
    DECLARE @SourcePath nvarchar(4000);
    DECLARE @ArchivePath nvarchar(4000);
    DECLARE @ClaimStatus nvarchar(24);
    DECLARE @SourceExists int;
    DECLARE @ArchiveExists int;
    DECLARE @CurrentFileDigest binary(32);
    DECLARE @MoveCommand nvarchar(4000);
    DECLARE @MoveExitCode int;
    DECLARE @FinalStatus nvarchar(24);

    IF @@TRANCOUNT <> 0
        THROW 51849, ''ARCHIVE_IMPORT_STAGING_FILE refuses caller-owned transactions; execute the public entry point with no active transaction.'', 1;

    SET XACT_ABORT ON;

    IF @CompletedFileName IS NULL
        THROW 51840, ''ARCHIVE_IMPORT_STAGING_FILE requires a completed filename.'', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51841, ''ARCHIVE_IMPORT_STAGING_FILE could not acquire the KingdomScanData4 import mutex within 60000 ms.'', 1;

        SELECT
            @FileDigest = FileDigest,
            @SourcePath = ClaimedPath,
            @ArchivePath = ArchivePath,
            @ClaimStatus = ClaimStatus
        FROM dbo.KS4_ImportFileClaim WITH (UPDLOCK, HOLDLOCK)
        WHERE CompletedFileName = @CompletedFileName;

        IF @SourcePath IS NULL OR @FileDigest IS NULL
            THROW 51842, ''ARCHIVE_IMPORT_STAGING_FILE did not find a digest-bound claim for the requested filename.'', 1;

        IF @SourcePath <>
                N''C:\discord_file_downloader\downloads\Import_Claimed\'' + @CompletedFileName
           OR @ArchivePath <>
                N''C:\discord_file_downloader\downloads\Import_Archive\'' + @CompletedFileName
            THROW 51843, ''ARCHIVE_IMPORT_STAGING_FILE refused claim-path definition drift.'', 1;

        IF @ClaimStatus NOT IN
           (
               N''imported'',
               N''archived'',
               N''duplicate'',
               N''duplicate_archived''
           )
            THROW 51851, ''ARCHIVE_IMPORT_STAGING_FILE refused a claim that is not committed or duplicate.'', 1;

        SET @FinalStatus =
            CASE
                WHEN @ClaimStatus IN (N''duplicate'', N''duplicate_archived'')
                    THEN N''duplicate_archived''
                ELSE N''archived''
            END;

        IF @ClaimStatus IN (N''imported'', N''archived'')
           AND NOT EXISTS
           (
               SELECT 1
               FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
               WHERE FileDigest = @FileDigest
                 AND SourcePath = @SourcePath
                 AND ArchivePath = @ArchivePath
           )
            THROW 51852, ''ARCHIVE_IMPORT_STAGING_FILE did not find the matching committed receipt.'', 1;

        IF @ClaimStatus IN (N''duplicate'', N''duplicate_archived'')
           AND NOT EXISTS
           (
               SELECT 1
               FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
               WHERE FileDigest = @FileDigest
           )
            THROW 51853, ''ARCHIVE_IMPORT_STAGING_FILE could not bind the duplicate claim to an existing receipt.'', 1;

        SET @SourceExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@SourcePath)), 0);
        SET @ArchiveExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@ArchivePath)), 0);

        -- Reconcile a previous move that completed before its database status
        -- update. The destination digest is authoritative for reconciliation.
        IF ISNULL(@SourceExists, 0) <> 1 AND ISNULL(@ArchiveExists, 0) = 1
        BEGIN
            SET @CurrentFileDigest = NULL;

            EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
                @ApprovedPath = @ArchivePath,
                @FileDigest = @CurrentFileDigest OUTPUT;

            IF @CurrentFileDigest IS NULL OR @CurrentFileDigest <> @FileDigest
                THROW 51850, ''ARCHIVE_IMPORT_STAGING_FILE refused to reconcile an archive destination whose digest differs from the claim.'', 1;

            UPDATE dbo.KS4_ImportFileClaim
            SET ClaimStatus = @FinalStatus,
                ArchivedAtUtc = COALESCE(ArchivedAtUtc, SYSUTCDATETIME()),
                LastError = NULL
            WHERE CompletedFileName = @CompletedFileName;

            IF @FinalStatus = N''archived''
            BEGIN
                UPDATE dbo.KS4_ImportFileReceipt
                SET ArchiveStatus = N''archived'',
                    ArchivedAtUtc = COALESCE(ArchivedAtUtc, SYSUTCDATETIME()),
                    LastArchiveError = NULL
                WHERE FileDigest = @FileDigest;
            END;

            COMMIT TRANSACTION;
            RETURN 0;
        END;

        IF ISNULL(@SourceExists, 0) <> 1
            THROW 51844, ''ARCHIVE_IMPORT_STAGING_FILE found neither the claimed file nor its archive destination.'', 1;

        IF ISNULL(@ArchiveExists, 0) = 1
            THROW 51845, ''ARCHIVE_IMPORT_STAGING_FILE refused to overwrite an existing archive destination.'', 1;

        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath = @SourcePath,
            @FileDigest = @CurrentFileDigest OUTPUT;

        IF @CurrentFileDigest IS NULL OR @CurrentFileDigest <> @FileDigest
            THROW 51846, ''ARCHIVE_IMPORT_STAGING_FILE refused to move claimed bytes that differ from the durable digest.'', 1;

        SET @MoveCommand =
            N''CMD /D /C MOVE "''
            + @SourcePath
            + N''" "''
            + @ArchivePath
            + N''"'';

        EXEC @MoveExitCode = master.dbo.xp_cmdshell @MoveCommand, NO_OUTPUT;

        SET @SourceExists = 0;
        SET @ArchiveExists = 0;
        SET @SourceExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@SourcePath)), 0);
        SET @ArchiveExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@ArchivePath)), 0);

        IF ISNULL(@MoveExitCode, 1) <> 0
           OR ISNULL(@SourceExists, 0) = 1
           OR ISNULL(@ArchiveExists, 0) <> 1
            THROW 51847, ''ARCHIVE_IMPORT_STAGING_FILE could not verify a successful filesystem move.'', 1;

        SET @CurrentFileDigest = NULL;

        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath = @ArchivePath,
            @FileDigest = @CurrentFileDigest OUTPUT;

        IF @CurrentFileDigest IS NULL OR @CurrentFileDigest <> @FileDigest
            THROW 51854, ''ARCHIVE_IMPORT_STAGING_FILE refused to advance after the archive destination rehash changed.'', 1;

        UPDATE dbo.KS4_ImportFileClaim
        SET ClaimStatus = @FinalStatus,
            ArchivedAtUtc = SYSUTCDATETIME(),
            LastError = NULL
        WHERE CompletedFileName = @CompletedFileName;

        IF @FinalStatus = N''archived''
        BEGIN
            UPDATE dbo.KS4_ImportFileReceipt
            SET ArchiveStatus = N''archived'',
                ArchivedAtUtc = SYSUTCDATETIME(),
                LastArchiveError = NULL
            WHERE FileDigest = @FileDigest;
        END;

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage nvarchar(2000) = ERROR_MESSAGE();

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        BEGIN TRY
            UPDATE dbo.KS4_ImportFileClaim
            SET LastError = @ErrorMessage
            WHERE CompletedFileName = @CompletedFileName
              AND ClaimStatus NOT IN (N''archived'', N''duplicate_archived'');

            IF @FileDigest IS NOT NULL
            BEGIN
                UPDATE dbo.KS4_ImportFileReceipt
                SET LastArchiveError = @ErrorMessage
                WHERE FileDigest = @FileDigest
                  AND ArchiveStatus = N''pending'';
            END;
        END TRY
        BEGIN CATCH
            -- Preserve the original archive failure.
        END CATCH;

        THROW;
    END CATCH;
END');
    INSERT @Modules (Name, BeforeHash, AfterHash, Body) VALUES
        (N'dbo.CLAIM_KS4_IMPORT_FILE', 0x9B2962A24D2AB9A9BB8F7C551A96F07B65B03FC3309BA48273AE3581D5A26787, 0xCAB5F8AC4855986C66284FE71401A85BFFE2E195B5E843AC8B77E4DA7EB13AA9, N'ALTER PROCEDURE [dbo].[CLAIM_KS4_IMPORT_FILE]
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
        THROW 51874, ''CLAIM_KS4_IMPORT_FILE refuses caller-owned transactions.'', 1;

    IF @CompletedFileName IS NULL
       OR DATALENGTH(@CompletedFileName) <> 96
       OR LEFT(@CompletedFileName, 6) <> N''stats_''
       OR RIGHT(@CompletedFileName, 10) <> N''.ready.csv''
       OR SUBSTRING(@CompletedFileName, 7, 32)
            COLLATE Latin1_General_100_BIN2 LIKE N''%[^0-9a-f]%''
        THROW 51875, ''CLAIM_KS4_IMPORT_FILE requires stats_<32 lowercase hex>.ready.csv.'', 1;

    DECLARE @ReadyPath nvarchar(4000) =
        N''C:\discord_file_downloader\downloads\Import_Ready\'' + @CompletedFileName;
    DECLARE @ExpectedClaimedPath nvarchar(4000) =
        N''C:\discord_file_downloader\downloads\Import_Claimed\'' + @CompletedFileName;
    DECLARE @ExpectedArchivePath nvarchar(4000) =
        N''C:\discord_file_downloader\downloads\Import_Archive\'' + @CompletedFileName;
    DECLARE @ClaimStatus nvarchar(24);
    DECLARE @ReadyExists int;
    DECLARE @ClaimedExists int;
    DECLARE @ArchiveExists int;
    DECLARE @MoveCommand nvarchar(4000);
    DECLARE @MoveExitCode int;
    DECLARE @AclCommand nvarchar(4000);
    DECLARE @AclExitCode int;
    DECLARE @AclOwnerIdentity nvarchar(256);
    DECLARE @AclHardenedAtUtc datetime2(3);
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
            THROW 51876, ''CLAIM_KS4_IMPORT_FILE could not acquire the KingdomScanData4 import mutex.'', 1;

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
                AclHardenedAtUtc,
                AclOwnerIdentity,
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
                N''claiming'',
                SYSUTCDATETIME(),
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL
            );

            SET @ClaimStatus = N''claiming'';
            SET @ClaimedPath = @ExpectedClaimedPath;
            SET @ArchivePath = @ExpectedArchivePath;
        END
        ELSE IF @ClaimedPath <> @ExpectedClaimedPath
             OR @ArchivePath <> @ExpectedArchivePath
        BEGIN
            THROW 51877, ''CLAIM_KS4_IMPORT_FILE found claim-path definition drift.'', 1;
        END;

        COMMIT TRANSACTION;

        IF @ClaimStatus IN (N''archived'', N''duplicate_archived'')
            THROW 51878, ''CLAIM_KS4_IMPORT_FILE refused a completed filename that was already handled.'', 1;

        IF @ClaimStatus IN (N''imported'', N''duplicate'')
        BEGIN
            EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
                @CompletedFileName = @CompletedFileName;

            THROW 51879, ''CLAIM_KS4_IMPORT_FILE reconciled an already committed or duplicate claim; no new scan was allocated.'', 1;
        END;

        SET @ReadyExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@ReadyPath)), 0);
        SET @ClaimedExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@ClaimedPath)), 0);
        SET @ArchiveExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@ArchivePath)), 0);

        IF ISNULL(@ArchiveExists, 0) = 1
            THROW 51880, ''CLAIM_KS4_IMPORT_FILE refused an unexpected pre-existing archive destination.'', 1;

        IF ISNULL(@ReadyExists, 0) = 1 AND ISNULL(@ClaimedExists, 0) = 1
            THROW 51881, ''CLAIM_KS4_IMPORT_FILE found both ready and claimed copies for one identity.'', 1;

        IF ISNULL(@ReadyExists, 0) <> 1 AND ISNULL(@ClaimedExists, 0) <> 1
            THROW 51882, ''CLAIM_KS4_IMPORT_FILE found neither the ready file nor a recoverable claimed file.'', 1;

        IF ISNULL(@ReadyExists, 0) = 1
        BEGIN
            SET @MoveCommand =
                N''CMD /D /C MOVE "''
                + @ReadyPath
                + N''" "''
                + @ClaimedPath
                + N''"'';

            EXEC @MoveExitCode = master.dbo.xp_cmdshell @MoveCommand, NO_OUTPUT;

            SET @ReadyExists = 0;
            SET @ClaimedExists = 0;
            SET @ReadyExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@ReadyPath)), 0);
            SET @ClaimedExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@ClaimedPath)), 0);

            IF ISNULL(@MoveExitCode, 1) <> 0
               OR ISNULL(@ReadyExists, 0) = 1
               OR ISNULL(@ClaimedExists, 0) <> 1
                THROW 51883, ''CLAIM_KS4_IMPORT_FILE could not verify the ready-to-claimed move.'', 1;
        END;

        CREATE TABLE #XpCmdShellIdentity
        (
            OutputLine nvarchar(4000) NULL
        );

        INSERT #XpCmdShellIdentity (OutputLine)
        EXEC @AclExitCode = master.dbo.xp_cmdshell N''WHOAMI'';

        SELECT TOP (1)
            @AclOwnerIdentity = LOWER(LTRIM(RTRIM(OutputLine)))
        FROM #XpCmdShellIdentity
        WHERE NULLIF(LTRIM(RTRIM(OutputLine)), N'''') IS NOT NULL;

        DROP TABLE #XpCmdShellIdentity;

        IF ISNULL(@AclExitCode, 1) <> 0
           OR @AclOwnerIdentity IS NULL
           OR @AclOwnerIdentity COLLATE Latin1_General_100_BIN2 LIKE N''%[^0-9A-Za-z ._\$-]%''
            THROW 51886, ''CLAIM_KS4_IMPORT_FILE could not resolve a safe xp_cmdshell owner identity.'', 1;

        SET @AclCommand =
            N''ICACLS "''
            + @ClaimedPath
            + N''" /SETOWNER "''
            + @AclOwnerIdentity
            + N''" /Q'';

        EXEC @AclExitCode = master.dbo.xp_cmdshell @AclCommand, NO_OUTPUT;

        IF ISNULL(@AclExitCode, 1) <> 0
            THROW 51887, ''CLAIM_KS4_IMPORT_FILE could not transfer claimed-file ownership to the xp_cmdshell identity.'', 1;

        SET @AclCommand =
            N''ICACLS "''
            + @ClaimedPath
            + N''" /RESET /Q'';

        EXEC @AclExitCode = master.dbo.xp_cmdshell @AclCommand, NO_OUTPUT;

        IF ISNULL(@AclExitCode, 1) <> 0
            THROW 51888, ''CLAIM_KS4_IMPORT_FILE could not reset the claimed file to the Claimed directory ACL.'', 1;

        SET @AclCommand =
            N''ICACLS "''
            + @ClaimedPath
            + N''" /VERIFY /Q'';

        EXEC @AclExitCode = master.dbo.xp_cmdshell @AclCommand, NO_OUTPUT;

        SET @ClaimedExists = 0;
        SET @ClaimedExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@ClaimedPath)), 0);

        IF ISNULL(@AclExitCode, 1) <> 0
           OR ISNULL(@ClaimedExists, 0) <> 1
            THROW 51889, ''CLAIM_KS4_IMPORT_FILE could not verify the hardened claimed file.'', 1;

        SET @AclHardenedAtUtc = SYSUTCDATETIME();

        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath = @ClaimedPath,
            @FileDigest = @FileDigest OUTPUT;

        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51884, ''CLAIM_KS4_IMPORT_FILE could not reacquire the import mutex after the filesystem claim.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
            WHERE FileDigest = @FileDigest
        )
            SET @Duplicate = 1;

        UPDATE dbo.KS4_ImportFileClaim
        SET FileDigest = @FileDigest,
            ClaimStatus = CASE WHEN @Duplicate = 1 THEN N''duplicate'' ELSE N''claimed'' END,
            ClaimedAtUtc = COALESCE(ClaimedAtUtc, SYSUTCDATETIME()),
            AclHardenedAtUtc = COALESCE(AclHardenedAtUtc, @AclHardenedAtUtc),
            AclOwnerIdentity = COALESCE(AclOwnerIdentity, @AclOwnerIdentity),
            LastError = NULL
        WHERE CompletedFileName = @CompletedFileName
          AND ClaimStatus IN (N''claiming'', N''claimed'', N''failed'', N''duplicate'');

        IF @@ROWCOUNT <> 1
            THROW 51885, ''CLAIM_KS4_IMPORT_FILE could not advance exactly one durable claim.'', 1;

        COMMIT TRANSACTION;

        IF @Duplicate = 1
        BEGIN
            EXEC dbo.ARCHIVE_IMPORT_STAGING_FILE
                @CompletedFileName = @CompletedFileName;

            THROW 51803, ''IMPORT_STAGING_PROC refused bytes that already have a committed receipt; the duplicate claim was archived without allocating another scan.'', 1;
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
                        WHEN ClaimStatus IN (N''claimed'', N''archived'', N''duplicate_archived'', N''imported'', N''duplicate'')
                            THEN ClaimStatus
                        ELSE N''failed''
                    END,
                LastError =
                    CASE
                        WHEN ClaimStatus IN (N''claimed'', N''archived'', N''duplicate_archived'')
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
END');
    INSERT @Modules (Name, BeforeHash, AfterHash, Body) VALUES
        (N'dbo.IMPORT_STAGING_PROC_CORE', 0xBE5B9B541C90D5C596BBEDE9471443D74DE1E17F4FAEBB8D7FA1E73FF9331C79, 0x512580FE637F13BF8DE91070EC760B7E95F13A9301FAE13D9E6C8770B9045C40, N'ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC_CORE]
    @CompletedFileName [nvarchar](260),
    @ImportFileDigest [binary](32) = NULL OUTPUT,
    @ArchivePath [nvarchar](4000) = NULL OUTPUT,
    @ImportError [nvarchar](2000) = NULL OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ----------------------------------------------------------------
    -- This procedure:
    -- 1) loads one digest-bound claimed file into dbo.IMPORT_STAGING_CSV_RAW
    -- 2) converts raw text into typed dbo.IMPORT_STAGING_CSV
    -- 3) maps CSV columns into canonical dbo.IMPORT_STAGING
    -- 4) applies a few cleanup fixes, computes deltas against last scan,
    -- 5) records the committed immutable identity for post-commit archive.
    --
    -- Assumptions:
    -- - dbo.IMPORT_STAGING_CSV physical column order and names match the CSV header.
    -- - SQL Server service account has exclusive mutation rights in Import_Claimed.
    ----------------------------------------------------------------

    DECLARE @FileExists INT;
    DECLARE @NextScanOrder INT;
    DECLARE @CurrentMaxScanOrder INT;
    DECLARE @InsertedRows INT = 0;
    DECLARE @LatestDate DATETIME;
    DECLARE @CsvPath NVARCHAR(4000);
    DECLARE @ClaimStatus NVARCHAR(24);
    DECLARE @ClaimDigest BINARY(32);
    DECLARE @CurrentFileDigest BINARY(32);
    DECLARE @EntryTranCount INT = @@TRANCOUNT;
    DECLARE @StartedLocalTransaction BIT = 0;
    DECLARE @ImportLockResult INT;
    DECLARE @ArchiveReturnCode INT;

    SET @ImportFileDigest = NULL;
    SET @ArchivePath = NULL;
    SET @ImportError = NULL;

    BEGIN TRY
            IF @EntryTranCount = 0
            BEGIN
                BEGIN TRANSACTION;
                SET @StartedLocalTransaction = 1;
            END
            ELSE
            BEGIN
                SAVE TRANSACTION IMPORT_STAGING_PROC_SAVEPOINT;
            END;

            EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
                @LockTimeout = 60000,
                @LockResult = @ImportLockResult OUTPUT;

            IF @ImportLockResult < 0
                THROW 51800, ''IMPORT_STAGING_PROC could not acquire the KingdomScanData4 import mutex within 60000 ms; no import work was performed.'', 1;

            SELECT
                @CsvPath = ClaimedPath,
                @ArchivePath = ArchivePath,
                @ClaimStatus = ClaimStatus,
                @ClaimDigest = FileDigest
            FROM dbo.KS4_ImportFileClaim WITH (UPDLOCK, HOLDLOCK)
            WHERE CompletedFileName = @CompletedFileName;

            IF @CsvPath IS NULL
               OR @ClaimStatus <> N''claimed''
               OR @ClaimDigest IS NULL
               OR @CsvPath <>
                    N''C:\discord_file_downloader\downloads\Import_Claimed\'' + @CompletedFileName
               OR @ArchivePath <>
                    N''C:\discord_file_downloader\downloads\Import_Archive\'' + @CompletedFileName
                THROW 51801, ''IMPORT_STAGING_PROC did not find the expected digest-bound claimed file.'', 1;

            SET @ImportFileDigest = @ClaimDigest;

            -- File presence and digest are checked only after the database mutex
            -- is held. The producer cannot mutate the SQL-owned claimed path.
            SET @FileExists = COALESCE((SELECT file_exists FROM sys.dm_os_file_exists(@CsvPath)), 0);

            IF @FileExists <> 1
                THROW 51801, ''IMPORT_STAGING_PROC did not find the claimed file after acquiring the import mutex.'', 1;

            EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
                @ApprovedPath = @CsvPath,
                @FileDigest = @CurrentFileDigest OUTPUT;

            IF @CurrentFileDigest IS NULL
               OR @CurrentFileDigest <> @ImportFileDigest
                THROW 51802, ''IMPORT_STAGING_PROC refused claimed bytes that differ from the durable claim digest.'', 1;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
                WHERE FileDigest = @ImportFileDigest
            )
            BEGIN
                DECLARE @DuplicateFileMessage nvarchar(2048) =
                    CONCAT(
                        N''IMPORT_STAGING_PROC refused claimed bytes that already have a committed receipt. '',
                        N''Reconcile claim '',
                        @CompletedFileName,
                        N'' for digest 0x'',
                        CONVERT(varchar(64), @ImportFileDigest, 2),
                        N'' instead of allocating another scan.''
                    );
                THROW 51803, @DuplicateFileMessage, 1;
            END;

            ----------------------------------------------------------------
            -- Step 1: truncate CSV staging tables (fresh load)
            ----------------------------------------------------------------
            TRUNCATE TABLE dbo.IMPORT_STAGING_CSV_RAW;
            TRUNCATE TABLE dbo.IMPORT_STAGING_CSV;

            ----------------------------------------------------------------
            -- Step 2: BULK INSERT CSV -> IMPORT_STAGING_CSV_RAW
            -- Raw text staging preserves Unicode and separates file decoding
            -- from typed conversion diagnostics.
            ----------------------------------------------------------------
            DECLARE @bulksql NVARCHAR(MAX) = N''
                BULK INSERT dbo.IMPORT_STAGING_CSV_RAW
                FROM '''''' + REPLACE(@CsvPath, '''''''', '''''''''''') + N''''''
                WITH (
                    FORMAT = ''''CSV'''',
                    FIRSTROW = 2,
                    FIELDTERMINATOR = '''','''',
                    FIELDQUOTE = ''''"'''',
                    ROWTERMINATOR = ''''0x0a'''',
                    CODEPAGE = ''''65001'''',
                    TABLOCK
                );'';

            EXEC sp_executesql @bulksql;

            SET @CurrentFileDigest = NULL;

            EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
                @ApprovedPath = @CsvPath,
                @FileDigest = @CurrentFileDigest OUTPUT;

            IF @CurrentFileDigest IS NULL
               OR @CurrentFileDigest <> @ImportFileDigest
                THROW 51808, ''IMPORT_STAGING_PROC detected claimed-file mutation across BULK INSERT.'', 1;

            ----------------------------------------------------------------
            -- Step 3: Convert raw text staging into typed CSV staging.
            ----------------------------------------------------------------
            INSERT INTO dbo.IMPORT_STAGING_CSV (
                [Governor ID], [Name], [Power], [Alliance], [T1-Kills], [T2-Kills], [T3-Kills],
                [T4-Kills], [T5-Kills], [Total Kill Points], [Dead Troops], [Healed Troops],
                [Rss Assistance], [Alliance Helps], [Rss Gathered], [City Hall], [Troops Power],
                [Tech Power], [Building Power], [Commander Power], [Civilization], [Autarch Times],
                [Ranged Points], [KvK Played], [Most KvK Kill], [Most KvK Dead], [Most KvK Heal],
                [Acclaim], [Highest Acclaim], [AOO Joined], [AOO Won], [AOO Avg Kill],
                [AOO Avg Dead], [AOO Avg Heal], [Credit], [updated_on]
            )
            SELECT
                TRY_CAST(NULLIF(REPLACE([Governor ID], '','', ''''), '''') AS bigint) AS [Governor ID],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Name]), CHAR(13), N'' ''), CHAR(10), N'' ''), CHAR(9), N'' ''))), N''''), 200) AS [Name],
                TRY_CAST(NULLIF(REPLACE([Power], '','', ''''), '''') AS bigint) AS [Power],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Alliance]), CHAR(13), N'' ''), CHAR(10), N'' ''), CHAR(9), N'' ''))), N''''), 100) AS [Alliance],
                TRY_CAST(NULLIF(REPLACE([T1-Kills], '','', ''''), '''') AS bigint) AS [T1-Kills],
                TRY_CAST(NULLIF(REPLACE([T2-Kills], '','', ''''), '''') AS bigint) AS [T2-Kills],
                TRY_CAST(NULLIF(REPLACE([T3-Kills], '','', ''''), '''') AS bigint) AS [T3-Kills],
                TRY_CAST(NULLIF(REPLACE([T4-Kills], '','', ''''), '''') AS bigint) AS [T4-Kills],
                TRY_CAST(NULLIF(REPLACE([T5-Kills], '','', ''''), '''') AS bigint) AS [T5-Kills],
                TRY_CAST(NULLIF(REPLACE([Total Kill Points], '','', ''''), '''') AS bigint) AS [Total Kill Points],
                TRY_CAST(NULLIF(REPLACE([Dead Troops], '','', ''''), '''') AS bigint) AS [Dead Troops],
                TRY_CAST(NULLIF(REPLACE([Healed Troops], '','', ''''), '''') AS bigint) AS [Healed Troops],
                TRY_CAST(NULLIF(REPLACE([Rss Assistance], '','', ''''), '''') AS bigint) AS [Rss Assistance],
                TRY_CAST(NULLIF(REPLACE([Alliance Helps], '','', ''''), '''') AS bigint) AS [Alliance Helps],
                TRY_CAST(NULLIF(REPLACE([Rss Gathered], '','', ''''), '''') AS bigint) AS [Rss Gathered],
                TRY_CAST(NULLIF(REPLACE([City Hall], '','', ''''), '''') AS int) AS [City Hall],
                TRY_CAST(NULLIF(REPLACE([Troops Power], '','', ''''), '''') AS bigint) AS [Troops Power],
                TRY_CAST(NULLIF(REPLACE([Tech Power], '','', ''''), '''') AS bigint) AS [Tech Power],
                TRY_CAST(NULLIF(REPLACE([Building Power], '','', ''''), '''') AS bigint) AS [Building Power],
                TRY_CAST(NULLIF(REPLACE([Commander Power], '','', ''''), '''') AS bigint) AS [Commander Power],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Civilization]), CHAR(13), N'' ''), CHAR(10), N'' ''), CHAR(9), N'' ''))), N''''), 100) AS [Civilization],
                TRY_CAST(NULLIF(REPLACE([Autarch Times], '','', ''''), '''') AS int) AS [Autarch Times],
                TRY_CAST(NULLIF(REPLACE([Ranged Points], '','', ''''), '''') AS bigint) AS [Ranged Points],
                TRY_CAST(NULLIF(REPLACE([KvK Played], '','', ''''), '''') AS int) AS [KvK Played],
                TRY_CAST(NULLIF(REPLACE([Most KvK Kill], '','', ''''), '''') AS bigint) AS [Most KvK Kill],
                TRY_CAST(NULLIF(REPLACE([Most KvK Dead], '','', ''''), '''') AS bigint) AS [Most KvK Dead],
                TRY_CAST(NULLIF(REPLACE([Most KvK Heal], '','', ''''), '''') AS bigint) AS [Most KvK Heal],
                TRY_CAST(NULLIF(REPLACE([Acclaim], '','', ''''), '''') AS bigint) AS [Acclaim],
                TRY_CAST(NULLIF(REPLACE([Highest Acclaim], '','', ''''), '''') AS bigint) AS [Highest Acclaim],
                TRY_CAST(NULLIF(REPLACE([AOO Joined], '','', ''''), '''') AS bigint) AS [AOO Joined],
                TRY_CAST(NULLIF(REPLACE([AOO Won], '','', ''''), '''') AS int) AS [AOO Won],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Kill], '','', ''''), '''') AS bigint) AS [AOO Avg Kill],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Dead], '','', ''''), '''') AS bigint) AS [AOO Avg Dead],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Heal], '','', ''''), '''') AS bigint) AS [AOO Avg Heal],
                TRY_CAST(NULLIF(REPLACE([Credit], '','', ''''), '''') AS decimal(5,2)) AS [Credit],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [updated_on]), CHAR(13), N'' ''), CHAR(10), N'' ''), CHAR(9), N'' ''))), N''''), 200) AS [updated_on]
            FROM dbo.IMPORT_STAGING_CSV_RAW;

            ----------------------------------------------------------------
            -- Step 4: Allocate the next scan atomically while the transaction-
            -- owned database mutex and serializable key-range lock are held.
            ----------------------------------------------------------------
            SELECT @CurrentMaxScanOrder = ISNULL(MAX(scan_max.ScanOrder), 0)
            FROM
            (
                SELECT MAX(SCANORDER) AS ScanOrder
                FROM dbo.KingdomScanData4 WITH (UPDLOCK, HOLDLOCK)

                UNION ALL

                SELECT MAX(SCANORDER)
                FROM dbo.KingdomScanData5 WITH (UPDLOCK, HOLDLOCK)

                UNION ALL

                SELECT MAX(ScanOrder)
                FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
            ) AS scan_max;

            IF @CurrentMaxScanOrder = 2147483647
                THROW 51807, ''KingdomScanData4 SCANORDER exhausted the int range; allocation refused.'', 1;

            SET @NextScanOrder = @CurrentMaxScanOrder + 1;

            ----------------------------------------------------------------
            -- Step 5: Truncate canonical staging and insert mapped values
            -- OPTIMIZATION: Added AutarchTimes mapping
            ----------------------------------------------------------------
            TRUNCATE TABLE dbo.IMPORT_STAGING;

            INSERT INTO dbo.IMPORT_STAGING (
                [Name], [Governor ID], [Alliance], [Power],
                [Total Kill Points], [Dead Troops], [T1-Kills], [T2-Kills], [T3-Kills],
                [T4-Kills], [T5-Kills], [Kills (T4+)], [KILLS], [Rss Gathered],
                [Rss Assistance], [Alliance Helps], [ScanDate], [SCANORDER],
                [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power],
                [Updated_on],
                -- existing new fields
                [HealedTroops], [RangedPoints], [Civilization], [KvKPlayed],
                [MostKvKKill], [MostKvKDead], [MostKvKHeal],
                [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon],
                [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct],
                -- NEW FIELD
                [AutarchTimes]
            )
            SELECT
                RTRIM(ISNULL([Name], '''')) AS [Name],
                [Governor ID] AS [Governor ID],
                [Alliance],

                -- OPTIMIZATION: Simplified TRY_CAST (removed redundant CASE/CAST)
                TRY_CAST(REPLACE([Power], '','', '''') AS BIGINT) AS [Power],
                TRY_CAST(REPLACE([Total Kill Points], '','', '''') AS BIGINT) AS [Total Kill Points],
                TRY_CAST(REPLACE([Dead Troops], '','', '''') AS BIGINT) AS [Dead Troops],
                TRY_CAST(REPLACE([T1-Kills], '','', '''') AS BIGINT) AS [T1-Kills],
                TRY_CAST(REPLACE([T2-Kills], '','', '''') AS BIGINT) AS [T2-Kills],
                TRY_CAST(REPLACE([T3-Kills], '','', '''') AS BIGINT) AS [T3-Kills],
                TRY_CAST(REPLACE([T4-Kills], '','', '''') AS BIGINT) AS [T4-Kills],
                TRY_CAST(REPLACE([T5-Kills], '','', '''') AS BIGINT) AS [T5-Kills],

                -- derived fields - OPTIMIZATION: Use ISNULL to handle NULLs
                (ISNULL([T4-Kills], 0) + ISNULL([T5-Kills], 0)) AS [Kills (T4+)],
                (ISNULL([T1-Kills], 0) + ISNULL([T2-Kills], 0) + ISNULL([T3-Kills], 0) + ISNULL([T4-Kills], 0) + ISNULL([T5-Kills], 0)) AS [KILLS],

                TRY_CAST(REPLACE([Rss Gathered], '','', '''') AS BIGINT) AS [RssGathered],
                TRY_CAST(REPLACE([Rss Assistance], '','', '''') AS BIGINT) AS [RssAssistance],
                TRY_CAST(REPLACE([Alliance Helps], '','', '''') AS BIGINT) AS [AllianceHelps],

                -- convert updated_on string like ''19Jan26-15h57m'' into DATETIME
                TRY_CAST(
                    CONCAT(
                        ''20'', SUBSTRING([updated_on], 6, 2), ''-'',
                        CASE SUBSTRING([updated_on], 3, 3)
                            WHEN ''Jan'' THEN ''01''
                            WHEN ''Feb'' THEN ''02''
                            WHEN ''Mar'' THEN ''03''
                            WHEN ''Apr'' THEN ''04''
                            WHEN ''May'' THEN ''05''
                            WHEN ''Jun'' THEN ''06''
                            WHEN ''Jul'' THEN ''07''
                            WHEN ''Aug'' THEN ''08''
                            WHEN ''Sep'' THEN ''09''
                            WHEN ''Oct'' THEN ''10''
                            WHEN ''Nov'' THEN ''11''
                            WHEN ''Dec'' THEN ''12''
                        END, ''-'',
                        SUBSTRING([updated_on], 1, 2), '' '',
                        SUBSTRING([updated_on], 9, 2), '':'',
                        SUBSTRING([updated_on], 12, 2), '':00''
                    ) AS DATETIME
                ) AS ScanDate,

                @NextScanOrder AS SCANORDER,

                TRY_CAST(REPLACE([Troops Power], '','', '''') AS BIGINT) AS [TroopsPower],
                TRY_CAST([City Hall] AS INT) AS [CityHall],
                TRY_CAST(REPLACE([Tech Power], '','', '''') AS BIGINT) AS [TechPower],
                TRY_CAST(REPLACE([Building Power], '','', '''') AS BIGINT) AS [BuildingPower],
                TRY_CAST(REPLACE([Commander Power], '','', '''') AS BIGINT) AS [CommanderPower],

                [updated_on],

                -- existing new fields mapping
                TRY_CAST(REPLACE([Healed Troops], '','', '''') AS BIGINT) AS [HealedTroops],
                TRY_CAST(REPLACE([Ranged Points], '','', '''') AS BIGINT) AS [RangedPoints],
                [Civilization] AS [Civilization],
                TRY_CAST([KvK Played] AS INT) AS [KvKPlayed],
                TRY_CAST(REPLACE([Most KvK Kill], '','', '''') AS BIGINT) AS [MostKvKKill],
                TRY_CAST(REPLACE([Most KvK Dead], '','', '''') AS BIGINT) AS [MostKvKDead],
                TRY_CAST(REPLACE([Most KvK Heal], '','', '''') AS BIGINT) AS [MostKvKHeal],
                TRY_CAST(REPLACE([Acclaim], '','', '''') AS BIGINT) AS [Acclaim],
                TRY_CAST(REPLACE([Highest Acclaim], '','', '''') AS BIGINT) AS [HighestAcclaim],
                TRY_CAST(REPLACE([AOO Joined], '','', '''') AS BIGINT) AS [AOOJoined],
                TRY_CAST([AOO Won] AS INT) AS [AOOWon],
                TRY_CAST(REPLACE([AOO Avg Kill], '','', '''') AS BIGINT) AS [AOOAvgKill],
                TRY_CAST(REPLACE([AOO Avg Dead], '','', '''') AS BIGINT) AS [AOOAvgDead],
                TRY_CAST(REPLACE([AOO Avg Heal], '','', '''') AS BIGINT) AS [AOOAvgHeal],
                TRY_CAST(NULLIF(REPLACE(CONVERT(nvarchar(50), [Credit]), '','', ''''), '''') AS decimal(5,2)) AS [Conduct],

                -- NEW FIELD: Autarch Times
                TRY_CAST([Autarch Times] AS INT) AS [AutarchTimes]

            FROM dbo.IMPORT_STAGING_CSV;

            SET @InsertedRows = @@ROWCOUNT;

            IF @InsertedRows = 0
                THROW 51804, ''IMPORT_STAGING_PROC produced zero canonical staging rows.'', 1;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.IMPORT_STAGING
                GROUP BY SCANORDER, [Governor ID]
                HAVING COUNT_BIG(*) > 1
            )
                THROW 51805, ''IMPORT_STAGING_PROC rejected duplicate (SCANORDER, Governor ID) keys in canonical staging.'', 1;

            ----------------------------------------------------------------
            -- Step 6: Clean up known alliance typos
            -- OPTIMIZATION: Batched into single UPDATE for better performance
            ----------------------------------------------------------------
            UPDATE dbo.IMPORT_STAGING
            SET ALLIANCE = CASE
                WHEN ALLIANCE = ''[k98A]SparTanS$S'' THEN ''[k98A]SparTanS''
                WHEN ALLIANCE = ''[K98B]Trojan$S'' THEN ''[K98B]TrojanS''
                ELSE ALLIANCE
            END
            WHERE ALLIANCE IN (''[k98A]SparTanS$S'', ''[K98B]Trojan$S'');

            ----------------------------------------------------------------
            -- Step 7: Delta update from latest scan (preserve original behaviour)
            ----------------------------------------------------------------
            WITH LatestScan AS (
                SELECT GovernorID,
                       KillPoints, Deads, T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills,
                       [T4&T5_KILLS], [TOTAL_KILLS], RSS_Gathered, RSSAssistance, Helps
                FROM dbo.KingdomScanData4
                WHERE SCANORDER = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)
            )
            UPDATE I
            SET
                [Total Kill Points] = CASE WHEN I.[Total Kill Points] < K.KillPoints THEN K.KillPoints ELSE I.[Total Kill Points] END,
                [Dead Troops] = CASE WHEN I.[Dead Troops] < K.Deads THEN K.Deads ELSE I.[Dead Troops] END,
                [T1-Kills] = CASE WHEN I.[T1-Kills] < K.T1_Kills THEN K.T1_Kills ELSE I.[T1-Kills] END,
                [T2-Kills] = CASE WHEN I.[T2-Kills] < K.T2_Kills THEN K.T2_Kills ELSE I.[T2-Kills] END,
                [T3-Kills] = CASE WHEN I.[T3-Kills] < K.T3_Kills THEN K.T3_Kills ELSE I.[T3-Kills] END,
                [T4-Kills] = CASE WHEN I.[T4-Kills] < K.T4_Kills THEN K.T4_Kills ELSE I.[T4-Kills] END,
                [T5-Kills] = CASE WHEN I.[T5-Kills] < K.T5_Kills THEN K.T5_Kills ELSE I.[T5-Kills] END,
                [Kills (T4+)] = CASE WHEN I.[Kills (T4+)] < K.[T4&T5_KILLS] THEN K.[T4&T5_KILLS] ELSE I.[Kills (T4+)] END,
                [KILLS] = CASE WHEN I.[KILLS] < K.[TOTAL_KILLS] THEN K.[TOTAL_KILLS] ELSE I.[KILLS] END,
                [RSS Gathered] = CASE WHEN I.[RSS Gathered] < K.RSS_Gathered THEN K.RSS_Gathered ELSE I.[RSS Gathered] END,
                [RSS Assistance] = CASE WHEN I.[RSS Assistance] < K.RSSAssistance THEN K.RSSAssistance ELSE I.[RSS Assistance] END,
                [Alliance Helps] = CASE WHEN I.[Alliance Helps] < K.Helps THEN K.Helps ELSE I.[Alliance Helps] END
            FROM dbo.IMPORT_STAGING AS I
            INNER JOIN LatestScan AS K ON I.[Governor ID] = K.GovernorID;

            ----------------------------------------------------------------
            -- Step 8: Record the durable archive handoff. The filesystem move
            -- happens only after the owning database transaction commits.
            ----------------------------------------------------------------
            SELECT TOP 1 @LatestDate = ScanDate
            FROM dbo.IMPORT_STAGING
            WHERE ScanDate IS NOT NULL
            ORDER BY ScanDate DESC;

            IF @LatestDate IS NULL
                SET @LatestDate = GETDATE();

            INSERT dbo.KS4_ImportFileReceipt
            (
                FileDigest,
                SourcePath,
                ArchivePath,
                ScanOrder,
                ScanDate,
                [RowCount],
                DatabaseCommittedAtUtc,
                ArchiveStatus,
                ArchivedAtUtc,
                LastArchiveError
            )
            VALUES
            (
                @ImportFileDigest,
                @CsvPath,
                @ArchivePath,
                @NextScanOrder,
                @LatestDate,
                @InsertedRows,
                SYSUTCDATETIME(),
                N''pending'',
                NULL,
                NULL
            );

            UPDATE dbo.KS4_ImportFileClaim
            SET ClaimStatus = N''imported'',
                ImportCommittedAtUtc = SYSUTCDATETIME(),
                LastError = NULL
            WHERE CompletedFileName = @CompletedFileName
              AND FileDigest = @ImportFileDigest
              AND ClaimedPath = @CsvPath
              AND ArchivePath = @ArchivePath
              AND ClaimStatus = N''claimed'';

            IF @@ROWCOUNT <> 1
                THROW 51809, ''IMPORT_STAGING_PROC could not advance exactly one claim to imported.'', 1;

            ----------------------------------------------------------------
            -- Step 9: Output summary & cleanup
            ----------------------------------------------------------------
            PRINT ''--- IMPORT STAGING SUMMARY ---'';
            PRINT ''Rows Inserted: '' + CAST(@InsertedRows AS VARCHAR(20));
            PRINT ''ScanOrder Used: '' + CAST(@NextScanOrder AS VARCHAR(20));
            PRINT ''Archive Pending: '' + @ArchivePath;

            IF @StartedLocalTransaction = 1
            BEGIN
                COMMIT TRANSACTION;

                EXEC @ArchiveReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
                    @CompletedFileName = @CompletedFileName;

                IF @ArchiveReturnCode <> 0
                    THROW 51806, ''IMPORT_STAGING_PROC committed staging but the archive handoff did not complete.'', 1;

                PRINT ''File Archived To: '' + @ArchivePath;
            END
            ELSE
            BEGIN
                PRINT ''Archive handoff deferred until the caller commits the authoritative import transaction.'';
            END;

            RETURN 0; -- Success
    END TRY
    BEGIN CATCH
            DECLARE @ErrNumber INT = ERROR_NUMBER();
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @ErrLine INT = ERROR_LINE();
            DECLARE @ErrProc NVARCHAR(128) = ERROR_PROCEDURE();
            DECLARE @PersistedError NVARCHAR(2000) =
                LEFT(
                    CONCAT(
                        N''Error '',
                        ERROR_NUMBER(),
                        N'' in '',
                        COALESCE(ERROR_PROCEDURE(), N''Ad-hoc''),
                        N'' line '',
                        ERROR_LINE(),
                        N'': '',
                        COALESCE(ERROR_MESSAGE(), N''(no message)'')
                    ),
                    2000
                );

            SET @ImportError = @PersistedError;

            IF @StartedLocalTransaction = 1 AND XACT_STATE() <> 0
                ROLLBACK TRANSACTION;
            ELSE IF @EntryTranCount > 0 AND XACT_STATE() = 1
                ROLLBACK TRANSACTION IMPORT_STAGING_PROC_SAVEPOINT;

            -- A caller-owned transaction will be rolled back by UPDATE_ALL or
            -- UPDATE_ALL2. Return the exact error through @ImportError so that
            -- the owner persists it only after the outer rollback. A standalone
            -- IMPORT_STAGING_PROC call is already back in autocommit here.
            IF @EntryTranCount = 0
            BEGIN
                BEGIN TRY
                    UPDATE dbo.KS4_ImportFileClaim
                    SET LastError = @ImportError
                    WHERE CompletedFileName = @CompletedFileName
                      AND ClaimStatus = N''claimed'';
                END TRY
                BEGIN CATCH
                    -- Never replace the original import failure with a ledger
                    -- persistence error.
                END CATCH;
            END;

            -- OPTIMIZATION: Enhanced error reporting
            PRINT ''Error occurred in procedure: '' + ISNULL(@ErrProc, ''Ad-hoc'');
            PRINT ''Error line: '' + CAST(@ErrLine AS VARCHAR(10));
            PRINT ''Error number: '' + CAST(@ErrNumber AS VARCHAR(10));
            PRINT ''Error message: '' + COALESCE(@ErrMsg, N''(no message)'');

            RETURN 1; -- Failure
    END CATCH
END');
    IF EXISTS (SELECT 1 FROM @Modules WHERE
        HASHBYTES('SHA2_256',N'CREATE'+SUBSTRING(Body,6,DATALENGTH(Body)/2))<>AfterHash)
        THROW 51920, 'Migration body bytes differ from reviewed postimages.', 1;
    UPDATE @Modules SET ObjectID = OBJECT_ID(Name, N'P');
    IF EXISTS (
        SELECT 1 FROM @Modules AS expected
        LEFT JOIN sys.sql_modules AS actual ON actual.object_id=expected.ObjectID
        WHERE actual.object_id IS NULL OR actual.execute_as_principal_id IS NOT NULL
           OR actual.uses_ansi_nulls<>1 OR actual.uses_quoted_identifier<>1
           OR actual.definition IS NULL
           OR HASHBYTES('SHA2_256',actual.definition) NOT IN (expected.BeforeHash,expected.AfterHash)
           OR EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=expected.ObjectID)
    ) THROW 51920, 'Exact unsigned caller module preimages required.', 1;
    DECLARE @Name sysname, @Body nvarchar(max);
    DECLARE Modules CURSOR LOCAL FAST_FORWARD FOR
        SELECT expected.Name,expected.Body FROM @Modules AS expected
        JOIN sys.sql_modules AS actual ON actual.object_id=expected.ObjectID
        WHERE HASHBYTES('SHA2_256',actual.definition)=expected.BeforeHash
        ORDER BY expected.Name;
    OPEN Modules;
    FETCH NEXT FROM Modules INTO @Name,@Body;
    WHILE @@FETCH_STATUS=0
    BEGIN
        EXEC sys.sp_executesql @Body;
        FETCH NEXT FROM Modules INTO @Name,@Body;
    END;
    CLOSE Modules;
    DEALLOCATE Modules;
    IF EXISTS (
        SELECT 1 FROM @Modules AS expected
        LEFT JOIN sys.sql_modules AS actual ON actual.object_id=expected.ObjectID
        WHERE actual.object_id IS NULL OR OBJECT_ID(expected.Name,N'P')<>expected.ObjectID
           OR actual.execute_as_principal_id IS NOT NULL
           OR actual.uses_ansi_nulls<>1 OR actual.uses_quoted_identifier<>1
           OR actual.definition IS NULL
           OR HASHBYTES('SHA2_256',actual.definition)<>expected.AfterHash
           OR EXISTS (SELECT 1 FROM sys.crypt_properties WHERE major_id=expected.ObjectID)
    ) THROW 51920, 'Exact unsigned caller module postimages required.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
