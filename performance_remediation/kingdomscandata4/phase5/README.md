# KingdomScanData4 Phase 5 — bot, DAL and immutable file handoff

Status updated 2026-07-28. Phase 4 is merged at `74bd8b1`. Phase 5.0 is closed on the SQL
repository boundary: the package passes offline contract/repository gates, the pinned isolated
rehearsal completed forward migration, protocol smokes, exact rollback, clean reapply and final
verification, and final Changes scan `099379cd-119b-4402-8ecb-cf2e1c105f40` has zero reportable
findings. The real-token claimed-directory ACL proof remains assigned to Phase 5.1. Nothing in
this package has been deployed to production.
Phase 5.1 bot/DAL implementation belongs to the separate repository at
`C:\discord_file_downloader`.
The implementation-ready Phase 5.1 task pack is
`docs/Codex_Task_KingdomScanData4_Phase5_1_Bot_DAL_Immutable_Handoff.md`.

## Delivery slices

The operator-facing `5.0`, `5.1`, and `5.2` labels are slices inside the existing five-phase plan;
they do not create Phase 6:

1. **Phase 5.0 — SQL companion:** immutable claim ledger, exact completed-name claim, digest-bound
   import/receipt/archive, migration/rollback, and representative SQL rehearsal.
2. **Phase 5.1 — bot and DAL:** atomic unique-name publication, Ready/Claimed/Archive ACL
   enforcement, four approved DAL cleanups, unchanged-path smokes, and bot Changes review.
3. **Phase 5.2 — combined release gate:** bind exact SQL and bot commits, rehearse Phases 2–5 from
   a fresh restore, then request a separate production go/no-go. This is a promotion/release
   slice, not another implementation phase and not production authorization.

Phase 5.0 was accepted after its representative-copy forward, verification, protocol smokes,
rollback, clean reapply, repository gates and SQL Changes review passed. This SQL acceptance does
not close the cross-repository ACL proof assigned to Phase 5.1.

## Objective

Remove bot-side SQL compensation made obsolete by the corrected SQL contracts while preserving
every public, DAL, import, export, ordering, null and fallback behavior. Close the two Phase 3
Low/P3 mutable-path findings by binding producer publication, SQL claim, digest, import, receipt
and archive to one immutable, uniquely named file.

## Repository and architecture rules

- Create a dedicated bot mirror branch and PR; do not place Python changes in the SQL repository.
- Validate every SQL assumption against `C:\K98-bot-SQL-Server`.
- Data access belongs in DAL/repository modules; commands and views remain SQL-free.
- Promote the validated mirror delta through the patch-based production flow and deploy only from
  `K98-bot/main`.
- The SQL and bot repositories require separate test and diff-security evidence.
- Do not combine the repositories into an invented Git diff. Freeze one exact SQL commit and one
  exact bot commit for the combined release receipt.

## Approved changes

1. `player_self_service/accounts_dal.py`
   - use direct `bigint` GovernorID selection/partition/join expressions;
   - remove only newly redundant integer-metric conversions;
   - preserve the 22-column contract, nulls, ascending SQL order, account-slot remap and five-ID
     scenario.
2. `player_self_service/governor_dashboard_dal.py`
   - replace the float governor predicate with a direct `bigint` predicate;
   - remove only casts made redundant by final integer types;
   - preserve the exact-one-row 19-column contract, freshness/latest precedence and
     present/absent behavior.
3. `weekly_activity_importer.py`
   - use direct `bigint` governor values and remove the obsolete `nvarchar(255)` alliance
     conversion;
   - preserve blank-alliance normalization, date conversion, allied-cohort and completion-state
     semantics.
4. `embed_offseason_stats.py`
   - move the touched direct SQL into a dedicated stats-alert DAL;
   - remove only redundant `Power AS bigint` casts;
   - preserve daily/weekly totals, limits, ordering, fallbacks and all six leaderboard contracts.

No source change is planned for `kvk_state.py`, `kvk/dal/kvk_history_dal.py`,
`stats/dal/fallback_import_dal.py` or `leadership_player_review/dal.py` while their mapped
contracts remain unchanged. Their exact smokes remain mandatory.

