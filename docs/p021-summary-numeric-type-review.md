> **Integrated P02 scope, 7 November 2026:** This assessment is now part of the [combined SQL delivery plan](p02-integrated-sql-delivery-plan.md) and its canonical Bot P02 plan. Numeric alignment, export precision, original contention/maintenance obligations and recovery dependencies have one coordinated delivery sequence. Underlying-table review now covers all 75 tables / 325 columns, with no fractions or bigint conversion failures. The operator reports no known external use. Fresh installed-binding checks remain a release obligation; no type conversion or production deployment occurred.

# P02.1 summary numeric types: scope assessment

Date: 7 November 2026. Review requested by the operator while the approved
summary rewrite is undergoing isolated local qualification. No type conversion
has been implemented or deployed.

## Finding and recommendation

The repository evidence supports retained legacy design as the reason for float
in the affected count/identity fields, rather than a requirement for fractional
raw counts. This establishes the current contracts, not the original author's
intent or the exact values currently present in production.

Canonical KingdomScanData4 already declares GovernorID and all eight summary
metrics as bigint, with PowerRank and SCANORDER as int. Older power/deads/T4/T5/
combined-kills summary layers still use float, including IDs and ranks. The newer
healed/ranged summaries use bigint counts/IDs and int ranks. KillPoints counts
are bigint but some identity fields remain float. SUMMARY_CHANGE_EXPORT still
declares every numeric column as float, even metrics whose source is bigint.

Recommend a bounded summary-chain type-alignment follow-up: bigint for IDs,
whole-number counts and compatible signed deltas; int for proven bounded ranks
and scan numbers; an explicitly chosen decimal intermediate for averages before
the agreed rounding rule. Verify overflow headroom for subtraction and aggregate
sums. Do not convert all numbers to int: its maximum is 2,147,483,647. Genuine
fractional settings/weights and unrelated source fields require their own domain
decision and are outside this proposal.

## Rounding is a real behavior dependency

The existing routines use ROUND(AVG(metric),0). AVG(bigint) returns bigint and
discards the fractional part before ROUND can use it. AVG(float) retains a
fractional result. A read-only scalar experiment on local 9SX2VF4\K98DEV, using
only the constants 1 and 2, confirmed:

| Calculation | Result |
| --- | ---: |
| Float average | 1.5 |
| Float average rounded to a whole number | 2 |
| Bigint average, including after ROUND | 1 |
| Decimal average rounded to a whole number | 2 |

Thus a blind float-to-bigint replacement changes reported averages. Existing
healed/ranged and other bigint paths already have different fractional-average
behavior from the older float paths. This is a source-level inconsistency, not
proof of a particular incorrect production report. Agree whether to preserve
each existing rule or deliberately standardize rounding, including negative
deltas and halfway values, and test it separately. The approved endpoint rewrite
preserves the existing per-metric behavior and all current types.

## Expected benefit and evidence limits

Default SQL Server float and bigint both occupy eight bytes; int occupies four.
The local scalar experiment confirmed these lengths. Consequently bigint is not
an automatic storage reduction or a demonstrated speedup. Exact representation
of integer IDs/counts and removal of mixed-type conversions are the primary
design benefits; reads, CPU, elapsed time, grants, log and version-store effects
must be measured. Decimal averaging can itself add work. No performance gain
from type alignment has been measured here.

## Connection to existing deferred work

[Phase 3 downstream inventory](../performance_remediation/kingdomscandata4/phase3/downstream_inventory.md)
explicitly retained approximately 190 legacy float key/scan column entries,
including DALL and delta tables, pending separate writer/consumer and exact-value
proof. That count is a historical July inventory, not a fresh production count.
Its production deployment statements are also historical. This summary slice
belongs to that existing retained surface; it is not authorization to convert
all 190 entries. The Bot SUMMARY_PROC deferred item links this assessment.

Required next evidence for any type change:

1. Inventory actual deployed columns and every affected writer, reader, index,
   join and external/ad hoc report. Include all nine children, parent export,
   latest/delta/final outputs, retained-cache rollback and the legacy TEST path.
2. Read-only profile of fractional, out-of-range and NULL values; exact
   conversion/identity round trips and collision checks. A float cannot recover
   precision already lost; reconcile such cases to authoritative history.
3. Freeze output metadata and export compatibility. The Bot sheet configuration
   selects all columns from SUMMARY_CHANGE_EXPORT, so test Python/pandas and
   spreadsheet formatting, null handling and large integer transport as well.
4. Rehearse schema/index migration and rollback on an owned representative copy;
   test boundary values, averages, corrected history, duplicate/tied rows,
   overflow, output parity or explicitly approved differences, and direct calls.
