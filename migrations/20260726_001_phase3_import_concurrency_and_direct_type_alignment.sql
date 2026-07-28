/*
MigrationId: 20260726_001_phase3_import_concurrency_and_direct_type_alignment
Purpose: Add database-owned import serialization, digest-backed post-commit CSV archival, and align direct Phase 3 persisted contracts
Author: cwatts
CreatedUtc: 2026-07-26
RequiresBackup: Yes
RiskLevel: High
Rollback: Included
RollbackScript: migrations/rollback/20260726_001_phase3_import_concurrency_and_direct_type_alignment_rollback.sql
TransactionMode: Required
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: Existing rows in PlayerScanMeta, SUMMARY_PROC_STATE, and STAGING_STATS; representative counts 2371, 9, and 411
PreValidationQuery: Confirm Phase 2 source types and zero non-integral/out-of-range values in the three altered downstream tables
PostValidationQuery: Confirm target column metadata, receipt-table constraints, changed module compilation, and zero duplicate receipt scan orders
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety plan:
    - Deploy only after the Phase 2 migration has completed and its verification
      receipt is current.
    - Stop bot/import/admin writers and acquire the same migration mutex used by
      the Phase 2 package before changing downstream metadata or module definitions.
    - Preview every altered value and refuse non-integral or out-of-range data.
    - Preserve row counts; the migration changes storage metadata only.
    - Drop and recreate only the known PlayerScanMeta primary key required for
      its GovernorID type change.
    - Keep all work, including procedure definitions, in one transaction across
      SQL batches. A failed deployment connection rolls the open transaction back.
    - Rollback is allowed only before the new import receipt table contains rows.
      After a Phase 3 import commits, use a reviewed forward fix or restore decision.
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
    THROW 51900, 'Phase 3 migration could not acquire the KingdomScanData4 migration mutex within 60000 ms.', 1;

IF NOT EXISTS
   (
       SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
         AND name = N'GovernorID'
         AND system_type_id = TYPE_ID(N'bigint')
         AND user_type_id = TYPE_ID(N'bigint')
   )
   OR NOT EXISTS
   (
       SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
         AND name = N'SCANORDER'
         AND system_type_id = TYPE_ID(N'int')
         AND user_type_id = TYPE_ID(N'int')
   )
   OR NOT EXISTS
   (
       SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData5')
         AND name = N'GovernorID'
         AND system_type_id = TYPE_ID(N'bigint')
         AND user_type_id = TYPE_ID(N'bigint')
   )
   OR NOT EXISTS
   (
       SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData5')
         AND name = N'SCANORDER'
         AND system_type_id = TYPE_ID(N'int')
         AND user_type_id = TYPE_ID(N'int')
   )
   OR NOT EXISTS
   (
       SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.IMPORT_STAGING')
         AND name = N'Governor ID'
         AND system_type_id = TYPE_ID(N'bigint')
         AND user_type_id = TYPE_ID(N'bigint')
   )
   OR NOT EXISTS
   (
       SELECT 1 FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.IMPORT_STAGING')
         AND name = N'SCANORDER'
         AND system_type_id = TYPE_ID(N'int')
         AND user_type_id = TYPE_ID(N'int')
   )
    THROW 51901, 'Phase 3 requires the verified Phase 2 bigint/int source contracts.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.PlayerScanMeta
    WHERE GovernorID <> FLOOR(GovernorID)
       OR GovernorID < -9223372036854775808.0
       OR GovernorID > 9223372036854775807.0
       OR (FirstScanOrder IS NOT NULL AND
           (FirstScanOrder <> FLOOR(FirstScanOrder)
            OR FirstScanOrder < -2147483648.0
            OR FirstScanOrder > 2147483647.0))
       OR (LastScanOrder IS NOT NULL AND
           (LastScanOrder <> FLOOR(LastScanOrder)
            OR LastScanOrder < -2147483648.0
            OR LastScanOrder > 2147483647.0))
)
    THROW 51902, 'PlayerScanMeta contains values that cannot be converted exactly to the Phase 3 bigint/int contract.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.SUMMARY_PROC_STATE
    WHERE LastScanOrder IS NOT NULL
      AND
      (
          LastScanOrder <> FLOOR(LastScanOrder)
          OR LastScanOrder < -2147483648.0
          OR LastScanOrder > 2147483647.0
      )
)
    THROW 51903, 'SUMMARY_PROC_STATE contains values that cannot be converted exactly to int.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.STAGING_STATS
    WHERE GovernorID <> FLOOR(GovernorID)
       OR GovernorID < -9223372036854775808.0
       OR GovernorID > 9223372036854775807.0
       OR PowerRank <> FLOOR(PowerRank)
       OR PowerRank < -2147483648.0
       OR PowerRank > 2147483647.0
)
    THROW 51904, 'STAGING_STATS contains values that cannot be converted exactly to the Phase 3 bigint/int contract.', 1;

DECLARE @PlayerScanMetaRows bigint = (SELECT COUNT_BIG(*) FROM dbo.PlayerScanMeta);
DECLARE @SummaryStateRows bigint = (SELECT COUNT_BIG(*) FROM dbo.SUMMARY_PROC_STATE);
DECLARE @StagingStatsRows bigint = (SELECT COUNT_BIG(*) FROM dbo.STAGING_STATS);

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.KS4_ImportFileReceipt
    (
        FileDigest binary(32) NOT NULL,
        SourcePath nvarchar(4000) NOT NULL,
        ArchivePath nvarchar(4000) NOT NULL,
        ScanOrder int NOT NULL,
        ScanDate datetime NULL,
        [RowCount] int NOT NULL,
        DatabaseCommittedAtUtc datetime2(3) NOT NULL,
        ArchiveStatus nvarchar(20) NOT NULL,
        ArchivedAtUtc datetime2(3) NULL,
        LastArchiveError nvarchar(2000) NULL,
        CONSTRAINT PK_KS4_ImportFileReceipt
            PRIMARY KEY CLUSTERED (FileDigest),
        CONSTRAINT UQ_KS4_ImportFileReceipt_ScanOrder
            UNIQUE NONCLUSTERED (ScanOrder),
        CONSTRAINT CK_KS4_ImportFileReceipt_ArchiveStatus
            CHECK (ArchiveStatus IN (N'pending', N'archived'))
    );
END;

IF EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.PlayerScanMeta')
      AND name = N'GovernorID'
      AND system_type_id = TYPE_ID(N'float')
      AND user_type_id = TYPE_ID(N'float')
)
BEGIN
    IF OBJECT_ID(N'dbo.PK_PlayerScanMeta', N'PK') IS NOT NULL
        ALTER TABLE dbo.PlayerScanMeta DROP CONSTRAINT PK_PlayerScanMeta;

    ALTER TABLE dbo.PlayerScanMeta ALTER COLUMN GovernorID bigint NOT NULL;
    ALTER TABLE dbo.PlayerScanMeta ALTER COLUMN FirstScanOrder int NULL;
    ALTER TABLE dbo.PlayerScanMeta ALTER COLUMN LastScanOrder int NULL;

    ALTER TABLE dbo.PlayerScanMeta
        ADD CONSTRAINT PK_PlayerScanMeta
        PRIMARY KEY CLUSTERED (GovernorID)
        WITH
        (
            PAD_INDEX = OFF,
            STATISTICS_NORECOMPUTE = OFF,
            IGNORE_DUP_KEY = OFF,
            ALLOW_ROW_LOCKS = ON,
            ALLOW_PAGE_LOCKS = ON,
            OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
        );
END;

IF EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.SUMMARY_PROC_STATE')
      AND name = N'LastScanOrder'
      AND system_type_id = TYPE_ID(N'float')
      AND user_type_id = TYPE_ID(N'float')
)
    ALTER TABLE dbo.SUMMARY_PROC_STATE ALTER COLUMN LastScanOrder int NULL;

IF EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.STAGING_STATS')
      AND name = N'GovernorID'
      AND system_type_id = TYPE_ID(N'float')
      AND user_type_id = TYPE_ID(N'float')
)
    ALTER TABLE dbo.STAGING_STATS ALTER COLUMN GovernorID bigint NOT NULL;

IF EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.STAGING_STATS')
      AND name = N'PowerRank'
      AND system_type_id = TYPE_ID(N'float')
      AND user_type_id = TYPE_ID(N'float')
)
    ALTER TABLE dbo.STAGING_STATS ALTER COLUMN PowerRank int NOT NULL;

IF (SELECT COUNT_BIG(*) FROM dbo.PlayerScanMeta) <> @PlayerScanMetaRows
   OR (SELECT COUNT_BIG(*) FROM dbo.SUMMARY_PROC_STATE) <> @SummaryStateRows
   OR (SELECT COUNT_BIG(*) FROM dbo.STAGING_STATS) <> @StagingStatsRows
    THROW 51905, 'Phase 3 downstream type alignment changed an unexpected row count.', 1;
GO

IF DATABASE_PRINCIPAL_ID(N'K98ImportLockPrincipal') IS NULL
    CREATE ROLE K98ImportLockPrincipal AUTHORIZATION dbo;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[ACQUIRE_KS4_IMPORT_LOCK]
    @LockTimeout [int] = 60000,
    @LockResult [int] OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT = 0
        THROW 51870, 'ACQUIRE_KS4_IMPORT_LOCK requires an active caller transaction.', 1;

    IF @LockTimeout < 0 OR @LockTimeout > 60000
        THROW 51871, 'ACQUIRE_KS4_IMPORT_LOCK requires a timeout from 0 through 60000 ms.', 1;

    EXEC @LockResult = sys.sp_getapplock
        @Resource = N'K98:KingdomScanData4:ImportPipeline:v1',
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = @LockTimeout,
        @DbPrincipal = N'K98ImportLockPrincipal';
END
GO

DENY EXECUTE ON OBJECT::dbo.ACQUIRE_KS4_IMPORT_LOCK TO public;
GO

-- GENERATED PROCEDURE DEFINITIONS BEGIN
-- Source: sql_schema/dbo.HASH_KS4_IMPORT_ARCHIVE_FILE.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[HASH_KS4_IMPORT_ARCHIVE_FILE]
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
DENY EXECUTE ON OBJECT::dbo.HASH_KS4_IMPORT_ARCHIVE_FILE TO public;
GO
-- Source: sql_schema/dbo.ARCHIVE_IMPORT_STAGING_FILE.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[ARCHIVE_IMPORT_STAGING_FILE]
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
-- Source: sql_schema/dbo.IMPORT_STAGING_PROC_CORE.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC_CORE]
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
DENY EXECUTE ON OBJECT::dbo.IMPORT_STAGING_PROC_CORE TO public;
GO
-- Source: sql_schema/dbo.IMPORT_STAGING_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC]
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
-- Source: sql_schema/dbo.UPDATE_ALL.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[UPDATE_ALL]
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
-- Source: sql_schema/dbo.CREATE_DASH.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[CREATE_DASH]
WITH EXECUTE AS CALLER
AS
BEGIN

-- Clear target table
TRUNCATE TABLE DASH;

-- Step 1: Create #RankingGroups temp table
IF OBJECT_ID('tempdb..#RankingGroups') IS NOT NULL DROP TABLE #RankingGroups;

SELECT DISTINCT KVK_NO, RankGroup, KVK_Rank_Max
INTO #RankingGroups
FROM (
    SELECT KVK_NO, '50' AS RankGroup, 50 AS KVK_Rank_Max FROM EXCEL_FOR_DASHBOARD
    UNION ALL
    SELECT KVK_NO, '100', 100 FROM EXCEL_FOR_DASHBOARD
    UNION ALL
    SELECT KVK_NO, '150', 150 FROM EXCEL_FOR_DASHBOARD
) AS t;

-- Step 2: Create #Aggregated temp table
IF OBJECT_ID('tempdb..#Aggregated') IS NOT NULL DROP TABLE #Aggregated;

SELECT
    rg.RankGroup AS [RANK],
    rg.RankGroup AS [KVK_RANK],
    CASE rg.RankGroup
        WHEN '50' THEN '999999997'
        WHEN '100' THEN '999999998'
        WHEN '150' THEN '999999999'
    END AS [Gov_ID],
    CASE rg.RankGroup
        WHEN '50' THEN 'Top50'
        WHEN '100' THEN 'Top100'
        WHEN '150' THEN 'Kingdom Average'
    END AS [Governor_Name],
    ROUND(AVG([Starting POWER]), 0) AS [Starting Power],
    ROUND(AVG([T4_Kills]), 0) AS [T4_Kills],
    ROUND(AVG([T5_Kills]), 0) AS [T5_Kills],
    ROUND(AVG([T4&T5_Kills]), 0) AS [T4&T5_Kills],
    ROUND(AVG([Kill Target]), 0) AS [Kill Target],
    ROUND(AVG([% of Kill target]), 0) AS [% of Kill target],
    ROUND(AVG([Deads_Delta]), 0) AS [Deads],
    ROUND(AVG([T4_Deads]), 0) AS [T4_Deads],
    ROUND(AVG([T5_Deads]), 0) AS [T5_Deads],
    ROUND(AVG([Dead_Target]), 0) AS [Dead_Target],
    ROUND(AVG([% of Dead Target]), 0) AS [% of Dead_Target],
    ed.KVK_NO,
    ROUND(AVG([Pass 4 Kills]), 0) AS [Pass 4 Kills],
    ROUND(AVG([Pass 6 Kills]), 0) AS [Pass 6 Kills],
    ROUND(AVG([Pass 7 Kills]), 0) AS [Pass 7 Kills],
    ROUND(AVG([Pass 8 Kills]), 0) AS [Pass 8 Kills],
    ROUND(AVG([POWER_DELTA]), 0) AS [POWER_DELTA],
    ROUND(AVG([DKP_Score]), 0) AS [DKP_Score],
    ROUND(AVG([DKP Target]), 0) AS [DKP Target],
    ROUND(AVG([% of DKP Target]), 0) AS [% of DKP Target]
INTO #Aggregated
FROM #RankingGroups rg
JOIN EXCEL_FOR_DASHBOARD ed
    ON ed.KVK_NO = rg.KVK_NO
   AND ed.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
GROUP BY rg.RankGroup, ed.KVK_NO;

-- Step 3: Insert into DASH
INSERT INTO DASH (
    [RANK], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [T4_Kills], [T5_Kills], [T4&T5_Kills],
    [Kill Target], [% of Kill target], [Deads], [T4_Deads],
    [T5_Deads], [Dead_Target], [% of Dead_Target], [KVK_NO],
    [Pass 4 Kills], [Pass 6 Kills], [Pass 7 Kills], [Pass 8 Kills],
    [POWER_DELTA], [DKP_Score], [DKP Target], [% of DKP Target]
)
SELECT *
FROM #Aggregated;

-- Step 4: Insert into EXCEL_FOR_DASHBOARD from DASH
INSERT INTO EXCEL_FOR_DASHBOARD (
    [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [Power_Delta], [T4_KILLS], [T5_KILLS],
    [T4&T5_Kills], [Kill Target], [% of Kill target],
    [Deads_Delta], [T4_Deads], [T5_Deads], [Dead_Target],
    [% of Dead Target], [DKP_Score], [DKP Target],
    [% of DKP Target], [Pass 4 Kills], [Pass 6 Kills],
    [Pass 7 Kills], [Pass 8 Kills], [KVK_NO]
)
SELECT
    [RANK], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [POWER_DELTA], [T4_Kills], [T5_Kills],
    [T4&T5_Kills], [Kill Target], [% of Kill target],
    [Deads], [T4_Deads], [T5_Deads], [Dead_Target],
    [% of Dead_Target], [DKP_Score], [DKP Target],
    [% of DKP Target], [Pass 4 Kills], [Pass 6 Kills],
    [Pass 7 Kills], [Pass 8 Kills], [KVK_NO]
FROM DASH;

-- Cleanup temp tables
DROP TABLE IF EXISTS #RankingGroups;
DROP TABLE IF EXISTS #Aggregated;

 END;
GO
-- Source: sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[UPDATE_ALL2]
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
-- Source: sql_schema/dbo.CREATE_DELTA_TABLES.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[CREATE_DELTA_TABLES]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- ✅ Ensures transaction rolls back on any error

    DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @NewMaxScan INT = 0;

    -- For low-volume processing (500-2000/day), run maintenance weekly
    DECLARE @MaintenanceRowThreshold INT = 5000;
    DECLARE @MaintenanceHourThreshold INT = 168; -- 7 days

    ----------------------------------------------------------------
    -- Step 1: Determine what's already been processed
    ----------------------------------------------------------------
    DECLARE @LastProcessedScan INT;

    PRINT '----------------------------------------';
    PRINT 'Starting delta processing at ' + CONVERT(VARCHAR(30), @StartTime, 120);

	DECLARE @DeltaMetricsExists BIT = CASE WHEN OBJECT_ID(N'dbo.DeltaMetrics', N'U') IS NOT NULL THEN 1 ELSE 0 END;

    IF @DeltaMetricsExists = 0
    BEGIN
        RAISERROR('DeltaMetrics table missing. Run dbo.DeltaMetrics.Build.sql to create/backfill before executing CREATE_DELTA_TABLES.', 16, 1);
        RETURN;
    END


    -- Find the highest scan order we've already processed across all delta tables
    SELECT @LastProcessedScan = ISNULL(MAX(MaxDelta), 0)
    FROM (
        SELECT MAX(DeltaOrder) AS MaxDelta FROM dbo.DeltaMetrics
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM DeadsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HelpsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSASSISTDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSGatheredDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM POWERDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM KillPointsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HealedTroopsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RangedPointsDelta
    ) AS AllDeltas;

    -- ✅ Data integrity check: Verify all delta tables are in sync
    DECLARE @MinMaxDelta FLOAT, @MaxMaxDelta FLOAT;
    SELECT
        @MinMaxDelta = MIN(MaxDelta),
        @MaxMaxDelta = MAX(MaxDelta)
    FROM (
        SELECT MAX(DeltaOrder) AS MaxDelta FROM dbo.DeltaMetrics
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM DeadsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HelpsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSASSISTDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSGatheredDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM POWERDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM KillPointsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HealedTroopsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RangedPointsDelta
    ) AS AllDeltas;

    IF @MinMaxDelta <> @MaxMaxDelta
    BEGIN
        PRINT '❌ ERROR: Delta tables are out of sync!';
        PRINT '   Minimum MaxDeltaOrder: ' + CAST(@MinMaxDelta AS VARCHAR(20));
        PRINT '   Maximum MaxDeltaOrder: ' + CAST(@MaxMaxDelta AS VARCHAR(20));
        PRINT '';
        PRINT 'Detailed breakdown:';

		SELECT
            'DeltaMetrics' AS TableName,
            MAX(DeltaOrder) AS MaxDeltaOrder,
            COUNT(*) AS TotalRows
        FROM dbo.DeltaMetrics
        UNION ALL
        SELECT
            'T4T5KillDelta' AS TableName,
            MAX(DeltaOrder) AS MaxDeltaOrder,
            COUNT(*) AS TotalRows
        FROM T4T5KillDelta
        UNION ALL
        SELECT 'T4KillDelta', MAX(DeltaOrder), COUNT(*) FROM T4KillDelta
        UNION ALL
        SELECT 'T5KillDelta', MAX(DeltaOrder), COUNT(*) FROM T5KillDelta
        UNION ALL
        SELECT 'DeadsDelta', MAX(DeltaOrder), COUNT(*) FROM DeadsDelta
        UNION ALL
        SELECT 'HelpsDelta', MAX(DeltaOrder), COUNT(*) FROM HelpsDelta
        UNION ALL
        SELECT 'RSSASSISTDelta', MAX(DeltaOrder), COUNT(*) FROM RSSASSISTDelta
        UNION ALL
        SELECT 'RSSGatheredDelta', MAX(DeltaOrder), COUNT(*) FROM RSSGatheredDelta
        UNION ALL
        SELECT 'POWERDelta', MAX(DeltaOrder), COUNT(*) FROM POWERDelta
        UNION ALL
        SELECT 'KillPointsDelta', MAX(DeltaOrder), COUNT(*) FROM KillPointsDelta
        UNION ALL
        SELECT 'HealedTroopsDelta', MAX(DeltaOrder), COUNT(*) FROM HealedTroopsDelta
        UNION ALL
        SELECT 'RangedPointsDelta', MAX(DeltaOrder), COUNT(*) FROM RangedPointsDelta
        ORDER BY MaxDeltaOrder DESC;

        RAISERROR('Delta tables are out of sync. Please fix manually before proceeding.', 16, 1);
        RETURN;
    END

    IF @LastProcessedScan IS NULL SET @LastProcessedScan = 0;

    PRINT 'Last processed scan order: ' + CAST(@LastProcessedScan AS VARCHAR(20));

    ----------------------------------------------------------------
    -- Step 2: Build base data for NEW scans only
    ----------------------------------------------------------------
    SELECT
        GovernorID,
        SCANORDER,
        SUM(T4_Kills) AS T4_Kills,
        SUM(T5_Kills) AS T5_Kills,
        SUM([T4&T5_Kills]) AS T4T5_Kills,
        SUM([Power]) AS Power,
        SUM([KillPoints]) AS KillPoints,
        SUM([Deads]) AS Deads,
        SUM([Helps]) AS Helps,
        SUM([RSSAssistance]) AS RSSAssist,
        SUM([RSS_Gathered]) AS RSSGathered,
        SUM([HealedTroops]) AS HealedTroops,
        SUM([RangedPoints]) AS RangedPoints
    INTO #NewScans
    FROM dbo.kingdomscandata4
    WHERE SCANORDER > @LastProcessedScan
    GROUP BY GovernorID, SCANORDER;

    SELECT @RowsProcessed = COUNT(*) FROM #NewScans;
    SELECT @NewMaxScan = ISNULL(MAX(SCANORDER), @LastProcessedScan) FROM #NewScans;

    IF @RowsProcessed = 0
    BEGIN
        PRINT 'No new scans to process.';
        PRINT '----------------------------------------';
        DROP TABLE #NewScans;
        RETURN;
    END

    PRINT 'New scan orders found: ' + CAST(@LastProcessedScan AS VARCHAR(20)) + ' to ' + CAST(@NewMaxScan AS VARCHAR(20));
    PRINT 'Processing ' + CAST(@RowsProcessed AS VARCHAR(10)) + ' new scan records...';

    CREATE CLUSTERED INDEX IX_NewScans ON #NewScans (GovernorID, SCANORDER);

----------------------------------------------------------------
-- Step 3: Get ABSOLUTE VALUES at the last processed scan
----------------------------------------------------------------

PRINT 'Calculating absolute values at last processed scan...';

;WITH LastAbsoluteValues AS (
    SELECT
        GovernorID,
        SUM(T4KillsDelta) AS T4_Kills_Absolute,
        SUM(T5KillsDelta) AS T5_Kills_Absolute,
        SUM(T4T5KillsDelta) AS T4T5_Kills_Absolute,
        SUM(Power_Delta) AS Power_Absolute,
        SUM(KillPointsDelta) AS KillPoints_Absolute,
        SUM(DeadsDelta) AS Deads_Absolute,
        SUM(HelpsDelta) AS Helps_Absolute,
        SUM(RSSAssistDelta) AS RSSAssist_Absolute,
        SUM(RSSGatheredDelta) AS RSSGathered_Absolute,
        SUM(HealedTroopsDelta) AS HealedTroops_Absolute,
        SUM(RangedPointsDelta) AS RangedPoints_Absolute
    FROM dbo.DeltaMetrics dm
    WHERE dm.DeltaOrder <= @LastProcessedScan
    GROUP BY GovernorID
)
SELECT * INTO #LastAbsoluteValues FROM LastAbsoluteValues;

CREATE CLUSTERED INDEX IX_LastAbsolute ON #LastAbsoluteValues (GovernorID);

----------------------------------------------------------------
-- Step 4: Calculate deltas = CurrentValue - PreviousValue
----------------------------------------------------------------

PRINT 'Calculating deltas...';

;WITH AbsoluteValues AS (
    SELECT
        ns.GovernorID,
        ns.SCANORDER,
        ns.T4_Kills AS T4_Current,
        ns.T5_Kills AS T5_Current,
        ns.T4T5_Kills AS T4T5_Current,
        ns.Power AS Power_Current,
        ns.KillPoints AS KillPoints_Current,
        ns.Deads AS Deads_Current,
        ns.Helps AS Helps_Current,
        ns.RSSAssist AS RSSAssist_Current,
        ns.RSSGathered AS RSSGathered_Current,
        ns.HealedTroops AS HealedTroops_Current,
        ns.RangedPoints AS RangedPoints_Current
    FROM #NewScans ns
),
AbsoluteWithLag AS (
    SELECT
        GovernorID,
        SCANORDER,
        T4_Current,
        LAG(T4_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T4_Previous,
        T5_Current,
        LAG(T5_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T5_Previous,
        T4T5_Current,
        LAG(T4T5_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T4T5_Previous,
        Power_Current,
        LAG(Power_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Power_Previous,
        KillPoints_Current,
        LAG(KillPoints_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS KillPoints_Previous,
        Deads_Current,
        LAG(Deads_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Deads_Previous,
        Helps_Current,
        LAG(Helps_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Helps_Previous,
        RSSAssist_Current,
        LAG(RSSAssist_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RSSAssist_Previous,
        RSSGathered_Current,
        LAG(RSSGathered_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RSSGathered_Previous,
        HealedTroops_Current,
        LAG(HealedTroops_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS HealedTroops_Previous,
        RangedPoints_Current,
        LAG(RangedPoints_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RangedPoints_Previous
    FROM AbsoluteValues
),
DeltaCalculations AS (
    SELECT
        awl.GovernorID,
        awl.SCANORDER,
        CAST(ISNULL(awl.T4_Current - ISNULL(awl.T4_Previous, ISNULL(lav.T4_Kills_Absolute, 0)), awl.T4_Current) AS FLOAT) AS T4_Delta,
        CAST(ISNULL(awl.T5_Current - ISNULL(awl.T5_Previous, ISNULL(lav.T5_Kills_Absolute, 0)), awl.T5_Current) AS FLOAT) AS T5_Delta,
        CAST(ISNULL(awl.T4T5_Current - ISNULL(awl.T4T5_Previous, ISNULL(lav.T4T5_Kills_Absolute, 0)), awl.T4T5_Current) AS FLOAT) AS T4T5_Delta,
        CAST(ISNULL(awl.Power_Current - ISNULL(awl.Power_Previous, ISNULL(lav.Power_Absolute, 0)), awl.Power_Current) AS FLOAT) AS Power_Delta,
        CAST(ISNULL(awl.KillPoints_Current - ISNULL(awl.KillPoints_Previous, ISNULL(lav.KillPoints_Absolute, 0)), awl.KillPoints_Current) AS BIGINT) AS KillPoints_Delta,
        CAST(ISNULL(awl.Deads_Current - ISNULL(awl.Deads_Previous, ISNULL(lav.Deads_Absolute, 0)), awl.Deads_Current) AS FLOAT) AS Deads_Delta,
        CAST(ISNULL(awl.Helps_Current - ISNULL(awl.Helps_Previous, ISNULL(lav.Helps_Absolute, 0)), awl.Helps_Current) AS FLOAT) AS Helps_Delta,
        CAST(ISNULL(awl.RSSAssist_Current - ISNULL(awl.RSSAssist_Previous, ISNULL(lav.RSSAssist_Absolute, 0)), awl.RSSAssist_Current) AS FLOAT) AS RSSAssist_Delta,
        CAST(ISNULL(awl.RSSGathered_Current - ISNULL(awl.RSSGathered_Previous, ISNULL(lav.RSSGathered_Absolute, 0)), awl.RSSGathered_Current) AS FLOAT) AS RSSGathered_Delta,
        CAST(ISNULL(awl.HealedTroops_Current - ISNULL(awl.HealedTroops_Previous, ISNULL(lav.HealedTroops_Absolute, 0)), awl.HealedTroops_Current) AS BIGINT) AS HealedTroops_Delta,
        CAST(ISNULL(awl.RangedPoints_Current - ISNULL(awl.RangedPoints_Previous, ISNULL(lav.RangedPoints_Absolute, 0)), awl.RangedPoints_Current) AS BIGINT) AS RangedPoints_Delta
    FROM AbsoluteWithLag awl
    LEFT JOIN #LastAbsoluteValues lav ON awl.GovernorID = lav.GovernorID
)
SELECT * INTO #DeltaCalculations FROM DeltaCalculations;

    ----------------------------------------------------------------
    -- Step 5: INSERT with TRANSACTION (all-or-nothing)
    ----------------------------------------------------------------

    PRINT 'Inserting deltas into tables (transactional)...';

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @InsertedRows INT;

        INSERT INTO T4KillDelta (GovernorID, DeltaOrder, T4KILLSDelta)
        SELECT GovernorID, SCANORDER, T4_Delta FROM #DeltaCalculations;
        SET @InsertedRows = @@ROWCOUNT;
        PRINT '  T4KillDelta: ' + CAST(@InsertedRows AS VARCHAR(10)) + ' rows';

        INSERT INTO T5KillDelta (GovernorID, DeltaOrder, T5KILLSDelta)
        SELECT GovernorID, SCANORDER, T5_Delta FROM #DeltaCalculations;
        PRINT '  T5KillDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO T4T5KillDelta (GovernorID, DeltaOrder, [T4&T5_KILLSDelta])
        SELECT GovernorID, SCANORDER, T4T5_Delta FROM #DeltaCalculations;
        PRINT '  T4T5KillDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO POWERDelta (GovernorID, DeltaOrder, [Power_Delta])
        SELECT GovernorID, SCANORDER, Power_Delta FROM #DeltaCalculations;
        PRINT '  POWERDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO KillPointsDelta (GovernorID, DeltaOrder, KillPointsDelta)
        SELECT GovernorID, SCANORDER, KillPoints_Delta FROM #DeltaCalculations;
        PRINT '  KillPointsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO DeadsDelta (GovernorID, DeltaOrder, DeadsDelta)
        SELECT GovernorID, SCANORDER, Deads_Delta FROM #DeltaCalculations;
        PRINT '  DeadsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO HelpsDelta (GovernorID, DeltaOrder, HelpsDelta)
        SELECT GovernorID, SCANORDER, Helps_Delta FROM #DeltaCalculations;
        PRINT '  HelpsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO RSSASSISTDelta (GovernorID, DeltaOrder, RSSAssistDelta)
        SELECT GovernorID, SCANORDER, RSSAssist_Delta FROM #DeltaCalculations;
        PRINT '  RSSASSISTDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO RSSGatheredDelta (GovernorID, DeltaOrder, RSSGatheredDelta)
        SELECT GovernorID, SCANORDER, RSSGathered_Delta FROM #DeltaCalculations;
        PRINT '  RSSGatheredDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO HealedTroopsDelta (GovernorID, DeltaOrder, HealedTroopsDelta)
        SELECT GovernorID, SCANORDER, HealedTroops_Delta FROM #DeltaCalculations;
        PRINT '  HealedTroopsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO RangedPointsDelta (GovernorID, DeltaOrder, RangedPointsDelta)
        SELECT GovernorID, SCANORDER, RangedPoints_Delta FROM #DeltaCalculations;
        PRINT '  RangedPointsDelta: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        INSERT INTO dbo.DeltaMetrics (
            DeltaOrder,
            GovernorID,
            T4KillsDelta,
            T5KillsDelta,
            T4T5KillsDelta,
            Power_Delta,
            KillPointsDelta,
            DeadsDelta,
            HelpsDelta,
            RSSAssistDelta,
            RSSGatheredDelta,
            HealedTroopsDelta,
            RangedPointsDelta
        )
        SELECT
            SCANORDER,
            GovernorID,
            T4_Delta,
            T5_Delta,
            T4T5_Delta,
            Power_Delta,
            KillPoints_Delta,
            Deads_Delta,
            Helps_Delta,
            RSSAssist_Delta,
            RSSGathered_Delta,
            HealedTroops_Delta,
            RangedPoints_Delta
        FROM #DeltaCalculations DC
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.DeltaMetrics dm
            WHERE dm.DeltaOrder = DC.SCANORDER
              AND dm.GovernorID = DC.GovernorID
        );
        PRINT '  DeltaMetrics: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

        COMMIT TRANSACTION;
        PRINT '✅ All delta inserts committed successfully.';

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        PRINT '❌ ERROR: Transaction rolled back!';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));

        -- Cleanup
        DROP TABLE #NewScans;
        DROP TABLE #LastAbsoluteValues;
        DROP TABLE #DeltaCalculations;

        RETURN;
    END CATCH

    -- Cleanup temp tables
    DROP TABLE #NewScans;
    DROP TABLE #LastAbsoluteValues;
    DROP TABLE #DeltaCalculations;

    ----------------------------------------------------------------
    -- Step 6: LIGHTWEIGHT MAINTENANCE
    ----------------------------------------------------------------

    DECLARE @ShouldRunMaintenance BIT = 0;
    DECLARE @LastMaintenanceTime DATETIME2;
    DECLARE @TotalRowsSinceLastMaintenance INT;

    IF OBJECT_ID('dbo.DeltaProcessingLog', 'U') IS NOT NULL
    BEGIN
        SELECT TOP 1
            @LastMaintenanceTime = ExecutionTime,
            @TotalRowsSinceLastMaintenance =
                (SELECT SUM(RowsProcessed)
                 FROM dbo.DeltaProcessingLog
                 WHERE ExecutionTime > ISNULL((SELECT TOP 1 ExecutionTime
                                               FROM dbo.DeltaProcessingLog
                                               WHERE MaintenanceRan = 1
                                               ORDER BY ExecutionTime DESC), '1900-01-01'))
        FROM dbo.DeltaProcessingLog
        WHERE MaintenanceRan = 1
        ORDER BY ExecutionTime DESC;

        IF @LastMaintenanceTime IS NULL
            OR DATEDIFF(HOUR, @LastMaintenanceTime, SYSUTCDATETIME()) >= @MaintenanceHourThreshold
            OR @TotalRowsSinceLastMaintenance >= @MaintenanceRowThreshold
        BEGIN
            SET @ShouldRunMaintenance = 1;
        END
    END
    ELSE
    BEGIN
        IF @RowsProcessed >= @MaintenanceRowThreshold
            SET @ShouldRunMaintenance = 1;
    END

    IF @ShouldRunMaintenance = 1
    BEGIN
        PRINT 'Running weekly maintenance...';
        PRINT 'Days since last maintenance: ' + CAST(DATEDIFF(DAY, ISNULL(@LastMaintenanceTime, '1900-01-01'), SYSUTCDATETIME()) AS VARCHAR(10));
        PRINT 'Rows since last maintenance: ' + CAST(ISNULL(@TotalRowsSinceLastMaintenance, @RowsProcessed) AS VARCHAR(10));

        UPDATE STATISTICS T4KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS T5KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS T4T5KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS POWERDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS KillPointsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS DeadsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS HelpsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RSSASSISTDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RSSGatheredDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS HealedTroopsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RangedPointsDelta WITH SAMPLE 25 PERCENT;
		UPDATE STATISTICS DeltaMetrics WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS dbo.kingdomscandata4 WITH SAMPLE 25 PERCENT;

        PRINT 'Statistics updated (25% sample).';

        -- Index maintenance code (same as before)
        DECLARE @TableName NVARCHAR(128);
        DECLARE @IndexName NVARCHAR(128);
        DECLARE @Fragmentation FLOAT;
        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @IndexesChecked INT = 0;
        DECLARE @IndexesMaintained INT = 0;

        CREATE TABLE #IndexFragmentation (
            TableName NVARCHAR(128),
            IndexName NVARCHAR(128),
            FragmentationPercent FLOAT,
            PageCount BIGINT
        );

        INSERT INTO #IndexFragmentation
        SELECT
            OBJECT_NAME(ips.object_id) AS TableName,
            i.name AS IndexName,
            ips.avg_fragmentation_in_percent AS FragmentationPercent,
            ips.page_count AS PageCount
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE OBJECT_NAME(ips.object_id) IN (
            'T4KillDelta', 'T5KillDelta', 'T4T5KillDelta', 'POWERDelta',
            'KillPointsDelta', 'DeadsDelta', 'HelpsDelta', 'RSSASSISTDelta',
            'RSSGatheredDelta', 'HealedTroopsDelta', 'RangedPointsDelta',
			'DeltaMetrics', 'kingdomscandata4'
        )
        AND i.name IS NOT NULL
        AND ips.page_count > 1000;

        SELECT @IndexesChecked = COUNT(*) FROM #IndexFragmentation;

        DECLARE index_cursor CURSOR FOR
        SELECT TableName, IndexName, FragmentationPercent
        FROM #IndexFragmentation
        WHERE FragmentationPercent > 15
        ORDER BY FragmentationPercent DESC;

        OPEN index_cursor;
        FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @Fragmentation;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @Fragmentation > 50
            BEGIN
                SET @SQL = N'ALTER INDEX [' + @IndexName + N'] ON [dbo].[' + @TableName + N'] REBUILD WITH (ONLINE = OFF, SORT_IN_TEMPDB = ON, MAXDOP = 2);';
                PRINT 'Rebuilding: ' + @IndexName + ' on ' + @TableName + ' (' + CAST(CAST(@Fragmentation AS DECIMAL(5,2)) AS VARCHAR(10)) + '% fragmented)';
            END
            ELSE
            BEGIN
                SET @SQL = N'ALTER INDEX [' + @IndexName + N'] ON [dbo].[' + @TableName + N'] REORGANIZE;';
                PRINT 'Reorganizing: ' + @IndexName + ' on ' + @TableName + ' (' + CAST(CAST(@Fragmentation AS DECIMAL(5,2)) AS VARCHAR(10)) + '% fragmented)';
            END

            BEGIN TRY
                EXEC sp_executesql @SQL;
                SET @IndexesMaintained = @IndexesMaintained + 1;
            END TRY
            BEGIN CATCH
                PRINT 'Warning: Index maintenance failed for ' + @IndexName + ' - ' + ERROR_MESSAGE();
            END CATCH

            FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @Fragmentation;
        END

        CLOSE index_cursor;
        DEALLOCATE index_cursor;
        DROP TABLE #IndexFragmentation;

        PRINT 'Index maintenance: ' + CAST(@IndexesMaintained AS VARCHAR(10)) + ' of ' + CAST(@IndexesChecked AS VARCHAR(10)) + ' indexes maintained.';
    END
    ELSE
    BEGIN
        PRINT 'Skipping maintenance - next scheduled in ' +
              CAST(@MaintenanceHourThreshold - DATEDIFF(HOUR, ISNULL(@LastMaintenanceTime, SYSUTCDATETIME()), SYSUTCDATETIME()) AS VARCHAR(10)) +
              ' hours or after ' +
              CAST(@MaintenanceRowThreshold - ISNULL(@TotalRowsSinceLastMaintenance, 0) AS VARCHAR(10)) +
              ' more rows.';
    END

    ----------------------------------------------------------------
    -- Step 7: Performance Logging
    ----------------------------------------------------------------
    DECLARE @ElapsedMS INT = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME());

    IF OBJECT_ID('dbo.DeltaProcessingLog', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.DeltaProcessingLog (RowsProcessed, LastScanProcessed, ElapsedMS, MaintenanceRan, Notes)
        VALUES (
            @RowsProcessed,
            @NewMaxScan,
            @ElapsedMS,
            @ShouldRunMaintenance,
            CASE
                WHEN @ShouldRunMaintenance = 1 THEN 'Weekly maintenance completed'
                ELSE 'Incremental processing (no maintenance)'
            END
        );
    END

    PRINT '----------------------------------------';
    PRINT '✅ Processing completed in ' + CAST(@ElapsedMS AS VARCHAR(10)) + 'ms';
    PRINT 'Rows processed: ' + CAST(@RowsProcessed AS VARCHAR(10));
    IF @RowsProcessed > 0
        PRINT 'Performance: ' + CAST(CAST(@ElapsedMS * 1.0 / @RowsProcessed AS DECIMAL(10,2)) AS VARCHAR(10)) + ' ms/row';
    PRINT 'New maximum scan order: ' + CAST(@NewMaxScan AS VARCHAR(20));
    PRINT '----------------------------------------';

    SET NOCOUNT OFF;
END
GO
-- Source: sql_schema/dbo.DEADSSUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[DEADSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'Deads';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.Deads
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE d
    FROM dbo.DALL d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.DALL (GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE d
    FROM dbo.D12 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.D12 (GovernorID, Deads, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, Deads, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12;

    DELETE d
    FROM dbo.D6 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.D6 (GovernorID, Deads, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, Deads, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6;

    DELETE d
    FROM dbo.D3 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.D3 (GovernorID, Deads, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, Deads, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.Deads
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, Deads = src.Deads
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.Deads);

    DELETE d
    FROM dbo.D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D3D (GovernorID, DeadsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.Deads END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN dbo.D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D6D (GovernorID, DeadsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.Deads END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN dbo.D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D12D (GovernorID, DeadsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.Deads END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.Deads END)
    FROM dbo.LATEST L
    LEFT JOIN dbo.D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT d.GovernorID,
               MAX(CASE WHEN d.RowAscALL = 1 THEN d.Deads END) AS StartingDeads,
               MAX(CASE WHEN d.RowDescALL = 1 THEN d.Deads END) AS EndingDeads
        FROM dbo.DALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
        GROUP BY d.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.Deads,
            F.StartingDeads,
            F.EndingDeads - F.StartingDeads AS OverallDeadsDelta,
            ISNULL(D12D.DeadsDelta12Months, 0) AS DeadsDelta12Months,
            ISNULL(D6D.DeadsDelta6Months, 0) AS DeadsDelta6Months,
            ISNULL(D3D.DeadsDelta3Months, 0) AS DeadsDelta3Months
        FROM dbo.LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.D12D D12D ON L.GovernorID = D12D.GovernorID
        LEFT JOIN dbo.D6D D6D ON L.GovernorID = D6D.GovernorID
        LEFT JOIN dbo.D3D D3D ON L.GovernorID = D3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.DEADSSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            Deads = S.Deads,
            StartingDeads = S.StartingDeads,
            OverallDeadsDelta = S.OverallDeadsDelta,
            DeadsDelta12Months = S.DeadsDelta12Months,
            DeadsDelta6Months = S.DeadsDelta6Months,
            DeadsDelta3Months = S.DeadsDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.Deads, S.StartingDeads, S.OverallDeadsDelta, S.DeadsDelta12Months, S.DeadsDelta6Months, S.DeadsDelta3Months);

    DELETE FROM dbo.DEADSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 50
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 100
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(D.Deads), 0),
           ROUND(AVG(D.StartingDeads), 0),
           ROUND(AVG(D.OverallDeadsDelta), 0),
           ROUND(AVG(D.DeadsDelta12Months), 0),
           ROUND(AVG(D.DeadsDelta6Months), 0),
           ROUND(AVG(D.DeadsDelta3Months), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 150
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END
GO
-- Source: sql_schema/dbo.FIX_IMPORT_STAGING.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[FIX_IMPORT_STAGING]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

IF @@TRANCOUNT <> 0
    THROW 51833, 'FIX_IMPORT_STAGING refuses caller-owned transactions; execute the public entry point with no active transaction.', 1;

SET XACT_ABORT ON;

DECLARE @DT DATETIME;
DECLARE @ImportLockResult INT;
DECLARE @CurrentMaxScanOrder INT;
DECLARE @NextScanOrder INT;

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
        @LockTimeout = 60000,
        @LockResult = @ImportLockResult OUTPUT;

    IF @ImportLockResult < 0
        THROW 51830, 'FIX_IMPORT_STAGING could not acquire the KingdomScanData4 import mutex within 60000 ms; staging was not changed.', 1;

-- Set the variable using SELECT
SELECT @DT = CONVERT(DATETIME,
    STUFF(STUFF(SUBSTRING(Updated_on, 1, 7), 3, 0, '-'), 7, 0, '-') + ' ' +
    REPLACE(REPLACE(SUBSTRING(Updated_on, 9, LEN(Updated_on) - 8), 'h', ':'), 'm', '')
)
FROM IMPORT_STAGING;

UPDATE IMPORT_STAGING --
--SET SCANDATE = @CurrentDate
SET SCANDATE = @DT

SELECT [Governor ID],
 SUM([T4-Kills] + [T5-Kills]) AS [Kills (T4+)],
 SUM([T1-Kills]+[T2-KILLS]+[T3-KILLS]+[T4-Kills]+[T5-Kills]) AS KILLS
 INTO #Killsum
FROM IMPORT_STAGING
GROUP BY [Governor ID]

UPDATE IMPORT_STAGING
SET IMPORT_STAGING.[Kills (T4+)] = KS.[Kills (T4+)],
 IMPORT_STAGING.KILLS = KS.KILLS
FROM IMPORT_STAGING
JOIN #Killsum AS KS ON  IMPORT_STAGING.[Governor ID] = KS.[Governor ID]

DROP TABLE #killsum


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
    THROW 51831, 'Import SCANORDER exhausted the int range; allocation refused.', 1;

SET @NextScanOrder = @CurrentMaxScanOrder + 1;

UPDATE IMPORT_STAGING
SET SCANORDER = @NextScanOrder;

IF EXISTS
(
    SELECT 1
    FROM dbo.IMPORT_STAGING
    GROUP BY SCANORDER, [Governor ID]
    HAVING COUNT_BIG(*) > 1
)
    THROW 51832, 'FIX_IMPORT_STAGING rejected duplicate (SCANORDER, Governor ID) keys.', 1;


UPDATE IMPORT_STAGING -- FIX ALLIANCE SCAN NAME
SET ALLIANCE = '[k98A]SparTanS'
WHERE ALLIANCE = '[k98A]SparTanS$S'

UPDATE IMPORT_STAGING -- FIX ALLIANCE SCAN NAME
SET ALLIANCE = '[K98B]TrojanS'
WHERE ALLIANCE = '[K98B]Trojan$S';



---FIX SCAN ISSUES---
-- Step 1: Precompute latest scan data
WITH LatestScan AS (
    SELECT *
    FROM KingdomScanData4
    WHERE SCANORDER = (SELECT MAX(SCANORDER) FROM KingdomScanData4)
)

-- Step 2: Update all fields in one go
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
FROM IMPORT_STAGING AS I
JOIN LatestScan AS K ON I.[Governor ID] = K.GovernorID;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
END;
GO
-- Source: sql_schema/dbo.HEALEDSUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'HealedTroops';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    /* Optional independent mode */
    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE d
    FROM dbo.HEALED_ALL d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE d
    FROM dbo.HEALED_D12 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12;

    DELETE d
    FROM dbo.HEALED_D6 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6;

    DELETE d
    FROM dbo.HEALED_D3 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.HEALED_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.HealedTroops
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, HealedTroops = src.HealedTroops
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, HealedTroops)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.HealedTroops);

    DELETE d
    FROM dbo.HEALED_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D3D (GovernorID, HealedTroopsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.HealedTroops END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.HealedTroops END)
    FROM dbo.HEALED_LATEST L
    LEFT JOIN dbo.HEALED_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.HEALED_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D6D (GovernorID, HealedTroopsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.HealedTroops END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.HealedTroops END)
    FROM dbo.HEALED_LATEST L
    LEFT JOIN dbo.HEALED_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.HEALED_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D12D (GovernorID, HealedTroopsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.HealedTroops END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.HealedTroops END)
    FROM dbo.HEALED_LATEST L
    LEFT JOIN dbo.HEALED_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT d.GovernorID,
               MAX(CASE WHEN d.RowAscALL = 1 THEN d.HealedTroops END) AS StartingHealed,
               MAX(CASE WHEN d.RowDescALL = 1 THEN d.HealedTroops END) AS EndingHealed
        FROM dbo.HEALED_ALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
        GROUP BY d.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.HealedTroops,
            F.StartingHealed,
            F.EndingHealed - F.StartingHealed AS OverallHealedDelta,
            ISNULL(D12D.HealedTroopsDelta12Months, 0) AS HealedDelta12Months,
            ISNULL(D6D.HealedTroopsDelta6Months, 0) AS HealedDelta6Months,
            ISNULL(D3D.HealedTroopsDelta3Months, 0) AS HealedDelta3Months
        FROM dbo.HEALED_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.HEALED_D12D D12D ON L.GovernorID = D12D.GovernorID
        LEFT JOIN dbo.HEALED_D6D D6D ON L.GovernorID = D6D.GovernorID
        LEFT JOIN dbo.HEALED_D3D D3D ON L.GovernorID = D3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.HEALEDSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            HealedTroops = S.HealedTroops,
            StartingHealed = S.StartingHealed,
            OverallHealedDelta = S.OverallHealedDelta,
            HealedDelta12Months = S.HealedDelta12Months,
            HealedDelta6Months = S.HealedDelta6Months,
            HealedDelta3Months = S.HealedDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.HealedTroops, S.StartingHealed, S.OverallHealedDelta, S.HealedDelta12Months, S.HealedDelta6Months, S.HealedDelta3Months);

    DELETE FROM dbo.HEALEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(H.HealedTroops), 0),
           ROUND(AVG(H.StartingHealed), 0),
           ROUND(AVG(H.OverallHealedDelta), 0),
           ROUND(AVG(H.HealedDelta12Months), 0),
           ROUND(AVG(H.HealedDelta6Months), 0),
           ROUND(AVG(H.HealedDelta3Months), 0)
    FROM dbo.HEALEDSUMMARY AS H
    WHERE H.PowerRank <= 50
      AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(H.HealedTroops), 0),
           ROUND(AVG(H.StartingHealed), 0),
           ROUND(AVG(H.OverallHealedDelta), 0),
           ROUND(AVG(H.HealedDelta12Months), 0),
           ROUND(AVG(H.HealedDelta6Months), 0),
           ROUND(AVG(H.HealedDelta3Months), 0)
    FROM dbo.HEALEDSUMMARY AS H
    WHERE H.PowerRank <= 100
      AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(H.HealedTroops), 0),
           ROUND(AVG(H.StartingHealed), 0),
           ROUND(AVG(H.OverallHealedDelta), 0),
           ROUND(AVG(H.HealedDelta12Months), 0),
           ROUND(AVG(H.HealedDelta6Months), 0),
           ROUND(AVG(H.HealedDelta3Months), 0)
    FROM dbo.HEALEDSUMMARY AS H
    WHERE H.PowerRank <= 150
      AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END
