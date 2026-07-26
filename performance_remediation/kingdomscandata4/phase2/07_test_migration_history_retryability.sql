/*
Purpose:
    Prove that the Phase 2 early-rollback migration-history transition is
    accepted by the live repository schema and remains retryable.

Safety:
    - Representative KS4 databases only; production is forbidden.
    - Confirmation defaults to refusal.
    - All test mutations are rolled back.
    - The exact pre-test history row is compared after rollback.

Operator:
    Set @ConfirmTargetDatabase to DB_NAME() on an approved representative copy.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ConfirmTargetDatabase sysname = N'';
DECLARE @MigrationId nvarchar(255) =
    N'20260725_001_kingdomscandata4_shadow_type_remediation';
DECLARE @ResetRows int;

IF DB_NAME() <> @ConfirmTargetDatabase
    THROW 51680, 'Safety stop: confirm the connected representative database.', 1;

IF DB_NAME() = N'ROK_TRACKER'
   OR DB_NAME() NOT LIKE N'ROK[_]TRACKER[_]BACKUP[_]TEST[_]KS4%'
    THROW 51681, 'This retryability rehearsal is forbidden outside a KS4 representative database.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE database_id = DB_ID()
      AND source_database_id IS NOT NULL
)
    THROW 51682, 'Do not run the retryability rehearsal against a database snapshot.', 1;

IF OBJECT_ID(N'dbo.SchemaMigrationHistory', N'U') IS NULL
    THROW 51683, 'SchemaMigrationHistory is absent from the representative database.', 1;

SELECT *
INTO #BeforeHistory
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = @MigrationId;

BEGIN TRY
    BEGIN TRANSACTION;

    MERGE dbo.SchemaMigrationHistory AS target
    USING (SELECT @MigrationId AS MigrationId) AS source
    ON target.MigrationId = source.MigrationId
    WHEN MATCHED THEN
        UPDATE SET Status = N'Applied'
    WHEN NOT MATCHED THEN
        INSERT
        (
            MigrationId,
            MigrationFile,
            ChecksumSha256,
            AppliedAtUtc,
            Status
        )
        VALUES
        (
            @MigrationId,
            N'20260725_001_kingdomscandata4_shadow_type_remediation.sql',
            REPLICATE(N'0', 64),
            SYSUTCDATETIME(),
            N'Applied'
        );

    UPDATE dbo.SchemaMigrationHistory WITH (UPDLOCK, HOLDLOCK)
    SET Status = N'Pending',
        ErrorMessage = N'Phase 2 runtime migration-history retryability rehearsal'
    WHERE MigrationId = @MigrationId
      AND Status = N'Applied';

    SET @ResetRows = @@ROWCOUNT;

    IF @ResetRows <> 1
        THROW 51684, 'The exact Applied migration row was not reset once.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.SchemaMigrationHistory
        WHERE MigrationId = @MigrationId
          AND Status = N'Applied'
    )
        THROW 51685, 'The deployment runner would still treat the migration as applied.', 1;

    SELECT
        N'phase2_migration_history_retryability' AS EvidenceSection,
        DB_NAME() AS DatabaseName,
        @MigrationId AS MigrationId,
        @ResetRows AS ResetRows,
        Status,
        CAST(0 AS int) AS AppliedCount,
        @@TRANCOUNT AS TransactionCount,
        N'PASS_BEFORE_ROLLBACK' AS Result
    FROM dbo.SchemaMigrationHistory
    WHERE MigrationId = @MigrationId;

    ROLLBACK TRANSACTION;

    IF EXISTS
    (
        SELECT *
        FROM dbo.SchemaMigrationHistory
        WHERE MigrationId = @MigrationId
        EXCEPT
        SELECT *
        FROM #BeforeHistory
    )
    OR EXISTS
    (
        SELECT *
        FROM #BeforeHistory
        EXCEPT
        SELECT *
        FROM dbo.SchemaMigrationHistory
        WHERE MigrationId = @MigrationId
    )
        THROW 51686, 'The rehearsal did not restore the exact pre-test history state.', 1;

    SELECT
        N'phase2_migration_history_retryability_cleanup' AS EvidenceSection,
        (SELECT COUNT(*) FROM #BeforeHistory) AS BeforeCount,
        (
            SELECT COUNT(*)
            FROM dbo.SchemaMigrationHistory
            WHERE MigrationId = @MigrationId
        ) AS AfterRollbackCount,
        N'PASS' AS Result;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
