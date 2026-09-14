# SQL Delivery Log

> Current KVK status, 2026-09-14: S9B repository delivery is complete. SQL #84,
> Bot mirror #277 and production #584 are merged and locally pulled; the bot machine is unchanged.
> S10A Shared Export Coordination SQL Foundation is implemented and published in
> [SQL PR #85](https://github.com/cwatts6/K98-bot-SQL-Server/pull/85), pending review and merge.
> Approved disposable validation is complete: backup/actual restore, all five fixture modes,
> 76 unique structural cases in both install and constraints, and direct apply/rerun passed.
> Retained databases and evidence are preserved; merge and deployment remain separate.
> Both delivery-log and migration-README updates are included in that S10A SQL
> implementation PR. Bot handoff documentation stays in Bot for the next Bot implementation PR,
> S10B; no standalone documentation PR. Earlier status/publication checkpoints are historical.
> No SQL execution, bot-machine pull, deployment or activation is authorized by this update.



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


## S8A KVK SQL foundation â€” authored 2026-09-12, execution not authorized

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

### Exact proposed disposable execution plan â€” requires separate approval

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


## S8A disposable execution and PR handoff â€” 2026-09-12

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

## S8A accepted closeout and S8B handoff â€” 2026-09-13

S8A is complete, operator smoke accepted and merged. SQL PR #80 merged at
2026-09-13 06:47:39 UTC as `50310950a1adb7425e6db6bc86f38bdeb38e0830`, reviewed
head `120110e0222881b8938e5071544267f6afb74995`. Actual GitHub Files changed confirms
ten paths, including the runner/test amendment to the original eight. Local SQL
main/origin main matches the merge; the worktree was clean before this documentation append.
Bot mirror #273 and production #580 are merged; the operator confirms local pulls complete
and no changes pulled to the bot machine. No production runtime deployment is claimed.

Smoke acceptance is operator-attested and supported by the six successful disposable
scripts recorded above. The later runner fix retains offline-only validation; no fresh
post-merge SQL execution, two-session concurrency pass or actual restore is claimed.
The follow-up Changes review `7c5a7f68-9bd7-4629-b035-0d0b757404a4` completed/sealed
2026-09-12T22:00:17.914530Z at `05d7815..120110e` with zero reportable findings, Deep off.
The original seven SQL files and their accepted source/disposable evidence remain unchanged.
Migration `20260912_001` is retained without renaming. No real allowlist rows are added.

Next is S8B Bot source/matched-update DAL and services, initial review/scope in a new chat.
It owns immutable choices/sealed tuples, authorization, eligibility/counterpart validation,
CAS and atomic complete selection plus full-vector intent. Ordinary public routing remains
separate S9 work; SourceRouting.Enabled alone is insufficient. Further database operations
require exact target, backup/row preview and operation approval. S1â€“S6 acceptance,
S6-OPS01/PERF01/CAP01, both uncertain publications and every retained database/file remain intact.

This append is a separate SQL documentation carry-forward for a later authorized SQL PR,
not part of the S8B Bot PR. Verify its actual Files changed or prove this exact append merged.
Bot closeout, four archived S7/S8A pack/starter pairs of paths and the S8B preparation outputs
are listed in the Bot handoff `s8a_closeout_and_s8b_handoff.md`, carried by [Bot PR #274](https://github.com/cwatts6/K98-bot-mirror/pull/274).
Security routing: documentation-only skip for this append against the merge above; no
executable/configuration/permission/data-access/deployment/persistence behavior changes.
No SQL connection/execution, stage/commit/push/PR/merge, deployment or cleanup performed.


## S8B no-fight update amendment â€” 2026-09-13 (authored, not executed)

The operator approved closing the recorded S8B gaps. Migration
`20260913_001_kvk_source_update_no_fight_context.sql` adds required `SourceUpdate.PeriodKind`
copied from the immutable period and rebinds the scoped kind FK to that classification.
`UpdateKind=no_fight` may then apply to an existing fight period without changing its identity.
The new mode check rejects all other cross-kind combinations; existing equal-player-input,
no-aggregate, readiness and scoped revision/configuration constraints remain intact. The Bot
additionally requires explicitly confirmed equal configured endpoints and exact revisions.
No historical ID, hash, confirmation, state, selection, intent or publication is rewritten.

Execution remains separately gated: provide exact target, backup/restore and metadata preview
receipts plus expected update count in `#S8BNoFightApproval`. Review `preview`, then separately
approve `apply` with all source writers idle. This batch owns its transaction and is intended
for a reviewed same-session invocation, not the generic pending deploy runner (which does not
supply this input table). Do not alter runner/history behavior or rerun predecessors implicitly.
Deploy the amendment before the revised S8B writer; older inserts omit the required column
and fail closed. Retained no-fight fight-period updates require forward fixes, not a downgrade.
Disposable validation must prove preview/apply/rerun, rollback, FK/check rejection and retained
history identity before deployment. No SQL connection or execution is claimed by this entry.


S8B amendment offline review evidence, 2026-09-13: separate SQL Changes scan
`ebf9cb6a-f2a8-4399-9879-ec1d5b67458b` sealed at 08:33:04 UTC, Deep off, zero findings,
complete two-source-file coverage plus both documentation paths. Snapshot digest:
`49a1bcb632ba32c6aa3032b986e3b23c57621478c8e5f7bba62d710d944b2816`.
SQLFluff T-SQL parsing passed migration, both constant dynamic batches and snapshot.
Isolated-copy Validate-SqlRepo passed with only 15 older-migration warnings; no operational
SQL logs changed. Bot offline rerun: 4,139 passed / 57 skipped, logs unchanged; SQL tests
remain gated. These results do not assert SQL Server compilation or execution. This final
Markdown evidence append has a documentation-only security skip with no runtime effect.
Source implementation approval is satisfied; actual target/backup/preview/apply/rerun and
real concurrency evidence still require the separate SQL operations gate. Preserve this
SQL delivery-log carry-forward in the SQL PR, never in the Bot PR. No SQL connection,
Git publication, deployment, predecessor rerun or retained-data cleanup occurred.


## S8B approved disposable execution completed â€” 2026-09-13

The operator approved the exact new target `9SX2VF4\K98DEV` /
`K98_S8B_Disposable_20260913_validation` and separate actual-restore database
`K98_S8B_Disposable_20260913_validation_restore`. Both are retained. COPY_ONLY/CHECKSUM backup,
RESTORE VERIFYONLY and actual RESTORE passed; restored baseline digests matched all thirty
original table projections. Wrong target/count rejected unchanged. Migration preview, apply and
fresh-session rerun passed, preserving every original-column count/content digest.

Amendment SHA256: `aa66a2015e089a7df9ae5cdb6e4d89f96e3d0cfacfa119ba9ca7d39dcf8ac807`.
Snapshot SHA256: `bdf354f1c78fb113c04b22d073a0ee5fd6771d41e79f31ec1d5cb8ec5cad432a`.
Both source files remain unchanged from separate SQL Changes review
`ebf9cb6a-f2a8-4399-9879-ec1d5b67458b` (Deep off, zero findings).

Evidence root: `C:/Users/cwatt/AppData/Local/Temp/k98-s8b-execution-dzmmcw49`.
Original manifest SHA256 `ab149d5622661a059736b149d9a03500f91f26f8ef75bc09efaff32f1beaedbb`;
reviewed-continuation-01 manifest `227d69ca50840654b250e39804974141222bc923c20a08ea71343b24c0f6d0ad`.
The first connection failure, rolled-back bootstrap dependency-order failure and initial SQL
suite (30 passed / 20 failed) remain recorded. A reviewed continuation moved the existing roster
unique key before its dependent FK after verifying an empty target; no database was dropped.
Related Bot-only synthetic fixture corrections passed 22 selected cases, then **all 50 SQL
cases in 25.09 seconds**. Receipts, JUnit, transcripts and execution-summary.md are retained in
reviewed-continuation-01. Final offline suite: **4,139 passed / 57 skipped**, logs unchanged.

This closes the disposable migration and real transaction/concurrency evidence gaps. Earlier
unexecuted entries are historical; this is not production deployment, operator acceptance of
these new results, or a fresh S7/S8A post-merge smoke. SQL-before-Bot rollout with source writers
idle and actual publication/merge/deployment gates remain separately authorized work. Preserve
all four SQL delivery paths and this entire log carry-forward in a SQL PR, never the Bot PR.
No provider operation, predecessor runner, retained-data cleanup or Git mutation occurred.
This append is documentation-only and has a precise security skip: no executable, configuration,
permission, input, data-access or persistence change. All retained S6/S7/S8A evidence remains.


## Operator acceptance and publication approval â€” 2026-09-13

The operator accepted the completed S8B implementation, gap closure and disposable validation,
and explicitly approved publication. Publish separate Bot mirror and SQL PRs with the exact
51-path Bot and four-path SQL manifests. This supersedes earlier pending acceptance/publication
wording; it does not authorize merge, production promotion, deployment, activation or new runtime
operations. Preserve all earlier evidence and verify actual PR filename plus previous_filename
for every path, including the four archive origin/destination pairs. SQL delivery-log carry-forward
remains exclusively in the SQL PR. Source/test bytes are unchanged from accepted validation and
final Changes reviews; these acceptance/status edits have a documentation-only security skip.


## PR #81 review action â€” supported S8B runner path

The P1 missing same-session input/history path was confirmed. The approved review-action scope
adds deploy/Deploy-SqlMigration.ps1 and deploy/Test-S8AMigrationInputs.ps1 to the SQL delivery:
six physical SQL paths in total, with all original four carry-forward paths retained. The Bot
manifest remains 51 physical paths; no SQL delivery log enters its PR.

Use Deploy-SqlMigration.ps1 with exact MigrationId
`20260913_001_kvk_source_update_no_fight_context`, explicit ServerName and DatabaseName,
and S8BInputFile plus its S8BInputSha256. The input is a separately reviewed UTF-8 SQL prelude
creating and populating exactly one `#S8BNoFightApproval` row with Mode=apply, exact target,
backup/restore evidence, preview evidence and expected row count. It must not open a transaction.
The runner verifies the input bytes against SHA256 and rejects SQLCMD directives before opening
the migration connection. Prelude, apply/history guard and migration run on that same connection.

The guard requires SchemaMigrationHistory and refuses preview mode. Only a successful migration
returns to the existing Applied-history writer; failures take the Failed-history path. If the
history write fails after schema commit, a newly reviewed exact count/evidence packet permits the
migration's verified idempotent rerun to complete history. No manual history deletion or fake
Applied record is a supported recovery path. Preview remains a separately approved operation and
must never be recorded as Applied. This runner support does not grant SQL execution permission.

Offline regression coverage in Test-S8AMigrationInputs.ps1 now covers both S8A and S8B: exact
argument gates, hash/directive rejection, one-connection batch order, guard failure/disposal,
pending-migration rejection, S8B dispatch and Applied/Failed history ordering with mocked SQL.
The S8A entry point and guard are retained through the shared reviewed-session executor.
No live deployment-runner or migration-history execution is claimed by these offline checks.


PR-fix validation: offline S8A/S8B runner tests passed, including actual runner gate/dispatch/history
control flow with fake connections. Separate SQL Changes review
33e0bcba-9127-45a8-95d5-b2fa26e048f2 sealed 2026-09-13 09:55:32 UTC, Deep off, zero findings,
complete changed-source coverage. Bot review ef9cf7e4-f388-4e8b-9f64-dfaba85f13b1 likewise completed;
full offline Bot suite 4,149 passed /57 skipped, logs unchanged. New runner history execution was
not tested against live SQL. The retained 50-case disposable result remains historical evidence
for its recorded source. Documentation-only follow-up evidence has a precise security skip.


## S8B accepted closeout and S8C documentation carry-forward â€” 2026-09-13

SQL #81 merged at 10:57:34 UTC as 3983522feb0ff90c96ba56ca11c2dac177f84ca6, final reviewed
head 32d7752f90fba9bbc805d86f80326ce78771924a. All six actual PR file blobs match local
main/origin main at that merge. Bot production #581 merged at 10:58:06 UTC as
9bcbe004ecd6174e7343dbbb552410facd2feb32, reviewed head fc600fdba378e62e1aec5486b5480152d5bc090b.
Bot mirror main/origin main e9114dd62f4f4ee2d8e193bd1f0b9e31b8543486 is synchronized from that
production merge. Mirror #274 is closed without a merge record; content delivery is verified
through production's complete 51-path manifest and local blob equality, not a claimed mirror merge.

The operator confirms successful smoke acceptance and completed local pulls; no changes have
been pulled to the bot machine. S8B is complete. Retained S8B disposable backup/actual restore,
preview/apply/rerun and 50 SQL cases passed at their recorded source hashes. Later runner input/
session/history fixes passed offline with fake connections only; no live runner-history test or
fresh post-merge SQL execution is claimed. S8A six-script/VERIFYONLY evidence remains separate.
Final Bot review fixes passed 43 focused tests and equivalent mirror full offline tests
(4,152 passed / 57 skipped, operational logs unchanged); exact production Changes review
092cb991-5be6-4be6-86e6-1633413b7342 completed with zero findings, Deep off. SQL Changes review
33e0bcba-9127-45a8-95d5-b2fa26e048f2 remains the accepted final SQL review. No SQL code changed here.

S8C Intake and Admin Pairing UX is ready for initial review/scope in a new chat, not implementation
or activation. The companion [Bot PR #275](https://github.com/cwatts6/K98-bot-mirror/pull/275) carries the canonical Bot closeout reference:
`s8b_closeout_and_s8c_handoff.md` in the Bot KVK source-migration reference documentation.
The Bot S8C pack requires its entire documentation manifest and both S8B archive move sides in
the eventual Bot PR. This new SQL_DELIVERY_LOG.md append and migrations/README.md closeout status edit are the exact
two-path separate SQL documentation carry-forward against
3983522feb0ff90c96ba56ca11c2dac177f84ca6; never include it in a Bot PR. Earlier log carry-forward
is already merged in #81. Prove each exact changed path merged if omitted from a later SQL PR.

Preserve S6-OPS01/PERF01/CAP01, both uncertain publications, all disposable/predecessor databases,
backups, files and receipts. No SQL connection/execution, provider/Discord operation, deployment,
activation, cleanup or Git mutation occurred in this closeout. Security skip: these two Markdown status
and evidence edits changes no executable, configuration, data-access or persistence behavior.

## S8C local authoring checkpoint - 2026-09-13

Operator approval covers authoring the S8C review table, additive migration,
disposable-only validation fixture and read-only static contract checker. The exact
SQL union is these four new paths plus this log and migrations/README.md:

- migrations/20260913_002_kvk_source_admin_reviews.sql
- sql_schema/KVK.SourceAdminReview.Table.sql
- validation/kvk_source/s8c_admin_reviews.sql
- deploy/Test-KvkSourceAdminReviewContracts.ps1

The checker passes 13 static checks. No SQL was executed; the disposable fixture
and five opt-in Bot SQL tests remain unrun. Deploy this additive table after S8A/S8B
and before the revised intake is enabled, under separate execution approval.
ReviewSequence orders import snapshots only; it never allocates scan IDs.

These six paths belong exclusively to the separate SQL PR. Preserve the existing
S8B delivery record: accepted operator smoke, retained 50-case disposable evidence,
later offline review fixes and offline-only runner history support are distinct.
S8A six-script evidence remains separate. No fresh post-merge or bot-machine run
is claimed. This checkpoint does not authorize Git publication or deployment.

### S8C PR review corrections

Migration recovery metadata now states Forward Fix Only, consistent with retaining review data.
Migration and disposable fixture set NOCOUNT ON; fixture owner/guild/channel literals are Unicode.
The 13 text-only contract checks pass. Follow-up Changes security review
1f23bee6-0463-4fa7-9eff-6b11a538270f completed with zero findings, Deep off, against
2f419bfbee3124e5bb88b6b94c9768164d431c15. No SQL was executed and the table definition is unchanged.
The six-path SQL PR union and original S8B documentation carry-forward remain intact.

## S8C merged delivery and next steps â€” 2026-09-13

S8C code review and repository delivery are complete. SQL #82 merged at 18:43:41 UTC as
3c1b5ceaa7a686bc594ca8637d0a1569030d66c4 (reviewed head 083718e971acc7d4593610199a5575bd3159b4e8).
Mirror #275 merged at 18:44:03 UTC; production-repository #582 merged at 18:45:13 UTC as
afac4118db4bca282c8d12ea3d121701ae2da3c0. Local SQL main/origin main matches its merge; Bot
main/origin main b6e45293348ece7b562e29c0451a8c3a7dbe2550 is synchronized from production.
All six actual SQL PR file blobs match local HEAD; production's 69 physical Bot paths were
also verified, including archive previous_filename entries. Both worktrees were clean at entry.

Final Bot offline evidence: 4214 passed / 62 skipped, 96 focused tests, operational logs unchanged.
At the repository-delivery checkpoint, hosted Bot and SQL CI passed and the SQL static contract
checker passed 13 checks. The S8C disposable fixture and five opt-in Bot SQL cases had not yet run
at that checkpoint. Their later approved execution for the named disposable target is recorded in
the [disposable execution addendum](#2026-09-13-approved-s8c-disposable-execution-addendum) below.
No bot-machine pull, deployment or activation is claimed. Local whole-repo validation previously
could not write its sandboxed log; hosted SQL validation passed. Earlier entries retain their
dated scope; the addendum supersedes only the named disposable-execution status.

The next implementation slice is S9A Public Routing and Availability, initial review/scope only,
as specified in the approved S7 manifests. See the companion Bot documentation
`s8c_closeout_and_s9a_handoff.md` and S9A pack/starter; completed S8C pack/starter are archived.
Separately scope exact disposable SQL migration/fixture and intake smoke operations for approval
before enabling dependent intake. Apply the additive S8C table after reviewed S8A/S8B prerequisites;
no predecessor rerun is implied. SourceRouting.Enabled alone does not implement public routing.
S9B cards, S10 exports and S11 integration evidence remain later slices.

Preserve accepted S8B smoke and 50-case/actual-restore evidence separately from offline review fixes
and offline-only runner-history support; S8A six-script/VERIFYONLY evidence remains separate.
Preserve S6-OPS01/PERF01/CAP01, both uncertain publications and all databases/backups/files.
This append in docs/SQL_DELIVERY_LOG.md and migrations/README.md is the exact two-path pending SQL
closeout carry-forward against 3c1b5ceaa7a686bc594ca8637d0a1569030d66c4. Deliver it in a separately
authorized SQL PR, never in a Bot PR; omissions require specific merged-content proof.
Security skip: Markdown status/evidence only, no SQL/config/runtime behavior change. No SQL
execution, Git mutation, provider/Discord action or deployment occurs in this closeout.


## 2026-09-13 approved S8C disposable execution addendum

Supersedes the earlier unrun-S8C statements above for this named disposable target only.
Operator approved instance `9SX2VF4\K98DEV`, primary
`K98_S8C_Disposable_20260913_intake`, separate `_restore` database and
`C:/K98-S8C-Smoke/20260913`. New prerequisite fixture backup/VERIFYONLY/actual restore,
S8C migration apply/rerun, rollback fixture and five opt-in S8C SQL tests passed.
The static contract validator passed 13 checks. This used direct SQL execution, not deployment
runner history. S8A/B snapshots were empty prerequisite fixtures; their installers/tests were not rerun.

Real Bot intake/services/DAL used this disposable SQL for synthetic B0, waiting-pair completion,
11âˆ’10/12âˆ’10/13âˆ’10 then authorized 14âˆ’10, later 17/18 assignment, no-fight, independent overall,
weight/camp corrections, explicit synthetic attestation, CAS and semantic duplicate checks.
No production code fix was required. SourceRouting remained disabled and no provider delivery ran.
See [Bot companion PR #276](https://github.com/cwatts6/K98-bot-mirror/pull/276), its
`s8c_folder_intake_smoke_evidence.md`, and retained
`C:/K98-S8C-Smoke/20260913/evidence` for scripts, hashes, failures/resumptions, exact assertions
and limits. Live Discord, real Google kvk_list import and bot-machine smoke are not claimed.

All predecessor evidence, uncertain publications and S6 open gates remain separate and preserved.
These two SQL documentation paths were retained locally at the original closeout checkpoint
and are now committed and published separately in SQL PR #83 for the S9A delivery cycle.
Only documentation changed; no SQL runtime file, deployment or activation changed.

## S9A delivered / S9B documentation carry-forward â€” 2026-09-14

[SQL #83](https://github.com/cwatts6/K98-bot-SQL-Server/pull/83) merged at 10:13:01 UTC as
`278b24b48ed075252217a5525ccb751f8e5bf928`, reviewed head
`810ade56faa25f9e0333e0175b753bfa326190dd`. Local main/origin main match the merge;
the worktree was clean at closeout entry. These are comparison anchors, never reset instructions.
The exact two delivered files were the SQL delivery log and migration README, with local blob
matches. Both SQL static CI checks passed; this documentation-only PR introduced no SQL runtime
change and no migration execution. Historical metadata/CI-link review comments were addressed.

Companion [Bot mirror #276](https://github.com/cwatts6/K98-bot-mirror/pull/276) and
[production #583](https://github.com/cwatts6/K98-bot/pull/583) are merged. Their 56 GitHub entries
cover the exact 58 physical Bot paths after checking filenames and previous filenames for both
S8C archive moves; resulting blobs match synchronized Bot main. The Bot S9A closeout and S9B pack
record current evidence and the fresh pending documentation manifest. S9A's delivered union is
not the next slice's pending carry-forward.

The operator approved these documentation updates on 2026-09-14. Both files are now published
in [SQL PR #84](https://github.com/cwatts6/K98-bot-SQL-Server/pull/84) in the same delivery cycle
as [Bot mirror PR #277](https://github.com/cwatts6/K98-bot-mirror/pull/277). The SQL files are
excluded from Bot. Exact provider filename/previous_filename coverage was verified before
ready-for-review, with no missing paths or already-merged exemptions. The final Bot scope is
23 runtime/test paths after the approved posting amendment; there is no SQL runtime amendment.
Authoritative SQL definitions were validated during Bot implementation.

Retain S8B accepted disposable smoke/50-case and actual-restore evidence separately from offline
runner-history support, S8A six-script evidence and S8C disposable SQL/folder smoke. Chris's seven
local S8C operator checks PASS on 2026-09-14 is not live Discord acceptance. The completed evidence
does not prove production migration application. Preserve S6-OPS01/PERF01/CAP01, both uncertain
publications and all retained databases, backups and files; no predecessor rerun or cleanup.
PR publication was subsequently authorized and completed for the two linked PRs. SQL/provider/Discord
execution, real import/export, bot-machine pull/restart/deployment and activation remain excluded.
Deployment history remains governed
by the migration files and actual SchemaMigrationHistory, not repository merge records.

Security routing: independent documented skip for this exact two-Markdown-file working-tree patch
against `278b24b48ed075252217a5525ccb751f8e5bf928`; no SQL/data-access, permissions, configuration,
execution or persistence behavior changes. No security scan or SQL execution. Validate Markdown
links, exact pending paths and whitespace; runtime SQL checks are intentionally not rerun.


## S9B publication checkpoint â€” 2026-09-14

The operator authorized PR creation following local Bot implementation and review. The final
Bot scope is 23 runtime/test paths plus 35 documentation paths, including the two approved
path amendments. This SQL PR remains limited to `docs/SQL_DELIVERY_LOG.md` and
`migrations/README.md`; no SQL runtime amendment or execution is included. Earlier scope-only
and publication-not-authorized statements describe the historical closeout checkpoint.
The independent documentation-only security skip still applies to these exact two paths.
Bot offline tests and Changes security evidence are recorded in [Bot mirror PR #277](https://github.com/cwatts6/K98-bot-mirror/pull/277)
and the S9B closeout linked from that PR;
they do not establish SQL execution or live Discord acceptance. All retained gates, uncertain
publications, databases and files remain preserved. No merge, deployment or activation occurs.


## S9B delivered / S10A documentation carry-forward â€” 2026-09-14

[SQL PR #84](https://github.com/cwatts6/K98-bot-SQL-Server/pull/84) merged at 13:27:17 UTC as
`d0916f742f9c88743b97107dfca1f3acbcb32c2e`, final reviewed head
`604af8f88e42f43cc80d1848b37312526e56338f`. Both SQL static CI runs passed. Exact provider
coverage is these two documentation paths, with resulting blobs matching local SQL main.
No migration or runtime SQL file was changed by that PR; no SQL execution was performed.

Companion [Bot mirror #277](https://github.com/cwatts6/K98-bot-mirror/pull/277) and
[production #584](https://github.com/cwatts6/k98-bot/pull/584) merged at 13:27:27 and 13:27:58 UTC.
Their exact 56 provider entries cover all 58 physical paths after checking both filename and
previous_filename for both S9A archive moves. Final blobs match synchronized Bot main.
Final Bot offline evidence is 4,350 passed / 62 skipped, operational logs unchanged; final hosted
quality, governance and secrets checks passed. These are retained results, not fresh execution.
No changes have been pulled to the bot machine; no deployment or activation is claimed.

S10A Shared Export Coordination SQL Foundation is next, initial review/scope only, using the
new task pack/starter and S9B closeout retained in the Bot repository. The initial approved SQL
manifest reserves a migration, six general export tables, one SQL validation file and the delivery
log. The migration README is also mandatory, yielding ten initial delivery paths. Resolve the
reserved migration date/sequence during scope before writing SQL. Do not rename merged migrations.

**The eventual S10A SQL implementation PR must include these updated `docs/SQL_DELIVERY_LOG.md`
and `migrations/README.md` alongside its reviewed SQL implementation.** Recheck pending changes
at entry and before PR creation; verify exact filename/previous_filename coverage or explicit
already-merged content proof. Counts alone are insufficient. The Bot-side documentation manifest,
including S9B archive move origins/destinations and S10A preparation outputs, stays in Bot and is
mandatory carry-forward into the next Bot implementation PR (S10B). S10A must preserve and hand
that exact manifest onward. No standalone documentation PR or repository mixing; grouping is
approved and must not be re-requested. Implementation and Git publication need separate approval.

Preserve S6-OPS01/PERF01/CAP01, both uncertain publications and all retained databases/backups/files.
S8B accepted smoke/50-case and actual-restore evidence remains separate from offline runner-history
support, S8A six-script and S8C evidence. S8C seven local checks PASS is not live Discord acceptance.
No SQL/provider/Discord execution, real imports/exports, bot-machine pull/restart/deployment,
activation or predecessor rerun. SchemaMigrationHistory and actual execution records, not PR merges,
remain the deployment truth. SourceRouting.Enabled alone is insufficient.

Security routing: independent documentation-only skip for this exact two-Markdown-file update
against `d0916f742f9c88743b97107dfca1f3acbcb32c2e`. No runtime, data-access, permission, configuration,
dependency or persistence behavior changes. Validate links, documentation references, whitespace
and exact paths. No SQL runtime execution or fresh security scan for this closeout.

## S10A approved local SQL implementation â€” 2026-09-14

The operator approved local implementation and closure of the physical-design gaps.
This is additive SQL authoring, offline validation and Changes security review only.
SQL execution (including disposable databases), provider/Discord operations, imports/exports,
Git staging/commit/publication, bot-machine changes, deployment and activation remain unapproved.
Earlier initial-scope statements above are historical. No S10B/C/D/E or S11 implementation.

### Exact SQL delivery manifest

The uncreated S7 reservation was amended to the actual authoring date and free sequence:
`migrations/20260914_001_shared_export_coordination.sql`. No merged migration was renamed.
The eventual SQL implementation PR must include ALL ten paths below, including both
pre-existing pending documentation files. Check provider filename AND previous_filename,
or supply per-path merged-content proof; counts alone are insufficient.

- migrations/20260914_001_shared_export_coordination.sql
- sql_schema/dbo.ExportJob.Table.sql
- sql_schema/dbo.ExportJobResource.Table.sql
- sql_schema/dbo.ExportResource.Table.sql
- sql_schema/dbo.ExportRequestBudget.Table.sql
- sql_schema/dbo.ExportAttempt.Table.sql
- sql_schema/dbo.ExportAttemptPart.Table.sql
- validation/kvk_source/s10_export_coordination.sql
- docs/SQL_DELIVERY_LOG.md
- migrations/README.md

### Physical contract and closed design gaps

All identity/enumeration text uses Latin1_General_100_BIN2. UUIDs are uniqueidentifier,
digests binary(32), audit timestamps datetime2(0) UTC, budget timestamps datetime2(3) UTC.
There are no application defaults, seed rows, permissions, cascade deletes or activation changes.
Required identifiers reject empty/edge-spaced values; enums reject trailing-space aliases.

| Table | Contract |
|---|---|
| ExportJob | JobID PK; ConsumerKind new_source/all_kvk/scan_data. New-source requires SourceKey=snapshot_report_v1, positive KVK_NO/PoolEpoch and scoped IntentID FK. All-KVK requires positive KVK_NO, no source intent/epoch; scan-data has no season/intent/epoch. AccountKey varchar(128), input/destination hashes; nullable RepairID. Replay UQ includes consumer/account/season/input/destination/epoch/repair, INCLUDING NULL epoch/repair tuples; no filtered NULL escape. SpoolKey varchar(128) is an opaque ASCII alphanumeric/underscore/hyphen token; SpoolBytes positive bigint and StorageOwner varchar(128) are all-or-none, mandatory for legacy/daily jobs. New-source may reload pinned SQL facts without a spool. |
| ExportJob state | waiting/ready/running/confirmed/failed/uncertain/coalesced/cancelled. Unclaimed waiting/ready/coalesced/cancelled have NULL OwnerID and fence 0; attempted running/confirmed/failed/uncertain retain UUID OwnerID and positive fence. Version and EnqueueSequence are positive bigint. Tickets are caller-supplied, not identity or unique: a successor may inherit the original pending ticket while history retains it. Supersession is only coalesced new-source and FK-scoped to consumer/account/season/destination/epoch. Actor nvarchar(128), Reason nvarchar(1024), provenance valid JSON <=65536 bytes. |
| ExportResource / ExportJobResource | ResourceKey varchar(256) PK; kind account/destination/sql_snapshot. JobResource PK(JobID,ResourceKey), both parent FKs and reverse index. Resource active ownership FK references declared membership, preventing an undeclared job claim. ActiveJobID/OwnerID are paired; claimed fence positive; free resources retain a nonnegative fence. BlockedReason nullable nvarchar(1024), Version positive bigint. A blocked resource may remain unassigned for an ambiguous historical association. |
| ExportRequestBudget | PK(AccountKey varchar(128),BudgetKind varchar(32)); initial allowed kind google_request covers both Google client stacks. NextAllowedUTC required, CooldownUntilUTC optional, both datetime2(3). IntervalMilliseconds int 1..86400000; PolicyVersion/Version positive bigint. No seeded budget or implicit quota. Later DAL starts with the retained 2100ms spacing and reserves max(server UTC,next allowance,cooldown) atomically. The interval bound is representation safety, not provider quota; cooldown can extend independently. |
| ExportAttempt | AttemptID PK, UQ(JobID,AttemptNo), positive bigint owner fence/attempt/remote sequence/CAS version. ConsumerKind and optional Epoch FKs pin job kind/epoch without binding old attempts to a mutable current owner. Phase private_started/verified/publication_pending/published/failed/uncertain/retired. Verified/publication phases require verification time; published/retired require publication time and receipt. Manifest hash and JSON required, receipt JSON optional; each JSON <=65536 bytes. PartCount int 1..1024 counts every represented file, including an index when present. This is a schema safety limit, not pool capacity or provider policy. |
| ExportAttempt legacy reference | Optional complete six-column reference: publication/source/KVK/period/destination-kind/destination-ID. Exact SourceDelivery PK FK plus scoped SourcePublication FK and job-season FK. Only new-source attempts may reference this predecessor table, even though columns use the Legacy prefix. Existing receipt bytes remain in SourceDelivery. No receipt import/backfill occurs. |
| ExportAttemptPart | PK(AttemptID,PartNo), UQ(AttemptID,FileID); FileID nvarchar(128) BIN2. PartCount copied and FK-bound to attempt; PartNo 1..PartCount. Role index/generation/output. ManifestHash required; GridCount positive int, RowCount nonnegative bigint, CellCount positive bigint >=RowCount. VerificationState pending/verified/failed/uncertain with verified timestamp required exactly for verified. AclState pending/private/public_viewer/failed/uncertain; non-pending requires observation time. QuarantineState none/quarantined; quarantine requires time/reason (nvarchar(1024)). EvidenceJson optional valid JSON <=65536 bytes; Version positive bigint. |

The bounded manifest is metadata; normalized part rows hold per-file evidence. Exhaustion must
reject before any provider mutation, never truncate receipts or assume 1024 files are provisioned.
New vocabularies require a reviewed schema/protocol amendment, never unvalidated strings.

Queue indexes support account/state/ticket, intent and supersession lookup. Resource reverse/active
indexes support admission inspection. Attempt job/sequence and phase/time indexes support recovery.
All scoped FK column types/collations were checked against authoritative snapshots.

### Static SQL versus later writer obligations

SQL enforces row shape, scoped relationships, bounded evidence and uniqueness. It does NOT prove
temporal immutability, authorized repairs, valid provider receipts or complete manifest cardinality.
Authorized later DAL must validate exactly PartCount distinct rows, hashes, pinned intent vector
and matching legacy receipt publication membership before mutation/confirmation. Existing complete
selection FKs alone also do not prove matching input tuples: keep S8B sealed-input/CAS validation.

Resource ownership/fence updates must be monotonic and atomic across Job/Resource under the later
admission protocol. Matching resource/job owner tuples, canonical resolved account/file identities,
frozen resource membership, oldest-ticket fairness, retained repair authority, immutable attempt
identity and valid phase transitions are DAL/service guarantees. Historical attempts must not FK
to the mutable current job owner, nor be overwritten when another owner/attempt is admitted.

Keep running A pinned while pending B/C arrive; coalesce only eligible pending new-source work,
preserving B and its ticket. Daily SCANORDER jobs are not coalesced. An uncertain claim blocks
conflicting admission even after timeout/lease expiry. SQL fences cannot cancel a submitted Google
request. Blocked/unmapped history is not free capacity. Later recovery needs exact readback and
terminated-worker evidence. Failed pre-mutation work may be retried under a new retained attempt;
do not erase ownership evidence to make it look never attempted.

Account admission precedes sorted destination acquisition and short job CAS. Budget reservations
are separate short transactions; waits/provider calls occur after commit. Legacy SQL snapshot
admission is confined to producer/capture work and released before provider work. All participating
writers must use the same coordinator database/admission; bypassing writers remain a deployment
gate. The existing Bot publication_gate/latest-selection behavior is unchanged until S10B/C.

### Migration classification, order and recovery

DataChange: No; zero existing application rows affected. RequiresBackup: Yes; DataSafetyPlan:
Included; rollback Forward Fix Only. Creates Job, Resource, JobResource, Budget, Attempt and Part,
then adds FKs including cyclic active membership. Uses XACT_ABORT and a transaction-owned schema
application lock. Owns commit/rollback only when no caller transaction exists; an ambient caller
must roll back on failure. No SQL transaction spans provider work.

Absent-all installs atomically. Partial presence fails before creation. Full presence is verified
against empty temporary expected shapes through SQL catalog comparisons: column types/nullability/
collations, CHECK expressions without lossy normalization, trusted/enabled checks and FKs, index
grouping/uniqueness/order, and absence of unexpected defaults/triggers/table modes. Conflicting
schema is rejected without attempting history repair. Compatible reruns do not alter application
rows. Deploy only the migration; snapshots describe post-installation state and their cyclic FKs
require creating all tables first if constructing a separately approved empty prerequisite fixture.

Forward correction retains tables, attempts, receipts and fences. No history cleanup, backfill,
old-receipt mapping, automatic repair, predecessor rerun or manual migration-history rewrite.
Deploy after S8A/S8B prerequisites and before coordinated Bot writers, with separate execution
approval. Repository delivery is never proof of migration application.

### Validation and retained evidence boundaries

76 offline static checks and 85 T-SQL parse inputs passed (eight artifacts, embedded test body,
76 case statements). The fixture authors 76 structural cases and five guarded modes (install,
constraints, partial, drift, type_conflict), including exact NULL replay, repairs/epochs, scopes, key/JSON limits,
ownership membership, budget precision, attempt/part evidence, and unchanged uncertain state on
rerun. These SQL cases have NOT executed. Later execution requires exact new disposable target,
reviewed migration hash, backup/actual-restore evidence and independent operation approval.
No mock/static result establishes SQL Server catalog behavior, concurrency or provider acceptance.

Offline validation evidence is retained outside Git at
`C:/Users/cwatt/AppData/Local/Temp/k98-s10a-implementation-20260914`.
Security review is separately tracked at its exact working-patch snapshot; do not treat this
authoring checkpoint as a completed scan or live acceptance claim.

All pending Bot documentation remains mandatory in S10B's next Bot implementation PR, including
the S10A pack/starter, S9B closeout and both sides of both S9B archive moves. The new Bot handoff
is added to that exact manifest; no Bot file enters this SQL PR, no standalone documentation PR.

Preserve fixed source, supplied overall/B0, independent stats/targets/publication/roster/history/
daily consumers, authoritative aggregate/DKP values, UTC starts, SCANORDER, unused scans, movable
within-season windows, exact 11-10/12-10/13-10/authorized14-10 endpoint chain, sealed inputs/CAS,
matched UpdateID, explicit counterpart attestation and admission locks. No summed-fight overall,
mixed source, silent legacy fallback or activation from SourceRouting.Enabled alone.
S6-OPS01/PERF01/CAP01 and both uncertain publications remain untouched. S8B accepted smoke/50-case/
actual-restore evidence stays distinct from offline runner history, S8A six-script evidence and
S8C execution/operator evidence. S8C seven local checks PASS is not live Discord acceptance.


### PR #85 review corrections â€” 2026-09-14

Current banners now reflect the implemented/open-PR checkpoint. Migration and fixture reject
non-table name conflicts explicitly before counting user tables for the absent/complete state.
The additional type_conflict fixture mode creates a synthetic conflicting view inside its
rollback transaction and requires the exact migration error without any new export table.
All five modes and 76 structural cases remain unexecuted; no SQL execution is authorized.


### PR #85 temporary-shape collation correction â€” 2026-09-14

Seven temporary reason/JSON columns now explicitly use COLLATE DATABASE_DEFAULT so their
expected catalog shape matches permanent columns inheriting the application database default,
even when tempdb differs. Explicit BIN2 identity columns and permanent schemas are unchanged.
Static regression checks compare every temporary character column with its permanent counterpart.
Before deployment, separately authorize the existing install/constraints fixture modes against
a new disposable database with collation different from tempdb, recording both collations.
That SQL execution remains pending; parser/static checks are not runtime collation evidence.

## S10A compilation-boundary correction â€” 2026-09-14

The first approved disposable run retained the checksum backup, successful actual restore,
and 76-case cross-collation install result. Partial-schema validation stopped with SQL Server
error 207 (`IntentID`): the static installation index was bound before the partial-table guard.
The permanent six-table DDL now runs as one constant `sys.sp_executesql` batch only after
prerequisite, object-type and completeness guards pass. Decoded DDL is unchanged; transaction,
applock, exact rerun checks and strict error 51000 fixture expectations remain intact.

The operator approved this fix and continuation on the existing
`K98_S10A_Disposable_20260914_validation` and `_restore` databases on `9SX2VF4\K98DEV`.
Both currently retain the identical 19-table empty prerequisite baseline. A new pinned receipt
will preserve the original failed-run evidence and reuse its backup/actual-restore proof;
no database recreation, prerequisite rerun, backup overwrite or restore rerun is planned.
Run install, partial, type_conflict, direct apply/rerun, constraints and drift after review.
PR #85 remains unmerged. No production, provider, Discord or bot-machine action is included.

## S10A corrected compilation validation result — 2026-09-14

Fix commit `b8e19f8f03683eec0d6c2563d732fb5303ba04dd` passed 87 static parse inputs
and exact decoded-DDL/guard/verification parity. Changes review, Deep off, scan
`0a151f59-3c5d-4dfc-a5dc-81852a5782d0` completed with zero findings; target base
`0cdf9efcc6f625580a84f57449c5c103e74d8268`, content digest
`3f1701d12151a1b24203a15c0ff20d97af003d6decd54b224520028dc2447a7e`.

Approved continuation manifest SHA256
`705ce96f3ef40907c059a30c118dedfb8835e40a66adb7370bc31b1bd146c3b7`
ran against the two retained S10A disposable databases. Install passed all 76 cases;
partial and type_conflict passed their strict expected-error assertions. Direct migration
application returned successfully and committed six empty export tables. The subsequent
Python audit compared SQL case-insensitive ORDER BY output with Python case-sensitive sort
and stopped on the same exact 25 names in different order. This was a harness comparison
failure, not a second migration failure. No automatic runtime retry occurred.

The corrected read-only audit verifies 25 empty primary tables, 19 empty restored tables,
unchanged prerequisite metadata, enabled/trusted constraints, original database inventory
and backup presence. Receipt `s10a-continuation-01-receipt.json` SHA256
`f6c2032f99605225eef146853594f5135f355663a92c45966d5474328e0408f0`
and `s10a-continuation-01-stopped-audit.json` are retained beside the original execution
evidence under the existing `k98-s10a-implementation-20260914` temporary evidence directory.

A separate continuation02 harness normalizes both name lists before exact comparison;
offline regression rejects missing, extra and duplicate names. Only direct migration rerun,
constraints (76 cases), drift and final audit remain, requiring approval after this new stop.
No install/bootstrap/backup/restore will be repeated. Both original receipts remain immutable.
These sequential SQL checks do not establish worker concurrency or provider guarantees.
This evidence-only update needs no new security scan: migration and fixture bytes are unchanged.
PR #85 remains unmerged and no production or bot-machine action occurred.

## S10A disposable validation complete — 2026-09-14

The operator approved continuation02 and it passed at 16:39:18–16:39:22 UTC on
`9SX2VF4\K98DEV`, using retained `K98_S10A_Disposable_20260914_validation` and
`K98_S10A_Disposable_20260914_validation_restore`. Direct migration rerun preserved the
installed baseline; constraints passed all 76 cases; drift rejection passed; final baseline
and database inventory checks passed. Primary retains 25 empty tables, restore retains the
unchanged 19-table prerequisite baseline, with enabled/trusted constraints.

Together with the retained original backup/actual-restore proof and continuation01 install,
partial/type-conflict and direct-apply evidence, all five fixture modes and direct apply/rerun
are now complete. Install and constraints each passed the same 76 structural cases; these
are 76 unique cases, not 152 different cases. Cross-collation application/default-tempdb
behavior passed. No database recreation, bootstrap, backup overwrite or restore repeat occurred.

Executed SQL head: `dbaab083db57e400845f701b453fb4ff6d158dab`; migration/fixture unchanged
from security-reviewed fix `b8e19f8`. Manifest SHA256
`170493741737c899caeaebb98d8e0e93f00d54ba4e3d0347bc04420f2c4e7b50`.
Receipt `s10a-continuation-02-receipt.json`, SHA256
`71be461a0ab4db270c49664c97a8d89a376a3bbb958b65c165f3edd160254713`, retained under
`C:/Users/cwatt/AppData/Local/Temp/k98-s10a-implementation-20260914` with every prior receipt.
The manifest's pending-approval wording is its immutable preparation checkpoint; subsequent
operator approval and this executed receipt supersede it without rewriting evidence.

This is sequential disposable SQL evidence, not worker concurrency, provider truth or live
Discord acceptance. All retained operational gates and uncertain publications remain intact.
No production/bot-machine deployment, activation, merge or later-slice implementation occurred.
This update changes only delivery evidence; SQL source bytes remain unchanged, so the existing
Changes security review applies and a precise documentation-only skip covers this delta.
