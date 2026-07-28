# Phase 3 affected-module contract

Status: frozen from SQL `main` commit `b6b0bc4` on 2026-07-26 before Phase 3 definition edits.

## Release boundary

PR #60 is merged into the SQL source-of-truth repository, and its Phase 2 package has passed the
representative-copy gate. Production remains on the pre-Phase-2 schema. That is intentional:
Phase 3 development and representative-copy rehearsal use the approved Phase 2 package, while
production receives the coordinated Phase 2, Phase 3 and Phase 4 SQL release only after Phases
3-5 and the combined release gate close.

## Exact dependency inventory

The Phase 2 preflight freezes 52 schema-bound or expression-dependent modules: 39 procedures and
13 views. Phase 3 owns the 39 procedure contracts below. The 13 views remain definition-unchanged
until Phase 4, but Phase 3 must compile/refresh them after changed procedure and table deployment.

Phase 3 additionally creates three denied security-control helpers:
`dbo.ACQUIRE_KS4_IMPORT_LOCK`, `dbo.IMPORT_STAGING_PROC_CORE` and
`dbo.HASH_KS4_IMPORT_ARCHIVE_FILE`. They are not among the 52 Phase 2 frozen dependents and have
no pre-Phase-3 rollback definitions. Verification refreshes the 52 frozen modules plus these
three helpers (55 modules total).

### Phase 3 procedure definitions

The SHA-256 values identify the exact rollback source in `sql_schema/` at commit `b6b0bc4`.

