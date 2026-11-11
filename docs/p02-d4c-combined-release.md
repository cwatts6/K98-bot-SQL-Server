> **Current P02 checkpoint, 11 November 2026:** Private Bot PR740 is merged at `ef8aee34`; D2/D3/D4 are not deployed. Use the [D5 scope and handover](p02-d5-scope-handover.md) for review-first integrated qualification, the failed Personal Stats drain evidence and all remaining owners. Fixed SQL payload remains `ba5c6acb`. D6 release approval and P03/P04 action gates remain separate; earlier dated checkpoints below are historical.

> **D4 SQL delivery, 11 November 2026:** PRs 150-154 are merged; the fixed combined package is bound to `ba5c6acb`. See the [D4 delivery and D5 handoff](p02-d4-delivery-handoff.md) for installed/caller dispositions, approved legacy retirement, permissions, migration and Bot integration. Source delivery is not deployment or whole-flow acceptance. D5 integrated qualification and separate D6 authorization remain required. Earlier dated checkpoints below are historical.

# P02 D4c combined SQL release

The installed Phase 1 predecessor now has a fixed successor SQL package, selected
explicitly by migration `20261111_001_p02_d4_combined` and profile `p02_d4_v1`.
This source package is one D4c deliverable. Final permission/startup contracts,
the Bot updater binding and combined qualification remain required before use.
It is not authorization to install SQL or to deploy the Bot.

## Change and custody

The package contains 30 objects: four new maintenance ledgers, 12 maintenance
routines, seven producer/worker amendments, three approved retired entry points,
three guarded historical queue APIs and the fixed dbo metadata helper. Existing
definitions and data remain in source/history. No grant or role changes occur.

All formerly anonymous constraints on the four new ledgers have stable names.
Native comparisons prove unchanged types, checks, indexes and seed rows. The
initial insert count is eight: six fixed maintenance kinds, one configuration
checkpoint and one backup checkpoint. KVK work starts empty. Existing queues,
captures, claims and counters are never adopted, cleared, reseeded or expired.

The exact profile SHA256 is
`57944777e50b7dc9200220cfcc2ce767edb22a2e0972e02bc2cd6f04e23e8171`;
the fixed single-batch script SHA256 is
`8c0c99d92c14cac6da6e22076a5620927bac4c8af3deaa50950d66062381a8dc`.
The profile preserves all five Phase 1 prerequisites and additionally requires
its exact Applied receipt. No Phase 1 migration or numeric conversion is replayed.
Thirty native predecessor/postimage hashes include definitions, owner/signature/
object permissions and ledger shape through the existing recovery-image query.
The private installed receipt supplies exact predecessor evidence; its principal
inventory and the backup job identifier are not published.

## Admission, commit and recovery

The existing coordinator holds the exclusive session release lock, checks fixed
profile bytes and predecessor history, and requires the exact MINI_AMD /
ROK_TRACKER target, stable snapshot enabled, RCSI off, writable multi-user state,
no enabled DDL/history triggers, and the existing recent backup evidence before
Apply. Installed sequence structure, wrapper body/owner/permissions/signatures,
fixed enabled backup job and msdb owner capability are checked without dispatch.
The sequence current value is intentionally neither pinned nor consumed.

Resource gates retain log below 70%, version store below 512 MiB and data/log/temp
volume reserves of at least 8 GiB, and add the agreed 8 GiB available-memory floor.
Dependencies and resources are checked again inside the release transaction.
All DDL, eight initial rows and the Applied/Succeeded receipts commit together.
Before commit, failure rolls back. After commit, the same release verifies the
exact postimage and linked receipt and continues remaining stages without replay.
Missing, foreign, partial or damaged evidence stops for inspection. Raw replay
also refuses because the new ledgers already exist.

The transition must drain legacy and modern producers/consumers first; a metadata
check cannot revoke an already admitted call. After commit, recovery is forward
only and preserves outstanding/unknown work. There is no automatic old Bot/SQL
fallback, broad grant, reverse numeric conversion or age-based replay. D4d must
bind this package into the complete stopped/drained updater transition before
either installer is an approved route.

## Validation and limits

- `tests/test_d4_release_runner.ps1`: 19 Windows PowerShell 5.1 checks for fixed
  package admission, replacement/damaged input, target state, transaction
  propagation and dependency/resource refusal. Included in CI.
- `tests/test_d4_release_source.py`: exact complete payload reconstruction from
  all 30 current authoritative definitions and historical prerequisite custody.
  Included in CI; no database required.
- `tests/test_d4_combined_release.py`: two opt-in native tests in a newly owned
  local database. The complete batch rejects no/nested transaction and wrong
  database, installs/rolls back with exact images, commits and resumes against
  the actual production outcome-reader SQL, refuses foreign/missing/partial
  receipts and shape drift, preserves unknown claims and historical queue rows,
  and rejects replay. Exact dependency hashes and permission/sequence/missing
  wrapper refusals are exercised without invoking the wrapper.
- `tests/test_d4_ledger_schema_contract.py` and the child source custody test:
  stable images, unchanged ledger semantics and original D3 source evidence.

Native tests require `K98_D4_RELEASE_NATIVE=OWNED_LOCAL_METADATA_ONLY` and
`K98_D4_INSTALLED_RECEIPT` pointing to the exact private receipt. Their fixed local
server, new UUID database, resource limits and no-force cleanup prevent use of an
existing application database. Only the fixed database-name guard is substituted
in a test copy after the unchanged production guard is proved to reject it.
The actual release coordinator Apply is not called against production.

Historical publication validators must run through
`deploy/Test-P02Phase1HistoricalContracts.ps1`, which checks their immutable
historical source. Running the older atomic/publication validator directly over
current snapshots mixes generations: sp_TARGETS_MASTER changed in Phase 1 (not
D3), while CREATE_DELTA_TABLES changed in D3. D4's current custody and native
tests are separate successor evidence; historical hashes remain unchanged.

SQL repository validation, the historical Phase 1 package tests and the module
profile tests remain required. Bot architecture/deferred/test-selector/security
routing scripts, command-registration and Bot log hygiene are not applicable to
this SQL-only patch. A separate SQL Changes security review (Deep off) covers
the exact committed diff before its PR merges.

This is metadata/receipt qualification, not D5 real-child, cost, restart/provider
acceptance. The consumed 21-input allowance is unchanged. Final combined
permission/source/startup bindings and updater qualification remain D4c/D4d;
D5 and separately authorized installation/operational recovery remain held.
