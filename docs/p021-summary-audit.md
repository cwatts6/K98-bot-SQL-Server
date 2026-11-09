# Task C Slice 14 — SUMMARY_PROC responsibility and write-cost audit

> **Approved rewrite implemented and locally qualified — 7 November 2026.** All eight metric routines and the alternate healed routine now use compact temporary endpoints. The complete focused local SQL suite passed 30 tests, including output parity, permissions and atomic rollback/cache restoration. See [implementation and qualification](p021-summary-implementation.md). No production deployment or retained VM workload ran; limits and remaining consumer/signing/full-rehearsal gates are unchanged. Earlier approval-pending wording below is historical.


> **Complete retained evidence and rewrite proposal — 7 November 2026.**
> All 192 retained plans are complete; all 184 summary cost records match the
> earlier attribution and all 12 captured module hashes are unchanged. Incoming
> static cache references cover ten modules, but broad grants leave external
> usage to settle before production retirement of cache refresh. The
> [concrete optimisation proposal](p021-summary-optimisation-proposal.md)
> recommends temporary endpoint calculation from existing shared history,
> with final/delta/latest outputs preserved and explicit legacy-cache/rollback
> handling. This resolves the earlier truncated-plan collection gap below.
> No further collection or diagnostic import is needed to decide the proposal.
> Summary implementation and candidate savings are not yet approved/proven.


> **Retained statement evidence reviewed — 7 November 2026, 20:38 UTC collection.**
> The read-only collection retained 184 unique statement/plan/interval records
> inside the ON summary phase, with one regular execution each and all 56 cache
> delete/insert pairs. The parent/eight child module hashes still match baseline.
> Deleting/reinserting the 32 history/window caches accounts for 118.841 of
> 127.589 seconds (93.14%) and 10,778,936 SQL-reported row actions. This identifies
> the rewrite target; it does not measure candidate savings or per-table versions.
> See [the measured evidence and bounded follow-up](p021-summary-cost-evidence.md).
> Extra instrumented OFF execution is no longer the immediate next step. Complete
> the retained plan and incoming-consumer inventory with the prepared read-only
> supplement. No summary rewrite, workload replay or limit change has occurred.
> Earlier attribution gaps and experiment suggestions below are the initial
> pre-collection assessment, superseded to this extent by the new evidence.


## Decision and evidence boundary

The operator approved bringing this existing deferred item forward on 7 November
2026. The snapshot-enabled rehearsal exceeded both the earlier 90-second summary
alert threshold and the declared version-store budget. This justifies early
investigation; it does not manufacture the earlier 30-production-batch sample or
authorize a wholesale rewrite. Continue the existing Bot Task C Slice 14 item;
do not create a duplicate optimisation backlog entry.

The smallest justified **next action is bounded measurement**, followed by a
specific helper/cache rewrite decision. Retained evidence does not identify
per-statement cost, affected-history row counts or version generation per table.
There is no defensible numerical saving to promise yet. Only the separately
approved historical-name correction has been implemented.

## Measured costs

| Measure | Snapshot OFF | Snapshot ON | Interpretation |
| --- | ---: | ---: | --- |
| Canonical import/report | 82.516 s | 144.781 s | One functional pair; not a median or causal benchmark |
| SUMMARY_PROC | 70.122 s | 127.589 s | About 85.0% / 88.1% of each total |
| GOVERNOR_NAMES_PROC | 1.760 s | 7.384 s | Separate determinism fix; ordering cost still to measure |
| Observed version-store peak | 0 KiB | 1,843,712 KiB | ON exceeds 524,288 KiB limit by about 3.52 times |
| Imported / archived rows | 415 | 415 | Both business imports completed |
| History rows afterward | 486,842 | 486,842 | Baseline 486,427 |
| Exact output matches | Reference | 13 of 14 | Name-history representative mismatch in remaining output |

The summary difference is 57.467 s of the 62.265 s total difference (about 92.3%).
That is correlation, not proof of which statement caused it. Warm/cold state,
file growth and cached plans were not controlled in this pair. Index-maintenance
choices were the same: two skipped, one reorganized, one rebuilt.

Later read-only collection found version store zero and no active snapshots.
Tempdb retained 2,080 MiB of data files, approximately 2,075.875 MiB internally
free; this is reusable allocation, not evidence of a continuing leak. Do not
shrink or restart to make the historical peak disappear. The budget stays
512 MiB, and the isolated guest disk reserve stays 8 GiB.

## Current responsibility and dependency map

Canonical source was checked against the retained restored workload definitions:
the parent and all eight active children match. The current report path is
`usp_S11CompleteStatsReportsCore -> SUMMARY_PROC`; the older `UPDATE_ALL` also
contains a direct call. All eight children have a standalone path which builds
its own affected-governor/history inputs when shared temporary tables are absent.
Static call references are evidence of code paths, not frequency or proof of
current manual execution.

