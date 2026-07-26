# KingdomScanData4 bot/DAL result-contract map

## Scope and evidence boundary

This is the Phase 1 Gate 4 contract map for the eight bot paths named in
`closure_matrix.md`. It is a read-only source review of the separate
`C:\discord_file_downloader` Git repository at commit
`46e5a9cd58a4f475557904226656b2b8cc39dbb2`. No bot file was changed.

SQL types below are the explicit SQL output types where the query casts them. Where an expression
inherits a source type, the entry records the Python/DAL type and null contract that the caller
actually enforces. `nullable` means SQL `NULL` is accepted by the current caller; it does not
weaken a source column's schema nullability.

## Source receipts

| Path | SHA-256 |
| --- | --- |
| `embed_offseason_stats.py` | `0E583C6D310DD0ACE0CD08FEA84AEBEE9D853C844309C334C78AFD10EC828AF5` |
| `weekly_activity_importer.py` | `3919DC7B47BD026B184AC578F7AE0B130BD63F71864B359DA2569B283246D2DB` |
| `kvk_state.py` | `DE8D2FB4694164A4150E147A6148D85B340EF8C23E0EDB1DF16E623886008F59` |
| `kvk/dal/kvk_history_dal.py` | `B05DA85D3BC280E02282C74FF7200AB106C5A5078BD79D13D22C473765A3DB03` |
| `stats/dal/fallback_import_dal.py` | `4E633B7784E49F1413184FF97BD19109D92C3412298F23946E8EFB8FD6BAEA88` |
| `player_self_service/accounts_dal.py` | `D586B38D93BA37ED4C57618E25BED99E8436741E0E8E8079931C69305BE08488` |
| `player_self_service/governor_dashboard_dal.py` | `C63D1BF8345355B403859FC7E1F291756D3DBE6AB50F177C96974052D41721D4` |
| `leadership_player_review/dal.py` | `AE8E7DF5E2AEFFD9F8B84AC052625EABC430431671EAAF90D8FF351724ECC3EE` |

Transitive owner receipts used to verify mapping were
`stats_alerts/embeds/offseason.py`
`C0DE01724D997BDFA4BCA9525B616D450D0CAC0DB92667052B49235E4365F571`,
`upload_routes/weekly_activity_route.py`
`B5D8A95DC4231D483272049D31A93AEEFBF55EF8AB878338D4522D24A63C261F`,
`services/kvk_history_service.py`
`A929329F2E6DF846E3E4B4C89D12EF7D9F00D88E29EB3BAD98C31E935BEFAD72`,
`stats_module.py`
`DD0816F315B78C3C1E69DF01E18766C558339EFCFB5F9C69275C31BEDD6BE1EB`,
`player_self_service/accounts_service.py`
`B91ED9589DB4DF305194B02A6097A47550B1A1DFA071DF8A9597FF1CB0C5A982`,
`player_self_service/governor_dashboard_service.py`
`EE87ED2D89BF5389F65FC05161D2C9E9E2F281A635AD7D30D598791768D51B86`,
and `leadership_player_review/service.py`
`37011489834D34C8CA74CBA88EDB556239EE6A4517023E8EA32F47A72F5F9598`.

## 1. `embed_offseason_stats.py`

**Caller/owner.** `stats_alerts/embeds/offseason.py:send_offseason_flow` owns the daily and weekly
embed flows.

**SQL and parameters.**

- `get_kingdom_summary` reads `dbo.KingdomScanData4`; parameters are current/previous
  `SCANORDER` values inherited from `MAX(SCANORDER)`.
- `get_kingdom_summary_weekly` reads the same table with `date` week boundaries and
  `SCANORDER` boundary parameters.
- Daily leaderboards read `dbo.vDaily_Helps`, `dbo.vDaily_RSSGathered`, and
  `dbo.vDaily_RSSAssisted`.
