> **Whole-P02 status, 7 November 2026:** This qualified rewrite is one component of the [integrated SQL delivery plan](p02-integrated-sql-delivery-plan.md). It does not close the original P02 scope or the failed full-workload snapshot resource gate.

# P02.1 summary endpoint rewrite: local implementation and qualification

Date: 7 November 2026. Operator approved implementation and isolated local tests.
Status: implemented; 30 focused tests passed on disposable local SQL fixtures.
Production deployment, full rehearsal cost qualification and external cache-consumer
clearance remain separate. Existing performance, version-store, log and disk limits
are unchanged.

## Delivered behavior

The eight metric procedures and HEALEDSUMMARY_PROC_OPT now calculate temporary
first/last rows for all history and the 3/6/12-month windows. Each calculation keeps
at most two rows per affected governor/window. The 32 persistent history tables
are no longer read or written by these nine procedures; they remain on disk for
the explicitly controlled compatibility/rollback process.

The existing parent SUMMARY_PROC is unchanged. It still loads shared affected
history and owns the transaction. The children still support direct calls, loading
their own affected history when shared inputs are absent. Their cutoff times,
ordering expressions, latest selection, small delta writes, final summaries,
aggregate rows and state updates retain their prior semantics. The alternate
healed routine retains its own transaction and existing ranking implementation.

Temporary column declarations match the former table types, nullability and
collations. This intentionally preserves float conversion in older metrics and
integer behavior in newer ones. The original KingdomScanData4 data is untouched.
There is no bot runtime, provider, import allocation, permission or scheduler change.

## Local qualification package

- Nine authoritative procedure files under `sql_schema` contain the rewrite.
- `qualification/p021_summary/legacy_modules.json` freezes the nine exact old
  module bodies; `manifest.json` pins normalized old/new body hashes and 32 targets.
- `qualification/p021_summary/install.sql` validates every module's body, SET
  options, caller execution context and absence of signatures before transactional
  installation. Object-level grants are retained; unknown definitions are refused.
- `qualification/p021_summary/rollback.sql` restores the old bodies and, in the
  same transaction, rebuilds the 32 caches for governors present in authoritative
  history. It does not execute business procedures, rewind watermarks or rebuild
  final reports. Failure leaves candidate definitions and prior data intact.
- Both scripts accept only `9SX2VF4\K98DEV` and a generated
  `K98_P021_SummaryTest_<32 lowercase hex characters>` database with matching
  database ownership metadata and session token. They are **local test scripts,
  not production migrations or commands for the retained VM**.

The rollback rebuild uses each canonical metric's historical expressions with a
fresh per-metric UTC cutoff. It refreshes all current nonzero governors, not just
those above the already-advanced watermark. Final summaries/state remain as they
were; an already-legacy repeated rollback does not execute a second cache rebuild.
This qualification does not authorize blind legacy execution as recovery.

## Tests and evidence

`tests/test_summary_endpoints.py`: **30 passed in 62.94 seconds** in the final
complete run. Black formatting and Ruff checks passed. Two UUID-named databases
were created on local K98DEV using canonical table definitions and removed after
the run; no forced disconnection or wildcard cleanup is used. Tests compare all
columns/multiplicities across 42 output/state tables (8 latest, 8 final, 24 delta,
export and state), plus targeted history preservation/rebuild assertions.

Coverage includes:

- Parent and all nine direct entry points; subsequent imports, corrected historical
  values for selected governors, unchanged governors and newly arriving governors.
- Empty input, zero-governor exclusion, one-scan and no-window histories, NULL
  optional values, decreasing values, float conversion and aggregate rank boundaries.
- Inclusive 3/6/12-month boundaries to datetime precision; no-new-scan calls remain
  no-ops even when the test clock moves forward.
- Identical historical ties; duplicate latest rows still fail and roll back the
  parent. Distinct historical ties retain existing unspecified ordering rather
  than acquiring a new implicit winner rule.
