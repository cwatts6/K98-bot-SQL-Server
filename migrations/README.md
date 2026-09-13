# SQL Migrations

This folder is the deployable source for intentional SQL changes.

Schema snapshots in `sql_schema/` are generated reference material. Do not deploy from
snapshots directly unless an approved emergency recovery plan requires it.

Notable deployed SQL milestones that need cross-repo closeout context may also be recorded in
`docs/SQL_DELIVERY_LOG.md`. That log is informational; migration files and
`dbo.SchemaMigrationHistory` remain the deployment source of truth.

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


## S8B no-fight update amendment — 2026-09-13 (authored, not executed)

The operator approved closing the recorded S8B gaps. Migration
`20260913_001_kvk_source_update_no_fight_context.sql` adds required `SourceUpdate.PeriodKind`
copied from the immutable period and rebinds the scoped kind FK to that classification.
`UpdateKind=no_fight` may then apply to an existing fight period without changing its identity.
The new mode check rejects all other cross-kind combinations; existing equal-player-input,
no-aggregate, readiness and scoped revision/configuration constraints remain intact. The Bot
additionally requires explicitly confirmed equal configured endpoints and exact revisions.
No historical ID, hash, confirmation, state, selection, intent or publication is rewritten.

Execution remains separately gated: provide exact target, backup/restore and metadata preview
receipts plus expected update count in `#S8BNoFightApproval`. Review `preview`, then separately
approve `apply` with all source writers idle. This batch owns its transaction and is intended
for a reviewed same-session invocation, not the generic pending deploy runner (which does not
supply this input table). Do not alter runner/history behavior or rerun predecessors implicitly.
Deploy the amendment before the revised S8B writer; older inserts omit the required column
and fail closed. Retained no-fight fight-period updates require forward fixes, not a downgrade.
Disposable validation must prove preview/apply/rerun, rollback, FK/check rejection and retained
history identity before deployment. No SQL connection or execution is claimed by this entry.
