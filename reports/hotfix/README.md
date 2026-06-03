# SQL Hotfix Reports

This folder stores evidence for emergency SQL hotfixes and controlled hotfix rehearsals.

Use this folder only for operational records, not general design notes. Reports should be detailed
enough for another operator to understand what happened, what was changed, how Git was reconciled,
and whether final drift was clean.

## Naming

Use UTC timestamps.

```text
hotfix_YYYYMMDD_HHMM_short_description.md
rehearsal_YYYYMMDD_HHMM_short_description.md
```

Examples:

```text
hotfix_20260602_2130_restore_missing_proc.md
rehearsal_20260602_2130_sql_hotfix_rehearsal_table.md
```

## Required Evidence

Each report should include:

- incident reason or rehearsal purpose
- operator and approval source
- production server and database
- backup readiness result or documented override
- exact SQL applied, or a path to the reviewed script
- execution timestamp, rows affected, and objects affected
- SQL validation and bot smoke checks when relevant
- export branch and drift report path
- reconciliation migration path
- rollback classification and rollback or forward-fix notes
- final drift status
- related SQL PR and bot PR links when applicable

## Sensitive Information

Do not paste passwords, tokens, connection strings with credentials, private keys, or Discord
webhooks into reports. Use Windows Auth context, script paths, command output summaries, and PR
links instead of secrets.

If a report needs to reference a sensitive operational detail, describe the location or owner of
the evidence without copying the secret value.

## Final Status

Every report must end with one of:

- resolved and reconciled
- resolved with accepted documented drift
- reverted
- monitoring
- incomplete, with owner-run steps listed
