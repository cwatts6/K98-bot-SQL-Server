> **Current P02 checkpoint, 11 November 2026:** Private Bot PR740 is merged at `ef8aee34`; D2/D3/D4 are not deployed. Use the [D5 scope and handover](p02-d5-scope-handover.md) for review-first integrated qualification, the failed Personal Stats drain evidence and all remaining owners. Fixed SQL payload remains `ba5c6acb`. D6 release approval and P03/P04 action gates remain separate; earlier dated checkpoints below are historical.

# P02 D4 SQL delivery and D5 handoff

D4 SQL source delivery is complete in PRs 150-154. The combined release is bound
to SQL revision `ba5c6acbefba0eb89cb18842a7f6c6811096759b`, migration
`20261111_001_p02_d4_combined` and profile `p02_d4_v1`. This documentation successor
does not change that fixed payload or establish installed acceptance.

## Delivered contracts

- Bounded installed and host evidence plus read-only catalog checks reconcile
  legacy, scheduled, direct-child, backup and configured identity paths. The
  operator reports no manual/external use and approved retirement of `dbo.UPDATE_ALL`,
  `dbo.UPDATE_RALLY_DATA` and `dbo.TEST` if caller checks passed. Those checks passed within
  the recorded scope; absence of recorded recent calls is not a complete use history.
- The three retired roots retain archived definitions and data; after installation
  they refuse with 52940 before mutations. UPDATE_ALL2 and the separate daily Rally
  importer remain supported. Direct maintenance children retain admission checks.
- Sequence and installed backup-wrapper qualification sources, permissions and
  fixed job binding are authenticated without consuming sequence values, resetting
  state or dispatching a backup. Hidden or denied metadata refuses. No grants,
  TRUSTWORTHY change or automatic identity/profile fallback are introduced.
- The 30-object combined package covers four ledgers and all six maintenance kinds,
  producer/child receipts and exact migration outcomes. It checks 13 predecessor
  definitions and absence of 17 new objects, seeds eight new rows and preserves
  historical captures, claims, backup rows and sequence state. Applied/Succeeded
  receipts commit with the DDL; recovery after commit is forward-only from the
  same verified release receipt.
- The Bot D4 transition binds this fixed SQL payload and all three startup
  contracts to the inventoried installed predecessor. An exact updater upgrade
  precedes admission; source classification is not proof of host readiness.

See [combined release](p02-d4c-combined-release.md),
[legacy boundaries](p02-d4b-legacy-boundaries.md),
[child admission](p02-d4b-child-admission.md) and
[installed dependencies](p02-d4b-installed-dependencies.md) for definitions,
qualification and evidence limits. The canonical cross-repository closeout is
the Bot task pack **Startup Import Export Reliability - P02 D4 Delivery and D5
Handoff - 2026-11-11.md**.

## Validation and remaining owners

PR154 final source `7a8615068346ab93cb0486965ef145e78388f43f` passed its two SQL CI
checks and exact-head code review. Changes scan
`247247c4-a99d-4334-8b69-1beeb706232b` covered all 18 changed files with zero
findings. Native complete-batch cases passed commit, rollback, exact outcome
reading, replay/foreign/partial/drift refusals and retained-row checks. Ledger
and source tests passed; Windows PowerShell 5.1 covered the D4 outcome reader,
module reader and existing Phase 1 runner. The inherited historical contract
validator was qualified with PowerShell 7 as used by CI. These fixture results
are not a production SQL installation or actual child/provider acceptance.

D5 owns final combined output/state correctness, exact numeric/rounding behavior,
old queued payloads, real maintenance children, both ownership orders, saturation,
known holders, cancellation, lost acknowledgements, physical cleanup, restart and
balanced cost qualification. Preserve SQL 3961 evidence and the consumed 21-input
allowance; no additional business input copy is authorized. Keep RCSI off, memory
and disk floors at 8 GiB, log threshold at 70 percent and version-store threshold
at 512 MiB. The canonical Bot plan retains the detailed timing and sampling limits.

D6 requires separate deployment approval, fresh exact source/updater/seed and
effective-identity checks plus path/ancestor custody. No production install,
restart, provider dispatch or retained-work recovery is authorized by this handoff.
P03 actual retained-work blockers and essential P04 corrections precede the first
normal import/export; D7/P05 retain whole-flow and natural acceptance. Zero incidents
is not proof of health, and a source merge does not satisfy these remaining gates.
