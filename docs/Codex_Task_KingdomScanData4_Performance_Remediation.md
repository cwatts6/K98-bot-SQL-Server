# Codex Task: Full SQL Server Performance Remediation for `dbo.KingdomScanData4`

## Objective

Perform an evidence-led, end-to-end audit and remediation of SQL Server performance, correctness, maintainability, and application compatibility centred on `dbo.KingdomScanData4` in the `ROK_TRACKER` database.

This is not a narrow table-alteration task. Review the whole database and the relevant application/bot repositories so the complete upstream write path and every direct or transitive downstream read path are understood and corrected. The work must cover the import task, staging path, stored procedures, functions, downstream tables, views, scheduled jobs, bot operations, and all DAL/model/query code that depends on any changed contract.

The attached `KingdomScanData4_Analysis_Report.md` is the starting evidence, not an implementation specification. Reproduce and validate every material finding against the current schema, data, workload, execution plans, and code before changing anything. Do not blindly execute the example DDL or assume the proposed five-index end state is optimal.

At the end of this task, no issue causally related to the `KingdomScanData4` remediation may be left as a TODO, follow-up ticket, deferred migration, compatibility shim to remove later, or undocumented manual action.

## Execution status — 2026-07-28

Phases 1 through 4 are complete and closed on representative-copy evidence. Phase 4 passed its
guarded obsolete-view retirement, view-contract alignment, forward/rollback/reapply,
value/metadata equivalence, full materialization, benchmark, mapped-consumer, repository, and
zero-finding final SQL Changes gates. Phase 5 is the next implementation phase and belongs
primarily to the separate bot repository, with its narrowly scoped companion SQL migration kept
in this repository. Production execution remains separately gated.

The operator approved the exact Phase 2 implementation and representative-copy rehearsal plan on
2026-07-25 in
`performance_remediation/kingdomscandata4/phase1/phase2_approval_checkpoint.md`.

Completed evidence includes:

- environment, dependency, conversion, Query Store, backup/storage and representative-data
  collection;
- zero failed/fractional/out-of-range conversions for the current 394,506-row data set;
- the locked no-narrowing ingestion contract of `nvarchar(200)` for names and
  `nvarchar(100)` for alliance/civilization;
- one warm-up plus five measured executions for the controlled summary, metadata, view and
  selected bot-facing lookup workloads;
- a successful representative restore, `DBCC CHECKDB`, row-presence check and guarded snapshot
  reset workflow;
- `UPDATE_ALL2` normal, boundary/Unicode/optional-blank, invalid-input, corrected-retry,
  controlled Phase-B failure and simultaneous two-session concurrency scenarios;
- one comparable committed-import warm-up plus five measured fresh-seed runs;
- all SQL Agent jobs, external scheduling and import-serialization entry points;
- all 12 shortlisted Query Store query/plan owners and representative after scenarios;
- the complete eight-path bot/DAL result-contract map; and
- a guarded shadow-copy forward in 45,779.868 ms plus production-usable metadata-swap rollback in
  34,255.475 ms against the same run ID, with exact digests and no snapshot.

The 2026-07-25 approval-checkpoint refinement retains all ten KS4 indexes unchanged: no exact
duplicate definitions were found and the operator determined the modest expected consolidation
benefit did not justify its risk/test cost. The same coordinated release now explicitly includes
contract-preserving conversion cleanup in four bot paths and separate SQL/bot Changes security
reviews.

Phase 2 implementation and representative-copy rehearsal may now begin under the approved
checkpoint. Do not execute destructive DDL against production without separate explicit approval.
The next-session starter is `docs/Codex_Task_KingdomScanData4_Phase2_Starter.md`.

## Non-negotiable rules

