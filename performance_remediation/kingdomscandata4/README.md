# KingdomScanData4 performance remediation

This folder contains the evidence and scripts for the five-phase remediation defined in
`docs/Codex_Task_KingdomScanData4_Performance_Remediation.md`.

Phase 1 collectors are read-only. The `phase2` package and matching migration/rollback scripts are
representative-copy validated but are not authorized for production execution. Phases 3 through 5
are separate implementation stages; the combined rehearsal and production decision are release
gates after Phase 5, not part of Phase 2.

## Current phase

Phase 1 and all five formal gate items are complete. The approved Phase 2 shadow-copy package
passed five representative-copy forward rehearsals, three production-usable metadata-swap
rollbacks, separately named backup/restore recovery, the controlled after-workload suite, an
expected post-verification drift refusal and a clean irreversible finalization rehearsal. The
final workload forward completed in 73,287.038 ms; `SUMMARY_PROC` improved to a 167,154.476 ms
five-run median with exact result stability. Early rollback also resets the exact deployment
history row to the retryable `Pending` state; its transaction and cleanup passed on the
representative recovery copy. The complete 61-file delivery diff then passed its final Changes
security review with zero reportable findings. Phase 2 is closed. Production execution remains
separately gated.

## Authoritative phase order

1. **Phase 1 — evidence and approval:** complete and closed.
2. **Phase 2 — physical table migration:** complete after the self-contained forward,
   verification, early-rollback, finalization, recovery, performance and delivery-history
   retryability gates pass.
3. **Phase 3 — procedures, import concurrency and downstream tables:** implement the database
   mutex, atomic scan allocation, duplicate prevention and type-aligned procedure contracts.
4. **Phase 4 — views and view consumers:** remove only obsolete conversion compensation and prove
   bidirectional result/metadata equivalence.
5. **Phase 5 — bot and DAL alignment:** implement the four approved bot paths in the separate bot
   repository and prove all changed and source-unchanged consumer contracts.
6. **Combined release gate:** rehearse the exact SQL and bot commits from a fresh restore, complete
   separate diff-focused security reviews, merge through the documented PR paths, and request
   explicit production execution approval.

The implementation contracts for the remaining phases are in `phase3/README.md`,
`phase4/README.md`, `phase5/README.md`, and `release/README.md`.

## Run order

Run the following against a representative restored copy first. If the production database must
be used for evidence collection, run during an approved low-activity window and retain the output.

1. `phase1/01_collect_environment_and_dependencies.sql`
2. `phase1/02_validate_candidate_conversions.sql`
3. `phase1/03_collect_query_store_baseline.sql`
4. Complete `phase1/benchmark_manifest.md` with representative parameters before executing
   procedures or import workflows.
5. Run `phase1/05_collect_sql_agent_and_serialization.sql` against production `ROK_TRACKER` and
   retain its `.rpt` outside Git.
6. Run `phase1/Collect-ExternalSerializationEvidence.ps1` on the bot host and retain its JSON
   output outside Git.

If the targeted SQL Agent collector reports more visible jobs than emitted relevant jobs, run
`phase1/06_collect_sql_agent_full_job_inventory.sql` as a small read-only supplement.

Run `phase1/07_collect_query_store_owner_parameter_map.sql` in the database whose Query Store
contains the retained `query_id`/`plan_id` pairs. Save the complete results as
`query_store_owner_parameter_map.rpt` outside Git and retain its SHA-256. The collector is
read-only and fails if any required pair is absent.

The scripts intentionally do not clear caches, update statistics, rebuild indexes, execute
procedures, or mutate data.

## Evidence status

- Repository-side discovery: started 2026-07-23.
- Live database collection: completed by the operator on 2026-07-23; sanitized metrics are
  recorded in `phase1/audit_report.md` and `phase1/benchmark_manifest.md`.
- Referenced `KingdomScanData4_Analysis_Report.md`: received and reconciled against live evidence.
- Bot repository: `C:\discord_file_downloader` found and inspected read-only.
- Representative restored database: available as `ROK_TRACKER_BACKUP_TEST_KS4`; restore completed,
  `DBCC CHECKDB` passed, and `KingdomScanData4` row presence was confirmed by the operator.
- Controlled baselines: full-history summary evidence and the normal v2 suite were captured on
  2026-07-23 with stable digests across five measured executions.
- `UPDATE_ALL2` functional rehearsal: normal, boundary/Unicode/optional-blank, invalid,
  corrected-retry, controlled Phase-B failure and simultaneous concurrency scenarios completed
  on 2026-07-24. The same-state one-warm-up/five-measured committed benchmark also completed with
  one stable material digest and a 195,362.014 ms measured median.
