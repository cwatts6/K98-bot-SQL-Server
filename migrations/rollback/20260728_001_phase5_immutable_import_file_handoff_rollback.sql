/*
RollbackForMigrationId: 20260728_001_phase5_immutable_import_file_handoff
Purpose: Restore the exact Phase 4-era mutable-path routine definitions during the coordinated pre-restart rollback
Author: cwatts
CreatedUtc: 2026-07-28
TransactionMode: Required
DataChange: No
DataLossRisk: Archived claim evidence is retained when present
*/

/*
Rollback boundary:
    - Use only while every bot/import/scheduler/admin writer remains stopped.
    - Reconcile every imported or duplicate claim to its archive first.
    - Refuse ready, claimed, failed, claiming or otherwise in-flight identities.
    - Restore this contract before the Phase 4, Phase 3 and Phase 2 rollback
      sequence continues.
    - Start only the old bot revision, which writes the legacy stats.csv path.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
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
    THROW 52350, 'Phase 5.0 rollback could not acquire the KingdomScanData4 migration mutex.', 1;

DECLARE @ImportLockResult int;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
    @LockTimeout = 60000,
    @LockResult = @ImportLockResult OUTPUT;

IF @ImportLockResult < 0
    THROW 52351, 'Phase 5.0 rollback could not acquire the import-pipeline mutex.', 1;

IF OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NULL
   OR OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NULL
    THROW 52352, 'Phase 5.0 rollback requires the immutable claim contract.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim
    WHERE ClaimStatus NOT IN (N'archived', N'duplicate_archived')
)
    THROW 52353, 'Phase 5.0 rollback refused an unreconciled immutable-file claim.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileReceipt
    WHERE ArchiveStatus <> N'archived'
)
    THROW 52354, 'Phase 5.0 rollback refused an unreconciled import receipt.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
       NOT LIKE N'%Import_Ready%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'))
       NOT LIKE N'%detected claimed-file mutation across BULK INSERT%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       NOT LIKE N'%archive destination rehash changed%'
    THROW 52355, 'Phase 5.0 rollback refused unexpected current definition drift.', 1;

CREATE TABLE #Phase5RollbackDirectoryEntry
(
    Subdirectory nvarchar(512) NULL,
    Depth int NULL,
    IsFile bit NULL
);

INSERT #Phase5RollbackDirectoryEntry
EXEC master.dbo.xp_dirtree
    N'C:\discord_file_downloader\downloads\Import_Ready',
    1,
    1;

IF EXISTS (SELECT 1 FROM #Phase5RollbackDirectoryEntry WHERE IsFile = 1)
    THROW 52356, 'Phase 5.0 rollback refused files waiting in Import_Ready.', 1;

TRUNCATE TABLE #Phase5RollbackDirectoryEntry;

INSERT #Phase5RollbackDirectoryEntry
EXEC master.dbo.xp_dirtree
    N'C:\discord_file_downloader\downloads\Import_Claimed',
    1,
    1;

IF EXISTS (SELECT 1 FROM #Phase5RollbackDirectoryEntry WHERE IsFile = 1)
    THROW 52357, 'Phase 5.0 rollback refused files remaining in Import_Claimed.', 1;

-- Exact Phase 4-era definitions are appended below from merge commit 74bd8b1.

-- Rollback source: sql_schema/dbo.HASH_KS4_IMPORT_ARCHIVE_FILE.StoredProcedure.sql at 74bd8b1
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HASH_KS4_IMPORT_ARCHIVE_FILE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[HASH_KS4_IMPORT_ARCHIVE_FILE] AS'
END
GO
ALTER PROCEDURE [dbo].[HASH_KS4_IMPORT_ARCHIVE_FILE]
    @ApprovedPath [nvarchar](4000),
    @FileDigest [binary](32) OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ApprovedPath IS NULL
       OR
       (
           @ApprovedPath <> N'C:\discord_file_downloader\downloads\stats.csv'
           AND @ApprovedPath NOT LIKE N'C:\discord_file_downloader\downloads\Import[_]Archive\Stats[_]%'
       )
       OR CHARINDEX(N'''', @ApprovedPath) > 0
       OR CHARINDEX(N'"', @ApprovedPath) > 0
       OR CHARINDEX(NCHAR(10), @ApprovedPath) > 0
       OR CHARINDEX(NCHAR(13), @ApprovedPath) > 0
       OR CHARINDEX(N'&', @ApprovedPath) > 0
       OR CHARINDEX(N'|', @ApprovedPath) > 0
       OR CHARINDEX(N'<', @ApprovedPath) > 0
       OR CHARINDEX(N'>', @ApprovedPath) > 0
       OR CHARINDEX(N'^', @ApprovedPath) > 0
       OR CHARINDEX(N'%', @ApprovedPath) > 0
       OR CHARINDEX(N'!', @ApprovedPath) > 0
        THROW 51872, 'HASH_KS4_IMPORT_ARCHIVE_FILE refused an unexpected file path.', 1;

    DECLARE @HashCommand nvarchar(4000) =
        N'CMD /D /C certutil -hashfile "'
        + @ApprovedPath
        + N'" SHA256';
    DECLARE @HashExitCode int;
    DECLARE @HashHex varchar(64);
    DECLARE @HashOutput table
    (
        OutputLine nvarchar(255) NULL
    );

    SET @FileDigest = NULL;

    INSERT @HashOutput (OutputLine)
    EXEC @HashExitCode = master.dbo.xp_cmdshell @HashCommand;

    SELECT TOP (1)
        @HashHex =
            CONVERT(varchar(64), REPLACE(LTRIM(RTRIM(OutputLine)), N' ', N''))
    FROM @HashOutput
    WHERE LEN(REPLACE(LTRIM(RTRIM(OutputLine)), N' ', N'')) = 64
      AND REPLACE(LTRIM(RTRIM(OutputLine)), N' ', N'')
            NOT LIKE N'%[^0-9A-Fa-f]%';

    IF ISNULL(@HashExitCode, 1) = 0 AND @HashHex IS NOT NULL
        SET @FileDigest =
            TRY_CONVERT(binary(32), CONVERT(varchar(66), '0x' + @HashHex), 1);

    IF @FileDigest IS NULL
        THROW 51873, 'HASH_KS4_IMPORT_ARCHIVE_FILE could not calculate the approved file digest.', 1;
END
GO

-- Rollback source: sql_schema/dbo.ARCHIVE_IMPORT_STAGING_FILE.StoredProcedure.sql at 74bd8b1
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ARCHIVE_IMPORT_STAGING_FILE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[ARCHIVE_IMPORT_STAGING_FILE] AS'
END
GO
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
GO

-- Rollback source: sql_schema/dbo.IMPORT_STAGING_PROC_CORE.StoredProcedure.sql at 74bd8b1
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_PROC_CORE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IMPORT_STAGING_PROC_CORE] AS'
END
GO
ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC_CORE]
    @ImportFileDigest [binary](32) = NULL OUTPUT,
    @ArchivePath [nvarchar](4000) = NULL OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ----------------------------------------------------------------
    -- This procedure:
    -- 1) loads stats.csv into dbo.IMPORT_STAGING_CSV_RAW via BULK INSERT
    -- 2) converts raw text into typed dbo.IMPORT_STAGING_CSV
    -- 3) maps CSV columns into canonical dbo.IMPORT_STAGING
    -- 4) applies a few cleanup fixes, computes deltas against last scan,
    -- 5) archives the CSV file and returns summary info.
    --
    -- Assumptions:
    -- - dbo.IMPORT_STAGING_CSV physical column order and names match the CSV header.
    -- - SQL Server service account has read access to the CSV path.
    ----------------------------------------------------------------

    DECLARE @FileExists INT;
    DECLARE @NextScanOrder INT;
    DECLARE @CurrentMaxScanOrder INT;
    DECLARE @InsertedRows INT = 0;
    DECLARE @LatestDate DATETIME;
    DECLARE @FormattedDate VARCHAR(50);
    DECLARE @CsvPath NVARCHAR(4000) = N'C:\discord_file_downloader\downloads\stats.csv';
    DECLARE @EntryTranCount INT = @@TRANCOUNT;
    DECLARE @StartedLocalTransaction BIT = 0;
    DECLARE @ImportLockResult INT;
    DECLARE @ArchiveReturnCode INT;

    SET @ImportFileDigest = NULL;
    SET @ArchivePath = NULL;

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
                THROW 51800, 'IMPORT_STAGING_PROC could not acquire the KingdomScanData4 import mutex within 60000 ms; no import work was performed.', 1;

            -- File presence is checked only after the database mutex is held so
            -- concurrent callers cannot race the shared staging file.
            EXEC master.dbo.xp_fileexist @CsvPath, @FileExists OUTPUT;

            IF @FileExists <> 1
                THROW 51801, 'IMPORT_STAGING_PROC did not find the shared stats.csv after acquiring the import mutex; import was skipped.', 1;

            SELECT @ImportFileDigest = HASHBYTES('SHA2_256', BulkColumn)
            FROM OPENROWSET(
                BULK 'C:\discord_file_downloader\downloads\stats.csv',
                SINGLE_BLOB
            ) AS source_file;

            IF @ImportFileDigest IS NULL
                THROW 51802, 'IMPORT_STAGING_PROC could not calculate the shared stats.csv SHA-256 digest.', 1;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
                WHERE FileDigest = @ImportFileDigest
            )
            BEGIN
                DECLARE @DuplicateFileMessage nvarchar(2048) =
                    CONCAT(
                        N'IMPORT_STAGING_PROC refused a file that already has a committed receipt. ',
                        N'Retry the archive handoff for digest 0x',
                        CONVERT(varchar(64), @ImportFileDigest, 2),
                        N' instead of allocating another scan.'
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
            DECLARE @bulksql NVARCHAR(MAX) = N'
                BULK INSERT dbo.IMPORT_STAGING_CSV_RAW
                FROM ''' + REPLACE(@CsvPath, '''', '''''') + N'''
                WITH (
                    FORMAT = ''CSV'',
                    FIRSTROW = 2,
                    FIELDTERMINATOR = '','',
                    FIELDQUOTE = ''"'',
                    ROWTERMINATOR = ''0x0a'',
                    CODEPAGE = ''65001'',
                    TABLOCK
                );';

            EXEC sp_executesql @bulksql;

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
                TRY_CAST(NULLIF(REPLACE([Governor ID], ',', ''), '') AS bigint) AS [Governor ID],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Name]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 200) AS [Name],
                TRY_CAST(NULLIF(REPLACE([Power], ',', ''), '') AS bigint) AS [Power],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Alliance]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 100) AS [Alliance],
                TRY_CAST(NULLIF(REPLACE([T1-Kills], ',', ''), '') AS bigint) AS [T1-Kills],
                TRY_CAST(NULLIF(REPLACE([T2-Kills], ',', ''), '') AS bigint) AS [T2-Kills],
                TRY_CAST(NULLIF(REPLACE([T3-Kills], ',', ''), '') AS bigint) AS [T3-Kills],
                TRY_CAST(NULLIF(REPLACE([T4-Kills], ',', ''), '') AS bigint) AS [T4-Kills],
                TRY_CAST(NULLIF(REPLACE([T5-Kills], ',', ''), '') AS bigint) AS [T5-Kills],
                TRY_CAST(NULLIF(REPLACE([Total Kill Points], ',', ''), '') AS bigint) AS [Total Kill Points],
                TRY_CAST(NULLIF(REPLACE([Dead Troops], ',', ''), '') AS bigint) AS [Dead Troops],
                TRY_CAST(NULLIF(REPLACE([Healed Troops], ',', ''), '') AS bigint) AS [Healed Troops],
                TRY_CAST(NULLIF(REPLACE([Rss Assistance], ',', ''), '') AS bigint) AS [Rss Assistance],
                TRY_CAST(NULLIF(REPLACE([Alliance Helps], ',', ''), '') AS bigint) AS [Alliance Helps],
                TRY_CAST(NULLIF(REPLACE([Rss Gathered], ',', ''), '') AS bigint) AS [Rss Gathered],
                TRY_CAST(NULLIF(REPLACE([City Hall], ',', ''), '') AS int) AS [City Hall],
                TRY_CAST(NULLIF(REPLACE([Troops Power], ',', ''), '') AS bigint) AS [Troops Power],
                TRY_CAST(NULLIF(REPLACE([Tech Power], ',', ''), '') AS bigint) AS [Tech Power],
                TRY_CAST(NULLIF(REPLACE([Building Power], ',', ''), '') AS bigint) AS [Building Power],
                TRY_CAST(NULLIF(REPLACE([Commander Power], ',', ''), '') AS bigint) AS [Commander Power],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [Civilization]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 100) AS [Civilization],
                TRY_CAST(NULLIF(REPLACE([Autarch Times], ',', ''), '') AS int) AS [Autarch Times],
                TRY_CAST(NULLIF(REPLACE([Ranged Points], ',', ''), '') AS bigint) AS [Ranged Points],
                TRY_CAST(NULLIF(REPLACE([KvK Played], ',', ''), '') AS int) AS [KvK Played],
                TRY_CAST(NULLIF(REPLACE([Most KvK Kill], ',', ''), '') AS bigint) AS [Most KvK Kill],
                TRY_CAST(NULLIF(REPLACE([Most KvK Dead], ',', ''), '') AS bigint) AS [Most KvK Dead],
                TRY_CAST(NULLIF(REPLACE([Most KvK Heal], ',', ''), '') AS bigint) AS [Most KvK Heal],
                TRY_CAST(NULLIF(REPLACE([Acclaim], ',', ''), '') AS bigint) AS [Acclaim],
                TRY_CAST(NULLIF(REPLACE([Highest Acclaim], ',', ''), '') AS bigint) AS [Highest Acclaim],
                TRY_CAST(NULLIF(REPLACE([AOO Joined], ',', ''), '') AS bigint) AS [AOO Joined],
                TRY_CAST(NULLIF(REPLACE([AOO Won], ',', ''), '') AS int) AS [AOO Won],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Kill], ',', ''), '') AS bigint) AS [AOO Avg Kill],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Dead], ',', ''), '') AS bigint) AS [AOO Avg Dead],
                TRY_CAST(NULLIF(REPLACE([AOO Avg Heal], ',', ''), '') AS bigint) AS [AOO Avg Heal],
                TRY_CAST(NULLIF(REPLACE([Credit], ',', ''), '') AS decimal(5,2)) AS [Credit],
                LEFT(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), [updated_on]), CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '))), N''), 200) AS [updated_on]
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
                THROW 51807, 'KingdomScanData4 SCANORDER exhausted the int range; allocation refused.', 1;

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
                RTRIM(ISNULL([Name], '')) AS [Name],
                [Governor ID] AS [Governor ID],
                [Alliance],

                -- OPTIMIZATION: Simplified TRY_CAST (removed redundant CASE/CAST)
                TRY_CAST(REPLACE([Power], ',', '') AS BIGINT) AS [Power],
                TRY_CAST(REPLACE([Total Kill Points], ',', '') AS BIGINT) AS [Total Kill Points],
                TRY_CAST(REPLACE([Dead Troops], ',', '') AS BIGINT) AS [Dead Troops],
                TRY_CAST(REPLACE([T1-Kills], ',', '') AS BIGINT) AS [T1-Kills],
                TRY_CAST(REPLACE([T2-Kills], ',', '') AS BIGINT) AS [T2-Kills],
                TRY_CAST(REPLACE([T3-Kills], ',', '') AS BIGINT) AS [T3-Kills],
                TRY_CAST(REPLACE([T4-Kills], ',', '') AS BIGINT) AS [T4-Kills],
                TRY_CAST(REPLACE([T5-Kills], ',', '') AS BIGINT) AS [T5-Kills],

                -- derived fields - OPTIMIZATION: Use ISNULL to handle NULLs
                (ISNULL([T4-Kills], 0) + ISNULL([T5-Kills], 0)) AS [Kills (T4+)],
                (ISNULL([T1-Kills], 0) + ISNULL([T2-Kills], 0) + ISNULL([T3-Kills], 0) + ISNULL([T4-Kills], 0) + ISNULL([T5-Kills], 0)) AS [KILLS],

                TRY_CAST(REPLACE([Rss Gathered], ',', '') AS BIGINT) AS [RssGathered],
                TRY_CAST(REPLACE([Rss Assistance], ',', '') AS BIGINT) AS [RssAssistance],
                TRY_CAST(REPLACE([Alliance Helps], ',', '') AS BIGINT) AS [AllianceHelps],

                -- convert updated_on string like '19Jan26-15h57m' into DATETIME
                TRY_CAST(
                    CONCAT(
                        '20', SUBSTRING([updated_on], 6, 2), '-',
                        CASE SUBSTRING([updated_on], 3, 3)
                            WHEN 'Jan' THEN '01'
                            WHEN 'Feb' THEN '02'
                            WHEN 'Mar' THEN '03'
                            WHEN 'Apr' THEN '04'
                            WHEN 'May' THEN '05'
                            WHEN 'Jun' THEN '06'
                            WHEN 'Jul' THEN '07'
                            WHEN 'Aug' THEN '08'
                            WHEN 'Sep' THEN '09'
                            WHEN 'Oct' THEN '10'
                            WHEN 'Nov' THEN '11'
                            WHEN 'Dec' THEN '12'
                        END, '-',
                        SUBSTRING([updated_on], 1, 2), ' ',
                        SUBSTRING([updated_on], 9, 2), ':',
                        SUBSTRING([updated_on], 12, 2), ':00'
                    ) AS DATETIME
                ) AS ScanDate,

                @NextScanOrder AS SCANORDER,

                TRY_CAST(REPLACE([Troops Power], ',', '') AS BIGINT) AS [TroopsPower],
                TRY_CAST([City Hall] AS INT) AS [CityHall],
                TRY_CAST(REPLACE([Tech Power], ',', '') AS BIGINT) AS [TechPower],
                TRY_CAST(REPLACE([Building Power], ',', '') AS BIGINT) AS [BuildingPower],
                TRY_CAST(REPLACE([Commander Power], ',', '') AS BIGINT) AS [CommanderPower],

                [updated_on],

                -- existing new fields mapping
                TRY_CAST(REPLACE([Healed Troops], ',', '') AS BIGINT) AS [HealedTroops],
                TRY_CAST(REPLACE([Ranged Points], ',', '') AS BIGINT) AS [RangedPoints],
                [Civilization] AS [Civilization],
                TRY_CAST([KvK Played] AS INT) AS [KvKPlayed],
                TRY_CAST(REPLACE([Most KvK Kill], ',', '') AS BIGINT) AS [MostKvKKill],
                TRY_CAST(REPLACE([Most KvK Dead], ',', '') AS BIGINT) AS [MostKvKDead],
                TRY_CAST(REPLACE([Most KvK Heal], ',', '') AS BIGINT) AS [MostKvKHeal],
                TRY_CAST(REPLACE([Acclaim], ',', '') AS BIGINT) AS [Acclaim],
                TRY_CAST(REPLACE([Highest Acclaim], ',', '') AS BIGINT) AS [HighestAcclaim],
                TRY_CAST(REPLACE([AOO Joined], ',', '') AS BIGINT) AS [AOOJoined],
                TRY_CAST([AOO Won] AS INT) AS [AOOWon],
                TRY_CAST(REPLACE([AOO Avg Kill], ',', '') AS BIGINT) AS [AOOAvgKill],
                TRY_CAST(REPLACE([AOO Avg Dead], ',', '') AS BIGINT) AS [AOOAvgDead],
                TRY_CAST(REPLACE([AOO Avg Heal], ',', '') AS BIGINT) AS [AOOAvgHeal],
                TRY_CAST(NULLIF(REPLACE(CONVERT(nvarchar(50), [Credit]), ',', ''), '') AS decimal(5,2)) AS [Conduct],

                -- NEW FIELD: Autarch Times
                TRY_CAST([Autarch Times] AS INT) AS [AutarchTimes]

            FROM dbo.IMPORT_STAGING_CSV;

            SET @InsertedRows = @@ROWCOUNT;

            IF @InsertedRows = 0
                THROW 51804, 'IMPORT_STAGING_PROC produced zero canonical staging rows.', 1;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.IMPORT_STAGING
                GROUP BY SCANORDER, [Governor ID]
                HAVING COUNT_BIG(*) > 1
            )
                THROW 51805, 'IMPORT_STAGING_PROC rejected duplicate (SCANORDER, Governor ID) keys in canonical staging.', 1;

            ----------------------------------------------------------------
            -- Step 6: Clean up known alliance typos
            -- OPTIMIZATION: Batched into single UPDATE for better performance
            ----------------------------------------------------------------
            UPDATE dbo.IMPORT_STAGING
            SET ALLIANCE = CASE
                WHEN ALLIANCE = '[k98A]SparTanS$S' THEN '[k98A]SparTanS'
                WHEN ALLIANCE = '[K98B]Trojan$S' THEN '[K98B]TrojanS'
                ELSE ALLIANCE
            END
            WHERE ALLIANCE IN ('[k98A]SparTanS$S', '[K98B]Trojan$S');

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

            SET @FormattedDate = FORMAT(@LatestDate, 'yyyyMMdd_HHmm');
            SET @ArchivePath =
                N'C:\discord_file_downloader\downloads\Import_Archive\Stats_'
                + @FormattedDate
                + N'_S'
                + CONVERT(nvarchar(20), @NextScanOrder)
                + N'.csv';

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
                N'pending',
                NULL,
                NULL
            );

            ----------------------------------------------------------------
            -- Step 9: Output summary & cleanup
            ----------------------------------------------------------------
            PRINT '--- IMPORT STAGING SUMMARY ---';
            PRINT 'Rows Inserted: ' + CAST(@InsertedRows AS VARCHAR(20));
            PRINT 'ScanOrder Used: ' + CAST(@NextScanOrder AS VARCHAR(20));
            PRINT 'Archive Pending: ' + @ArchivePath;

            IF @StartedLocalTransaction = 1
            BEGIN
                COMMIT TRANSACTION;

                EXEC @ArchiveReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
                    @FileDigest = @ImportFileDigest;

                IF @ArchiveReturnCode <> 0
                    THROW 51806, 'IMPORT_STAGING_PROC committed staging but the archive handoff did not complete.', 1;

                PRINT 'File Archived To: ' + @ArchivePath;
            END
            ELSE
            BEGIN
                PRINT 'Archive handoff deferred until the caller commits the authoritative import transaction.';
            END;

            RETURN 0; -- Success
    END TRY
    BEGIN CATCH
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @ErrLine INT = ERROR_LINE();
            DECLARE @ErrProc NVARCHAR(128) = ERROR_PROCEDURE();

            IF @StartedLocalTransaction = 1 AND XACT_STATE() <> 0
                ROLLBACK TRANSACTION;
            ELSE IF @EntryTranCount > 0 AND XACT_STATE() = 1
                ROLLBACK TRANSACTION IMPORT_STAGING_PROC_SAVEPOINT;

            -- OPTIMIZATION: Enhanced error reporting
            PRINT 'Error occurred in procedure: ' + ISNULL(@ErrProc, 'Ad-hoc');
            PRINT 'Error line: ' + CAST(@ErrLine AS VARCHAR(10));
            PRINT 'Error message: ' + COALESCE(@ErrMsg, N'(no message)');

            RETURN 1; -- Failure
    END CATCH
END
GO

-- Rollback source: sql_schema/dbo.IMPORT_STAGING_PROC.StoredProcedure.sql at 74bd8b1
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IMPORT_STAGING_PROC] AS'
END
GO
ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC]
    @ImportFileDigest [binary](32) = NULL OUTPUT,
    @ArchivePath [nvarchar](4000) = NULL OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF @@TRANCOUNT <> 0
        THROW 51807, 'IMPORT_STAGING_PROC refuses caller-owned transactions; execute the public entry point with no active transaction.', 1;

    SET XACT_ABORT ON;

    DECLARE @ReturnCode int;

    EXEC @ReturnCode = dbo.IMPORT_STAGING_PROC_CORE
        @ImportFileDigest = @ImportFileDigest OUTPUT,
        @ArchivePath = @ArchivePath OUTPUT;

    RETURN @ReturnCode;
END
GO

-- Rollback source: sql_schema/dbo.UPDATE_ALL.StoredProcedure.sql at 74bd8b1
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL] AS' 
END
GO
ALTER PROCEDURE [dbo].[UPDATE_ALL]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    -- Phase 2 adds filtered uniqueness indexes to the canonical scan tables.
    -- SQL Server requires ANSI_WARNINGS ON for every write touching them.
    SET ANSI_WARNINGS ON;

    IF @@TRANCOUNT <> 0
        THROW 51828, 'UPDATE_ALL refuses caller-owned transactions; execute the public entry point with no active transaction.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ImportLockResult INT;
        DECLARE @ImportReturnCode INT;
        DECLARE @AllocatedScanOrder INT;
        DECLARE @StagedRows INT;
        DECLARE @RowsKS5 INT;
        DECLARE @RowsKS4 INT;
        DECLARE @ImportFileDigest BINARY(32);
        DECLARE @ImportArchivePath NVARCHAR(4000);
        DECLARE @ArchiveReturnCode INT;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51820, 'UPDATE_ALL could not acquire the KingdomScanData4 import mutex within 60000 ms; import was not started.', 1;

		DECLARE @actual_param1 FLOAT = ISNULL(@param1, (SELECT TOP 1 KINGDOM_RANK FROM KS));
		DECLARE @actual_param2 NVARCHAR(100) = ISNULL(@param2, (SELECT TOP 1 KINGDOM_SEED FROM KS));
		DECLARE @StartTime DATETIME = GETDATE();

		

        DECLARE 
            @MATHCHMAKING_SCAN INT = 148,
            @MAXSCAN INT = (SELECT MAX(SCANORDER) FROM KingdomScanData4),
            @PRE_PASS_4_SCAN INT = 156,
            @KVK_END_SCAN INT = 171,
            @PASS4END INT = 161,
            @PASS6END INT = 167,
            @PASS7END INT = 170,
            @LASTKVKEND INT = 146,
            @CURRENTKVK3 INT = 11;
            --@KINGDOMRANK FLOAT = 1099,
            --@KINGDOMSEED NVARCHAR(20) = 'C Seed';
       

        -- Step 1: Refresh latest data
        EXEC UPDATE_RALLY_DATA;
        EXEC @ImportReturnCode = dbo.IMPORT_STAGING_PROC_CORE
            @ImportFileDigest = @ImportFileDigest OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT;

        IF @ImportReturnCode <> 0
            THROW 51821, 'UPDATE_ALL stopped because IMPORT_STAGING_PROC failed.', 1;

        SELECT
            @AllocatedScanOrder = MIN(SCANORDER),
            @StagedRows = COUNT(*)
        FROM dbo.IMPORT_STAGING;

        IF @AllocatedScanOrder IS NULL
           OR @AllocatedScanOrder <> (SELECT MAX(SCANORDER) FROM dbo.IMPORT_STAGING)
           OR @StagedRows <> (SELECT COUNT(DISTINCT [Governor ID]) FROM dbo.IMPORT_STAGING)
            THROW 51822, 'UPDATE_ALL rejected empty, mixed-scan, or duplicate-governor canonical staging.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @AllocatedScanOrder
        )
            THROW 51823, 'UPDATE_ALL refused to reuse an existing KingdomScanData5 SCANORDER.', 1;

        -- Step 2: Insert into KingdomScanData5
        INSERT INTO KingdomScanData5 (PowerRank, GovernorName, GovernorID, Alliance, Power, KillPoints, Deads,
                                      T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS,
                                      Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER, [Troops Power], 
                                      [City Hall], [Tech Power], [Building Power], [Commander Power])
        SELECT ROW_NUMBER() OVER (ORDER BY [Power] DESC),
               RTRIM([Name]), [Governor ID], [Alliance], [Power], [Total Kill Points], [Dead Troops],
               [T1-Kills], [T2-Kills], [T3-Kills], [T4-Kills], [T5-Kills], [Kills (T4+)], [KILLS],
               [RSS Gathered], [RSS Assistance], [Alliance Helps], [ScanDate], [SCANORDER],
               [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
        FROM IMPORT_STAGING;

        SET @RowsKS5 = @@ROWCOUNT;

        IF @RowsKS5 <> @StagedRows
           OR EXISTS
              (
                  SELECT 1
                  FROM dbo.KingdomScanData5
                  WHERE SCANORDER = @AllocatedScanOrder
                  GROUP BY SCANORDER, GovernorID
                  HAVING COUNT_BIG(*) > 1
              )
            THROW 51824, 'UPDATE_ALL KingdomScanData5 row-count or duplicate-key validation failed.', 1;

     
		-- Step 3: Copy to KingdomScanData4 only if SCANORDER is greater
		IF (
			SELECT MAX(SCANORDER) FROM KingdomScanData5
		) > (
			SELECT ISNULL(MAX(SCANORDER), 0) FROM KingdomScanData4
		)
		BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.KingdomScanData4
                WHERE SCANORDER = @AllocatedScanOrder
            )
                THROW 51825, 'UPDATE_ALL refused to reuse an existing KingdomScanData4 SCANORDER.', 1;

			INSERT INTO KingdomScanData4
			SELECT *
			FROM KingdomScanData5 
			WHERE SCANORDER = @AllocatedScanOrder;

            SET @RowsKS4 = @@ROWCOUNT;

            IF @RowsKS4 <> @RowsKS5
               OR EXISTS
                  (
                      SELECT 1
                      FROM dbo.KingdomScanData4
                      WHERE SCANORDER = @AllocatedScanOrder
                      GROUP BY SCANORDER, GovernorID
                      HAVING COUNT_BIG(*) > 1
                  )
                THROW 51826, 'UPDATE_ALL KingdomScanData4 row-count or duplicate-key validation failed.', 1;
		END

		

        -- Step 4: Truncate staging
        TRUNCATE TABLE IMPORT_STAGING;

		-- Step 4a: Creat Target Table--
		EXEC dbo.TARGETS;
		--EXEC dbo.TARGETS @InputScanOrder = @MATHCHMAKING_SCAN;

        -- Step 5: Create delta tables
        EXEC CREATE_DELTA_TABLES;

		-- Drop final staging table if it exists
		TRUNCATE TABLE STAGING_STATS;

		-----------------------------------------------
-- 1. Consolidated Deads Delta
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN DeadsDelta ELSE 0 END) AS DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @LASTKVKEND AND DeltaOrder <= @PRE_PASS_4_SCAN THEN DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN DeadsDelta ELSE 0 END) AS P4DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS4END AND DeltaOrder <= @PASS6END THEN DeadsDelta ELSE 0 END) AS P6DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS6END AND DeltaOrder <= @PASS7END THEN DeadsDelta ELSE 0 END) AS P7DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS7END AND DeltaOrder <= @KVK_END_SCAN THEN DeadsDelta ELSE 0 END) AS P8DeadsDelta
INTO #Deads
FROM ROK_TRACKER.dbo.DeadsDelta
WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 2. Consolidated Kills Delta (T4&T5)
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
    SUM(CASE WHEN DeltaOrder > @LASTKVKEND AND DeltaOrder <= @PRE_PASS_4_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
    SUM(CASE WHEN DeltaOrder > @PASS4END AND DeltaOrder <= @PASS6END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
    SUM(CASE WHEN DeltaOrder > @PASS6END AND DeltaOrder <= @PASS7END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
    SUM(CASE WHEN DeltaOrder > @PASS7END AND DeltaOrder <= @KVK_END_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
INTO #Kills
FROM ROK_TRACKER.dbo.T4T5KillDelta
WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 3. Consolidated T4/T5 Kills
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(COALESCE(T4KILLSDelta, 0)) AS T4KillsDelta
INTO #KillsT4
FROM ROK_TRACKER.dbo.T4KillDelta
WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(T5KILLSDelta, 0)) AS T5KillsDelta
INTO #KillsT5
FROM ROK_TRACKER.dbo.T5KillDelta
WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 4. Other Delta Metrics (RSS, Helps, Power)
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(COALESCE(HelpsDelta, 0)) AS HelpsDelta
INTO #Helps
FROM ROK_TRACKER.dbo.HelpsDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(RSSASSISTDelta, 0)) AS RSSAssistDelta
INTO #RSSAssist
FROM ROK_TRACKER.dbo.RSSASSISTDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(RSSGatheredDelta, 0)) AS RSSGatheredDelta
INTO #RSSGathered
FROM ROK_TRACKER.dbo.RSSGatheredDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(Power_Delta, 0)) AS PowerDelta
INTO #Power
FROM ROK_TRACKER.dbo.PowerDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 5. Latest Snapshot of Governors
-----------------------------------------------
SELECT 
    GovernorID,
    GovernorName,
    PowerRank,
    [Power]
INTO #Snapshot
FROM KingdomScanData4
WHERE SCANORDER = @MATHCHMAKING_SCAN;

-----------------------------------------------
-- 6. Final Join to Staging Table
-----------------------------------------------
INSERT INTO STAGING_STATS
(
    GovernorID,
    PowerRank,
    [Power],
    Power_Delta,
    GovernorName,
    T4KillsDelta,
    T5KillsDelta,
    [T4&T5_KILLSDelta],
    KILLS_OUTSIDE_KVK,
    [P4T4&T5_KILLSDelta],
    [P6T4&T5_KillsDelta],
    [P7T4&T5_KillsDelta],
    [P8T4&T5_KillsDelta],
    DeadsDelta,
    DEADS_OUTSIDE_KVK,
    P4DeadsDelta,
    P6DeadsDelta,
    P7DeadsDelta,
    P8DeadsDelta,
    HelpsDelta,
    RSSASSISTDelta,
    RSSGatheredDelta
)
SELECT 
    s.GovernorID,
    s.PowerRank,
    s.[Power],
    p.PowerDelta,
    s.GovernorName,
    kt4.T4KillsDelta,
    kt5.T5KillsDelta,
    k.T4T5KillsDelta AS [T4&T5_KILLSDelta],
    k.KillsOutsideKVK AS [KILLS_OUTSIDE_KVK],
    k.P4Kills AS [P4T4&T5_KILLSDelta],
	k.P6Kills AS [P6T4&T5_KillsDelta],
	k.P7Kills AS [P7T4&T5_KillsDelta], 
	k.P8Kills AS [P8T4&T5_KillsDelta],
    d.DeadsDelta,
    d.DeadsDeltaOutKVK AS [DEADS_OUTSIDE_KVK],
    d.P4DeadsDelta,
	d.P6DeadsDelta,
	d.P7DeadsDelta,
	d.P8DeadsDelta,
    h.HelpsDelta,
    ra.RSSAssistDelta,
    rg.RSSGatheredDelta
FROM #Snapshot s
LEFT JOIN #Power p ON p.GovernorID = s.GovernorID
LEFT JOIN #KillsT4 kt4 ON kt4.GovernorID = s.GovernorID
LEFT JOIN #KillsT5 kt5 ON kt5.GovernorID = s.GovernorID
LEFT JOIN #Kills k ON k.GovernorID = s.GovernorID
LEFT JOIN #Deads d ON d.GovernorID = s.GovernorID
LEFT JOIN #Helps h ON h.GovernorID = s.GovernorID
LEFT JOIN #RSSAssist ra ON ra.GovernorID = s.GovernorID
LEFT JOIN #RSSGathered rg ON rg.GovernorID = s.GovernorID
WHERE s.GovernorID IS NOT NULL
ORDER BY s.PowerRank;

-----------------------------------------------
-- 7. Cleanup
-----------------------------------------------
DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot;

SELECT  S1.[GovernorID],
		CASE WHEN z.GovernorID = s1.GovernorID
		THEN ROUND ((S1.[T4&T5_KILLSDelta]*3 + (S1.[DeadsDelta] * 0.1) *8) ,0)
		ELSE ROUND ((S1.[T4&T5_KILLSDelta]*3 + S1.[DeadsDelta] *8) ,0)
		END AS [DKP_Score]
		INTO #DKP
		FROM [ROK_TRACKER].[dbo].[STAGING_STATS] AS S1
	 LEFT JOIN ZEROED AS Z ON z.GovernorID=S1.GovernorID AND ScanOrder = @MATHCHMAKING_SCAN 

SELECT GovernorID, MAX(T4_Deads) as [T4 Deads], MAX (T5_Deads) AS [T5 Deads], MAX(KVK_START_SCANORDER) AS SCANORDER 
INTO #HD1
FROM HoH_Deads 
GROUP BY GovernorID

  DROP TABLE EXCEL_FOR_CURRENT_KVK

SELECT	TOP (5000)
		S.[PowerRank] AS [Rank],
		ROW_NUMBER() OVER (ORDER BY D.[DKP_Score] DESC) AS [KVK_RANK]
		,S.[GovernorID] AS Gov_ID
		,S.[GovernorName] AS [Governor_Name]
		,S.[Power] AS [Starting Power]
		,S.Power_Delta
		,s.T4KillsDelta AS [T4_KILLS]
		,s.T5KillsDelta AS [T5_KILLS]
		,S.[T4&T5_KILLSDelta] AS [T4&T5_Kills]
		,S.KILLS_OUTSIDE_KVK
		,t.[Kill Target] AS [Kill Target]
		,CASE WHEN t.[Kill Target]  = 0
				THEN 0
				ELSE ROUND(s.[T4&T5_KILLSDelta]/t.[Kill Target]  * 100, 2) 
				END AS [% of Kill target]
		,s.[DeadsDelta] AS Deads
		,s.DEADS_OUTSIDE_KVK
		,COALESCE(HD.[T4 Deads],0) AS T4_Deads
		,COALESCE(HD.[T5 Deads],0) AS T5_Deads
		,t.[Dead Target] AS [Dead Target]
		
		,CASE WHEN t.[Dead Target] = 0
			THEN 0
			WHEN z.GovernorID = s.GovernorID
			THEN ROUND((s.DeadsDelta * 0.1)/t.[Dead Target] *100, 2) 
			ELSE ROUND(s.DeadsDelta/t.[Dead Target] *100, 2) 
			END AS [% of Dead Target]
			,z.Zeroed
		,D.[DKP_SCORE]
		,t.[DKP TARGET] AS [DKP Target]
		,CASE WHEN t.[Kill Target] = 0
				THEN 0
				WHEN z.GovernorID = s.GovernorID
				THEN ROUND( (D.[DKP_SCORE] / (t.[Kill Target]  * 3 + (t.[Dead Target] * 8)) *100) ,2)
				ELSE ROUND( (D.[DKP_SCORE] / (t.[Kill Target]  * 3 + (t.[Dead Target] * 8)) *100) ,2)
				END AS [% of DKP Target]
		,S.[HelpsDelta] AS Helps
		,S.[RSSASSISTDelta] AS RSS_Assist
		,S.[RSSGatheredDelta] AS RSS_Gathered
		,S.[P4T4&T5_KillsDelta] AS [Pass 4 Kills]
	  ,[P6T4&T5_KillsDelta] AS [Pass 6 Kills]
	  ,[P7T4&T5_KillsDelta] AS [Pass 7 Kills]
	  ,[P8T4&T5_KillsDelta] AS [Pass 8 Kills]
	  ,P4DeadsDelta AS [Pass 4 Deads]
	  ,P6DeadsDelta AS [Pass 6 Deads]
	  ,P7DeadsDelta AS [Pass 7 Deads]
	  ,P8DeadsDelta AS [Pass 8 Deads]
	  ,@CURRENTKVK3 AS [KVK_NO]
	  INTO EXCEL_FOR_CURRENT_KVK
	  --INTO EXCEL_FOR_JAN25_KVK
  FROM [ROK_TRACKER].[dbo].[STAGING_STATS] AS S
  LEFT JOIN #HD1 AS HD on S.GovernorID=HD.GovernorID
  JOIN EXCEL_OUTPUT_KVK_TARGETS_MAR25 AS T ON T.gov_id=S.Governorid
  LEFT JOIN #DKP AS D on D.GovernorID=S.Governorid
  LEFT JOIN ZEROED AS Z ON z.GovernorID=S.GovernorID AND Z.ScanOrder = @MATHCHMAKING_SCAN 
  ORDER BY PowerRank ASC

EXEC CREATE_THE_AVERAGES 

DROP TABLE #DKP, #HD1, EXCEL_FOR_DASHBOARD

SELECT TOP (5000000)
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill target],
    [Deads] AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead Target] AS [Dead_Target],
    [% of Dead Target],
    [Zeroed],
    [DKP_SCORE],
    [DKP Target],
    [% of DKP Target],
    [Helps] AS [HelpsDelta],
    [RSS_Assist] AS [RSS_Assist_Delta],
    [RSS_Gathered] AS [RSS_Gathered_Delta],
    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],
    [KVK_NO]
INTO EXCEL_FOR_DASHBOARD
FROM

( SELECT * 
  FROM EXCEL_FOR_CURRENT_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_JAN25_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_SEPT24_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_MAY24_KVK
  UNION
  SELECT * 
  FROM  EXCEL_FOR_FEB24_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_OCT23_KVK
  UNION 
  SELECT * 
  FROM EXCEL_FOR_JUL23_KVK) AS T
ORDER BY KVK_NO, [RANK]

EXEC CREATE_DASH

---- OUTPUT NUMBER 1 = KVK STATS ----
DECLARE
@MAXDATE AS datetime2(0) = (SELECT MAX(ScanDate) FROM KingdomScanData4)

--DROP TABLE STATS_FOR_UPLOAD

TRUNCATE TABLE STATS_FOR_UPLOAD

INSERT INTO STATS_FOR_UPLOAD
(
[Rank],
[KVK_RANK],
[Gov_ID],
[Governor_Name],
[Starting Power],
[Power_Delta],
[T4_KILLS],
[T5_KILLS],
[T4&T5_Kills],
[KILLS_OUTSIDE_KVK],
[Kill Target],
[% of Kill Target],
[Deads_Delta],
[DEADS_OUTSIDE_KVK],
[T4_Deads],
[T5_Deads],
[Dead_Target],
[% of Dead Target],
[Zeroed],
[DKP_SCORE],
[DKP Target],
[% of DKP Target],
[HelpsDelta],
[RSS_Assist_Delta],
[RSS_Gathered_Delta],
[Pass 4 Kills],
[Pass 6 Kills],
[Pass 7 Kills],
[Pass 8 Kills],
[Pass 4 Deads],
[Pass 6 Deads],
[Pass 7 Deads],
[Pass 8 Deads],
[KVK_NO],
[LAST_REFRESH]
)
SELECT 
[Rank], KVK_RANK, Gov_ID AS [Governor ID], RTRIM(Governor_Name) AS [Governor_Name], [Starting Power] AS [Power], ISNULL(Power_Delta, 0) AS [Power Delta] , ISNULL(T4_KILLS, 0) T4_Kills, ISNULL(T5_KILLS, 0) T5_Kills,
ISNULL([T4&T5_Kills],0) [T4&T5_Kills], KILLS_OUTSIDE_KVK AS [OFF_SEASON_KILLS], [Kill Target], ISNULL([% of Kill target], 0) [% of Kill target], ISNULL(Deads, 0) Deads, DEADS_OUTSIDE_KVK AS [OFF_SEASON_DEADS],
T4_Deads, T5_Deads, [Dead Target], ISNULL([% of Dead Target], 0) [% of Dead Target], ISNULL(Zeroed, 0) Zeroed, ISNULL([DKP_Score], 0) [DKP_SCORE], [DKP Target],
ISNULL([% of DKP Target], 0) [% of DKP Target], ISNULL(HELPS, 0) Helps, ISNULL(RSS_Assist, 0) RSS_Assist, ISNULL(RSS_Gathered, 0 ) RSS_Gathered, 
ISNULL([Pass 4 Kills], 0) [Pass 4 Kills], ISNULL([Pass 6 Kills], 0) [Pass 6 Kills], ISNULL([Pass 7 Kills], 0) [Pass7 Kills], ISNULL([Pass 8 Kills], 0) [Pass 8 Kills],
ISNULL([Pass 4 Deads], 0) [Pass 4 Deads], ISNULL([Pass 6 Deads], 0) [Pass 6 Deads], ISNULL([Pass 7 Deads], 0) [Pass 7 Deads], ISNULL([Pass 8 Deads], 0) [Pass 8 Deads], KVK_NO, @MAXDATE AS LAST_REFRESH
--INTO STATS_FOR_UPLOAD
FROM EXCEL_FOR_CURRENT_KVK 
WHERE Gov_ID <> 12025033
ORDER BY [RANK] ASC;

--SELECT * FROM STATS_FOR_UPLOAD

---- OUTPUT NUMBER 2 = ALL STATS FOR DASHBOARD ----

TRUNCATE TABLE ALL_STATS_FOR_DASHBAORD

INSERT INTO ALL_STATS_FOR_DASHBAORD
(
      [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
      [Starting Power], [Power_Delta], [T4_Kills], [T5_Kills],
      [T4&T5_Kills], [Kill Target], [% of Kill target],
      [Deads_Delta], [T4_Deads], [T5_Deads], [Dead Target],
      [% of Dead Target], [Zeroed], [DKP_SCORE], [DKP Target],
      [% of DKP Target], [HelpsDelta], [RSS_Assist_Delta],
      [RSS_Gathered_Delta], [Pass 4 Kills], [Pass 6 Kills],
      [Pass 7 Kills], [Pass 8 Kills], [Pass 4 Deads],
      [Pass 6 Deads], [Pass 7 Deads], [Pass 8 Deads], [KVK_NO]
)
SELECT
      ed.[Rank],
      ed.[KVK_RANK],
      ed.[Gov_ID],
      ISNULL(RTRIM(ed.[Governor_Name]), '') AS [Governor_Name],
      ed.[Starting Power],
      ISNULL(ed.[Power_Delta], 0) AS [Power_Delta],
      ISNULL(ed.[T4_KILLS], 0) AS [T4_Kills],
      ISNULL(ed.[T5_KILLS], 0) AS [T5_Kills],
      ISNULL(ed.[T4&T5_Kills], 0) AS [T4&T5_Kills],
      ISNULL(ed.[Kill Target], 0) AS [Kill Target],
      ISNULL(ed.[% of Kill Target], 0) AS [% of Kill target],
      ISNULL(ed.[Deads_Delta], 0) AS [Deads_Delta],
      ISNULL(ed.[T4_Deads], 0) AS [T4_Deads],
      ISNULL(ed.[T5_Deads], 0) AS [T5_Deads],
      ISNULL(ed.[Dead_Target], 0) AS [Dead Target],
      ISNULL(ed.[% of Dead Target], 0) AS [% of Dead Target],
      ISNULL(ed.[Zeroed], 0) AS [Zeroed],
      ISNULL(ed.[DKP_SCORE], 0) AS [DKP_SCORE],
      ISNULL(ed.[DKP Target], 0) AS [DKP Target],
      ISNULL(ed.[% of DKP Target], 0) AS [% of DKP Target],
      ISNULL(ed.[HelpsDelta], 0) AS [HelpsDelta],
      ISNULL(ed.[RSS_Assist_Delta], 0) AS [RSS_Assist_Delta],
      ISNULL(ed.[RSS_Gathered_Delta], 0) AS [RSS_Gathered_Delta],
      ISNULL(ed.[Pass 4 Kills], 0) AS [Pass 4 Kills],
      ISNULL(ed.[Pass 6 Kills], 0) AS [Pass 6 Kills],
      ISNULL(ed.[Pass 7 Kills], 0) AS [Pass 7 Kills],
      ISNULL(ed.[Pass 8 Kills], 0) AS [Pass 8 Kills],
      ISNULL(ed.[Pass 4 Deads], 0) AS [Pass 4 Deads],
      ISNULL(ed.[Pass 6 Deads], 0) AS [Pass 6 Deads],
      ISNULL(ed.[Pass 7 Deads], 0) AS [Pass 7 Deads],
      ISNULL(ed.[Pass 8 Deads], 0) AS [Pass 8 Deads],
      ed.[KVK_NO]
FROM [ROK_TRACKER].[dbo].[EXCEL_FOR_DASHBOARD] AS ed
WHERE ed.Gov_ID <> 12025033

  --SELECT * FROM ALL_STATS_FOR_DASHBAORD

 ---- OUTPUT NUMBER 3 = POWER BY MONTH ---- 
 TRUNCATE TABLE POWER_BY_MONTH
 
 INSERT INTO POWER_BY_MONTH
 (
 GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
 DEADS, [MONTH], HealedTroops, RangedPoints
 )
 SELECT TOP (5000000)
 GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
 DEADS, [MONTH], HealedTroops, RangedPoints

 FROM (

SELECT GovernorID, RTRIM(GovernorName) AS [GovernorName] ,MAX([Power]) AS 'POWER', MAX(KillPoints) AS KILLPOINTS, MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, EOMONTH(ScanDate) AS [MONTH], MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints
FROM  KingdomScanData4
WHERE GovernorID NOT IN (0, 12025033)
GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

UNION

SELECT GovernorID, RTRIM(GovernorName) AS [GovernorName], MAX([Power]) AS 'POWER', MAX(KillPoints) AS KILLPOINTS, MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, EOMONTH(ScanDate) AS [MONTH], MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints
FROM THE_AVERAGES
GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)) AS T
ORDER BY GovernorID, [MONTH];

--SELECT * FROM POWER_BY_MONTH

EXEC sp_RefreshInactiveGovernors

TRUNCATE TABLE [KS]

--DECLARE
--@MAXDATE AS DATETIME = (SELECT MAX(ScanDate) FROM KingdomScanData4)

--DROP TABLE IF EXISTS [KS]

INSERT INTO [KS]
(
KINGDOM_POWER, Governors, KP, [KILL], [DEAD], [Last Update],
KINGDOM_RANK, KINGDOM_SEED, CH25, HealedTroops, RangedPoints
)
SELECT SUM(CAST([Power] AS BIGINT)) AS KINGDOM_POWER,
COUNT(GovernorID) AS Governors,
SUM([KillPoints]) AS KP,
SUM([TOTAL_KILLS]) as [KILL],
SUM([DEADS]) AS [DEAD],
@MAXDATE AS [Last Update],
--'1554' AS KINGDOM_RANK,
@actual_param1 AS KINGDOM_RANK,
--'C' AS KINGDOM_SEED
@actual_param2 AS KINGDOM_SEED,
CAST(SUM(CASE WHEN [City Hall] = 25 THEN 1 ELSE 0 END) AS INT) AS CH25,
SUM(ISNULL([HealedTroops], 0)) AS HealedTroops,
SUM(ISNULL([RangedPoints], 0)) AS RangedPoints
--INTO [KS]
FROM KingdomScanData4
WHERE ScanDate = @MAXDATE

--SELECT * FROM [KS]

EXEC SUMMARY_PROC

EXEC GOVERNOR_NAMES_PROC

DECLARE @EndTime DATETIME = GETDATE();
DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);

INSERT INTO SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
VALUES (
    'UPDATE_ALL',
    'Complete',
    @EndTime,
    ISNULL((SELECT MAX(LastRunCounter) FROM SP_TaskStatus WHERE TaskName = 'UPDATE_ALL'), 0) + 1,
    @DurationSeconds
);

SET ANSI_WARNINGS ON;

        COMMIT;

        EXEC @ArchiveReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
            @FileDigest = @ImportFileDigest;

        IF @ArchiveReturnCode <> 0
            THROW 51827, 'UPDATE_ALL committed its database work but the stats.csv archive handoff did not complete.', 1;

		INSERT INTO Update_ALL_Complete (CompletionTime)
		VALUES (GETDATE());


    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;
        SET ANSI_WARNINGS ON;
        THROW;
    END CATCH
END;
GO

-- Rollback source: sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql at 74bd8b1
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL2] AS' 
END
GO
ALTER PROCEDURE [dbo].[UPDATE_ALL2]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    -- REQUIRED SET Options for DML against indexed views / persisted computed columns
    SET ANSI_NULLS ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET QUOTED_IDENTIFIER ON;
    SET NUMERIC_ROUNDABORT OFF;

    IF @@TRANCOUNT <> 0
        THROW 51818, 'UPDATE_ALL2 refuses caller-owned transactions; execute the public entry point with no active transaction.', 1;

    SET XACT_ABORT ON;

    DECLARE @rc INT, @rowsKS5 INT, @rowsKS4 INT = 0;
    DECLARE @ImportLockResult INT;
    DECLARE @AllocatedScanOrder INT;
    DECLARE @StagedRows INT;
    DECLARE @ImportFileDigest BINARY(32);
    DECLARE @ImportArchivePath NVARCHAR(4000);
    DECLARE @ArchiveReturnCode INT;
    DECLARE @CurrentAuditPhase NVARCHAR(64) = N'update_all2_start';
    DECLARE @UpdateAll2PhaseAudit TABLE (
        SequenceNo INT IDENTITY(1,1) NOT NULL,
        PhaseName NVARCHAR(64) NOT NULL,
        PhaseStatus NVARCHAR(32) NOT NULL,
        StartedAtUtc DATETIME2(3) NOT NULL,
        CompletedAtUtc DATETIME2(3) NULL,
        DurationMs INT NULL,
        RowsIn INT NULL,
        RowsOut INT NULL,
        DetailsJson NVARCHAR(MAX) NULL,
        ErrorType NVARCHAR(128) NULL,
        ErrorText NVARCHAR(2000) NULL
    );

    BEGIN TRY
        ----------------------------------------------------------------
        -- Phase A: Import → KS5 → (maybe) KS4  [commit early]
        ----------------------------------------------------------------
        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51810, 'UPDATE_ALL2 could not acquire the KingdomScanData4 import mutex within 60000 ms; Phase A was not started.', 1;

        -- Get deterministic defaults from KS. Choose "latest" row by [Last Update] if present.
        DECLARE @actual_param1 FLOAT = NULL,
                @actual_param2 NVARCHAR(100) = NULL;

        SELECT TOP (1)
            @actual_param1 = COALESCE(@param1, KINGDOM_RANK, 0),
            @actual_param2 = COALESCE(@param2, KINGDOM_SEED, N'')
        FROM dbo.KS
        WHERE KINGDOM_RANK IS NOT NULL OR KINGDOM_SEED IS NOT NULL
        ORDER BY [Last Update] DESC; 

        IF @actual_param1 IS NULL SET @actual_param1 = COALESCE(@param1, 0);
        IF @actual_param2 IS NULL SET @actual_param2 = COALESCE(@param2, N'');

        DECLARE @StartTime DATETIME = GETDATE();

        -- 1) Refresh latest data
        EXEC @rc = dbo.IMPORT_STAGING_PROC_CORE
            @ImportFileDigest = @ImportFileDigest OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT;
        IF @rc <> 0
        BEGIN
            RAISERROR('IMPORT_STAGING_PROC failed (rc=%d).', 16, 1, @rc);
        END

        SELECT
            @AllocatedScanOrder = MIN(SCANORDER),
            @StagedRows = COUNT(*)
        FROM dbo.IMPORT_STAGING;

        IF @AllocatedScanOrder IS NULL
           OR @AllocatedScanOrder <> (SELECT MAX(SCANORDER) FROM dbo.IMPORT_STAGING)
           OR @StagedRows <> (SELECT COUNT(DISTINCT [Governor ID]) FROM dbo.IMPORT_STAGING)
            THROW 51811, 'UPDATE_ALL2 rejected empty, mixed-scan, or duplicate-governor canonical staging.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @AllocatedScanOrder
        )
            THROW 51812, 'UPDATE_ALL2 refused to reuse an existing KingdomScanData5 SCANORDER.', 1;

        -- 2) Insert into KingdomScanData5
        INSERT INTO dbo.KingdomScanData5 (
              PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
            , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
            , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
            , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
        )
        SELECT
              ROW_NUMBER() OVER (ORDER BY [Power] DESC, [Governor ID] ASC) AS PowerRank
            , RTRIM([Name])
            , [Governor ID]
            , NULLIF(
				  LTRIM(RTRIM(
					REPLACE(REPLACE(CONVERT(nvarchar(255), [Alliance]), CHAR(13), ''), CHAR(10), '')
				  )),
				  N''
			  ) AS Alliance
            , [Power]
            , [Total Kill Points]
            , [Dead Troops]
            , [T1-Kills], [T2-Kills], [T3-Kills], [T4-Kills], [T5-Kills]
            , [Kills (T4+)]
            , [KILLS]
            , [RSS Gathered], [RSS Assistance], [Alliance Helps]
            , [ScanDate], [SCANORDER]
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , [HealedTroops], [RangedPoints], [Civilization], [AutarchTimes], [KvKPlayed], [MostKvKKill], [MostKvKDead], [MostKvKHeal]
            , [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon], [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct]
        FROM dbo.IMPORT_STAGING WITH (TABLOCK);

        SET @rowsKS5 = @@ROWCOUNT;

        IF @rowsKS5 = 0
        BEGIN
            RAISERROR('No rows inserted into KingdomScanData5 (IMPORT_STAGING was empty).', 16, 1);
        END

        IF @rowsKS5 <> @StagedRows
           OR EXISTS
              (
                  SELECT 1
                  FROM dbo.KingdomScanData5
                  WHERE SCANORDER = @AllocatedScanOrder
                  GROUP BY SCANORDER, GovernorID
                  HAVING COUNT_BIG(*) > 1
              )
            THROW 51813, 'UPDATE_ALL2 KingdomScanData5 row-count or duplicate-key validation failed.', 1;

        -- SMART INDEX MAINTENANCE: Only update stats for KS5 (lightweight)
        -- Full index rebuild happens nightly via maintenance job
        PRINT 'Updating statistics for KingdomScanData5 (quick sample)...';
        UPDATE STATISTICS dbo.KingdomScanData5 WITH SAMPLE 20 PERCENT;
        PRINT 'KingdomScanData5 statistics refreshed.';

        -- Cache MAX(SCANORDER) values to avoid repeated scans
        DECLARE @MaxScanOrder5 INT = (SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData5 ORDER BY SCANORDER DESC);
        DECLARE @MaxScanOrder4 INT = (SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData4 ORDER BY SCANORDER DESC);

        IF @MaxScanOrder5 <> @AllocatedScanOrder
            THROW 51814, 'UPDATE_ALL2 allocated scan does not match the latest KingdomScanData5 scan.', 1;

        -- 3) Promote to KS4 if newer
        IF @MaxScanOrder5 > @MaxScanOrder4
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.KingdomScanData4
                WHERE SCANORDER = @AllocatedScanOrder
            )
                THROW 51815, 'UPDATE_ALL2 refused to reuse an existing KingdomScanData4 SCANORDER.', 1;

            INSERT INTO dbo.KingdomScanData4 (
                  PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , RSS_Gathered, RSSAssistance, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
            )
            SELECT
                  PowerRank, GovernorName, GovernorID,
                  NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), ''),
                  [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @MaxScanOrder5

            SET @rowsKS4 = @@ROWCOUNT;

            IF @rowsKS4 <> @rowsKS5
               OR EXISTS
                  (
                      SELECT 1
                      FROM dbo.KingdomScanData4
                      WHERE SCANORDER = @AllocatedScanOrder
                      GROUP BY SCANORDER, GovernorID
                      HAVING COUNT_BIG(*) > 1
                  )
                THROW 51816, 'UPDATE_ALL2 KingdomScanData4 row-count or duplicate-key validation failed.', 1;

            ----------------------------------------------------------------
            -- SMART INDEX MAINTENANCE for KS4: Check fragmentation first
            -- Thresholds: 
            --   - Skip if < 10% fragmentation
            --   - REORGANIZE if 10-30% fragmentation (online, low impact)
            --   - REBUILD if > 30% fragmentation
            ----------------------------------------------------------------
            PRINT 'Checking KingdomScanData4 index fragmentation...';
            
            DECLARE @IndexMaintLog TABLE (
                IndexName NVARCHAR(128),
                FragmentationPercent DECIMAL(5,2),
                Action NVARCHAR(20)
            );

            -- Check fragmentation of critical indexes
            DECLARE @IndexName NVARCHAR(128);
            DECLARE @Fragmentation DECIMAL(5,2);
            DECLARE @SQL NVARCHAR(MAX);

            DECLARE idx_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT 
                    i.name AS IndexName,
                    ips.avg_fragmentation_in_percent AS Fragmentation
                FROM sys.dm_db_index_physical_stats(
                    DB_ID(), 
                    OBJECT_ID('dbo.KingdomScanData4'), 
                    NULL, NULL, 'LIMITED'
                ) AS ips
                INNER JOIN sys.indexes AS i 
                    ON ips.object_id = i.object_id 
                    AND ips.index_id = i.index_id
                WHERE 
                    i.name IN (
                        'CIX_KS4_ScanOrder_Governor',
                        'IX_KSD4_Governor_ScanOrder', 
                        'IX_KS4_Governor_ScanDate',
                        'IX_KSD4_Gov_ScanOrder'
                    )
                    AND ips.avg_fragmentation_in_percent IS NOT NULL;

            OPEN idx_cursor;
            FETCH NEXT FROM idx_cursor INTO @IndexName, @Fragmentation;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @Fragmentation < 10
                BEGIN
                    -- Skip - fragmentation is low
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, 'SKIPPED');
                    PRINT '  ' + @IndexName + ': ' + CAST(@Fragmentation AS VARCHAR(10)) + '% - Skipped';
                END
                ELSE IF @Fragmentation < 30
                BEGIN
                    -- REORGANIZE - medium fragmentation, online operation
                    SET @SQL = N'ALTER INDEX [' + @IndexName + N'] ON dbo.KingdomScanData4 REORGANIZE;';
                    EXEC sp_executesql @SQL;
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, 'REORGANIZED');
                    PRINT '  ' + @IndexName + ': ' + CAST(@Fragmentation AS VARCHAR(10)) + '% - Reorganized';
                END
                ELSE
                BEGIN
                    -- REBUILD - high fragmentation
                    SET @SQL = N'ALTER INDEX [' + @IndexName + N'] ON dbo.KingdomScanData4 REBUILD WITH (SORT_IN_TEMPDB = ON, MAXDOP = 0);';
                    EXEC sp_executesql @SQL;
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, 'REBUILT');
                    PRINT '  ' + @IndexName + ': ' + CAST(@Fragmentation AS VARCHAR(10)) + '% - Rebuilt';
                END

                FETCH NEXT FROM idx_cursor INTO @IndexName, @Fragmentation;
            END

            CLOSE idx_cursor;
            DEALLOCATE idx_cursor;

            -- Always update statistics after any index maintenance
            UPDATE STATISTICS dbo.KingdomScanData4 WITH SAMPLE 25 PERCENT;
            PRINT 'KingdomScanData4 statistics refreshed.';

			EXEC [dbo].[Refresh_PlayerScanMeta] @MinScanOrder = @MaxScanOrder5
			UPDATE STATISTICS dbo.PlayerScanMeta WITH SAMPLE 25 PERCENT;

            -- Log index maintenance actions
            SELECT * FROM @IndexMaintLog;
        END

        EXEC dbo.usp_UpsertGovernorNameHistoryForScan @ScanOrder = @MaxScanOrder5;

        -- 4) Truncate staging (safe post-insert)
        TRUNCATE TABLE dbo.IMPORT_STAGING;

        COMMIT;  -- ✅ Import is now durable even if later steps fail

        EXEC @ArchiveReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
            @FileDigest = @ImportFileDigest;

        IF @ArchiveReturnCode <> 0
            THROW 51817, 'UPDATE_ALL2 committed Phase A but the stats.csv archive handoff did not complete.', 1;

        -- Return / Log Phase A summary values
        SELECT
            @MaxScanOrder5    AS Ks5_MaxScanOrder,
            @rowsKS5          AS Ks5_RowsInserted,
            @rowsKS4          AS Ks4_RowsInserted,
            (SELECT COUNT(*) FROM dbo.IMPORT_STAGING) AS ImportStaging_RowsAfterPhaseA,
            (SELECT COUNT(*) FROM dbo.KingdomScanData4 WHERE SCANORDER = @MaxScanOrder4) AS Ks4_RowsInLatest,
            @ImportArchivePath AS ArchivedFilePath;

        ----------------------------------------------------------------
        -- Phase B: Downstream builds (non-critical) - separate transaction
        -- ⚡ OPTIMIZED SECTION ⚡
        ----------------------------------------------------------------
        BEGIN TRANSACTION;

        -- Timing variables for performance monitoring
        DECLARE @PhaseBStart DATETIME2 = SYSUTCDATETIME();
        DECLARE @StepStart DATETIME2;
        DECLARE @StepEnd DATETIME2;
        DECLARE @StepDuration INT;

        -- *** NEW: Check log space at Phase B start ***
        DECLARE @CurrentLogUsedPct DECIMAL(5,2) = NULL;
        DECLARE @LogReuse NVARCHAR(60) = NULL;

        BEGIN TRY
            SELECT @CurrentLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC if DMV not available
            BEGIN TRY
                CREATE TABLE #LogSpace (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpace EXEC('DBCC SQLPERF(LOGSPACE)');
                SELECT @CurrentLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpace 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpace;
            END TRY
            BEGIN CATCH
                SET @CurrentLogUsedPct = NULL;
            END CATCH
        END CATCH

        BEGIN TRY
            SELECT @LogReuse = log_reuse_wait_desc
            FROM sys.databases
            WHERE name = DB_NAME();
        END TRY
        BEGIN CATCH
            SET @LogReuse = NULL;
        END CATCH

        PRINT 'Phase B Start - Log Usage: ' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), 'unknown') + 
              '%, Reuse Wait: ' + ISNULL(@LogReuse, 'unknown');

        -- If log usage is high (>70%), force checkpoint before continuing
        IF @CurrentLogUsedPct IS NOT NULL AND @CurrentLogUsedPct > 70.0
        BEGIN
            PRINT 'Log usage elevated (' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                  '%); executing CHECKPOINT before Phase B operations...';
            CHECKPOINT;
            
            -- Log this event for monitoring
            INSERT INTO dbo.ErrorAudit (ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo)
            VALUES (
                GETDATE(), 'UPDATE_ALL2', 0, 
                'Elevated log usage detected at Phase B start', 0,
                'Log usage: ' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                '%, Reuse wait: ' + ISNULL(@LogReuse, 'unknown')
            );
        END

        -- Step 1: CREATE_THE_AVERAGES
        SET @CurrentAuditPhase = N'update_all2_create_averages';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.CREATE_THE_AVERAGES;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
             N'{"procedure":"CREATE_THE_AVERAGES"}');
        PRINT 'CREATE_THE_AVERAGES: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

        -- Step 2: Rebuild EXCEL_FOR_DASHBOARD
        SET @CurrentAuditPhase = N'update_all2_rebuild_excel_dashboard';
        SET @StepStart = SYSUTCDATETIME();
        IF OBJECT_ID('dbo.EXCEL_FOR_DASHBOARD','U') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        EXEC dbo.sp_Rebuild_ExcelForDashboard;
        
        -- ⚡ OPTIMIZATION: Update statistics on newly built table
        IF OBJECT_ID('dbo.EXCEL_FOR_DASHBOARD','U') IS NOT NULL
        BEGIN
            UPDATE STATISTICS dbo.EXCEL_FOR_DASHBOARD WITH SAMPLE 25 PERCENT;
            PRINT 'EXCEL_FOR_DASHBOARD statistics updated';
        END
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
             N'{"procedure":"sp_Rebuild_ExcelForDashboard","target":"EXCEL_FOR_DASHBOARD"}');
        PRINT 'sp_Rebuild_ExcelForDashboard: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

        -- Step 3: CREATE_DASH2
        SET @CurrentAuditPhase = N'update_all2_create_dash2';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.CREATE_DASH2;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
             N'{"procedure":"CREATE_DASH2"}');
        PRINT 'CREATE_DASH2: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

        ----------------------------------------------------------------
        -- Step 4a: Refresh EXCEL_FOR_KVK table FIRST (lifted from SP_Stats_for_Upload)
        ----------------------------------------------------------------
        SET @StepStart = SYSUTCDATETIME();
        
        -- Determine which KVK and Scan to use (same logic as SP_Stats_for_Upload)
        DECLARE @LatestKVK_Upload INT;
        DECLARE @MaxScan_Upload INT = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4);
        DECLARE @MatchmakingScan_Upload INT;
        DECLARE @DraftScan_Upload INT;
        DECLARE @ScanToUse_Upload INT;

        SELECT TOP 1 @LatestKVK_Upload = KVKVersion
        FROM dbo.ProcConfig
        WHERE ConfigKey = 'MATCHMAKING_SCAN'
          AND TRY_CAST(ConfigValue AS INT) <= @MaxScan_Upload
        ORDER BY KVKVersion DESC;

        IF @LatestKVK_Upload IS NOT NULL
        BEGIN
            SELECT
                @MatchmakingScan_Upload = MAX(CASE WHEN ConfigKey = 'MATCHMAKING_SCAN' THEN TRY_CAST(ConfigValue AS INT) END),
                @DraftScan_Upload       = MAX(CASE WHEN ConfigKey = 'DRAFTSCAN'        THEN TRY_CAST(ConfigValue AS INT) END)
            FROM dbo.ProcConfig
            WHERE KVKVersion = @LatestKVK_Upload
              AND ConfigKey IN ('MATCHMAKING_SCAN','DRAFTSCAN');

            -- Decide which scan to use
            SET @ScanToUse_Upload = NULL;
            IF @MatchmakingScan_Upload IS NOT NULL AND @MaxScan_Upload >= @MatchmakingScan_Upload
                SET @ScanToUse_Upload = @MatchmakingScan_Upload;
            ELSE IF @DraftScan_Upload IS NOT NULL AND @MaxScan_Upload >= @DraftScan_Upload
                SET @ScanToUse_Upload = @DraftScan_Upload;

            IF @ScanToUse_Upload IS NOT NULL
            BEGIN
                PRINT 'Step 4a: Refreshing EXCEL_FOR_KVK_' + CAST(@LatestKVK_Upload AS VARCHAR(10)) 
                    + ' with ScanOrder=' + CAST(@ScanToUse_Upload AS VARCHAR(10)) + '...';
                
                -- ✅ LIFT: Call sp_ExcelOutput_ByKVK directly here
                SET @CurrentAuditPhase = N'update_all2_excel_for_kvk_refresh';
                SET @StepStart = SYSUTCDATETIME();
                EXEC dbo.sp_ExcelOutput_ByKVK @KVK = @LatestKVK_Upload, @Scan = @ScanToUse_Upload;
                
                SET @StepEnd = SYSUTCDATETIME();
                SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
                INSERT INTO @UpdateAll2PhaseAudit
                    (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
                VALUES
                    (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
                     N'{"procedure":"sp_ExcelOutput_ByKVK","kvk":' + CAST(@LatestKVK_Upload AS NVARCHAR(20)) +
                     N',"scan":' + CAST(@ScanToUse_Upload AS NVARCHAR(20)) + N'}');
                PRINT 'sp_ExcelOutput_ByKVK: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';
               	
				IF @@TRANCOUNT > 0
                BEGIN
                    COMMIT;
                    PRINT 'Committed EXCEL_FOR_KVK refresh before STATS_FOR_UPLOAD.';
                END

				-- ✅ CRITICAL: Force commit visibility before next step
                PRINT 'Forcing commit flush via CHECKPOINT...';
                CHECKPOINT;
                WAITFOR DELAY '00:00:00.100';  -- 100ms safety buffer

                ----------------------------------------------------------------
                -- Step 4b: Now populate STATS_FOR_UPLOAD (simplified SP)
                ----------------------------------------------------------------
                SET @CurrentAuditPhase = N'update_all2_stats_for_upload';
                SET @StepStart = SYSUTCDATETIME();
                EXEC dbo.SP_Stats_for_Upload;  -- Now just does INSERT, no refresh
                SET @StepEnd = SYSUTCDATETIME();
                SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
                INSERT INTO @UpdateAll2PhaseAudit
                    (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
                VALUES
                    (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
                     N'{"procedure":"SP_Stats_for_Upload"}');
                PRINT 'SP_Stats_for_Upload: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

				-- Resume Phase B work in a new transaction
                BEGIN TRANSACTION;
            END
            ELSE
            BEGIN
                SET @CurrentAuditPhase = N'update_all2_stats_for_upload';
                SET @StepStart = SYSUTCDATETIME();
                INSERT INTO @UpdateAll2PhaseAudit
                    (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
                VALUES
                    (N'update_all2_excel_for_kvk_refresh', N'skipped', @StepStart, @StepStart, 0,
                     N'{"reason":"no_valid_scan"}'),
                    (N'update_all2_stats_for_upload', N'skipped', @StepStart, @StepStart, 0,
                     N'{"reason":"no_valid_scan"}');
                PRINT 'Step 4: Skipping STATS_FOR_UPLOAD refresh (no valid scan available)';
            END
        END
        ELSE
        BEGIN
            SET @CurrentAuditPhase = N'update_all2_stats_for_upload';
            SET @StepStart = SYSUTCDATETIME();
            INSERT INTO @UpdateAll2PhaseAudit
                (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
            VALUES
                (N'update_all2_excel_for_kvk_refresh', N'skipped', @StepStart, @StepStart, 0,
                 N'{"reason":"no_eligible_kvk"}'),
                (N'update_all2_stats_for_upload', N'skipped', @StepStart, @StepStart, 0,
                 N'{"reason":"no_eligible_kvk"}');
            PRINT 'Step 4: Skipping STATS_FOR_UPLOAD refresh (no eligible KVK found)';
        END

        CHECKPOINT;
        WAITFOR DELAY '00:00:00.100';  -- 100ms delay for commit propagation
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        PRINT 'SP_Stats_for_Upload: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms (includes checkpoint)';

        ----------------------------------------------------------------
        -- ⚡⚡⚡ OPTIMIZED INSERT INTO ALL_STATS_FOR_DASHBAORD ⚡⚡⚡
        ----------------------------------------------------------------
        SET @CurrentAuditPhase = N'update_all2_all_stats_dashboard';
        SET @StepStart = SYSUTCDATETIME();
        
        TRUNCATE TABLE dbo.ALL_STATS_FOR_DASHBAORD;

        INSERT INTO dbo.ALL_STATS_FOR_DASHBAORD WITH (TABLOCK) (
            [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
            [Starting Power], [Power_Delta], [Civilization], [KvKPlayed],
            [MostKvKKill], [MostKvKDead], [MostKvKHeal],
            [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon],
            [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct],
            [Starting T4&T5_KILLS], [T4_KILLS], [T5_KILLS], [T4&T5_Kills],
            [KILLS_OUTSIDE_KVK], [Kill Target], [% of Kill target],
            [Starting Deads], Deads_Delta, [DEADS_OUTSIDE_KVK],
            [T4_Deads], [T5_Deads], [Dead Target], [% of Dead Target], [% of Dead_Target],
            [Zeroed], [DKP_SCORE], [DKP Target], [% of DKP Target],
            HelpsDelta, RSS_Assist_Delta, RSS_Gathered_Delta,
            [Pass 4 Kills], [Pass 6 Kills], [Pass 7 Kills], [Pass 8 Kills],
            [Pass 4 Deads], [Pass 6 Deads], [Pass 7 Deads], [Pass 8 Deads],
            [Starting HealedTroops], [HealedTroopsDelta],
            [Starting KillPoints], [KillPointsDelta],
            [RangedPoints], [RangedPointsDelta],
            [AutarchTimes],
            [Max_PreKvk_Points], [Max_HonorPoints],
            [PreKvk_Rank], [Honor_Rank], [KVK_NO]
        )
        SELECT
            ed.[Rank], 
            ed.[KVK_RANK], 
            ed.[Gov_ID],
            RTRIM(COALESCE(ed.[Governor_Name], '')) AS [Governor_Name],
            
            -- Numeric columns with COALESCE (handles NULL efficiently)
            COALESCE(ed.[Starting Power], 0),
            COALESCE(ed.[Power_Delta], 0),
            ed.[Civilization],  -- NULL allowed
            COALESCE(ed.[KvKPlayed], 0),
            
            COALESCE(ed.[MostKvKKill], 0),
            COALESCE(ed.[MostKvKDead], 0),
            COALESCE(ed.[MostKvKHeal], 0),
            COALESCE(ed.[Acclaim], 0),
            COALESCE(ed.[HighestAcclaim], 0),
            COALESCE(ed.[AOOJoined], 0),
            COALESCE(ed.[AOOWon], 0),
            COALESCE(ed.[AOOAvgKill], 0),
            COALESCE(ed.[AOOAvgDead], 0),
            COALESCE(ed.[AOOAvgHeal], 0),
            ed.[Conduct],
            
            COALESCE(ed.[Starting_T4&T5_KILLS], 0),
            COALESCE(ed.[T4_KILLS], 0),
            COALESCE(ed.[T5_KILLS], 0),
            COALESCE(ed.[T4&T5_Kills], 0),
            COALESCE(ed.[KILLS_OUTSIDE_KVK], 0),
            COALESCE(ed.[Kill Target], 0),
            COALESCE(ed.[% of Kill Target], 0),
            
            COALESCE(ed.[Starting_Deads], 0),
            COALESCE(ed.[Deads_Delta], 0),
            COALESCE(ed.[DEADS_OUTSIDE_KVK], 0),
            COALESCE(ed.[T4_Deads], 0),
            COALESCE(ed.[T5_Deads], 0),
            COALESCE(ed.[Dead_Target], 0),
            COALESCE(ed.[% of Dead Target], 0),
            COALESCE(ed.[% of Dead Target], 0),  -- Duplicate column (fix in schema later)
            
            COALESCE(ed.[Zeroed], 0),
            COALESCE(ed.[DKP_SCORE], 0),
            COALESCE(ed.[DKP Target], 0),
            COALESCE(ed.[% of DKP Target], 0),
            
            COALESCE(ed.[HelpsDelta], 0),
            COALESCE(ed.[RSS_Assist_Delta], 0),
            COALESCE(ed.[RSS_Gathered_Delta], 0),
            
            COALESCE(ed.[Pass 4 Kills], 0),
            COALESCE(ed.[Pass 6 Kills], 0),
            COALESCE(ed.[Pass 7 Kills], 0),
            COALESCE(ed.[Pass 8 Kills], 0),
            COALESCE(ed.[Pass 4 Deads], 0),
            COALESCE(ed.[Pass 6 Deads], 0),
            COALESCE(ed.[Pass 7 Deads], 0),
            COALESCE(ed.[Pass 8 Deads], 0),
            
            COALESCE(ed.[Starting_HealedTroops], 0),
            COALESCE(ed.[HealedTroopsDelta], 0),
            COALESCE(ed.[Starting_KillPoints], 0),
            COALESCE(ed.[KillPointsDelta], 0),
            COALESCE(ed.[RangedPoints], 0),
            COALESCE(ed.[RangedPointsDelta], 0),
            COALESCE(ed.[AutarchTimes], 0),
            
            COALESCE(ed.[Max_PreKvk_Points], 0),
            COALESCE(ed.[Max_HonorPoints], 0),
            COALESCE(ed.[PreKvk_Rank], 0),
            COALESCE(ed.[Honor_Rank], 0),
            COALESCE(ed.[KVK_NO], 0)
        FROM dbo.EXCEL_FOR_DASHBOARD AS ed
        WHERE ed.Gov_ID <> 12025033
        OPTION (RECOMPILE);  -- Fresh execution plan with current statistics
        
        DECLARE @RowsInserted INT = @@ROWCOUNT;
        
        -- ⚡ OPTIMIZATION: Update statistics after bulk insert
        UPDATE STATISTICS dbo.ALL_STATS_FOR_DASHBAORD WITH FULLSCAN;
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N'{"target":"ALL_STATS_FOR_DASHBAORD"}');
        PRINT 'ALL_STATS_FOR_DASHBAORD insert: ' + CAST(@RowsInserted AS VARCHAR(10)) + ' rows, ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';
        
        ----------------------------------------------------------------
        -- Continue with POWER_BY_MONTH and remaining steps
        ----------------------------------------------------------------
        SET @CurrentAuditPhase = N'update_all2_power_by_month';
        SET @StepStart = SYSUTCDATETIME();
        
        TRUNCATE TABLE dbo.POWER_BY_MONTH;

        INSERT INTO dbo.POWER_BY_MONTH (
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS], 
            DEADS, [MONTH], HealedTroops, RangedPoints
        )
        SELECT 
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
            DEADS, [MONTH], HealedTroops, RangedPoints
        FROM (
            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.KingdomScanData4
            WHERE GovernorID NOT IN (0, 12025033)
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

            UNION ALL

            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.THE_AVERAGES
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)
        ) AS T
        ORDER BY GovernorID, [MONTH];
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
             N'{"target":"POWER_BY_MONTH"}');
        PRINT 'POWER_BY_MONTH: ' + CAST(@StepDuration AS VARCHAR(10)) + 'ms';

        SET @CurrentAuditPhase = N'update_all2_refresh_inactive_governors';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.sp_RefreshInactiveGovernors;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
             N'{"procedure":"sp_RefreshInactiveGovernors"}');

        DECLARE @MAXDATE DATETIME = (SELECT TOP 1 ScanDate FROM dbo.KingdomScanData4 ORDER BY ScanDate DESC);

        SET @CurrentAuditPhase = N'update_all2_ks_summary_insert';
        SET @StepStart = SYSUTCDATETIME();
        INSERT INTO dbo.KS (
            KINGDOM_POWER, Governors, KP, [KILL], [DEAD], [CH25], 
            HealedTroops, RangedPoints, [Last Update], KINGDOM_RANK, KINGDOM_SEED
        )
        SELECT
            SUM(CAST([Power] AS BIGINT)), COUNT(GovernorID), SUM([KillPoints]),
            SUM([TOTAL_KILLS]), SUM([DEADS]),
            CAST(SUM(CASE WHEN [City Hall] = 25 THEN 1 ELSE 0 END) AS INT),
            SUM(ISNULL([HealedTroops], 0)), SUM(ISNULL([RangedPoints], 0)),
            @MAXDATE, @actual_param1, @actual_param2
        FROM dbo.KingdomScanData4
        WHERE ScanDate = @MAXDATE;
        SET @RowsInserted = @@ROWCOUNT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N'{"target":"KS"}');

        SET @CurrentAuditPhase = N'update_all2_summary_proc';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.SUMMARY_PROC;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
             N'{"procedure":"SUMMARY_PROC"}');

        SET @CurrentAuditPhase = N'update_all2_governor_names';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.GOVERNOR_NAMES_PROC;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
             N'{"procedure":"GOVERNOR_NAMES_PROC"}');

        SET @CurrentAuditPhase = N'update_all2_scan_list';
        SET @StepStart = SYSUTCDATETIME();
        TRUNCATE TABLE dbo.SCAN_LIST;

        INSERT INTO dbo.SCAN_LIST (SCANORDER, ScanDate)
        SELECT SCANORDER, ScanDate
        FROM dbo.KingdomScanData4
        GROUP BY SCANORDER, ScanDate;
        SET @RowsInserted = @@ROWCOUNT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N'{"target":"SCAN_LIST"}');

        ----------------------------------------------------------------
        -- *** NEW: Phase B Completion - Log Management ***
        ----------------------------------------------------------------
        
        -- Force checkpoint to write dirty pages and minimize recovery time
        SET @CurrentAuditPhase = N'update_all2_checkpoint_log';
        SET @StepStart = SYSUTCDATETIME();
        PRINT 'Executing CHECKPOINT to flush dirty pages...';
        CHECKPOINT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N'completed', @StepStart, @StepEnd, @StepDuration,
             N'{"operation":"CHECKPOINT"}');
        PRINT 'CHECKPOINT complete.';

        -- Get final log usage
        DECLARE @FinalLogUsedPct DECIMAL(5,2) = NULL;
        BEGIN TRY
            SELECT @FinalLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC
            BEGIN TRY
                CREATE TABLE #LogSpaceFinal (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpaceFinal EXEC('DBCC SQLPERF(LOGSPACE)');
                SELECT @FinalLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpaceFinal 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpaceFinal;
            END TRY
            BEGIN CATCH
                SET @FinalLogUsedPct = NULL;
            END CATCH
        END CATCH

        -- Insert signal record for Python bot to detect
        IF OBJECT_ID('dbo.LogBackupTriggerQueue', 'U') IS NOT NULL
        BEGIN
            INSERT INTO dbo.LogBackupTriggerQueue (
                TriggerTime, 
                ProcedureName, 
                Reason, 
                LogUsedPctBefore
            )
            VALUES (
                SYSDATETIME(), 
                'UPDATE_ALL2', 
                'post_heavy_operation',
                @FinalLogUsedPct
            );
            PRINT 'Log backup trigger queued (log usage: ' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), 'unknown') + '%).';
        END

        -- Attempt to trigger log backup job (non-blocking, best effort)
        DECLARE @LogBackupTriggered BIT = 0;
        PRINT 'Log backup trigger queued for Python processing.';

        DECLARE @EndTime DATETIME = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
        DECLARE @PhaseBDuration INT = DATEDIFF(MILLISECOND, @PhaseBStart, SYSUTCDATETIME());

        PRINT '========================================';
        PRINT 'Phase B Total: ' + CAST(@PhaseBDuration AS VARCHAR(10)) + 'ms';
        PRINT 'Log Usage: Initial=' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), 'unknown') + 
              '%, Final=' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), 'unknown') + '%';
        PRINT 'Log Backup Triggered: ' + CASE WHEN @LogBackupTriggered = 1 THEN 'Yes' ELSE 'No (queued for Python)' END;
        PRINT '========================================';

        INSERT INTO dbo.SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
        VALUES (
            'UPDATE_ALL2', 'Complete', @EndTime,
            ISNULL((SELECT MAX(LastRunCounter) FROM dbo.SP_TaskStatus WHERE TaskName='UPDATE_ALL2'), 0) + 1,
            @DurationSeconds
        );

        COMMIT;

        INSERT INTO dbo.Update_ALL_Complete (CompletionTime) VALUES (GETDATE());

        SELECT
            PhaseName,
            PhaseStatus,
            StartedAtUtc,
            CompletedAtUtc,
            DurationMs,
            RowsIn,
            RowsOut,
            DetailsJson,
            ErrorType,
            ErrorText
        FROM @UpdateAll2PhaseAudit
        ORDER BY SequenceNo;

        SELECT 
            @rowsKS5 AS RowsInsertedKS5,
            @rowsKS4 AS RowsInsertedKS4,
            @DurationSeconds AS DurationSeconds,
            @PhaseBDuration AS PhaseBDurationMS,
            @CurrentLogUsedPct AS LogUsedPctBefore,
            @FinalLogUsedPct AS LogUsedPctAfter,
            @LogBackupTriggered AS LogBackupTriggered,
            'SUCCESS' AS Status;

    END TRY
	BEGIN CATCH
		DECLARE @ErrNum  INT = ERROR_NUMBER();
		DECLARE @ErrMsg  NVARCHAR(MAX) = ERROR_MESSAGE();
		DECLARE @ErrLine INT = ERROR_LINE();
		DECLARE @ErrProc NVARCHAR(200) = ERROR_PROCEDURE();

		-- ✅ capture transaction state before doing anything
		DECLARE @XState INT = XACT_STATE();

		-- ✅ if a transaction exists, you MUST rollback first (especially if @XState = -1)
		IF @XState <> 0
			ROLLBACK;

		-- ✅ now you're in autocommit, logging is allowed
		BEGIN TRY
			INSERT INTO dbo.ErrorAudit (
				ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo
			)
			VALUES (
				GETDATE(), ISNULL(@ErrProc, 'UPDATE_ALL2'), @ErrNum, @ErrMsg, @ErrLine,
				N'XACT_STATE=' + CAST(@XState AS NVARCHAR(10)) +
				N'; CurrentPhase=' + ISNULL(@CurrentAuditPhase, N'unknown') +
				N'; Phase info: KS5_Rows=' + ISNULL(CAST(@rowsKS5 AS NVARCHAR(20)), N'NULL') +
				N', KS4_Rows=' + ISNULL(CAST(@rowsKS4 AS NVARCHAR(20)), N'NULL')
			);
		END TRY
		BEGIN CATCH
			-- If even logging fails, don't mask the original error
		END CATCH;

		THROW;
	END CATCH
END
GO

DROP PROCEDURE dbo.CLAIM_KS4_IMPORT_FILE;

DECLARE @RetainedClaimRows bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileClaim);

IF @RetainedClaimRows = 0
    DROP TABLE dbo.KS4_ImportFileClaim;

EXEC sys.sp_refreshsqlmodule N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE';
EXEC sys.sp_refreshsqlmodule N'dbo.ARCHIVE_IMPORT_STAGING_FILE';
EXEC sys.sp_refreshsqlmodule N'dbo.IMPORT_STAGING_PROC_CORE';
EXEC sys.sp_refreshsqlmodule N'dbo.IMPORT_STAGING_PROC';
EXEC sys.sp_refreshsqlmodule N'dbo.UPDATE_ALL';
EXEC sys.sp_refreshsqlmodule N'dbo.UPDATE_ALL2';

IF OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NOT NULL
    THROW 52360, 'Phase 5.0 rollback did not remove the claim entry point.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.parameters
    WHERE object_id IN
    (
        OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'),
        OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'),
        OBJECT_ID(N'dbo.UPDATE_ALL', N'P'),
        OBJECT_ID(N'dbo.UPDATE_ALL2', N'P'),
        OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P')
    )
      AND name = N'@CompletedFileName'
)
    THROW 52361, 'Phase 5.0 rollback left the immutable filename parameter in the old contract.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'))
       NOT LIKE N'%C:\discord_file_downloader\downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P'))
       NOT LIKE N'%C:\discord_file_downloader\downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       NOT LIKE N'%C:\discord_file_downloader\downloads\stats.csv%'
    THROW 52362, 'Phase 5.0 rollback did not restore the exact old mutable-path routines.', 1;

COMMIT TRANSACTION;
GO

SELECT
    N'phase5_immutable_import_file_handoff_rollback' AS EvidenceSection,
    N'PASS' AS RollbackStatus,
    OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') AS RetainedClaimEvidenceTableObjectId;