1. Use no more than the five phases defined below. Subtasks and commits within a phase are fine; do not create phase sprawl.
2. Complete the audit, implementation, validation, and evidence pack. Do not stop after producing recommendations.
3. Treat all report claims as hypotheses until revalidated, including row counts, data ranges, current usage counts, dependency counts, index usage, string maximum lengths, absence of fractional values, conversion safety, and any claim of existing precision loss.
4. Go upstream to every source that inserts, bulk-copies, merges, or otherwise writes into `KingdomScanData4`. Go downstream through every direct and transitive consumer.
5. Search both database metadata and repository code. Static SQL dependency metadata alone is not enough because it misses dynamic SQL, ad hoc SQL, synonyms, cross-database references, job steps, and application queries.
6. Validate bot behaviour in every phase. Phase 5 is conditional only for code changes; bot and DAL impact analysis is mandatory even when no code changes are required.
7. Establish before benchmarks before the first change, then rerun the same benchmark set after each material change. Capture evidence, not impressions.
8. Preserve data and externally observable behaviour unless an intentional contract change is explicitly implemented in every consumer and proven by tests.
9. Do not run destructive DDL against production without explicit approval. Build and test migration and rollback paths against a representative restored copy or approved non-production environment first.
10. When evidence is unavailable, ask for the smallest useful anonymised sample, plan, backup, log, configuration, or repository access rather than assuming. State exactly what is needed, why it is needed, and which decision it unlocks.
11. Work through blockers instead of deferring them. Continue non-blocked work while awaiting evidence, but do not declare the task complete with a related blocker unresolved.
12. Keep all database changes scripted, reviewable, repeatable, environment-aware, and stored in the repository using its existing migration conventions.

## Known starting findings to validate

The supplied report states that the live table had approximately 394,506 rows, 2,371 distinct governors, 10 indexes, and at least 33 dependent stored procedures/views when captured. Recheck all of these against the target environment.

### Candidate type corrections

Validate whether the following source columns contain only safe whole-number values, preserve current nullability unless there is separate evidence to change it, and confirm all upstream/downstream contracts before conversion:

| Column | Candidate target type |
|---|---:|
| `GovernorID` | `BIGINT` |
| `PowerRank` | `INT` |
| `SCANORDER` | `INT` |
| `Power` | `BIGINT` |
| `KillPoints` | `BIGINT` |
| `Deads` | `BIGINT` |
| `T1_Kills` through `T5_Kills` | `BIGINT` |
| `T4&T5_KILLS` | `BIGINT` |
| `TOTAL_KILLS` | `BIGINT` |
| `RSS_Gathered` | `BIGINT` |
| `RSSAssistance` | `BIGINT` |
| `Helps` | `BIGINT` |

The report also proposes:

- `GovernorName`: `nchar(255)` to `nvarchar(100)`
- `Alliance`: `nchar(255)` to `nvarchar(50)`
- `AsOfDate`: retain `CONVERT(date, ScanDate)` but make the computed column `PERSISTED`

For string narrowing, validate the current data, source-system field limits, Unicode behaviour, trailing-space semantics, future growth allowance, and every consumer. Current maximum observed lengths alone are not enough to establish a safe contract. If the source contract is unavailable, request representative raw import samples and/or the upstream schema before choosing lengths.

Distinguish theoretical type risk from proven historical corruption. If source samples or authoritative upstream values are available, reconcile them against stored values before asserting that prior `float` storage changed data.

### Candidate index changes

Use the report’s index analysis as a starting point only. Revalidate against Query Store, plans, code paths, index operational statistics, server restart time, and a representative workload. Zero DMV reads since restart are not by themselves sufficient evidence to drop an index.

Candidate dead/redundant indexes named in the report include:

- `IX_KingdomScanData4_GovernorID_ScanOrder`
- `IX_KS4_Governor_ScanDate_ScanOrder`
- `IX_KingdomScanData4_GovernorID_ScanOrder_Covering`
- `IX_KSD4_Governor_ScanOrder`
- `IX_KS4_Governor_ScanDate`
- `IX_kingdomscandata4_ScanOrder_DESC`

Indexes identified as active or important include:

- `CIX_KS4_ScanOrder_Governor`
- `IX_KSD4_Gov_ScanOrder`
- `IX_KS4_AsOf_Governor`
- `IX_KingdomScanData4_ScanOrder_GovernorID`

Do not force a 10-to-5 index reduction if the evidence supports a different design. Avoid replacing several indexes with a single excessively wide covering index unless measured read savings clearly outweigh storage, memory, write, logging, and maintenance costs.

### Candidate module anti-patterns

At minimum, inspect and update as justified:

