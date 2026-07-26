# Phase 1 audit report

Status: Phase 1 and all five formal gate items complete; Phase 2 representative-copy
implementation, rehearsal and final-diff security review complete

Started: 2026-07-23

Target: `ROK_TRACKER.dbo.KingdomScanData4`

## Scope summary

The remediation covers the raw CSV landing path, typed and canonical staging, `KingdomScanData5`,
`KingdomScanData4`, all direct and transitive SQL consumers, Query Store/workload evidence, SQL
Agent operations, downstream tables/views, and the bot/DAL consumers in
`C:\discord_file_downloader`.

No table, module, index, data, or bot contract has been changed in Phase 1.

## Live evidence ingested

The authenticated collectors were run on 2026-07-23 and the raw outputs were retained locally
beside this report. They contain operator and player-identifying values and are intentionally not
staged for commit. The evidence files are identified by these SHA-256 hashes:

| Local evidence file | SHA-256 |
| --- | --- |
| `01_collect_environment_and_dependencies.rpt` | `91971EA079348330BFFF6A2D4F952189B5EF79B817DF5D5B0B7A2560A9798BBA` |
| `02_validate_candidate_conversions.rpt` | `523764E9B1965762154220464D83743E4F34D3FABB81A9FB01F80AAA1697FBC5` |
| `03_collect_query_store_baseline.rpt` | `E3B44BEDBBC51B61869C6071D2E20128C286133F1A2C37F645434D2B2971129E` |
| Original received `KingdomScanData4_Analysis_Report.md` | `38973A3D8D0E3E64820036E36645C124D21D92E7560A6BB2A2B24ECB642DF26D` |
| `kingdomscandata4_sample.csv` | `87A9ED09ECE9BB5AB4DFDBC78D2ECEF67BB5E7EB388CB6BC8A821E17A3A4A5C6` |
| `backup_analysis.rpt` | `990BBA4FC1EC2E7DD64093CFB406236D08EC7D83C3A32B0F0C9A40702E0B40E0` |
| `04_run_controlled_baseline.rpt` | `2936AAC2E6B2BE45CB24D2EE50E39D5A4705B0CCE4443104623EE0009D9F2931` |
| `04_run_controlled_baseline_v2.rpt` | `7762D24E0203C6A8AF5D9381B8931EEC16F17727AAF1E33544006483949C1BBA` |
| Operator-held `update_all2_normal_success.rpt` | `1693A32DC061DA186924FAA0FA6A374CA8A2F747E0C25F27AFE9BB749582788B` |
| Operator-held `update_all2_boundary_unicode.rpt` | `DC28C686F607DD091104125DC37AF34A7886379A6C44EFD4EEEDB68A2B2E7FD6` |
| Operator-held `update_all2_corrected_retry.rpt` | `E6B52B8F079D7CA205933B5899974A9DB664DABBF829B4D265F77CCB27932694` |
| Operator-held `update_all2_concurrency_validated.rpt` | `444A14F3591408E1E3486348924D7ACAC7B68C0699D8491492F48F4758B4E43D` |

### Environment and table

- Server/database: `mini_AMD` / `ROK_TRACKER`.
- SQL Server: `16.0.1190.2`, Developer Edition, compatibility level 160.
- Database: `Latin1_General_CI_AS`, FULL recovery, Query Store READ_WRITE/AUTO, no HADR,
  replication, merge publication, CDC or temporal table use reported for this target.
- Approximate instance start: 2026-07-22 05:46:38.340. Index-use counters therefore cover only
  about one day and cannot independently justify index removal.
- `KingdomScanData4`: 394,506 rows, approximately 2,408.17 MB allocated / 2,399.91 MB used,
  uncompressed.

### Backup, storage and restored-copy readiness

- Backup readiness reported `Succeeded` under FULL recovery. The captured reference points were
  full backup 2026-07-23 01:00:13, differential 2026-07-22 18:00:05 and log backup
  2026-07-23 17:00:00. The differential was older than the eight-hour warning threshold; this is
  an operational warning, not a failed restore-chain result.
