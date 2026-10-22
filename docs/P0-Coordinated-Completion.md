# P0 coordinated recovery SQL

This candidate accompanies the bot's final P0 recovery work. It is not deployed.
Merge and deployment remain separate operator decisions.

The receipt migration adds six tables: report-stage continuation, pipeline runs and
stages, current containment attestations, registration dependency attestations,
and audited disposition of an independently unowned SQL blocker. It never
backfills historical completion or treats released ownership as a receipt.

UPDATE_ALL2 writes continuation inputs in its import transaction. Its extracted
reporting procedure commits each of three stage receipts with that stage's writes.
Continuation validates the same file digest, scan, configuration, preparation and
worker guards, and skips committed stages. The scan import is never replayed.
The maintenance procedure excludes concurrent actual SQL worker sessions.

The exact coordinated profile `20261022_002_p0_completion_release` applies only
`20261022_001_p0_pipeline_receipts`. Its ten object images and fixed permission
delta are qualified independently of the adapter. Historical profiles remain
supported. The installer authenticates all input bytes, excludes live writers,
owns one transaction, and records the child and profile receipts atomically.
It requires the existing deployment history and backup gates. This is not a
general migration discovery mechanism.

Validation includes source-contract checks, exact preservation of the extracted
business calculations and nested procedure closure, disposable stage failures,
lost replies, stale configuration, live writers, migration rollback and reapply.
The real adapter is also compared against separately installed literal source,
then the application, export and legacy contracts are verified using a temporary
application login. Provider behavior is simulated in bot regression fixtures.

Run `deploy/Test-P0ReceiptContracts.ps1` and
`validation/validate_p0_reporting_equivalence.py` for offline source checks.
`validation/rehearse_p0_receipts.py --allow-disposable-sql` creates a new local
K98DEV fixture and retains its evidence. It has no production endpoint option.

Deployment must use the final paired bot updater package: drain the protected
process pair, apply and verify the exact SQL profile, verify the updated three
contracts, then start the reviewed bot pair. Resume an interrupted release from
its durable receipt. Do not rerun a committed import or manually clear ownership.
The prior bot's whole-application contract will reject the new schema; reverting
the bot alone is not a supported rollback. Preserve SQL and release evidence and
use a separately reviewed compatible correction.

Natural admission and provider acceptance remain post-deployment observations.
The accepted KVK16 publication and cache checks must not be repeated for this PR.
P1, including tracked-view restoration, remains the next complete programme.
