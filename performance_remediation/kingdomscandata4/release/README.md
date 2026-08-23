# KingdomScanData4 Phase 5.2 combined release gate

This is a release gate after Phases 2 through 5. It is not a sixth implementation phase and it
does not authorize production execution.

Current status 2026-08-17: the Phase 5.0 SQL entry component and Phase 5.1 bot/DAL plus
receipt-backed real-token ACL evidence are closed for Phase 5.2 entry review. SQL PR #64 merged as
clean SQL `main`/`origin/main` `3a6162d981a48f4bcebc6e31c45db4e61614393f`; executable evidence
remains bound to `368292fe1f291ff20765f3ecb6702a119fb78a20`. Checkpoint A refreshed bot
PR #232 to `f95ead9d348bdf45726fb9ce1e73f6ed2a20483a` and production PR #539 to
`53eaeb66b99538778ad7cd95a974dcd0bc8ccd55`. SQL-history, retained-original, and MINI_AMD
return-to-main facts remain blocking live gates. The combined rehearsal has not started.

## Entry criteria

- Phase 2 physical migration and retryable early rollback are closed.
- Phase 3 procedure/import/downstream work is closed.
- Phase 4 view/consumer work is closed.
- Phase 5.0 SQL companion rehearsal and Phase 5.1 bot/DAL work are closed.
- Exact SQL and bot commits, rollback definitions and security-review artifacts are identified.
- Stable findings `csf_1a1c440452b02cdb787fa7c3` and
  `csf_3cb54318733d3a216dd91e9b` are closed by the reviewed immutable-file protocol and retained
  real-token ACL evidence.

Accepted Phase 5.1 handoff evidence:

- bot mirror PR #232 frozen range
  `46e5a9cd58a4f475557904226656b2b8cc39dbb2..f95ead9d348bdf45726fb9ce1e73f6ed2a20483a`;
- production PR #539 candidate `53eaeb66b99538778ad7cd95a974dcd0bc8ccd55`, based on production
  `main` `caabd2c7dc77aec67f2748a1b9b66fdf53a4aa02`;
- run `phase5_1_20260817T155508137Z`, evidence version 2, status PASS;
- receipt SHA-256
  `C9319B9980AE270C0F7C8D2891012E538951D052D206114C9F9828851279EDCF`;
- transcript SHA-256
  `91A6C281230B441B1111417366D79D1A532B8296E10017BB38BE63B288236B4C`;
- Ready/claim/archive SHA-256
  `B4355635986F5BF365AEADD3E7DA91F5A0ED5D65D33A976A726FFB125100A724`;
- overwrite, replacement, rename, delete, and in-place modification all denied to the bot token;
  SQL claim/import/archive completed and both finding IDs have receipt-backed closure evidence.

Exact contiguous bot Changes coverage is retained through scan
`c6761a00-3670-48f5-965f-43fe3228e675` for the original full range, scan
`02d8e353-4eec-40e9-bafa-4fd4c53ac860` for the archive-descendant ACL remediation, and closure
scan `0ecf75bf-359c-4503-a6c8-3fcbed84c98e` for the hard-link rejection delta. Finding
`csf_38e8134cbe97537f0652c431` is closed by the final commit, disposable NTFS negative probe,
repository gates, and zero-finding closure scan. PR #539's quality and scan checks now pass. No
Codebase or Deep scan was run or authorized.

The closed Phase 4 SQL artifact is bound to final Changes scan
`e6ce0a1d-7aba-428a-b40a-61001c924143` and reviewed snapshot
`codex-security-snapshot/v1:sha256:a00ac727cab59a0ed585b7e6f615a3391fc792d95a1165c624c0328e978a909b`.
That scan completed all 13 source-like worklist rows with no deferrals or
reportable findings. This receipt does not authorize production execution.

The closed Phase 5.0 SQL artifact is bound to final Changes scan
`099379cd-119b-4402-8ecb-cf2e1c105f40` and reviewed snapshot
`codex-security-snapshot/v1:sha256:cd7a6574c63a297d18f0748470292ed486fd3c7976d7c816d37ee20843bcd207`.
That scan closed all 18 executable worklist rows with zero reportable findings and retained the
real-token claimed-directory ACL check as a Phase 5.1 follow-up. This receipt does not authorize
production execution.

