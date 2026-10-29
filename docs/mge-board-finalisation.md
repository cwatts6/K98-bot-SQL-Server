# MGE immutable board finalisation — 29 October 2026

Local source change only. No migration, data mutation or bot restart has been run.
Bot and SQL review targets are separate. Bot integration is in the focused MGE
finalisation task pack; this document owns the database contract.

`dbo.MGE_BoardFinalisation` records each original signup, leadership and awards
target when domain completion commits. The generation is a UUID, the publication
version and channel/message identity are retained, and rowversion qualifies every
settlement or retirement. The payload is captured before Discord IO and never
overwritten. Unknown edit outcomes are read back; they never authorize a send.
Confirmed and retired rows cannot transition through the bot DAL.

No historical backfill is performed. Pre-existing completed events without these
records are frozen legacy history, not newly confirmed final deliveries. Partial
identity pairs are a deployment/inventory issue and must not be inferred absent.

The three freeze triggers reject changes to completed event records, signups and
awards. Completion itself is allowed from an active status; the final target rows
are inserted in the same transaction. Result import tables and audit history are
not blocked or deleted. Event locking serializes the freeze against other writers;
a deadlock or uncertain connection outcome is not permission to replay business
actions. These guards do not make legacy multi-call roster actions atomic.

Deployment order: qualify on an explicitly authorized disposable SQL target first;
review bot and SQL Changes diffs independently; drain the old bot; apply the table
and triggers; install the qualified bot release; restart through the protected
updater. Do not apply these guards under an old running bot: it still tries to
refresh completed messages before persisting IDs. This is a coordinated rollout,
not an ordinary unattended SQL-first change. No migration is automatically added
to a deployment manifest by this source work.

Rollback: preserve all finalisation rows/payloads, completed domain state and audit
data. Do not drop guards or resume the old historical sweep as a routine rollback.
Use a reviewed forward correction or a disabled/drained bot until compatible code
is installed. Legacy correction/reopen requires a separate explicit policy design.

Required native qualification (not executed here): migration twice; active target
and rank changes before completion; atomic freeze plus target inventory; rollback
when inventory insertion fails; multi-row and delete guards for events/signups/
awards; concurrent stale writer versus completion; rowversion conflict; retirement
versus settlement; results import after completion. Python fakes are not evidence
of SQL Server locking, trigger compilation or transaction behavior.
