> **Current status, 9 November 2026:** Phase 1 isolated SQL, shared latest names, numeric/export accuracy and recovery-reader qualification passed. Production release and the remaining P02 phases are separate. See the final acceptance section below.

# Shared report names qualification

Approved policy: display the latest nonempty name across current and historical
reports; preserve alias history separately. No separate speed benchmark.

The source images in `reviewed_sources.json` preserve the numeric-stage baseline
and the shared-name candidate. `targets.json` is the fixed table/identity/name
contract. Install the canonical view before the helper, then the callers and
report views. No production installation is authorized by this package.

The installed target-view binding must be read and preserved: the bootstrap SQL
snapshot is not permission to redirect an existing view to target table 15.
Reject unknown module bodies, signed-module changes, unexpected columns and
unreviewed target bindings. Existing EXECUTE permissions must survive ALTER.
Rollback restores the captured before-images, then removes only the two newly
owned objects after caller dependencies are restored. Output-name rollback must
restore captured labels transactionally; applying module before-images alone is
not a data rollback. Do not regenerate immutable queued export payloads.

Retained-VM definition evidence verified the active KVK16 target. The four-object
rollback-only names comparison is prepared; its VM receipt remains pending.
The numeric package remains a separately reproducible first stage. See
`../../docs/p02-phase1-implementation.md` for actual tests and open gates.


## 9 November 2026 - verified shared names and one final integrated rehearsal

The retained shared-name rollback comparison is independently verified:
14 exports, 49,472 rows, 827,703 cells; exactly 4,717 display-name cells changed,
with zero numerical changes and unchanged row multiplicity. Historical aliases
are preserved. All 172 original SQL definitions and original output rows were
restored exactly, with read-only containment verified. KVK16 remains the target.
The private proof is `phase1-shared-names-comparison-verified.json`; receipt
`P02-phase1-shared-names-comparison-b5c75ea78ed74ab9b9a7c7904b503b31.json`
has SHA256 `333777c80134d772cee632c073201ed5a123182aaf3c02fce66bdb93ba87209c`.

The operator explicitly approved "Allow 21 files for one rehearsal". This changes
only the retained-input cap from 20 to 21 for the one final integrated run
`142c9a6cc57b4b728c3e06056b849d71`. The additional copy is the same 415-row,
78,035-byte input. All old inputs and evidence remain preserved. Four CPUs,
8 GiB VM memory, 8 GiB disk reserve, log below 70%, version store below 512 MiB,
producer and per-stage timing limits, reader statement/hold/cleanup budgets and
production separation are unchanged. No name-speed benchmark is required.

`Invoke-P02Phase1FinalIntegrated.ps1` is prepared to preserve the completed
comparison and previous failures, restore only the owned test database, install
the unchanged 139-column/11-procedure numerical package followed by the complete
26-object shared-name package, then run one fresh import and its reports. The
short actual recovery inspector and a 30-second reader of the same ownership
and status tables run around that import. All 14 raw exports and the actual Bot
immutable local payload are retained for independent verification. The input
inventory must be exactly 20 before reset and exactly 21 after completion.

Local qualification: 47 installer, generated-runner and independent-verifier
checks passed; three native reader lifecycle tests passed, including a full
30-second hold while the raw source index was rebuilt; the exact 26 SQL bodies
compiled in disposable native databases and rollback restored their original
module inventory. Three PowerShell 5.1 wrappers parsed, valid pre/post inventories
passed, and 27 altered states/inventories were refused. The source-summary oracle
was exercised against retained source scans with only the approved name overlay;
numerical computations and original stage times were retained. Synthetic test
fixtures produce no VM acceptance proof. Actual pinned Bot imports were checked.

Focused supplemental static review found no concrete defects in the private
installer/reader/wrappers, including the final 21-file inventory and bounded fresh
metadata read. This is supplemental tooling review, not a new full Git scan.
The completed SQL Changes scan and earlier full regression evidence remain
applicable to unchanged checked-in runtime sources. Production installation,
promotion and deployment remain separate and are not authorized by this run.

The complete 26-object fresh import and simultaneous held-reader VM receipt is
still pending. The earlier raw-history snapshot failure across index REBUILD
(SQL 3961) remains preserved; metadata-reader acceptance cannot establish that
arbitrary raw-history readers survive DDL. P02 D3 retains maintenance ownership.
Do not mark Phase 1 or all P02 complete until the integrated evidence is reviewed.

Current handoff checks: architecture boundaries, deferred-item validation,
security routing and Bot/SQL whitespace checks passed. The test selector was
run for the documentation delta. Its general smoke-import and command-registration
recommendations are skipped because neither Bot runtime nor command registration
changed in this slice; the exact packaged inspector/import path was checked
separately. The private tooling has its own focused native and failure tests.

