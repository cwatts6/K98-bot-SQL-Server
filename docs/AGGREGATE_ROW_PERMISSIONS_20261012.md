# Aggregate row permission amendment

The bot's reviewed application grant plan omitted INSERT and SELECT on
`KVK.SourceKingdomReportRow` and `KVK.SourceCampReportRow`. Both tables already
exist. This amendment adds those four direct object rights to the existing
application user. It changes no schema, data, role, ownership, procedure,
ProcConfig or migration-history record.

The entry point is `deploy/amendments/20261012_aggregate_row_permissions.sql`.
It is deliberately outside automatic schema migration selection: this is an
existing-account grant amendment, coordinated with a protected startup contract.
Do not run the fresh-account provisioner against the existing user.

## Review bindings and preconditions

Retain the reviewed bot and SQL commit IDs, SQL file SHA256, exact server/database,
database user and login SID in the private release packet. Read these values from
the approved installation and independently confirm them; do not take defaults
from the current connection. Production is restricted to `ROK_TRACKER` and
`S11_ExportApplication`; local rehearsal permits an explicitly named
`K98_Aggregate_Disposable_*` database and an existing no-login fixture user.

The caller must create and populate this session-local table with approved
values before submitting the amendment batch on the same connection:

```sql
CREATE TABLE #AggregatePermissionAmendment (
    ExpectedServer nvarchar(128) NOT NULL,
    ExpectedDatabase nvarchar(128) NOT NULL,
    PrincipalName nvarchar(128) NOT NULL,
    LoginSid varbinary(85) NOT NULL,
    Action varchar(8) NOT NULL
);
-- INSERT exactly one independently approved identity; Action='Apply'.
-- Deliberately no executable production values in source control.
```

Before changing rights, drain the application and confirm both retained legacy
and whole-application permission observations match their existing protected
contracts. Verify the source schema against the two SQL table definitions and
the bot grant plan's file hashes. Any unexpected role, inherited permission,
ownership, schema change or permission delta blocks this release. The amendment's
narrow catalog checks do not substitute for those full contract checks.

## Coordinated release and verification

Use a reviewed generic configuration/SQL release packet. The routine source-only
updater intentionally preserves installed contracts and cannot deliver this
change alone. Ordering is drain, grant amendment, promoted bot source from private
main, reviewed startup-contract amendment, start once, readiness verification.
Keep the application stopped if any step fails; do not start with mixed contracts.

The companion bot document `aggregate_permission_contract_amendment_20261012.md`
in [bot PR 328](https://github.com/cwatts6/K98-bot-mirror/pull/328)
defines the exact allowed permission-observation changes and contract fields.
Capture observations as the real application login, not a sysadmin session, and
compare them to the independently derived expected postimage before installation.

The SQL batch checks the exact identity, takes the existing S11 transaction-owned
deployment lock, and accepts only zero or all four direct row grants. Partial
states, DENY, grant option, column grants and extra direct row rights fail closed.
Applying the completed amendment again is a no-op. Retain its identity/result and
the release packet's hashes as evidence; no schema migration receipt is fabricated.

After readiness, inspect the retained receipt and prepare a fresh operator-reviewed
confirmation. Do not replay an expired proposal or manually alter acceptance data.

## Recovery

While the application is drained, bind the same reviewed identity with
`Action='Rollback'` only if release evidence proves these four rights were absent
before this amendment. Restore the corresponding previous bot source and both
previous protected contracts as one coordinated rollback. The batch revokes only
the four direct grants, without CASCADE, and accepts an already absent state.
Retain all accepted data, artifacts and receipt history. If any identity, rights
or source differs from the captured baseline, stop for a new reviewed amendment.

Production execution, restart and merge require subsequent operator approval.
