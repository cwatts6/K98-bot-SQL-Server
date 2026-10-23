# Existing-URL legacy export closeout

The corrective migration adds an immutable closeout receipt and an effective
containment view. A restricted authority may abandon a stopped legacy export
after the private service verifies its complete request journal and original
worker closure. SQL independently checks ownership, versions, terminal events,
complete destination membership, no competing work and no replacement plan.

Historical containment records, request events, streams, attempts, retained input
and all import/report receipts remain intact. The old job becomes failed with a
distinct abandonment receipt; it never becomes delivered. Existing files are
unchanged. Later jobs may use their original URLs; old contained streams cannot
append requests after the restriction is lifted.

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
