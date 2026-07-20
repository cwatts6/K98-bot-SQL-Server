SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
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

    IF @AsOfDate IS NULL THROW 51001, 'Rally import requires AsOfDate.', 1;
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
            SAVE TRANSACTION RallyDailyImportSavepoint;

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
            SELECT 1 FROM dbo.stg_RallyDaily
            WHERE AsOfDate = @AsOfDate
              AND ((@ImportToken IS NULL AND ImportToken IS NULL) OR ImportToken = @ImportToken)
              AND (GovernorID <= 0 OR TotalRallies < 0 OR RalliesLaunched < 0 OR RalliesJoined < 0)
        )
            THROW 51008, 'Rally staging contains invalid IDs or negative counts.', 1;

        DELETE FROM dbo.cur_RallyDaily WHERE AsOfDate = @AsOfDate;

        INSERT INTO dbo.cur_RallyDaily
            (AsOfDate, GovernorID, GovernorName, TotalRallies,
             RalliesLaunched, RalliesJoined, InsertedAt)
        SELECT AsOfDate, GovernorID, GovernorName, TotalRallies,
               RalliesLaunched, RalliesJoined, SYSUTCDATETIME()
        FROM dbo.stg_RallyDaily
        WHERE AsOfDate = @AsOfDate
          AND ((@ImportToken IS NULL AND ImportToken IS NULL) OR ImportToken = @ImportToken);

        EXEC dbo.sp_Rebuild_RALLY_EXPORT;
        EXEC dbo.sp_Snapshot_PlayerForts @SnapshotAt = @AsOfDate;

        SELECT @ExistingRevision = Revision
        FROM dbo.RallyDailySnapshotHeader WITH (UPDLOCK, HOLDLOCK)
        WHERE AsOfDate = @AsOfDate;

        IF @ExistingRevision IS NULL
            INSERT INTO dbo.RallyDailySnapshotHeader
                (AsOfDate, CompletedAtUtc, SourceRowCount, DistinctGovernorCount,
                 Revision, CompletionBasis, ImportBatchID)
            VALUES
                (@AsOfDate, SYSUTCDATETIME(), @SourceRowCount, @DistinctGovernorCount,
                 1, @CompletionBasis, @ImportBatchID);
        ELSE
            UPDATE dbo.RallyDailySnapshotHeader
            SET CompletedAtUtc = SYSUTCDATETIME(),
                SourceRowCount = @SourceRowCount,
                DistinctGovernorCount = @DistinctGovernorCount,
                Revision = @ExistingRevision + 1,
                CompletionBasis = @CompletionBasis,
                ImportBatchID = @ImportBatchID
            WHERE AsOfDate = @AsOfDate;

        DELETE FROM dbo.stg_RallyDaily
        WHERE AsOfDate = @AsOfDate
          AND ((@ImportToken IS NULL AND ImportToken IS NULL) OR ImportToken = @ImportToken);

        IF @StartedTransaction = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = -1 ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 AND @StartedTransaction = 1 ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1 ROLLBACK TRANSACTION RallyDailyImportSavepoint;
        THROW;
    END CATCH;
END
