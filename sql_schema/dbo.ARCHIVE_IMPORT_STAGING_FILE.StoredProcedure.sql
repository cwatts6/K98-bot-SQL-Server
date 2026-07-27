SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ARCHIVE_IMPORT_STAGING_FILE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[ARCHIVE_IMPORT_STAGING_FILE] AS'
END
ALTER PROCEDURE [dbo].[ARCHIVE_IMPORT_STAGING_FILE]
    @FileDigest [binary](32)
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ImportLockResult int;
    DECLARE @SourcePath nvarchar(4000);
    DECLARE @ArchivePath nvarchar(4000);
    DECLARE @ArchiveStatus nvarchar(20);
    DECLARE @SourceExists int;
    DECLARE @ArchiveExists int;
    DECLARE @CurrentFileDigest binary(32);
    DECLARE @MoveCommand nvarchar(4000);
    DECLARE @MoveExitCode int;

    IF @@TRANCOUNT <> 0
        THROW 51849, 'ARCHIVE_IMPORT_STAGING_FILE refuses caller-owned transactions; execute the public entry point with no active transaction.', 1;

    SET XACT_ABORT ON;

    IF @FileDigest IS NULL
        THROW 51840, 'ARCHIVE_IMPORT_STAGING_FILE requires a non-null file digest.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51841, 'ARCHIVE_IMPORT_STAGING_FILE could not acquire the KingdomScanData4 import mutex within 60000 ms.', 1;

        SELECT
            @SourcePath = SourcePath,
            @ArchivePath = ArchivePath,
            @ArchiveStatus = ArchiveStatus
        FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
        WHERE FileDigest = @FileDigest;

        IF @SourcePath IS NULL
            THROW 51842, 'ARCHIVE_IMPORT_STAGING_FILE did not find a committed receipt for the requested file digest.', 1;

        IF @SourcePath <> N'C:\discord_file_downloader\downloads\stats.csv'
           OR @ArchivePath NOT LIKE N'C:\discord_file_downloader\downloads\Import[_]Archive\Stats[_]%'
            THROW 51843, 'ARCHIVE_IMPORT_STAGING_FILE refused an unexpected source or archive path.', 1;

        IF CHARINDEX(N'"', @ArchivePath) > 0
           OR CHARINDEX(N'&', @ArchivePath) > 0
           OR CHARINDEX(N'|', @ArchivePath) > 0
           OR CHARINDEX(N'<', @ArchivePath) > 0
           OR CHARINDEX(N'>', @ArchivePath) > 0
           OR CHARINDEX(N'^', @ArchivePath) > 0
           OR CHARINDEX(N'%', @ArchivePath) > 0
           OR CHARINDEX(N'!', @ArchivePath) > 0
           OR CHARINDEX(NCHAR(10), @ArchivePath) > 0
           OR CHARINDEX(NCHAR(13), @ArchivePath) > 0
            THROW 51848, 'ARCHIVE_IMPORT_STAGING_FILE refused command-shell metacharacters in the archive path.', 1;

        IF @ArchiveStatus = N'archived'
        BEGIN
            COMMIT TRANSACTION;
            RETURN 0;
        END;

        EXEC master.dbo.xp_fileexist @SourcePath, @SourceExists OUTPUT;
        EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

        -- A previous attempt may have completed the filesystem move and then
        -- lost its database update. Reconcile that state idempotently.
        IF ISNULL(@SourceExists, 0) <> 1 AND ISNULL(@ArchiveExists, 0) = 1
        BEGIN
            SET @CurrentFileDigest = NULL;

            EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
                @ApprovedPath = @ArchivePath,
                @FileDigest = @CurrentFileDigest OUTPUT;

            IF @CurrentFileDigest IS NULL OR @CurrentFileDigest <> @FileDigest
                THROW 51850, 'ARCHIVE_IMPORT_STAGING_FILE refused to reconcile an archive destination whose digest differs from the committed receipt.', 1;

            UPDATE dbo.KS4_ImportFileReceipt
            SET ArchiveStatus = N'archived',
                ArchivedAtUtc = SYSUTCDATETIME(),
                LastArchiveError = NULL
            WHERE FileDigest = @FileDigest;

            COMMIT TRANSACTION;
            RETURN 0;
        END;

        IF ISNULL(@SourceExists, 0) <> 1
            THROW 51844, 'ARCHIVE_IMPORT_STAGING_FILE found neither the expected source file nor its archive destination.', 1;

        IF ISNULL(@ArchiveExists, 0) = 1
            THROW 51845, 'ARCHIVE_IMPORT_STAGING_FILE refused to overwrite an existing archive destination.', 1;

        EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
            @ApprovedPath = @SourcePath,
            @FileDigest = @CurrentFileDigest OUTPUT;

        IF @CurrentFileDigest IS NULL OR @CurrentFileDigest <> @FileDigest
            THROW 51846, 'ARCHIVE_IMPORT_STAGING_FILE refused to move a source file whose digest differs from the committed receipt.', 1;

        SET @MoveCommand =
            N'CMD /D /C MOVE "'
            + @SourcePath
            + N'" "'
            + @ArchivePath
            + N'"';

        EXEC @MoveExitCode = master.dbo.xp_cmdshell @MoveCommand, NO_OUTPUT;

        EXEC master.dbo.xp_fileexist @SourcePath, @SourceExists OUTPUT;
        EXEC master.dbo.xp_fileexist @ArchivePath, @ArchiveExists OUTPUT;

        IF ISNULL(@MoveExitCode, 1) <> 0
           OR ISNULL(@SourceExists, 0) = 1
           OR ISNULL(@ArchiveExists, 0) <> 1
            THROW 51847, 'ARCHIVE_IMPORT_STAGING_FILE could not verify a successful filesystem move.', 1;

        UPDATE dbo.KS4_ImportFileReceipt
        SET ArchiveStatus = N'archived',
            ArchivedAtUtc = SYSUTCDATETIME(),
            LastArchiveError = NULL
        WHERE FileDigest = @FileDigest;

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage nvarchar(2000) = ERROR_MESSAGE();

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        BEGIN TRY
            IF EXISTS
            (
                SELECT 1
                FROM dbo.KS4_ImportFileReceipt
                WHERE FileDigest = @FileDigest
            )
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
