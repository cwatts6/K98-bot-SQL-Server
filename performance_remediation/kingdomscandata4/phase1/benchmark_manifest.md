# Phase 1 benchmark manifest

Populate this manifest only after the dependency collector and Query Store evidence identify real
parameters and callers. Do not execute write-capable procedures against production merely to fill
the table.

## Environment controls

| Field | Value |
| --- | --- |
| Server / database | `mini_AMD` / `ROK_TRACKER` |
| Database restore or production snapshot time | Live collector; approximate instance start 2026-07-22 05:46:38.340 |
| SQL Server version / compatibility | 16.0.1190.2 Developer Edition / 160 |
| Query Store state | READ_WRITE, AUTO capture, 310 MB of 1,000 MB |
| Cache state | Observed live workload; no cache clear; warm/cold state uncontrolled |
| Data row count / scan range | 394,506 rows; scan order 1-1020; 2022-03-30 through 2026-07-23 |
| Collection window | Query Store 2026-06-23 15:28:26 through 2026-07-23 15:28:26 UTC |
| Representative restored copy | `ROK_TRACKER_BACKUP_TEST_KS4`; restore and `DBCC CHECKDB` confirmed by the operator |
| Restored-copy reset | Guarded snapshot `ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE`; repeated reset confirmed |
| Committed-import benchmark copy | `ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK`; restore the same checksum-verified copy-only seed before ordinals 0–5; no snapshot on this database |
| Production volume capacity | `C:\` 474.99 GB total / 243.57 GB free (51.28%) |
| Production data/log | Data 9,224 MB with 513.31 MB internal free; log 65,536 MB with 51 MB used |
| Tempdb | 4,096 MB data files with 512 MB fixed growth; approximately 32 GB available at capture |
| Functional-test log | 16 GB size / 4 GB growth / 32 GB maximum after each snapshot revert |
| Typed string boundary | Preserve `nvarchar(200/100)` ingestion widths; no further narrowing |

## Committed-import seed receipt

The dedicated seed completed at `2026-07-24 12:11:58.0876026` UTC.

| Source | Retained snapshot | Seed backup | KS4 rows / scan | KS5 rows / scan | Live/test path references | Procedure SHA-256 | Checksum / verify |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ROK_TRACKER_BACKUP_TEST_KS4` | `ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE` | `C:\sql_backup\ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK_SEED_20260724.bak` | 394,506 / 1020 | 394,526 / 1020 | 0 / 3 | `4F9FE9A3574A40125EE3B45D3C4D94B01C1F47BFAC744955965E067EB28B58EA` | Enabled / passed |

The seed establishes identical restore input for ordinals 0–5. It does not
close the comparable committed-import gate until all six benchmark receipts
and filesystem manifests are retained and reconciled.

### Restore receipts

| Intended ordinal | Started UTC | Duration ms | KS4 rows / scan | KS5 rows / scan | Live/test paths | Benchmark snapshot | Procedure hash match | Status |
| ---: | --- | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 2026-07-24 12:23:12.6031321 | 12,818.931 | 394,506 / 1020 | 394,526 / 1020 | 0 / 3 | Absent | Yes | Passed |
| 1 | 2026-07-24 13:28:10.4120513 | 59,834.863 | 394,506 / 1020 | 394,526 / 1020 | 0 / 3 | Absent | Yes | Passed |

### Hardened backup-identity follow-up

The security follow-up was closed on 2026-07-26 with a new checksum/copy-only
seed and one representative committed ordinal. The fixed-path predecessor was
retained as
`ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK_SEED_20260724_pre_hardening_20260726T0855.bak`.

| Item | Result |
| --- | --- |
| Approved hardened `BackupSetGUID` | `77292DB9-81A9-4C51-8C8C-FB1B00ECF82C` |
| Seed / receipt | Passed in 18 seconds; `ks4_hardened_seed_receipt_20260726T0858.rpt` |
| Retained first restore receipt | Physical restore completed in 190.187 seconds; post-restore guard rejected the invalid target-database-GUID/source-BindingID comparison; `ks4_hardened_restore_receipt_20260726T0903.rpt` |
| Retained repeatability receipt | Stopped before mutation on stale `#SeedBackupHeader`; `ks4_hardened_restore_receipt_corrected_20260726T0922.rpt` |
| Corrected repeatable restore | Passed end-to-end in 58 seconds; `ks4_hardened_restore_receipt_repeatable_20260726T0924.rpt` |
| Representative committed ordinal 1 | Passed in 141 seconds; `ks4_update_all2_ordinal1_hardened_20260726T0931.rpt` |
| Exact final state | KS4 394,917/1021; KS5 394,937/1021; 411 rows at scan 1021; zero rows at scan 1071; canonical staging empty |
| KS4 material digest excluding `SCAN_UNO` | `D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463` |
| Read-only receipts | `r1.rpt` row/scan reconciliation and `d1.rpt` deterministic digest, retained in the SQL-host operator evidence directory |
| Snapshot / production | Guarded pristine snapshot retained; production untouched |

