# Codex Task — KingdomScanData4 Phase 5.2 Combined Release Gate

**Prepared:** 2026-08-16

**Status refreshed:** 2026-08-17

**SQL repository:** `C:\K98-bot-SQL-Server`

**Bot mirror repository:** `C:\discord_file_downloader` / `K98-bot-mirror`

**Production bot repository:** `K98-bot`

**Execution model:** checkpointed, cross-repository release rehearsal

**Production authorization:** **No** — this pack ends at a production go/no-go request

## 1. Operator Request and Document Boundary

The operator requested a Phase 5.2 task pack after the initial Phase 5.1 functional testing. The
first real-token ACL evidence failed and triggered a separately authorized remediation. That
failure remains historical evidence. The replacement 2026-08-17 run passed and is the accepted
Phase 5.1 evidence input recorded below. This document defines the next task. References listed
below supply engineering and operational constraints; they do not independently authorize a
merge, production promotion, SQL deployment, bot restart, data change, or rollback.

Phase 5.2 is a combined release gate, not a sixth implementation phase. Its purpose is to bind the
accepted SQL and bot revisions, rehearse the complete Phases 2–5.1 release from a fresh restore,
prove the supported rollback/reapply paths, and produce evidence for a separate production
go/no-go decision.

## 2. Current Known State

Record and revalidate these values at task start; do not silently substitute newer revisions.

| Item | Current value | Gate state |
|---|---|---|
| SQL Phase 5.2 candidate | `368292fe1f291ff20765f3ecb6702a119fb78a20` | current SQL `origin/main`; includes the accepted Phase 5.1 ACL remediation and subsequent reviewed fixes; revalidate at Checkpoint A |
| Phase 5.1 ACL migration | `20260816_001_phase5_1_claim_acl_hardening` | merged; the successful rehearsal history recorded introducing commit `4d9312a530f2`; pending-migration count was zero and must be revalidated |
| Phase 5.1 bot PR | `K98-bot-mirror#232`, `46e5a9cd58a4f475557904226656b2b8cc39dbb2..03ea272a9480bbc2cc360bfd574e3b5c9205f438` | open and frozen at handoff; 29 changed files, clean/mergeable, no unresolved review threads, and no GitHub checks reported; revalidate at Checkpoint A |
| Bot base commit | `46e5a9cd58a4f475557904226656b2b8cc39dbb2` | frozen review base |
| Production PR | `K98-bot#539`, branch `prod/kingdomscandata4-phase5-1-bot`, head `237eaa585be29b68d8ca0678f5f9b14e54327950` | open and frozen; quality passed, GitHub scan failed; the failed scan is a Checkpoint A gate and must not be dismissed without evidence |
| Phase 5.1 ACL/protocol evidence | `phase5_1_20260817T155508137Z` under the retained operator evidence root | accepted PASS, evidence version 2; receipt SHA-256 `C9319B9980AE270C0F7C8D2891012E538951D052D206114C9F9828851279EDCF`; transcript SHA-256 `91A6C281230B441B1111417366D79D1A532B8296E10017BB38BE63B288236B4C` |
| Completed immutable file | `stats_2ba4db28b3a2425e8032f5102ce4a79d.ready.csv` | Ready, claim, and archive SHA-256 all equal `B4355635986F5BF365AEADD3E7DA91F5A0ED5D65D33A976A726FFB125100A724`; claim and receipt are archived |
| Bot-machine branch state | PR #539 was temporarily run on MINI_AMD for evidence collection | unverified entry gate: MINI_AMD must be back on clean private `K98-bot/main`, equal to its `origin/main`, validated, and gracefully restarted before rehearsal |
| Stable finding `csf_1a1c440452b02cdb787fa7c3` | source hash versus `BULK INSERT` mutation window | receipt-backed closure accepted: the bot token was denied every claimed-file mutation and the source/claim/archive digests match |
| Stable finding `csf_3cb54318733d3a216dd91e9b` | source hash versus archive `MOVE` mutation window | receipt-backed closure accepted: SQL retained ownership and completed the digest-bound archive transition |
| Bot Changes evidence | remediation-delta scans `9bcfac4d-37de-4b93-b314-0af15fb42023` and `7bf41033-74d7-41ab-9726-6daa2f4a1ee7` | both reported no findings; retain and verify the original full-branch scan plus these deltas cover the exact final range, or run one final exact-range Changes scan with Deep off |
| Production SQL and bot | must be probed at go/no-go time | no change authorized by this pack |

