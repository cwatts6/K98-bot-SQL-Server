# KingdomScanData4 Phase 2 recovery runbook

This runbook applies to migration
`20260725_001_kingdomscandata4_shadow_type_remediation`.
It does not authorize production execution.

## Recovery decision

Use the metadata-swap rollback only while all of these are true:

- the bot, import path, `/run_sql_proc`, and direct administrative entry points remain stopped;
- `03_finalize.sql` has not run;
- no post-cutover write has occurred; and
- the rollback script proves that the three current normalized SHA-256 digests match the
  forward receipt, the three retained-original digests match the baseline receipt, and the
  retained originals still match the preflight column, index, standalone-statistic, permission,
  and dependent-module inventories.

If any condition is false or unknown, do not use metadata-swap rollback. Choose a reviewed
forward fix or the backup/log recovery branch below. A rollback refusal before the transactional
metadata swap preserves the forward run's eligible status and records the refusal reason; only a
failure after the rollback swap commits is recorded as `ROLLBACK_FAILED`.

## Forward-fix branch

Prefer a forward fix when the migrated data is intact and the problem is limited to a module,
permission, statistic, or other correction that can be proven without replacing post-cutover
writes.

1. Keep application/import/admin entry points stopped.
2. Capture the current database state, error, affected object definitions, rows, digests, log
   headroom, blocking, and Query Store evidence.
3. Prepare a separately reviewed migration with exact pre/post validation.
4. Rehearse it on a current representative restore.
5. Apply it only after operator approval, rerun `02_verify.sql`, and then decide whether restart
   is safe.

## Backup/log recovery branch

Use this branch after any post-cutover write, when current-table integrity is uncertain, or when
the rollback digest guard refuses the metadata swap.

1. Stop the bot, monitored upload workers, `/run_sql_proc`, schedulers, and direct administrative
   SQL entry points.
2. Record the failure time, migration run ID, last accepted business write, current database
   state, and the RPO decision owner.
3. Take a tail-log backup when the database state permits it. Do not overwrite the Phase 2
   preflight copy-only backup.
4. Read `BackupPath` from the matching row in `dbo.KS4_Phase2_PreflightState`. Confirm that the
   backup file still exists and run `RESTORE VERIFYONLY ... WITH CHECKSUM`.
5. Inspect the backup and log chain with `RESTORE HEADERONLY` and `RESTORE FILELISTONLY`. Select a
   `STOPAT` immediately before the Phase 2 cutover for full rollback, or the accepted later point
   for an operator-approved RPO.
6. Restore the copy-only full and required log chain to a separately named recovery database.
   Never restore `WITH REPLACE` over production as the first recovery step.
7. On the separately named recovery database, verify:

   - `DBCC CHECKDB` and `DBCC CHECKTABLE` for all three target tables;
   - the expected original or final column contracts, depending on the selected restore point;
   - KS4/KS5/staging rows, scan ranges, normalized SHA-256 digests, all ten KS4 indexes, the KS5
     primary key, standalone statistics, and `ImportProcUser SELECT`;
   - all 52 dependent modules refresh/compile;
   - the critical read-only view and DAL smoke scenarios; and
   - the exact set of writes that would be lost or replayed.

8. Compare the recovery database with production and obtain explicit operator acceptance of the
   RPO and replacement plan.
9. Replace production only through a separately reviewed restore/switchover procedure. Preserve
   the failed database and all reports until acceptance.
10. Deploy the SQL and bot revisions that match the recovered schema, restart in dependency
    order, and run the complete post-restart smoke and monitoring suite.

## Representative recovery rehearsal

The final non-production rehearsal must exercise the backup branch without touching production:

1. Restore the representative seed to the dedicated no-snapshot benchmark database.
2. Run `01_preflight.sql` with its default-safe confirmations deliberately set for that database;
   retain the backup path and `RESTORE VERIFYONLY` receipt.
3. Apply the forward migration and `02_verify.sql`.
4. Run `05_restore_preflight_backup_to_recovery.sql` to inspect the backup and restore it without
   `WITH REPLACE` to a new, separately named recovery database.
5. Run `06_verify_recovered_preflight_backup.sql` there. It checks `DBCC CHECKDB`,
   original-schema assertions, exact rows/scans/digests, indexes, standalone statistics,
   permissions, module hashes/refresh and critical read-only results.
6. Drop neither the retained pristine snapshot nor operator-held evidence. Cleanup of the
   temporary recovery database is a separate operator action after evidence acceptance.

The copy-only backup is taken before `01_preflight.sql` finalizes its run-state row. The restored
point-in-time row is therefore expected to be `STARTED` with `BackupVerified = 0` and null
finalized fields. `06_verify_recovered_preflight_backup.sql` validates that expected state, then
uses separately confirmed source constants for exact schema and material reconciliation.

## Evidence to retain

- preflight, backup, `RESTORE VERIFYONLY`, forward, verify, rollback, and recovery-restore reports;
- file paths, sizes, checksums, backup headers, LSNs, and selected `STOPAT`;
- run ID, script SHA-256 values, database/server identity, start/end UTC times;
- row/scan/digest/index/statistic/permission/module/DBCC receipts;
- outage, metadata-swap time, lock waits, deadlocks, log generation/growth, tempdb, internal
  data-file free space, and volume free-space deltas; and
- the explicit decision between metadata rollback, forward fix, and backup/log recovery.
