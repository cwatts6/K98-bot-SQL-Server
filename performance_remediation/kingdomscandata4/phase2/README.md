# KingdomScanData4 Phase 2 package

Status: package authored and the representative-copy forward, stale-receipt refusal,
production-usable early rollback, irreversible finalization, separately named backup/restore
recovery and controlled workload paths have passed. The final-diff Changes security review closed
with zero reportable findings. Phase 2 representative-copy acceptance is complete. Production
execution is not authorized.

## Scope

This package implements the approved three-table shadow migration for:

- `dbo.IMPORT_STAGING`;
- `dbo.KingdomScanData5`; and
- `dbo.KingdomScanData4`.

It preserves the raw and typed CSV boundaries, final nullability and column order, the persisted
`AsOfDate`, KS5 identity, KS4 sequence default, all ten KS4 indexes, every captured standalone
statistic, the explicit KS4 permission, and the 52 dependent module definitions. It does not
implement the Phase 3 procedure/import mutex work, Phase 4 view cleanup, or Phase 5 bot changes.

## Drift and rollback controls

- Preflight requires the exact three-table column contract, one KS5 primary-key index, no staging
  indexes, all ten named KS4 indexes, captured standalone statistics, permissions, dependencies,
  module hashes, expected representative rows/scans, a single ROWS data file, free space, and a
  fresh verified copy-only backup. Controlled preallocation reserves 64 MB above the hard 8 GB
  post-allocation free-space threshold; this covers SQL Server metadata pages consumed by the
  growth itself and prevents a rounding-sized false failure at exactly 8 GB. Its expected-module
  comparison explicitly normalizes catalog strings to the target database collation so a valid
  inventory is not rejected when catalog and data collations differ. The approved 22 KS4
  statistic-column shapes remain mandatory, while additional workload-created standalone
  statistics are retained one-for-one instead of being discarded. Forward and verification
  compare the complete captured statistic count as well as every captured name, column list and
  option, so additions after preflight are refused.
- Forward migration takes `TABLOCKX, HOLDLOCK` on the three canonical and three completed shadow
  tables before the final digests. Those locks remain held through the transactional metadata
  swap, so a caller that does not yet participate in the Phase 3 application mutex cannot create
  a digest-to-cutover race.
- Forward migration compares the complete explicit-permission set with the preflight inventory in
  both directions, then repeats that comparison inside the locked cutover transaction immediately
  before the metadata swap. An additional `DENY`, `GRANT`, or column-level permission therefore
  refuses the migration instead of remaining on the retained original.
- Verification compares the complete three-table column, index, standalone-statistic, permission,
  digest, row/scan, module, DBCC, and critical read contracts with the preflight inventories.
- Finalization is bound to the exact run ID and a verification receipt no older than five minutes.
  It obtains the migration application lock, holds `TABLOCKX, HOLDLOCK` on all three canonical and
  all three retained tables, and recomputes the six exact normalized digests inside the same
  transaction that drops the retained originals. Any canonical or retained drift refuses before
  a drop. KS5 primary-key verification uses the exact name captured by the preflight inventory,
  including a generated source name, rather than assuming a repository-friendly name.
- Early rollback takes the same exclusive table locks, reconciles both data copies, and compares
  the complete original metadata inventories before committing its metadata swap. A refusal
  before that commit records the reason without falsely marking an otherwise eligible forward run
  as `ROLLBACK_FAILED`.
- Early rollback also preserves migration-history retryability. When the forward migration was
  applied through `deploy/Deploy-SqlMigration.ps1`, the rollback changes only the exact
  `20260725_001_kingdomscandata4_shadow_type_remediation` history row from `Applied` to the
  repository-supported `Pending` state inside the same transaction as the metadata swap. Manual
  representative rehearsals without a history row remain valid and report zero rows reset.
- Operator-held Phase 1 raw reports remain in place and are excluded from Git by narrow
  remediation-path ignore rules; the rules do not delete or move any evidence.

## Files and run order

1. Restore the checksum-verified representative seed to the dedicated no-snapshot benchmark
   database. Keep `ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE` untouched.
2. Edit only the confirmation variables in a local execution copy of `01_preflight.sql`; run it
   and retain the complete report and backup receipt.
3. Apply
   `migrations/20260725_001_kingdomscandata4_shadow_type_remediation.sql`.
4. Run `02_verify.sql` before any application/import restart.
5. For the required early-rollback rehearsal, run
   `migrations/rollback/20260725_001_kingdomscandata4_shadow_type_remediation_rollback.sql`.
6. On a fresh restore, repeat forward and verification, then exercise the separately named
   backup/restore recovery rehearsal in `04_recovery_runbook.md`: run
   `05_restore_preflight_backup_to_recovery.sql`, then
   `06_verify_recovered_preflight_backup.sql`.
7. On a separate fresh restore, rehearse `03_finalize.sql` only after an accepted final forward
   verification and before restart. It is default-off, bound to an exact run ID, and irreversible.

## Representative-copy receipts

- Corrected forward/early-rollback pass 1: 74,543.351 ms forward; 33,727.390 ms rollback.
- Corrected forward/early-rollback pass 2: 73,112.792 ms forward; 30,656.546 ms rollback.
- Fresh recovery run `BBCA35A2-3091-4A77-A83F-095D31D993EF`: forward passed in
  73,287.038 ms and `02_verify.sql` passed in 22 seconds.