- `DEADSSUMMARY_PROC`
- `HEALEDSUMMARY_PROC`
- `HEALEDSUMMARY_PROC_OPT`
- `KILLPOINTSSUMMARY_PROC`
- `KILLSSUMMARY_PROC`
- `KT4SUMMARY_PROC`
- `KT5SUMMARY_PROC`
- `POWERSUMMARY_PROC`
- `RANGEDSUMMARY_PROC`
- `SUMMARY_PROC`
- `Refresh_PlayerScanMeta`
- `FIX_IMPORT_STAGING`
- `IMPORT_STAGING_PROC`
- `UPDATE_ALL2`
- `v_Active_Players`
- `vDaily_PlayerExport`
- `v_GovernorNames`
- `vw_Governor_KVK_Summary_GlobalLatest`
- every related `vDaily_*` and `vWTD_*` object
- all functions, views, procedures, triggers, jobs, and downstream tables discovered during the audit

Known patterns to verify include row-by-row `TRY_CONVERT`/`CAST` of `GovernorID`, `FLOAT` state variables for `SCANORDER`, float-typed temp tables and parameters, unnecessary numeric conversions in views, fixed-width string trimming, and type mismatches in joins to downstream tables such as `EXCEL_FOR_DASHBOARD`.

## Phase 1 — Full database/repository audit and baseline

### 1.1 Establish the exact target

Record and verify:

- SQL Server version, edition, compatibility level, collation, recovery model, database options, Query Store status, HA/DR topology, replication/CDC/temporal use, and maintenance-window constraints.
- Current branch, repositories, deployment process, migration framework, bot/service entry points, scheduled tasks, and connection targets.
- Current definitions and hashes of every object that will be changed, so drift can be detected before deployment.

### 1.2 Perform a database-wide performance review

Review the entire `ROK_TRACKER` database sufficiently to understand how this table interacts with the workload. Include:

- table and index sizes, row counts, data compression, partitions, statistics quality/age, fragmentation where relevant, and write/read patterns;
- Query Store top queries by CPU, duration, logical reads, writes, executions, and regressions;
- plan cache and runtime evidence where Query Store is unavailable;
- conversion warnings, spills, excessive grants, scans, key lookups, poor cardinality estimates, parameter sensitivity, blocking, deadlocks, tempdb pressure, and relevant waits;
- index usage and operational statistics with server/database restart context;
- SQL Agent jobs, job history, maintenance tasks, ETL steps, and cross-database dependencies that touch the table or its consumers.

This review must be broad enough to catch interactions, but implementation scope remains all findings directly or transitively related to `KingdomScanData4`. Unrelated database issues may be documented separately; they must not distract from completing this remediation.

### 1.3 Build a complete upstream and downstream dependency graph

Use multiple methods and reconcile the results:

- `sys.sql_expression_dependencies`, `sys.dm_sql_referencing_entities`, `sys.sql_modules`, synonyms, triggers, constraints, computed columns, indexed views, SQL Agent job steps, and cross-database references;
- Query Store/query text and plan cache searches for ad hoc and dynamic SQL;
- case-insensitive repository search for `KingdomScanData4`, all named procedures/functions/views, important column names, and downstream table names;
- ORM mappings, migrations, embedded SQL, Dapper/ADO.NET/EF code, `SqlBulkCopy`, `DataTable` schemas, command parameters, data readers, DTOs, reports, exports, caches, and bot commands;
- transitive dependencies: do not stop at an immediate procedure or view. Follow every changed output into its callers and readers.

Classify every dependency as upstream writer, direct reader, transitive reader, schema contract, operational dependency, or unused/dead candidate. Include evidence and file/object locations.

For the import path, explicitly trace the raw source file/message through parsing, staging, validation, `SCANORDER` assignment, insert/merge, post-import procedures, and bot-visible completion. Review retry behaviour, idempotency, transaction boundaries, and concurrency. Any `MAX(SCANORDER) + 1` pattern must be assessed for atomicity under concurrent or retried imports and corrected within this task if unsafe.

### 1.4 Prove conversion and narrowing safety

For every candidate column, capture:

- row count, null count, distinct count, minimum, maximum, fractional/non-integral count, failed-conversion count, and out-of-range count;
- duplicate/collision checks that compare distinct source values with distinct converted values, especially for `GovernorID`;
- defaults, constraints, keys, indexes, statistics, computed columns, schema-bound objects, and parameter/table-variable/temp-table types that depend on it;
- current and authoritative upstream types;
- downstream result-set metadata and application model types;
- for strings, `LEN`, `DATALENGTH`, leading/trailing spaces, empty values, unusual Unicode values, and values near the proposed limit.

If authoritative source values are required to prove a decision, request a minimal anonymised import sample containing normal, maximum, null/blank, Unicode, malformed, and boundary cases.

### 1.5 Create the repeatable baseline benchmark suite

