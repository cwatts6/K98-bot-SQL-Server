# SQL Delivery Log

This file records notable SQL delivery milestones that are useful to bot task-pack closeout and
promotion review. Migration files and `dbo.SchemaMigrationHistory` remain the source of truth for
what has actually been deployed.

## Discord Voting Post Framework

| Date | Migration / PR | Status | Notes |
|---|---|---|---|
| 2026-07-04 | `20260704_003_add_survey_ranking_questions` / SQL PR #33 | Deployed to production | Added complete ranking question SQL support through `dbo.SurveyRankingAnswers`, `Ranking` question-type constraints, per-response/question option/rank uniqueness, aggregate-friendly indexes, and deployment-order compatibility for the Phase 9C bot slice. Bot smoke testing confirmed ranking survey creation, required ranking submission, optional ranking skip/clear, ranking update/regression behavior, aggregate-only public cards, and compatibility with existing vote/survey behavior. |

## Import Pipeline

| Date | Migration / PR | Status | Notes |
|---|---|---|---|
| 2026-07-09 | `20260709_001_add_update_all2_audit_outputs` / SQL PR #41 | Deployed to production | Added non-invasive `dbo.UPDATE_ALL2` phase audit output rows while preserving output tables, `SP_TaskStatus` polling, and the final 8-column summary result set consumed by the bot. Bot PRs #215/#522 parse and persist the phase rows through generic `ImportAuditPhase`. Production smoke confirmed fallback batch 67 completed normally, emitted 13 `update_all2_*` subphase rows, identified `update_all2_summary_proc` as the dominant first-sample visible subphase at about 78 seconds, and showed no `_update_all2_phase_results` leakage after the bot review-fix restart. Follow-up work is evidence review before any `SUMMARY_PROC` or `UPDATE_ALL2` decomposition. |


## S8A KVK SQL foundation — authored 2026-09-12, execution not authorized

Chris Watts approved the eight-file implementation, static validation and exact SQL
Changes security review. Initial scope completed before authoring. SQL is on `main`
at `44afa315dd6cbfe9fec101f2a39a62e534f5b583` (also local origin/main), origin
`https://github.com/cwatts6/K98-bot-SQL-Server.git`. It was clean at entry. Actual
creation date is 2026-09-12; no migration occupied daily ordinal 001. **No naming
correction was necessary.** No branch, index, commit or remote ref was changed.

Exact SQL file boundary:

- [Migration](../migrations/20260912_001_kvk_season_complete_updates.sql)
- [SeasonSource](../sql_schema/KVK.SeasonSource.Table.sql)
- [SourceUpdate](../sql_schema/KVK.SourceUpdate.Table.sql)
- [SourceCompleteSelection](../sql_schema/KVK.SourceCompleteSelection.Table.sql)
- [SourceExportIntent](../sql_schema/KVK.SourceExportIntent.Table.sql)
- [SourceExportIntentPublication](../sql_schema/KVK.SourceExportIntentPublication.Table.sql)
- [Synthetic validation](../validation/kvk_source/s8_season_complete_updates.sql)
- This delivery log.

The first seven are new; only this log modifies an existing SQL file. Snapshots match
the migration's definitions. No predecessor SQL object, UDT, ProcConfig, legacy output,
source routing flag, calculation, Bot runtime/test/config or S8B/S10 implementation changes.
Existing migration metadata, explicit transaction/error conventions, source collations,
scoped candidate keys and synthetic rollback/error assertions are reused. No new runner,
connector, dependency or general helper/refactor is introduced; no unrelated debt found.

### Static integrity and remaining writer obligations

SQL enforces one choice per season, exact source allowlists, scoped config/roster,
period identity/kind and input references, stream nullability/state shape, no-fight
aggregate exclusion/equal endpoints, confirmation JSON bounds, public pointer scope,
positive versions, intent/vector uniqueness and same-season successor references.
`PeriodKey` in SourceUpdate binds the existing period/window/kind candidate keys; no
existing key needs an alteration. Intent vector rows reference immutable publication/
update/config identities, not a mutable complete pointer that would break old vectors.
Only integrity/scoped-lookup indexes from primary/unique keys are added.

