# Exact S11 stats import outcomes

Migration `migrations/20261009_001_stats_import_outcomes.sql` adds one execution
receipt table and a single-use wrapper. The optional UPDATE_ALL2 preparation
parameter preserves legacy caller syntax; coordinated callers use the wrapper.
New receipt markers are inside the import and final report transactions. A final
commit remains complete even if a later audit/result acknowledgment fails.

The wrapper holds an exclusive session application lock for the exact preparation.
It will not repeat a prepared execution once entered. A caught failure records
`rolled_back` only before Phase A commitment, or `partial` afterward. SQL attention
or disconnection can bypass CATCH; nonterminal rows remain unproven, never inferred
failed merely because the process or session disappeared.

Bot reconciliation requires exact preparation/resource owner, fence and versions,
same runtime account/storage scope, no captured/provider work, and exclusive SQL
execution/producer locks. Partial commitment requires an explicit reviewed admin
supersession decision. The migration itself classifies or settles no historical
work and changes no activation flag or provider output.

## Installation order

1. Review the Bot and SQL diffs separately and finish the disposable rehearsal.
2. Drain the protected process pair and close execution sessions.
3. Apply the migration through the normal runner so its exact checksum is recorded.
4. Apply the three Bot-reviewed application grants (SELECT/INSERT/UPDATE on the
   new receipt table) to the existing SID-bound application account. The migration
   grants the existing entry role EXECUTE on the wrapper; no account is created.
5. Use `deploy/export_stats_import_outcome_source.json` when reissuing the protected
   legacy contract. Preserve the separately pinned file-visibility amendment.
   Independently validate the new application source, metadata and permissions.
6. Deploy the reviewed matching private-main Bot source via the protected updater.

The old legacy manifest and migration remain immutable historical contracts. The
offline validator inverts only the reviewed UPDATE_ALL2 edits and checks the exact
old bytes; it does not add new bodies to the old runtime allowlist. The new source
manifest is deliberately a separate artifact. New migration/snapshot bytes use
explicit LF attributes so their pins survive checkout.

This is a forward-fix migration. Do not drop execution evidence, restore old
definitions over active work, or restart the successful historical export.
Deployment remains an operator readiness decision, separate from PR merge.

## Validation limits

`deploy/Test-StatsImportOutcomeContracts.ps1` verifies source/migration identity,
legacy inversion, permission scope and transaction marker placement offline.
`deploy/Test-ExportLegacyDirectPermissionContracts.ps1` includes this check while
preserving the historical signing/direct permission checks. ScriptDom parsing
establishes syntax only. Synthetic transactional rehearsal exercises protocol
semantics and migration rerun/backup/restore; it does not certify the entire legacy
UPDATE_ALL2 workload or production token/metadata installation.
