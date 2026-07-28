# Phase 4 view and consumer inventory

Status: frozen from `codex/kingdomscandata4-phase3` at `62cb739` and repository
rediscovery on 2026-07-27. Production execution is not authorized.

## Decision summary

The final Phase 2/3 source types require executable cleanup in four views. Nine
mandatory views retain their definitions because their conversions, trimming,
date boundaries, null rules, aggregation, and window semantics are contractual.
One unrelated, already-invalid legacy view is retired under the operator's
approved deferred-optimisation decision.

| View | Source relationship | Phase 4 decision | Contract reason |
| --- | --- | --- | --- |
| `dbo.v_Active_Players` | Direct KS4 | Change | Retain the result-side `GovernorID bigint` cast because it preserves nullable metadata; remove no consumer-facing semantics and preserve all 24 columns and the no-order contract |
| `dbo.v_GovernorNames` | Direct KS4 | Validate only | Trimming implements blank-to-null, historical fallback, and display semantics |
| `dbo.v_KVK_Under50_Last3_WithLatest` | Direct KS4 | Validate only | `KillPercent decimal(9,2)` conversion belongs to `PlayerKVKHistory`; latest scan/location and threshold semantics remain |
| `dbo.v_MGE_SignupReview` | Direct KS4 | Change | Align the KS4/signup bigint join; preserve all warning, award, null, and active-signup rules |
| `dbo.v_PlayerLatestStats` | Direct KS4 | Validate only | Already inherits final types directly; preserve per-governor latest-row selection and aliases |
| `dbo.vDaily_Helps` | Direct KS4 | Validate only | Preserve day-end choice, latest-date boundary, null handling, and positive-delta filter |
| `dbo.vDaily_PlayerExport` | Direct KS4 plus daily activity/rally | Change | Remove only compensation for the Phase 2 bigint columns; retain float/target-width conversion, trimming, daily windows, aliases, and 56-column order |
| `dbo.vDaily_RSSAssisted` | Direct KS4 | Validate only | Preserve day-end choice, latest-date boundary, null handling, and positive-delta filter |
| `dbo.vDaily_RSSGathered` | Direct KS4 | Validate only | Preserve day-end choice, latest-date boundary, null handling, and positive-delta filter |
| `dbo.vWTD_Helps` | Direct KS4 | Validate only | Preserve Monday boundary, prior/first baseline fallback, reset handling, and positive-delta filter |
| `dbo.vWTD_RSSAssisted` | Direct KS4 | Validate only | Preserve Monday boundary, prior/first baseline fallback, reset handling, and positive-delta filter |
| `dbo.vWTD_RSSGathered` | Direct KS4 | Validate only | Preserve Monday boundary, prior/first baseline fallback, reset handling, and positive-delta filter |
| `dbo.vw_Governor_KVK_Summary_GlobalLatest` | Direct KS4 plus dashboard | Change | Remove obsolete join-side bigint compensation, retain the result-side cast that preserves nullable metadata, and preserve global-latest and latest/previous KVK ranking |

## Transitive SQL consumers

Repository definition search and the recursive dependency collector in
`01_preflight.sql` establish this transitive SQL worklist.

| Consumer | Dependency | Contract |
| --- | --- | --- |
| `dbo.v_GovernorNames_Strict` | `v_GovernorNames` | Nonblank governor names only; no view order |
| `dbo.vAllianceActivity_DailyDelta` | `v_GovernorNames` | Direct bigint join; name fallback only |
| `dbo.vAllianceActivity_WeeklyDelta` | `v_GovernorNames` | Direct bigint join; weekly aggregation unchanged |
| `dbo.v_PlayerProfile` | `v_PlayerLatestStats` | Profile aliases, nulls, and latest values unchanged |
| `dbo.v_PlayerAccounts_Migrate` | latest stats/profile | Account migration join and column order unchanged |
| `dbo.fn_StatsWindowDeltas` | `vDaily_PlayerExport` | Date-window sums and result types unchanged |
| `dbo.fn_StatsWindowDeltas_GovCsv` | `vDaily_PlayerExport` | Governor CSV filtering and date-window sums unchanged |
| `dbo.usp_GetPlayerStatsWindows` | daily export and CSV function | Result-set count, aliases, order, and window boundaries unchanged |

`vDaily_AllianceActivity` and `cur_RallyDaily` are upstream inputs to
`vDaily_PlayerExport`; they are compilation and materialization controls, not
Phase 4 definition changes.

