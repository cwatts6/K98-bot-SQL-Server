# KingdomScanData4 coordinated deployment order

Status: operator guidance only. This file does not authorize production execution.

## Short answer

PR #60 is already merged into SQL `main` as commit `b6b0bc4`, but its Phase 2 migration has not
been applied to production. It does **not** need to be deployed before Phase 3 development or
representative-copy rehearsal. It **must** be deployed and verified before the Phase 3 production
migration, because Phase 3 refuses the old production `float`/`nchar` source contracts.

Do not deploy PR #60 by itself now. The approved plan is a coordinated maintenance-window release
after Phases 3, 4 and 5 and the combined release gate have closed.

## What deploys what

- SQL repository: `C:\K98-bot-SQL-Server`.
- SQL deployable source: ordered files under `migrations\`.
- SQL production runner: `deploy\Deploy-SqlMigration.ps1`, from a clean, reviewed SQL `main`.
- SSMS: production preflight/post-validation and diagnostics only; it is not the migration runner.
- Bot repository: `C:\discord_file_downloader`.
- Bot deployment: its own reviewed production promotion after every required SQL migration and
  SQL smoke check has passed.

`sql_schema\` files describe the expected final object definitions. Pulling Git or updating those
files does not change SQL Server. A migration changes SQL Server only when the deploy runner
successfully applies it and records it in `dbo.SchemaMigrationHistory`.

## Coordinated production sequence

1. Merge the reviewed Phase 3, Phase 4 and Phase 5 companion SQL work into SQL `main`; merge the
   reviewed Phase 5 bot work into the approved bot production branch, but do not start the new
   bot.
2. On the bot machine, stop the bot and every import, scheduler and administrative writer. Keep
   them stopped through SQL verification/finalization.
3. In `C:\K98-bot-SQL-Server`, switch to and pull SQL `main`; require a clean working tree.
4. Run repository validation and `Deploy-SqlMigration.ps1 -ValidationOnly`; confirm the exact
   Phase 2, Phase 3, Phase 4 and Phase 5 companion migration IDs are pending in that order.
5. Run `Test-SqlBackupReadiness.ps1` and the Phase 2 production-shaped
   `performance_remediation\kingdomscandata4\phase2\01_preflight.sql`. Preserve the run ID and
   receipts.
6. Apply only
   `20260725_001_kingdomscandata4_shadow_type_remediation` with
   `Deploy-SqlMigration.ps1 -MigrationId`, then run Phase 2 `02_verify.sql`.
7. Apply the reviewed Phase 3 migration ID(s), beginning with
   `20260726_001_phase3_import_concurrency_and_direct_type_alignment`, using the same deploy
   runner. Run the Phase 3 post-validation and smoke suite.
8. Apply the reviewed Phase 4 migration ID(s) using the same runner, then run the Phase 4
   post-validation and consumer suite.
9. Apply the reviewed Phase 5 SQL companion migration for the immutable claimed-file protocol
   while all writers remain stopped. Run its identity, duplicate, failure, archive, recovery and
   rollback checks.
10. Run the combined committed-import, Query Store, SQL/bot-contract and drift checks. Only an
   accepted fresh combined-release receipt may authorize the guarded Phase 2 finalizer.
11. Confirm `SchemaMigrationHistory`, `DeploymentRunHistory`, deployment logs, final drift and
    zero unexpected pending migrations.
12. Only now deploy the matching bot revision from `C:\discord_file_downloader`, start it, and run
    the end-to-end bot and immutable-file import smoke suite.

If a SQL gate fails, keep the new bot stopped. Before finalization or any post-cutover write, use
the reviewed Phase 5 companion SQL, then Phase 4, then Phase 3, then Phase 2 pre-restart rollback
order. After finalization or post-cutover writes, do not use the Phase 2 metadata-swap rollback;
make the documented forward-fix or backup/log recovery decision.

## Runner command shape

Run these only during the separately approved production window, from clean SQL `main`:

```powershell
cd C:\K98-bot-SQL-Server
git switch main
git pull origin main
git status --short

.\deploy\Validate-SqlRepo.ps1 -RepoPath C:\K98-bot-SQL-Server
.\deploy\Test-SqlBackupReadiness.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName MINI_AMD `
  -DatabaseName ROK_TRACKER `
  -BackupPath C:\sql_backup

.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName MINI_AMD `
  -DatabaseName ROK_TRACKER `
  -ValidationOnly
```

After the Phase 2 preflight succeeds, deploy each approved migration explicitly:

```powershell
.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName MINI_AMD `
  -DatabaseName ROK_TRACKER `
  -MigrationId 20260725_001_kingdomscandata4_shadow_type_remediation

.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName MINI_AMD `
  -DatabaseName ROK_TRACKER `
  -MigrationId 20260726_001_phase3_import_concurrency_and_direct_type_alignment
```

Phase 4 and Phase 5 companion SQL commands are added only after their exact reviewed migration IDs
exist. Bot commands are added to the combined release receipt only after the exact Phase 5
production revision is fixed.