GO
-- Source: sql_schema/dbo.HEALEDSUMMARY_PROC_OPT.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC_OPT]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'HealedTroops';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    SELECT @LastProcessed = LastScanOrder
    FROM dbo.SUMMARY_PROC_STATE
    WHERE MetricName = @MetricName;

    IF @LastProcessed IS NULL SET @LastProcessed = 0;

    SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
    FROM dbo.KingdomScanData4;

    IF @MaxScan <= @LastProcessed
    BEGIN
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        ------------------------------------------------------------
        -- Affected governors (typed as BIGINT to avoid implicit conversions)
        ------------------------------------------------------------
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime) VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

            COMMIT;
            RETURN;
        END

        DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
        DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
        DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
        DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

        ------------------------------------------------------------
        -- #GovScan with explicit types (avoid implicit conversions)
        ------------------------------------------------------------
        CREATE TABLE #GovScan
        (
            GovernorID   BIGINT       NOT NULL,
            GovernorName NVARCHAR(400) NULL,
            PowerRank    INT           NULL,
            ScanOrder    INT           NOT NULL,
            ScanDate     DATETIME      NULL,
            HealedTroops BIGINT        NULL
        );

        INSERT INTO #GovScan (GovernorID, GovernorName, PowerRank, ScanOrder, ScanDate, HealedTroops)
        SELECT
            ks4.GovernorID,
            CONVERT(NVARCHAR(400), ks4.GovernorName) AS GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        ------------------------------------------------------------
        -- 1) HEALED_ALL: Delete and rebuild for affected governors
        ------------------------------------------------------------
        DELETE d
        FROM dbo.HEALED_ALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedAll AS (
            SELECT
                g.GovernorID,
                g.GovernorName,
                g.HealedTroops,
                g.ScanDate,
                ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
                ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
            FROM #GovScan g
        )
        INSERT INTO dbo.HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL
        FROM RankedAll;

        ------------------------------------------------------------
        -- Remaining sections unchanged (D12/D6/D3/etc.)
        ------------------------------------------------------------
        DELETE d
        FROM dbo.HEALED_D12 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD12 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc12,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc12
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff12
        )
        INSERT INTO dbo.HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12
        FROM RankedD12;

        DELETE d
        FROM dbo.HEALED_D6 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD6 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc6,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc6
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff6
        )
        INSERT INTO dbo.HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6
        FROM RankedD6;

        DELETE d
        FROM dbo.HEALED_D3 d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        ;WITH RankedD3 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc3,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc3
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff3
        )
        INSERT INTO dbo.HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3
        FROM RankedD3;

        ;WITH LatestScanOrder AS (
            SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
            FROM #GovScan g
            GROUP BY g.GovernorID
        )
        MERGE dbo.HEALED_LATEST AS tgt
        USING (
            SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.HealedTroops
            FROM #GovScan g
            INNER JOIN LatestScanOrder l
                ON l.GovernorID = g.GovernorID
               AND l.LatestScanOrder = g.ScanOrder
        ) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, HealedTroops = src.HealedTroops
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, HealedTroops)
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.HealedTroops);

        DELETE d
        FROM dbo.HEALED_D3D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D3D (GovernorID, HealedTroopsDelta3Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.HealedTroops END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D3 D3 ON L.GovernorID = D3.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.HEALED_D6D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D6D (GovernorID, HealedTroopsDelta6Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.HealedTroops END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D6 D6 ON L.GovernorID = D6.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.HEALED_D12D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D12D (GovernorID, HealedTroopsDelta12Months)
        SELECT L.GovernorID,
               MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.HealedTroops END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.HealedTroops END)
        FROM dbo.HEALED_LATEST L
        LEFT JOIN dbo.HEALED_D12 D12 ON L.GovernorID = D12.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT d.GovernorID,
                   MAX(CASE WHEN d.RowAscALL = 1 THEN d.HealedTroops END) AS StartingHealed,
                   MAX(CASE WHEN d.RowDescALL = 1 THEN d.HealedTroops END) AS EndingHealed
            FROM dbo.HEALED_ALL d
            INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
            GROUP BY d.GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.HealedTroops,
                F.StartingHealed,
                F.EndingHealed - F.StartingHealed AS OverallHealedDelta,
                ISNULL(D12D.HealedTroopsDelta12Months, 0) AS HealedDelta12Months,
                ISNULL(D6D.HealedTroopsDelta6Months, 0) AS HealedDelta6Months,
                ISNULL(D3D.HealedTroopsDelta3Months, 0) AS HealedDelta3Months
            FROM dbo.HEALED_LATEST L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.HEALED_D12D D12D ON L.GovernorID = D12D.GovernorID
            LEFT JOIN dbo.HEALED_D6D D6D ON L.GovernorID = D6D.GovernorID
            LEFT JOIN dbo.HEALED_D3D D3D ON L.GovernorID = D3D.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.HEALEDSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                HealedTroops = S.HealedTroops,
                StartingHealed = S.StartingHealed,
                OverallHealedDelta = S.OverallHealedDelta,
                HealedDelta12Months = S.HealedDelta12Months,
                HealedDelta6Months = S.HealedDelta6Months,
                HealedDelta3Months = S.HealedDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.HealedTroops, S.StartingHealed, S.OverallHealedDelta, S.HealedDelta12Months, S.HealedDelta6Months, S.HealedDelta3Months);

        DELETE FROM dbo.HEALEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999997, 'Top50', 50,
               ROUND(AVG(H.HealedTroops), 0),
               ROUND(AVG(H.StartingHealed), 0),
               ROUND(AVG(H.OverallHealedDelta), 0),
               ROUND(AVG(H.HealedDelta12Months), 0),
               ROUND(AVG(H.HealedDelta6Months), 0),
               ROUND(AVG(H.HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 50
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999998, 'Top100', 100,
               ROUND(AVG(H.HealedTroops), 0),
               ROUND(AVG(H.StartingHealed), 0),
               ROUND(AVG(H.OverallHealedDelta), 0),
               ROUND(AVG(H.HealedDelta12Months), 0),
               ROUND(AVG(H.HealedDelta6Months), 0),
               ROUND(AVG(H.HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 100
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999999, 'Kingdom Average', 150,
               ROUND(AVG(H.HealedTroops), 0),
               ROUND(AVG(H.StartingHealed), 0),
               ROUND(AVG(H.OverallHealedDelta), 0),
               ROUND(AVG(H.HealedDelta12Months), 0),
               ROUND(AVG(H.HealedDelta6Months), 0),
               ROUND(AVG(H.HealedDelta3Months), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 150
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

        MERGE dbo.SUMMARY_PROC_STATE AS T
        USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
        ON T.MetricName = S.MetricName
        WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
        WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime) VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR('HEALEDSUMMARY_PROC_OPT failed: %s', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END
GO
-- Source: sql_schema/dbo.KILLPOINTSSUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[KILLPOINTSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'KillPoints';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.KillPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE kp
    FROM dbo.KILLPOINTS_ALL kp
    INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.KILLPOINTS_ALL (GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE kp
    FROM dbo.KILLPOINTS_D12 kp
    INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.KILLPOINTS_D12 (GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12;

    DELETE kp
    FROM dbo.KILLPOINTS_D6 kp
    INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID;

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.KILLPOINTS_D6 (GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6;

    DELETE kp
    FROM dbo.KILLPOINTS_D3 kp
    INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID;

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.KILLPOINTS_D3 (GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.KILLPOINTS_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.KillPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, KillPoints = src.KillPoints
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, KillPoints)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.KillPoints);

    DELETE d
    FROM dbo.KILLPOINTS_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D3D (GovernorID, KillPointsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.KillPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN dbo.KILLPOINTS_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.KILLPOINTS_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D6D (GovernorID, KillPointsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.KillPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN dbo.KILLPOINTS_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.KILLPOINTS_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D12D (GovernorID, KillPointsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.KillPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.KillPoints END)
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN dbo.KILLPOINTS_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT kp.GovernorID,
               MAX(CASE WHEN kp.RowAscALL = 1 THEN kp.KillPoints END) AS StartingKillPoints,
               MAX(CASE WHEN kp.RowDescALL = 1 THEN kp.KillPoints END) AS EndingKillPoints
        FROM dbo.KILLPOINTS_ALL kp
        INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID
        GROUP BY kp.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.KillPoints,
            F.StartingKillPoints,
            F.EndingKillPoints - F.StartingKillPoints AS OverallKillPointsDelta,
            ISNULL(D12D.KillPointsDelta12Months, 0) AS KillPointsDelta12Months,
            ISNULL(D6D.KillPointsDelta6Months, 0) AS KillPointsDelta6Months,
            ISNULL(D3D.KillPointsDelta3Months, 0) AS KillPointsDelta3Months
        FROM dbo.KILLPOINTS_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.KILLPOINTS_D12D D12D ON L.GovernorID = D12D.GovernorID
        LEFT JOIN dbo.KILLPOINTS_D6D D6D ON L.GovernorID = D6D.GovernorID
        LEFT JOIN dbo.KILLPOINTS_D3D D3D ON L.GovernorID = D3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.KILLPOINTSSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            KillPoints = S.KillPoints,
            StartingKillPoints = S.StartingKillPoints,
            OverallKillPointsDelta = S.OverallKillPointsDelta,
            KillPointsDelta12Months = S.KillPointsDelta12Months,
            KillPointsDelta6Months = S.KillPointsDelta6Months,
            KillPointsDelta3Months = S.KillPointsDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.KillPoints, S.StartingKillPoints, S.OverallKillPointsDelta, S.KillPointsDelta12Months, S.KillPointsDelta6Months, S.KillPointsDelta3Months);

    DELETE FROM dbo.KILLPOINTSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 50
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 100
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(KP.KillPoints), 0),
           ROUND(AVG(KP.StartingKillPoints), 0),
           ROUND(AVG(KP.OverallKillPointsDelta), 0),
           ROUND(AVG(KP.KillPointsDelta12Months), 0),
           ROUND(AVG(KP.KillPointsDelta6Months), 0),
           ROUND(AVG(KP.KillPointsDelta3Months), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 150
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END
GO
-- Source: sql_schema/dbo.KILLSSUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[KILLSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'T4T5Kills';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T4&T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE ka
    FROM dbo.KALL ka
    INNER JOIN #AffectedGovs a ON a.GovernorID = ka.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.KALL (GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE k12
    FROM dbo.K12 k12
    INNER JOIN #AffectedGovs a ON a.GovernorID = k12.GovernorID;

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.K12 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12;

    DELETE k6
    FROM dbo.K6 k6
    INNER JOIN #AffectedGovs a ON a.GovernorID = k6.GovernorID;

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.K6 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6;

    DELETE k3
    FROM dbo.K3 k3
    INNER JOIN #AffectedGovs a ON a.GovernorID = k3.GovernorID;

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.K3 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.[LATEST_T4&T5_KILLS] AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T4&T5_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4&T5_KILLS] = src.[T4&T5_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4&T5_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4&T5_KILLS]);

    DELETE kd3
    FROM dbo.K3D kd3
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd3.GovernorID;

    INSERT INTO dbo.K3D (GovernorID, [T4&T5_KILLSDelta3Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K3.RowDesc3 = 1 THEN K3.[T4&T5_KILLS] END) - MAX(CASE WHEN K3.RowAsc3 = 1 THEN K3.[T4&T5_KILLS] END)
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN dbo.K3 K3 ON L.GovernorID = K3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE kd6
    FROM dbo.K6D kd6
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd6.GovernorID;

    INSERT INTO dbo.K6D (GovernorID, [T4&T5_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K6.RowDesc6 = 1 THEN K6.[T4&T5_KILLS] END) - MAX(CASE WHEN K6.RowAsc6 = 1 THEN K6.[T4&T5_KILLS] END)
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN dbo.K6 K6 ON L.GovernorID = K6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE kd12
    FROM dbo.K12D kd12
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd12.GovernorID;

    INSERT INTO dbo.K12D (GovernorID, [T4&T5_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K12.RowDesc12 = 1 THEN K12.[T4&T5_KILLS] END) - MAX(CASE WHEN K12.RowAsc12 = 1 THEN K12.[T4&T5_KILLS] END)
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN dbo.K12 K12 ON L.GovernorID = K12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ka.GovernorID,
               MAX(CASE WHEN ka.RowAscALL = 1 THEN ka.[T4&T5_KILLS] END) AS StartingKills,
               MAX(CASE WHEN ka.RowDescALL = 1 THEN ka.[T4&T5_KILLS] END) AS EndingKills
        FROM dbo.KALL ka
        INNER JOIN #AffectedGovs a ON a.GovernorID = ka.GovernorID
        GROUP BY ka.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.POWERRank,
            L.[T4&T5_KILLS],
            F.StartingKills,
            F.EndingKills - F.StartingKills AS OverallKillsDelta,
            ISNULL(K12D.[T4&T5_KILLSDelta12Months], 0) AS [T4&T5_KILLSDelta12Months],
            ISNULL(K6D.[T4&T5_KILLSDelta6Months], 0) AS [T4&T5_KILLSDelta6Months],
            ISNULL(K3D.[T4&T5_KILLSDelta3Months], 0) AS [T4&T5_KILLSDelta3Months]
        FROM dbo.[LATEST_T4&T5_KILLS] L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.K12D K12D ON L.GovernorID = K12D.GovernorID
        LEFT JOIN dbo.K6D K6D ON L.GovernorID = K6D.GovernorID
        LEFT JOIN dbo.K3D K3D ON L.GovernorID = K3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.KILLSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            POWERRank = S.POWERRank,
            [T4&T5_KILLS] = S.[T4&T5_KILLS],
            [StartingT4&T5_KILLS] = S.StartingKills,
            [OverallT4&T5_KILLSDelta] = S.OverallKillsDelta,
            [T4&T5_KILLSDelta12Months] = S.[T4&T5_KILLSDelta12Months],
            [T4&T5_KILLSDelta6Months] = S.[T4&T5_KILLSDelta6Months],
            [T4&T5_KILLSDelta3Months] = S.[T4&T5_KILLSDelta3Months]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
        VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T4&T5_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T4&T5_KILLSDelta12Months], S.[T4&T5_KILLSDelta6Months], S.[T4&T5_KILLSDelta3Months]);

    DELETE FROM dbo.KILLSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(KS.[T4&T5_KILLS]), 0),
           ROUND(AVG(KS.[StartingT4&T5_KILLS]), 0),
           ROUND(AVG(KS.[OverallT4&T5_KILLSDelta]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta12Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta6Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta3Months]), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 50
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(KS.[T4&T5_KILLS]), 0),
           ROUND(AVG(KS.[StartingT4&T5_KILLS]), 0),
           ROUND(AVG(KS.[OverallT4&T5_KILLSDelta]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta12Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta6Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta3Months]), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 100
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(KS.[T4&T5_KILLS]), 0),
           ROUND(AVG(KS.[StartingT4&T5_KILLS]), 0),
           ROUND(AVG(KS.[OverallT4&T5_KILLSDelta]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta12Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta6Months]), 0),
           ROUND(AVG(KS.[T4&T5_KILLSDelta3Months]), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 150
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END
GO
-- Source: sql_schema/dbo.KT4SUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[KT4SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'T4Kills';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T4_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE k4a
    FROM dbo.K4ALL k4a
    INNER JOIN #AffectedGovs a ON a.GovernorID = k4a.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.K4ALL (GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE k412
    FROM dbo.K412 k412
    INNER JOIN #AffectedGovs a ON a.GovernorID = k412.GovernorID;

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.K412 (GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12;

    DELETE k46
    FROM dbo.K46 k46
    INNER JOIN #AffectedGovs a ON a.GovernorID = k46.GovernorID;

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.K46 (GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6;

    DELETE k43
    FROM dbo.K43 k43
    INNER JOIN #AffectedGovs a ON a.GovernorID = k43.GovernorID;

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.K43 (GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_T4_KILLS AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T4_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4_KILLS] = src.[T4_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4_KILLS]);

    DELETE k43d
    FROM dbo.K43D k43d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k43d.GovernorID;

    INSERT INTO dbo.K43D (GovernorID, [T4_KILLSDelta3Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K43.RowDesc3 = 1 THEN K43.[T4_KILLS] END) - MAX(CASE WHEN K43.RowAsc3 = 1 THEN K43.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN dbo.K43 K43 ON L.GovernorID = K43.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k46d
    FROM dbo.K46D k46d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k46d.GovernorID;

    INSERT INTO dbo.K46D (GovernorID, [T4_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K46.RowDesc6 = 1 THEN K46.[T4_KILLS] END) - MAX(CASE WHEN K46.RowAsc6 = 1 THEN K46.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN dbo.K46 K46 ON L.GovernorID = K46.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k412d
    FROM dbo.K412D k412d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k412d.GovernorID;

    INSERT INTO dbo.K412D (GovernorID, [T4_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K412.RowDesc12 = 1 THEN K412.[T4_KILLS] END) - MAX(CASE WHEN K412.RowAsc12 = 1 THEN K412.[T4_KILLS] END)
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN dbo.K412 K412 ON L.GovernorID = K412.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT k4a.GovernorID,
               MAX(CASE WHEN k4a.RowAscALL = 1 THEN k4a.[T4_KILLS] END) AS StartingKills,
               MAX(CASE WHEN k4a.RowDescALL = 1 THEN k4a.[T4_KILLS] END) AS EndingKills
        FROM dbo.K4ALL k4a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k4a.GovernorID
        GROUP BY k4a.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.POWERRank,
            L.[T4_KILLS],
            F.StartingKills,
            F.EndingKills - F.StartingKills AS OverallKillsDelta,
            ISNULL(K412D.[T4_KILLSDelta12Months], 0) AS [T4_KILLSDelta12Months],
            ISNULL(K46D.[T4_KILLSDelta6Months], 0) AS [T4_KILLSDelta6Months],
            ISNULL(K43D.[T4_KILLSDelta3Months], 0) AS [T4_KILLSDelta3Months]
        FROM dbo.LATEST_T4_KILLS L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.K412D K412D ON L.GovernorID = K412D.GovernorID
        LEFT JOIN dbo.K46D K46D ON L.GovernorID = K46D.GovernorID
        LEFT JOIN dbo.K43D K43D ON L.GovernorID = K43D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.KILL4SUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            POWERRank = S.POWERRank,
            [T4_KILLS] = S.[T4_KILLS],
            [StartingT4_KILLS] = S.StartingKills,
            [OverallT4_KILLSDelta] = S.OverallKillsDelta,
            [T4_KILLSDelta12Months] = S.[T4_KILLSDelta12Months],
            [T4_KILLSDelta6Months] = S.[T4_KILLSDelta6Months],
            [T4_KILLSDelta3Months] = S.[T4_KILLSDelta3Months]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
        VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T4_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T4_KILLSDelta12Months], S.[T4_KILLSDelta6Months], S.[T4_KILLSDelta3Months]);

    DELETE FROM dbo.KILL4SUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 50
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 100
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(K4.[T4_KILLS]), 0),
           ROUND(AVG(K4.[StartingT4_KILLS]), 0),
           ROUND(AVG(K4.[OverallT4_KILLSDelta]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta12Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta6Months]), 0),
           ROUND(AVG(K4.[T4_KILLSDelta3Months]), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 150
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END
GO
-- Source: sql_schema/dbo.KT5SUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[KT5SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'T5Kills';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE k5a
    FROM dbo.K5ALL k5a
    INNER JOIN #AffectedGovs a ON a.GovernorID = k5a.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.K5ALL (GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE k512
    FROM dbo.K512 k512
    INNER JOIN #AffectedGovs a ON a.GovernorID = k512.GovernorID;

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.K512 (GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12;

    DELETE k56
    FROM dbo.K56 k56
    INNER JOIN #AffectedGovs a ON a.GovernorID = k56.GovernorID;

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.K56 (GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6;

    DELETE k53
    FROM dbo.K53 k53
    INNER JOIN #AffectedGovs a ON a.GovernorID = k53.GovernorID;

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.K53 (GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_T5_KILLS AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T5_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T5_KILLS] = src.[T5_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T5_KILLS]);

    DELETE k53d
    FROM dbo.K53D k53d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k53d.GovernorID;

    INSERT INTO dbo.K53D (GovernorID, [T5_KILLSDelta3Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K53.RowDesc3 = 1 THEN K53.[T5_KILLS] END) - MAX(CASE WHEN K53.RowAsc3 = 1 THEN K53.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN dbo.K53 K53 ON L.GovernorID = K53.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k56d
    FROM dbo.K56D k56d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k56d.GovernorID;

    INSERT INTO dbo.K56D (GovernorID, [T5_KILLSDelta6Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K56.RowDesc6 = 1 THEN K56.[T5_KILLS] END) - MAX(CASE WHEN K56.RowAsc6 = 1 THEN K56.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN dbo.K56 K56 ON L.GovernorID = K56.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k512d
    FROM dbo.K512D k512d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k512d.GovernorID;

    INSERT INTO dbo.K512D (GovernorID, [T5_KILLSDelta12Months])
    SELECT L.GovernorID,
           MAX(CASE WHEN K512.RowDesc12 = 1 THEN K512.[T5_KILLS] END) - MAX(CASE WHEN K512.RowAsc12 = 1 THEN K512.[T5_KILLS] END)
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN dbo.K512 K512 ON L.GovernorID = K512.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT k5a.GovernorID,
               MAX(CASE WHEN k5a.RowAscALL = 1 THEN k5a.[T5_KILLS] END) AS StartingKills,
               MAX(CASE WHEN k5a.RowDescALL = 1 THEN k5a.[T5_KILLS] END) AS EndingKills
        FROM dbo.K5ALL k5a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k5a.GovernorID
        GROUP BY k5a.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.POWERRank,
            L.[T5_KILLS],
            F.StartingKills,
            F.EndingKills - F.StartingKills AS OverallKillsDelta,
            ISNULL(K512D.[T5_KILLSDelta12Months], 0) AS [T5_KILLSDelta12Months],
            ISNULL(K56D.[T5_KILLSDelta6Months], 0) AS [T5_KILLSDelta6Months],
            ISNULL(K53D.[T5_KILLSDelta3Months], 0) AS [T5_KILLSDelta3Months]
        FROM dbo.LATEST_T5_KILLS L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.K512D K512D ON L.GovernorID = K512D.GovernorID
        LEFT JOIN dbo.K56D K56D ON L.GovernorID = K56D.GovernorID
        LEFT JOIN dbo.K53D K53D ON L.GovernorID = K53D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.KILL5SUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            POWERRank = S.POWERRank,
            [T5_KILLS] = S.[T5_KILLS],
            [StartingT5_KILLS] = S.StartingKills,
            [OverallT5_KILLSDelta] = S.OverallKillsDelta,
            [T5_KILLSDelta12Months] = S.[T5_KILLSDelta12Months],
            [T5_KILLSDelta6Months] = S.[T5_KILLSDelta6Months],
            [T5_KILLSDelta3Months] = S.[T5_KILLSDelta3Months]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
        VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T5_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T5_KILLSDelta12Months], S.[T5_KILLSDelta6Months], S.[T5_KILLSDelta3Months]);

    DELETE FROM dbo.KILL5SUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 50
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 100
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(K5.[T5_KILLS]), 0),
           ROUND(AVG(K5.[StartingT5_KILLS]), 0),
           ROUND(AVG(K5.[OverallT5_KILLSDelta]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta12Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta6Months]), 0),
           ROUND(AVG(K5.[T5_KILLSDelta3Months]), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 150
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END
GO
-- Source: sql_schema/dbo.POWERSUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[POWERSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'Power';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[POWER]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE pa
    FROM dbo.PALL pa
    INNER JOIN #AffectedGovs a ON a.GovernorID = pa.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.PALL (GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    DELETE p12
    FROM dbo.P12 p12
    INNER JOIN #AffectedGovs a ON a.GovernorID = p12.GovernorID;

    ;WITH RankedP12 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.P12 (GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12
    FROM RankedP12;

    DELETE p6
    FROM dbo.P6 p6
    INNER JOIN #AffectedGovs a ON a.GovernorID = p6.GovernorID;

    ;WITH RankedP6 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.P6 (GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6
    FROM RankedP6;

    DELETE p3
    FROM dbo.P3 p3
    INNER JOIN #AffectedGovs a ON a.GovernorID = p3.GovernorID;

    ;WITH RankedP3 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.P3 (GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3
    FROM RankedP3;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_POWER AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[POWER]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, [POWER] = src.[POWER]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, [POWER])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[POWER]);

    DELETE p3d
    FROM dbo.P3D p3d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p3d.GovernorID;

    INSERT INTO dbo.P3D (GovernorID, POWERDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P3.RowDesc3 = 1 THEN P3.[POWER] END) - MAX(CASE WHEN P3.RowAsc3 = 1 THEN P3.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN dbo.P3 P3 ON L.GovernorID = P3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE p6d
    FROM dbo.P6D p6d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p6d.GovernorID;

    INSERT INTO dbo.P6D (GovernorID, POWERDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P6.RowDesc6 = 1 THEN P6.[POWER] END) - MAX(CASE WHEN P6.RowAsc6 = 1 THEN P6.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN dbo.P6 P6 ON L.GovernorID = P6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE p12d
    FROM dbo.P12D p12d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p12d.GovernorID;

    INSERT INTO dbo.P12D (GovernorID, POWERDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN P12.RowDesc12 = 1 THEN P12.[POWER] END) - MAX(CASE WHEN P12.RowAsc12 = 1 THEN P12.[POWER] END)
    FROM dbo.LATEST_POWER L
    LEFT JOIN dbo.P12 P12 ON L.GovernorID = P12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT pa.GovernorID,
               MAX(CASE WHEN pa.RowAscALL = 1 THEN pa.[POWER] END) AS StartingPower,
               MAX(CASE WHEN pa.RowDescALL = 1 THEN pa.[POWER] END) AS EndingPower
        FROM dbo.PALL pa
        INNER JOIN #AffectedGovs a ON a.GovernorID = pa.GovernorID
        GROUP BY pa.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.[POWER],
            F.StartingPower,
            F.EndingPower - F.StartingPower AS OverallPowerDelta,
            ISNULL(P12D.PowerDelta12Months, 0) AS PowerDelta12Months,
            ISNULL(P6D.PowerDelta6Months, 0) AS PowerDelta6Months,
            ISNULL(P3D.PowerDelta3Months, 0) AS PowerDelta3Months
        FROM dbo.LATEST_POWER L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.P12D P12D ON L.GovernorID = P12D.GovernorID
        LEFT JOIN dbo.P6D P6D ON L.GovernorID = P6D.GovernorID
        LEFT JOIN dbo.P3D P3D ON L.GovernorID = P3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.POWERSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            [POWER] = S.[POWER],
            StartingPower = S.StartingPower,
            OverallPowerDelta = S.OverallPowerDelta,
            PowerDelta12Months = S.PowerDelta12Months,
            PowerDelta6Months = S.PowerDelta6Months,
            PowerDelta3Months = S.PowerDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.[POWER], S.StartingPower, S.OverallPowerDelta, S.PowerDelta12Months, S.PowerDelta6Months, S.PowerDelta3Months);

    DELETE FROM dbo.POWERSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 50
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 100
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(P.[POWER]), 0),
           ROUND(AVG(P.StartingPower), 0),
           ROUND(AVG(P.OverallPowerDelta), 0),
           ROUND(AVG(P.PowerDelta12Months), 0),
           ROUND(AVG(P.PowerDelta6Months), 0),
           ROUND(AVG(P.PowerDelta3Months), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 150
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END
GO
-- Source: sql_schema/dbo.RANGEDSUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[RANGEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'RangedPoints';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL
         AND OBJECT_ID('tempdb..#GovScan') IS NOT NULL
         AND OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            RETURN;
        END

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.RangedPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    DELETE ra
    FROM dbo.RANGED_ALL ra
    INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID;

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO dbo.RANGED_ALL (GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.RANGED_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.RangedPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, RangedPoints = src.RangedPoints
    WHEN NOT MATCHED THEN INSERT (GovernorID, GovernorName, PowerRank, RangedPoints)
    VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.RangedPoints);

    DELETE d
    FROM dbo.RANGED_D3 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO dbo.RANGED_D3 (GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3;

    DELETE d
    FROM dbo.RANGED_D6 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO dbo.RANGED_D6 (GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6;

    DELETE d
    FROM dbo.RANGED_D12 d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO dbo.RANGED_D12 (GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12;

    DELETE d
    FROM dbo.RANGED_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D3D (GovernorID, RangedPointsDelta3Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.RangedPoints END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D6D (GovernorID, RangedPointsDelta6Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.RangedPoints END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D12D (GovernorID, RangedPointsDelta12Months)
    SELECT L.GovernorID,
           MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.RangedPoints END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.RangedPoints END)
    FROM dbo.RANGED_LATEST L
    LEFT JOIN dbo.RANGED_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ra.GovernorID,
               MAX(CASE WHEN ra.RowAscALL = 1 THEN ra.RangedPoints END) AS StartingRanged,
               MAX(CASE WHEN ra.RowDescALL = 1 THEN ra.RangedPoints END) AS EndingRanged
        FROM dbo.RANGED_ALL ra
        INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID
        GROUP BY ra.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.RangedPoints,
            F.StartingRanged,
            F.EndingRanged - F.StartingRanged AS OverallRangedDelta,
            ISNULL(R12D.RangedPointsDelta12Months, 0) AS RangedDelta12Months,
            ISNULL(R6D.RangedPointsDelta6Months, 0) AS RangedDelta6Months,
            ISNULL(R3D.RangedPointsDelta3Months, 0) AS RangedDelta3Months
        FROM dbo.RANGED_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.RANGED_D12D R12D ON L.GovernorID = R12D.GovernorID
        LEFT JOIN dbo.RANGED_D6D R6D ON L.GovernorID = R6D.GovernorID
        LEFT JOIN dbo.RANGED_D3D R3D ON L.GovernorID = R3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.RANGEDSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            RangedPoints = S.RangedPoints,
            StartingRanged = S.StartingRanged,
            OverallRangedDelta = S.OverallRangedDelta,
            RangedDelta12Months = S.RangedDelta12Months,
            RangedDelta6Months = S.RangedDelta6Months,
            RangedDelta3Months = S.RangedDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.RangedPoints, S.StartingRanged, S.OverallRangedDelta, S.RangedDelta12Months, S.RangedDelta6Months, S.RangedDelta3Months);

    DELETE FROM dbo.RANGEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999997, 'Top50', 50,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 50
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999998, 'Top100', 100,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 100
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999999, 'Kingdom Average', 150,
           ROUND(AVG(R.RangedPoints), 0),
           ROUND(AVG(R.StartingRanged), 0),
           ROUND(AVG(R.OverallRangedDelta), 0),
           ROUND(AVG(R.RangedDelta12Months), 0),
           ROUND(AVG(R.RangedDelta6Months), 0),
           ROUND(AVG(R.RangedDelta3Months), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 150
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
END
GO
-- Source: sql_schema/dbo.Refresh_PlayerScanMeta.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[Refresh_PlayerScanMeta]
	@FullRebuild [bit] = 0,
	@MinScanOrder [int] = NULL,
	@FromScanDate [date] = NULL,
	@BatchSize [int] = NULL,
	@StartingGovernorID [bigint] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#ScanDays') IS NULL
    BEGIN
        CREATE TABLE #ScanDays (
            ScanDate date NOT NULL PRIMARY KEY,
            DayIndex int NOT NULL
        );
    END

    IF @FullRebuild = 0 AND @MinScanOrder IS NULL AND @FromScanDate IS NULL
    BEGIN
        SELECT @FromScanDate = MAX(LastScanDate)
        FROM dbo.PlayerScanMeta;
    END

    IF @FullRebuild = 1 AND (@BatchSize IS NULL OR @BatchSize <= 0)
    BEGIN
        TRUNCATE TABLE dbo.PlayerScanMeta;

        TRUNCATE TABLE #ScanDays;

        ;WITH scan_bounds AS (
            SELECT
                MIN(ks.AsOfDate) AS MinScanDate,
                MAX(ks.AsOfDate) AS MaxScanDate
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
        ),
        scan_days AS (
            SELECT DISTINCT ks.AsOfDate AS ScanDate
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            CROSS JOIN scan_bounds sb
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
              AND ks.AsOfDate >= sb.MinScanDate
              AND ks.AsOfDate <= sb.MaxScanDate
        ),
        ordered_scan_days AS (
            SELECT
                sd.ScanDate,
                ROW_NUMBER() OVER (ORDER BY sd.ScanDate) AS DayIndex
            FROM scan_days sd
        )
        INSERT INTO #ScanDays (ScanDate, DayIndex)
        SELECT ScanDate, DayIndex
        FROM ordered_scan_days;

        ;WITH d AS (
            SELECT DISTINCT
                ks.GovernorID,
                ks.AsOfDate AS ScanDate,
                sd.DayIndex
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            INNER JOIN #ScanDays sd
                ON sd.ScanDate = ks.AsOfDate
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
        ),
        ordered AS (
            SELECT
                GovernorID,
                ScanDate,
                LAG(DayIndex) OVER (PARTITION BY GovernorID ORDER BY ScanDate) AS PrevDayIndex,
                DayIndex
            FROM d
        ),
        gaps AS (
            SELECT
                o.GovernorID,
                o.ScanDate,
                o.PrevDayIndex,
                MissedScanDays = CASE
                    WHEN o.PrevDayIndex IS NULL THEN 0
                    ELSE (o.DayIndex - o.PrevDayIndex - 1)
                END
            FROM ordered o
        ),
        meta AS (
            SELECT
                GovernorID,
                MIN(ScanDate) AS FirstScanDate,
                MAX(ScanDate) AS LastScanDate,
                SUM(CASE WHEN MissedScanDays > 30 THEN MissedScanDays ELSE 0 END) AS OfflineDaysOver30
            FROM gaps
            GROUP BY GovernorID
        ),
        orders AS (
            SELECT
                ks.GovernorID,
                MIN(ks.SCANORDER) AS FirstScanOrder,
                MAX(ks.SCANORDER) AS LastScanOrder
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
            GROUP BY ks.GovernorID
        )
        INSERT INTO dbo.PlayerScanMeta
        (
            GovernorID,
            FirstScanDate,
            LastScanDate,
            FirstScanOrder,
            LastScanOrder,
            OfflineDaysOver30,
            LastRefreshedUTC
        )
        SELECT
            m.GovernorID,
            m.FirstScanDate,
            m.LastScanDate,
            o.FirstScanOrder,
            o.LastScanOrder,
            m.OfflineDaysOver30,
            SYSUTCDATETIME()
        FROM meta m
        INNER JOIN orders o
            ON o.GovernorID = m.GovernorID;

        RETURN;
    END

    IF @FullRebuild = 1 AND (@BatchSize IS NOT NULL AND @BatchSize > 0)
    BEGIN
        IF @StartingGovernorID IS NULL
        BEGIN
            TRUNCATE TABLE dbo.PlayerScanMeta;
            SET @StartingGovernorID = 0;
        END
    END

    DECLARE @Continue bit = 1;
    DECLARE @LastGovernorID bigint = ISNULL(@StartingGovernorID, 0);

    WHILE @Continue = 1
    BEGIN
        IF OBJECT_ID('tempdb..#Governors') IS NOT NULL
            DROP TABLE #Governors;

        CREATE TABLE #Governors (GovernorID bigint NOT NULL PRIMARY KEY);

        INSERT INTO #Governors (GovernorID)
        SELECT TOP (CASE WHEN @BatchSize IS NULL OR @BatchSize <= 0 THEN 2147483647 ELSE @BatchSize END)
            g.GovernorID
        FROM (
            SELECT DISTINCT ks.GovernorID
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            WHERE ks.GovernorID IS NOT NULL
              AND ks.GovernorID <> 0
              AND (
                    @FullRebuild = 1
                 OR (@MinScanOrder IS NOT NULL AND ks.SCANORDER >= @MinScanOrder)
                 OR (@FromScanDate IS NOT NULL AND ks.ScanDate >= @FromScanDate)
              )
        ) AS g
        WHERE g.GovernorID > @LastGovernorID
        ORDER BY g.GovernorID;

        IF NOT EXISTS (SELECT 1 FROM #Governors)
        BEGIN
            SET @Continue = 0;
            BREAK;
        END

        SELECT @LastGovernorID = MAX(GovernorID)
        FROM #Governors;

        TRUNCATE TABLE #ScanDays;

        ;WITH scan_bounds AS (
            SELECT
                MIN(ks.AsOfDate) AS MinScanDate,
                MAX(ks.AsOfDate) AS MaxScanDate
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            INNER JOIN #Governors g
                ON g.GovernorID = ks.GovernorID
        ),
        scan_days AS (
            SELECT DISTINCT ks.AsOfDate AS ScanDate
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            CROSS JOIN scan_bounds sb
            WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
              AND ks.AsOfDate >= sb.MinScanDate
              AND ks.AsOfDate <= sb.MaxScanDate
        ),
        ordered_scan_days AS (
            SELECT
                sd.ScanDate,
                ROW_NUMBER() OVER (ORDER BY sd.ScanDate) AS DayIndex
            FROM scan_days sd
        )
        INSERT INTO #ScanDays (ScanDate, DayIndex)
        SELECT ScanDate, DayIndex
        FROM ordered_scan_days;

        ;WITH d AS (
            SELECT DISTINCT
                ks.GovernorID,
                ks.AsOfDate AS ScanDate,
                sd.DayIndex
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            INNER JOIN #Governors g
                ON g.GovernorID = ks.GovernorID
            INNER JOIN #ScanDays sd
                ON sd.ScanDate = ks.AsOfDate
        ),
        ordered AS (
            SELECT
                GovernorID,
                ScanDate,
                LAG(DayIndex) OVER (PARTITION BY GovernorID ORDER BY ScanDate) AS PrevDayIndex,
                DayIndex
            FROM d
        ),
        gaps AS (
            SELECT
                o.GovernorID,
                o.ScanDate,
                o.PrevDayIndex,
                MissedScanDays = CASE
                    WHEN o.PrevDayIndex IS NULL THEN 0
                    ELSE (o.DayIndex - o.PrevDayIndex - 1)
                END
            FROM ordered o
        ),
        meta AS (
            SELECT
                GovernorID,
                MIN(ScanDate) AS FirstScanDate,
                MAX(ScanDate) AS LastScanDate,
                SUM(CASE WHEN MissedScanDays > 30 THEN MissedScanDays ELSE 0 END) AS OfflineDaysOver30
            FROM gaps
            GROUP BY GovernorID
        ),
        orders AS (
            SELECT
                ks.GovernorID,
                MIN(ks.SCANORDER) AS FirstScanOrder,
                MAX(ks.SCANORDER) AS LastScanOrder
            FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
            INNER JOIN #Governors g
                ON g.GovernorID = ks.GovernorID
            GROUP BY ks.GovernorID
        )
        MERGE dbo.PlayerScanMeta AS target
        USING (
            SELECT
                m.GovernorID,
                m.FirstScanDate,
                m.LastScanDate,
                o.FirstScanOrder,
                o.LastScanOrder,
                m.OfflineDaysOver30
            FROM meta m
            INNER JOIN orders o
                ON o.GovernorID = m.GovernorID
        ) AS source
        ON target.GovernorID = source.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                FirstScanDate = source.FirstScanDate,
                LastScanDate = source.LastScanDate,
                FirstScanOrder = source.FirstScanOrder,
                LastScanOrder = source.LastScanOrder,
                OfflineDaysOver30 = source.OfflineDaysOver30,
                LastRefreshedUTC = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (
                GovernorID,
                FirstScanDate,
                LastScanDate,
                FirstScanOrder,
                LastScanOrder,
                OfflineDaysOver30,
                LastRefreshedUTC
            )
            VALUES (
                source.GovernorID,
                source.FirstScanDate,
                source.LastScanDate,
                source.FirstScanOrder,
                source.LastScanOrder,
                source.OfflineDaysOver30,
                SYSUTCDATETIME()
            );

        IF @BatchSize IS NULL OR @BatchSize <= 0
        BEGIN
            SET @Continue = 0;
        END
    END
END;
GO
-- Source: sql_schema/dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_ExcelOutput_ByKVK]
	@KVK [int],
	@Scan [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE
        @CURRENTKVK3      INT,
        @KVK_END_SCAN     INT,
        @LASTKVKEND       INT,
        @PASS4END         INT,
        @PASS6END         INT,
        @PASS7END         INT,
        @PRE_PASS_4_SCAN  INT,
        @MaxAvailableScan INT,
        @LatestScanToUse  INT;

    -- Load KVK config
    SELECT
        @CURRENTKVK3     = CAST(MAX(CASE WHEN ConfigKey = 'CURRENTKVK3'     THEN ConfigValue END) AS INT),
        @KVK_END_SCAN    = CAST(MAX(CASE WHEN ConfigKey = 'KVK_END_SCAN'    THEN ConfigValue END) AS INT),
        @LASTKVKEND      = CAST(MAX(CASE WHEN ConfigKey = 'LASTKVKEND'      THEN ConfigValue END) AS INT),
        @PASS4END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS4END'        THEN ConfigValue END) AS INT),
        @PASS6END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS6END'        THEN ConfigValue END) AS INT),
        @PASS7END        = CAST(MAX(CASE WHEN ConfigKey = 'PASS7END'        THEN ConfigValue END) AS INT),
        @PRE_PASS_4_SCAN = CAST(MAX(CASE WHEN ConfigKey = 'PRE_PASS_4_SCAN' THEN ConfigValue END) AS INT)
    FROM dbo.ProcConfig
    WHERE KVKVersion = @KVK;

    IF @KVK_END_SCAN IS NULL OR @LASTKVKEND IS NULL OR @PRE_PASS_4_SCAN IS NULL
    BEGIN
        RAISERROR('sp_ExcelOutput_ByKVK: Missing KVK window config for KVK=%d (one of KVK_END_SCAN/LASTKVKEND/PRE_PASS_4_SCAN is NULL).', 16, 1, @KVK);
        RETURN;
    END

    -- Cap @Scan to available data (safety if caller passed a future scan)
    SELECT @MaxAvailableScan = MAX(ScanOrder) FROM dbo.KingdomScanData4;
    IF @MaxAvailableScan IS NULL
    BEGIN
        RAISERROR('sp_ExcelOutput_ByKVK: No scan data available.', 16, 1);
        RETURN;
    END
    IF @Scan > @MaxAvailableScan SET @Scan = @MaxAvailableScan;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @Scan
    )
    BEGIN
        RAISERROR('sp_ExcelOutput_ByKVK: Requested final ScanOrder=%d has no source rows.', 16, 1, @Scan);
        RETURN;
    END

    -- Determine which scan to use for latest data
    -- For completed KVKs use KVK_END_SCAN, for current KVK use MaxAvailableScan
    SET @LatestScanToUse = CASE
        WHEN @MaxAvailableScan > @KVK_END_SCAN THEN @KVK_END_SCAN
        ELSE @MaxAvailableScan
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @LatestScanToUse
    )
    BEGIN
        RAISERROR('sp_ExcelOutput_ByKVK: Resolved final ScanOrder=%d has no source rows.', 16, 1, @LatestScanToUse);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Fresh staging
        TRUNCATE TABLE dbo.STAGING_STATS;

    -----------------------------------------------
    -- Build/refresh ranked PreKvk & Honor tables (so we can join ranks quickly)
    -----------------------------------------------
    EXEC dbo.sp_Build_Prekvk_And_Honor_Rankings;

    -----------------------------------------------
     -- 1. Snapshot (materialize once for reuse) - REDUCED COLUMNS
    -----------------------------------------------
    CREATE TABLE #Snapshot (
        GovernorID        bigint           NOT NULL PRIMARY KEY CLUSTERED,
        GovernorName      nvarchar(255)  NULL,
        PowerRank         int           NULL,
        [Power]           bigint        NULL,
        [Civilization]    nvarchar(100)  NULL,
        [KvKPlayed]       int           NULL,
        [Deads]           bigint        NULL,
        [T4&T5_KILLS]     bigint        NULL,
        [HealedTroops]    bigint        NULL,
        [KillPoints]      bigint        NULL,
        [AutarchTimes]    bigint        NULL,
        MaxPreKvkPoints   bigint        NULL,
        PreKvkRank        int           NULL,
        MaxHonorPoints    bigint        NULL,
        HonorRank         int           NULL,
		RangedPoints     bigint  NULL
    );

    INSERT INTO #Snapshot (
          GovernorID
        , GovernorName
        , PowerRank
        , [Power]
        , [Civilization]
        , [KvKPlayed]
        , [Deads]
        , [T4&T5_KILLS]
        , [HealedTroops]
        , [KillPoints]
        , [AutarchTimes]
        , MaxPreKvkPoints
        , PreKvkRank
        , MaxHonorPoints
        , HonorRank
		, RangedPoints
    )
    SELECT
        ksd.GovernorID,
        ksd.GovernorName,
        ksd.PowerRank,
        ksd.[Power],
        ksd.[Civilization],
        ksd.[KvKPlayed],
		ksd.[Deads],
		ksd.[T4&T5_KILLS],
		ksd.[HealedTroops],
		ksd.[KillPoints],
		ksd.[AutarchTimes],
        pk.MaxPreKvkPoints    AS MaxPreKvkPoints,
        pk.PreKvk_Rank        AS PreKvkRank,
        hn.MaxHonorPoints     AS MaxHonorPoints,
        hn.Honor_Rank         AS HonorRank,
		ksd.[RangedPoints]
    FROM dbo.KingdomScanData4 ksd
    LEFT JOIN dbo.PreKvk_Scores_Ranked pk
      ON pk.GovernorID = ksd.GovernorID AND pk.KVK_NO = @CURRENTKVK3
    LEFT JOIN dbo.KVK_Honor_Ranked hn
      ON hn.GovernorID = ksd.GovernorID AND hn.KVK_NO = @CURRENTKVK3
    WHERE ksd.ScanOrder = @Scan;

    -----------------------------------------------
    -- 1b. LATEST data (for completed/current KVK stats)
    -----------------------------------------------
    CREATE TABLE #LATEST (
        GovernorID       bigint  NOT NULL PRIMARY KEY CLUSTERED,
        MostKvKKill      bigint  NULL,
        MostKvKDead      bigint  NULL,
        MostKvKHeal      bigint  NULL,
        Acclaim          bigint  NULL,
        HighestAcclaim   bigint  NULL,
        AOOJoined        bigint  NULL,
        AOOWon           int     NULL,
        AOOAvgKill       bigint  NULL,
        AOOAvgDead       bigint  NULL,
        AOOAvgHeal       bigint  NULL,
        Conduct          decimal(5,2) NULL
    );

    INSERT INTO #LATEST (
          GovernorID
        , MostKvKKill
        , MostKvKDead
        , MostKvKHeal
        , Acclaim
        , HighestAcclaim
        , AOOJoined
        , AOOWon
        , AOOAvgKill
        , AOOAvgDead
        , AOOAvgHeal
        , Conduct
    )
    SELECT
        ksd.GovernorID,
        ksd.MostKvKKill,
        ksd.MostKvKDead,
        ksd.MostKvKHeal,
        ksd.Acclaim,
        ksd.HighestAcclaim,
        ksd.AOOJoined,
        ksd.AOOWon,
        ksd.AOOAvgKill,
        ksd.AOOAvgDead,
        ksd.AOOAvgHeal,
        ksd.Conduct
    FROM dbo.KingdomScanData4 ksd
    WHERE ksd.ScanOrder = @LatestScanToUse;

	CREATE TABLE #GovernorList (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED
    );

    INSERT INTO #GovernorList (GovernorID)
    SELECT s.GovernorID
    FROM #Snapshot s
    WHERE s.GovernorID IS NOT NULL;

    -----------------------------------------------
    -- 2. Consolidated Deads Delta (filtered to snapshot)
    -----------------------------------------------
    CREATE TABLE #Deads (
        GovernorID        bigint  NOT NULL PRIMARY KEY CLUSTERED,
        DeadsDelta        bigint  NOT NULL,
        DeadsDeltaOutKVK  bigint  NOT NULL,
        P4DeadsDelta      bigint  NOT NULL,
        P6DeadsDelta      bigint  NOT NULL,
        P7DeadsDelta      bigint  NOT NULL,
        P8DeadsDelta      bigint  NOT NULL
    );

    INSERT INTO #Deads (GovernorID, DeadsDelta, DeadsDeltaOutKVK, P4DeadsDelta, P6DeadsDelta, P7DeadsDelta, P8DeadsDelta)
    SELECT
        d.GovernorID,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @LASTKVKEND      AND d.DeltaOrder <= @PRE_PASS_4_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @PASS4END THEN d.DeadsDelta ELSE 0 END) AS P4DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS4END        AND d.DeltaOrder <= @PASS6END THEN d.DeadsDelta ELSE 0 END) AS P6DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS6END        AND d.DeltaOrder <= @PASS7END THEN d.DeadsDelta ELSE 0 END) AS P7DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS7END        AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS P8DeadsDelta
    FROM dbo.DeadsDelta d
    INNER JOIN #GovernorList gl ON gl.GovernorID = d.GovernorID
    WHERE d.DeltaOrder > @LASTKVKEND AND d.DeltaOrder <= @KVK_END_SCAN
    GROUP BY d.GovernorID;

    -----------------------------------------------
    -- 3. Consolidated Kills Delta (T4&T5)
    -----------------------------------------------
    CREATE TABLE #Kills (
        GovernorID      bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T4T5KillsDelta  bigint  NOT NULL,
        KillsOutsideKVK bigint  NOT NULL,
        P4Kills         bigint  NOT NULL,
        P6Kills         bigint  NOT NULL,
        P7Kills         bigint  NOT NULL,
        P8Kills         bigint  NOT NULL
    );

    INSERT INTO #Kills (GovernorID, T4T5KillsDelta, KillsOutsideKVK, P4Kills, P6Kills, P7Kills, P8Kills)
    SELECT
        k.GovernorID,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
        SUM(CASE WHEN k.DeltaOrder > @LASTKVKEND      AND k.DeltaOrder <= @PRE_PASS_4_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @PASS4END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS4END        AND k.DeltaOrder <= @PASS6END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS6END        AND k.DeltaOrder <= @PASS7END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS7END        AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
    FROM dbo.T4T5KillDelta k
    INNER JOIN #GovernorList gl ON gl.GovernorID = k.GovernorID
    WHERE k.DeltaOrder > @LASTKVKEND AND k.DeltaOrder <= @KVK_END_SCAN
    GROUP BY k.GovernorID;

    -----------------------------------------------
    -- 4. T4 / T5 splits
    -----------------------------------------------
    CREATE TABLE #KillsT4 (
        GovernorID   bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T4KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT4 (GovernorID, T4KillsDelta)
    SELECT t4.GovernorID, SUM(COALESCE(t4.T4KILLSDelta, 0)) AS T4KillsDelta
    FROM dbo.T4KillDelta t4
    INNER JOIN #GovernorList gl ON gl.GovernorID = t4.GovernorID
    WHERE t4.DeltaOrder > @PRE_PASS_4_SCAN AND t4.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t4.GovernorID;

    CREATE TABLE #KillsT5 (
        GovernorID   bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T5KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT5 (GovernorID, T5KillsDelta)
    SELECT t5.GovernorID, SUM(COALESCE(t5.T5KILLSDelta, 0)) AS T5KillsDelta
    FROM dbo.T5KillDelta t5
    INNER JOIN #GovernorList gl ON gl.GovernorID = t5.GovernorID
    WHERE t5.DeltaOrder > @PRE_PASS_4_SCAN AND t5.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t5.GovernorID;

	-----------------------------------------------
	-- 5. KillPointsDelta aggregation (use same window as other deltas)
	-----------------------------------------------
    CREATE TABLE #KillPoints (
        GovernorID      bigint  NOT NULL PRIMARY KEY CLUSTERED,
        KillPointsDelta bigint  NOT NULL
    );

	INSERT INTO #KillPoints (GovernorID, KillPointsDelta)
	SELECT kp.GovernorID, SUM(COALESCE(kp.KillPointsDelta, 0)) AS KillPointsDelta
	FROM dbo.KillPointsDelta kp
    INNER JOIN #GovernorList gl ON gl.GovernorID = kp.GovernorID
	WHERE kp.DeltaOrder > @PRE_PASS_4_SCAN AND kp.DeltaOrder <= @KVK_END_SCAN
	GROUP BY kp.GovernorID;

    -----------------------------------------------
    -- 6. Other deltas (use @Scan as lower bound)
    -----------------------------------------------
    CREATE TABLE #Helps (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED,
        HelpsDelta bigint NOT NULL
    );

    INSERT INTO #Helps (GovernorID, HelpsDelta)
    SELECT h.GovernorID, SUM(COALESCE(h.HelpsDelta, 0)) AS HelpsDelta
    FROM dbo.HelpsDelta h
    INNER JOIN #GovernorList gl ON gl.GovernorID = h.GovernorID
    WHERE h.DeltaOrder > @Scan AND h.DeltaOrder <= @KVK_END_SCAN
    GROUP BY h.GovernorID;

    CREATE TABLE #RSSAssist (
        GovernorID     bigint NOT NULL PRIMARY KEY CLUSTERED,
        RSSAssistDelta bigint NOT NULL
    );

    INSERT INTO #RSSAssist (GovernorID, RSSAssistDelta)
    SELECT ra.GovernorID, SUM(COALESCE(ra.RSSASSISTDelta, 0)) AS RSSAssistDelta
    FROM dbo.RSSASSISTDelta ra
    INNER JOIN #GovernorList gl ON gl.GovernorID = ra.GovernorID
    WHERE ra.DeltaOrder > @Scan AND ra.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ra.GovernorID;

    CREATE TABLE #RSSGathered (
        GovernorID       bigint NOT NULL PRIMARY KEY CLUSTERED,
        RSSGatheredDelta bigint NOT NULL
    );

    INSERT INTO #RSSGathered (GovernorID, RSSGatheredDelta)
    SELECT rg.GovernorID, SUM(COALESCE(rg.RSSGatheredDelta, 0)) AS RSSGatheredDelta
    FROM dbo.RSSGatheredDelta rg
    INNER JOIN #GovernorList gl ON gl.GovernorID = rg.GovernorID
    WHERE rg.DeltaOrder > @Scan AND rg.DeltaOrder <= @KVK_END_SCAN
    GROUP BY rg.GovernorID;

    CREATE TABLE #Power (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED,
        PowerDelta bigint NOT NULL
    );

    INSERT INTO #Power (GovernorID, PowerDelta)
    SELECT p.GovernorID, SUM(COALESCE(p.Power_Delta, 0)) AS PowerDelta
    FROM dbo.PowerDelta p
    INNER JOIN #GovernorList gl ON gl.GovernorID = p.GovernorID
    WHERE p.DeltaOrder > @Scan AND p.DeltaOrder <= @KVK_END_SCAN
    GROUP BY p.GovernorID;

    CREATE TABLE #Healed (
        GovernorID        bigint NOT NULL PRIMARY KEY CLUSTERED,
        HealedTroopsDelta bigint NOT NULL
    );

	INSERT INTO #Healed (GovernorID, HealedTroopsDelta)
    SELECT ht.GovernorID, SUM(COALESCE(ht.HealedTroopsDelta, 0)) AS HealedTroopsDelta
    FROM dbo.HealedTroopsDelta ht
    INNER JOIN #GovernorList gl ON gl.GovernorID = ht.GovernorID
    WHERE ht.DeltaOrder > @Scan AND ht.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ht.GovernorID;

    CREATE TABLE #Ranged (
        GovernorID        bigint NOT NULL PRIMARY KEY CLUSTERED,
        RangedPointsDelta bigint NOT NULL
    );

	INSERT INTO #Ranged (GovernorID, RangedPointsDelta)
    SELECT r.GovernorID, SUM(COALESCE(r.RangedPointsDelta, 0)) AS RangedPointsDelta
    FROM dbo.RangedPointsDelta r
    INNER JOIN #GovernorList gl ON gl.GovernorID = r.GovernorID
    WHERE r.DeltaOrder > @Scan AND r.DeltaOrder <= @KVK_END_SCAN
    GROUP BY r.GovernorID;

    -----------------------------------------------
    -- 7. Stage - NOW USING #LATEST FOR MOVED COLUMNS
    -----------------------------------------------
	INSERT INTO dbo.STAGING_STATS (
		  GovernorID
		, PowerRank
		, [Power]
		, Power_Delta
		, GovernorName
		, T4KillsDelta
		, T5KillsDelta
		, [T4&T5_KILLSDelta]
		, [KILLS_OUTSIDE_KVK]
		, [P4T4&T5_KILLSDelta]
		, [P6T4&T5_KillsDelta]
		, [P7T4&T5_KillsDelta]
		, [P8T4&T5_KillsDelta]
		, DeadsDelta
		, [DEADS_OUTSIDE_KVK]
		, P4DeadsDelta
		, P6DeadsDelta
		, P7DeadsDelta
		, P8DeadsDelta
		, HelpsDelta
		, RSSASSISTDelta
		, RSSGatheredDelta
		, HealedTroops
		, RangedPoints
		, RangedPointsDelta
		, AutarchTimes
		, Civilization
		, KvKPlayed
		, MostKvKKill
		, MostKvKDead
		, MostKvKHeal
		, Acclaim
		, HighestAcclaim
		, AOOJoined
		, AOOWon
		, AOOAvgKill
		, AOOAvgDead
		, AOOAvgHeal
		, Conduct
		, KillPointsDelta
		, KillPoints
		, HealedTroopsDelta
		, [Starting_Deads]
		, [Starting_T4&T5_KILLS]
		, MaxPreKvkPoints
		, MaxHonorPoints
		, PreKvkRank
		, HonorRank
	)
	SELECT
		  s.GovernorID
		, s.PowerRank
		, s.[Power]
		, COALESCE(p.PowerDelta, 0)                 AS Power_Delta
		, s.GovernorName
		, COALESCE(kt4.T4KillsDelta, 0)             AS T4KillsDelta
		, COALESCE(kt5.T5KillsDelta, 0)             AS T5KillsDelta
		, COALESCE(k.T4T5KillsDelta, 0)             AS [T4&T5_KILLSDelta]
		, COALESCE(k.KillsOutsideKVK, 0)            AS [KILLS_OUTSIDE_KVK]
		, COALESCE(k.P4Kills, 0)                    AS [P4T4&T5_KILLSDelta]
		, COALESCE(k.P6Kills, 0)                    AS [P6T4&T5_KillsDelta]
		, COALESCE(k.P7Kills, 0)                    AS [P7T4&T5_KillsDelta]
		, COALESCE(k.P8Kills, 0)                    AS [P8T4&T5_KillsDelta]
		, COALESCE(d.DeadsDelta, 0)                 AS DeadsDelta
		, COALESCE(d.DeadsDeltaOutKVK, 0)           AS [DEADS_OUTSIDE_KVK]
		, COALESCE(d.P4DeadsDelta, 0)               AS P4DeadsDelta
		, COALESCE(d.P6DeadsDelta, 0)               AS P6DeadsDelta
		, COALESCE(d.P7DeadsDelta, 0)               AS P7DeadsDelta
		, COALESCE(d.P8DeadsDelta, 0)               AS P8DeadsDelta
		, COALESCE(h.HelpsDelta, 0)                 AS HelpsDelta
		, COALESCE(ra.RSSAssistDelta, 0)            AS RSSASSISTDelta
		, COALESCE(rg.RSSGatheredDelta, 0)          AS RSSGatheredDelta
		, COALESCE(s.HealedTroops, 0)               AS HealedTroops
		, COALESCE(s.RangedPoints, 0)             AS RangedPoints
		, COALESCE(ran.RangedPointsDelta, 0)        AS RangedPointsDelta
		, COALESCE(s.AutarchTimes, 0)               AS AutarchTimes
		, s.Civilization
		, COALESCE(s.KvKPlayed, 0)                  AS KvKPlayed
		, COALESCE(lst.MostKvKKill, 0)              AS MostKvKKill        -- FROM #LATEST
		, COALESCE(lst.MostKvKDead, 0)              AS MostKvKDead        -- FROM #LATEST
		, COALESCE(lst.MostKvKHeal, 0)              AS MostKvKHeal        -- FROM #LATEST
		, COALESCE(lst.Acclaim, 0)                  AS Acclaim            -- FROM #LATEST
		, COALESCE(lst.HighestAcclaim, 0)           AS HighestAcclaim     -- FROM #LATEST
		, COALESCE(lst.AOOJoined, 0)                AS AOOJoined          -- FROM #LATEST
		, COALESCE(lst.AOOWon, 0)                   AS AOOWon             -- FROM #LATEST
		, COALESCE(lst.AOOAvgKill, 0)               AS AOOAvgKill         -- FROM #LATEST
		, COALESCE(lst.AOOAvgDead, 0)               AS AOOAvgDead         -- FROM #LATEST
		, COALESCE(lst.AOOAvgHeal, 0)               AS AOOAvgHeal         -- FROM #LATEST
		, lst.Conduct                                AS Conduct            -- FROM #LATEST
		, COALESCE(kp.KillPointsDelta, 0)           AS KillPointsDelta
		, COALESCE(s.KillPoints, 0)                 AS KillPoints
		, COALESCE(he.HealedTroopsDelta, 0)         AS HealedTroopsDelta
		, COALESCE(s.Deads, 0)                      AS [Starting_Deads]
		, COALESCE(s.[T4&T5_KILLS], 0)              AS [Starting_T4&T5_KILLS]
		, COALESCE(s.MaxPreKvkPoints, 0)            AS MaxPreKvkPoints
		, COALESCE(s.MaxHonorPoints, 0)             AS MaxHonorPoints
		, COALESCE(s.PreKvkRank, 0)                 AS PreKvkRank
		, COALESCE(s.HonorRank, 0)                  AS HonorRank
	FROM #Snapshot s
	LEFT JOIN #LATEST      lst ON lst.GovernorID = s.GovernorID  -- NEW JOIN
	LEFT JOIN #Power       p   ON p.GovernorID   = s.GovernorID
	LEFT JOIN #KillsT4     kt4 ON kt4.GovernorID = s.GovernorID
	LEFT JOIN #KillsT5     kt5 ON kt5.GovernorID = s.GovernorID
	LEFT JOIN #Kills       k   ON k.GovernorID   = s.GovernorID
	LEFT JOIN #KillPoints  kp  ON kp.GovernorID  = s.GovernorID
	LEFT JOIN #Deads       d   ON d.GovernorID   = s.GovernorID
	LEFT JOIN #Helps       h   ON h.GovernorID   = s.GovernorID
	LEFT JOIN #RSSAssist   ra  ON ra.GovernorID  = s.GovernorID
	LEFT JOIN #RSSGathered rg  ON rg.GovernorID  = s.GovernorID
	LEFT JOIN #Healed      he  ON he.GovernorID  = s.GovernorID
	LEFT JOIN #Ranged      ran ON ran.GovernorID = s.GovernorID
	WHERE s.GovernorID IS NOT NULL;


    -- Cleanup temps from stage step
    DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot, #LATEST, #Healed, #Ranged, #KillPoints, #GovernorList;

    -----------------------------------------------
    -- 8. DKP + HoH (normalize DKP column name)
    -----------------------------------------------
    SELECT  S1.[GovernorID],
            CASE WHEN z.GovernorID = s1.GovernorID
                 THEN ROUND((S1.[T4&T5_KILLSDelta]*3 + (S1.[DeadsDelta] * 0.1) * 8), 0)
                 ELSE ROUND((S1.[T4&T5_KILLSDelta]*3 +  S1.[DeadsDelta]      * 8), 0)
            END AS [DKP_SCORE]
    INTO #DKP
    FROM dbo.STAGING_STATS AS S1
    LEFT JOIN dbo.ZEROED    AS Z ON Z.GovernorID = S1.GovernorID AND Z.ScanOrder = @Scan;

    SELECT GovernorID, MAX(T4_Deads) AS [T4 Deads], MAX(T5_Deads) AS [T5 Deads], MAX(KVK_START_SCANORDER) AS SCANORDER
    INTO #HD1
    FROM dbo.HoH_Deads
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 9. Dynamic final table (typed columns!)
    -----------------------------------------------
    DECLARE @ExcelTbl       sysname       = N'EXCEL_FOR_KVK_' + CAST(@KVK AS nvarchar(10));
    DECLARE @TargetsTbl     sysname       = N'TARGETS_'       + CAST(@KVK AS nvarchar(10));
    DECLARE @ExcelTblFull   nvarchar(260) = QUOTENAME('dbo') + N'.' + QUOTENAME(@ExcelTbl);
    DECLARE @TargetsTblFull nvarchar(260) = QUOTENAME('dbo') + N'.' + QUOTENAME(@TargetsTbl);

    DECLARE @sql nvarchar(max) = N'';

    SET @sql += N'DROP TABLE IF EXISTS ' + @ExcelTblFull + N';' + CHAR(10);

    SET @sql += N'
    SELECT TOP (5000)
        S.[PowerRank]                                                AS [Rank],
        CAST(ROW_NUMBER() OVER (ORDER BY D.[DKP_SCORE] DESC) AS int) AS [KVK_RANK],
        S.[GovernorID]                                               AS [Gov_ID],
        CAST(S.[GovernorName] AS nvarchar(255))                      AS [Governor_Name],

        CAST(S.[Power] AS bigint)                                    AS [Starting Power],
        CAST(S.Power_Delta AS bigint)                                AS [Power_Delta],

        CAST(S.[Civilization] AS nvarchar(100))                      AS [Civilization],
        CAST(S.[KvKPlayed] AS int)                                   AS [KvKPlayed],
        CAST(S.[MostKvKKill] AS bigint)                              AS [MostKvKKill],
        CAST(S.[MostKvKDead] AS bigint)                              AS [MostKvKDead],
        CAST(S.[MostKvKHeal] AS bigint)                              AS [MostKvKHeal],
        CAST(S.[Acclaim] AS bigint)                                  AS [Acclaim],
        CAST(S.[HighestAcclaim] AS bigint)                           AS [HighestAcclaim],
        CAST(S.[AOOJoined] AS bigint)                                AS [AOOJoined],
        CAST(S.[AOOWon] AS int)                                      AS [AOOWon],
        CAST(S.[AOOAvgKill] AS bigint)                               AS [AOOAvgKill],
        CAST(S.[AOOAvgDead] AS bigint)                               AS [AOOAvgDead],
        CAST(S.[AOOAvgHeal] AS bigint)                               AS [AOOAvgHeal],
        CAST(S.[Conduct] AS decimal(5,2))                             AS [Conduct],

        CAST(S.[Starting_T4&T5_KILLS] AS bigint)                     AS [Starting_T4&T5_KILLS],
        CAST(S.[T4KillsDelta] AS bigint)                             AS [T4_KILLS],
        CAST(S.[T5KillsDelta] AS bigint)                             AS [T5_KILLS],
        CAST(S.[T4&T5_KILLSDelta] AS bigint)                         AS [T4&T5_Kills],
        CAST(S.KILLS_OUTSIDE_KVK AS bigint)                          AS [KILLS_OUTSIDE_KVK],

        CAST(T.[Kill_Target] AS bigint)                                 AS [Kill Target],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE ROUND( (CAST(S.[T4&T5_KILLSDelta] AS decimal(19,2)) / CAST(T.[Kill_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Kill Target],

        CAST(S.[Starting_Deads] AS bigint)                           AS [Starting_Deads],
        CAST(S.[DeadsDelta] AS bigint)                               AS [Deads_Delta],
        CAST(S.DEADS_OUTSIDE_KVK AS bigint)                          AS [DEADS_OUTSIDE_KVK],

        CAST(COALESCE(HD.[T4 Deads], 0) AS bigint)                   AS [T4_Deads],
        CAST(COALESCE(HD.[T5 Deads], 0) AS bigint)                   AS [T5_Deads],

        CAST(T.[Dead_Target] AS bigint)                                 AS [Dead_Target],
        CAST(
            CASE
                WHEN T.[Dead_Target] = 0 THEN 0
                WHEN Z.GovernorID = S.GovernorID
                    THEN ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) * 0.1 / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
                ELSE ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Dead Target],

        CAST(Z.Zeroed AS bit)                                        AS [Zeroed],

        CAST(D.[DKP_SCORE] AS bigint)                                AS [DKP_SCORE],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE (CAST(T.Kill_Target AS bigint) * 3 + CAST(T.Dead_Target AS bigint) * 8)
            END
            AS bigint
        )                                                            AS [DKP Target],

        CAST(
            CASE
                WHEN (CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) = 0 THEN 0
                ELSE ROUND(
                    (CAST(D.[DKP_SCORE] AS decimal(19,2)) /
                     CAST((CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) AS decimal(19,2))) * 100,
                    2
                )
            END
            AS decimal(9,2)
        )                                                            AS [% of DKP Target],

        CAST(S.[HelpsDelta] AS bigint)                               AS [HelpsDelta],
        CAST(S.[RSSASSISTDelta] AS bigint)                           AS [RSS_Assist_Delta],
        CAST(S.[RSSGatheredDelta] AS bigint)                         AS [RSS_Gathered_Delta],

        CAST(S.[P4T4&T5_KillsDelta] AS bigint)                       AS [Pass 4 Kills],
        CAST(S.[P6T4&T5_KillsDelta] AS bigint)                       AS [Pass 6 Kills],
        CAST(S.[P7T4&T5_KillsDelta] AS bigint)                       AS [Pass 7 Kills],
        CAST(S.[P8T4&T5_KillsDelta] AS bigint)                       AS [Pass 8 Kills],

        CAST(S.P4DeadsDelta AS bigint)                               AS [Pass 4 Deads],
        CAST(S.P6DeadsDelta AS bigint)                               AS [Pass 6 Deads],
        CAST(S.P7DeadsDelta AS bigint)                               AS [Pass 7 Deads],
        CAST(S.P8DeadsDelta AS bigint)                               AS [Pass 8 Deads],

        CAST(S.[HealedTroops] AS bigint)                             AS [Starting_HealedTroops],
        CAST(S.[HealedTroopsDelta] AS bigint)                        AS [HealedTroopsDelta],

        CAST(S.[KillPoints] AS bigint)                               AS [Starting_KillPoints],
        CAST(S.[KillPointsDelta] AS bigint)                          AS [KillPointsDelta],

        CAST(S.[RangedPoints] AS bigint)                             AS [RangedPoints],
        CAST(S.[RangedPointsDelta] AS bigint)                        AS [RangedPointsDelta],

        CAST(S.[AutarchTimes] AS bigint)                             AS [AutarchTimes],

        CAST(S.[MaxPreKvkPoints] AS bigint)                          AS [Max_PreKvk_Points],
        CAST(S.[MaxHonorPoints] AS bigint)                           AS [Max_HonorPoints],
        CAST(S.[PreKvkRank] AS bigint)                               AS [PreKvk_Rank],
        CAST(S.[HonorRank] AS bigint)                                AS [Honor_Rank],

        CAST(@pKVK AS int)                                           AS [KVK_NO]
    INTO ' + @ExcelTblFull + N'
    FROM dbo.STAGING_STATS AS S
    LEFT JOIN #HD1  AS HD ON S.GovernorID = HD.GovernorID
    LEFT JOIN ' + @TargetsTblFull + N' AS T ON T.GovernorID = S.GovernorID
    LEFT JOIN #DKP  AS D  ON D.GovernorID = S.GovernorID
    LEFT JOIN dbo.ZEROED AS Z ON Z.GovernorID = S.GovernorID AND Z.ScanOrder = @pScan
    ORDER BY S.PowerRank ASC;';

	IF CHARINDEX(N'COALESCE(HD.[T4 Deads]', @sql) = 0
	BEGIN
		RAISERROR('HD reference missing from SQL string (string likely broken).',16,1);
	END

    EXEC sp_executesql
        @sql,
        N'@pScan int, @pKVK int',
        @pScan = @Scan,
        @pKVK  = @KVK;

	-- Call index creation procedure with BOTH parameters
	EXEC dbo.sp_Create_Excel_For_Kvk_Indexes @FullTableName = @ExcelTblFull, @TableBase = @ExcelTbl;

	-- ✅ NEW: Update statistics for optimal query performance
    DECLARE @UpdateStatsSQL NVARCHAR(MAX) = N'UPDATE STATISTICS ' + @ExcelTblFull + N' WITH FULLSCAN;';
    EXEC sp_executesql @UpdateStatsSQL;
    PRINT 'Updated statistics on ' + @ExcelTblFull + ' with FULLSCAN';

    DROP TABLE IF EXISTS #DKP, #HD1;

    EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;
    EXEC dbo.usp_RecordKvkFinalReportCompletion
        @KVKNo = @KVK,
        @FinalScanOrder = @LatestScanToUse,
        @FinalizationBasis = N'LIVE_OUTPUT';

	        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    PRINT 'Completed KVK ' + CAST(@KVK AS varchar(10))
        + ' with ScanOrder=' + CAST(@Scan AS varchar(20))
        + ', LatestScanUsed=' + CAST(@LatestScanToUse AS varchar(20))
        + ' at ' + CONVERT(varchar, GETDATE(), 120);
END
GO
-- Source: sql_schema/dbo.sp_Rebuild_ExcelForDashboard.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_Rebuild_ExcelForDashboard]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = N'';
    DECLARE @unionSql NVARCHAR(MAX) = N'';
    DECLARE @KVK INT;
    DECLARE @MaxScan INT;
    DECLARE @TableName SYSNAME;

    -- Determine latest scan order for eligibility checks
    SELECT @MaxScan = MAX(SCANORDER) FROM dbo.KingdomScanData4;

    ----------------------------------------------------------------
    -- Build dynamic UNION of EXCEL_FOR_KVK_<KVK> tables that are eligible
    -- Eligible KVK versions are those with a MATCHMAKING_SCAN value in ProcConfig
    -- smaller than the current max scanorder.
    ----------------------------------------------------------------
    DECLARE cur CURSOR FOR
    SELECT DISTINCT KVKVersion
    FROM dbo.ProcConfig
    WHERE ConfigKey = 'MATCHMAKING_SCAN'
      AND TRY_CAST(ConfigValue AS INT) < ISNULL(@MaxScan, 0)
    ORDER BY KVKVersion DESC;

    OPEN cur;
    FETCH NEXT FROM cur INTO @KVK;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @TableName = N'EXCEL_FOR_KVK_' + CAST(@KVK AS NVARCHAR(10));

        IF OBJECT_ID(QUOTENAME(N'dbo') + N'.' + QUOTENAME(@TableName), N'U') IS NOT NULL
        BEGIN
            SET @unionSql +=
                CASE
                    WHEN LEN(ISNULL(@unionSql, N'')) = 0
                        THEN N''
                    ELSE N'
            UNION ALL
'
                END
                + N'
            SELECT
                CAST([Rank] AS int) AS [Rank],
                CAST([KVK_RANK] AS int) AS [KVK_RANK],
                CAST([Gov_ID] AS bigint) AS [Gov_ID],
                CAST([Governor_Name] AS nvarchar(255)) AS [Governor_Name],
                CAST([Starting Power] AS bigint) AS [Starting Power],
                CAST([Power_Delta] AS bigint) AS [Power_Delta],
                CAST([Civilization] AS nvarchar(100)) AS [Civilization],
                CAST([KvKPlayed] AS int) AS [KvKPlayed],
                CAST([MostKvKKill] AS bigint) AS [MostKvKKill],
                CAST([MostKvKDead] AS bigint) AS [MostKvKDead],
                CAST([MostKvKHeal] AS bigint) AS [MostKvKHeal],
                CAST([Acclaim] AS bigint) AS [Acclaim],
                CAST([HighestAcclaim] AS bigint) AS [HighestAcclaim],
                CAST([AOOJoined] AS bigint) AS [AOOJoined],
                CAST([AOOWon] AS int) AS [AOOWon],
                CAST([AOOAvgKill] AS bigint) AS [AOOAvgKill],
                CAST([AOOAvgDead] AS bigint) AS [AOOAvgDead],
                CAST([AOOAvgHeal] AS bigint) AS [AOOAvgHeal],
                CAST([Conduct] AS decimal(5,2)) AS [Conduct],
                CAST([Starting_T4&T5_KILLS] AS bigint) AS [Starting_T4&T5_KILLS],
                CAST([T4_KILLS] AS bigint) AS [T4_KILLS],
                CAST([T5_KILLS] AS bigint) AS [T5_KILLS],
                CAST([T4&T5_Kills] AS bigint) AS [T4&T5_Kills],
                CAST([KILLS_OUTSIDE_KVK] AS bigint) AS [KILLS_OUTSIDE_KVK],
                CAST([Kill Target] AS bigint) AS [Kill Target],
                CAST([% of Kill Target] AS decimal(9,2)) AS [% of Kill Target],
                CAST([Starting_Deads] AS bigint) AS [Starting_Deads],
                CAST([Deads_Delta] AS bigint) AS [Deads_Delta],
                CAST([DEADS_OUTSIDE_KVK] AS bigint) AS [DEADS_OUTSIDE_KVK],
                CAST([T4_Deads] AS bigint) AS [T4_Deads],
                CAST([T5_Deads] AS bigint) AS [T5_Deads],
                CAST([Dead_Target] AS bigint) AS [Dead_Target],
                CAST([% of Dead Target] AS decimal(9,2)) AS [% of Dead Target],
                CAST([Zeroed] AS bit) AS [Zeroed],
                CAST([DKP_SCORE] AS bigint) AS [DKP_SCORE],
                CAST([DKP Target] AS bigint) AS [DKP Target],
                CAST([% of DKP Target] AS decimal(9,2)) AS [% of DKP Target],
                CAST([HelpsDelta] AS bigint) AS [HelpsDelta],
                CAST([RSS_Assist_Delta] AS bigint) AS [RSS_Assist_Delta],
                CAST([RSS_Gathered_Delta] AS bigint) AS [RSS_Gathered_Delta],
                CAST([Pass 4 Kills] AS bigint) AS [Pass 4 Kills],
                CAST([Pass 6 Kills] AS bigint) AS [Pass 6 Kills],
                CAST([Pass 7 Kills] AS bigint) AS [Pass 7 Kills],
                CAST([Pass 8 Kills] AS bigint) AS [Pass 8 Kills],
                CAST([Pass 4 Deads] AS bigint) AS [Pass 4 Deads],
                CAST([Pass 6 Deads] AS bigint) AS [Pass 6 Deads],
                CAST([Pass 7 Deads] AS bigint) AS [Pass 7 Deads],
                CAST([Pass 8 Deads] AS bigint) AS [Pass 8 Deads],
                CAST([Starting_HealedTroops] AS bigint) AS [Starting_HealedTroops],
                CAST([HealedTroopsDelta] AS bigint) AS [HealedTroopsDelta],
                CAST([Starting_KillPoints] AS bigint) AS [Starting_KillPoints],
                CAST([KillPointsDelta] AS bigint) AS [KillPointsDelta],
                CAST([RangedPoints] AS bigint) AS [RangedPoints],
                CAST([RangedPointsDelta] AS bigint) AS [RangedPointsDelta],
                CAST([AutarchTimes] AS bigint) AS [AutarchTimes],
                CAST([Max_PreKvk_Points] AS bigint) AS [Max_PreKvk_Points],
                CAST([Max_HonorPoints] AS bigint) AS [Max_HonorPoints],
                CAST([PreKvk_Rank] AS bigint) AS [PreKvk_Rank],
                CAST([Honor_Rank] AS bigint) AS [Honor_Rank],
                CAST([KVK_NO] AS int) AS [KVK_NO]
            FROM dbo.' + QUOTENAME(@TableName);
        END

        FETCH NEXT FROM cur INTO @KVK;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -- If there are eligible KVK tables, build the EXCEL_FOR_DASHBOARD as a union of them
    IF LEN(ISNULL(@unionSql, '')) > 0
    BEGIN
        SET @sql = N'
        IF OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'', ''U'') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        SELECT TOP (50000000)
               T.*,
               T.[% of Dead Target] AS [% of Dead_Target]  -- alias for compatibility
        INTO dbo.EXCEL_FOR_DASHBOARD
        FROM (
            ' + @unionSql + '
        ) AS T
        ORDER BY KVK_NO, [RANK];
        ';

        EXEC sp_executesql @sql;

        PRINT 'Rebuilt EXCEL_FOR_DASHBOARD by unioning per-KVK tables with explicit columns.';
    END
    ELSE
    BEGIN
        PRINT 'No eligible KVK tables found based on MATCHMAKING_SCAN and Max SCANORDER.';
    END
END
GO
-- Source: sql_schema/dbo.sp_TARGETS_MASTER.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_TARGETS_MASTER]
	@KVK [int] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    PRINT N'DBG: sp_TARGETS_MASTER start';
    SET ANSI_WARNINGS OFF;

    -- Log the mode (full vs incremental)
    IF @KVK IS NULL
        PRINT N'MODE: Full refresh (all KVKs)';
    ELSE
        PRINT CONCAT('MODE: Incremental refresh (KVK ', CAST(@KVK AS NVARCHAR(20)), ' only)');

    BEGIN TRY
        -- Defensive cursor cleanup (handles both local/global)
        IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END
        IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;

        DECLARE @Now DATETIME = GETDATE()
              , @ConfiguredScan INT
              , @DraftScan INT
              , @MaxAvailableScan INT
              , @Scan INT;

        -- Build the KVK list from ANY of the two keys so we don't miss ones with only DRAFTSCAN
        -- Filter by @KVK parameter if provided
        DECLARE kvk_cursor_master CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT KVKVersion
            FROM dbo.ProcConfig
            WHERE ConfigKey IN ('MATCHMAKING_SCAN','DRAFTSCAN')
              AND (@KVK IS NULL OR KVKVersion = @KVK)  -- Filter by specific KVK if provided
            ORDER BY KVKVersion;

        -- Create delta tables once
		SET ANSI_WARNINGS ON;
        PRINT N'Calling CREATE_DELTA_TABLES';
        EXEC dbo.CREATE_DELTA_TABLES;
		SET ANSI_WARNINGS OFF;

        OPEN kvk_cursor_master;
        FETCH NEXT FROM kvk_cursor_master INTO @KVK;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT CONCAT('Processing KVKVersion: ', CAST(@KVK AS NVARCHAR(20)));

            -- Pull config values
            SELECT @ConfiguredScan = NULL, @DraftScan = NULL;

            SELECT @ConfiguredScan = TRY_CONVERT(INT, pc.ConfigValue)
            FROM dbo.ProcConfig pc
            WHERE pc.KVKVersion = @KVK AND pc.ConfigKey = 'MATCHMAKING_SCAN';

            SELECT @DraftScan = TRY_CONVERT(INT, pc.ConfigValue)
            FROM dbo.ProcConfig pc
            WHERE pc.KVKVersion = @KVK AND pc.ConfigKey = 'DRAFTSCAN';

            -- Current data ceiling
            SELECT @MaxAvailableScan = MAX(ScanOrder)
            FROM dbo.KingdomScanData4;

            IF @MaxAvailableScan IS NULL
            BEGIN
                PRINT CONCAT('WARN: No scan data in KingdomScanData4; skipping KVK ', CAST(@KVK AS NVARCHAR(20)));
                GOTO NextKVK;
            END

            -- Choose the scan to use:
            IF @ConfiguredScan IS NOT NULL AND @ConfiguredScan <= @MaxAvailableScan
            BEGIN
                SET @Scan = @ConfiguredScan;
                PRINT CONCAT('Using MATCHMAKING_SCAN (', CAST(@Scan AS VARCHAR(30)), ') for KVK ', CAST(@KVK AS NVARCHAR(20)));
            END
            ELSE IF @DraftScan IS NOT NULL
            BEGIN
                SET @Scan = CASE WHEN @DraftScan <= @MaxAvailableScan THEN @DraftScan ELSE @MaxAvailableScan END;
                PRINT CONCAT('Using DRAFTSCAN (', CAST(@DraftScan AS VARCHAR(30)), ' -> applied ', CAST(@Scan AS VARCHAR(30)), ') for KVK ', CAST(@KVK AS NVARCHAR(20)));
            END
            ELSE
            BEGIN
                PRINT CONCAT('WARN: Neither MATCHMAKING_SCAN nor DRAFTSCAN set; skipping KVK ', CAST(@KVK AS NVARCHAR(20)));
                GOTO NextKVK;
            END

            PRINT CONCAT('Processing KVK ', CAST(@KVK AS VARCHAR(20)), ' with SCANORDER = ', CAST(@Scan AS VARCHAR(30)));

            -- Per-KVK pipeline (local TRY/CATCHs keep errors informative)
            BEGIN TRY
                EXEC dbo.sp_Prep_TargetTable @KVK, @Scan;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('ERR: sp_Prep_TargetTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                THROW;
            END CATCH

            BEGIN TRY
                EXEC dbo.sp_ExcelOutput_ByKVK @KVK, @Scan;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('ERR: sp_ExcelOutput_ByKVK failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                THROW;
            END CATCH

            BEGIN TRY
                EXEC dbo.sp_Prep_ExcelOutputTable @KVK, @Scan;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('ERR: sp_Prep_ExcelOutputTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                THROW;
            END CATCH

            BEGIN TRY
                EXEC dbo.sp_Prep_ExcelExportTable @KVK;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('ERR: sp_Prep_ExcelExportTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                THROW;
            END CATCH

            NextKVK:
            FETCH NEXT FROM kvk_cursor_master INTO @KVK;
        END

        -- Safe cursor cleanup
        IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END
        IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END

        -------------------------------------------------------------------
        -- Create/refresh v_TARGETS_FOR_UPLOAD pointing at latest KVK export
        -------------------------------------------------------------------
        DECLARE @LatestKVK int;

        ;WITH src AS (
            SELECT kvk = TRY_CAST(REPLACE(t.name, 'EXCEL_EXPORT_KVK_TARGETS_', '') AS int)
            FROM sys.tables AS t
            WHERE t.name LIKE 'EXCEL_EXPORT_KVK_TARGETS[_]%'  -- escape underscore
              AND t.schema_id = SCHEMA_ID('dbo')
        )
        SELECT @LatestKVK = MAX(kvk) FROM src;

        PRINT CONCAT('LatestKVK = ', ISNULL(CAST(@LatestKVK AS nvarchar(10)), '(null)'));

        IF @LatestKVK IS NULL
        BEGIN
            PRINT N'WARN: No EXCEL_EXPORT_KVK_TARGETS_xx tables found. Skipping v_TARGETS_FOR_UPLOAD refresh.';
        END
        ELSE
        BEGIN
            DECLARE @plainName nvarchar(128) = N'dbo.EXCEL_EXPORT_KVK_TARGETS_' + CAST(@LatestKVK AS nvarchar(10));
            DECLARE @srcQuoted sysname = QUOTENAME('dbo') + N'.' + QUOTENAME('EXCEL_EXPORT_KVK_TARGETS_' + CAST(@LatestKVK AS nvarchar(10)));
            DECLARE @sql nvarchar(max);

            IF OBJECT_ID(@plainName, 'U') IS NULL
            BEGIN
                PRINT CONCAT('WARN: Expected table ', @plainName, ' does not exist. Skipping v_TARGETS_FOR_UPLOAD refresh.');
            END
            ELSE
            BEGIN
                IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', 'V') IS NOT NULL
                    DROP VIEW dbo.v_TARGETS_FOR_UPLOAD;
                IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', 'U') IS NOT NULL
                    DROP TABLE dbo.v_TARGETS_FOR_UPLOAD;

                SET @sql = N'CREATE VIEW dbo.v_TARGETS_FOR_UPLOAD AS SELECT * FROM ' + @srcQuoted + N';';
                PRINT N'About to execute dynamic SQL to create view:';
                PRINT @sql;

                BEGIN TRY
                    EXEC sys.sp_executesql @sql;
                    PRINT CONCAT('v_TARGETS_FOR_UPLOAD now points at ', @srcQuoted);
                END TRY
                BEGIN CATCH
                    DECLARE @dynMsg nvarchar(4000) = ERROR_MESSAGE();
                    DECLARE @dynLine int = ERROR_LINE();
                    DECLARE @fullMsg nvarchar(4000) = N'sp_TARGETS_MASTER: dynamic CREATE VIEW failed for ' + @srcQuoted + N': ' + ISNULL(@dynMsg, N'(no message)');
                    PRINT N'ERROR: ' + @fullMsg + N' (line ' + CAST(ISNULL(@dynLine,0) AS nvarchar(10)) + N')';
                    RAISERROR(@fullMsg, 16, 1);
                END CATCH
            END
        END

        SET ANSI_WARNINGS ON;
        PRINT N'DBG: sp_TARGETS_MASTER complete';
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END
        IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END

        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrProc SYSNAME = ERROR_PROCEDURE();
        DECLARE @ErrLine INT = ERROR_LINE();

        PRINT CONCAT(N'ERROR in sp_TARGETS_MASTER: ', ISNULL(@ErrProc, N'(no procedure)'), N' line ', CAST(ISNULL(@ErrLine, 0) AS NVARCHAR(10)), N': ', ISNULL(@ErrMsg, N'(no message)'));

        THROW;
    END CATCH
END
GO
-- Source: sql_schema/dbo.SUMMARY_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'SummaryExport';
    DECLARE @MinLastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    SELECT @MinLastProcessed = MIN(ISNULL(LastScanOrder, 0))
    FROM dbo.SUMMARY_PROC_STATE
    WHERE MetricName IN (
        N'Deads',
        N'Power',
        N'T4T5Kills',
        N'T4Kills',
        N'T5Kills',
        N'KillPoints',
        N'HealedTroops',
        N'RangedPoints'
    );

    IF @MinLastProcessed IS NULL SET @MinLastProcessed = 0;

    SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
    FROM dbo.KingdomScanData4;

    IF @MaxScan <= @MinLastProcessed
    BEGIN
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF OBJECT_ID('tempdb..#SummaryRunState') IS NOT NULL DROP TABLE #SummaryRunState;
        CREATE TABLE #SummaryRunState
        (
            MaxScan INT NOT NULL,
            MinLastProcessed INT NOT NULL
        );

        INSERT INTO #SummaryRunState (MaxScan, MinLastProcessed)
        VALUES (@MaxScan, @MinLastProcessed);

        IF OBJECT_ID('tempdb..#AffectedGovs') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @MinLastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID('tempdb..#GovScan') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops,
            ks4.Deads,
            ks4.KillPoints,
            ks4.[T4&T5_KILLS],
            ks4.[T4_KILLS],
            ks4.[T5_KILLS],
            ks4.[POWER],
            ks4.RangedPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        -- Execute dependent procedures (shared temp tables visible)
        EXEC dbo.DEADSSUMMARY_PROC;
        EXEC dbo.POWERSUMMARY_PROC;
        EXEC dbo.KILLSSUMMARY_PROC;
        EXEC dbo.KT4SUMMARY_PROC;
        EXEC dbo.KT5SUMMARY_PROC;
        EXEC dbo.KILLPOINTSSUMMARY_PROC;
        EXEC dbo.HEALEDSUMMARY_PROC;
        EXEC dbo.RANGEDSUMMARY_PROC;

        -- Clear export table
        TRUNCATE TABLE dbo.SUMMARY_CHANGE_EXPORT;

        -- Insert combined summary data
        INSERT INTO dbo.SUMMARY_CHANGE_EXPORT
        (
            GOVERNORID,
            GOVERNORNAME,
            [T4&T5_KILLS],
            [StartingT4&T5_KILLS],
            [OverallT4&T5_KILLSDelta],
            [T4&T5_KILLSDelta12Months],
            [T4&T5_KILLSDelta6Months],
            [T4&T5_KILLSDelta3Months],
            [T4_KILLS],
            [StartingT4_KILLS],
            [OverallT4_KILLSDelta],
            [T4_KILLSDelta12Months],
            [T4_KILLSDelta6Months],
            [T4_KILLSDelta3Months],
            [T5_KILLS],
            [StartingT5_KILLS],
            [OverallT5_KILLSDelta],
            [T5_KILLSDelta12Months],
            [T5_KILLSDelta6Months],
            [T5_KILLSDelta3Months],
            [POWER],
            StartingPower,
            OverallPowerDelta,
            PowerDelta12Months,
            PowerDelta6Months,
            PowerDelta3Months,
            DEADS,
            StartingDEADS,
            OverallDEADSDelta,
            DEADSDelta12Months,
            DEADSDelta6Months,
            DEADSDelta3Months,
            HealedTroops,
            StartingHealed,
            OverallHealedDelta,
            HealedDelta12Months,
            HealedDelta6Months,
            HealedDelta3Months,
            RangedPoints,
            StartingRanged,
            OverallRangedDelta,
            RangedDelta12Months,
            RangedDelta6Months,
            RangedDelta3Months,
            KillPoints,
            StartingKillPoints,
            OverallKillPointsDelta,
            KillPointsDelta12Months,
            KillPointsDelta6Months,
            KillPointsDelta3Months
        )
        SELECT
            P.GOVERNORID,
            P.GOVERNORNAME,
            K.[T4&T5_KILLS],
            K.[StartingT4&T5_KILLS],
            K.[OverallT4&T5_KILLSDelta],
            K.[T4&T5_KILLSDelta12Months],
            K.[T4&T5_KILLSDelta6Months],
            K.[T4&T5_KILLSDelta3Months],
            K4.[T4_KILLS],
            K4.[StartingT4_KILLS],
            K4.[OverallT4_KILLSDelta],
            K4.[T4_KILLSDelta12Months],
            K4.[T4_KILLSDelta6Months],
            K4.[T4_KILLSDelta3Months],
            K5.[T5_KILLS],
            K5.[StartingT5_KILLS],
            K5.[OverallT5_KILLSDelta],
            K5.[T5_KILLSDelta12Months],
            K5.[T5_KILLSDelta6Months],
            K5.[T5_KILLSDelta3Months],
            P.[POWER],
            P.StartingPower,
            P.OverallPowerDelta,
            P.PowerDelta12Months,
            P.PowerDelta6Months,
            P.PowerDelta3Months,
            D.DEADS,
            D.StartingDEADS,
            D.OverallDEADSDelta,
            D.DEADSDelta12Months,
            D.DEADSDelta6Months,
            D.DEADSDelta3Months,
            ISNULL(H.HealedTroops, 0),
            ISNULL(H.StartingHealed, 0),
            ISNULL(H.OverallHealedDelta, 0),
            ISNULL(H.HealedDelta12Months, 0),
            ISNULL(H.HealedDelta6Months, 0),
            ISNULL(H.HealedDelta3Months, 0),
            ISNULL(R.RangedPoints, 0),
            ISNULL(R.StartingRanged, 0),
            ISNULL(R.OverallRangedDelta, 0),
            ISNULL(R.RangedDelta12Months, 0),
            ISNULL(R.RangedDelta6Months, 0),
            ISNULL(R.RangedDelta3Months, 0),
            ISNULL(KP.KillPoints, 0),
            ISNULL(KP.StartingKillPoints, 0),
            ISNULL(KP.OverallKillPointsDelta, 0),
            ISNULL(KP.KillPointsDelta12Months, 0),
            ISNULL(KP.KillPointsDelta6Months, 0),
            ISNULL(KP.KillPointsDelta3Months, 0)
        FROM dbo.POWERSUMMARY AS P
        INNER JOIN dbo.KILL4SUMMARY AS K4 ON P.GOVERNORID = K4.GOVERNORID
        INNER JOIN dbo.KILL5SUMMARY AS K5 ON P.GOVERNORID = K5.GOVERNORID
        INNER JOIN dbo.KILLSUMMARY AS K ON P.GOVERNORID = K.GOVERNORID
        INNER JOIN dbo.DEADSSUMMARY AS D ON P.GOVERNORID = D.GOVERNORID
        INNER JOIN dbo.HEALEDSUMMARY AS H ON P.GOVERNORID = H.GOVERNORID
        INNER JOIN dbo.RANGEDSUMMARY AS R ON P.GOVERNORID = R.GOVERNORID
        INNER JOIN dbo.KILLPOINTSSUMMARY AS KP ON P.GOVERNORID = KP.GOVERNORID
        ORDER BY P.GOVERNORNAME;

        MERGE dbo.SUMMARY_PROC_STATE AS T
        USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
        ON T.MetricName = S.MetricName
        WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
        WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
        VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE
            @ErrorMessage NVARCHAR(4000),
            @ErrorSeverity INT,
            @ErrorState INT;

        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO
-- Source: sql_schema/dbo.TARGETS.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[TARGETS]
	@InputScanOrder [int] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY

        DECLARE @BAND1 FLOAT = 100000000,
                @BAND2 FLOAT = 90000000,
                @BAND3 FLOAT = 80000000,
                @BAND4 FLOAT = 70000000,
                @BAND5 FLOAT = 60000000,
                @BAND6 FLOAT = 50000000,
                @BAND7 FLOAT = 40000000,
                @MATCHMAKINGSCAN INT = ISNULL(@InputScanOrder, (SELECT MAX(SCANORDER) FROM KingdomScanData4));

        -- Clear previous target data
        TRUNCATE TABLE TARGETS_JUN25;

        -- Insert calculated targets
        INSERT INTO TARGETS_JUN25 (GovernorID, Kill_Target, Minimum_Kill_Target, Dead_Target)
        SELECT GovernorID,
               CASE
                   WHEN Power >= @BAND1 THEN 15000000
                   WHEN Power >= @BAND2 THEN 15000000
                   WHEN Power >= @BAND3 THEN 8000000
                   WHEN Power >= @BAND4 THEN 6000000
                   WHEN Power >= @BAND5 THEN 5000000
                   WHEN Power >= @BAND6 THEN 4000000
                   WHEN Power >= @BAND7 THEN 2500000
                   ELSE 0
               END AS Kill_Target,
               CASE
                   WHEN Power >= @BAND1 THEN 6000000
                   WHEN Power >= @BAND2 THEN 6000000
                   WHEN Power >= @BAND3 THEN 3000000
                   WHEN Power >= @BAND4 THEN 2000000
                   WHEN Power >= @BAND5 THEN 1000000
                   WHEN Power >= @BAND6 THEN 1000000
                   WHEN Power >= @BAND7 THEN 1000000
                   ELSE 0
               END AS Minimum_Kill_Target,
               CASE
                   WHEN Power >= @BAND1 THEN 1250000
                   WHEN Power >= @BAND2 THEN 1000000
                   WHEN Power >= @BAND3 THEN 800000
                   WHEN Power >= @BAND4 THEN 500000
                   WHEN Power >= @BAND5 THEN 500000
                   WHEN Power >= @BAND6 THEN 300000
                   WHEN Power >= @BAND7 THEN 300000
                   ELSE 0
               END AS Dead_Target
        FROM KingdomScanData4
        WHERE SCANORDER = @MATCHMAKINGSCAN;

        -- Prep staging table
        TRUNCATE TABLE EXCEL_OUTPUT_KVK_TARGETS_JUN25;

        -- Load power rankings into temp table
        SELECT GovernorID, GovernorName, Power, [Troops Power], [City Hall],
               [Tech Power], [Building Power], [Commander Power],
               ROW_NUMBER() OVER (ORDER BY Power DESC) AS PowerRank
        INTO #P
        FROM KingdomScanData4
        WHERE SCANORDER = @MATCHMAKINGSCAN
          AND GovernorID NOT IN (22345012, 46718337, 2510418, 83724180, 17868677, 12025033);

        -- Insert full KVK target view
        INSERT INTO EXCEL_OUTPUT_KVK_TARGETS_JUN25
        (
            [Rank],
            [RANK2],
            [Gov_ID],
            [Governor_Name],
            [Power],
            [City Hall],
            [Troops Power],
            [Tech Power],
            [Building Power],
            [Commander Power],
            [Kill Target],
            [Minimum Kill Target],
            [Dead Target],
            [DKP Target],
            [Kills Mar25 KVK],
            [DEADS Mar25 KVK],
            [DKP Mar25 KVK],
            [% DKP Target Mar25 KVK],
            [Kills Jan25 KVK],
            [DEADS Jan25 KVK],
            [DKP Jan25 KVK],
            [% DKP Target Jan25 KVK]
        )
        SELECT TOP 5000
               P.PowerRank AS Rank,
               ROW_NUMBER() OVER (ORDER BY P.Power DESC) AS RANK2,
               P.GovernorID AS Gov_ID,
               RTRIM(P.GovernorName) AS Governor_Name,
               FORMAT(P.Power, '#,###') AS Power,
               P.[City Hall],
               FORMAT(P.[Troops Power], '#,###') AS [Troops Power],
               FORMAT(P.[Tech Power], '#,###') AS [Tech Power],
               FORMAT(P.[Building Power], '#,###') AS [Building Power],
               FORMAT(P.[Commander Power], '#,###') AS [Commander Power],
               T.Kill_Target,
               T.Minimum_Kill_Target,
               T.Dead_Target,
               (T.Kill_Target * 3 + T.Dead_Target * 8) AS [DKP Target],
               LK.[t4&t5_kills], LK.deads, LK.dkp_score, LK.[% of DKP Target],
               JK.[t4&t5_kills], JK.deads, JK.dkp_score, JK.[% of DKP Target]
        FROM #P AS P
        JOIN TARGETS_JUN25 AS T ON T.GovernorID = P.GovernorID
        LEFT JOIN EXCEL_FOR_MAR25_KVK AS LK ON LK.Gov_ID = P.GovernorID
        LEFT JOIN EXCEL_FOR_JAN25_KVK AS JK ON JK.Gov_ID = P.GovernorID
        ORDER BY P.Power ASC;

        DROP TABLE IF EXISTS #P;

        -- Prepare export table
        TRUNCATE TABLE EXCEL_EXPORT_KVK_TARGETS_JUN25;

        -- Export top 350 to simplified table
        INSERT INTO EXCEL_EXPORT_KVK_TARGETS_JUN25
        SELECT TOP 350
               RANK2 AS [Rank],
               Gov_ID,
               Governor_Name,
               [Power],
               [City Hall] AS [CH],
               [Troops Power],
               [Tech Power],
               [Building Power],
               [Commander Power],
               '' AS B1,
               [Kill Target],
               [Minimum Kill Target],
               [Dead Target],
               [DKP Target],
               '' AS B2,
               [Kills Mar25 KVK],
               [DEADS Mar25 KVK],
               [DKP Mar25 KVK],
               [% DKP Target Mar25 KVK] AS [% DKP Mar25 KVK],
               '' AS B3,
               [Kills Jan25 KVK],
               [DEADS Jan25 KVK],
               [DKP Jan25 KVK],
               [% DKP Target Jan25 KVK] AS [% DKP Jan25 KVK]
        FROM EXCEL_OUTPUT_KVK_TARGETS_JUN25
        ORDER BY RANK2 ASC;

    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrState INT = ERROR_STATE();
        RAISERROR('TARGETS procedure failed: %s', @ErrSeverity, @ErrState, @ErrMsg);
    END CATCH
END
GO
-- Source: sql_schema/dbo.TARGETS_NEW.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[TARGETS_NEW]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Ensure any previously open cursor is cleaned up
        IF CURSOR_STATUS('global', 'kvk_cursor') >= -1
        BEGIN
            CLOSE kvk_cursor;
            DEALLOCATE kvk_cursor;
        END;

        DECLARE @KVK INT, @ScanOrder INT, @SQL NVARCHAR(MAX);

        DECLARE kvk_cursor CURSOR FOR
            SELECT DISTINCT KVKVersion
            FROM ProcConfig
            WHERE ConfigKey = 'MATHCHMAKING_SCAN';

        OPEN kvk_cursor;
        FETCH NEXT FROM kvk_cursor INTO @KVK;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @ScanOrder = ConfigValue
            FROM ProcConfig
            WHERE KVKVersion = @KVK AND ConfigKey = 'MATHCHMAKING_SCAN';

            DECLARE @Prev1 INT = @KVK - 1;
            DECLARE @Prev2 INT = @KVK - 2;
            DECLARE @ExportTable NVARCHAR(128) = 'EXCEL_EXPORT_KVK_TARGETS_' + CAST(@KVK AS VARCHAR);
            DECLARE @OutputTable NVARCHAR(128) = 'EXCEL_OUTPUT_KVK_TARGETS_' + CAST(@KVK AS VARCHAR);
            DECLARE @TargetTable NVARCHAR(128) = 'TARGETS_' + CAST(@KVK AS VARCHAR);
            DECLARE @Prev1Table NVARCHAR(128) = 'EXCEL_FOR_KVK_' + CAST(@Prev1 AS VARCHAR);
            DECLARE @Prev2Table NVARCHAR(128) = 'EXCEL_FOR_KVK_' + CAST(@Prev2 AS VARCHAR);
			DECLARE @Blank CHAR(1) = ' ';

            SET @SQL = '

IF OBJECT_ID(N''dbo.' + @TargetTable + ''') IS NULL
BEGIN
    SELECT GovernorID, CAST(0 AS INT) AS Kill_Target, CAST(0 AS INT) AS Minimum_Kill_Target, CAST(0 AS INT) AS Dead_Target
    INTO ' + @TargetTable + '
    FROM KingdomScanData4 WHERE 1 = 0;
END
ELSE
BEGIN
    TRUNCATE TABLE ' + @TargetTable + ';
END;

WITH BandMatch AS (
    SELECT d.GovernorID, d.Power, kb.KillTarget, kb.MinKillTarget, kb.DeadTarget,
           ROW_NUMBER() OVER (PARTITION BY d.GovernorID ORDER BY kb.MinPower DESC) AS rn
    FROM KingdomScanData4 d
    JOIN KVKTargetBands kb ON kb.KVKVersion = ' + CAST(@KVK AS VARCHAR) + ' AND d.Power >= kb.MinPower
    WHERE d.SCANORDER = @Scan
)
INSERT INTO ' + @TargetTable + ' (GovernorID, Kill_Target, Minimum_Kill_Target, Dead_Target)
SELECT GovernorID, KillTarget, MinKillTarget, DeadTarget
FROM BandMatch WHERE rn = 1;

IF OBJECT_ID(N''dbo.' + @OutputTable + ''') IS NOT NULL
BEGIN
    DROP TABLE ' + @OutputTable + ';
END;

SELECT TOP 0
    CAST(NULL AS INT) AS Rank,
    CAST(NULL AS INT) AS RANK2,
    CAST(NULL AS BIGINT) AS Gov_ID,
    CAST(NULL AS NVARCHAR(100)) AS Governor_Name,
    CAST(NULL AS NVARCHAR(100)) AS Power,
    CAST(NULL AS INT) AS [City Hall],
    CAST(NULL AS NVARCHAR(100)) AS [Troops Power],
    CAST(NULL AS NVARCHAR(100)) AS [Tech Power],
    CAST(NULL AS NVARCHAR(100)) AS [Building Power],
    CAST(NULL AS NVARCHAR(100)) AS [Commander Power],
    CAST(NULL AS INT) AS Kill_Target,
    CAST(NULL AS INT) AS Minimum_Kill_Target,
    CAST(NULL AS INT) AS Dead_Target,
    CAST(NULL AS INT) AS [DKP Target],
    CAST(NULL AS INT) AS [Kills KVK ' + CAST(@Prev1 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [DEADS KVK ' + CAST(@Prev1 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [DKP KVK ' + CAST(@Prev1 AS VARCHAR) + '],
    CAST(NULL AS FLOAT) AS [% DKP Target KVK ' + CAST(@Prev1 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [Kills KVK ' + CAST(@Prev2 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [DEADS KVK ' + CAST(@Prev2 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [DKP KVK ' + CAST(@Prev2 AS VARCHAR) + '],
    CAST(NULL AS FLOAT) AS [% DKP Target KVK ' + CAST(@Prev2 AS VARCHAR) + ']
INTO ' + @OutputTable + ';

IF OBJECT_ID(N''dbo.' + @ExportTable + ''') IS NULL
BEGIN
    SELECT * INTO ' + @ExportTable + ' FROM EXCEL_EXPORT_KVK_TARGETS_TEMPLATE WHERE 1 = 0;
END
ELSE
BEGIN
    TRUNCATE TABLE ' + @ExportTable + ';
END;

INSERT INTO ' + @OutputTable + '
SELECT TOP 5000
       P.PowerRank AS Rank,
       ROW_NUMBER() OVER (ORDER BY P.Power DESC) AS RANK2,
       P.GovernorID AS Gov_ID,
       RTRIM(P.GovernorName) AS Governor_Name,
       FORMAT(P.Power, ''#,###'') AS Power,
       P.[City Hall],
       FORMAT(P.[Troops Power], ''#,###'') AS [Troops Power],
       FORMAT(P.[Tech Power], ''#,###'') AS [Tech Power],
       FORMAT(P.[Building Power], ''#,###'') AS [Building Power],
       FORMAT(P.[Commander Power], ''#,###'') AS [Commander Power],
       T.Kill_Target,
       T.Minimum_Kill_Target,
       T.Dead_Target,
       (T.Kill_Target * 3 + T.Dead_Target * 8) AS [DKP Target],
       LK.[t4&t5_kills] AS [Kills KVK ' + CAST(@Prev1 AS VARCHAR) + '],
	   LK.deads AS [DEADS KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       LK.dkp_score AS [DKP KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       LK.[% of DKP Target] AS [% DKP Target KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       JK.[t4&t5_kills] AS [Kills KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       JK.deads AS [DEADS KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       JK.dkp_score AS [DKP KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       JK.[% of DKP Target] AS [% DKP Target KVK ' + CAST(@Prev2 AS VARCHAR) + ']
FROM (
    SELECT GovernorID, GovernorName, Power, [Troops Power], [City Hall],
           [Tech Power], [Building Power], [Commander Power],
           ROW_NUMBER() OVER (ORDER BY Power DESC) AS PowerRank
    FROM KingdomScanData4
    WHERE SCANORDER = @Scan
      AND GovernorID NOT IN (22345012, 46718337, 2510418, 83724180, 17868677, 12025033)
) AS P
JOIN ' + @TargetTable + ' AS T ON T.GovernorID = P.GovernorID
LEFT JOIN ' + @Prev1Table + ' AS LK ON LK.Gov_ID = P.GovernorID
LEFT JOIN ' + @Prev2Table + ' AS JK ON JK.Gov_ID = P.GovernorID
ORDER BY RANK2 ASC;

INSERT INTO ' + @ExportTable + '
SELECT TOP 350
       RANK2 AS [Rank],
       Gov_ID,
       Governor_Name,
       [Power],
       [City Hall],
       [Troops Power],
       [Tech Power],
       [Building Power],
       [Commander Power],
       @Blank AS [BLANK1],
       [Kill Target],
       [Minimum Kill Target],
       [Dead Target],
       [DKP Target],
       @Blank AS [BLANK2],
       [Kills KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       [DEADS KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       [DKP KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       [% DKP Target KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       @Blank AS [BLANK3],
       [Kills KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       [DEADS KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       [DKP KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       [% DKP Target KVK ' + CAST(@Prev2 AS VARCHAR) + ']
FROM ' + @OutputTable + '
ORDER BY RANK2 ASC;
';

    DECLARE @Params NVARCHAR(MAX) = N'@Scan INT';
	PRINT @SQL
EXEC sp_executesql @SQL, @Params, @Scan = @ScanOrder;
            FETCH NEXT FROM kvk_cursor INTO @KVK;
        END

        CLOSE kvk_cursor;
        DEALLOCATE kvk_cursor;

    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'kvk_cursor') >= -1
        BEGIN
            CLOSE kvk_cursor;
            DEALLOCATE kvk_cursor;
        END;
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR('TARGETS procedure failed: %s', 16, 1, @ErrMsg);
    END CATCH
END
GO
-- Source: sql_schema/dbo.TEST.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[TEST]
WITH EXECUTE AS CALLER
AS
BEGIN


    SELECT GovernorID,
			GovernorName,
           [DEADS],
		   ScanDate,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER ASC) AS RowAscALL,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER DESC) AS RowDescALL
		   INTO DALL
    FROM KingdomScanData4
	ORDER BY GovernorID

	SELECT GovernorID,
           [DEADS],
		   ScanDate,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER ASC) AS RowAsc12,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER DESC) AS RowDesc12
		   INTO D12
    FROM KingdomScanData4
	WHERE SCANDATE >= DATEADD(month, -12, GETDATE())


	SELECT GovernorID,
           [DEADS],
		   ScanDate,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER ASC) AS RowAsc6,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER DESC) AS RowDesc6
		   INTO D6
    FROM KingdomScanData4
	WHERE SCANDATE >= DATEADD(month, -6, GETDATE())

	SELECT GovernorID,
           [DEADS],
		   ScanDate,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER ASC) AS RowAsc3,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER DESC) AS RowDesc3
		   INTO D3
    FROM KingdomScanData4
	WHERE SCANDATE >= DATEADD(month, -3, GETDATE())
;

DECLARE
@MAXSCAN AS INT = (SELECT MAX(SCANORDER) FROM KingdomScanData4)

SELECT DISTINCT ([GovernorID]) -- Governor T5_Kills #K TEMP TABLE
		,GovernorName
		,[DEADS]
		INTO #D
		FROM KingdomScanData4
		WHERE SCANORDER = @MAXSCAN

DROP TABLE DEADSSUMMARY

SELECT DALL.GovernorID,
		#D.GovernorName,
		#D.[DEADS],
MAX(CASE WHEN RowAscALL = 1 THEN DALL.[DEADS] END) AS [StartingDEADS],
(MAX(CASE WHEN RowDescALL = 1 THEN DALL.[DEADS] END) - MAX(CASE WHEN RowASCALL = 1 THEN DALL.[DEADS] END)) AS [OverallDEADSDelta],
  (MAX(CASE WHEN RowDesc12 = 1 THEN D12.[DEADS] END) - MAX(CASE WHEN RowASC12 = 1 THEN D12.[DEADS] END)) AS [DEADSDelta12Months],
  (MAX(CASE WHEN RowDesc6 = 1 THEN D6.[DEADS] END) - MAX(CASE WHEN RowASC6 = 1 THEN D6.[DEADS] END)) AS [DEADSDelta6Months],
  (MAX(CASE WHEN RowDesc3 = 1 THEN D3.[DEADS] END) - MAX(CASE WHEN RowASC3 = 1 THEN D3.[DEADS] END)) AS [DEADSDelta3Months]
  INTO DEADSSUMMARY
FROM DALL
JOIN #D on DALL.GovernorID=#D.GovernorID
JOIN D12 ON DALL.GovernorID=D12.GovernorID
JOIN D6 ON D12.GovernorID=D6.GovernorID
JOIN D3 ON D6.GovernorID=D3.GovernorID
GROUP BY DALL.GovernorID, #D.GovernorName, #D.[DEADS]
ORDER BY #D.GovernorName ASC;

--SELECT *
--FROM DEADSSUMMARY
--ORDER BY GovernorName

DROP TABLE DALL, D12, D6, D3
DROP TABLE #D

END;
GO
-- Source: sql_schema/dbo.usp_BackfillKvkFinalReportCompletion.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_BackfillKvkFinalReportCompletion
    @KVKNo int,
    @FinalScanOrder int,
    @FinalDataAtUtc datetime2(0),
    @FinalizationBasis nvarchar(24) = N'AUDIT_BACKFILL'
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @KVKNo <= 0 OR @FinalScanOrder <= 0 OR @FinalDataAtUtc IS NULL
        THROW 51305, 'KVK completion backfill requires explicit positive KVK/scan values and an evidence timestamp.', 1;
    IF @FinalizationBasis NOT IN (N'AUDIT_BACKFILL', N'INFERRED_BACKFILL')
        THROW 51306, 'KVK completion backfill basis must be AUDIT_BACKFILL or INFERRED_BACKFILL.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.KVK_Details WHERE KVK_NO = @KVKNo)
        THROW 51307, 'KVK completion backfill could not find KVK details.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE SCANORDER = @FinalScanOrder
    )
        THROW 51308, 'KVK completion backfill could not find the final scan order.', 1;
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.v_EXCEL_FOR_KVK_All
        WHERE TRY_CONVERT(int, KVK_NO) = @KVKNo
    )
        THROW 51309, 'KVK completion backfill requires existing final output rows.', 1;
    EXEC dbo.usp_RecordKvkFinalReportCompletion
         @KVKNo = @KVKNo,
         @FinalScanOrder = @FinalScanOrder,
         @FinalizationBasis = @FinalizationBasis,
         @FinalDataAtUtc = @FinalDataAtUtc;
    SELECT KVK_NO, FinalDataAtUtc, FinalScanOrder, OutputRowCount,
           Revision, State, FinalizationBasis
    FROM dbo.KVKFinalReportHeader
    WHERE KVK_NO = @KVKNo;
END
GO
-- Source: sql_schema/dbo.usp_GetLeadershipPlayerIdentityHistory.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerIdentityHistory
    @GovernorIDs dbo.IntList READONLY,
    @HistoryDays smallint = 720
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @GovernorCount int = (SELECT COUNT(*) FROM @GovernorIDs);
    IF @GovernorCount < 1 OR @GovernorCount > 26
        THROW 51511, 'Leadership identity history requires between 1 and 26 Governor IDs.', 1;
    IF EXISTS (SELECT 1 FROM @GovernorIDs WHERE ID <= 0)
        THROW 51512, 'Leadership identity history received an invalid Governor ID.', 1;
    IF @HistoryDays < 1 OR @HistoryDays > 720
        THROW 51513, 'Leadership identity history is bounded to 1 through 720 days.', 1;

    DECLARE @AnchorDate date = (SELECT MAX(AsOfDate) FROM dbo.KingdomScanData4);
    DECLARE @StartDate date = DATEADD(DAY, 1 - @HistoryDays, @AnchorDate);

    /* Result set 1: aliases, normalized and grouped per Governor ID. */
    ;WITH AliasGroups AS
    (
        SELECT history_rows.GovernorID,
               dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName) AS GovernorNameKey,
               MIN(history_rows.FirstSeen) AS FirstSeen,
               MAX(history_rows.LastSeen) AS LastSeen,
               MAX(history_rows.SeenScanCount) AS SeenScanCount
        FROM dbo.GovernorNameHistory AS history_rows
        JOIN @GovernorIDs AS requested ON requested.ID = history_rows.GovernorID
        GROUP BY history_rows.GovernorID,
                 dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName)
    )
    SELECT groups.GovernorID, display_name.GovernorName,
           groups.FirstSeen, groups.LastSeen, groups.SeenScanCount
    FROM AliasGroups AS groups
    CROSS APPLY
    (
        SELECT TOP (1) LTRIM(RTRIM(history_rows.GovernorName)) AS GovernorName
        FROM dbo.GovernorNameHistory AS history_rows
        WHERE history_rows.GovernorID = groups.GovernorID
          AND dbo.fn_NormalizeGovernorNameKey(history_rows.GovernorName)
              = groups.GovernorNameKey
        ORDER BY history_rows.LastSeen DESC, history_rows.GovernorName DESC
    ) AS display_name
    ORDER BY groups.GovernorID, groups.LastSeen DESC, display_name.GovernorName;

    CREATE TABLE #IdentityScans
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        AsOfDate date NOT NULL,
        ScanOrdinal int NULL
    );
    INSERT INTO #IdentityScans (ScanOrder, AsOfDate)
    SELECT SCANORDER, MAX(AsOfDate)
    FROM dbo.KingdomScanData4
    WHERE AsOfDate BETWEEN @StartDate AND @AnchorDate
    GROUP BY SCANORDER;
    ;WITH Ordered AS
    (
        SELECT ScanOrder, ROW_NUMBER() OVER (ORDER BY ScanOrder) AS ScanOrdinal
        FROM #IdentityScans
    )
    UPDATE scans SET ScanOrdinal = ordered.ScanOrdinal
    FROM #IdentityScans AS scans
    JOIN Ordered AS ordered ON ordered.ScanOrder = scans.ScanOrder;

    /* Result set 2: consecutive complete-scan alliance episodes. */
    ;WITH RankedRows AS
    (
        SELECT source.GovernorID AS GovernorID,
               scans.ScanOrder, scans.ScanOrdinal, scans.AsOfDate,
               COALESCE(NULLIF(LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), source.Alliance))), 100), N''),
                        N'Unallied') AS AllianceDisplay,
               LOWER(COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), source.Alliance))), N''),
                              N'Unallied')) AS AllianceKey,
               ROW_NUMBER() OVER
               (PARTITION BY source.GovernorID, scans.ScanOrder
                ORDER BY source.ScanDate DESC, source.SCAN_UNO DESC) AS RowNumber
        FROM dbo.KingdomScanData4 AS source
        JOIN #IdentityScans AS scans
          ON scans.ScanOrder = source.SCANORDER
        JOIN @GovernorIDs AS requested
          ON requested.ID = source.GovernorID
    ),
    SelectedRows AS
    (
        SELECT * FROM RankedRows WHERE RowNumber = 1
    ),
    WithPrevious AS
    (
        SELECT *,
               LAG(ScanOrdinal) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousOrdinal,
               LAG(AllianceKey) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousAllianceKey
        FROM SelectedRows
    ),
    WithBreaks AS
    (
        SELECT *, CASE WHEN PreviousOrdinal IS NULL
                             OR PreviousOrdinal <> ScanOrdinal - 1
                             OR PreviousAllianceKey <> AllianceKey
                        THEN 1 ELSE 0 END AS StartsEpisode
        FROM WithPrevious
    ),
    Grouped AS
    (
        SELECT *, SUM(StartsEpisode) OVER
            (PARTITION BY GovernorID ORDER BY ScanOrdinal ROWS UNBOUNDED PRECEDING)
            AS EpisodeGroup
        FROM WithBreaks
    ),
    Episodes AS
    (
        SELECT GovernorID, EpisodeGroup,
               MAX(AllianceDisplay) AS Alliance,
               MIN(AsOfDate) AS FirstObservedDate,
               MAX(AsOfDate) AS LastObservedDate,
               MIN(ScanOrder) AS FirstScanOrder,
               MAX(ScanOrder) AS LastScanOrder,
               COUNT(*) AS ObservedScanCount
        FROM Grouped
        GROUP BY GovernorID, EpisodeGroup
    )
    SELECT GovernorID,
           ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY LastScanOrder DESC) AS EpisodeSequence,
           Alliance, FirstObservedDate, LastObservedDate, ObservedScanCount,
           CONVERT(bit, CASE WHEN LastScanOrder = (SELECT MAX(ScanOrder) FROM #IdentityScans)
                             THEN 1 ELSE 0 END) AS IsCurrentEpisode
    FROM Episodes
    ORDER BY GovernorID, EpisodeSequence;
END;
GO
-- Source: sql_schema/dbo.usp_GetLeadershipPlayerLastActive.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerLastActive
    @GovernorID bigint,
    @HistoryDays smallint = 720,
    @NowUtc datetime2(0) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @GovernorID IS NULL OR @GovernorID <= 0
        THROW 51551, 'Leadership Last Active requires a positive Governor ID.', 1;
    IF @HistoryDays IS NULL OR @HistoryDays < 1 OR @HistoryDays > 720
        THROW 51552, 'Leadership Last Active history is bounded to 1 through 720 days.', 1;

    DECLARE @EffectiveNowUtc datetime2(0) = COALESCE(@NowUtc, SYSUTCDATETIME());
    DECLARE @EffectiveUtcDate date = CONVERT(date, @EffectiveNowUtc);
    DECLARE @HistoryStartDate date = DATEADD(DAY, 1 - @HistoryDays, @EffectiveUtcDate);

    CREATE TABLE #CompleteScans
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        ScanDateUtc datetime2(0) NOT NULL,
        AsOfDate date NOT NULL
    );

    INSERT INTO #CompleteScans (ScanOrder, ScanDateUtc, AsOfDate)
    SELECT source.SCANORDER,
           MAX(TRY_CONVERT(datetime2(0), source.ScanDate)),
           MAX(source.AsOfDate)
    FROM dbo.KingdomScanData4 AS source
    WHERE source.AsOfDate BETWEEN @HistoryStartDate AND @EffectiveUtcDate
      AND TRY_CONVERT(datetime2(0), source.ScanDate) IS NOT NULL
    GROUP BY source.SCANORDER;

    CREATE TABLE #Observations
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        ScanDateUtc datetime2(0) NOT NULL,
        AsOfDate date NOT NULL,
        PowerValue decimal(38,0) NULL,
        HealedValue decimal(38,0) NULL,
        RssGatheredValue decimal(38,0) NULL,
        RssAssistedValue decimal(38,0) NULL,
        HelpsValue decimal(38,0) NULL,
        ActivityWeekStartDate date NULL,
        BuildingValue decimal(38,0) NULL,
        TechValue decimal(38,0) NULL
    );

    ;WITH RankedGovernorRows AS
    (
        SELECT scans.ScanOrder,
               scans.ScanDateUtc,
               scans.AsOfDate,
               TRY_CONVERT(decimal(38,0), source.Power) AS PowerValue,
               TRY_CONVERT(decimal(38,0), source.HealedTroops) AS HealedValue,
               TRY_CONVERT(decimal(38,0), source.RSS_Gathered) AS RssGatheredValue,
               TRY_CONVERT(decimal(38,0), source.RSSAssistance) AS RssAssistedValue,
               TRY_CONVERT(decimal(38,0), source.Helps) AS HelpsValue,
               ROW_NUMBER() OVER
               (
                   PARTITION BY scans.ScanOrder
                   ORDER BY source.ScanDate DESC, source.SCAN_UNO DESC
               ) AS RowNumber
        FROM #CompleteScans AS scans
        JOIN dbo.KingdomScanData4 AS source
          ON source.SCANORDER = scans.ScanOrder
         AND source.GovernorID = @GovernorID
    )
    INSERT INTO #Observations
        (ScanOrder, ScanDateUtc, AsOfDate, PowerValue, HealedValue,
         RssGatheredValue, RssAssistedValue, HelpsValue, ActivityWeekStartDate,
         BuildingValue, TechValue)
    SELECT selected.ScanOrder,
           selected.ScanDateUtc,
           selected.AsOfDate,
           selected.PowerValue,
           selected.HealedValue,
           selected.RssGatheredValue,
           selected.RssAssistedValue,
           selected.HelpsValue,
           CONVERT(date, activity_header.WeekStartUtc),
           TRY_CONVERT(decimal(38,0), activity_row.BuildingTotal),
           TRY_CONVERT(decimal(38,0), activity_row.TechDonationTotal)
    FROM RankedGovernorRows AS selected
    OUTER APPLY
    (
        SELECT TOP (1) header.SnapshotId, header.WeekStartUtc
        FROM dbo.AllianceActivitySnapshotHeader AS header
        WHERE header.CompletionState = N'COMPLETE'
          AND header.SnapshotTsUtc <= selected.ScanDateUtc
        ORDER BY header.SnapshotTsUtc DESC, header.SnapshotId DESC
    ) AS activity_header
    LEFT JOIN dbo.AllianceActivitySnapshotRow AS activity_row
      ON activity_row.SnapshotId = activity_header.SnapshotId
     AND activity_row.GovernorID = @GovernorID
    WHERE selected.RowNumber = 1;

    CREATE TABLE #Comparisons
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        ScanDateUtc datetime2(0) NOT NULL,
        AsOfDate date NOT NULL,
        PreviousScanOrder bigint NULL,
        PreviousScanDateUtc datetime2(0) NULL,
        PowerValue decimal(38,0) NULL,
        PreviousPowerValue decimal(38,0) NULL,
        HealedValue decimal(38,0) NULL,
        PreviousHealedValue decimal(38,0) NULL,
        RssGatheredValue decimal(38,0) NULL,
        PreviousRssGatheredValue decimal(38,0) NULL,
        RssAssistedValue decimal(38,0) NULL,
        PreviousRssAssistedValue decimal(38,0) NULL,
        HelpsValue decimal(38,0) NULL,
        PreviousHelpsValue decimal(38,0) NULL,
        ActivityWeekStartDate date NULL,
        PreviousActivityWeekStartDate date NULL,
        BuildingValue decimal(38,0) NULL,
        PreviousBuildingValue decimal(38,0) NULL,
        TechValue decimal(38,0) NULL,
        PreviousTechValue decimal(38,0) NULL
    );

    ;WITH WithPrevious AS
    (
        SELECT observations.*,
               LAG(ScanOrder) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousScanOrder,
               LAG(ScanDateUtc) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousScanDateUtc,
               LAG(PowerValue) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousPowerValue,
               LAG(HealedValue) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousHealedValue,
               LAG(RssGatheredValue) OVER (ORDER BY ScanDateUtc, ScanOrder)
                   AS PreviousRssGatheredValue,
               LAG(RssAssistedValue) OVER (ORDER BY ScanDateUtc, ScanOrder)
                   AS PreviousRssAssistedValue,
               LAG(HelpsValue) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousHelpsValue,
               LAG(ActivityWeekStartDate) OVER (ORDER BY ScanDateUtc, ScanOrder)
                   AS PreviousActivityWeekStartDate,
               LAG(BuildingValue) OVER (ORDER BY ScanDateUtc, ScanOrder)
                   AS PreviousBuildingValue,
               LAG(TechValue) OVER (ORDER BY ScanDateUtc, ScanOrder) AS PreviousTechValue
        FROM #Observations AS observations
    )
    INSERT INTO #Comparisons
        (ScanOrder, ScanDateUtc, AsOfDate, PreviousScanOrder, PreviousScanDateUtc,
         PowerValue, PreviousPowerValue, HealedValue, PreviousHealedValue,
         RssGatheredValue, PreviousRssGatheredValue,
          RssAssistedValue, PreviousRssAssistedValue,
          HelpsValue, PreviousHelpsValue,
          ActivityWeekStartDate, PreviousActivityWeekStartDate,
          BuildingValue, PreviousBuildingValue,
         TechValue, PreviousTechValue)
    SELECT ScanOrder, ScanDateUtc, AsOfDate, PreviousScanOrder, PreviousScanDateUtc,
           PowerValue, PreviousPowerValue, HealedValue, PreviousHealedValue,
           RssGatheredValue, PreviousRssGatheredValue,
           RssAssistedValue, PreviousRssAssistedValue,
           HelpsValue, PreviousHelpsValue,
           ActivityWeekStartDate, PreviousActivityWeekStartDate,
           BuildingValue, PreviousBuildingValue,
           TechValue, PreviousTechValue
    FROM WithPrevious;

    DECLARE @LastActiveDate date = NULL;
    DECLARE @QualifyingSourceCode nvarchar(32) = NULL;
    DECLARE @QualifyingScanOrder bigint = NULL;

    ;WITH Qualified AS
    (
        SELECT comparison.ScanOrder,
               comparison.ScanDateUtc,
               source_choice.SourceCode,
               source_choice.SourceOrder
        FROM #Comparisons AS comparison
        OUTER APPLY
        (
            SELECT COUNT_BIG(*) AS CompletedReportCount,
                   SUM(CONVERT(bigint, COALESCE(rally_row.TotalRallies, 0))) AS RallyTotal
            FROM dbo.RallyDailySnapshotHeader AS rally_header
            LEFT JOIN dbo.cur_RallyDaily AS rally_row
              ON rally_row.AsOfDate = rally_header.AsOfDate
             AND rally_row.GovernorID = @GovernorID
            WHERE comparison.PreviousScanDateUtc IS NOT NULL
              AND rally_header.AsOfDate > CONVERT(date, comparison.PreviousScanDateUtc)
              AND rally_header.AsOfDate <= CONVERT(date, comparison.ScanDateUtc)
        ) AS rally
        CROSS APPLY
        (
            SELECT TOP (1) candidates.SourceCode, candidates.SourceOrder
            FROM
            (
                VALUES
                    (N'POWER', 1, CASE WHEN comparison.PowerValue > comparison.PreviousPowerValue
                                      THEN 1 ELSE 0 END),
                    (N'HEALED', 2, CASE WHEN comparison.HealedValue > comparison.PreviousHealedValue
                                       THEN 1 ELSE 0 END),
                    (N'RSS_GATHERED', 3,
                        CASE WHEN comparison.RssGatheredValue
                                      > comparison.PreviousRssGatheredValue THEN 1 ELSE 0 END),
                    (N'RSS_ASSISTED', 4,
                        CASE WHEN comparison.RssAssistedValue
                                      > comparison.PreviousRssAssistedValue THEN 1 ELSE 0 END),
                    (N'HELPS', 5, CASE WHEN comparison.HelpsValue > comparison.PreviousHelpsValue
                                      THEN 1 ELSE 0 END),
                    (N'TECH_DONATIONS', 6,
                        CASE WHEN comparison.TechValue > comparison.PreviousTechValue
                                  OR (comparison.TechValue > 0
                                      AND comparison.PreviousTechValue IS NOT NULL
                                      AND comparison.ActivityWeekStartDate
                                          > comparison.PreviousActivityWeekStartDate)
                             THEN 1 ELSE 0 END),
                    (N'BUILDING_MINUTES', 7,
                        CASE WHEN comparison.BuildingValue > comparison.PreviousBuildingValue
                                  OR (comparison.BuildingValue > 0
                                      AND comparison.PreviousBuildingValue IS NOT NULL
                                      AND comparison.ActivityWeekStartDate
                                          > comparison.PreviousActivityWeekStartDate)
                             THEN 1 ELSE 0 END),
                    (N'FORT_RALLIES', 8,
                        CASE WHEN rally.CompletedReportCount > 0 AND rally.RallyTotal > 0
                             THEN 1 ELSE 0 END)
            ) AS candidates(SourceCode, SourceOrder, Qualified)
            WHERE candidates.Qualified = 1
            ORDER BY candidates.SourceOrder
        ) AS source_choice
        WHERE comparison.PreviousScanOrder IS NOT NULL
    )
    SELECT TOP (1)
           @LastActiveDate = CONVERT(date, ScanDateUtc),
           @QualifyingSourceCode = SourceCode,
           @QualifyingScanOrder = ScanOrder
    FROM Qualified
    ORDER BY ScanDateUtc DESC, ScanOrder DESC, SourceOrder;

    SELECT @GovernorID AS GovernorID,
           @EffectiveUtcDate AS EffectiveUtcDate,
           @HistoryStartDate AS HistoryStartDate,
           @EffectiveUtcDate AS HistoryEndDate,
           @LastActiveDate AS LastActiveDate,
           CONVERT(nvarchar(16),
               CASE WHEN @LastActiveDate IS NULL THEN N'NOT_RECORDED'
                    WHEN @LastActiveDate < DATEADD(DAY, -30, @EffectiveUtcDate) THEN N'INACTIVE'
                    ELSE N'ACTIVE' END) AS ActivityState,
           @QualifyingSourceCode AS QualifyingSourceCode,
           @QualifyingScanOrder AS QualifyingScanOrder,
           (SELECT COUNT(*) FROM #Comparisons WHERE PreviousScanOrder IS NOT NULL)
               AS ComparedCompleteScanCount,
           @HistoryDays AS HistoryDays;
END;
GO
-- Source: sql_schema/dbo.usp_GetLeadershipPlayerLookupDirectory.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerLookupDirectory
    @HistoryDays smallint = 720
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @HistoryDays < 1 OR @HistoryDays > 720
        THROW 51541, 'Leadership lookup history is bounded to 1 through 720 days.', 1;

    DECLARE @AnchorDate date = (SELECT MAX(AsOfDate) FROM dbo.KingdomScanData4);
    DECLARE @HistoryStart date = DATEADD(DAY, 1 - @HistoryDays, @AnchorDate);
    DECLARE @LatestScanOrder bigint =
        (SELECT MAX(SCANORDER)
         FROM dbo.KingdomScanData4 WHERE AsOfDate = @AnchorDate);

    ;WITH AliasGroups AS
    (
        SELECT h.GovernorID,
               dbo.fn_NormalizeGovernorNameKey(h.GovernorName) AS GovernorNameKey,
               MIN(h.FirstSeen) AS FirstSeen, MAX(h.LastSeen) AS LastSeen,
               MAX(h.SeenScanCount) AS SeenScanCount
        FROM dbo.GovernorNameHistory AS h
        WHERE h.LastSeen >= @HistoryStart
        GROUP BY h.GovernorID, dbo.fn_NormalizeGovernorNameKey(h.GovernorName)
    ),
    RelevantGovernors AS
    (
        SELECT DISTINCT GovernorID FROM AliasGroups
    ),
    RankedLatest AS
    (
        SELECT s.GovernorID AS GovernorID,
               LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), s.GovernorName))), 100) AS CurrentGovernorName,
               LEFT(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), s.Alliance))), N''), 100) AS CurrentAlliance,
               TRY_CONVERT(datetime2(0), s.ScanDate) AS LastGovernorScanAtUtc,
               s.SCANORDER AS LastGovernorScanOrder,
               ROW_NUMBER() OVER
               (PARTITION BY s.GovernorID
                ORDER BY s.SCANORDER DESC, s.ScanDate DESC, s.SCAN_UNO DESC) AS RowNumber
        FROM dbo.KingdomScanData4 AS s
        JOIN RelevantGovernors AS r
          ON r.GovernorID = s.GovernorID
        WHERE s.AsOfDate >= @HistoryStart
    ),
    Latest AS
    (
        SELECT * FROM RankedLatest WHERE RowNumber = 1
    )
    SELECT a.GovernorID, d.GovernorName, a.GovernorNameKey,
           a.FirstSeen, a.LastSeen, a.SeenScanCount,
           l.CurrentGovernorName, l.CurrentAlliance, l.LastGovernorScanAtUtc,
           CONVERT(bit, CASE WHEN l.LastGovernorScanOrder = @LatestScanOrder THEN 1 ELSE 0 END)
               AS PresentInLatestCompleteScan,
           CONVERT(bit, CASE WHEN a.GovernorNameKey =
                                  dbo.fn_NormalizeGovernorNameKey(l.CurrentGovernorName)
                             THEN 1 ELSE 0 END) AS IsCurrentName
    FROM AliasGroups AS a
    JOIN Latest AS l ON l.GovernorID = a.GovernorID
    CROSS APPLY
    (
        SELECT TOP (1) LEFT(LTRIM(RTRIM(h.GovernorName)), 100) AS GovernorName
        FROM dbo.GovernorNameHistory AS h
        WHERE h.GovernorID = a.GovernorID
          AND dbo.fn_NormalizeGovernorNameKey(h.GovernorName) = a.GovernorNameKey
        ORDER BY h.LastSeen DESC, h.GovernorName DESC
    ) AS d
    ORDER BY a.GovernorID, IsCurrentName DESC, a.LastSeen DESC, d.GovernorName;
