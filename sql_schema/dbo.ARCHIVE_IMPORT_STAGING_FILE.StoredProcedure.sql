SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ARCHIVE_IMPORT_STAGING_FILE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[ARCHIVE_IMPORT_STAGING_FILE] AS' 
END
ALTER PROCEDURE [dbo].[ARCHIVE_IMPORT_STAGING_FILE]
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
        THROW 51849, 'ARCHIVE_IMPORT_STAGING_FILE refuses caller-owned transactions; execute the public entry point with no active transaction.', 1;

    SET XACT_ABORT ON;

    IF @CompletedFileName IS NULL
        THROW 51840, 'ARCHIVE_IMPORT_STAGING_FILE requires a completed filename.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51841, 'ARCHIVE_IMPORT_STAGING_FILE could not acquire the KingdomScanData4 import mutex within 60000 ms.', 1;

        SELECT
            @FileDigest = FileDigest,
            @SourcePath = ClaimedPath,
            @ArchivePath = ArchivePath,
            @ClaimStatus = ClaimStatus
        FROM dbo.KS4_ImportFileClaim WITH (UPDLOCK, HOLDLOCK)
        WHERE CompletedFileName = @CompletedFileName;

        IF @SourcePath IS NULL OR @FileDigest IS NULL
            THROW 51842, 'ARCHIVE_IMPORT_STAGING_FILE did not find a digest-bound claim for the requested filename.', 1;

        IF @SourcePath <>
                N'C:\discord_file_downloader\downloads\Import_Claimed\' + @CompletedFileName
           OR @ArchivePath <>
                N'C:\discord_file_downloader\downloads\Import_Archive\' + @CompletedFileName
            THROW 51843, 'ARCHIVE_IMPORT_STAGING_FILE refused claim-path definition drift.', 1;

        IF @ClaimStatus NOT IN
           (
               N'imported',
               N'archived',
               N'duplicate',
               N'duplicate_archived'
           )
            THROW 51851, 'ARCHIVE_IMPORT_STAGING_FILE refused a claim that is not committed or duplicate.', 1;

        SET @FinalStatus =
            CASE
                WHEN @ClaimStatus IN (N'duplicate', N'duplicate_archived')
                    THEN N'duplicate_archived'
                ELSE N'archived'
            END;

        IF @ClaimStatus IN (N'imported', N'archived')
           AND NOT EXISTS
           (
               SELECT 1
               FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
               WHERE FileDigest = @FileDigest
                 AND SourcePath = @SourcePath
                 AND ArchivePath = @ArchivePath
           )
            THROW 51852, 'ARCHIVE_IMPORT_STAGING_FILE did not find the matching committed receipt.', 1;

        IF @ClaimStatus IN (N'duplicate', N'duplicate_archived')
           AND NOT EXISTS
           (
               SELECT 1
               FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
               WHERE FileDigest = @FileDigest
           )
            THROW 51853, 'ARCHIVE_IMPORT_STAGING_FILE could not bind the duplicate claim to an existing receipt.', 1;

        EXEC master.dbo.xp_fileexist @SourcePath, @SourceExists OUTPUT;
        EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

        -- Reconcile a previous move that completed before its database status
        -- update. The destination digest is authoritative for reconciliation.
        IF ISNULL(@SourceExists, 0) <> 1 AND ISNULL(@ArchiveExists, 0) = 1
        BEGIN
            SET @CurrentFileDigest = NULL;

            EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
                @ApprovedPath = @ArchivePath,
                @FileDigest = @CurrentFileDigest OUTPUT;

            IF @CurrentFileDigest IS NULL OR @CurrentFileDigest <> @FileDigest
                THROW 51850, 'ARCHIVE_IMPORT_STAGING_FILE refused to reconcile an archive destination whose digest differs from the claim.', 1;

            UPDATE dbo.KS4_ImportFileClaim
            SET ClaimStatus = @FinalStatus,
                ArchivedAtUtc = COALESCE(ArchivedAtUtc, SYSUTCDATETIME()),
                LastError = NULL
            WHERE CompletedFileName = @CompletedFileName;

            IF @FinalStatus = N'archived'
            BEGIN
                UPDATE dbo.KS4_ImportFileReceipt
                SET ArchiveStatus = N'archived',
                    ArchivedAtUtc = COALESCE(ArchivedAtUtc, SYSUTCDATETIME()),
                    LastArchiveError = NULL
                WHERE FileDigest = @FileDigest;
            END;

            COMMIT TRANSACTION;
            RETURN 0;
        END;

        IF ISNULL(@SourceExists, 0) <> 1
            THROW 51844, 'ARCHIVE_IMPORT_STAGING_FILE found neither the claimed file nor its archive destination.', 1;

        IF ISNULL(@ArchiveExists, 0) = 1
            THROW 51845, 'ARCHIVE_IMPORT_STAGING_FILE refused to overwrite an existing archive destination.', 1;

        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath = @SourcePath,
            @FileDigest = @CurrentFileDigest OUTPUT;

        IF @CurrentFileDigest IS NULL OR @CurrentFileDigest <> @FileDigest
            THROW 51846, 'ARCHIVE_IMPORT_STAGING_FILE refused to move claimed bytes that differ from the durable digest.', 1;

        SET @MoveCommand =
            N'CMD /D /C MOVE "'
            + @SourcePath
            + N'" "'
            + @ArchivePath
            + N'"';

        EXEC @MoveExitCode = master.dbo.xp_cmdshell @MoveCommand, NO_OUTPUT;

        SET @SourceExists = 0;
        SET @ArchiveExists = 0;
        EXEC master.dbo.xp_fileexist @SourcePath, @SourceExists OUTPUT;
        EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

        IF ISNULL(@MoveExitCode, 1) <> 0
           OR ISNULL(@SourceExists, 0) = 1
           OR ISNULL(@ArchiveExists, 0) <> 1
            THROW 51847, 'ARCHIVE_IMPORT_STAGING_FILE could not verify a successful filesystem move.', 1;

        SET @CurrentFileDigest = NULL;

        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath = @ArchivePath,
            @FileDigest = @CurrentFileDigest OUTPUT;

        IF @CurrentFileDigest IS NULL OR @CurrentFileDigest <> @FileDigest
            THROW 51854, 'ARCHIVE_IMPORT_STAGING_FILE refused to advance after the archive destination rehash changed.', 1;

        UPDATE dbo.KS4_ImportFileClaim
        SET ClaimStatus = @FinalStatus,
            ArchivedAtUtc = SYSUTCDATETIME(),
            LastError = NULL
        WHERE CompletedFileName = @CompletedFileName;

        IF @FinalStatus = N'archived'
        BEGIN
            UPDATE dbo.KS4_ImportFileReceipt
            SET ArchiveStatus = N'archived',
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
              AND ClaimStatus NOT IN (N'archived', N'duplicate_archived');

            IF @FileDigest IS NOT NULL
            BEGIN
                UPDATE dbo.KS4_ImportFileReceipt
                SET LastArchiveError = @ErrorMessage
                WHERE FileDigest = @FileDigest
                  AND ArchiveStatus = N'pending';
            END;
        END TRY
        BEGIN CATCH
            -- Preserve the original archive failure.
        END CATCH;

        THROW;
    END CATCH;
END