The current values are accepted handoff inputs where stated, not substitutes for live Checkpoint A
revalidation. If PR #232 changes, rerun every head-bound review and test required by Phase 5.1
before freezing the replacement head.

### 2026-08-17 documentation refresh record

SQL PR #64 was rebased from stale base `2e0f228f399bcc7b8bd3d6a758b059466c0474ac` onto SQL
`origin/main` `368292fe1f291ff20765f3ecb6702a119fb78a20`. The refresh is limited to the six
status documents named by the operator. It changes no executable SQL, migration, rollback,
deployment script, bot code, bot test, runtime configuration, permission, data-access,
dependency, input, network, filesystem, or persistence behavior. Codex Security is therefore
skipped for this documentation-only diff. `docs/SQL_DELIVERY_LOG.md` remains unchanged.

## 3. Required Reading

### SQL and programme controls

- `docs/Codex_Task_KingdomScanData4_Phases3_5.md`
- `docs/Codex_Task_KingdomScanData4_Phase5_1_Bot_DAL_Immutable_Handoff.md`
- `docs/Codex_Task_KingdomScanData4_Phase5_1_Immutable_Handoff_Remediation.md`; merged through SQL
  PR #65 and included in current SQL `main`, subject to Checkpoint A revision/history validation
- `performance_remediation/kingdomscandata4/README.md`
- `performance_remediation/kingdomscandata4/phase2/README.md`
- `performance_remediation/kingdomscandata4/phase3/README.md`
- `performance_remediation/kingdomscandata4/phase4/README.md`
- `performance_remediation/kingdomscandata4/phase5/README.md`
- `performance_remediation/kingdomscandata4/phase5/immutable_file_protocol.md`
- `performance_remediation/kingdomscandata4/release/README.md`
- `docs/SQL_DATA_MIGRATION_GUARDRAILS.md`
- `docs/SQL_PROMOTION_GUIDE.md`
- `docs/SQL_RELEASE_CHECKLIST.md`
- `docs/SQL_DELIVERY_LOG.md` — read-only until successful production deployment

### Bot engineering and promotion controls

The names below are resolved in the bot repository, not as paths in this SQL repository:

- `AGENTS.md`
- `README-DEV.md`
- reference-documentation `README.md`
- `K98 Bot - Project Engineering Standards.md`
- `K98 Bot - Coding Execution Guidelines.md`
- `K98 Bot - Testing Standards.md`
- `K98 Bot - Skills & Refactor Triggers.md`
- `K98 Bot - Deferred Optimisation Framework.md`
- `SECURITY.md`
- `runbook_devops.md`
- `Promotion Guide.md`

## 4. Objective

Produce one combined, machine-readable acceptance receipt proving that:

1. the exact accepted SQL and bot contents are identified and reproducible;
2. the full Phase 2–5.1 forward sequence succeeds from an approved fresh restore;
3. Phase 3/4/5 SQL contracts and the Phase 5.1 immutable producer/DAL contract remain aligned;
4. early rollback restores the approved pre-release state and leaves Phase 2 retryable;
5. a clean reapply and guarded Phase 2 finalization succeed;
6. the matching bot revision passes end-to-end immutable import, restart, failure, duplicate,
   cancellation, workload, source-unchanged, and operational smoke checks;
7. the mirror-to-production bot patch is content-equivalent and based on `production/main`;
8. SQL-first deployment, bot-second deployment, rollback, monitoring, and stop conditions are ready
   for an explicit operator go/no-go.

## 5. Entry Gates

Do not begin the combined fresh-restore rehearsal until every item is satisfied.

- [ ] Phase 2, Phase 3, Phase 4, and Phase 5.0 closure receipts remain accepted.
- [ ] The separately authorized Phase 5.1 SQL ACL-remediation migration, rollback, preflight,
      verification, tests and Changes review are accepted at one exact SQL head.