The current hardened files have SHA-256 values
`BD50C3665376D4BC1567314EB7B64A024379A65095A8B32756AE5A798579E8DE`
for script 14,
`46CD7E86797A999E40DDE6B0F39F78F10FD5DCABADAA934D2D770F16F4D60534`
for script 15, and
`C2A4A7F72C17AE7CFE43CE3CC3FE59B4860C4EEF6EF1FA4B06FCDD485E7BCAC3`
for the static identity-guard test.

## Required workloads

| Workload | Parameters / dataset | Read-only or write-capable | Before evidence | Phase reruns |
| --- | --- | --- | --- | --- |
| Summary procedures (`DEADSSUMMARY_PROC` through `SUMMARY_PROC`) | Full-history end-to-end and selected component attribution | Write-capable, rollback-isolated | Captured in `04_run_controlled_baseline.rpt` | 2, 3 |
| `Refresh_PlayerScanMeta` | Full, incremental, no-op | Write-capable, rollback-isolated | Five stable measured runs per path in `04_run_controlled_baseline_v2.rpt` | 2, 3 |
| Import staging and `UPDATE_ALL2` | Normal, boundary, Unicode, blank/null, invalid, retry, Phase-B failure and concurrent samples | Write-capable | Functional scenarios and comparable committed warm-up plus measured ordinals 1-5 complete | 2, 3, 5 |
| Important views / exports | Complete materialization of latest, daily, WTD and global-latest views | Read-only | Five stable measured runs per view in `04_run_controlled_baseline_v2.rpt` | 2, 4 |
| Direct bot/DAL reads | Existing/not-found governor, leadership directory and last-active paths | Read-only | Selected procedure baselines captured; all eight transitive result contracts and after scenarios are mapped in `bot_dal_contract_map.md` | 2, 4, 5 |
| Query Store top statements | 200 runtime rows / 464 plan rows from collector | Read-only | Captured; all 12 shortlisted query/plan pairs now map to owners, scenarios and exact after baselines | Every material change |

## Controlled before-baseline summary

All listed controlled workloads used one warm-up plus five measured executions. Result counts and
SHA-256 digests were stable across the five measured runs.

| Workload | Median duration ms | Average logical reads | Rows |
| --- | ---: | ---: | ---: |
| `SUMMARY_PROC` end-to-end | 267,946.951 | 71,891,096.0 | 2,374 |
| `DEADSSUMMARY_PROC` | 35,879.176 | 9,748,663.0 | 2,374 |
| `HEALEDSUMMARY_PROC` | 20,366.971 | 11,139,035.2 | 2,374 |
| `POWERSUMMARY_PROC` | 31,513.320 | 8,943,333.2 | 2,374 |
| `RANGEDSUMMARY_PROC` | 36,287.989 | 9,502,786.6 | 2,374 |
| `Refresh_PlayerScanMeta` full | 301.643 | 8,677.0 | 2,371 |
| `Refresh_PlayerScanMeta` incremental | 411.817 | 13,827.2 | 2,371 |
| `Refresh_PlayerScanMeta` no-op | 48.275 | 1,981.2 | 2,371 |
| `v_PlayerLatestStats` | 64.258 | 14,249.8 | 2,371 |
| `vDaily_PlayerExport` | 729.391 | 92,125.4 | 223,386 |
| `vw_Governor_KVK_Summary_GlobalLatest` | 10.015 | 2,443.6 | 411 |
| `usp_GetLeadershipPlayerLookupDirectory` | 987.686 | 76,449.0 | 1,639 |
| `usp_GetLeadershipPlayerLastActive` | 256.446 | 17,763.6 | 1 |

The remaining daily/WTD views and existing/absent governor lookups are retained in
`04_run_controlled_baseline_v2.rpt`.

## Phase 2 controlled after-baseline summary

The post-migration suite ran on `ROK_TRACKER_BACKUP_TEST_KS4_BENCHMARK` under benchmark run
`9775E3FF-DB41-45CF-89B1-075F01EDC23B`. Every enabled workload/scenario completed five measured
runs with identical row counts and one digest. `UPDATE_ALL2` was intentionally skipped because
this read/rollback-isolated run did not supply a committed-import ordinal.

