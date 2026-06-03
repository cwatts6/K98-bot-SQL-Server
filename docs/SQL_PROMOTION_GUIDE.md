# SQL Promotion Guide

Purpose: deploy K98 SQL Server changes from Git to Production with the same discipline used for
bot promotion.

## Environment Model

| Environment | Purpose | Notes |
| --- | --- | --- |
| Local SQL repo | SQL development and tooling | `C:\K98-bot-SQL-Server` |
| GitHub SQL repo | Source of truth for intentional SQL changes | PR-driven workflow |
| Production SQL Server | Runtime database | SQL Server 2022, `ROK_TRACKER` |
| Bot machine | Current deployment machine | Uses Windows Auth |
| Backup folder | Local SQL backup landing folder | `C:\sql_backup` |
| External backup | Off-machine backup copy | Every 15 minutes |
| Export branch | Drift evidence and recovery snapshot | `export/prod-schema-YYYYMMDD-HHMMSS` |

There is no DEV or UAT SQL environment today. The migration and validation model is designed so
additional environments can be added later without replacing the process.

## Tooling Prerequisites

- Start bot-machine sessions with the same dev bootstrap used for bot operations:

```powershell
cd C:\discord_file_downloader
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\venv\Scripts\Activate.ps1
.\dev.ps1
```

- Backup checks and migration deployment use Windows Auth. They can run through the PowerShell
  `SqlServer` module when installed, or through the built-in `.NET SqlClient` fallback.
- Production schema export requires SMO, normally provided by the PowerShell `SqlServer` module.
  Install that module on the bot machine before enabling live export or drift checks.
- Current production SQL connectivity requires trusting the SQL Server certificate. The tooling
  sets `TrustServerCertificate` for Windows Auth connections.

## Core Rules

- Git is the authority for intentional SQL changes.
- Deploy from `main` after PR review.
- Use `migrations/` as the deployable source.
- Treat `sql_schema/` as expected-state snapshots and drift evidence.
- Do not export Production directly into `main`.
- Direct Production edits are emergency hotfixes and must be reconciled back into Git.
- Deployment uses Windows Auth from the bot machine.

## Standard Process

### 1. Sync The SQL Repo

```powershell
cd C:\discord_file_downloader
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
.\dev.ps1

cd C:\K98-bot-SQL-Server
git switch main
git pull origin main
git status
```

### 2. Create A SQL Feature Branch

```powershell
git switch -c codex/sql-short-description
```

### 3. Create A Migration

```powershell
.\deploy\New-SqlMigration.ps1 -Description "add schema migration history"
```

Edit the generated file in `migrations/`. If the migration changes a schema object, update the
matching expected snapshot in `sql_schema/` where practical.

### 4. Validate Before PR

```powershell
.\deploy\Validate-SqlRepo.ps1
```

Review warnings carefully. Destructive operations such as `DROP TABLE`, `TRUNCATE TABLE`, broad
`UPDATE`, and broad `DELETE` require explicit migration notes and rollback/recovery thinking.

### 5. Open And Review The PR

Open a PR into SQL repo `main`. The PR should include:

- migration summary
- affected SQL objects
- rollback posture
- backup requirement
- bot dependency notes
- validation output

### 6. Deploy From Merged Main

On the bot machine:

```powershell
cd C:\discord_file_downloader
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\venv\Scripts\Activate.ps1
.\dev.ps1

cd C:\K98-bot-SQL-Server
git switch main
git pull origin main
git status
.\deploy\Validate-SqlRepo.ps1 -RepoPath C:\K98-bot-SQL-Server
.\deploy\Test-SqlBackupReadiness.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -BackupPath "C:\sql_backup"
.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER"
```

To deploy one migration explicitly:

```powershell
.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -MigrationId 20260602_001_add_schema_migration_history
```

Deployments from non-`main` branches are blocked by default. Emergency exceptions must include a
reason:

```powershell
.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -AllowNonMainBranch `
  -Reason "Emergency production fix approved by owner"
```

### 7. Verify Deployment History

```sql
SELECT TOP (20) *
FROM dbo.SchemaMigrationHistory
ORDER BY AppliedAtUtc DESC;

