# KingdomScanData4 Phases 3–5 delivery plan

Status updated 2026-08-17. Phases 1 and 2 are closed on the representative-copy evidence
boundary. Phase 3 implementation and representative-copy rehearsal are complete and frozen at
`62cb739`. The Phase 4 implementation package is authored on
`codex/kingdomscandata4-phase4`; its isolated forward/rollback/reapply,
equivalence, benchmark, actual-plan, mapped consumer, repository, and final
Changes gates passed on 2026-07-27. Phase 4 is closed. Phase 5.0 SQL closed on 2026-07-28 after
its isolated rehearsal, repository gates and final Changes review passed. Phase 5 now uses the
operator-facing 5.0 SQL, 5.1 bot/DAL, and 5.2 combined-release slices described below.
Production execution is not
authorized. This plan replaces task-list ordering that mixed Phase 2
acceptance with later coordinated-release work.

The first Phase 5.1 real-token ACL run failed: the bot replaced and renamed a claimed rehearsal
file because the same-volume move retained its writable Ready ACL. The original Phase 5.1 SQL stop
rule fired. The operator separately authorized migration
`20260816_001_phase5_1_claim_acl_hardening` and the matching bot remediation. The replacement
evidence run `phase5_1_20260817T155508137Z` passed and its receipt-backed stable-finding closure is
accepted. Phase 5.1 implementation/evidence is closed for Phase 5.2 entry review. Bot PR #232 and
production PR #539 remain open and frozen; MINI_AMD return-to-main, exact scan coverage, PR checks,
and all other live entry facts remain mandatory Checkpoint A gates.

## Authoritative order

| Order | Workstream | Entry condition | Exit condition |
| ---: | --- | --- | --- |
| 1 | Phase 3: procedures, import concurrency and downstream tables | Phase 2 package and rollback are stable | **Complete:** SQL mutex, atomic scan allocation, duplicate prevention, type alignment, equivalence, performance, rollback and final Changes review passed |
| 2 | Phase 4: views and consumers | **Complete:** frozen Phase 3 SQL contracts consumed | **Complete:** every changed view and transitive consumer is value- and metadata-equivalent, rollback and performance gates pass, and the final Changes review has zero findings |
| 3 | Phase 5.0: SQL immutable-file companion | Final Phase 3/4 SQL contracts are available | **Complete:** SQL migration/rollback, exact claim identity, digest-bound import/archive, representative rehearsal and SQL Changes review passed |
| 4 | Phase 5.1: bot/DAL producer and consumers | Accepted Phase 5.0 SQL contract is frozen | **Closed for Phase 5.2 entry review:** four approved bot paths, atomic unique publication, retained real-token ACL proof, source-unchanged smokes and receipt-backed stable-finding closure are accepted; exact final scan coverage is revalidated at Checkpoint A |
| 5 | Phase 5.2: combined release gate | Phases 2–5.1 are closed with exact commits | Fresh-restore coordinated forward, rollback, finalizer, workload and end-to-end bot rehearsal pass |
| 6 | Production go/no-go | Reviewed SQL and bot PRs plus combined receipts exist | Operator gives separate explicit execution approval after fresh production preflight |

The `5.0`, `5.1`, and `5.2` labels are delivery slices, not additional formal phases. The combined
release gate is still not Phase 6: it packages and proves the already approved implementation
phases. Phase 2 retained originals must remain available until this gate accepts the exact
Phase 3/4/5 SQL definitions and SQL/bot commits.

## Phase 3 closure receipt

- Branch: `codex/kingdomscandata4-phase3`.
- Migration:
  `20260726_001_phase3_import_concurrency_and_direct_type_alignment`.
