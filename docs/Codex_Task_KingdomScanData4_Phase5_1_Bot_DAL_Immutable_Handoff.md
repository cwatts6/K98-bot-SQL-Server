# Codex Task Pack — KingdomScanData4 Phase 5.1 Bot, DAL and Immutable Handoff

> 2026-08-16 status: the real-token ACL evidence failed after proving that the bot could replace
> and rename the claimed file. The SQL stop rule in this pack was triggered. The operator then
> separately authorized the SQL and bot remediation in
> `Codex_Task_KingdomScanData4_Phase5_1_Immutable_Handoff_Remediation.md`. Phase 5.1 and production
> PR #539 remain open until that remediation passes.

## 1. Task Header

- Task name: `KingdomScanData4 Phase 5.1 — bot, DAL and immutable file handoff`
- Date: `2026-07-28`
- Owner/context: KingdomScanData4 performance-remediation programme, after Phase 5.0 SQL closure
- Task type: refactor and security-finding remediation
- One-pass approved: no; complete audit, architecture and implementation-plan checkpoints before
  changing the bot repository
- Target repository: `C:\discord_file_downloader`
- SQL source of truth: `C:\K98-bot-SQL-Server`

## 2. Required Reading

Read these bot-repository instructions before implementation. The names below are resolved in the
bot repository, not as paths in this SQL repository:

1. `AGENTS.md`
2. `README-DEV.md`
3. reference-documentation `README.md`
4. `K98 Bot - Project Engineering Standards.md`
5. `K98 Bot - Coding Execution Guidelines.md`
6. `K98 Bot - Testing Standards.md`
7. `K98 Bot - Skills & Refactor Triggers.md`
8. `K98 Bot - Deferred Optimisation Framework.md`
9. `weekly_activity_importer.md`
10. `Promotion Guide.md`

Read these SQL-repository handoff documents:

1. `performance_remediation/kingdomscandata4/phase5/README.md`
2. `performance_remediation/kingdomscandata4/phase5/immutable_file_protocol.md`
3. `performance_remediation/kingdomscandata4/phase1/bot_dal_contract_map.md`
4. `docs/Codex_Task_KingdomScanData4_Phases3_5.md`
5. `docs/SQL_DATA_MIGRATION_GUARDRAILS.md`

Validate all schema, stored-procedure and filesystem assumptions against the accepted Phase 5.0
SQL definitions. Do not infer SQL contracts from bot code.

## 3. Objective

Complete the bot half of the immutable KingdomScanData4 import protocol and remove only the DAL
conversions made redundant by the corrected SQL schema. Preserve every public response, import,
ordering, null, fallback and output-shape contract while closing the mutable-path finding family
with real-token NTFS evidence.

## 4. Background

Phase 5.0 is closed on the SQL-repository boundary. Its isolated rehearsal passed forward
migration, verification, normal/duplicate/recovery protocol smokes, exact rollback, clean
reapply and final verification. Final SQL Changes scan
`099379cd-119b-4402-8ecb-cf2e1c105f40` reported zero findings.

Successful rehearsal evidence:

`C:\discord_file_downloader\downloads_test_phase5_rehearsal\evidence\phase5_0_20260728T160735090Z`

Phase 5.0 deliberately leaves one cross-repository condition open: prove that the real bot
Windows token cannot overwrite, replace or modify an object after SQL claims it, while the SQL
Server identity can still hash and move that object. Production has not been changed.

The two stable findings form one root-cause family and close together:

- `csf_1a1c440452b02cdb787fa7c3`: source hash and `BULK INSERT` can observe different bytes.
- `csf_3cb54318733d3a216dd91e9b`: source hash and archive `MOVE` can observe different bytes.

## 5. Scope

### In Scope

- Publish each completed stats CSV atomically under a unique name matching
  `^stats_[0-9a-f]{32}\.ready\.csv$`.