- Data, log and tempdb reside on `C:\`, which had 474.99 GB total and 243.57 GB free (51.28%).
- `ROK_TRACKER` data was 9,224 MB with 513.31 MB free inside the file, 64 MB fixed growth and
  unlimited maximum. The production log was 65,536 MB with 51 MB used (0.08%), 4,096 MB fixed
  growth and a 2 TB configured maximum.
- The tempdb data files were pre-sized to 4,096 MB each with 512 MB fixed growth; the captured
  aggregate reported approximately 32 GB available and negligible version-store use.
- `ROK_TRACKER_BACKUP_TEST_KS4` restored successfully, `DBCC CHECKDB` reported no errors and the
  operator confirmed all `KingdomScanData4` rows were present. A guarded pristine snapshot was
  created and repeatedly reverted successfully.
- Functional-test reset sizing is 16 GB log, 4 GB fixed growth and 32 GB maximum. This is isolated
  rehearsal sizing, not a production recommendation.
- The dedicated committed-import seed was created from
  `ROK_TRACKER_BACKUP_TEST_KS4` on 2026-07-24 at 12:11:58 UTC while retaining
  `ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE`. Its receipt confirmed KS4 394,506 rows,
  KS5 394,526 rows, maximum scan 1020 in both tables, zero live-path references, three isolated
  test-path references, backup checksums enabled and successful `RESTORE VERIFYONLY`. The captured
  `IMPORT_STAGING_PROC` definition hash was
  `4F9FE9A3574A40125EE3B45D3C4D94B01C1F47BFAC744955965E067EB28B58EA`.
- The first restore of that seed to
  `ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK` completed on 2026-07-24 in
  12,818.931 ms. Post-restore verification reproduced the exact KS4/KS5
  rows, scan 1020, path-reference counts and procedure hash; no snapshot
  referenced the benchmark database and the original guarded snapshot
  remained retained.
- The fresh-seed restore for measured ordinal 1 completed in 59,834.863 ms
  and reproduced the same rows, scans, path counts and procedure hash with no
  benchmark snapshot. Restore-time variance is retained separately from
  `UPDATE_ALL2` execution timing.
- The 2026-07-26 security follow-up repeated the evidence path with the hardened
  backup-identity guard. The checksum/copy-only seed completed in 18 seconds
  with `BackupSetGUID`
  `77292DB9-81A9-4C51-8C8C-FB1B00ECF82C`; the pre-existing fixed-path backup
  was retained under a timestamped name rather than overwritten. The first
  restore completed physically but the post-restore guard correctly stopped
  the workflow after exposing an invalid comparison between the restored
  target database GUID and the source backup BindingID. That receipt is
  retained. The corrected design instead requires a non-null target database
  GUID and binds the exact `msdb.restorehistory` backup-set ID/GUID plus the
  stable family GUID to the approved seed. A second attempt stopped before
  target mutation because a session-local header temp table remained; its
  receipt is also retained. The repeatable corrected restore then passed
  end-to-end in 58 seconds.
- One representative committed ordinal 1 completed through that corrected
  restore path in 141 seconds. Read-only reconciliation proved KS4
  394,917 rows and KS5 394,937 rows, maximum scan 1021 in both tables,
  411 rows in scan 1021, zero rows in scan 1071, and empty canonical
  `IMPORT_STAGING`. The deterministic KS4 material digest excluding
  `SCAN_UNO` matched the locked Phase 1 value
  `D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463`.
  The hardened seed, restore, import, reconciliation and digest reports remain
  operator-held on the SQL host; the retained pristine snapshot was not
  changed.

### Conversion and string evidence

- All 16 proposed numeric conversions reported zero fractional values, zero `int` range failures,
  zero `bigint` conversion failures and zero values beyond the exact integer range of `float`.
- `GovernorID` retained 2,371 distinct values before and after `bigint` conversion, with zero
  failed conversions and no collision rows.
- The live range is scan order 1-1020, covering 2022-03-30 through 2026-07-23.
- Live maximum trimmed lengths are 67 for `GovernorName` and 26 for `Alliance`. There are no
  leading-space rows; fixed-width padding appears on every non-null stored value. `Alliance` has
  5,913 null rows.
- The supplied 1,000-row CSV contains 358 governor IDs and four scan orders with no duplicate
  `(GovernorID, SCANORDER)` rows. Its maximum right-trimmed lengths are 15 and 24 respectively,
  and it includes Unicode governor names, but it is a representative extract rather than a
  boundary/malformed source-contract pack.
- The current typed ingestion boundary remains authoritative for future accepted widths:
  `IMPORT_STAGING_CSV.Name` is `nvarchar(200)` and `Alliance` is `nvarchar(100)`. The external
  report's proposed `nvarchar(100)` / `nvarchar(50)` would narrow that contract and is rejected
  unless the upstream contract is deliberately changed and separately validated.

### Workload and index evidence

- Query Store supplied 200 top runtime rows for the 30-day window and 464 stored plan rows. The
  highest-read statements include the `KingdomScanData4` insert, aggregate/reporting queries,
  ranked historical scans, summary work and exact-governor reads.
- The top recorded insert plan (`query_id=125393`, `plan_id=15558`) ran 46 times with weighted
  averages of 424.414 ms duration, 344.771 ms CPU, 105,580 logical reads, 3,806 logical writes
  and 8,475 physical reads.
- The most expensive listed statement by per-execution reads (`query_id=143117`,
  `plan_id=16603`) averaged 28.821 seconds CPU and 859,949 logical reads across three executions.
  Its `SourceRows`/`#AffectedAliases` text maps to
  `dbo.usp_UpsertGovernorNameHistoryForScan`, called by `UPDATE_ALL2` with the latest scan order.
  It remains a mandatory Phase 3 before/after workload.
- Eight of ten indexes recorded reads after the recent instance restart. Only
  `IX_KS4_Governor_ScanDate_ScanOrder` and
  `IX_KingdomScanData4_GovernorID_ScanOrder` recorded no reads in this short window. They remain
  candidates, not approved drops.
- The collector found 49 metadata dependency rows and 52 module-text matches. It found no matching
  SQL Agent job-step text, synonyms or triggers. SQL Agent history/schedule evidence and
  transitive/dynamic caller reconciliation are still required.

### Controlled baseline results

The baseline harness used no cache clearing, one warm-up and five measured executions, session
DMV deltas, full view materialization, stable row digests, and log/tempdb before/after samples.

| Workload | Measured median | Evidence |
| --- | ---: | --- |
| `SUMMARY_PROC` end-to-end | 267,946.951 ms | 2,374 rows, stable digest; 71,891,096 average logical reads |
| `DEADSSUMMARY_PROC` | 35,879.176 ms | 2,374 rows, stable digest |
| `HEALEDSUMMARY_PROC` | 20,366.971 ms | 2,374 rows, stable digest |
| `POWERSUMMARY_PROC` | 31,513.320 ms | 2,374 rows, stable digest |
| `RANGEDSUMMARY_PROC` | 36,287.989 ms | 2,374 rows, stable digest |
| `Refresh_PlayerScanMeta` full | 301.643 ms | 2,371 rows, stable digest |
| `Refresh_PlayerScanMeta` incremental | 411.817 ms | 2,371 rows, stable digest |
| `Refresh_PlayerScanMeta` no-op | 48.275 ms | 2,371 rows, stable digest |
| `v_PlayerLatestStats` | 64.258 ms | 2,371 rows, stable digest |
| `vDaily_PlayerExport` | 729.391 ms | 223,386 rows, stable digest |
| `vw_Governor_KVK_Summary_GlobalLatest` | 10.015 ms | 411 rows, stable digest |
| Leadership lookup directory | 987.686 ms | 1,639 rows, stable digest |

The remaining daily/WTD views and existing/not-found bot-facing lookups also produced one stable
digest across all five measured executions. These values are the before baseline for later phase
comparison, not performance targets in isolation.

### `UPDATE_ALL2` restored-copy functional rehearsal

The import used an isolated filesystem root and exact restored database guard. The functional
snapshot was not treated as a performance-comparable environment.