The parent reads the minimum watermark of the eight metric states and the maximum
history scan. It returns when no newer scan exists. Inside its transaction it
builds `#SummaryRunState`, `#AffectedGovs`, and **one already-shared** `#GovScan`
containing all history for affected governors, with governor/scan and date/governor
indexes. It calls the children in the table order, rebuilds
`SUMMARY_CHANGE_EXPORT`, updates `SummaryExport` state and commits/rolls back.

| Child / metric state | Four persisted history/window tables | Three persisted delta tables | Latest / final output |
| --- | --- | --- | --- |
| DEADSSUMMARY_PROC / Deads | DALL, D12, D6, D3 | D12D, D6D, D3D | LATEST / DEADSSUMMARY |
| POWERSUMMARY_PROC / Power | PALL, P12, P6, P3 | P12D, P6D, P3D | LATEST_POWER / POWERSUMMARY |
| KILLSSUMMARY_PROC / T4T5Kills | KALL, K12, K6, K3 | K12D, K6D, K3D | LATEST_T4&T5_KILLS / KILLSUMMARY |
| KT4SUMMARY_PROC / T4Kills | K4ALL, K412, K46, K43 | K412D, K46D, K43D | LATEST_T4_KILLS / KILL4SUMMARY |
| KT5SUMMARY_PROC / T5Kills | K5ALL, K512, K56, K53 | K512D, K56D, K53D | LATEST_T5_KILLS / KILL5SUMMARY |
| KILLPOINTSSUMMARY_PROC / KillPoints | KILLPOINTS_ALL, KILLPOINTS_D12, KILLPOINTS_D6, KILLPOINTS_D3 | KILLPOINTS_D12D, KILLPOINTS_D6D, KILLPOINTS_D3D | KILLPOINTS_LATEST / KILLPOINTSSUMMARY |
| HEALEDSUMMARY_PROC / HealedTroops | HEALED_ALL, HEALED_D12, HEALED_D6, HEALED_D3 | HEALED_D12D, HEALED_D6D, HEALED_D3D | HEALED_LATEST / HEALEDSUMMARY |
| RANGEDSUMMARY_PROC / RangedPoints | RANGED_ALL, RANGED_D12, RANGED_D6, RANGED_D3 | RANGED_D12D, RANGED_D6D, RANGED_D3D | RANGED_LATEST / RANGEDSUMMARY |

Each child deletes and repopulates seven caches **for affected governors**, then
updates latest/final rows, aggregate rows and its `SUMMARY_PROC_STATE` metric.
That is 56 cache targets, not 56 whole-table truncations. For scale, baseline
DALL has 486,427 rows; D12 373,721; D6 241,366; D3 132,461; DEADSSUMMARY about
2,451. These are full table sizes, **not measured rows rewritten** by this import.
Window ranking uses ScanOrder and 3/6/12-month UTC date cutoffs. Descending ranks
can change across all a governor's historical rows when a scan arrives, so an
append-only replacement is not equivalent without changing the cache contract.

Resolved additional consumers:

- `dbo.TEST` contains actual reads/creation/deletion of DALL/D12/D6/D3 and a
  DEADSSUMMARY reference. This is not a production-use claim, but prevents treating
  the objects as disposable solely from their names.
- `HEALEDSUMMARY_PROC_OPT` reads/writes the same healed caches, latest/final tables
  and metric watermark. It has its own transaction/input setup, is not called by
  the current parent, and cannot be substituted merely because it is named OPT.
- `LATEST` is also read by location import/replacement and the leadership lookup
  directory. Preserve these contracts even if historical caches later change.
- Bot `config/sheet_config.json` directly selects `SUMMARY_CHANGE_EXPORT` and
  `ALL_GOVS_NAMES`; release/grant/source manifests also bind those output contracts.
- Other apparent cross-metric D12/D12D references were aliases or comments, not
  accesses to the death tables. A token-filtered, object-position inventory
  resolved those false positives. Dynamic SQL, external jobs and ad hoc clients
  still require target inventory before removal of any persisted table.

Retained evidence includes definitions/dependencies and outer audit timing, but
no attributable statement plans or Query Store runtime snapshots for this pair.
The existence of `sp_QS_PerfPack` is not evidence that Query Store is enabled or
contains these runs. No new production queries or workloads were executed.

## Options and cost model

