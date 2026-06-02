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
cd C:\K98-bot-SQL-Server
git switch main
git pull origin main
git status
.\deploy\Validate-SqlRepo.ps1
.\deploy\Test-SqlBackupReadiness.ps1
.\deploy\Deploy-SqlMigration.ps1
```

To deploy one migration explicitly:

```powershell
.\deploy\Deploy-SqlMigration.ps1 -MigrationId 20260602_001_add_schema_migration_history
```

Deployments from non-`main` branches are blocked by default. Emergency exceptions must include a
reason:

```powershell
.\deploy\Deploy-SqlMigration.ps1 -AllowNonMainBranch -Reason "Emergency production fix approved by owner"
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
.\deploy\Invoke-DriftCheck.ps1
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

1. Record the emergency reason.
2. Confirm backup readiness.
3. Apply the smallest safe Production change.
4. Run a Production schema export immediately.
5. Create `hotfix/sql-short-description`.
6. Add a migration matching the Production change.
7. Open a PR into `main`.
8. Merge after review.
9. Run drift check to prove Git and Production are reconciled.
10. Record final notes.

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