| Scenario | Outcome | Durable evidence |
| --- | --- | --- |
| Normal representative file | Passed | 411 rows added to KS5 and KS4; scan 1021; 424 seconds |
| Boundary/Unicode/optional blanks | Passed | widths 200/100/100 preserved; optional blank row preserved; 411 rows; 273 seconds |
| Invalid required numeric | Expected failure passed | error 50000/`IMPORT_STAGING_PROC failed (rc=1)`; no row/scan change; file retained; 737 ms; no transaction leak |
| Corrected retry without reset | Passed | 411 rows added once; scan 1021; file archived; 250.792 seconds; no transaction leak |
| Controlled Phase-B failure | Expected failure passed | error 51091 at `dbo.CREATE_THE_AVERAGES`; Phase A 411-row commit remained durable; Phase B rolled back from `XACT_STATE=-1`; no transaction leak |
| Simultaneous two-session run | Passed with recorder limitation | 0 ms start spread; one success and one controlled rc=1 loser; exactly one 411-row scan; no duplicate/staging/file residue or transaction leak |

The normal run exposed an undersized restored-copy log (97.67% to 98.93%). Later functional
resets used the guarded 16/4/32 GB sizing. The boundary run's procedure-local final sample was
93.05%, but post-commit `sys.dm_db_log_stats` showed only 0.117 MB active log, one active VLF and
no truncation holdup. This was not an open-transaction leak.

The concurrency collector originally evaluated `@@TRANCOUNT` inside its evidence `INSERT`, which
recorded `2` even though the pre-insert post-call count, `XACT_STATE()`, final session output and
collector session were all zero. The runner now snapshots the value before inserting; the
validated report records this as an instrumentation limitation rather than a database leak.

### Committed-import warm-up

Ordinal 0 completed successfully on the dedicated no-snapshot benchmark copy
in 183,649.947 ms with 181,367 ms CPU, 56,038,925 logical reads, 877,653
physical reads, 358,377 writes and 2.238 imported rows/second. KS4 and KS5
each added exactly 411 rows at scan 1021, with 411 distinct governors and no
duplicate rows. Lock waits totalled 1 ms across 15 waits, no deadlock occurred,
the log-generation delta was 4,089.617 MB and the tempdb-used delta was
260.688 MB. The final KS4 digest was
`1D43678E03FEEE80C9475C1A2DFF3992F3BE824749107FA19358BA3BEF810101`.

The ordinal-0 report initially emitted error 51054 because the new harness
incorrectly asserted that raw and typed CSV boundary tables should be empty.
`IMPORT_STAGING_PROC` intentionally truncates and reloads those tables at the
start of each import, and `UPDATE_ALL2` truncates only canonical
`IMPORT_STAGING` after Phase A. The observed post-success state was the exact
expected 411 raw / 411 typed / 0 canonical rows. The harness assertion was
corrected before measured ordinal 1; the valid warm-up is retained as
`PASS_AFTER_HARNESS_CORRECTION`. Its operator-held report SHA-256 is
`4D59A3459BFA00BD1C57A981FFCF552B450E9A0E07EE3CADC66B96820048F3BA`.
The collected archived fixture was 78,480 bytes and matched the staged source
SHA-256 exactly:
`AC7FF4794067617738318594AA96ADD32069FB43C1C81943BD3A46C9A317BB26`.

Measured ordinal 1 completed in 183,546.667 ms with 179,094 ms CPU,
56,079,649 logical reads, 835,082 physical reads, 352,741 writes and 2.239
rows/second. It added the exact 411 rows to each target at scan 1021, with
411 distinct governors, no duplicates, the expected 411/411/0 boundary
state, 1 ms across 16 lock waits, no deadlock, 4,089.363 MB generated log and
262.125 MB tempdb delta. Its report and filesystem hashes are retained.

Ordinal 1 was executed from the earlier SSMS buffer and repeated the false
51054 boundary assertion. The exact receipt proves the import succeeded.
Its reported full-table digest included `SCAN_UNO` and differed from ordinal
0 because sequence values are assigned through an unordered insert source.
The read-only supplement confirmed 411 distinct surrogate values in range
425,256–425,666 and deterministic material digest
`D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463`.
Harness revision `20260724.3` performs that digest directly for subsequent
runs.

Measured ordinal 2 passed cleanly under harness revision `20260724.3` in
195,362.014 ms with 187,268 ms CPU, 56,138,037 logical reads, 710,109
physical reads, 354,592 writes and 2.104 rows/second. It reproduced the exact
411-row additions, scan 1021, 411 distinct governors, zero duplicates,
411/411/0 boundary state, 1 ms across 15 lock waits, no deadlock, 4,088.875 MB
generated log and 257.938 MB tempdb delta. Its material digest matched ordinal
1 exactly:
`D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463`.
The archived fixture again matched the 78,480-byte source SHA-256.

The first attempt at measured ordinal 3 is retained as an excluded transport
failure, not a performance sample. `dbo.IMPORT_STAGING_PROC` failed at its
post-insert `SET @InsertedRows = @@ROWCOUNT` statement because the client
connection had been recovered and SQL Server could not provide the first
post-recovery row count. The attempt stopped after 206.024 ms. KS4 and KS5
remained at the exact fresh-restore state of 394,506 / 394,526 rows and scan
1020; no target rows were committed. The boundary tables contained 411 raw /
411 typed / 0 canonical rows, log generation was 1.355 MB, tempdb delta was
zero, and no lock wait or deadlock was recorded. The collector preserved the
78,480-byte fixture as `unconsumed_stats.csv` with the expected SHA-256. The
operator-held failed report SHA-256 is
`10ABA6996CC4B37D1B0B7A6FF824A755C8813DC6E1ACD9A3D8D62978D758DF1F`.
At that point measured ordinal 3 remained open and required a repeat from the
seed backup on a new client connection.

The ordinal-3 retry then passed under harness revision `20260724.3` with
benchmark ID `9D5883F7-64E7-429B-A6CD-D126E2FEDE24`. It completed in
203,664.788 ms with 191,864 ms CPU, 56,184,069 logical reads, 787,222
physical reads, 355,563 writes and 2.018 rows/second. KS4 and KS5 each added
exactly 411 rows at scan 1021, with 411 distinct governors, zero duplicates,
411 distinct `SCAN_UNO` values in range 425,256-425,666 and the expected
411/411/0 boundary state. Lock waits totalled 2 ms across 14 waits, no
deadlock occurred, generated log was 4,088.758 MB, tempdb-used delta was
261.125 MB and no log-file growth occurred. The material digest again matched
ordinals 1 and 2:
`D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463`.
The successful report SHA-256 is
`3FB786677A364161189034F3D5D33E2986FFC46EB47E5945794DFE777C9818FC`.
Its archive receipt was collected at `2026-07-24T20:41:59.5194584Z` and
matched the fixture length and SHA-256.