- Weekly leaderboards read `dbo.vWTD_Helps`, `dbo.vWTD_RSSGathered`, and
  `dbo.vWTD_RSSAssisted`.

**Result contract.** Summary output is a dictionary of nullable SQL aggregates normalized to
Python `int`: current/previous scan order, current scan row count, and the `bigint` sum of the top
300 `Power` values for each boundary. The leaderboard contract is
`(GovernorName string, metric integer)`; blank names become the display fallback. Daily columns
are `GovernorName` plus respectively `HelpsDelta`, `RSSGatheredDelta`, and `RSSAssistedDelta`.
Weekly columns are `GovernorName` plus respectively `WTD_Helps`, `WTD_RSSGathered`, and
`WTD_RSSAssisted`. Daily rows are `TOP (5)` and weekly rows `TOP (10)`, ordered metric descending
then name ascending. The table-based top-300 subqueries order `Power DESC`.

**Smoke/equivalence.** On the representative copy at scan 1020, compare current/previous scan
orders, current row count, both top-300 totals, and exact ordered top-5/top-10 tuples. Include an
empty-result case and confirm aggregates become zero. After migration, rerun the existing daily
and WTD view materialization baselines before exercising the embed flow.

**Bot change decision.** A bot-repository change is approved for the coordinated release: move
the touched direct SQL into a dedicated stats-alert DAL and remove the `Power AS bigint` casts
made redundant by the corrected base type. Preserve aliases, integer semantics, null handling,
limits, fallbacks and order. Add focused DAL tests, retain this smoke, and run a separate
bot-repository Changes security review.

## 2. `weekly_activity_importer.py`

**Caller/owner.** `upload_routes/weekly_activity_route.py` validates the upload and dispatches
`ingest_weekly_activity_excel`.

**SQL and parameters.** `_load_expected_allied_governors` accepts a Python `datetime`, sends it as
the `datetime` parameter used by `CONVERT(date, ?)`, and reads the maximum KS4 `SCANORDER` whose
`AsOfDate` is on or before that date. It returns distinct nonblank-alliance
`TRY_CONVERT(bigint, GovernorID)` values. Completion is written through
`dbo.usp_SetAllianceActivitySnapshotCompletion`:

| Parameter | SQL type/nullability |
| --- | --- |
| `@SnapshotID` | `bigint`, required |
| `@CompletionState` | `nvarchar(24)`, required; `COMPLETE` or `PARTIAL` |
| five evidence counts | `int`, required and nonnegative |
| `@ValidatedAtUtc` | `datetime2(0)`, nullable; caller sends `NULL` |
| `@CompletionBasis` | `nvarchar(32)`, required by this caller |

The five counts are expected, observed, missing-expected, invalid-metric, and missing-metric.

**Result contract.** The cohort read is a Python `set[int]`; SQL row order is deliberately
irrelevant. The importer returns `(snapshot_id int, delta_row_count int)`. A duplicate source
returns `(0, 0)`. The completion procedure returns no result set; success is transactional, and
any failure rolls back the ingest.

**Smoke/equivalence.** Use the existing valid complete workbook, duplicate retry, and partial
workbook cases. Verify the same expected cohort, positive snapshot/delta counts for a new complete
file, `(0, 0)` for duplicate input, `COMPLETE` only with zero evidence gaps, and `PARTIAL` when a
gap exists.

**Bot change decision.** A bot-repository SQL change is approved for the coordinated release:
read the final bigint governor value directly and remove the obsolete `nvarchar(255)` alliance
conversion. Retain blank-alliance normalization, `CONVERT(date, ?)` and the cohort/completion
contract. Update importer, upload-route and audit-service tests and run the bot-repository Changes
security review.

## 3. `kvk_state.py`

**Caller/owner.** This module owns KVK-state resolution. Callers include the honor importer,
stats-alert KVK metadata, KVK target services, personal views, and target caches/utilities.

