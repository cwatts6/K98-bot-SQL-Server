# P02 D3b: bounded durable maintenance ownership

This is the SQL companion to the Bot D3b maintenance ownership slice. The
operator authorized completing D3b–g, merging focused Bot mirror PRs, and creating
and reviewing the combined private Bot PR. Production installation remains held
until after D5. No production SQL, provider, retained recovery or restart was run.

## Contract

`dbo.MaintenanceWork` has six fixed rows. `dbo.usp_MaintenanceDue` joins its
caller's transaction and coalesces due generations. It neither commits nor
rolls back an outer business transaction. A same latest request ID does not add
another generation; this is not general historic request replay authority.

`dbo.usp_RunMaintenance` is autocommit-only. Its actual worker session acquires
the existing `K98:post-import-stats:v1` lock and the existing SQL snapshot writer
guard without waiting. Retaining the older maintenance resource prevents overlap
with older callers. Known log use below 70 percent is required before claim.
Only pending work runs. A free worker lock with a durable running claim changes
the claim to unknown; it does not retry the child. Failed/unknown states retain
the original claim and first failure for reviewed reconciliation. New due work
during a claim remains pending after completion of that generation.

`dbo.usp_update_stats` records post-import work and invokes the worker. Its
result contains the finite durable receipt, consumed by the matching Bot DAL.
`dbo.usp_MaintenancePostImport` retains the intentional `sp_updatestats` child
under owner execution and checks both worker guards. Resource observation runs
in the caller context: placing that DMV inside database-owner impersonation
failed native qualification with SQL 15562. No TRUSTWORTHY change or new server
grant was used to bypass that boundary. SQL error paths retain guards until the
Bot explicitly acknowledges release on the still-owned session. A fresh-process
native experiment proved that default ODBC pooling retains locks after close.
The corrected DAL releases and verifies before pool return; uncertain release
retains the open connection/cursor and closes admission. No global pooling setting
was changed. The failed baseline is retained in the Bot qualification artifacts.

## Qualification and remaining scope

Eleven opted-in native tests passed on 10 November 2026 using only a uniquely
created local disposable database. They exercise real `sp_updatestats`, durable
receipts, exact latest-request deduplication, outer rollback/nested-commit
visibility, concurrent exclusion, producer-first and maintenance-first arrival,
generation arrival during the real child, child fault injection, process death,
and refusal of a missing child or caller transaction. Two additional cases keep
a default-pooled worker process alive after success and injected child failure,
then prove both SQL guards are available before process exit. Process death accepts only
the two evidenced outcomes: durable completion before disconnect is observed,
or an unknown claim; neither allows blind replay. Injected gates/errors are
fixture-only and are distinguished from unchanged child execution.

The Bot tests are `tests/test_maintenance_owned_native.py` and
`tests/test_maintenance_dal.py` in the companion repository. The native fixture
requires `K98_P021_NATIVE_SQL=CREATE_DISPOSABLE_LOCAL_ONLY` and verifies the fixed
local server identity before creating a UUID-named database. It never force
disconnects retained sessions or changes retained server/database isolation settings.

D3c–g add the other real children and due boundaries. D3g owns backup queue
claim/acknowledgement and post-success wait separation. Raw-history SNAPSHOT
versus index REBUILD (SQL 3961) remains open until D3c's actual overlap tests.
All existing 8 GiB memory/disk floors, log/version-store limits and D5 balanced
cost gates remain in force. This small fixture does not qualify production
scale, restricted installed principals or the combined workflow.

These schema snapshots are source candidates, not an installer. D4 must include
the exact predecessor/postimage deployment and signing profiles, dependencies,
new procedure permissions, installed/manual paths and coordinated Bot/SQL
compatibility. Do not run these files piecemeal in production. No downgrade that
discards outstanding maintenance records is authorized. Separate Bot/SQL Changes
security reviews and PR checks remain required before merge.

SQL Changes scan `d305e947-8e39-4f05-b290-16991aeaee71` reviewed executable
revision `48dc44ad` with zero security findings. It explicitly retained the
companion pooled-close reliability correction and D4/D5 limits. The later executable correction is qualified below.

## Review closeout (10 November 2026)

