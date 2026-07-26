# KingdomScanData4 Phase 2 approval checkpoint

Status: approved by the operator on 2026-07-25 for implementation and representative-copy
rehearsal; the approved representative-copy implementation, forward, rollback, recovery,
workload, drift-refusal and clean irreversible-finalization rehearsals completed on 2026-07-26
and the final SQL Changes security review closed with zero reportable findings. This document is
not approval to execute destructive DDL against production.

## Decision

Use a guarded shadow-copy migration for `dbo.IMPORT_STAGING`,
`dbo.KingdomScanData5` and `dbo.KingdomScanData4`.

Direct `ALTER COLUMN` is rejected because all ten KS4 indexes depend on changed columns, KS4
requires 18 non-metadata column changes, SQL Server permits only one `ALTER COLUMN` per statement,
and the direct path would repeatedly rewrite the live 2.4 GB table before rebuilding those same
indexes. It also has no table-level rollback comparable to a metadata swap.

The shadow method passed on the representative copy:

- forward: 45,779.868 ms conservative outage;
- transactional forward swap and 52-module refresh: 702.684 ms;
- rollback: 34,255.475 ms conservative outage;
- transactional rollback swap and 52-module refresh: 481.386 ms;
- exact KS4/KS5/staging row counts and normalized SHA-256 digests before, after and after rollback;
- all ten KS4 indexes, KS5 primary key, `ImportProcUser SELECT`, persisted `AsOfDate`, identity,
  sequence default, column order and nullability verified;
- `DBCC CHECKTABLE` passed in both directions; and
- production-usable rollback exercised without a database snapshot.

Forward and rollback used the same run ID
`B517B523-3B99-4848-868F-BB5083949403`.

## Exact table contract

All listed nullability is unchanged. All strings use `Latin1_General_CI_AS`. Columns not listed
remain at their current types, order and nullability.

### `dbo.KingdomScanData4`

| Columns | Final type | Nullability |
| --- | --- | --- |
| `PowerRank`, `SCANORDER` | `int` | `NOT NULL` |
| `GovernorID`, `Power`, `KillPoints`, `Deads`, `T1_Kills`, `T2_Kills`, `T3_Kills`, `T4_Kills`, `T5_Kills`, `RSSAssistance`, `Helps` | `bigint` | `NOT NULL` |
| `T4&T5_KILLS`, `TOTAL_KILLS`, `RSS_Gathered` | `bigint` | `NULL` |
| `GovernorName` | `nvarchar(200)` | `NULL` |
| `Alliance` | `nvarchar(100)` | `NULL` |

Preserve `SCAN_UNO int NOT NULL`, its `NEXT VALUE FOR dbo.KS4_UNO_SEQ` default, and
`AsOfDate AS CONVERT(date, ScanDate) PERSISTED`. Preserve `Civilization nvarchar(100) NULL`.
`AsOfDate` is not a new optimization in Phase 2; the shadow reproduces the existing persisted
definition.

### `dbo.KingdomScanData5`

| Columns | Final type | Nullability |
| --- | --- | --- |
| `PowerRank` | `int` | `NOT NULL` |
| `SCANORDER` | `int` | `NULL` |
| `GovernorID`, `Power`, `KillPoints`, `Deads`, `T1_Kills`, `T2_Kills`, `T3_Kills`, `T4_Kills`, `T5_Kills`, `RSSAssistance`, `Helps` | `bigint` | `NOT NULL` |
| `T4&T5_KILLS`, `TOTAL_KILLS`, `RSS_Gathered` | `bigint` | `NULL` |
| `GovernorName` | `nvarchar(200)` | `NULL` |
| `Alliance` | `nvarchar(100)` | `NULL` |

Preserve `SCAN_UNO int IDENTITY(1,1) NOT NULL`, its clustered primary key, identity seed and
increment. Preserve `Civilization nvarchar(100) NULL`.

### `dbo.IMPORT_STAGING`

| Columns | Final type | Nullability |
| --- | --- | --- |
| `SCANORDER` | `int` | `NULL` |
| `Governor ID`, `Power`, `Total Kill Points`, `Dead Troops`, `T1-Kills`, `T2-Kills`, `T3-Kills`, `T4-Kills`, `T5-Kills`, `RSS Assistance`, `Alliance Helps` | `bigint` | `NOT NULL` |
| `Kills (T4+)`, `KILLS`, `RSS Gathered` | `bigint` | `NULL` |
| `Name` | `nvarchar(200)` | `NULL` |
| `Alliance` | `nvarchar(100)` | `NULL` |
| `Updated_on` | `nvarchar(200)` | `NULL` |

