# Phase 3 import concurrency design

Status: implemented for the first Phase 3 slice and proven on the representative copy.

## Mutex contract

| Setting | Decision |
| --- | --- |
| Resource | `K98:KingdomScanData4:ImportPipeline:v1` |
| Mode | `Exclusive` |
| Owner | `Transaction` |
| Timeout | 60,000 ms |
| Database principal | `K98ImportLockPrincipal`, reached only through `dbo.ACQUIRE_KS4_IMPORT_LOCK` |
| Failure behavior | Return/throw an actionable error and make no staging, scan or filesystem progress |

Every authoritative SQL import path uses this exact resource. Public entry points
`dbo.IMPORT_STAGING_PROC`, `dbo.FIX_IMPORT_STAGING`, `dbo.UPDATE_ALL`, `dbo.UPDATE_ALL2` and
`dbo.ARCHIVE_IMPORT_STAGING_FILE` reject `@@TRANCOUNT <> 0` before acquiring the mutex or mutating
state. Each public operation therefore owns the transaction that owns the lock, and procedure
return is also a lock-release/durability boundary.

`dbo.ACQUIRE_KS4_IMPORT_LOCK`, `dbo.IMPORT_STAGING_PROC_CORE` and
`dbo.HASH_KS4_IMPORT_ARCHIVE_FILE` are explicitly denied to `public`. Only the narrow lock and
lock helper executes as owner; public wrappers, the import core, and the path-constrained
archive-hash helper remain caller-context. The hash helper uses the archive channel's existing
`xp_cmdshell` permission to run `certutil -hashfile` and parses exactly one SHA-256 value, avoiding
any new server-level bulk-load grant. An ordinary database user cannot acquire the namespace,
invoke the nested core, or invoke the archive hash helper directly.

Nested acquisition is deliberate but private. `UPDATE_ALL` and `UPDATE_ALL2` own their outer
transaction and call `IMPORT_STAGING_PROC_CORE`; both acquisitions are owned by that transaction.
The public importer delegates to the same core only when no caller transaction exists.

## Transaction boundary

1. A public entry point refuses a caller-owned transaction and opens its own transaction.
   Legitimate nesting occurs only through the denied same-owner import core.
2. Acquire the application lock.
3. Validate file presence and load/validate raw and typed staging.
4. Allocate the scan number and populate canonical staging.
5. Reject duplicate logical keys.
6. For `UPDATE_ALL`/`UPDATE_ALL2`, insert KS5 and KS4 rows and complete critical per-scan metadata.
7. Commit the authoritative Phase A transaction.
8. Run non-critical Phase B work under its existing separate transaction where applicable.

Filesystem archival is post-commit. If a previous move left the source absent and destination
present, the archive wrapper calls the private path-constrained hash helper and compares the exact
destination to the receipt digest before changing `ArchiveStatus`. A mismatch remains `pending`,
records `LastArchiveError`, and fails closed.

The application lock is not held across `UPDATE_ALL2` Phase B. Phase A is the durable import
boundary; a controlled Phase B failure remains retryable without creating another scan.

## Atomic scan allocation

While the application lock and transaction are held:

```sql
SELECT @NextScanOrder = ISNULL(MAX(SCANORDER), 0) + 1
FROM dbo.KingdomScanData4 WITH (UPDLOCK, HOLDLOCK);
```

`@NextScanOrder` is `int`, matching the final table contract. Allocation refuses when the current
maximum is `2147483647`. The existing clustered `(SCANORDER, GovernorID)` access path supports the
serializable range read; the database application lock is the cross-entry-point ownership guard.

## Duplicate-prevention contract

The logical import key is `(SCANORDER, GovernorID)`.

- Canonical staging must contain exactly one row per logical key.
- Before KS5 insert, no existing KS5 row may use the allocated `SCANORDER`.
- Before KS4 promotion, no existing KS4 row may use the allocated `SCANORDER`.
- After each insert, row count and distinct `GovernorID` count must match and no duplicate logical
  key may exist.
- All checks and writes occur under the same mutex and transaction.

The ten approved KS4 indexes remain unchanged. Duplicate prevention is enforced in the
authoritative write transaction rather than adding an eleventh KS4 index.

## Required concurrency proof

On a fresh representative Phase 2 copy:

1. Start two direct `UPDATE_ALL2` sessions with zero intentional start spread.
2. Prove one Phase A winner and one clean mutex/file loser, with no transaction leak.
3. Repeat with direct `IMPORT_STAGING_PROC` and the legacy `UPDATE_ALL`/`FIX_IMPORT_STAGING` entry
   points as applicable.
4. Confirm one new scan, one row per governor, no duplicate `(SCANORDER, GovernorID)`, correct file
   disposition, no deadlock and actionable timeout diagnostics.
5. Repeat corrected retry, invalid required numeric and controlled Phase B failure cases.

Production execution is outside this checkpoint and remains separately gated.

## Representative proof

On 2026-07-26, two direct `UPDATE_ALL2` sessions started without an intentional spread against
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE2_FINALIZEPASS`:

- session 96 won and committed scan 1023 with 411 KS4 and 411 KS5 rows in 90,605 ms;
- session 95 waited 10,215 ms, then rejected the now-receipted file with no data change;
- the final invariant query found two total receipts, 411 rows and 411 distinct governors in both
  tables for scan 1023, source absent, archive present, and `@@TRANCOUNT = 0`.

The same environment also passed a duplicate replay of a previously committed file with unchanged
KS4/KS5 row counts and scan maxima. Direct `IMPORT_STAGING_PROC`, legacy `UPDATE_ALL`, corrected
retry, invalid-required-numeric and controlled Phase-B cases remain required for Phase 3 closure.

On 2026-07-27, the final private-principal delta was exercised against
`ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`:

- an ordinary import principal received SQL error `1202` when it named the private lock principal
  directly and error `229` when it called private helpers directly;
- the same principal reached the intended ownership chain through a temporary public-wrapper
  grant, while an ambient wrapper call was rejected before acquiring the mutex; and
- session 66 acquired the private mutex, session 63 returned `-1` while it was held, and both
  sessions released with transaction count zero.
