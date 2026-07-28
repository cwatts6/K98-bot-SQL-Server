# KingdomScanData4 Phase 4 — views and view consumers

Status: ready to start from the frozen Phase 3 package on
`codex/kingdomscandata4-phase3`. Phase 3 SQL contracts, migration, rollback and representative
rehearsal are stable. Production execution is not authorized.

## Objective

Align every direct and transitive view with the Phase 2/3 types, remove only obsolete conversion
compensation, and prove that all consumer-facing values and metadata remain unchanged.

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

- Remove casts/conversions used only to compensate for the old base types.
- Retain trimming that implements blank-to-null, display, key or target-width semantics.
- Preserve date boundaries, null behavior, aggregation/window semantics, aliases and output types.
- Ensure type alignment does not merely move an implicit conversion to the other join operand.
- Do not change view ordering assumptions without updating and approving every consumer contract.

### 4.3 Package and rollback

- Author ordered Phase 4 migrations after
  `20260726_001_phase3_import_concurrency_and_direct_type_alignment`.
- Update the canonical `sql_schema` view definitions.
- Provide exact prior definitions for early rollback.
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
