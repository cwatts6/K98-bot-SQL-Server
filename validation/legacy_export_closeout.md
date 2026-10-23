# Existing-URL legacy export closeout

The corrective migration adds an immutable closeout receipt and an effective
containment view. A restricted authority may abandon a stopped legacy export
after the private service verifies its complete request journal and original
worker closure. SQL independently checks ownership, versions, terminal events,
complete destination membership, no competing work and no replacement plan.

Historical containment records, request events, streams, attempts, retained input
and all import/report receipts remain intact. The old job becomes failed with a
distinct abandonment receipt; it never becomes delivered. Existing files are
unchanged. Later scan_data/all_kvk jobs may use their original URLs; old contained
streams cannot append requests after the restriction is lifted. Exact configuration
preparation probes may read those same files. Managed pools, rollover, enrollment
and managed publication proofs retain the permanent historical fence. The
reconciliation proof issuer is verified unchanged in this release.

Every target exemption is bound to the receipt's original account at stream
opening, request preparation/dispatch and later closeout. Dispatch uses the
persisted request target. Global destination mutexes remain unchanged. The
active-target view is diagnostic inventory, not account-specific authorization.

## Deployment

Use the paired reviewed protected updater, with the exact
`20261023_002_legacy_export_closeout_release` profile. Its six object preimages
and postimages cover the new table, view and procedure plus the three admission
procedures. The runner drains the authority before SQL, then replaces source and
startup contracts. No business operation runs during installation. Do not apply
schema snapshot files or manually delete target fences. Recovery is a separate
operator-confirmed action after deployment.

## Validation

The bot repository's `tests/test_legacy_export_closeout_sql.py` installs these
actual module bodies and migration into a disposable local database and connects
using a temporary restricted SQL login. Tests cover repeat installation, exact
CAS, direct-write denial, reader denial, missing/unknown request outcomes, live
execution, foreign ownership, same-URL admission and continued old-stream denial.
Both legacy consumers dispatch through the restricted SQL boundary; configuration
reads succeed while configuration mutations and enrollment fail. Managed stream
creation, request preparation, request dispatch and proof issuance cannot use a
released legacy target. A later stopped legacy export can close out without a
second physical-target containment record.
Unrelated foreign keys are omitted from the synthetic fixture; the new receipt's
foreign keys and every table check/index are retained. Companion private-journal
tests verify closure hashes, request bodies, replies, restart and lost replies.

The full source-defined contract rehearsal additionally uses a fresh clone of
the retained synthetic baseline with production database/tempdb collations. It
verifies the unchanged baseline before deriving the six-object delta. This is
local validation, not production acceptance or provider delivery evidence.

After deployment, preserve the already committed scan and completed reporting
stages. Confirm `Allow next export`, verify abandonment, then run the next genuine
scan once and require its independent delivery receipts for all existing URLs.