**SQL and parameters.** `_get_max_scan_order` has no parameter and reads
`MAX(ScanOrder)` from `ROK_TRACKER.dbo.KingdomScanData4`. `get_latest_kvk_details` takes an
optional Python `date`, reads `TOP (1)` from `dbo.KVK_Details`, and falls back to
`dbo.ProcConfig` keys `CURRENTKVK3`, `MATCHMAKING_SCAN`, and `KVK_END_SCAN`.

**Result contract.** Max scan is `int | None`. The latest KVK row is ordered `KVK_NO DESC` and
maps: `KVK_NO int` required; `KVK_NAME string`, registration/start/end dates,
matchmaking/fighting dates, `MATCHMAKING_SCAN`, `KVK_END_SCAN`, and `PASS4_START_SCAN` nullable.
ProcConfig numeric text is converted to `int | None`. The derived state is one of `DRAFT`,
`ACTIVE`, or `ENDED`; no SQL ordering is consumed outside the explicit latest-KVK order.

**Smoke/equivalence.** With KS4 maximum scan 1020 and the retained latest KVK row, compare every
typed dictionary field and derived state. Also run the ProcConfig fallback with a missing details
row and preserve `None` behavior.

**Bot change decision.** No bot change is required for an integral `ScanOrder` source if the
maximum and KVK boundaries retain their values/nulls. Key, state, or fallback changes require bot
changes.

## 4. `kvk/dal/kvk_history_dal.py`

**Caller/owner.** `services/kvk_history_service.py` owns candidate resolution, legacy DataFrame
normalization, modern history payloads, and summary ranks.

**SQL, parameters, results, and ordering.**

- `fetch_output_complete_kvk_candidates(limit)` bounds the integer to 1-20 and returns
  `KVK_NO int` required; `PASS4_START_SCAN int`, `KVK_END_SCAN int`, and current KS4
  `MaxScanOrder` nullable; `FinalOutputState string` required for returned rows. Rows are ordered
  `KVK_NO DESC`.
- `fetch_history_rows_for_governors` uses nonempty integer governor-ID and finalized-KVK lists.
  It returns `Gov_ID bigint`, `Governor_Name string`, `KVK_NO int`, `T4_KILLS`, `T5_KILLS`,
  `T4T5_Kills`, `Deads`, `DKP_SCORE`, pass 4/6/7/8 kills and deads as `bigint`, and `KillPct`,
  `DeadPct`, `DKPPct` as `decimal(9,2)`. SQL has no `ORDER BY`; the owner service sorts
  `Gov_ID, KVK_NO` and fills missing numeric values with zero.
- `fetch_modern_history_rows_for_governors` uses the same list contract and preserves nulls. It
  returns `Kingdom_Rank int`, `KVK_RANK int`, `Gov_ID bigint`, `Governor_Name string`,
  `KVK_NO int`; `T4_KILLS`, `T5_KILLS`, `T4T5_Kills`, `Kill_Target`, `Deads`, `Dead_Target`,
  `DKP_SCORE`, `DKP_Target`, `Acclaim`, `HighestAcclaim`, `AutarchTimes`, `MostKvKKill`,
  `MostKvKDead`, `MostKvKHeal`, `HealedTroopsDelta`, `KillPointsDelta`,
  `Max_PreKvk_Points`, `Max_HonorPoints`, and pass 4/6/7/8 kills/deads as `bigint`;
  `KvKPlayed int`; and `KillPct`, `DeadPct`, `DKPPct` as `decimal(9,2)`. Rows are ordered
  `Gov_ID, KVK_NO`.
- `dbo.usp_GetKvkHistorySummaryMetricRanks` accepts `@GovernorID bigint` plus
  `@FinalizedKvkNos dbo.IntList READONLY` (1-20 normalized positive IDs). It returns
  `Metric string`, `Gov_ID bigint`, `KVK_NO int`, `MetricValue decimal` and
  `Overall_Rank bigint`; metric rows with no value are omitted. Order is `Metric, KVK_NO`.