5. Compare type-aligned candidate against the qualified endpoint-only candidate
   using the same input and unchanged performance/resource limits. Keep the
   established rewrite baseline so benefits and behavior changes are attributable.

The next full rehearsal may collect the bounded read-only numeric profile at the
same time as existing dependency checks. It must not silently apply conversions.
Production deployment remains separate. The approved rewrite's local tests do
not qualify a future datatype migration.

## Evidence

- Canonical sql_schema definitions: KingdomScanData4, POWERSUMMARY,
  HEALEDSUMMARY, RANGEDSUMMARY, KILLPOINTSSUMMARY and SUMMARY_CHANGE_EXPORT;
  summary child AVG expressions; July source-type remediation and Phase 3 record.
- Local private receipt: `.codex_artifacts/p021/summary-numeric-semantics.json`
  in the Bot workspace. Scalar SELECT only; no application data read or modified.
- [Microsoft integer types](https://learn.microsoft.com/en-us/sql/t-sql/data-types/int-bigint-smallint-and-tinyint-transact-sql)
  and [float types](https://learn.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql)
  document range, exactness and storage.
- [Microsoft AVG](https://learn.microsoft.com/en-us/sql/t-sql/functions/avg-transact-sql)
  documents result types and aggregate overflow behavior.

## Extended analysis: retained outputs, conversions and export fidelity

Operator approved further analysis on 7 November 2026. The work below reads
existing local receipts, canonical source and synthetic local data only. No VM
workload, production access, import, export delivery or type migration occurred.

### Actual retained output profile

Both retained OFF and ON SUMMARY_CHANGE_EXPORT captures contain 2,452 rows and
49 numeric columns: 120,148 numeric cells per capture. Each capture has:

- zero fractional, non-finite, NULL or bigint-out-of-range numeric values;
- zero duplicate GovernorID values and zero values beyond the consecutive
  integer precision boundary of float (2^53);
- 67 cells exceeding int range, across KillPoints, StartingKillPoints,
  OverallKillPointsDelta, KillPointsDelta12Months and KillPointsDelta6Months.

This is direct evidence that whole-number storage fits the captured final report
and int alone is already insufficient. It does not certify every historical or
intermediate row, prove that earlier rounding was correct, or recover precision
already lost before capture. The profile covers retained rehearsal evidence,
not fresh production data. Private receipt `summary-retained-numeric-profile.json`
pins each compressed source hash and per-column aggregate counts/ranges; names
and individual player rows are not reproduced in this assessment.

### Concrete conversion opportunities

Parsed all 184 retained compiled summary statement plans: 112 contain implicit
conversions to float, with 248 Convert XML nodes in total. None contains a
PlanAffectingConvert warning. Counts describe compiled expressions, not executions,
rows processed or milliseconds. Some expressions belong to history-cache writes
already eliminated by the approved endpoint rewrite; do not attribute all 248
nodes to remaining candidate overhead.

The parent export statement (query 202988, plan 25751) contains 20 such nodes:
18 metric values from healed/ranged/kill-points summaries and two GovernorID
references from healed/ranged. Its source also joins float and bigint IDs. This
is a specific surviving alignment opportunity because the endpoint rewrite left
the parent and its output contracts unchanged. Removal of mixed-type comparisons
may simplify execution, but these plans do not establish a bad seek or quantify
conversion CPU. No speedup percentage is claimed.

The current nine children and parent reference 43 canonical tables: the source
plus 42 latest/delta/final/export/state tables. Excluding the source's five
unrelated float columns, the 42-table output/state surface has 139 float columns:
49 in SUMMARY_CHANGE_EXPORT and 90 in older metric outputs. Thirty-two retained
history tables are an additional compatibility/rollback surface, not active
candidate history stores. Full column/type and qualified-reference inventories
are retained in `summary-numeric-plan-analysis.json`. Static references are a
lower bound; external, dynamic and unqualified consumers still need clearance.

### Bot and spreadsheet boundary

The active immutable scan-output route in LegacySnapshotDAL.capture_outputs
constructs pandas DataFrames from SQL rows, then calls plan_legacy_outputs. That
planner captures cells with itertuples and _coerce_cell_for_sheet. The retained
snapshot serializer itself supports exact Python int and typed Decimal values;
it does not require float. The separate direct transfer path uses read_sql and
iterrows, and remains a compatibility path to cover without enabling or calling it.

An offline experiment used the existing pure cell helper, pandas 3.0.2 and numpy
2.4.4. Constructing a summary-shaped DataFrame containing names, a count of
9,007,199,254,740,993 and a blank count in another row inferred float for the
count column. Both tuple capture and the direct sheet loop then produced
9,007,199,254,740,992. The ID remained exact in this mixed string/numeric shape.
Explicit object or nullable Int64 construction preserved the tested integers.
Converting to Int64 after an already-lossy float inference cannot recover the
original number; preservation must begin when constructing the frame.

These synthetic values exceed those in the retained reports. This demonstrates
a concrete future compatibility risk, not current data corruption. A real type
alignment must cover the SQL-to-DataFrame boundary, immutable payload/digest and
queued-job compatibility, cell formatting, blank values, and provider numeric
limits. No provider was contacted and no claim is made that Sheets supports every
bigint exactly. Decide a text/number contract for any values beyond the provider's
exact range; IDs used as identifiers and arithmetic counts need separate treatment.

### Bounded implementation design and acceptance

Recommended ownership: SQL canonical schemas/procedures and ordered migration
own types and arithmetic; the existing export DAL/planner owns lossless input
materialization and output representation. No command, UI, startup, scheduler,
permission or import-allocation change is needed merely to align numeric types.
Keep all eight metrics, the alternate healed path, parent joins/export, rollback
cache definitions and index dependencies in the same compatibility assessment.

Sequence after the remaining value/consumer checks:

1. Freeze the endpoint-only candidate as comparison baseline. Profile underlying
   history and all candidate output columns read-only in the isolated VM, including
   integer round trips, identity collisions, extrema, NULLs and index dependencies.
2. Agree the average contract explicitly. Recommended target is exact decimal
   intermediate calculation and rounding to whole counts, but changing existing
   bigint truncation is a behavior change requiring separately enumerated output
   differences. Preserve negative deltas and verify sum/subtraction headroom.
3. Build a coordinated SQL and export-boundary candidate, with reviewed forward
   and rollback handling for indexes, grants, signed modules and retained jobs.
   Preserve existing immutable payload bytes; never regenerate queued payloads
   solely to adopt a new numeric representation.
4. Extend the existing 30-test parity suite for integer/decimal semantics and
   both export paths: current-range values, 2^31, 2^53, bigint bounds, NULLs,
   negative/halfway averages, aggregate overflow, duplicate keys, rollback and
   existing/new payload compatibility. Expected rounding changes must be listed,
   not hidden behind relaxed comparison tolerances.
5. Compare endpoint-only versus endpoint-plus-type-alignment on the same owned
   representative copy. Record CPU, duration, reads, conversion expressions,
   grants/spills, tempdb/log/version bytes and output metadata/content. Use the
   existing balanced five-pair and resource acceptance limits; SQL source-level
   cleanup alone is not performance acceptance.

Analysis verdict: the long-term type-alignment case is supported, with a concrete
conversion-removal opportunity. Magnitude of speed improvement remains unmeasured.
The final-report data check is complete; full stored-value/consumer proof and
provider-format decisions remain open. No datatype implementation is authorized
by this analysis entry. Existing summary rewrite approval and all limits remain
unchanged; production deployment stays separate.

Security route for this analysis: documented skip, because only offline private
analysis artifacts and documentation were added; qualified runtime hashes remain
unchanged. Future SQL migration and Bot runtime changes need separate Changes
reviews for their respective repositories. No repository-wide scan is implied.
The native rewrite tests were not repeated for this non-runtime delta.

## Completed retained-data analysis, 7 November 2026

Successful receipt `P02-complete-analysis-7173dab1d55d4fcf89be388552c6f1df.json`
and review `p02-complete-analysis-review.json` cover every targeted table and column.
All tables are populated. There are 43,679,892 non-null numeric cells and 1,397,963
null cells across overlapping derived tables; preserve those null semantics.
No fractions, bigint conversion failures, float-to-bigint-to-float discrepancies,
values beyond 2^53, or distinct GovernorID losses on conversion were found.
There are 68,424 cells outside int range across 18 kill-point columns, with a maximum
of 12,451,938,901. This supports bigint for counts/IDs/signed deltas and rules out a
blanket conversion to int. Bounded ranks/scans may remain int. Float is not required
to represent the observed stored summary values, but decimal intermediate arithmetic
is still needed to preserve explicit average/rounding semantics. This does not prove
that float never lost precision historically or that future input ranges cannot grow.

The operator reports no known external use of the intermediate tables or legacy
procedures. The restored matching job-step inventory is empty. Fresh production
bindings remain a D4 release check; preserve compatibility and legacy coverage until
that check and an explicit retirement decision. No automatic cache/table retirement.
No datatype or production change was made. Candidate performance remains unmeasured.
