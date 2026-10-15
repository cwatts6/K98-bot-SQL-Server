# Guided recovery persistence — P0 foundation

Companion Bot branch: `codex/guided-recovery-p0`. This package is additive and does
not settle existing operations, release reservations, or replay business work.

Install migration `20261015_002_guided_recovery` through the supported migration
runner before the companion Bot. The runner must skip its recorded applied ID;
direct replay refuses existing objects rather than adopting unknown definitions.
Rollback keeps both tables and their audit history; roll forward to repair errors.

`RecoveryIncident` is scoped by a SHA256 digest of runtime account, storage owner
and Discord guild. `(ScopeKey, SourceKind, SourceID)` deduplicates observations.
The evidence digest and revision bind an admin preview to its current facts.
`RecoveryAction` records the admin, decision and reason before any domain operation.
An unresolved action blocks any new action even if observation changes the revision.
The action table does not grant permission to release a resource: the domain DAL
must revalidate its original ownership, fencing and transaction evidence.

The first adapter uses the existing atomic StatsImportExecution settlement. Only
that proven idempotent metadata transaction can resume its original authorised
action after a lost acknowledgement. No UPDATE_ALL2/import/provider replay is added.

The application principal needs SELECT, INSERT and UPDATE on these two objects;
no DELETE, broad role membership, schema-wide grant or runtime self-grant is needed.
The target-specific protected permission manifest must include these exact rights
before installation is considered ready. This migration does not guess a principal
or change grants. Existing StatsImportExecution/ExportPreparation/ExportResource
permissions and lock checks remain unchanged.

AlertAttemptUTC is a five-minute delivery lease for diagnostic alerts only. It is
never business/resource ownership. An uncertain alert send is reconciled by its
stable incident marker; bounded-history absence permits only a duplicate-tolerant
diagnostic retry. It must not be used to authorise a business-message retry.

Local engine tests use randomly named global temporary tables on local K98DEV.
They exercise scoped reads, concurrent claims, lost commit acknowledgements,
stale revisions and durable action state. SQL Server does not enforce FKs on temp
tables, so these tests do not establish persistent FK installation or deployment.
Those remain mandatory release acceptance work, not deferred optimisation.

## Complete sealed read prefixes

Companion branch `codex/guided-read-journal` adds migration
`20261015_003_read_prefix_history`, after `20261015_001_failed_read_history`.
It accepts a historical closed probe's read prefix ending at `prepared` or
`dispatch_intent` without treating it as a successful fresh provider observation.
The authority must still validate the complete private request/event journal and
exact positive child closure before issuing any proof. Unknown mutations, fresh
failed probes, missing private evidence and live writers remain rejected.

The migration pins the exact predecessor and postimage, rejects unexpected module
signatures, holds the schema application lock and changes no grants or data.
Deploy with the matching Bot/authority verifier and refreshed protected SQL/source
contracts. Do not deploy the reference schema snapshot directly. Roll forward;
retain all existing streams, proofs, incidents and action history.

Local acceptance executes the actual procedure postimage as a session-local
temporary procedure and its historical-request predicate over disposable CTE rows.
Cases include both read prefixes, unknown reads, every fresh failed read, unknown
mutation and purpose/kind mismatches. This establishes predicate/metadata behavior,
not persistent production migration installation or end-to-end provider acceptance.
Remaining recovery packages stay required in the Bot delivery tracker.
