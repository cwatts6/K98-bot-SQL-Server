# P02.1 retained summary-cost evidence — 7 November 2026

> **Approved rewrite implemented and locally qualified — 7 November 2026.** All eight metric routines and the alternate healed routine now use compact temporary endpoints. The complete focused local SQL suite passed 30 tests, including output parity, permissions and atomic rollback/cache restoration. See [implementation and qualification](p021-summary-implementation.md). No production deployment or retained VM workload ran; limits and remaining consumer/signing/full-rehearsal gates are unchanged. Earlier approval-pending wording below is historical.


> **Complete retained evidence and rewrite proposal — 7 November 2026.**
> All 192 retained plans are complete; all 184 summary cost records match the
> earlier attribution and all 12 captured module hashes are unchanged. Incoming
> static cache references cover ten modules, but broad grants leave external
> usage to settle before production retirement of cache refresh. The
> [concrete optimisation proposal](p021-summary-optimisation-proposal.md)
> recommends temporary endpoint calculation from existing shared history,
> with final/delta/latest outputs preserved and explicit legacy-cache/rollback
> handling. This resolves the earlier truncated-plan collection gap below.
> No further collection or diagnostic import is needed to decide the proposal.
> Summary implementation and candidate savings are not yet approved/proven.


Receipt `P021-summary-cost-evidence-61b9a986c13941de89dcf3f320cfbb21.json`
completed read-only with zero errors at 20:38:33 UTC. The retained VM/database
containment passed: no network adapters, database read-only/restricted, Broker
and trust disabled, no target requests or active snapshots, version store zero,
disk free 9,914,949,632 bytes. No workload or configuration change occurred.

## What the saved evidence establishes

Query Store retained statement measurements from the ON rehearsal. All nine
parent/child definition hashes match the earlier workload profile. There are
184 unique plan/query/interval-boundary rows inside the exact summary phase
19:48:51.711–19:50:59.300 UTC. Each reports one regular execution. All 56 expected
cache DELETE/INSERT pairs are present. This is stronger than outer-stage timing,
although AUTO capture can omit other statements and the collector omitted numeric
interval IDs. Historical name-procedure rows outside the run are excluded.

| Work in the ON summary stage | Statement time | SQL-reported row actions | Log bytes |
| --- | ---: | ---: | ---: |
| Delete from 32 history/window work tables | 80.786 s | 5,416,720 | 2,210,793,108 |
| Reinsert into those 32 tables | 38.056 s | 5,362,216 | 2,492,521,260 |
| Delete/reinsert 24 smaller delta tables | 1.144 s | 19,896 | 4,780,756 |
| Other captured summary statements | 2.477 s | Mixed SELECT/DML; do not count as mutations | 4,048,408 |

The large history rebuilds account for **118.841 of 127.589 seconds (93.14%)**
of the enclosing phase and **10,778,936 reported delete/insert row actions** for
the 415-row import. The 4.380 GiB of reported log bytes for those statements is
not version-store usage. Captured statement time totals 122.463 seconds, leaving
5.126 seconds unassigned; do not invent an explanation for that remainder.

| Child | Sum of captured statement time |
| --- | ---: |
| Ranged | 28.080 s |
| Healed | 26.250 s |
| Kill points | 17.663 s |
| T5 kills | 12.628 s |
| Combined T4/T5 kills | 9.837 s |
| Power | 9.479 s |
| T4 kills | 9.439 s |
| Deaths | 8.845 s |

Largest single recorded delete: HEALED_ALL, 10.717 s, reported 268,954 rows;
RANGED_ALL follows at 9.377 s for the same reported row count. A complete saved
RANGED_ALL plan shows an affected-governor scan feeding index seeks, then heap
and nonclustered-index deletion with a sort. This is compiled-plan structure;
it does not prove actual per-operator row counts, waits or spills. It does show
that an index already supports the governor lookup, so a generic missing-index
recommendation is not supported by this plan alone.

The existing death-cache measurements illustrate the expiry contract: all-history
rows change from 268,954 deleted to 269,369 inserted; 12-month rows from 205,367 to
200,864; 6-month 128,111 to 126,966; 3-month 74,658 to 73,078. The insert/delete
difference is not simply the 415 newly imported rows. Window membership and
rank updates must remain explicit in any incremental alternative.

## Scope and next decision

The measured optimisation target is the **four persisted history/window caches
in each of eight children (32 tables)**. Preserve latest/final outputs, smaller
delta tables, metric state, transaction ordering and direct-call behavior while
designing the change. The already-shared #GovScan is a reusable input. Evaluate
temporary per-run calculations against compatible incremental maintenance; do
not assume that historical tables can be dropped or left stale.

The earlier proposal for an extra instrumented full OFF import is **not the next
step**: existing retained telemetry already attributes the dominant work. No
extra workload, Query Store enablement, trace or new observer is needed to obtain
the remaining plan/dependency evidence.

The first collector hit its 200-row and 50-plan limits; four returned plan XMLs
were truncated, and the expensive HEALED_ALL delete plan was outside the saved
plan slice. Runtime mapping contains all expected cache pairs, but neither full
plan coverage nor all incoming table consumers can be claimed. The next bounded
read-only supplement collects the exact rehearsal interval's counts/plans and
the 56 cache tables' incoming dependencies, definitions, indexes, allocations
and permissions. It checks counts and byte bounds before copying plans, uses
ISO timestamps and explicit interval IDs, and verifies definitions against this
receipt. No existing collector or receipt is overwritten.

`Collect-P021SummaryDetailEvidence.ps1` is ready for the retained Administrator
PowerShell session. Maximum 250 plans/16 MiB plan bytes/1 MiB per plan and 2,000
runtime rows; reaching metadata caps or changed counts stops for review. Both
scripts parse in Windows PowerShell 5.1, the guest script is hash-pinned, and all
14 literal SELECT query shapes executed successfully against local SQL16.
The initial message-string quoting defect was caught before guest execution,
corrected, and the checks rerun successfully.

Analysis: `analyse_summary_costs.py`, `summary-cost-analysis.json` and four passing
timestamp/weighted-total tests in `test_summary_cost_analysis.py`. The analysis
asserts exact run window, regular single executions, unique retained interval
keys, all 56 paired targets and nine unchanged module definitions. No SQL-facing
runtime source changed in this follow-up; no new formal security scan is claimed
for the private read-only collector. Manual review checked literal SELECTs,
identity/containment/hash bounds and absence of workload/settings/file writes in
the guest. SQL implementation and signed-release integration remain separate.

Metric units and interval aggregation rules were checked against Microsoft's
[Query Store runtime statistics reference](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql?view=sql-server-ver16).
Durations are microseconds; logical I/O and tempdb metrics are page counts; log
usage is bytes. None supplies per-table row-version bytes. This ON-only evidence
does not explain the entire OFF-to-ON difference or promise a measured saving
from an unimplemented candidate. Original snapshot storage failure and limits
remain unchanged.
