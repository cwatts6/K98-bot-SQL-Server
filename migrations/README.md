# SQL Migrations

## S11 merged source closeout — 2026-09-25

SQL PR #89 is merged at `aa7b01381e2e451368c9b7118891a9b960bed9d9`;
reviewed head `0aab5d74e116291bde9b027e44ca819fa35db03c`. Local main/origin main match.
All original delivery filenames/blobs, including both SQL delivery documents, were verified
against the retained final publication manifest. Final source evidence: 193 evidence assertions,
454 permission assertions and five error-free ScriptDom parses; portable manifest paths and
LF hash pins verified. Separate correction Changes review, Deep off,
`6637beed-5f86-408a-b777-0aa1c7e9c561` completed with zero findings. These are source/static
results, not SQL installation, actual restore, transaction/concurrency or provider proof.

Bot mirror #281 and production Bot #588 are also merged. The operator reports nothing updated
on the bot machine. The [companion Bot-mirror PR #282](https://github.com/cwatts6/K98-bot-mirror/pull/282)
contains the source closeout and new S11 G4 planning/controlled rollout/G5 pack and starter.
Those documents control the next phase: **G4 plan
development only**, with exact targets, operations, prerequisites, evidence, rollback and
approval checkpoints. Live read-only inventory also needs exact target approval. Later rollout
executes only approved operations; G5 acceptance remains operator-owned. No SQL execution,
provisioning, deployment, activation or predecessor rerun is authorized by this closeout.

On 2026-09-25 the operator explicitly authorized a separate SQL documentation closeout PR for
`docs/SQL_DELIVERY_LOG.md` and `migrations/README.md`, alongside the Bot-mirror repair/handoff PR
for parallel review. This supersedes the earlier deferral until an implementation PR for these
two entries. No SQL code changes are introduced. Security scan and SQL execution are skipped
precisely for the Markdown-only delta; existing runtime review evidence is preserved. Earlier
dated sections below retain their historical scope/status and do not reopen implementation.
Preserve all S6/S8 gates, both uncertain publications, data, receipts and ownership evidence.
Rollback remains closed admission and drain/reconciliation, with forward fixes for installed SQL;
never blind retry or release claims by age/job state.

## S11 approved NULL guard correction — 2026-09-24

The operator approved the local correction scope and continued closure of remaining S11
implementation gaps. The uninstalled 20260924_001 draft now rejects a NULL request-event
ExpectedVersion and unavailable definitions for each of its five evidence APIs. Its exact
embedded payload and installed-body comparison remain aligned with the source snapshot.
The narrow disposable fixture rejects unknown permission and administrator-token observations.
The source checker validates all concrete guards and both copies of every procedure body.

These are source corrections only. No SQL execution, installation, grant/key/proxy operation,
provider request or deployment occurred. Existing business modules and 20260924_002 remain
unchanged. The six corrected SQL paths are this document, the other delivery document,
migrations/20260924_001_export_execution_evidence.sql,
sql_schema/dbo.usp_ExportProviderRequestEventAppend.StoredProcedure.sql,
deploy/Test-ExportExecutionEvidenceContracts.ps1 and
validation/kvk_source/s11_export_execution_evidence.sql.

The earlier completed Changes review is tied to its exact pre-correction digest. The corrected
SQL source requires a new separate Changes review, Deep off. The authored negative/positive
engine cases remain unexecuted and operator-owned G4 work with exact target, backup/actual
restore, restricted identity and retained-row evidence. Preserve all SQL closeout history;
include these documents in the next actual authorized SQL implementation PR, separately
from Bot. No standalone documentation publication or predecessor rerun.

Before installation rollback is continued non-installation. If the draft is found installed
or published, do not edit deployed history; scope an additive forward fix. Retain all claims,
evidence rows, certificates, uncertain publications and earlier S6/S8 artifacts.


## S11 approved legacy module permission authoring — 2026-09-24

The operator approved the additional local source/static/offline permission-isolation
scope. This is authored source, not SQL installation or evidence of production failure.
Existing procedure bodies, merged migrations, configuration queries and retained data
remain unchanged. The current implementation consists of these exact new SQL paths:

- migrations/20260924_002_export_legacy_module_permissions.sql
- migrations/rollback/20260924_002_export_legacy_module_permissions_rollback.sql
- deploy/export_legacy_module_permission_manifest.json
- deploy/Test-ExportLegacyModulePermissionContracts.ps1
- validation/kvk_source/s11_export_legacy_module_permissions.sql

The manifest pins 37 procedures plus dbo.fn_NormalizeGovernorNameKey. Only UPDATE_ALL2,
sp_TARGETS_MASTER and SP_Stats_for_Upload receive root signatures. Twenty-three matching
child countersignatures preserve the required capability through their reviewed call
chains; a countersignature gives no privilege to a direct caller. Existing EXECUTE AS
OWNER on ACQUIRE_KS4_IMPORT_LOCK and sp_Upsert_ProcConfig_From_Staging remains unchanged.
The three fixed KVK ingest/recompute/export roots receive no elevated signature.

The three public-only certificates have separate import/target/stats capabilities.
Import/target certificate users need schema ALTER plus CREATE TABLE/VIEW and schema
SELECT/INSERT because existing modules create and replace numeric-season output objects.
These capabilities are never granted to the Bot. Import alone gets CHECKPOINT and the
master certificate-mapped login's bulk/performance permissions; master certificate-user
EXECUTE is limited to xp_cmdshell and xp_fileexist. No sysadmin, CONTROL SERVER, signing
key, proxy credential, xp enablement, Bot login or application role membership is added.
The newly created ExportLegacyEntryReader role has exactly the seven public entry grants.
Metadata visibility and the Bot's other existing fixed-table grants require their own
exact G4 principal plan; this is not a whole-application permission certificate.

Installation is restricted to SQL Server 2022 and ROK_TRACKER, which existing source
explicitly names. The source-equivalence hash normalizes CRLF, outer whitespace and the
CREATE/ALTER introducer only. Independently approved signature blobs still bind the exact
installed bytes. Session-local #S11LegacyDeployment and #S11LegacySignatures inputs must
match the fixed manifest; they are release inputs, not embedded sample credentials.
Certificates must already be independently provisioned as public-only; the import public
encoding must be byte-identical in ROK_TRACKER and master. Unknown names, source drift,
partial state, added signatures, inherited signing roles or changed grants refuse.
Exact reapplication validates the existing delivery; it never signs newly observed code.

Before G4, keep admission closed and obtain exact backup plus actual restore evidence,
source/installed definition and dependency/output-shape comparison, approved public keys
and signature blobs, principal visibility/grant plan, proxy identity and Windows file
ACL evidence. The Bot observation uses the producer's own connection and binds its
database/default schema, effective permissions, source bodies and certificate metadata.
Missing or extra metadata refuses before the legacy producer is entered. Source metadata
checks do not prove nested execution, transactions, provider behavior or deployment.

The separate disabled Bot SQL fixture requires an explicitly named disposable SQL
instance with database ROK_TRACKER; the ordinary K98_S11_Disposable_* database fixture
is unchanged. It authors restricted-login child/evidence denial checks and the original
configuration helper's denied-TRUNCATE/DELETE fallback, caller-owned transaction state
and rollback under both XACT_ABORT settings. No result is claimed until G4 executes it.
Actual root/nested calls, bulk/proxy behavior and complete output/dependency contracts
remain separate operator-owned cases, with exact resources and retained evidence.

Before installation rollback is continued non-installation. The authored inverse requires
the original packet with action rollback, exact unchanged signatures/grants and delivery
marker, and no remaining entry-role membership. G4 first closes admission and completes
owned drain/reconciliation. Reversal removes only this delivery's signatures, grants and
principals; certificates, signature inputs, all claims/journals and both uncertain S6
publications remain. Drift needs a reviewed reverse/forward plan, never blind revocation.
Migration-history handling and actual restore evidence are part of that exact G4 plan.

SQL Changes review, Deep off, is required for this separate permission-bearing delta once
the SQL patch is settled. Static parsing/checkers and offline Bot tests are not deployment
approval. All pending SQL closeout documents accompany the next actual authorized SQL
implementation PR separately from Bot delivery; no standalone documentation PR.

## S11 approved fresh-file enrollment source — 2026-09-24

The operator approved local enrollment authoring. Add dbo.ExportManagedFileOrigin and
dbo.usp_ExportOutputEnrollmentTransition; extend the pending stream/admission/request/proof APIs,
uninstalled 20260924_001_export_execution_evidence migration, static checker and disabled fixture.
This adds one evidence entity/procedure to the preceding five/four and changes no merged migration.
Migration checks require either none or all eleven S11 objects, exact definitions/metadata and
separate authority/reader permissions; incompatible installations require reviewed forward fixes.

Enrollment starts a new typed output_enrollment preparation under account/resource/owner CAS;
it cannot adopt a configuration claim or overtake ready/uncertain work. A fixed creation request
must succeed and close before the returned FileID is bound under current ownership. Existing
resource/origin/registered identities are refused. Created and eligible origin rows append without
updates, with unique file/stage, ordinal/stage and request/stage identities and non-cascading FKs.
Eligibility seals one closed grant/private-readback transcript for the entire 3–17-file plan.
Eight-pool capacity includes unregistered plans; incomplete plans retain all ownership/evidence.

Origin preparation streams enter the complete catalogue even before a file ID existed. SQL proof
issue requires eligible origins, as does Bot settlement within its existing locked transaction.
Private-byte/provider interpretation remains the narrow trusted parent responsibility. Schema,
role text and source checks are not installation, effective-permission, transaction, provider,
OS-containment or actual restore evidence. Every new live fixture remains opt-in and unexecuted.

Exact SQL changes: sql_schema/dbo.ExportManagedFileOrigin.Table.sql;
sql_schema/dbo.usp_ExportOutputEnrollmentTransition.StoredProcedure.sql;
sql_schema/dbo.ExportExecutionStream.Table.sql;
sql_schema/dbo.usp_ExportExecutionStreamTransition.StoredProcedure.sql;
sql_schema/dbo.usp_ExportProviderRequestEventAppend.StoredProcedure.sql;
sql_schema/dbo.usp_ExportReconciliationProofIssue.StoredProcedure.sql;
migrations/20260924_001_export_execution_evidence.sql;
validation/kvk_source/s11_export_execution_evidence.sql;
deploy/Test-ExportExecutionEvidenceContracts.ps1; these two existing SQL documents.

No SQL/provider/Discord execution, credential provisioning, publication, predecessor rerun or
deployment occurred. Complete issuer/caller composition and settled separate SQL Changes review
(Deep off) remain pending. Retain all prior documents and the S6/S8 uncertainties/evidence. Include
these SQL closeouts with the next actual authorized SQL implementation PR, separately from Bot;
no standalone documentation PR. Rollback now is non-installation; later retain all evidence and
use a reviewed forward fix, never reset versions, erase unknown files or restore a direct writer.


## S11 Bot foundation installation-contract alignment — 2026-09-24

No SQL executable source changed in this continuation. Approved Bot source now reads the actual
SchemaMigrationHistory columns MigrationId/ChecksumSha256/Status and fixed metadata for 28 required
coordination/evidence/dependency objects, covering S10A/C/D/E plus S11. All 28 object reference files
and five migration files were located in this authoritative repository; nine fixed SELECT batches
were captured with a fake connection and parsed by ScriptDom. No SQL connection or execution took
place. Prior static authoring evidence is retained as history, not installation evidence.

The explicit authority launcher requires a protected approved sql_contract and checks installation,
target/principal, role membership and effective evidence-table/procedure permissions before a
session/store/provider host can be created. Installed metadata must match independently reviewed
expected hashes; startup never accepts its own observation as its expected contract. Evidence
tables must not be directly writable, and Bot readers must not execute authority procedures.
Source tests cannot establish real SQL metadata semantics, permissions, DDL exclusion, isolation
or installation. Those require the exact G4 target/operation approval and retained measurements.

Bot's affected offline suite passed 747 tests with six gated skips. Complete trusted ProofID
production, caller/shared-writer and registration/storage bindings and remaining deployment gates
are still unfinished and disabled. Separate settled Bot/SQL Changes reviews require Deep off.
Both pending SQL closeout documents remain in the next genuine SQL implementation PR separately
from the mandatory Bot union. No Git publication, installation, provider action or deployment was
performed; G4/G5 and preserved predecessor uncertainty remain operator-owned.


## S11 interrupted-owner probe source checkpoint — 2026-09-24

The approved uninstalled S11 stream admission/event pre-dispatch source now permits the exact
retirement interruption transition: the uncertain job remains at its current owner/fence/version,
while its retained owned nested journal is exactly one version earlier. This exception requires
Purpose='probe'; mutations still need the current nested version. Arbitrarily older versions,
running-job adoption and altered owner/token/registration/resource membership remain rejected.

Exact SQL edits: migrations/20260924_001_export_execution_evidence.sql;
sql_schema/dbo.usp_ExportExecutionStreamTransition.StoredProcedure.sql;
sql_schema/dbo.usp_ExportProviderRequestEventAppend.StoredProcedure.sql; and
deploy/Test-ExportExecutionEvidenceContracts.ps1. Merged predecessors are unchanged. No SQL
installation, procedure execution, principal mapping or transaction fixture was performed.

Fresh checks: 125 source assertions passed; ScriptDom parsed 11 inputs; four weakened nested-owner
predicates plus eight catalogue and six closing-probe variants were rejected. Bot's affected
offline suite passed 689 tests with six opt-in skips. The Bot fixed publication evaluator preserves
receipt bytes and verifies fresh readback again from the closed private transcript. It issues no
ProofID and does not establish excluded external writers or deployment coverage.

Complete trusted issuer/readiness/caller composition, separate SQL Changes security review with
Deep off, and exact G4 installation/role/transaction/concurrency/provider evidence remain pending.
Both pending SQL closeout docs belong to the next genuine authorized SQL implementation PR,
separate from the Bot union. G4/G5 remain operator-owned. Keep all inherited evidence/uncertainty;
rollback preserves the uninstalled patch now and uses reviewed forward repair after installation.


## S11 complete recorded-catalogue checkpoint — 2026-09-24

The approved uninstalled S11 proof-issue source now independently enumerates every account stream
touching the registered file set, checks exact closed membership and verifies the complete v2
count/hash plus the fresh snapshot/registration-bound probe. The bounded receipt does not cap or
truncate retained history. Absence separately rejects any dispatched mutation from the probe's
exact publication job, including former nested owners and files outside the current scope.
Older successful jobs remain in catalogue coverage without being treated as this job's dispatch.

Exact SQL source paths: migrations/20260924_001_export_execution_evidence.sql;
sql_schema/dbo.usp_ExportReconciliationProofIssue.StoredProcedure.sql; and
deploy/Test-ExportExecutionEvidenceContracts.ps1. Merged predecessors are unchanged. An already
installed incompatible S11 definition is refused and needs reviewed forward repair. No schema,
permission, transaction, provider or deployment operation was executed.

Fresh validation: 121 static assertions; 11 ScriptDom inputs parsed; eight weakened catalogue
variants and six closing-probe variants rejected. Bot's affected offline suite: 653 passed,
six live-only opt-ins skipped. Python pins a hash vector; SQL cross-engine execution, catalogue
contention/lock duration and effective rights remain G4 evidence gaps. Bot consumes proofs under
the same owning settlement transaction and rejects later recorded writers, even already closed.

This is recorded S11 history coverage, not proof of pre-S11 finality or excluded external writers.
Trusted outcome issuance, immutable readiness and full production composition remain incomplete
and disabled. Separate SQL Changes review, Deep off, remains required on the settled patch.
Both SQL closeout documents remain in the next genuine SQL implementation PR separately from
the mandatory Bot document union. G4/G5 remain operator-owned; preserve all retained uncertainties.


## S11 actual-adapter read contract checkpoint — 2026-09-24

Under the existing local source approval, the uninstalled S11 evidence migration and
sql_schema/dbo.ExportProviderRequest.Table.sql now classify sheets.values.batchGet as a read,
matching the actual new-source export verification helper. The fixed operation list assertion in
deploy/Test-ExportExecutionEvidenceContracts.ps1 covers this contract. No predecessor migration,
installed database, transaction, permission or provider state was changed.

Fresh source validation: 108 assertions passed; 11 ScriptDom inputs parsed; six weakened source
variants rejected. Bot's affected offline suite passed 611 cases, with six opt-in SQL/Windows
cases skipped. Bot additionally closes delivery/retirement/recovery streams before release/reuse;
that DAL ordering uses the already-authored evidence table and introduces no further SQL schema
change. These checks are not installation, SQL transaction, containment or provider proof.

Complete trusted historical coverage/readback/proof issuance, immutable readiness and full
production composition remain incomplete and disabled. Separate SQL Changes review, Deep off,
remains for the settled patch. Preserve both pending SQL closeout docs with the next genuine SQL
implementation PR separately from Bot. No Git publication or predecessor execution occurred;
G4/G5 remain operator-owned and all retained data/uncertainties stay intact.


## S11 closing-operation probe continuation — 2026-09-24

Under the existing local source implementation approval, the uninstalled S11 stream contract
now retains null OwnerID/Fence 0 only for an operation's read-only closing probe. Admission and
request pre-dispatch repeat exact resource versions, closing pool reservation/registration/epoch
and closing/draining operation CAS. No new worker owner, claim release, fair-ticket advancement
or mutation authority is created. Sorted resource locks precede the pool lock and operation row.

Exact executable source changes: migrations/20260924_001_export_execution_evidence.sql;
sql_schema/dbo.ExportExecutionStream.Table.sql;
sql_schema/dbo.usp_ExportExecutionStreamTransition.StoredProcedure.sql;
sql_schema/dbo.usp_ExportProviderRequestEventAppend.StoredProcedure.sql; and
deploy/Test-ExportExecutionEvidenceContracts.ps1. The migration's prerequisite metadata check
now includes KVK.SourceOutputPool. This revises uninstalled S11 authoring only; merged predecessor
scripts are untouched. An already installed incompatible S11 shape would be refused and require
a separately reviewed forward fix, not an automatic schema rewrite.

Offline checker: 107 assertions passed; ScriptDom: 11 source files parsed; six weakened source
variants rejected. Bot affected suite: 344 passed, six opt-in SQL/Windows cases skipped. The Bot
SQL fixture optionally accepts closing_probe_scope in its exact approved disposable-target
packet and retains synthetic evidence. Its read is recorded not_sent, never provider success;
the fixture cannot supply real closure/finality evidence. It was authored, not executed.

No SQL connection, installation, transactions, provider/Discord call, predecessor fixture rerun
or Git publication occurred. Complete trusted historical coverage/readback/proof issuance,
immutable readiness and all-caller composition remain incomplete and disabled. Separate SQL
Changes review, Deep off, remains pending for the settled patch. Preserve both pending SQL
closeout documents with the next actual authorized SQL implementation PR, separately from Bot.
G4 and G5 remain operator-owned; all retained uncertainties, claims and evidence remain intact.


## S11 proof-consumption continuation — 2026-09-24

The uninstalled S11 evidence migration and exact table/procedure snapshots now constrain Outcome
by ProofKind, including completed for rollover_complete. The proof-issue procedure requires body
state/snapshot agreement and an actual successful read in the matching closed probe. Exact SQL
executable changes: migrations/20260924_001_export_execution_evidence.sql,
sql_schema/dbo.ExportReconciliationProof.Table.sql, and
sql_schema/dbo.usp_ExportReconciliationProofIssue.StoredProcedure.sql.

Offline checker: 87 assertions passed; ScriptDom: 11 source files parsed. No database connection,
installation, transaction/provider execution or predecessor rerun. Bot now consumes ProofID in six
existing settlement transactions and verifies private journals; its complete proof issuer, launcher
and all-caller composition remain incomplete and disabled. Separate Changes security review with
Deep off remains pending. Preserve all historical records and the separate SQL PR grouping.

## S11 evidence implementation checkpoint — 2026-09-24

Operator approval covers local source implementation of the additive independent-authority evidence
proposal. Authored paths: migrations/20260924_001_export_execution_evidence.sql; five table snapshots
(ExportExecutionSession, ExportExecutionStream, ExportProviderRequest, ExportProviderRequestEvent,
ExportReconciliationProof); four procedure snapshots (usp_ExportExecutionSessionTransition,
usp_ExportExecutionStreamTransition, usp_ExportProviderRequestEventAppend,
usp_ExportReconciliationProofIssue); validation/kvk_source/s11_export_execution_evidence.sql; and
deploy/Test-ExportExecutionEvidenceContracts.ps1. All nine objects use the dbo schema.

Offline checker: 87 assertions passed. ScriptDom parsed all 11 SQL source files. No SQL connection,
installation, transaction/permission/concurrency execution, predecessor rerun or provider operation
occurred. The guarded disposable-target fixture is opt-in and covers only its authored cases;
it does not establish the full stream/request/proof acceptance matrix. Bot trusted proof production,
settlement integration and complete closed composition remain unfinished. Source is not release-ready.
Separate SQL Changes review with Deep off remains pending on the settled patch. G4/G5 stay operator-owned.

Keep these two previously pending SQL closeout documents with the next genuine authorized SQL
implementation PR, separately from Bot documentation. No Git publication occurred. Do not remove
retained claims, receipts, request history or either uncertain publication; no historical evidence is
backfilled. Current rollback is non-installation and preservation of local source/evidence.

## Current S10E merged closeout — 2026-09-15

[SQL PR #88](https://github.com/cwatts6/K98-bot-SQL-Server/pull/88) merged at 20:30:08 UTC
as `2352a898881d4b74d6eec153bb3cb381d6162041`; local main/origin main match. Reviewed head:
`c19c37988c9854d0474369244608962e1a053698`. All eight filename/content identities were verified
against the reviewed manifest, merged PR and local refs. Both pending SQL documentation edits
were delivered. Production Bot #587 and mirror #280 also merged; local Bot mirror was synchronized.
**No changes have been pulled to the bot machine.**

S10E operation/resource ownership authoring and review are complete. Static checker: 428 assertions;
T-SQL syntax checks and independently stale owner/fence/version fixture controls passed. The guarded
transaction fixture remains authored and unexecuted. SQL C/D/E installation, actual transactions,
provider/Discord behavior, bot deployment and activation are not established by merges or CI.
Corrective Changes review `909679f7-d8ff-41f5-900b-8b6a2ed9797d`, Deep off, has zero findings;
Bot's final reviewed recovery correction uses these same SQL contracts without another SQL delta.

Next is S11 Controlled Release and Acceptance, initial review/scope in Bot. The authoritative Bot
handoff is named s10e_closeout_and_s11_handoff.md in its KVK migration reference directory. It
records exact delivered/pending identities, source/static-versus-runtime limits and the new pack.
S11 must assess real composition/installation gaps and propose exact targets/operations before
approval; no SQL/provider action or predecessor rerun is authorized by this closeout.

These new closeout edits to `docs/SQL_DELIVERY_LOG.md` and `migrations/README.md` MUST travel in the
next genuine authorized SQL implementation PR, separately from all Bot documents. If S11 has no
actual authorized SQL delta, retain both pending. No standalone docs PR, mixed histories or
manufactured SQL work. Verify exact filenames/content at head and merge, not counts. Preserve all
S6/S8 data, uncertain publications, original 50-document recovery hashes/ZIPs and updated manifests.

Documentation-only security skip: this exact two-Markdown-file patch at the SQL merge above changes
no schema, executable fixture, configuration, data access or deployment behavior. No installation,
execution or runtime gate is closed. Earlier current/next-slice blocks below are historical.

## Historical S10D merged closeout — 2026-09-15

[SQL PR #87](https://github.com/cwatts6/K98-bot-SQL-Server/pull/87) merged at 10:57:04 UTC
as `80353a6280e523f30c27e724f71e7b47dadadd16`; local main/origin main match. Final PR head:
`0eb5494976627bcb6efaea40e11adcb0cf231344`. All eleven filename/previous_filename identities
and delivered blobs were checked against head, merge and local refs. Both pending SQL documents
were delivered. The migration remains `20260915_001_kvk_output_pool_rollover.sql`.
Both corrected CI runs (34960113322 and 34960108335) passed. The final Changes security scan,
Deep off, completed with zero findings; later edits were documentation-only.

S10D establishes static physical identity, scope-correct references and additive shape. S10E owns
transaction owner/fence/version CAS, monotonic epochs, append-only writer APIs, complete capacity
preflight and provider proof. The 463 static assertions, 101 parse inputs and 11 rejected mutations
are offline evidence; 90 authored SQL cases/seven modes remain unexecuted. S10C/S10D SQL installation
is unproven. No predecessor rerun, database/provider/Discord operation, deployment or activation.

Bot main/origin main remains `bf3eccf964601e2975dd86eefe96f7b0153be3bb`; production/main remains
`aa1821adbde9ccda47797caa83b5d5a9958bfce9`. **No changes have been pulled to the bot machine.**
Next is S10E initial review/scope only in Bot. Its `s10d_closeout_and_s10e_handoff.md` contains
the current exact pending Bot documentation manifest, superseding the historical fifty-path table
below. All fifty lost entries were recovered against their original hashes before closeout edits.
S10D pack/starter are archived; include every pending Bot document, both S10C move sides, S10D
archive destinations and new S10E pack/starter in the eventual authorized Bot implementation PR.
Verify filename AND previous_filename or explicit content/base-absence proof; counts are insufficient.

These new changes to `docs/SQL_DELIVERY_LOG.md` and `migrations/README.md` are pending after #87.
Carry BOTH into the next genuine authorized SQL implementation PR. If S10E identifies an actual
SQL gap, scope it separately; otherwise retain both for the next SQL implementation. No standalone
docs PR, mixed repositories, manufactured runtime work or renewed grouping/predecessor approval.
Preserve historical receipts, uncertain ownership, all S6 gates and both uncertain publications,
and distinct S8A/S8B/S8C retained evidence. Earlier checkpoints below are historical.


## Historical S10D authoring checkpoint - 2026-09-15

The operator approved the eleven-path SQL-only scope and offline validation. S10D is now
authored locally; it is not published or installed. The migration is
`20260915_001_kvk_output_pool_rollover.sql`: actual creation date and free ordinal checked
before authoring. No merged predecessor migration was changed or rerun.

The new file registry prevents pool-index/slot aliasing; pool, current-slot and disposition
tables retain scoped ownership/history evidence. Two additive attempt/part reference keys
complete exact FKs. S10E owns transaction CAS, append-only writer APIs, monotonic lifecycle
transitions and provider proof; static shape does not certify remote privacy or safe reuse.

S10C prerequisites remain source/static evidence, not installation proof. SQL main/origin
main remains `a03835a12feb0d52374e00206f944a02d8937fbd`. Bot main/origin main remains
`bf3eccf964601e2975dd86eefe96f7b0153be3bb`; production/main remains
`aa1821adbde9ccda47797caa83b5d5a9958bfce9`. No changes have been pulled to the bot machine.

Both previously pending SQL documents are preserved in this implementation. Every pending
Bot document and both sides of both S10C archive moves remain assigned to the next authorized
Bot implementation PR, currently S10E; see the exact tracking table in SQL_DELIVERY_LOG.md.
No standalone documentation PR, mixed repository delivery, manufactured Bot work or renewed
predecessor/grouping approval. Git publication, SQL/provider/Discord execution, deployment
and activation are separate gates. Earlier dated checkpoints below remain historical.


## Historical KVK status — S10C merged and locally pulled; S10D scope next, 2026-09-15

SQL [#86](https://github.com/cwatts6/K98-bot-SQL-Server/pull/86) is merged at
`a03835a12feb0d52374e00206f944a02d8937fbd`; local main/origin main match. Final reviewed head:
`bf87ca2b3d8795abb1a02764d390f8a87f51f5ad`. S10C's eight-path preparation patch and both pending
SQL documents were delivered. The inherited-resource validator, pending-owner restriction and Actor
BIN2 correction are included. Static validation and seven checker variants are retained evidence;
no S10C migration/fixture/database execution, SQL deployment or activation is claimed.

Bot mirror #279 and production #586 are merged and locally pulled. Bot main/origin main is
`bf3eccf964601e2975dd86eefe96f7b0153be3bb`; production/main is
`aa1821adbde9ccda47797caa83b5d5a9958bfce9`. **No changes have been pulled to the bot machine.**
The final Bot offline suite passed 4,514 tests with 67 skips; this is not SQL execution evidence.

Next is S10D Output Pool and Rollover SQL Foundation, initial review/scope only. Its Bot-repository
task pack and `s10c_closeout_and_s10d_handoff.md` control the handoff. The S7 six-path SQL proposal
plus this repository's `migrations/README.md` must be reconciled before implementation approval.
Resolve the migration's actual creation date and free daily ordinal during scope; never rename a
merged migration or use the historical proposed date blindly. No S10D schema objects are created now.

Both `docs/SQL_DELIVERY_LOG.md` and `migrations/README.md` are newly pending documentation updates
and MUST accompany the next authorized S10D SQL implementation PR. Verify exact filename and
previous_filename coverage or exact merged/absent-at-base proof, not counts. Bot documentation and
S10C task archive moves remain in Bot for its next authorized implementation PR, currently S10E;
S10D must track that manifest without copying it into SQL or opening a standalone docs PR.

Preserve S6-OPS01/PERF01/CAP01, both uncertain publications
`e19c89ac-7977-5f28-ae4c-031807cd1728` and `54a2480a-26fb-5bad-a3f5-9321525a731c`, and all retained
databases/files. Keep S8A six-script/VERIFYONLY, S8B 50-case/actual-restore versus offline history,
and S8C seven local checks distinct. Predecessor acceptance is not reopened; no rerun is authorized.
Documentation-only security skip: no code, schema, configuration, permissions or persistence changes.
No implementation, Git publication, SQL/provider/Discord execution, real import/export, bot-machine
pull/restart, deployment, activation or automatic task is authorized. Earlier dated entries are historical.

## Historical S10A publication checkpoint — 2026-09-14

> Current KVK status, 2026-09-14: S9B repository delivery is complete. SQL #84,
> Bot mirror #277 and production #584 are merged and locally pulled; the bot machine is unchanged.
> S10A Shared Export Coordination SQL Foundation is implemented and published in
> [SQL PR #85](https://github.com/cwatts6/K98-bot-SQL-Server/pull/85), pending review and merge.
> Approved disposable validation is complete: backup/actual restore, all five fixture modes,
> 76 unique structural cases in both install and constraints, and direct apply/rerun passed.
> Retained databases and evidence are preserved; merge and deployment remain separate.
> Both delivery-log and migration-README updates are included in that S10A SQL
> implementation PR. Bot handoff documentation stays in Bot for the next Bot implementation PR,
> S10B; no standalone documentation PR. Earlier status/publication checkpoints are historical.
> No SQL execution, bot-machine pull, deployment or activation is authorized by this update.



This folder is the deployable source for intentional SQL changes.

Schema snapshots in `sql_schema/` are generated reference material. Do not deploy from
snapshots directly unless an approved emergency recovery plan requires it.

Notable deployed SQL milestones that need cross-repo closeout context may also be recorded in
`docs/SQL_DELIVERY_LOG.md`. That log is informational; migration files and
`dbo.SchemaMigrationHistory` remain the deployment source of truth.

## Naming

Use sortable migration names:

```text
YYYYMMDD_NNN_short_description.sql
```

Example:

```text
20260602_001_add_schema_migration_history.sql
```

Rules:

- Date is the migration creation date.
- `NNN` increments per day.
- Description uses lowercase snake case.
- The migration ID is the filename without `.sql`.
- Never rename a migration after it has been merged.

## Header

Every migration must start with this metadata block:

```sql
/*
MigrationId: 20260602_001_add_schema_migration_history
Purpose: Add SQL migration tracking table
Author: cwatts
CreatedUtc: 2026-06-02
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: N/A
PostValidationQuery: N/A
RelatedBotPR:
RelatedSQLPR:
*/
```

## Rollback

Rollback is explicit, not assumed.

- `Included`: a matching script exists in `migrations/rollback/`.
- `Manual`: rollback notes are in the migration or release notes.
- `Forward Fix Only`: do not roll back; correct the issue with a new migration.
- `Not Possible`: recovery requires restore from backup or bespoke manual recovery.

When `Rollback: Included`, set `RollbackScript:` to:

```text
migrations/rollback/YYYYMMDD_NNN_short_description_rollback.sql
```

The rollback file must include a `RollbackForMigrationId:` header and be reviewed with the forward
migration. Do not create a rollback file when it would imply safety that does not exist.

## Data Safety

Use `DataChange: Yes` when a migration updates, deletes, truncates, backfills, transforms, or
otherwise changes existing data. Schema-only changes can normally use `DataChange: No`, but schema
changes with material data risk should still include a safety plan.

`DataSafetyPlan:` values:

- `Not Required`: no existing data is changed and no material data risk is expected.
- `Required`: the PR or migration notes must include the data safety plan before deployment.
- `Included`: the migration header/comments include the preview, transaction, validation, and
  rollback or forward-fix notes.

For high-risk data changes, include:

- expected row-count range
- pre-validation query
- post-validation query
- backup confirmation
- transaction and locking notes
- rollback or forward-fix plan

See `docs/SQL_DATA_MIGRATION_GUARDRAILS.md`.

The deploy runner prevents repeat execution through `dbo.SchemaMigrationHistory`; individual
migrations should still be idempotent where that is genuinely safe.


## Historical S8B authoring checkpoint â€” 2026-09-13 (before disposable execution)

The operator approved closing the recorded S8B gaps. Migration
`20260913_001_kvk_source_update_no_fight_context.sql` adds required `SourceUpdate.PeriodKind`
copied from the immutable period and rebinds the scoped kind FK to that classification.
`UpdateKind=no_fight` may then apply to an existing fight period without changing its identity.
The new mode check rejects all other cross-kind combinations; existing equal-player-input,
no-aggregate, readiness and scoped revision/configuration constraints remain intact. The Bot
additionally requires explicitly confirmed equal configured endpoints and exact revisions.
No historical ID, hash, confirmation, state, selection, intent or publication is rewritten.

Execution remains separately gated: provide exact target, backup/restore and metadata preview
receipts plus expected update count in `#S8BNoFightApproval`. Review `preview`, then separately
approve `apply` with all source writers idle. This batch owns its transaction and is intended
for the reviewed same-session runner path documented below. Ordinary pending deployment stops
before applying migrations if S8B inputs are missing. No predecessor is rerun implicitly.
Deploy the amendment before the revised S8B writer; older inserts omit the required column
and fail closed. Retained no-fight fight-period updates require forward fixes, not a downgrade.
Disposable validation must prove preview/apply/rerun, rollback, FK/check rejection and retained
history identity before deployment. No SQL connection or execution is claimed by this entry.


## S8B reviewed runner inputs â€” PR #81 review follow-up

Use Deploy-SqlMigration.ps1 with exact MigrationId
`20260913_001_kvk_source_update_no_fight_context`, explicit ServerName and DatabaseName,
and S8BInputFile plus its S8BInputSha256. The input is a separately reviewed UTF-8 SQL prelude
creating and populating exactly one `#S8BNoFightApproval` row with Mode=apply, exact target,
backup/restore evidence, preview evidence and expected row count. It must not open a transaction.
The runner verifies the input bytes against SHA256 and rejects SQLCMD directives before opening
the migration connection. Prelude, apply/history guard and migration run on that same connection.

The guard requires SchemaMigrationHistory and refuses preview mode. Only a successful migration
returns to the existing Applied-history writer; failures take the Failed-history path. If the
history write fails after schema commit, a newly reviewed exact count/evidence packet permits the
migration's verified idempotent rerun to complete history. No manual history deletion or fake
Applied record is a supported recovery path. Preview remains a separately approved operation and
must never be recorded as Applied. This runner support does not grant SQL execution permission.

Offline regression coverage in Test-S8AMigrationInputs.ps1 now covers both S8A and S8B: exact
argument gates, hash/directive rejection, one-connection batch order, guard failure/disposal,
pending-migration rejection, S8B dispatch and Applied/Failed history ordering with mocked SQL.
The S8A entry point and guard are retained through the shared reviewed-session executor.
No live deployment-runner or migration-history execution is claimed by these offline checks.

## S8C local authoring checkpoint - 2026-09-13

Operator approval covers authoring the S8C review table, additive migration,
disposable-only validation fixture and read-only static contract checker. The exact
SQL union is these four new paths plus this log and migrations/README.md:

- migrations/20260913_002_kvk_source_admin_reviews.sql
- sql_schema/KVK.SourceAdminReview.Table.sql
- validation/kvk_source/s8c_admin_reviews.sql
- deploy/Test-KvkSourceAdminReviewContracts.ps1

The checker passes 13 static checks. No SQL was executed; the disposable fixture
and five opt-in Bot SQL tests remain unrun. Deploy this additive table after S8A/S8B
and before the revised intake is enabled, under separate execution approval.
ReviewSequence orders import snapshots only; it never allocates scan IDs.

These six paths belong exclusively to the separate SQL PR. Preserve the existing
S8B delivery record: accepted operator smoke, retained 50-case disposable evidence,
later offline review fixes and offline-only runner history support are distinct.
S8A six-script evidence remains separate. No fresh post-merge or bot-machine run
is claimed. This checkpoint does not authorize Git publication or deployment.

## S8C merged delivery and next steps â€” 2026-09-13

S8C code review and repository delivery are complete. SQL #82 merged at 18:43:41 UTC as
3c1b5ceaa7a686bc594ca8637d0a1569030d66c4 (reviewed head 083718e971acc7d4593610199a5575bd3159b4e8).
Mirror #275 merged at 18:44:03 UTC; production-repository #582 merged at 18:45:13 UTC as
afac4118db4bca282c8d12ea3d121701ae2da3c0. Local SQL main/origin main matches its merge; Bot
main/origin main b6e45293348ece7b562e29c0451a8c3a7dbe2550 is synchronized from production.
All six actual SQL PR file blobs match local HEAD; production's 69 physical Bot paths were
also verified, including archive previous_filename entries. Both worktrees were clean at entry.

Final Bot offline evidence: 4214 passed / 62 skipped, 96 focused tests, operational logs unchanged.
At the repository-delivery checkpoint, hosted Bot and SQL CI passed and the SQL static contract
checker passed 13 checks. The S8C disposable fixture and five opt-in Bot SQL cases had not yet run
at that checkpoint. Their later approved execution for the named disposable target is recorded in
the [disposable execution addendum](#2026-09-13-approved-s8c-disposable-execution-addendum) below.
No bot-machine pull, deployment or activation is claimed. Local whole-repo validation previously
could not write its sandboxed log; hosted SQL validation passed. Earlier entries retain their
dated scope; the addendum supersedes only the named disposable-execution status.

The next implementation slice is S9A Public Routing and Availability, initial review/scope only,
as specified in the approved S7 manifests. See the companion Bot documentation
`s8c_closeout_and_s9a_handoff.md` and S9A pack/starter; completed S8C pack/starter are archived.
Separately scope exact disposable SQL migration/fixture and intake smoke operations for approval
before enabling dependent intake. Apply the additive S8C table after reviewed S8A/S8B prerequisites;
no predecessor rerun is implied. SourceRouting.Enabled alone does not implement public routing.
S9B cards, S10 exports and S11 integration evidence remain later slices.

Preserve accepted S8B smoke and 50-case/actual-restore evidence separately from offline review fixes
and offline-only runner-history support; S8A six-script/VERIFYONLY evidence remains separate.
Preserve S6-OPS01/PERF01/CAP01, both uncertain publications and all databases/backups/files.
This append in docs/SQL_DELIVERY_LOG.md and migrations/README.md is the exact two-path pending SQL
closeout carry-forward against 3c1b5ceaa7a686bc594ca8637d0a1569030d66c4. Deliver it in a separately
authorized SQL PR, never in a Bot PR; omissions require specific merged-content proof.
Security skip: Markdown status/evidence only, no SQL/config/runtime behavior change. No SQL
execution, Git mutation, provider/Discord action or deployment occurs in this closeout.


## 2026-09-13 approved S8C disposable execution addendum

Supersedes the earlier unrun-S8C statements above for this named disposable target only.
Operator approved instance `9SX2VF4\K98DEV`, primary
`K98_S8C_Disposable_20260913_intake`, separate `_restore` database and
`C:/K98-S8C-Smoke/20260913`. New prerequisite fixture backup/VERIFYONLY/actual restore,
S8C migration apply/rerun, rollback fixture and five opt-in S8C SQL tests passed.
The static contract validator passed 13 checks. This used direct SQL execution, not deployment
runner history. S8A/B snapshots were empty prerequisite fixtures; their installers/tests were not rerun.

Real Bot intake/services/DAL used this disposable SQL for synthetic B0, waiting-pair completion,
11âˆ’10/12âˆ’10/13âˆ’10 then authorized 14âˆ’10, later 17/18 assignment, no-fight, independent overall,
weight/camp corrections, explicit synthetic attestation, CAS and semantic duplicate checks.
No production code fix was required. SourceRouting remained disabled and no provider delivery ran.
See [Bot companion PR #276](https://github.com/cwatts6/K98-bot-mirror/pull/276), its
`s8c_folder_intake_smoke_evidence.md`, and retained
`C:/K98-S8C-Smoke/20260913/evidence` for scripts, hashes, failures/resumptions, exact assertions
and limits. Live Discord, real Google kvk_list import and bot-machine smoke are not claimed.

All predecessor evidence, uncertain publications and S6 open gates remain separate and preserved.
These two SQL documentation paths were retained locally at the original closeout checkpoint
and are now committed and published separately in SQL PR #83 for the S9A delivery cycle.
Only documentation changed; no SQL runtime file, deployment or activation changed.

## S9A delivered / S9B documentation carry-forward â€” 2026-09-14

[SQL #83](https://github.com/cwatts6/K98-bot-SQL-Server/pull/83) merged at 10:13:01 UTC as
`278b24b48ed075252217a5525ccb751f8e5bf928`, reviewed head
`810ade56faa25f9e0333e0175b753bfa326190dd`. Local main/origin main match the merge;
the worktree was clean at closeout entry. These are comparison anchors, never reset instructions.
The exact two delivered files were the SQL delivery log and migration README, with local blob
matches. Both SQL static CI checks passed; this documentation-only PR introduced no SQL runtime
change and no migration execution. Historical metadata/CI-link review comments were addressed.

Companion [Bot mirror #276](https://github.com/cwatts6/K98-bot-mirror/pull/276) and
[production #583](https://github.com/cwatts6/K98-bot/pull/583) are merged. Their 56 GitHub entries
cover the exact 58 physical Bot paths after checking filenames and previous filenames for both
S8C archive moves; resulting blobs match synchronized Bot main. The Bot S9A closeout and S9B pack
record current evidence and the fresh pending documentation manifest. S9A's delivered union is
not the next slice's pending carry-forward.

The operator approved these documentation updates on 2026-09-14. Both files are now published
in [SQL PR #84](https://github.com/cwatts6/K98-bot-SQL-Server/pull/84) in the same delivery cycle
as [Bot mirror PR #277](https://github.com/cwatts6/K98-bot-mirror/pull/277). The SQL files are
excluded from Bot. Exact provider filename/previous_filename coverage was verified before
ready-for-review, with no missing paths or already-merged exemptions. The final Bot scope is
23 runtime/test paths after the approved posting amendment; there is no SQL runtime amendment.
Authoritative SQL definitions were validated during Bot implementation.

Retain S8B accepted disposable smoke/50-case and actual-restore evidence separately from offline
runner-history support, S8A six-script evidence and S8C disposable SQL/folder smoke. Chris's seven
local S8C operator checks PASS on 2026-09-14 is not live Discord acceptance. The completed evidence
does not prove production migration application. Preserve S6-OPS01/PERF01/CAP01, both uncertain
publications and all retained databases, backups and files; no predecessor rerun or cleanup.
PR publication was subsequently authorized and completed for the two linked PRs. SQL/provider/Discord
execution, real import/export, bot-machine pull/restart/deployment and activation remain excluded.
Deployment history remains governed
by the migration files and actual SchemaMigrationHistory, not repository merge records.

Security routing: independent documented skip for this exact two-Markdown-file working-tree patch
against `278b24b48ed075252217a5525ccb751f8e5bf928`; no SQL/data-access, permissions, configuration,
execution or persistence behavior changes. No security scan or SQL execution. Validate Markdown
links, exact pending paths and whitespace; runtime SQL checks are intentionally not rerun.


## S9B publication checkpoint â€” 2026-09-14

The operator authorized PR creation following local Bot implementation and review. The final
Bot scope is 23 runtime/test paths plus 35 documentation paths, including the two approved
path amendments. This SQL PR remains limited to `docs/SQL_DELIVERY_LOG.md` and
`migrations/README.md`; no SQL runtime amendment or execution is included. Earlier scope-only
and publication-not-authorized statements describe the historical closeout checkpoint.
The independent documentation-only security skip still applies to these exact two paths.
Bot offline tests and Changes security evidence are recorded in [Bot mirror PR #277](https://github.com/cwatts6/K98-bot-mirror/pull/277)
and the S9B closeout linked from that PR;
they do not establish SQL execution or live Discord acceptance. All retained gates, uncertain
publications, databases and files remain preserved. No merge, deployment or activation occurs.


## S9B delivered / S10A documentation carry-forward â€” 2026-09-14

[SQL PR #84](https://github.com/cwatts6/K98-bot-SQL-Server/pull/84) merged at 13:27:17 UTC as
`d0916f742f9c88743b97107dfca1f3acbcb32c2e`, final reviewed head
`604af8f88e42f43cc80d1848b37312526e56338f`. Both SQL static CI runs passed. Exact provider
coverage is these two documentation paths, with resulting blobs matching local SQL main.
No migration or runtime SQL file was changed by that PR; no SQL execution was performed.

Companion [Bot mirror #277](https://github.com/cwatts6/K98-bot-mirror/pull/277) and
[production #584](https://github.com/cwatts6/k98-bot/pull/584) merged at 13:27:27 and 13:27:58 UTC.
Their exact 56 provider entries cover all 58 physical paths after checking both filename and
previous_filename for both S9A archive moves. Final blobs match synchronized Bot main.
Final Bot offline evidence is 4,350 passed / 62 skipped, operational logs unchanged; final hosted
quality, governance and secrets checks passed. These are retained results, not fresh execution.
No changes have been pulled to the bot machine; no deployment or activation is claimed.

S10A Shared Export Coordination SQL Foundation is next, initial review/scope only, using the
new task pack/starter and S9B closeout retained in the Bot repository. The initial approved SQL
manifest reserves a migration, six general export tables, one SQL validation file and the delivery
log. The migration README is also mandatory, yielding ten initial delivery paths. Resolve the
reserved migration date/sequence during scope before writing SQL. Do not rename merged migrations.

**The eventual S10A SQL implementation PR must include these updated `docs/SQL_DELIVERY_LOG.md`
and `migrations/README.md` alongside its reviewed SQL implementation.** Recheck pending changes
at entry and before PR creation; verify exact filename/previous_filename coverage or explicit
already-merged content proof. Counts alone are insufficient. The Bot-side documentation manifest,
including S9B archive move origins/destinations and S10A preparation outputs, stays in Bot and is
mandatory carry-forward into the next Bot implementation PR (S10B). S10A must preserve and hand
that exact manifest onward. No standalone documentation PR or repository mixing; grouping is
approved and must not be re-requested. Implementation and Git publication need separate approval.

Preserve S6-OPS01/PERF01/CAP01, both uncertain publications and all retained databases/backups/files.
S8B accepted smoke/50-case and actual-restore evidence remains separate from offline runner-history
support, S8A six-script and S8C evidence. S8C seven local checks PASS is not live Discord acceptance.
No SQL/provider/Discord execution, real imports/exports, bot-machine pull/restart/deployment,
activation or predecessor rerun. SchemaMigrationHistory and actual execution records, not PR merges,
remain the deployment truth. SourceRouting.Enabled alone is insufficient.

Security routing: independent documentation-only skip for this exact two-Markdown-file update
against `d0916f742f9c88743b97107dfca1f3acbcb32c2e`. No runtime, data-access, permission, configuration,
dependency or persistence behavior changes. Validate links, documentation references, whitespace
and exact paths. No SQL runtime execution or fresh security scan for this closeout.

## S10A approved local SQL implementation â€” 2026-09-14

The operator approved local implementation and closure of the physical-design gaps.
This is additive SQL authoring, offline validation and Changes security review only.
SQL execution (including disposable databases), provider/Discord operations, imports/exports,
Git staging/commit/publication, bot-machine changes, deployment and activation remain unapproved.
Earlier initial-scope statements above are historical. No S10B/C/D/E or S11 implementation.

### Exact SQL delivery manifest

The uncreated S7 reservation was amended to the actual authoring date and free sequence:
`migrations/20260914_001_shared_export_coordination.sql`. No merged migration was renamed.
The eventual SQL implementation PR must include ALL ten paths below, including both
pre-existing pending documentation files. Check provider filename AND previous_filename,
or supply per-path merged-content proof; counts alone are insufficient.

- migrations/20260914_001_shared_export_coordination.sql
- sql_schema/dbo.ExportJob.Table.sql
- sql_schema/dbo.ExportJobResource.Table.sql
- sql_schema/dbo.ExportResource.Table.sql
- sql_schema/dbo.ExportRequestBudget.Table.sql
- sql_schema/dbo.ExportAttempt.Table.sql
- sql_schema/dbo.ExportAttemptPart.Table.sql
- validation/kvk_source/s10_export_coordination.sql
- docs/SQL_DELIVERY_LOG.md
- migrations/README.md

### Physical contract and closed design gaps

All identity/enumeration text uses Latin1_General_100_BIN2. UUIDs are uniqueidentifier,
digests binary(32), audit timestamps datetime2(0) UTC, budget timestamps datetime2(3) UTC.
There are no application defaults, seed rows, permissions, cascade deletes or activation changes.
Required identifiers reject empty/edge-spaced values; enums reject trailing-space aliases.

| Table | Contract |
|---|---|
| ExportJob | JobID PK; ConsumerKind new_source/all_kvk/scan_data. New-source requires SourceKey=snapshot_report_v1, positive KVK_NO/PoolEpoch and scoped IntentID FK. All-KVK requires positive KVK_NO, no source intent/epoch; scan-data has no season/intent/epoch. AccountKey varchar(128), input/destination hashes; nullable RepairID. Replay UQ includes consumer/account/season/input/destination/epoch/repair, INCLUDING NULL epoch/repair tuples; no filtered NULL escape. SpoolKey varchar(128) is an opaque ASCII alphanumeric/underscore/hyphen token; SpoolBytes positive bigint and StorageOwner varchar(128) are all-or-none, mandatory for legacy/daily jobs. New-source may reload pinned SQL facts without a spool. |
| ExportJob state | waiting/ready/running/confirmed/failed/uncertain/coalesced/cancelled. Unclaimed waiting/ready/coalesced/cancelled have NULL OwnerID and fence 0; attempted running/confirmed/failed/uncertain retain UUID OwnerID and positive fence. Version and EnqueueSequence are positive bigint. Tickets are caller-supplied, not identity or unique: a successor may inherit the original pending ticket while history retains it. Supersession is only coalesced new-source and FK-scoped to consumer/account/season/destination/epoch. Actor nvarchar(128), Reason nvarchar(1024), provenance valid JSON <=65536 bytes. |
| ExportResource / ExportJobResource | ResourceKey varchar(256) PK; kind account/destination/sql_snapshot. JobResource PK(JobID,ResourceKey), both parent FKs and reverse index. Resource active ownership FK references declared membership, preventing an undeclared job claim. ActiveJobID/OwnerID are paired; claimed fence positive; free resources retain a nonnegative fence. BlockedReason nullable nvarchar(1024), Version positive bigint. A blocked resource may remain unassigned for an ambiguous historical association. |
| ExportRequestBudget | PK(AccountKey varchar(128),BudgetKind varchar(32)); initial allowed kind google_request covers both Google client stacks. NextAllowedUTC required, CooldownUntilUTC optional, both datetime2(3). IntervalMilliseconds int 1..86400000; PolicyVersion/Version positive bigint. No seeded budget or implicit quota. Later DAL starts with the retained 2100ms spacing and reserves max(server UTC,next allowance,cooldown) atomically. The interval bound is representation safety, not provider quota; cooldown can extend independently. |
| ExportAttempt | AttemptID PK, UQ(JobID,AttemptNo), positive bigint owner fence/attempt/remote sequence/CAS version. ConsumerKind and optional Epoch FKs pin job kind/epoch without binding old attempts to a mutable current owner. Phase private_started/verified/publication_pending/published/failed/uncertain/retired. Verified/publication phases require verification time; published/retired require publication time and receipt. Manifest hash and JSON required, receipt JSON optional; each JSON <=65536 bytes. PartCount int 1..1024 counts every represented file, including an index when present. This is a schema safety limit, not pool capacity or provider policy. |
| ExportAttempt legacy reference | Optional complete six-column reference: publication/source/KVK/period/destination-kind/destination-ID. Exact SourceDelivery PK FK plus scoped SourcePublication FK and job-season FK. Only new-source attempts may reference this predecessor table, even though columns use the Legacy prefix. Existing receipt bytes remain in SourceDelivery. No receipt import/backfill occurs. |
| ExportAttemptPart | PK(AttemptID,PartNo), UQ(AttemptID,FileID); FileID nvarchar(128) BIN2. PartCount copied and FK-bound to attempt; PartNo 1..PartCount. Role index/generation/output. ManifestHash required; GridCount positive int, RowCount nonnegative bigint, CellCount positive bigint >=RowCount. VerificationState pending/verified/failed/uncertain with verified timestamp required exactly for verified. AclState pending/private/public_viewer/failed/uncertain; non-pending requires observation time. QuarantineState none/quarantined; quarantine requires time/reason (nvarchar(1024)). EvidenceJson optional valid JSON <=65536 bytes; Version positive bigint. |

The bounded manifest is metadata; normalized part rows hold per-file evidence. Exhaustion must
reject before any provider mutation, never truncate receipts or assume 1024 files are provisioned.
New vocabularies require a reviewed schema/protocol amendment, never unvalidated strings.

Queue indexes support account/state/ticket, intent and supersession lookup. Resource reverse/active
indexes support admission inspection. Attempt job/sequence and phase/time indexes support recovery.
All scoped FK column types/collations were checked against authoritative snapshots.

### Static SQL versus later writer obligations

SQL enforces row shape, scoped relationships, bounded evidence and uniqueness. It does NOT prove
temporal immutability, authorized repairs, valid provider receipts or complete manifest cardinality.
Authorized later DAL must validate exactly PartCount distinct rows, hashes, pinned intent vector
and matching legacy receipt publication membership before mutation/confirmation. Existing complete
selection FKs alone also do not prove matching input tuples: keep S8B sealed-input/CAS validation.

Resource ownership/fence updates must be monotonic and atomic across Job/Resource under the later
admission protocol. Matching resource/job owner tuples, canonical resolved account/file identities,
frozen resource membership, oldest-ticket fairness, retained repair authority, immutable attempt
identity and valid phase transitions are DAL/service guarantees. Historical attempts must not FK
to the mutable current job owner, nor be overwritten when another owner/attempt is admitted.

Keep running A pinned while pending B/C arrive; coalesce only eligible pending new-source work,
preserving B and its ticket. Daily SCANORDER jobs are not coalesced. An uncertain claim blocks
conflicting admission even after timeout/lease expiry. SQL fences cannot cancel a submitted Google
request. Blocked/unmapped history is not free capacity. Later recovery needs exact readback and
terminated-worker evidence. Failed pre-mutation work may be retried under a new retained attempt;
do not erase ownership evidence to make it look never attempted.

Account admission precedes sorted destination acquisition and short job CAS. Budget reservations
are separate short transactions; waits/provider calls occur after commit. Legacy SQL snapshot
admission is confined to producer/capture work and released before provider work. All participating
writers must use the same coordinator database/admission; bypassing writers remain a deployment
gate. The existing Bot publication_gate/latest-selection behavior is unchanged until S10B/C.

### Migration classification, order and recovery

DataChange: No; zero existing application rows affected. RequiresBackup: Yes; DataSafetyPlan:
Included; rollback Forward Fix Only. Creates Job, Resource, JobResource, Budget, Attempt and Part,
then adds FKs including cyclic active membership. Uses XACT_ABORT and a transaction-owned schema
application lock. Owns commit/rollback only when no caller transaction exists; an ambient caller
must roll back on failure. No SQL transaction spans provider work.

Absent-all installs atomically. Partial presence fails before creation. Full presence is verified
against empty temporary expected shapes through SQL catalog comparisons: column types/nullability/
collations, CHECK expressions without lossy normalization, trusted/enabled checks and FKs, index
grouping/uniqueness/order, and absence of unexpected defaults/triggers/table modes. Conflicting
schema is rejected without attempting history repair. Compatible reruns do not alter application
rows. Deploy only the migration; snapshots describe post-installation state and their cyclic FKs
require creating all tables first if constructing a separately approved empty prerequisite fixture.

Forward correction retains tables, attempts, receipts and fences. No history cleanup, backfill,
old-receipt mapping, automatic repair, predecessor rerun or manual migration-history rewrite.
Deploy after S8A/S8B prerequisites and before coordinated Bot writers, with separate execution
approval. Repository delivery is never proof of migration application.

### Validation and retained evidence boundaries

76 offline static checks and 85 T-SQL parse inputs passed (eight artifacts, embedded test body,
76 case statements). The fixture authors 76 structural cases and five guarded modes (install,
constraints, partial, drift, type_conflict), including exact NULL replay, repairs/epochs, scopes, key/JSON limits,
ownership membership, budget precision, attempt/part evidence, and unchanged uncertain state on
rerun. These SQL cases have NOT executed. Later execution requires exact new disposable target,
reviewed migration hash, backup/actual-restore evidence and independent operation approval.
No mock/static result establishes SQL Server catalog behavior, concurrency or provider acceptance.

Offline validation evidence is retained outside Git at
`C:/Users/cwatt/AppData/Local/Temp/k98-s10a-implementation-20260914`.
Security review is separately tracked at its exact working-patch snapshot; do not treat this
authoring checkpoint as a completed scan or live acceptance claim.

All pending Bot documentation remains mandatory in S10B's next Bot implementation PR, including
the S10A pack/starter, S9B closeout and both sides of both S9B archive moves. The new Bot handoff
is added to that exact manifest; no Bot file enters this SQL PR, no standalone documentation PR.

Preserve fixed source, supplied overall/B0, independent stats/targets/publication/roster/history/
daily consumers, authoritative aggregate/DKP values, UTC starts, SCANORDER, unused scans, movable
within-season windows, exact 11-10/12-10/13-10/authorized14-10 endpoint chain, sealed inputs/CAS,
matched UpdateID, explicit counterpart attestation and admission locks. No summed-fight overall,
mixed source, silent legacy fallback or activation from SourceRouting.Enabled alone.
S6-OPS01/PERF01/CAP01 and both uncertain publications remain untouched. S8B accepted smoke/50-case/
actual-restore evidence stays distinct from offline runner history, S8A six-script evidence and
S8C execution/operator evidence. S8C seven local checks PASS is not live Discord acceptance.


### PR #85 review corrections â€” 2026-09-14

Current banners now reflect the implemented/open-PR checkpoint. Migration and fixture reject
non-table name conflicts explicitly before counting user tables for the absent/complete state.
The additional type_conflict fixture mode creates a synthetic conflicting view inside its
rollback transaction and requires the exact migration error without any new export table.
All five modes and 76 structural cases remain unexecuted; no SQL execution is authorized.


### PR #85 temporary-shape collation correction â€” 2026-09-14

Seven temporary reason/JSON columns now explicitly use COLLATE DATABASE_DEFAULT so their
expected catalog shape matches permanent columns inheriting the application database default,
even when tempdb differs. Explicit BIN2 identity columns and permanent schemas are unchanged.
Static regression checks compare every temporary character column with its permanent counterpart.
Before deployment, separately authorize the existing install/constraints fixture modes against
a new disposable database with collation different from tempdb, recording both collations.
That SQL execution remains pending; parser/static checks are not runtime collation evidence.

## S10A compilation-boundary correction â€” 2026-09-14

The first approved disposable run retained the checksum backup, successful actual restore,
and 76-case cross-collation install result. Partial-schema validation stopped with SQL Server
error 207 (`IntentID`): the static installation index was bound before the partial-table guard.
The permanent six-table DDL now runs as one constant `sys.sp_executesql` batch only after
prerequisite, object-type and completeness guards pass. Decoded DDL is unchanged; transaction,
applock, exact rerun checks and strict error 51000 fixture expectations remain intact.

The operator approved this fix and continuation on the existing
`K98_S10A_Disposable_20260914_validation` and `_restore` databases on `9SX2VF4\K98DEV`.
Both currently retain the identical 19-table empty prerequisite baseline. A new pinned receipt
will preserve the original failed-run evidence and reuse its backup/actual-restore proof;
no database recreation, prerequisite rerun, backup overwrite or restore rerun is planned.
Run install, partial, type_conflict, direct apply/rerun, constraints and drift after review.
PR #85 remains unmerged. No production, provider, Discord or bot-machine action is included.

## S10A corrected compilation validation result — 2026-09-14

Fix commit `b8e19f8f03683eec0d6c2563d732fb5303ba04dd` passed 87 static parse inputs
and exact decoded-DDL/guard/verification parity. Changes review, Deep off, scan
`0a151f59-3c5d-4dfc-a5dc-81852a5782d0` completed with zero findings; target base
`0cdf9efcc6f625580a84f57449c5c103e74d8268`, content digest
`3f1701d12151a1b24203a15c0ff20d97af003d6decd54b224520028dc2447a7e`.

Approved continuation manifest SHA256
`705ce96f3ef40907c059a30c118dedfb8835e40a66adb7370bc31b1bd146c3b7`
ran against the two retained S10A disposable databases. Install passed all 76 cases;
partial and type_conflict passed their strict expected-error assertions. Direct migration
application returned successfully and committed six empty export tables. The subsequent
Python audit compared SQL case-insensitive ORDER BY output with Python case-sensitive sort
and stopped on the same exact 25 names in different order. This was a harness comparison
failure, not a second migration failure. No automatic runtime retry occurred.

The corrected read-only audit verifies 25 empty primary tables, 19 empty restored tables,
unchanged prerequisite metadata, enabled/trusted constraints, original database inventory
and backup presence. Receipt `s10a-continuation-01-receipt.json` SHA256
`f6c2032f99605225eef146853594f5135f355663a92c45966d5474328e0408f0`
and `s10a-continuation-01-stopped-audit.json` are retained beside the original execution
evidence under the existing `k98-s10a-implementation-20260914` temporary evidence directory.

A separate continuation02 harness normalizes both name lists before exact comparison;
offline regression rejects missing, extra and duplicate names. Only direct migration rerun,
constraints (76 cases), drift and final audit remain, requiring approval after this new stop.
No install/bootstrap/backup/restore will be repeated. Both original receipts remain immutable.
These sequential SQL checks do not establish worker concurrency or provider guarantees.
This evidence-only update needs no new security scan: migration and fixture bytes are unchanged.
PR #85 remains unmerged and no production or bot-machine action occurred.

## S10A disposable validation complete — 2026-09-14

The operator approved continuation02 and it passed at 16:39:18–16:39:22 UTC on
`9SX2VF4\K98DEV`, using retained `K98_S10A_Disposable_20260914_validation` and
`K98_S10A_Disposable_20260914_validation_restore`. Direct migration rerun preserved the
installed baseline; constraints passed all 76 cases; drift rejection passed; final baseline
and database inventory checks passed. Primary retains 25 empty tables, restore retains the
unchanged 19-table prerequisite baseline, with enabled/trusted constraints.

Together with the retained original backup/actual-restore proof and continuation01 install,
partial/type-conflict and direct-apply evidence, all five fixture modes and direct apply/rerun
are now complete. Install and constraints each passed the same 76 structural cases; these
are 76 unique cases, not 152 different cases. Cross-collation application/default-tempdb
behavior passed. No database recreation, bootstrap, backup overwrite or restore repeat occurred.

Executed SQL head: `dbaab083db57e400845f701b453fb4ff6d158dab`; migration/fixture unchanged
from security-reviewed fix `b8e19f8`. Manifest SHA256
`170493741737c899caeaebb98d8e0e93f00d54ba4e3d0347bc04420f2c4e7b50`.
Receipt `s10a-continuation-02-receipt.json`, SHA256
`71be461a0ab4db270c49664c97a8d89a376a3bbb958b65c165f3edd160254713`, retained under
`C:/Users/cwatt/AppData/Local/Temp/k98-s10a-implementation-20260914` with every prior receipt.
The manifest's pending-approval wording is its immutable preparation checkpoint; subsequent
operator approval and this executed receipt supersede it without rewriting evidence.

This is sequential disposable SQL evidence, not worker concurrency, provider truth or live
Discord acceptance. All retained operational gates and uncertain publications remain intact.
No production/bot-machine deployment, activation, merge or later-slice implementation occurred.
This update changes only delivery evidence; SQL source bytes remain unchanged, so the existing
Changes security review applies and a precise documentation-only skip covers this delta.


## S10C preparation authoring approved — 2026-09-14

The operator separately approved the eight-path preparation schema/migration/fixture/static-checker
authoring boundary recorded in the Bot S10C task pack. Adds pre-spool preparation identity and
exclusive preparation/job resource ownership. SQL execution, publication, deployment and activation
remain unauthorized. Both pending SQL documentation files accompany the eventual separately
authorized SQL implementation PR. Preserve accepted SQL #85, every retained database/file and
uncertain publication. Static validation is not SQL concurrency or restore evidence.

## S10C completed local review — 2026-09-14

Separate Changes review (Deep off) 83778eb1-6169-4d08-ab6a-24ebfdd90f20 completed
with no reportable findings or deferred candidates against the exact eight-path patch:
codex-security-snapshot/v1:sha256:c56aa47a8c0672f6c1cb8c2d52311d8a907ed8d17ebd865baff2914c15f2e8be.
The offline checker passed; no SQL case or migration was executed. This later evidence-only
documentation update has no runtime/schema effect and is covered by a documentation-only
security skip. Reviewed SQL/checker source bytes remain unchanged.
The earlier scope-only closeout above is historical; separately approved authoring is complete.
Exact-target SQL execution, backup/actual restore, rollout attestation and publication remain
separate authorization gates. Preserve all retained databases/files, claims and receipts.

## S10C PR86 review corrections — 2026-09-15

The authorized review response tightens pending ownership and Actor BIN2 collation and validates
inherited ExportResource columns, CHECKs, indexes and FK mappings against accepted S10A expectations
before the first S10C alteration or metadata seal. Missing/extra/disabled/untrusted/altered inherited
shape fails closed. This covers ExportResource, not a new deployment attestation of every S10A table.
The script remains authoring-only, not an upgrade for a previously installed old S10C shape.

Offline static validation passed the valid patch and rejected six corrupted variants. The authored
SQL fixture adds owned-pending rejection and Actor metadata checks; it was not executed.
Changes review (Deep off) eeb8cf3a-d063-4c0c-ba7e-97caf5aab5a4 completed without reportable findings
or deferred candidates at codex-security-snapshot/v1:sha256:19c735c6af83c989274ceff27251179534358bd3fca9856bc2c7d2c1e270868a.
This subsequent evidence-only documentation update is covered by a documentation-only security skip.
No live SQL/provider/Discord execution, deployment, activation or retained-state mutation occurred.


## S10D output pool and rollover foundation - authored 2026-09-15

Deployable source: `20260915_001_kvk_output_pool_rollover.sql`. Four new KVK tables plus
two additive attempt/part unique reference keys; the complete eleven-path approved manifest,
FK/ownership matrix, data-safety plan and exact Bot carry-forward table are recorded in
`../docs/SQL_DELIVERY_LOG.md` under S10D. Both pending SQL documentation updates accompany
the eventual authorized SQL implementation PR.

Require exact accepted S10A/S10C schema. S10C merge/static results are not installation proof.
Absent/partial/conflicted/drifted prerequisite state fails closed, without executing old
migrations. Validate inherited shape before ALTER; compare full expected shape after install
and on rerun. Never seal observed drift. The two additive indexes can lock populated attempt
tables; preview row counts and schedule installation under an approved backup/restore plan.

Metadata: DataChange No, zero application rows changed, RequiresBackup Yes, RiskLevel High,
DataSafetyPlan Included, TransactionMode Auto, Rollback Forward Fix Only. Constant DDL runs
under a transaction-owned schema lock after guards; direct calls own commit/rollback and
ambient callers must roll back on failure. Do not deploy table snapshots. No seed/backfill,
receipt rewrite, budget change, ownership release, feature activation or provider operation.

Static SQL enforces file/index identity, scope, shape and evidence bounds. S10E must enforce
owner/fence/version CAS, monotonic epochs, append-only event APIs, P/Q/R capacity and the
9,000,000-cell ceiling before mutation. Keep eight registrations and sixteen slots each.
Rollover closes admission, drains/reconciles, proves old-writer termination and separately
verifies private ACL, complete clear and empty readback. Uncertainty remains quarantined;
lease age/job state cannot release claims. Historical receipts and assignments remain intact.

`../deploy/Test-OutputPoolRolloverContracts.ps1` is offline only. The fixture
`../validation/kvk_source/s10_output_pool_rollover.sql` authors 90 structural/transaction
examples and seven guarded modes, all unexecuted. Actual install/rerun, concurrency,
lost acknowledgement, cross-collation and backup/actual restore require separate exact-target
approval. Retained predecessor databases/files are not test targets. No bot-machine change.

## S10D corrected authoring and security result - 2026-09-15

The three expected-schema indexes for ExportPreparation/ExportPreparationResource now
reference their #S10D temporary tables. The offline checker handles ON targets immediately
followed by an opening parenthesis and rejects permanent table/index DDL outside the guarded
installation payload. This corrects the installation-order defect found during review.
No migration or fixture was executed.

Validation of the corrected source:

- Offline contract checker: 463 assertions passed in the actual SQL repository.
- SQLFluff TSQL parsing: 101 inputs passed, including constant payloads and 90 case snippets.
- Eleven deliberately corrupted scratch variants were rejected, including both affected
  expected-index table targets. Original scratch bytes were restored after each case.
- Validate-SqlRepo passed against an isolated source copy. All 15 warnings concern older
  migrations; they were not changed or executed. git diff --check passed.
- Exact identities/actions/bytes for all 50 pending Bot paths remain unchanged; both SQL
  document titles and complete earlier pending bodies are retained. Both Git indexes are
  empty and all recorded Bot/production/SQL base anchors remain unchanged.

Initial Changes scan `a582a43f-c6df-4ec3-98be-2dc100f8fa0a` was completed after correcting
its final-draft submission. Its source review identified the installation correctness issue,
not a vulnerability. Corrected Changes scan `eddcf7bb-ba2f-48c2-a995-b4371f9ce3ac` is sealed,
Deep off, with complete coverage of nine SQL/code files plus both documents and zero security
findings. Corrected reviewed snapshot:
`codex-security-snapshot/v1:sha256:11954e5793ccce9428f4fd70b1981be56407400085d86dfbab059f7521c76c14`.

Implementation source SHA256:

- Migration: `fd5344ec9d1080fe7ee824801ccb4f03910b71d83e85c6e42d48cbc90f2f0852`
- Offline checker: `e34fd0498c601e0d40e3683844d41d72e2621c436084a5c27a77b917521cb9b1`

This result section was appended to the two approved SQL documents after sealing. That
follow-up is documentation-only; implementation source bytes remain exactly those reviewed.
Security routing skips another scan for this evidence-only addition. No Bot runtime delta,
standalone docs PR, Git publication, SQL installation, provider/Discord execution, predecessor
rerun, bot-machine pull/restart/deployment or activation occurred. All unexecuted S10D/S10E
transaction/provider gates and all retained S6/S8 evidence distinctions remain as recorded.

### S10E ownership amendment (local authoring; not installed)

`20260915_002_kvk_output_operation_ownership.sql` is the separately approved follow-on to
S10D, not a predecessor rerun. It requires exact accepted S10A/C/D objects and adds typed
rollover operation/resource ownership. Existing jobs, preparations and receipts remain.
Run `deploy/Test-OutputOperationOwnershipContracts.ps1` for offline text contracts only.
`validation/kvk_source/s10e_output_operation_ownership.sql` requires separate exact
disposable target, backup and actual restore approval; it has not been executed.
Upgrade all resource readers/writers before operation admission. Do not activate by merely
installing SQL or setting flags. Preserve claims/history and forward-fix on uncertainty.
