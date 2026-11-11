# P02 D4b legacy entry and backup queue boundaries

## Approved behavior

The operator approved retiring `dbo.UPDATE_ALL`, `dbo.UPDATE_RALLY_DATA` and
`dbo.TEST` if the remaining caller checks passed. The 11 November read-only
checks complete that condition within the reviewed installed/source/task/catalog
scope and the operator's confirmation of no manual external callers. This is not
proof against an arbitrary future, remote or dynamically constructed invocation.

Each procedure now retains its name, parameters and caller execution context but
immediately raises error 52940. There is no business SQL, file deletion, input
claim, child invocation or success receipt. An authorized direct caller gets a
clear retirement error; a caller denied EXECUTE still receives the ordinary
permission error. THROW retains SQL Server's normal caller error/transaction
semantics; the refusal does not commit or roll back a caller's transaction.

`UPDATE_ALL2`, the modern statistics/report workflow and the daily/all-time Rally
import remain supported. The retired UPDATE_ALL's fixed historic KVK/scan path,
Rally CSV deletion/error swallowing and TEST's old summary rebuild are not
transferred into another entry point. Existing data is retained.

The exact pre-retirement definitions are preserved under `deploy/source_baselines`.
`qualification/p02_d4/legacy_source_history.json` records their Git source revision
and raw SHA256 values. Git attributes prevent newline conversion of those evidence
blobs. They are historical references, not automatically executable rollback.

## Caller evidence and its limits

The installed Bot source, enabled/disabled task inventory and all enumerated SQL
Agent job steps were reconciled. The remaining TEST substring in the backup-prune
step was `Test-Path` in backup-file cleanup; the reviewed command matched the
receipt's hash and contained no SQL call. No task, job or business work was run.

The database module catalog had no hidden definitions under the inspection account.
Exact token checks for the three legacy roots and three queue helpers returned
only the known legacy UPDATE_ALL-to-Rally call and an UPDATE_ALL rollback comment.
The only online user database was the application database. Custom master/msdb
modules and server SQL triggers supplied no additional callers. The installed
cache and Query Store had no recorded recent calls to the three retired roots;
restart, capture and retention limits mean this is supporting evidence only.
Raw host receipts, account names and job identifiers remain private.

## Historical backup queue coexistence

The old `usp_GetPendingLogBackupTriggers`, `usp_MarkLogBackupTriggerProcessed` and
`usp_CleanupLogBackupTriggerQueue` ask the fixed metadata-only helper
`usp_P02LegacyQueueState` whether any object named `dbo.MaintenanceBackupWork`
exists. Only that observation runs as the module owner, and the helper requires
its effective user to be dbo. A changed owner raises 52942; a missing helper
raises the ordinary missing-procedure error. Neither permits a legacy fallback.

The three queue APIs retain EXECUTE AS CALLER, original parameters and ordinary
EXECUTE authorization. If the helper reports an existing ledger, all three raise
52941 before selecting, marking or deleting queue rows. A wrong-type object also
refuses. Database, schema and object metadata denials on the caller cannot hide
the ledger from the helper. With no ledger, original queue behavior is retained
without adding a caller metadata grant. There is no new permission grant, queue
adoption, age-based expiry, conversion of request to completion, or alternate
dispatch. The boundary protects these APIs; it does not revoke direct-table rights.

D4c must install the helper before the guards during a drained, coordinated transition before new
maintenance processing is admitted. The guards alone do not close a concurrent
legacy call that passed its check before deployment. Historical queue rows,
unknown results and new outstanding work must survive migration and resume.
Reverting to old queue processing after new work exists is not an automatic or
lossless rollback. Exact predecessor/postimage verification and the recovery/write
boundary remain D4c obligations.

## Validation and release status

Native tests create a uniquely owned disposable local K98DEV database with resource
and identity gates. They exercise all three retirement calls under autocommit,
ambient and implicit transaction modes, denied callers, repeated guarded queue
calls, table/wrong-type ledger identities, hidden metadata with and without the
ledger, narrower object/schema denials, changed/missing helper ownership and the
original legacy-only queue behavior. Sentinel data and queue rows
are compared across refusals. Archived definitions are checked byte-for-byte.
No wrapper, backup job, business procedure or installed application is invoked.

This is a source slice, not an installer. D4c owns the combined SQL migration and
permission profile; D4d owns startup/updater compatibility. D5 retains combined
fault/restart/cost qualification. Installation and operational acceptance remain
separate decisions. The security gate is a SQL-repository Changes review of this
slice, with Deep off. Bot architecture/deferred/test-selection scripts are not
applicable to this SQL-only patch; native tests, SQL repository validation and the
updated publication-contract validator cover its changed surfaces.

Validation result after review correction: 26 focused native tests passed, Black and Ruff passed, and
`deploy/Validate-SqlRepo.ps1` passed. The full KVK publication-contract script
stops in its unchanged atomic-configuration prerequisite with `Atomic
configuration forward source drift`. Its helper, prerequisite validator, manifest
and target module are identical to base b8e6b925; this is the existing historical
validator/D3-source mismatch, not caused by this slice. It is recorded for D4c's
combined contract update. The new retirement behavior is exercised natively above;
the full historical publication gate is not claimed as passed.

The first reviewed implementation checked database VIEW DEFINITION in the caller
context. PR review identified that narrower object/schema DENYs could still hide
the ledger. A new native regression reproduced that bypass before the correction;
the fixed helper and both denial cases now pass. The initial 22-test/security
receipt belongs to the superseded head and does not qualify the corrected diff.
