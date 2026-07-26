# Phase 1 closure matrix

Status updated 2026-07-26. Phase 1 collection, functional rehearsal, committed-import,
scheduler/serialization, Query Store, bot/DAL contracts and exact migration/rollback rehearsal
are complete. The formal Phase 1 gate is closed. The operator approved the exact Phase 2
implementation/rehearsal plan on 2026-07-25. Representative-copy forward, drift-refusal,
rollback, recovery, workload and irreversible-finalization rehearsals and the final SQL Changes
security review are complete. The self-contained delivery-history retryability gap and its final
61-file Changes review are also closed. Production execution remains separately gated.

| Object / path | Classification | Required resolution | Phase | Status |
| --- | --- | --- | ---: | --- |
| `dbo.IMPORT_STAGING_CSV_RAW` | Upstream raw landing | Preserve raw/error boundary; validate file/source contract | 1, 3 | Raw boundary retained; invalid numeric, blank optional, Unicode and maximum-width fixtures tested |
| `dbo.IMPORT_STAGING_CSV` | Upstream typed boundary | Validate conversion/rejection behavior and final types | 1, 3 | `bigint`/`int` and `nvarchar(200/100)` boundary locked; width/Unicode/invalid behavior passed |
| `dbo.IMPORT_STAGING` | Upstream canonical staging | Remove float/string mismatch after proof | 1, 3 | Live float/`nchar(255)` mismatch confirmed; coordinated migration pending |
| `dbo.IMPORT_STAGING_PROC` | Upstream writer/orchestrator | Fix typed mapping, concurrency, idempotency and file handling | 1, 3 | Success/invalid/retry/concurrency behavior captured; no explicit mutex; Phase 3 correction still required |
| `dbo.FIX_IMPORT_STAGING` | Upstream legacy writer helper | Establish runtime use; align or remove in coordinated release | 1, 3 | Static definition reviewed |
| `dbo.KingdomScanData5` | Upstream promotion table | Align final contract and migration | 1, 2, 3 | Live float/`nchar(255)` mismatch confirmed; coordinated migration pending |
| `dbo.UPDATE_ALL` | Direct writer | Establish runtime use; align or remove in coordinated release | 1, 3 | Static write found |
| `dbo.UPDATE_ALL2` | Direct writer/orchestrator | Align types; separate unsafe maintenance; prove outputs/retry | 1, 3 | Functional scenarios and comparable committed warm-up plus measured ordinals 1-5 passed; stable 411-row material digest and 195,362.014 ms measured median; first ordinal-3 attempt excluded with raw-receipt retention limitation recorded |
| `dbo.KingdomScanData4` | Remediation centre | Prove data, select migration, reconcile all rows and indexes | 1, 2 | Phase 2 representative-copy implementation passed five forward runs, three production-usable early rollbacks, separately named backup/restore recovery, expected stale-receipt drift refusal before any retained-table drop, clean irreversible finalization, exact digests, ten retained indexes, permission/module/DBCC checks, retryable migration-history reset and no snapshot rollback; production remains gated |
| `dbo.CREATE_DELTA_TABLES` | Direct SQL reader | Align variables/temp/output and prove results | 3 | Static reference found |
| `dbo.CREATE_THE_AVERAGES` | Direct SQL reader | Align variables/temp/output and prove results | 3 | Static reference found |
| `dbo.DEADSSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Five-run stable component baseline captured; after equivalence pending |
| `dbo.HEALEDSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Five-run stable component baseline captured; after equivalence pending |
| `dbo.HEALEDSUMMARY_PROC_OPT` | Summary reader | Establish canonical/runtime use; benchmark/equivalence | 3 | Static reference found |
| `dbo.KILLPOINTSSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Static reference found |
| `dbo.KILLSSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Static reference found |
| `dbo.KT4SUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Static reference found |
| `dbo.KT5SUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Static reference found |
| `dbo.POWERSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Five-run stable component baseline captured; after equivalence pending |
| `dbo.RANGEDSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Five-run stable component baseline captured; after equivalence pending |
| `dbo.SUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Phase 2 type-migration after-run stable at 167,154.476 ms median with the exact 2,374-row digest; Phase 3 cleanup equivalence remains pending |
| `dbo.Refresh_PlayerScanMeta` | Metadata writer | Validate full/incremental/no-op plans and consistency | 3 | Five-run full/incremental/no-op baselines stable; after equivalence pending |
| `dbo.GOVERNOR_NAMES_PROC` | Direct reader | Align final string/ID contract and prove output | 3 | Static reference found |
| `dbo.sp_ExcelOutput_ByKVK` | Direct reader/downstream writer | Align joins/output and prove exports | 3 | Static reference found |
| `dbo.sp_Loop_ExcelOutput_ByKVK` | Transitive orchestrator | Map calls and prove loop behavior | 3 | Static reference found |
| `dbo.sp_Prep_ExcelOutputTable` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.sp_Prep_TargetTable` | Direct reader/downstream writer | Align dynamic SQL/types and prove output | 3 | Static reference found |
| `dbo.sp_Rebuild_ExcelForDashboard` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.sp_Rebuild_v_PlayerKVK_Last3` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.sp_RefreshInactiveGovernors` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.SP_Stats_for_Upload` | Direct reader/downstream writer | Align types and prove upload output | 3 | Static reference found |
| `dbo.sp_TARGETS_MASTER` | Direct reader/downstream writer | Align types and prove target output | 3 | Static reference found |
| `dbo.TARGETS` | Direct reader | Replace float scan variables and prove results | 3 | Static reference found |
| `dbo.TARGETS_NEW` | Direct reader | Align temp/output shapes and prove results | 3 | Static reference found |
| `dbo.TEST` | Direct reader/dead candidate | Establish runtime ownership before removal or alignment | 1, 3 | Static reference found |
| `dbo.UPDATE_RALLY_DATA` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.usp_BackfillKvkFinalReportCompletion` | Direct reader | Prove historical/backfill behavior | 3 | Static reference found |
| `dbo.usp_GetLeadershipPlayerIdentityHistory` | Direct reader | Prove ID/string/date result contract | 3, 5 | Static reference found |
| `dbo.usp_GetLeadershipPlayerLastActive` | Direct reader | Prove ID/date result contract | 3, 5 | High-activity 720-day five-run baseline stable; bot caller mapping pending |
| `dbo.usp_GetLeadershipPlayerLookupDirectory` | Direct reader | Prove ID/string/date result contract | 3, 5 | 720-day directory five-run baseline stable; bot caller mapping pending |
| `dbo.usp_GetLeadershipPlayerReview` | Direct reader | Prove large contract, plans and bot mapping | 3, 5 | Static reference found |
| `dbo.usp_GetPersonalStatsDaily` | Direct reader | Prove stats contract and bot mapping | 3, 5 | Static reference found |
| `dbo.usp_LeadershipPlayerGovernorExists` | Direct reader | Prove exact ID lookup contract | 3, 5 | Existing/absent five-run baselines stable; bot caller mapping pending |
| `dbo.usp_UpsertGovernorNameHistoryForScan` | Direct reader/downstream writer | Remove obsolete conversion; prove idempotency | 3 | Query Store 143117/16603 mapped here; high-cost affected-alias aggregation requires after benchmark |
| `dbo.STAGING_STATS` | Downstream staging table | Align remaining float metrics and joins | 3 | Live mixed float/`bigint` contract confirmed |
| `dbo.EXCEL_FOR_DASHBOARD` | Downstream output table | Prove bigint alignment and row/value equivalence | 3 | Live `Gov_ID bigint` output alignment confirmed |
| `dbo.STATS_FOR_UPLOAD` | Downstream output table | Prove bigint alignment and export contract | 3, 5 | Live `Gov_ID bigint` output alignment confirmed |
| `dbo.v_Active_Players` | Direct view | Remove obsolete cast only after contract proof | 4, 5 | Static reference found |
| `dbo.v_GovernorNames` | Direct view | Align ID/string semantics and consumers | 4, 5 | Static reference found |
| `dbo.v_KVK_Under50_Last3_WithLatest` | Direct view | Align types and prove range/latest output | 4, 5 | Static reference found |
| `dbo.v_MGE_SignupReview` | Direct view | Align types and prove latest output | 4, 5 | Static reference found |
| `dbo.v_PlayerLatestStats` | Direct view | Align types and prove latest output | 4, 5 | Five-run complete-materialization baseline stable; consumer mapping pending |
| `dbo.vDaily_Helps` | Direct view | Align types and prove daily boundaries | 4, 5 | Five-run materialization baseline stable; after equivalence pending |
| `dbo.vDaily_PlayerExport` | Direct view | Align output contract and exports | 4, 5 | Phase 2 isolated after-run stable at 603.284 ms median for 223,386 rows and exact digest; Phase 4 cleanup and export consumer verification remain pending |
| `dbo.vDaily_RSSAssisted` | Direct view | Align types and prove daily boundaries | 4, 5 | Five-run materialization baseline stable; after equivalence pending |
| `dbo.vDaily_RSSGathered` | Direct view | Align types and prove daily boundaries | 4, 5 | Five-run materialization baseline stable; after equivalence pending |
| `dbo.vWTD_Helps` | Direct view | Align types and prove week boundaries | 4, 5 | Five-run materialization baseline stable; after equivalence pending |
| `dbo.vWTD_RSSAssisted` | Direct view | Align types and prove week boundaries | 4, 5 | Five-run materialization baseline stable; after equivalence pending |
| `dbo.vWTD_RSSGathered` | Direct view | Align types and prove week boundaries | 4, 5 | Five-run materialization baseline stable; after equivalence pending |
| `dbo.vw_Governor_KVK_Summary_GlobalLatest` | Direct view | Align latest-scan contract and consumers | 4, 5 | Five-run 411-row materialization baseline stable; consumer mapping pending |
| `embed_offseason_stats.py` | Bot direct reader | Map parameters/types/output and move SQL if touched | 5 | Contract map complete; coordinated implementation will extract the touched SQL to a stats-alert DAL, remove redundant Power casts and preserve summary/leaderboard outputs with focused tests |
| `weekly_activity_importer.py` | Bot direct reader/import consumer | Prove overlay/import behavior and types | 5 | Contract map complete; coordinated implementation will use direct bigint IDs and remove obsolete alliance-width conversion while preserving blank/date/cohort/completion semantics and mapped smokes |
| `kvk_state.py` | Bot direct reader | Prove scan-order mapping and move SQL if touched | 5 | Complete: all transitive consumers, max-scan/latest-KVK/ProcConfig result contracts and state smoke retained |
| `kvk/dal/kvk_history_dal.py` | Bot DAL direct reader | Prove row mapping and range behavior | 5 | Complete: service owner, candidate/legacy/modern/rank parameters, full typed outputs, null/order differences and range smokes retained |
| `stats/dal/fallback_import_dal.py` | Bot DAL direct reader | Prove fallback overlay and null/type behavior | 5 | Complete: owner, ordered 35-column DataFrame, control/status contracts and retained 411-row overlay smoke mapped |
| `player_self_service/accounts_dal.py` | Bot DAL direct reader | Prove account lookup contract | 5 | Contract map complete; coordinated implementation will remove obsolete GovernorID/new-integer conversions while preserving the 22-column contract, ascending SQL/service slot remap and five-ID Query Store smoke |
| `player_self_service/governor_dashboard_dal.py` | Bot DAL direct reader | Prove dashboard freshness/result contract | 5 | Contract map complete; coordinated implementation will replace the float predicate and obsolete new-integer casts while preserving the exact-one-row 19-column contract, latest precedence and present/absent smokes |
| `leadership_player_review/dal.py` | Bot DAL procedure consumer | Prove exact-ID existence/result contract | 5 | Complete: six procedure entry points, fixed result-set ordinals/shapes/nulls/enums/order and exact lookup/existence/review/identity/KVK/last-active smokes retained |
| SQL Agent job steps | Operational dependency | Collect job definitions/history and schedule overlap | 1 | Complete: all five jobs captured; four are backup/prune jobs and the fifth is standard `syspolicy_purge_history`; none invokes the import, 200/200 retained targeted outcomes succeeded and no overlaps were returned |
| Bot `UPDATE_ALL2` invocation and serialization | Operational dependency | Prove every bot entry point and whether guards cover it | 1, 3 | Complete: monitored-channel imports hold one process-wide `processing_lock`, but admin `/run_sql_proc` calls the same runner without that lock; direct SQL also bypasses bot guards, so overlap remains possible and Phase 3 requires a database mutex |
| Query Store / plan cache | Workload dependency | Collect real callers, plans, metrics and regressions | 1 | Complete: 12/12 shortlisted pairs matched owners; 143117 retained as affected-alias aggregation; pinned procedure scenarios and five compiled accounts-DAL IDs map to exact after suites |
| Cross-database references / synonyms | Schema dependency | Collect and reconcile with repository scan | 1 | No synonyms or external-server references found; repository reconciliation complete |

