# Phase 4 representative-copy rehearsal

Status: closed on 2026-07-27. Forward, rollback, clean reapply, equivalence,
full materialization, benchmark, actual-plan, mapped consumer, repository, and
final SQL Changes gates passed. Production remained untouched.

## Environment and authority boundary

- SQL Server: `MINI_AMD`, SQL Server 2022.
- Isolated database:
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`.
- Frozen Phase 3 source: `62cb739`.
- Phase 4 branch: `codex/kingdomscandata4-phase4`.
- Maximum baseline `SCANORDER`: `1020`.
- Maximum baseline `AsOfDate`: `2026-07-23`.
- Production database: `ROK_TRACKER`; no Phase 4 command was executed there.

## Obsolete-view retirement

`dbo.vAllianceActivity_WeeklyCumulative` was already invalid before Phase 4.
Its definition referenced `WeekStartUtc` and `AllianceTag`, but its source
`dbo.vAllianceActivity_WeeklyDelta` exposes only `GovernorName`, `GovernorID`,
`BuildingDeltaWeek`, and `TechDonationDeltaWeek`.

Repository, bot, and SQL Server discovery found:

- zero executable SQL, export, report, or bot consumers;
- zero SQL dependency rows other than the invalid definition's own source
  reference;
- zero explicit permissions;
- zero signatures; and
- zero extended properties.

The exact accepted definition SHA-256 was
`DD5C6AC7E3D179463AB22C2618026A0479BC8A0C0D9564D766F1553237465CF4`.
`20260727_000_retire_vAllianceActivity_WeeklyCumulative.sql` passed all guards,
dropped the object in the isolated database, and left it absent after rollback
and reapply. Retirement is intentionally forward-fix-only: rollback never
recreates a known-invalid unused object.

## Forward, rollback, and reapply receipts

The migration originally exposed a batch fall-through risk: a failed guard in
an earlier `GO` batch could still leave a later DDL batch runnable. The final
forward and rollback packages use guarded dynamic DDL, so no definition change
can execute after a failed prerequisite.

The representative sequence then completed:

| Step | Duration | Active players | MGE review | Daily export | Global latest | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Forward | 8 s | 411 | 56 | 223,386 | 411 | Pass |
| Rollback | 7 s | 411 | 56 | 223,386 | 411 | Pass |
| Clean reapply | 7 s | 411 | 56 | 223,386 | 411 | Pass |

Every forward and rollback transaction:

- held the migration and import mutexes;
- checked the exact accepted prior-definition hashes;
- refreshed all retained transitive SQL consumers;
- materialized all four changed views;
- compared row counts and bidirectional `EXCEPT`;
- compared ordinal, alias, system/user type, length, precision, scale,
  collation, and nullability; and
- committed only after every comparison passed.

The select casts on `dbo.v_Active_Players.GovernorID` and
`dbo.vw_Governor_KVK_Summary_GlobalLatest.GovernorId` are retained because
removing them changed `sys.columns.is_nullable` from the established nullable
contract to non-nullable. Phase 4 removes obsolete join-side compensation
without changing consumer-visible nullability.

## Verification and materialization

`02_verify.sql` initially exposed a verifier-only defect: SQL `LIKE` treated
the brackets in `[Troops Power]` as a character class. The final verifier uses
exact `CHARINDEX` definition checks. The corrected run completed in 3 seconds:

- all 21 retained transitive SQL targets refreshed and compiled;
- 269 result-metadata rows were captured;
- all latest, daily, WTD, global-latest, export, profile, account, and
  stats-window consumers materialized;
- exact retained definition checks passed; and
- `dbo.vAllianceActivity_WeeklyCumulative` remained absent.

The focused mapped bot/DAL suite passed `164` tests in `7.86 s`, covering the
stats-alert, weekly-activity, KVK-state/history, fallback-import,
player-account, governor-dashboard, and leadership-review consumer paths.

## One-warm-up plus five-measured benchmark

The first benchmark collector sampled `sys.dm_exec_sessions`, which cannot
measure the running request. The final collector samples
`sys.dm_exec_requests`. The corrected 78-execution run completed in 38 seconds.
Every view returned one normalized digest and stable row counts across all five
measured executions.

| View | Median ms | Average ms | Average CPU ms | Average reads | Rows |
| --- | ---: | ---: | ---: | ---: | ---: |
| `dbo.v_Active_Players` | 10.311 | 8.314 | 8.800 | 600.400 | 411 |
| `dbo.v_GovernorNames` | 245.448 | 246.871 | 387.200 | 34,962.600 | 2,371 |
| `dbo.v_KVK_Under50_Last3_WithLatest` | 2.945 | 5.781 | 6.600 | 1,669.800 | 19 |
| `dbo.v_MGE_SignupReview` | 13.577 | 15.530 | 15.600 | 2,339.200 | 56 |
| `dbo.v_PlayerLatestStats` | 78.740 | 79.060 | 80.200 | 10,491.400 | 2,371 |
| `dbo.vDaily_Helps` | 190.000 | 193.578 | 1,174.000 | 19,062.200 | 184 |
| `dbo.vDaily_PlayerExport` | 4,294.912 | 4,332.131 | 7,499.600 | 189,910.800 | 223,386 |
| `dbo.vDaily_RSSAssisted` | 199.186 | 198.587 | 1,189.600 | 19,057.600 | 10 |
| `dbo.vDaily_RSSGathered` | 198.283 | 199.158 | 1,167.400 | 19,059.000 | 203 |
| `dbo.vWTD_Helps` | 368.910 | 370.650 | 2,083.000 | 46,653.200 | 197 |
| `dbo.vWTD_RSSAssisted` | 365.482 | 365.628 | 2,064.400 | 46,655.800 | 1 |
| `dbo.vWTD_RSSGathered` | 370.066 | 368.186 | 2,084.600 | 46,666.400 | 224 |
| `dbo.vw_Governor_KVK_Summary_GlobalLatest` | 15.886 | 16.447 | 15.600 | 1,908.000 | 411 |

No comparable pre-change measured suite exists for a percentage-regression
claim, so these values are the locked same-state Phase 4 baseline. Stability,
value equivalence, and metadata equivalence passed; no unsupported improvement
claim is made.

## Actual-plan, grant, spill, and warning evidence

`04_capture_plan_evidence.sql` completed in 2 seconds and returned:

| Materialization | Rows |
| --- | ---: |
| `dbo.v_Active_Players` | 411 |
| `dbo.v_MGE_SignupReview` | 56 |
| `dbo.vDaily_PlayerExport` | 223,386 |
| `dbo.vw_Governor_KVK_Summary_GlobalLatest` | 411 |
| 30-day `dbo.fn_StatsWindowDeltas` | 480 |

The captured actual plan XML and `STATISTICS IO/TIME` receipts show:

| Workload | Grant requested / granted / max used KB | Warnings |
| --- | --- | --- |
| Active players | `0 / 0 / 0` | Two cardinality-estimate `CONVERT_IMPLICIT(varchar(12), PlayerLocation.X/Y, 0)` warnings; unrelated to the Phase 4 KS4 ID cleanup |
| MGE review | `206,528 / 206,528 / 4,336` | Excessive grant |
| Daily player export | `635,080 / 635,080 / 236,544` | Level-1 hash spill; 6,104 TempDB pages written and 6,104 read |
| Global latest | `136,432 / 136,432 / 3,824` | Excessive grant |
| 30-day stats window | `587,336 / 587,336 / 113,664` | No warning node |

The daily-export execution recorded 16 workfile scans, 6,104 logical reads,
459 physical reads, and 5,645 read-ahead reads. These are baseline query-shape
findings carried forward for later optimization; the changed-view
forward/rollback equivalence and stable repeated workload provide no evidence
that Phase 4 introduced them.

## Exit-gate receipts

- Phase 4 static contracts: passed with four forward and four rollback
  definitions checked.
- Phase 3, Phase 2 history/finalization, and Phase 1 benchmark-seed regression
  guards: passed.
- SQL repository validation: passed; only pre-existing destructive-operation
  advisory warnings were emitted.
- `git diff --check`: passed.
- Final SQL Changes review, Deep off: scan
  `e6ce0a1d-7aba-428a-b40a-61001c924143`, reviewed snapshot
  `codex-security-snapshot/v1:sha256:a00ac727cab59a0ed585b7e6f615a3391fc792d95a1165c624c0328e978a909b`,
  13/13 canonical source-like worklist rows completed, zero deferred rows, and
  zero reportable findings.

The post-scan changes are limited to these status and receipt records. They do
not alter SQL tokens, executable behavior, tooling, configuration, permissions,
deployment behavior, or runtime contracts and therefore use a documented
security-review skip.

Production execution remains unauthorized.
