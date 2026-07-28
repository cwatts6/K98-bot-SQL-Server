# Phase 4 baseline contracts

Status: baseline assignments frozen. `01_preflight.sql` captures the immediate
pre-change rows, normalized digests, definitions, metadata, dependency closure,
latest scan/date, and ordering assumptions from the accepted Phase 3 database.

## Exact prior definitions

The rollback source is commit `62cb739`.

| Changed view | Frozen definition SHA-256 |
| --- | --- |
| `dbo.v_Active_Players` | `41F2E83E2EC702CA226347C6ED29DC2CB3EB9298681BD3F26AE51CD0CAF89A24` |
| `dbo.v_MGE_SignupReview` | `61EE372A5C89F0BC283470AF1D580C4376073BD4D97D79DC2F21E0908414E8B2` |
| `dbo.vDaily_PlayerExport` | `DC7421B4AD6AAD56182737696561814C58B9AD16ED72145DD4AB6B47606FD3E1` |
| `dbo.vw_Governor_KVK_Summary_GlobalLatest` | `2D3C0D412623FB783482C53AEA94639AFD6910CD515662F98CCABFC6203644D7` |

The migration refuses any mismatch before changing a definition. The rollback
contains the exact four prior definitions and runs before Phase 3/2 rollback.

## Retained Phase 1/2 measurements

These values are historical comparison points, not substitutes for the
immediate Phase 4 preflight receipt.

| View | Median ms | Average logical reads | Rows | Digest/status |
| --- | ---: | ---: | ---: | --- |
| `dbo.v_PlayerLatestStats` | 63.433 | 14,264.0 | 2,371 | Stable |
| `dbo.vDaily_Helps` | 655.318 | 69,801.6 | 184 | Stable |
| `dbo.vDaily_PlayerExport` | 788.019 | 90,803.6 | 223,386 | Stable |
| `dbo.vDaily_RSSAssisted` | 643.984 | 68,980.0 | 10 | Stable |
| `dbo.vDaily_RSSGathered` | 654.976 | 69,788.6 | 203 | Stable |
| `dbo.vWTD_Helps` | 496.061 | 149,848.0 | 197 | Stable |
| `dbo.vWTD_RSSAssisted` | 489.194 | 149,890.8 | 1 | Stable |
| `dbo.vWTD_RSSGathered` | 499.981 | 149,838.2 | 224 | Stable |
| `dbo.vw_Governor_KVK_Summary_GlobalLatest` | 15.950 | 2,443.8 | 411 | Stable |

The isolated Phase 2 confirmation subsequently recorded:

- `vDaily_PlayerExport`: 603.284 ms median, 223,386 rows, digest
  `3EB8E0C681DC9CAAA541B79FB1034C6F5890CFD40E6CE356C42870245635422A`;
- `vw_Governor_KVK_Summary_GlobalLatest`: 19.337 ms median, 411 rows;
- `v_PlayerLatestStats`: approximately 64.258 ms median.

## Immediate Phase 4 scenarios

| Surface | Parameters/boundary | Required comparison |
| --- | --- | --- |
| All 13 views | Complete materialization | Exact rows, normalized digest, aliases, column order, types, scale/precision, collation, nullability |
| Latest views | Global latest and per-governor latest | Exact scan choice, missing governor, null values, and no duplicate drift |
| Daily views | Latest day, prior day, empty/zero delta | Exact positive filters, totals, baseline null rules, and day boundary |
| WTD views | Monday start, prior-before-week, first-in-week | Exact reset handling, baseline date/value, positive filters, and week boundary |
| Global latest | Current/previous KVK rows | Exact rank, kills, target percentages, nulls, and 411-row representative materialization |
| MGE review | Active signups | Exact latest power/KVK, award counts, flags, aliases, and caller-owned order |
| Player export | Full history/large range | Exact 56-column shape, daily deltas, activity/rally joins, 223,386-row reference scale |
| Stats windows | 30-day latest window and governor CSV | Exact aggregates, aliases, types, and procedure result-set order |
| Bot/DAL | Eight Phase 1 mapped paths | Exact values/types/nulls/order described in `phase1/bot_dal_contract_map.md` |

## Performance policy

`03_run_view_benchmarks.sql` performs one warm-up plus five measured
materializations for every mandatory view and requires one row count and digest
across the measured runs. `04_capture_plan_evidence.sql` captures actual XML
plans plus IO/TIME for the four changed views and the principal stats-window
consumer.

Any approximately 10 percent or greater regression in median duration, CPU,
logical reads, or throughput must be resolved or justified under the task-wide
policy. Absolute differences at very small runtimes are assessed with both
percentage and practical impact.