- [ ] PR #232 still targets bot mirror `main` from the intended Phase 5.1 branch.
- [ ] The PR head is the exact tested commit; otherwise tests and review are refreshed.
- [ ] The real-token Phase 5.1 runner produced a retained `receipt.json` and transcript.
- [ ] Receipt evidence proves bot-negative and SQL-positive access on the isolated Ready, Claimed,
      and Archive paths, all on one NTFS volume.
- [ ] Source/archive digests and claim/receipt identities match for the canonical completed name.
- [ ] The retained original full-branch bot Changes review plus remediation-delta scans
      `9bcfac4d-37de-4b93-b314-0af15fb42023` and
      `7bf41033-74d7-41ab-9726-6daa2f4a1ee7` demonstrably cover exact range
      `46e5a9cd58a4f475557904226656b2b8cc39dbb2..03ea272a9480bbc2cc360bfd574e3b5c9205f438`.
      If they do not, run one final bot **Changes** review for that exact range with Deep off.
- [ ] Both stable finding IDs have explicit receipt-backed final dispositions.
- [ ] Final `k98-pr-review` reports no merge blocker.
- [ ] All actionable PR review threads are answered and resolved.
- [ ] PR #232 is accepted as ready to merge at the exact reviewed head and remains unchanged.
- [ ] The accepted source head is recorded; record the mirror merge commit later when the standard
      promotion sequence creates it.
- [ ] SQL and bot working trees are clean and all required commits exist on their expected remotes.
- [ ] Production PR #539 contains the accepted content-equivalent remediation or has been replaced
      by an explicitly recorded production PR.
- [ ] MINI_AMD is checked out to private production `main`, contains the merged production commit,
      passes deployment validation, and has completed a clean graceful restart. A PR branch or
      mirror branch on the bot machine blocks Phase 5.2.

### Checkpoint A — Phase 5.1 close and freeze

Stop and report if any entry item fails. Phase 5.2 planning may continue, but the combined rehearsal
and production promotion must not proceed.

## 6. Scope

### In scope

- Resolve and freeze exact SQL and bot commits, any existing merge commits, remotes, file manifests,
  and content digests.
- Run a fresh-restore combined rehearsal on an explicitly isolated database and filesystem root.
- Exercise the committed Phase 2–5.0 SQL scripts in their documented order.
- Add only the narrowly required guarded adapter/finalizer extension described by the existing
  combined-release README, with a separate reviewed SQL change if it is not already present.
- Run the Phase 5.1 bot revision against the rehearsed SQL contracts in an isolated bot runtime.
- Prove rollback before finalization, clean reapply, finalization, and post-finalization recovery
  decisions.
- Prepare and validate the patch-based bot production branch and production PR without deploying.
- Produce evidence and an explicit production go/no-go request.

### Out of scope

- Production SQL execution, grants, data changes, schema changes, database restore, bot restart, or
  deployment.
- Direct pushes of mirror history to the production bot repository.
- New command surfaces, UI behavior, SQL contracts, data semantics, performance redesign, or
  unrelated refactors.
- Weakening ACLs, mutexes, digest checks, finalizer guards, backup requirements, security gates, or
  rollback stop conditions to obtain a pass.
- Updating `docs/SQL_DELIVERY_LOG.md` before successful production deployment.
- Committing credentials, tokens, raw operator evidence, personal data, connection strings, or
  live filesystem ACL dumps to Git.

## 7. Required Skills and Review Routing

| Skill | Use |
|---|---|
| `k98-architecture-scope` | confirm affected repositories, finalizer boundary, operator checkpoints, and no feature expansion |
| `k98-sql-validation` | verify every migration, rollback, procedure, view, table, parameter, deployment order, and bot/DAL assumption against SQL source of truth |
| `k98-test-selection` | select focused, full, source-unchanged, security-negative, restart, workload, and operational validation |
| `k98-pr-review` | review any finalizer/release-tool change and both final SQL and bot candidate diffs for merge readiness |
| `k98-security-review-routing` | choose separate SQL and bot security decisions and preserve exact base/head evidence |
| `k98-promotion-check` | validate patch-based bot promotion, SQL-first order, deployment readiness, rollback, and runtime safety |
| `k98-deferred-optimisation-capture` | record unrelated cleanup without widening this release gate |

