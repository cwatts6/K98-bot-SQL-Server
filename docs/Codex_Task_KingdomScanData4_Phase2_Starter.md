# KingdomScanData4 Phase 2 starter

## Purpose

Use this file to start the next Codex chat for the `KingdomScanData4` remediation. Phase 1 and all
five formal gate items are complete. The evidence-backed Phase 2 plan is retained in
`performance_remediation/kingdomscandata4/phase1/phase2_approval_checkpoint.md`. The operator
approved implementation and representative-copy rehearsal on 2026-07-25. Production execution
remains separately gated.

## Copy/paste starter prompt

```text
Continue the KingdomScanData4 performance remediation in
C:\K98-bot-SQL-Server on branch codex/kingdomscandata4-remediation.

Read these files first and treat them as authoritative:
- docs/Codex_Task_KingdomScanData4_Performance_Remediation.md
- performance_remediation/kingdomscandata4/README.md
- performance_remediation/kingdomscandata4/phase1/audit_report.md
- performance_remediation/kingdomscandata4/phase1/benchmark_manifest.md
- performance_remediation/kingdomscandata4/phase1/closure_matrix.md
- performance_remediation/kingdomscandata4/phase1/phase2_approval_checkpoint.md
- performance_remediation/kingdomscandata4/phase1/update_all2_rehearsal/README.md
- docs/Codex_Task_KingdomScanData4_Phase2_Starter.md

Preserve the existing dirty worktree and operator-held raw evidence. All five Phase 1 gate items
are complete and recorded in the audit report, benchmark manifest and closure matrix. The formal
Phase 1 gate is closed. The operator approved the exact Phase 2 implementation and
representative-copy rehearsal plan on 2026-07-25; production execution remains separately gated.

Implement the approved plan evidence-first. Author the drift-guarded Phase 2 package, validate it,
and rehearse forward and rollback paths on the representative copy. Do not execute against
production, drop the retained pristine snapshot, or discard operator-held raw evidence.
```

## Current target and retained test environment

| Item | Value |
| --- | --- |
| Production target | `ROK_TRACKER.dbo.KingdomScanData4` |
| Representative restored copy | `ROK_TRACKER_BACKUP_TEST_KS4` |
| Guarded pristine snapshot | `ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE` |
| Isolated import root | `C:\discord_file_downloader\downloads_test` |
| Baseline rows / scans | KS4 394,506 rows; KS5 394,526 rows; scan 1–1020 |
| Table size | Approximately 2.4 GB used |
| Volume capacity | 474.99 GB total / 243.57 GB free |
| Production log | 64 GB, 0.08% used at capture, 4 GB fixed growth |
| Functional-test log | 16 GB size / 4 GB growth / 32 GB maximum |
| App outage constraint | Application is non-critical; process may determine the outage |
| Rollback constraint | Process may determine rollback duration; backups and off-site copy exist |

The snapshot was retained throughout the completed forward/rollback migration rehearsal. Drop it
only with the guarded cleanup script after the operator confirms the retained reports and approval
checkpoint are sufficient.

## Locked Phase 1 decisions

1. Current numeric data is conversion-safe: no fractional, failed, out-of-range or
   `GovernorID` collision rows were found in the 394,506-row data set.
2. Preserve `IMPORT_STAGING_CSV_RAW` as the wide text/error-capture boundary.
3. Preserve the typed ingestion widths:
   - name: `nvarchar(200)`
   - alliance: `nvarchar(100)`
   - civilization: `nvarchar(100)`
   - `updated_on`: `nvarchar(200)`
4. Do not implement the external report's narrower name/alliance 100/50 proposal.
5. `AsOfDate` is already persisted in the authoritative schema; do not recreate it without new
   evidence.
6. Retain all ten KS4 indexes unchanged. The operator closed index consolidation out of this
   remediation after evidence found no exact duplicates and only modest expected benefit from
   overlapping-index removal.
7. Query Store `query_id=143117`, `plan_id=16603` maps to
   `dbo.usp_UpsertGovernorNameHistoryForScan`.
8. `UPDATE_ALL2` functional behavior passed, but the procedures contain no explicit import mutex.
   Phase 3 must make scan allocation and duplicate prevention explicit rather than relying on the
   observed file/staging-lock interleaving.
9. The coordinated release includes contract-preserving SQL cleanup in
   `embed_offseason_stats.py`, `weekly_activity_importer.py`,
   `player_self_service/accounts_dal.py` and
   `player_self_service/governor_dashboard_dal.py`. Preserve trims used for blank/display
   semantics and conversions at raw, date, civilization and unchanged float/text boundaries.
   Treat the bot and SQL repositories as separate test/security-review targets.

