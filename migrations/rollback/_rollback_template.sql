/*
RollbackForMigrationId: YYYYMMDD_NNN_short_description
Purpose: Describe what this rollback reverses
Author: cwatts
CreatedUtc: YYYY-MM-DD
RiskLevel: Low | Medium | High
DataLossRisk: None | Low | Medium | High
RollbackType: Full | Partial | Manual Assist
RequiresBackup: Yes
PreRollbackValidation: Describe query/check
PostRollbackValidation: Describe query/check
RelatedSQLPR:
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Review before use:
- Confirm this rollback matches the deployed migration and current Production state.
- Confirm backup readiness immediately before execution.
- Confirm whether data loss or bot behavior impact is possible.
- Do not run this script automatically from deployment tooling.
*/

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Add rollback SQL here.
    -- Prefer precise, idempotent operations with pre/post validation.

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

