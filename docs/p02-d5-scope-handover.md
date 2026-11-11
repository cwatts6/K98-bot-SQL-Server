# P02 D5 SQL scope and handover

Private Bot PR740 merged at `ef8aee342fbe2d91c9e8aaef34c0df6b54570803`
on 11 November 2026, 10:41:16 UTC. D4 source delivery is complete; nothing is
installed by that repository merge. The operator requested D5 scope/handover,
documentation/archive updates and a new chat beginning with scope reconfirmation
and a missed/new-issue check. First deliverable is review/scope only.

The canonical cross-repository packet is the Bot task pack **Startup Import
Export Reliability - P02 D5 Scope and Handover - 2026-11-11.md**. Read it with
[D4 delivery](p02-d4-delivery-handoff.md), [combined release](p02-d4c-combined-release.md)
and the [integrated SQL plan](p02-integrated-sql-delivery-plan.md). Superseded
[D4 planning](archive/p02-d4-scope-handover.md) is historical evidence only.

## Fixed baseline and contracts

- SQL PRs150-155 are merged. Payload remains exactly
  `ba5c6acbefba0eb89cb18842a7f6c6811096759b`, migration
  `20261111_001_p02_d4_combined`, profile `p02_d4_v1`; documentation successors
  do not change it. Last accepted installed Phase1 remains separate.
- Thirty objects cover four ledgers and six maintenance kinds; thirteen existing
  predecessor definitions, seventeen new objects, eight initial rows. Preserve
  captures, claims, historical backup rows and sequence state; no old-work adoption.
- DDL and Applied/Succeeded receipts commit together; post-commit recovery is
  forward-only from the same verified release. No SQL replay, reverse numeric
  conversion, old-Bot fallback or second start to resolve uncertainty.
- Approved retirement of UPDATE_ALL, UPDATE_RALLY_DATA and TEST followed bounded
  caller checks; old definitions/data remain and installed stubs refuse52940.
  UPDATE_ALL2 and the daily Rally importer continue. No broad grants, identity
  fallback, TRUSTWORTHY or backup-schedule change was introduced.
- Native fixtures and separate SQL Changes scan have their recorded limits;
  source/fixture qualification is not deployed-host or real-child/provider acceptance.

## Required D5 SQL qualification

| Area / owner | Required evidence |
| --- | --- |
| Baseline and packet / SQL+Bot reviewer | Reconcile exact final D1-D4 source, retained authorized data/fixtures and equivalent/direct callers. Verify test-host/VM/session readiness after the prior crash; define exact isolated targets, operation limits, cleanup and stop conditions before execution. |
| Outputs/state / report owner | All fourteen outputs and detailed state; exact integer/rounding and latest-name semantics; old queued serialized payload bytes unchanged; execution-time date windows; tied-rank policy explicit. Reuse valid Phase1 evidence without claiming it qualifies later composition. |
| Actual maintenance / SQL owner | Import, configuration, player, KVK, final-report and post-import children; due/claim/ACK, producer intent and exact target identity. Actual child work and both ownership orders, not only simulated calculations. Optional upkeep failure never relabels committed business/capture work. |
| Observers/permissions / coordination owner | Known actual holders versus requesters; both arrival orders, short passive selectors, saturation, denied identities, alternate factories, stale tuples and disabled snapshot. Preserve mutation fencing and current-state admission. |
| Failure/restart / lifecycle owner | Lost lock-grant, commit and backup-dispatch acknowledgement; cancellation before/after native entry; rollback/reset/cursor/guard/close uncertainty; exact nested resources and restart. A proxy close or reused SPID does not prove physical closure. |
| Backup / maintenance owner | High-log optional-statistics deferral still permits eligible committed summary backup demand. Requested is not completed. Hidden/denied wrapper metadata refuses, one dispatch only, no fallback after uncertain reply, historical queue rows protected. No real backup merely to test route discovery. |
| Cost / qualification owner | Warmup and at least five balanced comparable OFF/ON pairs; actual children, observer cost and saturation. Preserve resource limits and failed runs. |
| Closeout / release owner | Every inherited finding, equivalent caller and integration case mapped to pass or explicit gap. D6 deployment and P03/P04 recovery prerequisites remain separate. |

Raw-history SNAPSHOT across index REBUILD failed with SQL3961; retain it.
Managed metadata-reader exclusion does not qualify arbitrary readers/ad-hoc DDL.
Do not introduce blanket indexes or instrumentation. Evaluate ActivePreparationID
index only if measured plans and write cost demonstrate benefit.

## New drain evidence and immutable limits

Bot quality run42998021332 attempt1 on8b6879bf failed the final drain assertion in
`tests/test_personal_stats_render_submission.py::test_cancelled_unstarted_owners_keep_two_native_slots_and_drain`
at line63. The test and PersonalStats runtime were unchanged from the private
baseline. Four focused cases and one same-head full retry passed. Root cause is
unproven; passing retry is not closure. D5 lifecycle owner must investigate native
completion, settlement callback ordering, concurrent drains, executor shutdown
and retained capacity using bounded deterministic evidence, without weakening
assertions or increasing limits. The Bot handover links retained failed/success
logs and PR740 comments6793114051/6793565436. Keep this separate from SQL51400,
lock-holder attribution and SQL3961 unless direct evidence connects them.

Keep RCSI off, free memory/disk >=8GiB, log <70 percent for optional statistics,
version store <512MiB. Short observations retain three-second statements and zero
row-lock wait; metadata holds remain bounded at30seconds. Overall median
ON <= OFF*1.20+1000ms and per-report stage <= OFF*1.20+250ms after warmup/five pairs.
The1800second rehearsal cap is not a Bot timeout increase. The21-input allowance
is consumed: no new copy/reset/restore or larger allowance is implied. Retain
original failure and cleanup evidence separately from later success.

## Next-chat and release boundaries

Begin with an independent reconciliation of all F01-F32/C01-C16, all73 recovery
action pairs and Recheck/group/batch/outcome paths outside the count. Carry settled
decisions without asking to start again. Identify genuinely new issues with
evidence, consequence, owner, prerequisite and acceptance proof; present a bounded
first slice before new implementation/native qualification.

D6 requires separate approval after D5, fresh actual-host source/updater/seed,
effective process identity/rights and every changed path/ancestor including
archives, safe drain and exact receipts. No production SQL install, restart,
provider/backup action or retained-work recovery is authorized by this handover.
P03 actual blockers and essential P04 cancellation/history/notification corrections
precede first normal import/export. D7/P05 retain provider and natural acceptance;
zero incidents is neither health proof nor a prerequisite.

This SQL delta is Markdown only. Validate repository documentation/links and
archive body preservation; runtime/native tests and a new security scan are
skipped for the prose delta. Future executable changes need separate exact Bot
and SQL Changes reviews, Deep off, or precise documented skips.