- Pass that exact completed filename to Phase 5.0 `dbo.UPDATE_ALL2 @CompletedFileName`.
- Keep Ready, Claimed and Archive directories on one NTFS volume and prove effective ACLs under
  the real bot and SQL Server Windows identities.
- Update the four approved SQL-facing bot paths and their focused tests.
- Add a stats-alert DAL for SQL currently embedded in `embed_offseason_stats.py`.
- Run source-unchanged contract smokes for the four explicitly frozen consumers.
- Retain deterministic failure, retry, duplicate, cancellation and recovery behavior.
- Produce bot-repository Changes-review evidence against the final branch diff.

### Out of Scope

- Any Phase 5.0 SQL migration or stored-procedure change.
- Production deployment, production grants, service restart or Phase 5.2 promotion.
- Public command, option, permission, embed-layout or upload-name changes.
- Broad cleanup of unrelated direct SQL, logging, tests or services.
- Closure of the stable findings without the real-token ACL and end-to-end protocol evidence.

If the accepted SQL contract proves insufficient, stop. Record the exact mismatch and coordinate
a separate SQL-repository change and security decision; do not silently amend SQL from this bot
slice.

## 6. Codex Skills To Use

| Skill | Decision | Notes |
|---|---|---|
| `k98-architecture-scope` | use | Confirm the producer/service/DAL boundaries, filesystem ownership, SQL dependency and approval checkpoints before implementation. |
| `k98-discord-command-feature` | not applicable | No command, interaction, view, modal, option, registration or permission change is approved. |
| `k98-sql-validation` | use | Validate every DAL expression and the `@CompletedFileName` contract against the Phase 5.0 SQL repo. |
| `k98-test-selection` | use | Select focused contract tests plus the required repository gates and record any justified skip. |
| `k98-deferred-optimisation-capture` | use if triggered | Capture unrelated non-security debt discovered during audit; do not broaden this slice. |
| `k98-pr-review` | use | Perform the final bot PR merge-readiness review after tests and security evidence. |
| `k98-promotion-check` | not applicable during implementation | Required later for Phase 5.2; this task does not authorize promotion or deployment. |
| `k98-security-review-routing` | use | Bot: final diff-focused Changes review with Deep Off. SQL: documented skip unless SQL changes unexpectedly become necessary. |

### Security Review Decision

| Repository | Decision | Target | Expected setup / execution | Evidence |
|---|---|---|---|---|
| Bot | Changes review | Phase 5.1 bot base commit through final bot head, including all runtime, test and operational-script changes | Changes + Deep Off | Pending final scan; validate both stable finding IDs and retain the scan ID/snapshot with the PR |
| SQL | documented skip | Accepted Phase 5.0 SQL commit and this documentation-only handoff | Not applicable | No Phase 5.1 SQL runtime, configuration, permission, deployment or persistence change is authorized; record the frozen Phase 5.0 commit |

A standard or deep codebase audit is not authorized by this task pack.

## 7. Mandatory Workflow

1. Audit the target files, callers, tests and existing publication/staging helpers; stop for
   approval.
2. Record the exact bot base commit, Phase 5.0 SQL commit and provisional security targets.
3. Complete architecture and SQL-contract validation; stop for approval.
4. Present the implementation plan, ACL design and test selection; stop for approval.
5. Implement only after approval.
6. Run focused and repository-wide validation.
7. Capture real-token filesystem and end-to-end SQL evidence on an isolated target.
8. Run the final bot Changes review with Deep Off, then complete `k98-pr-review`.
9. Open a separate bot PR. Do not deploy it.

## 8. Audit and Architecture Requirements

Map and verify:

- stats upload entry points, fallback queue routing and audit metadata;
- CSV materialization, private staging and publication ownership;
- `stats_module.py` orchestration and cancellation/failure cleanup;
- `update_all2_log_manager.py` stored-procedure execution and result-set parsing;
- direct SQL ownership in each approved path;
- Ready/Claimed/Archive volume identity, ACL inheritance and service identities;
- restart behavior between write, close, publish, claim, import, receipt and archive;
- logging sufficient to correlate completed filename, claim, digest and SQL result without
  leaking secrets;
