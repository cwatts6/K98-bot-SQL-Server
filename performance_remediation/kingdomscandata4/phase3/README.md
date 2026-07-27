# KingdomScanData4 Phase 3 — procedures, import concurrency and downstream tables

Status: implementation and representative-copy rehearsal complete on
`codex/kingdomscandata4-phase3`. Phase 2 representative-copy acceptance was the entry dependency
and is complete. Phase 2 has not been deployed to production and did not need to be deployed there
before Phase 3 implementation or representative-copy rehearsal. Production execution remains
unauthorized until Phases 4 and 5, the combined release gate, reviewed promotion, and a separate
go/no-go.

The Phase 3 package is complete: the import mutex, atomic scan allocation, digest receipt,
post-commit archive, duplicate replay refusal, three directly affected downstream table
conversions, and aligned procedure definitions pass a fresh Phase 2-to-Phase 3
forward/rollback/forward chain. Direct, legacy, invalid/corrected retry, simultaneous-session,
controlled Phase-B failure, Query Store mapped, compilation, repository, and security checks are
recorded in `rehearsal_report.md`. The broader legacy persisted surface is an evidence-backed
retain decision, not an unfinished bulk conversion: approximately 190 columns remain unchanged
because their independent writer/consumer proof belongs to later scoped work.

The Changes-only security reviews drove three Phase 3 controls. The application-lock namespace
belongs to a private database role. The lock helper, nested import core and archive-digest helper
are denied to `public` and are reachable only through same-owner procedure chains. Every public
import entry point rejects a caller-owned transaction before lock acquisition, and archive
reconciliation hashes the exact destination before advancing a receipt. The final scan retained
two Low/P3 mutable-path races: hash-to-`BULK INSERT` and hash-to-`MOVE`. They share one
cross-repository immutable-file remediation assigned to Phase 5 and remain combined-release
blockers.

Phase 3 working contracts:

- `affected_module_contract.md` freezes the exact 52-module dependency inventory, the 39
  Phase 3 procedure definitions, downstream persisted contracts, baseline assignments and
  rollback source.
- `import_concurrency_design.md` records the mutex resource, lock ownership and timeout,
  public/private transaction boundary, atomic scan allocation statement, duplicate key,
  destination reconciliation and failure behavior.
- `downstream_inventory.md` records the live production/representative split and the first
  conversion-safe persisted contracts. Approximately 190 other legacy `float` key/scan columns
  remain explicitly deferred until their writer/consumer and conversion evidence is complete.
- `deployment_order.md` records the exact SQL-first and bot-second production sequence and answers
  the PR #60 dependency question.

## Objective

Align every affected procedure, function, staging contract and downstream table with the Phase 2
types while making import serialization, scan allocation and duplicate prevention explicit in SQL
Server. Preserve the raw/error boundary and every external result contract.

## Locked constraints

- `dbo.IMPORT_STAGING_CSV_RAW` remains the untrusted wide text/error-capture boundary.
- Typed ingestion widths remain name `nvarchar(200)`, alliance `nvarchar(100)`, civilization
  `nvarchar(100)` and `updated_on` `nvarchar(200)`.
- Validation, trimming and checked conversion remain at raw, date, civilization and unchanged
  float/text boundaries.
- `dbo.KingdomScanData4`, `dbo.KingdomScanData5` and `dbo.IMPORT_STAGING` use the Phase 2 types.
- All ten KS4 indexes remain unchanged.
- External result aliases, column order, types, null behavior and business semantics remain
  unchanged unless a separately approved contract change is recorded.

## Work packages

### 3.1 Freeze the affected-module contract

Use `phase1/closure_matrix.md`, `phase1/bot_dal_contract_map.md` and the Query Store owner map to
produce the exact procedure/function/downstream-table manifest. Record each module's baseline
scenario, parameters, output digest, result metadata and rollback definition before editing it.

### 3.2 Make import ownership explicit

- Add one database-enforced application mutex acquired inside every authoritative SQL import path,
  including direct execution paths that bypass the bot's `processing_lock`.