Security routing:

- Existing Phase 5.1 bot code retains its exact final Changes review and stable-finding evidence.
- Any later bot patch, promotion conflict resolution, config, script, or runtime change receives a
  new bot Changes review against its actual base/head.
- Any SQL finalizer adapter, migration, rollback, deployment script, or executable rehearsal change
  receives a separate SQL Changes review against the SQL repository base/head.
- A documentation-only task-pack diff receives a documented skip because it changes no executable
  behavior, permissions, data access, config, dependency, deployment execution, input, network,
  filesystem, or persistence behavior.
- Do not use Codebase or Deep scans as routine Phase 5.2 gates.

## 8. Exact Revision Freeze

Create a freeze manifest outside Git evidence storage and copy only non-sensitive identifiers into
the final task report. Record:

- SQL repository URL/remotes, branch, accepted source commit, rehearsal head, any applicable merge
  commit, clean status, and `git diff --name-status` from the reviewed base;
- bot mirror URL/remotes, PR number, base commit, accepted source head, later mirror merge commit
  when created, clean status, and changed-file manifest;
- production bot `main` base used for patch promotion, promoted branch head, and production PR;
- SHA-256 content digest for every executable changed file in both repositories;
- Phase 2 run ID and retained-table digests;
- final Phase 3/4/5 SQL module hashes and migration IDs;
- Phase 5.0 and Phase 5.1 receipt paths and hashes;
- final Changes scan IDs, snapshots, coverage, and finding dispositions;
- database identity, source backup identity, restore timestamp, SQL Server version, compatibility
  level, and isolated filesystem root;
- UTC start/end times and the identities/roles of the bot and SQL execution tokens, without
  recording credentials.

If any executable content changes after freezing, invalidate the affected freeze, rerun its tests
and Changes review, and issue a replacement manifest.

### Checkpoint B — exact inputs accepted

Present the freeze manifest, isolated targets, available capacity, backup/restore plan, test plan,
security-routing decisions, and rollback order. Continue only after operator approval.

## 9. Isolated Environment and Safety Controls

- Use an approved representative backup restored to a newly named non-production database. Do not
  use a database snapshot as the release rehearsal or production rollback mechanism.
- Never point rehearsal scripts at `ROK_TRACKER` or the live bot download root.
- Pin the expected server, database, bot commit, SQL commit, and isolated filesystem root in the
  rehearsal configuration and machine receipt.
- Confirm sufficient disk, log, tempdb, and backup capacity before applying Phase 2.
- Confirm backup readiness and the source backup chain even though the target is isolated.
- Stop or exclude every bot, import, scheduler, admin, SSMS, and ad-hoc write entry point to the
  isolated database before migration.
- Capture sessions, effective grants, database options, recovery model, compatibility level,
  migration history, and object hashes before changing the isolated database.
- Use Ready, Claimed, Archive, failure, and evidence directories on one NTFS volume with the
  approved inheritance and real-token access boundary.
- Store raw receipts and transcripts outside Git. Redact only derived task summaries, never the
  original evidence.

## 10. Combined Forward Rehearsal

Follow `performance_remediation/kingdomscandata4/release/README.md` as the authoritative sequence.
At minimum:

1. Restore the approved representative seed to the isolated database.
2. Run repository validation, backup readiness, capacity checks, preflight hashes, session/grant
   capture, and clean-revision checks.
3. Stop all write entry points to the isolated database.
4. Run Phase 2 production-shaped preflight, apply the Phase 2 migration, and run table, module,
   digest, DBCC, history, and retryability verification.
5. Apply Phase 3 migrations in documented order and run procedure, import, concurrency,
   authorization, archive-reconciliation, ambient-transaction, equivalence, and workload checks.
6. Apply `20260727_000_retire_vAllianceActivity_WeeklyCumulative`, then
   `20260727_001_phase4_view_type_alignment`; run Phase 4 view, consumer, plan, benchmark, and
   equivalence validation.