Preserve `Civilization nvarchar(100) NULL`. Preserve `dbo.IMPORT_STAGING_CSV_RAW` unchanged as
the wide text/error boundary and `dbo.IMPORT_STAGING_CSV` unchanged as the typed validation
boundary.

## Index and statistics decision

The operator selected the retain-all option on 2026-07-25. Drop no KS4 index, add no replacement
index and run no consolidation experiment in this remediation. There are no exact duplicate
definitions. The three indexes led by `(GovernorID, SCANORDER)` overlap, but have different include
sets and observed-use histories; the clustered and nonclustered scan/governor indexes also share
keys without being equivalent physical structures. The expected insert/log/storage saving from
removing the most-overlapped zero-read candidate is small, while the short post-restart DMV window
does not prove its workload absent. This is a deliberate unchanged-design decision, not a deferred
index change.

Retain these exact definitions:

| Index | Workload reason for Phase 2 retention |
| --- | --- |
| `CIX_KS4_ScanOrder_Governor` | Physical scan/governor ordering used by scan-wide processing |
| `IX_KS4_AsOf_Governor` | Daily/WTD and date-derived governor workloads |
| `IX_KS4_Governor_ScanDate` | Governor history and date-range lookups |
| `IX_KSD4_Governor_ScanOrder` | Latest governor/history access with date/name/alliance coverage |
| `IX_KSD4_Gov_ScanOrder` | Narrow governor/scan/rank access |
| `IX_kingdomscandata4_ScanOrder_DESC` | Latest-scan discovery |
| `IX_KS4_Governor_ScanDate_ScanOrder` | Governor/date/scan history access |
| `IX_KingdomScanData4_GovernorID_ScanOrder_Covering` | Wide summary/profile history coverage |
| `IX_KingdomScanData4_ScanOrder_GovernorID` | Scan-cohort lookups |
| `IX_KingdomScanData4_GovernorID_ScanOrder` | Governor-history lookups |

The production package must improve on the method rehearsal by explicitly inventorying and
recreating standalone statistics for all three copied tables. The Phase 1 KS4 inventory includes
22 auto-created single-column statistics in addition to the ten index statistics. The package
will recreate equivalent stable user statistics on the same columns, with the source filter and
`NORECOMPUTE` properties, then run `FULLSCAN`. It will fail on unexpected statistic-column or
option drift. It must not rely on query-time auto-statistic creation.

## Affected objects and dependency order

Physical objects changed in one coordinated cutover:

1. `dbo.IMPORT_STAGING`
2. `dbo.KingdomScanData5`
3. `dbo.KingdomScanData4`

Preserved supporting contracts are `dbo.IMPORT_STAGING_CSV_RAW`,
`dbo.IMPORT_STAGING_CSV`, `dbo.KS4_UNO_SEQ`, the KS5 identity and primary key,
the KS4 sequence default, all ten KS4 indexes and `ImportProcUser SELECT`.

The 52 modules refreshed after the three-table swap, with views first, are:

- Views: `dbo.v_Active_Players`, `dbo.v_GovernorNames`,
  `dbo.v_KVK_Under50_Last3_WithLatest`, `dbo.v_MGE_SignupReview`,
  `dbo.v_PlayerLatestStats`, `dbo.vDaily_Helps`, `dbo.vDaily_PlayerExport`,
  `dbo.vDaily_RSSAssisted`, `dbo.vDaily_RSSGathered`,
  `dbo.vw_Governor_KVK_Summary_GlobalLatest`, `dbo.vWTD_Helps`,
  `dbo.vWTD_RSSAssisted`, `dbo.vWTD_RSSGathered`.