The operator reused `committed_import_ordinal_3` for the successful
filesystem receipt and the Downloads report path. A read-only listing then
confirmed that the surviving directory contains the successful archived
fixture and manifest timestamped `2026-07-24T20:41:59Z`. Ordinal 3 is
therefore closed under that unique valid-run label. The earlier excluded
failure remains distinguishable by its captured report hash and supplied
timestamp, but its unconsumed-file evidence directory is no longer present
in the evidence root; this retention limitation is recorded rather than
reconstructing raw evidence.

Measured ordinal 4 passed under harness revision `20260724.3` with benchmark
ID `60AF46DA-AA92-411D-BE1C-13E4609BAAD5`. It completed in 216,637.477 ms
with 181,405 ms CPU, 56,115,096 logical reads, 781,496 physical reads,
353,887 writes and 1.897 rows/second. KS4 and KS5 each added exactly 411 rows
at scan 1021, with 411 distinct governors, zero duplicates, 411 distinct
`SCAN_UNO` values in range 425,256-425,666 and the expected 411/411/0
boundary state. Lock waits totalled 1 ms across 12 waits, no deadlock
occurred, generated log was 4,088.449 MB, tempdb-used delta was 262.250 MB
and no log-file growth occurred. The material digest again matched measured
ordinals 1-3. The successful report SHA-256 is
`80DBA04DC25AFC0D742E5681A9AE840078D92E09D049C1BCD2F2C9D8E5EB5FC2`.
Its archive receipt was collected under `committed_import_ordinal_4` at
`2026-07-24T21:06:30.3923043Z` and matched the fixture length and SHA-256.

Measured ordinal 5 passed under harness revision `20260724.3` with benchmark
ID `6AC962F5-3D74-446C-8A15-9913FD9D3406`. It completed in 186,951.946 ms
with 180,545 ms CPU, 56,106,810 logical reads, 818,355 physical reads,
351,158 writes and 2.198 rows/second. KS4 and KS5 each added exactly 411 rows
at scan 1021, with 411 distinct governors, zero duplicates, 411 distinct
`SCAN_UNO` values in range 425,256-425,666 and the expected 411/411/0
boundary state. No lock time accumulated across 11 lock waits, no deadlock
occurred, generated log was 4,110.387 MB, tempdb-used delta was 262.063 MB
and no log-file growth occurred. The material digest again matched measured
ordinals 1-4. The successful report SHA-256 is
`38EAFA0ECB2C2BA79BF170CAB383272B605DAC8704A2EEA522FB8063E852B723`.
Its archive receipt was collected under `committed_import_ordinal_5` at
`2026-07-24T21:32:48.6489762Z` and matched the fixture length and SHA-256.

The comparable committed-import gate is complete. Across measured ordinals
1-5, median duration was 195,362.014 ms, median CPU was 181,405 ms, median
logical/physical reads were 56,115,096 / 787,222, median writes were 353,887,
median throughput was 2.104 rows/second, median lock waits were 1 ms across
14 waits, median generated log was 4,088.875 MB and median tempdb-used delta
was 262.063 MB. Every run began from the exact seed state, added the exact
411-row scan to both tables, produced zero duplicates and reproduced the same
material digest. No run grew the 16 GB log file or recorded a deadlock.

### SQL Agent and external serialization evidence

Operator-held receipts were collected on 2026-07-25. The SQL Agent report
SHA-256 is
`03DF6F9626CC81FF9838FABABA4C4AD1E89BD532BC261832BFE10A8F9289E945`;
the full SQL Agent inventory supplement SHA-256 is
`2F906E890BF1A552FC33F1157788E0F1BE5153DD505CBFFF45511748681E46EA`;
the external serialization JSON SHA-256 is
`3B56C266844770238F52FDE8037EE0094A5CF9D0D871E09F73A4370AA60F81BF`.

The SQL collector ran as `sysadmin` with `VIEW SERVER STATE`. SQL Server
Agent was automatic and running under `NT Service\SQLSERVERAGENT`. Five jobs
were visible; the broad relevance filter emitted four, all enabled and owned
by `mini_AMD\cwatt`:

- `ROK_TRACKER - Backup Prune`, daily at 02:00;
- `ROK_TRACKER - DIFF Backup`, daily at 18:00;
- `ROK_TRACKER - FULL Backup`, daily at 01:00; and
- `ROK_TRACKER - LOG Backup`, with both 15-minute and 5-minute enabled
  schedules.

Every emitted job had one backup/prune step. None invoked `UPDATE_ALL2`,
`IMPORT_STAGING_PROC`, `KingdomScanData4`, Python, the downloader or the
isolated/import filesystem paths. Each job retained 50 recent outcomes and
all 200 were successful; average durations were 1.420 seconds for prune,
4.280 seconds for differential backup, 12.980 seconds for full backup and
0.040 seconds for log backup. No recent failure-step or cross-job overlap
rows were returned.

The revision `20260725.1` full-inventory supplement emitted all five jobs and
every step. The fifth job is the enabled, `sa`-owned
`syspolicy_purge_history` job on its standard daily 02:00 schedule. Its three
steps verify Policy-Based Management automation, run
`msdb.dbo.sp_syspolicy_purge_history`, and erase phantom System Health
records. It does not reference the application, import files, or
`UPDATE_ALL2`. SQL Agent therefore does not own or schedule this import.

The external collector ran without collection errors against bot repository
commit `caabd2c7dc77aec67f2748a1b9b66fdf53a4aa02` on `main`; the only reported
dirty entry was the expected untracked `downloads_test/` evidence root. It
found three relevant Windows scheduled tasks:

- nightly SQL schema export, enabled daily at 00:30 with
  `MultipleInstances=IgnoreNew`;
- graceful downloader/bot shutdown, enabled twice weekly with
  `MultipleInstances=IgnoreNew` and a non-zero most-recent task result; and
- `RUN_Bot`, disabled, logon-triggered and configured
  `MultipleInstances=IgnoreNew`.

No task action invoked `UPDATE_ALL2` or scheduled the stats import. No
matching Windows service, running process or registry startup command was
observed at collection time.

