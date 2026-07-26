# Phase 1 migration-method rehearsal

This pack closes the remaining Phase 1 design gate. It is not the Phase 2 production migration
package.

The scripts are hard-guarded to
`ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK` and refuse `ROK_TRACKER`. They do not use, create, revert,
or drop a database snapshot. The retained
`ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE` snapshot is outside their target database and
must remain in place.

## Selected method to rehearse

The evidence-led candidate is a shadow copy:

1. Clone the three affected table shapes while empty.
2. Change the empty clone columns to the proposed final types.
3. Copy and normalize data once.
4. Recreate every current index deliberately; no Phase 1 index is dropped or consolidated.
5. Stop application/import activity and verify no other user session is connected.
6. Perform a short transactional name swap and refresh every affected module.
7. Keep the original tables through verification for a production-usable metadata-swap rollback.

Direct `ALTER COLUMN` is rejected for rehearsal because all ten KS4 indexes depend on a changed
column and must first be dropped, and SQL Server permits only one `ALTER COLUMN` per statement.
The 18 KS4 changes are not metadata-only, so the direct path would repeatedly rewrite the live
2.4 GB table under `SCH-M`, then rebuild the same indexes, and would have no equally fast
table-level rollback.

## Run order

1. Restore the seed using
   `../update_all2_rehearsal/15_restore_update_all2_benchmark_database.sql`.
2. Run `01_collect_preflight.sql` and retain the complete `.rpt`.
3. Run `02_forward_shadow_rehearsal.sql` with the bot/import stopped and retain the complete
   `.rpt`.
4. Keep the bot/import stopped; do not mutate the migrated tables.
5. Run `03_rollback_shadow_rehearsal.sql` and retain the complete `.rpt`.

The forward script retains the original tables under guarded `_Phase2_Old` names. The rollback
script swaps those production-usable originals back without using a database snapshot. Rehearsal
artifacts remain in the benchmark database until receipts are accepted.

Save reports outside Git and provide their SHA-256 values. Do not clean up the retained source
snapshot.

## Accepted receipts

- Preflight revision `20260725.1`: passed; operator report SHA-256
  `CDE5A51DD49ACAE5756A54B29ED2CE2C876FCF15E03FEE8AE7BCA26642306FCA`.
- Forward revision `20260725.1`: passed; 45,779.868 ms conservative outage, exact normalized
  KS4/KS5/staging digests, all ten KS4 indexes and the KS5 primary key retained, permission and
  52-module refresh verified, and originals retained under `_Phase2_Old`; operator report
  SHA-256 `97EAF66EC7557B524B132C321E8134E8E868A1B9598302608B1EF27C6199AFDF`.
- Rollback revision `20260725.1` stopped before mutation because its user-session guard
  counted sleeping, zero-transaction SSMS IntelliSense metadata connections. Revision
  `20260725.2`, SHA-256
  `1F207DD220972BC7CCDAE046AE2733604300A619673C3ADB52670D29E0F25D18`,
  ignored only that exact non-conflicting state while retaining all other session guards. It
  passed against the same forward run ID in 34,255.475 ms, restored the original float/`nchar`
  schema and exact digests without a snapshot, and retained the migrated copies under
  `_Phase2_Failed`; operator report SHA-256
  `FE5FA524F3FEC32951C8340314A41AEB7E557D176F0497D73F49748C1161EF47`.