The GitHub review identified implicit transaction mode as a durability defect:
`@@TRANCOUNT=0` alone does not establish autocommit. Both public/worker entry
points now refuse `SET IMPLICIT_TRANSACTIONS ON` before any table access. The two
native regressions failed before the fix and passed afterward; they are committed
in `tests/test_maintenance_session_contract.py`. Combined Bot/native qualification
passed 13 cases. The additional native cases above are included in the eleven,
not eleven plus two.

Exact correction Changes scan `cf8d43d4-579e-4353-a0d1-d015565fd6a0`
covered all eight changed paths through `287c73e` with zero findings. Its measured
usage was 660,506 tokens (656,864 input, 605,440 cached input, 3,642 output).
Both SQL validation CI runs passed at that head and refreshed GitHub code review
reported no findings. The first failure and fixed-test evidence remain retained.

Review comments on repeatable seeding and execution context were reconciled
against the source-only boundary. This CREATE TABLE snapshot is intentionally
not a reapplicable installer. D4 must preserve existing outstanding work and
qualify exact installed source/signing, restricted-principal DMV access and
same-owner access. Restoring owner impersonation would reintroduce the observed
SQL 15562 failure. Historical P0 installation manifests and migrations remain
immutable; the offline test first authenticates these five D3 sources, then
checks the pinned pre-D3 P0 body. Each changed-source mutation is rejected.
No current D3 installer or production permission/compatibility claim is supplied.

## D3c import maintenance candidate

UPDATE_ALL2 now records import maintenance due in its own Phase A transaction.
Only KS5 sampled statistics and conditional KS4 index/statistics upkeep move to
usp_MaintenanceImport. Required Refresh_PlayerScanMeta remains in the import;
typed/history writes, scan allocation, file/digest, receipts and archive remain
unchanged. The exact source comparison runs in CI. IMPORT_STAGING_PROC_CORE
contains no eligible upkeep and is unchanged.

The same six bounded kind rows carry import-specific KS4 due/completed generations.
Only actual KS4 promotion requests KS4 upkeep. Each claim acknowledges its captured
generation; newer work remains pending. No per-import queue or new scheduler is
introduced. The explicit post-import route processes due import work and returns
both finite receipts, preserving outstanding maintenance separately from business
completion.

All maintenance now acquires K98:maintenance-schema:v1 Exclusive/Session before
claim. Managed SNAPSHOT readers take Shared/Transaction through the Bot helper;
rollback releases that guard. Producers do not acquire this resource, preserving
metadata/producer independence. Unknown rollback retains open custody; pooled
maintenance release explicitly verifies all three session resources. This does
not qualify unmanaged legacy/manual readers.

Native qualification: five import cases run real sampled statistics and fragmented
index rebuilds, conditional KS4 scope, rollback, both managed reader arrival
orders and a new generation arriving during a running claim. The combined native
maintenance and existing snapshot selection passed 28 cases. Fixture delays are
identified separately from unchanged real child work. Exact business/upkeep
source preservation and all seven candidate mutation refusals pass. Historical
encoding/source tests use authenticated immutable predecessors; runtime installer
admission is unchanged. D4 owns final permissions/source/consumer compatibility;
D5 owns combined scale and cost. No production execution or installation occurred.

## D3d configuration maintenance candidate

CREATE_DELTA_TABLES retains its full business calculation/insert prefix and adds
only transactional due registration before the existing COMMIT. sp_TARGETS_MASTER
is unchanged, including its typed outer transaction guard and publication identity.
Optional statistics, fragmentation upkeep and DeltaProcessingLog run afterward
through the existing worker. A fixed singleton coalesces rows/scan and qualifying
large-batch generations, preserving 168-hour/5000-row eligibility with or without
the optional log. No per-request backlog is introduced.

All maintenance acquires the existing DeltaPreprocessing session mutex at zero
wait before claim, in producer-compatible order. The Bot acknowledges all four
guard releases before pool return. Configuration counter/main-claim completion
is one short owned transaction; rollback failure cannot mask the original error.
Successful or ineligible upkeep has its own generation/disposition before timing
logging. A log failure retains that evidence and FirstLogErrorNumber while the
packet remains failed without automatic replay. Index failures are no longer
swallowed; identifiers are quoted, dbo scope fixed and cursor lifetime local.

