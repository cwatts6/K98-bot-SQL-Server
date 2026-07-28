# Phase 3 downstream inventory

Status: Phase 3 conversion decision complete and rehearsed 2026-07-27. The directly proven table
slice is converted; the broader legacy surface is explicitly retained pending a separately scoped
writer/consumer proof.

## Environment evidence

The read-only SSMS inventory was run on `MINI_AMD`.

- Production `ROK_TRACKER` has no applied
  `20260725_001_kingdomscandata4_shadow_type_remediation` history row and still exposes the old
  `float`/`nchar(255)` source contracts.
- The fresh rehearsal chain began from the approved Phase 2 `bigint`/`int`/`nvarchar` source
  contracts and finished at
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`.
- No production DDL or DML was executed.

This confirms that Phase 3 can start on the representative Phase 2 copy without deploying PR #60
to production. It also confirms that the production release must remain coordinated; deploying
Phase 2 alone would leave the bot and a broad downstream surface on mixed contracts.

## Targeted persisted contracts

Read-only counts on the finalized Phase 2 representative copy:

| Table | Rows | Live conversion evidence |
| --- | ---: | --- |
| `dbo.EXCEL_FOR_DASHBOARD` | 4,953 | `Gov_ID` is already `bigint`; preserve |
| `dbo.PlayerScanMeta` | 2,371 | Zero non-integral/out-of-range `GovernorID`, `FirstScanOrder` or `LastScanOrder` rows |
| `dbo.STAGING_STATS` | 411 | Zero non-integral/out-of-range `GovernorID` or `PowerRank` rows |
| `dbo.STATS_FOR_UPLOAD` | 411 | `Gov_ID` is already `bigint`; preserve |
| `dbo.SUMMARY_PROC_STATE` | 9 | Zero non-integral/out-of-range `LastScanOrder` rows |

## Broader legacy surface

The same catalog inventory found approximately 190 legacy `float` key/scan column entries across
persisted downstream and historical tables. Large examples include `DALL`, delta tables and KVK
summary tables with approximately 394,506 rows each. These are not automatically approved for
type alteration:

1. map each changed procedure's writes and transitive consumers;
2. prove every current value converts exactly;
3. preserve result metadata and bot/export contracts;
4. define drop/recreate handling for keys and indexes;
5. rehearse forward and rollback on a fresh representative copy.

The first safe table-change candidates—`PlayerScanMeta`, `SUMMARY_PROC_STATE` and the directly
assigned `STAGING_STATS` columns—are implemented in
`20260726_001_phase3_import_concurrency_and_direct_type_alignment` and passed
forward/rollback/forward rehearsal with preserved row counts of 2,371, 9 and 411. Their changed
writers compile against the aligned contracts. `EXCEL_FOR_DASHBOARD` and `STATS_FOR_UPLOAD`
continue to require validation only, not type changes to `Gov_ID`.

The approximately 190 broader legacy entries are not silently included in this migration. Phase 3
records an explicit retain decision for them: changing them without the five evidence requirements
above would broaden the release and increase rollback risk. They remain candidates for separately
scoped remediation, not a blocker to the proven Phase 3 direct-alignment package.
