SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_BackfillRallyDailySnapshotCompletion]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_BackfillRallyDailySnapshotCompletion] AS' 
END
ALTER PROCEDURE [dbo].[usp_BackfillRallyDailySnapshotCompletion]
	@AsOfDate [date],
	@ExpectedRowCount [int],
	@CompletionBasis [nvarchar](24),
	@CompletedAtUtc [datetime2](0),
	@ImportBatchID [bigint] = NULL
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

