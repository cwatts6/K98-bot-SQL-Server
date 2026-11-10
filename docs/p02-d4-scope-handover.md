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
  from disposable fixtures or create guessed objects.
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