The representative-copy rehearsal on 2026-07-27 found that
`dbo.vAllianceActivity_WeeklyCumulative` is already unmaterializable before
Phase 4: its definition and stale six-column metadata require `WeekStartUtc`
and `AllianceTag`, while `dbo.vAllianceActivity_WeeklyDelta` exposes only
`GovernorName`, `GovernorID`, `BuildingDeltaWeek`, and
`TechDonationDeltaWeek`. Repository SQL search, SQL Server dependency metadata,
and a read-only search of the separate bot checkout found no executable
consumer. The bot deferred-optimisation backlog already assigned the object for
retirement if that audit found no use. The operator approved that retirement on
2026-07-27.

`20260727_000_retire_vAllianceActivity_WeeklyCumulative` therefore removes the
invalid object before the type-alignment migration. It fails closed on
definition drift, any referencing SQL module, explicit permission, signature,
or extended property. The retirement is forward-fix-only: recreating the known
invalid definition would provide false rollback safety. A future approved
consumer must receive a new valid contract through a new migration.

After retirement, `01_preflight.sql`, the alignment migration, and
`02_verify.sql` compile the 21 retained transitive targets only.

## Export, report, and bot/DAL consumers

The Phase 1 bot/DAL contract map remains authoritative for external consumers.

| Consumer path | SQL surface | Locked Phase 4 smoke |
| --- | --- | --- |
| `embed_offseason_stats.py` / stats-alert embed owner | Six daily/WTD leaderboard views | Exact ordered top-5 daily and top-10 weekly tuples, empty fallback, aliases and integer values |
| `weekly_activity_importer.py` | KS4 cohort plus governor-name/activity view chain | Exact allied-governor cohort and completion behavior |
| `kvk_state.py` | KS4 latest scan | Exact max scan and KVK fallback/state behavior |
| `kvk/dal/kvk_history_dal.py` | KVK/dashboard history chain | Candidate order, values, aliases, types, nulls, and metric ranks |
| `stats/dal/fallback_import_dal.py` | KS4 latest snapshot | Exact ordered 35-column DataFrame and 411-row representative shape |
| `player_self_service/accounts_dal.py` | Latest KS4/account profile chain | Five requested IDs, one row each, ascending SQL order, aliases/types/nulls |
| `player_self_service/governor_dashboard_dal.py` | Latest KS4/dashboard chain | Existing/absent governor exact-one-row contract |
| `leadership_player_review/dal.py` | Phase 3 procedure contracts | Lookup/existence/review/identity/KVK/last-active result-set contracts |
| Daily player export job/report | `vDaily_PlayerExport` | Full materialization, exact 56-column order, row count, digest, and export serialization |
| MGE signup review flow | `v_MGE_SignupReview` | Active signups, latest stats/KVK, award counts, warning flags, and caller-defined ordering |

The four bot source cleanups and immutable-file handoff remain Phase 5. Phase 4
does not edit bot runtime code; it closes only the existing deferred backlog
entry for this retired view.

## Ordering and metadata rules

- None of the 13 views promises row order.
- Daily and WTD leaderboard callers own explicit metric-descending/name-ascending
  ordering and their `TOP` limits.
- Window functions retain their existing `GovernorID` partition and date/scan
  ordering.
- The alignment forward and rollback migrations snapshot every changed result, compare
  row counts plus bidirectional `EXCEPT`, and compare column ordinal, alias,
  system/user type, length, precision, scale, collation, and nullability.
- The isolated forward probe proved that removing the result-side casts on
  `v_Active_Players.GovernorID` and
  `vw_Governor_KVK_Summary_GlobalLatest.GovernorId` changes
  `sys.columns.is_nullable` from the established nullable contract. Those casts
  therefore remain; the obsolete join-side compensation does not.
- `01_preflight.sql`, `02_verify.sql`, and `03_run_view_benchmarks.sql` cover all
  13 retained mandatory views. The alignment migration and rollback refresh
  every retained SQL consumer listed above.

## Scope exclusions

- No table, index, permission, procedure, function, bot runtime, import-file, or
  production-data change. The obsolete view itself is intentionally removed.
- The two Phase 3 Low/P3 mutable-file findings remain Phase 5/combined-release
  blockers.
- No conversion is moved to the opposite side of a join.
- No trim, date, display, target-width, overflow, or untrusted-data conversion
  is removed.
