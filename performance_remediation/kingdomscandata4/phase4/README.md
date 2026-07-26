# KingdomScanData4 Phase 4 — views and view consumers

Status: planned; starts only after Phase 3 SQL contracts and rollback definitions are stable.
Production execution is not authorized.

## Objective

Align every direct and transitive view with the Phase 2/3 types, remove only obsolete conversion
compensation, and prove that all consumer-facing values and metadata remain unchanged.

## Work packages

### 4.1 Lock the view and consumer inventory

Start from `phase1/closure_matrix.md` and rediscover direct/transitive dependencies after Phase 3.
The mandatory set includes:

- `dbo.v_Active_Players`, `dbo.v_GovernorNames`,
  `dbo.v_KVK_Under50_Last3_WithLatest`, `dbo.v_MGE_SignupReview` and
  `dbo.v_PlayerLatestStats`;
- every related `dbo.vDaily_*` and `dbo.vWTD_*` view;
- `dbo.vw_Governor_KVK_Summary_GlobalLatest`; and
- every SQL, export, report and DAL consumer found transitively.

Record exact baseline parameters, rows, normalized digests, result metadata and ordering
assumptions before each definition changes.

### 4.2 Apply contract-preserving cleanup

- Remove casts/conversions used only to compensate for the old base types.
- Retain trimming that implements blank-to-null, display, key or target-width semantics.
- Preserve date boundaries, null behavior, aggregation/window semantics, aliases and output types.
- Ensure type alignment does not merely move an implicit conversion to the other join operand.
- Do not change view ordering assumptions without updating and approving every consumer contract.

### 4.3 Package and rollback

- Author ordered Phase 4 migrations after the Phase 3 migrations.
- Update the canonical `sql_schema` view definitions.
- Provide exact prior definitions for early rollback.
- Restore Phase 4 views first, then Phase 3 routines, then Phase 2 tables when the combined
  pre-restart rollback branch is selected.

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

## Exit gate

Phase 4 closes only when every changed view and transitive consumer is value- and
metadata-equivalent, the required workloads are stable, rollback definitions are rehearsed and the
closure matrix contains exact receipts.