- existing helpers in `services/fallback_upload_staging_service.py` before adding a new staging
  abstraction.

Architecture target:

```text
upload/fallback route
  -> fallback import service writes a private temporary CSV
  -> producer closes and atomically renames it to a unique Ready identity
  -> stats orchestration passes that exact basename
  -> UPDATE_ALL2 wrapper calls dbo.UPDATE_ALL2 @CompletedFileName
  -> SQL claims, hashes, imports, receipts and archives the same identity
```

Commands, Discord views and embed renderers remain free of newly introduced SQL. Touched
offseason queries move behind a dedicated `stats_alerts` DAL.

## 9. Likely Files

### Review

- `stats_module.py`
- `services/fallback_import_service.py`
- `services/fallback_upload_staging_service.py`
- `update_all2_log_manager.py`
- `stats/dal/fallback_import_dal.py`
- `kvk_state.py`
- `kvk/dal/kvk_history_dal.py`
- `leadership_player_review/dal.py`
- the owning upload routes, audit services and focused tests

### Modify

- `player_self_service/accounts_dal.py`
- `player_self_service/governor_dashboard_dal.py`
- `weekly_activity_importer.py`
- `embed_offseason_stats.py`
- `stats_module.py`
- `services/fallback_import_service.py`
- `update_all2_log_manager.py`
- focused tests named in Section 11

### Create

- a focused DAL module under `stats_alerts/` using the repository's established naming pattern;
- focused DAL tests;
- an isolated ACL/protocol evidence runner or operator script if an existing operational script
  cannot produce deterministic, receipt-backed proof.

Do not assume every likely file must change. Keep the final manifest evidence-driven.

## 10. Implementation Requirements

### 10.1 Immutable publication and SQL handoff

1. Generate a cryptographically unpredictable 32-character lowercase hexadecimal work identity.
2. Write the CSV to a private temporary path that is not discoverable as Ready.
3. Flush and close the file before publication.
4. Atomically rename on the same NTFS volume to a name matching
   `Import_Ready\stats_[0-9a-f]{32}.ready.csv`; never copy into the final name.
5. Refuse overwrite/collision. A retry receives a new completed identity unless it is explicitly
   reconciling an already published object.
6. Pass only the exact basename to
   `dbo.UPDATE_ALL2 @param1=?, @param2=?, @CompletedFileName=?`.
7. Do not move, rename, delete or archive a file after SQL has claimed it. SQL owns Claimed and
   Archive transitions.
8. Preserve the original user upload filename and source metadata in the audit trail; do not use
   the public upload name as the work identity.
9. Log the completed identity and state transition at each boundary without logging credentials.
10. Make cleanup state-aware: private temporary files may be removed by their owner; published,
    claimed and archived objects require protocol reconciliation.

### 10.2 Approved DAL changes

`player_self_service/accounts_dal.py`:

- use direct `bigint` `GovernorID` selection, partition and join expressions;
- remove only integer conversions proven redundant by the final schema;
- preserve the exact 22-column row shape, null handling, ascending governor order, account-slot
  remap and five-requested-ID behavior.

`player_self_service/governor_dashboard_dal.py`:

- replace `s.GovernorID = CONVERT(FLOAT, ?)` with the schema-correct `bigint` predicate;
- remove only conversions proven redundant by the final schema;
- preserve the exact 19-column one-row shape, present/absent behavior, freshness and latest-row
  precedence.

`weekly_activity_importer.py`:

- select and compare schema-native `bigint` governors directly;
- remove the obsolete `CONVERT(nvarchar(255), scan.Alliance)` compensation;
- preserve blank-alliance normalization, date boundary, allied-cohort and completion-state
  semantics.