END
GO
-- Source: sql_schema/dbo.usp_GetLeadershipPlayerReview.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerReview
    @GovernorID bigint,
    @PeriodDays smallint = 90,
    @NowUtc datetime2(0) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @GovernorID <= 0
        THROW 51501, 'Leadership player review requires a positive Governor ID.', 1;
    IF @PeriodDays NOT IN (30, 90, 180, 360)
        THROW 51502, 'Leadership player review period must be 30, 90, 180, or 360 days.', 1;

    DECLARE @EffectiveNow datetime2(0) = COALESCE(@NowUtc, SYSUTCDATETIME());
    DECLARE @AnchorDate date =
        (SELECT MAX(AsOfDate) FROM dbo.KingdomScanData4
         WHERE AsOfDate <= CONVERT(date, @EffectiveNow));
    DECLARE @CurrentStart date = DATEADD(DAY, 1 - @PeriodDays, @AnchorDate);
    DECLARE @PreviousEnd date = DATEADD(DAY, -1, @CurrentStart);
    DECLARE @PreviousStart date = DATEADD(DAY, 1 - @PeriodDays, @PreviousEnd);
    DECLARE @LatestScanOrder bigint =
        (SELECT MAX(SCANORDER)
         FROM dbo.KingdomScanData4 WHERE AsOfDate = @AnchorDate);
    DECLARE @LatestScanAtUtc datetime2(0) =
        (SELECT MAX(TRY_CONVERT(datetime2(0), ScanDate))
         FROM dbo.KingdomScanData4 WHERE SCANORDER = @LatestScanOrder);
    DECLARE @BaselineScanOrder bigint =
        (SELECT TOP (1) SCANORDER
         FROM dbo.KingdomScanData4
         WHERE AsOfDate < @PreviousStart
         ORDER BY SCANORDER DESC);

    CREATE TABLE #Scans
    (
        ScanOrder bigint NOT NULL PRIMARY KEY,
        ScanDateUtc datetime2(0) NOT NULL,
        AsOfDate date NOT NULL,
        ScanOrdinal int NULL
    );

    INSERT INTO #Scans (ScanOrder, ScanDateUtc, AsOfDate)
    SELECT SCANORDER,
           MAX(TRY_CONVERT(datetime2(0), ScanDate)),
           MAX(AsOfDate)
    FROM dbo.KingdomScanData4
    WHERE (@AnchorDate IS NOT NULL AND AsOfDate BETWEEN @PreviousStart AND @AnchorDate)
       OR SCANORDER = @BaselineScanOrder
    GROUP BY SCANORDER;

    ;WITH Ordered AS
    (
        SELECT ScanOrder, ROW_NUMBER() OVER (ORDER BY ScanOrder) AS ScanOrdinal
        FROM #Scans
    )
    UPDATE scans
    SET ScanOrdinal = ordered.ScanOrdinal
    FROM #Scans AS scans
    JOIN Ordered AS ordered ON ordered.ScanOrder = scans.ScanOrder;

    CREATE TABLE #Population
    (
        GovernorID bigint NOT NULL PRIMARY KEY,
        IsCurrentCohort bit NOT NULL,
        IsCurrentlyAllied bit NOT NULL
    );

    INSERT INTO #Population (GovernorID, IsCurrentCohort, IsCurrentlyAllied)
    SELECT GovernorID, 1,
           CONVERT(bit, MAX(CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), N'')
                                      IS NOT NULL THEN 1 ELSE 0 END))
    FROM dbo.KingdomScanData4
    WHERE SCANORDER = @LatestScanOrder
      AND GovernorID > 0
    GROUP BY GovernorID;

    IF NOT EXISTS (SELECT 1 FROM #Population WHERE GovernorID = @GovernorID)
        INSERT INTO #Population (GovernorID, IsCurrentCohort, IsCurrentlyAllied)
        VALUES (@GovernorID, 0, 0);

    CREATE TABLE #StatsRows
    (
        GovernorID bigint NOT NULL,
        ScanOrder bigint NOT NULL,
        ScanOrdinal int NOT NULL,
        AsOfDate date NOT NULL,
        ScanDateUtc datetime2(0) NOT NULL,
        GovernorName nvarchar(100) NULL,
        Alliance nvarchar(100) NULL,
        PowerValue decimal(38,0) NULL,
        CityHall int NULL,
        HelpsValue decimal(38,0) NULL,
        RSSValue decimal(38,0) NULL,
        PRIMARY KEY CLUSTERED (GovernorID, ScanOrder)
    );

    ;WITH RankedRows AS
    (
        SELECT
            source.GovernorID AS GovernorID,
            scans.ScanOrder,
            scans.ScanOrdinal,
            scans.AsOfDate,
            TRY_CONVERT(datetime2(0), source.ScanDate) AS ScanDateUtc,
            LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), source.GovernorName))), 100) AS GovernorName,
            LEFT(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), source.Alliance))), N''), 100) AS Alliance,
            TRY_CONVERT(decimal(38,0), source.Power) AS PowerValue,
            TRY_CONVERT(int, source.[City Hall]) AS CityHall,
            TRY_CONVERT(decimal(38,0), source.Helps) AS HelpsValue,
            TRY_CONVERT(decimal(38,0), source.RSS_Gathered) AS RSSValue,
            ROW_NUMBER() OVER
            (
                PARTITION BY source.GovernorID, scans.ScanOrder
                ORDER BY source.ScanDate DESC, source.SCAN_UNO DESC
            ) AS RowNumber
        FROM dbo.KingdomScanData4 AS source
        JOIN #Scans AS scans ON scans.ScanOrder = source.SCANORDER
        JOIN #Population AS population
          ON population.GovernorID = source.GovernorID
    )
    INSERT INTO #StatsRows
        (GovernorID, ScanOrder, ScanOrdinal, AsOfDate, ScanDateUtc,
         GovernorName, Alliance, PowerValue, CityHall, HelpsValue, RSSValue)
    SELECT GovernorID, ScanOrder, ScanOrdinal, AsOfDate, ScanDateUtc,
           GovernorName, Alliance, PowerValue, CityHall, HelpsValue, RSSValue
    FROM RankedRows
    WHERE RowNumber = 1;

    CREATE TABLE #StatsDeltas
    (
        GovernorID bigint NOT NULL,
        AsOfDate date NOT NULL,
        IsConsecutive bit NOT NULL,
        HelpsDelta decimal(38,0) NULL,
        HelpsReset bit NOT NULL,
        RSSDelta decimal(38,0) NULL,
        RSSReset bit NOT NULL,
        PowerDelta decimal(38,0) NULL
    );

    ;WITH WithPrevious AS
    (
        SELECT rows.*,
            LAG(ScanOrdinal) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousOrdinal,
            LAG(HelpsValue) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousHelps,
            LAG(RSSValue) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousRSS,
            LAG(PowerValue) OVER (PARTITION BY GovernorID ORDER BY ScanOrdinal) AS PreviousPower
        FROM #StatsRows AS rows
    )
    INSERT INTO #StatsDeltas
        (GovernorID, AsOfDate, IsConsecutive, HelpsDelta, HelpsReset,
         RSSDelta, RSSReset, PowerDelta)
    SELECT
        GovernorID,
        AsOfDate,
        CONVERT(bit, CASE WHEN PreviousOrdinal = ScanOrdinal - 1 THEN 1 ELSE 0 END),
        CASE WHEN PreviousOrdinal = ScanOrdinal - 1 AND HelpsValue >= PreviousHelps
             THEN HelpsValue - PreviousHelps END,
        CONVERT(bit, CASE WHEN PreviousOrdinal = ScanOrdinal - 1 AND HelpsValue < PreviousHelps
                          THEN 1 ELSE 0 END),
        CASE WHEN PreviousOrdinal = ScanOrdinal - 1 AND RSSValue >= PreviousRSS
             THEN RSSValue - PreviousRSS END,
        CONVERT(bit, CASE WHEN PreviousOrdinal = ScanOrdinal - 1 AND RSSValue < PreviousRSS
                          THEN 1 ELSE 0 END),
        CASE WHEN PreviousOrdinal = ScanOrdinal - 1 THEN PowerValue - PreviousPower END
    FROM WithPrevious
    WHERE AsOfDate BETWEEN @PreviousStart AND @AnchorDate;

    CREATE TABLE #MetricValues
    (
        WindowCode nvarchar(8) NOT NULL,
        GovernorID bigint NOT NULL,
        MetricOrder tinyint NOT NULL,
        MetricCode nvarchar(24) NOT NULL,
        MetricTotal decimal(38,4) NULL,
        ValidReportingDays int NOT NULL,
        ExpectedUnits int NOT NULL,
        MissingUnits int NOT NULL,
        ResetCount int NOT NULL,
        IsAvailable bit NOT NULL,
        PRIMARY KEY CLUSTERED (WindowCode, GovernorID, MetricOrder)
    );

    CREATE TABLE #Windows
    (
        WindowCode nvarchar(8) NOT NULL PRIMARY KEY,
        StartDate date NULL,
        EndDate date NULL
    );
    INSERT INTO #Windows VALUES
        (N'CURRENT', @CurrentStart, @AnchorDate),
        (N'PREVIOUS', @PreviousStart, @PreviousEnd);

    CREATE TABLE #StatsMetricDaily
    (
        GovernorID bigint NOT NULL,
        AsOfDate date NOT NULL,
        MetricOrder tinyint NOT NULL,
        MetricCode nvarchar(24) NOT NULL,
        MetricValue decimal(38,4) NULL,
        WasReset bit NOT NULL
    );
    INSERT INTO #StatsMetricDaily
    SELECT GovernorID, AsOfDate, metric.MetricOrder, metric.MetricCode,
           metric.MetricValue, metric.WasReset
    FROM #StatsDeltas
    CROSS APPLY
    (
        VALUES
            (CONVERT(tinyint, 2), N'HELPS', CONVERT(decimal(38,4), HelpsDelta), HelpsReset),
            (CONVERT(tinyint, 4), N'RSS_GATHERED', CONVERT(decimal(38,4), RSSDelta), RSSReset),
            (CONVERT(tinyint, 6), N'POWER_CHANGE', CONVERT(decimal(38,4), PowerDelta), CONVERT(bit, 0))
    ) AS metric(MetricOrder, MetricCode, MetricValue, WasReset);

    CREATE CLUSTERED INDEX CX_StatsMetricDaily_GovernorMetricDate
        ON #StatsMetricDaily (GovernorID, MetricOrder, AsOfDate);

    INSERT INTO #MetricValues
        (WindowCode, GovernorID, MetricOrder, MetricCode, MetricTotal,
         ValidReportingDays, ExpectedUnits, MissingUnits, ResetCount, IsAvailable)
    SELECT windows.WindowCode, population.GovernorID,
           metric_list.MetricOrder, metric_list.MetricCode,
           (SELECT SUM(daily.MetricValue)
            FROM #StatsMetricDaily AS daily
            WHERE daily.GovernorID = population.GovernorID
              AND daily.MetricOrder = metric_list.MetricOrder
              AND daily.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
           (SELECT COUNT(DISTINCT daily.AsOfDate)
            FROM #StatsMetricDaily AS daily
            WHERE daily.GovernorID = population.GovernorID
              AND daily.MetricOrder = metric_list.MetricOrder
              AND daily.MetricValue IS NOT NULL
              AND daily.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
           (SELECT COUNT(*) FROM #Scans AS scans
            WHERE scans.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
            (SELECT COUNT(*) FROM #Scans AS scans
             WHERE scans.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
              - (SELECT COUNT(*) FROM #StatsRows AS rows
                 WHERE rows.GovernorID = population.GovernorID
                   AND CASE metric_list.MetricOrder
                           WHEN 2 THEN rows.HelpsValue
                           WHEN 4 THEN rows.RSSValue
                           WHEN 6 THEN rows.PowerValue
                       END IS NOT NULL
                   AND rows.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
           (SELECT COUNT(*) FROM #StatsMetricDaily AS daily
            WHERE daily.GovernorID = population.GovernorID
              AND daily.MetricOrder = metric_list.MetricOrder
              AND daily.WasReset = 1
              AND daily.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
            -- Missing observations remain visible in coverage but do not discard valid rates.
            CONVERT(bit, CASE WHEN EXISTS
            (
                SELECT 1 FROM #StatsMetricDaily AS daily
                WHERE daily.GovernorID = population.GovernorID
                 AND daily.MetricOrder = metric_list.MetricOrder
                  AND daily.MetricValue IS NOT NULL
                  AND daily.AsOfDate BETWEEN windows.StartDate AND windows.EndDate
            ) THEN 1 ELSE 0 END)
    FROM #Population AS population
    CROSS JOIN #Windows AS windows
    CROSS JOIN
        (VALUES (CONVERT(tinyint, 2), N'HELPS'),
                (CONVERT(tinyint, 4), N'RSS_GATHERED'),
                (CONVERT(tinyint, 6), N'POWER_CHANGE'))
        AS metric_list(MetricOrder, MetricCode);

    CREATE TABLE #RallyDates (AsOfDate date NOT NULL PRIMARY KEY);
    INSERT INTO #RallyDates
    SELECT AsOfDate FROM dbo.RallyDailySnapshotHeader
    WHERE AsOfDate BETWEEN @PreviousStart AND @AnchorDate;

    INSERT INTO #MetricValues
        (WindowCode, GovernorID, MetricOrder, MetricCode, MetricTotal,
         ValidReportingDays, ExpectedUnits, MissingUnits, ResetCount, IsAvailable)
    SELECT windows.WindowCode, population.GovernorID, 1, N'FORTS_TOTAL',
           SUM(CONVERT(decimal(38,4), COALESCE(rallies.TotalRallies, 0))),
           COUNT(DISTINCT report_dates.AsOfDate),
           @PeriodDays,
           @PeriodDays - COUNT(DISTINCT report_dates.AsOfDate),
           0,
           CONVERT(bit, CASE WHEN COUNT(DISTINCT report_dates.AsOfDate) > 0 THEN 1 ELSE 0 END)
    FROM #Population AS population
    CROSS JOIN #Windows AS windows
    LEFT JOIN #RallyDates AS report_dates
      ON report_dates.AsOfDate BETWEEN windows.StartDate AND windows.EndDate
    LEFT JOIN dbo.cur_RallyDaily AS rallies
      ON rallies.AsOfDate = report_dates.AsOfDate
     AND rallies.GovernorID = population.GovernorID
    GROUP BY windows.WindowCode, population.GovernorID;

    CREATE TABLE #ActivityHeaders
    (
        SnapshotID bigint NOT NULL PRIMARY KEY,
        SnapshotDate date NOT NULL,
        WeekStartDate date NOT NULL,
        WeekOrdinal int NOT NULL,
        CompletionState nvarchar(24) NOT NULL
    );
    ;WITH RankedHeaders AS
    (
        SELECT SnapshotId, CONVERT(date, SnapshotTsUtc) AS SnapshotDate,
               CONVERT(date, WeekStartUtc) AS WeekStartDate, CompletionState,
               ROW_NUMBER() OVER
               (PARTITION BY CONVERT(date, SnapshotTsUtc)
                ORDER BY SnapshotTsUtc DESC, SnapshotId DESC) AS DayRow
        FROM dbo.AllianceActivitySnapshotHeader
        WHERE SnapshotTsUtc >= DATEADD(DAY, -6, CONVERT(datetime2(0), @PreviousStart))
          AND SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate))
    ),
    Selected AS
    (
        SELECT SnapshotId, SnapshotDate, WeekStartDate, CompletionState,
               ROW_NUMBER() OVER
               (PARTITION BY WeekStartDate ORDER BY SnapshotDate, SnapshotId) AS WeekOrdinal
        FROM RankedHeaders WHERE DayRow = 1
    )
    INSERT INTO #ActivityHeaders
    SELECT SnapshotId, SnapshotDate, WeekStartDate, WeekOrdinal, CompletionState
    FROM Selected;

    CREATE TABLE #ActivityDaily
    (
        GovernorID bigint NOT NULL,
        SnapshotDate date NOT NULL,
        MetricOrder tinyint NOT NULL,
        MetricCode nvarchar(24) NOT NULL,
        MetricValue decimal(38,4) NULL,
        WasReset bit NOT NULL,
        IsComplete bit NOT NULL,
        PRIMARY KEY CLUSTERED (GovernorID, SnapshotDate, MetricOrder)
    );

    ;WITH Observed AS
    (
        SELECT population.GovernorID, headers.SnapshotID, headers.SnapshotDate,
               headers.WeekStartDate, headers.WeekOrdinal, headers.CompletionState,
               TRY_CONVERT(decimal(38,0), rows.BuildingTotal) AS BuildingValue,
               TRY_CONVERT(decimal(38,0), rows.TechDonationTotal) AS TechValue,
               LAG(headers.WeekOrdinal) OVER
                 (PARTITION BY population.GovernorID, headers.WeekStartDate
                  ORDER BY headers.WeekOrdinal) AS PreviousWeekOrdinal,
               LAG(headers.CompletionState) OVER
                 (PARTITION BY population.GovernorID, headers.WeekStartDate
                  ORDER BY headers.WeekOrdinal) AS PreviousCompletionState,
               LAG(TRY_CONVERT(decimal(38,0), rows.BuildingTotal)) OVER
                 (PARTITION BY population.GovernorID, headers.WeekStartDate
                  ORDER BY headers.WeekOrdinal) AS PreviousBuilding,
               LAG(TRY_CONVERT(decimal(38,0), rows.TechDonationTotal)) OVER
                 (PARTITION BY population.GovernorID, headers.WeekStartDate
                  ORDER BY headers.WeekOrdinal) AS PreviousTech
        FROM #Population AS population
        CROSS JOIN #ActivityHeaders AS headers
        LEFT JOIN dbo.AllianceActivitySnapshotRow AS rows
          ON rows.SnapshotId = headers.SnapshotID
         AND rows.GovernorID = population.GovernorID
    ),
    Deltas AS
    (
        SELECT *,
            CASE WHEN CompletionState = N'COMPLETE' AND BuildingValue IS NOT NULL
                       AND (WeekOrdinal = 1 OR (PreviousWeekOrdinal = WeekOrdinal - 1
                                               AND PreviousCompletionState = N'COMPLETE'
                                               AND PreviousBuilding IS NOT NULL))
                 THEN BuildingValue - COALESCE(PreviousBuilding, 0) END AS BuildingDelta,
            CASE WHEN CompletionState = N'COMPLETE' AND TechValue IS NOT NULL
                       AND (WeekOrdinal = 1 OR (PreviousWeekOrdinal = WeekOrdinal - 1
                                               AND PreviousCompletionState = N'COMPLETE'
                                               AND PreviousTech IS NOT NULL))
                 THEN TechValue - COALESCE(PreviousTech, 0) END AS TechDelta
        FROM Observed
    )
    INSERT INTO #ActivityDaily
        (GovernorID, SnapshotDate, MetricOrder, MetricCode,
         MetricValue, WasReset, IsComplete)
    SELECT GovernorID, SnapshotDate, metric.MetricOrder, metric.MetricCode,
           CASE WHEN metric.RawDelta >= 0 THEN metric.RawDelta END,
           CONVERT(bit, CASE WHEN metric.RawDelta < 0 THEN 1 ELSE 0 END),
           CONVERT(bit, CASE WHEN CompletionState = N'COMPLETE'
                                  AND metric.RawDelta IS NOT NULL THEN 1 ELSE 0 END)
    FROM Deltas
    CROSS APPLY
    (
        VALUES
            (CONVERT(tinyint, 3), N'TECH_DONATIONS', CONVERT(decimal(38,4), TechDelta)),
            (CONVERT(tinyint, 5), N'BUILDING_MINUTES', CONVERT(decimal(38,4), BuildingDelta))
    ) AS metric(MetricOrder, MetricCode, RawDelta)
    WHERE SnapshotDate BETWEEN @PreviousStart AND @AnchorDate;

    INSERT INTO #MetricValues
        (WindowCode, GovernorID, MetricOrder, MetricCode, MetricTotal,
         ValidReportingDays, ExpectedUnits, MissingUnits, ResetCount, IsAvailable)
    SELECT windows.WindowCode, population.GovernorID,
           metric_list.MetricOrder, metric_list.MetricCode,
           SUM(CASE WHEN daily.MetricValue IS NOT NULL THEN daily.MetricValue END),
           COUNT(DISTINCT CASE WHEN daily.MetricValue IS NOT NULL THEN daily.SnapshotDate END),
           COUNT(DISTINCT headers.SnapshotDate),
           COUNT(DISTINCT headers.SnapshotDate)
             - COUNT(DISTINCT CASE WHEN daily.IsComplete = 1 THEN daily.SnapshotDate END),
           COALESCE(SUM(CASE WHEN daily.WasReset = 1 THEN 1 ELSE 0 END), 0),
           -- Rank partial evidence by its valid-day rate; never impute a missing row as zero.
           CONVERT(bit, CASE
               WHEN population.IsCurrentlyAllied = 0 THEN 0
               WHEN COUNT(daily.MetricValue) = 0 THEN 0
               ELSE 1 END)
    FROM #Population AS population
    CROSS JOIN #Windows AS windows
    CROSS JOIN
        (VALUES (CONVERT(tinyint, 3), N'TECH_DONATIONS'),
                (CONVERT(tinyint, 5), N'BUILDING_MINUTES'))
        AS metric_list(MetricOrder, MetricCode)
    LEFT JOIN #ActivityHeaders AS headers
      ON headers.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate
    LEFT JOIN #ActivityDaily AS daily
      ON daily.GovernorID = population.GovernorID
     AND daily.SnapshotDate = headers.SnapshotDate
     AND daily.MetricOrder = metric_list.MetricOrder
    GROUP BY windows.WindowCode, population.GovernorID,
             population.IsCurrentlyAllied, metric_list.MetricOrder, metric_list.MetricCode;

    CREATE TABLE #MetricRanks
    (
        GovernorID bigint NOT NULL,
        MetricOrder tinyint NOT NULL,
        RankValue decimal(38,8) NOT NULL,
        CompetitionRank int NOT NULL,
        AverageRank decimal(18,4) NOT NULL,
        CohortCount int NOT NULL,
        PercentileScore decimal(9,4) NULL,
        PRIMARY KEY CLUSTERED (GovernorID, MetricOrder)
    );

    ;WITH RankBase AS
    (
        SELECT values_current.GovernorID, values_current.MetricOrder,
               CONVERT(decimal(38,8), values_current.MetricTotal
                   / NULLIF(values_current.ValidReportingDays, 0)) AS RankValue
        FROM #MetricValues AS values_current
        JOIN #Population AS population
          ON population.GovernorID = values_current.GovernorID
         AND population.IsCurrentCohort = 1
        WHERE values_current.WindowCode = N'CURRENT'
          AND values_current.IsAvailable = 1
          AND values_current.ValidReportingDays > 0
          AND values_current.MetricTotal IS NOT NULL
    ),
    Ranked AS
    (
        SELECT *,
            RANK() OVER (PARTITION BY MetricOrder ORDER BY RankValue DESC) AS CompetitionRank,
            COUNT(*) OVER (PARTITION BY MetricOrder, RankValue) AS TieCount,
            COUNT(*) OVER (PARTITION BY MetricOrder) AS CohortCount,
            MIN(RankValue) OVER (PARTITION BY MetricOrder) AS MinimumValue,
            MAX(RankValue) OVER (PARTITION BY MetricOrder) AS MaximumValue
        FROM RankBase
    )
    INSERT INTO #MetricRanks
    SELECT GovernorID, MetricOrder, RankValue, CompetitionRank,
           CONVERT(decimal(18,4), CompetitionRank + (TieCount - 1) / 2.0),
           CohortCount,
           CONVERT(decimal(9,4), CASE
               WHEN CohortCount < 2 THEN NULL
               WHEN MinimumValue = MaximumValue THEN 50.0
               ELSE (CohortCount - (CompetitionRank + (TieCount - 1) / 2.0))
                    / (CohortCount - 1.0) * 100.0 END)
    FROM Ranked;

    CREATE TABLE #ActivityIndex
    (
        GovernorID bigint NOT NULL PRIMARY KEY,
        ActivityIndex decimal(9,4) NOT NULL,
        ActivityRank int NULL,
        CohortCount int NULL
    );

    ;WITH Weighted AS
    (
        SELECT ranks.GovernorID, ranks.MetricOrder, ranks.PercentileScore,
               weights.WeightPercent
        FROM #MetricRanks AS ranks
        JOIN
            (VALUES (CONVERT(tinyint, 1), CONVERT(decimal(9,4), 30.0)),
                    (CONVERT(tinyint, 2), CONVERT(decimal(9,4), 22.0)),
                    (CONVERT(tinyint, 3), CONVERT(decimal(9,4), 18.0)),
                    (CONVERT(tinyint, 4), CONVERT(decimal(9,4), 14.0)),
                    (CONVERT(tinyint, 5), CONVERT(decimal(9,4), 10.0)),
                    (CONVERT(tinyint, 6), CONVERT(decimal(9,4), 6.0)))
            AS weights(MetricOrder, WeightPercent)
          ON weights.MetricOrder = ranks.MetricOrder
    ),
    IndexBase AS
    (
        SELECT GovernorID,
               CONVERT(decimal(9,4), SUM(PercentileScore * WeightPercent) / 100.0)
                   AS ActivityIndex
        FROM Weighted
        GROUP BY GovernorID
        HAVING COUNT(*) = 6 AND COUNT(PercentileScore) = 6
    ),
    RankedIndex AS
    (
        SELECT *, RANK() OVER (ORDER BY ActivityIndex DESC) AS ActivityRank,
               COUNT(*) OVER () AS CohortCount
        FROM IndexBase
    )
    INSERT INTO #ActivityIndex
    SELECT GovernorID, ActivityIndex, ActivityRank, CohortCount
    FROM RankedIndex;

    DECLARE @TargetLatestScanOrder bigint =
        (SELECT MAX(SCANORDER)
         FROM dbo.KingdomScanData4 WHERE GovernorID = @GovernorID);
    DECLARE @TargetFirstObservedDate date =
        (SELECT MIN(AsOfDate) FROM dbo.KingdomScanData4
         WHERE GovernorID = @GovernorID);

    /* Result set 1: header and source facts. */
    SELECT
        N'leadership_player_review_v1' AS ContractVersion,
        N'activity_index_v1|combat_metrics_v1' AS FormulaVersion,
        @GovernorID AS GovernorID,
        target.GovernorName,
        target.Alliance AS CurrentAlliance,
        target.PowerValue AS CurrentPower,
        target.PowerRank AS PowerRank,
        target.CityHall,
        @EffectiveNow AS EffectiveNowUtc,
        @AnchorDate AS AnchorDate,
        @CurrentStart AS CurrentStartDate,
        @AnchorDate AS CurrentEndDate,
        @PreviousStart AS PreviousStartDate,
        @PreviousEnd AS PreviousEndDate,
        @PeriodDays AS PeriodDays,
        @PreviousStart AS ReadStartDate,
        @LatestScanOrder AS LatestCompleteScanOrder,
        @LatestScanAtUtc AS LatestCompleteScanAtUtc,
        @TargetLatestScanOrder AS LatestGovernorScanOrder,
        target.ScanDateUtc AS LatestGovernorScanAtUtc,
        CONVERT(bit, CASE WHEN @TargetLatestScanOrder = @LatestScanOrder THEN 1 ELSE 0 END)
            AS PresentInLatestCompleteScan,
        @TargetFirstObservedDate AS FirstObservedDate,
        CASE WHEN @TargetFirstObservedDate BETWEEN @CurrentStart AND @AnchorDate
             THEN DATEDIFF(DAY, @CurrentStart, @TargetFirstObservedDate) END
            AS FirstObservedOffsetDays,
        location.X AS LocationX,
        location.Y AS LocationY,
        location.LastUpdated AS LocationUpdatedAtUtc,
        location.ShieldEndsAtUtc
    FROM (VALUES (1)) AS singleton(Value)
    OUTER APPLY
    (
        SELECT TOP (1)
            LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), GovernorName))), 100) AS GovernorName,
            LEFT(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), N''), 100) AS Alliance,
            TRY_CONVERT(decimal(38,0), Power) AS PowerValue,
            PowerRank AS PowerRank,
            TRY_CONVERT(int, [City Hall]) AS CityHall,
            TRY_CONVERT(datetime2(0), ScanDate) AS ScanDateUtc
        FROM dbo.KingdomScanData4
        WHERE GovernorID = @GovernorID
        ORDER BY SCANORDER DESC, ScanDate DESC, SCAN_UNO DESC
    ) AS target
    LEFT JOIN dbo.PlayerLocation AS location ON location.GovernorID = @GovernorID;

    /* Result set 2: scan presence, separate from activity coverage/index. */
    SELECT windows.WindowCode,
           COUNT(DISTINCT scans.ScanOrder) AS CompleteScanCount,
           COUNT(DISTINCT CASE WHEN rows.GovernorID IS NOT NULL THEN scans.ScanOrder END)
               AS PresentScanCount,
           COUNT(DISTINCT scans.AsOfDate) AS ScannedDayCount,
           COUNT(DISTINCT CASE WHEN rows.GovernorID IS NOT NULL THEN scans.AsOfDate END)
               AS PresentScannedDayCount
    FROM #Windows AS windows
    LEFT JOIN #Scans AS scans
      ON scans.AsOfDate BETWEEN windows.StartDate AND windows.EndDate
    LEFT JOIN #StatsRows AS rows
      ON rows.ScanOrder = scans.ScanOrder AND rows.GovernorID = @GovernorID
    GROUP BY windows.WindowCode
    ORDER BY CASE windows.WindowCode WHEN N'CURRENT' THEN 1 ELSE 2 END;

    /* Result set 3: source coverage. */
    SELECT windows.WindowCode, coverage.SourceCode, coverage.RequiredSource,
           coverage.ExpectedUnits, coverage.ValidUnits,
           coverage.ExpectedUnits - coverage.ValidUnits AS MissingUnits,
           coverage.ResetCount, coverage.CoverageState
    FROM #Windows AS windows
    CROSS APPLY
    (
        SELECT N'STATS_SCANS' AS SourceCode, CONVERT(bit, 1) AS RequiredSource,
               (SELECT COUNT(*) FROM #Scans s
                WHERE s.AsOfDate BETWEEN windows.StartDate AND windows.EndDate) AS ExpectedUnits,
               (SELECT COUNT(*) FROM #StatsRows r
                WHERE r.GovernorID = @GovernorID
                  AND r.HelpsValue IS NOT NULL
                  AND r.RSSValue IS NOT NULL
                  AND r.PowerValue IS NOT NULL
                  AND r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate) AS ValidUnits,
               COALESCE((SELECT SUM(ResetCount) FROM #MetricValues m
                         WHERE m.GovernorID = @GovernorID
                           AND m.WindowCode = windows.WindowCode
                           AND m.MetricOrder IN (2, 4)), 0) AS ResetCount,
               CASE
                   WHEN NOT EXISTS (SELECT 1 FROM #StatsRows r WHERE r.GovernorID = @GovernorID
                                    AND r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'NO_DATA'
                   WHEN (SELECT COUNT(*) FROM #Scans s
                         WHERE s.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
                        = (SELECT COUNT(*) FROM #StatsRows r
                           WHERE r.GovernorID = @GovernorID
                             AND r.HelpsValue IS NOT NULL
                             AND r.RSSValue IS NOT NULL
                             AND r.PowerValue IS NOT NULL
                             AND r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'COMPLETE'
                   ELSE N'PARTIAL' END AS CoverageState
        UNION ALL
        SELECT N'ALLIANCE_ACTIVITY', population.IsCurrentlyAllied,
               (SELECT COUNT(*) FROM #ActivityHeaders h
                WHERE h.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate),
               (SELECT COUNT(DISTINCT d.SnapshotDate) FROM #ActivityDaily d
                WHERE d.GovernorID = @GovernorID AND d.IsComplete = 1
                  AND d.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate),
               COALESCE((SELECT SUM(ResetCount) FROM #MetricValues m
                         WHERE m.GovernorID = @GovernorID
                           AND m.WindowCode = windows.WindowCode
                           AND m.MetricOrder IN (3, 5)), 0),
               CASE
                   WHEN population.IsCurrentlyAllied = 0 THEN N'NOT_REQUIRED'
                   WHEN NOT EXISTS (SELECT 1 FROM #ActivityHeaders h
                                    WHERE h.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'NO_DATA'
                   WHEN EXISTS (SELECT 1 FROM #ActivityHeaders h
                                WHERE h.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate
                                  AND h.CompletionState <> N'COMPLETE')
                       THEN N'PARTIAL'
                   WHEN (SELECT COUNT(*) FROM #ActivityHeaders h
                         WHERE h.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate)
                        = (SELECT COUNT(DISTINCT d.SnapshotDate) FROM #ActivityDaily d
                           WHERE d.GovernorID = @GovernorID AND d.IsComplete = 1
                             AND d.SnapshotDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'COMPLETE'
                   ELSE N'PARTIAL' END
        FROM #Population AS population WHERE population.GovernorID = @GovernorID
        UNION ALL
        SELECT N'RALLY_COMPLETED_DATES', CONVERT(bit, 1), @PeriodDays,
               (SELECT COUNT(*) FROM #RallyDates r
                WHERE r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate),
               0,
               CASE
                   WHEN NOT EXISTS (SELECT 1 FROM #RallyDates r
                                    WHERE r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate)
                       THEN N'NO_DATA'
                   WHEN (SELECT COUNT(*) FROM #RallyDates r
                         WHERE r.AsOfDate BETWEEN windows.StartDate AND windows.EndDate) = @PeriodDays
                       THEN N'COMPLETE'
                   ELSE N'PARTIAL' END
    ) AS coverage(SourceCode, RequiredSource, ExpectedUnits, ValidUnits, ResetCount, CoverageState)
    ORDER BY CASE windows.WindowCode WHEN N'CURRENT' THEN 1 ELSE 2 END,
             CASE coverage.SourceCode WHEN N'STATS_SCANS' THEN 1
                  WHEN N'ALLIANCE_ACTIVITY' THEN 2 ELSE 3 END;

    /* Result set 4: the six ordered metrics and equal-period comparison. */
    SELECT current_values.MetricOrder, current_values.MetricCode,
           current_values.MetricTotal AS CurrentTotal,
           current_values.ValidReportingDays AS CurrentValidReportingDays,
           CONVERT(decimal(38,8), current_values.MetricTotal
               / NULLIF(current_values.ValidReportingDays, 0)) AS CurrentAveragePerValidDay,
           previous_values.MetricTotal AS PreviousTotal,
           previous_values.ValidReportingDays AS PreviousValidReportingDays,
           CONVERT(decimal(38,8), previous_values.MetricTotal
               / NULLIF(previous_values.ValidReportingDays, 0)) AS PreviousAveragePerValidDay,
           CASE
               WHEN current_values.IsAvailable = 0 OR previous_values.IsAvailable = 0
                   THEN N'UNAVAILABLE'
               WHEN previous_values.MetricTotal = 0 AND current_values.MetricTotal > 0
                   THEN N'NEW_VS_ZERO'
               WHEN current_values.ValidReportingDays = previous_values.ValidReportingDays
                   THEN N'TOTAL_PERCENT'
               ELSE N'RATE_PERCENT' END AS ComparisonMode,
           CONVERT(decimal(18,4), CASE
               WHEN current_values.IsAvailable = 0 OR previous_values.IsAvailable = 0 THEN NULL
               WHEN previous_values.MetricTotal = 0 AND current_values.MetricTotal = 0 THEN 0
               WHEN previous_values.MetricTotal = 0 THEN NULL
               WHEN current_values.ValidReportingDays = previous_values.ValidReportingDays
                   THEN (current_values.MetricTotal - previous_values.MetricTotal)
                        / NULLIF(ABS(previous_values.MetricTotal), 0) * 100.0
               WHEN previous_values.ValidReportingDays > 0
                   THEN ((current_values.MetricTotal
                            / NULLIF(current_values.ValidReportingDays, 0))
                         - (previous_values.MetricTotal
                            / NULLIF(previous_values.ValidReportingDays, 0)))
                        / NULLIF(ABS(previous_values.MetricTotal
                            / NULLIF(previous_values.ValidReportingDays, 0)), 0) * 100.0
               END) AS ComparisonPercent,
           current_values.ExpectedUnits AS CurrentExpectedUnits,
           current_values.MissingUnits AS CurrentMissingUnits,
           current_values.ResetCount AS CurrentResetCount,
           current_values.IsAvailable AS CurrentIsAvailable,
           ranks.CompetitionRank AS KingdomRank,
           ranks.CohortCount AS RankCohortCount,
           ranks.PercentileScore,
           CONVERT(decimal(9,4), 100.0 - ranks.PercentileScore) AS TopPercent
    FROM #MetricValues AS current_values
    LEFT JOIN #MetricValues AS previous_values
      ON previous_values.GovernorID = current_values.GovernorID
     AND previous_values.MetricOrder = current_values.MetricOrder
     AND previous_values.WindowCode = N'PREVIOUS'
    LEFT JOIN #MetricRanks AS ranks
      ON ranks.GovernorID = current_values.GovernorID
     AND ranks.MetricOrder = current_values.MetricOrder
    WHERE current_values.WindowCode = N'CURRENT'
      AND current_values.GovernorID = @GovernorID
    ORDER BY current_values.MetricOrder;

    /* Result set 5: Activity Index v1 and visible components. */
    SELECT index_values.ActivityIndex, index_values.ActivityRank,
           index_values.CohortCount AS ActivityRankCohortCount,
           MAX(CASE WHEN ranks.MetricOrder = 1 THEN ranks.PercentileScore END) AS FortsScore,
           MAX(CASE WHEN ranks.MetricOrder = 2 THEN ranks.PercentileScore END) AS HelpsScore,
           MAX(CASE WHEN ranks.MetricOrder = 3 THEN ranks.PercentileScore END) AS TechScore,
           MAX(CASE WHEN ranks.MetricOrder = 4 THEN ranks.PercentileScore END) AS RSSScore,
           MAX(CASE WHEN ranks.MetricOrder = 5 THEN ranks.PercentileScore END) AS BuildingScore,
           MAX(CASE WHEN ranks.MetricOrder = 6 THEN ranks.PercentileScore END) AS PowerScore,
           CASE WHEN index_values.GovernorID IS NULL THEN N'MISSING_COMPONENT'
                ELSE N'AVAILABLE' END AS Availability
    FROM (VALUES (@GovernorID)) AS requested(GovernorID)
    LEFT JOIN #ActivityIndex AS index_values
      ON index_values.GovernorID = requested.GovernorID
    LEFT JOIN #MetricRanks AS ranks
      ON ranks.GovernorID = requested.GovernorID
    GROUP BY index_values.GovernorID, index_values.ActivityIndex,
             index_values.ActivityRank, index_values.CohortCount;

    /* Result set 6: source history depth and gap type. */
    CREATE TABLE #HistoryDepth
    (
        SourceCode nvarchar(32) NOT NULL,
        HistoryKind nvarchar(32) NOT NULL,
        EarliestObservedDate date NULL,
        LatestObservedDate date NULL,
        ObservationCount int NOT NULL,
        GapCount int NULL,
        LongestGapDays int NULL,
        EvidenceBasis nvarchar(32) NOT NULL
    );

    DECLARE @HistoryReadStart date = DATEADD(DAY, -719, @AnchorDate);

    ;WITH StatsScans AS
    (
        SELECT SCANORDER AS ScanOrder, MAX(AsOfDate) AS AsOfDate
        FROM dbo.KingdomScanData4
        WHERE AsOfDate BETWEEN @HistoryReadStart AND @AnchorDate
        GROUP BY SCANORDER
    )
    INSERT INTO #HistoryDepth
    SELECT N'KINGDOM_SCANS', N'COMPLETE_SCANORDERS', MIN(AsOfDate), MAX(AsOfDate), COUNT(*),
           NULL, NULL, N'AUTHORITATIVE_SCANORDER'
    FROM StatsScans;

    ;WITH StatsDates AS
    (
        SELECT DISTINCT AsOfDate FROM dbo.KingdomScanData4
        WHERE AsOfDate BETWEEN @HistoryReadStart AND @AnchorDate
    ), StatsGaps AS
    (
        SELECT AsOfDate, DATEDIFF(DAY, LAG(AsOfDate) OVER (ORDER BY AsOfDate), AsOfDate) AS GapDays
        FROM StatsDates
    )
    INSERT INTO #HistoryDepth
    SELECT N'KINGDOM_SCANS', N'SCANNED_DAYS', MIN(AsOfDate), MAX(AsOfDate), COUNT(*),
           SUM(CASE WHEN GapDays > 1 THEN 1 ELSE 0 END),
           MAX(CASE WHEN GapDays > 1 THEN GapDays - 1 END), N'AUTHORITATIVE_SCANORDER'
    FROM StatsGaps;

    ;WITH ActivityDates AS
    (
        SELECT DISTINCT CONVERT(date, SnapshotTsUtc) AS AsOfDate
        FROM dbo.AllianceActivitySnapshotHeader
        WHERE SnapshotTsUtc >= @HistoryReadStart
          AND SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate))
    ), ActivityGaps AS
    (
        SELECT AsOfDate, DATEDIFF(DAY, LAG(AsOfDate) OVER (ORDER BY AsOfDate), AsOfDate) AS GapDays
        FROM ActivityDates
    )
    INSERT INTO #HistoryDepth
    SELECT N'ALLIANCE_ACTIVITY', N'SNAPSHOT_DATES', MIN(AsOfDate), MAX(AsOfDate), COUNT(*),
           SUM(CASE WHEN GapDays > 1 THEN 1 ELSE 0 END),
           MAX(CASE WHEN GapDays > 1 THEN GapDays - 1 END), N'HEADER_COMPLETION_STATE'
    FROM ActivityGaps;

    INSERT INTO #HistoryDepth
    SELECT N'ALLIANCE_ACTIVITY', N'SNAPSHOTS',
           MIN(CONVERT(date, SnapshotTsUtc)), MAX(CONVERT(date, SnapshotTsUtc)), COUNT(*),
           NULL, NULL, N'HEADER_ROWS'
    FROM dbo.AllianceActivitySnapshotHeader
    WHERE SnapshotTsUtc >= @HistoryReadStart
      AND SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate));

    INSERT INTO #HistoryDepth
    SELECT N'ALLIANCE_ACTIVITY', LEFT(N'STATE_' + CompletionState, 32),
           MIN(CONVERT(date, SnapshotTsUtc)), MAX(CONVERT(date, SnapshotTsUtc)), COUNT(*),
           NULL, NULL, CompletionState
    FROM dbo.AllianceActivitySnapshotHeader
    WHERE SnapshotTsUtc >= @HistoryReadStart
      AND SnapshotTsUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate))
    GROUP BY CompletionState;

    ;WITH RallyGaps AS
    (
        SELECT AsOfDate, DATEDIFF(DAY, LAG(AsOfDate) OVER (ORDER BY AsOfDate), AsOfDate) AS GapDays
        FROM dbo.RallyDailySnapshotHeader
        WHERE AsOfDate BETWEEN @HistoryReadStart AND @AnchorDate
    )
    INSERT INTO #HistoryDepth
    SELECT N'RALLY', N'COMPLETED_REPORT_DATES', MIN(AsOfDate), MAX(AsOfDate), COUNT(*),
           SUM(CASE WHEN GapDays > 1 THEN 1 ELSE 0 END),
           MAX(CASE WHEN GapDays > 1 THEN GapDays - 1 END), N'COMPLETION_HEADER'
    FROM RallyGaps;

    INSERT INTO #HistoryDepth
    SELECT N'RALLY', LEFT(N'BASIS_' + CompletionBasis, 32), MIN(AsOfDate), MAX(AsOfDate),
           COUNT(*), NULL, NULL, CompletionBasis
    FROM dbo.RallyDailySnapshotHeader
    WHERE AsOfDate BETWEEN @HistoryReadStart AND @AnchorDate
    GROUP BY CompletionBasis;

    INSERT INTO #HistoryDepth
    SELECT N'ALIASES', N'OBSERVED_NAME_HISTORY',
           CONVERT(date, MIN(FirstSeen)), CONVERT(date, MAX(LastSeen)), COUNT(*),
           NULL, NULL, N'SCAN_BACKFILL'
    FROM dbo.GovernorNameHistory WHERE GovernorID = @GovernorID;

    INSERT INTO #HistoryDepth
    SELECT N'LOCATION', N'CURRENT_SNAPSHOT_ONLY', CONVERT(date, MIN(LastUpdated)),
           CONVERT(date, MAX(LastUpdated)), COUNT(*), NULL, NULL, N'NO_HISTORY_TABLE'
    FROM dbo.PlayerLocation WHERE GovernorID = @GovernorID;

    INSERT INTO #HistoryDepth
    SELECT N'FINAL_KVK', N'OUTPUT_COMPLETION', MIN(CONVERT(date, FinalDataAtUtc)),
           MAX(CONVERT(date, FinalDataAtUtc)), COUNT(*), NULL, NULL, N'FINAL_REPORT_HEADER'
    FROM dbo.KVKFinalReportHeader
    WHERE FinalDataAtUtc >= @HistoryReadStart
      AND FinalDataAtUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate));

    INSERT INTO #HistoryDepth
    SELECT N'FINAL_KVK', LEFT(N'BASIS_' + FinalizationBasis, 32),
           MIN(CONVERT(date, FinalDataAtUtc)), MAX(CONVERT(date, FinalDataAtUtc)),
           COUNT(*), NULL, NULL, FinalizationBasis
    FROM dbo.KVKFinalReportHeader
    WHERE FinalDataAtUtc >= @HistoryReadStart
      AND FinalDataAtUtc < DATEADD(DAY, 1, CONVERT(datetime2(0), @AnchorDate))
    GROUP BY FinalizationBasis;

    SELECT @HistoryReadStart AS ReadStartDate, @AnchorDate AS ReadEndDate,
           SourceCode, HistoryKind, EarliestObservedDate, LatestObservedDate,
           ObservationCount, GapCount, LongestGapDays, EvidenceBasis
    FROM #HistoryDepth
    ORDER BY CASE SourceCode WHEN N'KINGDOM_SCANS' THEN 1 WHEN N'ALLIANCE_ACTIVITY' THEN 2
             WHEN N'RALLY' THEN 3 WHEN N'ALIASES' THEN 4
             WHEN N'LOCATION' THEN 5 ELSE 6 END;
