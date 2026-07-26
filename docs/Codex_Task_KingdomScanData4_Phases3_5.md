# KingdomScanData4 Phases 3–5 delivery plan

Status updated 2026-07-26. Phase 1 is closed. Phase 2 is closed on the representative-copy
evidence boundary; production execution is not authorized. This plan replaces task-list ordering
that mixed Phase 2 acceptance with later coordinated-release work.

## Authoritative order

| Order | Workstream | Entry condition | Exit condition |
| ---: | --- | --- | --- |
| 1 | Phase 3: procedures, import concurrency and downstream tables | Phase 2 package and rollback are stable | SQL mutex, atomic scan allocation, duplicate prevention, type alignment, equivalence, performance and rollback all pass |
| 2 | Phase 4: views and consumers | Phase 3 SQL contracts are stable | Every changed view and transitive consumer is value- and metadata-equivalent and rollback passes |
| 3 | Phase 5: bot and DAL alignment | Final Phase 3/4 SQL contracts are available | Four approved bot paths and all source-unchanged smokes pass in the separate bot repository |
| 4 | Combined release gate | Phases 2–5 are closed with exact commits | Fresh-restore coordinated forward, rollback, finalizer, workload and end-to-end bot rehearsal pass |
| 5 | Production go/no-go | Reviewed SQL and bot PRs plus combined receipts exist | Operator gives separate explicit execution approval after fresh production preflight |

The combined release gate is not Phase 6. It packages and proves the already approved
implementation phases. Phase 2 retained originals must remain available until this gate accepts
the exact Phase 3/4 definitions and commits.

## Phase 3 delivery slices

1. Freeze the complete affected-module and downstream-table manifest from the closure matrix,
   Query Store map and bot/DAL contract map.
2. Approve one database application-lock resource, ownership scope, timeout, transaction boundary,
   scan-allocation statement and duplicate key.
3. Implement the mutex, atomic allocation and duplicate prevention across every authoritative
   import entry point, including direct SQL paths that bypass the bot lock.
4. Align stored procedures, functions, staging contracts and downstream tables to the Phase 2
   types. Retain conversion at genuinely untrusted or error-checking boundaries.
5. Rehearse forward and rollback definitions on a fresh representative copy.
6. Repeat the complete `UPDATE_ALL2` functional/concurrency/committed-import suite and every
   assigned summary, metadata, leadership and Query Store workload.
7. Close Phase 3 only after exact result metadata, bidirectional values, plans, resource metrics,
   module compilation, repository validation and a SQL Changes security review pass.

## Phase 4 delivery slices

1. Rediscover every direct and transitive view dependency after Phase 3.
2. Record old definitions, result metadata, rows, digests, parameters and ordering assumptions.
3. Remove only obsolete type compensation; preserve deliberate trimming, date, null, aggregate,
   display and overflow semantics.
4. Rehearse ordered forward and rollback view definitions.
5. Rerun latest, daily, WTD, global-latest, export and mapped consumer scenarios with one warm-up
   and five measured executions.
6. Close Phase 4 only after bidirectional value/metadata equivalence, refreshed dependencies,
   stable performance, repository validation and a SQL Changes security review pass.

## Phase 5 delivery slices

Work in `C:\discord_file_downloader` on its own branch and PR.

1. Change `player_self_service/accounts_dal.py`.
2. Change `player_self_service/governor_dashboard_dal.py`.
3. Change `weekly_activity_importer.py`.
4. Move touched SQL from `embed_offseason_stats.py` to a stats-alert DAL and update the caller.
5. Preserve all locked result, order, null, trim, date, civilization, fallback and display
   contracts.
6. Run focused tests for each changed path plus the four source-unchanged contract smokes.
7. Run the bot repository's architecture, deferred-item, test-selection, smoke-import,
   command-registration, security-routing, pre-commit and full pytest gates.
8. Close Phase 5 only after a separate bot Changes security review passes against the exact
   commit selected for the combined rehearsal.

## Task-wide controls

- Reuse the Phase 1 scenarios, parameters, fixtures, row counts and digests after every material
  change.
- Flag any regression around or above 10 percent in median duration, CPU, reads or import
  throughput. Resolve it or retain evidence that a necessary correctness/safety gain outweighs it.
- Keep `IMPORT_STAGING_CSV_RAW` wide and keep typed ingestion widths at
  `nvarchar(200/100/100/200)`.
- Keep all ten KS4 indexes and the existing persisted `AsOfDate`.
- Never use a snapshot as the production rollback mechanism.
- Never discard operator-held raw evidence or expose it in Git.
- Keep production stopped from this workflow until the separate go/no-go checkpoint.

## Detailed contracts

- Phase 3: `performance_remediation/kingdomscandata4/phase3/README.md`
- Phase 4: `performance_remediation/kingdomscandata4/phase4/README.md`
- Phase 5: `performance_remediation/kingdomscandata4/phase5/README.md`
- Combined release: `performance_remediation/kingdomscandata4/release/README.md`
- SQL promotion controls: `docs/SQL_DATA_MIGRATION_GUARDRAILS.md`,
  `docs/SQL_PROMOTION_GUIDE.md`, `docs/SQL_RELEASE_CHECKLIST.md` and
  `docs/SQL_DELIVERY_LOG.md`