These are storage constraints. S8B must enforce authorization, immutable source choice
and sealed tuples, lifecycle/CAS transitions, observation-to-logical-scan identity,
aggregate report-to-period/coverage and roster compatibility, retained counterpart validity
against the base update, exact candidate tuple/finality/manifest checks, complete vector
membership/hash, and atomic complete-selection plus intent. Check/FK constraints alone
cannot prove those contracts. Rejected SourceUpdate rows retain complete tuple evidence;
failed incomplete association attempts stay in private acceptance/audit state.

Writer lock order remains SeasonSource, SourceRouting, sorted component/complete period
selection rows, config/request/update rows, then intent/vector. No SQL transaction spans
a provider call. Public routing is still absent: SourceRouting.Enabled alone cannot
implement it. B0/private onboarding, frozen-roster no-fight zeros/absent members, independent
authoritative aggregate/overall reports, UTC scan starts, semantic deduplication, daily
SCANORDER and 11-10, 12-10, 13-10 then authorized 14-10 remain accepted S8B obligations,
with no additional player correction command introduced by this schema.

### Historical migration safety

DataChange is Yes. The migration requires explicit session-local target, backup/preview
receipts, exact expected insert count and reviewed classification rows. It contains no
real KVK allowlist. Existing legacy KVK_Scan and thirteen source metadata roots are
inventoried under held exclusive locks; child facts are bound to those roots. Mixed
streams fail closed. Missing classifications, unknown scopes, conflicting existing
choices/provenance or changed preview counts fail before any retained-data insert.
Rejected import attempts count as potential source history and require explicit review.
Do not infer source from Enabled or upload arrival. An empty allowlist cannot bypass
unclassified history. Existing classification is verified rather than overwritten.

Preview mode rolls back its schema and prospective inserts. Apply mode commits exactly
the approved new SeasonSource rows. Both verify the entire new catalog: columns/types/
collations/nullability, key columns/options, trusted non-cascading FKs, named CHECKs and
their SQL Server canonical definitions. Empty temporary shape tables allow the server
to canonicalize CHECK syntax; no extra persisted object is created. Incompatible partial
or full installations fail instead of being skipped or repaired. Backup/preview receipt
strings do not themselves prove backup success or operator approval.

The migration owns its transaction (`TransactionMode: None` tells the existing runner
not to add another); ambient transactions are rejected. The application lock serializes
installers and existing SeasonSource is locked first. The operation also requires a later
maintenance window with all writers stopped: catalog/history scans and TABLOCKX can block.
Runtime blocking and duration are unmeasured. Apply is additive, never activation. No
component selection/publication is automatically promoted and no intent is backfilled.
After retained data exists, rollback means preserving the schema/history and proposing a
reviewed forward fix, not dropping tables or switching source.

### Actual static evidence and limits

Local evidence directory: `C:/Users/cwatt/AppData/Local/Temp/k98-s8a-cdnzg6zy`.
This is local retained evidence, not a committed or external durable archive.

- `static_check.py`: 96/96 offline checks passed, including every new FK's authoritative
  candidate key/type/collation, snapshot parity, migration scope/guards and retained hashes.
- Installed SQLFluff T-SQL parser: all seven SQL files and eight embedded literal SQL
  batches parsed without violations. An initial parser failure exposed the reserved
  unquoted RowCount identifier in a temporary inventory; it was changed to HistoryRows
  before the final parse. No SQL Server compilation/binding result is claimed.
- Inspected `deploy/Validate-SqlRepo.ps1` ran against an isolated local file copy with
  this exact authored SQL overlay and succeeded. Its existing repository warnings remain
  in `check-6.txt`; none names the new migration. Its validation log was written only to
  that scratch copy, preserving repository and operational logs.
- Bot architecture validator passed (0 Python files); deferred validator passed (25
  existing Markdown files); security-routing validator passed (0 errors/warnings);
  exact 27-path test selector and Bot whitespace checks passed. Generic runtime pytest,
  smoke imports, registration, staged hooks and predecessor rehearsals are skipped:
  Bot changes are Markdown-only, staging/SQL operations are not authorized.
