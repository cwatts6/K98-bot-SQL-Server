# Export report Stage 2: import history

Local source implementation for review. No installation or production export is authorised.

Two additive tables retain one immutable history per IntentID, authorised GuildID and
history schema version. The header binds source, season and vector hash; rows contain
bounded canonical report-safe JSON, original attempt ID and SHA256. Ordinals follow
receipt time plus SQL Server UUID ordering. There is no cascade, cleanup or expiry.
The Bot captures header and rows atomically, preserves mutable attempt statuses, and
verifies the entire snapshot before yielding report rows. Retrying an uncertain commit
reads the existing identity instead of replacing it. A new export intent captures a
new history; retrying the same intent does not incorporate subsequent imports.

Manifest: migration `20261013_001_kvk_export_history.sql` plus the two matching
`sql_schema/KVK.SourceExportHistory*.Table.sql` reference snapshots and this document.
Prerequisite: accepted KVK.SourceExportIntent with its scoped unique key.
The migration validates exact new columns, checks, keys/indexes, defaults, foreign
keys, table modes and triggers on first installation and rerun. Partial/drifted states
fail closed. It changes no existing rows, permissions, ProcConfig, UDTs or flags.
SQL deployment precedes use of the new Bot reader API. Existing exports do not call
that API yet. Rollback disables the new caller and retains tables; forward fix only.

Capture performs one scoped HOLDLOCK source read into a temporary table, then bounded
keyset pages. This can hold broad shared locks on the existing unindexed import scope.
Measure blocking/plans and tempdb use on an approved disposable database before rollout.
Counts are independent scalar queries per exact revision, never multiplying joins.
JSON is an explicit bounded, versioned SQL contract, not a temporary filesystem cache.
Temporal immutability is owned by the DAL, as for existing source publication tables.

Validation: Bot unit tests exercise the actual DAL with a transactional cursor model;
guarded SQL integration tests require an exact separately approved disposable target.
Mocks/static parsing do not prove SQL Server concurrency, installation or query plans.
No retained recovery database may be made writable or used as a fixture.
Separate Bot and SQL Changes reviews are required; Deep scan is off.