- Representative database:
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`.
- Ordered proof: Phase 2 forward, Phase 3 forward, Phase 3 rollback, and clean Phase 3 reapply all
  passed without touching production.
- Final Codex Security Changes scan:
  `7ccf1007-269d-4470-94f0-638222312c5a`.
- Reviewed working-tree snapshot:
  `codex-security-snapshot/v1:sha256:98d3c2f01c061c4a3557b5d2f43d0080b47cab9c9863279c8162f3dbb9d653a8`.
- Result: two Low/P3 mutable-path TOCTOU findings. Both require one immutable, uniquely named
  producer-to-consumer handoff protocol and remain Phase 5/combined-release blockers.
- Post-scan closure edits are status/receipt/sequencing documentation plus mechanical trailing
  whitespace and final-newline cleanup in the generated Phase 3 SQL package. They do not alter
  SQL tokens, executable behavior, tooling, configuration, permissions, deployment behavior or
  runtime contracts and therefore use a documented security-review skip.

## Phase 3 delivery slices

1. Freeze the complete affected-module and downstream-table manifest from the closure matrix,
   Query Store map and bot/DAL contract map.
2. Approve one database application-lock resource, ownership scope, timeout, transaction boundary,
   scan-allocation statement and duplicate key.
3. Implement the mutex, atomic allocation and duplicate prevention across every authoritative
   import entry point, including direct SQL paths that bypass the bot lock.
4. Align stored procedures, functions, staging contracts and downstream tables to the Phase 2
   types. Retain conversion at genuinely untrusted or error-checking boundaries.
5. Rehearse forward and rollback definitions on a fresh representative copy.
6. Repeat the complete `UPDATE_ALL2` functional/concurrency/committed-import suite and every
   assigned summary, metadata, leadership and Query Store workload.
7. Close Phase 3 only after exact result metadata, bidirectional values, plans, resource metrics,
   module compilation, repository validation and a SQL Changes security review pass.

## Phase 4 delivery slices

1. Rediscover every direct and transitive view dependency after Phase 3.
2. Record old definitions, result metadata, rows, digests, parameters and ordering assumptions.
3. Retire only the separately approved invalid/unused
   `dbo.vAllianceActivity_WeeklyCumulative` object after dependency proof.
4. Remove only obsolete type compensation; preserve deliberate trimming, date, null, aggregate,
   display and overflow semantics.
5. Rehearse ordered forward and rollback view definitions.
6. Rerun latest, daily, WTD, global-latest, export and mapped consumer scenarios with one warm-up
   and five measured executions.
7. Close Phase 4 only after bidirectional value/metadata equivalence, refreshed dependencies,
   stable performance, repository validation and a SQL Changes security review pass.

## Phase 4 closure receipt

- Branch: `codex/kingdomscandata4-phase4`.
- Representative database:
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`.
- Ordered proof: guarded obsolete-view retirement, Phase 4 forward, exact
  rollback, and clean reapply passed without touching production.
- Final Codex Security Changes scan:
  `e6ce0a1d-7aba-428a-b40a-61001c924143`.
- Reviewed working-tree snapshot:
  `codex-security-snapshot/v1:sha256:a00ac727cab59a0ed585b7e6f615a3391fc792d95a1165c624c0328e978a909b`.
- Result: Deep off, 13/13 completed source-like worklist rows, no deferrals, and
  zero reportable findings.
- Post-scan closure edits are status and receipt documentation only. They do not
  alter SQL tokens, executable behavior, tooling, configuration, permissions,
  deployment behavior, or runtime contracts and therefore use a documented
  security-review skip.

## Phase 5 delivery slices

### Phase 5.0 — SQL companion

The SQL package is authored on `codex/kingdomscandata4-phase5-sql`. It introduces the immutable
claim ledger and exact completed-name consumers, binds digest/import/receipt/archive state,
includes a stopped-writer forward migration and exact early rollback, and supplies deterministic
preflight, verification, test-path, duplicate, failure and recovery smokes. Offline contract and
repository validation pass.