- The validation script is authored, **not run**: six separately selectable scenarios
  cover preview/install/rerun, historical legacy classification/opposing choice,
  mixed-history rejection, empty-allowlist rejection, partial-schema rejection, and
  rollback-only constraint fixtures with 23 negative cases. SQL Server execution,
  transactions, constraint runtime behavior, backup restoration, two-session schedules
  and all S8B service/integration tests remain unverified.

Security routing: SQL persistence/data-integrity changes require `security-diff-scan`,
**Changes, Deep off**, exact uncommitted eight-file SQL target against the recorded HEAD.
Sealed report/coverage and final target hashes are delivered with this local review;
no security pass is inferred from static checks. Bot's separate exact 27-path Markdown
patch against `a2f148fa9bd4fb367fd46d0500a768c14fee915b` qualifies for documented skip:
no executable, permission, configuration, dependency, input, data-access, network or
persistence behavior changes. There is no standard/deep audit or new task.

### Exact proposed disposable execution plan — requires separate approval

Proposed server: `9SX2VF4\K98DEV`, reached locally using `lpc:localhost\K98DEV` and
Windows authentication. This is a proposal based on retained evidence, **not a fresh
server identity/availability check**. No production server/database or retained
predecessor database is a permitted substitute.

1. Separately approve a read-only identity/version/compatibility/backup-path check and
   database-name absence check on that exact instance. Proposed new database names are
   `K98_S8A_Disposable_20260912_install`, `_legacy`, `_mixed`, `_unclassified`, and
   `_partial`, each with the full `K98_S8A_Disposable_20260912` prefix. If any exists,
   stop; no overwrite, restore-over, drop or name substitution. Capture both repository
   refs/status, all eight file hashes, migration UTF-16LE hash and explicit operation text.
2. Separately approve creation of those five empty databases and inert prerequisite
   bootstrap only: KVK schema, the authoritative KVK.KVK_Scan table definition for
   fixture compatibility, then accepted migrations 20260909_001 and 20260910_001 in
   dependency order. No predecessor fixture/worker is run and no data is restored from
   a retained database. The bootstrap extracts the exact reviewed legacy table definition
   for this disposable fixture; it is not a production snapshot deployment.
3. Before each migration scenario, separately approve full COPY_ONLY/CHECKSUM backup of
   that database to the verified writable instance backup directory, with distinct
   `<database>_pre_s8a.bak` files and no overwrite, then RESTORE VERIFYONLY. Record actual
   file path, backup result and verification result. The backup directory is not known
   from static files and must be resolved in step 1 before operation approval.
4. Approve the exact selected-case SQL text from the validation file, target session
   context and `#S8AMigrationInput` payload. Bind the reviewed migration text as Unicode;
   verify its file SHA-256 externally and UTF-16LE hash inside the script. The five
   installer cases run once each on their named empty targets. `install` performs
   rollback preview, apply and catalog-verifying rerun. `legacy` inserts one explicitly
   synthetic KVK_Scan row for KVK 2147483500, classifies it as legacy/closed with synthetic
   provenance, then preview/apply/rerun and opposing-source rejection. `mixed` inserts
   that synthetic legacy row plus a disabled SourceRouting row and must reject 51801.
   `unclassified` inserts only that legacy row with an empty allowlist and must reject
   51801. `partial` creates only an incomplete SeasonSource table and must reject 51810.
   These are synthetic fixtures, not environment classification recommendations.
5. Run `constraints` on the still-empty installed `_install` database with its own exact
   approval context. It inserts synthetic B0/config/input/publication/pointer/vector rows,
   checks 23 expected constraint failures plus positive scope/reuse/membership states,
   then rolls back and verifies all new and prerequisite tables remain empty. No real
   imports/calculations/exports occur. Record every assertion, SQL error and actual count.
6. Separately approve the validation file's two-session installer/onboarding schedules
   on `_install`, using fresh synthetic KVK identities and explicit BEGIN/COMMIT/ROLLBACK
   operations. Capture blocking, timeout or duplicate/conflict results and final choices.
   The pair/vector/lost-ack schedule is a proposed S8B test, not executable in S8A.
7. Stop and retain all five databases, backups and transcripts. No automatic cleanup,
   source activation, import/export, worker start or retained-file disposition. Failed
   cases preserve evidence and require a reviewed forward fix/rerun plan.