7. Apply the accepted Phase 5.0 SQL companion migration while writers remain stopped; run the file
   identity, claim, failure, retry, duplicate, receipt, archive, rollback-contract, and digest
   smokes.
8. Run the complete committed-import, Query Store, source-unchanged consumer, and representative
   workload matrix against the frozen SQL and stopped bot revisions.
9. Create a fresh combined pre-finalization receipt bound to the exact Phase 2 run ID, retained
   table digests, module hashes, migration history, SQL commit, bot commit, and validation receipts.

Flag any regression around or above 10 percent in median duration, CPU, reads, or import
throughput. Resolve it or retain a reviewed justification that a necessary correctness or safety
gain outweighs it.

### Checkpoint C — forward path accepted

Do not finalize Phase 2 or start the new bot until the operator accepts the combined
pre-finalization receipt.

## 11. Mandatory Early Rollback and Clean Reapply

The complete forward rehearsal in section 10 deliberately creates durable import receipts. Those
receipts make the Phase 3 and Phase 5.1 early rollback guards ineligible on that database. Preserve
its receipt and transcript, then restore the approved receipt-free seed into a newly named isolated
rollback database. Do not delete committed receipts or weaken rollback guards to reuse the forward
database.

On the fresh rollback database, keep all writers stopped and apply the accepted Phase 2–5.1
migrations without running committed imports, file claims, receipt-producing protocol smokes, or
other post-cutover writes. Prove this exact early failure path:

1. confirm that no Phase 3 import receipt and no Phase 5.1 ACL-hardening evidence exists;
2. roll back the Phase 5.1 ACL-hardening migration and the Phase 5.0 SQL companion file-protocol
   migration in their documented reverse order;
3. restore the four retained Phase 4 prior view definitions using
   `migrations/rollback/20260727_001_phase4_view_type_alignment_rollback.sql`;
4. leave the approved retired weekly-cumulative view retired because that migration is
   forward-fix-only;
5. restore the exact Phase 3 prior procedure/function definitions;
6. run the Phase 2 metadata-swap rollback;
7. rerun original-schema, module, digest, DBCC, session, and application compatibility smokes;
8. prove that only the old bot revision would be eligible to start;
9. record the rolled-back object state and every affected `dbo.SchemaMigrationHistory` row.

The Phase 3, Phase 4, Phase 5.0, and Phase 5.1 rollback scripts do not mark their deployment-history
rows as unapplied. Therefore `Deploy-SqlMigration.ps1` must not be used to reapply on this rolled-back
database: it would skip migrations whose history rows still say `Applied`. Preserve the rollback
evidence, restore the approved seed again into a third newly named isolated reapply database, and
repeat the complete section 10 forward path there. Do not hand-edit or delete migration-history
rows as a substitute for the fresh restore.

The finalizer must consume only the fresh combined receipt from that clean reapply while retaining
the exact run-ID, time, lock, table-digest, and no-drift controls. Never bypass or hand-edit the
finalizer evidence.

After finalization or any post-cutover write, metadata-swap rollback is forbidden. The only
permitted plans are a separately reviewed forward fix or the documented backup/log recovery
decision.

### Checkpoint D — rollback, reapply, and finalizer accepted

Record the forward, rollback, and clean-reapply database identities, their hashes, and every stop
condition. Continue only if rollback was faithful, reapply began from a fresh receipt-free restore,
and finalization used the accepted combined receipt.

## 12. Bot and Immutable-Handoff Rehearsal

Deploy or check out only the frozen bot content in an isolated runtime configured for the isolated
database and filesystem root. Keep the production bot and production database untouched.

Required proof:

- closed CSV publication is atomic and uniquely named;
- the exact canonical basename reaches `dbo.UPDATE_ALL2 @CompletedFileName`;
- SQL claims, hashes, bulk-imports, receipts, and archives the same immutable identity;
- the bot token cannot mutate or archive a claimed file and the SQL token can complete the
  approved operations;
- source and archive digests match and the claim/receipt rows match the published identity;
- success, failure, retry, duplicate, cancellation, timeout, restart-before-publish,
  restart-after-publish, restart-after-claim, and restart-after-receipt states are deterministic;
- fallback upload staging remains isolated per upload and processing remains serialized where
  required;
