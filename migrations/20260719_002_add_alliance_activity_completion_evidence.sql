/*
MigrationId: 20260719_002_add_alliance_activity_completion_evidence
Purpose: Record whether Alliance Activity snapshots prove full-roster explicit-zero coverage
Author: cwatts
CreatedUtc: 2026-07-19
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: One metadata update per existing AllianceActivitySnapshotHeader row
PreValidationQuery: SELECT COUNT(*) AS ExistingSnapshots FROM dbo.AllianceActivitySnapshotHeader;
PostValidationQuery: SELECT CompletionState, COUNT(*) AS Snapshots FROM dbo.AllianceActivitySnapshotHeader GROUP BY CompletionState;
RelatedBotPR:
RelatedSQLPR:

Data safety:
- Existing snapshots are labelled LEGACY_UNVERIFIED; no historical source is silently certified.
- Existing activity rows are not changed.
- The completion procedure checks its supplied counts against the stored row count.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF COL_LENGTH(N'dbo.AllianceActivitySnapshotHeader', N'CompletionState') IS NULL
BEGIN
    ALTER TABLE dbo.AllianceActivitySnapshotHeader
        ADD CompletionState nvarchar(24) NULL;
END;

IF COL_LENGTH(N'dbo.AllianceActivitySnapshotHeader', N'ExpectedGovernorCount') IS NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader ADD ExpectedGovernorCount int NULL;
IF COL_LENGTH(N'dbo.AllianceActivitySnapshotHeader', N'ObservedGovernorCount') IS NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader ADD ObservedGovernorCount int NULL;
IF COL_LENGTH(N'dbo.AllianceActivitySnapshotHeader', N'MissingExpectedGovernorCount') IS NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader ADD MissingExpectedGovernorCount int NULL;
IF COL_LENGTH(N'dbo.AllianceActivitySnapshotHeader', N'InvalidMetricCount') IS NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader ADD InvalidMetricCount int NULL;
IF COL_LENGTH(N'dbo.AllianceActivitySnapshotHeader', N'ValidatedAtUtc') IS NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader ADD ValidatedAtUtc datetime2(0) NULL;
GO

UPDATE dbo.AllianceActivitySnapshotHeader
SET CompletionState = N'LEGACY_UNVERIFIED'
WHERE CompletionState IS NULL;
GO

ALTER TABLE dbo.AllianceActivitySnapshotHeader
    ALTER COLUMN CompletionState nvarchar(24) NOT NULL;
GO

IF OBJECT_ID(N'dbo.DF_AllianceActivityHeader_CompletionState', N'D') IS NULL
BEGIN
    ALTER TABLE dbo.AllianceActivitySnapshotHeader
        ADD CONSTRAINT DF_AllianceActivityHeader_CompletionState
        DEFAULT (N'LEGACY_UNVERIFIED') FOR CompletionState;
END;
GO

IF OBJECT_ID(N'dbo.CK_AllianceActivityHeader_CompletionState', N'C') IS NULL
BEGIN
    ALTER TABLE dbo.AllianceActivitySnapshotHeader WITH CHECK
        ADD CONSTRAINT CK_AllianceActivityHeader_CompletionState
        CHECK (CompletionState IN (N'COMPLETE', N'PARTIAL', N'LEGACY_UNVERIFIED'));
END;
GO

IF OBJECT_ID(N'dbo.CK_AllianceActivityHeader_EvidenceCounts', N'C') IS NULL
BEGIN
    ALTER TABLE dbo.AllianceActivitySnapshotHeader WITH CHECK
        ADD CONSTRAINT CK_AllianceActivityHeader_EvidenceCounts
        CHECK
        (
            (ExpectedGovernorCount IS NULL OR ExpectedGovernorCount >= 0)
            AND (ObservedGovernorCount IS NULL OR ObservedGovernorCount >= 0)
            AND (MissingExpectedGovernorCount IS NULL OR MissingExpectedGovernorCount >= 0)
            AND (InvalidMetricCount IS NULL OR InvalidMetricCount >= 0)
        );
END;
GO

IF OBJECT_ID(N'dbo.CK_AllianceActivityHeader_CompleteEvidence', N'C') IS NULL
BEGIN
    ALTER TABLE dbo.AllianceActivitySnapshotHeader WITH CHECK
        ADD CONSTRAINT CK_AllianceActivityHeader_CompleteEvidence
        CHECK
        (
            CompletionState <> N'COMPLETE'
            OR
            (
                ExpectedGovernorCount IS NOT NULL
                AND ObservedGovernorCount IS NOT NULL
                AND MissingExpectedGovernorCount IS NOT NULL
                AND InvalidMetricCount IS NOT NULL
                AND ValidatedAtUtc IS NOT NULL
                AND MissingExpectedGovernorCount = 0
                AND InvalidMetricCount = 0
                AND ExpectedGovernorCount = ObservedGovernorCount
            )
        );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SetAllianceActivitySnapshotCompletion
    @SnapshotID bigint,
    @CompletionState nvarchar(24),
    @ExpectedGovernorCount int,
    @ObservedGovernorCount int,
    @MissingExpectedGovernorCount int,
    @InvalidMetricCount int,
    @ValidatedAtUtc datetime2(0) = NULL
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
       OR @MissingExpectedGovernorCount IS NULL OR @InvalidMetricCount IS NULL
        THROW 51107, 'Alliance Activity completion requires non-null evidence counts.', 1;
    IF @ExpectedGovernorCount < 0 OR @ObservedGovernorCount < 0
       OR @MissingExpectedGovernorCount < 0 OR @InvalidMetricCount < 0
        THROW 51103, 'Alliance Activity completion counts cannot be negative.', 1;

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
           AND (@MissingExpectedGovernorCount <> 0
                OR @InvalidMetricCount <> 0
                OR @ExpectedGovernorCount <> @ObservedGovernorCount)
            THROW 51105, 'A COMPLETE Alliance Activity snapshot requires full explicit-value coverage.', 1;

        UPDATE dbo.AllianceActivitySnapshotHeader
        SET CompletionState = @CompletionState,
            ExpectedGovernorCount = @ExpectedGovernorCount,
            ObservedGovernorCount = @ObservedGovernorCount,
            MissingExpectedGovernorCount = @MissingExpectedGovernorCount,
            InvalidMetricCount = @InvalidMetricCount,
            ValidatedAtUtc = COALESCE(@ValidatedAtUtc, SYSUTCDATETIME())
        WHERE SnapshotId = @SnapshotID;

        IF @OwnsTransaction = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @OwnsTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