| Option | Expected source-level effect | Cost / risk and selection |
| --- | --- | --- |
| Predicate unchanged latest/final updates | Avoid writes where all stored values are already equal | Small candidate after measuring unchanged-row fraction; unlikely alone to remove history-cache volume; exact NULL/float/name equality needed |
| Calculate first/latest/window deltas from shared #GovScan | Avoid repeated materialization/readback of history caches on the active path | Potentially substantial write reduction, unmeasured; must resolve every cache consumer, rank/tie and direct-call contract first |
| Incrementally maintain current history caches | Retain consumers while reducing some delete/insert work | RowDesc changes, expired windows and corrected scans can still require broad writes; more complex and cannot assume append-only |
| Extra shared history cache | No demonstrated benefit | Parent already shares history; reject as an unsupported duplicate |
| Index/plan tuning only | Potentially fewer scans/sorts | Requires actual plans/reads; extra indexes increase import and versioned-write cost |
| Raise snapshot limit / dirty reads | Does not repair the demonstrated issues | No budget change; dirty recovery observations violate the P02.1 contract |

For each candidate, report measured affected governors; all/window history rows
read, deleted, inserted and updated; row/index widths and allocations; logical
reads; CPU/elapsed time; spills; log bytes; and version-store samples. A transparent
write model is `sum(rows deleted + inserted + updated)` by target, with physical
bytes measured separately. Do not multiply full-table counts by eight or translate
row count directly into a promised version-store saving.

## Bounded measurement proposal — prepared, not executed

1. First collect **read-only** existing evidence on the retained isolated guest:
   exact VM ID/session/no-network/owned database, current requests/snapshots, stored
   definitions and signatures, target dependency rows (including TEST/OPT), index
   shapes, existing Query Store configuration/plans/runtime intervals and relevant
   cached statement metrics. Limit target objects to the parent/eight children
   and the name procedure; retain run time intervals and hashes. Do not enable
   Query Store or call its persistence-enabled helper. Old or aggregate plans are
   labelled contextual, never assigned to the OFF/ON pair without evidence.
2. If attribution remains absent, prepare one fresh owned **OFF** rehearsal with
   the reviewed name fix and the same backup/415-row input. Observe statements for
   the single workload session using a bounded diagnostic capture (at most 64 MiB
   event files and 300 seconds, exact session/database filter, no auto-start).
   Capture child/statement CPU, elapsed time, logical reads, writes and row counts;
   obtain a bounded actual-plan capture separately only if needed because it adds
   overhead. Retain disk/file-growth/log samples and session tempdb allocation.
   Define the exact capture events/permissions/cleanup in its reviewed executable
   pack before user execution; this proposal is not that executable pack.
3. This diagnostic run is attribution evidence, not a performance acceptance
   sample. Stop on missing identity/ownership, incorrect baseline/input/module
   hashes, an existing run folder, capture limits, workload failure or disk below
   8 GiB. Preserve failed evidence and state; never automatically replay. Clean up
   only its owned diagnostic session after it stops; no cache flush, shrink,
   existing-database deletion or production action.
4. Select the smallest measured helper/caches family. Its implementation pack
   must name exact procedures and consumers, before/after algorithm, migration
   pre/postimages, rollback, signing/source-pin changes, measured cost and tests.
   Start with one family only if it preserves shared/direct behavior; carry the
   equivalent eight-family obligations in the same design, avoiding a point fix.
5. After review and implementation, qualify full outputs on fresh baselines with
   the same SQL fix in both arms, then warmup and five balanced OFF/ON pairs plus
   actual candidate concurrent readers and the 30-second held-reader case.
   Keep the original performance/storage limits and all failed samples. Do not
   rerun the unchanged, known over-budget ON workload just to obtain more timing.

## Required semantic checks and related opportunities

Test all eight metrics, no new scan, missing/unequal metric watermarks, governor
zero, no affected governors, NULL metrics, first/last scan ties, declining values,
late/corrected history, month boundaries/leap dates, window expiry, synthetic
Top50/Top100/Kingdom Average rows, exact names/types, parent/shared versus direct
calls, failure after each child and rollback/state agreement. Current code
returns on unchanged maximum ScanOrder and refreshes affected governors only;
corrected old scans and time-only window expiry must not be silently redefined as
part of performance work. Any correctness change needs an explicit contract.

Children's standalone paths do not all provide the parent's transaction boundary;
the optimized healed sibling differs. Missing metric rows can be excluded from
the parent's MIN over existing states. These are review/test obligations in the
same Slice 14 responsibility audit, not newly proven production incidents or
permission to change semantics now.

SQL owns name and future summary changes. Bot owns later source-pin/release
integration and observer tests. The operator owns future VM execution and
production decisions. The six historical production incidents, later UPDATE_ALL2
and import-core decomposition, stats orchestration, PreKvK and inventory cleanup
remain separate; none is silently cleared or pulled into this patch.