## Phase 1 gate summary

| Gate | Status |
| --- | --- |
| Environment, conversion and no-narrowing contract | Complete |
| Backup/storage/restored-copy readiness | Complete |
| Controlled summary/metadata/view/selected lookup baseline | Complete |
| `UPDATE_ALL2` functional scenarios | Complete |
| Comparable committed-import 1+5 baseline | Complete: warm-up and measured ordinals 1-5 passed; failed ordinal-3 transport attempt excluded with retention limitation recorded |
| Remaining Query Store owner/parameter map | Complete: all 12 shortlisted pairs have matched owners, representative parameters/scenarios and named after baselines |
| SQL Agent schedule/history and external serialization | Complete: no Agent job or captured Windows task schedules the import; normal upload workers serialize in-process, but `/run_sql_proc` and direct SQL bypass that boundary, proving external overlap remains possible |
| Complete transitive bot/DAL result-contract map | Complete: all eight paths have transitive owners, SQL parameter contracts, result aliases/types/null/order assumptions and exact smoke scenarios; four targeted bot changes and four source-unchanged smoke paths are explicitly selected |
| Exact migration/rollback design and timed rehearsal | Complete: direct ALTER rejected by dependency/rewrite evidence; shadow forward and production-usable rollback passed against the same run ID with exact digests and no snapshot |

