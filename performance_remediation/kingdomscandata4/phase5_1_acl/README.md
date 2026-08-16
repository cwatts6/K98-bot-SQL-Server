# KingdomScanData4 Phase 5.1 claimed-file ACL remediation

The first real-token evidence run proved that a same-volume Ready-to-Claimed move retained the
Ready file's writable security descriptor. The bot token successfully replaced and renamed the
claimed test file. The later missing-file error was a consequence of that successful rename, not
an access denial.

This package changes the SQL claim boundary and bot operational evidence together:

1. An elevated operator configures deterministic Ready, Claimed and Archive directory DACLs using
   the real bot and SQL identities.
2. Ready grants the bot Modify and the SQL identity Full Control on inherited files.
3. Claimed and Archive grant the bot Read/Execute at most and the SQL identity Full Control.
4. SQL moves the exact completed file, resolves the real xp_cmdshell identity, resets that exact
   file to the inherited Claimed-directory DACL, transfers ownership to the xp_cmdshell identity,
   verifies the DACL, and only then calculates the first digest.
5. SQL persists the hardening timestamp and owner identity with the durable claim.
6. The bot evidence runner treats only an access-denied exception as denial, stops after the first
   successful mutation, and always writes a failure receipt.

## Files

- Migration: `migrations/20260816_001_phase5_1_claim_acl_hardening.sql`
- Early rollback:
  `migrations/rollback/20260816_001_phase5_1_claim_acl_hardening_rollback.sql`
- SQL preflight: `01_preflight.sql`
- SQL verification: `02_verify.sql`
- Static contracts: `Test-Phase51AclContracts.ps1`
- Bot ACL configuration:
  `C:\discord_file_downloader\scripts\Configure-Phase51ImmutableHandoffAcl.ps1`
- Bot evidence:
  `C:\discord_file_downloader\scripts\Invoke-Phase51ImmutableHandoffEvidence.ps1`

## Required order

1. Preserve the failed evidence directory and renamed file.
2. Use the reviewed failed-evidence reset against only the pinned isolated database and identity.
3. Stop the bot writer.
4. Configure the isolated directory ACLs and retain the JSON receipt.
5. Run `01_preflight.sql`, deploy the ACL migration, and run `02_verify.sql`.
6. Deploy the corrected bot mirror revision to the test machine.
7. Start the bot through `StartDLBotAfterSQL` and resolve its published PID.
8. Run the real-token evidence using exact expected SQL and bot commits.
9. Require `receipt.json`, five denied mutation attempts, matching digests, persisted ACL evidence,
   and an archived SQL receipt.
10. Run separate Changes security reviews for the SQL and bot diffs.
11. Update production PR #539 through the patch-based promotion flow; do not merge it before the
    evidence and review gates pass.
12. After the corrected production PR is merged, switch MINI_AMD back to `K98-bot/main`, pull,
    validate, and gracefully restart. Phase 5.2 must not begin while the machine is on a PR branch.

The rollback is deliberately early-only. It refuses once a claim records ACL-hardening evidence.
Directory ACLs are never weakened automatically by SQL rollback.