## Combined rehearsal order

Use three newly named databases restored independently from the same approved representative seed.
Do not reuse the existing Phase 5.1 rehearsal database.

### Forward database

1. Restore the approved representative seed to the newly named forward database without using a
   database snapshot.
2. Confirm repository validation, clean committed revisions, backup readiness, capacity, version,
   compatibility, sessions, grants, source-backup identity, and isolated filesystem roots.
3. Stop or exclude all bot/import/scheduler/admin/ad-hoc write entry points to that isolated
   database.
4. Run the Phase 2 production-shaped preflight, apply Phase 2, and run table/module/digest/DBCC,
   history, and retryability verification.
5. Apply the Phase 3 migrations in documented order and run procedure/import/concurrency,
   authorization, archive-reconciliation, ambient-transaction, equivalence, and workload checks.
6. Apply `20260727_000_retire_vAllianceActivity_WeeklyCumulative`, then
   `20260727_001_phase4_view_type_alignment`; run the Phase 4 view, consumer, plan, benchmark, and
   equivalence checks.
7. Apply `20260728_001_phase5_immutable_import_file_handoff`, then
   `20260816_001_phase5_1_claim_acl_hardening`, while writers remain stopped; run the immutable
   file identity, claim, ACL, failure, retry, duplicate, receipt, archive, and digest smokes.
8. Run the complete committed-import, source-unchanged, workload, Query Store, and matching bot/DAL
   matrix. Preserve its receipt and transcript. Durable receipts make early rollback ineligible on
   this database.
9. Create the combined pre-finalization receipt bound to the exact Phase 2 run ID, retained-table
   digests, final module hashes, migration history, SQL commit, bot commits, and validation
   receipts. Do not finalize this forward database.

### Rollback database

10. Restore the same approved receipt-free seed to a second newly named rollback database. Apply
    Phases 2–5.1 without committed imports, file claims, receipt-producing protocol smokes, or
    other post-cutover writes.
11. Prove no Phase 3 import receipt or Phase 5.1 ACL-hardening evidence exists. Roll back Phase 5.1
    ACL hardening and Phase 5.0 file protocol in reverse order; restore the four Phase 4 prior view
    definitions while leaving the approved retired weekly-cumulative view retired; restore Phase
    3 definitions; then run the Phase 2 metadata-swap rollback.
12. Verify the original schema/modules/digests, DBCC, sessions, application compatibility, Phase 2
    retryability, and the exact remaining migration-history rows. Preserve this database and its
    receipt. Do not edit or delete migration-history rows and do not use
    `Deploy-SqlMigration.ps1` to reapply rolled-back definitions whose rows still say `Applied`.

### Clean-reapply database

13. Restore the same approved receipt-free seed to a third newly named reapply database and repeat
    the complete forward path.
14. Create a new combined receipt for this reapply only. The guarded finalizer may consume only
    that exact receipt while retaining run-ID, time, lock, table-digest, and no-drift controls.
15. After finalization, run the matching isolated bot immutable-handoff, restart, failure,
    duplicate, cancellation, workload, source-unchanged, and operational smoke matrix. Preserve
    the complete evidence package outside Git.

The Phase 2 finalizer must not be weakened or manually bypassed. The release package supplies
`Invoke-Phase52GuardedFinalizer.ps1` and `combined_receipt.schema.json` as the guarded adapter and
receipt contract. The adapter leaves `phase2/03_finalize.sql` refusal-by-default and unchanged. It
requires an external receipt below a non-reparse evidence root, reads and hashes the receipt bytes
once, requires the operator-frozen receipt SHA-256 and exact SQL/bot commits, and validates:

- the clean-reapply stage, PASS status, backup checksum/`RESTORE VERIFYONLY` evidence and all nine
  combined gates;
- the exact six ordered Phase 2-5.1 migration IDs and repository file SHA-256 values;
- a separately frozen applied SHA-256 for every migration; production receipts require it to
  equal the canonical repository digest, while rehearsal receipts may bind a different applied
  digest only for the Phase 5 test-root derivation;
- the exact Phase 2 run ID, row counts and six baseline/forward table digests;
- concrete retained module, changed-file and validation-manifest paths below the evidence root,
  each re-read and checked against its receipt-bound digest, plus at least one exact SQL Changes
  scan ID;
