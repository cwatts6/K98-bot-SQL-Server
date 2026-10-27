# Alliance Activity snapshot completion reconciliation

The activity workbook covers the top ten alliances. The kingdom scan has a different
population and must not decide whether the activity workbook imported completely.
Bot correction removes that comparison for future imports. This script reconciles
existing metadata through snapshot 574 without reimporting, inventing absent rows,
changing metrics, rebuilding daily totals, or changing database objects/permissions.

In SSMS on MINI_AMD, select the bot's intended database, open `reconcile.sql`, and run
with its default `@Apply=0`. Save the preview result. Candidates must have the original
SOURCE_VALIDATED receipt, source hash, no missing/invalid metrics, and equal source,
observed and actual stored counts. All checks run together with locks. Legacy assumed
zero, unverifiable, genuinely partial, newer and already complete snapshots are excluded.

After the bot correction is deployed, rerun the reviewed script with `@Apply=1` only in
the same intended database. Save both result sets (original counts and verified result)
as the audit record. Snapshot 574 is expected to show 855 supplied/stored rows and
COMPLETE if live evidence still matches. A repeat produces no changes to completed rows.
No schema migration, bot restart, upload replay or provider call is part of this SQL step.

If locks are busy the whole attempt rolls back; retry the whole reviewed script later.
If the connection outcome is unknown, inspect the exact headers first: committed rows
are COMPLETE with equal source counts; unchanged eligible rows remain PARTIAL. Never
invent zero activity for missing governors. Leadership review will be able to use the
corrected COMPLETE snapshots; absent governors still have no snapshot row.

To reverse a particular metadata decision, use its saved original-count result with
`dbo.usp_SetAllianceActivitySnapshotCompletion` and PARTIAL in a reviewed transaction.
Do not rerun imports or overwrite business rows for a metadata rollback.