- all four approved DAL paths and all source-unchanged consumer contracts remain unchanged;
- no public command, upload, filename, output, order, null, trim, date, civilization, permission,
  or display contract changed;
- operational logs contain no secrets and no unexpected WARNING/ERROR pollution from tests;
- bot stop/start/singleton behavior and rollback to the old revision are rehearsed.

Run the bot repository's focused tests, full pytest, architecture, deferred-item, test-selection,
Codex Security routing, pre-commit, smoke-import, command-registration, and log-noise gates, or
record an evidence-based skip where the repository standards allow one.

## 13. Promotion Rehearsal

Use the bot repository's `Promotion Guide.md` for the mirror-to-production path and the SQL
promotion documents for SQL. The coordinated order is:

1. complete Phase 5.2 rehearsal and obtain both final PR-review verdicts;
2. if Phase 5.2 needs the guarded finalizer adapter or another executable SQL change, merge that
   complete SQL PR only when the coordinated release is scheduled; otherwise retain the accepted
   SQL `main` commit recorded in the freeze manifest;
3. verify only the intended migration IDs are pending on SQL `main`;
4. run `k98-promotion-check` before creating the production bot branch;
5. use `scripts/promote-to-production.ps1` to apply the bot file delta to a new branch based on
   `production/main`; never push mirror branch history directly to production;
6. verify the promoted patch is content-equivalent to the accepted mirror source head;
7. open and approve the production bot PR;
8. test the production-based branch on the bot machine before merge;
9. stop before merging either bot PR or deploying either repository and request the separate
   production go/no-go.

The planned production maintenance order, after a later explicit go/no-go, is SQL first and bot
second:

1. merge the unchanged accepted mirror PR and record its merge commit;
2. stop approved write entry points;
3. re-run fresh production preflight and backup readiness;
4. deploy and verify SQL from SQL `main`;
5. finalize only with the approved production receipt;
6. merge the production bot PR and deploy the content-equivalent bot revision from `K98-bot/main`;
7. run SQL, immutable-import, bot, command, log, migration-history, deployment-history, and drift
   smokes;
8. monitor and update `docs/SQL_DELIVERY_LOG.md` only after successful deployment.

## 14. Evidence Package

Create one Phase 5.2 evidence root outside Git. It must contain or reference:

- `freeze_manifest.json`;
- `combined_preflight.json`;
- `forward_receipt.json`;
- `rollback_receipt.json`;
- `reapply_receipt.json`;
- `finalizer_receipt.json`;
- `bot_immutable_handoff_receipt.json`;
- `promotion_equivalence_receipt.json`;
- validation transcripts and exit codes;
- SQL migration/deployment history extracts;
- module, file, table, source, and archive digests;
- Query Store/workload/benchmark summaries;
- final PR-review and promotion-check verdicts;
- separate SQL and bot security scan manifests, coverage, findings, IDs, snapshots, and stable
  finding dispositions;
- an evidence index with SHA-256 hashes for every retained artifact.

Each machine receipt must include a schema/version, UTC timestamps, server/database identity,
isolated root, exact commits, command or script identity, status, failed gate list, and child
artifact hashes. It must fail closed when required evidence is missing or revisions drift.

## 15. Acceptance Criteria

- [ ] All Phase 5.1 entry gates are closed and PR #232 is accepted as ready to merge at the frozen
      content without later drift.
- [ ] Exact SQL, bot mirror, bot production-base, and promoted commits are recorded.
- [ ] Fresh restore and preflight prove database identity, backups, capacity, sessions, grants,
      hashes, clean revisions, and isolated targets.
- [ ] Complete Phase 2–5.1 forward sequence passes in documented order.
- [ ] Phase 3/4/5 SQL contracts and bot/DAL consumers match the SQL source of truth.
- [ ] All source-unchanged and representative workload checks pass.
- [ ] Performance regressions at or above the programme threshold are resolved or explicitly
      justified and accepted.
- [ ] Pre-finalization rollback restores the approved state and leaves Phase 2 retryable.
- [ ] Clean reapply passes and the guarded finalizer consumes the exact combined receipt.
- [ ] Immutable publication, ACL boundary, identity, digest, receipt, archive, failure, retry,
      duplicate, cancellation, timeout, and restart evidence passes.
