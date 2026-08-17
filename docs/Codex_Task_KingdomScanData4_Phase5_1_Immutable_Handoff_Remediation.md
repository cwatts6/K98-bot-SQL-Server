# Codex Task Pack — KingdomScanData4 Phase 5.1 Immutable Handoff Remediation

## Status and authority

- Date authorized: 2026-08-16
- Operator authorization: implement the SQL and bot remediation after the real-token Phase 5.1
  evidence failure.
- Parent task:
  `docs/Codex_Task_KingdomScanData4_Phase5_1_Bot_DAL_Immutable_Handoff.md`
- SQL base: `2e0f228f399bcc7b8bd3d6a758b059466c0474ac`
- Bot mirror PR: #232
- Production PR: #539, open and temporarily exercised on MINI_AMD
- Production state constraint: MINI_AMD must return to the merged private
  `K98-bot/main` revision after remediation and before Phase 5.2 starts.

The parent task's SQL stop rule fired correctly. This pack is the separately authorized SQL change
and security decision; it does not silently amend the frozen Phase 5.0 package.

## Failure reproduced

The real bot token retained inherited Modify access after SQL moved the file from Ready to Claimed.
The evidence run successfully replaced the contents with the 11-byte string `replacement` and
renamed the file to `<completed-name>.renamed`. Its later missing-file exception was caused by the
successful rename and was not an ACL denial. The durable claim remains nonterminal and must be
recovered only through the reviewed isolated reset.

## Scope

### SQL repository

- Add paired ACL-hardening evidence columns to `dbo.KS4_ImportFileClaim`.
- Update `dbo.CLAIM_KS4_IMPORT_FILE` so every fresh or recovered claimed file:
  1. resolves the real xp_cmdshell identity;
  2. transfers ownership to the xp_cmdshell identity, removing the bot owner's DACL control;
  3. performs the final reset to the inherited Claimed-directory DACL;
  4. verifies the DACL;
  5. hashes only after those steps succeed;
  6. persists the hardening timestamp and owner with the claim.
- Add a guarded migration, early rollback, preflight, verification and static contracts.

### Bot repository

- Add a guarded directory ACL configuration script for the isolated and later production roots.
- Correct mutation classification so only an actual access-denied exception counts as denial.
- Stop mutation probing after the first successful mutation and always persist a failure receipt.
- Require exact expected SQL and bot commits.
- Retain file owner/DACL evidence and validate the SQL-persisted owner.
- Add a shape-specific recovery script for the retained failed rehearsal.
- Add focused script-contract tests and update operator documentation.

## Security decision

Both repositories change security-sensitive filesystem, SQL and privileged subprocess behavior.
Run separate `codex-security:security-diff-scan` Changes reviews with Deep off:

- SQL: `origin/main..final SQL head`
- Bot: PR #232 base through final mirror head

A standard or deep codebase scan is not authorized or required.

## Acceptance

- SQL static contracts and repository validation pass.
- Bot focused tests, standard gates, pre-commit and full pytest pass.
- The isolated ACL configuration receipt records protected DACLs, the exact bot/SQL SIDs and no
  broad mutable principal.
- The real-token evidence receipt records:
  - bot publication to Ready;
  - SQL ownership transfer followed by the final DACL reset before digest;
  - overwrite, replacement, rename, delete and in-place modification all denied;
  - matching Ready, claim and archive digests;
  - paired ACL evidence in the claim;
  - archived claim and receipt.
- Both stable findings are closed against the final evidence.
- Mirror PR #232 and production PR #539 have no unresolved merge blocker.
- MINI_AMD is restored to private production `main`, validated and gracefully restarted.
- Only then may Phase 5.2 begin.
