# KingdomScanData4 performance remediation

This folder contains the evidence and scripts for the five-phase remediation defined in
`docs/Codex_Task_KingdomScanData4_Performance_Remediation.md`.

Phase 1 collectors are read-only. The `phase2`, `phase3`, and `phase4` packages and matching
migration/rollback scripts are representative-copy validated but are not authorized for
production execution. Phase 4 is closed. Phase 5.0 SQL is closed after its isolated
forward/protocol/rollback/reapply rehearsal, repository gates and zero-finding final Changes
review passed. Phase 5.1 bot/DAL implementation and the replacement real-token ACL evidence are
closed for Phase 5.2 entry review as of 2026-08-17. Phase 5.2 is the combined rehearsal/promotion
gate and remains distinct from production go/no-go; its rehearsal has not started.
The Phase 5.1 implementation task pack is
`docs/Codex_Task_KingdomScanData4_Phase5_1_Bot_DAL_Immutable_Handoff.md`.

## Current phase

Phase 1 and all five formal gate items are complete. The approved Phase 2 shadow-copy package
passed five representative-copy forward rehearsals, three production-usable metadata-swap
rollbacks, separately named backup/restore recovery, the controlled after-workload suite, an
expected post-verification drift refusal and a clean irreversible finalization rehearsal. The
final workload forward completed in 73,287.038 ms; `SUMMARY_PROC` improved to a 167,154.476 ms
five-run median with exact result stability. Early rollback also resets the exact deployment
history row to the retryable `Pending` state; its transaction and cleanup passed on the
representative recovery copy. The complete 61-file delivery diff then passed its final Changes
security review with zero reportable findings. Phase 2 is closed.

Phase 3 is also complete on `codex/kingdomscandata4-phase3`. Its fresh Phase 2-to-Phase 3
forward/rollback/forward rehearsal passed the import mutex, atomic allocation, duplicate receipt,
archive, direct/legacy entry-point, failure, mapped workload, module refresh and repository gates.
Final Changes scan `7ccf1007-269d-4470-94f0-638222312c5a` sealed with two Low/P3 findings that
share one Phase 5 immutable-file handoff remediation. Phase 4 is closed after its complete
isolated rehearsal, repository gates, and zero-finding final Changes review. Phase 5.0 SQL is
closed after the equivalent forward/protocol/rollback/reapply and final Changes gates passed.
Production execution remains separately gated.

## Authoritative phase order

1. **Phase 1 — evidence and approval:** complete and closed.
2. **Phase 2 — physical table migration:** complete after the self-contained forward,
   verification, early-rollback, finalization, recovery, performance and delivery-history
   retryability gates pass.
3. **Phase 3 — procedures, import concurrency and downstream tables:** complete; database mutex,
   atomic scan allocation, duplicate prevention and type-aligned procedure contracts are frozen.
4. **Phase 4 — views and view consumers:** complete; the approved invalid/unused view is
   retired, four retained views are contract-aligned, and bidirectional result/metadata
   equivalence is proven.
5. **Phase 5 — bot, DAL and immutable import-file handoff:** Phase 5.0 SQL is closed on its
   repository boundary; Phase 5.1 implementation and retained receipt-backed ACL proof are closed
   for Phase 5.2 entry review. Frozen PR state, exact scan coverage, and MINI_AMD return-to-main
   remain live Checkpoint A gates.
6. **Phase 5.2 combined release gate:** rehearse the exact SQL and bot commits from a fresh restore, complete
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
- Phase 3 implementation/rehearsal: the exact 52-module contract and ordered Phase 2-to-Phase 3
  forward/rollback/forward chain passed on
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`. Final Changes scan
  `7ccf1007-269d-4470-94f0-638222312c5a` reviewed snapshot
  `codex-security-snapshot/v1:sha256:98d3c2f01c061c4a3557b5d2f43d0080b47cab9c9863279c8162f3dbb9d653a8`
  and reported two Low/P3 mutable-file identity findings. The shared immutable-file remediation
  is assigned to Phase 5 and blocks the combined release, not Phase 4 entry.
- Phase 4 implementation/rehearsal: the guarded invalid/unused
  `dbo.vAllianceActivity_WeeklyCumulative` retirement and four retained view
  alignments passed isolated forward/rollback/reapply, exact value/metadata
  equivalence, all 13 one-warm-up/five-measured stable workloads, five
  actual-plan materializations, and 164 mapped bot/DAL tests on 2026-07-27.
  Exact grants, warnings, and the baseline daily-export level-1 hash spill are
  retained in `phase4/rehearsal_report.md`. Repository gates passed. Final SQL
  Changes scan `e6ce0a1d-7aba-428a-b40a-61001c924143` reviewed snapshot
  `codex-security-snapshot/v1:sha256:a00ac727cab59a0ed585b7e6f615a3391fc792d95a1165c624c0328e978a909b`
  with Deep off, 13/13 completed source-like rows, no deferrals, and zero
  reportable findings. Phase 4 is closed; production was untouched.
- Phase 5.0 SQL implementation/closure: the immutable claim table/procedure, fixed-root
  completed-name consumers, digest-bound import/archive state, stopped-writer migration/rollback,
  static contracts and protocol rehearsal assets passed offline validation and the full isolated
  forward/protocol/rollback/reapply run. Final Changes scan
  `099379cd-119b-4402-8ecb-cf2e1c105f40` closed 18/18 executable rows with zero reportable
  findings. At Phase 5.0 closure, real-token ACL evidence was assigned to Phase 5.1; production
  was untouched.
- Phase 5.1 bot/DAL and immutable-handoff closure: accepted run
  `phase5_1_20260817T155508137Z` passed on MINI_AMD against SQL commit
  `368292fe1f291ff20765f3ecb6702a119fb78a20`. Receipt SHA-256 is
  `C9319B9980AE270C0F7C8D2891012E538951D052D206114C9F9828851279EDCF`; transcript SHA-256 is
  `91A6C281230B441B1111417366D79D1A532B8296E10017BB38BE63B288236B4C`. All five bot-token
  claimed-file mutation attempts were denied, SQL completed the claim/import/archive path, and
  Ready/claim/archive digest
  `B4355635986F5BF365AEADD3E7DA91F5A0ED5D65D33A976A726FFB125100A724` matched. Stable findings
  `csf_1a1c440452b02cdb787fa7c3` and `csf_3cb54318733d3a216dd91e9b` therefore have
  receipt-backed closure evidence. Bot PR #232 and production PR #539 remain open and frozen;
  production is untouched.
- Phase 5.2 Checkpoint A bot correction: mirror PR #232 is now frozen at
  `f95ead9d348bdf45726fb9ce1e73f6ed2a20483a`. Exact contiguous Changes scans
  `c6761a00-3670-48f5-965f-43fe3228e675`, `02d8e353-4eec-40e9-bafa-4fd4c53ac860`, and
  `0ecf75bf-359c-4503-a6c8-3fcbed84c98e` cover the base through that head. The middle scan found
  archive hard-link finding `csf_38e8134cbe97537f0652c431`; the final commit and zero-finding
  closure scan reject that indirection. Full pytest passed `2823 passed, 2 skipped`.
  Patch-based production PR #539 head `53eaeb66b99538778ad7cd95a974dcd0bc8ccd55` is based on
  production `main` `caabd2c7dc77aec67f2748a1b9b66fdf53a4aa02`, is content-equivalent across
  all 29 promoted files, and has passing quality and scan checks.
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