- Backup/storage readiness: backup posture, volume/file/log/tempdb capacity, successful restore,
  `DBCC CHECKDB`, row presence, snapshot reset and isolated test-path evidence collected.
- SQL Agent/external serialization: all five Agent jobs and captured external tasks exclude the
  import; the normal bot upload path serializes in-process, while `/run_sql_proc` and direct SQL
  can bypass that lock. Phase 3 therefore retains the database-mutex requirement.
- Query Store owner/parameter map: 12/12 shortlisted query/plan pairs matched their SQL or ad hoc
  owners; representative procedure scenarios, five compiled accounts-DAL IDs and exact after
  baselines are retained.
- Bot/DAL result contracts: all eight paths named in the closure matrix now map to their
  transitive owner, SQL parameter and result contract, null/order assumptions, exact smoke
  scenario and bot-change decision in `phase1/bot_dal_contract_map.md`. The operator selected
  contract-preserving conversion cleanup in four bot paths; the other four remain source-unchanged
  with mandatory smokes.
- Migration preflight: the fresh-seed benchmark copy passed source-shape, full KS4/KS5 numeric
  conversion, string-width, dependency, permission and capacity checks. The guarded shadow-copy
  forward passed in 45,779.868 ms with exact normalized digests, all ten KS4 indexes,
  permission/module/DBCC verification and production-usable originals retained. The metadata-swap
  rollback passed in 34,255.475 ms, restoring the original schema and exact digests without a
  snapshot.
- Phase 2 implementation/rehearsal: three corrected workload/recovery forward runs completed in
  73,112.792-74,543.351 ms, two earlier rollbacks in 30,656.546-33,727.390 ms, and the verified
  preflight backup restored to the separately named recovery database without `WITH REPLACE`.
  A finalizer-focused forward passed in 56,854.713 ms, deliberate post-verification drift was
  refused before any retained-table drop, and a third metadata-swap rollback passed in
  25,047.184 ms. A separate clean forward passed in 59,471.943 ms and finalization completed
  after a 22,275.645 ms six-table digest guard. All exact schema, row, digest, index, statistic,
  permission, module, critical-read and DBCC checks passed.
- Phase 2 workloads: all 21 enabled workload/scenario pairs completed five stable measured runs.
  The apparent full-suite export slowdown was invalidated by an immediate isolated rerun:
  `vDaily_PlayerExport` passed at 603.284 ms median for 223,386 rows with one exact digest.
- Index decision: all ten KS4 indexes are retained unchanged. No exact duplicates were found;
  overlapping definitions have different physical/include contracts, and the expected benefit of
  a consolidation experiment does not justify its risk and test cost for this remediation.
- Final SQL Changes security review: completed against the 61-file staged delivery snapshot
  `codex-security-snapshot/v1:sha256:51fdbddd810d4b4b8b01926fb27c51b3179f8af13e0b29dee1573424aa83707a`.
  All 61 worklist receipts closed with zero reportable findings. The recovery-backup identity
  candidate was rejected after validation and attack-path analysis because exploitation requires
  protected SQL-host or database write access and can affect only the fixed, separately named
  non-production rehearsal target. Effective production grants and the SQL-host backup-folder ACL
  remain explicit production preflights because they are not represented in Git.
- Raw `.rpt` outputs and `kingdomscandata4_sample.csv` are operator-held local evidence. They
  contain player-identifying values and an operator login and must not be committed without
  anonymisation/redaction.

See `phase1/audit_report.md`, `phase1/benchmark_manifest.md`, `phase1/closure_matrix.md`,
`phase1/bot_dal_contract_map.md`, and `phase2/rehearsal_report.md` for the retained evidence.
The approved plan and receipt are in `phase1/phase2_approval_checkpoint.md`. Production execution
remains separately gated.

## SQL Agent and external serialization collection

The SQL collector returns relevant job ownership, every job step, enabled and disabled schedules,
next/last execution details, 90-day outcomes/failures, current activity and historical overlaps.
Run it in an SSMS connection to production `ROK_TRACKER` and save the results as
`sql_agent_and_serialization.rpt`.

On the bot host, run:

```powershell
.\performance_remediation\kingdomscandata4\phase1\Collect-ExternalSerializationEvidence.ps1 `
  -BotRoot 'C:\discord_file_downloader' |
  Set-Content -Encoding utf8 `
    'C:\Users\cwatt\Downloads\external_serialization_evidence.json'

Get-FileHash -Algorithm SHA256 `
  'C:\Users\cwatt\Downloads\external_serialization_evidence.json'
```

The raw SQL Agent report and external JSON can contain command lines, accounts, paths and source
excerpts. Keep both outside Git and provide them for review through the operator evidence channel.