- Procedures: `dbo.CREATE_DELTA_TABLES`, `dbo.CREATE_THE_AVERAGES`,
  `dbo.DEADSSUMMARY_PROC`, `dbo.FIX_IMPORT_STAGING`, `dbo.GOVERNOR_NAMES_PROC`,
  `dbo.HEALEDSUMMARY_PROC`, `dbo.HEALEDSUMMARY_PROC_OPT`,
  `dbo.IMPORT_STAGING_PROC`, `dbo.KILLPOINTSSUMMARY_PROC`,
  `dbo.KILLSSUMMARY_PROC`, `dbo.KT4SUMMARY_PROC`, `dbo.KT5SUMMARY_PROC`,
  `dbo.POWERSUMMARY_PROC`, `dbo.RANGEDSUMMARY_PROC`,
  `dbo.Refresh_PlayerScanMeta`, `dbo.sp_ExcelOutput_ByKVK`,
  `dbo.sp_Loop_ExcelOutput_ByKVK`, `dbo.sp_Prep_ExcelOutputTable`,
  `dbo.sp_Prep_TargetTable`, `dbo.sp_Rebuild_ExcelForDashboard`,
  `dbo.sp_Rebuild_v_PlayerKVK_Last3`, `dbo.sp_RefreshInactiveGovernors`,
  `dbo.SP_Stats_for_Upload`, `dbo.sp_TARGETS_MASTER`, `dbo.SUMMARY_PROC`,
  `dbo.TARGETS`, `dbo.TARGETS_NEW`, `dbo.TEST`, `dbo.UPDATE_ALL`,
  `dbo.UPDATE_ALL2`, `dbo.UPDATE_RALLY_DATA`,
  `dbo.usp_BackfillKvkFinalReportCompletion`,
  `dbo.usp_GetLeadershipPlayerIdentityHistory`,
  `dbo.usp_GetLeadershipPlayerLastActive`,
  `dbo.usp_GetLeadershipPlayerLookupDirectory`,
  `dbo.usp_GetLeadershipPlayerReview`, `dbo.usp_GetPersonalStatsDaily`,
  `dbo.usp_LeadershipPlayerGovernorExists` and
  `dbo.usp_UpsertGovernorNameHistoryForScan`.

The physical Phase 2 cutover refreshes these definitions so metadata binds to the replacement
tables. It does not change result contracts. The type-dependent definition changes remain in their
authoritative Phase 3 and Phase 4 workstreams, but they are now mandatory parts of the same
coordinated release and must be implemented and rehearsed before production:

- Phase 3 procedures align parameters, variables, temporary objects and join expressions to the
  corrected integer/string types. Remove `TRY_CONVERT`, `CONVERT`, `CAST`, `CROSS APPLY` and
  padded-string compensation only where they exist solely for the old KS4/KS5/staging types.
- Phase 4 views apply the same rule and preserve aliases, output types, null behavior, aggregation,
  ordering and date-boundary semantics.
- `dbo.IMPORT_STAGING_PROC` retains validation, trimming and checked conversion at
  `dbo.IMPORT_STAGING_CSV_RAW`, the untrusted text/error boundary. It also retains conversions for
  intentionally text or float inputs. The separate Phase 3 database mutex, atomic scan allocation
  and duplicate-prevention work remains mandatory.
- `LTRIM`/`RTRIM`/`TRIM` remains where it deliberately implements blank-to-null, display
  normalization, name-key semantics or a target-width contract. It is removed only when it solely
  compensates for the old padded `nchar(255)` storage and bidirectional result comparison proves
  equivalence.
- Date conversions, civilization text-to-integer mapping and conversions for columns that remain
  float/text are not removed.

## Bot/DAL compatibility changes

Phase 5 code changes are required even though the external result contracts remain unchanged.
The bot is a separate Git, test and security-review target. The coordinated bot change is:

| Bot path | Required change | Contract/test guard |
| --- | --- | --- |
| `player_self_service/accounts_dal.py` | Use direct bigint `GovernorID` select/partition/join expressions and direct reads for newly typed integer metrics; retain checked conversions for unchanged float/text fields | Preserve the 22 columns, nulls, ascending SQL order, account-slot remap and the five compiled-ID scenario; update `tests/test_player_self_service_accounts_dal.py` |
| `player_self_service/governor_dashboard_dal.py` | Replace the float governor predicate with a direct bigint predicate and remove casts made redundant by final integer types | Preserve the exact-one-row 19-column contract, freshness/latest precedence and present/absent behavior; update `tests/test_governor_dashboard_dal.py` |
| `weekly_activity_importer.py` | Use direct bigint governor values and remove the obsolete `nvarchar(255)` alliance conversion while retaining blank-alliance normalization and the date conversion | Preserve allied-cohort and completion-state semantics; update `tests/test_weekly_activity_importer.py`, upload-route and audit-service coverage |
| `embed_offseason_stats.py` | Move the touched direct SQL into a dedicated stats-alert DAL and remove only the now-redundant `Power AS bigint` casts | Preserve daily/weekly summary totals, limits, ordering, fallbacks and all six leaderboard contracts; add focused DAL tests and retain the owning embed smoke |