- Finalizer race/rollback run `CD8B69F6-CC1D-4F6A-BD4E-B6944B844FB6` on
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_FINALIZER`: forward passed in 56,854.713 ms. A one-unit
  witnessed KS4 change after verification produced expected error 51674 before any retained table
  was dropped. After restoring the witness value, the production-usable metadata-swap rollback
  passed in 25,047.184 ms with exact current/retained digests.
- Clean irreversible-finalization run `E55C338E-6CDE-4048-ABDF-8AF68232C5BB` on
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_FINALIZEPASS`: forward passed in 59,471.943 ms,
  verification passed with exact rows/digests, and the locked six-table finalizer digest guard
  passed in 22,275.645 ms across 1,578,064 rows. The run status is `FINALIZED`, all three
  `_Phase2_Old` objects are absent, KS4 has ten indexes, the captured KS5 primary-key name and
  `DF_KS4_SCAN_UNO` are intact, and the guarded pristine snapshot remains present.
- The same fresh run's preflight backup restored without `WITH REPLACE` to
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY` in 65 seconds. Recovery verification passed in
  36 seconds with 394,506 KS4 rows, 394,526 KS5 rows, zero staging rows, all schema/index/
  statistic/permission/module checks, critical reads and `DBCC CHECKDB`.
- The restored backup is deliberately a preflight point-in-time image. Its run-state row is
  therefore `STARTED` with `BackupVerified = 0`; finalized preflight fields are not expected to
  exist in that image. `06_verify_recovered_preflight_backup.sql` checks those point-in-time
  semantics and independently reconciles the restored tables to the exact approved source
  receipt constants.
- Exact recovery material digests were unchanged:
  KS4 `2E0FE9F846FA4C29D6900C81DE3A04637F8CA23A9C01DE8CD8E958222EE94D1A`,
  KS5 `1AB01D4C73BA72EC7EFB5B04755EED0FF214EBD686CA0A9EAB590B5441FCABB1`,
  and staging
  `5EE9173B1B564E61AFD2359A897C180B5EA83875A91A28537DF4202AAD4B3AA7`.
- The recovery database is intentionally retained for operator inspection. The guarded pristine
  snapshot and all operator-held raw receipts remain untouched.
- Controlled after-run `9775E3FF-DB41-45CF-89B1-075F01EDC23B` completed one warm-up and five
  measured executions for every enabled workload. All 21 executed workload/scenario pairs had
  stable row counts and one digest. `SUMMARY_PROC` improved from 267,946.951 ms to
  167,154.476 ms median with its exact 2,374-row digest unchanged.
- The full-suite `vDaily_PlayerExport` timing was invalidated by maintenance interference. Its
  immediate isolated repeat passed at 603.284 ms median for 223,386 rows with stable digest
  `3EB8E0C681DC9CAAA541B79FB1034C6F5890CFD40E6CE356C42870245635422A`,
  faster than the 729.391 ms Phase 1 baseline.
- The benchmark-only `FULL` recovery log required verified checksum/compressed log backups after
  an excluded error-9002 attempt. Its physical size remained 32 GB; its maximum was temporarily
  raised to 64 GB for the test copy only, and final used log was 2,924.55 MB (8.93%).
- The early-rollback deployment-history transition was exercised inside a transaction on
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY` on 2026-07-26. The exact migration changed from
  `Applied` to the repository-supported `Pending` state with one affected row and zero remaining
  `Applied` rows. The transaction was rolled back and the original zero-row history state was
  restored. The canonical repeatable test is
  `07_test_migration_history_retryability.sql`.

## Required receipts

| Receipt | Status |
| --- | --- |
| Static repository validation | Passed after evidence consolidation; `git diff --check` and `deploy/Validate-SqlRepo.ps1` succeeded |
| Migration-history retryability guard | Passed: static guard validates exact migration targeting, `Applied` to `Pending` transition, supported history status, lock/commit ordering and deployment-runner retry semantics; the transition passed transactionally on the representative recovery copy and cleanup restored its exact prior state |
| SSMS parser validation | Passed for preflight, forward, verify, early rollback, and finalize |
| Preflight and copy-only backup verification | Passed on each fresh representative-copy run |
| Forward migration | Passed three corrected runs; final run 73,287.038 ms |
| Schema/row/digest/index/statistic/permission/module/DBCC verification | Passed |
| Critical read-only smoke | Passed |
| Production-usable early rollback | Passed three times without snapshot recovery |
| Separately named backup/restore recovery rehearsal | Passed without `WITH REPLACE` |
| Post-verification drift refusal | Passed: error 51674 before any retained-table drop |
| Irreversible finalization rehearsal | Passed on a fresh isolated copy; six locked digests, exact captured constraints, three retained tables removed |
| Relevant controlled before/after workloads | Passed: five stable measured samples per enabled scenario; targeted export repeat closed the maintenance-overlap outlier |
| SQL repository Changes security review | Passed on complete staged delivery snapshot `codex-security-snapshot/v1:sha256:51fdbddd810d4b4b8b01926fb27c51b3179f8af13e0b29dee1573424aa83707a`: 61/61 file receipts, zero reportable findings |

## Hard stops

- Never run destructive DDL against `ROK_TRACKER` without separate production approval.
- Never drop or revert the retained pristine snapshot from this package.
- Never commit or discard operator-held raw `.rpt`, fixture, or filesystem evidence.
- Never use metadata-swap rollback after a post-cutover write or after finalization.
- Never remove or consolidate a KS4 index in this remediation.
