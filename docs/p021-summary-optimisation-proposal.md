# P02.1 / Task C Slice 14: summary optimisation proposal

> **Approved rewrite implemented and locally qualified — 7 November 2026.** All eight metric routines and the alternate healed routine now use compact temporary endpoints. The complete focused local SQL suite passed 30 tests, including output parity, permissions and atomic rollback/cache restoration. See [implementation and qualification](p021-summary-implementation.md). No production deployment or retained VM workload ran; limits and remaining consumer/signing/full-rehearsal gates are unchanged. Earlier approval-pending wording below is historical.


Date: 7 November 2026. Status: evidence reviewed; proposed implementation awaiting approval.

## Scope summary

Replace repeated rebuilding of 32 persisted intermediate history tables with
temporary endpoint calculations from the history already loaded by SUMMARY_PROC.
Keep the original scan history and the summaries used by reports. This extends
the existing approved Slice 14 audit; it is not an additional duplicate backlog item.

The proposed approval is for local SQL implementation and disposable local
qualification, followed by preparation of a reviewed isolated-VM rehearsal.
It does not authorize production activation, deletion of old tables, incident
recovery or an immediate repeat of the retained VM workload.

## Evidence and expected benefit

The supplementary receipt `P021-summary-detail-evidence-eaede657f004495eb964463407564c2f.json`
completed without errors or workload execution. Private `summary-detail-review.json`
verifies all 192 retained plans as complete XML (7,396,412 UTF-16 bytes), 192 unique
regular single-execution runtime records, 12 unchanged module hashes, and all 184
summary records with unchanged costs from the earlier capture. The 8 remaining
records concern governor names. No plan contains actual per-operator runtime counters.

| Measured work in the retained ON run | Duration | SQL-reported row actions |
| --- | ---: | ---: |
| Delete affected history from 32 intermediate tables | 80.786 s | 5,416,720 |
| Reinsert that history | 38.056 s | 5,362,216 |
| Combined target | 118.841 s | 10,778,936 |
| Whole summary phase | 127.589 s | Not a row-action total |

The target is 93.14% of the observed summary elapsed time and approximately
4.380 GiB of recorded transaction-log generation. These are attribution figures,
not a promise to save 118.841 seconds or 4.380 GiB: replacement calculations still
consume CPU, reads, sorts and temporary storage. Transaction-log bytes are not
row-version bytes. The earlier 1,843,712 KiB version-store peak still fails the
524,288 KiB ceiling; this proposal has not yet demonstrated a passing candidate.

The complete HEALED_ALL delete plan uses a clustered index seek driven by
#AffectedGovs, followed by indexed deletion and a sort. The RANGED_ALL plan also
has indexed governor lookup. A blanket recommendation to add another lookup
index does not address the demonstrated volume of delete/reinsert work.

## Affected areas and architecture direction

SQL owns the change. No Discord command, view, bot orchestration, DAL, configuration,
startup or scheduler change is proposed. SUMMARY_PROC already loads #AffectedGovs
and #GovScan once; reuse those inputs rather than introduce another history store.

| Routine | Persisted history tables replaced in the candidate calculation |
| --- | --- |
| DEADSSUMMARY_PROC | DALL, D12, D6, D3 |
| POWERSUMMARY_PROC | PALL, P12, P6, P3 |
| KILLSSUMMARY_PROC | KALL, K12, K6, K3 |
| KT4SUMMARY_PROC | K4ALL, K412, K46, K43 |
| KT5SUMMARY_PROC | K5ALL, K512, K56, K53 |
| KILLPOINTSSUMMARY_PROC | KILLPOINTS_ALL, KILLPOINTS_D12, KILLPOINTS_D6, KILLPOINTS_D3 |
| HEALEDSUMMARY_PROC | HEALED_ALL, HEALED_D12, HEALED_D6, HEALED_D3 |
| RANGEDSUMMARY_PROC | RANGED_ALL, RANGED_D12, RANGED_D6, RANGED_D3 |

