/*
MigrationId: 20260721_002_backfill_leadership_activity_completion
Purpose: Backfill Rally completion evidence, explicitly classify legacy Alliance Activity zeros, and support validated future snapshots
Author: cwatts
CreatedUtc: 2026-07-21
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: Existing eligible Rally dates and legacy Alliance Activity snapshot headers only
PreValidationQuery: SELECT COUNT(DISTINCT AsOfDate) AS RallyDates FROM dbo.cur_RallyDaily; SELECT CompletionState, COUNT(*) AS ActivitySnapshots FROM dbo.AllianceActivitySnapshotHeader GROUP BY CompletionState;
PostValidationQuery: SELECT CompletionBasis, COUNT(*) AS RallyDates FROM dbo.RallyDailySnapshotHeader GROUP BY CompletionBasis; SELECT CompletionState, CompletionBasis, COUNT(*) AS ActivitySnapshots FROM dbo.AllianceActivitySnapshotHeader GROUP BY CompletionState, CompletionBasis;
RelatedBotPR:
RelatedSQLPR:

Data safety:
- Rally dates use a matching successful dbo.IngestionLog record when available; otherwise the
  existing unique per-date rows and InsertedAt timestamp are explicitly labelled INFERRED_DATE.
- Rally dates with duplicate Governor IDs are not eligible for backfill.
- Legacy Alliance Activity snapshots are promoted only when Row_Count matches the stored unique
  GovernorID rows and a 20-byte source hash is present.
- Historical Building/Tech zero values are intentionally accepted as zero under the operator-
  approved LEGACY_ASSUMED_ZERO basis; future imports use SOURCE_VALIDATED evidence.
- No Rally or Alliance Activity measurement rows are modified.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF COL_LENGTH(N'dbo.AllianceActivitySnapshotHeader', N'MissingMetricCount') IS NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader ADD MissingMetricCount int NULL;
IF COL_LENGTH(N'dbo.AllianceActivitySnapshotHeader', N'CompletionBasis') IS NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader
        ADD CompletionBasis nvarchar(32) COLLATE Latin1_General_CI_AS NULL;
GO

UPDATE dbo.AllianceActivitySnapshotHeader
SET MissingMetricCount = COALESCE(MissingMetricCount, 0),
    CompletionBasis = COALESCE(CompletionBasis, N'SOURCE_VALIDATED')
WHERE CompletionState IN (N'COMPLETE', N'PARTIAL');
GO

IF OBJECT_ID(N'dbo.CK_AllianceActivityHeader_CompleteEvidence', N'C') IS NOT NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader
        DROP CONSTRAINT CK_AllianceActivityHeader_CompleteEvidence;
IF OBJECT_ID(N'dbo.CK_AllianceActivityHeader_EvidenceCounts', N'C') IS NOT NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader
        DROP CONSTRAINT CK_AllianceActivityHeader_EvidenceCounts;
IF OBJECT_ID(N'dbo.CK_AllianceActivityHeader_CompletionBasis', N'C') IS NOT NULL
    ALTER TABLE dbo.AllianceActivitySnapshotHeader
        DROP CONSTRAINT CK_AllianceActivityHeader_CompletionBasis;
GO

ALTER TABLE dbo.AllianceActivitySnapshotHeader WITH CHECK
    ADD CONSTRAINT CK_AllianceActivityHeader_EvidenceCounts
    CHECK
    (
        (ExpectedGovernorCount IS NULL OR ExpectedGovernorCount >= 0)
        AND (ObservedGovernorCount IS NULL OR ObservedGovernorCount >= 0)
        AND (MissingExpectedGovernorCount IS NULL OR MissingExpectedGovernorCount >= 0)
        AND (MissingMetricCount IS NULL OR MissingMetricCount >= 0)
        AND (InvalidMetricCount IS NULL OR InvalidMetricCount >= 0)
    );
GO

ALTER TABLE dbo.AllianceActivitySnapshotHeader WITH CHECK
    ADD CONSTRAINT CK_AllianceActivityHeader_CompletionBasis
    CHECK
    (
        (CompletionState = N'LEGACY_UNVERIFIED' AND CompletionBasis IS NULL)
        OR
        (CompletionState IN (N'COMPLETE', N'PARTIAL')
         AND CompletionBasis IN (N'SOURCE_VALIDATED', N'LEGACY_ASSUMED_ZERO'))
    );
GO

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
            AND MissingMetricCount IS NOT NULL
            AND InvalidMetricCount IS NOT NULL
            AND ValidatedAtUtc IS NOT NULL
            AND MissingExpectedGovernorCount = 0
            AND MissingMetricCount = 0
            AND InvalidMetricCount = 0
        )
    );
GO

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
END;
GO

DECLARE @RallyBackfill TABLE
(
    AsOfDate date NOT NULL PRIMARY KEY,
    ExpectedRowCount int NOT NULL,
    CompletionBasis nvarchar(24) NOT NULL,
    CompletedAtUtc datetime2(0) NOT NULL,
    ImportBatchID bigint NULL
);

;WITH RallyRows AS
(
    SELECT AsOfDate,
           COUNT(*) AS SourceRowCount,
           COUNT(DISTINCT GovernorID) AS DistinctGovernorCount,
           SUM(CASE WHEN TotalRallies < 0 OR RalliesLaunched < 0 OR RalliesJoined < 0
                         OR CONVERT(bigint, TotalRallies)
                            <> CONVERT(bigint, RalliesLaunched) + CONVERT(bigint, RalliesJoined)
                    THEN 1 ELSE 0 END) AS InvalidMetricRowCount,
           MAX(InsertedAt) AS LastInsertedAt
    FROM dbo.cur_RallyDaily
    GROUP BY AsOfDate
),
RankedAudit AS
(
    SELECT IngestionID, AsOfDate, RowsIn, EndedAt, Status, FileHash,
           ROW_NUMBER() OVER
           (PARTITION BY AsOfDate ORDER BY EndedAt DESC, IngestionID DESC) AS AuditRow
    FROM dbo.IngestionLog
    WHERE Source = N'rally_daily'
)
INSERT INTO @RallyBackfill
    (AsOfDate, ExpectedRowCount, CompletionBasis, CompletedAtUtc, ImportBatchID)
SELECT rows.AsOfDate,
       rows.SourceRowCount,
       CASE WHEN audit.IngestionID IS NOT NULL
                 AND audit.Status = N'success'
                 AND audit.RowsIn = rows.SourceRowCount
                 AND audit.EndedAt IS NOT NULL
                 AND audit.FileHash IS NOT NULL
            THEN N'AUDIT_BACKFILL' ELSE N'INFERRED_DATE' END,
       CASE WHEN audit.IngestionID IS NOT NULL
                 AND audit.Status = N'success'
                 AND audit.RowsIn = rows.SourceRowCount
                 AND audit.EndedAt IS NOT NULL
                 AND audit.FileHash IS NOT NULL
            THEN audit.EndedAt ELSE rows.LastInsertedAt END,
       CASE WHEN audit.IngestionID IS NOT NULL
                 AND audit.Status = N'success'
                 AND audit.RowsIn = rows.SourceRowCount
                 AND audit.EndedAt IS NOT NULL
                 AND audit.FileHash IS NOT NULL
            THEN audit.IngestionID END
FROM RallyRows AS rows
LEFT JOIN RankedAudit AS audit
  ON audit.AsOfDate = rows.AsOfDate
 AND audit.AuditRow = 1
LEFT JOIN dbo.RallyDailySnapshotHeader AS header
  ON header.AsOfDate = rows.AsOfDate
WHERE header.AsOfDate IS NULL
  AND rows.SourceRowCount > 0
  AND rows.SourceRowCount = rows.DistinctGovernorCount
  AND rows.InvalidMetricRowCount = 0
  AND rows.LastInsertedAt IS NOT NULL;

DECLARE @RallyDate date,
        @RallyExpectedRows int,
        @RallyBasis nvarchar(24),
        @RallyCompletedAt datetime2(0),
        @RallyImportBatchID bigint;

DECLARE RallyCompletionCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT AsOfDate, ExpectedRowCount, CompletionBasis, CompletedAtUtc, ImportBatchID
FROM @RallyBackfill
ORDER BY AsOfDate;

OPEN RallyCompletionCursor;
FETCH NEXT FROM RallyCompletionCursor
INTO @RallyDate, @RallyExpectedRows, @RallyBasis,
     @RallyCompletedAt, @RallyImportBatchID;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.usp_BackfillRallyDailySnapshotCompletion
        @AsOfDate = @RallyDate,
        @ExpectedRowCount = @RallyExpectedRows,
        @CompletionBasis = @RallyBasis,
        @CompletedAtUtc = @RallyCompletedAt,
        @ImportBatchID = @RallyImportBatchID;

    FETCH NEXT FROM RallyCompletionCursor
    INTO @RallyDate, @RallyExpectedRows, @RallyBasis,
         @RallyCompletedAt, @RallyImportBatchID;
END;

CLOSE RallyCompletionCursor;
DEALLOCATE RallyCompletionCursor;
GO

;WITH StoredActivity AS
(
    SELECT SnapshotId,
           COUNT(*) AS StoredRowCount,
           COUNT(DISTINCT GovernorID) AS DistinctGovernorCount,
           SUM(CASE WHEN BuildingTotal < 0 OR TechDonationTotal < 0
                    THEN 1 ELSE 0 END) AS InvalidStoredMetricCount
    FROM dbo.AllianceActivitySnapshotRow
    GROUP BY SnapshotId
)
UPDATE header
SET CompletionState = N'COMPLETE',
    ExpectedGovernorCount = stored.StoredRowCount,
    ObservedGovernorCount = stored.StoredRowCount,
    MissingExpectedGovernorCount = 0,
    MissingMetricCount = 0,
    InvalidMetricCount = 0,
    ValidatedAtUtc = SYSUTCDATETIME(),
    CompletionBasis = N'LEGACY_ASSUMED_ZERO'
FROM dbo.AllianceActivitySnapshotHeader AS header
JOIN StoredActivity AS stored
  ON stored.SnapshotId = header.SnapshotId
WHERE header.CompletionState = N'LEGACY_UNVERIFIED'
  AND stored.StoredRowCount > 0
  AND stored.StoredRowCount = stored.DistinctGovernorCount
  AND stored.InvalidStoredMetricCount = 0
  AND header.Row_Count = stored.StoredRowCount
  AND DATALENGTH(header.SourceFileSha1) = 20;
GO

SELECT CompletionBasis, COUNT(*) AS RallyDates
FROM dbo.RallyDailySnapshotHeader
GROUP BY CompletionBasis;

SELECT CompletionState, CompletionBasis, COUNT(*) AS ActivitySnapshots
FROM dbo.AllianceActivitySnapshotHeader
GROUP BY CompletionState, CompletionBasis;
GO