END;
GO
-- Source: sql_schema/dbo.usp_LeadershipPlayerGovernorExists.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_LeadershipPlayerGovernorExists
    @GovernorID bigint
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @GovernorID IS NULL OR @GovernorID <= 0
        THROW 51561, 'Leadership Governor existence requires a positive Governor ID.', 1;

    SELECT
        @GovernorID AS GovernorID,
        CONVERT(bit, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.KingdomScanData4 AS source
            WHERE source.GovernorID = @GovernorID
        )
        THEN 1 ELSE 0 END) AS ExistsInDatabase;
END
GO
-- Source: sql_schema/dbo.usp_UpsertGovernorNameHistoryForScan.StoredProcedure.sql
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_UpsertGovernorNameHistoryForScan
    @ScanOrder int = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ScanOrder IS NULL
        SELECT @ScanOrder = MAX(SCANORDER) FROM dbo.KingdomScanData4;
    IF @ScanOrder IS NULL OR @ScanOrder <= 0
        THROW 51201, 'Governor alias upsert requires a valid scan order.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.KingdomScanData4 WHERE SCANORDER = @ScanOrder)
        THROW 51202, 'Governor alias upsert scan order was not found.', 1;

    CREATE TABLE #AffectedAliases
    (
        GovernorID bigint NOT NULL,
        GovernorNameKey nvarchar(100) NOT NULL,
        PRIMARY KEY CLUSTERED (GovernorID, GovernorNameKey)
    );
    INSERT INTO #AffectedAliases
    SELECT DISTINCT GovernorID,
           dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), GovernorName))
    FROM dbo.KingdomScanData4
    WHERE SCANORDER = @ScanOrder AND GovernorID > 0
      AND dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), GovernorName)) IS NOT NULL;

    CREATE TABLE #ObservedAliases
    (
        GovernorID bigint NOT NULL,
        GovernorNameKey nvarchar(100) NOT NULL,
        GovernorName nvarchar(100) NOT NULL,
        FirstSeen datetime2(0) NOT NULL,
        LastSeen datetime2(0) NOT NULL,
        SeenScanCount int NOT NULL,
        PRIMARY KEY CLUSTERED (GovernorID, GovernorNameKey)
    );
    ;WITH SourceRows AS
    (
        SELECT s.GovernorID,
               a.GovernorNameKey,
               LEFT(LTRIM(RTRIM(CONVERT(nvarchar(255), s.GovernorName))), 100) AS GovernorName,
               TRY_CONVERT(datetime2(0), s.ScanDate) AS ScanDate,
               s.SCANORDER AS ScanOrder
        FROM dbo.KingdomScanData4 AS s
        JOIN #AffectedAliases AS a
          ON a.GovernorID = s.GovernorID
         AND a.GovernorNameKey = dbo.fn_NormalizeGovernorNameKey(CONVERT(nvarchar(255), s.GovernorName))
    ),
    Aggregated AS
    (
        SELECT GovernorID, GovernorNameKey, MIN(ScanDate) AS FirstSeen,
               MAX(ScanDate) AS LastSeen, COUNT(DISTINCT ScanOrder) AS SeenScanCount
        FROM SourceRows
        WHERE GovernorName <> N'' AND ScanDate IS NOT NULL
        GROUP BY GovernorID, GovernorNameKey
    )
    INSERT INTO #ObservedAliases
    SELECT a.GovernorID, a.GovernorNameKey, latest.GovernorName,
           a.FirstSeen, a.LastSeen, a.SeenScanCount
    FROM Aggregated AS a
    CROSS APPLY
    (
        SELECT TOP (1) s.GovernorName
        FROM SourceRows AS s
        WHERE s.GovernorID = a.GovernorID AND s.GovernorNameKey = a.GovernorNameKey
        ORDER BY s.ScanDate DESC, s.ScanOrder DESC, s.GovernorName DESC
    ) AS latest;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE h
        SET FirstSeen = o.FirstSeen, LastSeen = o.LastSeen, SeenScanCount = o.SeenScanCount
        FROM dbo.GovernorNameHistory AS h
        JOIN #ObservedAliases AS o
          ON o.GovernorID = h.GovernorID
         AND o.GovernorNameKey = dbo.fn_NormalizeGovernorNameKey(h.GovernorName);
        INSERT INTO dbo.GovernorNameHistory
            (GovernorID, GovernorName, FirstSeen, LastSeen, SeenScanCount)
        SELECT o.GovernorID, o.GovernorName, o.FirstSeen, o.LastSeen, o.SeenScanCount
        FROM #ObservedAliases AS o
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.GovernorNameHistory AS h WITH (UPDLOCK, HOLDLOCK)
            WHERE h.GovernorID = o.GovernorID
              AND dbo.fn_NormalizeGovernorNameKey(h.GovernorName) = o.GovernorNameKey
        );
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO
-- GENERATED PROCEDURE DEFINITIONS END

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
    THROW 51906, 'Phase 3 post-validation found an unexpected downstream column type.', 1;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
   OR OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL2', N'P') IS NULL
    THROW 51907, 'Phase 3 post-validation found a missing import receipt or procedure contract.', 1;

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
    THROW 51909, 'Phase 3 post-validation found an unprotected private import helper.', 1;

IF EXISTS
(
    SELECT ScanOrder
    FROM dbo.KS4_ImportFileReceipt
    GROUP BY ScanOrder
    HAVING COUNT_BIG(*) > 1
)
    THROW 51908, 'Phase 3 post-validation found duplicate import receipt scan orders.', 1;

COMMIT TRANSACTION;
GO

SELECT
    N'phase3_import_concurrency_and_direct_type_alignment' AS EvidenceSection,
    (SELECT COUNT_BIG(*) FROM dbo.PlayerScanMeta) AS PlayerScanMetaRows,
    (SELECT COUNT_BIG(*) FROM dbo.SUMMARY_PROC_STATE) AS SummaryStateRows,
    (SELECT COUNT_BIG(*) FROM dbo.STAGING_STATS) AS StagingStatsRows,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS ImportReceiptRows,
    N'PASS' AS MigrationStatus;
