# SQL Migrations

This folder is the deployable source for intentional SQL changes.

Schema snapshots in `sql_schema/` are generated reference material. Do not deploy from
snapshots directly unless an approved emergency recovery plan requires it.

## Naming

Use sortable migration names:

```text
YYYYMMDD_NNN_short_description.sql
```

Example:

```text
20260602_001_add_schema_migration_history.sql
```

Rules:

- Date is the migration creation date.
- `NNN` increments per day.
- Description uses lowercase snake case.
- The migration ID is the filename without `.sql`.
- Never rename a migration after it has been merged.

## Header

Every migration must start with this metadata block:

```sql
/*
MigrationId: 20260602_001_add_schema_migration_history
Purpose: Add SQL migration tracking table
Author: cwatts
CreatedUtc: 2026-06-02
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: N/A
PostValidationQuery: N/A
RelatedBotPR:
RelatedSQLPR:
*/
```

## Rollback

Rollback is explicit, not assumed.

- `Included`: a matching script exists in `migrations/rollback/`.
- `Manual`: rollback notes are in the migration or release notes.
- `Forward Fix Only`: do not roll back; correct the issue with a new migration.
- `Not Possible`: recovery requires restore from backup or bespoke manual recovery.

When `Rollback: Included`, set `RollbackScript:` to:

```text
migrations/rollback/YYYYMMDD_NNN_short_description_rollback.sql
```

The rollback file must include a `RollbackForMigrationId:` header and be reviewed with the forward
migration. Do not create a rollback file when it would imply safety that does not exist.

## Data Safety

Use `DataChange: Yes` when a migration updates, deletes, truncates, backfills, transforms, or
otherwise changes existing data. Schema-only changes can normally use `DataChange: No`, but schema
changes with material data risk should still include a safety plan.

`DataSafetyPlan:` values:

- `Not Required`: no existing data is changed and no material data risk is expected.
- `Required`: the PR or migration notes must include the data safety plan before deployment.
- `Included`: the migration header/comments include the preview, transaction, validation, and
  rollback or forward-fix notes.

For high-risk data changes, include:

- expected row-count range
- pre-validation query
- post-validation query
- backup confirmation
- transaction and locking notes
- rollback or forward-fix plan

See `docs/SQL_DATA_MIGRATION_GUARDRAILS.md`.

The deploy runner prevents repeat execution through `dbo.SchemaMigrationHistory`; individual
migrations should still be idempotent where that is genuinely safe.
