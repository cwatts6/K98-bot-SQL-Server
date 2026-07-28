# Phase 3 representative-copy rehearsal

Status: Phase 3 implementation and representative-copy rehearsal complete. Production remained
read-only throughout; merge, promotion, and production deployment are separate later gates.

## Environment

- SQL Server: `MINI_AMD`, SQL Server 2022.
- Authoritative representative database:
  `ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL`.
- Production database: `ROK_TRACKER`; no Phase 2 or Phase 3 DDL/DML was run.
- SQL source baseline: `b6b0bc4` plus the Phase 3 working-tree package.
- Recovery model during the measured isolated workload: `SIMPLE`; log use was checked before
  starting.

## Fresh ordered deployment proof

The authoritative copy was restored from the production representative backup, then exercised
through the exact release order.

| Order | Check | Evidence | Result |
| ---: | --- | --- | --- |
| 1 | Restore | Database `FULL`/`ONLINE` | Pass |
| 2 | Phase 2 preflight | Run ID `7A15C40C-741C-48AF-95D6-00242C91897D`; KS4 394,506; KS5 394,526; staging 0 | Pass |
| 3 | Phase 2 forward | Migration completed; measured outage 59.001 seconds | Pass |
| 4 | Phase 2 verify | KS4 394,506; KS5 394,526; latest 2,371; daily 22,336; global 411 | Pass |
| 5 | Phase 2 finalizer | Same run ID retained and accepted | Pass |
| 6 | Phase 3 preflight | `PlayerScanMeta` 2,371; `SUMMARY_PROC_STATE` 9; `STAGING_STATS` 411; invalid conversions 0; receipt object absent | Pass |
| 7 | Phase 3 forward | Same 2,371/9/411 rows; empty receipt table | Pass |
| 8 | Phase 3 verify | All 52 frozen dependent modules plus security helpers refreshed/compiled | Pass |
| 9 | Phase 3 rollback | Phase 3 objects/types removed or restored; no open transaction | Pass |
| 10 | Phase 3 preflight again | Pre-Phase-3 contract re-established | Pass |
| 11 | Final Phase 3 forward | Migration reapplied cleanly | Pass |
| 12 | Final Phase 3 verify | 2,371/9/411 rows; receipt rows 0; security helpers included; transaction count 0 | Pass |

The first rollback rehearsal identified old `CREATE_DASH` column names (`Deads` and
`Dead Target`) that no longer matched the approved Phase 2 schema. The migration transaction
failed closed and preserved the database. The rollback definition was corrected to the Phase 2
names, then the complete rollback and final forward chain passed. This is precisely why Phase 3
must be deployed with the repository runner rather than by continuing after an SSMS batch error.

## Import ownership, concurrency, and failure paths

| Check | Evidence | Result |
| --- | --- | --- |
| SQL application mutex | Private role/helper; session 66 acquired, session 63 returned `-1`; both ended with transaction count 0 | Pass |
| Mutex authorization | Ordinary import principal: direct role error `1202`; lock/hash/core helper errors `229`; authorized wrapper reached `51842`; ambient wrapper returned `51849` with no retained lock | Pass |
| Ambient transaction refusal | All five public entry points return their dedicated guard error with `NoLock`, caller transaction count `1`, and `XACT_STATE() = 1` | Pass |
| Archive reconciliation | Constrained `certutil` SHA-256: wrong destination digest remains pending with error `51850`; matching destination digest reconciles once; probe rows/files removed | Pass |
| Archive fail-closed path | Unknown digest raised error `51842`; receipt rows 0; transaction count 0 | Pass |
| Committed import | 411 rows in KS4 and KS5, one governor per source row, source removed, archive and receipt durable | Pass |
| Duplicate replay | Same digest refused; maxima and KS4/KS5 row counts unchanged; staging cleared; source retained for correction | Pass |
| Simultaneous `UPDATE_ALL2` | One winner and one duplicate loser; one new scan/receipt only; loser waited at the database mutex | Pass |
| Invalid then corrected retry | Invalid required numeric rejected without a partial scan; corrected fixture imported once | Pass |
| Direct entry points | Direct `IMPORT_STAGING_PROC` allocated scans 1024/1025; `FIX_IMPORT_STAGING` allocated 1026 | Pass |
| Legacy entry point | `UPDATE_ALL` completed with its durable import invariants | Pass |
| Controlled Phase-B failure | Error `51091`; Phase-A scan 1027 durable with 411/411 rows; source absent; archive present; audit matched; transaction count 0; 11,397 ms | Pass |

