# Atomic coordinated recovery SQL release

`coordinated_recovery_v1` extends the existing module release runner for one
explicit chain of twelve recovery migrations. It is a coordinated deployment
adapter, not a normal updater profile or permission to execute production SQL.

The profile authenticates every original migration byte and all 26 affected
object images. Eleven scripts have exactly one reviewed outer transaction
boundary adapted to the caller's transaction; the second migration already
supports an ambient transaction. Stored-procedure bodies are unchanged.
Parameterized `sp_executesql` gives each migration its own local variables and
temporary-table scope. Transaction escape is refused after every script.

All twelve individual Applied receipts, the outer Applied receipt and the
successful deployment attempt commit with the schema changes. The existing
session lock serializes apply and status. Reconciliation checks the release,
attempt, commit, profile checksum, every child checksum and independent schema
postimages. An absent receipt is insufficient: the complete preimage must also
match before reporting unstarted or rolled back. A conflicting owner or drift
returns unresolved. Preflight and verification write no deployment records.

## Reproduction and retained evidence

Run on the approved development SQL instance only:

```powershell
python validation/rehearse_guided_recovery_release.py --allow-disposable-sql
```

The helper requires the exact local server identity `9SX2VF4\K98DEV`, creates
fresh random databases, and retains them. It derives expectations by installing
immutable source at `b3480656` and literal migrations at `21de1988` in a separate
reference fixture. It never learns expected metadata from its deployment target.
Real backup checks remain enabled. Faults are injected only into retained copies
of the adapter, never the production implementation.

The final rehearsal used reference database `K98_P0a_Migrations_f5c37cd76bbc` and
target `K98_P0a_Atomic_2b597d943833`. Its 13 adapter invocations passed, covering
read-only preflight, unstarted status, competing owner refusal, forced deployment
process termination before commit, exact rollback, caught precommit interruption,
wrong-release refusal, lost commit reply, committed verification, idempotent
repeat apply, child receipt corruption, restored receipt, and module drift.
Additional assertions checked zero partial schema/permission changes, zero
partial child receipts and no additional attempt on completed repeat apply.

Artifacts: `%TEMP%\K98_P0a_Release_btlp_kme`; final report:
`%TEMP%\K98_P0a_Atomic_2b597d943833.json`. The target intentionally ends with a
modified procedure to prove drift refusal. It is not an installation candidate.
Ruff and whitespace validation pass. Existing migration fixture formatting is
unchanged; the new helper was formatted with Ruff.

Changes scan `bbe88635-f743-46c6-9ec8-a706859ecc1c` covered all four changed
source files against `9a59efbf` at snapshot `4b50aab5f6d9a19c5a829c34a95e001258f543c80cc0f4af3e828df1a4a69499`.
It completed and sealed at `2026-10-16T09:39:12.941133Z`, with complete coverage
and no findings. Finalization succeeded and the sealed result was read back.
Tool-reported usage: 2,813,574 tokens. This evidence document adds no execution
behavior after the scan.

## Release boundary

This closes SQL transaction/receipt interruption handling. It does not complete
P0a: production-bound principal/grant expectations, protected successor contracts,
source/seed activation, complete enabled-action qualification and the final
installed-package rehearsal remain required. The generated fixture profile is
not a production profile: its baseline contains only source-defined fixture
permissions, not the installed application account's complete grants. The
coordinated production package must derive and verify those explicitly.
No maintenance window is requested. All P0b recovery workflows remain in scope.

## Application grant completion

The adapter now adds the exact 22 direct application permissions missing from the
twelve-migration chain, inside the same outer transaction and before postimage
verification. The beneficiary is fixed to `S11_ExportApplication`; its required
authority/legacy roles and absence of reader/db-owner membership are checked on
preflight, apply and verification. No role is granted by this release.

The independent fixture transcribes the delta from bot `ded19ccd..c2d9a961`, not
from the adapter SQL. It includes the seven existing application object grants
on affected baseline objects. Reference `K98_P0a_Migrations_a83f648ab8e0` and target
`K98_P0a_Atomic_14e51f6623d5` passed all **18 adapter calls**, adding missing-principal,
revoked-permission and incompatible-role rejection. It checks all 22 effective
rights while impersonating the application user, the exact added permission set,
and unchanged baseline grants after both process death and caught rollback.
Artifacts: `%TEMP%\K98_P0a_Release_1t91fgao`; report:
`%TEMP%\K98_P0a_Atomic_14e51f6623d5.json`. The final intentional module drift is
retained. Ruff and whitespace checks pass.

Changes scan `c85d73f3-d942-48c7-a324-8a4d3b17d20b` covered both changed source
files against `5b364db4` at snapshot
`2fc51b647e98e1f3b6a5ce4adb9886ae77c5e23f81b396407dc48d2f732a6718`, with complete
parent and independent delegated review and no findings. Finalization succeeded,
and sealed documents were read back at `2026-10-16T10:01:01.473400Z`.
Tool-reported usage: 1,421,604 tokens. This subsequent evidence-only documentation
does not require another Changes scan.

This closes atomic installation and verification of the permission delta. The
fixture still does not represent every existing production role/object grant or
the complete application schema. Production image derivation, protected successor
contracts, package assembly and final rehearsal remain mandatory P0a gates.

## Exact installed predecessor representations

Retained reviewed deployment evidence exposed two source-equivalent installed
representations that the original guards rejected: manual enrollment without a
final newline, and configuration publication with its exact leading newline,
SQL Server `CREATE   PROCEDURE` spelling and two final newlines. The migration
guards now admit those two complete SHA-256 hashes in addition to the original
source forms. No normalization, procedure body, postimage or permission changed.

The fixture independently reconstructs both representations from immutable SQL
baseline `b3480656`, and uses migration revision `ee71a4ae`. Reference database
`K98_P0a_Migrations_8f0bff5d3871` and target `K98_P0a_Atomic_c242ae115a16` passed
all **22 adapter invocations**. The two additional changed-body injections occur
after adapter preflight and before the migration chain, so they independently
exercise the literal migration guards. Both reject and roll back all changes
and receipts. Artifacts: `%TEMP%\K98_P0a_Release_pcfc8cmt`; report:
`%TEMP%\K98_P0a_Atomic_c242ae115a16.json`. Ruff and whitespace checks pass.

Changes scan `0232d2f7-8316-4589-8f9d-96a936207d1a` reviewed all four changed
source files in `49e38576..fc6d8b63`, with independent hash reconstruction and
complete coverage. It completed with no findings, sealed and read back at
`2026-10-16T10:15:20.258611Z`; tool-reported usage 1,394,498 tokens. This later
evidence-only document does not change executable behavior. The production
package and successor-contract gates above remain required; no window is requested.