Except for the required identity/key fields noted above, history values are nullable at the DAL
boundary; legacy service normalization and modern null preservation are intentionally different.

**Smoke/equivalence.** Resolve output-complete candidates, then use high-activity, median, and
sparse governors over the same finalized KVK set. Compare candidate order; all legacy values
after its documented zero-fill/sort; every modern nullable value and its `Gov_ID, KVK_NO` order;
and exact metric/rank rows.

**Bot change decision.** No bot change is required if KS4 max scan conversion preserves the
candidate set and all output aliases/types/order. Changing legacy zero-fill, modern null
preservation, or result aliases requires a bot change.

## 5. `stats/dal/fallback_import_dal.py`

**Caller/owner.** `stats_module.py` owns fallback snapshot overlay/import behavior and task-status
polling.

**SQL and parameters.** `fetch_latest_fallback_snapshot` has no parameter and reads all rows for
the maximum KS4 `SCANORDER`. `record_fallback_import_control` inserts:
`SourceType nvarchar(64)` required, `SourceFilename nvarchar(260)`, `ScoreHeader nvarchar(64)`,
`ColumnsPresentJson nvarchar(max)`, `RowsInSource int`, and `RowsWritten int`, returning
`ControlId bigint`. Status methods pass `TaskName` as text to `dbo.SP_TaskStatus`.

**Result contract.** The snapshot is a pandas DataFrame with exactly these ordered aliases:
`Governor ID`, `Name`, `Power`, `Alliance`, `T1-Kills`, `T2-Kills`, `T3-Kills`, `T4-Kills`,
`T5-Kills`, `Total Kill Points`, `Dead Troops`, `Healed Troops`, `Rss Assistance`,
`Alliance Helps`, `Rss Gathered`, `City Hall`, `Troops Power`, `Tech Power`, `Building Power`,
`Commander Power`, `Civilization`, `Autarch Times`, `Ranged Points`, `KvK Played`,
`Most KvK Kill`, `Most KvK Dead`, `Most KvK Heal`, `Acclaim`, `Highest Acclaim`, `AOO Joined`,
`AOO Won`, `AOO Avg Kill`, `AOO Avg Dead`, `AOO Avg Heal`, `Credit`. Row order is not assumed.
The overlay treats `Name`, `Alliance`, and `Civilization` as nullable text, `Credit` as decimal,
and all other values as nullable integers. The control insert returns `int | None`; the interim
partial mode requires the table to exist. Counter output is one `int` defaulting to zero. Status
is one aggregate row with nullable `LastRunCounter int`, `LastRunTime datetime`, and
`DurationSeconds int`.

**Smoke/equivalence.** Run the retained partial-overlay scenario against the 411-row latest scan.
Require the exact ordered 35-column DataFrame, no duplicate normalized governor keys, identical
inherited values, stable integral formatting, a committed control row where applicable, and the
same counter/status semantics.

**Bot change decision.** No bot change is expected for conversion-safe float-to-integer source
changes, but the pandas dtype/normalization smoke is mandatory. Column alias/order, null, or
metadata-contract changes require a bot change.

## 6. `player_self_service/accounts_dal.py`

**Caller/owner.** `player_self_service/accounts_service.py:build_accounts_portfolio` calls
`fetch_latest_accounts_scan_rows` and re-associates results to registered account slots by
Governor ID.

**SQL and parameters.** Positive Python integers are deduplicated, split into chunks of at most
500, and sent as parameterized `VALUES (?)`; the `Requested` CTE casts each to `bigint`.
Query Store compiled the representative five-ID set
`(2441482, 46718337, 2510418, 85574801, 93858355)`.

**Result contract.** The `Requested` left-join shape guarantees one row per distinct requested ID:

