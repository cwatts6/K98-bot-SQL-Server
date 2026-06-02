# Migration Rollbacks

Place optional rollback scripts here.

Use the same migration ID with `.rollback.sql` appended:

```text
20260602_001_add_schema_migration_history.rollback.sql
```

Rollback scripts must be reviewed with the forward migration. Not every SQL migration can be
safely reversed; use manual recovery notes when rollback would risk data loss or false safety.