| Workload | Phase 2 median ms | Rows | Result |
| --- | ---: | ---: | --- |
| `SUMMARY_PROC` end-to-end | 167,154.476 | 2,374 | Stable digest `467092D9B32AEB45142FBA2AD8376AB4ACA42CEC4FF44B1AD3E8B452DCDD71BB`; 37.6% faster |
| `DEADSSUMMARY_PROC` | 18,572.113 | 2,374 | Stable; faster |
| `HEALEDSUMMARY_PROC` | 16,817.544 | 2,374 | Stable; faster |
| `POWERSUMMARY_PROC` | 19,724.638 | 2,374 | Stable; faster |
| `RANGEDSUMMARY_PROC` | 15,205.826 | 2,374 | Stable; faster |
| `Refresh_PlayerScanMeta` full | 470.612 | 2,371 | Stable; 168.969 ms absolute increase |
| `Refresh_PlayerScanMeta` incremental | 548.919 | 2,371 | Stable; 137.102 ms absolute increase |
| `Refresh_PlayerScanMeta` no-op | 62.602 | 2,371 | Stable; 14.327 ms absolute increase |
| `v_PlayerLatestStats` | 95.087 | 2,371 | Stable; 30.829 ms absolute increase |
| `vDaily_PlayerExport`, isolated confirmation | 603.284 | 223,386 | Stable digest `3EB8E0C681DC9CAAA541B79FB1034C6F5890CFD40E6CE356C42870245635422A`; 17.3% faster |
| `vw_Governor_KVK_Summary_GlobalLatest` | 19.337 | 411 | Stable; 9.322 ms absolute increase |
| `usp_GetLeadershipPlayerLookupDirectory` | 749.879 | 1,639 | Stable; faster |
| `usp_GetLeadershipPlayerLastActive` | 325.244 | 1 | Stable; 68.798 ms absolute increase |

The full-suite export timing of 5,611.234 ms overlapped benchmark log maintenance and is retained
as an invalidated interference sample. The immediate isolated six-ordinal confirmation returned
five measured timings of 601.677, 600.410, 642.599, 609.021 and 603.284 ms with exact material
stability. The benchmark-only log-full attempt and the unique verified log backups are
environmental receipts, not product failures or production configuration changes.

## `UPDATE_ALL2` functional baseline

These snapshot-backed runs prove behavior and recovery. They are not substitutes for the
fresh-restore one-warm-up/five-measured performance baseline.

| Scenario | Elapsed | Result |
| --- | ---: | --- |
| Normal representative | 424 s | Success; 411 KS5 + 411 KS4 rows; scan 1021 |
| Boundary/Unicode/optional blanks | 273 s | Success; widths 200/100/100 and optional blank preserved |
| Invalid required numeric | 737 ms | Expected rc=1 failure; no row/scan change; file retained |
| Corrected retry without reset | 250.792 s | Success; one 411-row scan; file archived; no transaction leak |
| Controlled Phase-B failure | Not retained as a timed `.rpt` | Expected 51091; Phase A durable; Phase B rolled back; no transaction leak |
| Simultaneous concurrency | Winner 250.618 s; loser 51.895 s | One success, one rc=1 loser, 0 ms start spread and no duplicate scan |

The concurrency result is `PASS_WITH_CLEANUP_RECORDER_LIMITATION`: the original runner evaluated
`@@TRANCOUNT` inside its evidence `INSERT`. Post-call count, `XACT_STATE()`, final session output
and collector state were zero. The runner has been corrected to snapshot cleanup state before
the evidence insert.

## Committed `UPDATE_ALL2` benchmark receipts

The representative fixture staged for ordinal 0 was 78,480 bytes with SHA-256
`AC7FF4794067617738318594AA96ADD32069FB43C1C81943BD3A46C9A317BB26`.
Its collected archive
`archive_Stats_20260723_2022.csv` retained the same length and SHA-256 under
run label `committed_import_ordinal_0` at
`2026-07-24T13:08:19.4030269Z`.