Every actual database target, backup/row preview/classification and operation script
still needs separate approval. No SQL connection or execution occurred in this delivery.
The proposal cannot be called execution-ready until step 1 supplies the backup path and
the operator approves the exact scripts/rows. No runner with production defaults is used.

### Preserved programme and separate repository handoff

All 27 Bot carry-forward paths are preserved byte-for-byte from entry: the 23-path
post-S6 handoff, both S7 outputs and both S8A pack/starter outputs, including both source
deletions and both destinations of the S6 archive moves. Bot main/origin main remains
`a2f148fa9bd4fb367fd46d0500a768c14fee915b`; local production/main remains
`a8c9c515066ca6ef079120b76dd160e3389badab`. Mirror #272 and production-repository #579
remain accepted merged evidence. Local deployment is operator-attested, not production
runtime deployment or a fresh post-merge smoke.

S1-S6 evidence remains accepted. S6-OPS01/PERF01/CAP01 keep their unresolved operational
parts. Publications `e19c89ac-7977-5f28-ae4c-031807cd1728` and
`54a2480a-26fb-5bad-a3f5-9321525a731c` remain retained uncertainties; exact IDs/file
sets/hashes/fences/states remain in the byte-preserved Bot S6 evidence. The benchmark
and both uncertain readback files match their recorded SHA-256 hashes. No database,
provider or retained-file state was queried or changed.

SQL needs its own later PR; the 27 Bot paths need their own later Bot PR. No path is
claimed already merged. For each eventual PR, verify actual Files changed against its
manifest using both filename and previous_filename, or provide exact prior merge/content
evidence for each omitted path. No stage/commit/push/PR/merge/pull/reset/fetch is performed.
This is a reviewable file/static-evidence checkpoint, not deployment or release approval.


## S8A disposable execution and PR handoff — 2026-09-12

The operator separately approved the exact six-script disposable package after the
read-only target/name/backup-path preflight. All six scripts completed with sqlcmd exit
code 0 on local `9SX2VF4\K98DEV` (SQL Server 16.0.1200.5 Developer Edition). This
supersedes the preceding authored-only/no-execution status for those approved operations.
It does not authorize production SQL, deployment, activation or S8B implementation.

| Case | Actual outcome |
| --- | --- |
| install | Preview rolled back; apply and full-catalog rerun passed; zero choices |
| constraints | All 23 negative assertions passed; all synthetic fixture rows rolled back |
| legacy | One synthetic legacy choice; preview/apply/rerun passed; opposing source rejected |
| mixed | Expected 51801 rejection; mixed synthetic history retained |
| unclassified | Expected 51801 rejection; synthetic legacy row retained |
| partial | Expected 51810 rejection; incomplete synthetic schema retained |

Five new databases remain retained: `K98_S8A_Disposable_20260912_install`,
`K98_S8A_Disposable_20260912_legacy`, `K98_S8A_Disposable_20260912_mixed`,
`K98_S8A_Disposable_20260912_unclassified`, `K98_S8A_Disposable_20260912_partial`.
Each COPY_ONLY/CHECKSUM backup succeeded and RESTORE VERIFYONLY reported valid;
the constraints session also reverified the install backup. Backups are the full
database name plus `_pre_s8a.bak` under
`C:\Program Files\Microsoft SQL Server\MSSQL16.K98DEV\MSSQL\Backup`.
No actual restore or cleanup occurred. Synthetic KVK 2147483500 is not a real allowlist.
All predecessor evidence/databases, both uncertain publications and S6 gates remain intact.

Execution bundle: `C:/Users/cwatt/AppData/Local/Temp/k98-s8a-cdnzg6zy/disposable-plan`.
Retain `manifest.json`, `execution-results.json`, `EXECUTION-RESULTS.md` and all six
`execution-<case>-01.txt` transcripts. These are local evidence, not a remote archive.
Transcript SHA-256 values, for independent matching:

| Case | Transcript SHA-256 |
| --- | --- |
| install | `16d9b47ae49e2ca7f87f191c5015cb49c766523dc7466157929fc0b6b0300f70` |
| constraints | `de324905ebc3563d4b7b7354b774184312288b757f918a6c2b56f2b8f1b3fe9f` |
| legacy | `3e86e6044c6eb3d04db68f992983f65f174566639f9f22af8b8e4d8be6a15698` |
| mixed | `d96a7d3dd1416823a888a2fc75e9e2333bedfac18ea43a276e4a924400b7fb17` |
| unclassified | `b68fb9e99c55f7c0b6c7d08c2ee8c41e6b16b9050c6598532e7454dfe4f3eef3` |
| partial | `c39cfce55f32e8cb3b5c9e94d9229c087e326e3282bf9182d304bfd476a9dafa` |

SQL Changes review `b9c38572-208e-4dfe-aa4b-17bae8c560db` completed and sealed at
2026-09-12T21:04:13.709462Z, Deep off, base/head
`44afa315dd6cbfe9fec101f2a39a62e534f5b583`, snapshot
`codex-security-snapshot/v1:sha256:af335e0ccf70029c311320625956346b4b06d2de326f61f821614e6af96e734e`.
All seven SQL source files and the then-current delivery log were reviewed; zero
reportable findings. The seven source files remain byte-identical to that reviewed
target. This later delivery-log append is documentation-only and receives a documented
scan skip: no executable, configuration, permission, data-access, network, deployment
or persistence behavior changes. The old scan is not represented as a fresh scan of
the appended documentation. Final PR review must verify this source-equivalence mapping.

Remaining limits: two-session concurrency, actual restore recovery, S8B authorization,
semantic pair/counterpart validation, CAS and atomic vector behavior are unverified.
Public routing is still absent. No helper/refactor or unrelated debt was introduced.

The operator subsequently authorized separate SQL and Bot mirror PR preparation and
creation. The SQL manifest remains exactly eight paths. The Bot PR must preserve all
27 carry-forward paths, including both origins/destinations of the S6 archive moves.
Verify actual provider Files changed with filename and previous_filename before handoff.
PR creation does not authorize merge, production promotion or database deployment.


## PR #80 review follow-up: standard runner integration

Review found that the normal runner had no way to provide S8A temporary inputs on its
fresh connection. The review-fix scope adds `deploy/Deploy-SqlMigration.ps1` and
`deploy/Test-S8AMigrationInputs.ps1` to the original eight paths: ten SQL PR paths total.
This is a bounded deployment/test addition authorized by the operator's review-action
request, not a change to the approved S7 data model or S8B scope.

The existing runner now accepts `-S8AInputFile` (reviewed UTF-8 plain SQL prelude) and
`-S8AInputSha256` only with exact `-MigrationId 20260912_001_kvk_season_complete_updates`
and explicit server/database arguments. The prelude creates/populates #S8AApproval and
#S8AClassification under the migration's existing contract. Its exact hash is checked
before connecting. Prelude, apply-only guard and unchanged migration share one SqlClient
connection. The existing backup/clean-tree checks and SchemaMigrationHistory success/
failure recording remain in the runner. The ledger must exist before S8A apply. An
already-Applied migration is skipped by the existing history check. If SQL commits but
the separate history write fails, preserve the input and obtain a reviewed rerun with an
updated ExpectedNewChoices count (normally zero). The migration verifies existing catalog/choices and the normal runner repairs its history; never reset data.

Preview remains a separately approved explicit operation, not a runner deployment:
the runner rejects preview mode so it cannot record rolled-back schema as Applied.
Missing inputs fail before any pending migration is applied and explain the required
targeted command. After approved S8A apply/history completion, normal pending deployment
can continue. Never invent historical rows or use a default production target.

Example command shape (placeholders require separately approved actual values):
`Deploy-SqlMigration.ps1 -ServerName <approved-server> -DatabaseName <approved-database> -MigrationId 20260912_001_kvk_season_complete_updates -S8AInputFile <reviewed-input.sql> -S8AInputSha256 <approved-sha256>`.
This source change does not authorize running it against any retained or new database.
The six earlier disposable results remain valid for the unchanged migration/fixture;
they do not claim runtime coverage of the new runner path. Offline regression checks
cover same-connection ordering, hash/directive rejection and error/disposal behavior.
The runner change requires its own exact Changes review, Deep off, before final handoff.