## Immutable file-handoff remediation

The following two findings are one root-cause family and must close together across Phase 5.0 and
Phase 5.1:

- Start from
  `docs/Codex_Task_KingdomScanData4_Phase5_1_Bot_DAL_Immutable_Handoff.md`; it records the exact
  bot/SQL boundaries, skills, security routing, ACL proof, tests and acceptance gates.

- `csf_1a1c440452b02cdb787fa7c3`: source hash and `BULK INSERT` can observe different bytes.
- `csf_3cb54318733d3a216dd91e9b`: source hash and archive `MOVE` can observe different bytes.

The approved design requirements are:

1. The bot writes to a private temporary name, closes the file, then atomically publishes a
   unique completed name.
2. SQL claims that exact completed name; the reusable `stats.csv` pathname is no longer the work
   identity.
3. Producer and directory ACL behavior prevents replacement or mutation after claim.
4. Hashing, `BULK INSERT`, the receipt and archival all carry the claimed immutable identity.
5. The archive destination is derived from the claim and rehashed before the receipt advances.
6. Duplicate retry, invalid/corrected retry, controlled failure, reconciliation and crash recovery
   remain deterministic.
7. The SQL companion migration is backward/forward ordered for a stopped-writer maintenance
   window and has an exact rollback definition.

The SQL-only slice cannot prove the NTFS boundary. The findings remain open until Phase 5.1
retains effective `icacls` output and proves, under the real bot token, that overwrite and
in-place modification of a claimed file are denied while the SQL identity can still hash and
move it.

## Phase 5.0 package

- Forward migration:
  `migrations/20260728_001_phase5_immutable_import_file_handoff.sql`.
- Early rollback:
  `migrations/rollback/20260728_001_phase5_immutable_import_file_handoff_rollback.sql`.
- Canonical claim objects:
  `dbo.KS4_ImportFileClaim` and `dbo.CLAIM_KS4_IMPORT_FILE`.
- Updated consumers:
  `dbo.IMPORT_STAGING_PROC`, `dbo.IMPORT_STAGING_PROC_CORE`, `dbo.UPDATE_ALL`,
  `dbo.UPDATE_ALL2`, `dbo.ARCHIVE_IMPORT_STAGING_FILE`, and
  `dbo.HASH_KS4_IMPORT_ARCHIVE_FILE`.
- Offline/rehearsal assets:
  `01_preflight.sql`, `02_verify.sql`, `03_apply_test_path_override.sql`,
  `04_run_protocol_smokes.sql`, `Initialize-Phase5RehearsalFile.ps1`,
  `Invoke-Phase5Rehearsal.ps1`, `Reset-Phase5FailedRehearsal.ps1`, fixtures,
  and `Test-Phase5Contracts.ps1`.
- Concurrency hardening: a losing same-name claim attempt cannot downgrade a valid `claimed`,
  imported, duplicate, or archived state.

### One-command representative rehearsal

Run the orchestrator locally on `MINI_AMD` under the approved Windows/SQL administrator identity.
It is pinned to `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`, refuses production, requires an
unoccupied target and empty rehearsal work directories, and never deletes stale evidence:

```powershell
Set-Location C:\K98-bot-SQL-Server

.\performance_remediation\kingdomscandata4\phase5\Invoke-Phase5Rehearsal.ps1 `
  -ConfirmIsolatedTarget `
  -ConfirmWritersStopped
```

The runner first writes hash-recorded test-root-bound copies of the canonical preflight, forward
migration and rollback into the run evidence directory. It proves the production filesystem root
is absent from those executable copies, then performs preflight, forward migration, verification,
test-path binding verification, fixture publication, normal/duplicate/recovery protocol smokes,
rollback, rollback preflight, clean reapply and final verification. A timestamped transcript,
derived SQL copies and `phase5-rehearsal/v1` JSON receipt are written below:

`C:\discord_file_downloader\downloads_test_phase5_rehearsal\evidence\<run-id>`

