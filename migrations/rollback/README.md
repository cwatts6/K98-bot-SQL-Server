# Migration Rollbacks

Place reviewed rollback scripts here for migrations that can be safely reversed.

Rollback scripts are manual recovery tools. They are not run automatically by deployment tooling.

## When A Rollback Script Is Required

Create a rollback script when all of these are true:

- the migration declares `Rollback: Included`
- the reverse operation is understood
- the reverse operation is safer than a forward fix or restore
- data-loss risk is documented
- pre/post validation can prove the outcome

## When Not To Create One

Do not create a rollback script when it would give false confidence, such as:

- destructive data changes where lost data cannot be reconstructed
- broad data migrations that need case-by-case judgement
- table or column drops without a restore-based recovery path
- changes where a forward fix is safer than reversing under pressure

Use `Rollback: Manual`, `Rollback: Forward Fix Only`, or `Rollback: Not Possible` instead.

## Naming

Use the migration ID with `_rollback.sql` appended:

```text
migrations/rollback/20260602_001_add_schema_migration_history_rollback.sql
```

## Header

Each rollback script must include:

```sql
/*
RollbackForMigrationId: YYYYMMDD_NNN_short_description
Purpose:
Author:
CreatedUtc:
RiskLevel: Low | Medium | High
DataLossRisk: None | Low | Medium | High
RollbackType: Full | Partial | Manual Assist
RequiresBackup: Yes
PreRollbackValidation:
PostRollbackValidation:
RelatedSQLPR:
*/
```

## Transaction Handling

Prefer explicit transactions with `SET XACT_ABORT ON`, `TRY...CATCH`, and `XACT_STATE()` handling.
If a rollback cannot safely run in one transaction, document why and include stop points.

## Review Requirements

Rollback scripts must be reviewed in the same PR as the forward migration when possible. Before a
rollback is executed, the operator must:

- confirm backup readiness
- review current Production state
- confirm the rollback still matches the deployed migration
- run pre-validation
- execute the rollback deliberately
- run post-validation
- document the result in deployment or hotfix notes

Rollback is not a substitute for restore-from-backup. Use restore escalation when data corruption,
unknown row impact, or destructive changes make manual rollback unsafe.