| Columns | Driver/DAL type and nullability |
| --- | --- |
| `RequestedGovernorID` | `bigint` -> Python `int`, required |
| `GovernorName`, `Civilisation`, `VipLevelCode`, `VipLevelLabel` | string, nullable/blank-cleaned |
| `CityHall`, `LocationX`, `LocationY` | `int`, nullable |
| `Power`, `TroopPower`, `KillPoints`, `T4Kills`, `T5Kills`, `Deads`, `HealedTroops`, `HighestAcclaim`, `Helps`, `RSSGathered`, `RSSAssistance` | `bigint`, nullable |
| `Conduct` | numeric/`Decimal`, nullable |
| `ScanDate`, `LatestScanDate` | `datetime`, nullable at DAL boundary |

The SQL result is ordered by requested Governor ID ascending. The service does not preserve this
SQL order for presentation; it maps rows by ID back to account-slot order. Latest KS4 row choice
is `ScanDate DESC, SCANORDER DESC, AsOfDate DESC`. Missing governors still return their requested
ID and global latest date with governor-specific values `NULL`.

**Smoke/equivalence.** Execute the current DAL with the five compiled IDs, one warm-up and five
measured runs. Compare five ascending SQL rows, all values/types/nulls, exact digest, missing-ID
one-row behavior, and service `CURRENT`/`STALE`/`NO DATA` classification plus slot remapping.

**Bot change decision.** A bot DAL change is approved for the coordinated release: use direct
bigint `GovernorID` select/partition/join expressions and direct reads for newly typed integer
metrics. Keep checked conversion for unchanged float/text fields and keep name/civilization/VIP
blank normalization. Preserve aliases, one-row-per-request, latest-row, null, freshness, ascending
SQL order and service slot remapping; update the focused DAL tests and run the bot-repository
Changes security review.

## 7. `player_self_service/governor_dashboard_dal.py`

**Caller/owner.** `player_self_service/governor_dashboard_service.py` calls
`fetch_governor_dashboard_data`.

**SQL and parameters.** One positive Python integer is passed twice: as requested `bigint`, and
to the current legacy predicate `s.GovernorID = CONVERT(float, ?)`. Latest-row precedence is
`SCANORDER DESC, AsOfDate DESC, ScanDate DESC`.

**Result contract.** The left-join shape returns exactly one row:

| Columns | Driver/DAL type and nullability |
| --- | --- |
| `GovernorID` | `bigint` -> Python `int`, required |
| `GovernorName`, `Alliance`, `Civilization` | string, nullable/blank-cleaned |
| `Power`, `KillPoints`, `Dead`, `Helps`, `Healed`, `HighestAcclaim`, `AOOJoined`, `AutarchTimes`, `ScanOrder` | `bigint`, nullable |
| `AOOWon`, `KvKPlayed`, `LocationX`, `LocationY` | `int`, nullable |
| `Conduct` | numeric -> Python `float`, nullable |
| `UpdatedAtUtc` | `datetime`, nullable |

There is no result order dependency because exactly one row is required. An absent governor maps
to the requested ID with all optional fields `None`.

**Smoke/equivalence.** Use a high-activity existing governor and a known absent governor. Compare
exactly one row, every value/type/null, latest-row precedence, location/civilization joins, and
absent-row behavior.

**Bot change decision.** A bot DAL change is approved for the coordinated release: replace the
float governor predicate with a direct bigint predicate and remove casts made redundant by final
integer source types. Retain civilization mapping, display normalization and conversions for
unchanged source fields. Preserve aliases, nulls, exact-one-row and latest-row behavior; update
the focused DAL test, including its current float-predicate assertion, and run the bot-repository
Changes security review.

## 8. `leadership_player_review/dal.py`

**Caller/owner.** `leadership_player_review/service.py` owns lookup, review, identity, KVK, and
last-active orchestration. The DAL uses `cursor.description`, advances result sets explicitly,
and rejects missing or extra result sets where a fixed count is specified.

**Parameters.**

