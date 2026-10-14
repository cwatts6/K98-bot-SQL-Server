# Additive table release profile

`additive_tables_v1` extends the existing combined updater's pinned SqlClient
runner. This is implementation for review, not installation or activation.
The normal updater selects an exact profile from the pinned SQL commit through
the reviewed Bot descriptor `k98-release.json` in that repository's `deploy`
directory. No arbitrary SQL migration is executed.

The JSON fields are exactly `version` (1), `profile` (`additive_tables_v1`),
`migration_id`, `database_collation`, `tempdb_collation`, `compatibility_level`,
`tables`, and `requires`. Environment and predecessor-history fields retain the
module profile semantics. All tables must be absent initially. Existing exact
tables without this profile's committed receipt are refused, not adopted.

Each of at most eight tables declares ordinary `schema`/`name`, `columns`,
`primary_key`, `unique_keys`, `checks`, and `foreign_keys`. Columns specify exact
`name`, `type`, boolean `nullable`, and `collation` (null for non-character types).
Version one supports int, bigint, bit, uniqueidentifier, date, datetime2(0–7),
binary/varchar lengths 1–999, nvarchar lengths 1–999 or max. Character collation
must be explicit. Identity, computed/default columns, custom types, triggers,
partitioning/compression, replication, temporal/memory/file tables, existing-table
ALTER, data backfill, grants, schema creation and destructive changes are excluded.

Primary/unique keys specify `name` and `columns`. Primary keys are clustered and
unique keys nonclustered. Checks specify `name` and a bounded expression:
`and` with 2–8 `args`, or `op`/`column`/`value`. Operations are `eq` (quoted printable
ASCII string data, at most 128 characters), `gt`, `ge`, `bytes_eq`, `bytes_min`, `bytes_max`, `bytes_between`, `digits`
(true) and `json` (1). Arbitrary expressions/functions are not accepted.
Foreign keys specify `name`, `columns`, `schema`, `table`, `target_columns` and
always use NO ACTION. New referenced tables must precede their consumers within
the same profile. Existing referenced tables need the exact enabled unfiltered
unique key. Intra-release dependencies between separate profiles remain unsupported.

The runner generates DDL from these declarations. Preflight checks schema, absence,
constraint collisions, referenced keys, compilation of temporary expected tables,
deployment history, metadata visibility, triggers, backup age and environment.
Postimage verification independently compares column/index/check/FK metadata,
object identities and ordinary table modes; it does not rerun the migration or
equate table existence with success. Temporary expected tables are confined to
tempdb; observation creates no persistent application or migration data.

Apply reuses the module runner's exclusive session lock and existing ledgers.
Table creation and the Applied/Succeeded receipts commit in one transaction.
Attempts use BranchName `additive_tables_v1`, binding profile hash, SQL commit,
migration ID and release UUID. Real process death before commit must produce exact
absent preimages and a retained attempt; the same release may retry after proving
rollback. A committed receipt and exact postimages allow continuation without
reapplying. A different release, partial schema, altered metadata or unknown owner
is refused. Schema is retained on Bot rollback; no automatic DROP or database restore.
Migration identities are shared across both supported profile families: a retained
module-profile attempt also prevents reusing that identity for additive tables,
and conversely. A different profile requires a reviewed corrective identity.

`validation/build_history_release_profile.py` generates the first two-table report
profile using explicit observed collations and compatibility. It performs no SQL
operation and does not overwrite an existing output. The generated definitions
match `20261013_001_kvk_export_history.sql`. Review and commit the resulting
`20261013_001_kvk_export_history.release.json` in `migrations/` before pinning it in a Bot
descriptor. Never substitute development observations for production values.
The historical `.sql` and this profile are alternative installation paths; their
different receipt/checksum contracts are not interchangeable. If history tables
were installed through the historical path, stop for explicit reconciliation.

Run `deploy/Test-TableReleaseProfile.ps1 -FixturePath <generated-test-profile>`
offline, and the existing module profile regressions. The real rehearsal is
`validation/rehearse_table_release.py --database <approved-disposable-name>`;
it requires an exact `K98_TABLE_TEST_APPROVED_TARGET`, asserts local K98DEV identity,
adds isolated schemas and missing fixture ledgers, makes a test backup, and retains
all evidence. It refuses production and does not create/drop a database. It covers
matching legacy schema, first/repeated apply, retained data, wrong-release adoption,
partial/drifted shape, transaction rollback, real process death and lock contention.