No source edit is planned for `kvk_state.py`, `kvk/dal/kvk_history_dal.py`,
`stats/dal/fallback_import_dal.py` or `leadership_player_review/dal.py` while their documented
contracts remain unchanged. Their exact smoke/equivalence scenarios are still mandatory.

## Proposed implementation package

The operator authorised authoring and representative-copy rehearsal of the files in this list on
2026-07-25. Production execution remains a separate deployment approval.

1. `performance_remediation/kingdomscandata4/phase2/01_preflight.sql`
   - exact database/environment and schema hashes;
   - conversion, collision, width, nullability and column-order checks;
   - table, constraint, index, standalone-statistic, permission and 52-module inventory;
   - current row/scan/digest capture;
   - fresh `COPY_ONLY, CHECKSUM` backup receipt plus `RESTORE VERIFYONLY WITH CHECKSUM`;
   - no snapshot, foreign key, trigger, schema-bound module, signature, extended property or
     conflicting session;
   - capacity thresholds: at least 8 GB internal data-file free after controlled preallocation,
     at least 12 GB volume free, at least 4 GB reusable/growable log headroom and at least 1 GB
     tempdb free.
2. `migrations/20260725_001_kingdomscandata4_shadow_type_remediation.sql`
   - high-risk/data-change migration metadata and drift guards;
   - acquire `K98:KingdomScanData4:Migration` exclusive application lock;
   - require bot/import/admin SQL entry points stopped and no conflicting user session;
   - create the three exact typed shadows;
   - copy once in order staging, KS5, KS4 using explicit columns and checked conversions;
   - preserve/reseed KS5 identity and recreate its clustered primary key;
   - recreate all ten KS4 indexes and all captured standalone statistics;
   - copy the KS4 permission;
   - verify shadow counts and normalized digests;
   - transactionally rename canonical tables to `_Phase2_Old`, new tables to canonical in
     staging, KS5, KS4 order;
   - refresh the 13 views first and the other 39 modules second.
3. `performance_remediation/kingdomscandata4/phase2/02_verify.sql`
   - exact schema/type/order/nullability/default/identity/computed-column assertions;
   - row, scan, material-value and normalized digest reconciliation;
   - index, statistic, permission and module-definition/compile assertions;
   - `DBCC CHECKTABLE` for all three canonical tables;
   - Query Store/plan error, blocking, deadlock, log, tempdb and disk receipts;
   - read-only critical-path smoke before application restart.
4. `migrations/rollback/20260725_001_kingdomscandata4_shadow_type_remediation_rollback.sql`
   - usable only before application/import restart and only when no post-cutover write occurred;
   - require current objects to match the verified forward digests and retained originals to
     match baseline;
   - transactionally rename current tables to `_Phase2_Failed`, originals back to canonical;
   - refresh all 52 modules and verify original schema, rows, digests, indexes, permission and
     `DBCC CHECKTABLE`.
5. `performance_remediation/kingdomscandata4/phase2/03_finalize.sql`
   - run only after verification is accepted and before application restart;
   - drop the three `_Phase2_Old` tables, rename temporary default/PK constraints to canonical
     names, rerun metadata checks, and record the irreversible transition to backup/restore
     recovery.
6. `performance_remediation/kingdomscandata4/phase2/04_recovery_runbook.md`
   - after any post-cutover write, never use the metadata-swap rollback;
   - stop application/import/admin entry points and take a tail-log backup;
   - restore the fresh pre-change copy-only full plus required log chain to a separately named
     recovery database with `STOPAT` immediately before cutover;
   - verify it before any production replacement;
   - replace production only with explicit operator acceptance of the post-cutover-write RPO;
     otherwise apply a reviewed forward fix.
7. Update the three `sql_schema` snapshots and the Phase 2 evidence/readme files only after the
   migration definitions are final.

The Phase 3 procedure/import and Phase 4 view changes will use the existing canonical
`sql_schema` module files and migration conventions. The four Phase 5 bot changes above will be
prepared in `C:\discord_file_downloader` on its own remediation branch. The complete sequence is:

1. rehearse the Phase 2 shadow migration and early rollback with the current compatible module
   definitions;
2. implement and benchmark the Phase 3 procedures/import path;
3. implement and benchmark the Phase 4 views;
4. implement and test the four Phase 5 bot paths;
5. rehearse the combined SQL package and bot smoke suite from a fresh representative restore;
6. deploy the complete SQL release during the maintenance window, verify it before application
   restart, then deploy/start the matching bot revision; and
