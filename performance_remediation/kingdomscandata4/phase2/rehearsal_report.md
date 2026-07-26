# KingdomScanData4 Phase 2 representative-copy rehearsal

Status: forward, verification, stale-receipt refusal, early rollback, irreversible finalization,
separately named backup/restore recovery, controlled workload and deployment-history retryability
rehearsals passed on 2026-07-25/26. The complete 61-file staged delivery diff passed its final
Changes security review with zero reportable findings. Phase 2 representative-copy acceptance is
complete. Production execution is not authorized.

## Scope and safety boundary

The rehearsal used only `ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK`,
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY`,
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_FINALIZER` and
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_FINALIZEPASS`. It did not execute against `ROK_TRACKER`,
alter the retained `ROK_TRACKER_BACKUP_TEST_KS4` source copy, drop the guarded
`ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE` snapshot, or discard operator-held raw
evidence.

The implemented package migrates `dbo.IMPORT_STAGING`, `dbo.KingdomScanData5` and
`dbo.KingdomScanData4` by shadow copy and transactional metadata swap. It preserves column order
and nullability, KS5 identity and primary key, the KS4 sequence default and persisted `AsOfDate`,
all ten KS4 indexes, the complete captured standalone-statistic set, explicit permissions, and
the 52 dependent module definitions.

## Rehearsal results

| Rehearsal | Result | Conservative outage |
| --- | --- | ---: |
| Corrected forward pass 1 | Passed | 74,543.351 ms |
| Production-usable early rollback pass 1 | Passed | 33,727.390 ms |
| Corrected forward pass 2 | Passed | 73,112.792 ms |
| Production-usable early rollback pass 2 | Passed | 30,656.546 ms |
| Fresh recovery forward, run `BBCA35A2-3091-4A77-A83F-095D31D993EF` | Passed | 73,287.038 ms |
| Fresh forward verification | Passed | 22 seconds |
| Separately named preflight-backup restore | Passed without `WITH REPLACE` | 65 seconds |
| Recovery-database verification | Passed | 36 seconds |
| Finalizer race-test forward, run `CD8B69F6-CC1D-4F6A-BD4E-B6944B844FB6` | Passed | 56,854.713 ms |
| Expected post-verification drift refusal | Passed with error 51674 before any drop | 15 seconds |
| Race-test production-usable early rollback | Passed | 25,047.184 ms |
| Clean finalization forward, run `E55C338E-6CDE-4048-ABDF-8AF68232C5BB` | Passed | 59,471.943 ms |
| Clean finalization verification | Passed | 17 seconds |
| Locked pre-finalize digest guard and retained-table drop | Passed; status `FINALIZED` | 22,275.645 ms guard; 22 seconds end-to-end |
| Transactional migration-history retryability | Passed; one exact `Applied` row reset to `Pending`, zero remained `Applied`, and rollback restored the exact prior zero-row state | Statement-level representative-copy proof |

All three early rollback passes exercised the documented production-usable metadata-swap path. No
database snapshot was used as the rollback mechanism. The final fresh run retained the migrated
benchmark database and restored its verified preflight backup to a different recovery database.

The finalizer race test changed the witnessed KS4 row `SCAN_UNO=1` from `Power=124109056` to
`124109057` after verification. Revision `20260726.1` recomputed the canonical and retained
digests while holding all six table locks and raised error 51674 before any retained-table drop.
The witness value was restored exactly and the early rollback then passed. A clean restore
exercised the irreversible path: all six digests matched, the exact inventory-captured KS5
primary-key name was accepted, the three `_Phase2_Old` tables were dropped, and status advanced
to `FINALIZED`.

## Exact reconciliation

All five forward passes, all three early rollback passes, the separately named recovery
verification and the clean finalization guard reconciled the expected schema and material-value
contracts. The final recovery verification returned:

| Object | Rows | Normalized SHA-256 digest |
| --- | ---: | --- |
| `dbo.KingdomScanData4` | 394,506 | `2E0FE9F846FA4C29D6900C81DE3A04637F8CA23A9C01DE8CD8E958222EE94D1A` |
| `dbo.KingdomScanData5` | 394,526 | `1AB01D4C73BA72EC7EFB5B04755EED0FF214EBD686CA0A9EAB590B5441FCABB1` |
| `dbo.IMPORT_STAGING` | 0 | `5EE9173B1B564E61AFD2359A897C180B5EA83875A91A28537DF4202AAD4B3AA7` |

The checks also passed for scan range, final types, unchanged nullability and column order,
persisted `AsOfDate`, KS5 identity, KS4 sequence default, ten KS4 indexes, KS5 primary key,
standalone statistics, complete explicit-permission sets, module definition hashes and refresh,
critical read-only result counts, and `DBCC CHECKTABLE`/`DBCC CHECKDB`.

The preflight backup is taken before `01_preflight.sql` marks its receipt complete. A restored
preflight point-in-time image therefore correctly contains a `STARTED` state row with
`BackupVerified = 0` and no finalized receipt fields. The recovery verifier asserts that
point-in-time state and then independently compares the restored schema, metadata and material
digests with the exact approved source constants; it does not mistake the expected incomplete
receipt for backup corruption.

## Rehearsed package identity

| File | SHA-256 |
| --- | --- |
| `phase2/01_preflight.sql` | `D6F5217CC24E765D5338ADBCD73B606C4ECF80F7D2654CD1814F89A8BA8B7A02` |
| `migrations/20260725_001_kingdomscandata4_shadow_type_remediation.sql` | `1DB79AF05C16B1E494AE2643657F910670050E157EBE30E97102465AB0C63FE1` |
| `phase2/02_verify.sql` | `405C32DB6193A4B4896A7892A64E94C40DAA78E7E034F0D1232D1A09238A769C` |
| `phase2/03_finalize.sql`, revision `20260726.1` | `86A1F6A4F72A26DBB09AEF810033745A571679EFB4B3057EA31E98D19B99304E` |
| `migrations/rollback/20260725_001_kingdomscandata4_shadow_type_remediation_rollback.sql`, revision `20260726.2` | `A842B5B6E94E3C08EDA60B448F533EEB28C2059023E525F82EAF992DC40DCE8D` |
| `phase2/Test-Phase2FinalizeDigestGuard.ps1` | `549D6899A568CC4612A69F11E7E896952549044920C208A4C7A293053DB297AF` |
| `phase2/Test-Phase2DeliveryHistoryGuard.ps1` | `5C65E411B07897FB07BB6BA3B178685319806D891D625C3FAA94A0478C8CBD91` |
| `phase2/07_test_migration_history_retryability.sql` | `3D90C929590CE57935684F5FD7AAA0AF603D7D7D1637B08B4B643E647E546205` |
| `phase2/05_restore_preflight_backup_to_recovery.sql` | `034854906B497AC74DDE4A194A0A87BD3220B5049A7CE554DF04C546AF755873` |
| `phase2/06_verify_recovered_preflight_backup.sql` | `4DAE4F79450109330A907242E1CB1471901C8081FAA9BA82FB447978B375B3AF` |

## Drift and TOCTOU controls proven

- Confirmation variables default to refusal and non-production targets must match the approved
  representative-copy naming boundary.
- Preflight refuses associated snapshots, conflicting sessions, prior Phase 2 artifacts, schema
  or conversion drift, missing backup verification, and insufficient space.
- Forward migration holds an exclusive application lock and `TABLOCKX, HOLDLOCK` table locks
  through final digest reconciliation and transactional cutover.
- The complete explicit-permission inventory is compared in both directions before copy and again
  inside the locked cutover transaction. New grants, denies or column-level permissions therefore
  stop the migration rather than remaining silently attached to the retained original tables.
- The complete captured standalone-statistic inventory is recreated one-for-one and compared by
  name, columns and options. Unexpected additions or removals stop the run.
- Early rollback is allowed only before application restart and only while canonical and retained
  table digests still match the verified forward and baseline receipts.
- In the same rollback transaction, revision `20260726.2` locks and resets only the exact
  `Applied` `SchemaMigrationHistory` row to `Pending`. The deployment runner therefore cannot
  skip a forward retry after a successful pre-restart rollback. The representative-copy
  transition affected exactly one row, left zero `Applied` rows and was itself rolled back to
  prove cleanup.
- Finalization requires the exact run ID and a verification receipt no older than five minutes,
  locks all six current/retained tables, recomputes all six digests in the drop transaction, and
  verifies the inventory-captured constraint names. The witnessed post-verification write proved
  refusal before any irreversible DDL.
- Post-cutover writes make metadata-swap rollback ineligible; the separately named restore
  rehearsal proves the documented backup/recovery branch without replacing any existing database.

## Resource and outage decision

The corrected package remains within the approved 30-minute maintenance window and the 10-minute
pre-restart forward/verification trigger. The longest corrected forward outage was 74.544 seconds
and the longest corrected early rollback was 33.728 seconds. The Phase 1 sizing receipt remains
the production planning floor: controlled 8 GB data-file preallocation outside the outage,
approximately 1,351.15 MB used-log growth, 62.37 MB tempdb allocation growth and approximately
518.69 MB additional used data while old and new tables coexist. Production must collect fresh
values and stop on any package threshold failure.

## Controlled workload rerun

The first post-migration launch exposed a benchmark-harness parser defect before any workload
executed: four aliases named `RowCount` were unquoted. The canonical harness now uses
`[RowCount]`; the failed compile receipt is retained and is not counted as a benchmark result.

The first corrected repeat in the same SSMS session then found stale session-local temporary
tables. The harness now drops every named benchmark temporary table at startup. A later attempt
stopped with SQL Server error 9002 because the dedicated benchmark copy retained `FULL` recovery
but had no log-backup chain servicing its 32 GB maximum. That environmental failure is retained
and excluded. No production setting was changed: the benchmark-only maximum was temporarily
raised to 64 GB, its physical log remained 32 GB, and unique checksum/compressed log backups were
taken and verified. The final used-log state was 2,924.55 MB of 32,767.99 MB (8.93%), with fixed
4 GB growth and the temporary 64 GB test-only maximum.

The clean final suite used benchmark run
`9775E3FF-DB41-45CF-89B1-075F01EDC23B`, one warm-up and five measured runs.
All 21 executed workload/scenario pairs had five successful samples, identical result-row counts
and exactly one digest. The only non-success row was the intentional configuration skip for
`UPDATE_ALL2`, because no committed-import ordinal was supplied.

| Workload | Before median ms | Phase 2 median ms | Rows | Disposition |
| --- | ---: | ---: | ---: | --- |
| `SUMMARY_PROC` end-to-end | 267,946.951 | 167,154.476 | 2,374 | 37.6% faster; exact stable digest `467092D9B32AEB45142FBA2AD8376AB4ACA42CEC4FF44B1AD3E8B452DCDD71BB` |
| `DEADSSUMMARY_PROC` | 35,879.176 | 18,572.113 | 2,374 | Faster; stable |
| `HEALEDSUMMARY_PROC` | 20,366.971 | 16,817.544 | 2,374 | Faster; stable |
| `POWERSUMMARY_PROC` | 31,513.320 | 19,724.638 | 2,374 | Faster; stable |
| `RANGEDSUMMARY_PROC` | 36,287.989 | 15,205.826 | 2,374 | Faster; stable |
| `Refresh_PlayerScanMeta` full / incremental / no-op | 301.643 / 411.817 / 48.275 | 470.612 / 548.919 / 62.602 | 2,371 | Small absolute increases, all below 0.55 seconds; stable rows/digests |
| `v_PlayerLatestStats` | 64.258 | 95.087 | 2,371 | 30.829 ms absolute increase; stable |
| `vw_Governor_KVK_Summary_GlobalLatest` | 10.015 | 19.337 | 411 | 9.322 ms absolute increase; stable |
| `usp_GetLeadershipPlayerLookupDirectory` | 987.686 | 749.879 | 1,639 | Faster; stable |
| `usp_GetLeadershipPlayerLastActive` | 256.446 | 325.244 | 1 | 68.798 ms absolute increase; stable |

The end-to-end summary samples were 166,360.882, 167,016.493, 167,154.476,
195,210.795 and 213,526.612 ms. Verified log backups overlapped later samples while preventing
another environmental log-full stop; the median is therefore the comparison statistic and this
interference limitation is retained.

The full-suite `vDaily_PlayerExport` sample was 5,611.234 ms and was not accepted as an
unexplained regression. An immediate interference-free warm-up plus five measured rerun of the
exact 223,386-row materialization produced 601.677, 600.410, 642.599, 609.021 and 603.284 ms:
603.284 ms median, 611.398 ms average, and stable digest
`3EB8E0C681DC9CAAA541B79FB1034C6F5890CFD40E6CE356C42870245635422A`.
That is 17.3% faster than the 729.391 ms Phase 1 baseline and closes the apparent regression.
The remaining daily/WTD views also returned five stable samples with no material mismatch.

## Residual scope

Phase 2 does not start the application and production execution remains separately gated. Phase 3
still owns procedure/import alignment and an explicit database mutex with atomic scan allocation
and duplicate prevention. Phase 4 owns contract-preserving view cleanup. Phase 5 owns the approved
four-path bot/DAL cleanup and separate repository tests/security review. Those phases are not
Phase 2 acceptance dependencies; their combined fresh-restore rehearsal is the later release gate.