Independent review of the new offline acceptance checker identified a parent
summary identity-multiplicity gap. It is corrected: the parent output must contain
exactly the verified child-summary player IDs, once each. A duplicate-player /
missing-player fault preserving total row count is now rejected. The focused
verifier suite passed 17 cases; follow-up review confirmed this specific fix.
No VM acceptance is claimed and the execution package was unchanged.


## 9 November 2026 - final installation handoff correction and same-input continuation

The final integrated attempt `142c9a6cc57b4b728c3e06056b849d71` stopped during
installation, before producer admission or import. All 45 retained evidence files
were authenticated. The 139-column/11-procedure numerical installation committed;
the shared-name installation had not begun. Read-only containment was restored.
The failed command and its package remain immutable and must not be rerun.

Root cause: the new shared-name installer treated the numerical install receipt's
submitted-body hashes as stored-definition hashes. SQL Server stores these eleven
ALTER PROCEDURE bodies with an initial CREATE keyword. The distinction had been
proven earlier in the source collector but was not carried into this new installer
handoff. The old native compilation test did not exercise this sequential handoff,
and the old installer mock used an empty numerical predecessor mapping. This was
a qualification-tooling error, not an observed import or report-data failure.

The separate v2 installer now authenticates submitted SQL evidence independently,
compares stored numerical definitions with only their leading DDL verb/spacing
normalized, and preserves exact body and unrelated-module checks. A native local
regression executes all eleven numerical definitions, reproduces SQL Server's
stored form, verifies the corrected handoff, rejects body drift, then compiles all
26 shared-name definitions and verifies rollback. It passed.

Read-only receipt `P02-phase1-final-install-state-255033b839394311b5ffda180949a0fc.json`
passed independent verification: 172 exact expected definitions, 139 converted
columns, unchanged history 1,244 / 486,427 rows, no matching execution/preparation/
resource ownership rows, and exactly 21 retained inputs. The same pending input
`stats_0cc4457d9042433ab82c81caab004447.ready.csv` remains ready. No extra input is
needed and the one-rehearsal 21-file allowance is not increased.

`Continue-P02Phase1FinalIntegrated.ps1`, attempt
`7aea1e23b649448ea68df59b714445cb`, is prepared to recheck this exact state, preserve
the original failure, and use a separate one-shot evidence directory for the same
approved pending workload. It skips restore and numeric reinstallation, applies
the corrected shared-name stage, then runs the pending import/report/export and
metadata concurrency checks. It does not publish another input. Original logical
run, preparation, owner, account, filename and digest remain unchanged.

Continuation qualification: 57 focused Python checks passed (installer 16,
runner/containment 14, independent output verifier 17, resume prerequisites 10),
plus the native sequential handoff/26-module rollback test. PowerShell 5.1 checks
parsed both collector and continuation wrappers, exercised the full read-only
collector with inert boundaries, rejected 28 changed installation states and nine
changed pending-input inventories. The 21-file final inventory check is unchanged.
The earlier 30-second reader native proof remains applicable: reader, concurrency,
Bot, SQL bodies and data/export limits are byte-identical to the sealed package.

Supplemental read-only review found no concrete defects in the continuation host,
guest, runner delta, v2 installer, resume contract or hash bindings. Checked-in Bot
and SQL runtime sources are unchanged, so the completed Changes reviews remain
applicable; private continuation tooling is covered by this explicit supplemental
review and targeted tests, not represented as a new whole-repository scan.

The continuation VM receipt and its independent acceptance remain pending.
Production deployment remains separate. No Phase 1/P02 completion is claimed.


## 9 November 2026 - Phase 1 isolated qualification accepted

The completed continuation `7aea1e23b649448ea68df59b714445cb` passed independent
verification. Receipt SHA256:
`c7f9ae17a8fc707b3241a8a809fb7a03026e203279008504137250b8563a5247`.
The original stopped attempt, its overstrict export comparison, all inputs and
all prior evidence remain preserved. No restore, numeric reinstall, second import
or additional ready input was used by the continuation.

Acceptance covers the coordinated endpoint SQL rewrite, 139 numeric columns,
all 26 shared-name SQL objects, latest names for 2,449 players, and all 14 raw and
actual-Bot immutable local exports. The current exports contain 49,468 rows and
827,683 cells. Source-based checks verified 19,920 endpoint cells, 432 aggregate
cells and 117,696 combined-summary cells, plus exact player membership and row
multiplicity. Historical alias output remains exact; KVK16 binding is preserved.
The actual immutable payload reload is byte-identical and no provider was called.

