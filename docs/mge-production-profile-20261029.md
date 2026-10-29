# MGE production profile binding

The release profile in
`migrations/20261029_001_mge_board_finalisation.release.json` binds the existing
bounded MGE runner to the production environment observed read-only at
2026-10-29 15:24:28 UTC. Database collation is `Latin1_General_CI_AS`, tempdb
collation is `SQL_Latin1_General_CP1_CI_AS`, and compatibility is 160.

The private evidence export contains 112 complete JSON records: one environment,
101 migration records, five deployment records, and five recent backup records.
Its SHA256 is
`fa1e103e99d349ef3c541b9c18234fc918c807ce63ce949bf753890945330749`.
The observed history count and unique migration count both equal 101. No
application rows, credentials, or private paths are published here.

The ten `requires` entries are a bounded release baseline, not a claim that the
entire database history fits the profile's 64-entry limit. They pin both deployment
ledgers, the MGE-adjacent view/type alignment, the retained stats-outcome failure
and correction chain, the previous KVK combined release, and the latest legacy
export closeout pair. Their exact checksums and statuses come from the retained
observation. The two historical `Failed` rows remain `Failed`; this release neither
repairs nor replays them. Unrelated vote, survey, and reporting history remains in
the full private evidence and is not selected for execution.

Only `20261029_001_mge_board_finalisation` is selected by this profile. The existing
runner still independently checks environment, metadata visibility, backup age,
permissions, parent shapes, absent preimages, unexpected triggers, transaction
outcome and postimages. Required history is additional admission evidence, not a
replacement for those checks. No runner, migration SQL, permission or schema
definition is changed by this binding.

This file is release-authoring evidence, not production execution or acceptance.
The native SQL qualification used its separate disposable profile and retained
release identity; those receipts must not be relabelled with this production
profile. Protected Windows and end-to-end combined rehearsal remain release
gates. Installed-tool upgrade, production preparation and deployment still require
their separate approvals and fresh operational checks.
