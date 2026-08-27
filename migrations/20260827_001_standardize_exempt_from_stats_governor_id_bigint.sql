/*
MigrationId: 20260827_001_standardize_exempt_from_stats_governor_id_bigint
Purpose: Standardize dbo.EXEMPT_FROM_STATS.GovernorID from float to bigint
Author: cwatts
CreatedUtc: 2026-08-27
RequiresBackup: Yes
RiskLevel: Low
Rollback: Included
RollbackScript: migrations/rollback/20260827_001_standardize_exempt_from_stats_governor_id_bigint_rollback.sql
TransactionMode: Required
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: 55 rows observed in Production on 2026-08-27
PreValidationQuery: Confirm every GovernorID is integral, within the exact float integer range, bigint-convertible, and bigint round-trip safe
PostValidationQuery: Confirm GovernorID is bigint NOT NULL and the table row count is unchanged
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety plan:
    - Deploy outside the ProcConfig exemption-import window because ALTER COLUMN takes
      a schema-modification lock, although the table currently contains only 55 rows.
    - Production evidence captured on 2026-08-27 found zero conversion failures,
      fractional values, non-positive values, values beyond the exact float integer
      range, or bigint round-trip mismatches.
    - Preserve every row and every other column; do not add a key, unique constraint,
      index, or exemption-rule change. One existing non-conflicting duplicate
      GovernorID/KVK group is deliberately retained.
    - Acquire and retain an exclusive table lock before value validation, then run the
      conversion and post-validation in one transaction with XACT_ABORT enabled.
    - The included rollback refuses to restore float if new bigint values cannot be
      represented exactly as float.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 60000;

DECLARE @CurrentType sysname;
DECLARE @IsNullable bit;
DECLARE @RowsBefore bigint;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.EXEMPT_FROM_STATS', N'U') IS NULL
        THROW 52700, 'dbo.EXEMPT_FROM_STATS does not exist.', 1;

    SELECT @RowsBefore = COUNT_BIG(*)
    FROM dbo.EXEMPT_FROM_STATS WITH (TABLOCKX, HOLDLOCK);

    SELECT
        @CurrentType = TYPE_NAME(system_type_id),
        @IsNullable = is_nullable
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.EXEMPT_FROM_STATS', N'U')
      AND name = N'GovernorID';

    IF @CurrentType IS NULL
        THROW 52701, 'dbo.EXEMPT_FROM_STATS.GovernorID does not exist.', 1;

    IF @CurrentType NOT IN (N'float', N'bigint')
        THROW 52702, 'dbo.EXEMPT_FROM_STATS.GovernorID has an unexpected datatype.', 1;

    IF @IsNullable <> 0
        THROW 52703, 'dbo.EXEMPT_FROM_STATS.GovernorID must remain NOT NULL.', 1;

    IF @CurrentType = N'float'
       AND EXISTS
       (
           SELECT 1
           FROM dbo.EXEMPT_FROM_STATS
           WHERE TRY_CONVERT(bigint, GovernorID) IS NULL
              OR GovernorID <> FLOOR(GovernorID)
              OR ABS(GovernorID) > 9007199254740991.0
              OR GovernorID <> CONVERT(float, TRY_CONVERT(bigint, GovernorID))
       )
        THROW 52704, 'dbo.EXEMPT_FROM_STATS contains GovernorID values that cannot be converted exactly to bigint.', 1;

    IF @CurrentType = N'float'
        ALTER TABLE dbo.EXEMPT_FROM_STATS
            ALTER COLUMN GovernorID bigint NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.EXEMPT_FROM_STATS', N'U')
          AND name = N'GovernorID'
          AND system_type_id = TYPE_ID(N'bigint')
          AND user_type_id = TYPE_ID(N'bigint')
          AND is_nullable = 0
    )
        THROW 52705, 'dbo.EXEMPT_FROM_STATS.GovernorID did not reach the bigint NOT NULL contract.', 1;

    IF (SELECT COUNT_BIG(*) FROM dbo.EXEMPT_FROM_STATS) <> @RowsBefore
        THROW 52706, 'dbo.EXEMPT_FROM_STATS row count changed during GovernorID conversion.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
