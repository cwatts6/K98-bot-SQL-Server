/*
MigrationId: 20260727_000_retire_vAllianceActivity_WeeklyCumulative
Purpose: Retire the invalid and unused dbo.vAllianceActivity_WeeklyCumulative view before Phase 4 consumer refresh
Author: cwatts
CreatedUtc: 2026-07-27
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Forward Fix Only
RollbackScript:
TransactionMode: Required
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0
PreValidationQuery: Run performance_remediation/kingdomscandata4/phase4/01_preflight.sql
PostValidationQuery: Run performance_remediation/kingdomscandata4/phase4/02_verify.sql after the Phase 4 alignment migration
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety and forward-fix plan:
    - The view is already unmaterializable because its stored definition expects
      columns no longer exposed by dbo.vAllianceActivity_WeeklyDelta.
    - Repository and bot searches found no executable consumer. The migration
      independently refuses any schema-bound or non-schema-bound SQL module
      dependency recorded by SQL Server.
    - The migration refuses definition drift, explicit permissions, signatures,
      and extended properties so DROP VIEW cannot silently discard an
      unreviewed contract.
    - The retirement is intentionally forward-fix-only. Recreating the known
      invalid definition would provide false rollback safety. If a future
      consumer is approved, introduce a new valid view contract through a new
      reviewed migration rather than resurrecting this object.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 60000;

BEGIN TRANSACTION;

DECLARE @MigrationLockResult int;
EXEC @MigrationLockResult = sys.sp_getapplock
    @Resource = N'K98:KingdomScanData4:Migration',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 60000,
    @DbPrincipal = N'public';

IF @MigrationLockResult < 0
    THROW 51990, 'Phase 4 retirement could not acquire the KingdomScanData4 migration mutex within 60000 ms.', 1;

DECLARE @ImportLockResult int;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
    @LockTimeout = 60000,
    @LockResult = @ImportLockResult OUTPUT;

IF @ImportLockResult < 0
    THROW 51991, 'Phase 4 retirement could not acquire the Phase 3 import-pipeline mutex within 60000 ms.', 1;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK', N'P') IS NULL
    THROW 51992, 'Phase 4 retirement requires the verified Phase 3 import and rollback contracts.', 1;

DECLARE @RetiredViewId int =
    OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative', N'V');

IF @RetiredViewId IS NULL
    THROW 51993, 'Phase 4 retirement found the target view already absent; reconcile migration history before continuing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.sql_modules AS module_info
    WHERE module_info.object_id = @RetiredViewId
      AND CONVERT(
              char(64),
              HASHBYTES(
                  'SHA2_256',
                  CONVERT(varbinary(max), module_info.definition)
              ),
              2
          ) = N'DD5C6AC7E3D179463AB22C2618026A0479BC8A0C0D9564D766F1553237465CF4'
)
    THROW 51994, 'Phase 4 retirement refused unexpected target view-definition drift.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.sql_expression_dependencies AS dependency
    WHERE dependency.referenced_id = @RetiredViewId
      AND dependency.referencing_id <> @RetiredViewId
)
    THROW 51995, 'Phase 4 retirement found a SQL module that still depends on the target view.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.database_permissions AS permission_info
    WHERE permission_info.class = 1
      AND permission_info.major_id = @RetiredViewId
)
    THROW 51996, 'Phase 4 retirement found explicit permissions on the target view.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.crypt_properties AS signature_info
    WHERE signature_info.class_desc = N'OBJECT_OR_COLUMN'
      AND signature_info.major_id = @RetiredViewId
)
    THROW 51997, 'Phase 4 retirement found a signature on the target view.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.extended_properties AS property_info
    WHERE property_info.class = 1
      AND property_info.major_id = @RetiredViewId
)
    THROW 51998, 'Phase 4 retirement found extended properties on the target view.', 1;

DROP VIEW dbo.vAllianceActivity_WeeklyCumulative;

IF OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative') IS NOT NULL
    THROW 51999, 'Phase 4 retirement did not remove the target view.', 1;

COMMIT TRANSACTION;
GO

SELECT
    N'phase4_retire_vAllianceActivity_WeeklyCumulative' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    CAST(
        CASE
            WHEN OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative') IS NULL
            THEN 1
            ELSE 0
        END
        AS bit
    ) AS ViewRemoved,
    N'PASS' AS RetirementStatus;
GO