A read-only control-flow review was then completed against the current bot
repository commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` on `main`. All reviewed
runtime files were clean relative to that commit; unrelated operator-held
documentation changes were left untouched. The normal monitored-channel
path is:

1. `DL_bot.py` passes supported attachments to
   `upload_routes/fallback_queue_route.py`;
2. the route puts the message onto its channel queue;
3. `bot_helpers.queue_worker` downloads the attachment, atomically checks
   the in-process `(channel_id, filename)` active-job set, and enters the
   process-wide `processing_lock`;
4. while holding that lock it awaits
   `processing_pipeline.handle_file_processing`, which awaits
   `execute_processing_pipeline`;
5. the pipeline awaits `stats_module.run_stats_copy_archive`, whose SQL
   step awaits `run_sql_procedure`; and
6. the blocking worker executes parameterized
   `dbo.UPDATE_ALL2` through `update_all2_log_manager.py` and commits.

The child bot acquires `BOT_LOCK_PATH` during module startup and the watchdog
acquires `WATCHDOG_LOCK_PATH`. Thus, after one normal bot process is
established, all monitored-channel import workers share the same global
`processing_lock` and cannot overlap each other.

That is not the only invocation path. The admin-only `/run_sql_proc` command
in `commands/admin_cmds.py` calls `run_stats_copy_archive(rank, seed)`
directly. It does not acquire `bot_helpers.processing_lock`, use a named
operation lock, or declare a Discord concurrency guard. A second command,
an upload arriving during that command, a direct SQL session, or another
external caller can therefore overlap `UPDATE_ALL2`. The procedure itself
still has no database mutex, and the process singleton does not protect
manual/direct SQL sessions.

Gate 2 is complete with the following verdict: there is no authoritative
time-based scheduler and no single serialized invocation boundary. The bot
is the normal operational owner, with an upload-event path that is
serialized only in process and a manual command path that bypasses that
lock. SQL Agent and the captured Windows tasks do not invoke the import.
Phase 3 must establish a database-enforced import mutex/scan-allocation
contract that covers every caller; this resolved exposure must not be
reclassified as safe serialization.

### Query Store owner and parameter map

The revision `20260725.1` read-only collector completed against production
`ROK_TRACKER` at `2026-07-25 07:59:39.6562891` UTC. The operator-held report
is 40,808 bytes with SHA-256
`7563884C4D926054ADC63011B089AC15850305F97F0FE6FA2AFA53A78C94DFD4`.
It ran as `sysadmin` with `VIEW DATABASE STATE` while Query Store was
`READ_WRITE`/`AUTO`.

All 12 retained query/plan pairs were present and all 12 ownership checks
matched; there were no missing, mismatch or SQL error rows:

- `125393/15558` and `52300/8473` belong to `dbo.UPDATE_ALL2`;
- `49472/4949` belongs to `dbo.CREATE_THE_AVERAGES`;
- `125576/15435` and `23307/12884` belong to
  `dbo.GOVERNOR_NAMES_PROC`;
- `67494/10394` belongs to `dbo.SUMMARY_PROC`;
- `143117/16603` remains mapped to
  `dbo.usp_UpsertGovernorNameHistoryForScan` and its affected-alias
  aggregation;
- `143049/16547`, `143234/16658`, `143319/16735` and `144113/16877`
  belong to `dbo.usp_GetLeadershipPlayerReview`; and
- `140333/16354` is ad hoc and uniquely maps in the current bot repository
  to
  `player_self_service/accounts_dal.py:fetch_latest_accounts_scan_rows`.

The executed collector revision `20260725.1` used the shorter static function
label `fetch_accounts_scan_rows`; direct current-source review corrected that
provenance label without changing the captured query text, query/plan IDs,
compiled values or ad hoc ownership result. Revision `20260725.2` contains
the corrected label.

The stored-procedure statement plans did not expose caller parameters in
their individual `ParameterList`; the pinned representative scenarios are
therefore based on the already retained restored-copy parameters and owning
procedure contracts. The ad hoc accounts plan did retain compiled values:
`2441482`, `46718337`, `2510418`, `85574801` and `93858355`.

Every pair now has an exact after entry in the benchmark manifest. Import
and invoked-module statements rerun through the fresh-restore committed
ordinal 0 plus measured 1-5 suite. Leadership-review statements use
governor `2441482`, 90 days and pinned UTC
`2026-07-23T09:55:00`, one warm-up plus five measured runs. The ad hoc
accounts lookup reruns through the current DAL with the five compiled IDs,
again one warm-up plus five measured runs. Gate 3 is complete; the original
Query Store performance window remains the before baseline and was not
replaced by the later ownership receipt.

### Bot/DAL result-contract map

The separate bot repository was inspected read-only at clean commit
`46e5a9cd58a4f475557904226656b2b8cc39dbb2`. The resulting
`bot_dal_contract_map.md` has SHA-256
`2BD4D34955761D5F5A2F00C76394CBE8B1AEA850E884CE82F7017782123B7450`.
It covers every bot path named in the closure matrix:

- offseason summaries and six daily/WTD leaderboard views;
- weekly activity cohort selection and completion-state write;
- KVK-state maximum-scan and fallback resolution;
- legacy and modern KVK history plus metric ranks;
- fallback snapshot overlays, control metadata and task-status reads;
- set-based Accounts lookup and account-slot remapping;
- one-row governor-dashboard latest-scan lookup; and
- all leadership lookup, existence, six-result-set review, identity, KVK
  and last-active procedure contracts.

For each path the map retains the Python caller and owning service, SQL
objects and parameter types, returned aliases/types/null behavior, result
set and row ordering assumptions, exact smoke/equivalence scenario, and the
condition under which a bot change becomes mandatory. The Accounts after
suite was clarified: SQL returns requested IDs ascending, while the service
maps those rows by ID back to registered account-slot order.

The operator selected coordinated, contract-preserving bot cleanup in four
paths: `embed_offseason_stats.py`, `weekly_activity_importer.py`,
`player_self_service/accounts_dal.py` and
`player_self_service/governor_dashboard_dal.py`. These changes remove
conversion or padded-width compensation made obsolete by the corrected
types; the offseason SQL is moved to a dedicated DAL because touching
direct SQL in a root module triggers that extraction. Trims implementing
blank-to-null/display semantics, date/civilization conversions and checked
conversion for unchanged float/text columns remain. The other four mapped
paths require no source edit while their documented contracts remain
identical. Gate 4 is complete for Phase 1 design purposes; all eight
smoke/equivalence cases and a separate bot-repository Changes review remain
mandatory.

### Migration-method preflight

The read-only migration preflight revision `20260725.1` completed against a
fresh `ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK` seed at
`2026-07-25 09:28:49.2197736` UTC. The 77,121-byte operator report has
SHA-256
`CDE5A51DD49ACAE5756A54B29ED2CE2C876FCF15E03FEE8AE7BCA26642306FCA`.

It proved:

- exact KS4/KS5 rows `394,506`/`394,526` and maximum scan 1020;
- no source type/nullability drift;
- zero fractional, failed-bigint or out-of-int-range rows for all selected
  KS4 and KS5 columns; `IMPORT_STAGING` was correctly empty;
- KS4/KS5 maximum normalized name/alliance lengths 67/26 against the locked
  200/100 widths, with no over-width or leading-space rows;
- no schema-bound module, foreign key, trigger, extended property, snapshot,
  blocker or competing user session;
- all ten current KS4 indexes plus the KS5 clustered primary key;
- the one explicit table permission, `GRANT SELECT` to `ImportProcUser`,
  which the shadow must copy; and
- 2,408.17 MB KS4 plus 528.59 MB KS5 total allocation, 193,857.40 MB free
  on the volume, a 16,384 MB test log with 32,768 MB ceiling, and 32,760 MB
  unallocated tempdb.

Revision `20260725.2` corrects only the report's approximate KS4 row display,
which revision 1 summed once per index partition; the exact 394,506-row
identity guard and every conversion/size result in the executed receipt are
unaffected.

The preflight supports shadow copy over direct `ALTER COLUMN`. Direct alter
would drop all ten indexes and execute 18 non-metadata KS4 column rewrites
against the canonical 2.4 GB object before rebuilding the indexes, with
`SCH-M` exposure and no fast table-level rollback. The guarded shadow
rehearsal instead performs one normalized copy, deliberately rebuilds all
ten indexes, copies `ImportProcUser SELECT`, refreshes dependent metadata,
and retains the original objects for a transactional production-usable
metadata-swap rollback.

### Shadow-copy forward rehearsal

The guarded forward rehearsal revision `20260725.1` completed against
`ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK` on 2026-07-25. The 11,842-byte
operator report has SHA-256
`97EAF66EC7557B524B132C321E8134E8E868A1B9598302608B1EF27C6199AFDF`.
It returned `PASS` with run ID
`B517B523-3B99-4848-868F-BB5083949403`.

The measured application/import outage was 45,779.868 ms. The transactional
three-table name swap plus 52-object metadata refresh took 702.684 ms.
The complete interval also included baseline and shadow digest calculation,
copy, index/statistics construction and post-cutover validation so that the
reported outage is deliberately conservative.

The receipt proved:

- exact KS4/KS5 rows `394,506`/`394,526`;
- matching baseline/shadow normalized SHA-256 digests for KS4
  (`2E0FE9F846FA4C29D6900C81DE3A04637F8CA23A9C01DE8CD8E958222EE94D1A`),
  KS5
  (`1AB01D4C73BA72EC7EFB5B04755EED0FF214EBD686CA0A9EAB590B5441FCABB1`)
  and empty staging
  (`5EE9173B1B564E61AFD2359A897C180B5EA83875A91A28537DF4202AAD4B3AA7`);
- deliberate recreation of all ten KS4 indexes and the KS5 clustered primary
  key with full-scan statistics;
- retained `ImportProcUser SELECT`, persisted `AsOfDate`, final types,
  nullability and column order;
- successful `DBCC CHECKTABLE` and dependent-module refresh; and
- retention of all three original tables under `_Phase2_Old` names.

The data file grew from 10,120 MB to 18,244 MB outside the measured outage;
internal free space moved from 68.75 MB to 7,674.06 MB. Log size stayed at
16,384 MB while used log rose from 31.28 MB to 1,382.43 MB (1,351.15 MB).
Tempdb allocation rose from 8.19 MB to 70.56 MB (62.37 MB), and volume free
space fell from 193,628.07 MB to 185,503.79 MB (8,124.28 MB). These are
representative-copy requirements, not yet production deployment allowances.

The report contains only expected aggregate-null and `sp_rename` caution
messages; no SQL error or failed invariant is present. Gate 5 and formal
Phase 1 remain open until the production-usable metadata-swap rollback
receipt restores and verifies the original objects without a snapshot.

The first rollback invocation using revision `20260725.1` stopped before
mutation at guard 51467. The only detected connections were SSMS
Transact-SQL IntelliSense metadata sessions from the operator host; both
were sleeping with zero open transactions. Revision `20260725.2` narrows
the guard to ignore only that exact non-conflicting state. It continues to
reject every other user connection, any active IntelliSense request and any
IntelliSense session with an open transaction.

### Production-usable rollback rehearsal

Rollback revision `20260725.2` then completed against the same forward run
ID `B517B523-3B99-4848-868F-BB5083949403` and returned `PASS`. The
9,110-byte operator report has SHA-256
`FE5FA524F3FEC32951C8340314A41AEB7E557D176F0497D73F49748C1161EF47`.

The measured conservative rollback outage was 34,255.475 ms. Its
transactional three-table metadata swap plus 52-object refresh took
481.386 ms; pre-rollback current/retained digest verification took
26,535.382 ms and post-rollback `DBCC CHECKTABLE` plus schema verification
took 6,104.771 ms.

The current post-forward and retained-original KS4, KS5 and staging counts
and normalized digests matched exactly before the swap. The original
394,506-row KS4 and 394,526-row KS5 tables, original float/`nchar` schema,
all ten KS4 indexes, persisted `AsOfDate`, permission and module metadata
were restored without a snapshot. The migrated copies remain under the
three `_Phase2_Failed` names for evidence.

Data and log files did not grow. Used log increased only 2.56 MB; tempdb
allocation increased 62.19 MB. Internal data-file free space changed by
0.06 MB, while reported volume free space increased 5.03 MB. The report
contains only expected aggregate-null and `sp_rename` cautions, with no SQL
error or failed invariant.

This closed Gate 5 and the formal Phase 1 gate. The operator subsequently
approved the evidence-backed Phase 2 implementation/rehearsal plan on
2026-07-25. Production execution remains separately gated.

## Repository evidence established

1. The current schema snapshot already defines `AsOfDate` as a persisted computed `date` column.
   The report proposal to make it persisted is therefore stale or already implemented; live
   metadata and workload benefit still need validation.
2. The snapshot contains ten indexes, including the clustered index. Several share the
   `(GovernorID, SCANORDER)` prefix, but no index will be removed without Query Store, plan,
   restart-context, size, write-cost, and representative benchmark evidence.
3. The raw CSV table stores source values as `nvarchar`. `IMPORT_STAGING_CSV` is an explicit typed
   boundary using `bigint`, `int`, `decimal`, and bounded `nvarchar`.
4. `IMPORT_STAGING`, `KingdomScanData5`, and `KingdomScanData4` currently convert many of those
   typed integer values back to `float`. The final migration must therefore align the whole
   upstream chain rather than alter only `KingdomScanData4`.
5. `EXCEL_FOR_DASHBOARD.Gov_ID` and `STATS_FOR_UPLOAD.Gov_ID` are already `bigint`, while
   `STAGING_STATS.GovernorID` remains `float`. Downstream alignment is incomplete.
6. Static writer discovery found `UPDATE_ALL` and `UPDATE_ALL2`. The current `UPDATE_ALL2` path
   calls `IMPORT_STAGING_PROC`, writes `KingdomScanData5`, and then promotes the newest scan to
   `KingdomScanData4`.
7. `IMPORT_STAGING_PROC` allocates a new scan number with `MAX(SCANORDER) + 1`.
   `KingdomScanData4` has no visible unique constraint on scan/governor identity. Concurrent
   imports can therefore allocate the same scan number unless an external serialization control
   exists. The simultaneous restored-copy test produced one successful consumer and one
   controlled file-loser with no duplicate scan, but neither procedure contains an explicit
   application mutex and one observed interleaving does not prove all schedules safe.
   Runtime ownership is now mapped: SQL Agent and external tasks do not invoke the import,
   monitored uploads serialize only inside one bot process, and `/run_sql_proc` plus direct SQL
   bypass that guard. Phase 3 must therefore use a database-enforced mutex/scan-allocation
   contract rather than rely on an external scheduler.
8. `UPDATE_ALL2` performs index fragmentation checks, possible reorganize/rebuild operations, and
   statistics updates inside the import transaction. This is an evidence-backed operational-risk
   area for locking, log use, and import latency. Functional runs took approximately 250–424
   seconds and `SUMMARY_PROC` dominated Phase B. The comparable fresh-restore 1+5 import benchmark
   is complete; deliberate maintenance ownership/extraction remains a Phase 3 requirement.
9. The import procedure uses fixed server-side paths, `BULK INSERT`, `xp_fileexist`, and
   `xp_cmdshell` for file archival. These are privileged operational boundaries. The values are
   constants in the current procedure. Bot/runtime ownership is now mapped; execution context,
   least privilege and failure recovery remain deployment/security review requirements.
10. Static bot search found direct reads in `embed_offseason_stats.py`, `weekly_activity_importer.py`,
    `kvk_state.py`, `kvk/dal/kvk_history_dal.py`, `stats/dal/fallback_import_dal.py`,
    `player_self_service/accounts_dal.py`, `player_self_service/governor_dashboard_dal.py`, and
    `leadership_player_review/dal.py`. Their transitive owners, parameter contracts, complete
    result shapes/null/order assumptions, smoke scenarios, and bot-change decisions are retained
    in `bot_dal_contract_map.md`.

## SQL / persistence review

Numeric conversion safety is proven for the current 394,506 rows. Actual dependencies reject
direct `ALTER COLUMN` as the evidence-led candidate: all ten indexes depend on changed columns,
KS4 alone needs 18 non-metadata column changes, and SQL Server permits only one column alteration
per statement. The representative forward shadow-copy path instead completed one normalized copy,
index/statistics construction, transactional cutover, module refresh and full verification in
45,779.868 ms while retaining the original tables. Shadow copy is therefore the selected design
candidate, subject to a successful production-usable rollback receipt and the Phase 2 approval
checkpoint.

For strings, use the existing typed ingestion contract as the no-narrowing baseline:
`nvarchar(200)` for `GovernorName`/`Name` and `nvarchar(100)` for `Alliance`. Current live maxima
and the sample fit within those widths, but they do not justify the external report's narrower
100/50 recommendation.

## Refactor triggers

| Trigger | Decision | Evidence |
| --- | --- | --- |
| Repeated conversions caused by float base types | Fix in this task after conversion proof | Summary procedures and views |
| Duplicate/overlapping indexes | Closed unchanged by operator decision: no exact duplicates, modest expected benefit and insufficient workload proof for safe consolidation | Ten-index snapshot and post-restart DMV window |
| Unsafe restart/persistence state | Not currently indicated | Scan state is SQL-backed |
| Concurrency-fragile `MAX + 1` | Fix in this task after runtime ownership is mapped | `IMPORT_STAGING_PROC` |
| Import-time index maintenance | Fix or redesign in this task after benchmarks | `UPDATE_ALL2` |
| Direct SQL in bot root modules | Extract touched offseason SQL to a dedicated DAL; leave untouched KVK path unchanged and smoke it | `embed_offseason_stats.py`, `kvk_state.py` |

The task forbids related deferred cleanup. Findings are therefore tracked in the closure matrix,
not moved to the deferred-optimisation backlog.

## Security review decision

Changes review required. SQL/import/file/deployment boundaries are security-sensitive, but this is
routine Git-backed remediation rather than an explicit repository security audit. The
diff-focused Codex Security review for the complete 61-file staged SQL delivery closed with zero
reportable findings. The four selected bot changes still require a separate bot-repository Changes
review against their own base/head in Phase 5. Standard and deep scans are not selected.

## Test strategy

- Run the three read-only Phase 1 collectors and retain raw result sets.
- Build representative benchmark parameter sets from Query Store and real bot callers.
- Test all write-capable procedures only on a representative restored copy before production.
- Add schema/type/index assertions, conversion and string preflights, exact data reconciliation,
  forward/failure/rollback tests, import success/invalid/retry/concurrency tests, module/view
  result equivalence, and bot/DAL contract tests.
- Run `deploy/Validate-SqlRepo.ps1` for every SQL diff. Run the focused accounts, dashboard,
  weekly-import and new offseason-DAL tests plus the bot repository's required validation gates
  for the separate bot diff.

## Locked ingestion-width decision

Decision recorded 2026-07-23: preserve the existing typed ingestion boundary rather than narrow
it further:

- `dbo.IMPORT_STAGING_CSV.[Name]` remains `nvarchar(200)`.
- `dbo.IMPORT_STAGING_CSV.[Alliance]` and `[Civilization]` remain `nvarchar(100)`.
- `dbo.IMPORT_STAGING_CSV.[updated_on]` remains `nvarchar(200)`.
- `dbo.IMPORT_STAGING_CSV_RAW` remains the wider raw/error-capture boundary.

No separate anonymised pack is required to justify narrower string widths. Invalid required
numeric, blank optional, Unicode and maximum-width fixtures were exercised successfully against
the restored copy.

## Phase 1 completion and gate status

Phase 1 collection, functional rehearsal and all five formal gate items are complete. The operator
approved the evidence-backed Phase 2 implementation and representative-copy rehearsal plan on
2026-07-25. This does not authorise production execution.

| Gate item | Status | Required next evidence |
| --- | --- | --- |
| Environment, conversion, widths, backup/storage and restored copy | Complete | Rerun drift preflights immediately before migration rehearsal |
| Summary, metadata, view and selected lookup baselines | Complete | Reuse identical scenarios after each material change |
| `UPDATE_ALL2` functional success/invalid/retry/failure/concurrency | Complete | Preserve operator-held reports and filesystem hashes |
| Comparable committed-import performance baseline | Complete | Warm-up plus five measured fresh-seed restores complete; stable 411-row material digest; 195,362.014 ms measured median |
| Query Store owner/parameter map | Complete | 12/12 retained pairs matched owners; compiled ad hoc values and pinned stored-procedure scenarios retained; every pair maps to an exact after baseline |
| SQL Agent/runtime serialization map | Complete | All five Agent jobs and external tasks exclude the import; the normal bot upload path holds one process-wide lock, but `/run_sql_proc` and direct SQL bypass it, so overlap remains possible and Phase 3 requires a database mutex |
| Transitive bot/DAL contracts | Complete | All eight named paths map owner, SQL parameters, full result/null/order contract, exact smoke case, and bot-change decision in `bot_dal_contract_map.md` |
| Migration and rollback design | Complete | Direct ALTER rejected; shadow copy selected with exact preflight, shutdown, dependency, copy, index/statistics, verification and early/late recovery branches |
| Forward/rollback rehearsal | Complete | Forward passed in 45,779.868 ms and production-usable metadata-swap rollback passed in 34,255.475 ms against the same run ID with exact normalized digests and no snapshot |

## Phase 2 representative-copy update

The operator-approved package was implemented without changing the locked Phase 1 decisions.
Three corrected forward rehearsals completed in 73,112.792-74,543.351 ms, two production-usable
early rollbacks in 30,656.546-33,727.390 ms, and the final run's verified preflight backup
restored without `WITH REPLACE` to `ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY`. Recovery
verification passed exact rows, normalized material digests, column/null/order contracts,
identity/default/computed-column metadata, ten retained KS4 indexes, standalone statistics,
permissions, 52 module definitions, critical reads and `DBCC CHECKDB`.

Controlled after-run `9775E3FF-DB41-45CF-89B1-075F01EDC23B` produced five stable measured
samples for all 21 enabled workload/scenario pairs. `SUMMARY_PROC` improved from 267,946.951 ms
to 167,154.476 ms median while preserving its exact 2,374-row digest. The full-suite
`vDaily_PlayerExport` timing was invalidated by log-maintenance overlap; an immediate isolated
repeat passed at 603.284 ms median for 223,386 rows and exact digest
`3EB8E0C681DC9CAAA541B79FB1034C6F5890CFD40E6CE356C42870245635422A`.

Finalizer-focused run `CD8B69F6-CC1D-4F6A-BD4E-B6944B844FB6` passed forward in 56,854.713 ms.
A witnessed post-verification KS4 change caused revision `20260726.1` to refuse with error 51674
before any retained-table drop; after exact witness restoration, the production-usable
metadata-swap rollback passed in 25,047.184 ms with all six digests reconciled. Separate clean run
`E55C338E-6CDE-4048-ABDF-8AF68232C5BB` passed forward in 59,471.943 ms and finalization after a
22,275.645 ms locked six-table digest guard. Its status is `FINALIZED`, all three retained
`_Phase2_Old` tables are absent, all ten KS4 indexes and the inventory-captured KS5 primary key
remain present, and exact rows/material values reconciled.

The production database, representative source copy, guarded pristine snapshot and operator-held
raw evidence were not changed. Production execution remains separately gated.

The early rollback now resets only the exact `Applied` Phase 2 migration-history row to the
repository-supported `Pending` state inside the same transaction, after module verification and
before commit. A transactional representative-copy exercise on
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_RECOVERY` affected exactly one row, left zero matching
`Applied` rows, and restored the exact prior zero-row state on rollback. Static delivery guards
also prove the deployment runner retries `Pending` migrations. This closes the remaining
self-contained Phase 2 delivery gap.

The final SQL working-tree Changes review completed against the complete staged delivery snapshot
`codex-security-snapshot/v1:sha256:51fdbddd810d4b4b8b01926fb27c51b3179f8af13e0b29dee1573424aa83707a`.
It closed all 61 full-file worklist receipts with zero reportable findings. One recovery-file
identity candidate completed discovery, validation and attack-path analysis and was rejected:
exploitation requires protected SQL-host or database write access and is constrained to the fixed,
separately named non-production recovery database. The prior finalizer TOCTOU finding remains
fixed.

Effective production DML/`EXECUTE` grants and the SQL-host backup-folder ACL are not represented in
Git. Confirm both during the separately approved production preflight. Those are deployment
environment checks, not open representative-copy package defects.

These gates determine direct-alter versus shadow migration, the exact coordinated upstream-chain
sequence, the operator-selected retain-all-index design, rollback design and the production
deployment order. The approval checkpoint also includes the mandatory Phase 3/4 conversion
cleanup and four-path Phase 5 bot/DAL update in the same coordinated production release.
