# KingdomScanData4 combined release gate

This is a release gate after Phases 2 through 5. It is not a sixth implementation phase and it
does not authorize production execution.

## Entry criteria

- Phase 2 physical migration and retryable early rollback are closed.
- Phase 3 procedure/import/downstream work is closed.
- Phase 4 view/consumer work is closed.
- Phase 5 bot/DAL work is closed in the separate bot repository.
- Exact SQL and bot commits, rollback definitions and security-review artifacts are identified.

## Combined rehearsal order

1. Restore the approved representative seed without a database snapshot.
2. Confirm repository validation, clean committed revisions, backup readiness and available
   capacity.
3. Stop all bot/import/scheduler/admin write entry points.
4. Run the Phase 2 production-shaped preflight.
5. Apply Phase 2 forward migration and run its table/module/DBCC verification.
6. Apply Phase 3 migrations and run procedure/import/concurrency/equivalence validation.
7. Apply Phase 4 migrations and run view/consumer/equivalence validation.
8. Run the complete committed-import, workload, Query Store and bot/DAL smoke matrix.
9. Create a fresh combined-release acceptance receipt bound to the exact Phase 2 run ID, final
   Phase 3/4 module hashes, SQL commit, bot commit and completed validation receipts.
10. Finalize the retained Phase 2 tables only from that fresh combined receipt.
11. Start the matching bot revision and rerun the end-to-end smoke suite.

The Phase 2 finalizer must not be weakened or manually bypassed. Before the combined rehearsal,
add a guarded adapter or finalizer extension that consumes the combined receipt while retaining
the exact run-ID, time, lock, table-digest and no-drift controls.

## Pre-restart rollback order

If any gate fails before finalization or application restart:

1. keep every write entry point stopped;
2. restore the exact Phase 4 prior view definitions;
3. restore the exact Phase 3 prior procedure/function definitions;
4. run the Phase 2 metadata-swap rollback;
5. verify that `SchemaMigrationHistory` leaves the Phase 2 migration retryable;
6. rerun original-schema/module/digest/DBCC smokes; and
7. start only the old bot revision.

After finalization or any post-cutover write, metadata-swap rollback is forbidden. Use a reviewed
forward fix or the documented backup/log recovery branch.

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