`embed_offseason_stats.py`:

- move touched direct SQL into the new stats-alert DAL;
- remove only redundant `Power AS bigint` casts;
- preserve daily and weekly totals, limit and ordering rules, fallback behavior and all six
  leaderboard contracts.

### 10.3 Source-unchanged consumers

Do not change these paths unless audit proves a contract defect and the operator separately
approves the expansion:

- `kvk_state.py`
- `kvk/dal/kvk_history_dal.py`
- `stats/dal/fallback_import_dal.py`
- `leadership_player_review/dal.py`

Their mapped contract smokes remain mandatory.

### 10.4 ACL and identity proof

Retain:

- the resolved Ready, Claimed and Archive absolute paths and volume serial/identity;
- effective `icacls` output for all three directories;
- the real bot service identity and SQL Server service identity used by the test;
- positive bot proof: create private temporary file and atomically publish to Ready;
- negative bot proof after SQL claim: overwrite, replacement, rename, delete and in-place
  modification are denied;
- positive SQL proof: SQL can claim, hash, bulk-read and move the exact object;
- source and archive digest equality plus the matching claim/receipt rows;
- timestamps, target database, exact bot commit and exact SQL commit.

Use an isolated database and isolated filesystem root. Never weaken production ACLs to make the
test pass.

## 11. Testing Requirements

Update or add focused coverage for:

- `tests/test_player_self_service_accounts_dal.py`
- `tests/test_governor_dashboard_dal.py`
- `tests/test_weekly_activity_importer.py`
- `tests/test_weekly_activity_upload_route.py`
- `tests/test_weekly_activity_import_audit_service.py`
- `tests/test_stats_module.py`
- `tests/test_update_all2_log_manager.py`
- `tests/test_fallback_upload_staging_service.py`
- the new stats-alert DAL and the owning offseason embed smoke

Required scenarios:

- successful unique atomic publication and exact `@CompletedFileName` binding;
- publication collision refusal;
- private-write failure and rename failure without a false Ready object;
- SQL success, SQL controlled failure, cancellation and restart after publication;
- duplicate content under a different completed name;
- duplicate invocation of the same completed name;
- invalid file followed by corrected content under a new name;
- bot-denied mutation after claim and SQL-positive hash/move;
- digest equality between claimed source and archive;
- exact accounts/governor-dashboard row shapes, ordering, nulls and absence cases;
- weekly allied-cohort, blank-alliance, date and completion semantics;
- daily/weekly offseason totals, ordering, limits, fallbacks and six leaderboards;
- all source-unchanged contract-map smokes.

Run test selection first, then at minimum:

```powershell
Set-Location C:\discord_file_downloader

.\.venv\Scripts\python.exe scripts\validate_architecture_boundaries.py
.\.venv\Scripts\python.exe scripts\validate_deferred_items.py
.\.venv\Scripts\python.exe scripts\select_tests.py
.\.venv\Scripts\python.exe scripts\validate_codex_security_routing.py
.\.venv\Scripts\python.exe -m pytest -q `
  tests/test_player_self_service_accounts_dal.py `
  tests/test_governor_dashboard_dal.py `
  tests/test_weekly_activity_importer.py `
  tests/test_weekly_activity_upload_route.py `
  tests/test_weekly_activity_import_audit_service.py `
  tests/test_stats_module.py `
  tests/test_update_all2_log_manager.py `
  tests/test_fallback_upload_staging_service.py
.\.venv\Scripts\python.exe -m pre_commit run -a
.\.venv\Scripts\python.exe -m pytest -q tests
.\.venv\Scripts\python.exe scripts\smoke_imports.py
.\.venv\Scripts\python.exe scripts\validate_command_registration.py
```

Record whether pytest changed any operational logs and restore only test-created artifacts using
the repository's approved procedure.

## 12. Refactor Decisions