If the run stops, retain the evidence directory and inspect the reported step. Reconcile any
Ready, Claimed or Archive files manually; do not delete them merely to make a retry pass.

The 2026-07-28 failed smoke exposed a fixture-only defect: both fixture files contained an extra
final LF, which SQL Server treated as an empty CSV record. The corrected fixtures contain exactly
one header, one data record and one final LF. To recover only that exact failed-attempt shape,
quarantine its three files under the existing evidence receipt, remove its single uncommitted test
claim and apply the reviewed rollback:

```powershell
.\performance_remediation\kingdomscandata4\phase5\Reset-Phase5FailedRehearsal.ps1 `
  -ConfirmDiscardFailedAttempt `
  -ConfirmWritersStopped
```

The reset refuses every other database or filesystem shape and emits
`failed_work_files\reset_receipt.json`. It can also resume the exact zero-claim, quarantined state
left when a reviewed rollback guard fails transactionally. After it passes, rerun the one-command
rehearsal above.
The import core now also persists its exact SQL exception on the claim after rollback so future
smoke failures surface the underlying cause directly.

### Phase 5.0 closure receipt

- Branch: `codex/kingdomscandata4-phase5-sql`.
- Base revision: `74bd8b1860b1b28138e4b470ded123c14a73256d`.
- Representative database:
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`.
- Successful rehearsal:
  `C:\discord_file_downloader\downloads_test_phase5_rehearsal\evidence\phase5_0_20260728T160735090Z`.
- Machine-readable receipt:
  `C:\discord_file_downloader\downloads_test_phase5_rehearsal\evidence\phase5_0_20260728T160735090Z\receipt.json`.
- Ordered proof: target guard, test-bound SQL materialization, preflight, forward migration,
  verification, normal/duplicate/recovery protocol smokes, rollback, rollback preflight, clean
  reapply and final verification all passed. Final state retained three claims and two committed
  receipts on the isolated database.
- Exact failed-attempt recovery also passed and retained:
  `C:\discord_file_downloader\downloads_test_phase5_rehearsal\evidence\phase5_0_20260728T153326225Z\failed_work_files\reset_receipt.json`.
- Final Codex Security Changes scan:
  `099379cd-119b-4402-8ecb-cf2e1c105f40`.
- Reviewed working-tree snapshot:
  `codex-security-snapshot/v1:sha256:cd7a6574c63a297d18f0748470292ed486fd3c7976d7c816d37ee20843bcd207`.
- Result: 18/18 executable worklist rows closed, zero reportable findings, and one explicit
  Phase 5.1 follow-up for effective `icacls` plus real-bot-token mutation denial.
- Post-scan edits are status and receipt documentation only. They do not alter SQL tokens,
  executable behavior, tooling, configuration, permissions, deployment behavior or runtime
  contracts and therefore use a documented security-review skip.
- Production was untouched.

## Required tests

- Update `tests/test_player_self_service_accounts_dal.py`.
- Update `tests/test_governor_dashboard_dal.py`.
- Update `tests/test_weekly_activity_importer.py`,
  `tests/test_weekly_activity_upload_route.py` and weekly/import audit coverage.
- Add focused tests for the new stats-alert DAL and retain the owning embed smoke.
- Run every scenario in the SQL repository's `phase1/bot_dal_contract_map.md`.
- Run architecture, deferred-item, test-selection, smoke-import, command-registration,
  security-routing, pre-commit and full pytest gates.
- Confirm pytest did not mutate production operational logs.
- Run a bot-repository Changes security review against the final committed diff.
- Run a separate SQL-repository Changes security review for the companion migration. Both scans
  must validate closure of the two stable finding IDs.

## Exit gate

Phase 5.0 is closed on its SQL repository boundary. Formal Phase 5 closes only when the four
approved bot paths are implemented, every changed and
source-unchanged contract smoke passes, the full bot suite is clean, both repository-specific
security reviews are complete, both mutable-path findings are closed, and the exact SQL and bot
commits are ready for the combined release rehearsal.
