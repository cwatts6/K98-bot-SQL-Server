/*
MigrationId: 20260728_001_phase5_immutable_import_file_handoff
Purpose: Bind fallback import claim, digest, bulk load, receipt and archive to one immutable uniquely named file
Author: cwatts
CreatedUtc: 2026-07-28
RequiresBackup: Yes
RiskLevel: High
Rollback: Included
RollbackScript: migrations/rollback/20260728_001_phase5_immutable_import_file_handoff_rollback.sql
TransactionMode: Required
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing rows; creates an empty claim ledger
PreValidationQuery: Run performance_remediation/kingdomscandata4/phase5/01_preflight.sql
PostValidationQuery: Run performance_remediation/kingdomscandata4/phase5/02_verify.sql
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety and deployment plan:
    - Deploy only in the stopped-writer combined maintenance window after
      Phases 2, 3 and 4 pass their exact gates.
    - Require the old reusable downloads\stats.csv path to be empty.
    - Require empty Import_Ready and Import_Claimed directories and a present
      Import_Archive directory before changing the SQL contract.
    - Hold the shared migration and import mutexes for the complete definition
      change.
    - Preserve the Phase 3 receipt table and every committed import row.
    - Create an additive claim ledger, then replace only the five import
      routines that carry file identity plus UPDATE_ALL and UPDATE_ALL2.
    - The bot remains stopped until its matching Phase 5.1 revision atomically
      publishes stats_<32 lowercase hex>.ready.csv and passes that leaf name to SQL.
    - Rollback restores the exact Phase 4-era routine definitions. Archived
      claim evidence is retained if the new protocol was exercised.
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
    THROW 52300, 'Phase 5.0 migration could not acquire the KingdomScanData4 migration mutex.', 1;

DECLARE @ImportLockResult int;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
    @LockTimeout = 60000,
    @LockResult = @ImportLockResult OUTPUT;

IF @ImportLockResult < 0
    THROW 52301, 'Phase 5.0 migration could not acquire the import-pipeline mutex.', 1;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
   OR OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL2', N'P') IS NULL
    THROW 52302, 'Phase 5.0 requires the closed Phase 3 import contracts.', 1;

IF OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative') IS NOT NULL
    THROW 52303, 'Phase 5.0 requires the closed Phase 4 obsolete-view retirement.', 1;

CREATE TABLE #Phase5DeploymentState
(
    HadRetainedClaimEvidence bit NOT NULL
);

INSERT #Phase5DeploymentState (HadRetainedClaimEvidence)
VALUES
(
    CASE WHEN OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NULL THEN 0 ELSE 1 END
);

IF OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NOT NULL
    THROW 52304, 'Phase 5.0 refused a partial or previously applied claim procedure.', 1;

IF OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'CompletedFileName') IS NULL
       OR COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'FileDigest') IS NULL
       OR COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'ClaimStatus') IS NULL
        THROW 52315, 'Phase 5.0 refused incompatible retained claim evidence.', 1;

    DECLARE @HasUnreconciledRetainedClaimEvidence bit = 0;

    -- Compile the retained-row query only after the optional table is known to
    -- exist. A guarded static reference still fails batch compilation on a
    -- clean Phase 4 database where the Phase 5 claim table is not present yet.
    EXEC sys.sp_executesql
        N'
        IF EXISTS
        (
            SELECT 1
            FROM dbo.KS4_ImportFileClaim
            WHERE ClaimStatus NOT IN (N''archived'', N''duplicate_archived'')
        )
            SET @HasUnreconciled = 1;',
        N'@HasUnreconciled bit OUTPUT',
        @HasUnreconciled = @HasUnreconciledRetainedClaimEvidence OUTPUT;

    IF @HasUnreconciledRetainedClaimEvidence = 1
        THROW 52315, 'Phase 5.0 refused unreconciled retained claim evidence.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.crypt_properties AS signature_info
    WHERE signature_info.class_desc = N'OBJECT_OR_COLUMN'
      AND signature_info.major_id IN
      (
          OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE'),
          OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE'),
          OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE'),
          OBJECT_ID(N'dbo.IMPORT_STAGING_PROC'),
          OBJECT_ID(N'dbo.UPDATE_ALL'),
          OBJECT_ID(N'dbo.UPDATE_ALL2')
      )
)
    THROW 52305, 'Phase 5.0 found a signed changed module; preserve or re-apply its signature explicitly.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.configurations
    WHERE name = N'xp_cmdshell'
      AND value_in_use = 1
)
    THROW 52306, 'Phase 5.0 requires the already-approved xp_cmdshell archive capability.', 1;

DECLARE @LegacyFileExists int;
EXEC master.dbo.xp_fileexist
    N'C:\discord_file_downloader\downloads\stats.csv',
    @LegacyFileExists OUTPUT;

IF ISNULL(@LegacyFileExists, 0) = 1
    THROW 52307, 'Phase 5.0 refused to strand the legacy downloads\stats.csv file.', 1;

CREATE TABLE #Phase5PathState
(
    FileExists int NULL,
    FileIsDirectory int NULL,
    ParentDirectoryExists int NULL
);

INSERT #Phase5PathState
EXEC master.dbo.xp_fileexist
    N'C:\discord_file_downloader\downloads\Import_Ready';

IF NOT EXISTS (SELECT 1 FROM #Phase5PathState WHERE FileIsDirectory = 1)
    THROW 52310, 'Phase 5.0 requires the Import_Ready directory.', 1;

TRUNCATE TABLE #Phase5PathState;

INSERT #Phase5PathState
EXEC master.dbo.xp_fileexist
    N'C:\discord_file_downloader\downloads\Import_Claimed';

IF NOT EXISTS (SELECT 1 FROM #Phase5PathState WHERE FileIsDirectory = 1)
    THROW 52311, 'Phase 5.0 requires the SQL-owned Import_Claimed directory.', 1;

TRUNCATE TABLE #Phase5PathState;

INSERT #Phase5PathState
EXEC master.dbo.xp_fileexist
    N'C:\discord_file_downloader\downloads\Import_Archive';

IF NOT EXISTS (SELECT 1 FROM #Phase5PathState WHERE FileIsDirectory = 1)
    THROW 52312, 'Phase 5.0 requires the Import_Archive directory.', 1;

CREATE TABLE #Phase5DirectoryEntry
(
    Subdirectory nvarchar(512) NULL,
    Depth int NULL,
    IsFile bit NULL
);

INSERT #Phase5DirectoryEntry
EXEC master.dbo.xp_dirtree
    N'C:\discord_file_downloader\downloads\Import_Ready',
    1,
    1;

IF EXISTS (SELECT 1 FROM #Phase5DirectoryEntry WHERE IsFile = 1)
    THROW 52313, 'Phase 5.0 requires an empty Import_Ready directory at contract cutover.', 1;

TRUNCATE TABLE #Phase5DirectoryEntry;

INSERT #Phase5DirectoryEntry
EXEC master.dbo.xp_dirtree
    N'C:\discord_file_downloader\downloads\Import_Claimed',
    1,
    1;

IF EXISTS (SELECT 1 FROM #Phase5DirectoryEntry WHERE IsFile = 1)
    THROW 52314, 'Phase 5.0 requires an empty Import_Claimed directory at contract cutover.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'))
       NOT LIKE N'%C:\discord_file_downloader\downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2', N'P'))
       NOT LIKE N'%IMPORT_STAGING_PROC_CORE%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL', N'P'))
       NOT LIKE N'%IMPORT_STAGING_PROC_CORE%'
    THROW 52308, 'Phase 5.0 refused unexpected Phase 3 import-definition drift.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileReceipt
    WHERE ArchiveStatus <> N'archived'
)
    THROW 52309, 'Phase 5.0 requires every Phase 3 receipt archive handoff to be reconciled first.', 1;

-- Canonical Phase 5.0 definitions are appended below in dependency order.

-- Source: sql_schema\dbo.KS4_ImportFileClaim.Table.sql
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileClaim]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_ImportFileClaim](
    [CompletedFileName] [nvarchar](260) NOT NULL,
    [ReadyPath] [nvarchar](4000) NOT NULL,
    [ClaimedPath] [nvarchar](4000) NOT NULL,
    [ArchivePath] [nvarchar](4000) NOT NULL,
    [FileDigest] [binary](32) NULL,
    [ClaimStatus] [nvarchar](24) NOT NULL,
    [ClaimRequestedAtUtc] [datetime2](3) NOT NULL,
    [ClaimedAtUtc] [datetime2](3) NULL,
    [ImportCommittedAtUtc] [datetime2](3) NULL,
    [ArchivedAtUtc] [datetime2](3) NULL,
    [LastError] [nvarchar](2000) NULL,
 CONSTRAINT [PK_KS4_ImportFileClaim] PRIMARY KEY CLUSTERED
(
    [CompletedFileName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ReadyPath] UNIQUE NONCLUSTERED
(
    [ReadyPath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ClaimedPath] UNIQUE NONCLUSTERED
(
    [ClaimedPath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ArchivePath] UNIQUE NONCLUSTERED
(
    [ArchivePath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [CK_KS4_ImportFileClaim_Status] CHECK ([ClaimStatus] IN
    (N'claiming', N'claimed', N'imported', N'archived', N'duplicate', N'duplicate_archived', N'failed'))
) ON [PRIMARY]
END

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.KS4_ImportFileClaim')
      AND name = N'IX_KS4_ImportFileClaim_FileDigest'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_KS4_ImportFileClaim_FileDigest]
        ON [dbo].[KS4_ImportFileClaim] ([FileDigest] ASC)
        INCLUDE ([ClaimStatus], [CompletedFileName]);
END

-- Source: sql_schema\dbo.HASH_KS4_IMPORT_ARCHIVE_FILE.StoredProcedure.sql
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

    DECLARE @ClaimedRoot nvarchar(4000) =
        N'C:\discord_file_downloader\downloads\Import_Claimed\';
    DECLARE @ArchiveRoot nvarchar(4000) =
        N'C:\discord_file_downloader\downloads\Import_Archive\';
    DECLARE @CompletedFileName nvarchar(260);

    IF LEFT(@ApprovedPath, LEN(@ClaimedRoot)) = @ClaimedRoot
        SET @CompletedFileName = SUBSTRING(@ApprovedPath, LEN(@ClaimedRoot) + 1, 260);
    ELSE IF LEFT(@ApprovedPath, LEN(@ArchiveRoot)) = @ArchiveRoot
        SET @CompletedFileName = SUBSTRING(@ApprovedPath, LEN(@ArchiveRoot) + 1, 260);

    IF @CompletedFileName IS NULL
       OR DATALENGTH(@CompletedFileName) <> 96
       OR LEFT(@CompletedFileName, 6) <> N'stats_'
       OR RIGHT(@CompletedFileName, 10) <> N'.ready.csv'
       OR SUBSTRING(@CompletedFileName, 7, 32)
            COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%'
       OR @ApprovedPath NOT IN
          (
              @ClaimedRoot + @CompletedFileName,
              @ArchiveRoot + @CompletedFileName
          )
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

-- Source: sql_schema\dbo.ARCHIVE_IMPORT_STAGING_FILE.StoredProcedure.sql
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ARCHIVE_IMPORT_STAGING_FILE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[ARCHIVE_IMPORT_STAGING_FILE] AS'
END
GO
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
GO

-- Source: sql_schema\dbo.CLAIM_KS4_IMPORT_FILE.StoredProcedure.sql
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CLAIM_KS4_IMPORT_FILE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CLAIM_KS4_IMPORT_FILE] AS'
END
GO
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

-- Source: sql_schema\dbo.IMPORT_STAGING_PROC_CORE.StoredProcedure.sql
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_PROC_CORE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IMPORT_STAGING_PROC_CORE] AS'
END
GO
ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC_CORE]
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
                THROW 51800, 'IMPORT_STAGING_PROC could not acquire the KingdomScanData4 import mutex within 60000 ms; no import work was performed.', 1;

            SELECT
                @CsvPath = ClaimedPath,
                @ArchivePath = ArchivePath,
                @ClaimStatus = ClaimStatus,
                @ClaimDigest = FileDigest
            FROM dbo.KS4_ImportFileClaim WITH (UPDLOCK, HOLDLOCK)
            WHERE CompletedFileName = @CompletedFileName;

            IF @CsvPath IS NULL
               OR @ClaimStatus <> N'claimed'
               OR @ClaimDigest IS NULL
               OR @CsvPath <>
                    N'C:\discord_file_downloader\downloads\Import_Claimed\' + @CompletedFileName
               OR @ArchivePath <>
                    N'C:\discord_file_downloader\downloads\Import_Archive\' + @CompletedFileName
                THROW 51801, 'IMPORT_STAGING_PROC did not find the expected digest-bound claimed file.', 1;

            SET @ImportFileDigest = @ClaimDigest;

            -- File presence and digest are checked only after the database mutex
            -- is held. The producer cannot mutate the SQL-owned claimed path.
            EXEC master.dbo.xp_fileexist @CsvPath, @FileExists OUTPUT;

            IF @FileExists <> 1
                THROW 51801, 'IMPORT_STAGING_PROC did not find the claimed file after acquiring the import mutex.', 1;

            EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
                @ApprovedPath = @CsvPath,
                @FileDigest = @CurrentFileDigest OUTPUT;

            IF @CurrentFileDigest IS NULL
               OR @CurrentFileDigest <> @ImportFileDigest
                THROW 51802, 'IMPORT_STAGING_PROC refused claimed bytes that differ from the durable claim digest.', 1;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
                WHERE FileDigest = @ImportFileDigest
            )
            BEGIN
                DECLARE @DuplicateFileMessage nvarchar(2048) =
                    CONCAT(
                        N'IMPORT_STAGING_PROC refused claimed bytes that already have a committed receipt. ',
                        N'Reconcile claim ',
                        @CompletedFileName,
                        N' for digest 0x',
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

            SET @CurrentFileDigest = NULL;

            EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE
                @ApprovedPath = @CsvPath,
                @FileDigest = @CurrentFileDigest OUTPUT;

            IF @CurrentFileDigest IS NULL
               OR @CurrentFileDigest <> @ImportFileDigest
                THROW 51808, 'IMPORT_STAGING_PROC detected claimed-file mutation across BULK INSERT.', 1;

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

            UPDATE dbo.KS4_ImportFileClaim
            SET ClaimStatus = N'imported',
                ImportCommittedAtUtc = SYSUTCDATETIME(),
                LastError = NULL
            WHERE CompletedFileName = @CompletedFileName
              AND FileDigest = @ImportFileDigest
              AND ClaimedPath = @CsvPath
              AND ArchivePath = @ArchivePath
              AND ClaimStatus = N'claimed';

            IF @@ROWCOUNT <> 1
                THROW 51809, 'IMPORT_STAGING_PROC could not advance exactly one claim to imported.', 1;

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
                    @CompletedFileName = @CompletedFileName;

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
            DECLARE @ErrNumber INT = ERROR_NUMBER();
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @ErrLine INT = ERROR_LINE();
            DECLARE @ErrProc NVARCHAR(128) = ERROR_PROCEDURE();
            DECLARE @PersistedError NVARCHAR(2000) =
                LEFT(
                    CONCAT(
                        N'Error ',
                        ERROR_NUMBER(),
                        N' in ',
                        COALESCE(ERROR_PROCEDURE(), N'Ad-hoc'),
                        N' line ',
                        ERROR_LINE(),
                        N': ',
                        COALESCE(ERROR_MESSAGE(), N'(no message)')
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
                      AND ClaimStatus = N'claimed';
                END TRY
                BEGIN CATCH
                    -- Never replace the original import failure with a ledger
                    -- persistence error.
                END CATCH;
            END;

            -- OPTIMIZATION: Enhanced error reporting
            PRINT 'Error occurred in procedure: ' + ISNULL(@ErrProc, 'Ad-hoc');
            PRINT 'Error line: ' + CAST(@ErrLine AS VARCHAR(10));
            PRINT 'Error number: ' + CAST(@ErrNumber AS VARCHAR(10));
            PRINT 'Error message: ' + COALESCE(@ErrMsg, N'(no message)');

            RETURN 1; -- Failure
    END CATCH
END
GO

-- Source: sql_schema\dbo.IMPORT_STAGING_PROC.StoredProcedure.sql
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IMPORT_STAGING_PROC] AS'
END
GO
ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC]
    @CompletedFileName [nvarchar](260),
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
    DECLARE @ClaimedPath nvarchar(4000);
    DECLARE @ImportError nvarchar(2000);

    EXEC dbo.CLAIM_KS4_IMPORT_FILE
        @CompletedFileName = @CompletedFileName,
        @FileDigest = @ImportFileDigest OUTPUT,
        @ClaimedPath = @ClaimedPath OUTPUT,
        @ArchivePath = @ArchivePath OUTPUT;

    EXEC @ReturnCode = dbo.IMPORT_STAGING_PROC_CORE
        @CompletedFileName = @CompletedFileName,
        @ImportFileDigest = @ImportFileDigest OUTPUT,
        @ArchivePath = @ArchivePath OUTPUT,
        @ImportError = @ImportError OUTPUT;

    RETURN @ReturnCode;
END
GO

-- Source: sql_schema\dbo.UPDATE_ALL.StoredProcedure.sql
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL] AS' 
END
GO
ALTER PROCEDURE [dbo].[UPDATE_ALL]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL,
    @CompletedFileName [nvarchar](260)
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
        DECLARE @ImportFileDigest BINARY(32);
        DECLARE @ImportClaimedPath NVARCHAR(4000);
        DECLARE @ImportArchivePath NVARCHAR(4000);
        DECLARE @ImportError NVARCHAR(2000);

        EXEC dbo.CLAIM_KS4_IMPORT_FILE
            @CompletedFileName = @CompletedFileName,
            @FileDigest = @ImportFileDigest OUTPUT,
            @ClaimedPath = @ImportClaimedPath OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT;

        BEGIN TRANSACTION;

        DECLARE @ImportLockResult INT;
        DECLARE @ImportReturnCode INT;
        DECLARE @AllocatedScanOrder INT;
        DECLARE @StagedRows INT;
        DECLARE @RowsKS5 INT;
        DECLARE @RowsKS4 INT;
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
            @CompletedFileName = @CompletedFileName,
            @ImportFileDigest = @ImportFileDigest OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT,
            @ImportError = @ImportError OUTPUT;

        IF @ImportReturnCode <> 0
        BEGIN
            SET @ImportError = COALESCE(
                @ImportError,
                N'UPDATE_ALL stopped because IMPORT_STAGING_PROC failed without returning error detail.'
            );
            THROW 51821, @ImportError, 1;
        END;

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
            @CompletedFileName = @CompletedFileName;

        IF @ArchiveReturnCode <> 0
            THROW 51827, 'UPDATE_ALL committed its database work but the immutable-file archive handoff did not complete.', 1;

		INSERT INTO Update_ALL_Complete (CompletionTime)
		VALUES (GETDATE());


    END TRY
    BEGIN CATCH
        DECLARE @OuterPersistedError nvarchar(2000) =
            LEFT(
                COALESCE(
                    @ImportError,
                    CONCAT(
                        N'Error ',
                        ERROR_NUMBER(),
                        N' in ',
                        COALESCE(ERROR_PROCEDURE(), N'UPDATE_ALL'),
                        N' line ',
                        ERROR_LINE(),
                        N': ',
                        COALESCE(ERROR_MESSAGE(), N'(no message)')
                    )
                ),
                2000
            );

        IF XACT_STATE() <> 0
            ROLLBACK;

        BEGIN TRY
            UPDATE dbo.KS4_ImportFileClaim
            SET LastError = @OuterPersistedError
            WHERE CompletedFileName = @CompletedFileName
              AND ClaimStatus = N'claimed';
        END TRY
        BEGIN CATCH
            -- Never mask the original UPDATE_ALL failure.
        END CATCH;

        SET ANSI_WARNINGS ON;
        THROW;
    END CATCH
END;
GO

-- Source: sql_schema\dbo.UPDATE_ALL2.StoredProcedure.sql
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL2] AS' 
END
GO
ALTER PROCEDURE [dbo].[UPDATE_ALL2]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL,
    @CompletedFileName [nvarchar](260)
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
    DECLARE @ImportClaimedPath NVARCHAR(4000);
    DECLARE @ImportArchivePath NVARCHAR(4000);
    DECLARE @ImportError NVARCHAR(2000);
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
        EXEC dbo.CLAIM_KS4_IMPORT_FILE
            @CompletedFileName = @CompletedFileName,
            @FileDigest = @ImportFileDigest OUTPUT,
            @ClaimedPath = @ImportClaimedPath OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT;

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
            @CompletedFileName = @CompletedFileName,
            @ImportFileDigest = @ImportFileDigest OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT,
            @ImportError = @ImportError OUTPUT;
        IF @rc <> 0
        BEGIN
            SET @ImportError = COALESCE(
                @ImportError,
                N'UPDATE_ALL2 stopped because IMPORT_STAGING_PROC failed without returning error detail.'
            );
            THROW 51819, @ImportError, 1;
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
            @CompletedFileName = @CompletedFileName;

        IF @ArchiveReturnCode <> 0
            THROW 51817, 'UPDATE_ALL2 committed Phase A but the immutable-file archive handoff did not complete.', 1;

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
        DECLARE @PersistedImportError NVARCHAR(2000) =
            LEFT(
                COALESCE(
                    @ImportError,
                    CONCAT(
                        N'Error ',
                        ERROR_NUMBER(),
                        N' in ',
                        COALESCE(ERROR_PROCEDURE(), N'UPDATE_ALL2'),
                        N' line ',
                        ERROR_LINE(),
                        N': ',
                        COALESCE(ERROR_MESSAGE(), N'(no message)')
                    )
                ),
                2000
            );

		-- ✅ capture transaction state before doing anything
		DECLARE @XState INT = XACT_STATE();

		-- ✅ if a transaction exists, you MUST rollback first (especially if @XState = -1)
		IF @XState <> 0
			ROLLBACK;

        BEGIN TRY
            UPDATE dbo.KS4_ImportFileClaim
            SET LastError = @PersistedImportError
            WHERE CompletedFileName = @CompletedFileName
              AND ClaimStatus = N'claimed';
        END TRY
        BEGIN CATCH
            -- Never mask the original UPDATE_ALL2 failure.
        END CATCH;

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

DENY EXECUTE ON OBJECT::dbo.CLAIM_KS4_IMPORT_FILE TO public;
DENY EXECUTE ON OBJECT::dbo.IMPORT_STAGING_PROC_CORE TO public;
DENY EXECUTE ON OBJECT::dbo.HASH_KS4_IMPORT_ARCHIVE_FILE TO public;
DENY SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.KS4_ImportFileClaim TO public;

EXEC sys.sp_refreshsqlmodule N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE';
EXEC sys.sp_refreshsqlmodule N'dbo.ARCHIVE_IMPORT_STAGING_FILE';
EXEC sys.sp_refreshsqlmodule N'dbo.CLAIM_KS4_IMPORT_FILE';
EXEC sys.sp_refreshsqlmodule N'dbo.IMPORT_STAGING_PROC_CORE';
EXEC sys.sp_refreshsqlmodule N'dbo.IMPORT_STAGING_PROC';
EXEC sys.sp_refreshsqlmodule N'dbo.UPDATE_ALL';
EXEC sys.sp_refreshsqlmodule N'dbo.UPDATE_ALL2';

IF OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NULL
   OR OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NULL
    THROW 52320, 'Phase 5.0 did not create the immutable claim objects.', 1;

IF EXISTS
(
    SELECT expected.ParameterName
    FROM
    (
        VALUES
            (N'dbo.IMPORT_STAGING_PROC_CORE', N'@CompletedFileName'),
            (N'dbo.IMPORT_STAGING_PROC', N'@CompletedFileName'),
            (N'dbo.UPDATE_ALL', N'@CompletedFileName'),
            (N'dbo.UPDATE_ALL2', N'@CompletedFileName'),
            (N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'@CompletedFileName')
    ) AS expected(ObjectName, ParameterName)
    LEFT JOIN sys.parameters AS actual
      ON actual.object_id = OBJECT_ID(expected.ObjectName, N'P')
     AND actual.name = expected.ParameterName
     AND actual.system_type_id = TYPE_ID(N'nvarchar')
     AND actual.max_length = 520
    WHERE actual.parameter_id IS NULL
)
    THROW 52321, 'Phase 5.0 did not propagate the immutable filename contract through every SQL entry point.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P')
      AND name = N'@ImportError'
      AND system_type_id = TYPE_ID(N'nvarchar')
      AND max_length = 4000
      AND is_output = 1
)
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL', N'P'))
        LIKE N'%@CompletedFileName [nvarchar](260) = NULL%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2', N'P'))
        LIKE N'%@CompletedFileName [nvarchar](260) = NULL%'
    THROW 52325, 'Phase 5.0 left an optional filename or incomplete error-handoff contract.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'))
       LIKE N'%downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P'))
       LIKE N'%downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       LIKE N'%downloads\stats.csv%'
    THROW 52322, 'Phase 5.0 left the reusable stats.csv pathname in the immutable consumer chain.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
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
    THROW 52323, 'Phase 5.0 is missing a claim, post-bulk rehash, or post-archive rehash guard.', 1;

IF EXISTS
(
    SELECT 1
    FROM #Phase5DeploymentState
    WHERE HadRetainedClaimEvidence = 0
)
AND EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim
)
    THROW 52324, 'Phase 5.0 claim ledger was not empty immediately after deployment.', 1;

COMMIT TRANSACTION;
GO

SELECT
    N'phase5_immutable_import_file_handoff' AS EvidenceSection,
    N'PASS' AS MigrationStatus,
    OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') AS ClaimTableObjectId,
    OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') AS ClaimProcedureObjectId;
