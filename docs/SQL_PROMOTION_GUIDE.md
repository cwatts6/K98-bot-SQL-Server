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
.\.venv\Scripts\Activate.ps1
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
- `NotPossible`: recovery requires restore, forward fix, or bespoke data repair.

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

Create a local incident note before opening SSMS. A plain Markdown note is enough:

```powershell
cd C:\K98-bot-SQL-Server
New-Item -ItemType Directory -Force -Path .\reports\hotfix | Out-Null
notepad .\reports\hotfix\hotfix_YYYYMMDD_short_reason.md
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

### Export Production Immediately

After the direct change, capture Production state:

```powershell
cd C:\discord_file_downloader
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\venv\Scripts\Activate.ps1
.\dev.ps1

cd C:\K98-bot-SQL-Server
.\deploy\Export-ProdSchemaSnapshot.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER"
```

This creates an `export/prod-schema-*` branch. It must not update `main`.

### Reconcile Back Into Git

Create a hotfix branch from current `main`:

```powershell
git switch main
git pull origin main
git switch -c hotfix/sql-short-reason
```

Create a migration:

```powershell
.\deploy\New-SqlMigration.ps1 `
  -Description "reconcile emergency production hotfix" `
  -RiskLevel Medium `
  -Rollback Manual
```

Edit the migration so it exactly matches what was applied in Production. Include comments pointing
to the incident note and export branch.

Update `sql_schema/` to match Production. The safest source is the export branch/snapshot generated
immediately after the hotfix. Copy only the affected object files, then review the diff:

```powershell
Copy-Item .\exports\prod-schema-YYYYMMDD-HHMMSS\dbo.ObjectName.StoredProcedure.sql `
  .\sql_schema\dbo.ObjectName.StoredProcedure.sql -Force

git diff
```

Validate and open PR:

```powershell
.\deploy\Validate-SqlRepo.ps1 -RepoPath C:\K98-bot-SQL-Server
git add -A
git commit -m "fix: reconcile emergency SQL hotfix"
git push -u origin hotfix/sql-short-reason
```

PR body must include:

- emergency reason
- exact Production change time
- affected object(s)
- backup readiness result
- smoke check result
- export branch name
- rollback/forward-fix notes

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

If the migration is already effectively present in Production because of the emergency SSMS
change, do not blindly apply a duplicate destructive migration. Either:

- make the reconciliation migration idempotent and safe to run, or
- mark the exact migration as applied only after owner approval and a documented manual history
  insertion.

Then run:

```powershell
.\deploy\Invoke-DriftCheck.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER"
```

The hotfix is not closed until drift is clean or the remaining drift is documented in a follow-up
PR.

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