- [ ] Both stable mutable-path findings have explicit final accepted dispositions.
- [ ] Focused and full repository validation passes or carries an allowed evidence-based skip.
- [ ] Any executable SQL or bot change has its own exact-range Changes review with full coverage.
- [ ] Final `k98-pr-review` reports no blocker for each changed repository.
- [ ] `k98-promotion-check` reports the patch-based production branch, SQL-first order, rollback,
      config, and runtime plan ready.
- [ ] Production bot patch is based on `production/main` and content-equivalent to the accepted
      mirror revision.
- [ ] MINI_AMD has been restored from the temporary PR #539 test deployment to the merged private
      production `main` revision and its running PID/lock/startup evidence matches that commit.
- [ ] Combined evidence index and machine receipts are retained outside Git.
- [ ] Production repository `main`, production SQL data/schema and `docs/SQL_DELIVERY_LOG.md`
      remain untouched by this release-gate rehearsal; the temporary bot-machine PR test has been
      explicitly unwound to private production `main` before entry.
- [ ] A separate, explicit production go/no-go request is presented to the operator.

## 16. Required Delivery Output

1. Executive merge/release-gate verdict.
2. Exact SQL, bot mirror, any existing mirror merge, production base, promoted branch, and PR
   identifiers.
3. New/modified file manifests for each repository.
4. SQL migration, rollback, finalizer, procedure, view, table, and DAL contract map.
5. Fresh-restore identity and safety evidence.
6. Forward, rollback, reapply, finalizer, and bot immutable-handoff receipts.
7. Focused, full, source-unchanged, workload, performance, and operational test results.
8. Security routing, scan IDs/snapshots/coverage, and stable-finding dispositions.
9. Promotion equivalence, remotes, PRs, deployment order, monitoring, and rollback plan.
10. Deferred optimisations, clearly separated from security findings.
11. Exact remaining blockers, if any.
12. Explicit production go/no-go request; do not infer approval.

## 17. Stop Conditions

Stop immediately and preserve evidence if any of the following occurs:

- revision, migration, module, table, file, receipt, or promoted-patch digest drift;
- production server, database, filesystem root, branch, or bot process is selected accidentally;
- missing or stale backup evidence, insufficient capacity, unexpected sessions, or unknown grants;
- any unapproved writer remains active;
- Phase 2 run ID/finalizer guard mismatch or an attempt to bypass the guard;
- unexpected row-count, DBCC, migration-history, module, view, procedure, claim, receipt, archive,
  ACL, or source/archive digest result;
- rollback cannot restore the approved pre-finalization state or Phase 2 is not retryable;
- an executable change lacks the required exact-range review;
- a stable finding remains unresolved or its retained evidence cannot be verified;
- any secret, credential, personal data, or live evidence is about to enter Git;
- any step would require production change before the separate go/no-go.

Report the failed gate and safest recovery branch. Do not improvise destructive rollback or restore
under pressure.

## 18. Immediate Start Sequence

1. Refresh SQL PR #64 onto current SQL `origin/main`, update the six operator-named status
   documents, validate the documentation-only diff, update the PR, and stop for operator approval
   before merging it.
2. After separate approval and merge of PR #64, perform Checkpoint A only: revalidate every Phase
   5.1 entry gate, exact PR heads/comments/checks, MINI_AMD production-main state, retained original
   receipt/hashes, SQL migration/rollback/history state, test evidence, and security coverage.
3. Stop at Checkpoint A and report every blocker before creating or modifying a rehearsal
   database.
4. After operator approval, prepare Checkpoint B: propose the external evidence root and three
   newly named fresh-restore databases, identify the approved backup without restoring it, collect
   prerequisites, and present the exact freeze manifest, execution order, tests, security routing,
   stop conditions, and recovery paths.
5. Stop at Checkpoint B for separate operator approval before any restore or rehearsal-environment
   mutation.
6. After the eventual separate production go/no-go, follow the coordinated SQL-first and bot-second
   production sequence in this pack. No earlier checkpoint implies production authorization.
