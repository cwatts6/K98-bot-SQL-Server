> **Archived 9 November 2026:** Completed Phase 1 analysis/qualification history, not current execution instructions. See [current SQL companion](../p02-integrated-sql-delivery-plan.md). Production installation is verified; whole-flow/provider acceptance remains separate.

# P02.1 deterministic historical-name selection — local implementation

Operator-approved scope, 7 November 2026: fix historical name selection and bring
forward the existing Task C Slice 14 summary responsibility/cost audit. This is
local implementation and qualification, not production deployment approval.

## Behavior

The historical-name output previously selected an unspecified spelling from each
SQL-collation-equivalent `(GovernorID, GovernorName)` group. Two isolated runs
therefore returned different visible names even though both imports completed.
Step 4 of `dbo.GOVERNOR_NAMES_PROC` now chooses the spelling from the highest
`ScanOrder`, with `Latin1_General_100_BIN2` ascending spelling as the same-scan
tie-break. Partitioning still uses the source column's existing collation.

The source remains `ROK_TRACKER.dbo.KingdomScanData4`. Governor zero and NULL names
remain excluded; unrelated name groups, `RTRIM`, float governor output and
nchar(255) name output are preserved. Differences consisting only of trailing
spaces can tie under SQL comparison but produce identical trimmed output.
Steps 1–3 and 5, transactions, execution context, permissions, table/index shapes
and Bot code are unchanged. This is a determinism correction, not a claimed
performance improvement; its extra ordering must be costed on restored history.

## Installation and rollback

Forward artifact: `migrations/20261107_001_deterministic_governor_names.sql`.
Rollback artifact:
`migrations/rollback/20261107_001_deterministic_governor_names_rollback.sql`.

Both scripts accept only their exact predecessor or postimage, normalizing CRLF
and the stored CREATE/ALTER header. They refuse missing/unreadable procedures,
unexpected execution context/SET options and module signatures. Fixed reviewed
definition literals are executed transactionally; there are no business-row
writes or procedure calls. ALTER preserves object permissions. Rollback restores
the prior definition and its original nondeterministic spelling behavior; it does
not rewrite any output already produced. Repetition is a definition-only no-op.

Use an explicitly selected, approved target and exact migration ID after backup
and inventory. Never use the legacy runner's production defaults or batch mode.
An existing signed procedure requires a separately reviewed signing release;
this migration deliberately refuses to strip its signature.

Existing S11/P0 release manifests, installed-byte allowlists and Bot source pins
remain historical release artifacts. They have **not** been silently updated to
accept the new body. Before deployment, prepare the corresponding versioned
release/profile and Bot source-pin change, with exact live predecessor, signing
and restricted-principal qualification. The old manifest equivalence test proves
historical manifest preservation, not compatibility of this new module with a
deployed signed closure. Publication/deployment readiness is not claimed.

For the isolated VM, its six reviewed cross-database substitutions require a
separate pinned test-profile adaptation of both expected images. Do not loosen
the canonical migration to accept arbitrary replacements. Both future OFF/ON
arms must use the same reviewed fix and fresh baselines, preserving old evidence.

## Qualification

`tests/test_deterministic_governor_names.py` contains the source contract test and
opt-in native tests. With `K98_NAME_SQL_TESTS=1`, it connects only to local
`9SX2VF4\K98DEV`, creates a unique `K98_P021_NameTest_` UUID database, and drops only
that fixture without forced disconnection. It never executes the business
procedure. Query tests use the real extracted step-4 SQL and session-local tables
with authoritative source/output types and collations.

33 tests passed: latest case/Unicode representative, equal-scan binary tie,
reversed input order, trailing spaces, accent-sensitive separate groups, multiple
governors, duplicates, empty input and NULL/zero filters; exact output padding and
two-way preservation of SQL equivalence groups; forward/repeat/rollback/repeat/
reinstall with LF and CRLF; permission retention; CREATE header recognition;
unknown-definition, owner-context and signed-module refusal.

The first harness run exposed two test-harness defects: SQL stores a CREATE
header after ALTER, and pooled connections prevented immediate fixture drop.
The comparison now normalizes only the declaration header; pooling is disabled.
The corrected complete run passed. Neither defect changed business data or the VM.

SQL repository validation passed with zero errors and 29 existing warnings;
historical source-custody and P0 extraction checks passed. Full restored-history
output equality, name-sort cost, snapshot storage limit, balanced performance
pairs and candidate concurrent observers remain unqualified. The previous
snapshot-enabled rehearsal is still a failed qualification.

The additional historical `Test-ExportLegacyModulePermissionContracts.ps1`
check was run and **fails at `Source byte drift: dbo.GOVERNOR_NAMES_PROC`**.
This is related to the intentional source change and is an open release gate,
not an unrelated test failure. A later versioned signing/source integration must
reconcile this checker using exact historical reconstruction and separate new
postimage validation; do not replace historical hashes or weaken the check.
The legacy migration runner also retains production target defaults and does not
enforce explicit target arguments for this new ID. Use explicit target selection;
that requirement is currently procedural, not a new enforced runner guarantee.

Bot runtime pytest, command registration and smoke-import tests are skipped:
there is no Bot runtime change in this SQL-only patch. Bot architecture/deferred/
security-routing/selector gates are evaluated separately for audit documentation.
SQL Changes security review covers this patch separately from the earlier Bot
review: scan `e62a1422-6ac3-440f-82d5-4971e92fb4ab` completed with zero findings,
Deep off, covering the three SQL files, test source and both documents. Subsequent
import-order formatting, restoration of the snapshot's original UTF-8 BOM and
this status clarification were manually reviewed; executable SQL is unchanged.

The connected optimisation proposal is [the Slice 14 audit](p021-summary-audit.md).