Two differences from the previous-day reference were explicitly adjudicated,
not ignored or relabelled as name changes:

- All 353 changed KVK ordinal ranks belong to zero-DKP players. The unchanged SQL
  uses ROW_NUMBER ordered only by DKP_SCORE, so this tie has no defined internal
  order. Both reports contain each of the same 415 players once, ranks 1-415 once,
  and descending scores. Every non-rank cell is unchanged apart from the approved
  latest display names. Positive-score ranks did not change.
- Four inactive rows dated 1 August 2026 05:59 aged past the existing 100-day lower
  cutoff. The actual procedure's saved local start/end log is 9 November 2026
  09:21:28.060 / 09:21:28.077, with server offset zero. The independent oracle
  recalculated membership and latest power/name/date from all 486,842 retained
  source rows, including SQL datetime rounding bounds. It requires exactly 571
  eligible rows, rejects ambiguous cutoff boundaries, and verifies every retained
  value. The four removals account exactly for the 4-row / 20-cell export decrease.

The original exact-reference verifier and its stop are retained. The separate
`verify_phase1_final_continuation_v2.py` plus `verify_phase1_report_semantics.py`
adds only these source-proven existing rank/date semantics. Seventeen fault tests
passed: duplicate/missing players, invalid/duplicate/fractional ranks, wrong
scores/statistics, wrong inactive names/power/dates/status, unexpected identities
and ambiguous date boundaries are rejected. Supplemental independent review found
no concrete defect in this adjudication. No workload package, report SQL or
acceptance resource/timing limit was changed to obtain the pass.

Concurrency qualification passed with the actual short recovery inspection during
an active writer and the same three-table recovery-metadata snapshot held for
30.031 seconds. The held transaction retained the prepared view after commit;
a fresh read saw completed version 4. No conflicting data/application locks were
held, and all original reader/monitor connection identities were verified closed
within the existing one-second bound. The earlier observer-first qualification
and five balanced OFF/ON pairs remain preserved and applicable. The 13.375-second
producer measurement, including observer setup, and all report stages passed the
unchanged timing ceilings; this single run is not a name-speed benchmark.

Resource limits passed: minimum free space 9,146,789,888 bytes (above 8 GiB),
maximum log use 2.4244%, maximum version store 5,184 KiB (below 512 MiB).
Exactly 21 inputs remain: the original ready input and 20 archives. The pending
input was imported once and archived. The owned test database returned to
READ_ONLY / RESTRICTED_USER, Broker/RCSI remain off, snapshot remains on, and
file-command settings returned to disabled. Other databases and production were
not targeted. No further rehearsal run is required for this Phase 1 scope.

Canonical private acceptance proof:
`phase1-final-continuation-adjudicated-7aea1e23b649448ea68df59b714445cb.json`.
Clock/log corroboration:
`P02-phase1-final-report-clock-eca6313027024a7aa1c9975f6e91bbcc.json`.

This closes Phase 1's isolated SQL/name/numeric/export and selected recovery-reader
qualification. It does not close all P02, authorize production deployment, prove
provider delivery, resolve the six production incident records, or qualify
arbitrary raw-history snapshot readers across index DDL. The original SQL 3961
raw-history failure remains owned by the P02 D3 maintenance work.

Next delivery gate: final coordinated Bot/SQL source and release-contract review,
versioned production installation/source-pin/signing/updater integration, fresh
installed binding/host custody and retained-work readiness evidence, and a
concrete rollout/rollback plan. Production action remains separately approved.
D2-D4 remaining observer/connection/maintenance/legacy scope, whole-programme D5
fault/restart qualification, and D6/D7 release/provider/exercised acceptance remain
open under the integrated plan. Do not substitute this isolated pass for them.

### Deferred Optimisation
- Area: SQL `dbo.sp_ExcelOutput_ByKVK`, `KVK_RANK` projection and downstream `STATS_FOR_UPLOAD` exports.
- Type: consistency
- Description: Existing ROW_NUMBER ordering uses only DKP_SCORE. Equal-score players have valid but unstable ordinal positions across recalculations; the qualified run permuted all 353 zero-score ranks without any score or other statistic change. This is an existing tie-policy limitation, not incorrect metric data or a new name regression.
- Suggested Fix: At the release/output-consistency review, explicitly decide and document a stable secondary key such as GovernorID ascending, or retain the current unspecified-tie policy. If changed, test repeated recalculation, report/export agreement and preservation of every score and player; do not silently change ordinal policy while closing the current name/numeric tests.
- Impact: low
- Risk: low
- Dependencies: SQL report owner decision on equal-score ordinal policy; separate from Phase 1's preserved-ranking contract and P02 D3 DDL ownership.
