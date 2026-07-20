/*
MigrationId: 20260719_001_add_rally_daily_completion_contract
Purpose: Add authoritative Rally report completion evidence and transactional date replacement
Author: cwatts
CreatedUtc: 2026-07-19
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Required
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: Existing Rally rows are not changed during deployment
PreValidationQuery: SELECT COUNT(*) AS RallyRows, COUNT(DISTINCT AsOfDate) AS RallyDates FROM dbo.cur_RallyDaily;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.RallyDailySnapshotHeader', N'U') AS HeaderTable, COL_LENGTH(N'dbo.stg_RallyDaily', N'ImportToken') AS ImportTokenColumn, OBJECT_ID(N'dbo.sp_Import_Rally_Daily', N'P') AS ImportProcedure, OBJECT_ID(N'dbo.usp_BackfillRallyDailySnapshotCompletion', N'P') AS BackfillProcedure;
RelatedBotPR:
RelatedSQLPR:

Data safety:
- Deployment adds metadata only and does not infer historical completion.
- Runtime replacement is bounded to one explicit @AsOfDate and is transactional.
- The completion header is written only after dependent rebuild/snapshot procedures succeed.
- Existing callers remain compatible through optional parameters and the legacy NULL-token path.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.RallyDailySnapshotHeader', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RallyDailySnapshotHeader
    (
        AsOfDate date NOT NULL,
        CompletedAtUtc datetime2(0) NOT NULL,
        SourceRowCount int NOT NULL,
        DistinctGovernorCount int NOT NULL,
        Revision int NOT NULL,
        CompletionBasis nvarchar(24) NOT NULL,
        ImportBatchID bigint NULL,
        CONSTRAINT PK_RallyDailySnapshotHeader PRIMARY KEY CLUSTERED (AsOfDate),
        CONSTRAINT CK_RallyDailySnapshotHeader_Counts CHECK
            (SourceRowCount >= 0 AND DistinctGovernorCount >= 0
             AND DistinctGovernorCount <= SourceRowCount),
        CONSTRAINT CK_RallyDailySnapshotHeader_Revision CHECK (Revision > 0),
        CONSTRAINT CK_RallyDailySnapshotHeader_Basis CHECK
            (CompletionBasis IN
                (N'LIVE_IMPORT', N'AUDIT_BACKFILL', N'OTHER_AUTHORITY', N'INFERRED_DATE'))
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_BackfillRallyDailySnapshotCompletion
    @AsOfDate date,
    @ExpectedRowCount int,
    @CompletionBasis nvarchar(24),
    @CompletedAtUtc datetime2(0),
    @ImportBatchID bigint = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @AsOfDate IS NULL OR @CompletedAtUtc IS NULL OR @ExpectedRowCount < 0
        THROW 51009, 'Rally completion backfill requires date, timestamp, and non-negative row count.', 1;
    IF @CompletionBasis NOT IN (N'AUDIT_BACKFILL', N'OTHER_AUTHORITY', N'INFERRED_DATE')
        THROW 51010, 'Rally completion backfill basis must identify its historical authority.', 1;

    DECLARE @SourceRowCount int;
    DECLARE @DistinctGovernorCount int;
    DECLARE @ExistingRevision int;
    DECLARE @LockResult int;
    DECLARE @LockResource nvarchar(255) =
        N'K98:RallyDaily:' + CONVERT(nvarchar(10), @AsOfDate, 23);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = N'Exclusive',
            @LockOwner = N'Transaction',
            @LockTimeout = 10000;
        IF @LockResult < 0
            THROW 51011, 'Rally completion backfill could not acquire the date lock.', 1;

        SELECT @SourceRowCount = COUNT(*),
               @DistinctGovernorCount = COUNT(DISTINCT GovernorID)
        FROM dbo.cur_RallyDaily
        WHERE AsOfDate = @AsOfDate;

        IF @SourceRowCount <> @ExpectedRowCount
            THROW 51012, 'Rally completion backfill row count does not match stored daily rows.', 1;
        IF @SourceRowCount <> @DistinctGovernorCount
            THROW 51013, 'Rally completion backfill found duplicate or null Governor IDs.', 1;

        SELECT @ExistingRevision = Revision
        FROM dbo.RallyDailySnapshotHeader WITH (UPDLOCK, HOLDLOCK)
        WHERE AsOfDate = @AsOfDate;

        IF @ExistingRevision IS NULL
            INSERT INTO dbo.RallyDailySnapshotHeader
                (AsOfDate, CompletedAtUtc, SourceRowCount, DistinctGovernorCount,
                 Revision, CompletionBasis, ImportBatchID)
            VALUES
                (@AsOfDate, @CompletedAtUtc, @SourceRowCount, @DistinctGovernorCount,
                 1, @CompletionBasis, @ImportBatchID);
        ELSE
            UPDATE dbo.RallyDailySnapshotHeader
            SET CompletedAtUtc = @CompletedAtUtc,
                SourceRowCount = @SourceRowCount,
                DistinctGovernorCount = @DistinctGovernorCount,
                Revision = @ExistingRevision + 1,
                CompletionBasis = @CompletionBasis,
                ImportBatchID = @ImportBatchID
            WHERE AsOfDate = @AsOfDate;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

IF COL_LENGTH(N'dbo.stg_RallyDaily', N'ImportToken') IS NULL
BEGIN
    ALTER TABLE dbo.stg_RallyDaily ADD ImportToken uniqueidentifier NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Import_Rally_Daily
    @AsOfDate date,
    @ImportToken uniqueidentifier = NULL,
    @ExpectedRowCount int = NULL,
    @CompletionBasis nvarchar(24) = N'LIVE_IMPORT',
    @ImportBatchID bigint = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @AsOfDate IS NULL
        THROW 51001, 'Rally import requires AsOfDate.', 1;

    IF @ExpectedRowCount IS NOT NULL AND @ExpectedRowCount < 0
        THROW 51002, 'Rally import ExpectedRowCount cannot be negative.', 1;

    IF @CompletionBasis NOT IN
        (N'LIVE_IMPORT', N'AUDIT_BACKFILL', N'OTHER_AUTHORITY', N'INFERRED_DATE')
        THROW 51003, 'Rally import received an invalid completion basis.', 1;

    DECLARE @StartedTransaction bit = 0;
    DECLARE @LockResult int;
    DECLARE @SourceRowCount int;
    DECLARE @DistinctGovernorCount int;
    DECLARE @ExistingRevision int;
    DECLARE @LockResource nvarchar(255) =
        N'K98:RallyDaily:' + CONVERT(nvarchar(10), @AsOfDate, 23);

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTransaction = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION RallyDailyImportSavepoint;
        END;

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = N'Exclusive',
            @LockOwner = N'Transaction',
            @LockTimeout = 10000;

        IF @LockResult < 0
            THROW 51004, 'Rally import could not acquire the date replacement lock.', 1;

        SELECT
            @SourceRowCount = COUNT(*),
            @DistinctGovernorCount = COUNT(DISTINCT GovernorID)
        FROM dbo.stg_RallyDaily
        WHERE AsOfDate = @AsOfDate
          AND ((@ImportToken IS NULL AND ImportToken IS NULL) OR ImportToken = @ImportToken);

        IF @ExpectedRowCount IS NOT NULL AND @SourceRowCount <> @ExpectedRowCount
            THROW 51005, 'Rally staged row count does not match ExpectedRowCount.', 1;

        IF @ExpectedRowCount IS NULL AND @SourceRowCount = 0
            THROW 51006, 'Legacy Rally import cannot replace a date from empty staging.', 1;

        IF @SourceRowCount <> @DistinctGovernorCount
            THROW 51007, 'Rally staging contains duplicate Governor IDs for the date.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.stg_RallyDaily
            WHERE AsOfDate = @AsOfDate
              AND ((@ImportToken IS NULL AND ImportToken IS NULL) OR ImportToken = @ImportToken)
              AND (GovernorID <= 0 OR TotalRallies < 0 OR RalliesLaunched < 0 OR RalliesJoined < 0)
        )
            THROW 51008, 'Rally staging contains invalid IDs or negative counts.', 1;

        DELETE FROM dbo.cur_RallyDaily
        WHERE AsOfDate = @AsOfDate;

        INSERT INTO dbo.cur_RallyDaily
        (
            AsOfDate,
            GovernorID,
            GovernorName,
            TotalRallies,
            RalliesLaunched,
            RalliesJoined,
            InsertedAt
        )
        SELECT
            AsOfDate,
            GovernorID,
            GovernorName,
            TotalRallies,
            RalliesLaunched,
            RalliesJoined,
            SYSUTCDATETIME()
        FROM dbo.stg_RallyDaily
        WHERE AsOfDate = @AsOfDate
          AND ((@ImportToken IS NULL AND ImportToken IS NULL) OR ImportToken = @ImportToken);

        EXEC dbo.sp_Rebuild_RALLY_EXPORT;
        EXEC dbo.sp_Snapshot_PlayerForts @SnapshotAt = @AsOfDate;

        SELECT @ExistingRevision = Revision
        FROM dbo.RallyDailySnapshotHeader WITH (UPDLOCK, HOLDLOCK)
        WHERE AsOfDate = @AsOfDate;

        IF @ExistingRevision IS NULL
        BEGIN
            INSERT INTO dbo.RallyDailySnapshotHeader
            (
                AsOfDate,
                CompletedAtUtc,
                SourceRowCount,
                DistinctGovernorCount,
                Revision,
                CompletionBasis,
                ImportBatchID
            )
            VALUES
            (
                @AsOfDate,
                SYSUTCDATETIME(),
                @SourceRowCount,
                @DistinctGovernorCount,
                1,
                @CompletionBasis,
                @ImportBatchID
            );
        END
        ELSE
        BEGIN
            UPDATE dbo.RallyDailySnapshotHeader
            SET CompletedAtUtc = SYSUTCDATETIME(),
                SourceRowCount = @SourceRowCount,
                DistinctGovernorCount = @DistinctGovernorCount,
                Revision = @ExistingRevision + 1,
                CompletionBasis = @CompletionBasis,
                ImportBatchID = @ImportBatchID
            WHERE AsOfDate = @AsOfDate;
        END;

        DELETE FROM dbo.stg_RallyDaily
        WHERE AsOfDate = @AsOfDate
          AND ((@ImportToken IS NULL AND ImportToken IS NULL) OR ImportToken = @ImportToken);

        IF @StartedTransaction = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 AND @StartedTransaction = 1
            ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1
            ROLLBACK TRANSACTION RallyDailyImportSavepoint;
        THROW;
    END CATCH;
END;
GO
