# P0a recovery migration-chain rehearsal

Status: the twelve-migration SQL chain passes on a fresh disposable local
database. This is not a production deployment approval or a complete P0a release.

The source baseline is `b3480656e3454fbe713905460177f8d038c2bd5f`; the migration
candidate is `21de1988819fc734252b9efc68c2ea047d0b11d3`. The retained helper at
`validation/rehearse_guided_recovery_migrations.py` uses those immutable revisions,
an explicit `--allow-disposable-sql` option, a fixed local shared-memory SQL
instance and an exact server identity check. It creates and retains a new random
database; it never targets an existing application database.

The baseline fixture installs 58 source-defined tables, their foreign keys and
seven changed predecessor procedures. It then applies the twelve literal
migrations from `20261015_001_failed_read_history` through
`20261016_002_atomic_configuration_publication` in the helper's explicit order.
No business procedures, provider operations or Discord messages run.

## Defects found and corrected

Migration `20261015_009_guided_export_replacement.sql` failed when executed as
one complete SQL Server batch. The fix:

- Gives each of its three temporary before/after constraint pairs unique names.
  Dropping and recreating the same temporary name still conflicts at compilation.
- Compiles the three DDL statements that use newly added columns through fixed
  literal `sp_executesql` calls, inside the existing migration transaction.
- Compares constraint definitions with explicit binary collation on both sides,
  preserving exact preimage checks across database/tempdb collation differences.

The constraints, index semantics, stored-procedure payloads, permissions and
signature checks are preserved. The migration file checksum changes and must be
bound explicitly in the forthcoming release package. Existing installation
receipts must never be rewritten to adopt this checksum.

## Evidence and limits

On 16 October 2026, retained database `K98_P0a_Migrations_8e954346a854` passed
all twelve migrations. Database collation was `Latin1_General_CI_AS`, differing
from the local tempdb collation. A test-only THROW immediately before migration
009's outer COMMIT left no open transaction and restored the captured object,
column, index and permission metadata. Applying the original migration afterwards
succeeded. The JSON result is retained in the local OS temporary directory as
`K98_P0a_Migrations_8e954346a854.json` and records each applied source checksum.

The companion Bot migration regression executes all six temporary declarations
in one driver batch and checks their constraints against independent source
definitions. That suite and rollover migration checks passed: 4 tests.

Ruff and whitespace checks pass. Black timed out on the standalone rehearsal
helper, including a bounded 30-second `--fast` attempt; no formatting pass is
claimed for that helper. The engine rehearsal executed the retained source.

Changes security scan `c5434566-e65e-427b-8198-c3b1e9c10a26` covered both changed
source files in `71c6cedc..662f58c6`, with Deep off. It completed and its sealed
result was read back at `2026-10-16T08:55:08.279104Z`: complete coverage, zero
findings. Reported usage: 953,337 tokens. This subsequent evidence document is
documentation only; it changes no execution, configuration or permissions.

Still required for P0a: coordinated migration/receipt handling, protected host
contracts and source/seed activation, the enabled-action acceptance matrix, and
the final installed-package rehearsal. This fixture does not prove business-data
publication, live provider delivery or recovery from a lost deployment commit
reply. All P0b workflows remain required, as recorded in the Bot release split.
