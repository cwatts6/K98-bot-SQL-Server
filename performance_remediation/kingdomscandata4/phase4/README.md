# KingdomScanData4 Phase 4 — views and view consumers

Status: closed on 2026-07-27 on `codex/kingdomscandata4-phase4`, based on the
frozen Phase 3 commit `62cb739`. The isolated forward/rollback/reapply,
equivalence, benchmark, actual-plan, mapped consumer, repository, and final SQL
Changes gates passed. Production execution is not authorized.

## Objective

Align every retained direct and transitive view with the Phase 2/3 types,
remove only obsolete conversion compensation, retire the separately approved
invalid/unused weekly-cumulative view, and prove that all retained
consumer-facing values and metadata remain unchanged.

## Work packages

### 4.1 Lock the view and consumer inventory

Start from the final Phase 3 definitions, `phase1/closure_matrix.md`,
`phase1/bot_dal_contract_map.md`, and the frozen Phase 3 affected-module contract. Rediscover
direct/transitive dependencies before editing. The mandatory 13-view set is:

1. `dbo.v_Active_Players`
2. `dbo.v_GovernorNames`
3. `dbo.v_KVK_Under50_Last3_WithLatest`
4. `dbo.v_MGE_SignupReview`
5. `dbo.v_PlayerLatestStats`
6. `dbo.vDaily_Helps`
7. `dbo.vDaily_PlayerExport`
8. `dbo.vDaily_RSSAssisted`
9. `dbo.vDaily_RSSGathered`
10. `dbo.vWTD_Helps`
11. `dbo.vWTD_RSSAssisted`
12. `dbo.vWTD_RSSGathered`
13. `dbo.vw_Governor_KVK_Summary_GlobalLatest`

The worklist also includes every SQL function, procedure, dependent view, export, report and bot
DAL consumer found transitively. New discoveries must be classified before implementation rather
than silently added or ignored.

Record exact baseline parameters, rows, normalized digests, result metadata and ordering
assumptions before each definition changes.

### 4.2 Apply contract-preserving cleanup

- Retire `dbo.vAllianceActivity_WeeklyCumulative` only after repository, bot,
  and SQL Server dependency evidence proves no executable consumer.
- Remove casts/conversions used only to compensate for the old base types.
- Retain the two result-side `GovernorID` casts whose removal changes the
  established nullable result metadata; remove obsolete join-side compensation
  without moving an implicit conversion to the opposite operand.
- Retain trimming that implements blank-to-null, display, key or target-width semantics.
- Preserve date boundaries, null behavior, aggregation/window semantics, aliases and output types.
- Ensure type alignment does not merely move an implicit conversion to the other join operand.
- Do not change view ordering assumptions without updating and approving every consumer contract.

### 4.3 Package and rollback

- Author ordered Phase 4 migrations after
  `20260726_001_phase3_import_concurrency_and_direct_type_alignment`.
- Run the guarded obsolete-view retirement migration before the alignment
  migration.
- Update the canonical `sql_schema` view definitions.
- Provide exact prior definitions for early rollback.
- Treat the approved invalid-view retirement as forward-fix-only. Do not
  recreate a known-invalid object during rollback.
- Restore Phase 4 views first, then Phase 3 routines, then Phase 2 tables when the combined
  pre-restart rollback branch is selected.

### 4.4 Required delivery artifacts

Create and retain under this directory:

- `view_consumer_inventory.md`
- `baseline_contracts.md`
- ordered forward and rollback SQL under the repository migration paths
- `01_preflight.sql` and `02_verify.sql`
- `Test-Phase4Contracts.ps1`
- `rehearsal_report.md`

The exact filenames may be extended when split-session or other focused proof requires it, but
the inventory, baseline, forward, rollback, verification, repository contract test and rehearsal
receipt are mandatory.

Current package:

- `migrations/20260727_000_retire_vAllianceActivity_WeeklyCumulative.sql`;
- `migrations/20260727_001_phase4_view_type_alignment.sql`;
- `migrations/rollback/20260727_001_phase4_view_type_alignment_rollback.sql`;
- `view_consumer_inventory.md` and `baseline_contracts.md`;
- `01_preflight.sql` and `02_verify.sql`;
- `03_run_view_benchmarks.sql` and `04_capture_plan_evidence.sql`; and
- `Test-Phase4Contracts.ps1`.

One invalid unused definition is retired. Four retained definitions change:
`dbo.v_Active_Players`,
`dbo.v_MGE_SignupReview`, `dbo.vDaily_PlayerExport`, and
`dbo.vw_Governor_KVK_Summary_GlobalLatest`. The other nine mandatory
definitions remain validation-only. Forward and rollback both hold the
migration/import mutexes, materialize every changed result, compare row counts
and bidirectional `EXCEPT`, compare exact result metadata, and refresh the
complete transitive SQL consumer set before commit. Every forward, rollback,
preflight and verification refresh path refuses signed modules before calling
`sys.sp_refreshsqlmodule`; signature preservation or re-signing requires a
separate explicit review.

The retirement migration refuses definition drift, SQL module dependencies,
explicit grants, signatures, and extended properties. The alignment migration
refuses to start until the retired object is absent.

The isolated rehearsal established that the result-side casts on
`dbo.v_Active_Players.GovernorID` and
`dbo.vw_Governor_KVK_Summary_GlobalLatest.GovernorId` preserve the existing
nullable metadata contract. They remain by design. The obsolete MGE and
global-latest join-side compensation and the redundant daily-export numeric
casts are removed.

## Required validation

- Bidirectional `EXCEPT`/digest reconciliation for representative governors, dates, latest scans,
  empty periods and large ranges.
- Exact aggregate totals, deltas, nulls, aliases, types and column order.
- One warm-up plus five measured executions for the assigned baselines.
- Complete materialization of latest, daily, WTD, global-latest and export views.
- Consumer smokes from `phase1/bot_dal_contract_map.md`.
- Refresh/compile all dependent modules and capture plans, reads, CPU, duration, grants, spills and
  warnings.
- Flag any regression around or above 10 percent and resolve or justify it under the task-wide
  regression policy.
- Run repository validation, `git diff --check` and a SQL Changes security review for the final
  Phase 4 diff.
- Keep the scan type `Changes`, Deep scan off, and review only the Phase 4 Git diff plus directly
  supporting code. Do not broaden to a codebase or Deep scan without explicit authorization.

## Rehearsal and scope boundary

- Rehearse on a fresh isolated database carrying the accepted Phase 2 and frozen Phase 3
  definitions. Production remains untouched.
- The two final Phase 3 Low/P3 mutable-file findings are not Phase 4 view work. Preserve them as
  Phase 5/combined-release blockers and do not mix their cross-repository remediation into this
  phase.
- Continue refining migration IDs, stop/start controls, receipts, rollback commands and operator
  checkpoints in `../release/README.md`, but do not authorize deployment.

## Exit gate

Phase 4 closes only when every changed view and transitive consumer is value- and
metadata-equivalent, the required workloads are stable, rollback definitions are rehearsed and the
closure matrix contains exact receipts.

Closed: all conditions passed. Final SQL Changes scan
`e6ce0a1d-7aba-428a-b40a-61001c924143` reviewed
`codex-security-snapshot/v1:sha256:a00ac727cab59a0ed585b7e6f615a3391fc792d95a1165c624c0328e978a909b`
with Deep off, 13/13 completed source-like worklist rows, no deferrals, and no
reportable findings. The only post-scan edits are non-executable status and
receipt documentation.