The pinned `MINI_AMD` runner completed forward migration, verification, normal/duplicate/recovery
protocol smokes, exact rollback, rollback preflight, clean reapply and final verification on
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`. Final SQL Changes scan
`099379cd-119b-4402-8ecb-cf2e1c105f40` closed all 18 executable worklist rows with zero
reportable findings. Phase 5.0 is closed on the SQL repository boundary. Production execution
remains unauthorized.

#### Phase 5.0 closure receipt

- Successful rehearsal:
  `C:\discord_file_downloader\downloads_test_phase5_rehearsal\evidence\phase5_0_20260728T160735090Z`.
- Receipt:
  `C:\discord_file_downloader\downloads_test_phase5_rehearsal\evidence\phase5_0_20260728T160735090Z\receipt.json`.
- Final Changes snapshot:
  `codex-security-snapshot/v1:sha256:cd7a6574c63a297d18f0748470292ed486fd3c7976d7c816d37ee20843bcd207`.
- The SQL controls fail closed on byte changes. Effective `icacls` readback and negative
  claimed-file mutation tests under the real bot token remain explicit Phase 5.1 evidence.
- Post-scan closure edits are status and receipt documentation only; production was untouched.

### Phase 5.1 — bot/DAL and producer

Use the standalone implementation task pack:
`docs/Codex_Task_KingdomScanData4_Phase5_1_Bot_DAL_Immutable_Handoff.md`.

Work primarily in `C:\discord_file_downloader` on its own branch and PR. The immutable-file
handoff consumes the frozen Phase 5.0 SQL contract. The repositories retain separate Git
histories, tests and Changes reviews.

1. Change `player_self_service/accounts_dal.py`.
2. Change `player_self_service/governor_dashboard_dal.py`.
3. Change `weekly_activity_importer.py`.
4. Move touched SQL from `embed_offseason_stats.py` to a stats-alert DAL and update the caller.
5. Preserve all locked result, order, null, trim, date, civilization, fallback and display
   contracts.
6. Run focused tests for each changed path plus the four source-unchanged contract smokes.
7. Run the bot repository's architecture, deferred-item, test-selection, smoke-import,
   command-registration, security-routing, pre-commit and full pytest gates.
8. Replace the reusable mutable `stats.csv` handoff with an atomically published, uniquely named
   completed file that the SQL side claims, hashes, imports, receipts and archives as one
   immutable object. Enforce claim-directory ACL assumptions and retain destination rehashing as
   defense in depth.
9. Prove atomic unique publication and preserve effective ACL evidence showing that the bot
   cannot modify a claimed file while SQL can hash and move it.
10. Close Phase 5 only after separate SQL and bot Changes security reviews pass against the exact
    commits selected for the combined rehearsal and both Low/P3 findings are closed.

#### Phase 5.1 closure receipt

- Date: 2026-08-17.
- SQL candidate: `368292fe1f291ff20765f3ecb6702a119fb78a20`; ACL migration
  `20260816_001_phase5_1_claim_acl_hardening`.
- Bot mirror PR #232 frozen range:
  `46e5a9cd58a4f475557904226656b2b8cc39dbb2..03ea272a9480bbc2cc360bfd574e3b5c9205f438`.
- Production PR #539 frozen candidate:
  `237eaa585be29b68d8ca0678f5f9b14e54327950`; its failed GitHub scan remains a Checkpoint A gate.
- Accepted run: `phase5_1_20260817T155508137Z`, evidence version 2, status PASS.
- Receipt SHA-256:
  `C9319B9980AE270C0F7C8D2891012E538951D052D206114C9F9828851279EDCF`.
- Transcript SHA-256:
  `91A6C281230B441B1111417366D79D1A532B8296E10017BB38BE63B288236B4C`.
- Canonical completed-file Ready/claim/archive SHA-256:
  `B4355635986F5BF365AEADD3E7DA91F5A0ED5D65D33A976A726FFB125100A724`.
- The bot token was denied overwrite, replacement, rename, delete, and in-place modification;
  SQL retained the claim/archive capability and both stable finding IDs have receipt-backed
  closure evidence.
- Delta Changes scans `9bcfac4d-37de-4b93-b314-0af15fb42023` and
  `7bf41033-74d7-41ab-9726-6daa2f4a1ee7` reported no findings. Checkpoint A must prove combined
  coverage of the exact final range or run one final exact-range bot Changes scan with Deep off.
- This closes neither PR, authorizes no merge/deployment/restart, and does not permit production
  SQL execution or a `docs/SQL_DELIVERY_LOG.md` update.

### Phase 5.2 — combined release

Use `docs/Codex_Task_KingdomScanData4_Phase5_2_Combined_Release_Gate.md` with
`performance_remediation/kingdomscandata4/release/README.md`. Freeze one SQL commit and one bot
commit, rehearse Phases 2–5 from a fresh restore, and produce the combined acceptance receipt.
Do not update `docs/SQL_DELIVERY_LOG.md` or execute production deployment until the separate
production go/no-go is explicitly approved.

## Task-wide controls

- Reuse the Phase 1 scenarios, parameters, fixtures, row counts and digests after every material
  change.
- Flag any regression around or above 10 percent in median duration, CPU, reads or import
  throughput. Resolve it or retain evidence that a necessary correctness/safety gain outweighs it.
- Keep `IMPORT_STAGING_CSV_RAW` wide and keep typed ingestion widths at
  `nvarchar(200/100/100/200)`.
- Keep all ten KS4 indexes and the existing persisted `AsOfDate`.
- Never use a snapshot as the production rollback mechanism.
- Never discard operator-held raw evidence or expose it in Git.
- Keep production stopped from this workflow until the separate go/no-go checkpoint.

## Detailed contracts

- Phase 3: `performance_remediation/kingdomscandata4/phase3/README.md`
- Phase 4: `performance_remediation/kingdomscandata4/phase4/README.md`
- Phase 5: `performance_remediation/kingdomscandata4/phase5/README.md`
- Combined release: `performance_remediation/kingdomscandata4/release/README.md`
- SQL promotion controls: `docs/SQL_DATA_MIGRATION_GUARDRAILS.md`,
  `docs/SQL_PROMOTION_GUIDE.md`, `docs/SQL_RELEASE_CHECKLIST.md` and
  `docs/SQL_DELIVERY_LOG.md`
