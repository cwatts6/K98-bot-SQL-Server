-- Operator-run metadata reconciliation. Preview is the default.
-- Select the intended K98 database in SSMS; save BOTH result sets with the change record.
-- Apply only after reviewing the preview and deploying the corrected bot importer.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 5000;
DECLARE @Apply bit = 0;
DECLARE @ThroughSnapshotId bigint = 574;
IF @@TRANCOUNT <> 0 THROW 51110, 'Run in a new session without an existing transaction.', 1;
DECLARE @Candidates TABLE (
    SnapshotId bigint PRIMARY KEY, SourceRows int, StoredRows bigint,
    OldExpected int, OldMissing int, OldValidated datetime2(0)
);
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT @Candidates
    SELECT h.SnapshotId,h.Row_Count,r.StoredRows,h.ExpectedGovernorCount,
           h.MissingExpectedGovernorCount,h.ValidatedAtUtc
    FROM dbo.AllianceActivitySnapshotHeader h WITH (UPDLOCK,HOLDLOCK)
    CROSS APPLY (
        SELECT COUNT_BIG(*) AS StoredRows,
               SUM(CASE WHEN GovernorID<=0 OR BuildingTotal<0 OR TechDonationTotal<0
                             OR BuildingTotal IS NULL OR TechDonationTotal IS NULL
                        THEN 1 ELSE 0 END) AS InvalidRows
        FROM dbo.AllianceActivitySnapshotRow WITH (UPDLOCK,HOLDLOCK)
        WHERE SnapshotId=h.SnapshotId
    ) r
    WHERE h.SnapshotId<=@ThroughSnapshotId AND h.CompletionState=N'PARTIAL'
      AND h.CompletionBasis=N'SOURCE_VALIDATED'
      AND h.Row_Count>0 AND h.ObservedGovernorCount=h.Row_Count
      AND r.StoredRows=h.Row_Count AND r.InvalidRows=0
      AND h.MissingMetricCount=0 AND h.InvalidMetricCount=0
      AND h.MissingExpectedGovernorCount>0 AND h.ValidatedAtUtc IS NOT NULL
      AND DATALENGTH(h.SourceFileSha1)=20;

    -- Original roster evidence is returned even when applying. Preserve this result.
    SELECT @Apply AS ApplyRequested, DB_NAME() AS DatabaseName, *
    FROM @Candidates ORDER BY SnapshotId;
    IF @Apply=1
    BEGIN
        DECLARE @SnapshotId bigint, @Rows int;
        DECLARE candidates CURSOR LOCAL FAST_FORWARD FOR
            SELECT SnapshotId,SourceRows FROM @Candidates ORDER BY SnapshotId;
        OPEN candidates;
        FETCH NEXT FROM candidates INTO @SnapshotId,@Rows;
        WHILE @@FETCH_STATUS=0
        BEGIN
            -- Existing procedure independently checks the stored count and constraints.
            EXEC dbo.usp_SetAllianceActivitySnapshotCompletion
                @SnapshotID=@SnapshotId,@CompletionState=N'COMPLETE',
                @ExpectedGovernorCount=@Rows,@ObservedGovernorCount=@Rows,
                @MissingExpectedGovernorCount=0,@MissingMetricCount=0,@InvalidMetricCount=0,
                @CompletionBasis=N'SOURCE_VALIDATED';
            FETCH NEXT FROM candidates INTO @SnapshotId,@Rows;
        END;
        CLOSE candidates;
        DEALLOCATE candidates;
        IF EXISTS (
            SELECT 1 FROM @Candidates c JOIN dbo.AllianceActivitySnapshotHeader h
                ON h.SnapshotId=c.SnapshotId
            WHERE h.CompletionState<>N'COMPLETE' OR h.ExpectedGovernorCount<>c.SourceRows
                OR h.ObservedGovernorCount<>c.SourceRows OR h.MissingExpectedGovernorCount<>0
        ) THROW 51111, 'Reconciliation verification failed; transaction rolled back.', 1;
        COMMIT TRANSACTION;
    END
    ELSE ROLLBACK TRANSACTION;
    SELECT @Apply AS Applied, h.SnapshotId,h.Row_Count,h.CompletionState,
           h.ExpectedGovernorCount,h.ObservedGovernorCount,h.MissingExpectedGovernorCount,
           h.MissingMetricCount,h.InvalidMetricCount,h.ValidatedAtUtc,h.CompletionBasis
    FROM dbo.AllianceActivitySnapshotHeader h JOIN @Candidates c ON c.SnapshotId=h.SnapshotId
    ORDER BY h.SnapshotId;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