| Ordinal | Kind | Duration ms | CPU ms | Logical / physical reads | Writes | Rows/sec | KS4/KS5 added | Final scan / rows / distinct / duplicates | Boundary raw/typed/canonical | Lock wait ms / count | Deadlock | Log generated MB | Tempdb delta MB | KS4 digest | Receipt |
| ---: | --- | ---: | ---: | --- | ---: | ---: | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| 0 | Warm-up | 183,649.947 | 181,367 | 56,038,925 / 877,653 | 358,377 | 2.238 | 411 / 411 | 1021 / 411 / 411 / 0 | 411 / 411 / 0 | 1 / 15 | No | 4,089.617 | 260.688 | `1D43678E03FEEE80C9475C1A2DFF3992F3BE824749107FA19358BA3BEF810101` | `PASS_AFTER_HARNESS_CORRECTION`; filesystem hash matched |
| 1 | Measured | 183,546.667 | 179,094 | 56,079,649 / 835,082 | 352,741 | 2.239 | 411 / 411 | 1021 / 411 / 411 / 0 | 411 / 411 / 0 | 1 / 16 | No | 4,089.363 | 262.125 | `D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463` | Passed via supplemental material digest; filesystem hash matched |
| 2 | Measured | 195,362.014 | 187,268 | 56,138,037 / 710,109 | 354,592 | 2.104 | 411 / 411 | 1021 / 411 / 411 / 0 | 411 / 411 / 0 | 1 / 15 | No | 4,088.875 | 257.938 | `D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463` | Passed; harness `20260724.3`; filesystem hash matched |
| 3 | Measured | 203,664.788 | 191,864 | 56,184,069 / 787,222 | 355,563 | 2.018 | 411 / 411 | 1021 / 411 / 411 / 0 | 411 / 411 / 0 | 2 / 14 | No | 4,088.758 | 261.125 | `D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463` | Passed; harness `20260724.3`; surviving successful-run archive and manifest confirmed |
| 4 | Measured | 216,637.477 | 181,405 | 56,115,096 / 781,496 | 353,887 | 1.897 | 411 / 411 | 1021 / 411 / 411 / 0 | 411 / 411 / 0 | 1 / 12 | No | 4,088.449 | 262.250 | `D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463` | Passed; harness `20260724.3`; filesystem hash matched |
| 5 | Measured | 186,951.946 | 180,545 | 56,106,810 / 818,355 | 351,158 | 2.198 | 411 / 411 | 1021 / 411 / 411 / 0 | 411 / 411 / 0 | 0 / 11 | No | 4,110.387 | 262.063 | `D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463` | Passed; harness `20260724.3`; filesystem hash matched |

### Five-run measured committed-import summary

| Runs | Duration ms median / range | CPU ms median | Logical / physical reads median | Writes median | Rows/sec median | Lock wait ms / count median | Deadlocks | Log generated MB median | Tempdb delta MB median | Material stability |
| ---: | --- | ---: | --- | ---: | ---: | --- | --- | ---: | ---: | --- |
| 5 | 195,362.014 / 183,546.667-216,637.477 | 181,405 | 56,115,096 / 787,222 | 353,887 | 2.104 | 1 / 14 | 0 | 4,088.875 | 262.063 | Exact 411-row additions, zero duplicates and one stable material digest in every run |

Ordinal 0 was emitted as error 51054 only because the new harness incorrectly
expected the raw and typed CSV boundary tables to be empty. Repository
definitions prove those tables are truncated and reloaded at the start of an
import, while only canonical `IMPORT_STAGING` is truncated after Phase A.
The observed `411/411/0` boundary state is therefore the exact successful
contract. Ordinal 1 was executed from the same earlier SSMS buffer and
repeated the false 51054 assertion despite its exact successful state. Its
performance and row/scan receipts pass. The read-only material supplement
confirmed 411 distinct `SCAN_UNO` values in range 425,256–425,666 and material
digest `D4C0938EB0D3E97D1FAA2A912B12F2B0964A6599F1109CF6C76746DB11B53463`.

### Excluded committed-import attempts

| Intended ordinal | Attempt label | Failure point | Duration ms | Target state | Boundary raw/typed/canonical | Log / tempdb delta MB | Fixture disposition | Resolution |
| ---: | --- | --- | ---: | --- | --- | --- | --- | --- |
| 3 | `committed_import_ordinal_3` | `IMPORT_STAGING_PROC` post-insert `@@ROWCOUNT`; client connection recovered | 206.024 | Unchanged: KS4 394,506/1020; KS5 394,526/1020 | 411 / 411 / 0 | 1.355 / 0 | Supplied receipt reported `unconsumed_stats.csv`, 78,480 bytes, expected SHA-256; directory no longer present | Excluded; report hash/timestamp retained in the audit, raw filesystem receipt unavailable |