Qualification: 18 configuration-native cases plus existing import/maintenance
regressions (combined 67 cases) pass, including real fragmented-index rebuilding,
standalone/nested commit/rollback, thresholds/coalescing, failed child/log/ack,
physical guard order and cursor cleanup. Six separate typed-parent contract tests
pass using their existing nested stub; this is not full combined production
publication qualification. Exact retained business/caller comparison runs in CI.
The authoritative KS4 table refers to KS4_UNO_SEQ without a repository sequence
definition; the owned fixture omits only that default and supplies explicit
SCAN_UNO. D4 must reconcile the actual installed dependency, not infer its schema.
No production installation/execution occurred. D4/D5 boundaries remain unchanged.

## D3e player report maintenance candidate

SP_Stats_for_Upload preserves its full validated report publication, naming,
provenance and standalone/savepoint transaction behavior. Only its FULLSCAN
becomes a transactional player_report due marker. The fixed deferred child runs
FULLSCAN after committed business work. Every maintenance kind now takes the
existing StatsForUpload:Publish mutex at zero wait before claim (post_import
sp_updatestats also touches the report). A standalone publication transaction
therefore leaves maintenance pending without claiming it. All five session guards
are explicitly acknowledged before pooled return in the Bot companion.

Nine actual player-report native cases qualify the real procedure, tables and
naming helper/view, including outer rollback/commit, invalid provenance, due-write
failure, real statistics, publication contention and actual missing-object upkeep
failure with committed report rows retained. D2 statement limits are unchanged.
Exact full business-source comparison runs in CI. Thirteen fixed source candidates
and all mutation refusals pass. Installed permissions/signing/manual compatibility
remain D4, scale/cost D5. No production SQL or deployment occurred.

## D3f KVK output maintenance candidate

The real output calculation, views and exact receipt stay in the business
transaction. Only the post-output nonunique indexes and FULLSCAN are deferred.
A typed positive KVK due helper validates the canonical dbo output object and
KVKFinalReportHeader, coalescing one row per output identity. Claim identity is
retained separately from newer due object/revision fields. One target is processed
per worker call; aggregate completion waits until all captured targets complete.
Earlier per-target completion survives later failure; failed/unknown claims never
automatically replay. Existing unique indexes are preserved without DROP.

The actual output producer takes the existing maintenance-schema Shared transaction
lock at zero wait before its first mutation. This excludes the maintenance worker,
including standalone producer calls, without adding a sixth session guard. It is
not a claim that all unmanaged/manual producers or historical readers are qualified.
Required ranking access indexes and temporary calculation indexes remain in their
active business queries; D5 owns their combined cost qualification.

13 actual KVK native cases and127 combined native/caller/source cases passed.
Exact business and unchanged child-source comparisons run in CI; all17 fixed
candidate mutation refusals pass. D4 installed/signing/manual compatibility and
D5 scale/cost remain. No production SQL or installation occurred.

## D3g final report and backup request ownership

The report core keeps its admission headroom checks and stage receipts. Dashboard
SAMPLE25 and summary FULLSCAN/completion CHECKPOINT become scoped final_stats work,
registered inside each corresponding stage transaction. The shared schema guard
now also protects the legacy report entry before output changes.

MaintenanceBackupWork is one coalesced row, separate from historical unowned queue
rows. The backup claim observes committed summary demand independently of statistics
headroom or outcome, only when the optional legacy queue installation is present. Claim requires its own
autocommit session and retains the existing physical maintenance guard throughout
Python dispatch and exact claim/generation acknowledgement. Missing physical owner
means unknown outcome; failed/unknown attempts never age out or replay. Newer demand
is retained when an older request is acknowledged. Requested means acknowledged
dispatch, not completed backup. No production Agent call was used in qualification.

D3g disposable native tests cover real statistics and CHECKPOINT, stage intent
rollback/commit, worker exclusion, backup live owner, orphan unknown, exact ACK,
ACK persistence failure and continued refusal to replay. Business-preservation
checks compare every retained core byte and preserve the eight-column result.
D4 still owns installed permissions/signing/manual compatibility and the missing
msdb wrapper source qualification; D5 owns scale/cost. No deployment authority.