For each metric, derive first and last values in ScanOrder order for all history
and each rolling window. Use temporary ranked calculations and compact per-governor
endpoint results; feed the existing delta and final-summary calculations from
those results. Preserve each child's present UTC cutoff calculation and inclusive
ScanDate comparison. Do not silently substitute a shared new cutoff timestamp,
MIN/MAX of metric values, different tie-breaking, or a new null conversion.

Keep all eight latest tables, eight final summary tables, 24 small delta tables,
SUMMARY_CHANGE_EXPORT and SUMMARY_PROC_STATE. Preserve their shapes, types,
affected-governor selection, aggregate rows, ranks, rounding and current update
semantics. Parent transaction ownership and commit/state ordering remain intact.
Preserve direct child entry points and their source-loading path; qualify direct
calls explicitly. Do not claim they provide all the parent's atomicity today.

Latest-table consumers include location/leadership paths; these remain in the
compatibility inventory. Bot sheet configuration consumes final export/name
outputs rather than the 32 intermediate tables. No change to KingdomScanData4,
scan allocation, raw import handling, file custody or provider delivery is proposed.

## Intermediate-table compatibility decision

The capture contains 88 incoming dependency metadata rows across ten modules:
the eight canonical children, HEALEDSUMMARY_PROC_OPT and TEST. Some references
have unspecified schemas and overlap named dbo references; retain the full rows
rather than treating every row as an additional caller. No cross-database/server
reference appears in this captured set. This is a static inventory of the restored
database, not proof that production, dynamic SQL or external tools have no readers.

Broad schema SELECT grants exist for SHEETS_USER, ImportProcUser and
ExportLegacyEntryReader. Therefore the proposal explicitly changes the automatic
freshness contract of the 32 work tables. It must not be described as preserving
every observable table merely because normal reports remain equivalent.

During the isolated prototype, retain old tables for inspection and rollback but
do not use their old contents as candidate report inputs. Before any production
activation, identify external consumers and either migrate them to the supported
summary/history interfaces or retain compatible maintenance. Approval of this
prototype does not certify that external consumers are absent.

HEALEDSUMMARY_PROC_OPT must be addressed in the same implementation family:
preserve its callable interface and healed output/state behavior while removing
its dependency on freshly rebuilt history caches, with independent parity tests.
Do not leave a second legacy writer sharing a watermark as an assumed fallback.
It can return early after the new path advances that watermark, leaving caches
stale. Its implementation differences require explicit comparison before reuse
of any new internal calculation.

TEST is a legacy destructive routine that creates/drops history tables and drops
DEADSSUMMARY; it is not a normal passive report. Do not execute it during
qualification or bundle unrelated deletion of it. Its operational disposition
must be recorded before release; it is not an approved recovery mechanism.

Rollback must restore exact old module bodies and re-establish intermediate-cache
freshness before legacy consumers resume. Retaining tables alone is insufficient.
Prove controlled rebuilding from authoritative history with explicit state handling
on a disposable copy; never assume a no-new-scan legacy call will rebuild them.

## Alternatives assessed

| Option | Assessment |
| --- | --- |
| Temporary endpoint calculation from shared history | Preferred prototype: removes the demonstrated large persistent write cycle, with explicit cache-contract and rollback work. |
| Incrementally maintain existing history tables | Required alternative if a real consumer needs these tables. It preserves that interface but descending ranks, corrections and window expiry can still require broad updates. Not equivalent to adding only 415 rows. |
| Tune indexes or query plans only | Possible later refinement if candidate measurements justify it. Existing seeks and dominant write volume do not support selecting this as the main fix. |
| Replace DELETE with TRUNCATE | Reject: the current deletes target affected governors; truncation would discard unrelated cached history and retain the full rebuilding cost. |

For example, the death 12-month cache changes from 205,367 deleted rows to
200,864 inserted rows, while the all-history cache grows by 415. Rolling windows
can shrink even during a new import. New rows also change descending ranks.
Recomputing endpoints from authoritative affected history avoids introducing a
separate incremental invalidation protocol for this first candidate.