| SQL object | Parameter contract |
| --- | --- |
| `dbo.usp_GetLeadershipPlayerLookupDirectory` | `@HistoryDays smallint`, 1-720 |
| `dbo.usp_LeadershipPlayerGovernorExists` | `@GovernorID bigint`, positive |
| `dbo.usp_GetLeadershipPlayerReview` | `@GovernorID bigint`; `@PeriodDays smallint` (30/90/180/360); nullable `@NowUtc datetime2(0)` |
| `dbo.usp_GetLeadershipPlayerIdentityHistory` | `@GovernorIDs dbo.IntList READONLY`, 1-26 positive IDs; `@HistoryDays smallint`, 1-720 |
| `dbo.usp_GetLeadershipPlayerKvkHistory` | `@GovernorID bigint`; `@CandidateLimit tinyint`, 3-20 |
| `dbo.usp_GetLeadershipPlayerLastActive` | `@GovernorID bigint`; `@HistoryDays smallint`, 1-720; nullable `@NowUtc datetime2(0)` |

**Lookup and existence results.** Lookup returns
`GovernorID int`, `GovernorName string`, and `GovernorNameKey string` required by the mapper;
nullable `FirstSeen datetime`, `LastSeen datetime`, `CurrentGovernorName string`,
`CurrentAlliance string`, and `LastGovernorScanAtUtc datetime`; `SeenScanCount int` default zero;
and nonnull bit-like `PresentInLatestCompleteScan`, `IsCurrentName`. It is ordered Governor ID,
current-name first, last-seen descending, then name. Rows missing any required identity value are
dropped. Existence returns exactly one row, `GovernorID bigint` plus `ExistsInDatabase bit`; the
returned ID must match the requested ID.

**Review result contract.** Exactly six result sets are required, in this order:

1. Exactly one header row: required `GovernorID int`, `EffectiveNowUtc datetime2`, and
   `PeriodDays int`; nullable `GovernorName`, `CurrentAlliance`, `CurrentPower bigint`,
   `PowerRank int`, `CityHall int`, `AnchorDate`, current/previous start/end dates,
   `LatestCompleteScanOrder bigint`, `LatestCompleteScanAtUtc datetime`,
   `LatestGovernorScanOrder bigint`, `LatestGovernorScanAtUtc datetime`,
   `FirstObservedDate`, `FirstObservedOffsetDays int`, `LocationX int`, `LocationY int`,
   `LocationUpdatedAtUtc datetime`, and `ShieldEndsAtUtc datetime`; plus nonnull bit-like
   `PresentInLatestCompleteScan`.
2. Presence rows: `WindowCode string` and four nonnull/default-zero integers
   `CompleteScanCount`, `PresentScanCount`, `ScannedDayCount`, `PresentScannedDayCount`;
   ordered current then previous.
3. Coverage rows: `WindowCode`, `SourceCode`, `CoverageState` strings; `RequiredSource bit`;
   `ExpectedUnits`, `ValidUnits`, `MissingUnits`, `ResetCount` integers defaulting zero; ordered
   window then `STATS`, `ALLIANCE`, `RALLY`.
4. Metric rows ordered `MetricOrder`: `MetricOrder int`, `MetricCode string`;
   nullable-decimal `CurrentTotal`, `CurrentAveragePerValidDay`, `PreviousTotal`,
   `PreviousAveragePerValidDay`, `ComparisonPercent`, `PercentileScore`, `TopPercent`;
   nonnull/default-zero `CurrentValidReportingDays`, `PreviousValidReportingDays`,
   `CurrentExpectedUnits`, `CurrentMissingUnits`, `CurrentResetCount`; `ComparisonMode string`;
   `CurrentIsAvailable bit`; nullable `KingdomRank int`, `RankCohortCount int`.