The failed attempt is not one of the five measured samples. Its filesystem
receipt was collected at `2026-07-24T20:06:05.0985863Z`; the unconsumed file
matched SHA-256
`AC7FF4794067617738318594AA96ADD32069FB43C1C81943BD3A46C9A317BB26`.

## Evidence hashes

| Evidence | SHA-256 |
| --- | --- |
| `04_run_controlled_baseline.sql` at original controlled-baseline capture | `A6B3E6B3FD13C72CA28872F73F70F43F82FDDB903F9899E97E302FF98B106BD7` |
| Ordinal-0 executed `04_run_controlled_baseline.sql` | `8F83DEEA507BA079069CCCE0D0B7DD4218A024725818D0CD90A8D8E55E0B93D8` |
| Current `04_run_controlled_baseline.sql`, repeatable-session revision | `6D096136A57B2101A2EFE07C70004C1CE1598912B36DF54AB6D93C02984DEF8B` |
| `14_create_update_all2_benchmark_seed_backup.sql` | `A2D219049644E36C057D1B0D4FFAE17F5FC1ED840347A1588983035A5F6DCD36` |
| `15_restore_update_all2_benchmark_database.sql` | `37E2FECADA1CDC6E7EB05106E9965B8C0086A57951B7E5267DCCD6335C9D2EB7` |
| `16_collect_update_all2_material_digest.sql` | `FF97612B08D6B5962AA0E6376E6BDA0C16D20E8ABE77D4FC87D04DECCE022B37` |
| Superseded compile-failing `05_collect_sql_agent_and_serialization.sql`, revision `20260724.1` | `AD98181C13C34C7B46AEC4C6861CF76854A55F8E1A6C2E0A54321E368F93A1A2` |
| Current `05_collect_sql_agent_and_serialization.sql`, revision `20260724.2` | `9C4161DDFB95761871DEABF5492C6A705E5699C62B4C265704F76CF55310E097` |
| `06_collect_sql_agent_full_job_inventory.sql`, revision `20260725.1` | `4EE785997FF6ADAE039DF7E4E60D9B9B2C3D6B4D582C2B4D5BF5E3D0ED68C66C` |
| Executed `07_collect_query_store_owner_parameter_map.sql`, revision `20260725.1` | `05737CDF452F8E9579CA742E71A0D185B4F0AC0F022810A45680F6BDE931BF1F` |
| Current `07_collect_query_store_owner_parameter_map.sql`, revision `20260725.2` (static function-label correction only) | `EA8175E106DC0BC6020B02728B54BB9AB6AB7F921F85B65262C4575D5E5BD631` |
| `Collect-ExternalSerializationEvidence.ps1`, revision `20260724.1` | `0643D992B5DB8F9518B7A4953747D9A67F3D529E692D287BF98AEF74EF063AED` |
| Operator-held ordinal-0 committed-import report | `4D59A3459BFA00BD1C57A981FFCF552B450E9A0E07EE3CADC66B96820048F3BA` |
| Operator-held ordinal-1 committed-import report | `816C7680086B6F353FE8546459E20049F3CA94BCDB3D1C75F4FB02A977DC635F` |
| Operator-held ordinal-2 committed-import report | `844966020B27240071D0ED91AA05B81A9C4E8EC7CBBF5CD88FBF68E58C8E619D` |
| Captured excluded ordinal-3-attempt report hash; file retention unconfirmed | `10ABA6996CC4B37D1B0B7A6FF824A755C8813DC6E1ACD9A3D8D62978D758DF1F` |
| Operator-held successful ordinal-3 committed-import report | `3FB786677A364161189034F3D5D33E2986FFC46EB47E5945794DFE777C9818FC` |
| Operator-held ordinal-4 committed-import report | `80DBA04DC25AFC0D742E5681A9AE840078D92E09D049C1BCD2F2C9D8E5EB5FC2` |
| Operator-held ordinal-5 committed-import report | `38EAFA0ECB2C2BA79BF170CAB383272B605DAC8704A2EEA522FB8063E852B723` |
| Operator-held SQL Agent/serialization report | `03DF6F9626CC81FF9838FABABA4C4AD1E89BD532BC261832BFE10A8F9289E945` |
| Operator-held full SQL Agent inventory supplement | `2F906E890BF1A552FC33F1157788E0F1BE5153DD505CBFFF45511748681E46EA` |
| Operator-held external serialization JSON | `3B56C266844770238F52FDE8037EE0094A5CF9D0D871E09F73A4370AA60F81BF` |
| Operator-held Query Store owner/parameter map | `7563884C4D926054ADC63011B089AC15850305F97F0FE6FA2AFA53A78C94DFD4` |
| Phase 1 bot/DAL contract map | `2BD4D34955761D5F5A2F00C76394CBE8B1AEA850E884CE82F7017782123B7450` |
| Bot `embed_offseason_stats.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `0E583C6D310DD0ACE0CD08FEA84AEBEE9D853C844309C334C78AFD10EC828AF5` |
| Bot `weekly_activity_importer.py` at that commit | `3919DC7B47BD026B184AC578F7AE0B130BD63F71864B359DA2569B283246D2DB` |
| Bot `kvk_state.py` at that commit | `DE8D2FB4694164A4150E147A6148D85B340EF8C23E0EDB1DF16E623886008F59` |
| Bot `kvk/dal/kvk_history_dal.py` at that commit | `B05DA85D3BC280E02282C74FF7200AB106C5A5078BD79D13D22C473765A3DB03` |
| Bot `stats/dal/fallback_import_dal.py` at that commit | `4E633B7784E49F1413184FF97BD19109D92C3412298F23946E8EFB8FD6BAEA88` |
| Bot `player_self_service/accounts_dal.py` at that commit | `D586B38D93BA37ED4C57618E25BED99E8436741E0E8E8079931C69305BE08488` |
| Bot `player_self_service/governor_dashboard_dal.py` at that commit | `C63D1BF8345355B403859FC7E1F291756D3DBE6AB50F177C96974052D41721D4` |
| Bot `leadership_player_review/dal.py` at that commit | `AE8E7DF5E2AEFFD9F8B84AC052625EABC430431671EAAF90D8FF351724ECC3EE` |
| Executed migration rehearsal `01_collect_preflight.sql`, revision `20260725.1` | `2F594EF27FBC7E8141CF106A4E6AB3D901298C634889FD53BF88978AD47F2F80` |
| Current migration rehearsal `01_collect_preflight.sql`, revision `20260725.2` (report-only row estimate correction) | `796B5E359EA67C2D99161BEE4AE70EBD0FE61BBCD5ECB5FEBE4B3A6D0E1B8702` |
| Operator-held migration preflight report | `CDE5A51DD49ACAE5756A54B29ED2CE2C876FCF15E03FEE8AE7BCA26642306FCA` |
| Migration rehearsal `02_forward_shadow_rehearsal.sql`, revision `20260725.1` | `99F06FA708519B30477C37F615810A7164183F9FF9F2E9F43C83FD35253EB846` |
| Superseded rollback rehearsal `03_rollback_shadow_rehearsal.sql`, revision `20260725.1` (over-strict SSMS IntelliSense session guard; stopped before mutation) | `47DE80F2929372B840599AE42F523FCEA91A453CC09BFF678A40115749B724D1` |
| Current rollback rehearsal `03_rollback_shadow_rehearsal.sql`, revision `20260725.2` | `1F207DD220972BC7CCDAE046AE2733604300A619673C3ADB52670D29E0F25D18` |
| Operator-held shadow-copy forward rehearsal report | `97EAF66EC7557B524B132C321E8134E8E868A1B9598302608B1EF27C6199AFDF` |
| Operator-held production-usable rollback rehearsal report | `FE5FA524F3FEC32951C8340314A41AEB7E557D176F0497D73F49748C1161EF47` |
| Approved Phase 2 checkpoint | `9070BF0E01E390301D12CC49347931584DBF5D8D37D8CA0BAE2EA95D0E42619C` |
| Bot `bot_helpers.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `4C04FBF948594D9234FB4146E88C28BCD2BEB9F99EFA385E394044CB39A9197F` |
| Bot `processing_pipeline.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `182C0392D85547C5562ADBB78D642FBD3EB8870779AF32529EF00460A5BDCC99` |
| Bot `stats_module.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `DD0816F315B78C3C1E69DF01E18766C558339EFCFB5F9C69275C31BEDD6BE1EB` |
| Bot `update_all2_log_manager.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `E7B4479214A2313D9B2E09FADC61C45A7FF805DA107ADB0C87ED1CD83DC0C635` |
| Bot `commands/admin_cmds.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `3DD3022A91A73AD118B2993B9084AB786FE970E7A993C4003E9B099B8930FA66` |
| Bot `DL_bot.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `1C665BA8D404EBB4BBDE2310C8820971FFC687BC27C130A1D167C94BA5B9CAFC` |
| Bot `run_bot.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `A897FFFF6E95FB76AD15A254443AB5BD8B58714E54FCEC643C2D0CB7449EB5AA` |
| Bot `singleton_lock.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `45D2065541A9C80E51224A135DA93FE9DB3FF3F464C7E13719ED70806D8CA9F2` |
| Bot `upload_routes/fallback_queue_route.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `ED94D11A27D1578FADF93A57DBA79C2150141E4CFD3E9A26E449BF6C1E9DBB94` |
| Bot `core/interaction_safety.py` at clean commit `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | `DC58FDE1721BB517A4D2F99168C8BB48A00FE2FEB215C75A9BB72DBD58246689` |
| `04_run_controlled_baseline.rpt` | `2936AAC2E6B2BE45CB24D2EE50E39D5A4705B0CCE4443104623EE0009D9F2931` |
| `04_run_controlled_baseline_v2.rpt` | `7762D24E0203C6A8AF5D9381B8931EEC16F17727AAF1E33544006483949C1BBA` |
| Operator-held normal-success report | `1693A32DC061DA186924FAA0FA6A374CA8A2F747E0C25F27AFE9BB749582788B` |
| Operator-held boundary/Unicode report | `DC28C686F607DD091104125DC37AF34A7886379A6C44EFD4EEEDB68A2B2E7FD6` |
| Operator-held corrected-retry report | `E6B52B8F079D7CA205933B5899974A9DB664DABBF829B4D265F77CCB27932694` |
| Operator-held validated concurrency report | `444A14F3591408E1E3486348924D7ACAC7B68C0699D8491492F48F4758B4E43D` |

## Query Store baseline shortlist

These are observed 30-day Query Store values, not controlled benchmark repetitions. Use them to
select workloads and parameters, then run the measurement template on a representative restored
copy. The collector orders this list by total logical reads.

The original 2026-06-23 through 2026-07-23 performance values below remain
the before baseline. The 2026-07-25 receipt is used only to prove ownership,
parameters and the exact rerun entry; its later runtime window does not
replace these values.

| Query/plan | Original executions / duration / CPU / logical reads / writes | Owner and statement role | Representative scenario | Required after baseline |
| --- | --- | --- | --- | --- |
| 125393/15558 | 46 / 424.414 / 344.771 / 105580.457 / 3805.783 | `dbo.UPDATE_ALL2`; insert promoted scan into `KingdomScanData4` | Exact committed fixture, `@param1=NULL`, `@param2=NULL`, seed rows/scans 394,506/394,526/1020, expected 411/411 at scan 1021 | Restore seed before each ordinal; committed import ordinal 0 plus measured 1-5 with exact row/scan/value/digest reconciliation |
| 49472/4949 | 46 / 426.803 / 2359.934 / 83832.652 / 6413.804 | `dbo.CREATE_THE_AVERAGES`; scan-level aggregation | Same committed import, which invokes this procedure | Same committed 0+1-5 suite |
| 144113/16877 | 77 / 1203.303 / 1050.113 / 38890.974 / 402.818 | `dbo.usp_GetLeadershipPlayerReview`; ranked historical rows | `@GovernorID=2441482`, `@PeriodDays=90`, `@NowUtc='2026-07-23T09:55:00'` | Pinned leadership review, one warm-up plus five measured executions; reconcile every result set, row/column contract and digest |
| 52300/8473 | 46 / 136.922 / 530.606 / 57501.065 / 241.348 | `dbo.UPDATE_ALL2`; insert `POWER_BY_MONTH` | Same committed import | Same committed 0+1-5 suite |
| 143117/16603 | 3 / 28820.541 / 28628.908 / 859949.333 / 12.000 | `dbo.usp_UpsertGovernorNameHistoryForScan`; affected-alias aggregation | Same committed import at new scan 1021 | Same committed 0+1-5 suite, retaining the affected-alias phase measurement |
| 125576/15435 | 31 / 484.020 / 2572.063 / 78635.871 / 152.258 | `dbo.GOVERNOR_NAMES_PROC`; ranked scan refresh | Same committed import, which invokes this procedure | Same committed 0+1-5 suite |
| 143234/16658 | 108 / 1087.985 / 89.164 / 14263.315 / 0.000 | `dbo.usp_GetLeadershipPlayerReview`; previous-period baseline lookup | Same pinned high-activity 90-day leadership review | Same pinned leadership-review 0+1-5 suite |
| 143319/16735 | 31 / 359.812 / 1317.663 / 47691.000 / 2013.516 | `dbo.usp_GetLeadershipPlayerReview`; ranked historical rows | Same pinned high-activity 90-day leadership review | Same pinned leadership-review 0+1-5 suite |
| 143049/16547 | 94 / 132.343 / 128.576 / 14851.745 / 0.000 | `dbo.usp_GetLeadershipPlayerReview`; previous-period baseline lookup | Same pinned high-activity 90-day leadership review | Same pinned leadership-review 0+1-5 suite |
| 23307/12884 | 31 / 115.161 / 253.517 / 44389.161 / 231.000 | `dbo.GOVERNOR_NAMES_PROC`; insert `ALL_GOVS_NAMES` | Same committed import | Same committed 0+1-5 suite |
| 67494/10394 | 39 / 220.584 / 218.368 / 33959.744 / 14442.000 | `dbo.SUMMARY_PROC`; affected-governor scan materialization | Same committed import | Same committed 0+1-5 suite plus the retained rollback-isolated `SUMMARY_PROC` baseline |
| 140333/16354 | 51 / 66.519 / 65.469 / 24715.039 / 0.000 | Ad hoc `player_self_service/accounts_dal.py:fetch_latest_accounts_scan_rows`; exact requested-governor lookup | Query Store compiled values `(2441482, 46718337, 2510418, 85574801, 93858355)` | Call the current DAL with those five IDs, one warm-up plus five measured executions; preserve ascending SQL output, service remapping to account-slot order, and reconcile rows, nulls, types and digest |

## Measurement template

| Object / query | Run | Duration ms | CPU ms | Logical reads | Physical reads | Writes | Rows | Grant KB | Spills | Plan ID / file | Warnings / waits |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Pending | 1 |  |  |  |  |  |  |  |  |  |  |

For imports also record rows/second, transaction-log growth, blocking/deadlocks and total
end-to-end bot completion time. Use exact `EXCEPT`-style result reconciliation for every changed
module and explain any unavoidable variance.

## Phase 1 gate outcome

All five formal gate items are complete. The guarded forward receipt passed with a 45,779.868 ms
conservative outage, exact KS4/KS5/staging normalized digests, 1,351.15 MB used-log increase,
62.37 MB tempdb allocation increase and 8,124.28 MB volume-space consumption. The
production-usable metadata-swap rollback passed against the same run ID in 34,255.475 ms, restored
the original schema and exact digests without a snapshot, and used 2.56 MB additional log plus
62.19 MB additional tempdb allocation. The operator approved the Phase 2
implementation/rehearsal plan on 2026-07-25. Phase 2 forward, rollback, backup/restore recovery
and controlled workload rehearsals are now complete on representative copies; production
execution remains separately gated.

## Phase 2 finalizer-focused receipts

| Receipt | Result |
| --- | --- |
| Drift-refusal run | `CD8B69F6-CC1D-4F6A-BD4E-B6944B844FB6`; forward 56,854.713 ms; expected error 51674 before any retained-table drop |
| Drift witness | KS4 `SCAN_UNO=1`, `Power` changed from `124109056` to `124109057`, then restored exactly |
| Production-usable rollback | 25,047.184 ms total; 19,432.055 ms pre-rollback digest guard; exact six-table reconciliation |
| Clean finalization run | `E55C338E-6CDE-4048-ABDF-8AF68232C5BB`; forward 59,471.943 ms; verification 17 seconds |
| Irreversible finalizer | 22,275.645 ms six-table digest guard across 1,578,064 rows; status `FINALIZED`; three retained tables absent |
| Preserved contract | KS4 394,506 rows and ten indexes; KS5 394,526 rows and inventory-captured primary key; staging zero rows |
| Migration-history retryability | Transactional representative-copy proof affected the exact one `Applied` row, left zero matching `Applied` rows, and restored the exact prior zero-row state on rollback |
| Safety boundary | Production, representative source copy, guarded pristine snapshot and operator-held raw evidence unchanged |

Finalizer script SHA-256:
`86A1F6A4F72A26DBB09AEF810033745A571679EFB4B3057EA31E98D19B99304E`.
Static finalizer-guard test SHA-256:
`549D6899A568CC4612A69F11E7E896952549044920C208A4C7A293053DB297AF`.
Rollback revision `20260726.2` SHA-256:
`A842B5B6E94E3C08EDA60B448F533EEB28C2059023E525F82EAF992DC40DCE8D`.
Migration-history runtime test SHA-256:
`3D90C929590CE57935684F5FD7AAA0AF603D7D7D1637B08B4B643E647E546205`.
Static delivery-history guard SHA-256:
`5C65E411B07897FB07BB6BA3B178685319806D891D625C3FAA94A0478C8CBD91`.