The database allocator takes the maximum across KS4, KS5, and the receipt ledger while the
transaction-owned application mutex is held. Direct SQL paths therefore cannot collide with the
bot-equivalent path, and duplicate detection does not depend on filenames or process-local locks.

## Result, metadata, and performance evidence

- `02_verify.sql` checks exact Phase 2 source types by `system_type_id`, the three converted
  downstream table contracts, receipt indexes/constraints, migration-history state, row counts,
  module refresh, and zero leaked transactions.
- The explicit-column changes preserve external aliases and result ordering. `UPDATE_ALL`,
  `UPDATE_ALL2`, `TARGETS`, dashboard, export, leadership, and upload paths compiled against the
  final contracts.
- `21_run_query_store_mapped_workloads.sql` completed one warm-up plus five measured executions
  for both the pinned leadership review and the accounts-DAL latest-scan materialization. All
  12 receipts were present; the accounts result stayed at five rows with one stable digest.
- The targeted controlled Phase-B workload completed in 11,397 ms while preserving the durable
  Phase-A contract. The standard controlled suite was repeated with one warm-up plus five measured
  executions and rollback-isolated writers on the same final definitions; SQL Server resource and
  transaction state was monitored independently while it ran.
- No deadlock was observed in the import/concurrency or mapped-workload runs. The new mutex
  intentionally converts concurrent imports into one winner plus deterministic duplicate refusal.

## Downstream decision

`PlayerScanMeta`, `SUMMARY_PROC_STATE`, and the directly written `STAGING_STATS` columns had exact
conversion proof and are aligned in this migration. Existing `bigint` contracts in
`EXCEL_FOR_DASHBOARD` and `STATS_FOR_UPLOAD` remain unchanged.

Approximately 190 other legacy key/scan columns are deliberately retained. Bulk-altering them
without independent writer, consumer, key/index, value, and rollback evidence would expand risk
without being required for the Phase 3 direct source contract. They remain separately scoped
remediation candidates; this is a completed retain decision, not an implicit conversion.

## Repository and security gates

| Gate | Result |
| --- | --- |
| `Test-Phase3Contracts.ps1` | Pass; 33 forward and 30 rollback procedure definitions |
| `Validate-SqlRepo.ps1` | Pass; only expected destructive-SQL review warnings |
| `git diff --check` | Pass; line-ending notices only |
| Codex Security Changes-only scan | Pass with follow-up: final scan `7ccf1007-269d-4470-94f0-638222312c5a` sealed the reviewed implementation snapshot with two Low/P3 findings assigned to Phase 5. |

The final scan reviewed
`codex-security-snapshot/v1:sha256:98d3c2f01c061c4a3557b5d2f43d0080b47cab9c9863279c8162f3dbb9d653a8`
and retained two related Low/P3 findings:

- `csf_1a1c440452b02cdb787fa7c3`: hashing and `BULK INSERT` open the reusable source path
  separately, so committed rows can be bound to an earlier digest.
- `csf_3cb54318733d3a216dd91e9b`: `certutil` hashing and `MOVE` resolve the source path separately,
  so a replacement can be archived after a different file was accepted.

Closing both boundaries requires the Phase 5 bot producer and SQL consumer to adopt one immutable,
uniquely named claimed file, with appropriate ACLs and destination rehashing. They are
combined-release blockers, not reasons to broaden this SQL-only Phase 3 implementation.

The only changes made after the reviewed snapshot are documentation status, receipt and future
deployment-sequencing updates plus mechanical trailing-whitespace/final-newline cleanup in the
generated migration, rollback and canonical import-core files. No SQL token, executable behavior,
permission, data access, configuration, dependency, deployment tooling or persistence behavior
changed, so the security-routing decision for that post-scan delta is a documented skip.

## Retained test evidence

The pre-existing `C:\discord_file_downloader\downloads_test\Import_Archive` content was not
deleted or overwritten. Phase 3 committed-import work used the separate
`C:\discord_file_downloader\downloads_test_phase3_rehearsal` root.

## Deployment boundary

PR #60 does not need to be deployed to production before Phase 3 development or rehearsal. It is
the required Phase 2 production predecessor and must be applied and verified before the Phase 3
migration during the later coordinated maintenance window. Git updates and `sql_schema` changes do
not deploy SQL Server; only the ordered migration runner does. The exact SQL-first, bot-second
sequence is in `deployment_order.md`.
