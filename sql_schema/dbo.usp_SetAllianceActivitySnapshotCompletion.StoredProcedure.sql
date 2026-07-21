SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE OR ALTER PROCEDURE dbo.usp_SetAllianceActivitySnapshotCompletion
    @SnapshotID bigint,
    @CompletionState nvarchar(24),
    @ExpectedGovernorCount int,
    @ObservedGovernorCount int,
    @MissingExpectedGovernorCount int,
    @InvalidMetricCount int,
    @ValidatedAtUtc datetime2(0) = NULL,
    @MissingMetricCount int = 0,
    @CompletionBasis nvarchar(32) = N'SOURCE_VALIDATED'
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @SnapshotID <= 0
        THROW 51101, 'Alliance Activity completion requires a valid SnapshotID.', 1;
    IF @CompletionState NOT IN (N'COMPLETE', N'PARTIAL')
        THROW 51102, 'Alliance Activity completion state must be COMPLETE or PARTIAL.', 1;
    IF @ExpectedGovernorCount IS NULL OR @ObservedGovernorCount IS NULL
       OR @MissingExpectedGovernorCount IS NULL OR @MissingMetricCount IS NULL
       OR @InvalidMetricCount IS NULL
        THROW 51107, 'Alliance Activity completion requires non-null evidence counts.', 1;
    IF @ExpectedGovernorCount < 0 OR @ObservedGovernorCount < 0
       OR @MissingExpectedGovernorCount < 0 OR @MissingMetricCount < 0
       OR @InvalidMetricCount < 0
        THROW 51103, 'Alliance Activity completion counts cannot be negative.', 1;
    IF @CompletionBasis NOT IN (N'SOURCE_VALIDATED', N'LEGACY_ASSUMED_ZERO')
        THROW 51108, 'Alliance Activity completion basis is invalid.', 1;

    DECLARE @OwnsTransaction bit = 0;
    DECLARE @StoredRowCount int;

    IF @@TRANCOUNT = 0
    BEGIN
        SET @OwnsTransaction = 1;
        BEGIN TRANSACTION;
    END;

    BEGIN TRY
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.AllianceActivitySnapshotHeader WITH (UPDLOCK, HOLDLOCK)
            WHERE SnapshotId = @SnapshotID
        )
            THROW 51106, 'Alliance Activity snapshot header was not found.', 1;

        SELECT @StoredRowCount = COUNT(*)
        FROM dbo.AllianceActivitySnapshotRow WITH (UPDLOCK, HOLDLOCK)
        WHERE SnapshotId = @SnapshotID;

        IF @ObservedGovernorCount <> @StoredRowCount
            THROW 51104, 'Alliance Activity observed count does not match stored snapshot rows.', 1;
        IF @CompletionState = N'COMPLETE'
           AND (@MissingExpectedGovernorCount <> 0 OR @MissingMetricCount <> 0
                OR @InvalidMetricCount <> 0)
            THROW 51105, 'A COMPLETE Alliance Activity snapshot requires full explicit-value coverage.', 1;

        UPDATE dbo.AllianceActivitySnapshotHeader
        SET CompletionState = @CompletionState,
            ExpectedGovernorCount = @ExpectedGovernorCount,
            ObservedGovernorCount = @ObservedGovernorCount,
            MissingExpectedGovernorCount = @MissingExpectedGovernorCount,
            MissingMetricCount = @MissingMetricCount,
            InvalidMetricCount = @InvalidMetricCount,
            ValidatedAtUtc = COALESCE(@ValidatedAtUtc, SYSUTCDATETIME()),
            CompletionBasis = @CompletionBasis
        WHERE SnapshotId = @SnapshotID;

        IF @OwnsTransaction = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @OwnsTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
