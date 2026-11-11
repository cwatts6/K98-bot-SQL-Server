# P02 D4 SQL scope companion

The canonical plan is the Bot task pack **Startup Import Export Reliability - P02
D4 Scope and Handover - 2026-11-10.md**. This companion records SQL ownership and
navigation, not a competing plan. Start with review/scope and a missed/new-item
check. Preserve prior remaining-P02 agreements; implementation and operational
actions are distinct from this documentation handover.

Private Bot PR739 merged at 5ec55e3bbfaaca020b6046e94d80bb7645736742 after final
review and six passing CI checks. SQL D3 companions 142-149 are merged at
2018ffe215138db363e62a5d6025a5407173b5e2. Neither source merge installs SQL or
deploys the Bot. Deployment remains held until D4/D5 and a separate release decision.

## Required D4 closure

- Inventory actual UPDATE_ALL/Rally/TEST, direct/manual/scheduled callers, external
  consumers and cache readers. Qualify active paths or obtain explicit retirement
  approval. Static absence, an empty restored job list and no-known-use do not
  prove installed absence. Preserve input custody, child errors and post-commit
  archive semantics; never execute business work merely to discover use.
- Reconcile the missing authoritative dbo.KS4_UNO_SEQ and installed msdb
  usp_start_rok_tracker_log_backup definitions and rights. Identify the configured
  wrapper/job route without invoking a backup. Do not infer production definitions
  from disposable fixtures or create guessed objects. The [installed dependency source](p02-d4b-installed-dependencies.md)
  records the observed sequence and redacted wrapper contract; effective installed
  rights and migration bindings remain open.
- Include MaintenanceWork, MaintenanceConfigurationWork, MaintenanceKvkWork and
  MaintenanceBackupWork, all due/claim/ACK/child routines, six fixed kinds and
  producer transactional intent. Qualify direct child guards and restricted
  diagnostic/DMV access. Preserve the reviewed direct_application_v1 profile and
  historical signed profiles; no automatic fallback, broad grants or TRUSTWORTHY.
- Build versioned exact predecessor/postimage migration, permission/source/profile
  and startup contracts for the final combined Bot/SQL target. Retain historical
  hashes, native permission ordering and visible schema fingerprints. Disposable
  K98DEV-only installers and raw schema snapshots are not production installers.
- Preserve outstanding claims, old serialized captures and historical backup queue
  rows through migration/resume/rollback. Requested is not completed backup.
  High log use may defer statistics without suppressing eligible backup relief;
  failed/unknown dispatch or lost ACK cannot authorize fallback/replay by age.
- Prove compatible predecessor/successor switchover and rollback/forward recovery.
  Reverse numeric conversion after out-of-exact-float-range writes is unsafe;
  define a proved write boundary and recovery strategy without losing committed work.
- Cooperate with Bot D4 on all three startup contracts and the exact installed-to-
  combined updater refusal. Final Bot registry is 88 entries with immutable prior
  87 and unchanged cap; late nested-handle/uncertain-commit cleanup is included.

## Qualification and later owners

D5 retains final real-child faults, both ownership orders, actual short observers,
restart/cancellation/cleanup, exact output/state and old-payload compatibility,
and balanced cost qualification. RCSI stays off; memory/disk reserves >=8 GiB,
optional-statistics log <70 percent and version store <512 MiB. Warmup plus five
balanced measured pairs: overall ON <= OFF * 1.20 + 1000 ms, stage <= OFF * 1.20 +
250 ms. Preserve three-second short statements, zero row-lock wait and bounded
30-second metadata snapshot. The 1800-second rehearsal cap is not a Bot timeout
increase; the 21-input allowance is consumed. Recheck retained test-host readiness.

SQL 3961 raw-history SNAPSHOT/index REBUILD evidence remains failed. Native D3
fixtures qualified actual guards/receipts with simulated large calculations and
provider delivery where recorded. The unrelated diagnostic fingerprint assertion
remains documented, unchanged. Do not conflate those limits with final acceptance.

D6/D7 require separate installation/rollback and exercised/provider acceptance.
P03 actual blockers and essential P04 convergence corrections precede the first
normal import/export; no zero-incident prerequisite or automatic replay. Broader
datatype conversion, ranking policy and unrelated performance debt retain owners.

This draft changes Markdown only. Runtime/native SQL tests and formal Changes scan
are skipped for the prose-only diff; check links, whitespace, documentation gates
and pre-commit. A future executable SQL patch requires its own exact Changes review.
Carry the reviewed SQL companion and canonical Bot packet through their separate
publication histories; preserve all existing D3 and Phase 1 evidence.