SELECT TOP (20) *
FROM dbo.DeploymentRunHistory
ORDER BY StartedAtUtc DESC;
```

Review:

```powershell
Get-Content .\logs\deployment.jsonl -Tail 20
```

### 8. Run Drift Check

```powershell
.\deploy\Invoke-DriftCheck.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER"
```

Review the generated report under `reports/`. No drift means Production matches the expected
schema snapshots. Unexpected drift should be reconciled through a SQL PR.

## Export Snapshots

To export Production schema onto a reviewable branch:

```powershell
.\deploy\Export-ProdSchemaSnapshot.ps1
```

Default branch:

```text
export/prod-schema-YYYYMMDD-HHMMSS
```

The export script refuses direct `main` overwrite by design.

## Nightly Production Export

The old `Export-SqlSchemaAndPush.ps1` task must not remain active because it can push Production
snapshots directly into `main`. Replace it with `deploy\Invoke-NightlyProdSchemaExport.ps1`.

The new nightly workflow:

1. Activates the bot dev environment from `C:\discord_file_downloader`.
2. Requires a clean SQL repo working tree.
3. Fetches and fast-forwards SQL `main`.
4. Creates a timestamped `export/prod-schema-YYYYMMDD-HHMMSS` branch.
5. Exports Production schema onto that branch.
6. Commits and pushes only the export branch when schema changes exist.
7. Switches the local SQL repo back to `main`.
8. Writes structured export logs.

### Replace The Scheduled Task

On `MINI_AMD`, inspect the current scheduled task first:

```powershell
Get-ScheduledTask | Where-Object {
  $_.TaskName -match "SQL|Schema|Export|K98|ROK"
} | Select-Object TaskName, State
```

If the old task name is known, disable it and install the safe task:

```powershell
cd C:\discord_file_downloader
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
.\dev.ps1

cd C:\K98-bot-SQL-Server
.\deploy\Install-NightlySchemaExportTask.ps1 `
  -TaskName "K98 SQL Nightly Schema Export" `
  -OldTaskName "<old task name>" `
  -DisableOldTask `
  -RepoPath "C:\K98-bot-SQL-Server" `
  -BotRepoPath "C:\discord_file_downloader" `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -At "01:30"
```

For unattended overnight execution when the RDP session is logged off, register with an explicit
credential:

```powershell
$credential = Get-Credential "$env:USERDOMAIN\$env:USERNAME"

.\deploy\Install-NightlySchemaExportTask.ps1 `
  -TaskName "K98 SQL Nightly Schema Export" `
  -OldTaskName "<old task name>" `
  -DisableOldTask `
  -RepoPath "C:\K98-bot-SQL-Server" `
  -BotRepoPath "C:\discord_file_downloader" `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -At "01:30" `
  -RunWhetherLoggedOnOrNot `
  -Credential $credential
```

Use the same Windows account that already connects to SQL Server with Windows Auth and has GitHub
push credentials available for the SQL repo.

If the old task name is uncertain, disable it manually in Task Scheduler only after confirming its
action points to `Export-SqlSchemaAndPush.ps1`.

### Test The New Task

Run the task manually:

```powershell
Start-ScheduledTask -TaskName "K98 SQL Nightly Schema Export"
```

Watch local state:

```powershell
Get-ScheduledTask -TaskName "K98 SQL Nightly Schema Export" | Get-ScheduledTaskInfo
Get-Content C:\K98-bot-SQL-Server\logs\export.jsonl -Tail 20
cd C:\K98-bot-SQL-Server
git status
git branch --show-current
```

Expected result:

- task exits successfully
- repo branch returns to `main`
- `git status` is clean
- if drift exists, an `export/prod-schema-*` branch is pushed
- no scheduled job pushes directly to `main`

If the task fails, leave the old task disabled until the failure is understood. Do not re-enable
the old direct-to-main export routine.

## Backup Readiness

Backups are checked through SQL Server `msdb` history and supported by files under
`C:\sql_backup`.

Default thresholds:

- full backup: 24 hours
- differential backup: 8 hours
- log backup: 30 minutes when recovery model is `FULL` or `BULK_LOGGED`

Use explicit parameters if the production policy changes:

```powershell
.\deploy\Test-SqlBackupReadiness.ps1 `
  -MaxFullBackupAgeHours 24 `
  -MaxDiffBackupAgeHours 8 `
  -MaxLogBackupAgeMinutes 30
```