| Procedure | Baseline / acceptance assignment | Pre-Phase-3 SHA-256 |
| --- | --- | --- |
| `dbo.CREATE_DELTA_TABLES` | Committed `UPDATE_ALL2` 0+1-5 suite; downstream row/value reconciliation | `5CF42BCF65D5687EAF8F01266468DBA9E4B419CA1D88D086B04922263E2E98ED` |
| `dbo.CREATE_THE_AVERAGES` | Committed `UPDATE_ALL2` 0+1-5 suite; Query Store 49472/4949 | `84CCD9CE2C49E2150E09E51AAAAA7C7780098AAA8FBD272DD155432D1E1A4140` |
| `dbo.DEADSSUMMARY_PROC` | Full history; 2,374 rows; Phase 2 median 18,572.113 ms | `01A434F0FDE87D35674326BFFA26FCB0BA7AEC0BC739871CE614FA009AFED83A` |
| `dbo.FIX_IMPORT_STAGING` | Direct legacy staging path; date, duplicate, retry and concurrent-session cases | `41430FF8850A33EA7247D7BDA3EED6A610D1E1CED4944D8CAE64BB24BC32A684` |
| `dbo.GOVERNOR_NAMES_PROC` | Committed import; Query Store 125576/15435 and 23307/12884 | `48BF04D217D446B49C63321503463A3FD6C2351BD7634E072586BDD2081A52D8` |
| `dbo.HEALEDSUMMARY_PROC` | Full history; 2,374 rows; Phase 2 median 16,817.544 ms | `D67A55C9F4EEAB9721C55168F74454B051E200A31C7F2E160BAEBF7D4F4D77F6` |
| `dbo.HEALEDSUMMARY_PROC_OPT` | Static/runtime ownership check plus full-history bidirectional equivalence | `05760A6EAE89D953A00FA72FF8A2B380C3D36E7DC244C6FDADF4E190BE9EFD26` |
| `dbo.IMPORT_STAGING_PROC` | Normal, boundary/Unicode/blanks, invalid, corrected retry and simultaneous SQL sessions | `B87011CE847708853F787F1188D2366FF18464AAE0DECAD594D8BF058FB76CF3` |
| `dbo.KILLPOINTSSUMMARY_PROC` | Full-history summary component and downstream reconciliation | `ACF6F5DB5D82116BE79F3E78363C2AD48A9A6A5386DE760EAB88DF1BBDE66BA0` |
| `dbo.KILLSSUMMARY_PROC` | Full-history summary component and downstream reconciliation | `083873657952EB518422622D7EFE2B8CAE4A386F4D687039F1BD02E4468784B7` |
| `dbo.KT4SUMMARY_PROC` | Full-history summary component and downstream reconciliation | `8435CF8491B21AD21A25225B15542C06D2F531CC3DDA32F9BDB3E48C62C21E94` |
| `dbo.KT5SUMMARY_PROC` | Full-history summary component and downstream reconciliation | `901BC7F65D7FA806477AE3653EFC4991922E20151EED109AE94AF8DDC545A903` |
| `dbo.POWERSUMMARY_PROC` | Full history; 2,374 rows; Phase 2 median 19,724.638 ms | `9BE03122CB1072B61E32A53A9C9689709DA3E21BBB6B87F5B181EE783489C04F` |
| `dbo.RANGEDSUMMARY_PROC` | Full history; 2,374 rows; Phase 2 median 15,205.826 ms | `D1EE8FAC639DF42356FEB8C9F43880991CC70A8CE105EF8E073E0591E2527DB1` |
| `dbo.Refresh_PlayerScanMeta` | Full/incremental/no-op; 2,371 rows; Phase 2 medians 470.612/548.919/62.602 ms | `2E58DAA7BB7C8D1A41068D436456398DE0F23AECC533AB14B993BD01EA007316` |
| `dbo.sp_ExcelOutput_ByKVK` | Representative KVK export parameters; exact rows, metadata and target-table digest | `1FD78DEA83052558EB1E95AF953E8EA9BD14E70C8E2A732F18C25D6F6A094B22` |
| `dbo.sp_Loop_ExcelOutput_ByKVK` | Same KVK set through transitive loop; output-table equivalence | `F2799CDB46362B800A9A7B24E68CD102153B2701C7E72628851ADFD8731251F8` |
| `dbo.sp_Prep_ExcelOutputTable` | Representative scan/KVK; exact generated table metadata and values | `F3C4D4CD432D6B90881840EE412CD80045A56E8392D10684ACCFBC0201A0B2FC` |
| `dbo.sp_Prep_TargetTable` | Representative scan/KVK; dynamic identifier allowlist and exact output | `E8B883D4581BD73DB5B7F7AE6EA9D5DC8FDFB052DDE5227CFB60DAE5513AA76C` |
| `dbo.sp_Rebuild_ExcelForDashboard` | Latest representative scan; `Gov_ID bigint`; row/value/metadata digest | `6C52140F918BAF17F2B7F13DF2AECEFF73581AEC11AEF477EEA1BCBCD9C72203` |
| `dbo.sp_Rebuild_v_PlayerKVK_Last3` | Representative last-three KVK rebuild; exact object/result contract | `FD4A42A07B059E8C61EC600A3A22B08965BF85F2D9EAFCC485A4A0BE4C89BFBE` |
| `dbo.sp_RefreshInactiveGovernors` | Committed import; active/inactive row reconciliation | `D541C839A5B58730EB0B50F28F5D668948DF869716EC1BF0DF9059720430133B` |
| `dbo.SP_Stats_for_Upload` | Representative upload scan; `Gov_ID bigint`; exact rows/order/metadata | `46C37F17400CF038CD87EAD964927BD2DAD51C8DA728301193E3FFDE3624197B` |
| `dbo.sp_TARGETS_MASTER` | Representative matchmaking/draft scans; exact target outputs | `6E4FAF0B06C77A07C7BFDCE5BFB8ED5155D114DCAEA885CFE34CF0933A98E29E` |
| `dbo.SUMMARY_PROC` | Full history; stable digest `467092...71BB`; Phase 2 median 167,154.476 ms | `D94911210336E94C468DEAB4EB13E4AB1970D0FB4F1A65FE977BD4ABA1EEF81A` |
| `dbo.TARGETS` | Representative matchmaking/draft scans; exact rows and output metadata | `A618CF0D8652949014D7A9CD7421BE5658022B9C6D5BC7B18CAF7A3E318BF061` |
| `dbo.TARGETS_NEW` | Representative matchmaking/draft scans; exact temp/output shapes | `F3CE15BAF21885CA85A356E1087421B237E8495C5C08326DC854A0EDD3963A77` |
| `dbo.TEST` | Runtime ownership proof; if retained, read-only result/metadata equivalence | `26F3EAA381F7FF5AB1612AEEB21A725CD2DBCB31BCE3CCCF9D3428D132648856` |
| `dbo.UPDATE_ALL` | Legacy authoritative path; import mutex, duplicate/retry and committed state | `AA94F1497F0409EAD6C6D0934DEA2C407555D402E68D1ACCB1E56E0D0137D650` |
| `dbo.UPDATE_ALL2` | Exact committed fixture 0+1-5; 411/411 rows at scan 1021; digest `D4C093...3463` | `AE58F27E154A8F06B7D413E17E129DA425EE8D3BDBFF744507E7237DCCF9C9E9` |
| `dbo.UPDATE_RALLY_DATA` | Committed import path; downstream table row/value equivalence | `F55ABB67E4E2BA8B303736D6863FAD3F31EDE67798C0010452D29E9BC7F31271` |
| `dbo.usp_BackfillKvkFinalReportCompletion` | Historical/backfill and no-op cases; exact affected rows | `07F91825AD024292F7B572AF1EEB2AF7ED0CD754E76BC15572A6CC4DB2D939EE` |
| `dbo.usp_GetLeadershipPlayerIdentityHistory` | Existing/absent governor; exact ID/name/date metadata and order | `F4BA31817A7F6FF1550CA6E2C5C3485AED4911E07C3B9ECFE368E2A3A21BB19A` |
| `dbo.usp_GetLeadershipPlayerLastActive` | 720-day high-activity path; one row; Phase 2 median 325.244 ms | `0275F754DDF32DA16E32F44F45DF21FE0D3CD68AB1D030A752C854514CD5D2F8` |
| `dbo.usp_GetLeadershipPlayerLookupDirectory` | 720-day directory; 1,639 rows; Phase 2 median 749.879 ms | `4819CB35C7EC4DB51CFF9B31D06E901FB9C53F38E0868C44C65D90514C22E933` |
| `dbo.usp_GetLeadershipPlayerReview` | Governor 2441482, 90 days, pinned UTC; all result sets; Query Store map | `58E554010869B8A06B8999E5D8FC65FBA6EED1B676EEC7112B153634113746B0` |
| `dbo.usp_GetPersonalStatsDaily` | Existing/absent governor and representative date range; exact metadata/order | `B1C438800CAE483019CA12567DC32470B457D187779EABEF6A874087651582ED` |
| `dbo.usp_LeadershipPlayerGovernorExists` | Existing and absent governor; exact one-row boolean contract | `12C1B7FEB737B384C92E8F5630C6195B82A17F6FA3DA1C9584CCD212FB62A706` |
| `dbo.usp_UpsertGovernorNameHistoryForScan` | Scan 1021 idempotency; Query Store 143117/16603 affected-alias phase | `6A1EDDECEF81BC1EFCF08C83FB9C9D2B7675631899FDCB9237473CD9EA8FEED0` |