- Candidate calculations ignore retained stale cache data and leave those tables
  untouched. Alternate healed/parent interleaving preserves outputs and state.
- Mid-parent failure rolls back all dependent output/state writes. Real unmodified
  procedure bodies run with the existing caller permission boundary: EXECUTE alone
  cannot satisfy the parent's export TRUNCATE; the existing ALTER requirement is
  neither bypassed nor added to production grants.
- Install/repeat/rollback/repeat/reinstall; retained execute grants; wrong database,
  wrong ownership token, source drift, altered execution context and signed module
  refusal; cache-rebuild failure atomically restores candidate bodies and data.

Most parity tests replace only SYSUTCDATETIME with a fixed literal in the disposable
installed copies so clocks cannot change cutoff results or state comparisons.
Separate tests execute unmodified bodies and compare non-clock outputs. Test source
checks pin module hashes and prove latest selection/final aggregate/state expressions
remain unchanged apart from their history input names.

The canonical KingdomScanData4 file references KS4_UNO_SEQ whose definition is absent
from the SQL repository. Fixtures supply an explicitly synthetic unused sequence;
every SCAN_UNO is provided. This is not a claim of complete canonical deployment.
The canonical combined-kills table's filename uses an underscore where its SQL name
uses an ampersand; fixtures resolve actual CREATE TABLE names, not filename guesses.

Initial harness failures exposed a filename mapping assumption, a structural
assertion that did not account for RANGED's existing statement order, the parent's
existing ALTER permission requirement, local fixture-name validation errors, and
ODBC batch/result consumption plus CREATE/ALTER definition normalization. These
were corrected before the final full pass. They did not require changes to the
candidate's calculations. Original receipts and VM failures remain immutable.

## Security and remaining qualification

Review route: SQL repository **Changes**, Deep off, exact final uncommitted patch
against `dad628c7a353cc6391868d097a6ae5fb7a8d9e84`. It includes the retained earlier
name fix and new summary source/tests/local qualification scripts. Completed
scan `59b599c8-c2fb-4df2-b895-0c2000976138` reported zero findings, with complete
coverage for snapshot
`codex-security-snapshot/v1:sha256:8dd6f738ea98202bf3e40d8def7d1784570dea8554c9d5513ce9dc7dbb7ad1c1`.
The result was sealed and read back on 7 November 2026. This covers the rewrite;
the earlier name-only scan alone did not. Bot updates are documentation-only.

The later [numeric-type assessment](p021-summary-numeric-type-review.md), related
backlog note and this completion record are documentation-only changes after the
scan. They were manually reviewed; no executable file changed from the qualified
hashes. A new runtime security scan is skipped for that non-executable delta.
Architecture, deferred-item and security-routing validators passed. Test selection
suggested generic Bot smoke-import/command-registration checks; these are skipped
because the Bot changes contain no runtime modules or command registration changes.
The 30 native SQL tests are the focused runtime validation for this rewrite.

No full import/export rehearsal, candidate concurrent-reader test, held-reader test
or balanced five-pair performance study was run here. The retained observed 1.758 GiB
version-store peak still fails the unchanged 512 MiB ceiling. The earlier 118.841 s
cache-write cost identifies the target; it is not a measured candidate saving.

Next, prepare the reviewed fresh VM comparison with the same backup/415-row input,
the deterministic name fix in both arms, all 14 output checks, existing timing/log
limits, 8 GiB disk reserve and approved 8 GiB host-memory requirement. Preserve old
failed evidence and use new owned run folders. Do not reuse one-shot commands.

Before production: reconcile external/ad hoc readers of the 32 tables and the
legacy TEST routine's disposition; qualify real outputs/performance/concurrency;
complete signing/source-pin and historical release integration; produce a separately
reviewed release installer/rollback package. The local fixture scripts deliberately
cannot serve as that release installer. Existing six-incident recovery and provider
acceptance are not cleared by these tests.
