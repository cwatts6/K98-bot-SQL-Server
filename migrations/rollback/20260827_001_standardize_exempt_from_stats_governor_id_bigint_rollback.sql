/*
RollbackForMigrationId: 20260827_001_standardize_exempt_from_stats_governor_id_bigint
Purpose: Restore dbo.EXEMPT_FROM_STATS.GovernorID to its pre-migration float NOT NULL contract
Author: cwatts
CreatedUtc: 2026-08-27
RiskLevel: Low
DataLossRisk: Low; refused when any bigint value is outside the exact float integer range
RollbackType: Full
RequiresBackup: Yes
PreRollbackValidation: Confirm every GovernorID remains within plus or minus 9007199254740991
PostRollbackValidation: Confirm GovernorID is float NOT NULL and the table row count is unchanged
RelatedSQLPR:
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 60000;

IF OBJECT_ID(N'dbo.EXEMPT_FROM_STATS', N'U') IS NULL
    THROW 52750, 'dbo.EXEMPT_FROM_STATS does not exist.', 1;

DECLARE @CurrentType sysname;
DECLARE @IsNullable bit;

SELECT
    @CurrentType = TYPE_NAME(system_type_id),
    @IsNullable = is_nullable
FROM sys.columns
WHERE object_id = OBJECT_ID(N'dbo.EXEMPT_FROM_STATS', N'U')
  AND name = N'GovernorID';

IF @CurrentType IS NULL
    THROW 52751, 'dbo.EXEMPT_FROM_STATS.GovernorID does not exist.', 1;

IF @CurrentType NOT IN (N'bigint', N'float')
    THROW 52752, 'dbo.EXEMPT_FROM_STATS.GovernorID has an unexpected datatype.', 1;

IF @IsNullable <> 0
    THROW 52753, 'dbo.EXEMPT_FROM_STATS.GovernorID must remain NOT NULL.', 1;

IF @CurrentType = N'bigint'
   AND EXISTS
   (
       SELECT 1
       FROM dbo.EXEMPT_FROM_STATS
       WHERE GovernorID < -9007199254740991
          OR GovernorID > 9007199254740991
   )
    THROW 52754, 'Rollback refused because a GovernorID cannot be represented exactly as float.', 1;

DECLARE @RowsBefore bigint = (SELECT COUNT_BIG(*) FROM dbo.EXEMPT_FROM_STATS);

BEGIN TRY
    BEGIN TRANSACTION;

    IF @CurrentType = N'bigint'
        ALTER TABLE dbo.EXEMPT_FROM_STATS
            ALTER COLUMN GovernorID float NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.EXEMPT_FROM_STATS', N'U')
          AND name = N'GovernorID'
          AND system_type_id = TYPE_ID(N'float')
          AND user_type_id = TYPE_ID(N'float')
          AND is_nullable = 0
    )
        THROW 52755, 'dbo.EXEMPT_FROM_STATS.GovernorID did not return to the float NOT NULL contract.', 1;

    IF (SELECT COUNT_BIG(*) FROM dbo.EXEMPT_FROM_STATS) <> @RowsBefore
        THROW 52756, 'dbo.EXEMPT_FROM_STATS row count changed during rollback.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
