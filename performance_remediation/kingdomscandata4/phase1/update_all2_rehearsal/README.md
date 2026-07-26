# UPDATE_ALL2 restored-copy rehearsal

These scripts isolate `UPDATE_ALL2` file operations and accelerate functional
test resets without changing production `ROK_TRACKER`.

## Fixed contract

- Restored copy: `ROK_TRACKER_BACKUP_TEST_KS4`
- Pristine snapshot:
  `ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE`
- Active input:
  `C:\discord_file_downloader\downloads_test\stats.csv`
- Fixture library:
  `C:\discord_file_downloader\downloads_test\fixtures`
- Test archive:
  `C:\discord_file_downloader\downloads_test\Import_Archive`
- Collected file evidence:
  `C:\discord_file_downloader\downloads_test\evidence\<run-label>`
- Repo-local fixture package:
  `update_all2_rehearsal\fixtures`

Raw fixtures and collected evidence may contain player-identifying data. Keep
them local and do not commit them to the SQL repository.

## Fixture package

Three master files cover the rehearsal scenarios:

| Fixture | Purpose |
| --- | --- |
| `valid_representative.csv` | Exact byte-for-byte copy of the supplied valid `stats.csv`. |
| `valid_boundary_unicode_optional_blanks.csv` | Valid 411-row file with `Name` at 200 characters, `Alliance` and `Civilization` at 100 characters, Unicode/CSV quoting, and nullable optional fields blank on a separate row. |
| `invalid_required_numeric.csv` | One `Governor ID` value changed to `not-a-number`; `UPDATE_ALL2` should fail and leave the input unarchived. |

`fixtures_manifest.json` records row/column counts, SHA-256 hashes and the
controlled mutations without reproducing player data.

The five functional scenarios do not need five independent files:

| Scenario | Fixture use |
| --- | --- |
| Normal success | `valid_representative.csv` |
| Width, Unicode and nullable-field compatibility | `valid_boundary_unicode_optional_blanks.csv` |
| Invalid required numeric | `invalid_required_numeric.csv` |
| Corrected retry | Invalid fixture first, collect it, then representative fixture without a database reset between attempts |
| Controlled Phase-B failure and concurrency | Reuse `valid_representative.csv` |

## One-time functional-test preparation

1. Restore `ROK_TRACKER_BACKUP_TEST_KS4` from the representative backup.
2. On the SQL Server host, create the isolated subdirectories and install the
   supplied fixture package:

   ```powershell
   .\Initialize-UpdateAll2RehearsalFolders.ps1
   ```

   If the repo-local package is on another machine, copy it to the SQL Server
   host first and pass that directory as `-FixtureSourceDirectory`.
3. Run `05_apply_update_all2_test_path_override.sql` while connected to that
   restored copy.
4. Run `06_create_update_all2_rehearsal_snapshot.sql`.

The snapshot captures the test-only procedure override. It does not capture or
reset filesystem state.

`06_create_update_all2_rehearsal_snapshot.sql` is the snapshot creation
operation; SSMS does not provide a database-snapshot creation wizard. It
dynamically includes every `ROWS` data file and places each `.ss` sparse file
beside its corresponding source data file.

Verify the result from `master`:

```sql
SELECT
    snapshot_db.name AS SnapshotDatabase,
    source_db.name AS SourceDatabase,
    snapshot_db.state_desc,
    snapshot_db.create_date
FROM sys.databases AS snapshot_db
JOIN sys.databases AS source_db
  ON source_db.database_id = snapshot_db.source_database_id
WHERE snapshot_db.name =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
```

The expected result is one `ONLINE` row whose source is
`ROK_TRACKER_BACKUP_TEST_KS4`.

If `05_apply_update_all2_test_path_override.sql` reports that
`IMPORT_STAGING_PROC` already exists, use the current copy of the script. The
stored module text on some restored databases begins with `CREATE PROCEDURE`;
the helper now normalizes that leading verb to `ALTER PROCEDURE` before
replaying the path-only change.

## Functional scenario cycle

1. Stage a fixture:

   ```powershell
   .\Stage-UpdateAll2RehearsalFixture.ps1 `
     -FixturePath "C:\discord_file_downloader\downloads_test\fixtures\valid_representative.csv"
   ```

2. Run the scenario against `ROK_TRACKER_BACKUP_TEST_KS4`.
3. Save SQL results as a scenario-specific `.rpt`.
4. Collect the input/archive evidence:

   ```powershell
   .\Collect-UpdateAll2RehearsalEvidence.ps1 `
     -RunLabel "success_valid_01"
   ```