If backup readiness cannot be verified, stop and resolve it before deployment unless the owner
approves a documented emergency exception.

## Rollback And Recovery

Not every SQL migration can be safely auto-rolled back.

Rollback categories:

- `Included`: a reviewed rollback script exists.
- `Manual`: operator notes describe the recovery path.
- `Forward Fix Only`: correct with a new migration rather than rolling back.
- `Not Possible`: recovery requires restore, forward fix, or bespoke data repair.

Failure cases:

- Before SQL changes: fix validation, backup, branch, or connection issue and rerun.
- During migration: stop, inspect error, review partial SQL effects, and use rollback notes.
- After SQL succeeds but bot validation fails: decide between bot rollback, forward fix, or SQL
  rollback based on compatibility and data risk.
- Data-destructive failure: consider restore from backup; do not improvise broad data repairs.

## Emergency Production Hotfix

Use only when Production must be changed directly in SSMS.

### When This Is Allowed

Use this path only when waiting for the normal PR flow would create unacceptable production risk,
for example:

- bot production is broken because an urgent SQL object is missing or malformed
- a safe stored procedure/view fix is needed immediately
- an operator-approved incident requires a minimum direct Production correction

Do not use this path for convenience, routine feature work, broad schema redesign, destructive data
cleanup, or speculative performance tuning.

### Before Touching Production

Create a local incident report from the template before opening SSMS:

```powershell
cd C:\K98-bot-SQL-Server
$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmm")
Copy-Item .\reports\hotfix\hotfix_template.md ".\reports\hotfix\hotfix_${stamp}_short_reason.md"
notepad ".\reports\hotfix\hotfix_${stamp}_short_reason.md"
```

Record:

- UTC time
- operator
- incident reason
- affected SQL object(s)
- expected bot/user impact
- exact intended SQL change
- rollback or forward-fix approach
- approval source
- backup readiness result, including warnings

Confirm backups:

```powershell
.\deploy\Test-SqlBackupReadiness.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -BackupPath "C:\sql_backup"
```

If backup readiness fails, stop unless the owner explicitly accepts restore risk in the incident
note.

### Apply The Direct Production Change

In SSMS:

1. Connect to `MINI_AMD`.
2. Select database `ROK_TRACKER`.
3. Paste only the minimum approved SQL.
4. Prefer `CREATE OR ALTER` for procedures, views, and functions.
5. Avoid destructive table/data changes unless the restore plan is explicit.
6. Save the exact SQL text into the incident note.
7. Execute once.
8. Capture success/error output in the incident note.

Run the narrowest smoke check possible. Examples:

```sql
SELECT OBJECT_ID(N'dbo.ObjectName') AS ObjectId;
EXEC dbo.SomeVerificationProcedure;
```

### Capture Drift Evidence Immediately

After the direct change, capture Production state with the drift workflow. This exports a timestamped
snapshot under `exports/` and writes a drift report under `reports/`:

```powershell
cd C:\K98-bot-SQL-Server
.\deploy\Invoke-DriftCheck.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER"
```

Expected emergency hotfix drift should be narrow and explainable. Record the generated export
snapshot path, drift report path, expected drift, and unexpected drift in the incident report.

Use `deploy\Export-ProdSchemaSnapshot.ps1` only when you specifically need a pushed
`export/prod-schema-*` branch for review. Drift reconciliation can use the local snapshot created
by `Invoke-DriftCheck.ps1`.

### Reconcile Back Into Git

Create a hotfix branch from current `main`:

```powershell
git switch main
git pull origin main
git switch -c codex/sql-hotfix-short-reason
```

Create a migration:

```powershell
.\deploy\New-SqlMigration.ps1 `
  -Description "reconcile emergency production hotfix" `
  -RiskLevel Medium `
  -Rollback Manual