## Refactor and deferred-scope decisions

Bring forward the existing Task C Slice 14 responsibility/write-cost item; do not
open a second optimisation entry. Cover all eight metrics and the alternate healed
entry point together so one remaining writer cannot undermine the reduction.
Reuse the parent input contract. Avoid a generic dynamic-SQL framework or broad
MERGE/index rewrite without measured need.

UPDATE_ALL2 decomposition, IMPORT_STAGING_PROC_CORE decomposition and residual
stats_module.py orchestration extraction remain their existing separate backlog
items. This investigation does not require new bot timing instrumentation, so
those refactors are not prerequisites. The deterministic name correction remains
a separate qualified change, with its signing/source-pin release gate still open.
Production incident recovery and whole-flow provider acceptance remain separate.

## Qualification and security decision

1. Freeze exact source bodies and a baseline/candidate fixture before editing.
   Add native SQL parity tests for all metrics, parent and direct entry points,
   including HEALEDSUMMARY_PROC_OPT. Compare unchanged governors and all output
   columns, not just totals or row counts.
2. Cover first import, subsequent import, no-new-scan return, one history row,
   missing/NULL values, decreasing metrics, historical corrections when selected
   by the existing affected-governor contract, name/rank changes, absent window
   rows, exact cutoff boundaries, and top-50/100/150 aggregate behavior. Preserve
   current no-new-scan and correction-selection semantics; expanding those would
   be a separate behavioral decision.
3. Examine duplicate ScanOrder input. Do not silently add a new winner rule to
   nondeterministic ordering or conceal the existing duplicate-latest failure.
   Use deterministic fixture clocks for cutoff comparisons; retain the production
   per-child time semantics. Verify result types, arithmetic and null propagation.
4. Inject a failure partway through the parent and prove rollback of outputs and
   watermarks; verify successful commit and no duplicate mutation on a no-op call.
   Qualify forward migration, wrong-target/source-drift rejection and rollback,
   including the stale-intermediate-cache restoration case.
5. After local parity passes, prepare fresh uniquely owned VM comparison runs.
   Keep original failed evidence immutable. Use the same backup/input and the
   deterministic name fix in both arms so it cannot confound the summary comparison.
   Require all 14 output contracts to match; record expected name-fix differences
   from the historical baseline separately, never rewrite the old captures.
6. Then run the already-declared warmup and balanced five measured pairs, stage
   median gates, actual candidate observers and 30-second held-reader case. Keep
   the 512 MiB version-store ceiling, existing log/timing limits and 8 GiB disk
   reserve. Record summary duration, CPU/reads, writes/log bytes, tempdb allocation,
   version-store peak and cleanup. The host RAM requirement remains the approved
   8 GiB. No thresholds are relaxed by this proposal.
7. Reconcile known consumers and release signing/source pins before production
   consideration. Publish a reviewed SQL migration and rollback package; production
   deployment remains a separate decision after evidence, not part of this approval.

Current changes are proposal/evidence documentation plus private offline analysis;
no new runtime or SQL workload code is changed. A formal security scan is skipped
for this documentation-only update. The future SQL implementation requires a
separate immutable Changes review, Deep off, against its exact Git diff; the earlier
name-fix scan cannot cover it. Review execute-as/signatures, grants, transaction and
failure behavior without weakening historical source pins. Bot and SQL review
targets remain separate if bot runtime scope later changes.

For this proposal run architecture/deferred/security-routing documentation gates
and whitespace/link checks. No bot runtime pytest run is needed for prose-only
changes. Existing cost-analysis tests and offline receipt assertions verify the
evidence arithmetic; they are not proof that the proposed SQL rewrite is correct.

## Decision requested

Approve the bounded summary rewrite above for local implementation and disposable
qualification, including the alternate healed path and explicit cache-contract/
rollback handling. Proceed to a concrete reviewed VM rehearsal package after those
checks. Stop for a design decision if a required consumer cannot be supported
without retaining the large cache writes. No new collector command is required
to make this proposal reviewable.