- Allocate the next scan atomically while the database mutex is held.
- Make duplicate prevention explicit and transactional.
- Preserve corrected retry, invalid-input and controlled Phase-B failure behavior.
- Fail closed with actionable diagnostics when the mutex, scan allocation or duplicate guard
  cannot be established.
- Do not depend on filename interleaving, staging-table locks or bot-process state for correctness.

The exact mutex resource, lock owner, timeout, transaction boundary and duplicate key are an
implementation checkpoint. They must be shared by the relevant procedures and proven with
simultaneous SQL sessions before acceptance.

### 3.3 Align procedures and functions

Align parameters, variables, temp/table variables, joins and downstream writes to the final
integer/string types. Remove only `TRY_CONVERT`, `CONVERT`, `CAST`, `CROSS APPLY` or padded-string
compensation that exists solely for the old KS4/KS5/staging types. Preserve deliberate trimming,
overflow checks, date/civilization conversion and unchanged float/text handling.

The affected set includes the Phase 1 closure-matrix procedures, with special gates for:

- `dbo.IMPORT_STAGING_PROC`, `dbo.FIX_IMPORT_STAGING`, `dbo.UPDATE_ALL` and `dbo.UPDATE_ALL2`;
- `dbo.SUMMARY_PROC` and its component summary procedures;
- `dbo.Refresh_PlayerScanMeta`;
- downstream Excel/dashboard/upload/target rebuild procedures;
- leadership and personal-stats procedures; and
- `dbo.usp_UpsertGovernorNameHistoryForScan`, including Query Store `143117/16603`.

### 3.4 Align downstream persisted contracts

Reconcile every table populated from the changed modules. Do not change a downstream type without
conversion, row/value, dependency and consumer evidence. Existing aligned `bigint` outputs such as
`EXCEL_FOR_DASHBOARD.Gov_ID` and `STATS_FOR_UPLOAD.Gov_ID` remain unchanged unless new evidence
requires otherwise.

### 3.5 Package and rollback

- Author ordered migration files under `migrations/`.
- Update matching canonical `sql_schema` definitions.
- Provide reviewed rollback files for every reversible module change.
- The rollback sequence restores Phase 3 definitions before the Phase 2 table rollback.
- Keep Phase 2 retained originals until the combined release gate accepts Phase 3 and Phase 4.

## Required validation

- Repeat every `UPDATE_ALL2` functional and committed-import scenario from Phase 1.
- Run simultaneous direct SQL, bot-equivalent and corrected-retry cases.
- Compare every changed module bidirectionally and compare result metadata.
- Rerun the exact summary, metadata, leadership, DAL and Query Store scenarios assigned in the
  closure matrix.
- Capture duration, CPU, reads, writes, grants, spills, log/tempdb/disk deltas, locks and
  deadlocks. Flag any regression around or above 10 percent and resolve or justify it under the
  task-wide regression policy.
- Refresh/compile all 52 dependent modules.
- Run repository validation, `git diff --check` and a SQL Changes security review for the final
  Phase 3 diff.

## Exit gate

Phase 3 closes only when the mutex/allocation/duplicate strategy is proven under concurrency,
every changed routine is result- and metadata-equivalent, the committed import remains correct and
stable, rollback definitions are rehearsed, and the closure matrix contains exact receipts.

The implementation and representative-copy portions of this exit gate are complete. Merge,
promotion, and production deployment are separate later approvals; this branch has not changed
production.

## Freeze record

- Final Changes scan: `7ccf1007-269d-4470-94f0-638222312c5a`.
- Reviewed snapshot:
  `codex-security-snapshot/v1:sha256:98d3c2f01c061c4a3557b5d2f43d0080b47cab9c9863279c8162f3dbb9d653a8`.
- Findings: `csf_1a1c440452b02cdb787fa7c3` and
  `csf_3cb54318733d3a216dd91e9b`, both Low/P3 and open for Phase 5.
- Changes after that snapshot are limited to closure status, scan receipt, Phase 4/release
  documentation and mechanical trailing-whitespace/final-newline cleanup in the generated
  migration, rollback and canonical import-core files. No SQL token, executable behavior,
  configuration, permission, deployment behavior or runtime contract changed after the reviewed
  snapshot; this non-semantic delta uses a documented security-review skip.