### Phase 4-held view definitions

`dbo.v_Active_Players`, `dbo.v_GovernorNames`, `dbo.v_KVK_Under50_Last3_WithLatest`,
`dbo.v_MGE_SignupReview`, `dbo.v_PlayerLatestStats`, `dbo.vDaily_Helps`,
`dbo.vDaily_PlayerExport`, `dbo.vDaily_RSSAssisted`, `dbo.vDaily_RSSGathered`,
`dbo.vw_Governor_KVK_Summary_GlobalLatest`, `dbo.vWTD_Helps`,
`dbo.vWTD_RSSAssisted`, and `dbo.vWTD_RSSGathered`.

### Persisted downstream contracts

| Table | Phase 3 rule |
| --- | --- |
| `dbo.STAGING_STATS` | Reconcile every write and join. Change a remaining `float` only with conversion and downstream evidence. |
| `dbo.EXCEL_FOR_DASHBOARD` | Preserve the existing aligned `Gov_ID bigint` contract and prove exact rows/metadata. |
| `dbo.STATS_FOR_UPLOAD` | Preserve the existing aligned `Gov_ID bigint` contract and bot/export result shape. |

## Locked baseline and rollback rules

- Reuse the operator-held Phase 1/2 reports and exact scenarios from
  `phase1/benchmark_manifest.md`; raw reports remain outside Git.
- Compare changed module results bidirectionally and compare result-set metadata.
- Flag an approximately 10 percent or greater median duration, CPU, reads or throughput
  regression unless a documented correctness/safety benefit justifies it.
- The rollback source for every changed procedure is the exact `b6b0bc4` definition identified
  above. The Phase 3 rollback restores these definitions before Phase 2 metadata-swap rollback.
- Views are compilation/metadata consumers in Phase 3, not cleanup targets. Their conversion
  cleanup remains Phase 4.
