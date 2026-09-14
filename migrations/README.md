# SQL Migrations

> Current KVK status, 2026-09-14: S9B repository delivery is complete. SQL #84,
> Bot mirror #277 and production #584 are merged and locally pulled; the bot machine is unchanged.
> S10A Shared Export Coordination SQL Foundation is implemented and published in
> [SQL PR #85](https://github.com/cwatts6/K98-bot-SQL-Server/pull/85), pending review and merge.
> Approved disposable validation passed backup/actual restore, install (76 cases), partial
> and type-conflict rejection, and direct migration application. A Python audit ordering
> error then stopped the continuation; direct rerun, constraints and drift remain pending.
> Both delivery-log and migration-README updates are included in that S10A SQL
> implementation PR. Bot handoff documentation stays in Bot for the next Bot implementation PR,
> S10B; no standalone documentation PR. Earlier status/publication checkpoints are historical.
> No SQL execution, bot-machine pull, deployment or activation is authorized by this update.



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


## Historical S8B authoring checkpoint â€” 2026-09-13 (before disposable execution)

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


## S8B reviewed runner inputs â€” PR #81 review follow-up

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