5. Run `07_reset_update_all2_rehearsal.sql`.
6. Repeat from step 1 for the next scenario.

Use the pristine snapshot for functional success, invalid, corrected-retry,
controlled downstream-failure and concurrency tests.

The snapshot revert rebuilds the source transaction log at a very small
default size. The reset helper therefore prepares the functional-test log
after every revert with:

- initial size: 16 GB
- fixed growth: 4 GB
- maximum size: 32 GB

The boundary/Unicode run demonstrated that a 4 GB initial allocation could
grow to 10 GB before its final commit. The 16 GB allocation prevents those
functional-test growth events and leaves headroom for the two-session
concurrency scenario without adopting the production database's 64 GB log
allocation. This sizing is for snapshot-backed functional tests only. Timed
benchmark runs use fresh restores and do not use the functional snapshot.

For the corrected-retry test, collect the unconsumed invalid input and stage
the representative file without running the database reset between the two
attempts. Reset only after the successful retry evidence is collected.

For the controlled Phase-B failure test, stage `valid_representative.csv` and
then run `09_install_update_all2_phase_b_failure.sql`. The guarded helper
temporarily replaces `dbo.CREATE_THE_AVERAGES`, the first Phase-B operation,
with a stub that throws error 51091. This verifies that the already-committed
Phase-A import remains durable while the separate Phase-B transaction rolls
back and no transaction leaks. Run
`10_run_update_all2_phase_b_failure.sql` to execute the scenario and emit its
normalized pass/fail evidence. Collect the archived-file and SQL evidence,
then immediately run `07_reset_update_all2_rehearsal.sql` to restore the real
procedure definition from the pristine snapshot.

For the concurrency scenario, reset to the pristine snapshot and stage
`valid_representative.csv`, then run
`11_prepare_update_all2_concurrency.sql`. Open
`12_run_update_all2_concurrency_session.sql` in two independent SSMS windows
and execute both copies. Each connection atomically claims session A or B,
waits at the database-backed start gate, invokes `UPDATE_ALL2`, and records
its outcome durably. After both windows finish, run
`13_collect_update_all2_concurrency.sql`. The safe outcome is one successful
consumer, one controlled loser, exactly one 411-row scan in KS4 and KS5, no
remaining fixture or staging rows, and no leaked transaction.

The runner snapshots `@@TRANCOUNT` into a variable before inserting its result.
This avoids treating transaction context observed during the evidence `INSERT`
as post-cleanup session state. The collector uses the post-call transaction
count and `XACT_STATE()` as its leak test and reports any legacy inside-INSERT
cleanup value separately as a recorder limitation.

## Completed functional evidence — 2026-07-24

| Scenario | Result |
| --- | --- |
| Normal representative | Success; 411 rows added to KS5/KS4; scan 1021; 424 seconds |
| Boundary/Unicode/optional blanks | Success; widths 200/100/100 and optional blank preserved; 273 seconds |
| Invalid required numeric | Expected rc=1 failure; database unchanged; fixture retained; no transaction leak |
| Corrected retry without reset | Success; one 411-row scan; fixture archived; no transaction leak |
| Controlled Phase-B failure | Expected error 51091; Phase A durable; Phase B rolled back; no transaction leak |
| Simultaneous concurrency | One success and one controlled rc=1 loser; no duplicate scan or transaction leak |

The concurrency evidence is reported as
`PASS_WITH_CLEANUP_RECORDER_LIMITATION` because the original runner captured
`@@TRANCOUNT` inside its result `INSERT`. Both sessions had post-call count zero,
`XACT_STATE()` zero and final output zero. The runner is corrected for future
runs.

After the final scenario, the restored database was reverted successfully to
the pristine snapshot and reported `ONLINE`, `MULTI_USER`, with 16 GB log,
4 GB growth and 32 GB maximum. The filesystem evidence was collected before
each reset.

## Timed benchmark cycle

Do not retain an active database snapshot for performance measurements because
copy-on-write activity changes the write path.

The retained functional source and its snapshot remain untouched. Timed runs
use the separate database
`ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK`.

One time:

1. Review `14_create_update_all2_benchmark_seed_backup.sql`.
2. Set `@ConfirmCreateSeedBackup = 1` and run it from `master`.
3. Retain its `.rpt`. It verifies the exact source rows/scans and isolated
   path override, creates a checksum-enabled copy-only seed at the fixed
   `C:\sql_backup` path, runs `RESTORE VERIFYONLY`, and records the trusted
   `msdb` backup identity: backup-set, family and binding GUIDs; LSNs; size;
   finish time; media position; and media-family count.