## Completed before evidence

- `SUMMARY_PROC`: five-run median 267,946.951 ms; stable 2,374-row digest.
- Selected summary components: approximately 20.4–36.3 seconds median.
- `Refresh_PlayerScanMeta`: full 301.643 ms, incremental 411.817 ms, no-op 48.275 ms median.
- `v_PlayerLatestStats`: 64.258 ms median.
- `vDaily_PlayerExport`: 729.391 ms median for 223,386 materialized rows.
- Global-latest view: 10.015 ms median for 411 rows.
- Leadership lookup directory: 987.686 ms median for 1,639 rows.
- Functional `UPDATE_ALL2`: normal, boundary/Unicode/optional blanks, invalid, corrected retry,
  controlled Phase-B failure and simultaneous concurrency all passed their expected outcomes.

Reuse the exact scenarios, parameters, row counts and digests after each material change.

## Completed Phase 1 gate closure

All five items below are complete. The comparable import, scheduler/serialization, Query Store
and bot/DAL evidence is recorded in the Phase 1 reports. The shadow-copy forward passed in
45,779.868 ms and its production-usable metadata-swap rollback passed in 34,255.475 ms against the
same run ID with exact digests and no snapshot.

Complete these in order before Phase 2 DDL:

### 1. Comparable committed-import benchmark

- Run `UPDATE_ALL2` ordinal 0 plus measured ordinals 1–5.
- Restore the same backup before each ordinal.
- Apply only the isolated test-path override; do not create/retain a database snapshot.
- Use the same representative fixture and capture duration, CPU, reads, writes, log/tempdb deltas,
  rows/second, blocking/deadlocks and exact final rows/scans.
- Preserve each `.rpt` and filesystem hash under unique run labels.

### 2. SQL Agent and external serialization evidence

Collect:

- relevant job definitions and every step;
- enabled schedules and next/last run details;
- recent success/failure/duration history;
- job ownership and overlap with import/download tasks;
- any Windows Task Scheduler, bot singleton, filesystem lock or other external serialization.

Resolve whether `UPDATE_ALL2` has one authoritative scheduler and whether two invocations can
overlap outside the controlled test.

### 3. Remaining Query Store owner/parameter map

Map every shortlisted query/plan to:

- owning procedure/view/ad hoc caller;
- representative parameter or scan/date/governor scenario;
- baseline entry that will be rerun after the related phase.

Retain 143117/16603 as the `usp_UpsertGovernorNameHistoryForScan` affected-alias aggregation.

### 4. Complete bot/DAL result-contract map

For every path listed in `closure_matrix.md`, record:

- Python caller and owning service/DAL;
- SQL object and parameter types;
- returned columns, types, nullability and ordering assumptions;
- import/read smoke scenario and expected output;
- whether a bot change is required when the SQL contract changes.

Read-only search is expected in `C:\discord_file_downloader`. Treat bot and SQL repositories as
separate Git/security-review targets.

### 5. Exact migration and rollback design

Compare direct `ALTER COLUMN` with shadow/copy using the actual dependency and workload evidence.
The selected design must specify:

1. drift/conversion/space preflight;
2. application/import shutdown and serialization;
3. dependency drop/alter order;
4. aligned upstream staging and `KingdomScanData5` compatibility;
5. `KingdomScanData4` type conversion;
6. deliberate index recreation/consolidation;
7. statistics and metadata refresh;
8. row/value/digest and module-compile verification;
9. rollback triggers and exact rollback/recovery steps;
10. measured outage, lock waits, log generation/growth, tempdb and disk use.

Run and time forward and rollback paths on the representative copy. A snapshot revert may support
iteration, but the final rollback test must exercise the documented production-usable recovery
path rather than treating a database snapshot as the production rollback mechanism.

## Phase 2 approval checkpoint

After the five gate items are closed, update all Phase 1 reports and present:

- direct-alter versus shadow-copy verdict with evidence;
- exact affected objects and dependency order;
- proposed final types and unchanged nullability;
- named retained/dropped/replacement indexes with workload justification;
- forward, verification and rollback script plan;
- measured outage/log/disk requirements;
- before/after test matrix;
- SQL Changes security-review target.

Completed 2026-07-25: the operator approved the exact checkpoint for implementation and
representative-copy rehearsal. Production execution remains separately gated.

## Phase 2 acceptance

Phase 2 is complete only after the approved migration package is repeatable and drift-guarded,
forward and rollback rehearsals pass, every row/material value reconciles, relevant baseline
workloads are rerun, no critical path has an unexplained regression, and the closure matrix is
updated without moving unresolved contract work out of the original five-phase task.
