# SQL Migrations

> S8B closeout, 2026-09-13: SQL #81 and Bot production #581 are merged and locally pulled;
> S8B is complete and operator smoke accepted. No bot-machine pull or fresh post-merge SQL run.
> The approved S8B disposable packet passed backup/actual restore, preview/apply/rerun and 50
> SQL cases at its recorded hashes. Later runner/history support below has offline tests only.
> See [SQL delivery log](../docs/SQL_DELIVERY_LOG.md) for exact merge and evidence distinctions.
> S8C intake/admin UX is next for initial scope. This README status edit and the delivery-log
> closeout append must accompany a later separate SQL PR or have exact merged-content proof;
> neither belongs in the Bot PR. Existing execution guardrails remain unchanged.

This folder is the deployable source for intentional SQL changes.

Schema snapshots in `sql_schema/` are generated reference material. Do not deploy from
snapshots directly unless an approved emergency recovery plan requires it.

Notable deployed SQL milestones that need cross-repo closeout context may also be recorded in
`docs/SQL_DELIVERY_LOG.md`. That log is informational; migration files and
`dbo.SchemaMigrationHistory` remain the deployment source of truth.

## Naming

Use sortable migration names:

```text
YYYYMMDD_NNN_short_description.sql
```

Example:

```text
20260602_001_add_schema_migration_history.sql
```

Rules:

- Date is the migration creation date.
- `NNN` increments per day.
- Description uses lowercase snake case.
- The migration ID is the filename without `.sql`.
- Never rename a migration after it has been merged.

## Header

Every migration must start with this metadata block:

```sql
/*
MigrationId: 20260602_001_add_schema_migration_history
Purpose: Add SQL migration tracking table
Author: cwatts
CreatedUtc: 2026-06-02
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: N/A
PostValidationQuery: N/A
RelatedBotPR:
RelatedSQLPR:
*/
```

## Rollback

Rollback is explicit, not assumed.

- `Included`: a matching script exists in `migrations/rollback/`.
- `Manual`: rollback notes are in the migration or release notes.
- `Forward Fix Only`: do not roll back; correct the issue with a new migration.
- `Not Possible`: recovery requires restore from backup or bespoke manual recovery.

When `Rollback: Included`, set `RollbackScript:` to:

```text
migrations/rollback/YYYYMMDD_NNN_short_description_rollback.sql
```

The rollback file must include a `RollbackForMigrationId:` header and be reviewed with the forward
migration. Do not create a rollback file when it would imply safety that does not exist.

## Data Safety

Use `DataChange: Yes` when a migration updates, deletes, truncates, backfills, transforms, or
otherwise changes existing data. Schema-only changes can normally use `DataChange: No`, but schema
changes with material data risk should still include a safety plan.

`DataSafetyPlan:` values:

- `Not Required`: no existing data is changed and no material data risk is expected.
- `Required`: the PR or migration notes must include the data safety plan before deployment.
- `Included`: the migration header/comments include the preview, transaction, validation, and
  rollback or forward-fix notes.

For high-risk data changes, include:

- expected row-count range
- pre-validation query
- post-validation query
- backup confirmation
- transaction and locking notes
- rollback or forward-fix plan

See `docs/SQL_DATA_MIGRATION_GUARDRAILS.md`.

The deploy runner prevents repeat execution through `dbo.SchemaMigrationHistory`; individual
migrations should still be idempotent where that is genuinely safe.


## Historical S8B authoring checkpoint — 2026-09-13 (before disposable execution)

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
for the reviewed same-session runner path documented below. Ordinary pending deployment stops
before applying migrations if S8B inputs are missing. No predecessor is rerun implicitly.
Deploy the amendment before the revised S8B writer; older inserts omit the required column
and fail closed. Retained no-fight fight-period updates require forward fixes, not a downgrade.
Disposable validation must prove preview/apply/rerun, rollback, FK/check rejection and retained
history identity before deployment. No SQL connection or execution is claimed by this entry.


## S8B reviewed runner inputs — PR #81 review follow-up

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

## S8C merged delivery and next steps — 2026-09-13

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
11−10/12−10/13−10 then authorized 14−10, later 17/18 assignment, no-fight, independent overall,
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