7. if early rollback is triggered, restore the original SQL modules/tables before starting the
   old bot revision. After any post-cutover write, use the documented forward-fix or backup/log
   recovery branch rather than metadata-swap rollback.

## Deployment and rollback gates

- Reserve a 30-minute maintenance window. The target pre-restart forward/verification outage is
  at most 10 minutes; the representative full guarded path was 45.780 seconds.
- Trigger early rollback before application restart for any conversion/digest mismatch, missing
  row/index/statistic/permission, compile failure, `DBCC` error, unexpected lock/deadlock, or
  failure to finish pre-restart validation within 10 minutes.
- The rehearsed early rollback target is at most 5 minutes; the full guarded path was 34.255
  seconds.
- Forward measured 1,351.15 MB used-log growth, 62.37 MB tempdb allocation growth and an
  8,124.28 MB data-file/volume allocation caused by controlled 8 GB preallocation. Actual used
  data increased by approximately 518.69 MB while old and new tables coexisted.
- Rollback measured 2.56 MB used-log growth and 62.19 MB tempdb allocation growth with no
  data/log file growth.
- Production preallocation occurs before outage. Production receipts must capture actual outage,
  metadata-swap time, lock waits, deadlocks, file growth, log generated, tempdb and volume deltas.

## Before/after acceptance matrix

| Suite | Exact after requirement |
| --- | --- |
| Conversion/width/drift | Repeat Phase 1 conversion, collision, width and schema guards; all remain zero/pass |
| Row/value reconciliation | KS4 394,506 and KS5 394,526 on the representative seed; identical normalized digests and scans |
| Table contract | Exact final types, unchanged nullability/order, persisted `AsOfDate`, KS5 identity, KS4 sequence default |
| Index/statistics | All ten named KS4 indexes unchanged, KS5 PK and one-for-one standalone-statistic coverage; no consolidation experiment |
| Modules | All 52 refresh/compile; changed Phase 3/4 definitions pass bidirectional result comparison with no result metadata drift |
| `UPDATE_ALL2` functional | Repeat normal, boundary/Unicode/optional blank, invalid, corrected retry, Phase-B failure and simultaneous concurrency scenarios |
| Committed import | Same ordinal 0 plus fresh-restore measured ordinals 1-5; 411 final rows, no duplicates, same material digest and filesystem hash |
| Summary | Same `SUMMARY_PROC` warm-up/five-run suite and selected components; stable 2,374-row digest |
| Metadata/views | Same `Refresh_PlayerScanMeta` full/incremental/no-op and complete materialization of latest, daily, WTD and global-latest views |
| Leadership and direct DAL | Same pinned governor/date/day parameters, five compiled account IDs, result aliases/types/null/order and one warm-up/five measured runs |
| Query Store shortlist | Rerun all 12 mapped query/plan owner scenarios, including 143117/16603 affected-alias aggregation |
| Bot unit/contract smoke | Run the focused tests for the four changed bot paths plus every scenario in `bot_dal_contract_map.md`; all observable contracts remain identical |
| Forward/rollback | Fresh-seed forward, verification and early rollback must pass repeatedly without snapshot; final run also exercises the backup/restore branch |

Any correctness difference, deadlock, unexplained plan failure or contract drift fails Phase 2.
Investigate any median duration, CPU, reads or writes regression above 20%; accept it only with an
evidence-backed explanation and no critical-path harm.

## Security review target

Run a SQL repository Codex Security **Changes** review from the approved base (`main`) to the
remediation head after the coordinated SQL package and evidence are complete. The migration,
backup, permission, application-lock, dynamic SQL, import and file-growth boundaries are in scope.
Run a separate bot-repository Codex Security **Changes** review from that repository's `main` to
its remediation head after the four bot changes and tests are complete. A full or Deep scan is not
selected for either routine Git-backed change set.

## Approval receipt

Approved by the operator on 2026-07-25: this exact shadow-copy package, three-table contract,
retain-all-index decision, standalone-statistics preservation, mandatory Phase 3/4 SQL-module
alignment, four-path Phase 5 bot/DAL change, coordinated deployment order, 30-minute maintenance
window, pre-restart early rollback and post-write backup/restore recovery branch.

This approval authorises implementation and rehearsal against the representative non-production
copy. It does not authorise production deployment, dropping the retained pristine snapshot, or
discarding operator-held raw evidence.
