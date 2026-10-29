# Bounded MGE finalisation release and native qualification

29 October 2026. Review candidate only. Database creation/writes, merge, installed
updater upgrade and production deployment remain separate approvals. Publishing
the Bot mirror and SQL review PRs is authorized. No native write exercise has run.

## Fixed release contract

`deploy/SqlDeploy.MgeFinalisation.ps1` implements `mge_finalisation_v1` through
the existing module runner. It creates only `dbo.MGE_BoardFinalisation`, its named
constraints/defaults/work index and these enabled AFTER triggers:

- `dbo.tr_MGE_Events_Frozen`: UPDATE, DELETE on `dbo.MGE_Events`.
- `dbo.tr_MGE_Awards_Frozen`: INSERT, UPDATE, DELETE on `dbo.MGE_Awards`.
- `dbo.tr_MGE_Signups_Frozen`: INSERT, UPDATE, DELETE on `dbo.MGE_Signups`.

The profile supplies environment/history bindings, never SQL, table identifiers,
grants or arbitrary modules. Existing parent identities and types, enabled unique
EventId key, visibility and deployment permissions are checked. Partial objects,
unexpected parent triggers, explicit new-object ownership/grants and postimage
drift refuse adoption. No historical data is backfilled. ANSI/quoted settings,
trigger definition/event/parent/enabled/signature metadata and complete structural
table/index/check/default/FK metadata are independently checked.

The existing exclusive `K98_Module_Release_v1` lock, backup/environment/history
checks and transaction protocol remain authoritative. Five explicit SqlClient
batches create the table, index and three triggers. Schema plus Applied/Succeeded
receipts commit together. Started remains outside that transaction. An absent
Applied receipt only permits continuation after exact absent preimage and matching
same-release attempts prove rollback. Unknown, live, conflicting or drifted state
stops. Never delete receipts or adopt a manual installation.

The `20261029_001_mge_board_finalisation.sql` source migration's executable body
remains unchanged. Required repository metadata was added to its comment header
during PR CI review, superseding the initial preparation hash. Its bytes are not
a release-profile checksum. Existing legacy migration
execution is not qualified by this profile and must not bypass the combined runner.

## Authoring after approved environment observation

`validation/build_mge_finalisation_profile.py` prints the profile from explicit
database/tempdb collations, compatibility and reviewed prerequisite history. It
does not connect to SQL. Commit the resulting filename
`20261029_001_mge_board_finalisation.release.json` in the migrations directory only after its production
bindings are observed and reviewed. Do not use local disposable values as production
values. A prior attempt forbids silently changing this migration identity or hash.

The companion Bot `scripts.build_mge_release_description` module reads that exact
SQL commit and prints a descriptor with the explicitly supplied installed private
Bot predecessor. The Bot registry's new fixed 20-member transition includes all
14 runtime changes and six unchanged dependencies. Initial finalisation adoption
refuses an absent, removed, unchanged or wrong-family descriptor, including the old
KVK descriptor. The new installed updater must be authenticated via the existing
tool-upgrade mechanism; changing checked-out source is not installing it.

No production `.release.json` is fabricated in this PR: installed predecessor,
production SQL metadata/history and tool manifest still need their separate
read-only observation approval. Consequently the current candidate intentionally
fails release admission until that binding follow-up is reviewed and committed.

## Native harness and exact target

`validation/rehearse_mge_finalisation.py` defaults to SELECT-only discovery through
`lpc:localhost\K98DEV`, requiring canonical identity `9SX2VF4\K98DEV`. Its only
write target is `K98_MGE_Finalisation_Qualification_20261029_A`. It never creates,
drops, restores or renames a database. The protected recovery database and all other
databases are out of scope.

The default discovery was exercised: the proposed database is absent, SQL version
is 16.0.1210.3 and server/tempdb collation is
`SQL_Latin1_General_CP1_CI_AS`. Private evidence retains the integrated login and
paths. No fixture, temporary table, ledger or schema write occurred.

Before `--run`, separately approve an already-created **empty SIMPLE** database,
exact login, creation timestamp, two file paths, new backup destination, database
and tempdb collations, compatibility, clean Bot/SQL commit pair, fixture writes
and named child fault injection. The approval JSON requires exactly the fields in
`APPROVAL_FIELDS`. Supply its exact SHA256 via `--approval-sha256` and a matching
`K98_MGE_APPROVED_TARGET=server|database|approval-sha256` opt-in. These are execution
guards and retained operator evidence, not substitutes for human approval.

Execution verifies reviewed Git blobs against executed files, installs 13 synthetic
dependency/ledger tables from this repository, makes the approved backup, and uses
the real PowerShell 5.1/SqlClient runner. It imports actual Bot DAL functions with
test-owned pyodbc connections; production configuration/retry adapters are not
under test. Discord is fake and unexpected filesystem persistence is refused.

Cases N00–N16 exercise install/repeat, four real-runner process-loss boundaries,
postimage drift, OUTPUT INTO writers, completion/inventory atomicity, sparse/invalid
identities, inventory failure, pre/post-commit child loss, freeze triggers, blocking
order evidence, rowversion/CAS, terminal dispositions, competing settlement,
durable readback, result imports, multi-call boundaries and >50-event keyset reads.
Only child handles created by the harness may be terminated. No SQL Server or Bot
process is targeted. Each error stops execution, retaining fixtures, transcripts,
source hashes, operation exits and per-case results. There is no automatic cleanup
or replay; a used database is refused on a fresh invocation.

The harness does **not** qualify protected Windows custody, installed-tool upgrade,
startup contract regeneration or complete SQL/source/seed/start interruption paths
(U05–U13). Those use the existing combined-updater rehearsal tools after a separately
named Windows root and SQL target are approved. Native evidence and all untouched
cases remain NOT RUN; passing offline tests is not permission to execute them.

## Offline validation

- Fourteen Python guard/import tests passed, including refusal before connection
  for target/hash/approval mismatches and six actual DAL imports with no SQL access.
- `validation/Test-MgeFinalisationProfile.ps1` passed under Windows PowerShell 5.1:
  parser, five fixed batches, profile dispatch, byte hash and malformed inputs.
- Source whitespace check passed. Native SQL write cases remain NOT RUN.
- Final per-repository security review must be Changes mode on the immutable range,
  Deep off; no whole-repository audit is implied.

Changes scan `2abbbb8c-8453-4505-9178-a9d9bcba84fd` completed on
`7e91989f619deb46836194c7e705b0a9eb2ebe11..8a9be2dbe49199152f5083b140d5903779f0039f`
with all 15 changed source files covered and no reportable findings. The subsequent
CI correction adds only the new migration's required comment metadata and these
documentation clarifications; no executable SQL or runner changed. A repeat scan
is skipped for that exact comments/documentation delta. Native evidence stays pending.

PR #134 review correction `3c5b7d0` changes only N08's synthetic delete fixture:
an unreferenced frozen signup now reaches its AFTER DELETE trigger instead of
first failing the award foreign key. The original row is independently checked
after rejection. Fourteen offline guard/import tests pass again. This narrower
test case changes no runtime, approval guard, release policy or deployment path;
a further security scan is skipped for this exact fixture-only delta. The review
comment was answered and resolved; native error 51830 remains to be exercised.

After SQL commit, an old Bot is not a safe rollback because it can attempt frozen
history writes. Retain the drained state and evidence; use a reviewed compatible
forward correction or same-release continuation after independent outcome checks.