The operator approved the exact affected objects, tests, recovery branches and deployment order
in the Phase 2 approval checkpoint on 2026-07-25. Phase 2 implementation and all approved
representative-copy rehearsals are complete. The final Changes review closed 50/50 file receipts
and 17/17 candidate ledgers with zero reportable findings. The later complete-delivery review
closed 61/61 file receipts with zero reportable findings after the delivery-history addition and
ordered Phase 3–5 roadmap were included. Production execution remains separately gated and must
confirm current effective grants and the SQL-host backup-folder ACL before the migration window.

## 2026-07-26 security follow-up

The completed working-tree Changes review found no reportable vulnerability. Six candidates were
rejected after validation and attack-path analysis. One benchmark-evidence candidate remained
deferred because this workstation cannot read the SQL host's `C:\sql_backup` ACL or file hash:
the administrative share denies this identity, WinRM is unavailable, and Windows-authenticated
SQL metadata access stops at SSPI before executing a query.

The benchmark seed workflow now removes that ACL dependency from the restore decision.
`14_create_update_all2_benchmark_seed_backup.sql` records the trusted `msdb` backup identity, and
`15_restore_update_all2_benchmark_database.sql` requires the retained receipt's exact
`BackupSetGUID` and compares that identity with `RESTORE HEADERONLY`
and completes `RESTORE VERIFYONLY` before `SINGLE_USER` or `WITH REPLACE`. It then verifies the
actual `msdb.restorehistory` backup-set ID/GUID plus the stable restored family GUID before
benchmark use, and records a non-null target database GUID. The target database GUID is not
compared with the source backup BindingID because the restored benchmark database has its own
database identity. This closes the verification-to-restore replacement window at the execution
boundary.
Static repository and ordering validation passed. The representative hardened
seed/restore/import path then passed on the SQL host with approved
`BackupSetGUID` `77292DB9-81A9-4C51-8C8C-FB1B00ECF82C`, a repeatable
58-second corrected restore, a 141-second committed ordinal 1, exact
394,917/394,937 final rows at scan 1021, zero scan-1071 rows and the locked
material digest
`D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463`.
The two superseded restore attempts are retained as negative evidence, the
pristine snapshot remains retained, and production execution remains
prohibited. This follow-up is closed.