- the reviewed Phase 2 finalizer path and SHA-256;
- for live validation, a fresh eligible `VERIFIED` state row and six matching `Applied`
  migration-history rows; and
- for live validation and execution, a clean SQL repository at the exact receipt-bound commit.

`-OfflineValidationOnly` validates the external receipt and repository inputs without SQL access.
`-LiveValidationOnly` adds read-only SQL state/history and receipt-freshness validation but does
not finalize. Execution
requires separate `-ConfirmReceiptAccepted`, `-ConfirmWritersStopped` and
`-ConfirmIrreversibleFinalize` switches. Non-production execution accepts only the controlled
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_<YYYYMMDD>` or
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE52_REAPPLY_R<n>_<YYYYMMDD>` rehearsal naming forms, where
`n` is a positive integer. `ROK_TRACKER` additionally requires
`-ConfirmProductionTarget` and a production-purpose receipt. After all checks, the adapter changes
only the two confirmation declarations in an in-memory copy of the reviewed finalizer. It creates
randomly named authorized-SQL and execution-receipt files without overwrite, verifies each open
handle's final Windows path, and retains both exclusive handles throughout execution so a local
link swap cannot redirect later privileged content writes. It then executes the exact in-memory
text and requires durable `FINALIZED` state plus a finalization receipt. The existing finalizer still
rechecks receipt freshness, sessions, application lock, exclusive table locks, row counts and all
six data digests inside its transaction before it drops a retained table.

Run the deterministic refusal/contract suite before any live use:

```powershell
.\performance_remediation\kingdomscandata4\release\Test-Phase52GuardedFinalizer.ps1
```

Never use execution mode at Checkpoint B. Use offline/live validation to prepare evidence, then
execute only after Checkpoint C accepts the exact combined receipt. Production use still requires
the separate production go/no-go.

## Pre-restart rollback order

If any gate fails before finalization or application restart on an eligible receipt-free target:

1. keep every write entry point stopped;
2. roll back the Phase 5.1 ACL-hardening migration, then the Phase 5.0 SQL companion file-protocol
   migration;
3. restore the exact four retained Phase 4 prior view definitions; leave the
   approved invalid/unused weekly-cumulative view retired;
4. restore the exact Phase 3 prior procedure/function definitions;
5. run the Phase 2 metadata-swap rollback;
6. verify that `SchemaMigrationHistory` leaves the Phase 2 migration retryable and records the
   Phase 3/4/5 rows that remain `Applied` despite definition rollback;
7. rerun original-schema/module/digest/DBCC smokes; and
8. start only the old bot revision.

Retain the rolled-back database as evidence. Reapply only from the third fresh restore because the
Phase 3/4/5 rollback scripts do not mark their migration-history rows unapplied. Do not hand-edit
history or weaken rollback guards.

After finalization or any post-cutover write, metadata-swap rollback is forbidden. Use a reviewed
forward fix or the documented backup/log recovery branch.

The exact Phase 4 early rollback is
`migrations/rollback/20260727_001_phase4_view_type_alignment_rollback.sql`.
It holds both KS4 mutexes, restores the four frozen Phase 3 definitions, and
must complete before the Phase 3 rollback starts. The preceding obsolete-view
retirement is explicitly forward-fix-only and is not reversed.

## Git and promotion order

1. Review and merge the complete SQL PR only when the coordinated release is scheduled.
2. Validate that only the intended migration IDs are pending on SQL `main`.
3. Validate the bot mirror PR, promote its file delta onto a branch based on
   `production/main`, and obtain the production bot PR approval.
4. During the maintenance window, deploy and verify the complete SQL release first.
5. Merge/deploy the matching bot revision only after SQL verification/finalization succeeds.
6. Confirm migration/deployment history, drift, bot smoke and operational logs.
7. Update `docs/SQL_DELIVERY_LOG.md` only after successful production deployment.

## Production gate

Use `docs/SQL_RELEASE_CHECKLIST.md`, `docs/SQL_PROMOTION_GUIDE.md` and
`docs/SQL_DATA_MIGRATION_GUARDRAILS.md`. Production requires a separate explicit go/no-go after the
fresh preflight proves backups, effective grants, sessions, capacity, hashes and exact commits.