For warm-up ordinal 0 and measured ordinals 1 through 5:

1. Review `15_restore_update_all2_benchmark_database.sql`.
2. Copy the `BackupSetGUID` from the retained
   `14_create_update_all2_benchmark_seed_backup.sql` receipt into
   `@ApprovedBackupSetGuid`, set `@ConfirmRestoreBenchmark = 1`, and run the
   restore from `master`. Save its restore receipt. Before any `SINGLE_USER`
   or `WITH REPLACE`, it compares the file's `RESTORE HEADERONLY` identity
   with that exact approved checksum/copy-only `msdb` receipt for the fixed
   path, requires one position-1 backup set on one device, and reruns
   `RESTORE VERIFYONLY`.
   It refuses a substituted or ambiguous seed and any snapshot owned by the
   benchmark database. After the restore, it also binds the consumed
   `msdb.restorehistory` backup-set ID/GUID and the restored family GUID to the
   trusted seed before the benchmark procedure can be run. It also records the
   non-null target database GUID; that target identity is deliberately not
   compared with the source backup's `HEADERONLY` BindingID because a restore
   under the benchmark database name has its own database GUID. This closes
   the verification-to-restore file-replacement window at the execution
   boundary.
3. Stage the same `valid_representative.csv`.
4. In `04_run_controlled_baseline.sql`, set:

   ```sql
   @RunStandardSuite = 0
   @RunRollbackIsolatedWriters = 0
   @UpdateAll2RunOrdinal = <0 through 5>
   @ConfirmDurableUpdateAll2Database =
       N'ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK'
   @ConfirmIsolatedUpdateAll2Fixture = 1
   ```

5. Connect to `ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK`, execute the benchmark,
   save the `.rpt`, and collect filesystem evidence with a unique run label.
6. Repeat from the restore step before the next ordinal.

Run `Test-UpdateAll2BenchmarkSeedIdentityGuard.ps1` after editing either seed
script. It statically proves that the identity and checksum gates remain ahead
of target mutation and that the completed restore is rebound to the trusted
backup identity before benchmark use. The first run after adding the identity
guard must retain the new seed/restore receipts and repeat one representative
committed-import ordinal before the hardened evidence path is considered
closed.

That first hardened run completed on 2026-07-26. The approved seed
`BackupSetGUID` was `77292DB9-81A9-4C51-8C8C-FB1B00ECF82C`; the corrected
restore passed repeatably in 58 seconds and committed ordinal 1 passed in
141 seconds. Read-only follow-up proved KS4 394,917 rows, KS5 394,937 rows,
maximum scan 1021 in both tables, 411 rows at scan 1021, zero rows at scan
1071, empty canonical staging and material digest
`D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463`.
The superseded restore receipts were retained rather than overwritten, the
pre-existing fixed-path backup was renamed and retained, and the guarded
pristine snapshot remained untouched.

If a run fails because the SQL client connection was recovered, retain and
collect that failed attempt under its own label. Exclude it from the measured
sample, close the recovered query connection, restore the seed again, and
repeat the same ordinal from a new connection with a unique retry label. Do
not overwrite or delete the failed report or its filesystem evidence.

Each committed-import receipt asserts the exact 394,506/394,526-row,
scan-1020 starting state and records KS4/KS5 rows and scans before/after,
latest-scan row/distinct/duplicate counts, staging residue, rows/second,
session lock waits, deadlock-victim status, log used/generated/file-growth
deltas, tempdb delta and the final KS4 digest. A successful procedure call is
reported as failed evidence if any exact row, scan, duplicate or staging
assertion differs.

The successful post-import staging contract is 411 retained rows in each
raw/typed CSV boundary and zero rows in canonical `IMPORT_STAGING`.
`IMPORT_STAGING_PROC` truncates and reloads the boundary tables at the start
of the next import; `UPDATE_ALL2` truncates canonical staging after Phase A.

Harness revision `20260724.3` reports a deterministic KS4 material digest
that excludes `SCAN_UNO`. The surrogate is still checked for 411 distinct
values in the imported scan, but it is not a stable governor-to-value mapping:
the default sequence is consumed by an unordered insert source. For a run
captured with an earlier harness revision, execute the read-only
`16_collect_update_all2_material_digest.sql` before the next restore.

## Cleanup

`08_drop_update_all2_rehearsal_snapshot.sql` drops only the guarded snapshot.
Its confirmation flag defaults to off. It does not revert or drop the restored
copy.