Choose representative parameter sets from real usage, including small, large, empty/no-change, latest scan, historical range, and high-cardinality governors. Capture before evidence for:

- every important summary procedure;
- `Refresh_PlayerScanMeta` full and incremental paths;
- import/staging and post-import processing;
- important views and downstream exports;
- direct DAL/bot read operations;
- the top Query Store queries that touch the table or changed objects.

For each, record result row counts, elapsed time, CPU time, logical/physical reads, writes, tempdb spills, memory grant, execution plan, join/access methods, warnings, waits where available, and errors. For imports also record rows/second, log growth/bytes, lock/blocking behaviour, and total end-to-end completion time.

Run enough repetitions in a controlled environment to distinguish signal from noise, normally one warm-up plus 5–10 measured warm-cache executions. Never clear production caches. Cold-cache tests may be run only in an isolated environment with approval.

### Phase 1 gate

Before Phase 2, produce:

- the dependency graph;
- the validated data-quality/type report;
- the before benchmark pack;
- the exact proposed migration sequence, compatibility changes, outage/locking estimate, log/disk requirements, rollback design, and risks;
- a closure matrix listing every discovered affected object and the phase in which it will be resolved.

Do not proceed with an unproven narrowing/conversion or an incomplete import/bot dependency path.

## Phase 2 — Table, computed column, and index remediation

Treat this as a logical workstream. If compatibility requires phases 2–5 to be deployed together, prepare and test the complete coordinated release before production deployment.

### 2.1 Design a safe migration

- Choose the safest evidence-backed approach: direct `ALTER COLUMN`, shadow/copy table, staged columns with backfill, or another controlled method.
- Account for locks, transaction-log growth, available disk, index rebuild time, statistics, foreign keys, constraints, triggers, permissions, schema-bound objects, backups, rollback time, and HA/replication behaviour.
- Make preflight checks fail fast with actionable messages if schema drift, unsafe data, insufficient space, missing dependencies, or unexpected types are detected.
- Preserve object ownership, permissions, extended properties, compression, indexes, statistics, and constraints.
- Test the forward and rollback scripts against a representative restored copy.

### 2.2 Correct data types and string storage

Implement only conversions proven safe in Phase 1. Keep validation/conversion at the ingestion boundary for untrusted raw data; do not repeatedly convert already-clean typed data on every read.

If a raw landing table intentionally stores source text to capture bad data, do not blindly coerce it to the final type. Instead, provide an explicit typed validation/clean-staging boundary before insertion into `KingdomScanData4`.

After conversion, reconcile every row and material column against the pre-change snapshot. Prove that there is no truncation, overflow, unintended rounding, row loss, duplicate collapse, or nullability change.

### 2.3 Evaluate and implement `AsOfDate`

Benchmark the current non-persisted expression and the proposed persisted computed column, including storage/write overhead and dependent index behaviour. Implement `PERSISTED` only if it is valid and beneficial for the real workload. Recreate dependent indexes and required SET-option-compatible objects correctly.

### 2.4 Redesign indexes from workload evidence

- Map each retained/new index to named queries and plan operators.
- Remove a candidate index only when its workload is covered and the replacement has been benchmarked.
- Prefer the smallest useful key/include set; calculate estimated and actual index size.
- Check key order, sort direction, selectivity, filter opportunities, write amplification, and overlap with the clustered key.
- Validate import throughput and lock/log impact after each material index change.
- Update statistics appropriately and capture new plans without forcing unsafe global cache clears.

### 2.5 Phase smoke and performance gate

After each material schema/index change:

- rerun conversion/data reconciliation checks;
- run table-level and import smoke tests;
- rerun the relevant benchmark subset;
- compare plans and metrics to baseline;
- roll back or redesign changes that are not necessary for correctness and do not provide a demonstrable net benefit.

## Phase 3 — Functions, stored procedures, staging, and downstream tables

### 3.1 Update every affected SQL module

For all discovered procedures and functions, including the named summary procedures and `Refresh_PlayerScanMeta`:

- align parameters, local variables, temp tables, table variables, return types, and join columns with the corrected base types;
- remove `CROSS APPLY`, `TRY_CONVERT`, `CAST`, or other wrappers that exist solely because the base table used incorrect types;
- keep defensive conversion only at genuinely untrusted input boundaries or where it intentionally provides overflow/error handling;
- restore SARGable predicates and verify index seeks/range scans with actual plans;
- preserve result-set column names, nullability, ordering where contractually relied upon, and business semantics;
- review parameter sensitivity and recompilation choices using real workload evidence rather than blanket hints.