## Independent D4 scope review, 10 November 2026

The canonical Bot supplement is **Startup Import Export Reliability - P02 D4
Scope Review - 2026-11-10.md**. Source review used Bot d4169d7 and SQL eeefd6f;
PR525 and PR150 were independently verified as open drafts against main 199c2d2f
and 2018ffe2 respectively. Both checkouts were clean. No SQL execution occurred.

Keep D4a-e, with early release-capacity analysis alongside the census, and pin
the final combined target only after dependency/permission contracts are settled.
The source review adds or sharpens these required integration obligations:

| ID | SQL-owned evidence / disposition | Required proof |
| --- | --- | --- |
| D4-R01 | usp_MaintenancePostImport checks four guards before sp_updatestats, but not StatsForUpload:Publish. Normal usp_RunMaintenance takes all five. Import/configuration child requirements also need explicit direct-call audit. | Close post-import direct-child admission; native held-player-guard negative test must refuse before upkeep, while valid worker and physical cleanup pass. Qualify each child's actual object/transaction/guard requirements and effective callers. |
| D4-R02 | UPDATE_ALL claims stats input, invokes UPDATE_RALLY_DATA before parent commit, and writes shared outputs. Rally deletes its separate CSV and catches errors with PRINT. Existing stats custody does not cover Rally. | Two input identities; direct/parent/implicit-transaction modes; parent failure after child, commit/archive split, changed bytes, lost ACK, restart and modern writer/maintenance overlap. Qualify active/unknown route or explicit retirement; never run it to discover use. |
| D4-R03 | Backup claim session and msdb dispatch connection have different identity/context boundaries; OBJECT_ID(NULL) can reflect hidden metadata. | Exact wrapper/job binding and both principals, visible/absent/hidden wrapper and denied dispatch tests; no real backup, guessed definition, fallback after uncertain dispatch or new broad rights. |
| D4-R04 | Upload-triggered/pre-admission backup paths and SQL GetPending/MarkProcessed/Cleanup legacy queue consumers remain part of census, even though old Python processing returns held. | Installed bindings and grants; no alternate adoption/mark/age-expiry of unknown history; preserve schedules and request-versus-completion distinction. Source presence alone does not prove installed use or a historical deletion. |
| D4-R05 | Bot registry has 88 entries at its entry ceiling, LF 214882/CRLF 219407 bytes under cap 232448; 13041 bytes of Windows headroom. Prior 87 digest and eight cleanup members verified. | Exact smallest final combined representation and reviewed installed admission. No byte-cap increase or registry redesign inferred. Preserve all historical entries. |
| D4-R06 | Current Bot descriptor still selects Phase 1; new maintenance table snapshots and source checks are not a coordinated installer. | Versioned exact Phase 1-to-final migration, four ledgers initialized once, outstanding rows preserved, all three startup contracts, source/grant/signature ordering and before/after-commit interruption/resume. Preserve historical profiles and old captures. |
| D4-R07 | Active Rally XLSX filename/error-row uniqueness is F29/P03, separate from F31 CSV. Exact Bot action census remains 73 pairs, 52 actions, 22 kinds, four empty. | Preserve F29/P03 and F27/P04 owners; include Recheck, group approval, accepted-action reconciliation and outcome-worker paths outside that policy count. No new automated action. |

The first bounded D4a deliverable is source/installed consumer inventory and F31
contract design/tests: explicit host/database/principal, fixed metadata/job/source
allowlists, bounded Windows PowerShell 5.1 collector, private receipts and honest
unavailable/partial evidence. No NEXT VALUE FOR, business procedure, provider,
backup or reconciliation call is a discovery mechanism. Installed execution still
requires exact current access/target evidence; pre-crash sessions are not readiness.

Missing KS4_UNO_SEQ and wrapper definitions, effective direct/signed rights, all
four ledgers/six children, exact KVK identity, restricted diagnostics, native
permission/schema order, old queued payloads and rollback/write boundary remain
open. D5 retains the full combined cost/fault/restart/real-child gates and unchanged
limits. D6/D7 and P03/P04 retain their existing operational/acceptance boundaries.
This supplement changes prose only; no runtime, SQL, grant or migration bytes change.

## D4b legacy boundary source, 11 November 2026

The [legacy boundary slice](p02-d4b-legacy-boundaries.md) records the completed
bounded caller checks and the operator-approved refusal of the three legacy roots.
It also protects historical backup queue APIs when the new ledger is present,
using a fixed dbo metadata helper so caller metadata denials cannot hide it. Definitions and data are retained; no installed objects or
permissions changed. Combined migration, exact permission/startup bindings and
D5 qualification remain open as specified above.