```

Edit the migration so it exactly matches what was applied in Production. The migration must be
idempotent when the Production change has already happened. Include comments or metadata pointing
to the incident report and drift evidence.

For a safely reversible hotfix, prefer `Rollback: Included`, a `RollbackScript:` path, and a
matching rollback file with `RollbackForMigrationId:`.

Update `sql_schema/` to match Production. The safest source is the export branch/snapshot generated
immediately after the hotfix. Copy only the affected object files, then review the diff:

```powershell
Copy-Item .\exports\prod-schema-YYYYMMDD-HHMMSS\dbo.ObjectName.ObjectType.sql `
  .\sql_schema\dbo.ObjectName.ObjectType.sql -Force

git diff
```

If the incident report should be committed, force-add it because `reports/` is ignored by default:

```powershell
git add -f .\reports\hotfix\hotfix_YYYYMMDD_HHMM_short_reason.md
```

Validate and open PR:

```powershell
.\deploy\Validate-SqlRepo.ps1 -RepoPath C:\K98-bot-SQL-Server
git add -A
git commit -m "fix: reconcile emergency SQL hotfix"
git push -u origin codex/sql-hotfix-short-reason
```

PR body must include:

- emergency reason
- exact Production change time
- affected object(s)
- backup readiness result
- smoke check result
- export branch name
- rollback/forward-fix notes

If GitHub CLI is not available on the deployment machine, open the PR from GitHub in a browser or
ask Codex to create it after the branch is pushed.

### After The Hotfix PR Merges

On `MINI_AMD`:

```powershell
git switch main
git pull origin main
.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -ValidationOnly
```

If the reconciliation migration is already effectively present in Production because of the
emergency SSMS change, it should still be deployed when it is idempotent. This records the migration
in `dbo.SchemaMigrationHistory` and proves future deployments have no pending reconciliation work.

Expected pre-deployment validation for an idempotent reconciliation:

```text
Validation succeeded. Pending migration count: 1
PENDING: <reconciliation migration>.sql
```

Run drift check before deployment when the PR updated `sql_schema/`. A clean result means Git's
expected schema now matches Production, but the migration may still be pending in migration
history:

Then run:

```powershell
.\deploy\Invoke-DriftCheck.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER"
```

Deploy the idempotent reconciliation migration from `main`:

```powershell
.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER"
```

Verify there are no pending migrations:

```powershell
.\deploy\Deploy-SqlMigration.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -ValidationOnly
```

Expected:

```text
Validation succeeded. Pending migration count: 0
```

Verify migration history:

```sql
SELECT TOP (5)
    MigrationId,
    Status,
    AppliedAtUtc,
    BranchName,
    GitCommit
FROM dbo.SchemaMigrationHistory
WHERE MigrationId = N'<reconciliation migration id>'
ORDER BY AppliedAtUtc DESC;
```

The hotfix is not closed until drift is clean, migration history is recorded, and the incident
report final status is complete. If the migration is not idempotent, stop and get owner approval
before any manual history insertion.

## Detailed Emergency And Rollback Standards

### Emergency Hotfix Decision Tree

Use the normal SQL PR workflow unless every answer supports emergency handling:

1. Is Production down, corrupting data, blocking a critical bot function, or producing materially
   wrong user output?
   - If no, use the normal SQL PR workflow.
   - If yes, continue.
2. Is there a safe workaround outside SQL?
   - If yes, apply the workaround and create a normal SQL PR.
   - If no, continue.
3. Is the required SQL change small, understood, and reversible or forward-fixable?
   - If no, stop and consider restore or escalation.
   - If yes, continue.
4. Has backup readiness been confirmed?
   - If no, run the backup readiness check.
   - If the check fails, stop unless the owner explicitly accepts the risk in the hotfix report.
5. Create or start the hotfix report.
6. Apply only the minimum safe Production change.
7. Validate.
8. Export and run drift check.
9. Reconcile Git.
10. Complete the incident report.

### Hotfix Report Setup

Create reports from the template:

```powershell
cd C:\K98-bot-SQL-Server
$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmm")
Copy-Item .\reports\hotfix\hotfix_template.md ".\reports\hotfix\hotfix_${stamp}_short_description.md"
```

Do not paste secrets, passwords, tokens, webhooks, or credential-bearing connection strings into
the report.

### Already-Applied Hotfix Reconciliation

Use this when Production was changed before the formal hotfix report existed:

1. Stop making further Production changes.
2. Create a hotfix report immediately.
3. Record everything known: who, when, why, exact SQL if available, affected objects, and
   validation.
4. Run backup readiness for the current state.
5. Run drift check.
6. Create a Git branch from current `main`.
7. Create a reconciliation migration matching current Production.
8. Do not re-run a migration that duplicates an already-applied destructive effect unless it is
   idempotent and safe.
9. Validate migration logic against `dbo.SchemaMigrationHistory` expectations.
10. Open and merge the SQL PR.
11. Run final drift check.
12. Complete the incident report.

### Controlled Hotfix Rehearsal

Run this only when the owner has approved the rehearsal window.

Preferred low-risk rehearsal object:

```text
dbo.SqlHotfixRehearsal
```

The object is deliberately isolated from bot runtime behavior.

Rehearsal steps:

1. Create a rehearsal report:

```powershell
cd C:\K98-bot-SQL-Server
$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmm")
Copy-Item .\reports\hotfix\hotfix_template.md ".\reports\hotfix\rehearsal_${stamp}_sql_hotfix_rehearsal_table.md"
notepad ".\reports\hotfix\rehearsal_${stamp}_sql_hotfix_rehearsal_table.md"
```

2. Confirm the object does not already exist in Git or Production:

```powershell
Select-String -Path .\sql_schema\*.sql -Pattern "SqlHotfixRehearsal"
```

```sql
SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;
```

3. Confirm backup readiness:

```powershell
.\deploy\Test-SqlBackupReadiness.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -BackupPath "C:\sql_backup"
```

4. Apply the direct Production-style SQL in SSMS:

```sql
IF OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SqlHotfixRehearsal
    (
        RehearsalId INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SqlHotfixRehearsal PRIMARY KEY,
        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_SqlHotfixRehearsal_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        Notes NVARCHAR(4000) NULL
    );
END;
```

5. Validate the object exists and the table is empty.
6. Run drift check and record expected drift.
7. Create a reconciliation branch, migration, rollback script if applicable, and expected schema
   snapshot from the drift export.
8. Validate the SQL repo and open a reconciliation PR.
9. After merge, pull `main`, run deployment validation, run drift check, deploy the idempotent
   reconciliation migration, and confirm pending migration count is zero.
10. Complete the rehearsal report with migration history, final drift status, and lessons learned.

The successful Phase 2A rehearsal proved this exact sequence:

```text
Backup readiness succeeded with a differential-age warning
-> direct SQL created dbo.SqlHotfixRehearsal
-> post-change validation confirmed object exists and table is empty
-> drift check showed one expected added object
-> reconciliation PR added migration, rollback script, and schema snapshot
-> pre-deployment ValidationOnly showed one pending migration
-> drift check was clean after Git reconciliation
-> deployment applied the idempotent migration and recorded SchemaMigrationHistory
-> final ValidationOnly showed zero pending migrations
```

### Rollback Decision Tree

1. Did deployment fail before any SQL changed?
   - No rollback is required. Fix validation, backup, branch, or connection issues and retry.
2. Did migration partially apply?
   - Stop. Review deployment logs, transaction state, `SchemaMigrationHistory`, and
     `DeploymentRunHistory`.
   - Choose manual rollback, forward fix, or restore based on data risk.
3. Did SQL succeed but bot validation fail?
   - If backward-compatible, fix the bot or forward-fix SQL.
   - If breaking, consider rollback or restore based on risk.
4. Is there a reviewed rollback script?
   - If yes, confirm backup readiness, review current state, run pre-validation, execute
     deliberately, and run post-validation.
   - If no, do not invent rollback under pressure. Prefer forward fix or restore decision.
5. Is data loss involved or row impact unknown?
   - Escalate restore-from-backup decision.