### 3.2 Correct the complete import/staging path

Inspect and correct `IMPORT_STAGING_PROC`, `FIX_IMPORT_STAGING`, staging table schemas, bulk-copy mappings, parser types, validation/error tables, `SCANORDER` allocation, and all post-import processing.

Required import properties:

- one authoritative typed boundary before data reaches `KingdomScanData4`;
- clear rejection/quarantine of invalid rows with actionable diagnostics;
- atomic and concurrency-safe scan allocation;
- idempotent retry behaviour or an explicit duplicate-prevention strategy;
- no silent truncation or numeric coercion;
- unchanged or improved end-to-end import throughput.

### 3.3 Align downstream tables and persisted contracts

Find every table populated from the changed table, procedures, or functions. Align key/metric types where necessary and migrate existing data safely. This includes validating joins such as `EXCEL_FOR_DASHBOARD.Gov_ID` against the new `GovernorID` type.

Do not leave mismatched downstream types that merely reintroduce implicit conversions one hop later.

### 3.4 Prove behavioural equivalence and performance

For each changed routine:

- execute representative parameter sets before and after;
- compare outputs in both directions using exact `EXCEPT`/equivalent reconciliation, with explicit handling for intentional contract changes;
- verify row counts, values, ordering assumptions, error behaviour, transaction effects, and downstream table changes;
- capture actual plans and the standard benchmark metrics;
- test full and incremental/no-op paths.

## Phase 4 — Views and all view consumers

### 4.1 Update every affected view

At minimum review the named views and every related `vDaily_*`/`vWTD_*` view. Also discover all other direct and transitive views.

- Remove type conversions made unnecessary by the corrected source types.
- Remove trimming only when the output/compare semantics are proven unchanged; defensive display trimming may remain when harmless and intentional.
- Validate joins against downstream types so the conversion does not move to the other side of the predicate.
- Review aggregation/window expressions for overflow, null, duplicate, and date-boundary behaviour.
- Preserve consumer-facing column names and data contracts, or update every consumer in the same task.
- Refresh dependent metadata and compile all modules after deployment.

### 4.2 Compare outputs and plans

For representative dates, governors, empty periods, latest scans, and large ranges:

- compare old/new results bidirectionally;
- validate aggregate totals and deltas;
- capture plans, reads, CPU, duration, grants, spills, and warnings;
- verify reports/exports/DALs that consume each view.

## Phase 5 — Bot operations and DAL/application changes, when required

Impact analysis and end-to-end testing are mandatory. Code changes are conditional on the evidence.

### 5.1 Search and inspect the bot/application code

Find every use of:

- `KingdomScanData4`;
- every changed procedure, function, view, and downstream table;
- `GovernorID`, `SCANORDER`, affected metric fields, `GovernorName`, and `Alliance` where they form SQL or model contracts.

Inspect at least:

- import task orchestration and scheduling;
- file/message parsing and validation;
- `DataTable` and `SqlBulkCopy` schemas/mappings;
- stored-procedure parameters and command types;
- ADO.NET/Dapper/EF mappings, DTO/entity property types, data-reader getters/casts, serializers, caches, and report/export models;
- retry, timeout, transaction, and error-handling paths;
- any hard-coded assumptions about float values, padded strings, result metadata, or object definitions.

### 5.2 Implement all required application changes

Examples may include changing `double`/`float` model properties to 64-bit integer types, changing scan-order properties to 32-bit integer types, updating parameter bindings and bulk-copy metadata, handling string length contracts, and updating queries that relied on conversion/trimming.

Do not retain dual old/new code paths for later cleanup unless both are genuinely required as the final supported design.

### 5.3 Mandatory end-to-end bot smoke tests

Using a representative non-production environment:

1. Import a known sample batch containing normal, boundary, Unicode, blank/null, duplicate/retry, and invalid rows.
2. Verify accepted/rejected counts and diagnostics.
3. Verify `SCANORDER`, row counts, values, and post-import procedure execution.
4. Exercise every bot/DAL read path that directly or transitively consumes changed objects.
5. Compare bot-visible outputs with the pre-change baseline.
6. Review logs for conversion, truncation, timeout, deadlock, mapping, serialization, and result-reader errors.
7. Repeat/retry the import to prove idempotency and concurrency expectations.
8. Capture end-to-end timing and compare it with the before baseline.

