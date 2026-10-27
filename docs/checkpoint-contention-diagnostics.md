# Completion checkpoint contention

The bot correction serializes stats/unreceipted, all-KVK and player-report
recovery inspections before row locking. Observations yield on contention.
Only UPDATE_ALL2 completion metadata may retry row timeout/deadlock after an
acknowledged rollback and close, with exact completed receipt and ownership
revalidation. Business procedures and provider requests are never replayed.

There is no schema migration, grant, server setting or trace installation in
this companion change. Existing SQL contracts remain authoritative.

## Capturing a future blocker

Open [Observe-CheckpointBlocking.sql](../deploy/recovery/Observe-CheckpointBlocking.sql)
in a fresh SSMS window connected to MINI_AMD / ROK_TRACKER using the existing
administrative account. Run during an already-authorized import/export if
contention recurs. Save every result set with the matching bot log and UTC time.
The sampler is bounded to 15 seconds and 150 samples, and stops when its
512-row threshold is reached (a final batch can add up to 31 additional rows).
Cancel closes the diagnostic; no persistent objects or settings need cleanup.

RequestSessionId identifies the waiter; BlockingSessionId identifies the blocker
observed at that instant. A sleeping blocker can own an open transaction without
an active command. Negative blocker IDs describe engine states. Do not kill any
session or release reservations from these observations. No observed rows does
not prove absence of contention, and later observations cannot identify a past
blocker. The script deliberately omits SQL text, parameter values and identities.

The earlier application-lock trace excluded row error 1222. Retained traces did
not identify the historical checkpoint blocker. Local two-session tests proved
the opposed lock order, without proving that session attribution in production.

## Resource lookup breadth

The canonical ExportResource schema has ActiveJobID and ActiveOutputOperationID
indexes, but no ActivePreparationID index. Broad locked lookups are therefore a
contention amplifier. The bot correction uses nonblocking observation transactions
and producer/account admission so an observer releases instead of waiting while
holding earlier locks. No speculative index or production plan change is included.
The sampler returns the actual index inventory for a measured follow-up if waits
persist; use actual plan/row-count evidence before changing this shared table.

## Verification

Run SQL repository validation and parse the script before publishing. Rehearse
the unchanged SELECT against a synthetic local wait to verify both session IDs;
never manufacture a production failure. Bot tests cover both session orderings,
inherited observers, rollback/close failures, row timeout, deadlock classification,
changed ownership, lost commit acknowledgement and durable re-entry after restart.
Production acceptance requires new-runtime logs from normal work and durable
receipts, not just zero incidents or a successful restart.