### Reversible Migration Workflow

- Migration declares `Rollback: Included`.
- Matching rollback file exists under `migrations/rollback/`.
- Rollback file includes `RollbackForMigrationId:`.
- Rollback script includes pre/post validation.
- Rollback script is reviewed in the same PR.
- Rollback script is not automatically run by deployment tooling.
- Operator must manually choose rollback after checking backup readiness.

### Non-Reversible Migration Workflow

- Migration declares `Rollback: Forward Fix Only` or `Rollback: Not Possible`.
- PR explains why rollback is unsafe.
- Release checklist confirms review.
- Backup readiness is mandatory.
- Post-deployment validation is mandatory.
- Restore-from-backup decision point is documented.

### Data Migration Safety Workflow

For high-risk data changes:

1. Run a preview `SELECT`.
2. Confirm expected rows affected.
3. Confirm backup readiness.
4. Execute inside a transaction where safe.
5. Capture rows affected.
6. Run post-validation query.
7. Record results in deployment or hotfix notes.

Example pattern:

```sql
-- Preview
SELECT COUNT(*) AS RowsToChange
FROM dbo.ExampleTable
WHERE ...;

-- Change
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.ExampleTable
    SET ExampleColumn = ...
    WHERE ...;

    SELECT @@ROWCOUNT AS RowsChanged;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
```

### Restore-From-Backup Escalation Points

Restore is an operational decision, not casual rollback. Escalate when:

- data corruption is suspected
- unknown rows were changed
- destructive change applied without reliable rollback
- migration changed multiple dependent objects and failed mid-way
- bot is producing materially wrong output and forward fix is not immediately safe

Restore strategy depends on SQL Server recovery model and the available backup chain.

### Backup Threshold Policy

Current script defaults:

- full backup max age: 24 hours
- differential backup max age: 8 hours, warning-only in current script behavior
- log backup max age: 30 minutes for `FULL` or `BULK_LOGGED` recovery models

Use explicit parameters when the owner approves a temporary policy change. Record overrides in the
deployment or hotfix report.

### Hotfix Closure

A hotfix report is complete only when it records:

- final status
- SQL PR, migration, and commit
- export branch and drift report
- final drift clean, or accepted drift with follow-up
- migration history status, applied UTC, branch, and commit when a reconciliation migration was
  deployed
- final `Deploy-SqlMigration.ps1 -ValidationOnly` pending count
- rollback or forward-fix notes
- deferred optimisations, if any

## Bot Promotion Interaction

When bot code needs new SQL:

1. Deploy backward-compatible SQL first.
2. Confirm migration history and smoke checks.
3. Promote and deploy the bot from `K98-bot/main`.

When SQL needs new bot behavior:

1. Prefer additive SQL that old bot code can tolerate.
2. Deploy SQL.
3. Deploy bot.
4. Remove compatibility objects later through a separate migration.

Breaking SQL changes require a staged plan. Do not deploy a breaking SQL change and bot change as
a single blind step.

## Troubleshooting

### Dirty Working Tree

Commit, stash, or discard local changes before deployment. The deploy script refuses dirty trees.

### Wrong Branch

Deploy from `main`. Use non-`main` override only for documented emergencies.

### Backup Readiness Failure

Check SQL Agent jobs, `msdb` backup history, and `C:\sql_backup`. Do not deploy until backup state
is understood.

### SQL Connection Failure

Confirm the deployment is running on the bot machine under a Windows account with SQL permissions.
For Windows Auth errors such as `Cannot generate SSPI context`, confirm the server name is correct
for the deployment machine, test the same account in SSMS, and check SQL Server SPN/domain
configuration before retrying deployment.

### Migration Already Applied

The deploy runner skips migrations already marked `Applied` in `dbo.SchemaMigrationHistory`.

### Migration Failure

Review the SQL error, `logs/deployment.jsonl`, migration rollback notes, and any partial effects.
Do not mark success manually.

### Unexpected Drift

Review the generated drift report. If Production changed outside Git, reconcile with a hotfix PR.

### Export On Main

Use an export branch. Direct export to `main` defeats the Git-first model.