If no bot/DAL changes are required, provide code-search evidence, runtime test evidence, and an explicit explanation of why the contracts remain compatible.

## Benchmark and regression policy

For every material change, maintain a before/after table containing:

- object/query/test name and exact parameters/data set;
- execution count and environment;
- duration, CPU, logical reads, physical reads, writes, row count, memory grant, spills, warnings, and plan identifier;
- import rows/second, log growth, blocking/deadlocks, and total workflow time where relevant;
- bot/DAL response time and errors where relevant;
- percentage change and interpretation.

Use the same data, parameters, database settings, and comparable cache state. Explain unavoidable variance.

No unexplained material regression is acceptable on a critical path. Flag any regression around or above 10% in median duration, CPU, logical reads, or import throughput and either fix it or provide strong evidence that a necessary correctness/safety gain outweighs it. Targeted performance changes must show a repeatable benefit in the workload they are intended to improve; otherwise redesign or remove them.

## Required smoke-test suite

The final automated/manual suite must cover:

- schema/type/nullability/index assertions;
- all preflight conversion and string-length checks;
- exact row and value reconciliation after migration;
- every changed stored procedure and function, including full, incremental, no-op, empty, and large paths;
- every changed view and representative date/range boundaries;
- import success, invalid input, duplicate/retry, concurrency, and rollback behaviour;
- all downstream table updates;
- bot/DAL import and read operations;
- permissions and execution context;
- forward migration, failed preflight, interrupted/failed deployment recovery, and rollback on a restored copy;
- post-deployment compile/metadata validation and error-log review.

## Required deliverables

Store these using repository conventions; if none exist, create a clearly named performance-remediation folder.

1. **Audit report** — current state, database-wide findings relevant to this work, validated/refuted report claims, complete dependency graph, workload evidence, risks, and final design.
2. **Closure matrix** — every affected database object, code path, job, and bot operation; owner/location; required change; phase; test; status. Every related row must be closed.
3. **Benchmark pack** — reproducible scripts/tests, raw before/after evidence, plans, and a concise comparison summary after each phase.
4. **Migration package** — preflight, forward migration, post-deploy verification, and rollback/recovery scripts. Scripts must detect schema drift and be safe to rerun where practical.
5. **Database module changes** — all procedures, functions, views, staging objects, and downstream tables required for the final design.
6. **Application/bot changes** — all DAL, import, model, mapping, query, and test changes required by the final contracts.
7. **Test evidence** — data reconciliation, module equivalence, import/bot smoke results, concurrency/retry evidence, and regression results.
8. **Deployment/runbook** — prerequisites, backup, maintenance/outage expectations, exact order, validation gates, rollback triggers, monitoring, and post-deploy checks.
9. **Final closure report** — what changed, why, measured outcome, any report recommendation rejected and why, and confirmation that no `KingdomScanData4`-related work remains deferred.

## Definition of done

The task is complete only when all of the following are true:

- the complete upstream and downstream dependency chain is mapped and resolved;
- every material report claim has been validated, refined, or refuted with evidence;
- all safe and necessary table, type, computed-column, and index changes are implemented;
- all affected functions, procedures, staging objects, downstream tables, and views use compatible final types and plans;
- the bot import task and every affected DAL/read operation pass end-to-end tests;
- data reconciliation proves no unintended data loss, truncation, rounding, duplicate collapse, or semantic change;
- the forward migration and rollback/recovery path have been tested on a representative copy;
- targeted workloads show repeatable improvement and critical workloads have no unexplained material regression;
- all scripts, code, tests, plans, and evidence are committed and reviewable;
- the closure matrix has no open `KingdomScanData4`-related item, TODO, deferred cleanup, or manual follow-up.

## Evidence request protocol

When a decision cannot be proven from the accessible repository/database, ask for the smallest necessary item. Likely examples include:

- an anonymised raw import file with boundary and malformed cases;
- a representative database backup or targeted sample extracts;
- Query Store exports or actual execution plans from the production-like workload;
- SQL Agent job definitions/history;
- bot repository/configuration/log access;
- source-system field definitions and maximum lengths;
- maintenance-window, HA/DR, disk, log, and rollback constraints.

Do not substitute guesses for any of these when they materially affect data safety, compatibility, migration design, or performance conclusions.
