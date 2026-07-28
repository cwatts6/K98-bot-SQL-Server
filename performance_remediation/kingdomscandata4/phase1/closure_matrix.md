# Phase 1 closure matrix

Status updated 2026-07-27. Phase 1 collection, functional rehearsal, committed-import,
scheduler/serialization, Query Store, bot/DAL contracts and exact migration/rollback rehearsal
are complete. The formal Phase 1 gate is closed. The operator approved the exact Phase 2
implementation/rehearsal plan on 2026-07-25. Representative-copy forward, drift-refusal,
rollback, recovery, workload and irreversible-finalization rehearsals and the final SQL Changes
security review are complete. The self-contained delivery-history retryability gap and its final
61-file Changes review are also closed. Phase 3 implementation, ordered representative-copy
forward/rollback/reapply rehearsal and final Changes review are complete. Phase 4 isolated
forward/rollback/reapply, equivalence, benchmark, actual-plan, mapped consumer, repository, and
final Changes gates passed on 2026-07-27. Phase 4 is closed.
Production execution remains separately gated.

| Object / path | Classification | Required resolution | Phase | Status |
| --- | --- | --- | ---: | --- |
| `dbo.IMPORT_STAGING_CSV_RAW` | Upstream raw landing | Preserve raw/error boundary; validate file/source contract | 1, 3 | Raw boundary retained; invalid numeric, blank optional, Unicode and maximum-width fixtures tested |
| `dbo.IMPORT_STAGING_CSV` | Upstream typed boundary | Validate conversion/rejection behavior and final types | 1, 3 | `bigint`/`int` and `nvarchar(200/100)` boundary locked; width/Unicode/invalid behavior passed |
| `dbo.IMPORT_STAGING` | Upstream canonical staging | Remove float/string mismatch after proof | 1, 3 | Complete: Phase 2 type contract consumed by the Phase 3 import core; forward/rollback/reapply verified |
| `dbo.IMPORT_STAGING_PROC` | Upstream writer/orchestrator | Fix typed mapping, concurrency, idempotency and file handling | 1, 3 | Complete: public wrapper, private core, mutex, atomic allocation, digest receipt, duplicate refusal and failure paths passed |
| `dbo.FIX_IMPORT_STAGING` | Upstream legacy writer helper | Establish runtime use; align or remove in coordinated release | 1, 3 | Complete: retained legacy entry point uses the shared private core and passed committed import |
| `dbo.KingdomScanData5` | Upstream promotion table | Align final contract and migration | 1, 2, 3 | Complete for Phase 3: Phase 2 final types retained and committed import row/value invariants passed |
| `dbo.UPDATE_ALL` | Direct writer | Establish runtime use; align or remove in coordinated release | 1, 3 | Complete: retained legacy entry point passed durable import invariants through the shared core |
| `dbo.UPDATE_ALL2` | Direct writer/orchestrator | Align types; separate unsafe maintenance; prove outputs/retry | 1, 3 | Complete: direct, duplicate, simultaneous, invalid/corrected and controlled Phase-B scenarios passed with one winner and stable durable output |
| `dbo.KingdomScanData4` | Remediation centre | Prove data, select migration, reconcile all rows and indexes | 1, 2 | Phase 2 representative-copy implementation passed five forward runs, three production-usable early rollbacks, separately named backup/restore recovery, expected stale-receipt drift refusal before any retained-table drop, clean irreversible finalization, exact digests, ten retained indexes, permission/module/DBCC checks, retryable migration-history reset and no snapshot rollback; production remains gated |
| `dbo.CREATE_DELTA_TABLES` | Direct SQL reader | Align variables/temp/output and prove results | 3 | Complete: aligned definition refreshed and compiled against final types |
| `dbo.CREATE_THE_AVERAGES` | Direct SQL reader | Align variables/temp/output and prove results | 3 | Complete: retained definition refreshed and compiled against final types |
| `dbo.DEADSSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: cleanup included in the repeated controlled summary suite |
| `dbo.HEALEDSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: cleanup included in the repeated controlled summary suite |
| `dbo.HEALEDSUMMARY_PROC_OPT` | Summary reader | Establish canonical/runtime use; benchmark/equivalence | 3 | Complete: retained/aligned definition refreshed and compiled |
| `dbo.KILLPOINTSSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: cleanup included in the repeated controlled summary suite |
| `dbo.KILLSSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: cleanup included in the repeated controlled summary suite |
| `dbo.KT4SUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: cleanup included in the repeated controlled summary suite |
| `dbo.KT5SUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: cleanup included in the repeated controlled summary suite |
| `dbo.POWERSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: cleanup included in the repeated controlled summary suite |
| `dbo.RANGEDSUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: cleanup included in the repeated controlled summary suite |
| `dbo.SUMMARY_PROC` | Summary reader | Remove obsolete conversions; benchmark/equivalence | 3 | Complete: aligned definition passed controlled result/performance reconciliation |
| `dbo.Refresh_PlayerScanMeta` | Metadata writer | Validate full/incremental/no-op plans and consistency | 3 | Complete: final definition refreshed/compiled and metadata workload remained stable |
| `dbo.GOVERNOR_NAMES_PROC` | Direct reader | Align final string/ID contract and prove output | 3 | Static reference found |
| `dbo.sp_ExcelOutput_ByKVK` | Direct reader/downstream writer | Align joins/output and prove exports | 3 | Complete: aligned definition refreshed/compiled with external contract preserved |
| `dbo.sp_Loop_ExcelOutput_ByKVK` | Transitive orchestrator | Map calls and prove loop behavior | 3 | Static reference found |
| `dbo.sp_Prep_ExcelOutputTable` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.sp_Prep_TargetTable` | Direct reader/downstream writer | Align dynamic SQL/types and prove output | 3 | Static reference found |
| `dbo.sp_Rebuild_ExcelForDashboard` | Direct reader/downstream writer | Align types and prove output | 3 | Complete: aligned definition refreshed/compiled with external contract preserved |
| `dbo.sp_Rebuild_v_PlayerKVK_Last3` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.sp_RefreshInactiveGovernors` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.SP_Stats_for_Upload` | Direct reader/downstream writer | Align types and prove upload output | 3 | Static reference found |
| `dbo.sp_TARGETS_MASTER` | Direct reader/downstream writer | Align types and prove target output | 3 | Complete: aligned definition refreshed/compiled with external contract preserved |
| `dbo.TARGETS` | Direct reader | Replace float scan variables and prove results | 3 | Complete: scan variables aligned and definition refreshed/compiled |
| `dbo.TARGETS_NEW` | Direct reader | Align temp/output shapes and prove results | 3 | Complete: temp/output contract aligned and definition refreshed/compiled |
| `dbo.TEST` | Direct reader/dead candidate | Establish runtime ownership before removal or alignment | 1, 3 | Complete: retained and aligned; definition refreshed/compiled rather than removed |
| `dbo.UPDATE_RALLY_DATA` | Direct reader/downstream writer | Align types and prove output | 3 | Static reference found |
| `dbo.usp_BackfillKvkFinalReportCompletion` | Direct reader | Prove historical/backfill behavior | 3 | Complete: aligned definition refreshed/compiled against final contracts |
| `dbo.usp_GetLeadershipPlayerIdentityHistory` | Direct reader | Prove ID/string/date result contract | 3, 5 | Phase 3 complete: definition refreshed/compiled; mapped Phase 5 bot smoke remains mandatory |
| `dbo.usp_GetLeadershipPlayerLastActive` | Direct reader | Prove ID/date result contract | 3, 5 | Phase 3 complete: aligned definition refreshed/compiled; mapped 720-day Phase 5 smoke retained |
| `dbo.usp_GetLeadershipPlayerLookupDirectory` | Direct reader | Prove ID/string/date result contract | 3, 5 | Phase 3 complete: aligned definition refreshed/compiled; mapped 720-day Phase 5 smoke retained |
| `dbo.usp_GetLeadershipPlayerReview` | Direct reader | Prove large contract, plans and bot mapping | 3, 5 | Phase 3 complete: pinned six-result-set workload passed one warm-up plus five measured runs |
| `dbo.usp_GetPersonalStatsDaily` | Direct reader | Prove stats contract and bot mapping | 3, 5 | Phase 3 complete: retained definition refreshed/compiled; mapped Phase 5 smoke remains mandatory |
| `dbo.usp_LeadershipPlayerGovernorExists` | Direct reader | Prove exact ID lookup contract | 3, 5 | Phase 3 complete: aligned definition refreshed/compiled; mapped present/absent Phase 5 smoke retained |
| `dbo.usp_UpsertGovernorNameHistoryForScan` | Direct reader/downstream writer | Remove obsolete conversion; prove idempotency | 3 | Complete: aligned definition refreshed/compiled and mapped workload passed |
| `dbo.STAGING_STATS` | Downstream staging table | Align remaining float metrics and joins | 3 | Complete: three directly written contracts converted with exact 2,371/9/411 verification |
| `dbo.EXCEL_FOR_DASHBOARD` | Downstream output table | Prove bigint alignment and row/value equivalence | 3 | Complete: existing `Gov_ID bigint` contract retained and dependent modules compiled |
| `dbo.STATS_FOR_UPLOAD` | Downstream output table | Prove bigint alignment and export contract | 3, 5 | Phase 3 complete: existing `Gov_ID bigint` contract retained; Phase 5 export smoke remains mandatory |
| `dbo.v_Active_Players` | Direct view | Remove obsolete cast only after contract proof | 4, 5 | Phase 4 rehearsal passed 411-row value/metadata equivalence and stable five-run materialization; result-side cast retained because it preserves nullable metadata |
| `dbo.v_GovernorNames` | Direct view | Align ID/string semantics and consumers | 4, 5 | Definition retained; 2,371-row stable five-run materialization and mapped consumers passed |
| `dbo.v_KVK_Under50_Last3_WithLatest` | Direct view | Align types and prove range/latest output | 4, 5 | Definition retained; 19-row stable five-run materialization passed with latest/range semantics unchanged |
| `dbo.v_MGE_SignupReview` | Direct view | Align types and prove latest output | 4, 5 | Direct-bigint join cleanup passed 56-row forward/rollback/reapply value/metadata equivalence and stable five-run materialization |
| `dbo.v_PlayerLatestStats` | Direct view | Align types and prove latest output | 4, 5 | Definition retained; 2,371-row stable materialization plus profile/account consumers passed |
| `dbo.vDaily_Helps` | Direct view | Align types and prove daily boundaries | 4, 5 | Definition retained; 184-row stable five-run materialization and mapped stats-alert consumer tests passed |
| `dbo.vDaily_PlayerExport` | Direct view | Align output contract and exports | 4, 5 | 223,386-row forward/rollback/reapply equivalence, stable five-run materialization, 56-column export, and 30-day stats-window evidence passed; baseline level-1 hash spill recorded |
| `dbo.vDaily_RSSAssisted` | Direct view | Align types and prove daily boundaries | 4, 5 | Definition retained; 10-row stable five-run materialization and mapped stats-alert consumer tests passed |
| `dbo.vDaily_RSSGathered` | Direct view | Align types and prove daily boundaries | 4, 5 | Definition retained; 203-row stable five-run materialization and mapped stats-alert consumer tests passed |
| `dbo.vWTD_Helps` | Direct view | Align types and prove week boundaries | 4, 5 | Definition retained; 197-row stable five-run materialization and mapped stats-alert consumer tests passed |
| `dbo.vWTD_RSSAssisted` | Direct view | Align types and prove week boundaries | 4, 5 | Definition retained; one-row stable five-run materialization and mapped stats-alert consumer tests passed |
| `dbo.vWTD_RSSGathered` | Direct view | Align types and prove week boundaries | 4, 5 | Definition retained; 224-row stable five-run materialization and mapped stats-alert consumer tests passed |
| `dbo.vw_Governor_KVK_Summary_GlobalLatest` | Direct view | Align latest-scan contract and consumers | 4, 5 | Join-side bigint cleanup passed 411-row forward/rollback/reapply value/metadata equivalence and stable five-run materialization; result-side nullable-metadata cast retained |
| `dbo.vAllianceActivity_WeeklyCumulative` | Invalid unused legacy view | Retire only after SQL, repository and bot dependency proof | 4 | Operator-approved deferred cleanup passed zero-consumer/security-metadata proof and guarded isolated retirement; object remains absent after rollback/reapply and is never recreated |
| `embed_offseason_stats.py` | Bot direct reader | Map parameters/types/output and move SQL if touched | 5 | Contract map complete; coordinated implementation will extract the touched SQL to a stats-alert DAL, remove redundant Power casts and preserve summary/leaderboard outputs with focused tests |
| `weekly_activity_importer.py` | Bot direct reader/import consumer | Prove overlay/import behavior and types | 5 | Contract map complete; coordinated implementation will use direct bigint IDs and remove obsolete alliance-width conversion while preserving blank/date/cohort/completion semantics and mapped smokes |
| `kvk_state.py` | Bot direct reader | Prove scan-order mapping and move SQL if touched | 5 | Complete: all transitive consumers, max-scan/latest-KVK/ProcConfig result contracts and state smoke retained |
| `kvk/dal/kvk_history_dal.py` | Bot DAL direct reader | Prove row mapping and range behavior | 5 | Complete: service owner, candidate/legacy/modern/rank parameters, full typed outputs, null/order differences and range smokes retained |
| `stats/dal/fallback_import_dal.py` | Bot DAL direct reader | Prove fallback overlay and null/type behavior | 5 | Complete: owner, ordered 35-column DataFrame, control/status contracts and retained 411-row overlay smoke mapped |
| `player_self_service/accounts_dal.py` | Bot DAL direct reader | Prove account lookup contract | 5 | Contract map complete; coordinated implementation will remove obsolete GovernorID/new-integer conversions while preserving the 22-column contract, ascending SQL/service slot remap and five-ID Query Store smoke |
| `player_self_service/governor_dashboard_dal.py` | Bot DAL direct reader | Prove dashboard freshness/result contract | 5 | Contract map complete; coordinated implementation will replace the float predicate and obsolete new-integer casts while preserving the exact-one-row 19-column contract, latest precedence and present/absent smokes |
| `leadership_player_review/dal.py` | Bot DAL procedure consumer | Prove exact-ID existence/result contract | 5 | Complete: six procedure entry points, fixed result-set ordinals/shapes/nulls/enums/order and exact lookup/existence/review/identity/KVK/last-active smokes retained |
| SQL Agent job steps | Operational dependency | Collect job definitions/history and schedule overlap | 1 | Complete: all five jobs captured; four are backup/prune jobs and the fifth is standard `syspolicy_purge_history`; none invokes the import, 200/200 retained targeted outcomes succeeded and no overlaps were returned |
| Bot `UPDATE_ALL2` invocation and serialization | Operational dependency | Prove every bot entry point and whether guards cover it | 1, 3 | Complete: Phase 3 database mutex now serializes bot, admin and direct SQL paths; simultaneous-session proof produced one winner and one deterministic duplicate loser |
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

## Phase 3 gate summary

| Gate | Status |
| --- | --- |
| Frozen dependency and rollback contract | Complete: 52 modules and 39 Phase 3 procedure definitions |
| Import ownership and authorization | Complete: private role/helper chain, public-wrapper transaction guards, and no leaked locks |
| Atomic allocation and duplicate control | Complete: database mutex, cross-table allocator and digest receipt passed simultaneous-session proof |
| Forward/rollback/reapply | Complete on `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL` |
| Downstream persisted contracts | Complete: `PlayerScanMeta`, `SUMMARY_PROC_STATE` and direct `STAGING_STATS` columns aligned; broader legacy surface deliberately retained |
| Functional and mapped workloads | Complete: committed import, retry, direct/legacy, Phase-B failure, Query Store and module-refresh gates passed |
| Repository validation | Complete: Phase 3 contract test, SQL repository validation and `git diff --check` passed |
| Final Changes review | Complete with follow-up: scan `7ccf1007-269d-4470-94f0-638222312c5a` reported two Low/P3 mutable-path findings assigned to Phase 5 |

The final Phase 3 reviewed snapshot is
`codex-security-snapshot/v1:sha256:98d3c2f01c061c4a3557b5d2f43d0080b47cab9c9863279c8162f3dbb9d653a8`.
The two findings share one immutable, uniquely named file-handoff remediation spanning the bot
producer and SQL consumer. They block the combined release but do not block Phase 4 view work.

## Phase 4 gate summary

| Gate | Status |
| --- | --- |
| Inventory and obsolete-view decision | Complete: 13 retained mandatory views, 21 retained transitive SQL targets, mapped external consumers, and zero executable consumer/security metadata for the invalid weekly-cumulative view |
| Forward/rollback/reapply | Complete on `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`: 8 s / 7 s / 7 s with exact 411 / 56 / 223,386 / 411 changed-view rows |
| Value and metadata equivalence | Complete: row counts, bidirectional `EXCEPT`, aliases, ordinals, types, lengths, precision/scale, collation, and nullability passed in both directions |
| Full retained materialization | Complete: all 13 views and 21 retained transitive SQL targets refreshed, compiled, and materialized; 269 metadata rows captured |
| Performance stability | Complete: 78 executions (one warm-up plus five measured for each view), stable rows, and one normalized digest per view |
| Actual-plan evidence | Complete: five workloads materialized; exact grants, two coordinate-conversion warnings, two excessive-grant warnings, and the daily-export level-1 hash spill are recorded in `phase4/rehearsal_report.md` |
| Mapped consumer smokes | Complete: SQL/export/report materialization plus 164 focused offline bot/DAL tests passed |
| Repository validation | Complete: Phase 4 and inherited regression contract tests, SQL repository validation, and `git diff --check` passed |
| Final SQL Changes review | Complete: scan `e6ce0a1d-7aba-428a-b40a-61001c924143`, snapshot `codex-security-snapshot/v1:sha256:a00ac727cab59a0ed585b7e6f615a3391fc792d95a1165c624c0328e978a909b`, Deep off, 13/13 source-like worklist rows, zero deferrals, zero findings |

Production remained untouched. Phase 4 is closed. The post-scan changes are
limited to non-executable status and receipt documentation and do not change
the reviewed SQL or validation contracts.

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
