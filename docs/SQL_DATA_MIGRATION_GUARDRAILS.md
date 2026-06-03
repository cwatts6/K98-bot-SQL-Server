# SQL Data Migration Guardrails

Use these guardrails for migrations or emergency hotfixes that change existing data or introduce
schema changes with material data risk.

## Required Safety Plan

High-risk data changes must document:

1. Purpose statement.
2. Row-count preview query.
3. Expected row-count range.
4. Transaction plan.
5. Locking/runtime risk note.
6. Backup confirmation.
7. Rollback or forward-fix plan.
8. Pre-validation query.
9. Post-validation query.
10. Bot impact assessment where relevant.

Use migration header fields:

```sql
DataChange: Yes
DataSafetyPlan: Required | Included
EstimatedRowsAffected: expected range or N/A
PreValidationQuery: summary or N/A
PostValidationQuery: summary or N/A
```

## UPDATE

- Preview affected rows with `SELECT COUNT(*)` using the exact predicate.
- Use a narrow `WHERE` clause.
- Capture `@@ROWCOUNT`.
- Use a transaction where practical.
- Avoid broad updates during bot peak usage unless runtime impact is understood.

## DELETE

- Preview rows and keep evidence.
- Prefer soft delete or archival when the data may be needed for recovery.
- Treat deletes without a narrow predicate as high risk.
- Confirm restore or forward-fix expectations before execution.

## TRUNCATE

- Treat as destructive and high risk.
- Do not use for business data unless the table is confirmed disposable or reloadable.
- Require owner approval and restore/forward-fix notes.

## DROP

- Dropping tables, columns, procedures, views, functions, types, constraints, or indexes requires
  dependency review.
- Use staged compatibility where bot code depends on the object.
- Column and table drops require a clear restore or forward-fix decision.

## Large Backfills

- Batch when practical.
- Estimate runtime and locking.
- Prefer off-peak execution.
- Include pre/post validation and a stop condition.

## Column Type Changes

- Confirm existing data fits the target type.
- Check nullability, defaults, constraints, indexes, and dependent views/procedures.
- Prefer additive replacement columns when direct conversion is risky.

## Table Renames

- Treat as breaking unless all callers and dependent objects are updated in a coordinated rollout.
- Prefer creating a compatible view or staged migration when bot deployment order could overlap.

## Index Changes On Large Tables

- Document expected benefit and operational risk.
- Consider online options only when supported by the edition and object shape.
- Validate that dropping an index will not remove an important lookup path for bot operations.

## Config Data Changes

Config rows that affect bot behavior, such as procedure config, event config, import settings, or
feature flags, require:

- before/after values
- affected bot behavior
- rollback or forward-fix plan
- smoke test after deployment

