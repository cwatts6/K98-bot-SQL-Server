> **9 November 2026:** Phase 1 coordinated SQL/names/numeric/export and selected recovery-reader qualification passed in the owned restored VM. See [Phase 1 acceptance](p02-phase1-implementation.md). Production deployment, remaining P02 phases and provider/whole-flow acceptance remain separate.

# P02 SQL companion: integrated analysis and delivery

7 November 2026. P02 remains open. The canonical cross-repository plan is the
Bot task pack **Startup Import Export Reliability - P02 Integrated Analysis and
Delivery Plan - 2026-11-07.md** in the active P02 Bot checkout.
This companion is an SQL navigation and ownership record, not another plan.

## SQL scope in the combined solution

- D0: close retained underlying numeric/schema profile and current consumer/use
  evidence. All 75 tables / 325 numeric columns now profiled successfully: no
  fractions or bigint conversion failures, but 68,424 cells across 18 columns exceed
  int range (overlapping derived tables). Operator reports no known external use;
  restored matching jobs are absent. Fresh installed-binding verification remains D4.
- D1: [deterministic names](p021-deterministic-names.md), the locally qualified
  [nine-procedure endpoint rewrite](p021-summary-implementation.md), and the
  [numeric/export alignment](p021-summary-numeric-type-review.md). Preserve baseline
  comparison, exact output rules, current queued payloads, current-history rollback
  and index/grant contracts. The 139-column datatype package and 26-object shared-name package are implemented and qualified in the owned test copy; production rollout remains separate.
- D2: passive metadata reads, factory/budget and actual-holder diagnostic contract;
  mutation guards and action-time validation remain authoritative.
- D3: all six actual maintenance stages: import, configuration, player report,
  KVK output, final stats reporting and explicit post-import upkeep. Separate
  essential data/receipt/headroom from eligible post-success optimizer/backup work.
- D4: installed legacy UPDATE_ALL/Rally/TEST disposition and exact release
  profile/signing/startup pin integration. Do not run legacy business work to
  discover whether it is used. Static absence cannot clear external consumers.
- D5: final native correctness, real-child failure, concurrency and balanced
  cost study. The previous ON version-store failure is still a failure.
- D6/D7: separate approved installation/rollback, exact retained-work recovery
  dependencies and exercised whole-flow/provider acceptance.

## Current qualification and remaining gates

Name fix: 33 isolated tests. Summary rewrite: 30 isolated tests, exact output/state
comparison. Combined SQL Changes scan `59b599c8-c2fb-4df2-b895-0c2000976138`
completed without findings. These do not qualify future type/maintenance changes.
Local summary install/rollback scripts deliberately target owned K98DEV fixtures;
they cannot be deployed to the retained VM or production.

Frozen full-workflow limits: five balanced measured pairs after warmup; ON overall
median <= OFF x 1.20 + 1,000 ms and each report-stage median <= OFF x 1.20 + 250 ms;
observed version store <512 MiB; disk reserve >=8 GiB; sampled log use <70 percent;
approved host free-memory prerequisite 8 GiB; actual short observers and a bounded
30-second held snapshot. No RCSI change or limit increase is proposed.

Existing release blockers include name source-byte drift in historical permission
checks, new versioned signing/source profiles, exact explicit-target installer,
compatibility of SQL datatype metadata with both Bot versions/queued payloads,
external cache readers, TEST/legacy use and current host custody. Reverse numeric
conversion cannot be called safe after writes outside exact float range.

## Planning validation boundary

This companion and the integrated plan change documentation only. Qualified
executable hashes remain unchanged. Architecture/deferred/security-routing,
test-selector, links and whitespace are the relevant gates; runtime tests and a
new formal Changes scan are skipped for this non-executable planning delta.
Private read-only collector syntax and PowerShell 5.1/7.6 compatibility passed; guest execution and
underlying-data review are now recorded in the canonical plan. Production use and
performance acceptance are separate outstanding gates.