| Issue | Decision | Reason |
|---|---|---|
| Existing private unique upload staging | reuse or extend | Audit `fallback_upload_staging_service.py` before creating a parallel helper. |
| Direct SQL in touched offseason embed module | fix now | This approved path must move behind a stats-alert DAL. |
| Unrelated direct SQL or duplicate helpers | defer | Capture structurally unless required for this slice's correctness. |
| Public command or embed redesign | not applicable | No user-facing redesign is approved. |
| SQL contract change | stop | Phase 5.0 is frozen; coordinate a separate SQL change if a defect is proven. |

Security findings are not deferred optimisations. Keep the two stable findings in the security
workflow until the ACL and combined protocol proof is accepted.

## 13. Acceptance Criteria

- [ ] Exact bot base/head and accepted Phase 5.0 SQL commit are recorded.
- [ ] Each final CSV is closed and atomically published under a unique canonical Ready name.
- [ ] The exact basename reaches `dbo.UPDATE_ALL2 @CompletedFileName`.
- [ ] The bot does not mutate or archive an object after SQL claim.
- [ ] Real-token ACL evidence proves the bot-negative and SQL-positive boundary.
- [ ] Ready, Claimed and Archive paths are on the same NTFS volume.
- [ ] Source/archive digests and claim/receipt identities match.
- [ ] Failure, retry, duplicate, cancellation and restart scenarios are deterministic.
- [ ] All four approved DAL paths preserve their exact behavioral contracts.
- [ ] All four source-unchanged contract smokes pass.
- [ ] No command surface or public upload contract changed.
- [ ] Architecture, deferred-item, test-selection, routing, pre-commit, full pytest, smoke-import
      and command-registration gates pass or carry an evidence-based skip.
- [ ] Final bot Changes review uses the intended base/head with Deep Off.
- [ ] Both stable mutable-path findings are explicitly validated against the final evidence.
- [ ] Final `k98-pr-review` reports no merge blocker.
- [ ] A separate ready-for-review bot PR is created; production remains untouched.

## 14. Required Delivery Output

1. Summary
2. Exact bot and SQL commits
3. File manifest, split into new and modified files
4. SQL contracts consumed; state explicitly that no SQL changed
5. Helpers reused
6. Refactor/deferred findings
7. Focused and full test results
8. ACL/protocol receipt and evidence paths
9. Security routing, scan ID/snapshot and stable-finding disposition
10. Bot PR URL
11. Phase 5.2 prerequisites and rollback notes

## 15. PR Summary Template

```md
## Summary

- Complete the Phase 5.1 bot/DAL half of the immutable KingdomScanData4 file handoff.
- Preserve the approved DAL, import, output and source-unchanged contracts.

## Changes

- Publish a closed CSV atomically under a unique canonical Ready identity.
- Pass the exact completed filename to the accepted Phase 5.0 SQL contract.
- Apply the four approved DAL cleanups and move touched offseason SQL to a DAL.

## Tests

- [focused tests and results]
- [repository gates and full pytest result]
- [isolated ACL/protocol rehearsal receipt]

## Security Review

- Decision: Changes review
- Repository / target: bot `[base]..[head]`
- Expected setup / execution: Changes + Deep Off
- Evidence: [scan ID, snapshot, stable finding results and ACL receipt]
- SQL decision: documented skip; accepted Phase 5.0 commit `[commit]` was unchanged

## Deferred Optimisations

- [none, or structured non-security items]

## Risk / Rollback

- Production was not changed. Revert the bot commit/PR if required; do not roll back or deploy SQL
  outside the separate Phase 5.2 release plan.
```

## 16. Phase 5.2 Handoff

Phase 5.1 completion is not production authorization. Phase 5.2 must freeze the exact accepted SQL
and bot commits, run the combined fresh-restore rehearsal for Phases 2 through 5.1, validate
promotion order and rollback, then request a separate production go/no-go.
