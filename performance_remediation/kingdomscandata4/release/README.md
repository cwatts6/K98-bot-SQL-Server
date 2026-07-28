# KingdomScanData4 Phase 5.2 combined release gate

This is a release gate after Phases 2 through 5. It is not a sixth implementation phase and it
does not authorize production execution.

Current status 2026-07-28: the Phase 5.0 SQL entry component is closed. Phase 5.1 bot/DAL,
real-token ACL evidence, exact commit freezing, and this combined rehearsal remain pending.

## Entry criteria

- Phase 2 physical migration and retryable early rollback are closed.
- Phase 3 procedure/import/downstream work is closed.
- Phase 4 view/consumer work is closed.
- Phase 5.0 SQL companion rehearsal and Phase 5.1 bot/DAL work are closed.
- Exact SQL and bot commits, rollback definitions and security-review artifacts are identified.
- Stable findings `csf_1a1c440452b02cdb787fa7c3` and
  `csf_3cb54318733d3a216dd91e9b` are closed by the reviewed immutable-file protocol and retained
  real-token ACL evidence.

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

1. Restore the approved representative seed without a database snapshot.
2. Confirm repository validation, clean committed revisions, backup readiness and available
   capacity.
3. Stop all bot/import/scheduler/admin write entry points.
4. Run the Phase 2 production-shaped preflight.
5. Apply Phase 2 forward migration and run its table/module/DBCC verification.
6. Apply Phase 3 migrations and run procedure/import/concurrency/equivalence validation.
7. Apply
   `20260727_000_retire_vAllianceActivity_WeeklyCumulative`, then
   `20260727_001_phase4_view_type_alignment`, and run the Phase 4
   view/consumer/equivalence validation.
8. Apply the Phase 5 SQL companion migration for the immutable claimed-file protocol while all
   writers remain stopped, then run its file-identity, failure and rollback smokes.
9. Run the complete committed-import, workload, Query Store and bot/DAL smoke matrix against the
   matching stopped bot revision and SQL contracts.
10. Create a fresh combined-release acceptance receipt bound to the exact Phase 2 run ID, final
   Phase 3/4/5 SQL module hashes, SQL commit, bot commit and completed validation receipts.
11. Finalize the retained Phase 2 tables only from that fresh combined receipt.
12. Deploy/start the matching bot revision and rerun the end-to-end bot and immutable-file import
    smoke suite.

The Phase 2 finalizer must not be weakened or manually bypassed. Before the combined rehearsal,
add a guarded adapter or finalizer extension that consumes the combined receipt while retaining
the exact run-ID, time, lock, table-digest and no-drift controls.

## Pre-restart rollback order

If any gate fails before finalization or application restart:

1. keep every write entry point stopped;
2. roll back the Phase 5 SQL companion file-protocol migration;
3. restore the exact four retained Phase 4 prior view definitions; leave the
   approved invalid/unused weekly-cumulative view retired;
4. restore the exact Phase 3 prior procedure/function definitions;
5. run the Phase 2 metadata-swap rollback;
6. verify that `SchemaMigrationHistory` leaves the Phase 2 migration retryable;
7. rerun original-schema/module/digest/DBCC smokes; and
8. start only the old bot revision.

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