5. One logical activity-index row: nullable decimals `ActivityIndex`, `FortsScore`, `HelpsScore`,
   `TechScore`, `RSSScore`, `BuildingScore`, `PowerScore`; nullable
   `ActivityRank int`, `ActivityRankCohortCount int`; required/defaulted `Availability string`.
6. History rows: `SourceCode`, `HistoryKind`, `EvidenceBasis` strings; nullable
   `EarliestObservedDate`, `LatestObservedDate`, `GapCount int`, `LongestGapDays int`;
   `ObservationCount int` defaulting zero; ordered by source.

**Identity, KVK, and last-active results.** Identity returns exactly two result sets. Aliases are
`GovernorID int`, `GovernorName string`, nullable `FirstSeen/LastSeen datetime`, and
`SeenScanCount int`, ordered Governor ID then last-seen descending/name. Episodes are
`GovernorID int`, `EpisodeSequence bigint`, `Alliance string`, nullable first/last observed dates,
`ObservedScanCount int`, and `IsCurrentEpisode bit`, ordered Governor ID then sequence.

KVK history returns exactly three result sets. Candidates are ordered `KVK_NO DESC` and contain
`KVK_NO int` plus nullable KVK name/dates/scan boundaries/finalization strings and timestamp.
Performance rows are ordered `KVK_NO DESC` and contain required `KVK_NO int` and
`GovernorID bigint`; nullable governor name; nullable integer ranks, T4/T5 kills, targets, kill
points, deads, healed, KP loss, acclaim, DKP, pre-KVK/honor values and cohort counts; nullable
decimal target percentages/tanking score; bit-like exemption/engagement; nullable finalization
timestamp/state/basis and healed-availability. The third set must contain exactly one matching
Governor ID with `KvkIndexValue decimal`, score/candidate/cohort counts and rank integers, and
`Availability` restricted to `AVAILABLE`, `PARTIAL`, or `NOT_RECORDED`; its value/rank/count
invariants are enforced.

Last-active returns exactly one matching-ID row: required `GovernorID bigint`,
`EffectiveUtcDate`, `HistoryStartDate`, `HistoryEndDate`, `ComparedCompleteScanCount int`, and
`HistoryDays int`; nullable `LastActiveDate`, `QualifyingSourceCode`,
`QualifyingScanOrder bigint`; and `ActivityState` restricted to `ACTIVE`, `INACTIVE`, or
`NOT_RECORDED`.

**Smoke/equivalence.**

- Lookup: `@HistoryDays=720`; retain the stable 1,639-row ordered digest.
- Existence: Governor 2441482 is present and 228689487 is absent; each call returns one matching
  row.
- Review: Governor 2441482, 90 days, `@NowUtc='2026-07-23T09:55:00'`; compare all six result-set
  ordinals, shapes, nulls, values, order, and digest for one warm-up plus five measured runs.
- Identity: high-activity, median, and sparse IDs with 720 days; compare two ordered sets.
- KVK: high-activity ID with candidate limit 12; compare all three sets and index invariants.
- Last active: high-activity ID, 720 days, pinned `@NowUtc`; compare the exact validated row.

**Bot change decision.** Type-only changes beneath the procedures require no bot change when every
parameter and result contract above remains identical. Any result-set count/order, alias,
nullability, enum, exact-one-row, or identity-match change requires a coordinated bot change and
separate bot-repository Changes review.

## Gate decision

All eight paths now have an owning caller/service, SQL object and parameter contract, output
shape/type/null/order assumptions, an exact smoke/equivalence scenario, and a bot-change decision.
The operator selected targeted cleanup in four paths (`embed_offseason_stats.py`,
`weekly_activity_importer.py`, `player_self_service/accounts_dal.py` and
`player_self_service/governor_dashboard_dal.py`) while preserving every documented external
contract. The other four paths remain source-unchanged but require their mapped smokes. Gate 4 is
complete for Phase 1 design purposes. These decisions are included in the approval checkpoint;
they do not by themselves authorise SQL or bot implementation.
